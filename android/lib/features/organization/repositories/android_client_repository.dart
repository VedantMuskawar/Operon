import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/client.dart';

/// Cached phone map data structure
class CachedPhoneMap {
  final Map<String, String> data;
  final DateTime timestamp;
  final String version;
  
  static const Duration cacheValidDuration = Duration(hours: 1); // Cache valid for 1 hour
  static const Duration cacheStaleDuration = Duration(hours: 24); // Cache stale but usable for 24 hours
  
  CachedPhoneMap({
    required this.data,
    required this.timestamp,
    required this.version,
  });
  
  bool get isValid => DateTime.now().difference(timestamp) < cacheValidDuration;
  bool get isStale => DateTime.now().difference(timestamp) < cacheStaleDuration;
}

class _ClientCacheEntry {
  final List<Client> clients;
  final DateTime timestamp;

  static const Duration validDuration = Duration(minutes: 5);

  _ClientCacheEntry({required this.clients, required this.timestamp});

  bool get isValid => DateTime.now().difference(timestamp) < validDuration;
}

class _ClientPagingState {
  DocumentSnapshot<Map<String, dynamic>>? lastDocument;
  bool hasMore;

  _ClientPagingState({this.lastDocument, this.hasMore = true});

  void reset() {
    lastDocument = null;
    hasMore = true;
  }
}

class ClientPageResult {
  final List<Client> page;
  final List<Client> allClients;
  final bool hasMore;
  final bool fromCache;

  const ClientPageResult({
    required this.page,
    required this.allClients,
    required this.hasMore,
    required this.fromCache,
  });
}

class AndroidClientRepository {
  final FirebaseFirestore _firestore;
  static const String _cacheKeyPrefix = 'client_phone_map_';
  static const String _cacheTimestampPrefix = 'client_phone_map_ts_';
  static const String _cacheVersionPrefix = 'client_phone_map_v_';
  
  // In-memory cache to avoid SharedPreferences reads
  static final Map<String, CachedPhoneMap> _memoryCache = {};
  static final Map<String, _ClientCacheEntry> _clientMemoryCache = {};
  static final Map<String, _ClientPagingState> _clientPagingState = {};

  void _upsertClientInCache(String organizationId, Client client) {
    final existing = _clientMemoryCache[organizationId];
    final clients = existing != null
        ? List<Client>.from(existing.clients)
        : <Client>[];

    final index = clients.indexWhere((c) => c.clientId == client.clientId);
    if (index >= 0) {
      clients[index] = client;
    } else {
      clients.add(client);
    }

    clients.sort((a, b) => a.name.compareTo(b.name));
    _clientMemoryCache[organizationId] = _ClientCacheEntry(
      clients: clients,
      timestamp: DateTime.now(),
    );
  }

  void _removeClientFromCache(String organizationId, String clientId) {
    final existing = _clientMemoryCache[organizationId];
    if (existing == null) return;

    final clients = List<Client>.from(existing.clients)
      ..removeWhere((client) => client.clientId == clientId);

    _clientMemoryCache[organizationId] = _ClientCacheEntry(
      clients: clients,
      timestamp: DateTime.now(),
    );
  }

  void invalidateClientListCache(String organizationId) {
    _clientMemoryCache.remove(organizationId);
    _resetPagingState(organizationId);
  }
  
  AndroidClientRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance {
    // Note: Firestore offline persistence is enabled by default on mobile
    // This reduces server costs by serving cached data when available
  }

  String _pagingKey(String organizationId, String? searchQuery) {
    final normalizedQuery = searchQuery?.trim().toLowerCase() ?? '';
    return '$organizationId::$normalizedQuery';
  }

  void _resetPagingState(String organizationId) {
    _clientPagingState.removeWhere(
      (key, value) => key.startsWith('$organizationId::'),
    );
  }

  List<Client> _filterClients(List<Client> clients, String? searchQuery) {
    if (searchQuery == null || searchQuery.isEmpty) {
      return clients;
    }

    final queryLower = searchQuery.toLowerCase();
    final queryDigits = queryLower.replaceAll(RegExp(r'[^\d]'), '');

    return clients.where((client) {
      final nameMatch = client.name.toLowerCase().contains(queryLower);
      final phoneMatch = client.phoneNumber.toLowerCase().contains(queryLower);
      final emailMatch = client.email?.toLowerCase().contains(queryLower) ?? false;
      final tagMatch = client.tags?.any((tag) => tag.toLowerCase().contains(queryLower)) ?? false;

      if (nameMatch || phoneMatch || emailMatch || tagMatch) {
        return true;
      }

      if (queryDigits.isNotEmpty) {
        final phoneDigitsList = <String>{};
        phoneDigitsList.add(client.phoneNumber.replaceAll(RegExp(r'[^\d]'), ''));
        if (client.phoneList != null) {
          for (final phone in client.phoneList!) {
            phoneDigitsList.add(phone.replaceAll(RegExp(r'[^\d]'), ''));
          }
        }
        return phoneDigitsList.any((digits) => digits.contains(queryDigits));
      }

      return false;
    }).toList();
  }

  List<Client> getCachedClientsList(String organizationId) {
    final cached = _clientMemoryCache[organizationId];
    if (cached == null) {
      return const <Client>[];
    }
    return List<Client>.from(cached.clients);
  }

  /// Fetches all client phone numbers for an organization
  /// Returns a Set of normalized phone numbers and a map of phone to clientId
  /// Uses aggressive caching to minimize Firestore reads (cost optimization)
  Future<Map<String, String>> getClientPhoneToIdMap(String organizationId) async {
    try {
      // Check memory cache first (fastest)
      final memoryCached = _memoryCache[organizationId];
      if (memoryCached != null && memoryCached.isValid) {
        return memoryCached.data;
      }
      
      // Check persistent cache (if memory cache is stale but still usable)
      if (memoryCached != null && memoryCached.isStale) {
        // Return stale data but refresh in background (cost optimization)
        _refreshCacheInBackground(organizationId);
        return memoryCached.data;
      }
      
      // Try to get from persistent cache
      final cached = await _getCachedPhoneMap(organizationId);
      if (cached != null) {
        // Load into memory cache
        _memoryCache[organizationId] = CachedPhoneMap(
          data: cached,
          timestamp: DateTime.now(),
          version: await _getCacheVersion(organizationId) ?? '1',
        );
        return cached;
      }

      // Fetch from Firestore (only if cache is completely expired)
      final snapshot = await _firestore
          .collection('CLIENTS')
          .where('organizationId', isEqualTo: organizationId)
          .get();

      final phoneToIdMap = <String, String>{};
      
      for (var doc in snapshot.docs) {
        final data = doc.data();
        final clientId = data['clientId'] as String? ?? doc.id;

        void addPhone(dynamic phoneValue) {
          if (phoneValue == null) return;
          final phoneStr = phoneValue.toString();
          if (phoneStr.isEmpty) return;
          final normalized = _normalizePhoneNumber(phoneStr);

          if (phoneToIdMap.length < 3) {
            print('Building phone map: "$phoneStr" -> normalized: "$normalized"');
          }

          if (normalized.isNotEmpty) {
            phoneToIdMap[normalized] = clientId;
          }
        }

        addPhone(data['phoneNumber']);

        final additionalPhones = data['phoneList'];
        if (additionalPhones is List) {
          for (final phone in additionalPhones) {
            addPhone(phone);
          }
        }
      }
      
      // Debug: Log final map keys
      if (phoneToIdMap.isNotEmpty) {
        print('Phone map built with ${phoneToIdMap.length} entries');
        print('Sample keys: ${phoneToIdMap.keys.take(3).toList()}');
      }
      
      // Cache the result (memory + persistent)
      final version = await _incrementCacheVersion(organizationId);
      _memoryCache[organizationId] = CachedPhoneMap(
        data: phoneToIdMap,
        timestamp: DateTime.now(),
        version: version,
      );
      await _cachePhoneMap(organizationId, phoneToIdMap, version);
      
      return phoneToIdMap;
    } catch (e) {
      // If Firestore fails, try to return stale cache (better than nothing)
      final staleCache = _memoryCache[organizationId];
      if (staleCache != null && staleCache.isStale) {
        return staleCache.data;
      }
      throw Exception('Failed to fetch client phone numbers: $e');
    }
  }
  
  /// Refresh cache in background without blocking
  void _refreshCacheInBackground(String organizationId) {
    // Refresh asynchronously without blocking current operation
    Future.microtask(() async {
      try {
        final snapshot = await _firestore
            .collection('CLIENTS')
            .where('organizationId', isEqualTo: organizationId)
            .get();

        final phoneToIdMap = <String, String>{};
        
        for (var doc in snapshot.docs) {
          final data = doc.data();
          final clientId = data['clientId'] as String? ?? doc.id;

          void addPhone(dynamic phoneValue) {
            if (phoneValue == null) return;
            final phoneStr = phoneValue.toString();
            if (phoneStr.isEmpty) return;
            final normalized = _normalizePhoneNumber(phoneStr);
            if (normalized.isNotEmpty) {
              phoneToIdMap[normalized] = clientId;
            }
          }

          addPhone(data['phoneNumber']);

          final additionalPhones = data['phoneList'];
          if (additionalPhones is List) {
            for (final phone in additionalPhones) {
              addPhone(phone);
            }
          }
        }
        
        final version = await _incrementCacheVersion(organizationId);
        _memoryCache[organizationId] = CachedPhoneMap(
          data: phoneToIdMap,
          timestamp: DateTime.now(),
          version: version,
        );
        await _cachePhoneMap(organizationId, phoneToIdMap, version);
      } catch (e) {
        // Silent fail - old cache still works
      }
    });
  }

  /// Get cached phone map if valid
  Future<Map<String, String>?> _getCachedPhoneMap(String organizationId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheKey = '$_cacheKeyPrefix$organizationId';
      final timestampKey = '$_cacheTimestampPrefix$organizationId';
      
      final timestampStr = prefs.getString(timestampKey);
      if (timestampStr == null) return null;
      
      final timestamp = DateTime.parse(timestampStr);
      final now = DateTime.now();
      
      // Check if cache is stale (but still usable to reduce server costs)
      if (now.difference(timestamp) > CachedPhoneMap.cacheStaleDuration) {
        // Cache too old, remove it
        await prefs.remove(cacheKey);
        await prefs.remove(timestampKey);
        await prefs.remove('$_cacheVersionPrefix$organizationId');
        return null;
      }
      
      // Get cached data (even if slightly stale, use it to save costs)
      final cachedData = prefs.getString(cacheKey);
      if (cachedData == null) return null;
      
      final Map<String, dynamic> decoded = jsonDecode(cachedData);
      return Map<String, String>.from(decoded);
    } catch (e) {
      // If cache read fails, return null to fetch fresh data
      return null;
    }
  }

  /// Cache phone map with version
  Future<void> _cachePhoneMap(String organizationId, Map<String, String> phoneMap, String version) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheKey = '$_cacheKeyPrefix$organizationId';
      final timestampKey = '$_cacheTimestampPrefix$organizationId';
      final versionKey = '$_cacheVersionPrefix$organizationId';
      
      await prefs.setString(cacheKey, jsonEncode(phoneMap));
      await prefs.setString(timestampKey, DateTime.now().toIso8601String());
      await prefs.setString(versionKey, version);
    } catch (e) {
      // If caching fails, silently continue - not critical
    }
  }
  
  /// Get cache version
  Future<String?> _getCacheVersion(String organizationId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('$_cacheVersionPrefix$organizationId');
    } catch (e) {
      return null;
    }
  }
  
  /// Increment cache version
  Future<String> _incrementCacheVersion(String organizationId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final versionKey = '$_cacheVersionPrefix$organizationId';
      final currentVersion = prefs.getString(versionKey) ?? '0';
      final newVersion = (int.tryParse(currentVersion) ?? 0) + 1;
      await prefs.setString(versionKey, newVersion.toString());
      return newVersion.toString();
    } catch (e) {
      return '1';
    }
  }

  /// Invalidate cache for an organization (call when clients are created/updated)
  /// Clears both memory and persistent cache to ensure fresh data
  Future<void> invalidatePhoneMapCache(String organizationId) async {
    try {
      // Clear memory cache
      _memoryCache.remove(organizationId);
      
      // Clear persistent cache to ensure we get fresh normalized data
      final prefs = await SharedPreferences.getInstance();
      final cacheKey = '$_cacheKeyPrefix$organizationId';
      final timestampKey = '$_cacheTimestampPrefix$organizationId';
      final versionKey = '$_cacheVersionPrefix$organizationId';
      
      await prefs.remove(cacheKey);
      await prefs.remove(timestampKey);
      await prefs.remove(versionKey);
    } catch (e) {
      // If cache invalidation fails, silently continue
    }
  }
  
  /// Incrementally update cache when a client is added/updated
  Future<void> updateCacheIncrementally(String organizationId, String phoneNumber, String clientId, {bool isDelete = false}) async {
    try {
      final memoryCached = _memoryCache[organizationId];
      if (memoryCached != null) {
        final normalized = _normalizePhoneNumber(phoneNumber);
        if (isDelete) {
          memoryCached.data.remove(normalized);
        } else {
          memoryCached.data[normalized] = clientId;
        }
        // Update persistent cache too
        await _cachePhoneMap(organizationId, memoryCached.data, memoryCached.version);
      }
    } catch (e) {
      // Silent fail - will refresh on next full load
    }
  }

  /// Fetches all client phone numbers for an organization (backward compatibility)
  /// Returns a Set of normalized phone numbers
  Future<Set<String>> getClientPhoneNumbers(String organizationId) async {
    final map = await getClientPhoneToIdMap(organizationId);
    return map.keys.toSet();
  }

  Future<ClientPageResult> getClientsPage(
    String organizationId, {
    int limit = 50,
    String? searchQuery,
    bool reset = false,
    bool forceServer = false,
  }) async {
    final pagingKey = _pagingKey(organizationId, searchQuery);
    final pagingState = _clientPagingState.putIfAbsent(
      pagingKey,
      () => _ClientPagingState(),
    );

    if (reset) {
      pagingState.reset();
    }

    final cachedClients = getCachedClientsList(organizationId);
    if (!pagingState.hasMore && !forceServer) {
      return ClientPageResult(
        page: const <Client>[],
        allClients: _filterClients(cachedClients, searchQuery),
        hasMore: false,
        fromCache: true,
      );
    }

    Query<Map<String, dynamic>> query = _firestore
        .collection('CLIENTS')
        .where('organizationId', isEqualTo: organizationId)
        .orderBy('name')
        .limit(limit);

    if (pagingState.lastDocument != null) {
      query = query.startAfterDocument(pagingState.lastDocument!);
    }

    try {
      final snapshot = await query.get(
        GetOptions(
          source: forceServer ? Source.server : Source.serverAndCache,
        ),
      );

      if (reset) {
        _clientMemoryCache.remove(organizationId);
      }

      final newClients = snapshot.docs
          .map((doc) => Client.fromFirestore(doc))
          .toList();

      for (final client in newClients) {
        _upsertClientInCache(organizationId, client);
      }

      if (snapshot.docs.isNotEmpty) {
        pagingState.lastDocument = snapshot.docs.last;
      }
      pagingState.hasMore = snapshot.docs.length == limit;

      final allClients = getCachedClientsList(organizationId);
      return ClientPageResult(
        page: _filterClients(newClients, searchQuery),
        allClients: _filterClients(allClients, searchQuery),
        hasMore: pagingState.hasMore,
        fromCache: false,
      );
    } on FirebaseException catch (e) {
      if (cachedClients.isNotEmpty) {
        return ClientPageResult(
          page: const <Client>[],
          allClients: _filterClients(cachedClients, searchQuery),
          hasMore: pagingState.hasMore,
          fromCache: true,
        );
      }
      throw Exception('Failed to fetch clients: ${e.message ?? e.code}');
    } catch (e) {
      if (cachedClients.isNotEmpty) {
        return ClientPageResult(
          page: const <Client>[],
          allClients: _filterClients(cachedClients, searchQuery),
          hasMore: pagingState.hasMore,
          fromCache: true,
        );
      }
      throw Exception('Failed to fetch clients: $e');
    }
  }

  /// Get clients with caching or force refresh fallback.
  Future<List<Client>> getClients(
    String organizationId, {
    String? searchQuery,
    bool forceRefresh = false,
    int pageSize = 100,
  }) async {
    final cachedEntry = _clientMemoryCache[organizationId];
    if (!forceRefresh && cachedEntry != null && cachedEntry.isValid) {
      return _filterClients(List<Client>.from(cachedEntry.clients), searchQuery);
    }

    final result = await getClientsPage(
      organizationId,
      limit: pageSize,
      searchQuery: searchQuery,
      reset: forceRefresh || cachedEntry == null,
      forceServer: forceRefresh,
    );

    if (result.allClients.isNotEmpty) {
      return result.allClients;
    }

    return _filterClients(getCachedClientsList(organizationId), searchQuery);
  }

  /// Get client by phone number
  Future<Client?> getClientByPhoneNumber(String organizationId, String phoneNumber) async {
    try {
      final normalized = _normalizePhoneNumber(phoneNumber);
      final phoneToIdMap = await getClientPhoneToIdMap(organizationId);
      final clientId = phoneToIdMap[normalized];
      
      if (clientId == null) return null;
      
      return await getClient(organizationId, clientId);
    } catch (e) {
      throw Exception('Failed to fetch client by phone number: $e');
    }
  }

  /// Get client by ID - optimized to use direct document read instead of query (cost savings)
  Future<Client?> getClient(String organizationId, String clientId) async {
    try {
      // Try direct document read first (cheaper than query)
      final doc = await _firestore
          .collection('CLIENTS')
          .doc(clientId)
          .get();

      if (doc.exists) {
        final client = Client.fromFirestore(doc);
        // Verify organizationId matches
        if (client.organizationId == organizationId) {
          return client;
        }
      }
      
      // Fallback: try query (only if document ID doesn't match)
      final snapshot = await _firestore
          .collection('CLIENTS')
          .where('clientId', isEqualTo: clientId)
          .where('organizationId', isEqualTo: organizationId)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) return null;
      return Client.fromFirestore(snapshot.docs.first);
    } catch (e) {
      throw Exception('Failed to fetch client: $e');
    }
  }

  /// Create a new client
  /// Client ID is automatically generated in the backend
  Future<String> createClient(String organizationId, Client client, String userId) async {
    try {
      final now = DateTime.now();
      final normalizedPhone = _normalizePhoneNumber(client.phoneNumber);

      // Generate client ID automatically (using Firestore document ID as clientId)
      // Firestore will generate a unique document ID for us
      final clientData = {
        'organizationId': organizationId,
        'name': client.name,
        'phoneNumber': normalizedPhone,
        'email': client.email,
        if (client.address != null) 'address': client.address!.toMap(),
        'createdAt': Timestamp.fromDate(now),
        'updatedAt': Timestamp.fromDate(now),
        'createdBy': userId,
        'updatedBy': userId,
        'status': client.status,
        if (client.notes != null) 'notes': client.notes,
        if (client.tags != null) 'tags': client.tags,
      };

      // Add document and get the auto-generated ID
      final docRef = await _firestore
          .collection('CLIENTS')
          .add(clientData);

      // Set clientId to match the document ID for consistency
      await docRef.update({'clientId': docRef.id});

      // Update cache incrementally instead of invalidating (cost optimization)
      await updateCacheIncrementally(
        organizationId,
        normalizedPhone,
        docRef.id,
      );

      final newClient = Client(
        id: docRef.id,
        clientId: docRef.id,
        organizationId: organizationId,
        name: client.name,
        phoneNumber: normalizedPhone,
        email: client.email,
        address: client.address,
        createdAt: now,
        updatedAt: now,
        createdBy: userId,
        updatedBy: userId,
        status: client.status,
        notes: client.notes,
        tags: client.tags,
        phoneList: client.phoneList,
      );
      _upsertClientInCache(organizationId, newClient);
      _resetPagingState(organizationId);

      return docRef.id;
    } catch (e) {
      throw Exception('Failed to create client: $e');
    }
  }

  /// Update an existing client
  Future<void> updateClient(
    String organizationId,
    String clientId,
    Client client,
    String userId,
  ) async {
    try {
      final clientWithUser = client.copyWith(
        organizationId: organizationId,
        phoneNumber: _normalizePhoneNumber(client.phoneNumber),
        updatedAt: DateTime.now(),
        updatedBy: userId,
      );

      // Try direct document read first (cheaper)
      final doc = await _firestore
          .collection('CLIENTS')
          .doc(clientId)
          .get();

      if (doc.exists) {
        final existingClient = Client.fromFirestore(doc);
        if (existingClient.organizationId == organizationId) {
          await doc.reference.update(clientWithUser.toFirestore());
          
          // Update cache incrementally
          await updateCacheIncrementally(
            organizationId,
            clientWithUser.phoneNumber,
            clientId,
          );
          _upsertClientInCache(
            organizationId,
            clientWithUser.copyWith(clientId: clientId),
          );
          _resetPagingState(organizationId);
          return;
        }
      }

      // Fallback: use query
      final snapshot = await _firestore
          .collection('CLIENTS')
          .where('clientId', isEqualTo: clientId)
          .where('organizationId', isEqualTo: organizationId)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) {
        throw Exception('Client not found');
      }
      
      await snapshot.docs.first.reference.update(clientWithUser.toFirestore());
      
      // Update cache incrementally
      await updateCacheIncrementally(
        organizationId,
        clientWithUser.phoneNumber,
        clientId,
      );
      _upsertClientInCache(
        organizationId,
        clientWithUser.copyWith(clientId: clientId),
      );
      _resetPagingState(organizationId);
    } catch (e) {
      throw Exception('Failed to update client: $e');
    }
  }

  /// Delete a client and invalidate caches
  Future<void> deleteClient(String organizationId, String clientId) async {
    try {
      final docRef = _firestore.collection('CLIENTS').doc(clientId);
      final doc = await docRef.get();

      if (!doc.exists) {
        return;
      }

      final client = Client.fromFirestore(doc);
      if (client.organizationId != organizationId) {
        throw Exception('Client does not belong to this organization');
      }

      // Remove from caches before deleting
      await updateCacheIncrementally(
        organizationId,
        client.phoneNumber,
        clientId,
        isDelete: true,
      );

      await docRef.delete();

      // Invalidate cache to ensure fresh data everywhere
      await invalidatePhoneMapCache(organizationId);
      _removeClientFromCache(organizationId, clientId);
      _resetPagingState(organizationId);
    } catch (e) {
      throw Exception('Failed to delete client: $e');
    }
  }

  /// Update primary phone number for a client
  Future<void> updatePrimaryPhone(
    String organizationId,
    String clientId,
    String newPhoneNumber,
    String userId,
  ) async {
    try {
      final client = await getClient(organizationId, clientId);
      if (client == null) {
        throw Exception('Client not found');
      }

      final normalizedNewPhone = _normalizePhoneNumber(newPhoneNumber);
      final normalizedCurrentPhone = _normalizePhoneNumber(client.phoneNumber);

      if (normalizedNewPhone == normalizedCurrentPhone) {
        // No change needed
        return;
      }

      final updatedPhoneList = List<String>.from(client.phoneList ?? []);
      // Remove the new primary number from additional numbers (if present)
      updatedPhoneList.removeWhere((phone) => phone == normalizedNewPhone);

      // Add previous primary number to the list for future reference
      if (!updatedPhoneList.contains(normalizedCurrentPhone)) {
        updatedPhoneList.add(normalizedCurrentPhone);
      }

      // Remove old phone from cache before update
      await updateCacheIncrementally(
        organizationId,
        normalizedCurrentPhone,
        clientId,
        isDelete: true,
      );

      final updatedClient = client.copyWith(
        phoneNumber: normalizedNewPhone,
        phoneList: updatedPhoneList,
        updatedAt: DateTime.now(),
        updatedBy: userId,
      );

      await updateClient(organizationId, clientId, updatedClient, userId);
    } catch (e) {
      throw Exception('Failed to update primary phone number: $e');
    }
  }

  /// Normalizes phone number by removing spaces, dashes, and special characters
  /// Preserves country code (e.g., +919876543210)
  String _normalizePhoneNumber(String phone) {
    if (phone.isEmpty) return phone;
    
    // Remove all non-digit characters except + at the beginning
    final cleaned = phone.replaceAll(RegExp(r'[^\d+]'), '');
    
    // If phone starts with +, keep it
    if (cleaned.startsWith('+')) {
      // Already has country code
      return cleaned;
    }
    
    // If no country code, check if it's a valid 10-digit number and add +91 (India default)
    // Remove leading zeros
    var digits = cleaned;
    while (digits.startsWith('0') && digits.length > 1) {
      digits = digits.substring(1);
    }
    
    // If it's exactly 10 digits, assume it's Indian and add +91
    if (digits.length == 10) {
      return '+91$digits';
    }
    
    // If it's more than 10 digits, check if it starts with country code
    if (digits.length > 10) {
      // Common country codes: 91 (India), 1 (US/Canada), etc.
      // If starts with 91 followed by 10 digits, add +
      if (digits.startsWith('91') && digits.length == 12) {
        return '+$digits';
      }
      // If starts with 1 followed by 10 digits (US/Canada), add +
      if (digits.startsWith('1') && digits.length == 11) {
        return '+$digits';
      }
      // For other cases, try to detect country code or default to +91
      // Take last 10 digits and assume +91
      final last10 = digits.substring(digits.length - 10);
      return '+91$last10';
    }
    
    // If less than 10 digits, return as is (might be incomplete)
    return digits;
  }

  /// Add a phone number to a client's phoneList
  Future<void> addPhoneToClient(String organizationId, String clientId, String phoneNumber, String userId) async {
    try {
      // Normalize the phone number
      final normalizedPhone = _normalizePhoneNumber(phoneNumber);
      
      // Get the current client
      final client = await getClient(organizationId, clientId);
      if (client == null) {
        throw Exception('Client not found');
      }
      
      // Get current phoneList or create empty list
      final currentPhoneList = client.phoneList ?? [];
      
      // Check if phone number already exists in phoneList
      if (currentPhoneList.contains(normalizedPhone)) {
        // Phone number already exists, no need to update
        return;
      }
      
      // Add the new phone number to the list
      final updatedPhoneList = [...currentPhoneList, normalizedPhone];
      
      // Update the client with new phoneList
      final updatedClient = client.copyWith(
        phoneList: updatedPhoneList,
        updatedAt: DateTime.now(),
        updatedBy: userId,
      );
      
      await updateClient(organizationId, clientId, updatedClient, userId);
    } catch (e) {
      throw Exception('Failed to add phone to client: $e');
    }
  }

  /// Public method to normalize phone numbers (for use in UI)
  /// Preserves country code (e.g., +919876543210)
  static String normalizePhoneNumber(String phone) {
    if (phone.isEmpty) return phone;
    
    // Remove all non-digit characters except + at the beginning
    final cleaned = phone.replaceAll(RegExp(r'[^\d+]'), '');
    
    // If phone starts with +, keep it
    if (cleaned.startsWith('+')) {
      return cleaned;
    }
    
    // If no country code, check if it's a valid 10-digit number and add +91 (India default)
    var digits = cleaned;
    while (digits.startsWith('0') && digits.length > 1) {
      digits = digits.substring(1);
    }
    
    // If it's exactly 10 digits, assume it's Indian and add +91
    if (digits.length == 10) {
      return '+91$digits';
    }
    
    // If it's more than 10 digits, check if it starts with country code
    if (digits.length > 10) {
      // Common country codes: 91 (India), 1 (US/Canada), etc.
      if (digits.startsWith('91') && digits.length == 12) {
        return '+$digits';
      }
      if (digits.startsWith('1') && digits.length == 11) {
        return '+$digits';
      }
      // For other cases, take last 10 digits and assume +91
      final last10 = digits.substring(digits.length - 10);
      return '+91$last10';
    }
    
    // If less than 10 digits, return as is (might be incomplete)
    return digits;
  }
}

