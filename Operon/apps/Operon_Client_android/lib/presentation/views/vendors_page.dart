import 'package:core_bloc/core_bloc.dart';
import 'package:core_ui/core_ui.dart';
import 'package:core_models/core_models.dart';
import 'package:dash_mobile/presentation/blocs/vendors/vendors_cubit.dart';
import 'package:dash_mobile/presentation/blocs/vendors/vendors_state.dart';
import 'package:dash_mobile/presentation/views/vendors_page/vendor_analytics_page.dart';
import 'package:dash_mobile/presentation/widgets/quick_nav_bar.dart';
import 'package:dash_mobile/presentation/widgets/modern_page_header.dart';
import 'package:dash_mobile/presentation/widgets/standard_search_bar.dart';
import 'package:dash_mobile/presentation/widgets/empty/empty_state_widget.dart';
import 'package:dash_mobile/presentation/widgets/error/error_state_widget.dart';
import 'package:dash_mobile/presentation/utils/debouncer.dart';
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AuthColors.background,
      appBar: const ModernPageHeader(
        title: 'Vendors',
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
                          ),
                          const VendorAnalyticsPage(),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    _CompactPageIndicator(
                      pageCount: 2,
                      currentIndex: _currentPage,
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
              QuickNavBar(
                currentIndex: -1, // -1 means no selection when on this page
                onTap: (value) => context.go('/home', extra: value),
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
  });

  final ScrollController scrollController;
  final bool isLoadingMore;
  final TextEditingController searchController;
  final String searchQuery;
  final VoidCallback onClearSearch;

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
                const SizedBox(height: 16),
                _VendorFilterChips(
                  selectedType: state.selectedVendorType,
                  onTypeChanged: (type) {
                    context.read<VendorsCubit>().filterByType(type);
                  },
                ),
                const SizedBox(height: 24),
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
                    const SizedBox(height: 16),
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
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: AnimationLimiter(
                  child: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        if (index >= filteredVendors.length) {
                          return isLoadingMore
                              ? const Padding(
                                  padding: EdgeInsets.all(16),
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

  List<Vendor> _getFilteredVendors(List<Vendor> vendors, String query) {
    // Cache key based on vendors hash and search query
    final vendorsHash = '${vendors.length}_${vendors.hashCode}';
    final cacheKey = '${vendorsHash}_$query';

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
            .where((v) =>
                v.name.toLowerCase().contains(query.toLowerCase()) ||
                v.phoneNumber.contains(query) ||
                (v.gstNumber?.toLowerCase().contains(query.toLowerCase()) ?? false))
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
          const SizedBox(height: 8),
          if (state.status == ViewStatus.loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: CircularProgressIndicator(),
              ),
            )
          else if (vendors.isEmpty)
            _EmptySearchState(query: searchQuery)
          else
            ...vendors.map((vendor) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
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
    this.onDelete,
  });

  final Vendor vendor;
  final VoidCallback? onDelete;

  Color _getVendorColor() {
    final hash = vendor.vendorType.name.hashCode;
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

  String _formatVendorType() {
    return vendor.vendorType.name
        .split(RegExp(r'(?=[A-Z])'))
        .map((word) => word[0].toUpperCase() + word.substring(1))
        .join(' ');
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
    subtitleParts.add(_formatVendorType());
    subtitleParts.add(vendor.phoneNumber);
    final subtitle = subtitleParts.join(' • ');

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AuthColors.background,
        borderRadius: BorderRadius.circular(18),
      ),
      child: DataList(
        title: vendor.name,
        subtitle: subtitle,
        leading: DataListAvatar(
          initial: _getVendorTypeInitials(vendor.vendorType),
          radius: 28,
          statusRingColor: vendorColor,
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (balanceDifference != 0)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    color: isPositive
                        ? AuthColors.success.withOpacity(0.15)
                        : AuthColors.error.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(6),
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
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.search_off,
            size: 48,
            color: AuthColors.textSub.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          const Text(
            'No results found',
            style: TextStyle(
              color: AuthColors.textMain,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
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
          const SizedBox(width: 8),
          _FilterChip(
            label: 'Raw Material',
            icon: Icons.inventory_2,
            isSelected: selectedType == VendorType.rawMaterial,
            onTap: () => onTypeChanged(VendorType.rawMaterial),
          ),
          const SizedBox(width: 8),
          _FilterChip(
            label: 'Vehicle',
            icon: Icons.directions_car,
            isSelected: selectedType == VendorType.vehicle,
            onTap: () => onTypeChanged(VendorType.vehicle),
          ),
          const SizedBox(width: 8),
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
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? AuthColors.primary.withOpacity(0.2)
              : AuthColors.surface.withOpacity(0.6),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? AuthColors.primary
                : AuthColors.textSub.withOpacity(0.2),
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
            const SizedBox(width: 6),
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





