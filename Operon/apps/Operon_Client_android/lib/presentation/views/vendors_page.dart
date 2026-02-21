import 'package:core_bloc/core_bloc.dart';
import 'package:core_ui/core_ui.dart';
import 'package:core_models/core_models.dart';
import 'package:dash_mobile/presentation/blocs/vendors/vendors_cubit.dart';
import 'package:dash_mobile/presentation/blocs/vendors/vendors_state.dart';
import 'package:dash_mobile/presentation/views/vendors_page/vendor_analytics_page.dart';
import 'package:dash_mobile/presentation/widgets/modern_page_header.dart';
import 'package:dash_mobile/presentation/widgets/standard_search_bar.dart';
import 'package:dash_mobile/presentation/widgets/empty/empty_state_widget.dart';
import 'package:dash_mobile/presentation/widgets/error/error_state_widget.dart';
import 'package:dash_mobile/presentation/utils/debouncer.dart';
import 'package:dash_mobile/shared/constants/app_spacing.dart';
import 'package:dash_mobile/shared/constants/constants.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:go_router/go_router.dart';

class VendorsPage extends StatefulWidget {
  const VendorsPage({super.key});

  @override
  State<VendorsPage> createState() => _VendorsPageState();
}

class _VendorsPageState extends State<VendorsPage> {
  late final TextEditingController _searchController;
  late final PageController _pageController;
  late final ScrollController _scrollController;
  late final Debouncer _searchDebouncer;
  double _currentPage = 0;
  final bool _isLoadingMore = false;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _searchDebouncer = Debouncer(duration: const Duration(milliseconds: 300));
    _searchController = TextEditingController()
      ..addListener(_handleSearchChanged);
    _pageController = PageController()
      ..addListener(_onPageChanged);
    _scrollController = ScrollController()
      ..addListener(_onScroll);
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

  void _onScroll() {
    if (_scrollController.hasClients &&
        _scrollController.position.pixels >= 
        _scrollController.position.maxScrollExtent * 0.8) {
      // Load more if needed - placeholder for future pagination
    }
  }

  @override
  void dispose() {
    _searchController.removeListener(_handleSearchChanged);
    _searchController.dispose();
    _pageController.removeListener(_onPageChanged);
    _pageController.dispose();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _searchDebouncer.dispose();
    super.dispose();
  }

  void _handleSearchChanged() {
    _searchDebouncer.run(() {
      if (mounted) {
        setState(() {
          _searchQuery = _searchController.text;
        });
        context.read<VendorsCubit>().search(_searchController.text);
      }
    });
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() {
      _searchQuery = '';
    });
    context.read<VendorsCubit>().search('');
  }

  void _showVendorDialog(BuildContext context, Vendor? vendor) {
    showDialog(
      context: context,
      builder: (dialogContext) => _VendorDialog(vendor: vendor),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AuthColors.background,
      appBar: const ModernPageHeader(
        title: 'Vendors',
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showVendorDialog(context, null),
        icon: const Icon(Icons.add),
        label: const Text('Add Vendor'),
      ),
      body: SafeArea(
        child: BlocListener<VendorsCubit, VendorsState>(
          listener: (context, state) {
            if (state.status == ViewStatus.failure && state.message != null) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(state.message!)),
              );
            }
          },
          child: Column(
            children: [
              Expanded(
                child: Column(
                  children: [
                    Expanded(
                      child: PageView(
                        controller: _pageController,
                        physics: const PageScrollPhysics(),
                        children: [
                          _VendorsListView(
                            scrollController: _scrollController,
                            isLoadingMore: _isLoadingMore,
                            searchController: _searchController,
                            searchQuery: _searchQuery,
                            onClearSearch: _clearSearch,
                            onEditVendor: (vendor) =>
                                _showVendorDialog(context, vendor),
                          ),
                          const VendorAnalyticsPage(),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.paddingSM),
                    _CompactPageIndicator(
                      pageCount: 2,
                      currentIndex: _currentPage,
                    ),
                    const SizedBox(height: AppSpacing.paddingLG),
                  ],
                ),
              ),
              FloatingNavBar(
                items: const [
                  NavBarItem(
                    icon: Icons.home_rounded,
                    label: 'Home',
                    heroTag: 'nav_home',
                  ),
                  NavBarItem(
                    icon: Icons.pending_actions_rounded,
                    label: 'Pending',
                    heroTag: 'nav_pending',
                  ),
                  NavBarItem(
                    icon: Icons.schedule_rounded,
                    label: 'Schedule',
                    heroTag: 'nav_schedule',
                  ),
                  NavBarItem(
                    icon: Icons.map_rounded,
                    label: 'Map',
                    heroTag: 'nav_map',
                  ),
                  NavBarItem(
                    icon: Icons.event_available_rounded,
                    label: 'Cash Ledger',
                    heroTag: 'nav_cash_ledger',
                  ),
                ],
                currentIndex: -1, // -1 means no selection when on this page
                onItemTapped: (value) => context.go('/home', extra: value),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _VendorsListView extends StatelessWidget {
  const _VendorsListView({
    required this.scrollController,
    required this.isLoadingMore,
    required this.searchController,
    required this.searchQuery,
    required this.onClearSearch,
    required this.onEditVendor,
  });

  final ScrollController scrollController;
  final bool isLoadingMore;
  final TextEditingController searchController;
  final String searchQuery;
  final VoidCallback onClearSearch;
  final ValueChanged<Vendor> onEditVendor;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<VendorsCubit, VendorsState>(
      buildWhen: (previous, current) {
        // Only rebuild when relevant state changes
        return previous.vendors != current.vendors ||
            previous.status != current.status;
      },
      builder: (context, state) {
        final allVendors = state.vendors;
        final filteredVendors = _getFilteredVendors(allVendors, searchQuery);

        // Error state
        if (state.status == ViewStatus.failure) {
          return SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              16,
              16,
              16,
              MediaQuery.of(context).viewInsets.bottom + 16,
            ),
            child: Column(
              children: [
                _buildSearchBar(context, state),
                const SizedBox(height: AppSpacing.paddingLG),
                _VendorFilterChips(
                  selectedType: state.selectedVendorType,
                  onTypeChanged: (type) {
                    context.read<VendorsCubit>().filterByType(type);
                  },
                ),
                const SizedBox(height: AppSpacing.paddingXXL),
                ErrorStateWidget(
                  message: state.message ?? 'Failed to load vendors',
                  errorType: ErrorType.network,
                  onRetry: () {
                    context.read<VendorsCubit>().load();
                  },
                ),
              ],
            ),
          );
        }

        return CustomScrollView(
          controller: scrollController,
          slivers: [
            SliverPadding(
              padding: EdgeInsets.fromLTRB(
                16,
                16,
                16,
                MediaQuery.of(context).viewInsets.bottom + 16,
              ),
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildSearchBar(context, state),
                    const SizedBox(height: AppSpacing.paddingLG),
                    _VendorFilterChips(
                      selectedType: state.selectedVendorType,
                      onTypeChanged: (type) {
                        context.read<VendorsCubit>().filterByType(type);
                      },
                    ),
                  ],
                ),
              ),
            ),
            if (state.status == ViewStatus.loading && allVendors.isEmpty)
              const SliverFillRemaining(
                child: Center(
                  child: CircularProgressIndicator(),
                ),
              )
            else if (searchQuery.isNotEmpty)
              SliverToBoxAdapter(
                child: _SearchResultsCard(
                  state: state,
                  vendors: filteredVendors,
                  onClear: onClearSearch,
                  searchQuery: searchQuery,
                ),
              )
            else if (filteredVendors.isEmpty && state.status != ViewStatus.loading)
              const SliverFillRemaining(
                child: _EmptyVendorsState(),
              )
            else ...[
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.paddingLG),
                sliver: AnimationLimiter(
                  child: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        if (index >= filteredVendors.length) {
                          return isLoadingMore
                              ? const Padding(
                                  padding: EdgeInsets.all(AppSpacing.paddingLG),
                                  child: Center(child: CircularProgressIndicator()),
                                )
                              : const SizedBox.shrink();
                        }
                        return AnimationConfiguration.staggeredList(
                          position: index,
                          duration: const Duration(milliseconds: 200),
                          child: SlideAnimation(
                            verticalOffset: 50.0,
                            child: FadeInAnimation(
                              curve: Curves.easeOut,
                              child: _VendorTile(
                                vendor: filteredVendors[index],
                                onEdit: () => onEditVendor(filteredVendors[index]),
                                onDelete: () => context.read<VendorsCubit>().deleteVendor(filteredVendors[index].id),
                              ),
                            ),
                          ),
                        );
                      },
                      childCount: filteredVendors.length + (isLoadingMore ? 1 : 0),
                    ),
                  ),
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  static final _filteredCache = <String, List<Vendor>>{};
  static String? _lastVendorsHash;
  static String? _lastSearchQuery;
  static final _searchIndexCache = <String, String>{};
  static String? _lastSearchIndexHash;

  Map<String, String> _buildSearchIndex(
    List<Vendor> vendors,
    String vendorsHash,
  ) {
    if (_lastSearchIndexHash == vendorsHash && _searchIndexCache.isNotEmpty) {
      return _searchIndexCache;
    }

    _searchIndexCache.clear();
    for (final vendor in vendors) {
      final buffer = StringBuffer();
      void add(String? value) {
        if (value == null) return;
        final trimmed = value.trim();
        if (trimmed.isEmpty) return;
        buffer.write(trimmed.toLowerCase());
        buffer.write(' ');
      }

      add(vendor.name);
      add(vendor.phoneNumber);
      add(vendor.gstNumber);

      _searchIndexCache[vendor.id] = buffer.toString();
    }

    _lastSearchIndexHash = vendorsHash;
    return _searchIndexCache;
  }

  List<Vendor> _getFilteredVendors(List<Vendor> vendors, String query) {
    // Cache key based on vendors hash and search query
    final vendorsHash = '${vendors.length}_${vendors.hashCode}';
    final cacheKey = '${vendorsHash}_$query';
    final searchIndex = _buildSearchIndex(vendors, vendorsHash);

    // Check if we can reuse cached result
    if (_lastVendorsHash == vendorsHash &&
        _lastSearchQuery == query &&
        _filteredCache.containsKey(cacheKey)) {
      return _filteredCache[cacheKey]!;
    }

    // Invalidate cache if vendors list changed
    if (_lastVendorsHash != vendorsHash) {
      _filteredCache.clear();
    }

    // Calculate filtered list
    final filtered = query.isEmpty
      ? vendors
      : vendors
        .where((v) {
          final indexText = searchIndex[v.id] ?? '';
          return indexText.contains(query.toLowerCase());
        })
        .toList();

    // Cache result
    _filteredCache[cacheKey] = filtered;
    _lastVendorsHash = vendorsHash;
    _lastSearchQuery = query;

    return filtered;
  }

  Widget _buildSearchBar(BuildContext context, VendorsState state) {
    return StandardSearchBar(
      controller: searchController,
      hintText: 'Search vendors by name, phone, or GST',
      onChanged: (value) {
        // The parent handles search state
      },
      onClear: onClearSearch,
    );
  }
}

class _SearchResultsCard extends StatelessWidget {
  const _SearchResultsCard({
    required this.state,
    required this.vendors,
    required this.onClear,
    required this.searchQuery,
  });

  final VendorsState state;
  final List<Vendor> vendors;
  final VoidCallback onClear;
  final String searchQuery;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.paddingXL),
      decoration: BoxDecoration(
        color: AuthColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusXL),
        border: Border.all(color: AuthColors.textMainWithOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Search Results',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AuthColors.textMain,
                  ),
                ),
              ),
              TextButton(
                onPressed: onClear,
                child: const Text('Clear'),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.paddingSM),
          if (state.status == ViewStatus.loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.paddingXL),
              child: Center(
                child: CircularProgressIndicator(),
              ),
            )
          else if (vendors.isEmpty)
            _EmptySearchState(query: searchQuery)
          else
            ...vendors.map((vendor) => Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.paddingMD),
                  child: _VendorTile(
                    vendor: vendor,
                  ),
                )),
        ],
      ),
    );
  }
}

class _VendorTile extends StatelessWidget {
  const _VendorTile({
    required this.vendor,
    this.onEdit,
    this.onDelete,
  });

  final Vendor vendor;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  Color _getVendorColor() {
    final hash = vendor.primaryVendorType.name.hashCode;
    final colors = [
      AuthColors.primary,
      AuthColors.success,
      AuthColors.secondary,
      AuthColors.primary,
      AuthColors.error,
      AuthColors.primary,
    ];
    return colors[hash.abs() % colors.length];
  }

  String _formatVendorTypes() {
    final formatted = vendor.effectiveVendorTypes
        .map((type) => type.name
            .split(RegExp(r'(?=[A-Z])'))
            .map((word) => word[0].toUpperCase() + word.substring(1))
            .join(' '))
        .toList();
    if (formatted.length <= 2) {
      return formatted.join(', ');
    }
    return '${formatted.take(2).join(', ')} +${formatted.length - 2}';
  }

  String _getVendorTypeInitials(VendorType type) {
    final formattedType = type.name
        .split(RegExp(r'(?=[A-Z])'))
        .map((word) => word[0].toUpperCase() + word.substring(1))
        .join(' ');
    
    if (formattedType.isEmpty) return '?';
    // Take first 2 characters of vendor type, or first character if single letter
    return formattedType.length >= 2
        ? formattedType.substring(0, 2).toUpperCase()
        : formattedType[0].toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final vendorColor = _getVendorColor();
    final balanceDifference = vendor.currentBalance - vendor.openingBalance;
    final isPositive = balanceDifference >= 0;
    final subtitleParts = <String>[];
    subtitleParts.add(_formatVendorTypes());
    subtitleParts.add(vendor.phoneNumber);
    final subtitle = subtitleParts.join(' • ');

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.paddingMD),
      decoration: BoxDecoration(
        color: AuthColors.background,
        borderRadius: BorderRadius.circular(AppSpacing.radiusXL),
      ),
      child: DataList(
        title: vendor.name,
        subtitle: subtitle,
        leading: DataListAvatar(
          initial: _getVendorTypeInitials(vendor.primaryVendorType),
          radius: 28,
          statusRingColor: vendorColor,
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (balanceDifference != 0)
              Padding(
                padding: const EdgeInsets.only(right: AppSpacing.paddingSM),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.gapSM, vertical: AppSpacing.paddingXS / 2),
                  decoration: BoxDecoration(
                    color: isPositive
                        ? AuthColors.success.withValues(alpha: 0.15)
                        : AuthColors.error.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(AppSpacing.radiusXS),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isPositive ? Icons.arrow_upward : Icons.arrow_downward,
                        size: 10,
                        color: isPositive ? AuthColors.success : AuthColors.error,
                      ),
                      const SizedBox(width: 2),
                      Text(
                        '₹${balanceDifference.abs().toStringAsFixed(2)}',
                        style: TextStyle(
                          color: isPositive ? AuthColors.success : AuthColors.error,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            Text(
              '₹${vendor.currentBalance.toStringAsFixed(2)}',
              style: TextStyle(
                color: vendor.currentBalance >= 0 ? AuthColors.secondary : AuthColors.success,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (onEdit != null) ...[
              const SizedBox(width: AppSpacing.paddingSM),
              IconButton(
                onPressed: onEdit,
                icon: const Icon(Icons.edit_outlined, size: 18),
                tooltip: 'Edit Vendor',
              ),
            ],
          ],
        ),
        onTap: () => context.pushNamed('vendor-detail', extra: vendor),
      ),
    );
  }
}

class _EmptyVendorsState extends StatelessWidget {
  const _EmptyVendorsState();

  @override
  Widget build(BuildContext context) {
    return const EmptyStateWidget(
      icon: Icons.store_outlined,
      title: 'No vendors yet',
      message: 'No vendors to display.',
      iconColor: AuthColors.primary,
    );
  }
}

class _EmptySearchState extends StatelessWidget {
  const _EmptySearchState({required this.query});

  final String query;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.paddingXXXL),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.search_off,
            size: 48,
            color: AuthColors.textSub.withValues(alpha: 0.5),
          ),
                    const SizedBox(height: AppSpacing.paddingLG),
          const Text(
            'No results found',
            style: TextStyle(
              color: AuthColors.textMain,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppSpacing.paddingSM),
          Text(
            'No vendors match "$query"',
            style: const TextStyle(
              color: AuthColors.textSub,
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _VendorFilterChips extends StatelessWidget {
  const _VendorFilterChips({
    required this.selectedType,
    required this.onTypeChanged,
  });

  final VendorType? selectedType;
  final ValueChanged<VendorType?> onTypeChanged;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _FilterChip(
            label: 'All Types',
            icon: Icons.store,
            isSelected: selectedType == null,
            onTap: () => onTypeChanged(null),
          ),
          const SizedBox(width: AppSpacing.paddingSM),
          _FilterChip(
            label: 'Raw Material',
            icon: Icons.inventory_2,
            isSelected: selectedType == VendorType.rawMaterial,
            onTap: () => onTypeChanged(VendorType.rawMaterial),
          ),
          const SizedBox(width: AppSpacing.paddingSM),
          _FilterChip(
            label: 'Vehicle',
            icon: Icons.directions_car,
            isSelected: selectedType == VendorType.vehicle,
            onTap: () => onTypeChanged(VendorType.vehicle),
          ),
          const SizedBox(width: AppSpacing.paddingSM),
          _FilterChip(
            label: 'Repair',
            icon: Icons.build,
            isSelected: selectedType == VendorType.repairMaintenance,
            onTap: () => onTypeChanged(VendorType.repairMaintenance),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSpacing.radiusXL),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.paddingLG, vertical: AppSpacing.paddingMD),
        decoration: BoxDecoration(
          color: isSelected
              ? AuthColors.primary.withValues(alpha: 0.2)
              : AuthColors.surface.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(AppSpacing.radiusXL),
          border: Border.all(
            color: isSelected
                ? AuthColors.primary
                : AuthColors.textSub.withValues(alpha: 0.2),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected
                  ? AuthColors.primary
                  : AuthColors.textSub,
            ),
            const SizedBox(width: AppSpacing.gapSM),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? AuthColors.textMain : AuthColors.textSub,
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CompactPageIndicator extends StatelessWidget {
  const _CompactPageIndicator({
    required this.pageCount,
    required this.currentIndex,
  });

  final int pageCount;
  final double currentIndex;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: List.generate(
        pageCount,
        (index) {
          final isActive = currentIndex.round() == index;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            margin: const EdgeInsets.symmetric(horizontal: 3),
            width: isActive ? 24 : 6,
            height: 3,
            decoration: BoxDecoration(
              color: isActive ? AuthColors.legacyAccent : AuthColors.textMainWithOpacity(0.3),
              borderRadius: BorderRadius.circular(1.5),
            ),
          );
        },
      ),
    );
  }
}

class _VendorDialog extends StatefulWidget {
  const _VendorDialog({this.vendor});

  final Vendor? vendor;

  @override
  State<_VendorDialog> createState() => _VendorDialogState();
}

class _VendorDialogState extends State<_VendorDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _gstController;
  late final TextEditingController _openingBalanceController;

  late Set<VendorType> _selectedTypes;
  late VendorStatus _selectedStatus;

  bool get _isEditing => widget.vendor != null;

  @override
  void initState() {
    super.initState();
    final vendor = widget.vendor;
    _nameController = TextEditingController(text: vendor?.name ?? '');
    _phoneController = TextEditingController(text: vendor?.phoneNumber ?? '');
    _gstController = TextEditingController(text: vendor?.gstNumber ?? '');
    _openingBalanceController = TextEditingController(
      text: vendor != null ? vendor.openingBalance.toStringAsFixed(2) : '0.00',
    );
    _selectedTypes = vendor != null
        ? vendor.effectiveVendorTypes.toSet()
        : <VendorType>{VendorType.other};
    _selectedStatus = vendor?.status ?? VendorStatus.active;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _gstController.dispose();
    _openingBalanceController.dispose();
    super.dispose();
  }

  String _formatVendorType(VendorType type) {
    return type.name
        .split(RegExp(r'(?=[A-Z])'))
        .map((word) => word[0].toUpperCase() + word.substring(1))
        .join(' ');
  }

  Future<void> _saveVendor() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    final cubit = context.read<VendorsCubit>();
    final selectedTypes = _selectedTypes.toList(growable: false);
    final primaryType = selectedTypes.isNotEmpty
        ? selectedTypes.first
        : VendorType.other;

    final openingBalance = widget.vendor?.openingBalance ??
        double.parse(_openingBalanceController.text.trim());
    final currentBalance = widget.vendor?.currentBalance ?? openingBalance;

    final vendor = Vendor(
      id: widget.vendor?.id ?? '',
      vendorCode: widget.vendor?.vendorCode ?? '',
      name: _nameController.text.trim(),
      nameLowercase: _nameController.text.trim().toLowerCase(),
      phoneNumber: _phoneController.text.trim(),
      phoneNumberNormalized: _phoneController.text.trim(),
      phones: widget.vendor?.phones ?? const [],
      phoneIndex: widget.vendor?.phoneIndex ?? const [],
      openingBalance: openingBalance,
      currentBalance: currentBalance,
      vendorType: primaryType,
      vendorTypes: selectedTypes,
      status: _selectedStatus,
      organizationId: widget.vendor?.organizationId ?? cubit.organizationId,
      gstNumber: _gstController.text.trim().isEmpty
          ? null
          : _gstController.text.trim(),
      rawMaterialDetails: widget.vendor?.rawMaterialDetails,
      vehicleDetails: widget.vendor?.vehicleDetails,
      repairMaintenanceDetails: widget.vendor?.repairMaintenanceDetails,
      welfareDetails: widget.vendor?.welfareDetails,
      fuelDetails: widget.vendor?.fuelDetails,
      utilitiesDetails: widget.vendor?.utilitiesDetails,
      rentDetails: widget.vendor?.rentDetails,
      professionalServicesDetails: widget.vendor?.professionalServicesDetails,
      marketingAdvertisingDetails: widget.vendor?.marketingAdvertisingDetails,
      insuranceDetails: widget.vendor?.insuranceDetails,
      logisticsDetails: widget.vendor?.logisticsDetails,
      officeSuppliesDetails: widget.vendor?.officeSuppliesDetails,
      securityDetails: widget.vendor?.securityDetails,
      cleaningDetails: widget.vendor?.cleaningDetails,
      taxConsultantDetails: widget.vendor?.taxConsultantDetails,
      bankingFinancialDetails: widget.vendor?.bankingFinancialDetails,
      createdBy: widget.vendor?.createdBy,
      createdAt: widget.vendor?.createdAt,
      updatedBy: widget.vendor?.updatedBy,
      updatedAt: widget.vendor?.updatedAt,
      lastTransactionDate: widget.vendor?.lastTransactionDate,
    );

    if (_isEditing) {
      await cubit.updateVendor(vendor);
    } else {
      await cubit.createVendor(vendor);
    }

    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: 480,
        padding: const EdgeInsets.all(AppSpacing.paddingLG),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _isEditing ? 'Edit Vendor' : 'Add Vendor',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: AuthColors.textMain,
                  ),
                ),
                const SizedBox(height: AppSpacing.paddingLG),
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(labelText: 'Vendor Name'),
                  validator: (value) => (value == null || value.trim().isEmpty)
                      ? 'Enter vendor name'
                      : null,
                ),
                const SizedBox(height: AppSpacing.paddingMD),
                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(labelText: 'Phone Number'),
                  validator: (value) => (value == null || value.trim().isEmpty)
                      ? 'Enter phone number'
                      : null,
                ),
                const SizedBox(height: AppSpacing.paddingMD),
                const Text(
                  'Vendor Types',
                  style: TextStyle(
                    color: AuthColors.textSub,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: AppSpacing.paddingSM),
                Wrap(
                  spacing: AppSpacing.paddingSM,
                  runSpacing: AppSpacing.paddingSM,
                  children: VendorType.values.map((type) {
                    final isSelected = _selectedTypes.contains(type);
                    return FilterChip(
                      selected: isSelected,
                      label: Text(_formatVendorType(type)),
                      onSelected: (selected) {
                        setState(() {
                          if (selected) {
                            _selectedTypes.add(type);
                          } else {
                            _selectedTypes.remove(type);
                          }

                          if (_selectedTypes.isEmpty) {
                            _selectedTypes = {VendorType.other};
                          }
                        });
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: AppSpacing.paddingMD),
                TextFormField(
                  controller: _gstController,
                  decoration:
                      const InputDecoration(labelText: 'GST Number (Optional)'),
                ),
                const SizedBox(height: AppSpacing.paddingMD),
                TextFormField(
                  controller: _openingBalanceController,
                  enabled: !_isEditing,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Opening Balance'),
                  validator: (value) {
                    if (_isEditing) {
                      return null;
                    }
                    if (value == null || value.trim().isEmpty) {
                      return 'Enter opening balance';
                    }
                    if (double.tryParse(value.trim()) == null) {
                      return 'Enter a valid number';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.paddingMD),
                DropdownButtonFormField<VendorStatus>(
                  initialValue: _selectedStatus,
                  decoration: const InputDecoration(labelText: 'Status'),
                  items: VendorStatus.values
                      .map(
                        (status) => DropdownMenuItem(
                          value: status,
                          child: Text(
                            status.name[0].toUpperCase() + status.name.substring(1),
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (status) {
                    if (status != null) {
                      setState(() => _selectedStatus = status);
                    }
                  },
                ),
                const SizedBox(height: AppSpacing.paddingLG),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: AppSpacing.paddingSM),
                    FilledButton.icon(
                      onPressed: _saveVendor,
                      icon: Icon(_isEditing ? Icons.check : Icons.add),
                      label: Text(_isEditing ? 'Save Changes' : 'Create Vendor'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}





