import 'package:core_bloc/core_bloc.dart';
import 'package:core_ui/core_ui.dart';
import 'package:dash_web/domain/entities/client.dart';
import 'package:dash_web/presentation/blocs/clients/clients_cubit.dart';
import 'package:dash_web/presentation/widgets/client_detail_modal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';

class ClientsPageContent extends StatefulWidget {
  const ClientsPageContent({super.key});

  @override
  State<ClientsPageContent> createState() => _ClientsPageContentState();
}

enum _ClientSortOption {
  nameAsc,
  nameDesc,
  ordersHigh,
  ordersLow,
  corporateFirst,
  individualFirst,
}

enum _ClientFilterType {
  all,
  corporate,
  individual,
}

class _ClientsPageContentState extends State<ClientsPageContent> {
  String _query = '';
  _ClientSortOption _sortOption = _ClientSortOption.nameAsc;
  _ClientFilterType _filterType = _ClientFilterType.all;
  final ScrollController _scrollController = ScrollController();
  final Map<String, String> _searchIndexCache = {};
  String? _lastSearchIndexHash;

  // Caching for filtered/sorted results to avoid recomputation
  List<Client>? _cachedFilteredClients;
  String? _cachedQuery;
  _ClientFilterType? _cachedFilterType;
  _ClientSortOption? _cachedSortOption;
  List<Client>? _cachedInputClients;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    // Load clients and recent clients on init
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ClientsCubit>().loadClients();
    });
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.hasClients &&
        _scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent * 0.8) {
      // Load more if needed
    }
  }

  /// Memoized filter and sort logic to avoid recomputation on every build
  List<Client> _getFilteredAndSortedClients(List<Client> clients) {
    // Check if we can use cached result
    if (_cachedFilteredClients != null &&
        _cachedQuery == _query &&
        _cachedFilterType == _filterType &&
        _cachedSortOption == _sortOption &&
        _cachedInputClients?.length == clients.length) {
      return _cachedFilteredClients!;
    }

    // Apply search filter
    List<Client> filtered;
    if (_query.isEmpty) {
      filtered = [...clients];
    } else {
      final queryLower = _query.toLowerCase();
      final clientsHash = '${clients.length}_${clients.hashCode}';
      final searchIndex = _buildSearchIndex(clients, clientsHash);
      filtered = clients.where((c) {
        final indexText = searchIndex[c.id] ?? '';
        return indexText.contains(queryLower);
      }).toList();
    }

    // Apply type filter
    switch (_filterType) {
      case _ClientFilterType.corporate:
        filtered = filtered.where((c) => c.isCorporate).toList();
        break;
      case _ClientFilterType.individual:
        filtered = filtered.where((c) => !c.isCorporate).toList();
        break;
      case _ClientFilterType.all:
        break;
    }

    // Apply sorting
    switch (_sortOption) {
      case _ClientSortOption.nameAsc:
        filtered.sort((a, b) => a.name.compareTo(b.name));
        break;
      case _ClientSortOption.nameDesc:
        filtered.sort((a, b) => b.name.compareTo(a.name));
        break;
      case _ClientSortOption.ordersHigh:
        filtered.sort((a, b) {
          final aOrders = a.stats?['orders'] as num? ?? 0;
          final bOrders = b.stats?['orders'] as num? ?? 0;
          return bOrders.compareTo(aOrders);
        });
        break;
      case _ClientSortOption.ordersLow:
        filtered.sort((a, b) {
          final aOrders = a.stats?['orders'] as num? ?? 0;
          final bOrders = b.stats?['orders'] as num? ?? 0;
          return aOrders.compareTo(bOrders);
        });
        break;
      case _ClientSortOption.corporateFirst:
        filtered.sort((a, b) {
          if (a.isCorporate && !b.isCorporate) return -1;
          if (!a.isCorporate && b.isCorporate) return 1;
          return a.name.compareTo(b.name);
        });
        break;
      case _ClientSortOption.individualFirst:
        filtered.sort((a, b) {
          if (!a.isCorporate && b.isCorporate) return -1;
          if (a.isCorporate && !b.isCorporate) return 1;
          return a.name.compareTo(b.name);
        });
        break;
    }

    // Cache the result
    _cachedFilteredClients = filtered;
    _cachedQuery = _query;
    _cachedFilterType = _filterType;
    _cachedSortOption = _sortOption;
    _cachedInputClients = clients;

    return filtered;
  }

  Map<String, String> _buildSearchIndex(
    List<Client> clients,
    String clientsHash,
  ) {
    if (_lastSearchIndexHash == clientsHash && _searchIndexCache.isNotEmpty) {
      return _searchIndexCache;
    }

    _searchIndexCache.clear();
    for (final client in clients) {
      final buffer = StringBuffer();
      void add(String? value) {
        if (value == null) return;
        final trimmed = value.trim();
        if (trimmed.isEmpty) return;
        buffer.write(trimmed.toLowerCase());
        buffer.write(' ');
      }

      add(client.name);
      add(client.primaryPhone);
      if (client.tags.isNotEmpty) {
        buffer.write(client.tags.map((t) => t.toLowerCase()).join(' '));
        buffer.write(' ');
      }

      _searchIndexCache[client.id] = buffer.toString();
    }

    _lastSearchIndexHash = clientsHash;
    return _searchIndexCache;
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ClientsCubit, ClientsState>(
      builder: (context, state) {
        if (state.status == ViewStatus.loading && state.clients.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SkeletonLoader(
                    height: 40,
                    width: double.infinity,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  const SizedBox(height: 16),
                  ...List.generate(
                      8,
                      (_) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: SkeletonLoader(
                              height: 80,
                              width: double.infinity,
                              borderRadius: BorderRadius.circular(8),
                            ),
                          )),
                ],
              ),
            ),
          );
        }
        if (state.status == ViewStatus.failure && state.clients.isEmpty) {
          return _ErrorState(
            message: state.message ?? 'Failed to load clients',
            onRetry: () => context.read<ClientsCubit>().loadClients(),
          );
        }

        // Use server-side search results if query exists, otherwise filter local clients
        List<Client> displayClients =
            state.searchQuery.isNotEmpty ? state.searchResults : state.clients;
        List<Client> filtered = _getFilteredAndSortedClients(displayClients);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Statistics Dashboard
            BlocBuilder<ClientsCubit, ClientsState>(
              buildWhen: (previous, current) =>
                  previous.analytics != current.analytics,
              builder: (context, state) {
                final totalClients =
                    state.analytics?.totalActiveClients ?? state.clients.length;
                final corporateCount = state.analytics?.corporateCount ??
                    state.clients.where((c) => c.isCorporate).length;
                final individualCount = state.analytics?.individualCount ??
                    (totalClients - corporateCount);
                final totalOrders = state.analytics?.totalOrders ??
                    state.clients.fold<int>(
                        0,
                        (sum, client) =>
                            sum +
                            ((client.stats?['orders'] as num?)?.toInt() ?? 0));

                return _ClientsStatsHeader(
                  totalClients: totalClients,
                  corporateCount: corporateCount,
                  individualCount: individualCount,
                  totalOrders: totalOrders,
                );
              },
            ),
            const SizedBox(height: 32),

            // Top Action Bar with Filters
            Row(
              children: [
                // Search Bar
                Expanded(
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 400),
                    decoration: BoxDecoration(
                      color: AuthColors.surface.withOpacity(0.6),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: AuthColors.textSub.withOpacity(0.2),
                      ),
                    ),
                    child: TextField(
                      onChanged: (v) {
                        setState(() => _query = v);
                        context.read<ClientsCubit>().search(v);
                      },
                      style: const TextStyle(color: AuthColors.textMain),
                      decoration: InputDecoration(
                        hintText: 'Search clients by name, phone, or tags...',
                        hintStyle: const TextStyle(
                          color: AuthColors.textDisabled,
                        ),
                        filled: true,
                        fillColor: AuthColors.transparent,
                        prefixIcon:
                            const Icon(Icons.search, color: AuthColors.textSub),
                        suffixIcon: _query.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear,
                                    color: AuthColors.textSub),
                                onPressed: () {
                                  setState(() => _query = '');
                                  context.read<ClientsCubit>().search('');
                                },
                              )
                            : null,
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 16,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Type Filter
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AuthColors.surface.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AuthColors.textSub.withOpacity(0.2),
                    ),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<_ClientFilterType>(
                      value: _filterType,
                      dropdownColor: AuthColors.surface,
                      style: const TextStyle(
                          color: AuthColors.textMain, fontSize: 14),
                      items: const [
                        DropdownMenuItem(
                          value: _ClientFilterType.all,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.people,
                                  size: 16, color: AuthColors.textSub),
                              SizedBox(width: 6),
                              Text('All Clients'),
                            ],
                          ),
                        ),
                        DropdownMenuItem(
                          value: _ClientFilterType.corporate,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.business,
                                  size: 16, color: AuthColors.textSub),
                              SizedBox(width: 6),
                              Text('Corporate'),
                            ],
                          ),
                        ),
                        DropdownMenuItem(
                          value: _ClientFilterType.individual,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.person,
                                  size: 16, color: AuthColors.textSub),
                              SizedBox(width: 6),
                              Text('Individual'),
                            ],
                          ),
                        ),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => _filterType = value);
                        }
                      },
                      icon: const Icon(Icons.arrow_drop_down,
                          color: AuthColors.textSub, size: 20),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Sort Options
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AuthColors.surface.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AuthColors.textSub.withOpacity(0.2),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.sort,
                          size: 16, color: AuthColors.textSub),
                      const SizedBox(width: 6),
                      DropdownButtonHideUnderline(
                        child: DropdownButton<_ClientSortOption>(
                          value: _sortOption,
                          dropdownColor: AuthColors.surface,
                          style: const TextStyle(
                              color: AuthColors.textMain, fontSize: 14),
                          items: const [
                            DropdownMenuItem(
                              value: _ClientSortOption.nameAsc,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.sort_by_alpha,
                                      size: 16, color: AuthColors.textSub),
                                  SizedBox(width: 8),
                                  Text('Name (A-Z)'),
                                ],
                              ),
                            ),
                            DropdownMenuItem(
                              value: _ClientSortOption.nameDesc,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.sort_by_alpha,
                                      size: 16, color: AuthColors.textSub),
                                  SizedBox(width: 8),
                                  Text('Name (Z-A)'),
                                ],
                              ),
                            ),
                            DropdownMenuItem(
                              value: _ClientSortOption.ordersHigh,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.trending_down,
                                      size: 16, color: AuthColors.textSub),
                                  SizedBox(width: 8),
                                  Text('Orders (High to Low)'),
                                ],
                              ),
                            ),
                            DropdownMenuItem(
                              value: _ClientSortOption.ordersLow,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.trending_up,
                                      size: 16, color: AuthColors.textSub),
                                  SizedBox(width: 8),
                                  Text('Orders (Low to High)'),
                                ],
                              ),
                            ),
                            DropdownMenuItem(
                              value: _ClientSortOption.corporateFirst,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.business,
                                      size: 16, color: AuthColors.textSub),
                                  SizedBox(width: 8),
                                  Text('Corporate First'),
                                ],
                              ),
                            ),
                            DropdownMenuItem(
                              value: _ClientSortOption.individualFirst,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.person,
                                      size: 16, color: AuthColors.textSub),
                                  SizedBox(width: 8),
                                  Text('Individual First'),
                                ],
                              ),
                            ),
                          ],
                          onChanged: (value) {
                            if (value != null) {
                              setState(() => _sortOption = value);
                            }
                          },
                          icon: const Icon(Icons.arrow_drop_down,
                              color: AuthColors.textSub, size: 20),
                          isDense: true,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                // Results count
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AuthColors.surface.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AuthColors.textSub.withOpacity(0.2),
                    ),
                  ),
                  child: Text(
                    '${filtered.length} ${filtered.length == 1 ? 'client' : 'clients'}',
                    style: const TextStyle(
                      color: AuthColors.textSub,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Add Client Button
                DashButton(
                  icon: Icons.add,
                  label: 'Add Client',
                  onPressed: () => _showClientDialog(context, null),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Client List
            if (filtered.isEmpty &&
                (_query.isNotEmpty || _filterType != _ClientFilterType.all))
              _EmptySearchState(query: _query)
            else if (filtered.isEmpty)
              _EmptyClientsState(
                onAddClient: () => _showClientDialog(context, null),
              )
            else
              _ClientListView(
                clients: filtered,
                hasMore: state.hasMore && state.searchQuery.isEmpty,
                isLoadingMore: state.isLoadingMore,
                onLoadMore: () =>
                    context.read<ClientsCubit>().loadMoreClients(),
                onTap: (client) => _openClientDetail(client),
                onEdit: (client) => _showClientDialog(context, client),
                onDelete: (client) => _showDeleteConfirmation(context, client),
              ),
          ],
        );
      },
    );
  }

  void _openClientDetail(Client client) {
    showDialog(
      context: context,
      builder: (dialogContext) => ClientDetailModal(
        client: client,
        onClientChanged: (updatedClient) {
          // Refresh clients list if needed
          context.read<ClientsCubit>().loadClients();
        },
        onEdit: () => _showClientDialog(context, client),
      ),
    );
  }
}

void _showClientDialog(BuildContext context, Client? client) {
  final cubit = context.read<ClientsCubit>();
  showDialog(
    context: context,
    builder: (dialogContext) => _ClientDialog(
      client: client,
      clientsCubit: cubit,
    ),
  );
}

void _showDeleteConfirmation(BuildContext context, Client client) {
  showDialog(
    context: context,
    builder: (dialogContext) => AlertDialog(
      backgroundColor: AuthColors.surface,
      title: const Text(
        'Delete Client',
        style: TextStyle(color: AuthColors.textMain),
      ),
      content: Text(
        'Are you sure you want to delete ${client.name}?',
        style: const TextStyle(color: AuthColors.textSub),
      ),
      actions: [
        DashButton(
          label: 'Cancel',
          onPressed: () => Navigator.of(dialogContext).pop(),
          variant: DashButtonVariant.text,
        ),
        DashButton(
          label: 'Delete',
          onPressed: () {
            context.read<ClientsCubit>().deleteClient(client.id);
            Navigator.of(dialogContext).pop();
          },
          variant: DashButtonVariant.text,
          isDestructive: true,
        ),
      ],
    ),
  );
}

class _ClientDialog extends StatefulWidget {
  const _ClientDialog({
    this.client,
    required this.clientsCubit,
  });

  final Client? client;
  final ClientsCubit clientsCubit;

  @override
  State<_ClientDialog> createState() => _ClientDialogState();
}

class _ClientDialogState extends State<_ClientDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  final List<String> _tags = [];
  final TextEditingController _tagController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final client = widget.client;
    _nameController = TextEditingController(text: client?.name ?? '');
    _phoneController = TextEditingController(text: client?.primaryPhone ?? '');
    if (client != null) {
      _tags.addAll(client.tags);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _tagController.dispose();
    super.dispose();
  }

  void _addTag() {
    final tag = _tagController.text.trim();
    if (tag.isNotEmpty && !_tags.contains(tag)) {
      setState(() {
        _tags.add(tag);
        _tagController.clear();
      });
    }
  }

  void _removeTag(String tag) {
    setState(() {
      _tags.remove(tag);
    });
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.client != null;

    return Dialog(
      backgroundColor: AuthColors.transparent,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AuthColors.surface,
              AuthColors.background,
            ],
          ),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: AuthColors.textSub.withOpacity(0.2),
          ),
          boxShadow: [
            BoxShadow(
              color: AuthColors.background.withOpacity(0.7),
              blurRadius: 30,
              spreadRadius: -10,
              offset: const Offset(0, 20),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AuthColors.surface,
                    AuthColors.backgroundAlt,
                  ],
                ),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(24),
                ),
                border: Border(
                  bottom: BorderSide(
                    color: AuthColors.textMain.withValues(alpha: 0.08),
                  ),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AuthColors.primaryWithOpacity(0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      isEditing ? Icons.edit : Icons.person_add,
                      color: AuthColors.primary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      isEditing ? 'Edit Client' : 'Add Client',
                      style: const TextStyle(
                        color: AuthColors.textMain,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: AuthColors.textSub),
                    onPressed: () => Navigator.of(context).pop(),
                    tooltip: 'Close',
                  ),
                ],
              ),
            ),

            // Content
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextFormField(
                        controller: _nameController,
                        style: const TextStyle(color: AuthColors.textMain),
                        decoration: _inputDecoration(
                            'Client name', Icons.person_outline),
                        validator: (value) =>
                            (value == null || value.trim().isEmpty)
                                ? 'Enter client name'
                                : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        style: const TextStyle(color: AuthColors.textMain),
                        decoration: _inputDecoration(
                            'Primary phone', Icons.phone_outlined),
                        validator: (value) =>
                            (value == null || value.trim().isEmpty)
                                ? 'Enter primary phone'
                                : null,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Tags',
                        style: TextStyle(
                          color: AuthColors.textSub,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _tagController,
                              style:
                                  const TextStyle(color: AuthColors.textMain),
                              decoration: InputDecoration(
                                hintText: 'Enter tag and press Enter',
                                hintStyle: TextStyle(
                                  color:
                                      AuthColors.textSub.withValues(alpha: 0.6),
                                ),
                                prefixIcon: const Icon(Icons.tag,
                                    color: AuthColors.textSub, size: 20),
                                filled: true,
                                fillColor: AuthColors.surface,
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                    color: AuthColors.textMain
                                        .withValues(alpha: 0.1),
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(
                                    color: AuthColors.primary,
                                    width: 2,
                                  ),
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 16,
                                ),
                              ),
                              onFieldSubmitted: (_) => _addTag(),
                            ),
                          ),
                          const SizedBox(width: 12),
                          DashButton(
                            icon: Icons.add,
                            label: 'Add',
                            onPressed: _addTag,
                          ),
                        ],
                      ),
                      if (_tags.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _tags.map((tag) {
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: AuthColors.primaryWithOpacity(0.2),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: AuthColors.primaryWithOpacity(0.3),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    tag,
                                    style: const TextStyle(
                                      color: AuthColors.textMain,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  GestureDetector(
                                    onTap: () => _removeTag(tag),
                                    child: const Icon(
                                      Icons.close,
                                      size: 16,
                                      color: AuthColors.textSub,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),

            // Footer Actions
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: AuthColors.textMain.withValues(alpha: 0.08),
                  ),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  DashButton(
                    label: 'Cancel',
                    onPressed: () => Navigator.of(context).pop(),
                    variant: DashButtonVariant.text,
                  ),
                  const SizedBox(width: 12),
                  DashButton(
                    icon: isEditing ? Icons.check : Icons.add,
                    label: isEditing ? 'Save Changes' : 'Create Client',
                    onPressed: () {
                      if (!(_formKey.currentState?.validate() ?? false)) return;

                      if (widget.client == null) {
                        widget.clientsCubit.createClient(
                          name: _nameController.text.trim(),
                          primaryPhone: _phoneController.text.trim(),
                          phones: [],
                          tags: _tags,
                        );
                      } else {
                        final updatedClient = Client(
                          id: widget.client!.id,
                          name: _nameController.text.trim(),
                          primaryPhone: _phoneController.text.trim(),
                          phones: widget.client!.phones,
                          phoneIndex: widget.client!.phoneIndex,
                          tags: _tags,
                          status: widget.client!.status,
                          organizationId: widget.client!.organizationId,
                          createdAt: widget.client!.createdAt,
                          stats: widget.client!.stats,
                        );
                        widget.clientsCubit.updateClient(updatedClient);
                      }
                      Navigator.of(context).pop();
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: AuthColors.textSub, size: 20),
      filled: true,
      fillColor: AuthColors.surface,
      labelStyle: const TextStyle(color: AuthColors.textSub),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: AuthColors.textMain.withValues(alpha: 0.1),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(
          color: AuthColors.primary,
          width: 2,
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(
          color: AuthColors.error,
        ),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(
          color: AuthColors.error,
          width: 2,
        ),
      ),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 16,
      ),
    );
  }
}

class _ClientsStatsHeader extends StatelessWidget {
  const _ClientsStatsHeader({
    required this.totalClients,
    required this.corporateCount,
    required this.individualCount,
    required this.totalOrders,
  });

  final int totalClients;
  final int corporateCount;
  final int individualCount;
  final int totalOrders;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 1000;
        return isWide
            ? Row(
                children: [
                  Expanded(
                    child: _StatCard(
                      icon: Icons.people_outline,
                      label: 'Total Clients',
                      value: totalClients.toString(),
                      color: AuthColors.primary,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _StatCard(
                      icon: Icons.business_outlined,
                      label: 'Corporate',
                      value: corporateCount.toString(),
                      color: AuthColors.success,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _StatCard(
                      icon: Icons.person_outline,
                      label: 'Individual',
                      value: individualCount.toString(),
                      color: AuthColors.secondary,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _StatCard(
                      icon: Icons.shopping_bag_outlined,
                      label: 'Total Orders',
                      value: totalOrders.toString(),
                      color: AuthColors.primary,
                    ),
                  ),
                ],
              )
            : Wrap(
                spacing: 16,
                runSpacing: 16,
                children: [
                  _StatCard(
                    icon: Icons.people_outline,
                    label: 'Total Clients',
                    value: totalClients.toString(),
                    color: AuthColors.primary,
                  ),
                  _StatCard(
                    icon: Icons.business_outlined,
                    label: 'Corporate',
                    value: corporateCount.toString(),
                    color: AuthColors.success,
                  ),
                  _StatCard(
                    icon: Icons.person_outline,
                    label: 'Individual',
                    value: individualCount.toString(),
                    color: AuthColors.secondary,
                  ),
                  _StatCard(
                    icon: Icons.shopping_bag_outlined,
                    label: 'Total Orders',
                    value: totalOrders.toString(),
                    color: AuthColors.primary,
                  ),
                ],
              );
      },
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return DashCard(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: AuthColors.textSub,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    color: AuthColors.textMain,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(40),
        decoration: BoxDecoration(
          color: AuthColors.surface.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: AuthColors.error.withValues(alpha: 0.3),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: AuthColors.error.withValues(alpha: 0.7),
            ),
            const SizedBox(height: 16),
            const Text(
              'Failed to load clients',
              style: TextStyle(
                color: AuthColors.textMain,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: const TextStyle(
                color: AuthColors.textSub,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            DashButton(
              icon: Icons.refresh,
              label: 'Retry',
              onPressed: onRetry,
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyClientsState extends StatelessWidget {
  const _EmptyClientsState({required this.onAddClient});

  final VoidCallback onAddClient;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(48),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AuthColors.surface.withValues(alpha: 0.6),
              AuthColors.backgroundAlt.withValues(alpha: 0.8),
            ],
          ),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: AuthColors.textMain.withValues(alpha: 0.1),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AuthColors.primaryWithOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.people_outline,
                size: 40,
                color: AuthColors.primary,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'No clients yet',
              style: TextStyle(
                color: AuthColors.textMain,
                fontSize: 24,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Start by adding your first client to the system',
              style: TextStyle(
                color: AuthColors.textSub,
                fontSize: 16,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            DashButton(
              icon: Icons.add,
              label: 'Add Client',
              onPressed: onAddClient,
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptySearchState extends StatelessWidget {
  const _EmptySearchState({required this.query});

  final String query;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.search_off,
              size: 64,
              color: AuthColors.textSub.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 16),
            const Text(
              'No results found',
              style: TextStyle(
                color: AuthColors.textMain,
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'No clients match "$query"',
              style: const TextStyle(
                color: AuthColors.textSub,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ClientListView extends StatelessWidget {
  const _ClientListView({
    required this.clients,
    this.hasMore = false,
    this.isLoadingMore = false,
    this.onLoadMore,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  final List<Client> clients;
  final bool hasMore;
  final bool isLoadingMore;
  final VoidCallback? onLoadMore;
  final ValueChanged<Client> onTap;
  final ValueChanged<Client> onEdit;
  final ValueChanged<Client> onDelete;

  Color _getClientColor(Client client) {
    if (client.isCorporate) {
      return AuthColors.primary;
    }
    final hash = client.name.hashCode;
    final colors = [
      AuthColors.success,
      AuthColors.secondary,
      AuthColors.primary,
      AuthColors.error,
    ];
    return colors[hash.abs() % colors.length];
  }

  String _getInitials(String name) {
    final parts = name.split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.length >= 2
        ? name.substring(0, 2).toUpperCase()
        : name.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final itemCount = clients.length + (hasMore ? 1 : 0);
    return AnimationLimiter(
      child: ListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: itemCount,
        itemBuilder: (context, index) {
          if (index >= clients.length) {
            return Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 24),
              child: Center(
                child: isLoadingMore
                    ? const Padding(
                        padding: EdgeInsets.all(16),
                        child: SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AuthColors.primary,
                          ),
                        ),
                      )
                    : DashButton(
                        label: 'Load more',
                        icon: Icons.add_circle_outline,
                        onPressed: onLoadMore,
                        variant: DashButtonVariant.outlined,
                      ),
              ),
            );
          }
          final client = clients[index];
          final clientColor = _getClientColor(client);
          final orderCount = client.stats?['orders'] ?? 0;
          final phoneLabel = client.primaryPhone ?? '';
          final subtitleParts = <String>[];
          if (phoneLabel.isNotEmpty) subtitleParts.add(phoneLabel);
          if (client.isCorporate) subtitleParts.add('Corporate');
          final subtitle = subtitleParts.join(' • ');

          // Animate only first 20 items to keep frame rate smooth with large datasets
          const int maxAnimatedItems = 20;
          final content = Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: AuthColors.background,
              borderRadius: BorderRadius.circular(18),
            ),
            child: DataList(
              title: client.name,
              subtitle: subtitle.isNotEmpty ? subtitle : null,
              leading: DataListAvatar(
                initial: _getInitials(client.name),
                radius: 28,
                statusRingColor: clientColor,
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (orderCount > 0)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AuthColors.success.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.shopping_bag_outlined,
                                size: 12, color: AuthColors.success),
                            const SizedBox(width: 4),
                            Text(
                              orderCount.toString(),
                              style: const TextStyle(
                                color: AuthColors.success,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  IconButton(
                    icon: const Icon(Icons.visibility_outlined,
                        size: 20, color: AuthColors.textSub),
                    onPressed: () => onTap(client),
                    tooltip: 'View Details',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    icon: const Icon(Icons.edit_outlined,
                        size: 20, color: AuthColors.textSub),
                    onPressed: () => onEdit(client),
                    tooltip: 'Edit',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    icon: const Icon(Icons.delete_outline,
                        size: 20, color: AuthColors.error),
                    onPressed: () => onDelete(client),
                    tooltip: 'Delete',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              onTap: () => onTap(client),
            ),
          );
          if (index < maxAnimatedItems) {
            return AnimationConfiguration.staggeredList(
              position: index,
              duration: const Duration(milliseconds: 200),
              child: SlideAnimation(
                verticalOffset: 50.0,
                child: FadeInAnimation(
                  curve: Curves.easeOut,
                  child: content,
                ),
              ),
            );
          }
          return content;
        },
      ),
    );
  }
}
