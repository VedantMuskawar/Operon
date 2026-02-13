import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:call_log/call_log.dart' as device_log;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_contacts/flutter_contacts.dart' as device_contacts;
import 'package:permission_handler/permission_handler.dart';
import 'package:dash_mobile/data/services/client_service.dart';
import 'package:dash_mobile/presentation/blocs/org_context/org_context_cubit.dart';
import 'package:dash_mobile/presentation/blocs/contacts/contact_cubit.dart';
import 'package:dash_mobile/presentation/blocs/contacts/contact_state.dart';
import 'package:dash_mobile/presentation/utils/network_error_helper.dart';
import 'package:dash_mobile/presentation/views/clients_page/contact_processing.dart';
import 'package:dash_mobile/presentation/widgets/loading/contact_skeleton.dart';
import 'package:dash_mobile/presentation/widgets/alphabet_strip.dart' show groupContactsByLetter, getAvailableLetters;
import 'package:dash_mobile/shared/constants/app_spacing.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:core_ui/core_ui.dart';
import 'package:core_bloc/core_bloc.dart' as core_bloc;

enum _ListItemType { header, contact }

class _ListItem {
  const _ListItem({
    required this.type,
    this.letter,
    this.contact,
  });

  final _ListItemType type;
  final String? letter;
  final ContactEntry? contact;
}

class ContactPage extends StatelessWidget {
  const ContactPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => ContactCubit(),
      child: const _ContactPageContent(),
    );
  }
}

class _ContactPageContent extends StatefulWidget {
  const _ContactPageContent();

  @override
  State<_ContactPageContent> createState() => _ContactPageState();
}

class _ContactPageState extends State<_ContactPageContent> {
  bool _isCallLogLoading = true;
  String? _callLogMessage;
  List<_CallLogEntry> _entries = const [];
  List<_CallLogEntry> _filteredCallLogs = const [];
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _callLogSearchController = TextEditingController();
  final ScrollController _contactListController = ScrollController();
  final ScrollController _callLogScrollController = ScrollController();
  late final PageController _pageController;
  double _currentPage = 0;
  final ClientService _clientService = ClientService();
  Isolate? _contactsIsolate;
  ReceivePort? _receivePort;

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
    _callLogSearchController.addListener(_onCallLogSearchChanged);
    _pageController = PageController()
      ..addListener(_onPageChanged);
    _contactListController.addListener(_handleContactListScroll);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _callLogSearchController.dispose();
    _pageController.removeListener(_onPageChanged);
    _pageController.dispose();
    _contactListController.removeListener(_handleContactListScroll);
    _contactListController.dispose();
    _callLogScrollController.dispose();
    _contactsIsolate?.kill(priority: Isolate.immediate);
    _receivePort?.close();
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
        _filteredCallLogs = entries;
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
    if (!mounted) return;
    final cubit = context.read<ContactCubit>();

    if (!Platform.isAndroid) {
      cubit.setError('Phone contacts are only available on Android devices.');
      return;
    }

    try {
      // Check current permission status first
      final permissionStatus = await Permission.contacts.status;
      bool hasPermission = permissionStatus.isGranted;
      
      if (!hasPermission) {
        // Request permission
        debugPrint('Requesting contacts permission...');
        final requestResult = await Permission.contacts.request();
        hasPermission = requestResult.isGranted;
        
        if (!hasPermission) {
          if (!mounted) return;
          // Check if permanently denied
          if (requestResult.isPermanentlyDenied) {
            cubit.setError(
              'Contacts permission is required. Please enable it in app settings.',
            );
          } else {
            cubit.setError(
              'Contacts permission is required to view your phone contacts.',
            );
          }
          return;
        }
      }

      // Initialize loading
      cubit.initializeLoading();

      // Load contacts WITHOUT properties for speed - lazy load phone numbers on demand
      debugPrint('Loading contacts from device (lazy mode)...');
      final contacts = await device_contacts.FlutterContacts.getContacts(
        withProperties: false, // Don't load phone numbers initially - much faster!
        withPhoto: false,
        sorted: false,
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw TimeoutException('Contact loading timed out');
        },
      );
      
      debugPrint('Loaded ${contacts.length} raw contacts from device (names only)');
      
      if (!mounted) return;

      // Process contacts in chunks using isolate
      await _processContactsInChunks(contacts, cubit);
      
    } catch (error) {
      if (!mounted) return;
      
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
      cubit.setError(errorMessage);
    }
  }

  Future<void> _processContactsInChunks(
    List<device_contacts.Contact> contacts,
    ContactCubit cubit,
  ) async {
    // Store contacts count for batching optimization
    final totalContacts = contacts.length;
    if (!mounted) return;

    // Create receive port for chunked data
    _receivePort = ReceivePort();
    final sendPort = _receivePort!.sendPort;

    // Spawn isolate for processing
    final params = _ProcessContactsParams(sendPort: sendPort, contacts: contacts);
    _contactsIsolate = await Isolate.spawn<_ProcessContactsParams>(
      _ContactPageState._isolateEntryPoint,
      params,
    );

    // Progressive loading: First chunk shows immediately, subsequent chunks batch
    int processedCount = 0;
    bool isFirstChunk = true;
    final chunkBuffer = <List<ContactEntry>>[];
    Timer? batchTimer;
    final isLargeList = totalContacts > 5000;
    
    await for (final message in _receivePort!) {
      if (!mounted) break;
      
      if (message == null) {
        // Process any remaining buffered chunks
        batchTimer?.cancel();
        if (chunkBuffer.isNotEmpty) {
          cubit.setLoadingChunk(true);
          cubit.loadContactChunks(chunkBuffer);
          chunkBuffer.clear();
          cubit.setLoadingChunk(false);
        }
        // Completion signal
        cubit.finishLoading();
        debugPrint('Contact processing completed: $processedCount contacts processed');
        break;
      } else if (message is List<ContactEntry>) {
        processedCount += message.length;
        
        if (isFirstChunk) {
          // First chunk (300 contacts) - show IMMEDIATELY for instant feedback
          isFirstChunk = false;
          cubit.setLoadingChunk(true);
          cubit.loadContactChunk(message);
          cubit.setLoadingChunk(false);
          debugPrint('First batch displayed: ${message.length} contacts');
        } else {
          // Subsequent chunks - batch them to reduce UI rebuilds
          chunkBuffer.add(message);
          
          // Batch every 2-3 chunks depending on list size
          final batchThreshold = isLargeList ? 3 : 2;
          if (chunkBuffer.length >= batchThreshold) {
            batchTimer?.cancel();
            final delay = isLargeList
                ? const Duration(milliseconds: 50)  // Less frequent for huge lists
                : const Duration(milliseconds: 32);  // More frequent for smaller lists
            batchTimer = Timer(delay, () {
              if (chunkBuffer.isNotEmpty && mounted) {
                cubit.setLoadingChunk(true);
                final toProcess = List<List<ContactEntry>>.from(chunkBuffer);
                chunkBuffer.clear();
                cubit.loadContactChunks(toProcess);
                cubit.setLoadingChunk(false);
              }
            });
          }
        }
      }
    }
    
    batchTimer?.cancel();
  }

  // Helper function to process contacts in background isolate
  // Optimized with better error handling and validation
  void _onSearchChanged() {
    final query = _searchController.text;
    if (!mounted) return;
    context.read<ContactCubit>().searchContacts(query);
  }

  void _onCallLogSearchChanged() {
    final query = _callLogSearchController.text.trim().toLowerCase();
    if (!mounted) return;
    
    setState(() {
      if (query.isEmpty) {
        _filteredCallLogs = _entries;
      } else {
        _filteredCallLogs = _entries.where((entry) {
          final nameMatch = entry.contactName.toLowerCase().contains(query);
          final phoneMatch = entry.phoneNumber.replaceAll(RegExp(r'[^0-9+]'), '').contains(query.replaceAll(RegExp(r'[^0-9+]'), ''));
          return nameMatch || phoneMatch;
        }).toList();
      }
    });
  }

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
    if (!_contactListController.hasClients) return;
    if (!mounted) return;

    final cubit = context.read<ContactCubit>();
    if (cubit.state.isSearchActive) return;
  }

  Future<void> _handleContactTap(ContactEntry entry) async {
    if (!mounted) return;
    final cubit = context.read<ContactCubit>();

    // Lazy load contact details if needed
    ContactEntry contactToUse = entry;
    if (!entry.hasPhones && entry.contactId != null) {
      try {
        final fullContact = await device_contacts.FlutterContacts.getContact(
          entry.contactId!,
          withProperties: true,
        );
        if (fullContact != null && mounted) {
          final processed = await processContactWithDetails(entry.id, fullContact);
          if (processed.isNotEmpty) {
            contactToUse = processed.first;
            cubit.updateContactDetails(contactToUse);
          }
        }
      } catch (e) {
        debugPrint('Error loading contact details: $e');
      }
    }

    final existingClient = await _findExistingClient(contactToUse);
    if (existingClient != null) {
      if (!mounted) return;
      context.pushNamed('client-detail', extra: existingClient);
      return;
    }

    final action = await _showContactActionSheet();
    if (action == null) return;

    if (action == _ContactAction.newClient) {
      final saved = await _showClientFormSheet(contactToUse);
      if (saved == true && mounted) {
        cubit.addRecentContact(contactToUse);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Client "${contactToUse.name}" saved'),
          ),
        );
      }
      return;
    }

    final selectedClient = await _showExistingClientPicker();
    if (selectedClient == null) return;

    final success = await _showAddContactToClientSheet(
      entry: contactToUse,
      client: selectedClient,
    );

    if (success == true && mounted) {
      cubit.addRecentContact(contactToUse);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Added contact to ${selectedClient.name}.'),
        ),
      );
    }
  }

  /// Batch futures to limit concurrency and prevent overwhelming the network
  Future<List<T>> _batchFutures<T>(List<Future<T>> futures, {int batchSize = 10}) async {
    final results = <T>[];
    for (int i = 0; i < futures.length; i += batchSize) {
      final batch = futures.skip(i).take(batchSize).toList();
      final batchResults = await Future.wait(batch);
      results.addAll(batchResults);
    }
    return results;
  }

  Future<ClientRecord?> _findExistingClient(ContactEntry entry) async {
    final orgId =
        context.read<OrganizationContextCubit>().state.organization?.id;
    // Optimize: Check all phones in parallel but limit concurrency
    final futures = entry.displayPhones
        .map((phone) => _clientService.findClientByPhone(
              phone,
              organizationId: orgId,
            ))
        .toList();
    
    try {
      // Process futures in batches to limit concurrent network requests
      final results = await _batchFutures(futures, batchSize: 10);
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

  Future<ClientRecord?> _showExistingClientPicker() {
    final orgId =
        context.read<OrganizationContextCubit>().state.organization?.id;
    return showDialog<ClientRecord>(
      context: context,
      builder: (context) => _ExistingClientPickerSheet(
        loadClients: () => _clientService.fetchClients(
          limit: _clientFetchLimit,
          organizationId: orgId,
        ),
      ),
    );
  }

  Future<bool?> _showAddContactToClientSheet({
    required ContactEntry entry,
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

    final contactEntry = ContactEntry(
      id: 'call_${entry.timestamp.millisecondsSinceEpoch}_$phone',
      name: contactName,
      normalizedName: contactName.toLowerCase(),
      displayPhones: [phone],
      normalizedPhones: [
        phone.replaceAll(RegExp(r'[^0-9+]'), ''),
      ],
      hasPhones: true,
    );

    await _handleContactTap(contactEntry);
  }

  @override
  Widget build(BuildContext context) {
    final grouped = _groupByDay(_filteredCallLogs);

    return Scaffold(
      backgroundColor: AuthColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Container(
              color: AuthColors.primary,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.paddingXL, vertical: AppSpacing.paddingMD),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close, color: AuthColors.textMain),
                  ),
                  const SizedBox(width: AppSpacing.paddingSM),
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
                  const SizedBox(width: AppSpacing.avatarSM),
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
                        Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.fromLTRB(
                                AppSpacing.paddingXL,
                                AppSpacing.paddingLG,
                                AppSpacing.paddingXL,
                                AppSpacing.paddingMD,
                              ),
                              color: AuthColors.background,
                              child: TextField(
                                controller: _callLogSearchController,
                                style: const TextStyle(color: AuthColors.textMain, fontSize: 15),
                                decoration: InputDecoration(
                                  prefixIcon: const Icon(Icons.search, color: AuthColors.textSub, size: 20),
                                  hintText: 'Search call logs',
                                  hintStyle: const TextStyle(color: AuthColors.textDisabled, fontSize: 14),
                                  filled: true,
                                  fillColor: AuthColors.backgroundAlt,
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: AppSpacing.paddingLG,
                                    vertical: AppSpacing.paddingLG,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(AppSpacing.radiusLG),
                                    borderSide: BorderSide.none,
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(AppSpacing.radiusLG),
                                    borderSide: const BorderSide(
                                      color: AuthColors.legacyAccent,
                                      width: 2,
                                    ),
                                  ),
                                ),
                                textInputAction: TextInputAction.search,
                              ),
                            ),
                            Expanded(
                              child: SingleChildScrollView(
                                controller: _callLogScrollController,
                                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.paddingXL),
                                physics: const ClampingScrollPhysics(),
                                child: _CallLogsCard(
                                  isLoading: _isCallLogLoading,
                                  message: _callLogMessage,
                                  groupedEntries: grouped,
                                  onCallTap: _handleCallLogTap,
                                  searchQuery: _callLogSearchController.text,
                                ),
                              ),
                            ),
                          ],
                        ),
                        BlocBuilder<ContactCubit, ContactState>(
                          builder: (context, state) {
                            return RefreshIndicator(
                              onRefresh: _loadContacts,
                              color: AuthColors.legacyAccent,
                              child: Stack(
                                children: [
                                  CustomScrollView(
                                    controller: _contactListController,
                                    physics: const ClampingScrollPhysics(),
                                    slivers: [
                                      SliverPersistentHeader(
                                        pinned: true,
                                        delegate: _PinnedSearchHeader(
                                          searchController: _searchController,
                                          recentContacts: state.recentContacts,
                                          onContactTap: _handleContactTap,
                                        ),
                                      ),
                                      if (state.status == core_bloc.ViewStatus.loading &&
                                          state.allContacts.isEmpty)
                                        const SliverToBoxAdapter(
                                          child: Padding(
                                            padding: EdgeInsets.all(AppSpacing.paddingXL),
                                            child: ContactListSkeleton(itemCount: 10),
                                          ),
                                        )
                                      else if (state.message != null &&
                                          state.allContacts.isEmpty)
                                        SliverFillRemaining(
                                          child: Padding(
                                            padding: const EdgeInsets.all(AppSpacing.paddingXL),
                                            child: _ContactPermissionErrorWidget(
                                              message: state.message ?? '',
                                              onOpenSettings: () async {
                                                await openAppSettings();
                                                // Reload contacts after returning from settings
                                                if (mounted) {
                                                  await Future.delayed(
                                                    const Duration(milliseconds: 500),
                                                  );
                                                  _loadContacts();
                                                }
                                              },
                                            ),
                                          ),
                                        )
                                      else if (state.filteredContacts.isEmpty &&
                                          state.isSearchActive)
                                        const SliverFillRemaining(
                                          child: Padding(
                                            padding: EdgeInsets.all(AppSpacing.paddingXL),
                                            child: Center(
                                              child: Text(
                                                'No contacts match your search.',
                                                style: TextStyle(
                                                  color: AuthColors.textSub,
                                                  fontSize: 14,
                                                ),
                                              ),
                                            ),
                                          ),
                                        )
                                      else
                                        _buildContactList(state),
                                      if (state.isLoadingChunk)
                                        const SliverToBoxAdapter(
                                          child: Padding(
                                            padding: EdgeInsets.symmetric(vertical: AppSpacing.paddingLG),
                                            child: Center(
                                              child: SizedBox(
                                                height: 20,
                                                width: 20,
                                                child: CircularProgressIndicator(
                                                  strokeWidth: 2,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.paddingMD),
                  _PageIndicator(pageCount: 2, currentIndex: _currentPage),
                  const SizedBox(height: AppSpacing.paddingXXL),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContactList(ContactState state) {
    // Use cached index if available, otherwise group on the fly
    // For very large lists, use flat list without grouping for better performance
    final contacts = state.filteredContacts;
    
    if (contacts.length > 5000) {
      // Very large list - use flat list for better performance
      return SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            if (index >= contacts.length) return null;
            final contact = contacts[index];
            return RepaintBoundary(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.paddingXL),
                child: _ContactListTile(
                  key: ValueKey(contact.id),
                  contact: contact,
                  onTap: () => _handleContactTap(contact),
                ),
              ),
            );
          },
          childCount: contacts.length,
          addAutomaticKeepAlives: false,
          addRepaintBoundaries: true,
        ),
      );
    }
    
    // Smaller lists - use grouped view with alphabet sections
    final grouped = groupContactsByLetter<ContactEntry>(
      contacts: contacts,
      getName: (c) => c.normalizedName,
    );
    final letters = getAvailableLetters(grouped);

    // Pre-calculate item positions for O(1) lookup
    final itemPositions = <int, _ListItem>{};
    int position = 0;
    for (final letter in letters) {
      final sectionContacts = grouped[letter] ?? [];
      itemPositions[position] = _ListItem(type: _ListItemType.header, letter: letter);
      position++;
      for (int i = 0; i < sectionContacts.length; i++) {
        itemPositions[position] = _ListItem(
          type: _ListItemType.contact,
          contact: sectionContacts[i],
        );
        position++;
      }
    }

    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final item = itemPositions[index];
          if (item == null) return null;
          
          if (item.type == _ListItemType.header) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.paddingXL,
                AppSpacing.paddingLG,
                AppSpacing.paddingXL,
                AppSpacing.paddingSM,
              ),
              child: Text(
                item.letter!,
                style: const TextStyle(
                  color: AuthColors.textSub,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            );
          } else {
            return RepaintBoundary(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.paddingXL),
                child: _ContactListTile(
                  key: ValueKey(item.contact!.id),
                  contact: item.contact!,
                  onTap: () => _handleContactTap(item.contact!),
                ),
              ),
            );
          }
        },
        childCount: position,
        addAutomaticKeepAlives: false,
        addRepaintBoundaries: true,
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

  // Helper method for isolate entry point
  static void _isolateEntryPoint(_ProcessContactsParams params) {
    processContactsInChunks(params.sendPort, params.contacts);
  }

  Future<bool?> _showClientFormSheet(ContactEntry entry) {
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
              final duplicate = await _clientService.findClientByPhone(
                number,
                organizationId: organizationId,
              );
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

class _ProcessContactsParams {
  const _ProcessContactsParams({
    required this.sendPort,
    required this.contacts,
  });

  final SendPort sendPort;
  final List<device_contacts.Contact> contacts;
}

/// Widget to display permission error with option to open settings
class _ContactPermissionErrorWidget extends StatelessWidget {
  const _ContactPermissionErrorWidget({
    required this.message,
    required this.onOpenSettings,
  });

  final String message;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.contacts_outlined,
            size: 64,
            color: AuthColors.textMainWithOpacity(0.3),
          ),
          const SizedBox(height: AppSpacing.paddingLG),
          Text(
            message,
            style: const TextStyle(
              color: AuthColors.textSub,
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.paddingXXL),
          FilledButton.icon(
            onPressed: onOpenSettings,
            icon: const Icon(Icons.settings, size: 18),
            label: const Text('Open Settings'),
            style: FilledButton.styleFrom(
              backgroundColor: AuthColors.legacyAccent,
              foregroundColor: AuthColors.textMain,
              padding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 12,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppSpacing.radiusMD),
              ),
            ),
          ),
        ],
      ),
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
        const SizedBox(height: AppSpacing.paddingSM),
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
        borderRadius: BorderRadius.circular(AppSpacing.radiusMD),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.paddingSM),
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
              const SizedBox(width: AppSpacing.paddingMD),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
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
                    const SizedBox(height: AppSpacing.paddingXS / 2),
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
              borderRadius: BorderRadius.circular(AppSpacing.radiusXL),
            ),
            child: const SizedBox(
              width: 60,
              height: 60,
              child: Icon(Icons.call_end, color: AuthColors.textDisabled),
            ),
          ),
          const SizedBox(height: AppSpacing.paddingMD),
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

/// Pinned search header delegate for SliverPersistentHeader
class _PinnedSearchHeader extends SliverPersistentHeaderDelegate {
  const _PinnedSearchHeader({
    required this.searchController,
    required this.recentContacts,
    required this.onContactTap,
  });

  final TextEditingController searchController;
  final List<ContactEntry> recentContacts;
  final ValueChanged<ContactEntry> onContactTap;

  @override
  double get minExtent {
    // Minimum: padding (4*2) + TextField height (~56) = ~64px
    // Using smaller value to ensure layoutExtent doesn't exceed paintExtent
    return 68.0;
  }

  @override
  double get maxExtent {
    // Maximum: padding (16*2) + TextField (~56) + recent contacts section (~60) = ~148px
    // Reduced by 1px to ensure layoutExtent doesn't exceed paintExtent
    return recentContacts.isNotEmpty ? 148.0 : 87.0;
  }

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    final isShrunk = shrinkOffset > 0;
    final showRecentContacts = !isShrunk && recentContacts.isNotEmpty;
    
    return LayoutBuilder(
      builder: (context, constraints) {
        final availableHeight = constraints.maxHeight;
        final canShowRecent = availableHeight >= 120 && showRecentContacts;
        
        return Container(
          color: AuthColors.background,
          padding: EdgeInsets.symmetric(
            horizontal: AppSpacing.paddingXL,
            vertical: isShrunk ? AppSpacing.paddingXS : AppSpacing.paddingLG,
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: availableHeight,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
              TextField(
                controller: searchController,
                style: const TextStyle(color: AuthColors.textMain, fontSize: 15),
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search, color: AuthColors.textSub, size: 20),
                  hintText: 'Search contacts',
                  hintStyle: const TextStyle(color: AuthColors.textDisabled, fontSize: 14),
                  filled: true,
                  fillColor: AuthColors.backgroundAlt,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.paddingLG,
                    vertical: AppSpacing.paddingLG,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppSpacing.radiusLG),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppSpacing.radiusLG),
                    borderSide: const BorderSide(
                      color: AuthColors.legacyAccent,
                      width: 2,
                    ),
                  ),
                ),
                textInputAction: TextInputAction.search,
              ),
              if (canShowRecent) ...[
                const SizedBox(height: AppSpacing.paddingMD),
                const Text(
                  'Recently searched',
                  style: TextStyle(
                    color: AuthColors.textSub,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: AppSpacing.paddingSM),
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
                    separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.paddingSM),
                    itemCount: recentContacts.length,
                  ),
                ),
              ],
            ],
          ),
        ),
      );
      },
    );
  }

  @override
  bool shouldRebuild(_PinnedSearchHeader oldDelegate) {
    return searchController.text != oldDelegate.searchController.text ||
        recentContacts.length != oldDelegate.recentContacts.length;
  }
}


class _ContactListTile extends StatelessWidget {
  const _ContactListTile({
    super.key,
    required this.contact,
    required this.onTap,
  });

  final ContactEntry contact;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // Optimize: Use const where possible, avoid unnecessary rebuilds
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMD),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.paddingSM),
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
              const SizedBox(width: AppSpacing.paddingMD),
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
                    const SizedBox(height: AppSpacing.paddingXS / 2),
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
            margin: const EdgeInsets.symmetric(horizontal: AppSpacing.paddingXS),
            width: isActive ? 18 : 8,
            height: 8,
            decoration: BoxDecoration(
              color: isActive ? AuthColors.legacyAccent : AuthColors.textMainWithOpacity(0.3),
              borderRadius: BorderRadius.circular(AppSpacing.radiusRound),
            ),
          );
        },
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
    this.searchQuery = '',
  });

  final bool isLoading;
  final String? message;
  final Map<String, List<_CallLogEntry>> groupedEntries;
  final ValueChanged<_CallLogEntry> onCallTap;
  final String searchQuery;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.paddingXL),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.paddingXXXL * 1.25),
              child: Center(
                child: CircularProgressIndicator(
                  color: AuthColors.legacyAccent,
                ),
              ),
            )
          else if (groupedEntries.isEmpty)
            _EmptyState(
              message: searchQuery.isNotEmpty
                  ? 'No call logs match your search.'
                  : message,
            )
          else
            Column(
              mainAxisSize: MainAxisSize.min,
              children: groupedEntries.entries
                  .map(
                    (entry) => Padding(
                      key: ValueKey(entry.key),
                      padding: const EdgeInsets.only(bottom: AppSpacing.paddingLG),
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
        padding: const EdgeInsets.all(AppSpacing.paddingXXL),
        decoration: BoxDecoration(
          color: AuthColors.surface,
          borderRadius: BorderRadius.circular(AppSpacing.radiusXL),
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
            const SizedBox(height: AppSpacing.paddingXS),
            const Text(
              'Create a new client or attach this contact to an existing one.',
              style: TextStyle(
                color: AuthColors.textSub,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: AppSpacing.paddingXL),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AuthColors.legacyAccent.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusLG),
                ),
                child: Icon(
                  Icons.person_add_alt,
                  color: AuthColors.legacyAccent.withValues(alpha: 0.8),
                ),
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
            const SizedBox(height: AppSpacing.paddingMD),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AuthColors.successVariant.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusLG),
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
          left: AppSpacing.paddingXL,
          right: AppSpacing.paddingXL,
          top: AppSpacing.paddingXL,
          bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.paddingXL,
        ),
        decoration: BoxDecoration(
          color: AuthColors.surface,
          borderRadius: BorderRadius.circular(AppSpacing.radiusXL),
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
            const SizedBox(height: AppSpacing.gapSM),
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
                  borderRadius: BorderRadius.circular(AppSpacing.radiusLG),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.paddingLG),
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: AppSpacing.paddingXXXL),
                child: CircularProgressIndicator(),
              )
            else if (_error != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.paddingXXXL),
                child: Text(
                  _error!,
                  style: const TextStyle(color: AuthColors.error),
                  textAlign: TextAlign.center,
                ),
              )
            else if (_filtered.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: AppSpacing.paddingXXXL),
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
                  separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.paddingMD),
                  itemBuilder: (context, index) {
                    final client = _filtered[index];
                    final tagSummary = client.tags.isEmpty
                        ? 'No tags'
                        : client.tags.take(3).join(', ');
                    return ListTile(
                      tileColor: AuthColors.backgroundAlt,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppSpacing.radiusLG),
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

class _AddContactToClientSheet extends StatefulWidget {
  const _AddContactToClientSheet({
    required this.entry,
    required this.client,
    required this.onSubmit,
  });

  final ContactEntry entry;
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
            left: AppSpacing.paddingXL,
            right: AppSpacing.paddingXL,
            top: AppSpacing.paddingXL,
            bottom: bottomInset + AppSpacing.paddingXL,
          ),
          decoration: BoxDecoration(
            color: AuthColors.surface,
            borderRadius: BorderRadius.circular(AppSpacing.radiusXL),
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
            const SizedBox(height: AppSpacing.paddingMD),
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
            const SizedBox(height: AppSpacing.paddingLG),
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
            const SizedBox(height: AppSpacing.paddingLG),
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
                padding: const EdgeInsets.all(AppSpacing.paddingLG),
                decoration: BoxDecoration(
                  color: AuthColors.backgroundAlt,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusLG),
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
                    const SizedBox(height: AppSpacing.paddingXS),
                    Text(
                      widget.entry.primaryDisplayPhone,
                      style: const TextStyle(color: AuthColors.textMain, fontSize: 16),
                    ),
                  ],
                ),
              ),
            if (_requiresDescription) ...[
              const SizedBox(height: AppSpacing.paddingLG),
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
              const SizedBox(height: AppSpacing.paddingSM),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  _errorMessage!,
                  style: const TextStyle(color: AuthColors.error),
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.paddingXXL),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _isSaving ? null : _handleSave,
                style: FilledButton.styleFrom(
                  backgroundColor: AuthColors.successVariant,
                  foregroundColor: AuthColors.textMain,
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.paddingLG),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppSpacing.radiusLG),
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

  final ContactEntry entry;
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
            left: AppSpacing.paddingXL,
            right: AppSpacing.paddingXL,
            top: AppSpacing.paddingXL,
            bottom: bottomInset + AppSpacing.paddingXL,
          ),
          decoration: BoxDecoration(
            color: AuthColors.surface,
            borderRadius: BorderRadius.circular(AppSpacing.radiusXL),
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
            const SizedBox(height: AppSpacing.paddingMD),
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
            const SizedBox(height: AppSpacing.paddingLG),
                const Text(
                  'Tag',
                  style: TextStyle(
                    color: AuthColors.textSub,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: AppSpacing.paddingSM),
                _TagSelector(
                  availableTags: widget.availableTags,
                  selectedTag: _selectedTag,
                  onTagSelected: (tag) {
                    setState(() => _selectedTag = tag);
                  },
                ),
            const SizedBox(height: AppSpacing.paddingLG),
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
                    padding: const EdgeInsets.all(AppSpacing.paddingLG),
                    decoration: BoxDecoration(
                      color: AuthColors.backgroundAlt,
                      borderRadius: BorderRadius.circular(AppSpacing.radiusLG),
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
                        const SizedBox(height: AppSpacing.paddingXS),
                        Text(
                          widget.entry.primaryDisplayPhone,
                          style: const TextStyle(color: AuthColors.textMain, fontSize: 16),
                        ),
                      ],
                    ),
                  ),
                if (_errorMessage != null) ...[
                  const SizedBox(height: AppSpacing.paddingSM),
                  Text(
                    _errorMessage!,
                    style: const TextStyle(color: AuthColors.error),
                  ),
                ],
                const SizedBox(height: AppSpacing.paddingXXL),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _isSaving ? null : _handleSave,
                    style: FilledButton.styleFrom(
                      backgroundColor: AuthColors.primary,
                      foregroundColor: AuthColors.textMain,
                      padding: const EdgeInsets.symmetric(vertical: AppSpacing.paddingLG),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppSpacing.radiusLG),
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
      spacing: AppSpacing.paddingSM,
      runSpacing: AppSpacing.paddingSM,
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

