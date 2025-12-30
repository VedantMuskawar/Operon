import 'package:cloud_firestore/cloud_firestore.dart' hide Transaction;
import 'package:core_bloc/core_bloc.dart';
import 'package:core_models/core_models.dart';
import 'package:dash_mobile/data/repositories/delivery_zones_repository.dart';
import 'package:dash_mobile/data/repositories/products_repository.dart';
import 'package:dash_mobile/domain/entities/order_item.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

part 'create_order_event.dart';
part 'create_order_state.dart';

class CreateOrderCubit extends Cubit<CreateOrderState> {
  CreateOrderCubit({
    required ProductsRepository productsRepository,
    required DeliveryZonesRepository deliveryZonesRepository,
    required String organizationId,
  })  : _productsRepository = productsRepository,
        _deliveryZonesRepository = deliveryZonesRepository,
        _organizationId = organizationId,
        super(const CreateOrderState()) {
    loadProducts();
    loadZones();
  }

  final ProductsRepository _productsRepository;
  final DeliveryZonesRepository _deliveryZonesRepository;
  final String _organizationId;

  // Default fixed quantity options (fallback if product doesn't specify)
  static const List<int> _defaultFixedQuantityOptions = [
    1000,
    1500,
    2000,
    2500,
    3000,
    4000,
  ];

  Future<void> loadProducts() async {
    emit(state.copyWith(isLoadingProducts: true));
    try {
      final products = await _productsRepository.fetchProducts(_organizationId);
      
      // Build map of product fixed quantity options
      final productFixedQuantityOptions = <String, List<int>>{};
      for (final product in products) {
        if (product.fixedQuantityPerTripOptions != null &&
            product.fixedQuantityPerTripOptions!.isNotEmpty) {
          productFixedQuantityOptions[product.id] =
              product.fixedQuantityPerTripOptions!;
        }
      }

      emit(
        state.copyWith(
          availableProducts: products.where((p) => p.status == ProductStatus.active).toList(),
          productFixedQuantityOptions: productFixedQuantityOptions,
          isLoadingProducts: false,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          isLoadingProducts: false,
          status: ViewStatus.failure,
          message: 'Failed to load products: ${e.toString()}',
        ),
      );
    }
  }

  List<int> getFixedQuantityOptions(String productId) {
    return state.productFixedQuantityOptions[productId] ??
        _defaultFixedQuantityOptions;
  }

  void addProductItem({
    required OrganizationProduct product,
    required int estimatedTrips,
    required int fixedQuantityPerTrip,
  }) {
    // Use zone price if available, otherwise use product base price
    final unitPrice = state.zonePrices[product.id] ?? product.unitPrice;
    
    // Check if product already exists in selected items
    final existingIndex = state.selectedItems
        .indexWhere((item) => item.productId == product.id);
    
    if (existingIndex >= 0) {
      // Update existing item
      final existingItem = state.selectedItems[existingIndex];
      final updatedItems = List<OrderItem>.from(state.selectedItems);
      updatedItems[existingIndex] = existingItem.copyWith(
        estimatedTrips: estimatedTrips,
        fixedQuantityPerTrip: fixedQuantityPerTrip,
        unitPrice: unitPrice,
      );
      emit(state.copyWith(selectedItems: updatedItems));
    } else {
      // Add new item
      final newItem = OrderItem(
        productId: product.id,
        productName: product.name,
        estimatedTrips: estimatedTrips,
        fixedQuantityPerTrip: fixedQuantityPerTrip,
        unitPrice: unitPrice,
        gstPercent: product.gstPercent,
      );
      emit(
        state.copyWith(
          selectedItems: [...state.selectedItems, newItem],
        ),
      );
    }
  }

  void removeProductItem(String productId) {
    emit(
      state.copyWith(
        selectedItems: state.selectedItems
            .where((item) => item.productId != productId)
            .toList(),
      ),
    );
  }

  void incrementItemTrips(String productId) {
    final index = state.selectedItems.indexWhere(
      (item) => item.productId == productId,
    );
    if (index >= 0) {
      final item = state.selectedItems[index];
      final updatedItems = List<OrderItem>.from(state.selectedItems);
      updatedItems[index] = item.copyWith(
        estimatedTrips: item.estimatedTrips + 1,
      );
      emit(state.copyWith(selectedItems: updatedItems));
    }
  }

  void decrementItemTrips(String productId) {
    final index = state.selectedItems.indexWhere(
      (item) => item.productId == productId,
    );
    if (index >= 0) {
      final item = state.selectedItems[index];
      if (item.estimatedTrips > 1) {
        final updatedItems = List<OrderItem>.from(state.selectedItems);
        updatedItems[index] = item.copyWith(
          estimatedTrips: item.estimatedTrips - 1,
        );
        emit(state.copyWith(selectedItems: updatedItems));
      }
    }
  }

  void updateItemTrips(String productId, int estimatedTrips) {
    if (estimatedTrips < 1) return;
    final index = state.selectedItems.indexWhere(
      (item) => item.productId == productId,
    );
    if (index >= 0) {
      final item = state.selectedItems[index];
      final updatedItems = List<OrderItem>.from(state.selectedItems);
      updatedItems[index] = item.copyWith(estimatedTrips: estimatedTrips);
      emit(state.copyWith(selectedItems: updatedItems));
    }
  }

  void updateItemFixedQuantity(String productId, int fixedQuantityPerTrip) {
    final index = state.selectedItems.indexWhere(
      (item) => item.productId == productId,
    );
    if (index >= 0) {
      final item = state.selectedItems[index];
      final updatedItems = List<OrderItem>.from(state.selectedItems);
      updatedItems[index] = item.copyWith(
        fixedQuantityPerTrip: fixedQuantityPerTrip,
      );
      emit(state.copyWith(selectedItems: updatedItems));
    }
  }

  // Section 2: Delivery Zones
  Future<void> loadZones() async {
    emit(state.copyWith(isLoadingZones: true));
    try {
      final zones = await _deliveryZonesRepository.fetchZones(_organizationId);
      final fetchedCities = await _deliveryZonesRepository.fetchCities(_organizationId);
      
      final cities = fetchedCities..sort((a, b) => a.name.compareTo(b.name));

      emit(
        state.copyWith(
          zones: zones,
          cities: cities,
          isLoadingZones: false,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          isLoadingZones: false,
          status: ViewStatus.failure,
          message: 'Failed to load delivery zones: ${e.toString()}',
        ),
      );
    }
  }

  void selectCity(String cityName) {
    if (state.selectedCity == cityName) return;
    
    // Find first zone in this city
    final zonesInCity = state.zones.where((z) => z.cityName == cityName).toList();
    final firstZone = zonesInCity.isNotEmpty ? zonesInCity.first : null;
    
    emit(
      state.copyWith(
        selectedCity: cityName,
        selectedZoneId: firstZone?.id,
      ),
    );
  }

  Future<void> selectZone(String zoneId) async {
    final zone = state.zones.firstWhere(
      (z) => z.id == zoneId,
      orElse: () => state.zones.first,
    );
    
    // Get prices from zone (embedded in zone document)
    final priceMap = <String, double>{};
    for (final entry in zone.prices.entries) {
      priceMap[entry.key] = entry.value.unitPrice;
    }
    
    // Update order items with zone prices
    final updatedItems = state.selectedItems.map((item) {
      final zonePrice = priceMap[item.productId];
      if (zonePrice != null) {
        return item.copyWith(unitPrice: zonePrice);
      }
      return item;
    }).toList();
    
    emit(
      state.copyWith(
        selectedCity: zone.cityName,
        selectedZoneId: zoneId,
        zonePrices: priceMap,
        selectedItems: updatedItems,
      ),
    );
  }

  List<DeliveryZone> getZonesForCity(String? cityName) {
    if (cityName == null) return [];
    return state.zones.where((z) => z.cityName == cityName).toList();
  }

  // Update zone prices and refresh order items
  void updateZonePrices(Map<String, double> zonePrices) {
    final updatedItems = state.selectedItems.map((item) {
      final zonePrice = zonePrices[item.productId];
      if (zonePrice != null) {
        return item.copyWith(unitPrice: zonePrice);
      }
      return item;
    }).toList();
    
    emit(
      state.copyWith(
        zonePrices: zonePrices,
        selectedItems: updatedItems,
      ),
    );
  }

  // Create new region/zone (stored as pending, will be saved during order creation)
  void addPendingRegion({
    required String city,
    required String region,
    required double roundtripKm,
  }) {
    // Find city by name to get cityId
    final cityObj = state.cities.firstWhere(
      (c) => c.name == city,
      orElse: () => throw Exception('City not found'),
    );
    
    final newZone = DeliveryZone(
      id: 'pending-${DateTime.now().millisecondsSinceEpoch}', // Temporary ID
      organizationId: _organizationId,
      cityId: cityObj.id,
      cityName: cityObj.name,
      region: region,
      prices: {},
      isActive: true,
      roundtripKm: roundtripKm,
    );
    
    // Auto-select the pending zone
    emit(
      state.copyWith(
        pendingNewZone: newZone,
        selectedCity: city,
        selectedZoneId: newZone.id, // Use temporary ID for selection
      ),
    );
  }

  // Update zone price (stored as pending, will be saved during order creation)
  void addPendingPriceUpdate({
    required String productId,
    required double unitPrice,
  }) {
    final updatedPrices = Map<String, double>.from(state.pendingPriceUpdates ?? {});
    updatedPrices[productId] = unitPrice;
    
    // Also update zonePrices for immediate UI feedback
    final updatedZonePrices = Map<String, double>.from(state.zonePrices);
    updatedZonePrices[productId] = unitPrice;
    
    // Update order items with new price
    final updatedItems = state.selectedItems.map((item) {
      if (item.productId == productId) {
        return item.copyWith(unitPrice: unitPrice);
      }
      return item;
    }).toList();
    
    emit(
      state.copyWith(
        pendingPriceUpdates: updatedPrices,
        zonePrices: updatedZonePrices,
        selectedItems: updatedItems,
      ),
    );
  }
  
  // Clear pending changes (after successful order creation)
  void clearPendingZoneChanges() {
    emit(
      state.copyWith(
        pendingNewZone: null,
        pendingPriceUpdates: null,
      ),
    );
  }

  // Get zone prices for a zone
  Future<List<DeliveryZonePrice>> getZonePrices(String zoneId) async {
    // Prices are now embedded in zone, get from state
    final zone = state.zones.firstWhere(
      (z) => z.id == zoneId,
      orElse: () => throw Exception('Zone not found'),
    );
    return zone.prices.values.toList();
  }

  // Create order with atomic zone updates
  Future<String> createOrder({
    required String clientId,
    required String clientName,
    required String clientPhone,
    required String priority,
    required bool includeGstInTotal,
    String? advancePaymentAccountId,
    double? advanceAmount,
    required String createdBy,
  }) async {
    emit(state.copyWith(status: ViewStatus.loading));

    try {
      // Validate required fields
      if (state.selectedItems.isEmpty) {
        throw Exception('Please add at least one product');
      }
      if (state.selectedCity == null) {
        throw Exception('Please select delivery city and region');
      }

      final firestore = FirebaseFirestore.instance;
      final batch = firestore.batch();
      String finalZoneId;
      String finalCity;
      String finalRegion;

      // Step 1: Handle zone updates if any
      if (state.hasPendingZoneChanges) {
        if (state.pendingNewZone != null) {
          // Create new zone (nested collection)
          final zonesRef = firestore
              .collection('ORGANIZATIONS')
              .doc(_organizationId)
              .collection('DELIVERY_ZONES');
          final zoneRef = zonesRef.doc();
          finalZoneId = zoneRef.id;
          finalCity = state.pendingNewZone!.cityName;
          finalRegion = state.pendingNewZone!.region;

          // Build prices map
          final pricesMap = <String, Map<String, dynamic>>{};
          if (state.pendingPriceUpdates != null) {
            for (final entry in state.pendingPriceUpdates!.entries) {
              pricesMap[entry.key] = {
                'unit_price': entry.value,
                'deliverable': true,
                'updated_at': FieldValue.serverTimestamp(),
              };
            }
          }

          batch.set(zoneRef, {
            'organization_id': _organizationId,
            'city_id': state.pendingNewZone!.cityId,
            'city_name': state.pendingNewZone!.cityName,
            'region': state.pendingNewZone!.region,
            'is_active': true,
            if (state.pendingNewZone!.roundtripKm != null)
              'roundtrip_km': state.pendingNewZone!.roundtripKm,
            'prices': pricesMap,
            'created_at': FieldValue.serverTimestamp(),
            'updated_at': FieldValue.serverTimestamp(),
          });
        } else if (state.pendingPriceUpdates != null && state.selectedZoneId != null) {
          // Update existing zone prices
          finalZoneId = state.selectedZoneId!;
          final existingZone = state.zones.firstWhere(
            (z) => z.id == finalZoneId,
          );
          finalCity = existingZone.cityName;
          finalRegion = existingZone.region;

          final zoneRef = firestore
              .collection('ORGANIZATIONS')
              .doc(_organizationId)
              .collection('DELIVERY_ZONES')
              .doc(finalZoneId);

          // Update prices in zone document
          for (final entry in state.pendingPriceUpdates!.entries) {
            batch.update(zoneRef, {
              'prices.${entry.key}.unit_price': entry.value,
              'prices.${entry.key}.deliverable': true,
              'prices.${entry.key}.updated_at': FieldValue.serverTimestamp(),
              'updated_at': FieldValue.serverTimestamp(),
            });
          }
        } else {
          throw Exception('Invalid pending zone changes state');
        }
      } else {
        // No pending changes, use existing zone
        if (state.selectedZoneId == null) {
          throw Exception('Please select delivery city and region');
        }
        finalZoneId = state.selectedZoneId!;
        final existingZone = state.zones.firstWhere(
          (z) => z.id == finalZoneId,
        );
        finalCity = existingZone.cityName;
        finalRegion = existingZone.region;
      }

      // Step 2: Calculate pricing
      double totalSubtotal = 0;
      double gstSum = 0;
      for (final item in state.selectedItems) {
        totalSubtotal += item.subtotal;
        if (item.hasGst) {
          gstSum += item.gstAmount;
        }
      }
      // Only include GST in stored total when includeGstInTotal is true
      final totalGst = includeGstInTotal ? gstSum : 0;
      final totalAmount = totalSubtotal + totalGst;
      final remainingAmount = advanceAmount != null && advanceAmount > 0
          ? totalAmount - advanceAmount
          : null;

      // Step 3: Create order document (standalone collection)
      final ordersRef = firestore.collection('PENDING_ORDERS');
      final orderRef = ordersRef.doc();

      final normalizedPhone = _normalizePhone(clientPhone);
      batch.set(orderRef, {
        'orderId': orderRef.id,
        'orderNumber': '', // Will be generated by Cloud Function
        'clientId': clientId,
        'clientName': clientName,
        'name_lc': clientName.trim().toLowerCase(),
        'clientPhone': normalizedPhone.isNotEmpty ? normalizedPhone : clientPhone,
        'items': state.selectedItems.map((item) => item.toJson()).toList(),
        'deliveryZone': {
          'zone_id': finalZoneId,
          'city_name': finalCity,
          'region': finalRegion,
        },
        'pricing': {
          'subtotal': totalSubtotal,
          'totalGst': totalGst,
          'totalAmount': totalAmount,
          'currency': 'INR',
        },
        'includeGstInTotal': includeGstInTotal,
        'priority': priority,
        'status': 'pending',
        'scheduledTrips': <dynamic>[],
        'totalScheduledTrips': 0,
        'scheduledQuantity': null,
        'unscheduledQuantity': null,
        'organizationId': _organizationId,
        'createdBy': createdBy,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        if (advanceAmount != null && advanceAmount > 0) 'advanceAmount': advanceAmount,
        if (advancePaymentAccountId != null) 'advancePaymentAccountId': advancePaymentAccountId,
        if (remainingAmount != null) 'remainingAmount': remainingAmount,
      });

      // Step 4: Commit batch (atomic operation)
      await batch.commit();

      // Step 5: Advance transaction creation is now handled by Cloud Function
      // (onPendingOrderCreated) to ensure atomicity with order creation

      // Clear pending changes after successful commit
      clearPendingZoneChanges();

      emit(state.copyWith(status: ViewStatus.success));
      return orderRef.id;
    } catch (e) {
      emit(
        state.copyWith(
          status: ViewStatus.failure,
          message: 'Failed to create order: ${e.toString()}',
        ),
      );
      rethrow;
    }
  }

  String _normalizePhone(String input) {
    return input.replaceAll(RegExp(r'[^0-9+]'), '');
  }
}

