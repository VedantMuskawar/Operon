import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/location_pricing.dart';

class LocationPricingRepository {
  final FirebaseFirestore _firestore;

  LocationPricingRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  // Get location pricing stream for a specific organization
  Stream<List<LocationPricing>> getLocationPricingStream(String organizationId) {
    return _firestore
        .collection('ORGANIZATIONS')
        .doc(organizationId)
        .collection('LOCATION_PRICING')
        .snapshots()
        .map((snapshot) {
      final locations = snapshot.docs
          .map((doc) => LocationPricing.fromFirestore(doc))
          .toList();
      // Sort locations by locationName for consistent ordering
      locations.sort((a, b) => a.locationName.compareTo(b.locationName));
      return locations;
    });
  }

  // Get location pricing once (non-stream)
  Future<List<LocationPricing>> getLocationPricing(String organizationId) async {
    try {
      final snapshot = await _firestore
          .collection('ORGANIZATIONS')
          .doc(organizationId)
          .collection('LOCATION_PRICING')
          .get();

      final locations = snapshot.docs
          .map((doc) => LocationPricing.fromFirestore(doc))
          .toList();
      // Sort locations by locationName for consistent ordering
      locations.sort((a, b) => a.locationName.compareTo(b.locationName));
      return locations;
    } catch (e) {
      throw Exception('Failed to fetch location pricing: $e');
    }
  }

  // Add a new location pricing
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

  // Update an existing location pricing
  Future<void> updateLocationPricing(
    String organizationId,
    String locationPricingId,
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
          .doc(locationPricingId)
          .update(locationWithUser.toFirestore());
    } catch (e) {
      throw Exception('Failed to update location pricing: $e');
    }
  }

  // Delete a location pricing
  Future<void> deleteLocationPricing(String organizationId, String locationPricingId) async {
    try {
      await _firestore
          .collection('ORGANIZATIONS')
          .doc(organizationId)
          .collection('LOCATION_PRICING')
          .doc(locationPricingId)
          .delete();
    } catch (e) {
      throw Exception('Failed to delete location pricing: $e');
    }
  }

  // Search location pricing by query
  Stream<List<LocationPricing>> searchLocationPricing(
    String organizationId,
    String query,
  ) {
    final lowerQuery = query.toLowerCase();

    return _firestore
        .collection('ORGANIZATIONS')
        .doc(organizationId)
        .collection('LOCATION_PRICING')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => LocationPricing.fromFirestore(doc))
          .where((location) {
        return location.locationId.toLowerCase().contains(lowerQuery) ||
            location.locationName.toLowerCase().contains(lowerQuery) ||
            location.city.toLowerCase().contains(lowerQuery);
      }).toList();
    });
  }

  // Get a single location pricing by ID
  Future<LocationPricing?> getLocationPricingById(
    String organizationId,
    String locationPricingId,
  ) async {
    try {
      final doc = await _firestore
          .collection('ORGANIZATIONS')
          .doc(organizationId)
          .collection('LOCATION_PRICING')
          .doc(locationPricingId)
          .get();

      if (!doc.exists) {
        return null;
      }

      return LocationPricing.fromFirestore(doc);
    } catch (e) {
      throw Exception('Failed to fetch location pricing: $e');
    }
  }

  // Check if location ID already exists for an organization
  Future<bool> locationIdExists(String organizationId, String locationId) async {
    try {
      final snapshot = await _firestore
          .collection('ORGANIZATIONS')
          .doc(organizationId)
          .collection('LOCATION_PRICING')
          .where('locationId', isEqualTo: locationId)
          .limit(1)
          .get();

      return snapshot.docs.isNotEmpty;
    } catch (e) {
      throw Exception('Failed to check location ID: $e');
    }
  }

  // Get location pricing by custom locationId (not Firestore doc ID)
  Future<LocationPricing?> getLocationPricingByCustomId(
    String organizationId,
    String customLocationId,
  ) async {
    try {
      final snapshot = await _firestore
          .collection('ORGANIZATIONS')
          .doc(organizationId)
          .collection('LOCATION_PRICING')
          .where('locationId', isEqualTo: customLocationId)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) {
        return null;
      }

      return LocationPricing.fromFirestore(snapshot.docs.first);
    } catch (e) {
      throw Exception('Failed to fetch location pricing by custom ID: $e');
    }
  }
}

