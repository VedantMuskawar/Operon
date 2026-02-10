import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:core_models/core_models.dart';

class VendorsDataSource {
  VendorsDataSource({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _vendorsRef =>
      _firestore.collection('VENDORS');

  Future<List<Vendor>> fetchVendors(String organizationId) async {
    try {
      final snapshot = await _vendorsRef
          .where('organizationId', isEqualTo: organizationId)
          .orderBy('name_lowercase')
          .get();
      final vendors = snapshot.docs
          .map((doc) => Vendor.fromJson(doc.data(), doc.id))
          .toList();
      // Sort in memory as fallback if index is not ready
      vendors
          .sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      return vendors;
    } catch (e) {
      // If index is not ready, fetch without orderBy and sort in memory
      final snapshot = await _vendorsRef
          .where('organizationId', isEqualTo: organizationId)
          .get();
      final vendors = snapshot.docs
          .map((doc) => Vendor.fromJson(doc.data(), doc.id))
          .toList();
      vendors
          .sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      return vendors;
    }
  }

  Future<
      ({
        List<Vendor> vendors,
        DocumentSnapshot<Map<String, dynamic>>? lastDoc,
      })> fetchVendorsPage({
    required String organizationId,
    int limit = 30,
    DocumentSnapshot<Map<String, dynamic>>? startAfterDocument,
  }) async {
    try {
      Query<Map<String, dynamic>> query = _vendorsRef
          .where('organizationId', isEqualTo: organizationId)
          .orderBy('name_lowercase')
          .limit(limit);

      if (startAfterDocument != null) {
        query = query.startAfterDocument(startAfterDocument);
      }

      final snapshot = await query.get();
      final vendors = snapshot.docs
          .map((doc) => Vendor.fromJson(doc.data(), doc.id))
          .toList();
      vendors
          .sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      final lastDoc = snapshot.docs.isNotEmpty ? snapshot.docs.last : null;
      return (vendors: vendors, lastDoc: lastDoc);
    } catch (e) {
      final snapshot = await _vendorsRef
          .where('organizationId', isEqualTo: organizationId)
          .limit(limit)
          .get();
      final vendors = snapshot.docs
          .map((doc) => Vendor.fromJson(doc.data(), doc.id))
          .toList();
      vendors
          .sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      return (vendors: vendors, lastDoc: null);
    }
  }

  Stream<List<Vendor>> watchVendors(String organizationId) {
    return _vendorsRef
        .where('organizationId', isEqualTo: organizationId)
        .snapshots()
        .map((snapshot) {
      final vendors = snapshot.docs
          .map((doc) => Vendor.fromJson(doc.data(), doc.id))
          .toList();
      // Sort in memory
      vendors
          .sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      return vendors;
    });
  }

  Future<List<Vendor>> searchVendors(
    String organizationId,
    String query,
  ) async {
    final normalizedQuery = query.trim().toLowerCase();
    final digitsQuery = query.replaceAll(RegExp(r'[^0-9+]'), '');

    // Search by name (case-insensitive)
    final nameQuery = _vendorsRef
        .where('organizationId', isEqualTo: organizationId)
        .where('name_lowercase', isGreaterThanOrEqualTo: normalizedQuery)
        .where('name_lowercase', isLessThanOrEqualTo: '$normalizedQuery\uf8ff')
        .limit(20);

    final nameResults = await nameQuery.get();
    final nameVendors = nameResults.docs
        .map((doc) => Vendor.fromJson(doc.data(), doc.id))
        .toList();

    // Search by phone if query contains digits
    List<Vendor> phoneVendors = [];
    if (digitsQuery.isNotEmpty) {
      final phoneQuery = _vendorsRef
          .where('organizationId', isEqualTo: organizationId)
          .where('phoneIndex', arrayContains: digitsQuery)
          .limit(20);

      final phoneResults = await phoneQuery.get();
      phoneVendors = phoneResults.docs
          .map((doc) => Vendor.fromJson(doc.data(), doc.id))
          .toList();
    }

    // Search by GST number if query looks like GST
    List<Vendor> gstVendors = [];
    if (normalizedQuery.length >= 10) {
      final gstQuery = _vendorsRef
          .where('organizationId', isEqualTo: organizationId)
          .where('gstNumber', isEqualTo: normalizedQuery.toUpperCase())
          .limit(10);

      final gstResults = await gstQuery.get();
      gstVendors = gstResults.docs
          .map((doc) => Vendor.fromJson(doc.data(), doc.id))
          .toList();
    }

    // Combine and deduplicate
    final allVendors = <String, Vendor>{};
    for (final vendor in [...nameVendors, ...phoneVendors, ...gstVendors]) {
      allVendors[vendor.id] = vendor;
    }

    return allVendors.values.toList();
  }

  Future<List<Vendor>> filterVendorsByType(
    String organizationId,
    VendorType? vendorType,
  ) async {
    if (vendorType == null) {
      return fetchVendors(organizationId);
    }

    try {
      final snapshot = await _vendorsRef
          .where('organizationId', isEqualTo: organizationId)
          .where('vendorType', isEqualTo: vendorType.name)
          .orderBy('name_lowercase')
          .get();
      final vendors = snapshot.docs
          .map((doc) => Vendor.fromJson(doc.data(), doc.id))
          .toList();
      vendors
          .sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      return vendors;
    } catch (e) {
      // If index is not ready, fetch without orderBy and sort in memory
      final snapshot = await _vendorsRef
          .where('organizationId', isEqualTo: organizationId)
          .where('vendorType', isEqualTo: vendorType.name)
          .get();
      final vendors = snapshot.docs
          .map((doc) => Vendor.fromJson(doc.data(), doc.id))
          .toList();
      vendors
          .sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      return vendors;
    }
  }

  Future<List<Vendor>> filterVendorsByStatus(
    String organizationId,
    VendorStatus? status,
  ) async {
    if (status == null) {
      return fetchVendors(organizationId);
    }

    try {
      final snapshot = await _vendorsRef
          .where('organizationId', isEqualTo: organizationId)
          .where('status', isEqualTo: status.name)
          .orderBy('name_lowercase')
          .get();
      final vendors = snapshot.docs
          .map((doc) => Vendor.fromJson(doc.data(), doc.id))
          .toList();
      vendors
          .sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      return vendors;
    } catch (e) {
      // If index is not ready, fetch without orderBy and sort in memory
      final snapshot = await _vendorsRef
          .where('organizationId', isEqualTo: organizationId)
          .where('status', isEqualTo: status.name)
          .get();
      final vendors = snapshot.docs
          .map((doc) => Vendor.fromJson(doc.data(), doc.id))
          .toList();
      vendors
          .sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      return vendors;
    }
  }

  Future<Vendor?> getVendor(String vendorId) async {
    final doc = await _vendorsRef.doc(vendorId).get();
    if (!doc.exists) return null;
    return Vendor.fromJson(doc.data()!, doc.id);
  }

  Future<String> createVendor(Vendor vendor) async {
    // Always let Firestore generate a new document ID for new vendors
    // This ensures consistency and allows Firebase triggers to work correctly
    final docRef = _vendorsRef.doc();

    final vendorData = vendor.toJson();
    vendorData['vendorId'] = docRef.id;
    // Ensure vendorCode is explicitly set to empty string so Firebase trigger can generate it
    vendorData['vendorCode'] = '';
    vendorData['createdAt'] = FieldValue.serverTimestamp();
    vendorData['updatedAt'] = FieldValue.serverTimestamp();

    await docRef.set(vendorData);
    return docRef.id;
  }

  Future<void> updateVendor(Vendor vendor) async {
    final updateData = vendor.toJson();
    // Remove fields that are auto-managed by Firebase functions or shouldn't be updated
    updateData.remove('vendorId'); // Don't update ID
    updateData.remove(
        'vendorCode'); // Don't update code (auto-generated, managed by trigger)
    updateData.remove(
        'openingBalance'); // Don't update opening balance (managed by trigger)
    updateData.remove('createdAt'); // Don't update createdAt
    updateData.remove(
        'updatedAt'); // Don't update updatedAt - let Firebase function handle it to prevent infinite loops
    updateData.remove('name_lowercase'); // Auto-managed by Firebase function
    updateData.remove('phoneIndex'); // Auto-managed by Firebase function

    // Only update if there are actual changes
    if (updateData.isEmpty) {
      return; // Nothing to update
    }

    await _vendorsRef.doc(vendor.id).update(updateData);
  }

  Future<void> deleteVendor(String vendorId) {
    return _vendorsRef.doc(vendorId).delete();
  }
}
