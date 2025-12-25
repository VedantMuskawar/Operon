part of 'create_order_cubit.dart';

class CreateOrderState {
  const CreateOrderState({
    this.selectedItems = const [],
    this.availableProducts = const [],
    this.productFixedQuantityOptions = const {},
    this.isLoadingProducts = false,
    // Section 2: Delivery Zones
    this.cities = const [],
    this.zones = const [],
    this.selectedCity,
    this.selectedZoneId,
    this.isLoadingZones = false,
    this.zonePrices = const {},
    this.pendingNewZone,
    this.pendingPriceUpdates,
    this.status = ViewStatus.initial,
    this.message,
  });

  final List<OrderItem> selectedItems;
  final List<OrganizationProduct> availableProducts;
  final Map<String, List<int>> productFixedQuantityOptions;
  final bool isLoadingProducts;
  // Section 2: Delivery Zones
  final List<DeliveryCity> cities;
  final List<DeliveryZone> zones;
  final String? selectedCity;
  final String? selectedZoneId;
  final bool isLoadingZones;
  final Map<String, double> zonePrices; // productId -> unitPrice
  // Pending zone changes (not yet saved)
  final DeliveryZone? pendingNewZone; // New zone to create
  final Map<String, double>? pendingPriceUpdates; // Price updates to apply
  final ViewStatus status;
  final String? message;
  
  bool get hasPendingZoneChanges =>
      pendingNewZone != null ||
      (pendingPriceUpdates != null && pendingPriceUpdates!.isNotEmpty);

  CreateOrderState copyWith({
    List<OrderItem>? selectedItems,
    List<OrganizationProduct>? availableProducts,
    Map<String, List<int>>? productFixedQuantityOptions,
    bool? isLoadingProducts,
    List<DeliveryCity>? cities,
    List<DeliveryZone>? zones,
    String? selectedCity,
    String? selectedZoneId,
    bool? isLoadingZones,
    Map<String, double>? zonePrices,
    DeliveryZone? pendingNewZone,
    Map<String, double>? pendingPriceUpdates,
    ViewStatus? status,
    String? message,
  }) {
    return CreateOrderState(
      selectedItems: selectedItems ?? this.selectedItems,
      availableProducts: availableProducts ?? this.availableProducts,
      productFixedQuantityOptions:
          productFixedQuantityOptions ?? this.productFixedQuantityOptions,
      isLoadingProducts: isLoadingProducts ?? this.isLoadingProducts,
      cities: cities ?? this.cities,
      zones: zones ?? this.zones,
      selectedCity: selectedCity ?? this.selectedCity,
      selectedZoneId: selectedZoneId ?? this.selectedZoneId,
      isLoadingZones: isLoadingZones ?? this.isLoadingZones,
      zonePrices: zonePrices ?? this.zonePrices,
      pendingNewZone: pendingNewZone ?? this.pendingNewZone,
      pendingPriceUpdates: pendingPriceUpdates ?? this.pendingPriceUpdates,
      status: status ?? this.status,
      message: message ?? this.message,
    );
  }
}

