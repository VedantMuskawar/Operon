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
}

