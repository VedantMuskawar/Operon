import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/widgets/page_container.dart';
import '../../../../core/widgets/page_header.dart';
import '../../../../core/widgets/custom_button.dart';
import '../../../../core/widgets/custom_text_field.dart';
import '../../../../core/widgets/custom_snackbar.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../contexts/organization_context.dart';
import '../../bloc/location_pricing_bloc.dart';
import '../../bloc/location_pricing_event.dart';
import '../../bloc/location_pricing_state.dart';
import '../../repositories/location_pricing_repository.dart';
import '../../models/location_pricing.dart';
import '../widgets/location_pricing_form_dialog.dart';
import '../../../auth/bloc/auth_bloc.dart';
import 'package:uuid/uuid.dart';

class LocationPricingManagementPage extends StatelessWidget {
  final VoidCallback? onBack;

  const LocationPricingManagementPage({
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
          create: (context) => LocationPricingBloc(
            locationPricingRepository: LocationPricingRepository(),
          )..add(LoadLocationPricing(organizationId)),
          child: LocationPricingManagementView(
            organizationId: organizationId,
            userRole: orgContext.userRole ?? 0,
            onBack: onBack,
          ),
        );
      },
    );
  }
}

class LocationPricingManagementView extends StatelessWidget {
  final String organizationId;
  final int userRole;
  final VoidCallback? onBack;

  const LocationPricingManagementView({
    super.key,
    required this.organizationId,
    required this.userRole,
    this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return BlocListener<LocationPricingBloc, LocationPricingState>(
      listener: (context, state) {
        if (state is LocationPricingOperationSuccess) {
          CustomSnackBar.showSuccess(context, state.message);
        } else if (state is LocationPricingError) {
          CustomSnackBar.showError(context, state.message);
        }
      },
      child: PageContainer(
        fullHeight: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            PageHeader(
              title: 'Location Pricing',
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
                        'Location Pricing',
                        style: TextStyle(
                          color: AppTheme.textPrimaryColor,
                          fontWeight: FontWeight.w600,
                          fontSize: 20,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppTheme.spacingLg),
                  BlocBuilder<LocationPricingBloc, LocationPricingState>(
                    builder: (context, state) {
                      if (state is LocationPricingInitial || state is LocationPricingLoading) {
                        return const Center(
                          child: Padding(
                            padding: EdgeInsets.all(AppTheme.spacing2xl),
                            child: CircularProgressIndicator(
                              color: AppTheme.primaryColor,
                            ),
                          ),
                        );
                      }
                      
                      if (state is LocationPricingError) {
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
                                    context.read<LocationPricingBloc>().add(
                                      LoadLocationPricing(organizationId),
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                        );
                      }
                      
                      if (state is LocationPricingEmpty) {
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
                                const Text(
                                  'No Location Pricing',
                                  style: TextStyle(
                                    color: AppTheme.textPrimaryColor,
                                    fontSize: 20,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: AppTheme.spacingSm),
                                const Text(
                                  'Add your first location pricing to get started',
                                  style: TextStyle(
                                    color: AppTheme.textSecondaryColor,
                                    fontSize: 14,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        );
                      }
                      
                      if (state is LocationPricingLoaded) {
                        return _buildLocationPricingTable(context, state.locations);
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
          text: '➕ Add Location',
          variant: CustomButtonVariant.primary,
          onPressed: () => _showAddLocationDialog(context),
        ),
        const Spacer(),
        SizedBox(
          width: 300,
          child: BlocBuilder<LocationPricingBloc, LocationPricingState>(
            builder: (context, state) {
              return CustomTextField(
                hintText: 'Search locations...',
                prefixIcon: const Icon(Icons.search, size: 18),
                variant: CustomTextFieldVariant.search,
                onChanged: (query) {
                  if (query.isEmpty) {
                    context.read<LocationPricingBloc>().add(
                      const ResetLocationPricingSearch(),
                    );
                    context.read<LocationPricingBloc>().add(
                      LoadLocationPricing(organizationId),
                    );
                  } else {
                    context.read<LocationPricingBloc>().add(
                      SearchLocationPricing(
                        organizationId: organizationId,
                        query: query,
                      ),
                    );
                  }
                },
                suffixIcon: state is LocationPricingLoaded && 
                            state.searchQuery != null &&
                            state.searchQuery!.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          context.read<LocationPricingBloc>().add(
                            const ResetLocationPricingSearch(),
                          );
                          context.read<LocationPricingBloc>().add(
                            LoadLocationPricing(organizationId),
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

  Widget _buildLocationPricingTable(
    BuildContext context,
    List<LocationPricing> locations,
  ) {
    const double minTableWidth = 900;
    
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
                      'LOCATION ID',
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
                      'LOCATION NAME',
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
                      'CITY',
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
                      'UNIT PRICE',
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
              rows: locations.map((location) {
                return DataRow(
                  cells: [
                    DataCell(
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 12,
                        ),
                        child: Text(
                          location.locationId,
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
                          location.locationName,
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
                          location.city,
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
                          '₹${location.unitPrice.toStringAsFixed(2)}',
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
                        child: _buildStatusBadge(location.status),
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
                              onPressed: () => _showEditLocationDialog(
                                context,
                                location,
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
                                location,
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

  void _showAddLocationDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => LocationPricingFormDialog(
        onSubmit: (location) {
          Navigator.of(dialogContext).pop();
          _submitLocation(context, location);
        },
        onCancel: () => Navigator.of(dialogContext).pop(),
      ),
    );
  }

  void _showEditLocationDialog(
    BuildContext context,
    LocationPricing location,
  ) {
    showDialog(
      context: context,
      builder: (dialogContext) => LocationPricingFormDialog(
        locationPricing: location,
        onSubmit: (updatedLocation) {
          Navigator.of(dialogContext).pop();
          _updateLocation(context, location, updatedLocation);
        },
        onCancel: () => Navigator.of(dialogContext).pop(),
      ),
    );
  }

  void _showDeleteConfirmation(
    BuildContext context,
    LocationPricing location,
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
          'Delete Location Pricing',
          style: TextStyle(
            color: AppTheme.errorColor,
            fontWeight: FontWeight.w600,
          ),
        ),
        content: Text(
          'Are you sure you want to delete "${location.locationName}"?',
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
              _deleteLocation(context, location);
            },
          ),
        ],
      ),
    );
  }

  void _submitLocation(
    BuildContext context,
    LocationPricing location,
  ) {
    final authState = context.read<AuthBloc>().state;
    final userId = authState is AuthAuthenticated
        ? authState.firebaseUser.uid
        : const Uuid().v4();

    context.read<LocationPricingBloc>().add(
      AddLocationPricing(
        organizationId: organizationId,
        locationPricing: location,
        userId: userId,
      ),
    );
  }

  void _updateLocation(
    BuildContext context,
    LocationPricing oldLocation,
    LocationPricing newLocation,
  ) {
    final authState = context.read<AuthBloc>().state;
    final userId = authState is AuthAuthenticated
        ? authState.firebaseUser.uid
        : const Uuid().v4();

    context.read<LocationPricingBloc>().add(
      UpdateLocationPricing(
        organizationId: organizationId,
        locationPricingId: oldLocation.id!,
        locationPricing: newLocation,
        userId: userId,
      ),
    );
  }

  void _deleteLocation(
    BuildContext context,
    LocationPricing location,
  ) {
    context.read<LocationPricingBloc>().add(
      DeleteLocationPricing(
        organizationId: organizationId,
        locationPricingId: location.id!,
      ),
    );
  }
}

