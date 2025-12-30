import 'package:core_bloc/core_bloc.dart';
import 'package:core_models/core_models.dart';
import 'package:dash_web/data/repositories/delivery_zones_repository.dart';
import 'package:dash_web/data/repositories/products_repository.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

part 'delivery_zones_state.dart';

class DeliveryZonesCubit extends Cubit<DeliveryZonesState> {
  DeliveryZonesCubit({
    required DeliveryZonesRepository repository,
    required ProductsRepository productsRepository,
    required String orgId,
  })  : _repository = repository,
        _productsRepository = productsRepository,
        _orgId = orgId,
        super(const DeliveryZonesState());

  final DeliveryZonesRepository _repository;
  final ProductsRepository _productsRepository;
  final String _orgId;
  String get orgId => _orgId;
  List<OrganizationProduct> _catalog = const [];
  List<DeliveryCity> _cities = const [];

  void _log(String message) {
    debugPrint('[ZonesCubit] $message');
  }

  Future<void> loadZones() async {
    _log('loadZones start orgId=$_orgId');
    emit(state.copyWith(status: ViewStatus.loading));
    try {
      final zones = await _repository.fetchZones(_orgId);
      _log('Fetched ${zones.length} zones');
      final fetchedCities = await _repository.fetchCities(_orgId);
      _cities = fetchedCities..sort((a, b) => a.name.compareTo(b.name));
      _log('Resolved ${_cities.length} cities');
      if (_catalog.isEmpty) {
        _catalog = await _productsRepository.fetchProducts(_orgId);
        _log('Fetched products catalog size=${_catalog.length}');
      }
      emit(
        state.copyWith(
          status: ViewStatus.success,
          zones: zones,
          products: _catalog,
          cities: _cities,
          message: null,
        ),
      );
      if (zones.isNotEmpty) {
        final targetZoneId = state.selectedZoneId ?? zones.first.id;
        _log('Selecting zone $targetZoneId after load');
        await selectZone(targetZoneId);
      }
    } catch (err, stack) {
      _log('loadZones error: $err\n$stack');
      emit(state.copyWith(
        status: ViewStatus.failure,
        message: 'Unable to load delivery zones.',
      ));
    }
  }

  Future<void> selectZone(String zoneId) async {
    _log('selectZone $zoneId');
    emit(state.copyWith(status: ViewStatus.loading, selectedZoneId: zoneId));
    try {
      final zone = state.zones.firstWhere((z) => z.id == zoneId);
      final prices = zone.prices.values.toList();
      _log('Fetched ${prices.length} prices for zone $zoneId');
      final mergedPrices = _mergePrices(_catalog, prices);
      _log('Merged price list size=${mergedPrices.length}');
      emit(
        state.copyWith(
          status: ViewStatus.success,
          selectedZonePrices: mergedPrices,
          selectedZoneId: zoneId,
        ),
      );
    } catch (err, stack) {
      _log('selectZone error: $err\n$stack');
      emit(state.copyWith(
        status: ViewStatus.failure,
        message: 'Unable to load prices.',
      ));
    }
  }

  Future<void> createZone(DeliveryZone zone) async {
    _log('createZone');
    emit(state.copyWith(status: ViewStatus.loading));
    try {
      await _repository.createZone(_orgId, zone);
      await loadZones();
    } catch (err, stack) {
      _log('createZone error: $err\n$stack');
      emit(state.copyWith(
        status: ViewStatus.failure,
        message: 'Unable to create zone.',
      ));
    }
  }

  Future<void> updateZone(DeliveryZone zone) async {
    _log('updateZone ${zone.id}');
    emit(state.copyWith(status: ViewStatus.loading));
    try {
      await _repository.updateZone(_orgId, zone);
      await loadZones();
    } catch (err, stack) {
      _log('updateZone error: $err\n$stack');
      emit(state.copyWith(
        status: ViewStatus.failure,
        message: 'Unable to update zone.',
      ));
    }
  }

  Future<void> deleteZone(String zoneId) async {
    _log('deleteZone $zoneId');
    emit(state.copyWith(status: ViewStatus.loading));
    try {
      await _repository.deleteZone(_orgId, zoneId);
      await loadZones();
    } catch (err, stack) {
      _log('deleteZone error: $err\n$stack');
      emit(state.copyWith(
        status: ViewStatus.failure,
        message: 'Unable to delete zone.',
      ));
    }
  }

  Future<void> upsertPrice(DeliveryZonePrice price) async {
    final zoneId = state.selectedZoneId;
    if (zoneId == null) return;
    _log('upsertPrice zoneId=$zoneId productId=${price.productId}');
    emit(state.copyWith(status: ViewStatus.loading));
    try {
      final product = _catalog.firstWhere(
        (p) => p.id == price.productId,
        orElse: () => OrganizationProduct(
          id: price.productId,
          name: price.productName,
          unitPrice: price.unitPrice,
          gstPercent: null,
          status: ProductStatus.active,
          stock: 0,
          fixedQuantityPerTripOptions: null,
        ),
      );
      final enriched = price.copyWith(productName: product.name);
      await _repository.upsertPrice(
        orgId: _orgId,
        zoneId: zoneId,
        price: enriched,
      );
      await selectZone(zoneId);
    } catch (err, stack) {
      _log('upsertPrice error: $err\n$stack');
      emit(state.copyWith(
        status: ViewStatus.failure,
        message: 'Unable to update price.',
      ));
    }
  }

  Future<void> deletePrice(String productId) async {
    final zoneId = state.selectedZoneId;
    if (zoneId == null) return;
    _log('deletePrice zoneId=$zoneId productId=$productId');
    emit(state.copyWith(status: ViewStatus.loading));
    try {
      await _repository.deletePrice(
        orgId: _orgId,
        zoneId: zoneId,
        productId: productId,
      );
      await selectZone(zoneId);
    } catch (err, stack) {
      _log('deletePrice error: $err\n$stack');
      emit(state.copyWith(
        status: ViewStatus.failure,
        message: 'Unable to delete price.',
      ));
    }
  }

  void clearSelection() {
    _log('clearSelection');
    emit(
      state.copyWith(
        selectedZoneId: null,
        selectedZonePrices: const [],
      ),
    );
  }

  List<DeliveryZonePrice> _mergePrices(
    List<OrganizationProduct> catalog,
    List<DeliveryZonePrice> configured,
  ) {
    if (catalog.isEmpty) return configured;
    final merged = catalog.map((product) {
      final match = configured.firstWhere(
        (price) => price.productId == product.id,
        orElse: () => DeliveryZonePrice(
          productId: product.id,
          productName: product.name,
          deliverable: false,
          unitPrice: product.unitPrice,
        ),
      );
      return match.copyWith(productName: product.name);
    }).toList();
    _log('mergePrices produced ${merged.length} entries');
    return merged;
  }

  Future<void> createCity(String name) async {
    final normalized = name.trim();
    if (normalized.isEmpty) {
      throw Exception('City name cannot be empty');
    }
    if (_cities.any((c) => c.name.toLowerCase() == normalized.toLowerCase())) {
      throw Exception('City already exists');
    }
    await _repository.createCity(orgId: _orgId, cityName: normalized);
    _cities = await _repository.fetchCities(_orgId);
    emit(state.copyWith(cities: _cities));
  }

  Future<void> renameCity({
    required DeliveryCity city,
    required String newName,
  }) async {
    final normalized = newName.trim();
    if (normalized.isEmpty) {
      throw Exception('City name cannot be empty');
    }
    if (_cities.any((c) =>
        c.id != city.id && c.name.toLowerCase() == normalized.toLowerCase())) {
      throw Exception('City already exists');
    }
    await _repository.renameCity(
      orgId: _orgId,
      cityId: city.id,
      oldName: city.name,
      newName: normalized,
    );
    _cities = await _repository.fetchCities(_orgId);
    final zones = await _repository.fetchZones(_orgId);
    emit(state.copyWith(cities: _cities, zones: zones));
  }

  Future<void> deleteCity(DeliveryCity city) async {
    await _repository.deleteCity(
      orgId: _orgId,
      cityId: city.id,
      cityName: city.name,
    );
    _cities = await _repository.fetchCities(_orgId);
    final zones = await _repository.fetchZones(_orgId);
    emit(state.copyWith(cities: _cities, zones: zones, selectedZoneId: null));
  }

  Future<void> createRegion({
    required String city,
    required String region,
    required double roundtripKm,
  }) async {
    final normalizedCity = city.trim();
    final normalizedRegion = region.trim();
    if (normalizedCity.isEmpty || normalizedRegion.isEmpty) {
      throw Exception('City and region are required');
    }
    
    // Find city by name
    final cityObj = _cities.firstWhere(
      (c) => c.name.toLowerCase() == normalizedCity.toLowerCase(),
      orElse: () => throw Exception('City not found'),
    );
    
    final duplicate = state.zones.any(
      (zone) =>
          zone.cityId == cityObj.id &&
          zone.region.toLowerCase() == normalizedRegion.toLowerCase(),
    );
    if (duplicate) {
      throw Exception('This address already exists.');
    }
    
    // ID will be auto-generated by Firestore
    final zone = DeliveryZone(
      id: '', // Will be generated by Firestore
      organizationId: _orgId,
      cityId: cityObj.id,
      cityName: cityObj.name,
      region: normalizedRegion,
      prices: {},
      isActive: true,
      roundtripKm: roundtripKm,
    );
    await createZone(zone);
  }
}

