import 'package:core_bloc/core_bloc.dart';
import 'package:core_models/core_models.dart';
import 'package:dash_mobile/presentation/blocs/vendors/vendors_cubit.dart';
import 'package:dash_mobile/presentation/blocs/vendors/vendors_state.dart';
import 'package:dash_mobile/presentation/views/vendors_page/vendor_analytics_page.dart';
import 'package:dash_mobile/presentation/widgets/quick_nav_bar.dart';
import 'package:dash_mobile/presentation/widgets/quick_action_menu.dart';
import 'package:dash_mobile/presentation/widgets/modern_page_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class VendorsPage extends StatefulWidget {
  const VendorsPage({super.key});

  @override
  State<VendorsPage> createState() => _VendorsPageState();
}

class _VendorsPageState extends State<VendorsPage> {
  late final TextEditingController _searchController;
  late final PageController _pageController;
  double _currentPage = 0;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController()
      ..addListener(_handleSearchChanged);
    _pageController = PageController()
      ..addListener(() {
        setState(() {
          _currentPage = _pageController.page ?? 0;
        });
      });
  }

  @override
  void dispose() {
    _searchController.removeListener(_handleSearchChanged);
    _searchController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  void _handleSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text;
    });
    context.read<VendorsCubit>().search(_searchController.text);
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() {
      _searchQuery = '';
    });
    context.read<VendorsCubit>().search('');
  }

  void _openVendorDialog() {
    _openVendorDialogInternal(context);
  }

  Future<void> _openVendorDialogInternal(
    BuildContext context, {
    Vendor? vendor,
  }) async {
    await showDialog(
      context: context,
      builder: (dialogContext) => BlocProvider.value(
        value: context.read<VendorsCubit>(),
        child: _VendorDialog(vendor: vendor),
      ),
    );
  }

  List<Vendor> _applySearch(List<Vendor> vendors) {
    if (_searchQuery.isEmpty) return vendors;
    final query = _searchQuery.toLowerCase();
    return vendors
        .where((v) =>
            v.name.toLowerCase().contains(query) ||
            v.phoneNumber.contains(query) ||
            (v.gstNumber?.toLowerCase().contains(query) ?? false))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        BlocListener<VendorsCubit, VendorsState>(
      listener: (context, state) {
        if (state.status == ViewStatus.failure && state.message != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.message!)),
          );
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF000000),
        appBar: const ModernPageHeader(
          title: 'Vendors',
        ),
        body: SafeArea(
          child: Stack(
            children: [
              Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Builder(
              builder: (context) {
                final media = MediaQuery.of(context);
                final screenHeight = media.size.height;
                // Approximate available height: screen height minus status bar, header, nav, and padding
                final availableHeight = screenHeight - media.padding.top - 72 - media.padding.bottom - 80 - 24 - 48;
                // Reserve space for page indicator (24px) + spacing (16px) + scroll padding (48px)
                final pageViewHeight = (availableHeight - 24 - 16 - 48).clamp(400.0, 600.0);

                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Page Indicator (dots)
                    _PageIndicator(
                      pageCount: 2,
                      currentIndex: _currentPage,
                      onPageTap: (index) {
                        _pageController.animateToPage(
                          index,
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: pageViewHeight,
                      child: PageView(
                        controller: _pageController,
                        children: [
                          BlocBuilder<VendorsCubit, VendorsState>(
                            builder: (context, state) {
                              final allVendors = state.vendors;
                              final filteredVendors = _applySearch(allVendors);

                              return SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
          children: [
                                    // Search Bar
                                    _buildSearchBar(state),
                                    const SizedBox(height: 16),
                                    // Filter Chips
                                    _VendorFilterChips(
                                      selectedType: state.selectedVendorType,
                                      onTypeChanged: (type) {
                                        context.read<VendorsCubit>().filterByType(type);
                                      },
                                    ),
                                    const SizedBox(height: 16),
                                    // Results count
                                    if (state.searchQuery.isEmpty)
                                      Padding(
                                        padding: const EdgeInsets.only(bottom: 12),
                                        child: Text(
                                          '${filteredVendors.length} ${filteredVendors.length == 1 ? 'vendor' : 'vendors'}',
                                          style: TextStyle(
                                            color: Colors.white.withOpacity(0.6),
                                            fontSize: 13,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                    // Search Results or Recent Vendors
                                    if (state.searchQuery.isNotEmpty)
                                      _SearchResultsCard(
                                        vendors: filteredVendors,
                                        onClear: _clearSearch,
                                        searchQuery: _searchQuery,
                                      )
                                    else if (filteredVendors.isEmpty && state.status != ViewStatus.loading)
                                      _EmptyVendorsState(
                                        onAddVendor: _openVendorDialog,
                                        canCreate: context.read<VendorsCubit>().canCreate,
                                      )
                                    else
                                      _RecentVendorsList(
                                        state: state,
                                        vendors: filteredVendors,
                                        onEdit: (vendor) => _openVendorDialogInternal(context, vendor: vendor),
                                        onDelete: (vendor) => context.read<VendorsCubit>().deleteVendor(vendor.id),
                                      ),
                                  ],
                  ),
                );
              },
            ),
                          const SingleChildScrollView(
                            child: VendorAnalyticsPage(),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
                      ),
                    ),
                QuickNavBar(
                  currentIndex: 5,
                  onTap: (value) => context.go('/home', extra: value),
                ),
              ],
            ),
            // Quick Action Menu - only visible on Vendors page
            if (_currentPage.round() == 0)
              Builder(
                builder: (context) {
                  final media = MediaQuery.of(context);
                  final bottomPadding = media.padding.bottom;
                  // Nav bar height (~80px) + safe area bottom + spacing (20px)
                  final bottomOffset = 80 + bottomPadding + 20;
                  final cubit = context.read<VendorsCubit>();
                  
                  final actions = <QuickActionItem>[];

                  if (cubit.canCreate) {
                    actions.add(
                      QuickActionItem(
                        icon: Icons.add,
                        label: 'Add Vendor',
                        onTap: _openVendorDialog,
                      ),
                    );
                  }
              
                  if (actions.isEmpty) return const SizedBox.shrink();
                  
                  return QuickActionMenu(
                    right: 40,
                    bottom: bottomOffset,
                    actions: actions,
                  );
                },
              ),
          ],
        ),
      ),
      ),
      ),
      ],
    );
  }

  Widget _buildSearchBar(VendorsState state) {
    return TextField(
      controller: _searchController,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        prefixIcon: const Icon(Icons.search, color: Colors.white54),
        suffixIcon: _searchQuery.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.close, color: Colors.white54),
                onPressed: _clearSearch,
              )
            : null,
        hintText: 'Search vendors by name, phone, or GST',
        hintStyle: const TextStyle(color: Colors.white38),
        filled: true,
        fillColor: const Color(0xFF1B1B2C),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}

class _SearchResultsCard extends StatelessWidget {
  const _SearchResultsCard({
    required this.vendors,
    required this.onClear,
    required this.searchQuery,
  });

  final List<Vendor> vendors;
  final VoidCallback onClear;
  final String searchQuery;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
        color: const Color(0xFF131324),
          borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Search Results',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
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
          if (vendors.isEmpty)
            _EmptySearchState(query: searchQuery)
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: vendors.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final vendor = vendors[index];
                return _VendorTile(
                  vendor: vendor,
                );
              },
            ),
        ],
      ),
    );
  }
}

class _RecentVendorsList extends StatelessWidget {
  const _RecentVendorsList({
    required this.state,
    required this.vendors,
    required this.onEdit,
    required this.onDelete,
  });

  final VendorsState state;
  final List<Vendor> vendors;
  final ValueChanged<Vendor> onEdit;
  final ValueChanged<Vendor> onDelete;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
        child: Text(
                'All vendors',
          style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
          ),
        ),
      ),
            if (state.status == ViewStatus.loading)
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
          ],
        ),
        const SizedBox(height: 12),
        if (vendors.isEmpty && state.status != ViewStatus.loading)
          const SizedBox.shrink()
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: vendors.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final vendor = vendors[index];
              return _VendorTile(
                vendor: vendor,
                onEdit: () => onEdit(vendor),
                onDelete: () => onDelete(vendor),
              );
            },
          ),
      ],
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
    final hash = vendor.vendorType.name.hashCode;
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

  IconData _getVendorTypeIcon() {
    switch (vendor.vendorType) {
      case VendorType.rawMaterial:
        return Icons.inventory_2;
      case VendorType.vehicle:
        return Icons.directions_car;
      case VendorType.repairMaintenance:
        return Icons.build;
      case VendorType.fuel:
        return Icons.local_gas_station;
      case VendorType.utilities:
        return Icons.bolt;
      case VendorType.rent:
        return Icons.home;
      case VendorType.professionalServices:
        return Icons.business_center;
      case VendorType.marketingAdvertising:
        return Icons.campaign;
      case VendorType.insurance:
        return Icons.shield;
      case VendorType.logistics:
        return Icons.local_shipping;
      case VendorType.officeSupplies:
        return Icons.description;
      case VendorType.security:
        return Icons.security;
      case VendorType.cleaning:
        return Icons.cleaning_services;
      case VendorType.taxConsultant:
        return Icons.account_balance;
      case VendorType.bankingFinancial:
        return Icons.account_balance_wallet;
      case VendorType.welfare:
        return Icons.favorite;
      case VendorType.other:
        return Icons.store;
    }
  }

  String _formatVendorType() {
    return vendor.vendorType.name
        .split(RegExp(r'(?=[A-Z])'))
        .map((word) => word[0].toUpperCase() + word.substring(1))
        .join(' ');
  }

  @override
  Widget build(BuildContext context) {
    final vendorColor = _getVendorColor();
    final balanceDifference = vendor.currentBalance - vendor.openingBalance;
    final isPositive = balanceDifference >= 0;

    return InkWell(
      onTap: () => context.pushNamed('vendor-detail', extra: vendor),
      borderRadius: BorderRadius.circular(18),
      child: Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
            colors: [
              const Color(0xFF1F1F33).withOpacity(0.6),
              const Color(0xFF1A1A28).withOpacity(0.8),
            ],
        ),
        borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: vendorColor.withOpacity(0.2),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
        children: [
            Row(
              children: [
                // Avatar
          Container(
                  width: 48,
                  height: 48,
            decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        vendorColor,
                        vendorColor.withOpacity(0.7),
                      ],
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: vendorColor.withOpacity(0.4),
                        blurRadius: 8,
                        spreadRadius: -1,
                      ),
                    ],
                  ),
                  child: Center(
            child: Icon(
                      _getVendorTypeIcon(),
              color: Colors.white,
                      size: 24,
                    ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                  vendor.name,
                  style: const TextStyle(
                    color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          // Type Badge
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: vendorColor.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: vendorColor.withOpacity(0.3),
                              ),
                            ),
                            child: Text(
                              _formatVendorType(),
                              style: TextStyle(
                                color: vendorColor,
                    fontWeight: FontWeight.w600,
                                fontSize: 10,
                  ),
                            ),
                          ),
                        ],
                ),
                const SizedBox(height: 6),
                      // Phone
                      Row(
                        children: [
                          Icon(
                            Icons.phone_outlined,
                            size: 14,
                            color: Colors.white.withOpacity(0.7),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                  vendor.phoneNumber,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 13,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      // Balance
                      Row(
                        children: [
                          Icon(
                            Icons.account_balance_wallet_outlined,
                            size: 14,
                            color: Colors.white.withOpacity(0.7),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              '₹${vendor.currentBalance.toStringAsFixed(2)}',
                  style: TextStyle(
                    color: vendor.currentBalance >= 0
                                    ? const Color(0xFFFF9800)
                                    : const Color(0xFF4CAF50),
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (balanceDifference != 0)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: isPositive
                                    ? const Color(0xFF5AD8A4).withOpacity(0.15)
                                    : Colors.redAccent.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    isPositive ? Icons.arrow_upward : Icons.arrow_downward,
                                    size: 10,
                                    color: isPositive ? const Color(0xFF5AD8A4) : Colors.redAccent,
                                  ),
                                  const SizedBox(width: 2),
                                  Text(
                                    '₹${balanceDifference.abs().toStringAsFixed(2)}',
                                    style: TextStyle(
                                      color: isPositive ? const Color(0xFF5AD8A4) : Colors.redAccent,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Action buttons
                if (onEdit != null || onDelete != null)
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert, color: Colors.white54),
                    color: const Color(0xFF1B1B2C),
                    onSelected: (value) {
                      if (value == 'edit' && onEdit != null) {
                        onEdit!();
                      } else if (value == 'delete' && onDelete != null) {
                        onDelete!();
                      }
                    },
                    itemBuilder: (context) => [
                      if (onEdit != null)
                        const PopupMenuItem(
                          value: 'edit',
                          child: Row(
              children: [
                              Icon(Icons.edit, color: Colors.white70, size: 18),
                              SizedBox(width: 8),
                              Text('Edit', style: TextStyle(color: Colors.white70)),
                            ],
                          ),
                        ),
                      if (onDelete != null)
                        const PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(Icons.delete_outline, color: Colors.redAccent, size: 18),
                              SizedBox(width: 8),
                              Text('Delete', style: TextStyle(color: Colors.redAccent)),
                            ],
                          ),
                        ),
                    ],
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyVendorsState extends StatelessWidget {
  const _EmptyVendorsState({
    required this.onAddVendor,
    required this.canCreate,
  });

  final VoidCallback onAddVendor;
  final bool canCreate;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF1B1B2C).withOpacity(0.6),
            const Color(0xFF161622).withOpacity(0.8),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Colors.white.withOpacity(0.1),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: const Color(0xFF6F4BFF).withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.store_outlined,
              size: 32,
              color: Color(0xFF6F4BFF),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'No vendors yet',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            canCreate
                ? 'Start by adding your first vendor to the system'
                : 'No vendors to display.',
            style: TextStyle(
              color: Colors.white.withOpacity(0.6),
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
          if (canCreate) ...[
            const SizedBox(height: 24),
            ElevatedButton.icon(
              icon: const Icon(Icons.add, size: 20),
              label: const Text('Add Vendor'),
              onPressed: onAddVendor,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6F4BFF),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ],
      ),
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
            color: Colors.white.withOpacity(0.3),
          ),
          const SizedBox(height: 16),
          const Text(
            'No results found',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'No vendors match "$query"',
            style: TextStyle(
              color: Colors.white.withOpacity(0.6),
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
              ? const Color(0xFF6F4BFF).withOpacity(0.2)
              : const Color(0xFF1B1B2C).withOpacity(0.6),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF6F4BFF)
                : Colors.white.withOpacity(0.1),
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
                  ? const Color(0xFF6F4BFF)
                  : Colors.white.withOpacity(0.7),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.white.withOpacity(0.7),
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

class _PageIndicator extends StatelessWidget {
  const _PageIndicator({
    required this.pageCount,
    required this.currentIndex,
    required this.onPageTap,
  });

  final int pageCount;
  final double currentIndex;
  final ValueChanged<int> onPageTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(
        pageCount,
        (index) {
          final isActive = currentIndex.round() == index;
          return GestureDetector(
            onTap: () => onPageTap(index),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.symmetric(horizontal: 4),
              width: isActive ? 24 : 8,
              height: 8,
              decoration: BoxDecoration(
                color: isActive ? const Color(0xFF6F4BFF) : Colors.white24,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          );
        },
      ),
    );
  }
}

// Vendor Dialog - Simplified version (can be expanded)
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
  late final TextEditingController _openingBalanceController;
  VendorType _selectedVendorType = VendorType.other;
  VendorStatus _selectedStatus = VendorStatus.active;

  @override
  void initState() {
    super.initState();
    final vendor = widget.vendor;
    _nameController = TextEditingController(text: vendor?.name ?? '');
    _phoneController = TextEditingController(text: vendor?.phoneNumber ?? '');
    _openingBalanceController = TextEditingController(
      text: vendor != null
          ? vendor.openingBalance.toStringAsFixed(2)
          : '0.00',
    );
    if (vendor != null) {
      _selectedVendorType = vendor.vendorType;
      _selectedStatus = vendor.status;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _openingBalanceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<VendorsCubit>();
    final isEditing = widget.vendor != null;

    return AlertDialog(
      backgroundColor: const Color(0xFF0A0A0A),
      title: Text(
        isEditing ? 'Edit Vendor' : 'Add Vendor',
        style: const TextStyle(color: Colors.white),
      ),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameController,
                style: const TextStyle(color: Colors.white),
                decoration: _inputDecoration('Vendor name'),
                validator: (value) =>
                    (value == null || value.trim().isEmpty)
                        ? 'Enter vendor name'
                        : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _phoneController,
                style: const TextStyle(color: Colors.white),
                decoration: _inputDecoration('Phone number'),
                validator: (value) =>
                    (value == null || value.trim().isEmpty)
                        ? 'Enter phone number'
                        : null,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<VendorType>(
                initialValue: _selectedVendorType,
                dropdownColor: const Color(0xFF1B1B2C),
                style: const TextStyle(color: Colors.white),
                items: VendorType.values
                    .map(
                      (type) => DropdownMenuItem(
                        value: type,
                        child: Text(_formatVendorType(type)),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _selectedVendorType = value);
                  }
                },
                decoration: _inputDecoration('Vendor Type'),
                validator: (value) => value == null ? 'Select vendor type' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _openingBalanceController,
                enabled: !isEditing && cubit.canCreate,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                style: const TextStyle(color: Colors.white),
                decoration: _inputDecoration('Opening balance'),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Enter opening balance';
                  }
                  final parsed = double.tryParse(value);
                  if (parsed == null) return 'Enter valid number';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<VendorStatus>(
                initialValue: _selectedStatus,
                dropdownColor: const Color(0xFF1B1B2C),
                style: const TextStyle(color: Colors.white),
                items: VendorStatus.values
                    .map(
                      (status) => DropdownMenuItem(
                        value: status,
                        child: Text(_formatStatus(status)),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _selectedStatus = value);
                  }
                },
                decoration: _inputDecoration('Status'),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: (cubit.canCreate && !isEditing) ||
                  (cubit.canEdit && isEditing)
              ? () {
                  if (!(_formKey.currentState?.validate() ?? false)) return;

                  final normalizedPhone = _phoneController.text
                      .replaceAll(RegExp(r'[^0-9+]'), '');
                  final phoneNumber = normalizedPhone.startsWith('+')
                      ? normalizedPhone
                      : '+91$normalizedPhone';

                  final vendor = Vendor(
                    id: widget.vendor?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
                    vendorCode: widget.vendor?.vendorCode ?? '', // Will be auto-generated
                    name: _nameController.text.trim(),
                    nameLowercase: _nameController.text.trim().toLowerCase(),
                    phoneNumber: phoneNumber,
                    phoneNumberNormalized: normalizedPhone,
                    phones: [
                      {'number': phoneNumber, 'normalized': normalizedPhone}
                    ],
                    phoneIndex: [normalizedPhone],
                    openingBalance: widget.vendor?.openingBalance ??
                        double.parse(_openingBalanceController.text.trim()),
                    currentBalance: widget.vendor?.currentBalance ??
                        double.parse(_openingBalanceController.text.trim()),
                    vendorType: _selectedVendorType,
                    status: _selectedStatus,
                    organizationId: cubit.organizationId,
                  );

                  if (widget.vendor == null) {
                    context.read<VendorsCubit>().createVendor(vendor);
                  } else {
                    context.read<VendorsCubit>().updateVendor(vendor);
                  }
                  Navigator.of(context).pop();
                }
              : null,
          child: Text(isEditing ? 'Save' : 'Create'),
        ),
      ],
    );
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: const Color(0xFF1B1B2C),
      labelStyle: const TextStyle(color: Colors.white70),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
    );
  }

  String _formatVendorType(VendorType type) {
    return type.name
        .split(RegExp(r'(?=[A-Z])'))
        .map((word) => word[0].toUpperCase() + word.substring(1))
        .join(' ');
  }

  String _formatStatus(VendorStatus status) {
    return status.name[0].toUpperCase() + status.name.substring(1);
  }
}




