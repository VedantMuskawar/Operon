import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:call_log/call_log.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/app_theme.dart';
import '../../repositories/android_client_repository.dart';
import '../../models/client.dart';
import 'android_client_detail_page.dart';
import 'android_client_pending_orders_page.dart';

class AndroidAddClientPage extends StatefulWidget {
  final String organizationId;

  const AndroidAddClientPage({
    super.key,
    required this.organizationId,
  });

  @override
  State<AndroidAddClientPage> createState() => _AndroidAddClientPageState();
}

class _AndroidAddClientPageState extends State<AndroidAddClientPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  Timer? _debounceTimer;
  bool _isSearching = false;
  static const int _minSearchLength = 2;
  static const Duration _debounceDelay = Duration(milliseconds: 300); // Reduced from 400ms for faster response
  
  // Pagination constants
  static const int _contactsPerPage = 100; // Increased from 50 for better initial load
  static const int _maxSearchResults = 200;
  static const String _contactsIndexCacheKey = 'android_add_client_search_index_v1';
  static const String _contactsIndexHashKey = 'android_add_client_search_index_hash_v1';

  // Contacts state
  List<Contact> _allContacts = [];
  List<Contact> _filteredContacts = [];
  List<Contact> _displayedContacts = []; // Paginated contacts for display
  bool _contactsLoading = false;
  bool _contactsPermissionGranted = false;
  bool _hasMoreContacts = false;
  int _currentPage = 0;
  final Map<String, Uint8List?> _thumbnailCache = {}; // Cache for loaded thumbnails
  final Set<String> _loadingThumbnails = {}; // Track thumbnails being loaded
  
  // Pre-processed search data for efficiency
  final Map<String, String> _contactNameLowercase = {}; // Contact ID -> lowercase name
  final Map<String, List<String>> _contactPhoneDigits = {}; // Contact ID -> normalized phone digits
  bool _searchDataPrepared = false;
  Future<void>? _searchPreparationFuture;
  
  // Client state
  final AndroidClientRepository _clientRepository = AndroidClientRepository();
  Map<String, String> _phoneToClientIdMap = {}; // Map normalized phone to clientId
  bool _clientsLoaded = false;
  bool _loadingClients = false;

  // Calls state
  List<CallLogEntry> _allCalls = [];
  List<CallLogEntry> _filteredCalls = [];
  bool _callsLoading = false;
  bool _callsPermissionGranted = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_onTabChanged);
    _requestPermissions();
  }

  void _onTabChanged() {
    if (!_tabController.indexIsChanging) {
      _requestPermissions();
      if (_tabController.index == 1 &&
          _contactsPermissionGranted &&
          !_contactsLoading &&
          _allContacts.isEmpty) {
        _loadContacts();
      }
    }
  }
  
  Future<void> _loadClientsIfNeeded() async {
    if (_clientsLoaded || _loadingClients) return;
    
    setState(() {
      _loadingClients = true;
    });
    
    try {
      // Invalidate cache to ensure we get fresh data with country codes
      await _clientRepository.invalidatePhoneMapCache(widget.organizationId);
      
      final phoneToIdMap = await _clientRepository.getClientPhoneToIdMap(widget.organizationId);
      if (mounted) {
        setState(() {
          _phoneToClientIdMap = phoneToIdMap;
          _clientsLoaded = true;
          _loadingClients = false;
        });
        
        // Debug: Log phone map contents
        print('Loaded ${phoneToIdMap.length} client phone numbers');
        if (phoneToIdMap.isNotEmpty) {
          print('Sample phone map keys: ${phoneToIdMap.keys.take(5).toList()}');
          // Check if keys have country codes
          final sampleKeys = phoneToIdMap.keys.take(5).toList();
          final hasCountryCodes = sampleKeys.any((key) => key.startsWith('+'));
          print('Phone map keys have country codes: $hasCountryCodes');
        }
      }
    } catch (e) {
      print('Error loading clients: $e');
      if (mounted) {
        setState(() {
          _loadingClients = false;
        });
      }
    }
  }

  Future<void> _requestPermissions() async {
    if (_tabController.index == 0) {
      // Recent Calls tab - request call log permission
      if (!_callsPermissionGranted) {
        await _loadRecentCalls();
      }
    } else {
      // Contacts tab - request permission and pre-load contacts when available
      if (!_contactsPermissionGranted) {
        final permission = await Permission.contacts.request();
        if (permission.isGranted) {
          setState(() {
            _contactsPermissionGranted = true;
          });
          if (_allContacts.isEmpty && !_contactsLoading) {
            _loadContacts();
          }
        }
      }
      if (_contactsPermissionGranted && _allContacts.isEmpty && !_contactsLoading) {
        _loadContacts();
      }
    }
  }

  Future<void> _loadContacts() async {
    if (_contactsLoading || _allContacts.isNotEmpty) return;
    
    setState(() {
      _contactsLoading = true;
    });

    try {
      if (!_contactsPermissionGranted) {
        final permission = await Permission.contacts.request();
        if (!permission.isGranted) {
          setState(() {
            _contactsPermissionGranted = false;
            _contactsLoading = false;
          });
          return;
        }
        setState(() {
          _contactsPermissionGranted = true;
        });
      }

      // Load contacts WITHOUT thumbnails initially for better performance
      final contacts = await FlutterContacts.getContacts(
        withProperties: true,
        withThumbnail: false, // Load thumbnails on-demand
      );

      if (mounted) {
        setState(() {
          _allContacts = contacts;
          _filteredContacts = contacts;
          _updateDisplayedContacts(); // Update displayed contacts immediately
          _contactsLoading = false;
          _searchDataPrepared = false; // Reset flag to prepare new data
          _contactNameLowercase.clear();
          _contactPhoneDigits.clear();
          _searchPreparationFuture = null;
        });
        
        // Prepare search data asynchronously
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _prepareSearchData();
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _contactsLoading = false;
        });
      }
    }
  }
  
  /// Pre-process contact data for efficient searching
  Future<void> _prepareSearchData() async {
    if (_searchDataPrepared || _allContacts.isEmpty) return;

    final contactsPayload = _allContacts
        .map((contact) => {
              'id': contact.id,
              'name': contact.displayName,
              'phones': contact.phones.map((p) => p.number).toList(),
            })
        .toList(growable: false);

    final signature = _generateContactsSignature(contactsPayload);

    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedSignature = prefs.getString(_contactsIndexHashKey);
      final cachedIndexJson = prefs.getString(_contactsIndexCacheKey);

      if (cachedSignature == signature && cachedIndexJson != null) {
        try {
          final cachedMap = jsonDecode(cachedIndexJson) as Map<String, dynamic>;
          _applySearchIndex(cachedMap);
          _searchDataPrepared = true;
          return;
        } catch (_) {
          // Ignore cache corruption and rebuild index below
        }
      }

      final indexData = await compute(_buildSearchIndex, contactsPayload);
      if (!mounted) return;
      _applySearchIndex(indexData);
      await prefs.setString(_contactsIndexCacheKey, jsonEncode(indexData));
      await prefs.setString(_contactsIndexHashKey, signature);
      _searchDataPrepared = true;
    } catch (e) {
      // Fallback: build index on main isolate if compute or prefs fail
      _buildSearchIndexSync(contactsPayload);
      _searchDataPrepared = true;
    }
  }

  void _applySearchIndex(Map<String, dynamic> indexData) {
    final names = Map<String, dynamic>.from(indexData['names'] as Map);
    final phones = Map<String, dynamic>.from(indexData['phones'] as Map);

    _contactNameLowercase
      ..clear()
      ..addAll(names.map((key, value) => MapEntry(key, value as String)));

    _contactPhoneDigits
      ..clear()
      ..addAll(phones.map((key, value) => MapEntry(key, List<String>.from(value as List))));
  }

  void _buildSearchIndexSync(List<Map<String, dynamic>> contactsPayload) {
    final index = _buildSearchIndex(contactsPayload);
    _applySearchIndex(index);
  }

  String _generateContactsSignature(List<Map<String, dynamic>> contactsPayload) {
    int hash = 17;
    for (final item in contactsPayload) {
      final id = item['id'] as String? ?? '';
      final name = item['name'] as String? ?? '';
      hash = 37 * hash + id.hashCode;
      hash = 37 * hash + name.hashCode;
      final phones = item['phones'] as List<dynamic>? ?? const [];
      for (final phone in phones) {
        hash = 37 * hash + phone.toString().hashCode;
      }
    }
    return '${contactsPayload.length}_$hash';
  }

  void _scheduleSearchAfterPreparation(String query) {
    if (_allContacts.isEmpty) {
      return;
    }
    if (_searchPreparationFuture == null) {
      _searchPreparationFuture = _prepareSearchData();
    }
    _searchPreparationFuture?.then((_) {
      if (!mounted) return;
      _searchPreparationFuture = null;
      if (_searchDataPrepared) {
        _performSearch(query);
      }
    }).catchError((error) {
      if (mounted) {
        _searchPreparationFuture = null;
      }
    });
  }
  
  void _updateDisplayedContacts() {
    final startIndex = 0;
    final endIndex = ((_currentPage + 1) * _contactsPerPage).clamp(0, _filteredContacts.length);
    _displayedContacts = _filteredContacts.sublist(startIndex, endIndex);
    _hasMoreContacts = endIndex < _filteredContacts.length;
  }
  
  Future<void> _loadMoreContacts() async {
    if (_contactsLoading || !_hasMoreContacts) return;
    
    setState(() {
      _currentPage++;
      _updateDisplayedContacts();
    });
    
    // Load thumbnails for newly visible contacts
    _loadThumbnailsForVisibleContacts();
  }
  
  Future<void> _loadThumbnailForContact(Contact contact) async {
    final contactId = contact.id;
    
    // Skip if already cached or loading
    if (_thumbnailCache.containsKey(contactId) || _loadingThumbnails.contains(contactId)) {
      return;
    }
    
    setState(() {
      _loadingThumbnails.add(contactId);
    });
    
    try {
      // Load thumbnail for this specific contact
      final updatedContact = await FlutterContacts.getContact(contactId, withThumbnail: true);
      if (updatedContact != null && updatedContact.photo != null && mounted) {
        setState(() {
          _thumbnailCache[contactId] = updatedContact.photo;
          _loadingThumbnails.remove(contactId);
        });
      } else {
        setState(() {
          _thumbnailCache[contactId] = null; // Cache null to avoid retrying
          _loadingThumbnails.remove(contactId);
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _thumbnailCache[contactId] = null;
          _loadingThumbnails.remove(contactId);
        });
      }
    }
  }
  
  void _loadThumbnailsForVisibleContacts() {
    // Load thumbnails for contacts near the end of displayed list
    final startIndex = (_displayedContacts.length - _contactsPerPage).clamp(0, _displayedContacts.length);
    final contactsToLoad = _displayedContacts.skip(startIndex).take(_contactsPerPage);
    
    for (final contact in contactsToLoad) {
      if (!_thumbnailCache.containsKey(contact.id) && !_loadingThumbnails.contains(contact.id)) {
        _loadThumbnailForContact(contact);
      }
    }
  }
  
  String _normalizePhoneNumber(String phone) {
    return AndroidClientRepository.normalizePhoneNumber(phone);
  }
  
  /// Check if a contact is an existing client (called on tap)
  Future<String?> _checkContactIsClient(Contact contact) async {
    // Load clients if not already loaded
    if (!_clientsLoaded) {
      await _loadClientsIfNeeded();
    }
    
    if (!_clientsLoaded || _phoneToClientIdMap.isEmpty) {
      return null;
    }
    
    // Check each phone number from the contact
    for (var phone in contact.phones) {
      if (phone.number.isEmpty) continue;
      
      // Normalize the contact phone number
      final normalized = _normalizePhoneNumber(phone.number);
      
      // Debug: Print for troubleshooting (remove in production if needed)
      print('Checking contact phone: "${phone.number}" -> normalized: "$normalized"');
      print('Phone map keys sample: ${_phoneToClientIdMap.keys.take(3).toList()}');
      
      // Check if normalized phone exists in the map
      final clientId = _phoneToClientIdMap[normalized];
      if (clientId != null) {
        print('Found matching client: $clientId');
        return clientId;
      }
      
      // Also try checking without the + sign (in case stored format is different)
      if (normalized.startsWith('+')) {
        final withoutPlus = normalized.substring(1);
        final clientIdWithoutPlus = _phoneToClientIdMap[withoutPlus];
        if (clientIdWithoutPlus != null) {
          print('Found matching client (without +): $clientIdWithoutPlus');
          return clientIdWithoutPlus;
        }
      }
      
      // Also try checking if the stored number is the reverse (with + added)
      if (!normalized.startsWith('+')) {
        final withPlus = '+$normalized';
        final clientIdWithPlus = _phoneToClientIdMap[withPlus];
        if (clientIdWithPlus != null) {
          print('Found matching client (with +): $clientIdWithPlus');
          return clientIdWithPlus;
        }
      }
    }
    
    print('No matching client found for contact: ${contact.displayName}');
    return null;
  }

  Future<void> _loadRecentCalls() async {
    setState(() {
      _callsLoading = true;
    });

    try {
      final permission = await Permission.phone.request();
      if (permission.isGranted) {
        setState(() {
          _callsPermissionGranted = true;
        });

        // Get recent calls (last 100 for performance)
        final calls = await CallLog.get();
        final recentCalls = calls.take(100).toList();

        setState(() {
          _allCalls = recentCalls;
          _filteredCalls = recentCalls;
          _callsLoading = false;
        });
      } else {
        setState(() {
          _callsPermissionGranted = false;
          _callsLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _callsLoading = false;
      });
    }
  }

  void _onSearchChanged(String query) {
    setState(() {
      _searchQuery = query;
      
      // If query is empty, show all items immediately
      if (query.isEmpty) {
        _filteredContacts = List.from(_allContacts);
        _currentPage = 0;
        _updateDisplayedContacts();
        _isSearching = false;
        _debounceTimer?.cancel();
        return;
      }
      
      // If query is less than minimum length, show all items
      if (query.length < _minSearchLength) {
        _filteredContacts = List.from(_allContacts);
        _currentPage = 0;
        _updateDisplayedContacts();
        _isSearching = false;
        _debounceTimer?.cancel();
        return;
      }
      
      // Set searching state
      _isSearching = true;
    });
    
    // Cancel previous timer
    _debounceTimer?.cancel();
    
    // Start new debounce timer
    _debounceTimer = Timer(_debounceDelay, () {
      if (mounted && query.length >= _minSearchLength) {
        _performSearch(query);
      }
    });
  }

  void _performSearch(String query) {
    final queryLower = query.trim().toLowerCase();
    
    if (!_searchDataPrepared) {
      _scheduleSearchAfterPreparation(query);
      return;
    }
    
    // Filter contacts - use pre-processed data for efficiency
    List<Contact> filteredResults;
    if (queryLower.isEmpty) {
      filteredResults = List.from(_allContacts);
    } else {
      final results = <Contact>[];
      int count = 0;
      
      // Pre-compile regex once
      final queryDigits = queryLower.replaceAll(RegExp(r'[^\d]'), '');
      final queryLowerName = queryLower;
      
      for (final contact in _allContacts) {
        if (count >= _maxSearchResults) break;
        
        final contactId = contact.id;
        
        // Use pre-processed lowercase name (much faster)
        final nameLower = _contactNameLowercase[contactId] ?? contact.displayName.toLowerCase();
        if (nameLower.contains(queryLowerName)) {
          results.add(contact);
          count++;
          continue;
        }
        
        // Use pre-processed phone digits (much faster)
        if (queryDigits.isNotEmpty) {
          final phoneDigits = _contactPhoneDigits[contactId] ?? [];
          for (final digits in phoneDigits) {
            if (digits.contains(queryDigits)) {
              results.add(contact);
              count++;
              break;
            }
          }
        }
      }
      filteredResults = results;
    }
    
    // Filter calls
    List<CallLogEntry> filteredCalls;
    if (queryLower.isEmpty) {
      filteredCalls = List.from(_allCalls);
    } else {
      final results = <CallLogEntry>[];
      final queryDigits = queryLower.replaceAll(RegExp(r'[^\d]'), '');
      
      for (final call in _allCalls) {
        final number = call.number ?? '';
        final name = call.name ?? '';
        
        // Check name match
        if (name.toLowerCase().contains(queryLower)) {
          results.add(call);
          continue;
        }
        
        // Check number match (remove non-digits for comparison)
        if (queryDigits.isNotEmpty) {
          final numberDigits = number.replaceAll(RegExp(r'[^\d]'), '');
          if (numberDigits.contains(queryDigits)) {
            results.add(call);
          }
        }
      }
      filteredCalls = results;
    }
    
    // Update state with filtered results and reset pagination
    setState(() {
      _filteredContacts = filteredResults;
      _filteredCalls = filteredCalls;
      _currentPage = 0; // Reset to first page
      _isSearching = false;
      _updateDisplayedContacts(); // Update displayed contacts
    });
    
    // Load thumbnails for visible contacts (async, non-blocking)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadThumbnailsForVisibleContacts();
    });
  }


  @override
  void dispose() {
    _debounceTimer?.cancel();
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    _searchController.dispose();
    // Clear thumbnail cache to free memory
    _thumbnailCache.clear();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Add Client',
          style: TextStyle(
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
        backgroundColor: AppTheme.surfaceColor,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppTheme.primaryColor,
          labelColor: AppTheme.primaryColor,
          unselectedLabelColor: AppTheme.textSecondaryColor,
          tabs: const [
            Tab(icon: Icon(Icons.call)),
            Tab(icon: Icon(Icons.people)),
          ],
        ),
      ),
      backgroundColor: AppTheme.backgroundColor,
      body: SafeArea(
        child: Column(
        children: [
          // Search Bar
          Container(
            padding: const EdgeInsets.all(16),
            color: AppTheme.surfaceColor,
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: _searchQuery.length < _minSearchLength && _searchQuery.isNotEmpty
                    ? 'Type at least $_minSearchLength characters to search...'
                    : _tabController.index == 0
                        ? 'Search recent calls...'
                        : 'Search contacts by name or phone...',
                hintStyle: const TextStyle(color: AppTheme.textSecondaryColor),
                prefixIcon: _isSearching
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: Padding(
                          padding: EdgeInsets.all(12.0),
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
                          ),
                        ),
                      )
                    : const Icon(
                        Icons.search,
                        color: AppTheme.textSecondaryColor,
                      ),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        color: AppTheme.textSecondaryColor,
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _searchQuery = '';
                            _filteredContacts = List.from(_allContacts);
                            _currentPage = 0;
                            _updateDisplayedContacts();
                            _filteredCalls = List.from(_allCalls);
                          });
                        },
                      )
                    : null,
                filled: true,
                fillColor: AppTheme.cardColor,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: AppTheme.borderColor,
                    width: 1,
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: AppTheme.borderColor,
                    width: 1,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: AppTheme.primaryColor,
                    width: 2,
                  ),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
              style: const TextStyle(color: AppTheme.textPrimaryColor),
              onChanged: (value) {
                // Load contacts when search is performed (if not already loaded)
                if (_tabController.index == 1 && value.isNotEmpty && _allContacts.isEmpty && !_contactsLoading) {
                  _loadContacts().then((_) {
                    if (mounted) {
                      _onSearchChanged(value);
                    }
                  });
                } else {
                  _onSearchChanged(value);
                }
              },
            ),
          ),
          // Tab Content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildRecentCallsTab(),
                _buildContactsTab(),
              ],
            ),
          ),
        ],
      ),
      ),
    );
  }

  Widget _buildRecentCallsTab() {
    if (_callsLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (!_callsPermissionGranted) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.phone_disabled,
              size: 64,
              color: AppTheme.textSecondaryColor,
            ),
            const SizedBox(height: 16),
            const Text(
              'Permission Required',
              style: TextStyle(
                color: AppTheme.textPrimaryColor,
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Please grant phone permission to view call logs',
              style: TextStyle(
                color: AppTheme.textSecondaryColor,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadRecentCalls,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
              ),
              child: const Text('Grant Permission'),
            ),
          ],
        ),
      );
    }

    // Show message when search query is less than minimum
    if (_searchQuery.isNotEmpty && _searchQuery.length < _minSearchLength) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search,
              size: 64,
              color: AppTheme.textSecondaryColor.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'Type at least $_minSearchLength characters to search',
              style: const TextStyle(
                color: AppTheme.textPrimaryColor,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Currently showing all ${_allCalls.length} recent call${_allCalls.length != 1 ? 's' : ''}',
              style: TextStyle(
                color: AppTheme.textSecondaryColor,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    if (_filteredCalls.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _searchQuery.isEmpty
                  ? Icons.call
                  : Icons.search_off,
              size: 64,
              color: AppTheme.textSecondaryColor,
            ),
            const SizedBox(height: 16),
            Text(
              _searchQuery.isEmpty
                  ? 'No Recent Calls'
                  : 'No Matching Calls',
              style: const TextStyle(
                color: AppTheme.textPrimaryColor,
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (_searchQuery.isNotEmpty) ...[
              const SizedBox(height: 8),
              const Text(
                'Try a different search query',
                style: TextStyle(
                  color: AppTheme.textSecondaryColor,
                  fontSize: 14,
                ),
              ),
            ],
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: _filteredCalls.length,
      itemBuilder: (context, index) {
        final call = _filteredCalls[index];
        return _buildCallListItem(call);
      },
    );
  }

  Widget _buildCallListItem(CallLogEntry call) {
    final number = call.number ?? 'Unknown';
    final name = call.name ?? number;
    final callType = call.callType;
    
    IconData callIcon;
    Color callColor;
    String callTypeText;
    
    switch (callType) {
      case CallType.incoming:
        callIcon = Icons.call_received;
        callColor = Colors.green;
        callTypeText = 'Incoming';
        break;
      case CallType.outgoing:
        callIcon = Icons.call_made;
        callColor = Colors.blue;
        callTypeText = 'Outgoing';
        break;
      case CallType.missed:
        callIcon = Icons.call_missed;
        callColor = Colors.red;
        callTypeText = 'Missed';
        break;
      default:
        callIcon = Icons.call;
        callColor = AppTheme.textSecondaryColor;
        callTypeText = 'Unknown';
    }

    // Display normal call list - check client status on tap
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: AppTheme.borderColor,
          width: 1,
        ),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.2),
          child: Icon(
            callIcon,
            color: callColor,
          ),
        ),
        title: Text(
          name,
          style: const TextStyle(
            color: AppTheme.textPrimaryColor,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              number,
              style: const TextStyle(
                color: AppTheme.textSecondaryColor,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 2),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    callTypeText,
                    style: TextStyle(
                      color: callColor,
                      fontSize: 11,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  _formatDuration(call.duration ?? 0),
                  style: const TextStyle(
                    color: AppTheme.textSecondaryColor,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ],
        ),
        trailing: const Icon(
          Icons.arrow_forward_ios,
          size: 16,
          color: AppTheme.textSecondaryColor,
        ),
        onTap: () async {
          // Show loading indicator
          if (mounted) {
            showDialog(
              context: context,
              barrierDismissible: false,
              builder: (context) => const Center(
                child: CircularProgressIndicator(),
              ),
            );
          }
          
          // Check if phone number is an existing client
          if (!_clientsLoaded) {
            await _loadClientsIfNeeded();
          }
          
          if (!mounted) return;
          
          // Dismiss loading indicator
          Navigator.of(context).pop();
          
          String? clientId;
          if (_clientsLoaded) {
            final normalized = _normalizePhoneNumber(number);
            print('Checking call log phone: "$number" -> normalized: "$normalized"');
            
            // Check with normalized phone
            clientId = _phoneToClientIdMap[normalized];
            
            // Also try variations if not found
            if (clientId == null && normalized.startsWith('+')) {
              clientId = _phoneToClientIdMap[normalized.substring(1)];
            }
            if (clientId == null && !normalized.startsWith('+')) {
              clientId = _phoneToClientIdMap['+$normalized'];
            }
            
            if (clientId != null) {
              print('Found matching client from call: $clientId');
            } else {
              print('No matching client found for call: $number');
            }
          }
          
          final foundClientId = clientId; // Store in non-nullable variable for null check
          if (foundClientId != null) {
            // Existing client - navigate to pending orders
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => AndroidClientPendingOrdersPage(
                  organizationId: widget.organizationId,
                  clientId: foundClientId,
                  clientName: name,
                  clientPhone: number,
                ),
              ),
            );
          } else {
            // Non-existing client - show dialog asking if new or existing customer
            final validName = (name != 'Unknown' && name != number && name.trim().isNotEmpty) 
                ? name 
                : null;
            await _showNewOrExistingDialogForCall(number, validName ?? number);
          }
        },
      ),
    );
  }

  Widget _buildContactsTab() {
    // Load clients if not already loaded
    if (!_clientsLoaded && !_loadingClients) {
      _loadClientsIfNeeded();
    }
    
    if (_contactsLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (!_contactsPermissionGranted) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.contacts_outlined,
              size: 64,
              color: AppTheme.textSecondaryColor,
            ),
            const SizedBox(height: 16),
            const Text(
              'Permission Required',
              style: TextStyle(
                color: AppTheme.textPrimaryColor,
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Please grant contacts permission to view contacts',
              style: TextStyle(
                color: AppTheme.textSecondaryColor,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () async {
                final permission = await Permission.contacts.request();
                if (permission.isGranted && mounted) {
                  setState(() {
                    _contactsPermissionGranted = true;
                  });
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
              ),
              child: const Text('Grant Permission'),
            ),
          ],
        ),
      );
    }

    // Show message when search query is less than minimum
    if (_searchQuery.isNotEmpty && _searchQuery.length < _minSearchLength) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search,
              size: 64,
              color: AppTheme.textSecondaryColor.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'Type at least $_minSearchLength characters to search',
              style: const TextStyle(
                color: AppTheme.textPrimaryColor,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              _allContacts.isEmpty
                  ? 'Enter a search query to find contacts'
                  : 'Showing ${_displayedContacts.length} of ${_allContacts.length} contact${_allContacts.length != 1 ? 's' : ''}',
              style: TextStyle(
                color: AppTheme.textSecondaryColor,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    // Show empty state if no search query and no contacts loaded
    if (_searchQuery.isEmpty && _allContacts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.search,
              size: 64,
              color: AppTheme.textSecondaryColor,
            ),
            const SizedBox(height: 16),
            const Text(
              'Search Contacts',
              style: TextStyle(
                color: AppTheme.textPrimaryColor,
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Enter at least $_minSearchLength characters to find contacts',
              style: TextStyle(
                color: AppTheme.textSecondaryColor,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    if (_filteredContacts.isEmpty && _searchQuery.isNotEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.search_off,
              size: 64,
              color: AppTheme.textSecondaryColor,
            ),
            const SizedBox(height: 16),
            const Text(
              'No Contacts Found',
              style: TextStyle(
                color: AppTheme.textPrimaryColor,
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Try a different search query',
              style: TextStyle(
                color: AppTheme.textSecondaryColor,
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: _hasMoreContacts ? _displayedContacts.length + 1 : _displayedContacts.length,
      cacheExtent: 500, // Cache 500 pixels worth of items
      addAutomaticKeepAlives: false, // Don't keep all items alive
      addRepaintBoundaries: true, // Add repaint boundaries for better performance
      itemBuilder: (context, index) {
        // Load more indicator
        if (index == _displayedContacts.length) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: ElevatedButton(
                onPressed: _hasMoreContacts ? _loadMoreContacts : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Load More Contacts'),
              ),
            ),
          );
        }
        
        final contact = _displayedContacts[index];
        
        // Load thumbnail when item becomes visible
        if (!_thumbnailCache.containsKey(contact.id) && !_loadingThumbnails.contains(contact.id)) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _loadThumbnailForContact(contact);
          });
        }
        
        return _buildContactListItem(contact);
      },
    );
  }

  Widget _buildContactListItem(Contact contact) {
    final name = contact.displayName.isNotEmpty 
        ? contact.displayName 
        : 'Unknown';
    final phones = contact.phones;
    final primaryPhone = phones.isNotEmpty ? phones.first.number : 'No number';
    final contactId = contact.id;
    
    // Get thumbnail from cache
    final thumbnail = _thumbnailCache[contactId];
    final isLoadingThumbnail = _loadingThumbnails.contains(contactId);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: AppTheme.borderColor,
          width: 1,
        ),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.2),
          child: thumbnail != null
              ? ClipOval(
                  child: Image.memory(
                    thumbnail,
                    width: 40,
                    height: 40,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Text(
                        name.isNotEmpty ? name[0].toUpperCase() : '?',
                        style: TextStyle(
                          color: AppTheme.primaryColor,
                          fontWeight: FontWeight.bold,
                        ),
                      );
                    },
                  ),
                )
              : isLoadingThumbnail
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
                      ),
                    )
                  : Text(
                      name.isNotEmpty ? name[0].toUpperCase() : '?',
                      style: TextStyle(
                        color: AppTheme.primaryColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
        ),
        title: Text(
          name,
          style: const TextStyle(
            color: AppTheme.textPrimaryColor,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          primaryPhone,
          style: const TextStyle(
            color: AppTheme.textSecondaryColor,
            fontSize: 12,
          ),
        ),
        trailing: const Icon(
          Icons.arrow_forward_ios,
          size: 16,
          color: AppTheme.textSecondaryColor,
        ),
        onTap: () async {
          // Show dialog asking if new or existing customer
          await _showNewOrExistingDialog(contact, name, primaryPhone);
        },
      ),
    );
  }

  /// Show dialog asking if new or existing customer (for call log entries)
  Future<void> _showNewOrExistingDialogForCall(String phoneNumber, String name) async {
    if (!mounted) return;
    
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          'Customer Type',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimaryColor,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Selected: $name',
              style: const TextStyle(
                color: AppTheme.textSecondaryColor,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              phoneNumber,
              style: const TextStyle(
                color: AppTheme.textSecondaryColor,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Is this a new or existing customer?',
              style: TextStyle(
                color: AppTheme.textPrimaryColor,
                fontSize: 16,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop('new'),
            child: const Text(
              'New Customer',
              style: TextStyle(color: AppTheme.primaryColor),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop('existing'),
            child: const Text(
              'Existing Customer',
              style: TextStyle(color: AppTheme.primaryColor),
            ),
          ),
        ],
      ),
    );
    
    if (!mounted) return;
    
    if (result == 'new') {
      // Navigate to add new client form
      final validName = (name != 'Unknown' && name != phoneNumber && name.trim().isNotEmpty) 
          ? name 
          : null;
      
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => AndroidClientDetailPage(
            organizationId: widget.organizationId,
            initialName: validName,
            initialPhone: phoneNumber,
          ),
        ),
      ).then((result) {
        // Refresh client list if a new client was created
        if (result == true && mounted) {
          setState(() {
            _clientsLoaded = false;
          });
        }
      });
    } else if (result == 'existing') {
      // Show list of existing clients
      await _showExistingClientsDialog(null, phoneNumber);
    }
  }

  /// Show dialog asking if new or existing customer
  Future<void> _showNewOrExistingDialog(Contact contact, String name, String primaryPhone) async {
    if (!mounted) return;
    
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          'Customer Type',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimaryColor,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Selected: $name',
              style: const TextStyle(
                color: AppTheme.textSecondaryColor,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              primaryPhone,
              style: const TextStyle(
                color: AppTheme.textSecondaryColor,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Is this a new or existing customer?',
              style: TextStyle(
                color: AppTheme.textPrimaryColor,
                fontSize: 16,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop('new'),
            child: const Text(
              'New Customer',
              style: TextStyle(color: AppTheme.primaryColor),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop('existing'),
            child: const Text(
              'Existing Customer',
              style: TextStyle(color: AppTheme.primaryColor),
            ),
          ),
        ],
      ),
    );
    
    if (!mounted) return;
    
    if (result == 'new') {
      // Navigate to add new client form
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => AndroidClientDetailPage(
            organizationId: widget.organizationId,
            initialName: name,
            initialPhone: primaryPhone,
          ),
        ),
      ).then((result) {
        // Refresh client list if a new client was created
        if (result == true && mounted) {
          setState(() {
            _clientsLoaded = false;
          });
        }
      });
    } else if (result == 'existing') {
      // Show list of existing clients
      await _showExistingClientsDialog(contact, primaryPhone);
    }
  }

  /// Show dialog with list of existing clients for selection
  Future<void> _showExistingClientsDialog(Contact? contact, String phoneNumber) async {
    if (!mounted) return;
    
    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );
    
    try {
      // Load all clients
      final clients = await _clientRepository.getClients(widget.organizationId);
      
      if (!mounted) return;
      
      // Dismiss loading indicator
      Navigator.of(context).pop();
      
      if (clients.isEmpty) {
        // Show message if no clients found
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No existing clients found'),
            ),
          );
        }
        return;
      }
      
      // Show client selection dialog
      if (!mounted) return;
      
      final selectedClient = await showDialog<Client>(
        context: context,
        builder: (context) => Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Container(
            constraints: const BoxConstraints(maxHeight: 500),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: AppTheme.borderColor,
                        width: 1,
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Select Existing Customer',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 18,
                            color: AppTheme.textPrimaryColor,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.close,
                          color: AppTheme.textSecondaryColor,
                        ),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                ),
                // Clients list
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: clients.length,
                    itemBuilder: (context, index) {
                      final client = clients[index];
                      return Container(
                        decoration: BoxDecoration(
                          border: Border(
                            bottom: BorderSide(
                              color: AppTheme.borderColor.withValues(alpha: 0.5),
                              width: 0.5,
                            ),
                          ),
                        ),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.2),
                            child: Text(
                              client.name.isNotEmpty ? client.name[0].toUpperCase() : '?',
                              style: TextStyle(
                                color: AppTheme.primaryColor,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          title: Text(
                            client.name,
                            style: const TextStyle(
                              color: AppTheme.textPrimaryColor,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          subtitle: Text(
                            client.phoneNumber,
                            style: const TextStyle(
                              color: AppTheme.textSecondaryColor,
                              fontSize: 12,
                            ),
                          ),
                          trailing: const Icon(
                            Icons.arrow_forward_ios,
                            size: 16,
                            color: AppTheme.textSecondaryColor,
                          ),
                          onTap: () => Navigator.of(context).pop(client),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      
      if (!mounted || selectedClient == null) return;
      
      // Add phone number to selected client's phoneList
      await _addPhoneToClient(selectedClient, phoneNumber);
    } catch (e) {
      if (!mounted) return;
      
      // Dismiss loading indicator if still showing
      Navigator.of(context).pop();
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading clients: $e'),
        ),
      );
    }
  }

  /// Add phone number to client's phoneList
  Future<void> _addPhoneToClient(Client client, String phoneNumber) async {
    if (!mounted) return;
    
    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );
    
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid ?? '';
      await _clientRepository.addPhoneToClient(
        widget.organizationId,
        client.clientId,
        phoneNumber,
        userId,
      );
      
      if (!mounted) return;
      
      // Dismiss loading indicator
      Navigator.of(context).pop();
      
      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Phone number added to ${client.name}'),
          backgroundColor: Colors.green,
        ),
      );
      
      // Refresh client list
      setState(() {
        _clientsLoaded = false;
      });
    } catch (e) {
      if (!mounted) return;
      
      // Dismiss loading indicator
      Navigator.of(context).pop();
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error adding phone number: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  String _formatDuration(int seconds) {
    if (seconds < 60) {
      return '${seconds}s';
    } else if (seconds < 3600) {
      final minutes = seconds ~/ 60;
      final remainingSeconds = seconds % 60;
      return '${minutes}m ${remainingSeconds}s';
    } else {
      final hours = seconds ~/ 3600;
      final minutes = (seconds % 3600) ~/ 60;
      return '${hours}h ${minutes}m';
    }
  }
}

Map<String, dynamic> _buildSearchIndex(List<dynamic> contactsPayload) {
  final Map<String, String> names = {};
  final Map<String, List<String>> phones = {};
  final digitPattern = RegExp(r'[^\d]');

  for (final entry in contactsPayload) {
    final map = Map<String, dynamic>.from(entry as Map);
    final id = map['id'] as String? ?? '';
    final name = (map['name'] as String? ?? '').toLowerCase();
    final phoneValues = (map['phones'] as List<dynamic>? ?? const [])
        .map((phone) => phone.toString().replaceAll(digitPattern, ''))
        .where((digits) => digits.isNotEmpty)
        .toList(growable: false);

    names[id] = name;
    phones[id] = phoneValues;
  }

  return {
    'names': names,
    'phones': phones,
  };
}
