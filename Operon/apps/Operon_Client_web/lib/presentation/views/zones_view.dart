import 'package:core_bloc/core_bloc.dart';
import 'package:core_ui/core_ui.dart';
import 'package:core_models/core_models.dart';
import 'package:dash_web/presentation/blocs/delivery_zones/delivery_zones_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';

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
}

class ZonesPageContent extends StatefulWidget {
  const ZonesPageContent({
    required this.cityPermission,
    required this.regionPermission,
    required this.pricePermission,
    required this.isAdmin,
    super.key,
  });

  final ZoneCrudPermission cityPermission;
  final ZoneCrudPermission regionPermission;
  final ZoneCrudPermission pricePermission;
  final bool isAdmin;

  @override
  State<ZonesPageContent> createState() => _ZonesPageContentState();
}

class _ZonesPageContentState extends State<ZonesPageContent> {
  String? _selectedCity;

  void _selectCity(String city, DeliveryZonesState state) {
    if (_selectedCity == city) return;
    setState(() => _selectedCity = city);
    final cityRegions =
        state.zones.where((z) => z.cityName == city).toList();
    if (cityRegions.isEmpty) {
      context.read<DeliveryZonesCubit>().clearSelection();
      return;
    }
    final firstRegion = cityRegions.first;
    context.read<DeliveryZonesCubit>().selectZone(firstRegion.id);
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<DeliveryZonesCubit, DeliveryZonesState>(
      listener: (context, state) {
        if (state.status == ViewStatus.failure && state.message != null) {
          DashSnackbar.show(
            context,
            message: state.message!,
            isError: true,
          );
        }
      },
      child: LayoutBuilder(
        builder: (context, constraints) {
          return BlocBuilder<DeliveryZonesCubit, DeliveryZonesState>(
            builder: (context, state) {
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
              final initialCity = selectedZone?.cityName ??
                  (sortedCities.isNotEmpty ? sortedCities.first : null);
              _selectedCity ??= initialCity;
              // Ensure selected city exists in list; otherwise reset to null
              final selectedCityExists =
                  _selectedCity != null && cityGroups.containsKey(_selectedCity);
              if (!selectedCityExists) {
                _selectedCity = initialCity;
              }
              final currentCityRegions = _selectedCity != null
                  ? cityGroups[_selectedCity] ?? <DeliveryZone>[]
                  : <DeliveryZone>[];

              final selectedRegion = selectedZone;
              final selectedZoneIdExists = selectedRegion != null &&
                  currentCityRegions.any((z) => z.id == selectedRegion.id);
              final safeSelectedZoneId =
                  selectedZoneIdExists ? selectedRegion.id : null;

              return LayoutBuilder(
                builder: (context, constraints) {
                  final maxWidth = constraints.maxWidth.isFinite
                      ? constraints.maxWidth
                      : MediaQuery.of(context).size.width;
                  final availableHeight = constraints.maxHeight.isFinite
                      ? constraints.maxHeight
                      : (MediaQuery.of(context).size.height * 0.7);
                  const columnSpacing = 20.0;
                  final contentHeight = (availableHeight > 400 
                      ? availableHeight - 200.0 
                      : 600.0);

                  return SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minWidth: maxWidth,
                        maxWidth: maxWidth,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Statistics Dashboard
                          _ZonesStatsHeader(
                            cities: state.cities,
                            zones: zones,
                          ),
                          const SizedBox(height: 24),
                          
                          // Three Column Layout
                          ConstrainedBox(
                            constraints: BoxConstraints(
                              minHeight: 400,
                              maxHeight: contentHeight,
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Column 1: City header + Add button + City list
                                Expanded(
                                  flex: 2,
                                  child: _CitySelectionColumn(
                                    selectedCity: selectedCityExists ? _selectedCity : null,
                                    cities: state.cities,
                                    zones: zones,
                                    onSelectCity: (city) => _selectCity(city, state),
                                    canCreate: widget.isAdmin,
                                    onAddCity: () => _openAddCityDialog(context),
                                    canLongPress: widget.isAdmin,
                                    onLongPressCity: widget.isAdmin
                                        ? (city) => _openCityOptionsSheet(context, city)
                                        : null,
                                  ),
                                ),
                                const SizedBox(width: columnSpacing),
                                // Column 2: Region header + Add button + Region list (when a city is selected)
                                Expanded(
                                  flex: 2,
                                  child: _selectedCity != null
                                      ? _RegionSelectionColumn(
                                          selectedRegion: selectedRegion,
                                          regions: currentCityRegions,
                                          selectedZoneId: safeSelectedZoneId,
                                          canCreateRegion: widget.regionPermission.canCreate,
                                          onSelectZone: (zoneId) =>
                                              context.read<DeliveryZonesCubit>().selectZone(zoneId),
                                          onAddRegion: () => _openAddRegionDialog(
                                                context,
                                                cities: state.cities,
                                                initialCity: _selectedCity,
                                              ),
                                          onEditZone: (zone) => _openZoneDialog(context, zone: zone),
                                          canEditZone: widget.regionPermission.canEdit,
                                          canDeleteZone: widget.regionPermission.canDelete,
                                        )
                                      : const _EmptyRegionState(
                                          message: 'Select a city to view regions',
                                        ),
                                ),
                                const SizedBox(width: columnSpacing),
                                // Column 3: Unit Price CRUD (shown when both city and region are selected)
                                Expanded(
                                  flex: 3,
                                  child: _selectedCity != null && selectedRegion != null
                                      ? _UnitPriceRow(
                                          zone: selectedRegion,
                                          pricePermission: widget.pricePermission,
                                          onEditRegion: () => _openZoneDialog(context, zone: selectedRegion),
                                          canEditRegion: widget.regionPermission.canEdit,
                                          canDeleteRegion: widget.regionPermission.canDelete,
                                        )
                                      : _EmptyPriceState(
                                          message: _selectedCity == null
                                              ? 'Select a city and region to manage unit prices'
                                              : 'Select a region to manage unit prices',
                                        ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
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

  Future<void> _openCityOptionsSheet(
    BuildContext context,
    DeliveryCity city,
  ) async {
    await showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF11111B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.white12,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Text(
                  city.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.edit, color: Colors.white),
                  title: const Text('Rename city',
                      style: TextStyle(color: Colors.white)),
                  onTap: () {
                    Navigator.of(context).pop();
                    _openRenameCityDialog(context, city);
                  },
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading:
                      const Icon(Icons.delete_outline, color: Colors.redAccent),
                  title: const Text('Delete city',
                      style: TextStyle(color: Colors.redAccent)),
                  onTap: () {
                    Navigator.of(context).pop();
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
            backgroundColor: const Color(0xFF11111B),
            title: const Text('Rename City', style: TextStyle(color: Colors.white)),
            content: TextField(
              controller: controller,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'City name',
                filled: true,
                fillColor: Color(0xFF1B1B2C),
                labelStyle: TextStyle(color: Colors.white70),
                border: OutlineInputBorder(borderSide: BorderSide.none),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
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
                            DashSnackbar.show(
                              context,
                              message: err.toString(),
                              isError: true,
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
                    : const Text('Save', style: TextStyle(color: Color(0xFF6F4BFF))),
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
        backgroundColor: const Color(0xFF11111B),
        title: const Text('Delete City', style: TextStyle(color: Colors.white)),
        content: Text(
          'Deleting "${city.name}" will remove all regions and prices in this city. This cannot be undone.',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text(
              'Delete',
              style: TextStyle(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );
    if (shouldDelete != true) return;
    try {
      await context.read<DeliveryZonesCubit>().deleteCity(city);
    } catch (err) {
      if (mounted) {
        DashSnackbar.show(
          context,
          message: 'Failed to delete city: $err',
          isError: true,
        );
      }
    }
  }
}

class _CitySelectionColumn extends StatelessWidget {
  const _CitySelectionColumn({
    required this.selectedCity,
    required this.cities,
    required this.zones,
    required this.onSelectCity,
    required this.canCreate,
    required this.onAddCity,
    this.canLongPress = false,
    this.onLongPressCity,
  });

  final String? selectedCity;
  final List<DeliveryCity> cities;
  final List<DeliveryZone> zones;
  final ValueChanged<String> onSelectCity;
  final bool canCreate;
  final VoidCallback onAddCity;
  final bool canLongPress;
  final ValueChanged<DeliveryCity>? onLongPressCity;

  int _getRegionCountForCity(String cityName) {
    return zones.where((z) => z.cityName == cityName).length;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF6F4BFF).withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.location_city,
                color: Color(0xFF6F4BFF),
                size: 18,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Cities',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
                  letterSpacing: -0.5,
                ),
              ),
            ),
            if (canCreate)
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.1),
                  ),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: onAddCity,
                    borderRadius: BorderRadius.circular(10),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.add, size: 16, color: Color(0xFF6F4BFF)),
                          SizedBox(width: 6),
                          Text(
                            'Add City',
                            style: TextStyle(
                              color: Color(0xFF6F4BFF),
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),
        Expanded(
          child: cities.isEmpty
              ? _EmptyCitiesState(canCreate: canCreate, onAddCity: onAddCity)
              : AnimationLimiter(
                  child: ListView.separated(
                    itemCount: cities.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final city = cities[index];
                      final isSelected = city.name == selectedCity;
                      final regionCount = _getRegionCountForCity(city.name);
                      
                      return AnimationConfiguration.staggeredList(
                        position: index,
                        duration: const Duration(milliseconds: 200),
                        child: SlideAnimation(
                          verticalOffset: 50.0,
                          child: FadeInAnimation(
                            curve: Curves.easeOut,
                            child: _CityCard(
                              city: city,
                              isSelected: isSelected,
                              regionCount: regionCount,
                              onTap: () => onSelectCity(city.name),
                              onLongPress: canLongPress && onLongPressCity != null
                                  ? () => onLongPressCity!(city)
                                  : null,
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

class _RegionSelectionColumn extends StatelessWidget {
  const _RegionSelectionColumn({
    required this.selectedRegion,
    required this.regions,
    required this.selectedZoneId,
    required this.canCreateRegion,
    required this.onSelectZone,
    required this.onAddRegion,
    required this.onEditZone,
    required this.canEditZone,
    required this.canDeleteZone,
  });

  final DeliveryZone? selectedRegion;
  final List<DeliveryZone> regions;
  final String? selectedZoneId;
  final bool canCreateRegion;
  final ValueChanged<String> onSelectZone;
  final VoidCallback onAddRegion;
  final ValueChanged<DeliveryZone> onEditZone;
  final bool canEditZone;
  final bool canDeleteZone;

  int _getPriceCount(DeliveryZone zone) {
    return zone.prices.length;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF5AD8A4).withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.location_on,
                color: Color(0xFF5AD8A4),
                size: 18,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Regions',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
                  letterSpacing: -0.5,
                ),
              ),
            ),
            if (canCreateRegion)
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.1),
                  ),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: onAddRegion,
                    borderRadius: BorderRadius.circular(10),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.add, size: 16, color: Color(0xFF5AD8A4)),
                          SizedBox(width: 6),
                          Text(
                            'Add Region',
                            style: TextStyle(
                              color: Color(0xFF5AD8A4),
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),
        Expanded(
          child: regions.isEmpty
              ? _EmptyRegionsState(onAddRegion: canCreateRegion ? onAddRegion : null)
              : AnimationLimiter(
                  child: ListView.separated(
                    itemCount: regions.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final zone = regions[index];
                      final isSelected = zone.id == selectedZoneId;
                      final priceCount = _getPriceCount(zone);
                      
                      return AnimationConfiguration.staggeredList(
                        position: index,
                        duration: const Duration(milliseconds: 200),
                        child: SlideAnimation(
                          verticalOffset: 50.0,
                          child: FadeInAnimation(
                            curve: Curves.easeOut,
                            child: _RegionCard(
                              zone: zone,
                              isSelected: isSelected,
                              priceCount: priceCount,
                              onTap: () => onSelectZone(zone.id),
                              onEdit: canEditZone ? () => onEditZone(zone) : null,
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

class _UnitPriceRow extends StatefulWidget {
  const _UnitPriceRow({
    required this.zone,
    required this.pricePermission,
    required this.onEditRegion,
    required this.canEditRegion,
    required this.canDeleteRegion,
  });

  final DeliveryZone zone;
  final ZoneCrudPermission pricePermission;
  final VoidCallback onEditRegion;
  final bool canEditRegion;
  final bool canDeleteRegion;

  @override
  State<_UnitPriceRow> createState() => _UnitPriceRowState();
}

class _UnitPriceRowState extends State<_UnitPriceRow> {
  String? _selectedProductId;
  final _priceController = TextEditingController();
  bool _submitting = false;
  String? _lastSyncedZoneId;
  String? _lastSyncedProductId;

  @override
  void initState() {
    super.initState();
    _lastSyncedZoneId = widget.zone.id;
  }

  @override
  void didUpdateWidget(_UnitPriceRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Reset when zone changes
    if (oldWidget.zone.id != widget.zone.id) {
      _lastSyncedZoneId = widget.zone.id;
      _lastSyncedProductId = null; // Force re-sync
      _selectedProductId = null; // Reset product selection
    }
  }

  @override
  void dispose() {
    _priceController.dispose();
    super.dispose();
  }

  void _syncPrice(DeliveryZonesState state) {
    // Initialize product selection if needed
    _selectedProductId ??= state.products.isNotEmpty ? state.products.first.id : null;
    
    // Check if zone changed (prices should be reloaded)
    final zoneChanged = _lastSyncedZoneId != widget.zone.id;
    
    // Sync if product changed OR zone changed OR prices list changed
    if (_selectedProductId == null) return;
    
    final shouldSync = zoneChanged || 
        _selectedProductId != _lastSyncedProductId ||
        state.selectedZoneId != widget.zone.id;
    
    if (!shouldSync) return;
    
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
        unitPrice: fallbackProduct?.unitPrice ?? 0,
      ),
    );
    _priceController.text = entry.unitPrice.toStringAsFixed(2);
    _lastSyncedProductId = _selectedProductId;
    _lastSyncedZoneId = widget.zone.id;
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<DeliveryZonesCubit, DeliveryZonesState>(
      builder: (context, state) {
        _syncPrice(state);
        final products = state.products;
        final hasProducts = products.isNotEmpty;
        final productIds = products.map((p) => p.id).toSet();
        final effectiveProductId = (_selectedProductId != null &&
                productIds.contains(_selectedProductId))
            ? _selectedProductId
            : (hasProducts ? products.first.id : null);
        if (_selectedProductId != effectiveProductId) {
          _selectedProductId = effectiveProductId;
        }
        final canEditPrice = widget.pricePermission.canEdit;

        final priceCount = widget.zone.prices.length;

        return Container(
          padding: const EdgeInsets.all(24),
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Section
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF9800).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.price_check_outlined,
                      color: Color(0xFFFF9800),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Unit Prices',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 18,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${widget.zone.region}, ${widget.zone.cityName}',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.6),
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Status Badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: widget.zone.isActive
                          ? const Color(0xFF5AD8A4).withValues(alpha: 0.2)
                          : Colors.white.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: widget.zone.isActive
                            ? const Color(0xFF5AD8A4).withValues(alpha: 0.3)
                            : Colors.white.withValues(alpha: 0.1),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          widget.zone.isActive ? Icons.check_circle : Icons.pause_circle,
                          size: 14,
                          color: widget.zone.isActive
                              ? const Color(0xFF5AD8A4)
                              : Colors.white.withValues(alpha: 0.6),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          widget.zone.isActive ? 'Active' : 'Inactive',
                          style: TextStyle(
                            color: widget.zone.isActive
                                ? const Color(0xFF5AD8A4)
                                : Colors.white.withValues(alpha: 0.6),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Actions
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF1B1B2C).withValues(alpha: 0.8),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.1),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (widget.canEditRegion)
                          IconButton(
                            icon: const Icon(Icons.edit, size: 18),
                            color: Colors.white70,
                            onPressed: widget.onEditRegion,
                            tooltip: 'Edit Region',
                            padding: const EdgeInsets.all(8),
                            constraints: const BoxConstraints(),
                          ),
                        if (widget.canDeleteRegion) ...[
                          if (widget.canEditRegion)
                            Container(
                              width: 1,
                              height: 24,
                              color: Colors.white.withValues(alpha: 0.1),
                            ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, size: 18),
                            color: Colors.redAccent,
                            onPressed: () async {
                              await context.read<DeliveryZonesCubit>().deleteZone(widget.zone.id);
                            },
                            tooltip: 'Delete Region',
                            padding: const EdgeInsets.all(8),
                            constraints: const BoxConstraints(),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              
              // Price Count Summary
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.08),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 16,
                      color: Colors.white.withValues(alpha: 0.7),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        '$priceCount ${priceCount == 1 ? 'product price' : 'product prices'} configured',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.8),
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              if (!hasProducts)
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.1),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        size: 20,
                        color: Colors.white.withValues(alpha: 0.6),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'No products available to configure prices.',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.7),
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              else ...[
                DropdownButtonFormField<String>(
                  initialValue: effectiveProductId,
                  dropdownColor: const Color(0xFF1B1B2C),
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Product',
                    prefixIcon: const Icon(Icons.inventory_2_outlined, color: Colors.white54, size: 20),
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
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 16,
                    ),
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
                const SizedBox(height: 16),
                TextField(
                  controller: _priceController,
                  style: const TextStyle(color: Colors.white),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: 'Unit Price',
                    prefixIcon: const Icon(Icons.currency_rupee, color: Colors.white54, size: 20),
                    prefixText: '₹ ',
                    prefixStyle: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
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
                    disabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: Colors.white.withValues(alpha: 0.05),
                      ),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 16,
                    ),
                  ),
                  enabled: canEditPrice,
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    icon: _submitting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Icon(Icons.save, size: 18),
                    label: Text(_submitting ? 'Saving...' : 'Save Price'),
                    onPressed: !canEditPrice ||
                            products.isEmpty ||
                            _selectedProductId == null ||
                            _submitting
                        ? null
                        : () async {
                            final parsed = double.tryParse(_priceController.text.trim());
                            if (parsed == null) {
                              DashSnackbar.show(
                                context,
                                message: 'Enter a valid price',
                                isError: true,
                              );
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
                              DashSnackbar.show(
                                context,
                                message: 'Price saved successfully',
                              );
                            } catch (err) {
                              DashSnackbar.show(
                                context,
                                message: err.toString(),
                                isError: true,
                              );
                            } finally {
                              if (mounted) setState(() => _submitting = false);
                            }
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
                ),
              ],
            ],
          ),
        );
      },
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
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 450),
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
                    child: const Icon(
                      Icons.add_location_alt,
                      color: Color(0xFF6F4BFF),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 16),
                  const Expanded(
                    child: Text(
                      'Add City',
                      style: TextStyle(
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
            Padding(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: TextFormField(
                  controller: _controller,
                  autofocus: true,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'City name',
                    prefixIcon: const Icon(Icons.location_city, color: Colors.white54, size: 20),
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
                  ),
                  validator: (value) =>
                      (value == null || value.trim().isEmpty) ? 'Enter a city name' : null,
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
                    icon: _submitting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Icon(Icons.check, size: 18),
                    label: Text(_submitting ? 'Adding...' : 'Add City'),
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
                                DashSnackbar.show(
                                  context,
                                  message: err.toString(),
                                  isError: true,
                                );
                              }
                            } finally {
                              if (mounted) setState(() => _submitting = false);
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
    _selectedCity = widget.initialCity ??
        (widget.cities.isNotEmpty ? widget.cities.first.name : null);
  }

  @override
  void dispose() {
    _regionController.dispose();
    _roundtripKmController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 450),
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
                      color: const Color(0xFF5AD8A4).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.add_location_alt,
                      color: Color(0xFF5AD8A4),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 16),
                  const Expanded(
                    child: Text(
                      'Add Region',
                      style: TextStyle(
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
            Padding(
              padding: const EdgeInsets.all(24),
              child: widget.cities.isEmpty
                  ? Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.1),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            color: Colors.white.withValues(alpha: 0.7),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Text(
                              'Please add a city first.',
                              style: TextStyle(color: Colors.white70),
                            ),
                          ),
                        ],
                      ),
                    )
                  : Form(
                      key: _formKey,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          DropdownButtonFormField<String>(
                            initialValue: _selectedCity,
                            dropdownColor: const Color(0xFF1B1B2C),
                            style: const TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              labelText: 'City',
                              prefixIcon: const Icon(Icons.location_city, color: Colors.white54, size: 20),
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
                                  color: Color(0xFF5AD8A4),
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
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _regionController,
                            autofocus: true,
                            style: const TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              labelText: 'Region / Address',
                              prefixIcon: const Icon(Icons.location_on, color: Colors.white54, size: 20),
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
                                  color: Color(0xFF5AD8A4),
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
                            ),
                            validator: (value) =>
                                (value == null || value.trim().isEmpty) ? 'Enter a region' : null,
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _roundtripKmController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            style: const TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              labelText: 'Round Trip Distance (KM)',
                              hintText: 'e.g., 25.5',
                              prefixIcon: const Icon(Icons.straighten, color: Colors.white54, size: 20),
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
                                  color: Color(0xFF5AD8A4),
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
                    icon: _submitting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Icon(Icons.check, size: 18),
                    label: Text(_submitting ? 'Adding...' : 'Add Region'),
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
                                DashSnackbar.show(
                                  context,
                                  message: err.toString(),
                                  isError: true,
                                );
                              }
                            } finally {
                              if (mounted) setState(() => _submitting = false);
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF5AD8A4),
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
    final selectedId = _selectedProductId ??
        (state.products.isNotEmpty ? state.products.first.id : null);
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
          backgroundColor: const Color(0xFF11111B),
          insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.zone.region, style: const TextStyle(color: Colors.white)),
              Text(widget.zone.city, style: const TextStyle(color: Colors.white54)),
            ],
          ),
          content: SingleChildScrollView(
            child: products.isEmpty
                ? const Text(
                    'No products available to configure prices.',
                    style: TextStyle(color: Colors.white70),
                  )
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      DropdownButtonFormField<String>(
                        initialValue: _selectedProductId,
                        dropdownColor: const Color(0xFF1B1B2C),
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(
                          labelText: 'Product',
                          filled: true,
                          fillColor: Color(0xFF1B1B2C),
                          labelStyle: TextStyle(color: Colors.white70),
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
                      const SizedBox(height: 12),
                      TextField(
                        controller: _priceController,
                        style: const TextStyle(color: Colors.white),
                        keyboardType:
                            const TextInputType.numberWithOptions(decimal: true),
                        decoration: InputDecoration(
                          labelText: 'Unit Price',
                          labelStyle: const TextStyle(color: Colors.white70),
                          filled: true,
                          fillColor: const Color(0xFF1B1B2C),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        enabled: canEditPrice,
                      ),
                    ],
                  ),
          ),
          actions: [
            TextButton(
              onPressed: widget.canEditRegion ? widget.onEditRegion : null,
              child: const Text('Edit Region', style: TextStyle(color: Colors.white70)),
            ),
            if (widget.canDeleteRegion)
              TextButton(
                onPressed: () async {
                  await context.read<DeliveryZonesCubit>().deleteZone(widget.zone.id);
                  if (mounted) Navigator.of(context).pop();
                },
                child: const Text(
                  'Delete Region',
                  style: TextStyle(color: Colors.redAccent),
                ),
              ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close', style: TextStyle(color: Colors.white70)),
            ),
            TextButton(
              onPressed: !canEditPrice ||
                      products.isEmpty ||
                      _selectedProductId == null ||
                      _submitting
                  ? null
                  : () async {
                      final parsed = double.tryParse(_priceController.text.trim());
                      if (parsed == null) {
                        DashSnackbar.show(
                          context,
                          message: 'Enter a valid price',
                          isError: true,
                        );
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
                        if (mounted) Navigator.of(context).pop();
                      } catch (err) {
                        if (mounted) {
                          DashSnackbar.show(
                            context,
                            message: err.toString(),
                            isError: true,
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
                  : const Text('Save Price', style: TextStyle(color: Color(0xFF6F4BFF))),
            ),
          ],
        );
      },
    );
  }
}

class _ZonesStatsHeader extends StatelessWidget {
  const _ZonesStatsHeader({
    required this.cities,
    required this.zones,
  });

  final List<DeliveryCity> cities;
  final List<DeliveryZone> zones;

  @override
  Widget build(BuildContext context) {
    final totalCities = cities.length;
    final totalRegions = zones.length;
    final activeZones = zones.where((z) => z.isActive).length;
    final citiesWithRegions = cities.where((city) {
      return zones.any((zone) => zone.cityName == city.name);
    }).length;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 900;
        return isWide
            ? Row(
                children: [
                  Expanded(
                    child: _StatCard(
                      icon: Icons.location_city,
                      label: 'Total Cities',
                      value: totalCities.toString(),
                      color: const Color(0xFF6F4BFF),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _StatCard(
                      icon: Icons.location_on,
                      label: 'Total Regions',
                      value: totalRegions.toString(),
                      color: const Color(0xFF5AD8A4),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _StatCard(
                      icon: Icons.check_circle,
                      label: 'Active Zones',
                      value: activeZones.toString(),
                      color: const Color(0xFFFF9800),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _StatCard(
                      icon: Icons.map,
                      label: 'Cities with Regions',
                      value: citiesWithRegions.toString(),
                      color: const Color(0xFF2196F3),
                    ),
                  ),
                ],
              )
            : Wrap(
                spacing: 16,
                runSpacing: 16,
                children: [
                  _StatCard(
                    icon: Icons.location_city,
                    label: 'Total Cities',
                    value: totalCities.toString(),
                    color: const Color(0xFF6F4BFF),
                  ),
                  _StatCard(
                    icon: Icons.location_on,
                    label: 'Total Regions',
                    value: totalRegions.toString(),
                    color: const Color(0xFF5AD8A4),
                  ),
                  _StatCard(
                    icon: Icons.check_circle,
                    label: 'Active Zones',
                    value: activeZones.toString(),
                    color: const Color(0xFFFF9800),
                  ),
                  _StatCard(
                    icon: Icons.map,
                    label: 'Cities with Regions',
                    value: citiesWithRegions.toString(),
                    color: const Color(0xFF2196F3),
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

class _CityCard extends StatefulWidget {
  const _CityCard({
    required this.city,
    required this.isSelected,
    required this.regionCount,
    required this.onTap,
    this.onLongPress,
  });

  final DeliveryCity city;
  final bool isSelected;
  final int regionCount;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  @override
  State<_CityCard> createState() => _CityCardState();
}

class _CityCardState extends State<_CityCard> with SingleTickerProviderStateMixin {
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

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => _controller.forward(),
      onExit: (_) => _controller.reverse(),
      child: GestureDetector(
        onTap: widget.onTap,
        onLongPress: widget.onLongPress,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Transform.scale(
              scale: 1.0 + (_controller.value * 0.02),
              child: Container(
                padding: const EdgeInsets.all(18),
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
                    color: widget.isSelected
                        ? const Color(0xFF6F4BFF)
                        : Colors.white.withValues(alpha: 0.1),
                    width: widget.isSelected ? 2 : 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                    if (widget.isSelected)
                      BoxShadow(
                        color: const Color(0xFF6F4BFF).withValues(alpha: 0.3),
                        blurRadius: 15,
                        spreadRadius: -3,
                      ),
                  ],
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
                      child: const Icon(
                        Icons.location_city,
                        color: Color(0xFF6F4BFF),
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.city.name,
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: widget.isSelected ? 16 : 15,
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(
                                Icons.location_on,
                                size: 12,
                                color: Colors.white.withValues(alpha: 0.6),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${widget.regionCount} ${widget.regionCount == 1 ? 'region' : 'regions'}',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.6),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    if (widget.isSelected)
                      const Icon(
                        Icons.check_circle,
                        color: Color(0xFF6F4BFF),
                        size: 20,
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

class _RegionCard extends StatefulWidget {
  const _RegionCard({
    required this.zone,
    required this.isSelected,
    required this.priceCount,
    required this.onTap,
    this.onEdit,
  });

  final DeliveryZone zone;
  final bool isSelected;
  final int priceCount;
  final VoidCallback onTap;
  final VoidCallback? onEdit;

  @override
  State<_RegionCard> createState() => _RegionCardState();
}

class _RegionCardState extends State<_RegionCard> with SingleTickerProviderStateMixin {
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

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => _controller.forward(),
      onExit: (_) => _controller.reverse(),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Transform.scale(
              scale: 1.0 + (_controller.value * 0.02),
              child: Container(
                padding: const EdgeInsets.all(18),
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
                    color: widget.isSelected
                        ? const Color(0xFF5AD8A4)
                        : Colors.white.withValues(alpha: 0.1),
                    width: widget.isSelected ? 2 : 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                    if (widget.isSelected)
                      BoxShadow(
                        color: const Color(0xFF5AD8A4).withValues(alpha: 0.3),
                        blurRadius: 15,
                        spreadRadius: -3,
                      ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: const Color(0xFF5AD8A4).withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.location_on,
                            color: Color(0xFF5AD8A4),
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.zone.region,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: widget.isSelected ? 16 : 15,
                                  letterSpacing: -0.3,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                widget.zone.cityName,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.6),
                                  fontSize: 12,
                                ),
                              ),
                              if (widget.zone.roundtripKm != null) ...[
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.straighten,
                                      size: 12,
                                      color: Colors.white.withValues(alpha: 0.5),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      '${widget.zone.roundtripKm!.toStringAsFixed(1)} km',
                                      style: TextStyle(
                                        color: Colors.white.withValues(alpha: 0.5),
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                        // Status Badge
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: widget.zone.isActive
                                ? const Color(0xFF5AD8A4).withValues(alpha: 0.2)
                                : Colors.white.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: widget.zone.isActive
                                  ? const Color(0xFF5AD8A4).withValues(alpha: 0.3)
                                  : Colors.white.withValues(alpha: 0.1),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                widget.zone.isActive ? Icons.check_circle : Icons.pause_circle,
                                size: 12,
                                color: widget.zone.isActive
                                    ? const Color(0xFF5AD8A4)
                                    : Colors.white.withValues(alpha: 0.6),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                widget.zone.isActive ? 'Active' : 'Inactive',
                                style: TextStyle(
                                  color: widget.zone.isActive
                                      ? const Color(0xFF5AD8A4)
                                      : Colors.white.withValues(alpha: 0.6),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (widget.isSelected && widget.onEdit != null)
                          Padding(
                            padding: const EdgeInsets.only(left: 8),
                            child: IconButton(
                              icon: const Icon(Icons.edit, size: 18),
                              color: Colors.white70,
                              onPressed: widget.onEdit,
                              tooltip: 'Edit Region',
                              padding: const EdgeInsets.all(4),
                              constraints: const BoxConstraints(),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Price Count Badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.attach_money,
                            size: 12,
                            color: Colors.white.withValues(alpha: 0.7),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${widget.priceCount} ${widget.priceCount == 1 ? 'price' : 'prices'}',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.7),
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
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

class _EmptyCitiesState extends StatelessWidget {
  const _EmptyCitiesState({
    required this.canCreate,
    required this.onAddCity,
  });

  final bool canCreate;
  final VoidCallback onAddCity;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(40),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFF1B1B2C).withValues(alpha: 0.6),
              const Color(0xFF161622).withValues(alpha: 0.8),
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.1),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: const Color(0xFF6F4BFF).withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.location_city,
                size: 32,
                color: Color(0xFF6F4BFF),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'No cities yet',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              canCreate
                  ? 'Start by adding your first delivery city'
                  : 'Admins can add cities to get started',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.6),
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
            if (canCreate) ...[
              const SizedBox(height: 24),
              ElevatedButton.icon(
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add City'),
                onPressed: onAddCity,
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
      ),
    );
  }
}

class _EmptyRegionsState extends StatelessWidget {
  const _EmptyRegionsState({this.onAddRegion});

  final VoidCallback? onAddRegion;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(40),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFF1B1B2C).withValues(alpha: 0.6),
              const Color(0xFF161622).withValues(alpha: 0.8),
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.1),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: const Color(0xFF5AD8A4).withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.location_on,
                size: 32,
                color: Color(0xFF5AD8A4),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'No regions yet',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              onAddRegion != null
                  ? 'Add your first region for this city'
                  : 'You do not have permission to add regions',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.6),
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
            if (onAddRegion != null) ...[
              const SizedBox(height: 24),
              ElevatedButton.icon(
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add Region'),
                onPressed: onAddRegion,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF5AD8A4),
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
      ),
    );
  }
}

class _EmptyRegionState extends StatelessWidget {
  const _EmptyRegionState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: const Color(0xFF1B1B2C).withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.1),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.location_off,
              size: 48,
              color: Colors.white.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 16),
            Text(
              message,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.6),
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyPriceState extends StatelessWidget {
  const _EmptyPriceState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: const Color(0xFF1B1B2C).withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.1),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.price_check_outlined,
              size: 48,
              color: Colors.white.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 16),
            Text(
              message,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.6),
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
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

    return AlertDialog(
      backgroundColor: const Color(0xFF11111B),
      title: Text(
        isEditing ? 'Edit Zone' : 'Add Zone',
        style: const TextStyle(color: Colors.white),
      ),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _cityController,
              style: const TextStyle(color: Colors.white),
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
              style: const TextStyle(color: Colors.white),
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
              style: const TextStyle(color: Colors.white),
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
                style: TextStyle(color: Colors.white),
              ),
            ),
            if (!canSubmit)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  'You do not have permission to save changes for this zone.',
                  style: TextStyle(color: Colors.redAccent, fontSize: 12),
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
        ),
        TextButton(
          onPressed: canSubmit
              ? () async {
                  if (!(_formKey.currentState?.validate() ?? false)) return;
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
                  } catch (err) {
                    if (mounted) {
                      DashSnackbar.show(
                        context,
                        message: 'Failed to save zone: $err',
                        isError: true,
                      );
                    }
                  }
                }
              : null,
          child: const Text('Save', style: TextStyle(color: Color(0xFF6F4BFF))),
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
}

