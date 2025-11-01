import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/widgets/page_container.dart';
import '../../../../core/widgets/page_header.dart';
import '../../../../core/widgets/custom_button.dart';
import '../../../../core/widgets/custom_text_field.dart';
import '../../../../core/widgets/custom_snackbar.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../contexts/organization_context.dart';
import '../../bloc/address_bloc.dart';
import '../../bloc/address_event.dart';
import '../../bloc/address_state.dart';
import '../../repositories/address_repository.dart';
import '../../models/address.dart';
import '../widgets/address_form_dialog.dart';
import '../../../auth/bloc/auth_bloc.dart';
import 'package:uuid/uuid.dart';

class AddressManagementPage extends StatelessWidget {
  final VoidCallback? onBack;

  const AddressManagementPage({
    super.key,
    this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return OrganizationAwareWidget(
      builder: (context, orgContext) {
        final organizationId = orgContext.organizationId;
        
        if (organizationId == null) {
          return Scaffold(
            body: Center(
              child: Text(
                'Organization not found',
                style: TextStyle(color: AppTheme.textPrimaryColor),
              ),
            ),
          );
        }

        return BlocProvider(
          create: (context) => AddressBloc(
            addressRepository: AddressRepository(),
          )..add(LoadAddresses(organizationId)),
          child: AddressManagementView(
            organizationId: organizationId,
            userRole: orgContext.userRole ?? 0,
            onBack: onBack,
          ),
        );
      },
    );
  }
}

class AddressManagementView extends StatelessWidget {
  final String organizationId;
  final int userRole;
  final VoidCallback? onBack;

  const AddressManagementView({
    super.key,
    required this.organizationId,
    required this.userRole,
    this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return BlocListener<AddressBloc, AddressState>(
      listener: (context, state) {
        if (state is AddressOperationSuccess) {
          CustomSnackBar.showSuccess(context, state.message);
        } else if (state is AddressError) {
          CustomSnackBar.showError(context, state.message);
        }
      },
      child: PageContainer(
        fullHeight: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            PageHeader(
              title: 'Addresses',
              onBack: onBack,
              role: _getRoleString(userRole),
            ),
            Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.95,
                  minWidth: 800,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: AppTheme.spacingLg),
                    _buildContent(context),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getRoleString(int userRole) {
    switch (userRole) {
      case 0:
        return 'admin';
      case 1:
        return 'admin';
      case 2:
        return 'manager';
      case 3:
        return 'driver';
      default:
        return 'member';
    }
  }

  Widget _buildContent(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF181C1F),
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.18),
                blurRadius: 12,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: AppTheme.spacingLg,
            vertical: AppTheme.spacingLg,
          ),
          child: _buildFilterBar(context),
        ),
        const SizedBox(height: AppTheme.spacingLg),
        
        LayoutBuilder(
          builder: (context, constraints) {
            return Container(
              decoration: BoxDecoration(
                color: const Color(0xFF141618).withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.1),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 32,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(AppTheme.spacingLg),
              width: double.infinity,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      const Text(
                        '📍',
                        style: TextStyle(fontSize: 24),
                      ),
                      const SizedBox(width: AppTheme.spacingSm),
                      const Text(
                        'Addresses',
                        style: TextStyle(
                          color: AppTheme.textPrimaryColor,
                          fontWeight: FontWeight.w600,
                          fontSize: 20,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppTheme.spacingLg),
                  BlocBuilder<AddressBloc, AddressState>(
                    builder: (context, state) {
                      if (state is AddressInitial || state is AddressLoading) {
                        return const Center(
                          child: Padding(
                            padding: EdgeInsets.all(AppTheme.spacing2xl),
                            child: CircularProgressIndicator(
                              color: AppTheme.primaryColor,
                            ),
                          ),
                        );
                      }
                      
                      if (state is AddressError) {
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.all(AppTheme.spacing2xl),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.error_outline,
                                  size: 64,
                                  color: AppTheme.errorColor,
                                ),
                                const SizedBox(height: AppTheme.spacingMd),
                                Text(
                                  state.message,
                                  style: const TextStyle(
                                    color: AppTheme.errorColor,
                                    fontSize: 16,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: AppTheme.spacingMd),
                                CustomButton(
                                  text: 'Retry',
                                  variant: CustomButtonVariant.primary,
                                  onPressed: () {
                                    context.read<AddressBloc>().add(
                                      LoadAddresses(organizationId),
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                        );
                      }
                      
                      if (state is AddressEmpty) {
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.all(AppTheme.spacing2xl),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text(
                                  '📍',
                                  style: TextStyle(fontSize: 64),
                                ),
                                const SizedBox(height: AppTheme.spacingMd),
                                Text(
                                  state.searchQuery != null
                                      ? 'No Addresses Found'
                                      : 'No Addresses',
                                  style: const TextStyle(
                                    color: AppTheme.textPrimaryColor,
                                    fontSize: 20,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: AppTheme.spacingSm),
                                Text(
                                  state.searchQuery != null
                                      ? 'No addresses match your search criteria'
                                      : 'Add your first address to get started',
                                  style: const TextStyle(
                                    color: AppTheme.textSecondaryColor,
                                    fontSize: 14,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: AppTheme.spacingLg),
                                if (state.searchQuery != null)
                                  CustomButton(
                                    text: 'Clear Search',
                                    variant: CustomButtonVariant.outline,
                                    onPressed: () {
                                      context.read<AddressBloc>().add(
                                        const ResetAddressSearch(),
                                      );
                                      context.read<AddressBloc>().add(
                                        LoadAddresses(organizationId),
                                      );
                                    },
                                  ),
                              ],
                            ),
                          ),
                        );
                      }
                      
                      if (state is AddressLoaded) {
                        return _buildAddressesTable(context, state.addresses);
                      }
                      
                      return const SizedBox.shrink();
                    },
                  ),
                ],
              ),
            );
          },
        ),
        const SizedBox(height: AppTheme.spacingLg),
      ],
    );
  }

  Widget _buildFilterBar(BuildContext context) {
    return Row(
      children: [
        CustomButton(
          text: '➕ Add Address',
          variant: CustomButtonVariant.primary,
          onPressed: () => _showAddAddressDialog(context),
        ),
        const Spacer(),
        SizedBox(
          width: 300,
          child: BlocBuilder<AddressBloc, AddressState>(
            builder: (context, state) {
              return CustomTextField(
                hintText: 'Search addresses...',
                prefixIcon: const Icon(Icons.search, size: 18),
                variant: CustomTextFieldVariant.search,
                onChanged: (query) {
                  if (query.isEmpty) {
                    context.read<AddressBloc>().add(
                      const ResetAddressSearch(),
                    );
                    context.read<AddressBloc>().add(
                      LoadAddresses(organizationId),
                    );
                  } else {
                    context.read<AddressBloc>().add(
                      SearchAddresses(
                        organizationId: organizationId,
                        query: query,
                      ),
                    );
                  }
                },
                suffixIcon: state is AddressLoaded && 
                            state.searchQuery != null &&
                            state.searchQuery!.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          context.read<AddressBloc>().add(
                            const ResetAddressSearch(),
                          );
                          context.read<AddressBloc>().add(
                            LoadAddresses(organizationId),
                          );
                        },
                      )
                    : null,
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildAddressesTable(
    BuildContext context,
    List<Address> addresses,
  ) {
    const double minTableWidth = 1100;
    
    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth;
        final tableWidth = availableWidth > minTableWidth 
            ? availableWidth 
            : minTableWidth;
            
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: tableWidth,
            child: DataTable(
              headingRowHeight: 52,
              dataRowMinHeight: 60,
              dataRowMaxHeight: 80,
              horizontalMargin: 0,
              columnSpacing: 24,
              headingRowColor: MaterialStateProperty.all(
                const Color(0xFF1F2937).withValues(alpha: 0.8),
              ),
              dataRowColor: MaterialStateProperty.resolveWith<Color?>(
                (Set<MaterialState> states) {
                  if (states.contains(MaterialState.selected)) {
                    return const Color(0xFF374151).withValues(alpha: 0.5);
                  }
                  if (states.contains(MaterialState.hovered)) {
                    return const Color(0xFF374151).withValues(alpha: 0.3);
                  }
                  return Colors.transparent;
                },
              ),
              dividerThickness: 1,
              columns: [
                DataColumn(
                  label: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Text(
                      'ADDRESS ID',
                      style: TextStyle(
                        color: AppTheme.textSecondaryColor,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
                DataColumn(
                  label: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Text(
                      'ADDRESS NAME',
                      style: TextStyle(
                        color: AppTheme.textSecondaryColor,
                        fontWeight: FontWeight.w700,
                        fontSize: 11,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
                DataColumn(
                  label: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Text(
                      'FULL ADDRESS',
                      style: TextStyle(
                        color: AppTheme.textSecondaryColor,
                        fontWeight: FontWeight.w700,
                        fontSize: 11,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
                DataColumn(
                  label: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Text(
                      'REGION',
                      style: TextStyle(
                        color: AppTheme.textSecondaryColor,
                        fontWeight: FontWeight.w700,
                        fontSize: 11,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
                DataColumn(
                  label: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Text(
                      'CITY/STATE',
                      style: TextStyle(
                        color: AppTheme.textSecondaryColor,
                        fontWeight: FontWeight.w700,
                        fontSize: 11,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
                DataColumn(
                  label: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Text(
                      'STATUS',
                      style: TextStyle(
                        color: AppTheme.textSecondaryColor,
                        fontWeight: FontWeight.w700,
                        fontSize: 11,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
                DataColumn(
                  label: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Text(
                      'ACTIONS',
                      style: TextStyle(
                        color: AppTheme.textSecondaryColor,
                        fontWeight: FontWeight.w700,
                        fontSize: 11,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
              ],
              rows: addresses.map((address) {
                return DataRow(
                  cells: [
                    DataCell(
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 12,
                        ),
                        child: Text(
                          address.addressId,
                          style: const TextStyle(
                            color: AppTheme.textPrimaryColor,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                    DataCell(
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 12,
                        ),
                        child: Text(
                          address.addressName,
                          style: const TextStyle(
                            color: AppTheme.textPrimaryColor,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                    DataCell(
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 12,
                        ),
                        child: SizedBox(
                          width: 200,
                          child: Text(
                            address.address,
                            style: const TextStyle(
                              color: AppTheme.textSecondaryColor,
                              fontSize: 14,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ),
                    DataCell(
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 12,
                        ),
                        child: Text(
                          address.region,
                          style: const TextStyle(
                            color: AppTheme.textPrimaryColor,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                    DataCell(
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 12,
                        ),
                        child: Text(
                          '${address.city ?? '—'}/${address.state ?? '—'}',
                          style: const TextStyle(
                            color: AppTheme.textSecondaryColor,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                    DataCell(
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 12,
                        ),
                        child: _buildStatusBadge(address.status),
                      ),
                    ),
                    DataCell(
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 12,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit, size: 18),
                              color: AppTheme.warningColor,
                              onPressed: () => _showEditAddressDialog(
                                context,
                                address,
                              ),
                              style: IconButton.styleFrom(
                                backgroundColor: AppTheme.warningColor
                                    .withValues(alpha: 0.1),
                                padding: const EdgeInsets.all(8),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(6),
                                ),
                              ),
                            ),
                            const SizedBox(width: AppTheme.spacingXs),
                            IconButton(
                              icon: const Icon(Icons.delete, size: 18),
                              color: AppTheme.errorColor,
                              onPressed: () => _showDeleteConfirmation(
                                context,
                                address,
                              ),
                              style: IconButton.styleFrom(
                                backgroundColor: AppTheme.errorColor
                                    .withValues(alpha: 0.1),
                                padding: const EdgeInsets.all(8),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(6),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatusBadge(String status) {
    Color color;
    if (status == 'Active') {
      color = AppTheme.successColor;
    } else {
      color = AppTheme.textTertiaryColor;
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacingSm,
        vertical: AppTheme.spacingXs,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        border: Border.all(
          color: color.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  void _showAddAddressDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => AddressFormDialog(
        onSubmit: (address) {
          Navigator.of(dialogContext).pop();
          _submitAddress(context, address);
        },
        onCancel: () => Navigator.of(dialogContext).pop(),
      ),
    );
  }

  void _showEditAddressDialog(
    BuildContext context,
    Address address,
  ) {
    showDialog(
      context: context,
      builder: (dialogContext) => AddressFormDialog(
        address: address,
        onSubmit: (updatedAddress) {
          Navigator.of(dialogContext).pop();
          _updateAddress(context, address, updatedAddress);
        },
        onCancel: () => Navigator.of(dialogContext).pop(),
      ),
    );
  }

  void _showDeleteConfirmation(
    BuildContext context,
    Address address,
  ) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppTheme.surfaceColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusXl),
          side: BorderSide(
            color: AppTheme.borderColor,
            width: 1,
          ),
        ),
        title: const Text(
          'Delete Address',
          style: TextStyle(
            color: AppTheme.errorColor,
            fontWeight: FontWeight.w600,
          ),
        ),
        content: Text(
          'Are you sure you want to delete "${address.addressName}"?',
          style: const TextStyle(color: AppTheme.textPrimaryColor),
        ),
        actions: [
          CustomButton(
            text: 'Cancel',
            variant: CustomButtonVariant.outline,
            onPressed: () => Navigator.of(dialogContext).pop(),
          ),
          const SizedBox(width: AppTheme.spacingSm),
          CustomButton(
            text: 'Delete',
            variant: CustomButtonVariant.danger,
            onPressed: () {
              Navigator.of(dialogContext).pop();
              _deleteAddress(context, address);
            },
          ),
        ],
      ),
    );
  }

  void _submitAddress(
    BuildContext context,
    Address address,
  ) {
    final authState = context.read<AuthBloc>().state;
    final userId = authState is AuthAuthenticated
        ? authState.firebaseUser.uid
        : const Uuid().v4();

    context.read<AddressBloc>().add(
      AddAddress(
        organizationId: organizationId,
        address: address,
        userId: userId,
      ),
    );
  }

  void _updateAddress(
    BuildContext context,
    Address oldAddress,
    Address newAddress,
  ) {
    final authState = context.read<AuthBloc>().state;
    final userId = authState is AuthAuthenticated
        ? authState.firebaseUser.uid
        : const Uuid().v4();

    context.read<AddressBloc>().add(
      UpdateAddress(
        organizationId: organizationId,
        addressId: oldAddress.id!,
        address: newAddress,
        userId: userId,
      ),
    );
  }

  void _deleteAddress(
    BuildContext context,
    Address address,
  ) {
    context.read<AddressBloc>().add(
      DeleteAddress(
        organizationId: organizationId,
        addressId: address.id!,
      ),
    );
  }
}

