import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/app_theme.dart';
import '../../../../core/config/android_config.dart';
import '../../bloc/android_location_pricing_bloc.dart';
import '../../repositories/android_location_pricing_repository.dart';
import '../../models/location_pricing.dart';
import '../widgets/android_location_pricing_form_dialog.dart';

class AndroidLocationPricingManagementPage extends StatelessWidget {
  final String organizationId;
  final String userId;

  const AndroidLocationPricingManagementPage({
    super.key,
    required this.organizationId,
    required this.userId,
  });

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => AndroidLocationPricingBloc(
        repository: AndroidLocationPricingRepository(),
      )..add(AndroidLoadLocationPricing(organizationId)),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Location Pricing'),
          backgroundColor: AppTheme.surfaceColor,
        ),
        backgroundColor: AppTheme.backgroundColor,
        body: BlocListener<AndroidLocationPricingBloc, AndroidLocationPricingState>(
          listener: (context, state) {
            if (state is AndroidLocationPricingOperationSuccess) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(state.message),
                  backgroundColor: AppTheme.successColor,
                ),
              );
            } else if (state is AndroidLocationPricingError) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(state.message),
                  backgroundColor: AppTheme.errorColor,
                ),
              );
            }
          },
          child: BlocBuilder<AndroidLocationPricingBloc, AndroidLocationPricingState>(
            builder: (context, state) {
              if (state is AndroidLocationPricingLoading || state is AndroidLocationPricingInitial) {
                return const Center(child: CircularProgressIndicator());
              }

              if (state is AndroidLocationPricingError) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, size: 64, color: AppTheme.errorColor),
                      const SizedBox(height: 16),
                      Text(state.message, style: const TextStyle(color: AppTheme.textPrimaryColor)),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () {
                          context.read<AndroidLocationPricingBloc>().add(
                            AndroidLoadLocationPricing(organizationId),
                          );
                        },
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                );
              }

              if (state is AndroidLocationPricingEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.location_on_outlined, size: 64, color: AppTheme.textSecondaryColor),
                      const SizedBox(height: 16),
                      const Text('No locations found', style: TextStyle(color: AppTheme.textPrimaryColor, fontSize: 18)),
                      const SizedBox(height: 8),
                      ElevatedButton.icon(
                        onPressed: () => _showAddLocationDialog(context),
                        icon: const Icon(Icons.add),
                        label: const Text('Add Location'),
                      ),
                    ],
                  ),
                );
              }

              if (state is AndroidLocationPricingLoaded) {
                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(AndroidConfig.defaultPadding),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Locations (${state.locations.length})',
                            style: const TextStyle(color: AppTheme.textPrimaryColor, fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          ElevatedButton.icon(
                            onPressed: () => _showAddLocationDialog(context),
                            icon: const Icon(Icons.add),
                            label: const Text('Add'),
                            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: AndroidConfig.defaultPadding),
                        itemCount: state.locations.length,
                        itemBuilder: (context, index) {
                          final location = state.locations[index];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            color: AppTheme.surfaceColor,
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: AppTheme.primaryColor.withOpacity(0.2),
                                child: const Icon(Icons.location_on, color: AppTheme.primaryColor),
                              ),
                              title: Text(
                                location.locationName,
                                style: const TextStyle(color: AppTheme.textPrimaryColor, fontWeight: FontWeight.bold),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('ID: ${location.locationId}', style: const TextStyle(color: AppTheme.textSecondaryColor)),
                                  Text('City: ${location.city}', style: const TextStyle(color: AppTheme.textSecondaryColor)),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Text(
                                        '₹${location.unitPrice.toStringAsFixed(2)}',
                                        style: const TextStyle(
                                          color: AppTheme.textPrimaryColor,
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: location.isActive
                                              ? AppTheme.successColor.withOpacity(0.2)
                                              : AppTheme.errorColor.withOpacity(0.2),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          location.status,
                                          style: TextStyle(
                                            color: location.isActive ? AppTheme.successColor : AppTheme.errorColor,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              trailing: PopupMenuButton(
                                icon: const Icon(Icons.more_vert),
                                color: AppTheme.surfaceColor,
                                itemBuilder: (context) => [
                                  PopupMenuItem(
                                    child: const Text('Edit'),
                                    onTap: () {
                                      Future.delayed(
                                        const Duration(milliseconds: 100),
                                        () => _showEditLocationDialog(context, location),
                                      );
                                    },
                                  ),
                                  PopupMenuItem(
                                    child: const Text('Delete'),
                                    onTap: () {
                                      Future.delayed(
                                        const Duration(milliseconds: 100),
                                        () => _showDeleteConfirmDialog(context, location),
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                );
              }

              return const SizedBox.shrink();
            },
          ),
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () => _showAddLocationDialog(context),
          backgroundColor: AppTheme.primaryColor,
          child: const Icon(Icons.add),
        ),
      ),
    );
  }

  void _showAddLocationDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surfaceColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => AndroidLocationPricingFormDialog(
        onSubmit: (location) {
          context.read<AndroidLocationPricingBloc>().add(
            AndroidAddLocationPricing(
              organizationId: organizationId,
              locationPricing: location,
              userId: userId,
            ),
          );
          Navigator.pop(context);
        },
      ),
    );
  }

  void _showEditLocationDialog(BuildContext context, LocationPricing location) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surfaceColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => AndroidLocationPricingFormDialog(
        locationPricing: location,
        onSubmit: (location) {
          context.read<AndroidLocationPricingBloc>().add(
            AndroidUpdateLocationPricing(
              organizationId: organizationId,
              locationId: location.id!,
              locationPricing: location,
              userId: userId,
            ),
          );
          Navigator.pop(context);
        },
      ),
    );
  }

  void _showDeleteConfirmDialog(BuildContext context, LocationPricing location) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surfaceColor,
        title: const Text('Delete Location', style: TextStyle(color: AppTheme.textPrimaryColor)),
        content: Text(
          'Are you sure you want to delete ${location.locationName}?',
          style: const TextStyle(color: AppTheme.textSecondaryColor),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              context.read<AndroidLocationPricingBloc>().add(
                AndroidDeleteLocationPricing(
                  organizationId: organizationId,
                  locationId: location.id!,
                ),
              );
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.errorColor),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

