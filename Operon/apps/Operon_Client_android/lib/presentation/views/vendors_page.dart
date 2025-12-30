import 'package:core_bloc/core_bloc.dart';
import 'package:core_ui/core_ui.dart';
import 'package:core_models/core_models.dart';
import 'package:dash_mobile/presentation/blocs/vendors/vendors_cubit.dart';
import 'package:dash_mobile/presentation/blocs/vendors/vendors_state.dart';
import 'package:dash_mobile/presentation/widgets/page_workspace_layout.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class VendorsPage extends StatelessWidget {
  const VendorsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final cubit = context.watch<VendorsCubit>();
    return BlocListener<VendorsCubit, VendorsState>(
      listener: (context, state) {
        if (state.status == ViewStatus.failure && state.message != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.message!)),
          );
        }
      },
      child: PageWorkspaceLayout(
        title: 'Vendors',
        currentIndex: 5, // Update based on your navigation
        onBack: () => context.go('/home'),
        onNavTap: (value) => context.go('/home', extra: value),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                color: const Color(0xFF13131E),
                border: Border.all(color: Colors.white12),
              ),
              child: const Text(
                'Manage vendor information, balances, and transactions. Track payables by vendor type.',
                style: TextStyle(color: Colors.white70),
              ),
            ),
            const SizedBox(height: 20),
            // Search Bar
            BlocBuilder<VendorsCubit, VendorsState>(
              builder: (context, state) {
                return TextField(
                  onChanged: (value) => cubit.search(value),
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search, color: Colors.white54),
                    suffixIcon: state.searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.close, color: Colors.white54),
                            onPressed: () => cubit.search(''),
                          )
                        : null,
                    hintText: 'Search by name, phone, or GST number',
                    hintStyle: const TextStyle(color: Colors.white38),
                    filled: true,
                    fillColor: const Color(0xFF1B1B2C),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
            // Filter Chips
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _FilterChip(
                    label: 'All Types',
                    isSelected: cubit.state.selectedVendorType == null,
                    onTap: () => cubit.filterByType(null),
                  ),
                  const SizedBox(width: 8),
                  _FilterChip(
                    label: 'Raw Material',
                    isSelected: cubit.state.selectedVendorType == VendorType.rawMaterial,
                    onTap: () => cubit.filterByType(VendorType.rawMaterial),
                  ),
                  const SizedBox(width: 8),
                  _FilterChip(
                    label: 'Vehicle',
                    isSelected: cubit.state.selectedVendorType == VendorType.vehicle,
                    onTap: () => cubit.filterByType(VendorType.vehicle),
                  ),
                  const SizedBox(width: 8),
                  _FilterChip(
                    label: 'Repair',
                    isSelected: cubit.state.selectedVendorType == VendorType.repairMaintenance,
                    onTap: () => cubit.filterByType(VendorType.repairMaintenance),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            if (cubit.canCreate)
              SizedBox(
                width: double.infinity,
                child: DashButton(
                  label: 'Add Vendor',
                  onPressed: () => _openVendorDialog(context),
                ),
              )
            else
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: const Color(0x22FFFFFF),
                ),
                child: const Text(
                  'You have read-only access.',
                  style: TextStyle(color: Colors.white70),
                ),
              ),
            const SizedBox(height: 20),
            BlocBuilder<VendorsCubit, VendorsState>(
              builder: (context, state) {
                if (state.status == ViewStatus.loading && state.vendors.isEmpty) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (state.filteredVendors.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 40),
                    child: Text(
                      cubit.canCreate
                          ? 'No vendors yet. Tap "Add Vendor" to get started.'
                          : 'No vendors to display.',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.6),
                        fontSize: 16,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  );
                }
                return ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: state.filteredVendors.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final vendor = state.filteredVendors[index];
                    return _VendorTile(
                      vendor: vendor,
                      canEdit: cubit.canEdit,
                      canDelete: cubit.canDelete,
                      onEdit: () => _openVendorDialog(context, vendor: vendor),
                      onDelete: () => _handleDelete(context, vendor),
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openVendorDialog(
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

  Future<void> _handleDelete(BuildContext context, Vendor vendor) async {
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
      context.read<VendorsCubit>().deleteVendor(vendor.id);
    }
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF6F4BFF)
              : const Color(0xFF1B1B2C),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? Colors.transparent : Colors.white24,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.white70,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}

class _VendorTile extends StatelessWidget {
  const _VendorTile({
    required this.vendor,
    required this.canEdit,
    required this.canDelete,
    required this.onEdit,
    required this.onDelete,
  });

  final Vendor vendor;
  final bool canEdit;
  final bool canDelete;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1A1A2A), Color(0xFF11111B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white10,
              borderRadius: BorderRadius.circular(14),
            ),
            alignment: Alignment.center,
            child: Icon(
              _getVendorTypeIcon(vendor.vendorType),
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  vendor.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _formatVendorType(vendor.vendorType),
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
                const SizedBox(height: 4),
                Text(
                  vendor.phoneNumber,
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
                const SizedBox(height: 4),
                Text(
                  'Balance: ₹${vendor.currentBalance.toStringAsFixed(2)}',
                  style: TextStyle(
                    color: vendor.currentBalance >= 0
                        ? Colors.orange
                        : Colors.green,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          if (canEdit || canDelete)
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (canEdit)
                  IconButton(
                    icon: const Icon(Icons.edit, color: Colors.white54),
                    onPressed: onEdit,
                  ),
                if (canEdit && canDelete) const SizedBox(height: 8),
                if (canDelete)
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                    onPressed: onDelete,
                  ),
              ],
            ),
        ],
      ),
    );
  }

  IconData _getVendorTypeIcon(VendorType type) {
    switch (type) {
      case VendorType.rawMaterial:
        return Icons.inventory_2_outlined;
      case VendorType.vehicle:
        return Icons.directions_car_outlined;
      case VendorType.repairMaintenance:
        return Icons.build_outlined;
      case VendorType.fuel:
        return Icons.local_gas_station_outlined;
      case VendorType.utilities:
        return Icons.bolt_outlined;
      case VendorType.rent:
        return Icons.home_outlined;
      default:
        return Icons.store_outlined;
    }
  }

  String _formatVendorType(VendorType type) {
    return type.name
        .split(RegExp(r'(?=[A-Z])'))
        .map((word) => word[0].toUpperCase() + word.substring(1))
        .join(' ');
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
      backgroundColor: const Color(0xFF11111B),
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


