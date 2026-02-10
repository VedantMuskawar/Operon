import 'package:core_models/core_models.dart';
import 'package:core_ui/core_ui.dart' show AuthColors;
import 'package:dash_mobile/presentation/blocs/create_order/create_order_cubit.dart';
import 'package:dash_mobile/shared/constants/app_spacing.dart';
import 'package:dash_mobile/shared/constants/app_typography.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class DeliveryZoneSelectionSection extends StatelessWidget {
  const DeliveryZoneSelectionSection({super.key});

  @override
  Widget build(BuildContext context) {
    final cubit = context.watch<CreateOrderCubit>();
    final state = cubit.state;

    return LayoutBuilder(
      builder: (context, constraints) {
        final totalWidth = constraints.maxWidth - 24; // Account for padding (12px each side)
        final cityWidth = totalWidth * 0.5;
        final regionWidth = totalWidth * 0.5 - 12; // Account for spacing

        final columnHeight = constraints.maxHeight.isFinite
            ? constraints.maxHeight
            : MediaQuery.of(context).size.height * 0.55;

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.paddingMD),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Select City & Region',
                style: AppTypography.withColor(AppTypography.h3, AuthColors.textMain),
              ),
              const SizedBox(height: AppSpacing.paddingXL),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'City',
                      style: AppTypography.withWeight(AppTypography.label, FontWeight.w600),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      'Region',
                      style: AppTypography.withWeight(AppTypography.label, FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.paddingMD),
            if (state.isLoadingZones)
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: AppSpacing.paddingLG),
                      Text(
                        'Loading zones...',
                        style: AppTypography.withColor(AppTypography.caption, AuthColors.textSub),
                      ),
                    ],
                  ),
                ),
              )
            else if (state.cities.isEmpty && state.zones.isEmpty)
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.location_off,
                        size: 48,
                        color: AuthColors.textDisabled,
                      ),
                      SizedBox(height: AppSpacing.paddingLG),
                      Text(
                        'No delivery zones available',
                        style: AppTypography.withColor(AppTypography.body, AuthColors.textSub),
                      ),
                      SizedBox(height: AppSpacing.paddingSM),
                      Text(
                        'Add cities and regions in Delivery Zones page',
                        style: AppTypography.withColor(AppTypography.labelSmall, AuthColors.textSub),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              )
            else
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 220),
                      width: cityWidth,
                      height: columnHeight,
                      child: _CityColumn(
                        selectedCity: state.selectedCity,
                        cities: state.cities,
                        onSelectCity: (city) => cubit.selectCity(city),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.paddingMD),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 220),
                      width: regionWidth,
                      height: columnHeight,
                      child: _RegionColumn(
                        regions: cubit.getZonesForCity(state.selectedCity),
                        selectedZoneId: state.selectedZoneId,
                        hasCities: state.cities.isNotEmpty,
                        selectedCity: state.selectedCity,
                        pendingNewZone: state.pendingNewZone,
                        onAddRegion: () => _showAddRegionDialog(context, cubit, state),
                        onLongPressZone: (zone) => _showRegionPriceDialog(context, cubit, zone),
                      ),
                    ),
                  ],
                ),
              ),
            // Unit Price Box - shown when both city and region are selected
            if (state.selectedCity != null && state.selectedZoneId != null) ...[
              const SizedBox(height: AppSpacing.paddingXL),
              _UnitPriceBox(
                zoneId: state.selectedZoneId!,
                cubit: cubit,
              ),
            ],
            ],
          ),
        );
      },
    );
  }

  static void _showAddRegionDialog(
    BuildContext context,
    CreateOrderCubit cubit,
    CreateOrderState state,
  ) {
    showDialog(
      context: context,
      builder: (dialogContext) => _AddRegionDialog(
        cities: state.cities,
        initialCity: state.selectedCity,
        onCreateRegion: (city, region, roundtripKm) async {
          cubit.addPendingRegion(city: city, region: region, roundtripKm: roundtripKm);
          // Dialog will close itself, no need to pop here
        },
      ),
    );
  }

  static void _showRegionPriceDialog(
    BuildContext context,
    CreateOrderCubit cubit,
    DeliveryZone zone,
  ) {
    showDialog(
      context: context,
      builder: (_) => _RegionPriceDialog(
        zone: zone,
        cubit: cubit,
      ),
    );
  }
}

class _CityColumn extends StatelessWidget {
  const _CityColumn({
    required this.selectedCity,
    required this.cities,
    required this.onSelectCity,
  });

  final String? selectedCity;
  final List<DeliveryCity> cities;
  final ValueChanged<String> onSelectCity;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: cities.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.paddingMD),
                    child: Text(
                      'No cities available.',
                      style: AppTypography.withColor(AppTypography.caption, AuthColors.textSub),
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : ListView.separated(
                  itemCount: cities.length,
                  separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.paddingMD),
                  itemBuilder: (context, index) {
                    final city = cities[index];
                    final isSelected = city.name == selectedCity;
                    return GestureDetector(
                      onTap: () => onSelectCity(city.name),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(AppSpacing.radiusLG),
                          color: isSelected
                              ? AuthColors.surface
                              : AuthColors.backgroundAlt,
                          border: Border.all(
                            color: isSelected
                                ? AuthColors.secondary
                                : AuthColors.textMainWithOpacity(0.12),
                            width: isSelected ? 2 : 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                city.name,
                                style: AppTypography.withWeight(
                                  isSelected ? AppTypography.h4 : AppTypography.bodyLarge,
                                  FontWeight.w600,
                                ).copyWith(color: AuthColors.textMain),
                              ),
                            ),
                            if (isSelected)
                              const Icon(
                                Icons.arrow_forward_ios,
                                size: 14,
                                color: AuthColors.textSub,
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
}

class _RegionColumn extends StatelessWidget {
  const _RegionColumn({
    required this.regions,
    required this.selectedZoneId,
    required this.hasCities,
    required this.selectedCity,
    this.pendingNewZone,
    required this.onAddRegion,
    required this.onLongPressZone,
  });

  final List<DeliveryZone> regions;
  final String? selectedZoneId;
  final bool hasCities;
  final String? selectedCity;
  final DeliveryZone? pendingNewZone;
  final VoidCallback onAddRegion;
  final ValueChanged<DeliveryZone> onLongPressZone;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (hasCities && selectedCity != null)
          SizedBox(
            width: 220,
            child: ElevatedButton(
              onPressed: onAddRegion,
              style: ElevatedButton.styleFrom(
                backgroundColor: AuthColors.secondary,
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.paddingMD),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMD),
                ),
              ),
              child: const Text(
                'Add Region',
                style: TextStyle(
                  color: AuthColors.textMain,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        if (hasCities && selectedCity != null) const SizedBox(height: AppSpacing.paddingLG),
        Expanded(
          child: !hasCities
              ? Center(
                  child: Text(
                    'Select a city first.',
                    style: AppTypography.withColor(AppTypography.caption, AuthColors.textSub),
                  ),
                )
              : _buildRegionsList(context),
        ),
      ],
    );
  }

  Widget _buildRegionsList(BuildContext context) {
    final cubit = context.read<CreateOrderCubit>();
    final allRegions = <DeliveryZone>[...regions];
    
    // Add pending zone if it matches selected city
    if (pendingNewZone != null && 
        pendingNewZone!.cityName == selectedCity) {
      allRegions.add(pendingNewZone!);
    }
    
    if (allRegions.isEmpty) {
      return Center(
        child: Text(
          'No regions in this city.',
          style: AppTypography.withColor(AppTypography.caption, AuthColors.textSub),
        ),
      );
    }
    
    return ListView.separated(
      itemCount: allRegions.length,
      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.paddingMD),
      itemBuilder: (context, index) {
        final zone = allRegions[index];
        final isPending = pendingNewZone != null && zone.id == pendingNewZone!.id;
        final isSelected = selectedZoneId == zone.id;
        
        return GestureDetector(
          onTap: () {
            if (isPending) {
              // Pending zone is already selected
              return;
            }
            cubit.selectZone(zone.id);
          },
          onLongPress: isPending ? null : () => onLongPressZone(zone),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.all(AppSpacing.paddingLG),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppSpacing.radiusXL),
              border: Border.all(
                color: isPending
                    ? AuthColors.secondary // Gold for pending
                    : isSelected
                        ? AuthColors.secondary
                        : AuthColors.textMainWithOpacity(0.12),
                width: isPending || isSelected ? 2 : 1,
              ),
              color: isPending
                  ? AuthColors.secondary.withOpacity(0.1) // Gold tint
                  : isSelected
                      ? AuthColors.surface
                      : AuthColors.backgroundAlt,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            zone.region,
                            style: AppTypography.withColor(
                              AppTypography.withWeight(AppTypography.h4, FontWeight.w600),
                              isPending ? AuthColors.secondary : AuthColors.textMain,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.paddingXS),
                      Text(
                        zone.isActive ? 'Active' : 'Inactive',
                        style: AppTypography.withColor(
                          AppTypography.withWeight(AppTypography.labelSmall, FontWeight.w600),
                          zone.isActive ? AuthColors.successVariant : AuthColors.textSub,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isSelected && !isPending)
                  const Icon(
                    Icons.check_circle,
                    color: AuthColors.secondary,
                    size: 20,
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _AddRegionDialog extends StatefulWidget {
  const _AddRegionDialog({
    required this.cities,
    this.initialCity,
    required this.onCreateRegion,
  });

  final List<DeliveryCity> cities;
  final String? initialCity;
  final Future<void> Function(String city, String region, double roundtripKm) onCreateRegion;

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
    return AlertDialog(
      backgroundColor: AuthColors.background,
      title: Text('Add Region', style: AppTypography.withColor(AppTypography.h3, AuthColors.textMain)),
      content: widget.cities.isEmpty
          ? Text(
              'Please add a city first.',
              style: AppTypography.withColor(AppTypography.body, AuthColors.textSub),
            )
          : Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: _selectedCity,
                    dropdownColor: AuthColors.surface,
                    decoration: InputDecoration(
                      labelText: 'City',
                      filled: true,
                      fillColor: AuthColors.surface,
                      labelStyle: AppTypography.withColor(AppTypography.label, AuthColors.textSub),
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
                  const SizedBox(height: AppSpacing.paddingMD),
                  TextFormField(
                    controller: _regionController,
                    style: AppTypography.withColor(AppTypography.body, AuthColors.textMain),
                    decoration: InputDecoration(
                      labelText: 'Region / Address',
                      filled: true,
                      fillColor: AuthColors.surface,
                      labelStyle: AppTypography.withColor(AppTypography.label, AuthColors.textSub),
                      border: OutlineInputBorder(borderSide: BorderSide.none),
                    ),
                    validator: (value) =>
                        (value == null || value.trim().isEmpty) ? 'Enter a region' : null,
                  ),
                  const SizedBox(height: AppSpacing.paddingMD),
                  TextFormField(
                    controller: _roundtripKmController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    style: AppTypography.withColor(AppTypography.body, AuthColors.textMain),
                    decoration: InputDecoration(
                      labelText: 'Round Trip Distance (KM)',
                      hintText: 'e.g., 25.5',
                      prefixIcon: Icon(Icons.straighten, color: AuthColors.textSub),
                      filled: true,
                      fillColor: AuthColors.backgroundAlt,
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
                    await widget.onCreateRegion(
                      _selectedCity!,
                      _regionController.text.trim(),
                      roundtripKm,
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
    required this.cubit,
  });

  final DeliveryZone zone;
  final CreateOrderCubit cubit;

  @override
  State<_RegionPriceDialog> createState() => _RegionPriceDialogState();
}

class _RegionPriceDialogState extends State<_RegionPriceDialog> {
  String? _selectedProductId;
  final _priceController = TextEditingController();
  bool _submitting = false;
  List<OrganizationProduct> _products = [];
  List<DeliveryZonePrice> _zonePrices = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      _products = widget.cubit.state.availableProducts;
      // Get prices directly from zone (embedded in zone document)
      _zonePrices = widget.zone.prices.values.toList();
      if (_products.isNotEmpty) {
        _selectedProductId = _products.first.id;
        _syncPrice();
      }
    } finally {
      setState(() => _loading = false);
    }
  }

  void _syncPrice() {
    if (_selectedProductId == null) {
      _priceController.text = '';
      return;
    }
    final price = _zonePrices.firstWhere(
      (p) => p.productId == _selectedProductId,
      orElse: () => DeliveryZonePrice(
        productId: _selectedProductId!,
        productName: _products
            .firstWhere((p) => p.id == _selectedProductId, orElse: () => _products.first)
            .name,
        deliverable: true,
        unitPrice: 0,
      ),
    );
    _priceController.text = price.unitPrice.toStringAsFixed(2);
  }

  @override
  void dispose() {
    _priceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const AlertDialog(
        backgroundColor: AuthColors.background,
        content: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return AlertDialog(
      backgroundColor: AuthColors.background,
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.zone.region, style: AppTypography.withColor(AppTypography.body, AuthColors.textMain)),
                Text(widget.zone.cityName, style: AppTypography.withColor(AppTypography.caption, AuthColors.textSub)),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: AuthColors.textSub),
            onPressed: () => Navigator.of(context).pop(),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
      content: _products.isEmpty
          ? const Text(
              'No products available to configure prices.',
            style: TextStyle(color: AuthColors.textSub),
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: _selectedProductId,
                  dropdownColor: AuthColors.backgroundAlt,
                  decoration: InputDecoration(
                    labelText: 'Product',
                    filled: true,
                    fillColor: AuthColors.surface,
                    labelStyle: AppTypography.withColor(AppTypography.label, AuthColors.textSub),
                    border: OutlineInputBorder(borderSide: BorderSide.none),
                  ),
                  items: _products
                      .map(
                        (product) => DropdownMenuItem(
                          value: product.id,
                          child: Text(product.name),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedProductId = value;
                      _syncPrice();
                    });
                  },
                ),
                const SizedBox(height: AppSpacing.paddingMD),
                TextField(
                  controller: _priceController,
                  style: AppTypography.withColor(AppTypography.body, AuthColors.textMain),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: 'Unit Price',
                    labelStyle: AppTypography.withColor(AppTypography.label, AuthColors.textSub),
                    filled: true,
                    fillColor: AuthColors.surface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(12)),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ],
            ),
      actions: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            TextButton.icon(
              onPressed: _products.isEmpty ||
                      _selectedProductId == null ||
                      _submitting
                  ? null
                  : () async {
                      // Edit functionality - same as save for now
                      final parsed = double.tryParse(_priceController.text.trim());
                      if (parsed == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Please enter a valid price')),
                        );
                        return;
                      }
                      setState(() => _submitting = true);
                      try {
                        widget.cubit.addPendingPriceUpdate(
                          productId: _selectedProductId!,
                          unitPrice: parsed,
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
              icon: _submitting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.edit, size: 18),
              label: const Text('Edit'),
              style: TextButton.styleFrom(
                foregroundColor: AuthColors.info,
              ),
            ),
            TextButton.icon(
              onPressed: _products.isEmpty ||
                      _selectedProductId == null ||
                      _submitting
                  ? null
                  : () async {
                      // Delete price
                      setState(() => _submitting = true);
                      try {
                        // Set price to 0 or remove it
                        widget.cubit.addPendingPriceUpdate(
                          productId: _selectedProductId!,
                          unitPrice: 0,
                        );
                        if (mounted) {
                          Navigator.of(context).pop();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Price deleted')),
                          );
                        }
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
              icon: const Icon(Icons.delete, size: 18),
              label: const Text('Delete'),
              style: TextButton.styleFrom(
                foregroundColor: AuthColors.error,
              ),
            ),
            TextButton.icon(
              onPressed: _products.isEmpty ||
                      _selectedProductId == null ||
                      _submitting
                  ? null
                  : () async {
                      final parsed = double.tryParse(_priceController.text.trim());
                      if (parsed == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Please enter a valid price')),
                        );
                        return;
                      }
                      setState(() => _submitting = true);
                      try {
                        widget.cubit.addPendingPriceUpdate(
                          productId: _selectedProductId!,
                          unitPrice: parsed,
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
              icon: _submitting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save, size: 18),
              label: const Text('Save'),
              style: TextButton.styleFrom(
                foregroundColor: AuthColors.success,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _UnitPriceBox extends StatefulWidget {
  const _UnitPriceBox({
    required this.zoneId,
    required this.cubit,
  });

  final String zoneId;
  final CreateOrderCubit cubit;

  @override
  State<_UnitPriceBox> createState() => _UnitPriceBoxState();
}

class _UnitPriceBoxState extends State<_UnitPriceBox> {
  final Map<String, TextEditingController> _priceControllers = {};
  List<DeliveryZonePrice> _zonePrices = [];
  List<OrganizationProduct> _products = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadPrices();
  }

  @override
  void didUpdateWidget(_UnitPriceBox oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Reload prices when zoneId changes
    if (oldWidget.zoneId != widget.zoneId) {
      _loadPrices();
    }
  }

  Future<void> _loadPrices() async {
    setState(() => _loading = true);
    try {
      final isPendingZone = widget.zoneId.startsWith('pending-');
      _products = widget.cubit.state.availableProducts;
      
      // Dispose old controllers
      for (final controller in _priceControllers.values) {
        controller.dispose();
      }
      _priceControllers.clear();
      
      if (isPendingZone) {
        // For pending zones, start with empty fields or pendingPriceUpdates
        final state = widget.cubit.state;
        final priceMap = <String, double>{};
        
        for (final product in _products) {
          // Use pendingPriceUpdates if available, otherwise empty
          final pendingPrice = state.pendingPriceUpdates?[product.id];
          if (pendingPrice != null) {
            _priceControllers[product.id] = TextEditingController(
              text: pendingPrice.toStringAsFixed(2),
            );
            priceMap[product.id] = pendingPrice;
          } else {
            // Empty field for new pending zone
            _priceControllers[product.id] = TextEditingController();
          }
        }
        
        // Update cubit with zone prices (if any pending prices exist)
        if (priceMap.isNotEmpty) {
          widget.cubit.updateZonePrices(priceMap);
        }
      } else {
        // For existing zones, load from database
        _zonePrices = await widget.cubit.getZonePrices(widget.zoneId);
        
        // Build price map
        final priceMap = <String, double>{};
        for (final zp in _zonePrices) {
          priceMap[zp.productId] = zp.unitPrice;
        }
        
        // Initialize controllers for each product with prices from database
        for (final product in _products) {
          final price = _zonePrices.firstWhere(
            (p) => p.productId == product.id,
            orElse: () => DeliveryZonePrice(
              productId: product.id,
              productName: product.name,
              deliverable: true,
              unitPrice: product.unitPrice, // Fallback to product base price
            ),
          );
          _priceControllers[product.id] = TextEditingController(
            text: price.unitPrice.toStringAsFixed(2),
          );
        }
        
        // Update cubit with zone prices and update existing order items
        widget.cubit.updateZonePrices(priceMap);
      }
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    for (final controller in _priceControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }


  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CreateOrderCubit, CreateOrderState>(
      bloc: widget.cubit,
      builder: (context, state) {
        if (_loading) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(AppSpacing.paddingXL),
              child: CircularProgressIndicator(),
            ),
          );
        }

        if (_products.isEmpty) {
          return const SizedBox.shrink();
        }

        return Container(
      padding: const EdgeInsets.all(AppSpacing.paddingLG),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AuthColors.backgroundAlt, AuthColors.background],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppSpacing.radiusXL),
        border: Border.all(color: AuthColors.textMainWithOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Unit Prices',
            style: TextStyle(
              color: AuthColors.textMain,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
                  const SizedBox(height: AppSpacing.paddingMD),
          ..._products.map((product) {
            final controller = _priceControllers[product.id];
            if (controller == null) return const SizedBox.shrink();
            
            return Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.paddingMD),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          product.name,
                          style: const TextStyle(
                            color: AuthColors.textMain,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.gapSM),
                        TextField(
                          controller: controller,
                          style: AppTypography.withColor(AppTypography.body, AuthColors.textMain),
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          onChanged: (value) {
                            final price = double.tryParse(value);
                            if (price != null && price >= 0) {
                              widget.cubit.addPendingPriceUpdate(
                                productId: product.id,
                                unitPrice: price,
                              );
                            }
                          },
                          decoration: InputDecoration(
                            hintText: '0.00',
                            hintStyle: const TextStyle(color: AuthColors.textDisabled),
                            filled: true,
                            fillColor: state.pendingPriceUpdates?[product.id] != null
                                ? AuthColors.secondary.withOpacity(0.1)
                                : AuthColors.backgroundAlt,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(AppSpacing.radiusMD),
                              borderSide: BorderSide(
                                color: state.pendingPriceUpdates?[product.id] != null
                                    ? AuthColors.secondary
                                    : AuthColors.transparent,
                                width: state.pendingPriceUpdates?[product.id] != null
                                    ? 2
                                    : 0,
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(AppSpacing.radiusMD),
                              borderSide: BorderSide(
                                color: state.pendingPriceUpdates?[product.id] != null
                                    ? AuthColors.secondary
                                    : AuthColors.transparent,
                                width: state.pendingPriceUpdates?[product.id] != null
                                    ? 2
                                    : 0,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(AppSpacing.radiusMD),
                              borderSide: BorderSide(
                                color: state.pendingPriceUpdates?[product.id] != null
                                    ? AuthColors.secondary
                                    : AuthColors.secondary,
                                width: 2,
                              ),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 12,
                            ),
                            suffixText: '₹',
                            suffixStyle: const TextStyle(
                              color: AuthColors.textSub,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
      },
    );
  }
}
