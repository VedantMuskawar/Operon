import 'dart:async';
import 'dart:io';

import 'package:call_log/call_log.dart' as device_log;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_contacts/flutter_contacts.dart' as device_contacts;
import 'package:permission_handler/permission_handler.dart';
import 'package:dash_mobile/data/services/client_service.dart';
import 'package:dash_mobile/presentation/blocs/org_context/org_context_cubit.dart';
import 'package:dash_mobile/presentation/utils/network_error_helper.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:go_router/go_router.dart';
import 'package:core_ui/core_ui.dart';

class ContactPage extends StatefulWidget {
  const ContactPage({super.key});

  @override
  State<ContactPage> createState() => _ContactPageState();
}

class _ContactPageState extends State<ContactPage> {
  static const int _contactBatchSize = 20; // Reduced for faster initial load
  static const int _initialDisplayCount = 20; // Show fewer initially

  bool _isCallLogLoading = true;
  bool _isContactsLoading = false; // Start as false to allow initial load
  bool _hasContactsPermission = false;
  String? _callLogMessage;
  String? _contactsMessage;

  List<_CallLogEntry> _entries = const [];
  final List<_ContactEntry> _allContacts = [];
  List<_ContactEntry> _filteredContacts = [];
  final List<_ContactEntry> _recentContacts = [];
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _contactListController = ScrollController();
  late final PageController _pageController;
  double _currentPage = 0;
  Timer? _searchDebounce;
  final ClientService _clientService = ClientService();
  bool _isLoadingMoreContacts = false;
  int _visibleContactLimit = _contactBatchSize;
  final Map<String, List<_ContactEntry>> _searchCache = {};

  static const List<String> _clientTags = [
    'Individual',
    'Corporate',
    'Vendor',
    'Distributor',
    'Priority',
  ];
  static const int _clientFetchLimit = 100;

  @override
  void initState() {
    super.initState();
    _loadCallLogs();
    _loadContacts();
    _searchController.addListener(_onSearchChanged);
    _pageController = PageController()
      ..addListener(_onPageChanged);
    _contactListController.addListener(_handleContactListScroll);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _pageController.removeListener(_onPageChanged);
    _pageController.dispose();
    _contactListController.removeListener(_handleContactListScroll);
    _contactListController.dispose();
    _searchDebounce?.cancel();
    super.dispose();
  }

  Future<void> _loadCallLogs() async {
    if (!Platform.isAndroid) {
      setState(() {
        _callLogMessage = 'Call logs are only available on Android devices.';
        _isCallLogLoading = false;
      });
      return;
    }

    final status = await Permission.phone.request();
    if (!status.isGranted) {
      setState(() {
        _callLogMessage = 'Phone permission is required to read call logs.';
        _isCallLogLoading = false;
      });
      return;
    }

    try {
      final now = DateTime.now();
      final twoDaysAgo = now.subtract(const Duration(days: 2));
      final rawLogs = await device_log.CallLog.query(
        dateFrom: twoDaysAgo.millisecondsSinceEpoch,
        dateTo: now.millisecondsSinceEpoch,
      );

      final entries = <_CallLogEntry>[];
      for (final log in rawLogs) {
        final timestampMs = log.timestamp;
        if (timestampMs == null) continue;
        final timestamp = DateTime.fromMillisecondsSinceEpoch(timestampMs);
        if (timestamp.isBefore(twoDaysAgo)) continue;

        entries.add(
          _CallLogEntry(
            contactName: log.name ?? 'Unknown',
            phoneNumber: log.number ?? '-',
            timestamp: timestamp,
            duration: Duration(seconds: log.duration ?? 0),
            isOutgoing: log.callType == device_log.CallType.outgoing,
          ),
        );
      }

      setState(() {
        _entries = entries;
        _callLogMessage =
            entries.isEmpty ? 'No call logs recorded for today or yesterday.' : null;
        _isCallLogLoading = false;
      });
    } catch (error) {
      setState(() {
        _callLogMessage = 'Unable to read call logs: $error';
        _isCallLogLoading = false;
      });
    }
  }

  Future<void> _loadContacts() async {
    // Prevent concurrent loads
    if (_isContactsLoading) {
      debugPrint('Contact loading already in progress, skipping...');
      return;
    }

    debugPrint('Starting contact load...');

    // Reset state
    _visibleContactLimit = _contactBatchSize;
    _isLoadingMoreContacts = false;

    if (!mounted) return;

    setState(() {
      _filteredContacts = [];
      _isContactsLoading = true;
      _contactsMessage = null;
    });

    if (!Platform.isAndroid) {
      if (!mounted) return;
      setState(() {
        _contactsMessage = 'Phone contacts are only available on Android devices.';
        _isContactsLoading = false;
      });
      return;
    }

    try {
      // Check permission with better error handling
      debugPrint('Requesting contacts permission...');
      final hasPermission = await device_contacts.FlutterContacts.requestPermission(
        readonly: true,
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          debugPrint('Permission request timed out');
          return false;
        },
      );
      
      debugPrint('Permission result: $hasPermission');
      
      if (!mounted) return;
      
      if (!hasPermission) {
        debugPrint('Permission denied, showing error message');
        if (!mounted) return;
        setState(() {
          _hasContactsPermission = hasPermission;
          _contactsMessage = 'Contacts permission denied. Enable it in settings.';
          _isContactsLoading = false;
        });
        return;
      }
      
      // Batch permission state update
      setState(() {
        _hasContactsPermission = hasPermission;
      });

      // Load contacts with timeout and error handling
      debugPrint('Loading contacts from device...');
      final contacts = await device_contacts.FlutterContacts.getContacts(
        withProperties: true, // Required to get phone numbers
        withPhoto: false, // Photos not needed - saves memory
        sorted: false, // Sort in isolate instead to avoid blocking
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          debugPrint('Contact loading timed out after 30 seconds');
          throw TimeoutException('Contact loading timed out after 30 seconds');
        },
      );
      
      debugPrint('Loaded ${contacts.length} raw contacts from device');
      
      if (!mounted) return;

      // Process contacts in background isolate with error handling
      debugPrint('Processing contacts in isolate...');
      final entries = await compute(_processContactsInBackground, contacts)
          .timeout(
            const Duration(seconds: 15),
            onTimeout: () {
              debugPrint('Contact processing timed out');
              return <_ContactEntry>[];
            },
          );

      debugPrint('Processed ${entries.length} valid contacts');

      if (!mounted) return;

      // Update state with processed contacts
      debugPrint('Updating UI with ${entries.length} contacts');
      
      // Optimize: Show minimal initial batch for fastest first render
      final initialLimit = entries.length < _initialDisplayCount
          ? entries.length
          : _initialDisplayCount;
      
      if (!mounted) return;
      
      // Update state immediately with small batch
      setState(() {
        _allContacts.clear();
        _allContacts.addAll(entries);
        
        _filteredContacts = entries.take(initialLimit).toList();
        _visibleContactLimit = initialLimit;
        
        _contactsMessage = entries.isEmpty
            ? 'No phone contacts found on this device.'
            : null;
        _isContactsLoading = false;
      });
      
      // Load more contacts after first frame for smoother experience
      if (entries.length > initialLimit && !_isSearchActive) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && !_isSearchActive) {
            setState(() {
              final nextLimit = entries.length < _contactBatchSize * 2
                  ? entries.length
                  : _contactBatchSize * 2;
              _filteredContacts = entries.take(nextLimit).toList();
              _visibleContactLimit = nextLimit;
            });
          }
        });
      }
      
      debugPrint('Contact loading completed successfully');
    } catch (error) {
      if (!mounted) return;
      
      // Better error messages
      String errorMessage;
      if (error is TimeoutException) {
        errorMessage = 'Loading contacts took too long. Please try again.';
      } else if (error is PlatformException) {
        errorMessage = 'Unable to access contacts. Please check permissions.';
      } else if (NetworkErrorHelper.isNetworkError(error)) {
        errorMessage = NetworkErrorHelper.getNetworkErrorMessage(error);
      } else {
        errorMessage = 'Unable to read contacts: ${error.toString()}';
      }
      
      debugPrint('Error loading contacts: $error');
      
      setState(() {
        _contactsMessage = errorMessage;
        _isContactsLoading = false;
        // Don't clear contacts on error - keep what we have
      });
    }
  }

  // Helper function to process contacts in background isolate
  // Optimized with better error handling and validation
  static List<_ContactEntry> _processContactsInBackground(
      List<device_contacts.Contact> contacts) {
    if (contacts.isEmpty) return <_ContactEntry>[];
    
    final entries = <_ContactEntry>[];
    
    for (final contact in contacts) {
      try {
        // Skip contacts without phone numbers
        if (contact.phones.isEmpty) continue;

        // Extract and validate phone numbers
        final displayPhones = contact.phones
            .map((phone) => phone.number.trim())
            .where((number) => number.isNotEmpty)
            .toList();
            
        if (displayPhones.isEmpty) continue;

        // Normalize phone numbers (digits only for matching)
        final normalizedPhones = displayPhones
            .map((number) => number.replaceAll(RegExp(r'[^0-9+]'), ''))
            .where((number) => number.isNotEmpty && number.length >= 3) // Minimum 3 digits
            .toList();
            
        if (normalizedPhones.isEmpty) continue;

        // Get contact name or use phone as fallback
        final name = (contact.displayName.trim().isNotEmpty
                ? contact.displayName.trim()
                : displayPhones.first)
            .trim();
            
        // Skip if name is still empty
        if (name.isEmpty) continue;

        // Create contact entry
        entries.add(
          _ContactEntry(
            id: contact.id.isNotEmpty ? contact.id : 'unknown_${entries.length}',
            name: name,
            normalizedName: name.toLowerCase(),
            displayPhones: displayPhones,
            normalizedPhones: normalizedPhones,
          ),
        );
      } catch (e) {
        // Skip invalid contacts silently
        continue;
      }
    }
    
    return entries;
  }

  void _onSearchChanged() {
    final query = _searchController.text;
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 250), () {
      _performContactSearch(query);
    });
  }

  Future<void> _performContactSearch(String rawQuery) async {
    if (!mounted) return;
    
    final query = rawQuery.trim();
    
    // Handle empty query - reset to paginated list
    if (query.isEmpty) {
      final limit = _allContacts.length < _visibleContactLimit
          ? _allContacts.length
          : _visibleContactLimit;
      
      if (!mounted) return;
      
      setState(() {
        _filteredContacts = _allContacts.take(limit).toList();
        // Only show permission message if permission is not granted
        if (_allContacts.isEmpty) {
          _contactsMessage = _hasContactsPermission
              ? null // Permission granted, no message needed
              : 'Contacts permission is required. Please grant permission to view contacts.';
        } else {
          _contactsMessage = null;
        }
      });
      return;
    }

    try {
      // Normalize query for matching
      final normalized = query.toLowerCase().trim();
      final digitsQuery = normalized.replaceAll(RegExp(r'[^0-9+]'), '');
      
      // Check cache first
      final cacheKey = normalized;
      if (_searchCache.containsKey(cacheKey)) {
        if (!mounted) return;
        setState(() {
          _filteredContacts = _searchCache[cacheKey]!;
          _contactsMessage = _filteredContacts.isEmpty
              ? 'No contacts matched "$query".'
              : null;
        });
        return;
      }
      
      // Optimize: Use isolate for very large lists, direct search for smaller ones
      List<_ContactEntry> results;
      
      // Lower threshold for isolate - use for lists >500 contacts
      if (_allContacts.length > 500) {
        // Large list - use isolate to avoid blocking UI
        results = await compute(
          _searchContactsInBackground,
          _SearchContactsParams(
            contacts: _allContacts,
            normalizedQuery: normalized,
            digitsQuery: digitsQuery,
            maxResults: 100, // Increased limit for better UX
          ),
        ).timeout(
          const Duration(seconds: 3), // Reduced timeout for faster feedback
          onTimeout: () {
            debugPrint('Search timed out');
            return <_ContactEntry>[];
          },
        );
      } else {
        // Small list - direct search is faster (no isolate overhead)
        results = <_ContactEntry>[];
        const maxResults = 100; // Increased for better UX
        
        for (final contact in _allContacts) {
          if (results.length >= maxResults) break;
          
          // Name matching (case-insensitive contains)
          final nameMatch = contact.normalizedName.contains(normalized);
          
          // Phone matching (digits only)
          final phoneMatch = digitsQuery.isNotEmpty &&
              contact.normalizedPhones.any(
                  (phone) => phone.contains(digitsQuery));
          
          if (nameMatch || phoneMatch) {
            results.add(contact);
          }
        }
      }

      if (!mounted) return;

      // Cache results
      _searchCache[cacheKey] = results;
      // Limit cache size to prevent memory issues
      if (_searchCache.length > 50) {
        final firstKey = _searchCache.keys.first;
        _searchCache.remove(firstKey);
      }

      setState(() {
        _filteredContacts = results;
        _contactsMessage = results.isEmpty
            ? 'No contacts matched "$query".'
            : null;
      });
    } catch (error) {
      if (!mounted) return;
      
      debugPrint('Error searching contacts: $error');
      setState(() {
        // On error, show current filtered list or empty
        _contactsMessage = 'Search error occurred. Please try again.';
      });
    }
  }

  bool get _isSearchActive => _searchController.text.trim().isNotEmpty;

  void _onPageChanged() {
    if (!_pageController.hasClients) return;
    final newPage = _pageController.page ?? 0;
    final roundedPage = newPage.round();
    if (roundedPage != _currentPage.round()) {
      setState(() {
        _currentPage = newPage;
      });
    }
  }

  void _handleContactListScroll() {
    if (_isSearchActive) return;
    if (!_contactListController.hasClients) return;

    final position = _contactListController.position;
    if (position.pixels >= position.maxScrollExtent - 120) {
      _loadMoreVisibleContacts();
    }
  }

  Future<void> _loadMoreVisibleContacts() async {
    // Prevent concurrent loads or loading during search
    if (_isSearchActive || _isLoadingMoreContacts || _isContactsLoading) return;
    
    final hasMoreLocal = _filteredContacts.length < _allContacts.length;
    if (!hasMoreLocal) return;

    if (!mounted) return;

    setState(() {
      _isLoadingMoreContacts = true;
      _visibleContactLimit += _contactBatchSize;
    });

    // Small delay to allow UI to update
    await Future.delayed(const Duration(milliseconds: 50));

    if (!mounted) return;

    final available = _allContacts.length;
    final target =
        available < _visibleContactLimit ? available : _visibleContactLimit;

    if (target > _filteredContacts.length) {
      setState(() {
        _filteredContacts = _allContacts.take(target).toList();
        _isLoadingMoreContacts = false;
      });
    } else {
      setState(() {
        _isLoadingMoreContacts = false;
      });
    }
  }

  Future<void> _handleContactTap(_ContactEntry entry) async {
    final existingClient = await _findExistingClient(entry);
    if (existingClient != null) {
      final action = await _showDuplicateClientSheet(existingClient);
      if (action == _ExistingClientAction.viewExisting && mounted) {
        context.pushNamed('client-detail', extra: existingClient);
      }
      return;
    }

    final action = await _showContactActionSheet();
    if (action == null) return;

    if (action == _ContactAction.newClient) {
      final saved = await _showClientFormSheet(entry);
      if (saved == true && mounted) {
        _recordRecentContact(entry);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Client "${entry.name}" saved'),
          ),
        );
      }
      return;
    }

    final selectedClient = await _showExistingClientPicker();
    if (selectedClient == null) return;

    final success = await _showAddContactToClientSheet(
      entry: entry,
      client: selectedClient,
    );

    if (success == true && mounted) {
      _recordRecentContact(entry);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text('Added contact to ${selectedClient.name}.'),
        ),
      );
    }
  }

  void _recordRecentContact(_ContactEntry entry) {
    setState(() {
      _recentContacts.removeWhere((existing) => existing.id == entry.id);
      _recentContacts.insert(0, entry);
      if (_recentContacts.length > 5) {
        _recentContacts.removeLast();
      }
    });
  }

  Future<ClientRecord?> _findExistingClient(_ContactEntry entry) async {
    // Optimize: Check all phones in parallel instead of sequentially
    final futures = entry.displayPhones
        .map((phone) => _clientService.findClientByPhone(phone))
        .toList();
    
    try {
      final results = await Future.wait(futures);
      for (final result in results) {
        if (result != null) {
          return result;
        }
      }
    } catch (error) {
      debugPrint('Error finding existing client: $error');
    }
    
    return null;
  }

  Future<_ContactAction?> _showContactActionSheet() {
    return showDialog<_ContactAction>(
      context: context,
      builder: (context) => const _ContactActionSheet(),
    );
  }

  Future<_ExistingClientAction?> _showDuplicateClientSheet(
    ClientRecord existing,
  ) {
    return showDialog<_ExistingClientAction>(
      context: context,
      builder: (context) => _DuplicateClientSheet(client: existing),
    );
  }

  Future<ClientRecord?> _showExistingClientPicker() {
    return showDialog<ClientRecord>(
      context: context,
      builder: (context) => _ExistingClientPickerSheet(
        loadClients: () => _clientService.fetchClients(
          limit: _clientFetchLimit,
        ),
      ),
    );
  }

  Future<bool?> _showAddContactToClientSheet({
    required _ContactEntry entry,
    required ClientRecord client,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (context) => _AddContactToClientSheet(
        entry: entry,
        client: client,
        onSubmit: (name, phone, description) async {
          await _clientService.addContactToExistingClient(
            clientId: client.id,
            contactName: name,
            phoneNumber: phone,
            description: description,
          );
        },
      ),
    );
  }

  Future<void> _handleCallLogTap(_CallLogEntry entry) async {
    final phone = entry.phoneNumber.trim();
    if (phone.isEmpty || phone == '-') {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('This call log does not include a valid phone number.'),
        ),
      );
      return;
    }

    final contactName = entry.contactName.trim().isEmpty ||
            entry.contactName.toLowerCase() == 'unknown'
        ? phone
        : entry.contactName.trim();

    final contactEntry = _ContactEntry(
      id: 'call_${entry.timestamp.millisecondsSinceEpoch}_$phone',
      name: contactName,
      normalizedName: contactName.toLowerCase(),
      displayPhones: [phone],
      normalizedPhones: [
        phone.replaceAll(RegExp(r'[^0-9+]'), ''),
      ],
    );

    await _handleContactTap(contactEntry);
  }

  @override
  Widget build(BuildContext context) {
    final grouped = _groupByDay(_entries);
    final hasMoreContacts =
        !_isSearchActive && _filteredContacts.length < _allContacts.length;

    return Scaffold(
      backgroundColor: AuthColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Container(
              color: AuthColors.primary,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close, color: AuthColors.textMain),
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Contact',
                      style: TextStyle(
                        color: AuthColors.textMain,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
            ),
            Expanded(
              child: Column(
                children: [
                  Expanded(
                    child: PageView(
                      controller: _pageController,
                      physics: const ClampingScrollPhysics(),
                      allowImplicitScrolling: false,
                      children: [
                        SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
                          physics: const ClampingScrollPhysics(),
                          child: _CallLogsCard(
                            isLoading: _isCallLogLoading,
                            message: _callLogMessage,
                            groupedEntries: grouped,
                            onCallTap: _handleCallLogTap,
                          ),
                        ),
                        RefreshIndicator(
                          onRefresh: _loadContacts,
                          color: AuthColors.legacyAccent,
                          child: SingleChildScrollView(
                            controller: _contactListController,
                            padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
                            physics: const ClampingScrollPhysics(),
                            child: _ContactSearchCard(
                              controller: _searchController,
                              isLoading:
                                  _isContactsLoading && _filteredContacts.isEmpty,
                              message: _contactsMessage,
                              filteredContacts: _filteredContacts,
                              recentContacts: _recentContacts,
                              onContactTap: _handleContactTap,
                              isLoadingMore: _isLoadingMoreContacts,
                              hasMore: hasMoreContacts,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  _PageIndicator(pageCount: 2, currentIndex: _currentPage),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Map<String, List<_CallLogEntry>> _groupByDay(List<_CallLogEntry> entries) {
    final today = DateTime.now();
    final yesterday = today.subtract(const Duration(days: 1));
    final Map<String, List<_CallLogEntry>> grouped = {};

    for (final entry in entries) {
      final date =
          DateTime(entry.timestamp.year, entry.timestamp.month, entry.timestamp.day);
      String? label;
      if (_isSameDay(date, today)) {
        label = 'Today';
      } else if (_isSameDay(date, yesterday)) {
        label = 'Yesterday';
      }
      if (label == null) continue;
      grouped.putIfAbsent(label, () => []).add(entry);
    }
    return grouped;
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }


  Future<bool?> _showClientFormSheet(_ContactEntry entry) {
    final orgContext = context.read<OrganizationContextCubit>().state;
    final organizationId = orgContext.organization?.id;

    return showDialog<bool>(
      context: context,
      builder: (context) {
        return _ClientFormSheet(
          entry: entry,
          availableTags: _clientTags,
          onSubmit: (name, phone, tag) async {
            final checkedNumbers = <String>{};
            for (final number in entry.displayPhones) {
              if (number.isEmpty || !checkedNumbers.add(number)) continue;
              final duplicate =
                  await _clientService.findClientByPhone(number);
              if (duplicate != null) {
                throw _DuplicateClientException(
                  'Client "${duplicate.name}" already exists with $number.',
                );
              }
            }
            await _clientService.createClient(
              name: name,
              primaryPhone: phone,
              phones: entry.displayPhones.contains(phone)
                  ? entry.displayPhones
                  : [...entry.displayPhones, phone],
              tags: [tag],
              organizationId: organizationId,
            );
          },
        );
      },
    );
  }
}

class _CallLogSection extends StatelessWidget {
  const _CallLogSection({
    required this.title,
    required this.entries,
    required this.onTap,
  });

  final String title;
  final List<_CallLogEntry> entries;
  final ValueChanged<_CallLogEntry> onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: AuthColors.textSub,
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 8),
        ...entries.map(
          (entry) => _CallLogTile(
            entry: entry,
            onTap: () => onTap(entry),
          ),
        ),
      ],
    );
  }
}

class _CallLogTile extends StatelessWidget {
  const _CallLogTile({
    required this.entry,
    required this.onTap,
  });

  final _CallLogEntry entry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: AuthColors.surface,
                child: Text(
                  entry.contactName.isNotEmpty 
                      ? entry.contactName[0].toUpperCase() 
                      : '?',
                  style: const TextStyle(
                    color: AuthColors.textMain,
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      entry.contactName,
                      style: const TextStyle(
                        color: AuthColors.textMain,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      entry.phoneNumber,
                      style: const TextStyle(
                        color: AuthColors.textSub,
                        fontSize: 13,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: AuthColors.textMainWithOpacity(0.3),
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({this.message});

  final String? message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              color: AuthColors.textMainWithOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const SizedBox(
              width: 60,
              height: 60,
              child: Icon(Icons.call_end, color: AuthColors.textDisabled),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            message ?? 'No call logs available.',
            style: TextStyle(color: AuthColors.textMainWithOpacity(0.6)),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _CallLogEntry {
  const _CallLogEntry({
    required this.contactName,
    required this.phoneNumber,
    required this.timestamp,
    required this.duration,
    required this.isOutgoing,
  });

  final String contactName;
  final String phoneNumber;
  final DateTime timestamp;
  final Duration duration;
  final bool isOutgoing;
}

// Helper class for search parameters
class _SearchContactsParams {
  const _SearchContactsParams({
    required this.contacts,
    required this.normalizedQuery,
    required this.digitsQuery,
    required this.maxResults,
  });

  final List<_ContactEntry> contacts;
  final String normalizedQuery;
  final String digitsQuery;
  final int maxResults;
}

// Helper function to search contacts in background
List<_ContactEntry> _searchContactsInBackground(_SearchContactsParams params) {
  final results = <_ContactEntry>[];
  final maxResults = params.maxResults;
  
  for (final contact in params.contacts) {
    if (results.length >= maxResults) break;
    
    final nameMatch = contact.normalizedName.contains(params.normalizedQuery);
    final phoneMatch = params.digitsQuery.isNotEmpty &&
        contact.normalizedPhones.any(
            (phone) => phone.contains(params.digitsQuery));
    
    if (nameMatch || phoneMatch) {
      results.add(contact);
    }
  }
  
  return results;
}

class _ContactEntry {
  const _ContactEntry({
    required this.id,
    required this.name,
    required this.normalizedName,
    required this.displayPhones,
    required this.normalizedPhones,
  });

  final String id;
  final String name;
  final String normalizedName;
  final List<String> displayPhones;
  final List<String> normalizedPhones;

  String get primaryDisplayPhone =>
      displayPhones.isNotEmpty ? displayPhones.first : '-';
}


class _ContactListTile extends StatelessWidget {
  const _ContactListTile({
    super.key,
    required this.contact,
    required this.onTap,
  });

  final _ContactEntry contact;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // Optimize: Use const where possible, avoid unnecessary rebuilds
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              // Optimized CircleAvatar with const text
              CircleAvatar(
                radius: 22,
                backgroundColor: AuthColors.surface,
                child: Text(
                  contact.name.isNotEmpty 
                      ? contact.name[0].toUpperCase() 
                      : '?',
                  style: const TextStyle(
                    color: AuthColors.textMain,
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      contact.name,
                      style: const TextStyle(
                        color: AuthColors.textMain,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      contact.primaryDisplayPhone,
                      style: const TextStyle(
                        color: AuthColors.textSub,
                        fontSize: 13,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: AuthColors.textMainWithOpacity(0.3),
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

enum _ContactAction { newClient, existing }

enum _ExistingClientAction { viewExisting, cancel }

class _PageIndicator extends StatelessWidget {
  const _PageIndicator({
    required this.pageCount,
    required this.currentIndex,
  });

  final int pageCount;
  final double currentIndex;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(
        pageCount,
        (index) {
          final isActive = currentIndex.round() == index;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.symmetric(horizontal: 4),
            width: isActive ? 18 : 8,
            height: 8,
            decoration: BoxDecoration(
              color: isActive ? AuthColors.legacyAccent : AuthColors.textMainWithOpacity(0.3),
              borderRadius: BorderRadius.circular(999),
            ),
          );
        },
      ),
    );
  }
}

class _ContactSearchCard extends StatelessWidget {
  const _ContactSearchCard({
    required this.controller,
    required this.isLoading,
    required this.message,
    required this.filteredContacts,
    required this.recentContacts,
    required this.onContactTap,
    required this.isLoadingMore,
    required this.hasMore,
  });

  final TextEditingController controller;
  final bool isLoading;
  final String? message;
  final List<_ContactEntry> filteredContacts;
  final List<_ContactEntry> recentContacts;
  final ValueChanged<_ContactEntry> onContactTap;
  final bool isLoadingMore;
  final bool hasMore;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Search Contacts',
            style: TextStyle(
              color: AuthColors.textMain,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Search through your phone contacts to quickly reach the right person.',
            style: TextStyle(
              color: AuthColors.textMainWithOpacity(0.6),
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: controller,
            style: const TextStyle(color: AuthColors.textMain, fontSize: 15),
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search, color: AuthColors.textSub, size: 20),
              hintText: 'Search contacts',
              hintStyle: const TextStyle(color: AuthColors.textDisabled, fontSize: 14),
              filled: true,
              fillColor: AuthColors.backgroundAlt,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(
                  color: AuthColors.legacyAccent,
                  width: 2,
                ),
              ),
            ),
            textInputAction: TextInputAction.search,
          ),
          const SizedBox(height: 16),
          if (isLoading)
            const Center(child: CircularProgressIndicator())
          else ...[
            if (message != null) ...[
              const SizedBox(height: 8),
              Text(
                message!,
                style: const TextStyle(color: AuthColors.textSub, fontSize: 12),
              ),
            ] else ...[
              if (recentContacts.isNotEmpty) ...[
                const Text(
                  'Recently searched',
                  style: TextStyle(
                    color: AuthColors.textSub,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 40,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemBuilder: (context, index) {
                      final contact = recentContacts[index];
                      return ActionChip(
                        label: Text(contact.name),
                        labelStyle: const TextStyle(color: AuthColors.textMain),
                        backgroundColor: AuthColors.surface,
                        onPressed: () => onContactTap(contact),
                      );
                    },
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemCount: recentContacts.length,
                  ),
                ),
                const SizedBox(height: 16),
              ],
              if (filteredContacts.isEmpty)
                const Text(
                  'No contacts match your search.',
                  style: TextStyle(color: AuthColors.textSub, fontSize: 12),
                )
              else
                AnimationLimiter(
                  child: ListView.builder(
                    addAutomaticKeepAlives: false,
                    itemCount: filteredContacts.length + (isLoadingMore ? 1 : 0) + (hasMore && !isLoadingMore ? 1 : 0),
                    itemExtent: 72,
                    itemBuilder: (context, index) {
                      if (index < filteredContacts.length) {
                        final contact = filteredContacts[index];
                        return AnimationConfiguration.staggeredList(
                          position: index,
                          duration: const Duration(milliseconds: 200),
                          child: SlideAnimation(
                            verticalOffset: 50.0,
                            child: FadeInAnimation(
                              curve: Curves.easeOut,
                              child: _ContactListTile(
                                key: ValueKey(contact.id),
                                contact: contact,
                                onTap: () => onContactTap(contact),
                              ),
                            ),
                          ),
                        );
                      }
                        
                        if (index == filteredContacts.length && isLoadingMore) {
                          return const Padding(
                            padding: EdgeInsets.symmetric(vertical: 16),
                            child: Center(
                              child: SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                            ),
                          );
                        }
                        
                        if (index == filteredContacts.length + (isLoadingMore ? 1 : 0) && hasMore) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 12, bottom: 16),
                            child: Text(
                              'Scroll to load more contacts…',
                              style: TextStyle(
                                color: AuthColors.textMainWithOpacity(0.6),
                                fontSize: 12,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          );
                        }
                        
                        return const SizedBox.shrink();
                      },
                    ),
                  ),
            ],
          ],
        ],
      ),
    );
  }
}

class _CallLogsCard extends StatelessWidget {
  const _CallLogsCard({
    required this.isLoading,
    required this.message,
    required this.groupedEntries,
    required this.onCallTap,
  });

  final bool isLoading;
  final String? message;
  final Map<String, List<_CallLogEntry>> groupedEntries;
  final ValueChanged<_CallLogEntry> onCallTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Center(
                child: CircularProgressIndicator(
                  color: AuthColors.legacyAccent,
                ),
              ),
            )
          else if (groupedEntries.isEmpty)
            _EmptyState(message: message)
          else
            Column(
              mainAxisSize: MainAxisSize.min,
              children: groupedEntries.entries
                  .map(
                    (entry) => Padding(
                      key: ValueKey(entry.key),
                      padding: const EdgeInsets.only(bottom: 16),
                      child: _CallLogSection(
                        title: entry.key,
                        entries: entry.value,
                        onTap: onCallTap,
                      ),
                    ),
                  )
                  .toList(),
            ),
        ],
      ),
    );
  }
}

class _ContactActionSheet extends StatelessWidget {
  const _ContactActionSheet();

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: 400,
          maxHeight: MediaQuery.of(context).size.height * 0.8,
        ),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AuthColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AuthColors.textMainWithOpacity(0.1)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'What would you like to do?',
                    style: TextStyle(
                      color: AuthColors.textMain,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close, color: AuthColors.textSub),
                ),
              ],
            ),
            const SizedBox(height: 4),
            const Text(
              'Create a new client or attach this contact to an existing one.',
              style: TextStyle(
                color: AuthColors.textSub,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 20),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AuthColors.legacyAccent.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(Icons.person_add_alt, color: AuthColors.legacyAccent.withOpacity(0.8)),
              ),
              title: const Text(
                'New Client',
                style: TextStyle(color: AuthColors.textMain, fontWeight: FontWeight.w600),
              ),
              subtitle: const Text(
                'Create a standalone client profile',
                style: TextStyle(color: AuthColors.textSub),
              ),
              onTap: () => Navigator.of(context).pop(_ContactAction.newClient),
            ),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AuthColors.successVariant.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.group_add, color: AuthColors.successVariant),
              ),
              title: const Text(
                'Add Contact to Existing Client',
                style: TextStyle(color: AuthColors.textMain, fontWeight: FontWeight.w600),
              ),
              subtitle: const Text(
                'Attach this contact under another client',
                style: TextStyle(color: AuthColors.textSub),
              ),
              onTap: () => Navigator.of(context).pop(_ContactAction.existing),
            ),
          ],
        ),
      ),
    );
  }
}

class _ExistingClientPickerSheet extends StatefulWidget {
  const _ExistingClientPickerSheet({required this.loadClients});

  final Future<List<ClientRecord>> Function() loadClients;

  @override
  State<_ExistingClientPickerSheet> createState() =>
      _ExistingClientPickerSheetState();
}

class _ExistingClientPickerSheetState
    extends State<_ExistingClientPickerSheet> {
  final TextEditingController _searchController = TextEditingController();
  List<ClientRecord> _clients = const <ClientRecord>[];
  List<ClientRecord> _filtered = const <ClientRecord>[];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final clients = await widget.loadClients();
      if (!mounted) return;
      setState(() {
        _clients = clients;
        _filtered = clients;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = 'Unable to load clients: $error';
        _isLoading = false;
      });
    }
  }

  void _onSearchChanged() {
    final query = _searchController.text.trim().toLowerCase();
    final digitsQuery = query.replaceAll(RegExp(r'[^0-9+]'), '');
    setState(() {
      if (query.isEmpty) {
        _filtered = _clients;
      } else {
        _filtered = _clients.where((client) {
          final nameMatch = client.name.toLowerCase().contains(query);
          final phoneMatch = digitsQuery.isNotEmpty &&
              client.phoneIndex.any((phone) => phone.contains(digitsQuery));
          return nameMatch || phoneMatch;
        }).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: 400,
          maxHeight: MediaQuery.of(context).size.height * 0.8,
        ),
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        ),
        decoration: BoxDecoration(
          color: AuthColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AuthColors.textMainWithOpacity(0.1)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Select Existing Client',
                    style: TextStyle(
                      color: AuthColors.textMain,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close, color: AuthColors.textSub),
                ),
              ],
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _searchController,
              style: const TextStyle(color: AuthColors.textMain),
              decoration: InputDecoration(
                hintText: 'Search by name or phone number',
                hintStyle: const TextStyle(color: AuthColors.textSub),
                prefixIcon: const Icon(Icons.search, color: AuthColors.textSub),
                filled: true,
                fillColor: AuthColors.backgroundAlt,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: CircularProgressIndicator(),
              )
            else if (_error != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 32),
                child: Text(
                  _error!,
                  style: const TextStyle(color: AuthColors.error),
                  textAlign: TextAlign.center,
                ),
              )
            else if (_filtered.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: Text(
                  'No clients match your search.',
                  style: TextStyle(color: AuthColors.textSub),
                ),
              )
            else
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: _filtered.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final client = _filtered[index];
                    final tagSummary = client.tags.isEmpty
                        ? 'No tags'
                        : client.tags.take(3).join(', ');
                    return ListTile(
                      tileColor: AuthColors.backgroundAlt,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      title: Text(
                        client.name,
                        style: const TextStyle(
                          color: AuthColors.textMain,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: Text(
                        tagSummary,
                        style: const TextStyle(color: AuthColors.textSub),
                      ),
                      trailing: Icon(
                        Icons.chevron_right,
                        color: AuthColors.textMainWithOpacity(0.7),
                      ),
                      onTap: () => Navigator.of(context).pop(client),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _DuplicateClientSheet extends StatelessWidget {
  const _DuplicateClientSheet({required this.client});

  final ClientRecord client;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: 400,
          maxHeight: MediaQuery.of(context).size.height * 0.8,
        ),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AuthColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AuthColors.textMainWithOpacity(0.1)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Client already exists',
                    style: TextStyle(
                      color: AuthColors.textMain,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close, color: AuthColors.textSub),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              client.name,
              style: const TextStyle(
                color: AuthColors.textSub,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 20),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.visibility_outlined, color: AuthColors.textSub),
              title: const Text(
                'View existing client',
                style: TextStyle(color: AuthColors.textMain),
              ),
              onTap: () =>
                  Navigator.pop(context, _ExistingClientAction.viewExisting),
            ),
            Divider(color: AuthColors.textMainWithOpacity(0.1)),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.close, color: AuthColors.textDisabled),
              title: const Text(
                'Cancel',
                style: TextStyle(color: AuthColors.textSub),
              ),
              onTap: () =>
                  Navigator.pop(context, _ExistingClientAction.cancel),
            ),
          ],
        ),
      ),
    );
  }
}

class _AddContactToClientSheet extends StatefulWidget {
  const _AddContactToClientSheet({
    required this.entry,
    required this.client,
    required this.onSubmit,
  });

  final _ContactEntry entry;
  final ClientRecord client;
  final Future<void> Function(String name, String phone, String? description)
      onSubmit;

  @override
  State<_AddContactToClientSheet> createState() =>
      _AddContactToClientSheetState();
}

class _AddContactToClientSheetState extends State<_AddContactToClientSheet> {
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  late String _selectedPhone;
  bool _isSaving = false;
  String? _errorMessage;

  bool get _requiresDescription => widget.client.isCorporate;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.entry.name);
    _descriptionController = TextEditingController();
    _selectedPhone = widget.entry.primaryDisplayPhone;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          constraints: BoxConstraints(
            maxWidth: 400,
            maxHeight: MediaQuery.of(context).size.height * 0.8,
          ),
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: bottomInset + 20,
          ),
          decoration: BoxDecoration(
            color: AuthColors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AuthColors.textMainWithOpacity(0.1)),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Add Contact to ${widget.client.name}',
                    style: const TextStyle(
                      color: AuthColors.textMain,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  icon: const Icon(Icons.close, color: AuthColors.textSub),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: widget.client.tags.isEmpty
                    ? [
                        const Chip(
                          label: Text('No tags'),
                          visualDensity: VisualDensity.compact,
                          backgroundColor: AuthColors.surface,
                          labelStyle: TextStyle(color: AuthColors.textSub),
                        )
                      ]
                    : widget.client.tags
                        .map(
                          (tag) => Chip(
                            label: Text(tag),
                            visualDensity: VisualDensity.compact,
                            backgroundColor: AuthColors.surface,
                            labelStyle: const TextStyle(color: AuthColors.textSub),
                          ),
                        )
                        .toList(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _nameController,
              style: const TextStyle(color: AuthColors.textMain),
              decoration: const InputDecoration(
                labelText: 'Contact Name',
                labelStyle: TextStyle(color: AuthColors.textSub),
                filled: true,
                fillColor: AuthColors.backgroundAlt,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(14)),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (widget.entry.displayPhones.length > 1)
              DropdownButtonFormField<String>(
                initialValue: _selectedPhone,
                decoration: const InputDecoration(
                  labelText: 'Phone Number',
                  labelStyle: TextStyle(color: AuthColors.textSub),
                  filled: true,
                  fillColor: AuthColors.backgroundAlt,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(14)),
                    borderSide: BorderSide.none,
                  ),
                ),
                dropdownColor: AuthColors.surface,
                style: const TextStyle(color: AuthColors.textMain),
                items: widget.entry.displayPhones
                    .map(
                      (phone) => DropdownMenuItem<String>(
                        value: phone,
                        child: Text(phone),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _selectedPhone = value);
                  }
                },
              )
            else
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AuthColors.backgroundAlt,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Phone Number',
                      style: TextStyle(
                        color: AuthColors.textSub,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.entry.primaryDisplayPhone,
                      style: const TextStyle(color: AuthColors.textMain, fontSize: 16),
                    ),
                  ],
                ),
              ),
            if (_requiresDescription) ...[
              const SizedBox(height: 16),
              TextField(
                controller: _descriptionController,
                maxLines: 2,
                style: const TextStyle(color: AuthColors.textMain),
                decoration: const InputDecoration(
                  labelText: 'Description',
                  hintText: 'e.g., Accounts Head, Dispatch Manager',
                  labelStyle: TextStyle(color: AuthColors.textSub),
                  filled: true,
                  fillColor: AuthColors.backgroundAlt,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(14)),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ],
            if (_errorMessage != null) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  _errorMessage!,
                  style: const TextStyle(color: AuthColors.error),
                ),
              ),
            ],
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _handleSave,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AuthColors.successVariant,
                  foregroundColor: AuthColors.textMain,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: _isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AuthColors.textMain,
                        ),
                      )
                    : const Text('Add Contact'),
              ),
            ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _handleSave() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _errorMessage = 'Contact name is required.');
      return;
    }

    final description = _descriptionController.text.trim();
    if (_requiresDescription && description.isEmpty) {
      setState(() => _errorMessage = 'Description is required for corporates.');
      return;
    }

    setState(() {
      _errorMessage = null;
      _isSaving = true;
    });

    try {
      await widget.onSubmit(
        name,
        _selectedPhone,
        description.isEmpty ? null : description,
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on _DuplicateClientException catch (error) {
      setState(() {
        _isSaving = false;
        _errorMessage = error.message;
      });
    } on ClientPhoneExistsException {
      setState(() {
        _isSaving = false;
        _errorMessage = 'This phone number already exists under the client.';
      });
    } catch (error) {
      setState(() {
        _isSaving = false;
        _errorMessage = 'Unable to add contact: $error';
      });
    }
  }
}

class _ClientFormSheet extends StatefulWidget {
  const _ClientFormSheet({
    required this.entry,
    required this.availableTags,
    required this.onSubmit,
  });

  final _ContactEntry entry;
  final List<String> availableTags;
  final Future<void> Function(String name, String phone, String tag) onSubmit;

  @override
  State<_ClientFormSheet> createState() => _ClientFormSheetState();
}

class _ClientFormSheetState extends State<_ClientFormSheet> {
  late final TextEditingController _nameController;
  late String _selectedPhone;
  late String _selectedTag;
  bool _isSaving = false;
  String? _errorMessage;
  List<DropdownMenuItem<String>>? _cachedDropdownItems;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.entry.name);
    _selectedPhone = widget.entry.primaryDisplayPhone;
    _selectedTag = widget.availableTags.first;
    // Cache dropdown items to avoid rebuilding on every setState
    if (widget.entry.displayPhones.length > 1) {
      _cachedDropdownItems = widget.entry.displayPhones
          .map(
            (phone) => DropdownMenuItem<String>(
              value: phone,
              child: Text(phone),
            ),
          )
          .toList();
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          constraints: BoxConstraints(
            maxWidth: 400,
            maxHeight: MediaQuery.of(context).size.height * 0.8,
          ),
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: bottomInset + 20,
          ),
          decoration: BoxDecoration(
            color: AuthColors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AuthColors.textMainWithOpacity(0.1)),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Add Client',
                        style: TextStyle(
                          color: AuthColors.textMain,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      icon: const Icon(Icons.close, color: AuthColors.textSub),
                    ),
                  ],
                ),
            const SizedBox(height: 12),
                TextField(
                  controller: _nameController,
                  style: const TextStyle(color: AuthColors.textMain),
                  decoration: const InputDecoration(
                    labelText: 'Name',
                    labelStyle: TextStyle(color: AuthColors.textSub),
                    filled: true,
                    fillColor: AuthColors.backgroundAlt,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(14)),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 16),
                const Text(
                  'Tag',
                  style: TextStyle(
                    color: AuthColors.textSub,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                _TagSelector(
                  availableTags: widget.availableTags,
                  selectedTag: _selectedTag,
                  onTagSelected: (tag) {
                    setState(() => _selectedTag = tag);
                  },
                ),
            const SizedBox(height: 16),
            if (widget.entry.displayPhones.length > 1)
              DropdownButtonFormField<String>(
                initialValue: _selectedPhone,
                decoration: const InputDecoration(
                  labelText: 'Phone Number',
                  labelStyle: TextStyle(color: AuthColors.textSub),
                  filled: true,
                  fillColor: AuthColors.backgroundAlt,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(14)),
                    borderSide: BorderSide.none,
                  ),
                ),
                dropdownColor: AuthColors.surface,
                style: const TextStyle(color: AuthColors.textMain),
                items: _cachedDropdownItems,
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _selectedPhone = value);
                  }
                },
              )
                else
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AuthColors.backgroundAlt,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Phone Number',
                          style: TextStyle(
                            color: AuthColors.textSub,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.entry.primaryDisplayPhone,
                          style: const TextStyle(color: AuthColors.textMain, fontSize: 16),
                        ),
                      ],
                    ),
                  ),
                if (_errorMessage != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    _errorMessage!,
                    style: const TextStyle(color: AuthColors.error),
                  ),
                ],
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : _handleSave,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AuthColors.primary,
                      foregroundColor: AuthColors.textMain,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: _isSaving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AuthColors.textMain,
                            ),
                          )
                        : const Text('Save Client'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _handleSave() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() {
        _errorMessage = 'Name is required.';
      });
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      await widget.onSubmit(
        name,
        _selectedPhone,
        _selectedTag,
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on _DuplicateClientException catch (error) {
      setState(() {
        _isSaving = false;
        _errorMessage = error.message;
      });
    } catch (error) {
      setState(() {
        _isSaving = false;
        _errorMessage = 'Failed to save client: $error';
      });
    }
  }
}

class _TagSelector extends StatelessWidget {
  const _TagSelector({
    required this.availableTags,
    required this.selectedTag,
    required this.onTagSelected,
  });

  final List<String> availableTags;
  final String selectedTag;
  final ValueChanged<String> onTagSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: availableTags.map((tag) {
        final isSelected = selectedTag == tag;
        return ChoiceChip(
          label: Text(tag),
          selected: isSelected,
          onSelected: (_) => onTagSelected(tag),
          selectedColor: AuthColors.primary,
          labelStyle: TextStyle(
            color: isSelected ? AuthColors.textMain : AuthColors.textSub,
          ),
          backgroundColor: AuthColors.surface,
        );
      }).toList(),
    );
  }
}

class _DuplicateClientException implements Exception {
  const _DuplicateClientException(this.message);
  final String message;
  @override
  String toString() => message;
}

