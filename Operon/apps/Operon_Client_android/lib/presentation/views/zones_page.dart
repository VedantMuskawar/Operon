import 'package:core_bloc/core_bloc.dart';
import 'package:core_models/core_models.dart';
import 'package:core_ui/core_ui.dart';
import 'package:dash_mobile/presentation/blocs/delivery_zones/delivery_zones_cubit.dart';
import 'package:dash_mobile/presentation/widgets/modern_page_header.dart';
import 'package:dash_mobile/presentation/widgets/loading/loading_skeleton.dart';
import 'package:dash_mobile/presentation/widgets/error/error_state_widget.dart';
import 'package:dash_mobile/presentation/widgets/empty/empty_state_widget.dart';
import 'package:dash_mobile/presentation/utils/network_error_helper.dart';
import 'package:dash_mobile/shared/constants/app_spacing.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:go_router/go_router.dart';

void _zonesLog(String message) {
  debugPrint('[ZonesPage] $message');
}

class ZoneCrudPermission {
  const ZoneCrudPermission({
    this.canCreate = false,
    this.canEdit = false,
    this.canDelete = false,
  });

  final bool canCreate;
  final bool canEdit;
  final bool canDelete;

  bool get canManage => canCreate || canEdit || canDelete;

  @override
  String toString() =>
      'ZoneCrudPermission(create=$canCreate, edit=$canEdit, delete=$canDelete)';
}

class ZonesPage extends StatefulWidget {
  const ZonesPage({
    super.key,
    required this.cityPermission,
    required this.regionPermission,
    required this.pricePermission,
    required this.isAdmin,
  });

  final ZoneCrudPermission cityPermission;
  final ZoneCrudPermission regionPermission;
  final ZoneCrudPermission pricePermission;
  final bool isAdmin;

  @override
  State<ZonesPage> createState() => _ZonesPageState();
}

class _ZonesPageState extends State<ZonesPage> {
  String? _selectedCity;

  void _selectCity(String city, DeliveryZonesState state) {
    if (_selectedCity == city) return;
    setState(() => _selectedCity = city);
    final firstRegion = state.zones.firstWhere(
      (z) => z.cityName == city,
      orElse: () => state.zones.first,
    );
    context.read<DeliveryZonesCubit>().selectZone(firstRegion.id);
  }

  @override
  Widget build(BuildContext context) {
    _zonesLog(
        'building page city=${widget.cityPermission} region=${widget.regionPermission} price=${widget.pricePermission}');
    return BlocListener<DeliveryZonesCubit, DeliveryZonesState>(
      listener: (context, state) {
        if (state.status == ViewStatus.failure && state.message != null) {
          final isNetworkError = NetworkErrorHelper.isNetworkError(state.message!);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message!),
              backgroundColor: isNetworkError ? AuthColors.warning : AuthColors.error,
              duration: const Duration(seconds: 5),
              action: SnackBarAction(
                label: 'Retry',
                textColor: AuthColors.textMain,
                onPressed: () {
                  context.read<DeliveryZonesCubit>().loadZones();
                },
              ),
            ),
          );
        }
      },
      child: Scaffold(
        backgroundColor: AuthColors.background,
        appBar: const ModernPageHeader(
          title: 'Delivery Zones',
        ),
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(AppSpacing.paddingLG),
                  child: LayoutBuilder(
          builder: (context, constraints) {
            return BlocBuilder<DeliveryZonesCubit, DeliveryZonesState>(
              builder: (context, state) {
                // Error state
                if (state.status == ViewStatus.failure && state.zones.isEmpty && state.cities.isEmpty) {
                  final message = state.message ?? 'Failed to load delivery zones';
                  final isNetworkError = NetworkErrorHelper.isNetworkError(message);
                  return ErrorStateWidget(
                    message: message,
                    errorType: isNetworkError ? ErrorType.network : ErrorType.generic,
                    onRetry: () {
                      context.read<DeliveryZonesCubit>().loadZones();
                    },
                  );
                }

                final zones = state.zones;
                final cityGroups = <String, List<DeliveryZone>>{};
                for (final zone in zones) {
                  cityGroups.putIfAbsent(zone.cityName, () => []).add(zone);
                }
                final sortedCities = cityGroups.keys.toList()..sort();
                final hasRegionSelected =
                    (state.selectedZoneId ?? '').isNotEmpty &&
                        zones.any((z) => z.id == state.selectedZoneId);
                final selectedZone = hasRegionSelected
                    ? zones.firstWhere((z) => z.id == state.selectedZoneId)
                    : null;
                _selectedCity ??= selectedZone?.cityName ??
                    (sortedCities.isNotEmpty ? sortedCities.first : null);
                final currentCityRegions = _selectedCity != null
                    ? cityGroups[_selectedCity] ?? <DeliveryZone>[]
                    : <DeliveryZone>[];

                final totalWidth = constraints.maxWidth;
                final cityWidth = totalWidth * 0.5;
                final regionWidth = totalWidth * 0.5;

                final columnHeight =
                    constraints.maxHeight.isFinite ? constraints.maxHeight : null;
                final resolvedHeight = columnHeight ?? MediaQuery.of(context).size.height * 0.55;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: AppSpacing.paddingSM),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              'City',
                              style: TextStyle(
                                color: AuthColors.textSub,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          Expanded(
                            child: Text(
                              'Region',
                              style: TextStyle(
                                color: AuthColors.textSub,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.paddingMD),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 220),
                          width: cityWidth,
                          height: resolvedHeight,
                          child: _CityColumn(
                            selectedCity: _selectedCity,
                            cities: state.cities,
                            isLoading: state.status == ViewStatus.loading && state.cities.isEmpty,
                            onSelectCity: (city) => _selectCity(city, state),
                            canCreate: widget.isAdmin,
                            onAddCity: () => _openAddCityDialog(context),
                            canLongPress: widget.isAdmin,
                            onLongPressCity: widget.isAdmin
                                ? (city) => _openCityOptionsSheet(context, city)
                                : null,
                          ),
                        ),
                        const SizedBox(width: 12),
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 220),
                          width: regionWidth - 12,
                          height: resolvedHeight,
                          child: _RegionColumn(
                            regions: currentCityRegions,
                            selectedZoneId: state.selectedZoneId,
                            isLoading: state.status == ViewStatus.loading && currentCityRegions.isEmpty && _selectedCity != null,
                            canEditZone: widget.regionPermission.canEdit,
                            canDeleteZone: widget.regionPermission.canDelete,
                            canCreateRegion: widget.regionPermission.canCreate,
                            hasCities: state.cities.isNotEmpty,
                            selectedCity: _selectedCity,
                            onAddRegion: state.cities.isEmpty
                                ? null
                                : () => _openAddRegionDialog(
                                      context,
                                      cities: state.cities,
                                      initialCity: _selectedCity,
                                    ),
                            onSelectZone: (zoneId) =>
                                context.read<DeliveryZonesCubit>().selectZone(zoneId),
                            onLongPressZone: (zone) =>
                                _openRegionPriceDialog(context, zone),
                            onEditZone: (zone) => _openZoneDialog(context, zone: zone),
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              },
            );
          },
                  ),
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
                currentIndex: -1,
                onItemTapped: (value) => context.go('/home', extra: value),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openZoneDialog(
    BuildContext context, {
    DeliveryZone? zone,
  }) async {
    final cubit = context.read<DeliveryZonesCubit>();
    await showDialog(
      context: context,
      builder: (_) => BlocProvider.value(
        value: cubit,
        child: _ZoneDialog(
          zone: zone,
          cityPermission: widget.cityPermission,
          regionPermission: widget.regionPermission,
        ),
      ),
    );
  }

  Future<void> _openAddCityDialog(BuildContext context) async {
    final cubit = context.read<DeliveryZonesCubit>();
    await showDialog(
      context: context,
      builder: (_) => BlocProvider.value(
        value: cubit,
        child: const _AddCityDialog(),
      ),
    );
  }

  Future<void> _openAddRegionDialog(
    BuildContext context, {
    required List<DeliveryCity> cities,
    String? initialCity,
  }) async {
    final cubit = context.read<DeliveryZonesCubit>();
    await showDialog(
      context: context,
      builder: (_) => BlocProvider.value(
        value: cubit,
        child: _AddRegionDialog(
          cities: cities,
          initialCity: initialCity,
        ),
      ),
    );
  }

  Future<void> _openRegionPriceDialog(
    BuildContext context,
    DeliveryZone zone,
  ) async {
    final cubit = context.read<DeliveryZonesCubit>();
    await cubit.selectZone(zone.id);
    if (!mounted) return;
    await showDialog(
      context: context,
      builder: (_) => BlocProvider.value(
        value: cubit,
        child: _RegionPriceDialog(
          zone: zone,
          pricePermission: widget.pricePermission,
          canEditRegion: widget.regionPermission.canEdit,
          canDeleteRegion: widget.regionPermission.canDelete,
          onEditRegion: () => _openZoneDialog(context, zone: zone),
        ),
      ),
    );
  }

  Future<void> _openCityOptionsSheet(
    BuildContext context,
    DeliveryCity city,
  ) async {
    await showModalBottomSheet(
      context: context,
      backgroundColor: AuthColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.paddingXL),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: AppSpacing.paddingLG),
                    decoration: BoxDecoration(
                      color: AuthColors.textMainWithOpacity(0.12),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Text(
                  city.name,
                  style: const TextStyle(
                    color: AuthColors.textMain,
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: AppSpacing.paddingXS),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.edit, color: AuthColors.textMain),
                  title: const Text('Rename city',
                      style: TextStyle(color: AuthColors.textMain)),
                  onTap: () {
                    Navigator.of(_).pop();
                    _openRenameCityDialog(context, city);
                  },
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading:
                      const Icon(Icons.delete_outline, color: AuthColors.error),
                  title: const Text('Delete city',
                      style: TextStyle(color: AuthColors.error)),
                  onTap: () {
                    Navigator.of(_).pop();
                    _confirmDeleteCity(context, city);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _openRenameCityDialog(
    BuildContext context,
    DeliveryCity city,
  ) async {
    final controller = TextEditingController(text: city.name);
    bool submitting = false;
    await showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            backgroundColor: AuthColors.surface,
            title: const Text('Rename City', style: TextStyle(color: AuthColors.textMain)),
            content: TextField(
              controller: controller,
              style: const TextStyle(color: AuthColors.textMain),
              decoration: const InputDecoration(
                labelText: 'City name',
                filled: true,
                fillColor: AuthColors.surface,
                labelStyle: TextStyle(color: AuthColors.textSub),
                border: OutlineInputBorder(borderSide: BorderSide.none),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: submitting
                    ? null
                    : () async {
                        final newName = controller.text.trim();
                        if (newName.isEmpty || newName == city.name) {
                          Navigator.of(context).pop();
                          return;
                        }
                        setState(() => submitting = true);
                        try {
                          await context
                              .read<DeliveryZonesCubit>()
                              .renameCity(city: city, newName: newName);
                          if (mounted) Navigator.of(context).pop();
                        } catch (err) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(err.toString())),
                            );
                          }
                        } finally {
                          if (mounted) setState(() => submitting = false);
                        }
                      },
                child: submitting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Save'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _confirmDeleteCity(
    BuildContext context,
    DeliveryCity city,
  ) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AuthColors.surface,
        title: const Text('Delete City', style: TextStyle(color: AuthColors.textMain)),
        content: Text(
          'Deleting "${city.name}" will remove all regions and prices in this city. This cannot be undone.',
          style: const TextStyle(color: AuthColors.textSub),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text(
              'Delete',
              style: TextStyle(color: AuthColors.error),
            ),
          ),
        ],
      ),
    );
    if (shouldDelete != true) return;
    try {
      await context.read<DeliveryZonesCubit>().deleteCity(city);
    } catch (err) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete city: $err')),
      );
    }
  }
}

class _CityColumn extends StatelessWidget {
  const _CityColumn({
    required this.selectedCity,
    required this.cities,
    required this.onSelectCity,
    required this.canCreate,
    required this.onAddCity,
    this.isLoading = false,
    this.canLongPress = false,
    this.onLongPressCity,
  });

  final String? selectedCity;
  final List<DeliveryCity> cities;
  final ValueChanged<String> onSelectCity;
  final bool canCreate;
  final VoidCallback onAddCity;
  final bool isLoading;
  final bool canLongPress;
  final ValueChanged<DeliveryCity>? onLongPressCity;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (canCreate)
          SizedBox(
            width: 220,
            child: DashButton(
              label: 'Add City',
              onPressed: onAddCity,
            ),
          )
        else
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.paddingMD),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppSpacing.radiusMD),
              color: AuthColors.textMainWithOpacity(0.13),
            ),
            child: const Text(
              'You do not have permission to add new addresses.',
              style: TextStyle(color: AuthColors.textSub),
            ),
          ),
        const SizedBox(height: AppSpacing.paddingLG),
        Expanded(
          child: isLoading
              ? ListView.builder(
                  itemCount: 5,
                  itemBuilder: (context, index) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.paddingMD),
                      child: LoadingSkeleton(
                        width: double.infinity,
                        height: 56,
                        borderRadius: BorderRadius.circular(AppSpacing.radiusLG),
                      ),
                    );
                  },
                )
              : cities.isEmpty
                  ? EmptyStateWidget(
                      icon: Icons.location_city_outlined,
                      title: 'No cities yet',
                      message: canCreate
                          ? 'Tap "Add City" to add your first city'
                          : 'No cities available. Admins can add cities.',
                      actionLabel: canCreate ? 'Add City' : null,
                      onAction: canCreate ? onAddCity : null,
                      iconColor: AuthColors.textDisabled,
                    )
                  : AnimationLimiter(
                      child: ListView.separated(
                        itemCount: cities.length,
                        separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.paddingMD),
                        itemBuilder: (context, index) {
                          final city = cities[index];
                          final isSelected = city.name == selectedCity;
                          return AnimationConfiguration.staggeredList(
                            position: index,
                            duration: const Duration(milliseconds: 200),
                            child: SlideAnimation(
                              verticalOffset: 50.0,
                              child: FadeInAnimation(
                                curve: Curves.easeOut,
                                child: GestureDetector(
                          key: ValueKey(city.name),
                          onTap: () => onSelectCity(city.name),
                          onLongPress: canLongPress && onLongPressCity != null
                              ? () => onLongPressCity!(city)
                              : null,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.paddingLG, vertical: AppSpacing.paddingLG),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(AppSpacing.radiusLG),
                              color: isSelected
                                  ? AuthColors.surface
                                  : AuthColors.surface,
                              border: Border.all(
                                color: isSelected ? AuthColors.legacyAccent : AuthColors.textMainWithOpacity(0.12),
                                width: isSelected ? 2 : 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    city.name,
                                    style: TextStyle(
                                      color: AuthColors.textMain,
                                      fontWeight: FontWeight.w600,
                                      fontSize: isSelected ? 16 : 15,
                                    ),
                                  ),
                                ),
                                if (isSelected)
                                  const Icon(Icons.arrow_forward_ios, size: 14, color: AuthColors.textSub),
                              ],
                            ),
                          ),
                                ),
                              ),
                            ),
                        );
                      },
                    ),
                  ),
        ),
      ],
    );
  }
}

class _RegionColumn extends StatelessWidget {
  const _RegionColumn({
    required this.regions,
    required this.selectedZoneId,
    required this.canEditZone,
    required this.canDeleteZone,
    required this.canCreateRegion,
    required this.hasCities,
    this.isLoading = false,
    this.selectedCity,
    this.onAddRegion,
    required this.onSelectZone,
    required this.onLongPressZone,
    required this.onEditZone,
  });

  final List<DeliveryZone> regions;
  final String? selectedZoneId;
  final bool canEditZone;
  final bool canDeleteZone;
  final bool canCreateRegion;
  final bool hasCities;
  final bool isLoading;
  final String? selectedCity;
  final VoidCallback? onAddRegion;
  final ValueChanged<String> onSelectZone;
  final ValueChanged<DeliveryZone> onLongPressZone;
  final ValueChanged<DeliveryZone> onEditZone;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (canCreateRegion)
          SizedBox(
            width: 220,
            child: DashButton(
              label: 'Add Region',
              onPressed: hasCities ? onAddRegion : null,
            ),
          ),
        const SizedBox(height: AppSpacing.paddingLG),
        Expanded(
          child: isLoading
              ? ListView.builder(
                  itemCount: 5,
                  itemBuilder: (context, index) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.paddingMD),
                      child: LoadingSkeleton(
                        width: double.infinity,
                        height: 80,
                        borderRadius: BorderRadius.circular(AppSpacing.radiusXL),
                      ),
                    );
                  },
                )
              : !hasCities
                  ? const Center(
                      child: Text(
                        'No cities available.',
                        style: TextStyle(color: AuthColors.textSub),
                      ),
                    )
                  : regions.isEmpty
                      ? EmptyStateWidget(
                          icon: Icons.location_off_outlined,
                          title: 'No regions',
                          message: selectedCity != null
                              ? 'No regions in "$selectedCity". Tap "Add Region" to add one.'
                              : 'Select a city to view its regions.',
                          actionLabel: canCreateRegion ? 'Add Region' : null,
                          onAction: canCreateRegion ? onAddRegion : null,
                          iconColor: AuthColors.textDisabled,
                        )
                      : AnimationLimiter(
                          child: ListView.separated(
                            itemCount: regions.length,
                            separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.paddingMD),
                            itemBuilder: (context, index) {
                              final zone = regions[index];
                              final isSelected = selectedZoneId == zone.id;
                              return AnimationConfiguration.staggeredList(
                                position: index,
                                duration: const Duration(milliseconds: 200),
                                child: SlideAnimation(
                                  verticalOffset: 50.0,
                                  child: FadeInAnimation(
                                    curve: Curves.easeOut,
                                    child: GestureDetector(
                              key: ValueKey(zone.id),
                              onTap: () => onSelectZone(zone.id),
                              onLongPress: () {
                                HapticFeedback.mediumImpact();
                                onLongPressZone(zone);
                              },
                              child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.all(AppSpacing.paddingLG),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppSpacing.radiusXL),
          border: Border.all(
            color: isSelected ? AuthColors.legacyAccent : AuthColors.textMainWithOpacity(0.12),
            width: isSelected ? 2 : 1,
          ),
                          color: isSelected
                              ? AuthColors.surface
                              : AuthColors.surface,
        ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                          zone.region,
                    style: const TextStyle(
                      color: AuthColors.textMain,
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.paddingXS),
                  Row(
                    children: [
                  Text(
                              zone.isActive ? 'Active' : 'Inactive',
                              style: TextStyle(
                                color: zone.isActive
                                    ? AuthColors.successVariant
                                    : AuthColors.textSub,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                      ),
                      if (zone.roundtripKm != null) ...[
                        const SizedBox(width: 12),
                        const Icon(
                          Icons.straighten,
                          size: 14,
                          color: AuthColors.textSub,
                        ),
                        const SizedBox(width: AppSpacing.paddingXS),
                        Text(
                          '${zone.roundtripKm!.toStringAsFixed(1)} km',
                          style: const TextStyle(
                            color: AuthColors.textSub,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
        ),
      ],
    );
  }
}

class _AddCityDialog extends StatefulWidget {
  const _AddCityDialog();

  @override
  State<_AddCityDialog> createState() => _AddCityDialogState();
}

class _AddCityDialogState extends State<_AddCityDialog> {
  final _formKey = GlobalKey<FormState>();
  final _controller = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AuthColors.surface,
      title: const Text('Add City', style: TextStyle(color: AuthColors.textMain)),
      content: Form(
        key: _formKey,
        child: TextFormField(
          controller: _controller,
          style: const TextStyle(color: AuthColors.textMain),
          decoration: const InputDecoration(
            labelText: 'City name',
            filled: true,
            fillColor: AuthColors.surface,
            labelStyle: TextStyle(color: AuthColors.textSub),
            border: OutlineInputBorder(borderSide: BorderSide.none),
          ),
          validator: (value) =>
              (value == null || value.trim().isEmpty) ? 'Enter a city name' : null,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: _submitting
              ? null
              : () async {
                  if (!(_formKey.currentState?.validate() ?? false)) return;
                  setState(() => _submitting = true);
                  try {
                    await context
                        .read<DeliveryZonesCubit>()
                        .createCity(_controller.text.trim());
                    if (mounted) Navigator.of(context).pop();
                  } catch (err) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(err.toString())),
                      );
                    }
                  } finally {
                    if (mounted) setState(() => _submitting = false);
                  }
                },
          child: _submitting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Save'),
        ),
      ],
    );
  }
}

class _AddRegionDialog extends StatefulWidget {
  const _AddRegionDialog({
    required this.cities,
    this.initialCity,
  });

  final List<DeliveryCity> cities;
  final String? initialCity;

  @override
  State<_AddRegionDialog> createState() => _AddRegionDialogState();
}

class _AddRegionDialogState extends State<_AddRegionDialog> {
  final _formKey = GlobalKey<FormState>();
  late String? _selectedCity;
  final _regionController = TextEditingController();
  final _roundtripKmController = TextEditingController();
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _selectedCity = widget.initialCity ?? (widget.cities.isNotEmpty ? widget.cities.first.name : null);
  }

  @override
  void dispose() {
    _regionController.dispose();
    _roundtripKmController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AuthColors.surface,
      title: const Text('Add Region', style: TextStyle(color: AuthColors.textMain)),
      content: widget.cities.isEmpty
          ? const Text(
              'Please add a city first.',
              style: TextStyle(color: AuthColors.textSub),
            )
          : Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: _selectedCity,
                    dropdownColor: AuthColors.surface,
                    decoration: const InputDecoration(
                      labelText: 'City',
                      filled: true,
                      fillColor: AuthColors.surface,
                      labelStyle: TextStyle(color: AuthColors.textSub),
                      border: OutlineInputBorder(borderSide: BorderSide.none),
                    ),
                    items: widget.cities
                        .map(
                          (city) => DropdownMenuItem(
                            value: city.name,
                            child: Text(city.name),
                          ),
                        )
                        .toList(),
                    onChanged: (value) => setState(() => _selectedCity = value),
                    validator: (value) =>
                        (value == null || value.isEmpty) ? 'Select a city' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _regionController,
                    style: const TextStyle(color: AuthColors.textMain),
                    decoration: const InputDecoration(
                      labelText: 'Region / Address',
                      filled: true,
                      fillColor: AuthColors.surface,
                      labelStyle: TextStyle(color: AuthColors.textSub),
                      border: OutlineInputBorder(borderSide: BorderSide.none),
                    ),
                    validator: (value) =>
                        (value == null || value.trim().isEmpty) ? 'Enter a region' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _roundtripKmController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    style: const TextStyle(color: AuthColors.textMain),
                    decoration: const InputDecoration(
                      labelText: 'Round Trip Distance (KM)',
                      hintText: 'e.g., 25.5',
                      prefixIcon: Icon(Icons.straighten, color: AuthColors.textSub),
                      filled: true,
                      fillColor: AuthColors.surface,
                      labelStyle: TextStyle(color: AuthColors.textSub),
                      border: OutlineInputBorder(borderSide: BorderSide.none),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Enter round trip distance';
                      }
                      final km = double.tryParse(value.trim());
                      if (km == null || km <= 0) {
                        return 'Enter a valid positive number';
                      }
                      return null;
                    },
                  ),
                ],
              ),
            ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: widget.cities.isEmpty || _submitting
              ? null
              : () async {
                  if (!(_formKey.currentState?.validate() ?? false)) return;
                  if (_selectedCity == null) return;
                  setState(() => _submitting = true);
                  try {
                    final roundtripKm = double.parse(_roundtripKmController.text.trim());
                    await context.read<DeliveryZonesCubit>().createRegion(
                          city: _selectedCity!,
                          region: _regionController.text.trim(),
                          roundtripKm: roundtripKm,
                        );
                    if (mounted) Navigator.of(context).pop();
                  } catch (err) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(err.toString())),
                      );
                    }
                  } finally {
                    if (mounted) setState(() => _submitting = false);
                  }
                },
          child: _submitting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Save'),
        ),
      ],
    );
  }
}

class _RegionPriceDialog extends StatefulWidget {
  const _RegionPriceDialog({
    required this.zone,
    required this.pricePermission,
    required this.canEditRegion,
    required this.canDeleteRegion,
    required this.onEditRegion,
  });

  final DeliveryZone zone;
  final ZoneCrudPermission pricePermission;
  final bool canEditRegion;
  final bool canDeleteRegion;
  final VoidCallback onEditRegion;

  @override
  State<_RegionPriceDialog> createState() => _RegionPriceDialogState();
}

class _RegionPriceDialogState extends State<_RegionPriceDialog> {
  final _formKey = GlobalKey<FormState>();
  String? _selectedProductId;
  final _priceController = TextEditingController();
  bool _submitting = false;
  String? _lastSyncedProductId;

  @override
  void dispose() {
    _priceController.dispose();
    super.dispose();
  }

  void _syncPrice(DeliveryZonesState state) {
    final selectedId = _selectedProductId ?? (state.products.isNotEmpty ? state.products.first.id : null);
    if (_selectedProductId != selectedId) {
      _selectedProductId = selectedId;
      _lastSyncedProductId = null;
    }
    if (_selectedProductId == null) {
      _priceController.text = '';
      return;
    }
    if (_lastSyncedProductId == _selectedProductId) {
      return;
    }
    OrganizationProduct? matched;
    for (final product in state.products) {
      if (product.id == _selectedProductId) {
        matched = product;
        break;
      }
    }
    final fallbackProduct =
        matched ?? (state.products.isNotEmpty ? state.products.first : null);
    final entry = state.selectedZonePrices.firstWhere(
      (price) => price.productId == _selectedProductId,
      orElse: () => DeliveryZonePrice(
        productId: _selectedProductId!,
        productName: fallbackProduct?.name ?? '',
        deliverable: true,
        unitPrice: 0,
      ),
    );
    _priceController.text = entry.unitPrice.toStringAsFixed(2);
    _lastSyncedProductId = _selectedProductId;
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<DeliveryZonesCubit, DeliveryZonesState>(
      builder: (context, state) {
        _syncPrice(state);
        final products = state.products;
        final canEditPrice = widget.pricePermission.canEdit;

        return AlertDialog(
          backgroundColor: AuthColors.surface,
          insetPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.paddingXL, vertical: AppSpacing.paddingXXL),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.zone.region, style: const TextStyle(color: AuthColors.textMain)),
              Text(widget.zone.cityName, style: const TextStyle(color: AuthColors.textSub)),
            ],
          ),
          content: SingleChildScrollView(
            child: Form(
              key: _formKey,
              child: products.isEmpty
                ? const Text(
                    'No products available to configure prices.',
                    style: TextStyle(color: AuthColors.textSub),
                  )
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      DropdownButtonFormField<String>(
                        initialValue: _selectedProductId,
                        dropdownColor: AuthColors.surface,
                        decoration: const InputDecoration(
                          labelText: 'Product',
                          filled: true,
                          fillColor: AuthColors.surface,
                          labelStyle: TextStyle(color: AuthColors.textSub),
                          border: OutlineInputBorder(borderSide: BorderSide.none),
                        ),
                        items: products
                            .map(
                              (product) => DropdownMenuItem(
                                value: product.id,
                                child: Text(product.name),
                              ),
                            )
                            .toList(),
                        onChanged: (value) => setState(() => _selectedProductId = value),
                      ),
                      const SizedBox(height: AppSpacing.paddingMD),
                      TextFormField(
                        controller: _priceController,
                        style: const TextStyle(color: AuthColors.textMain),
                        keyboardType:
                            const TextInputType.numberWithOptions(decimal: true),
                        enabled: canEditPrice,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Enter a price';
                          }
                          final parsed = double.tryParse(value.trim());
                          if (parsed == null) {
                            return 'Enter a valid number';
                          }
                          if (parsed < 0) {
                            return 'Price cannot be negative';
                          }
                          return null;
                        },
                        decoration: InputDecoration(
                          labelText: 'Unit Price',
                          labelStyle: const TextStyle(color: AuthColors.textSub),
                          filled: true,
                          fillColor: AuthColors.surface,
                          errorStyle: const TextStyle(color: AuthColors.error),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(AppSpacing.radiusMD),
                            borderSide: BorderSide.none,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(AppSpacing.radiusMD),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(AppSpacing.radiusMD),
                            borderSide: const BorderSide(
                              color: AuthColors.primary,
                              width: 2,
                            ),
                          ),
                          errorBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(AppSpacing.radiusMD),
                            borderSide: const BorderSide(
                              color: AuthColors.error,
                              width: 1,
                            ),
                          ),
                          focusedErrorBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(AppSpacing.radiusMD),
                            borderSide: const BorderSide(
                              color: AuthColors.error,
                              width: 2,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: widget.canEditRegion ? widget.onEditRegion : null,
              child: const Text('Edit Region'),
            ),
            if (widget.canDeleteRegion)
              TextButton(
                onPressed: () async {
                  HapticFeedback.mediumImpact();
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      backgroundColor: AuthColors.surface,
                      title: const Text('Delete Region', style: TextStyle(color: AuthColors.textMain)),
                      content: Text(
                        'Are you sure you want to delete "${widget.zone.region}"? This will also delete all prices for this region.',
                        style: const TextStyle(color: AuthColors.textSub),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(false),
                          child: const Text('Cancel'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(true),
                          child: const Text(
                            'Delete',
                            style: TextStyle(color: AuthColors.error),
                          ),
                        ),
                      ],
                    ),
                  );
                  if (confirmed != true || !mounted) return;
                  
                  try {
                    await context.read<DeliveryZonesCubit>().deleteZone(widget.zone.id);
                    if (mounted) {
                      Navigator.of(context).pop();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Region deleted successfully'),
                          backgroundColor: AuthColors.success,
                        ),
                      );
                    }
                  } catch (err) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Failed to delete region: ${err.toString()}'),
                          backgroundColor: AuthColors.error,
                        ),
                      );
                    }
                  }
                },
                child: const Text(
                  'Delete Region',
                  style: TextStyle(color: AuthColors.error),
                ),
              ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
            TextButton(
              onPressed: !canEditPrice || products.isEmpty || _selectedProductId == null || _submitting
                  ? null
                  : () async {
                      HapticFeedback.mediumImpact();
                      if (!(_formKey.currentState?.validate() ?? false)) {
                        return;
                      }
                      final parsed = double.tryParse(_priceController.text.trim());
                      if (parsed == null || parsed < 0) {
                        return;
                      }
                      setState(() => _submitting = true);
                      try {
                        await context.read<DeliveryZonesCubit>().upsertPrice(
                              DeliveryZonePrice(
                                productId: _selectedProductId!,
                                productName: products
                                    .firstWhere((p) => p.id == _selectedProductId!)
                                    .name,
                                deliverable: true,
                                unitPrice: parsed,
                              ),
                            );
                        if (mounted) {
                          Navigator.of(context).pop();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Price updated successfully'),
                              backgroundColor: AuthColors.success,
                            ),
                          );
                        }
                      } catch (err) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Failed to update price: ${err.toString()}'),
                              backgroundColor: AuthColors.error,
                              action: SnackBarAction(
                                label: 'Retry',
                                onPressed: () {
                                  // Re-run the save operation
                                  final parsed = double.tryParse(_priceController.text.trim());
                                  if (parsed != null && parsed >= 0) {
                                    // This will be handled by the button's onPressed callback
                                  }
                                },
                              ),
                            ),
                          );
                        }
                      } finally {
                        if (mounted) setState(() => _submitting = false);
                      }
                    },
              child: _submitting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Save Price'),
            ),
          ],
        );
      },
    );
  }
}

class _ZoneDialog extends StatefulWidget {
  const _ZoneDialog({
    this.zone,
    required this.cityPermission,
    required this.regionPermission,
  });

  final DeliveryZone? zone;
  final ZoneCrudPermission cityPermission;
  final ZoneCrudPermission regionPermission;

  @override
  State<_ZoneDialog> createState() => _ZoneDialogState();
}

class _ZoneDialogState extends State<_ZoneDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _cityController;
  late final TextEditingController _regionController;
  late final TextEditingController _roundtripKmController;
  bool _isActive = true;

  @override
  void initState() {
    super.initState();
    final zone = widget.zone;
    _cityController = TextEditingController(text: zone?.cityName ?? '');
    _regionController = TextEditingController(text: zone?.region ?? '');
    _roundtripKmController = TextEditingController(
      text: zone?.roundtripKm?.toString() ?? '',
    );
    _isActive = zone?.isActive ?? true;
  }

  @override
  void dispose() {
    _cityController.dispose();
    _regionController.dispose();
    _roundtripKmController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.zone != null;
    final canEditCityField = isEditing
        ? widget.cityPermission.canEdit
        : widget.cityPermission.canCreate;
    final canEditRegionField = isEditing
        ? widget.regionPermission.canEdit
        : widget.regionPermission.canCreate;
    final canToggleActive =
        widget.cityPermission.canEdit || widget.regionPermission.canEdit;
    final canSubmit = isEditing
        ? (widget.cityPermission.canEdit || widget.regionPermission.canEdit)
        : (widget.cityPermission.canCreate && widget.regionPermission.canCreate);
    _zonesLog(
        'ZoneDialog editing=$isEditing canSubmit=$canSubmit cityPerm=${widget.cityPermission} regionPerm=${widget.regionPermission}');

    return AlertDialog(
      backgroundColor: AuthColors.surface,
      title: Text(
        isEditing ? 'Edit Zone' : 'Add Zone',
        style: const TextStyle(color: AuthColors.textMain),
      ),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _cityController,
              style: const TextStyle(color: AuthColors.textMain),
              decoration: _inputDecoration('City'),
              enabled: canEditCityField,
              validator: (value) =>
                  (value == null || value.trim().isEmpty)
                      ? 'Enter city name'
                      : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _regionController,
              style: const TextStyle(color: AuthColors.textMain),
              decoration: _inputDecoration('Region'),
              enabled: canEditRegionField,
              validator: (value) =>
                  (value == null || value.trim().isEmpty)
                      ? 'Enter region'
                      : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _roundtripKmController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: const TextStyle(color: AuthColors.textMain),
              decoration: _inputDecoration('Round Trip Distance (KM)'),
              enabled: canEditRegionField,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Enter round trip distance';
                }
                final km = double.tryParse(value.trim());
                if (km == null || km <= 0) {
                  return 'Enter a valid positive number';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              value: _isActive,
              onChanged: canToggleActive
                  ? (value) => setState(() => _isActive = value)
                  : null,
              title: const Text(
                'Active',
                style: TextStyle(color: AuthColors.textMain),
              ),
            ),
            if (!canSubmit)
              const Padding(
                padding: EdgeInsets.only(top: AppSpacing.paddingSM),
                child: Text(
                  'You do not have permission to save changes for this zone.',
                  style: TextStyle(color: AuthColors.error, fontSize: 12),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: canSubmit
              ? () async {
            if (!(_formKey.currentState?.validate() ?? false)) return;
                  _zonesLog('ZoneDialog submit tapped (editing=$isEditing)');
            final cubit = context.read<DeliveryZonesCubit>();
            final state = cubit.state;
            
            // Find city by name to get cityId
            final cityName = _cityController.text.trim();
            final city = state.cities.firstWhere(
              (c) => c.name == cityName,
              orElse: () => throw Exception('City not found: $cityName'),
            );
            
            // Get organizationId from existing zone or from cubit
            final organizationId = widget.zone?.organizationId ?? 
                (state.zones.isNotEmpty ? state.zones.first.organizationId : cubit.orgId);
            
            // Parse roundtripKm
            final roundtripKmText = _roundtripKmController.text.trim();
            final roundtripKm = roundtripKmText.isEmpty
                ? null
                : double.tryParse(roundtripKmText);
            if (roundtripKm != null && roundtripKm <= 0) {
              throw Exception('Round trip distance must be a positive number');
            }
            
            // ID will be auto-generated by Firestore for new zones
            final zone = DeliveryZone(
              id: widget.zone?.id ?? '', // Empty for new zones, Firestore will generate
              organizationId: organizationId,
              cityId: city.id,
              cityName: city.name,
              region: _regionController.text.trim(),
              prices: widget.zone?.prices ?? {},
              isActive: _isActive,
              roundtripKm: roundtripKm,
            );
                  try {
            if (isEditing) {
                      await cubit.updateZone(zone);
            } else {
                      await cubit.createZone(zone);
                    }
                    if (mounted) Navigator.of(context).pop();
                  } catch (err, stack) {
                    _zonesLog('ZoneDialog submit error: $err\n$stack');
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Failed to save zone: $err'),
                        ),
                      );
                    }
                  }
                }
              : null,
          child: const Text('Save'),
        ),
      ],
    );
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: AuthColors.surface,
      labelStyle: const TextStyle(color: AuthColors.textSub),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
    );
  }
}

