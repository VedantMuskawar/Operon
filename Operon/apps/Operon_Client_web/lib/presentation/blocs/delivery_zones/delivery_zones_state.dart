part of 'delivery_zones_cubit.dart';

class DeliveryZonesState extends BaseState {
  const DeliveryZonesState({
    super.status = ViewStatus.initial,
    this.zones = const [],
    this.selectedZonePrices = const [],
    this.products = const [],
    this.cities = const [],
    this.message,
    this.selectedZoneId,
  }) : super(message: message);

  final List<DeliveryZone> zones;
  final List<DeliveryZonePrice> selectedZonePrices;
  final List<OrganizationProduct> products;
  final List<DeliveryCity> cities;
  final String? selectedZoneId;
  @override
  final String? message;

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

