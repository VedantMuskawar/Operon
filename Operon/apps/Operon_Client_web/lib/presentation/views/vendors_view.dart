import 'package:core_bloc/core_bloc.dart';
import 'package:core_models/core_models.dart';
import 'package:dash_web/presentation/blocs/vendors/vendors_cubit.dart';
import 'package:dash_web/presentation/blocs/vendors/vendors_state.dart';
import 'package:dash_web/presentation/blocs/org_context/org_context_cubit.dart';
import 'package:dash_web/data/repositories/raw_materials_repository.dart';
import 'package:dash_web/presentation/widgets/vendor_detail_modal.dart';
import 'package:core_datasources/core_datasources.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

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
  bool _isListView = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<VendorsCubit>().loadVendors();
    });
  }

  List<Vendor> _applyFiltersAndSort(List<Vendor> vendors) {
    var filtered = List<Vendor>.from(vendors);

    // Apply search filter
    if (_query.isNotEmpty) {
      final queryLower = _query.toLowerCase();
      filtered = filtered.where((v) {
        return v.name.toLowerCase().contains(queryLower) ||
            v.phoneNumber.contains(_query) ||
            (v.gstNumber?.toLowerCase().contains(queryLower) ?? false);
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
          return _LoadingState();
        }
        if (state.status == ViewStatus.failure && state.vendors.isEmpty) {
          return _ErrorState(
            message: state.message ?? 'Failed to load vendors',
            onRetry: () => cubit.loadVendors(),
          );
        }

        final vendors = state.vendors;
        final filtered = _applyFiltersAndSort(vendors);

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
                  color: const Color(0xFF1B1B2C).withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.1),
                  ),
                ),
                          child: TextField(
                      onChanged: (v) => setState(() => _query = v),
                            style: const TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                        hintText: 'Search vendors by name, phone, or GST...',
                              hintStyle: TextStyle(
                                color: Colors.white.withValues(alpha: 0.4),
                              ),
                              filled: true,
                        fillColor: Colors.transparent,
                        prefixIcon: const Icon(Icons.search, color: Colors.white54),
                        suffixIcon: _query.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, color: Colors.white54),
                                onPressed: () => setState(() => _query = ''),
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
                    color: const Color(0xFF1B1B2C).withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.1),
                    ),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<VendorType?>(
                      value: _selectedTypeFilter,
                      hint: Row(
                        mainAxisSize: MainAxisSize.min,
                      children: [
                          Icon(Icons.category, size: 16, color: Colors.white.withValues(alpha: 0.7)),
                          const SizedBox(width: 6),
                          Text(
                            'All Types',
                            style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 14),
                  ),
                ],
              ),
                      dropdownColor: const Color(0xFF1B1B2C),
                      style: const TextStyle(color: Colors.white, fontSize: 14),
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
                      icon: Icon(Icons.arrow_drop_down, color: Colors.white.withValues(alpha: 0.7), size: 20),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Status Filter
              Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF1B1B2C).withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.1),
                  ),
                ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<VendorStatus?>(
                      value: _selectedStatusFilter,
                      hint: Row(
                        mainAxisSize: MainAxisSize.min,
                  children: [
                          Icon(Icons.filter_list, size: 16, color: Colors.white.withValues(alpha: 0.7)),
                          const SizedBox(width: 6),
                        Text(
                            'All Status',
                            style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 14),
                          ),
                        ],
                      ),
                      dropdownColor: const Color(0xFF1B1B2C),
                      style: const TextStyle(color: Colors.white, fontSize: 14),
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
                      icon: Icon(Icons.arrow_drop_down, color: Colors.white.withValues(alpha: 0.7), size: 20),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Sort Options
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1B1B2C).withValues(alpha: 0.6),
                                borderRadius: BorderRadius.circular(12),
                    border: Border.all(
              color: Colors.white.withValues(alpha: 0.1),
            ),
          ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
            children: [
                      Icon(Icons.sort, size: 16, color: Colors.white.withValues(alpha: 0.7)),
                      const SizedBox(width: 6),
                      DropdownButtonHideUnderline(
                        child: DropdownButton<_VendorSortOption>(
                          value: _sortOption,
                          dropdownColor: const Color(0xFF1B1B2C),
                          style: const TextStyle(color: Colors.white, fontSize: 14),
                          items: const [
                            DropdownMenuItem(
                              value: _VendorSortOption.nameAsc,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                  children: [
                                  Icon(Icons.sort_by_alpha, size: 16, color: Colors.white70),
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
                                  Icon(Icons.sort_by_alpha, size: 16, color: Colors.white70),
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
                                  Icon(Icons.trending_down, size: 16, color: Colors.white70),
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
                                  Icon(Icons.trending_up, size: 16, color: Colors.white70),
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
                                  Icon(Icons.category, size: 16, color: Colors.white70),
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
                          icon: Icon(Icons.arrow_drop_down, color: Colors.white.withValues(alpha: 0.7), size: 20),
                          isDense: true,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                // View Toggle
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF1B1B2C).withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
            color: Colors.white.withValues(alpha: 0.1),
          ),
        ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
          children: [
                      _ViewToggleButton(
                        icon: Icons.grid_view,
                        isSelected: !_isListView,
                        onTap: () => setState(() => _isListView = false),
                        tooltip: 'Grid View',
                      ),
                      Container(
                        width: 1,
                        height: 32,
                        color: Colors.white.withValues(alpha: 0.1),
                      ),
                      _ViewToggleButton(
                        icon: Icons.list,
                        isSelected: _isListView,
                        onTap: () => setState(() => _isListView = true),
                        tooltip: 'List View',
            ),
          ],
        ),
              ),
                const SizedBox(width: 12),
                // Results count
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1B1B2C).withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.1),
                    ),
                  ),
            child: Text(
                    '${filtered.length} ${filtered.length == 1 ? 'vendor' : 'vendors'}',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                          ),
                        ),
                        ),
                const SizedBox(width: 12),
                // Add Vendor Button
                          ElevatedButton.icon(
                  icon: const Icon(Icons.add, size: 20),
                  label: const Text('Add Vendor'),
                  onPressed: () {
                    final cubit = context.read<VendorsCubit>();
                    _showVendorDialog(context, null, cubit);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6F4BFF),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 16,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
          ),
        ],
      ),
            const SizedBox(height: 24),
            
            // Vendor Grid/List
            if (filtered.isEmpty && (_query.isNotEmpty || _selectedTypeFilter != null || _selectedStatusFilter != null))
              _EmptySearchState(query: _query)
            else if (filtered.isEmpty)
              _EmptyVendorsState(
                onAddVendor: () => _showVendorDialog(context, null, context.read<VendorsCubit>()),
              )
            else if (_isListView)
              _VendorListView(
                vendors: filtered,
                onTap: (vendor) => _openVendorDetail(context, vendor),
                onEdit: (vendor) => _showVendorDialog(context, vendor, context.read<VendorsCubit>()),
                onDelete: (vendor) => _handleDeleteVendor(context, vendor, context.read<VendorsCubit>()),
                )
              else
              LayoutBuilder(
                builder: (context, constraints) {
                  final crossAxisCount = constraints.maxWidth > 1400
                      ? 4
                      : constraints.maxWidth > 1050
                          ? 3
                          : constraints.maxWidth > 700
                              ? 2
                              : 1;
                  return GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: crossAxisCount,
                      crossAxisSpacing: 20,
                      mainAxisSpacing: 20,
                      childAspectRatio: 1.25,
                    ),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final cubit = context.read<VendorsCubit>();
                      return _VendorCard(
                        vendor: filtered[index],
                        onTap: () => _openVendorDetail(context, filtered[index]),
                        onEdit: () => _showVendorDialog(context, filtered[index], cubit),
                        onDelete: () => _handleDeleteVendor(context, filtered[index], cubit),
        );
      },
    );
                },
              ),
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
            color: const Color(0xFF6F4BFF),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _StatCard(
                      icon: Icons.check_circle_outline,
            label: 'Active Vendors',
                      value: activeVendors.toString(),
            color: const Color(0xFF5AD8A4),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _StatCard(
                      icon: Icons.account_balance_wallet_outlined,
            label: 'Total Payable',
                      value: '₹${totalPayable.toStringAsFixed(2)}',
                      color: const Color(0xFFFF9800),
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
                    color: const Color(0xFF6F4BFF),
                  ),
                  _StatCard(
                    icon: Icons.check_circle_outline,
                    label: 'Active Vendors',
                    value: activeVendors.toString(),
                    color: const Color(0xFF5AD8A4),
                  ),
                  _StatCard(
                    icon: Icons.account_balance_wallet_outlined,
                    label: 'Total Payable',
                    value: '₹${totalPayable.toStringAsFixed(2)}',
                    color: const Color(0xFFFF9800),
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
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF1F1F33),
            Color(0xFF1A1A28),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
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
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    color: Colors.white,
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

class _LoadingState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 24),
          Text(
            'Loading vendors...',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 16,
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
            ElevatedButton.icon(
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Retry'),
              onPressed: onRetry,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6F4BFF),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
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
            ElevatedButton.icon(
              icon: const Icon(Icons.add, size: 20),
              label: const Text('Add Vendor'),
              onPressed: onAddVendor,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6F4BFF),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 16,
                        ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                      ),
                    ),
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

class _VendorCard extends StatefulWidget {
  const _VendorCard({
    required this.vendor,
    this.onTap,
    this.onEdit,
    this.onDelete,
  });

  final Vendor vendor;
  final VoidCallback? onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  @override
  State<_VendorCard> createState() => _VendorCardState();
}

class _VendorCardState extends State<_VendorCard>
    with SingleTickerProviderStateMixin {
  bool _isHovered = false;
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

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

  IconData _getVendorTypeIcon(VendorType type) {
    switch (type) {
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
        return Icons.category;
    }
  }

  String _formatVendorType(VendorType type) {
    return type.name
        .split(RegExp(r'(?=[A-Z])'))
        .map((word) => word[0].toUpperCase() + word.substring(1))
        .join(' ');
  }

  @override
  Widget build(BuildContext context) {
    final typeColor = _getVendorTypeColor(widget.vendor.vendorType);
    final balanceDifference = widget.vendor.currentBalance - widget.vendor.openingBalance;
    final isPositive = balanceDifference >= 0;
    final percentChange = widget.vendor.openingBalance != 0
        ? (balanceDifference / widget.vendor.openingBalance * 100)
        : 0.0;

    return MouseRegion(
      onEnter: (_) {
        setState(() => _isHovered = true);
        _controller.forward();
      },
      onExit: (_) {
        setState(() => _isHovered = false);
        _controller.reverse();
      },
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Transform.scale(
              scale: 1.0 + (_controller.value * 0.02),
              child: Container(
      decoration: BoxDecoration(
                gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
                    Color(0xFF1F1F33),
                    Color(0xFF1A1A28),
          ],
        ),
                borderRadius: BorderRadius.circular(20),
        border: Border.all(
                  color: _isHovered
                      ? typeColor.withValues(alpha: 0.5)
                      : Colors.white.withValues(alpha: 0.1),
                  width: _isHovered ? 1.5 : 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 15,
                    offset: const Offset(0, 5),
                  ),
                  if (_isHovered)
                    BoxShadow(
                      color: typeColor.withValues(alpha: 0.2),
                      blurRadius: 20,
                      spreadRadius: -5,
                      offset: const Offset(0, 10),
                    ),
                ],
              ),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 20,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Header with Avatar
                        Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    typeColor,
                                    typeColor.withValues(alpha: 0.7),
                                  ],
                                ),
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: typeColor.withValues(alpha: 0.4),
                                    blurRadius: 12,
                                    spreadRadius: -2,
                                  ),
                                ],
            ),
            child: Icon(
                                _getVendorTypeIcon(widget.vendor.vendorType),
                                color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                                  Text(
                                    widget.vendor.name,
                        style: const TextStyle(
                          color: Colors.white,
                                      fontWeight: FontWeight.w700,
                          fontSize: 18,
                                      letterSpacing: -0.5,
                        ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                      ),
                                  const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                                      color: typeColor.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: typeColor.withValues(alpha: 0.3),
                                      ),
                      ),
                      child: Text(
                                      _formatVendorType(widget.vendor.vendorType),
                        style: TextStyle(
                                        color: typeColor,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
                            ),
                          ],
                        ),
                        
                        // Balance Section
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.08),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Current Balance',
                                    style: TextStyle(
                                      color: Colors.white.withValues(alpha: 0.7),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isPositive
                                          ? const Color(0xFF5AD8A4)
                                              .withValues(alpha: 0.2)
                                          : Colors.redAccent.withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                                          isPositive
                                              ? Icons.arrow_upward
                                              : Icons.arrow_downward,
                                          size: 12,
                                          color: isPositive
                                              ? const Color(0xFF5AD8A4)
                                              : Colors.redAccent,
                    ),
                    const SizedBox(width: 4),
                    Text(
                                          '${isPositive ? '+' : ''}₹${balanceDifference.abs().toStringAsFixed(2)}',
                                          style: TextStyle(
                                            color: isPositive
                                                ? const Color(0xFF5AD8A4)
                                                : Colors.redAccent,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        if (widget.vendor.openingBalance != 0) ...[
                                          const SizedBox(width: 4),
                                          Text(
                                            '(${isPositive ? '+' : ''}${percentChange.abs().toStringAsFixed(1)}%)',
                                            style: TextStyle(
                                              color: isPositive
                                                  ? const Color(0xFF5AD8A4)
                                                  : Colors.redAccent,
                                              fontSize: 10,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '₹${widget.vendor.currentBalance.toStringAsFixed(2)}',
                                style: TextStyle(
                                  color: widget.vendor.currentBalance >= 0
                                      ? const Color(0xFFFF9800)
                                      : const Color(0xFF4CAF50),
                                  fontWeight: FontWeight.w700,
                                  fontSize: 20,
                                  letterSpacing: -0.5,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Opening: ₹${widget.vendor.openingBalance.toStringAsFixed(2)}',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.6),
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                        
                        // Vendor Info
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                    Icon(
                      Icons.phone,
                      size: 14,
                      color: Colors.white.withValues(alpha: 0.6),
                    ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    widget.vendor.phoneNumber,
                      style: TextStyle(
                                      color: Colors.white.withValues(alpha: 0.7),
                                      fontSize: 13,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                            if (widget.vendor.vendorCode.isNotEmpty) ...[
                  const SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(
                                    Icons.qr_code,
                                    size: 14,
                                    color: Colors.white.withValues(alpha: 0.6),
                                  ),
                                  const SizedBox(width: 6),
                  Text(
                                    widget.vendor.vendorCode,
                    style: TextStyle(
                                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
                              ),
                            ],
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: widget.vendor.status == VendorStatus.active
                                    ? const Color(0xFF5AD8A4).withValues(alpha: 0.2)
                                    : Colors.grey.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                widget.vendor.status.name.toUpperCase(),
                                style: TextStyle(
                                  color: widget.vendor.status == VendorStatus.active
                                      ? const Color(0xFF5AD8A4)
                                      : Colors.grey,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  
                  // Action Buttons (appear on hover)
                  if (_isHovered)
                    Positioned(
                      top: 12,
                      right: 12,
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF1B1B2C).withValues(alpha: 0.95),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.1),
                          ),
                        ),
                        child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
                            if (widget.onEdit != null)
                              IconButton(
                                icon: const Icon(Icons.edit, size: 18),
                                color: Colors.white70,
                                onPressed: widget.onEdit,
                                tooltip: 'Edit',
                                padding: const EdgeInsets.all(8),
                                constraints: const BoxConstraints(),
                              ),
                            if (widget.onEdit != null && widget.onDelete != null)
                              Container(
                                width: 1,
                                height: 24,
                                color: Colors.white.withValues(alpha: 0.1),
                              ),
                            if (widget.onDelete != null)
                              IconButton(
                                icon: const Icon(Icons.delete_outline, size: 18),
                                color: Colors.redAccent,
                                onPressed: widget.onDelete,
                                tooltip: 'Delete',
                                padding: const EdgeInsets.all(8),
                                constraints: const BoxConstraints(),
                              ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
        ),
      ),
    );
  }
}

class _ViewToggleButton extends StatelessWidget {
  const _ViewToggleButton({
    required this.icon,
    required this.isSelected,
    required this.onTap,
    required this.tooltip,
  });

  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: isSelected
                ? const Color(0xFF6F4BFF).withValues(alpha: 0.2)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            size: 20,
            color: isSelected
                ? const Color(0xFF6F4BFF)
                : Colors.white.withValues(alpha: 0.6),
          ),
        ),
      ),
    );
  }
}

class _VendorListView extends StatelessWidget {
  const _VendorListView({
    required this.vendors,
    this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  final List<Vendor> vendors;
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

  IconData _getVendorTypeIcon(VendorType type) {
    switch (type) {
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
        return Icons.category;
    }
  }

  String _formatVendorType(VendorType type) {
    return type.name
        .split(RegExp(r'(?=[A-Z])'))
        .map((word) => word[0].toUpperCase() + word.substring(1))
        .join(' ');
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: vendors.map((vendor) {
        final typeColor = _getVendorTypeColor(vendor.vendorType);
        final balanceDifference = vendor.currentBalance - vendor.openingBalance;
        final isPositive = balanceDifference >= 0;
        final percentChange = vendor.openingBalance != 0
            ? (balanceDifference / vendor.openingBalance * 100)
            : 0.0;

    return GestureDetector(
      onTap: onTap != null ? () => onTap!(vendor) : null,
      child: Container(
          margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
            gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
                Color(0xFF1F1F33),
                Color(0xFF1A1A28),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.1),
        ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
      ),
      child: Row(
        children: [
              // Avatar
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      typeColor,
                      typeColor.withValues(alpha: 0.7),
                    ],
                  ),
                  shape: BoxShape.circle,
            ),
            child: Icon(
              _getVendorTypeIcon(vendor.vendorType),
                  color: Colors.white,
              size: 28,
            ),
          ),
              const SizedBox(width: 20),
              // Name and Type
          Expanded(
                flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                    Text(
                        vendor.name,
                        style: const TextStyle(
                          color: Colors.white,
                        fontWeight: FontWeight.w700,
                          fontSize: 18,
                        letterSpacing: -0.5,
                        ),
                      ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: typeColor.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: typeColor.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Text(
                        _formatVendorType(vendor.vendorType),
                        style: TextStyle(
                          color: typeColor,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Balance
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '₹${vendor.currentBalance.toStringAsFixed(2)}',
                    style: TextStyle(
                      color: vendor.currentBalance >= 0
                          ? const Color(0xFFFF9800)
                          : const Color(0xFF4CAF50),
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                          isPositive ? Icons.arrow_upward : Icons.arrow_downward,
                          size: 12,
                          color: isPositive ? const Color(0xFF5AD8A4) : Colors.redAccent,
                    ),
                    const SizedBox(width: 4),
                  Text(
                          '${isPositive ? '+' : ''}₹${balanceDifference.abs().toStringAsFixed(2)}',
                    style: TextStyle(
                            color: isPositive ? const Color(0xFF5AD8A4) : Colors.redAccent,
                      fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (vendor.openingBalance != 0) ...[
                          const SizedBox(width: 4),
                  Text(
                            '(${isPositive ? '+' : ''}${percentChange.abs().toStringAsFixed(1)}%)',
                    style: TextStyle(
                              color: isPositive ? const Color(0xFF5AD8A4) : Colors.redAccent,
                              fontSize: 11,
                    ),
                  ),
                ],
              ],
              ),
            ],
          ),
              ),
              // Phone
              Expanded(
                flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                    Row(
                      children: [
                        Icon(
                      Icons.phone,
                      size: 14,
                  color: Colors.white.withValues(alpha: 0.6),
                    ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                      vendor.phoneNumber,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.8),
                        fontSize: 14,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                if (vendor.vendorCode.isNotEmpty) ...[
                  const SizedBox(height: 4),
                      Row(
                      children: [
                        Icon(
                            Icons.qr_code,
                            size: 14,
                            color: Colors.white.withValues(alpha: 0.6),
                          ),
                          const SizedBox(width: 6),
                        Text(
                            vendor.vendorCode,
                          style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.7),
                  fontSize: 12,
                              fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                ],
              ],
            ),
          ),
              // Actions
              Row(
            mainAxisSize: MainAxisSize.min,
            children: [
                  IconButton(
                    icon: const Icon(Icons.edit, size: 20),
                    color: Colors.white70,
                    onPressed: () => onEdit(vendor),
                    tooltip: 'Edit',
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, size: 20),
                    color: Colors.redAccent,
                    onPressed: () => onDelete(vendor),
                    tooltip: 'Delete',
                  ),
                ],
              ),
            ],
          ),
        ),
      );
      }).toList(),
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
        // Refresh vendors list if needed
        context.read<VendorsCubit>().loadVendors();
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
        backgroundColor: const Color(0xFF11111B),
        title: const Text(
          'Cannot Delete Vendor',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          'Cannot delete vendor with pending balance.\n'
          'Current balance: ₹${vendor.currentBalance.toStringAsFixed(2)}\n\n'
          'Please settle the balance first.',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
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
      backgroundColor: const Color(0xFF11111B),
      title: const Text(
        'Delete Vendor',
        style: TextStyle(color: Colors.white),
      ),
      content: Text(
        'Are you sure you want to delete "${vendor.name}"?',
        style: const TextStyle(color: Colors.white70),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          style: TextButton.styleFrom(foregroundColor: Colors.red),
          child: const Text('Delete'),
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load raw materials: $e')),
        );
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
                        value: _selectedType,
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
                        Row(
                          children: [
                            const Icon(
                              Icons.inventory_2_outlined,
                              color: Colors.white70,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            const Text(
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
                  value: _selectedStatus,
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
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.white70,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 12),
                  ElevatedButton.icon(
                    icon: Icon(_isEditing ? Icons.check : Icons.add, size: 18),
                    label: Text(_isEditing ? 'Save Changes' : 'Create Vendor'),
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
          color: Color(0xFF6F4BFF),
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
