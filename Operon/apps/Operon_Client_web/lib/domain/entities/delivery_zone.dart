import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dash_web/domain/entities/delivery_zone_price.dart';

class DeliveryZone {
  const DeliveryZone({
    required this.id,
    required this.organizationId,
    required this.cityId,
    required this.cityName,
    required this.region,
    required this.prices,
    this.isActive = true,
  });

  final String id;
  final String organizationId;
  final String cityId;
  final String cityName;
  final String region;
  final Map<String, DeliveryZonePrice> prices;
  final bool isActive;

  factory DeliveryZone.fromMap(Map<String, dynamic> map, String id) {
    final pricesMap = map['prices'] as Map<String, dynamic>? ?? {};
    final prices = pricesMap.map(
      (key, value) => MapEntry(
        key,
        DeliveryZonePrice.fromMap({
          ...value as Map<String, dynamic>,
          'product_id': key,
        }),
      ),
    );

    return DeliveryZone(
      id: id,
      organizationId: map['organization_id'] as String? ?? '',
      cityId: map['city_id'] as String? ?? '',
      cityName: map['city_name'] as String? ?? '',
      region: map['region'] as String? ?? '',
      prices: prices,
      isActive: map['is_active'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'city_id': cityId,
      'city_name': cityName,
      'region': region,
      'is_active': isActive,
      'prices': prices.map(
        (key, value) => MapEntry(key, {
          'unit_price': value.unitPrice,
          'deliverable': value.deliverable,
          'updated_at': FieldValue.serverTimestamp(),
        }),
      ),
    };
  }

  DeliveryZone copyWith({
    String? id,
    String? organizationId,
    String? cityId,
    String? cityName,
    String? region,
    Map<String, DeliveryZonePrice>? prices,
    bool? isActive,
  }) {
    return DeliveryZone(
      id: id ?? this.id,
      organizationId: organizationId ?? this.organizationId,
      cityId: cityId ?? this.cityId,
      cityName: cityName ?? this.cityName,
      region: region ?? this.region,
      prices: prices ?? this.prices,
      isActive: isActive ?? this.isActive,
    );
  }

  // Helper getter for backward compatibility
  String get city => cityName;
}

