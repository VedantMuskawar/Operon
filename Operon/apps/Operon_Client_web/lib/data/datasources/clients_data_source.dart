import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dash_web/domain/entities/client.dart';

class ClientsDataSource {
  ClientsDataSource({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _clientsRef =>
      _firestore.collection('CLIENTS');

  Future<List<Client>> fetchClients({int limit = 100}) async {
    final snapshot = await _clientsRef
        .orderBy('name_lc')
        .limit(limit)
        .get();
    return snapshot.docs
        .map((doc) => Client.fromJson(doc.data(), doc.id))
        .toList();
  }

  Future<List<Client>> fetchRecentClients({int limit = 10}) async {
    final snapshot = await _clientsRef
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .get();
    return snapshot.docs
        .map((doc) => Client.fromJson(doc.data(), doc.id))
        .toList();
  }

  Future<List<Client>> searchClientsByName(String query, {int limit = 20}) async {
    if (query.trim().isEmpty) return fetchClients(limit: limit);
    final normalized = query.trim().toLowerCase();
    final snapshot = await _clientsRef
        .orderBy('name_lc')
        .startAt([normalized])
        .endAt(['$normalized\uf8ff'])
        .limit(limit)
        .get();
    return snapshot.docs
        .map((doc) => Client.fromJson(doc.data(), doc.id))
        .toList();
  }

  Future<List<Client>> searchClientsByPhone(String digits, {int limit = 10}) async {
    final normalized = _normalizePhone(digits);
    final snapshot = await _clientsRef
        .where('phoneIndex', arrayContains: normalized)
        .limit(limit)
        .get();
    return snapshot.docs
        .map((doc) => Client.fromJson(doc.data(), doc.id))
        .toList();
  }

  Future<void> createClient({
    required String name,
    required String primaryPhone,
    required List<String> phones,
    required List<String> tags,
    String? organizationId,
  }) async {
    final normalizedName = name.trim().toLowerCase();

    final phoneEntries = <Map<String, String>>[
      {
        'e164': _normalizePhone(primaryPhone),
        'label': 'main',
      },
      ...phones.map(
        (phone) => {
          'e164': _normalizePhone(phone),
          'label': 'alt',
        },
      ),
    ];

    // Deduplicate and drop empties
    final seen = <String>{};
    final uniquePhones = <Map<String, String>>[];
    for (final entry in phoneEntries) {
      final value = entry['e164'] ?? '';
      if (value.isEmpty || seen.contains(value)) continue;
      seen.add(value);
      uniquePhones.add(entry);
    }

    final docData = <String, dynamic>{
      'name': name.trim(),
      'name_lc': normalizedName,
      'primaryPhone': _normalizePhone(primaryPhone),
      'phones': uniquePhones,
      'phoneIndex': uniquePhones.map((entry) => entry['e164']!).toList(),
      'tags': tags,
      'contacts': [],
      'status': 'active',
      'stats': {
        'orders': 0,
        'lifetimeAmount': 0,
      },
      'clientId': '', // placeholder replaced below
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (organizationId != null && organizationId.isNotEmpty) {
      docData['organizationId'] = organizationId;
    }

    final docRef = await _clientsRef.add(docData);
    await docRef.update({'clientId': docRef.id});
  }

  Future<void> updateClient(Client client) async {
    await _clientsRef.doc(client.id).update({
      'name': client.name,
      'name_lc': client.name.toLowerCase(),
      'primaryPhone': client.primaryPhone,
      'phones': client.phones,
      'phoneIndex': client.phoneIndex,
      'tags': client.tags,
      'status': client.status,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteClient(String clientId) {
    return _clientsRef.doc(clientId).delete();
  }

  String _normalizePhone(String phone) {
    return phone.replaceAll(RegExp(r'[^0-9+]'), '');
  }
}
