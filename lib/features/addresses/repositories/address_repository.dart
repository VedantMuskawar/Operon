import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/address.dart';

class AddressRepository {
  final FirebaseFirestore _firestore;

  AddressRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  // Get addresses stream for a specific organization
  Stream<List<Address>> getAddressesStream(String organizationId) {
    return _firestore
        .collection('ORGANIZATIONS')
        .doc(organizationId)
        .collection('ADDRESSES')
        .snapshots()
        .map((snapshot) {
      final addresses = snapshot.docs
          .map((doc) => Address.fromFirestore(doc))
          .toList();
      // Sort addresses by addressName for consistent ordering
      addresses.sort((a, b) => a.addressName.compareTo(b.addressName));
      return addresses;
    });
  }

  // Get addresses once (non-stream)
  Future<List<Address>> getAddresses(String organizationId) async {
    try {
      final snapshot = await _firestore
          .collection('ORGANIZATIONS')
          .doc(organizationId)
          .collection('ADDRESSES')
          .get();

      final addresses = snapshot.docs
          .map((doc) => Address.fromFirestore(doc))
          .toList();
      // Sort addresses by addressName for consistent ordering
      addresses.sort((a, b) => a.addressName.compareTo(b.addressName));
      return addresses;
    } catch (e) {
      throw Exception('Failed to fetch addresses: $e');
    }
  }

  // Add a new address
  Future<String> addAddress(
    String organizationId,
    Address address,
    String userId,
  ) async {
    try {
      final addressWithUser = Address(
        id: address.id,
        addressId: address.addressId,
        addressName: address.addressName,
        address: address.address,
        region: address.region,
        city: address.city,
        state: address.state,
        pincode: address.pincode,
        status: address.status,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        createdBy: userId,
        updatedBy: userId,
      );

      final docRef = await _firestore
          .collection('ORGANIZATIONS')
          .doc(organizationId)
          .collection('ADDRESSES')
          .add(addressWithUser.toFirestore());

      return docRef.id;
    } catch (e) {
      throw Exception('Failed to add address: $e');
    }
  }

  // Update an existing address
  Future<void> updateAddress(
    String organizationId,
    String addressId,
    Address address,
    String userId,
  ) async {
    try {
      final addressWithUser = address.copyWith(
        updatedAt: DateTime.now(),
        updatedBy: userId,
      );

      await _firestore
          .collection('ORGANIZATIONS')
          .doc(organizationId)
          .collection('ADDRESSES')
          .doc(addressId)
          .update(addressWithUser.toFirestore());
    } catch (e) {
      throw Exception('Failed to update address: $e');
    }
  }

  // Delete an address
  Future<void> deleteAddress(String organizationId, String addressId) async {
    try {
      await _firestore
          .collection('ORGANIZATIONS')
          .doc(organizationId)
          .collection('ADDRESSES')
          .doc(addressId)
          .delete();
    } catch (e) {
      throw Exception('Failed to delete address: $e');
    }
  }

  // Search addresses by query
  Stream<List<Address>> searchAddresses(
    String organizationId,
    String query,
  ) {
    final lowerQuery = query.toLowerCase();

    return _firestore
        .collection('ORGANIZATIONS')
        .doc(organizationId)
        .collection('ADDRESSES')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => Address.fromFirestore(doc))
          .where((address) {
        return address.addressId.toLowerCase().contains(lowerQuery) ||
            address.addressName.toLowerCase().contains(lowerQuery) ||
            address.address.toLowerCase().contains(lowerQuery) ||
            address.region.toLowerCase().contains(lowerQuery) ||
            (address.city?.toLowerCase().contains(lowerQuery) ?? false) ||
            (address.state?.toLowerCase().contains(lowerQuery) ?? false) ||
            (address.pincode?.toLowerCase().contains(lowerQuery) ?? false);
      }).toList();
    });
  }

  // Get a single address by ID
  Future<Address?> getAddressById(
    String organizationId,
    String addressId,
  ) async {
    try {
      final doc = await _firestore
          .collection('ORGANIZATIONS')
          .doc(organizationId)
          .collection('ADDRESSES')
          .doc(addressId)
          .get();

      if (!doc.exists) {
        return null;
      }

      return Address.fromFirestore(doc);
    } catch (e) {
      throw Exception('Failed to fetch address: $e');
    }
  }

  // Check if address ID already exists for an organization
  Future<bool> addressIdExists(String organizationId, String addressId) async {
    try {
      final snapshot = await _firestore
          .collection('ORGANIZATIONS')
          .doc(organizationId)
          .collection('ADDRESSES')
          .where('addressId', isEqualTo: addressId)
          .limit(1)
          .get();

      return snapshot.docs.isNotEmpty;
    } catch (e) {
      throw Exception('Failed to check address ID: $e');
    }
  }

  // Get address by custom addressId (not Firestore doc ID)
  Future<Address?> getAddressByCustomId(
    String organizationId,
    String customAddressId,
  ) async {
    try {
      final snapshot = await _firestore
          .collection('ORGANIZATIONS')
          .doc(organizationId)
          .collection('ADDRESSES')
          .where('addressId', isEqualTo: customAddressId)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) {
        return null;
      }

      return Address.fromFirestore(snapshot.docs.first);
    } catch (e) {
      throw Exception('Failed to fetch address by custom ID: $e');
    }
  }
}

