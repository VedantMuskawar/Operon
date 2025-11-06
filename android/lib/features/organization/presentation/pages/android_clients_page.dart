import 'dart:async';
import 'package:flutter/material.dart';
import '../../../../core/app_theme.dart';
import '../../repositories/android_client_repository.dart';
import '../../models/client.dart';
import 'android_client_overview_page.dart';
import 'android_create_order_page.dart';

class AndroidClientsPage extends StatefulWidget {
  final String organizationId;

  const AndroidClientsPage({
    super.key,
    required this.organizationId,
  });

  @override
  State<AndroidClientsPage> createState() => _AndroidClientsPageState();
}

class _AndroidClientsPageState extends State<AndroidClientsPage> {
  final AndroidClientRepository _repository = AndroidClientRepository();
  final TextEditingController _searchController = TextEditingController();
  late final ScrollController _scrollController;
  static const int _pageSize = 50;
  
  List<Client> _allClients = [];
  List<Client> _filteredClients = [];
  bool _isInitialLoading = true;
  bool _isRefreshing = false;
  bool _isSearching = false;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  String _searchQuery = '';
  String? _loadError;
  Timer? _debounceTimer;
  static const Duration _debounceDelay = Duration(milliseconds: 400);
  final Map<String, String> _clientNameLowercase = {};
  final Map<String, List<String>> _clientPhoneDigits = {};
  bool _searchDataPrepared = false;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController()..addListener(_onScroll);
    _searchController.addListener(_onSearchChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final cachedClients = _repository.getCachedClientsList(widget.organizationId);
      if (cachedClients.isNotEmpty && mounted) {
        setState(() {
          _updateClientLists(cachedClients);
          _isInitialLoading = false;
        });
      }
      _refreshClients();
    });
  }

  void _prepareSearchData(List<Client> clients) {
    _clientNameLowercase.clear();
    _clientPhoneDigits.clear();

    for (final client in clients) {
      final clientId = client.clientId;
      _clientNameLowercase[clientId] = client.name.toLowerCase();

      final digitsSet = <String>{};

      void addPhone(String? phone) {
        if (phone == null || phone.isEmpty) return;
        final digits = phone.replaceAll(RegExp(r'[^\d]'), '');
        if (digits.isNotEmpty) {
          digitsSet.add(digits);
        }
      }

      addPhone(client.phoneNumber);
      if (client.phoneList != null) {
        for (final phone in client.phoneList!) {
          addPhone(phone);
        }
      }

      _clientPhoneDigits[clientId] = digitsSet.toList();
    }

    _searchDataPrepared = true;
  }

  List<Client> _filterClientsByQuery(String query, List<Client> clients) {
    final trimmedQuery = query.trim().toLowerCase();
    if (trimmedQuery.isEmpty) {
      return List<Client>.from(clients);
    }

    final queryDigits = trimmedQuery.replaceAll(RegExp(r'[^\d]'), '');
    final results = <Client>[];

    for (final client in clients) {
      final clientId = client.clientId;
      final nameLower = _clientNameLowercase[clientId] ?? client.name.toLowerCase();

      final emailLower = client.email?.toLowerCase() ?? '';
      final tagMatch = client.tags?.any((tag) => tag.toLowerCase().contains(trimmedQuery)) ?? false;

      if (nameLower.contains(trimmedQuery) ||
          client.phoneNumber.toLowerCase().contains(trimmedQuery) ||
          emailLower.contains(trimmedQuery) ||
          tagMatch) {
        results.add(client);
        continue;
      }

      if (queryDigits.isNotEmpty) {
        final phoneDigitsList = _clientPhoneDigits[clientId] ?? const [];
        final matchesPhone = phoneDigitsList.any((digits) => digits.contains(queryDigits));
        if (matchesPhone) {
          results.add(client);
        }
      }
    }

    return results;
  }

  void _updateClientLists(List<Client> clients) {
    _allClients = List<Client>.from(clients);
    _prepareSearchData(_allClients);
    if (_searchQuery.isNotEmpty) {
      _filteredClients = _filterClientsByQuery(_searchQuery, _allClients);
    } else {
      _filteredClients = List<Client>.from(_allClients);
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final query = _searchController.text;

    _debounceTimer?.cancel();

    if (query.isEmpty) {
      setState(() {
        _searchQuery = '';
        _filteredClients = List.from(_allClients);
        _isSearching = false;
      });
      return;
    }

    setState(() {
      _searchQuery = query;
      _isSearching = true;
    });

    _debounceTimer = Timer(_debounceDelay, () {
      if (!mounted) return;
      _performSearch(query);
    });
  }

  void _performSearch(String query) {
    final trimmedQuery = query.trim().toLowerCase();

    if (trimmedQuery.isEmpty) {
      setState(() {
        _filteredClients = List.from(_allClients);
        _isSearching = false;
      });
      return;
    }

    if (!_searchDataPrepared) {
      _prepareSearchData(_allClients);
    }

    final results = _filterClientsByQuery(query, _allClients);

    setState(() {
      _filteredClients = results;
      _isSearching = false;
    });
  }

  void _onScroll() {
    if (_isLoadingMore || !_hasMore) {
      return;
    }
    if (!_scrollController.hasClients) {
      return;
    }
    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 200) {
      _loadMoreClients();
    }
  }

  Future<void> _refreshClients() async {
    setState(() {
      _isRefreshing = true;
      _loadError = null;
    });

    try {
      final result = await _repository.getClientsPage(
        widget.organizationId,
        limit: _pageSize,
        reset: true,
      );

      final updatedClients = result.allClients.isNotEmpty
          ? result.allClients
          : _repository.getCachedClientsList(widget.organizationId);

      if (!mounted) return;

      setState(() {
        _hasMore = result.hasMore;
        _isRefreshing = false;
        _isInitialLoading = false;
        _loadError = null;
        _updateClientLists(updatedClients);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isRefreshing = false;
        _isInitialLoading = _allClients.isEmpty;
        _loadError = e.toString();
      });
    }
  }

  Future<void> _loadMoreClients() async {
    if (_isLoadingMore || !_hasMore) {
      return;
    }

    setState(() {
      _isLoadingMore = true;
      _loadError = null;
    });

    try {
      final result = await _repository.getClientsPage(
        widget.organizationId,
        limit: _pageSize,
      );

      if (!mounted) return;

      setState(() {
        _hasMore = result.hasMore;
        _isLoadingMore = false;
        if (result.allClients.isNotEmpty) {
          _updateClientLists(result.allClients);
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoadingMore = false;
        _loadError = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Clients',
          style: TextStyle(
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
        backgroundColor: AppTheme.surfaceColor,
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
                hintText: 'Search clients by name, phone, email, or tags...',
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
            ),
          ),
          
          // Clients List
          Expanded(
            child: _buildClientsList(context),
          ),
        ],
      ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AndroidCreateOrderPage(
                organizationId: widget.organizationId,
              ),
            ),
          ).then((result) {
            if (result == true) {
              _refreshClients();
            }
          });
        },
        backgroundColor: AppTheme.primaryColor,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildClientsList(BuildContext context) {
    if (_isInitialLoading && _filteredClients.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_loadError != null && _filteredClients.isEmpty) {
      return RefreshIndicator(
        onRefresh: _refreshClients,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            _buildClientsErrorState(context, _loadError!),
          ],
        ),
      );
    }

    if (_filteredClients.isEmpty) {
      return RefreshIndicator(
        onRefresh: _refreshClients,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            _buildEmptyState(context),
          ],
        ),
      );
    }

    final showInlineError = _loadError != null && !_isRefreshing;
    final headerCount = showInlineError ? 1 : 0;
    final footerCount = _isLoadingMore ? 1 : 0;
    final totalCount = _filteredClients.length + headerCount + footerCount;

    return RefreshIndicator(
      onRefresh: _refreshClients,
      child: ListView.builder(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        itemCount: totalCount,
        itemBuilder: (context, index) {
          if (showInlineError && index == 0) {
            return _buildInlineErrorBanner();
          }

          final adjustedIndex = index - headerCount;
          if (adjustedIndex >= _filteredClients.length) {
            return _buildLoadingMoreIndicator();
          }

          final client = _filteredClients[adjustedIndex];
          return _buildClientCard(client);
        },
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final height = MediaQuery.of(context).size.height;
    return SizedBox(
      height: height * 0.5,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            _searchQuery.isEmpty ? Icons.people_outline : Icons.search_off,
            size: 64,
            color: AppTheme.textSecondaryColor,
          ),
          const SizedBox(height: 16),
          Text(
            _searchQuery.isEmpty ? 'No Clients Found' : 'No Matching Clients',
            style: const TextStyle(
              color: AppTheme.textPrimaryColor,
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _searchQuery.isEmpty
                ? 'Start by adding clients'
                : 'Try a different search query',
            style: const TextStyle(
              color: AppTheme.textSecondaryColor,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClientsErrorState(BuildContext context, String message) {
    final height = MediaQuery.of(context).size.height;
    return SizedBox(
      height: height * 0.5,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.error_outline,
            size: 64,
            color: AppTheme.errorColor,
          ),
          const SizedBox(height: 16),
          const Text(
            'Unable to load clients',
            style: TextStyle(
              color: AppTheme.textPrimaryColor,
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppTheme.textSecondaryColor,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => _refreshClients(),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
            ),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildInlineErrorBanner() {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.errorColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppTheme.errorColor.withValues(alpha: 0.25),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: AppTheme.errorColor),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _loadError ?? 'Something went wrong',
              style: const TextStyle(color: AppTheme.textPrimaryColor),
            ),
          ),
          TextButton(
            onPressed: () => _refreshClients(),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingMoreIndicator() {
    if (!_isLoadingMore) {
      return const SizedBox.shrink();
    }
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 16),
      child: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }

  Widget _buildClientCard(Client client) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppTheme.borderColor,
          width: 1,
        ),
      ),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AndroidClientOverviewPage(
                organizationId: widget.organizationId,
                clientId: client.clientId,
              ),
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.2),
                radius: 28,
                child: Text(
                  client.name.isNotEmpty ? client.name[0].toUpperCase() : '?',
                  style: TextStyle(
                    color: AppTheme.primaryColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      client.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimaryColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.phone,
                          size: 14,
                          color: AppTheme.textSecondaryColor,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          client.phoneNumber,
                          style: const TextStyle(
                            fontSize: 14,
                            color: AppTheme.textSecondaryColor,
                          ),
                        ),
                      ],
                    ),
                    if (client.email != null && client.email!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.email,
                            size: 14,
                            color: AppTheme.textSecondaryColor,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              client.email!,
                              style: const TextStyle(
                                fontSize: 14,
                                color: AppTheme.textSecondaryColor,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: AppTheme.textSecondaryColor,
              ),
            ],
          ),
        ),
      ),
    );
  }
}


