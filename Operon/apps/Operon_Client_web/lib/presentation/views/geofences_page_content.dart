import 'package:core_bloc/core_bloc.dart';
import 'package:core_ui/core_ui.dart';
import 'package:core_models/core_models.dart' as core_models;
import 'package:dash_web/data/repositories/geofences_repository.dart';
import 'package:dash_web/data/repositories/organization_locations_repository.dart';
import 'package:dash_web/data/repositories/users_repository.dart';
import 'package:dash_web/presentation/blocs/geofences/geofences_cubit.dart';
import 'package:dash_web/presentation/blocs/org_context/org_context_cubit.dart';
import 'package:dash_web/presentation/widgets/geofence_editor_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';

/// Reusable content for Geofences list; used by full page and Settings side sheet.
class GeofencesPageContent extends StatelessWidget {
  const GeofencesPageContent({super.key});

  @override
  Widget build(BuildContext context) {
    final orgState = context.watch<OrganizationContextCubit>().state;
    final organization = orgState.organization;
    final appAccessRole = orgState.appAccessRole;
    final isAdmin = appAccessRole?.isAdmin ?? false;

    if (organization == null) {
      return const Center(child: Text('No organization selected'));
    }

    return BlocListener<GeofencesCubit, GeofencesState>(
      listener: (context, state) {
        if (state.status == ViewStatus.failure && state.message != null) {
          DashSnackbar.show(
            context,
            message: state.message!,
            isError: true,
          );
        }
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isAdmin)
            SizedBox(
              width: double.infinity,
              child: DashButton(
                label: 'Create Geofence',
                onPressed: () => _openGeofenceDialog(context),
              ),
            )
          else
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: const Color(0x22FFFFFF),
              ),
              child: const Text(
                'You have read-only access to geofences.',
                style: TextStyle(color: Colors.white70),
              ),
            ),
          const SizedBox(height: 20),
          BlocBuilder<GeofencesCubit, GeofencesState>(
            builder: (context, state) {
              if (state.status == ViewStatus.loading) {
                return const Center(child: CircularProgressIndicator());
              }
              if (state.geofences.isEmpty) {
                return Center(
                  child: Text(
                    'No geofences yet. Tap "Create Geofence" to create one.',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.6),
                      fontSize: 16,
                    ),
                    textAlign: TextAlign.center,
                  ),
                );
              }

              // Group by location
              final locationGroups = <String, List<core_models.Geofence>>{};
              for (final geofence in state.geofences) {
                locationGroups.putIfAbsent(geofence.locationId, () => []).add(geofence);
              }

              return AnimationLimiter(
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: locationGroups.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 20),
                  itemBuilder: (context, index) {
                    final locationId = locationGroups.keys.elementAt(index);
                    final geofences = locationGroups[locationId]!;
                    return AnimationConfiguration.staggeredList(
                      position: index,
                      duration: const Duration(milliseconds: 200),
                      child: SlideAnimation(
                        verticalOffset: 50.0,
                        child: FadeInAnimation(
                          curve: Curves.easeOut,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    'Location: ${geofences.first.locationId}',
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  if (isAdmin) ...[
                                    const Spacer(),
                                    TextButton(
                                      onPressed: () => _openGeofenceDialog(
                                        context,
                                        locationId: locationId,
                                      ),
                                      child: const Text('Add geofence'),
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 8),
                              ...geofences.map((geofence) => Padding(
                                    padding: const EdgeInsets.only(bottom: 8),
                                    child: _GeofenceTile(
                                      geofence: geofence,
                                      canManage: isAdmin,
                                      onEdit: isAdmin
                                          ? () => _openGeofenceDialog(
                                                context,
                                                geofenceId: geofence.id,
                                                locationId: geofence.locationId,
                                              )
                                          : null,
                                      onDelete: isAdmin
                                          ? () => context.read<GeofencesCubit>().deleteGeofence(geofence.id)
                                          : null,
                                      onToggleActive: isAdmin
                                          ? (active) => context.read<GeofencesCubit>().toggleActive(
                                                geofenceId: geofence.id,
                                                isActive: active,
                                              )
                                          : null,
                                    ),
                                  )),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Future<void> _openGeofenceDialog(
    BuildContext context, {
    String? geofenceId,
    String? locationId,
  }) async {
    final orgState = context.read<OrganizationContextCubit>().state;
    final organization = orgState.organization;
    if (organization == null) return;

    // If locationId is not provided, we need to get it from the geofence
    String? finalLocationId = locationId;
    if (finalLocationId == null && geofenceId != null) {
      final geofencesRepo = context.read<GeofencesRepository>();
      final geofence = await geofencesRepo.fetchGeofence(
        orgId: organization.id,
        geofenceId: geofenceId,
      );
      if (geofence != null) {
        finalLocationId = geofence.locationId;
      }
    }

    // If still no locationId, show location selector dialog
    if (finalLocationId == null) {
      final locationsRepo = context.read<OrganizationLocationsRepository>();
      final locations = await locationsRepo.fetchLocations(organization.id);
      
      if (locations.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please create a location first before creating a geofence'),
          ),
        );
        return;
      }

      // Show location selector dialog
      final selectedLocation = await showDialog<core_models.OrganizationLocation>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          backgroundColor: AuthColors.surface,
          title: const Text(
            'Select Location',
            style: TextStyle(color: AuthColors.textMain),
          ),
          content: SizedBox(
            width: 400,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: locations.length,
              itemBuilder: (context, index) {
                final location = locations[index];
                return ListTile(
                  leading: Icon(
                    Icons.location_on,
                    color: location.isPrimary
                        ? const Color(0xFF6F4BFF)
                        : AuthColors.textSub,
                  ),
                  title: Text(
                    location.name,
                    style: const TextStyle(color: AuthColors.textMain),
                  ),
                  subtitle: Text(
                    '${location.latitude.toStringAsFixed(6)}, ${location.longitude.toStringAsFixed(6)}',
                    style: const TextStyle(color: AuthColors.textSub),
                  ),
                  trailing: location.isPrimary
                      ? const Text(
                          'Primary',
                          style: TextStyle(
                            color: Color(0xFF6F4BFF),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        )
                      : null,
                  onTap: () => Navigator.of(dialogContext).pop(location),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
          ],
        ),
      );

      if (selectedLocation == null) {
        return; // User cancelled
      }

      finalLocationId = selectedLocation.id;
    }

    await showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Geofence Editor Dialog',
      barrierColor: AuthColors.background.withValues(alpha: 0.8),
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, animation, secondaryAnimation) {
        return MultiRepositoryProvider(
          providers: [
            RepositoryProvider<GeofencesRepository>.value(
              value: context.read<GeofencesRepository>(),
            ),
            RepositoryProvider<OrganizationLocationsRepository>.value(
              value: context.read<OrganizationLocationsRepository>(),
            ),
            RepositoryProvider<UsersRepository>.value(
              value: context.read<UsersRepository>(),
            ),
          ],
          child: GeofenceEditorDialog(
            geofenceId: geofenceId,
            locationId: finalLocationId!,
          ),
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(
          opacity: CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
          ),
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.9, end: 1.0).animate(
              CurvedAnimation(
                parent: animation,
                curve: Curves.easeOutCubic,
              ),
            ),
            child: child,
          ),
        );
      },
    );
  }
}

class _GeofenceTile extends StatelessWidget {
  const _GeofenceTile({
    required this.geofence,
    required this.canManage,
    this.onEdit,
    this.onDelete,
    this.onToggleActive,
  });

  final core_models.Geofence geofence;
  final bool canManage;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final ValueChanged<bool>? onToggleActive;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: const Color(0xFF1F1F2C),
        border: Border.all(
          color: geofence.isActive
              ? const Color(0xFF5AD8A4)
              : Colors.white.withValues(alpha: 0.1),
          width: geofence.isActive ? 2 : 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: geofence.isActive
                  ? const Color(0xFF5AD8A4).withValues(alpha: 0.2)
                  : Colors.white.withValues(alpha: 0.1),
            ),
            child: Icon(
              geofence.type == core_models.GeofenceType.circle
                  ? Icons.radio_button_unchecked
                  : Icons.polyline,
              color: geofence.isActive
                  ? const Color(0xFF5AD8A4)
                  : Colors.white70,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        geofence.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (geofence.isActive)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          color: const Color(0xFF5AD8A4).withValues(alpha: 0.2),
                        ),
                        child: const Text(
                          'Active',
                          style: TextStyle(
                            color: Color(0xFF5AD8A4),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  geofence.type == core_models.GeofenceType.circle
                      ? 'Circle: ${geofence.radiusMeters?.toStringAsFixed(0) ?? 0}m radius'
                      : 'Polygon: ${geofence.polygonPoints?.length ?? 0} points',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.6),
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${geofence.notificationRecipientIds.length} notification recipients',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.5),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          if (canManage) ...[
            Switch(
              value: geofence.isActive,
              onChanged: onToggleActive,
            ),
            const SizedBox(width: 8),
            if (onEdit != null)
              IconButton(
                icon: const Icon(Icons.edit_outlined, color: Colors.white70),
                onPressed: onEdit,
                tooltip: 'Edit',
              ),
            if (onDelete != null)
              IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.red),
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      backgroundColor: const Color(0xFF11111B),
                      title: const Text(
                        'Delete Geofence',
                        style: TextStyle(color: Colors.white),
                      ),
                      content: Text(
                        'Are you sure you want to delete "${geofence.name}"?',
                        style: const TextStyle(color: Colors.white70),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(ctx).pop(),
                          child: const Text('Cancel'),
                        ),
                        TextButton(
                          onPressed: () {
                            Navigator.of(ctx).pop();
                            onDelete?.call();
                          },
                          child: const Text(
                            'Delete',
                            style: TextStyle(color: Colors.red),
                          ),
                        ),
                      ],
                    ),
                  );
                },
                tooltip: 'Delete',
              ),
          ],
        ],
      ),
    );
  }
}
