import 'package:core_bloc/core_bloc.dart';
import 'package:core_ui/core_ui.dart';
import 'package:core_models/core_models.dart';
import 'package:dash_web/presentation/blocs/vendors/vendors_cubit.dart';
import 'package:dash_web/presentation/blocs/vendors/vendors_state.dart';
import 'package:dash_web/presentation/blocs/org_context/org_context_cubit.dart';
import 'package:dash_web/data/repositories/raw_materials_repository.dart';
import 'package:dash_web/presentation/widgets/vendor_detail_modal.dart';
import 'package:core_datasources/core_datasources.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';

class VendorsPageContent extends StatefulWidget {
  const VendorsPageContent({super.key});

  @override
  State<VendorsPageContent> createState() => _VendorsPageContentState();
}

enum _VendorSortOption {
  nameAsc,
  nameDesc,
  balanceHigh,
  balanceLow,
  typeAsc,
}

class _VendorsPageContentState extends State<VendorsPageContent> {
  String _query = '';
  _VendorSortOption _sortOption = _VendorSortOption.nameAsc;
  VendorType? _selectedTypeFilter;
  VendorStatus? _selectedStatusFilter;
  final ScrollController _scrollController = ScrollController();
  final Map<String, String> _searchIndexCache = {};
  String? _lastSearchIndexHash;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
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
      // Load more if needed - placeholder for future pagination
    }
  }

  List<Vendor> _applyFiltersAndSort(
    List<Vendor> vendors, {
    bool applyQueryFilter = true,
  }) {
    var filtered = List<Vendor>.from(vendors);

    // Apply search filter
    if (applyQueryFilter && _query.isNotEmpty) {
      final queryLower = _query.toLowerCase();
      final vendorsHash = '${vendors.length}_${vendors.hashCode}';
      final searchIndex = _buildSearchIndex(vendors, vendorsHash);
      filtered = filtered.where((v) {
        final indexText = searchIndex[v.id] ?? '';
        return indexText.contains(queryLower);
      }).toList();
    }

    // Apply type filter
    if (_selectedTypeFilter != null) {
      filtered = filtered
          .where((v) => v.vendorType == _selectedTypeFilter)
          .toList();
    }

    // Apply status filter
    if (_selectedStatusFilter != null) {
      filtered = filtered
          .where((v) => v.status == _selectedStatusFilter)
          .toList();
    }

    // Apply sorting
    final sortedList = List<Vendor>.from(filtered);
    switch (_sortOption) {
      case _VendorSortOption.nameAsc:
        sortedList.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
        break;
      case _VendorSortOption.nameDesc:
        sortedList.sort((a, b) => b.name.toLowerCase().compareTo(a.name.toLowerCase()));
        break;
      case _VendorSortOption.balanceHigh:
        sortedList.sort((a, b) => b.currentBalance.compareTo(a.currentBalance));
        break;
      case _VendorSortOption.balanceLow:
        sortedList.sort((a, b) => a.currentBalance.compareTo(b.currentBalance));
        break;
      case _VendorSortOption.typeAsc:
        sortedList.sort((a, b) => a.vendorType.name.compareTo(b.vendorType.name));
        break;
    }

    return sortedList;
  }

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

  String _formatVendorType(VendorType type) {
    return type.name
        .split(RegExp(r'(?=[A-Z])'))
        .map((word) => word[0].toUpperCase() + word.substring(1))
        .join(' ');
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<VendorsCubit, VendorsState>(
      builder: (context, state) {
        // Show loading only on initial load
        final cubit = context.read<VendorsCubit>();
        final isLoading = state.status == ViewStatus.loading && state.vendors.isEmpty;
        if (isLoading) {
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
                  ...List.generate(8, (_) => Padding(
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
        if (state.status == ViewStatus.failure && state.vendors.isEmpty) {
          return _ErrorState(
            message: state.message ?? 'Failed to load vendors',
            onRetry: () => cubit.loadVendors(force: true),
          );
        }

        final vendors = state.vendors;
        final isServerSearch = state.searchQuery.isNotEmpty;
        final baseList = isServerSearch ? state.filteredVendors : vendors;
        final filtered = _applyFiltersAndSort(
          baseList,
          applyQueryFilter: !isServerSearch,
        );

        final Widget listContent;
        if (filtered.isEmpty &&
            (_query.isNotEmpty || _selectedTypeFilter != null || _selectedStatusFilter != null)) {
          listContent = _EmptySearchState(query: _query);
        } else if (filtered.isEmpty) {
          listContent = _EmptyVendorsState(
            onAddVendor: () => _showVendorDialog(context, null, context.read<VendorsCubit>()),
          );
        } else {
          listContent = _VendorListView(
            vendors: filtered,
            scrollController: _scrollController,
            onTap: (vendor) => _openVendorDetail(context, vendor),
            onEdit: (vendor) => _showVendorDialog(context, vendor, context.read<VendorsCubit>()),
            onDelete: (vendor) => _handleDeleteVendor(context, vendor, context.read<VendorsCubit>()),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Statistics Dashboard
              _VendorsStatsHeader(vendors: vendors),
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
                        context.read<VendorsCubit>().searchVendorsDebounced(v);
                      },
                            style: const TextStyle(color: AuthColors.textMain),
                            decoration: InputDecoration(
                        hintText: 'Search vendors by name, phone, or GST...',
                              hintStyle: const TextStyle(
                                color: AuthColors.textDisabled,
                              ),
                              filled: true,
                        fillColor: Colors.transparent,
                        prefixIcon: const Icon(Icons.search, color: AuthColors.textSub),
                        suffixIcon: _query.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, color: AuthColors.textSub),
                                onPressed: () {
                                  setState(() => _query = '');
                                  context.read<VendorsCubit>().searchVendorsDebounced('');
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
                // Vendor Type Filter
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AuthColors.surface.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AuthColors.textSub.withOpacity(0.2),
                    ),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<VendorType?>(
                      value: _selectedTypeFilter,
                      hint: const Row(
                        mainAxisSize: MainAxisSize.min,
                      children: [
                          Icon(Icons.category, size: 16, color: AuthColors.textSub),
                          SizedBox(width: 6),
                          Text(
                            'All Types',
                            style: TextStyle(color: AuthColors.textSub, fontSize: 14),
                  ),
                ],
              ),
                      dropdownColor: AuthColors.surface,
                      style: const TextStyle(color: AuthColors.textMain, fontSize: 14),
                      items: [
                        const DropdownMenuItem<VendorType?>(
                          value: null,
                          child: Text('All Types'),
                        ),
                        ...VendorType.values.map((type) => DropdownMenuItem<VendorType?>(
                          value: type,
                          child: Text(_formatVendorType(type)),
                            )),
                      ],
                      onChanged: (value) => setState(() => _selectedTypeFilter = value),
                      icon: const Icon(Icons.arrow_drop_down, color: AuthColors.textSub, size: 20),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Status Filter
              Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AuthColors.surface.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AuthColors.textSub.withOpacity(0.2),
                    ),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<VendorStatus?>(
                      value: _selectedStatusFilter,
                      hint: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.filter_list, size: 16, color: AuthColors.textSub),
                          SizedBox(width: 6),
                          Text(
                            'All Status',
                            style: TextStyle(color: AuthColors.textSub, fontSize: 14),
                          ),
                        ],
                      ),
                      dropdownColor: AuthColors.surface,
                      style: const TextStyle(color: AuthColors.textMain, fontSize: 14),
                      items: [
                        const DropdownMenuItem<VendorStatus?>(
                          value: null,
                          child: Text('All Status'),
                        ),
                        ...VendorStatus.values.map((status) => DropdownMenuItem<VendorStatus?>(
                          value: status,
                          child: Text(status.name[0].toUpperCase() + status.name.substring(1)),
                    )),
            ],
                      onChanged: (value) => setState(() => _selectedStatusFilter = value),
                      icon: const Icon(Icons.arrow_drop_down, color: AuthColors.textSub, size: 20),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Sort Options
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                      const Icon(Icons.sort, size: 16, color: AuthColors.textSub),
                      const SizedBox(width: 6),
                      DropdownButtonHideUnderline(
                        child: DropdownButton<_VendorSortOption>(
                          value: _sortOption,
                          dropdownColor: AuthColors.surface,
                          style: const TextStyle(color: AuthColors.textMain, fontSize: 14),
                          items: const [
                            DropdownMenuItem(
                              value: _VendorSortOption.nameAsc,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                  children: [
                                  Icon(Icons.sort_by_alpha, size: 16, color: AuthColors.textSub),
                                  SizedBox(width: 8),
                                  Text('Name (A-Z)'),
                                ],
                              ),
                            ),
                            DropdownMenuItem(
                              value: _VendorSortOption.nameDesc,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                      children: [
                                  Icon(Icons.sort_by_alpha, size: 16, color: AuthColors.textSub),
                                  SizedBox(width: 8),
                                  Text('Name (Z-A)'),
                                ],
                              ),
                            ),
                            DropdownMenuItem(
                              value: _VendorSortOption.balanceHigh,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                      children: [
                                  Icon(Icons.trending_down, size: 16, color: AuthColors.textSub),
                                  SizedBox(width: 8),
                                  Text('Balance (High to Low)'),
                                ],
                              ),
                            ),
                            DropdownMenuItem(
                              value: _VendorSortOption.balanceLow,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.trending_up, size: 16, color: AuthColors.textSub),
                                  SizedBox(width: 8),
                                  Text('Balance (Low to High)'),
                                ],
                              ),
                            ),
                            DropdownMenuItem(
                              value: _VendorSortOption.typeAsc,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.category, size: 16, color: AuthColors.textSub),
                                  SizedBox(width: 8),
                                  Text('Type'),
                  ],
                ),
              ),
                      ],
                          onChanged: (value) {
                            if (value != null) {
                              setState(() => _sortOption = value);
                            }
                          },
                          icon: const Icon(Icons.arrow_drop_down, color: AuthColors.textSub, size: 20),
                          isDense: true,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                // Results count
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AuthColors.surface.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AuthColors.textSub.withOpacity(0.2),
                    ),
                  ),
            child: Text(
                    '${filtered.length} ${filtered.length == 1 ? 'vendor' : 'vendors'}',
                          style: const TextStyle(
                            color: AuthColors.textSub,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                          ),
                        ),
                        ),
                const SizedBox(width: 12),
                // Add Vendor Button
                          DashButton(
                  icon: Icons.add,
                  label: 'Add Vendor',
                  onPressed: () {
                    final cubit = context.read<VendorsCubit>();
                    _showVendorDialog(context, null, cubit);
                  },
                ),
        ],
      ),
            const SizedBox(height: 24),
            
            // Vendor List
            listContent,
          ],
        );
      },
    );
  }
}

class _VendorsStatsHeader extends StatelessWidget {
  const _VendorsStatsHeader({required this.vendors});

  final List<Vendor> vendors;

  @override
  Widget build(BuildContext context) {
    final totalVendors = vendors.length;
    final activeVendors = vendors.where((v) => v.status == VendorStatus.active).length;
    final totalPayable = vendors.fold<double>(
      0.0,
      (sum, v) => sum + v.currentBalance,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 1000;
        return isWide
            ? Row(
      children: [
        Expanded(
          child: _StatCard(
                      icon: Icons.store_outlined,
            label: 'Total Vendors',
                      value: totalVendors.toString(),
            color: AuthColors.primary,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _StatCard(
                      icon: Icons.check_circle_outline,
            label: 'Active Vendors',
                      value: activeVendors.toString(),
            color: AuthColors.success,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _StatCard(
                      icon: Icons.account_balance_wallet_outlined,
            label: 'Total Payable',
                      value: '₹${totalPayable.toStringAsFixed(2)}',
                      color: AuthColors.secondary,
          ),
        ),
      ],
              )
            : Wrap(
                spacing: 16,
                runSpacing: 16,
                children: [
                  _StatCard(
                    icon: Icons.store_outlined,
                    label: 'Total Vendors',
                    value: totalVendors.toString(),
                    color: AuthColors.primary,
                  ),
                  _StatCard(
                    icon: Icons.check_circle_outline,
                    label: 'Active Vendors',
                    value: activeVendors.toString(),
                    color: AuthColors.success,
                  ),
                  _StatCard(
                    icon: Icons.account_balance_wallet_outlined,
                    label: 'Total Payable',
                    value: '₹${totalPayable.toStringAsFixed(2)}',
                    color: AuthColors.secondary,
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
          color: const Color(0xFF1B1B2C).withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: Colors.redAccent.withValues(alpha: 0.3),
          ),
        ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.redAccent.withValues(alpha: 0.7),
            ),
            const SizedBox(height: 16),
            const Text(
              'Failed to load vendors',
              style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
                ),
                const SizedBox(height: 8),
                    Text(
              message,
                      style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
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

class _EmptyVendorsState extends StatelessWidget {
  const _EmptyVendorsState({required this.onAddVendor});

  final VoidCallback onAddVendor;

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
            const Color(0xFF1B1B2C).withValues(alpha: 0.6),
            const Color(0xFF161622).withValues(alpha: 0.8),
          ],
        ),
          borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.1),
        ),
      ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                    Container(
              width: 80,
              height: 80,
                      decoration: BoxDecoration(
                color: const Color(0xFF6F4BFF).withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.store_outlined,
                size: 40,
                color: Color(0xFF6F4BFF),
                  ),
                ),
                const SizedBox(height: 24),
            const Text(
              'No vendors yet',
                      style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
                    Text(
              'Start by adding your first vendor to the system',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.6),
                fontSize: 16,
              ),
              textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
            DashButton(
              icon: Icons.add,
              label: 'Add Vendor',
              onPressed: onAddVendor,
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
              color: Colors.white.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 16),
            const Text(
              'No results found',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'No vendors match "$query"',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.6),
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VendorListView extends StatelessWidget {
  const _VendorListView({
    required this.vendors,
    required this.scrollController,
    this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  final List<Vendor> vendors;
  final ScrollController scrollController;
  final ValueChanged<Vendor>? onTap;
  final ValueChanged<Vendor> onEdit;
  final ValueChanged<Vendor> onDelete;

  Color _getVendorTypeColor(VendorType type) {
    final hash = type.name.hashCode;
    final colors = [
      const Color(0xFF6F4BFF),
      const Color(0xFF5AD8A4),
      const Color(0xFFFF9800),
      const Color(0xFF2196F3),
      const Color(0xFFE91E63),
      const Color(0xFF9C27B0),
    ];
    return colors[hash.abs() % colors.length];
  }

  String _formatVendorType(VendorType type) {
    return type.name
        .split(RegExp(r'(?=[A-Z])'))
        .map((word) => word[0].toUpperCase() + word.substring(1))
        .join(' ');
  }

  @override
  Widget build(BuildContext context) {
    return AnimationLimiter(
      child: ListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        controller: scrollController,
        itemCount: vendors.length,
        itemBuilder: (context, index) {
          final vendor = vendors[index];
          final typeColor = _getVendorTypeColor(vendor.vendorType);
          final balanceDifference = vendor.currentBalance - vendor.openingBalance;
          final isPositive = balanceDifference >= 0;
          final subtitleParts = <String>[];
          subtitleParts.add(_formatVendorType(vendor.vendorType));
          subtitleParts.add(vendor.phoneNumber);
          if (vendor.vendorCode.isNotEmpty) subtitleParts.add('Code: ${vendor.vendorCode}');
          final subtitle = subtitleParts.join(' • ');

          return AnimationConfiguration.staggeredList(
            position: index,
            duration: const Duration(milliseconds: 200),
            child: SlideAnimation(
              verticalOffset: 50.0,
              child: FadeInAnimation(
                curve: Curves.easeOut,
                child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: AuthColors.background,
            borderRadius: BorderRadius.circular(18),
          ),
          child: DataList(
            title: vendor.name,
            subtitle: subtitle,
            leading: DataListAvatar(
              initial: vendor.name.isNotEmpty ? vendor.name[0] : '?',
              radius: 28,
              statusRingColor: typeColor,
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
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.edit_outlined, size: 20, color: AuthColors.textSub),
                  onPressed: () => onEdit(vendor),
                  tooltip: 'Edit',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
                const SizedBox(width: 4),
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 20, color: AuthColors.error),
                  onPressed: () => onDelete(vendor),
                  tooltip: 'Delete',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            onTap: () => onTap?.call(vendor),
          ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// Helper functions
void _openVendorDetail(BuildContext context, Vendor vendor) {
  showDialog(
    context: context,
    builder: (dialogContext) => VendorDetailModal(
      vendor: vendor,
      onVendorChanged: (updatedVendor) {
        // Stream will update automatically; no manual refresh to avoid extra reads
      },
      onEdit: () => _showVendorDialog(context, vendor, context.read<VendorsCubit>()),
    ),
  );
}

void _showVendorDialog(BuildContext context, Vendor? vendor, VendorsCubit cubit) {
  showDialog(
    context: context,
    builder: (dialogContext) => _VendorDialog(
      vendor: vendor,
      vendorsCubit: cubit,
    ),
  );
}

Future<void> _handleDeleteVendor(BuildContext context, Vendor vendor, VendorsCubit cubit) async {
  // Check balance
  if (vendor.currentBalance != 0) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AuthColors.surface,
        title: const Text(
          'Cannot Delete Vendor',
          style: TextStyle(color: AuthColors.textMain),
        ),
        content: Text(
          'Cannot delete vendor with pending balance.\n'
          'Current balance: ₹${vendor.currentBalance.toStringAsFixed(2)}\n\n'
          'Please settle the balance first.',
          style: const TextStyle(color: AuthColors.textSub),
        ),
        actions: [
          DashButton(
            label: 'OK',
            onPressed: () => Navigator.pop(context),
            variant: DashButtonVariant.text,
          ),
        ],
      ),
    );
    return;
  }

  // Show confirmation
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: AuthColors.surface,
      title: const Text(
        'Delete Vendor',
        style: TextStyle(color: AuthColors.textMain),
      ),
      content: Text(
        'Are you sure you want to delete "${vendor.name}"?',
        style: const TextStyle(color: AuthColors.textSub),
      ),
      actions: [
        DashButton(
          label: 'Cancel',
          onPressed: () => Navigator.pop(context, false),
          variant: DashButtonVariant.text,
        ),
        DashButton(
          label: 'Delete',
          onPressed: () => Navigator.pop(context, true),
          variant: DashButtonVariant.text,
          isDestructive: true,
        ),
      ],
    ),
  );

  if (confirmed == true && context.mounted) {
    cubit.deleteVendor(vendor.id);
  }
}

class _VendorDialog extends StatefulWidget {
  const _VendorDialog({
    this.vendor,
    required this.vendorsCubit,
  });

  final Vendor? vendor;
  final VendorsCubit vendorsCubit;

  @override
  State<_VendorDialog> createState() => _VendorDialogState();
}

class _VendorDialogState extends State<_VendorDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _gstController;
  late final TextEditingController _openingBalanceController;
  
  VendorType _selectedType = VendorType.other;
  VendorStatus _selectedStatus = VendorStatus.active;
  bool _isEditing = false;
  
  // Raw materials assignment
  List<RawMaterial> _allRawMaterials = [];
  Set<String> _selectedMaterialIds = {};
  bool _isLoadingMaterials = false;

  @override
  void initState() {
    super.initState();
    final vendor = widget.vendor;
    _isEditing = vendor != null;
    _nameController = TextEditingController(text: vendor?.name ?? '');
    _phoneController = TextEditingController(text: vendor?.phoneNumber ?? '');
    _gstController = TextEditingController(text: vendor?.gstNumber ?? '');
    _openingBalanceController = TextEditingController(
      text: vendor != null ? vendor.openingBalance.toStringAsFixed(2) : '0.00',
    );
    _selectedType = vendor?.vendorType ?? VendorType.other;
    _selectedStatus = vendor?.status ?? VendorStatus.active;
    
    // Load assigned materials if editing and vendor type is rawMaterial
    if (vendor != null && vendor.vendorType == VendorType.rawMaterial) {
      _selectedMaterialIds = Set.from(vendor.rawMaterialDetails?.assignedMaterialIds ?? []);
    }
    
    // Load raw materials if type is rawMaterial
    if (_selectedType == VendorType.rawMaterial) {
      _loadRawMaterials();
    }
  }
  
  Future<void> _loadRawMaterials() async {
    setState(() => _isLoadingMaterials = true);
    try {
      final orgState = context.read<OrganizationContextCubit>().state;
      final organization = orgState.organization;
      if (organization == null) return;
      
      final repository = RawMaterialsRepository(
        dataSource: RawMaterialsDataSource(),
      );
      final materials = await repository.fetchRawMaterials(organization.id);
      setState(() {
        _allRawMaterials = materials;
        _isLoadingMaterials = false;
      });
    } catch (e) {
      setState(() => _isLoadingMaterials = false);
      if (mounted) {
        DashSnackbar.show(context, message: 'Failed to load raw materials: $e', isError: true);
      }
    }
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

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF11111B),
              Color(0xFF0D0D15),
            ],
          ),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
          color: Colors.white.withValues(alpha: 0.1),
        ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.5),
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
                    Color(0xFF1B1C2C),
                    Color(0xFF161622),
                  ],
                ),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(24),
                ),
                border: Border(
                  bottom: BorderSide(
                    color: Colors.white.withValues(alpha: 0.08),
                  ),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFF6F4BFF).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      _isEditing ? Icons.edit : Icons.store_outlined,
                      color: const Color(0xFF6F4BFF),
              size: 20,
            ),
          ),
                  const SizedBox(width: 16),
          Expanded(
            child: Text(
                      _isEditing ? 'Edit Vendor' : 'Add Vendor',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                        fontWeight: FontWeight.w700,
              ),
            ),
          ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white70),
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
                  style: const TextStyle(color: Colors.white),
                        decoration: _inputDecoration('Vendor name', Icons.store_outlined),
                  validator: (value) =>
                      (value == null || value.trim().isEmpty)
                          ? 'Enter vendor name'
                          : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  style: const TextStyle(color: Colors.white),
                        decoration: _inputDecoration('Phone number', Icons.phone_outlined),
                  validator: (value) =>
                      (value == null || value.trim().isEmpty)
                          ? 'Enter phone number'
                          : null,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<VendorType>(
                        initialValue: _selectedType,
                  dropdownColor: const Color(0xFF1B1B2C),
                  style: const TextStyle(color: Colors.white),
                        decoration: _inputDecoration('Vendor Type', Icons.category_outlined),
                        items: VendorType.values.map((type) {
                          return DropdownMenuItem(
                          value: type,
                          child: Text(_formatVendorType(type)),
                          );
                        }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        _selectedType = value;
                        // Load raw materials if switching to rawMaterial type
                        if (value == VendorType.rawMaterial && _allRawMaterials.isEmpty) {
                          _loadRawMaterials();
                        }
                      });
                    }
                  },
                ),
                // Raw Materials Assignment Section
                if (_selectedType == VendorType.rawMaterial) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1B1B2C),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.1),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(
                              Icons.inventory_2_outlined,
                              color: Colors.white70,
                              size: 20,
                            ),
                            SizedBox(width: 8),
                            Text(
                              'Assigned Raw Materials',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        if (_isLoadingMaterials)
                          const Center(
                            child: Padding(
                              padding: EdgeInsets.all(16.0),
                              child: CircularProgressIndicator(),
                            ),
                          )
                        else if (_allRawMaterials.isEmpty)
                          Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Text(
                              'No raw materials available. Create raw materials first.',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.6),
                                fontSize: 12,
                              ),
                            ),
                          )
                        else
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: _allRawMaterials.map((material) {
                              final isSelected = _selectedMaterialIds.contains(material.id);
                              return FilterChip(
                                label: Text(material.name),
                                selected: isSelected,
                                onSelected: (selected) {
                                  setState(() {
                                    if (selected) {
                                      _selectedMaterialIds.add(material.id);
                                    } else {
                                      _selectedMaterialIds.remove(material.id);
                                    }
                                  });
                                },
                                selectedColor: const Color(0xFF6F4BFF).withValues(alpha: 0.3),
                                checkmarkColor: const Color(0xFF6F4BFF),
                                labelStyle: TextStyle(
                                  color: isSelected ? Colors.white : Colors.white70,
                                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                                ),
                                side: BorderSide(
                                  color: isSelected
                                      ? const Color(0xFF6F4BFF)
                                      : Colors.white.withValues(alpha: 0.2),
                                ),
                              );
                            }).toList(),
                          ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                TextFormField(
                        controller: _gstController,
                  style: const TextStyle(color: Colors.white),
                        decoration: _inputDecoration('GST Number (optional)', Icons.receipt_long_outlined),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _openingBalanceController,
                        enabled: !_isEditing,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: const TextStyle(color: Colors.white),
                        decoration: _inputDecoration('Opening Balance', Icons.account_balance_wallet_outlined),
                  validator: (value) {
                          if (_isEditing) return null;
                    if (value == null || value.trim().isEmpty) {
                      return 'Enter opening balance';
                    }
                          if (double.tryParse(value.trim()) == null) {
                            return 'Enter a valid number';
                          }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<VendorStatus>(
                  initialValue: _selectedStatus,
                  dropdownColor: const Color(0xFF1B1B2C),
                  style: const TextStyle(color: Colors.white),
                        decoration: _inputDecoration('Status', Icons.flag_outlined),
                        items: VendorStatus.values.map((status) {
                          return DropdownMenuItem(
                          value: status,
                            child: Text(status.name[0].toUpperCase() + status.name.substring(1)),
                          );
                        }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _selectedStatus = value);
                    }
                  },
                ),
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
                    color: Colors.white.withValues(alpha: 0.08),
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
                    icon: _isEditing ? Icons.check : Icons.add,
                    label: _isEditing ? 'Save Changes' : 'Create Vendor',
          onPressed: () async {
            if (!(_formKey.currentState?.validate() ?? false)) return;

                      // Get organizationId from the vendor if editing, or from cubit
                      final orgId = widget.vendor?.organizationId ?? widget.vendorsCubit.organizationId;

                        // Build rawMaterialDetails if vendor type is rawMaterial
                        RawMaterialDetails? rawMaterialDetails;
                        if (_selectedType == VendorType.rawMaterial) {
                          rawMaterialDetails = RawMaterialDetails(
                            materialCategories: widget.vendor?.rawMaterialDetails?.materialCategories ?? [],
                            unitOfMeasurement: widget.vendor?.rawMaterialDetails?.unitOfMeasurement,
                            qualityCertifications: widget.vendor?.rawMaterialDetails?.qualityCertifications ?? [],
                            deliveryCapability: widget.vendor?.rawMaterialDetails?.deliveryCapability,
                            assignedMaterialIds: _selectedMaterialIds.toList(),
                          );
                        }
                        
              final vendor = Vendor(
                        id: widget.vendor?.id ?? '',
                        vendorCode: widget.vendor?.vendorCode ?? '',
                name: _nameController.text.trim(),
                nameLowercase: _nameController.text.trim().toLowerCase(),
                        phoneNumber: _phoneController.text.trim(),
                        phoneNumberNormalized: _phoneController.text.trim(),
                        phones: [],
                        phoneIndex: [],
                          openingBalance: widget.vendor?.openingBalance ??
                              double.parse(_openingBalanceController.text.trim()),
                          currentBalance: widget.vendor?.currentBalance ??
                              double.parse(_openingBalanceController.text.trim()),
                        vendorType: _selectedType,
                status: _selectedStatus,
                        organizationId: orgId,
                        gstNumber: _gstController.text.trim().isEmpty 
                    ? null
                            : _gstController.text.trim(),
                        rawMaterialDetails: rawMaterialDetails,
                        );

                      if (_isEditing) {
                        await widget.vendorsCubit.updateVendor(vendor);
            } else {
                        await widget.vendorsCubit.createVendor(vendor);
                        }
                      
            if (context.mounted) {
              Navigator.of(context).pop();
            }
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
      prefixIcon: Icon(icon, color: Colors.white54, size: 20),
      filled: true,
      fillColor: const Color(0xFF1B1B2C),
      labelStyle: const TextStyle(color: Colors.white70),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: Colors.white.withValues(alpha: 0.1),
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
          color: Colors.redAccent,
        ),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(
          color: Colors.redAccent,
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
