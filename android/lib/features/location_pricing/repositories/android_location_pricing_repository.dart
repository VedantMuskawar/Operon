import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/location_pricing.dart';

class AndroidLocationPricingRepository {
  final FirebaseFirestore _firestore;

  AndroidLocationPricingRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  Stream<List<LocationPricing>> getLocationPricingStream(String organizationId) {
    print('Getting location pricing stream for orgId: $organizationId');
    try {
      return _firestore
          .collection('ORGANIZATIONS')
          .doc(organizationId)
          .collection('LOCATION_PRICING')
          .snapshots()
          .map((snapshot) {
        print('Location pricing snapshot received: ${snapshot.docs.length} documents');
        try {
          final locations = <LocationPricing>[];
          for (var doc in snapshot.docs) {
            try {
              final location = LocationPricing.fromFirestore(doc);
              locations.add(location);
              print('Parsed location: ${location.locationName}');
            } catch (e) {
              print('Error parsing location pricing document ${doc.id}: $e');
              print('Document data: ${doc.data()}');
            }
          }
          locations.sort((a, b) => a.locationName.compareTo(b.locationName));
          print('Returning ${locations.length} location pricing entries');
          return locations;
        } catch (e) {
          print('Error processing location pricing stream: $e');
          return <LocationPricing>[];
        }
      }).handleError((error) {
        print('Error in location pricing stream: $error');
        return <LocationPricing>[];
      });
    } catch (e) {
      print('Error creating location pricing stream: $e');
      return Stream.value(<LocationPricing>[]);
    }
  }

  Future<String> addLocationPricing(
    String organizationId,
    LocationPricing locationPricing,
    String userId,
  ) async {
    try {
      final locationWithUser = LocationPricing(
        id: locationPricing.id,
        locationId: locationPricing.locationId,
        locationName: locationPricing.locationName,
        city: locationPricing.city,
        unitPrice: locationPricing.unitPrice,
        status: locationPricing.status,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        createdBy: userId,
        updatedBy: userId,
      );

      final docRef = await _firestore
          .collection('ORGANIZATIONS')
          .doc(organizationId)
          .collection('LOCATION_PRICING')
          .add(locationWithUser.toFirestore());

      return docRef.id;
    } catch (e) {
      throw Exception('Failed to add location pricing: $e');
    }
  }

  Future<void> updateLocationPricing(
    String organizationId,
    String locationId,
    LocationPricing locationPricing,
    String userId,
  ) async {
    try {
      final locationWithUser = locationPricing.copyWith(
        updatedAt: DateTime.now(),
        updatedBy: userId,
      );

      await _firestore
          .collection('ORGANIZATIONS')
          .doc(organizationId)
          .collection('LOCATION_PRICING')
          .doc(locationId)
          .update(locationWithUser.toFirestore());
    } catch (e) {
      throw Exception('Failed to update location pricing: $e');
    }
  }

  Future<void> deleteLocationPricing(String organizationId, String locationId) async {
    try {
      await _firestore
          .collection('ORGANIZATIONS')
          .doc(organizationId)
          .collection('LOCATION_PRICING')
          .doc(locationId)
          .delete();
    } catch (e) {
      throw Exception('Failed to delete location pricing: $e');
    }
  }

  /// Get location pricing by city and region
  Future<LocationPricing?> getLocationPricingByCity(
    String organizationId,
    String city,
    String region,
  ) async {
    try {
      final snapshot = await _firestore
          .collection('ORGANIZATIONS')
          .doc(organizationId)
          .collection('LOCATION_PRICING')
          .where('city', isEqualTo: city)
          .where('locationName', isEqualTo: region)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) return null;

      return LocationPricing.fromFirestore(snapshot.docs.first);
    } catch (e) {
      throw Exception('Failed to fetch location pricing by city: $e');
    }
  }

  /// Create or update location pricing (upsert)
  Future<String> createOrUpdateLocationPricing(
    String organizationId,
    String region,
    String city,
    double unitPrice,
    String userId,
  ) async {
    try {
      // Try to find existing location pricing
      final existing = await getLocationPricingByCity(organizationId, city, region);

      if (existing != null) {
        // Update existing
        final updated = existing.copyWith(
          unitPrice: unitPrice,
          updatedAt: DateTime.now(),
          updatedBy: userId,
        );

        await _firestore
            .collection('ORGANIZATIONS')
            .doc(organizationId)
            .collection('LOCATION_PRICING')
            .doc(existing.id!)
            .update(updated.toFirestore());

        return existing.id!;
      } else {
        // Create new
        final locationId = '${region}_${city}'.replaceAll(' ', '_').toLowerCase();
        final newLocation = LocationPricing(
          locationId: locationId,
          locationName: region,
          city: city,
          unitPrice: unitPrice,
          status: 'Active',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          createdBy: userId,
          updatedBy: userId,
        );

        final docRef = await _firestore
            .collection('ORGANIZATIONS')
            .doc(organizationId)
            .collection('LOCATION_PRICING')
            .add(newLocation.toFirestore());

        return docRef.id;
      }
    } catch (e) {
      throw Exception('Failed to create or update location pricing: $e');
    }
  }

  /// Get all location pricing entries for an organization
  Future<List<LocationPricing>> getLocationPricings(String organizationId) async {
    try {
      final snapshot = await _firestore
          .collection('ORGANIZATIONS')
          .doc(organizationId)
          .collection('LOCATION_PRICING')
          .get();

      final locations = snapshot.docs
          .map((doc) => LocationPricing.fromFirestore(doc))
          .toList();

      locations.sort((a, b) => a.locationName.compareTo(b.locationName));
      return locations;
    } catch (e) {
      throw Exception('Failed to fetch location pricings: $e');
    }
  }
}

