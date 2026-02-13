import 'package:core_bloc/core_bloc.dart';
import 'package:core_models/core_models.dart';
import 'package:dash_mobile/data/repositories/delivery_zones_repository.dart';
import 'package:dash_mobile/data/repositories/products_repository.dart';
import 'package:dash_mobile/presentation/utils/network_error_helper.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class DeliveryZonesState extends BaseState {
  const DeliveryZonesState({
    super.status = ViewStatus.initial,
    this.zones = const [],
    this.selectedZonePrices = const [],
    this.products = const [],
    this.cities = const [],
    String? message,
    this.selectedZoneId,
  }) : super(message: message);

  final List<DeliveryZone> zones;
  final List<DeliveryZonePrice> selectedZonePrices;
  final List<OrganizationProduct> products;
  final List<DeliveryCity> cities;
  final String? selectedZoneId;
  @override
  DeliveryZonesState copyWith({
    ViewStatus? status,
    List<DeliveryZone>? zones,
    List<DeliveryZonePrice>? selectedZonePrices,
    List<OrganizationProduct>? products,
    List<DeliveryCity>? cities,
    String? selectedZoneId,
    String? message,
  }) {
    return DeliveryZonesState(
      status: status ?? this.status,
      zones: zones ?? this.zones,
      selectedZonePrices: selectedZonePrices ?? this.selectedZonePrices,
      products: products ?? this.products,
      cities: cities ?? this.cities,
      selectedZoneId: selectedZoneId ?? this.selectedZoneId,
      message: message ?? this.message,
    );
  }
}

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
  String get orgId => _orgId; // Public getter for orgId
  List<OrganizationProduct> _catalog = const [];
  List<DeliveryCity> _cities = const [];

  void _log(String message) {
    debugPrint('[ZonesCubit] $message');
  }

  Future<void> loadZones({bool forceRefresh = false}) async {
    _log('loadZones start orgId=$_orgId forceRefresh=$forceRefresh');
    if (!forceRefresh &&
        state.zones.isNotEmpty &&
        _cities.isNotEmpty &&
        _catalog.isNotEmpty) {
      final selection = _resolveSelection(
        state.zones,
        preferredZoneId: state.selectedZoneId,
      );
      emit(state.copyWith(
        status: ViewStatus.success,
        zones: state.zones,
        products: _catalog,
        cities: _cities,
        selectedZoneId: selection.zoneId,
        selectedZonePrices: selection.prices,
        message: null,
      ));
      return;
    }
    emit(state.copyWith(status: ViewStatus.loading));
    try {
      final results = await Future.wait([
        _repository.fetchZones(_orgId),
        _repository.fetchCities(_orgId),
        _catalog.isEmpty
            ? _productsRepository.fetchProducts(_orgId)
            : Future.value(_catalog),
      ]);
      final zones = _sortZones(results[0] as List<DeliveryZone>);
      _log('Fetched ${zones.length} zones');
      _cities = (results[1] as List<DeliveryCity>)
        ..sort((a, b) => a.name.compareTo(b.name));
      _log('Resolved ${_cities.length} cities');
      _catalog = results[2] as List<OrganizationProduct>;
      _log('Resolved products catalog size=${_catalog.length}');
      final selection = _resolveSelection(
        zones,
        preferredZoneId: state.selectedZoneId,
      );
      emit(state.copyWith(
        status: ViewStatus.success,
        zones: zones,
        products: _catalog,
        cities: _cities,
        selectedZoneId: selection.zoneId,
        selectedZonePrices: selection.prices,
        message: null,
      ));
    } catch (err, stack) {
      _log('loadZones error: $err\n$stack');
      final errorMessage = NetworkErrorHelper.isNetworkError(err)
          ? NetworkErrorHelper.getNetworkErrorMessage(err)
          : 'Unable to load delivery zones.';
      emit(state.copyWith(
        status: ViewStatus.failure,
        message: errorMessage,
      ));
    }
  }

  Future<void> selectZone(String zoneId) async {
    _log('selectZone $zoneId');
    try {
      final selection = _resolveSelection(
        state.zones,
        preferredZoneId: zoneId,
      );
      emit(
        state.copyWith(
          status: ViewStatus.success,
          selectedZonePrices: selection.prices,
          selectedZoneId: selection.zoneId,
          message: null,
        ),
      );
    } catch (err, stack) {
      _log('selectZone error: $err\n$stack');
      final errorMessage = NetworkErrorHelper.isNetworkError(err)
          ? NetworkErrorHelper.getNetworkErrorMessage(err)
          : 'Unable to load prices.';
      emit(state.copyWith(
        status: ViewStatus.failure,
        message: errorMessage,
      ));
    }
  }

  Future<void> createZone(DeliveryZone zone) async {
    _log('createZone');
    emit(state.copyWith(status: ViewStatus.loading));
    try {
      final zoneId = await _repository.createZone(_orgId, zone);
      final created = zone.copyWith(id: zoneId, organizationId: _orgId);
      final updatedZones = _sortZones([...state.zones, created]);
      final selection = _resolveSelection(updatedZones, preferredZoneId: zoneId);
      emit(state.copyWith(
        status: ViewStatus.success,
        zones: updatedZones,
        selectedZoneId: selection.zoneId,
        selectedZonePrices: selection.prices,
        message: null,
      ));
    } catch (err, stack) {
      _log('createZone error: $err\n$stack');
      final errorMessage = NetworkErrorHelper.isNetworkError(err)
          ? NetworkErrorHelper.getNetworkErrorMessage(err)
          : 'Unable to create zone.';
      emit(state.copyWith(
        status: ViewStatus.failure,
        message: errorMessage,
      ));
    }
  }

  Future<void> updateZone(DeliveryZone zone) async {
    _log('updateZone ${zone.id}');
    emit(state.copyWith(status: ViewStatus.loading));
    try {
      await _repository.updateZone(_orgId, zone);
      final updatedZones = _sortZones(
        state.zones
            .map((z) => z.id == zone.id ? zone : z)
            .toList(),
      );
      final selection = _resolveSelection(
        updatedZones,
        preferredZoneId: state.selectedZoneId,
      );
      emit(state.copyWith(
        status: ViewStatus.success,
        zones: updatedZones,
        selectedZoneId: selection.zoneId,
        selectedZonePrices: selection.prices,
        message: null,
      ));
    } catch (err, stack) {
      _log('updateZone error: $err\n$stack');
      final errorMessage = NetworkErrorHelper.isNetworkError(err)
          ? NetworkErrorHelper.getNetworkErrorMessage(err)
          : 'Unable to update zone.';
      emit(state.copyWith(
        status: ViewStatus.failure,
        message: errorMessage,
      ));
    }
  }

  Future<void> deleteZone(String zoneId) async {
    _log('deleteZone $zoneId');
    emit(state.copyWith(status: ViewStatus.loading));
    try {
      await _repository.deleteZone(_orgId, zoneId);
      final updatedZones = state.zones.where((z) => z.id != zoneId).toList();
      final selection = _resolveSelection(
        updatedZones,
        preferredZoneId: state.selectedZoneId == zoneId
            ? null
            : state.selectedZoneId,
      );
      emit(state.copyWith(
        status: ViewStatus.success,
        zones: updatedZones,
        selectedZoneId: selection.zoneId,
        selectedZonePrices: selection.prices,
        message: null,
      ));
    } catch (err, stack) {
      _log('deleteZone error: $err\n$stack');
      final errorMessage = NetworkErrorHelper.isNetworkError(err)
          ? NetworkErrorHelper.getNetworkErrorMessage(err)
          : 'Unable to delete zone.';
      emit(state.copyWith(
        status: ViewStatus.failure,
        message: errorMessage,
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
          gstPercent: null, // No GST
          status: ProductStatus.active,
          stock: 0,
        ),
      );
      final enriched = price.copyWith(productName: product.name);
      await _repository.upsertPrice(
        orgId: _orgId,
        zoneId: zoneId,
        price: enriched,
      );
      final updatedZones = _updateZonePrices(
        zones: state.zones,
        zoneId: zoneId,
        updatedPrice: enriched,
      );
      final selection = _resolveSelection(updatedZones, preferredZoneId: zoneId);
      emit(state.copyWith(
        status: ViewStatus.success,
        zones: updatedZones,
        selectedZoneId: selection.zoneId,
        selectedZonePrices: selection.prices,
        message: null,
      ));
    } catch (err, stack) {
      _log('upsertPrice error: $err\n$stack');
      final errorMessage = NetworkErrorHelper.isNetworkError(err)
          ? NetworkErrorHelper.getNetworkErrorMessage(err)
          : 'Unable to update price.';
      emit(state.copyWith(
        status: ViewStatus.failure,
        message: errorMessage,
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
      final updatedZones = _removeZonePrice(
        zones: state.zones,
        zoneId: zoneId,
        productId: productId,
      );
      final selection = _resolveSelection(updatedZones, preferredZoneId: zoneId);
      emit(state.copyWith(
        status: ViewStatus.success,
        zones: updatedZones,
        selectedZoneId: selection.zoneId,
        selectedZonePrices: selection.prices,
        message: null,
      ));
    } catch (err, stack) {
      _log('deletePrice error: $err\n$stack');
      final errorMessage = NetworkErrorHelper.isNetworkError(err)
          ? NetworkErrorHelper.getNetworkErrorMessage(err)
          : 'Unable to delete price.';
      emit(state.copyWith(
        status: ViewStatus.failure,
        message: errorMessage,
      ));
    }
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

  List<DeliveryZone> _sortZones(List<DeliveryZone> zones) {
    final sorted = [...zones];
    sorted.sort((a, b) {
      final cityCompare = a.cityName.compareTo(b.cityName);
      if (cityCompare != 0) return cityCompare;
      return a.region.compareTo(b.region);
    });
    return sorted;
  }

  _SelectionSnapshot _resolveSelection(
    List<DeliveryZone> zones, {
    required String? preferredZoneId,
  }) {
    if (zones.isEmpty) {
      return const _SelectionSnapshot(null, <DeliveryZonePrice>[]);
    }
    final resolvedId = zones.any((z) => z.id == preferredZoneId)
        ? preferredZoneId
        : zones.first.id;
    final zone = zones.firstWhere((z) => z.id == resolvedId);
    final prices = _mergePrices(_catalog, zone.prices.values.toList());
    return _SelectionSnapshot(resolvedId, prices);
  }

  List<DeliveryZone> _updateZonePrices({
    required List<DeliveryZone> zones,
    required String zoneId,
    required DeliveryZonePrice updatedPrice,
  }) {
    return zones.map((zone) {
      if (zone.id != zoneId) return zone;
      final updatedPrices = Map<String, DeliveryZonePrice>.from(zone.prices)
        ..[updatedPrice.productId] = updatedPrice;
      return zone.copyWith(prices: updatedPrices);
    }).toList();
  }

  List<DeliveryZone> _removeZonePrice({
    required List<DeliveryZone> zones,
    required String zoneId,
    required String productId,
  }) {
    return zones.map((zone) {
      if (zone.id != zoneId) return zone;
      final updatedPrices = Map<String, DeliveryZonePrice>.from(zone.prices)
        ..remove(productId);
      return zone.copyWith(prices: updatedPrices);
    }).toList();
  }

  Future<void> createCity(String name) async {
    final normalized = name.trim();
    if (normalized.isEmpty) {
      throw Exception('City name cannot be empty');
    }
    if (_cities.any((c) => c.name.toLowerCase() == normalized.toLowerCase())) {
      throw Exception('City already exists');
    }
    final cityId = await _repository.createCity(
      orgId: _orgId,
      cityName: normalized,
    );
    _cities = [..._cities, DeliveryCity(id: cityId, name: normalized)]
      ..sort((a, b) => a.name.compareTo(b.name));
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
    _cities = _cities
        .map((c) => c.id == city.id ? DeliveryCity(id: c.id, name: normalized) : c)
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    final updatedZones = state.zones
        .map((z) => z.cityId == city.id ? z.copyWith(cityName: normalized) : z)
        .toList();
    final selection = _resolveSelection(
      updatedZones,
      preferredZoneId: state.selectedZoneId,
    );
    emit(state.copyWith(
      cities: _cities,
      zones: updatedZones,
      selectedZoneId: selection.zoneId,
      selectedZonePrices: selection.prices,
    ));
  }

  Future<void> deleteCity(DeliveryCity city) async {
    await _repository.deleteCity(
      orgId: _orgId,
      cityId: city.id,
      cityName: city.name,
    );
    _cities = _cities.where((c) => c.id != city.id).toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    final updatedZones = state.zones.where((z) => z.cityId != city.id).toList();
    final selection = _resolveSelection(updatedZones, preferredZoneId: null);
    emit(state.copyWith(
      cities: _cities,
      zones: updatedZones,
      selectedZoneId: selection.zoneId,
      selectedZonePrices: selection.prices,
    ));
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

class _SelectionSnapshot {
  const _SelectionSnapshot(this.zoneId, this.prices);

  final String? zoneId;
  final List<DeliveryZonePrice> prices;
}

