import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dash_web/domain/entities/client.dart';

class ClientsDataSource {
  ClientsDataSource({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _clientsRef =>
      _firestore.collection('CLIENTS');

  /// Fetches clients with optional cursor for pagination.
  /// Returns clients and the last document snapshot for [startAfterDocument] on next page.
  Future<({List<Client> clients, DocumentSnapshot<Map<String, dynamic>>? lastDoc})> fetchClients({
    required String organizationId,
    int limit = 20,
    DocumentSnapshot<Map<String, dynamic>>? startAfterDocument,
  }) async {
    Query<Map<String, dynamic>> query = _clientsRef
        .where('organizationId', isEqualTo: organizationId)
        .orderBy('createdAt', descending: true)
        .limit(limit);
    if (startAfterDocument != null) {
      query = query.startAfterDocument(startAfterDocument);
    }
    final snapshot = await query.get();
    final clients = snapshot.docs
        .map((doc) => Client.fromJson(doc.data(), doc.id))
        .toList();
    final lastDoc = snapshot.docs.isNotEmpty ? snapshot.docs.last : null;
    return (clients: clients, lastDoc: lastDoc);
  }

  Future<List<Client>> fetchRecentClients({
    required String organizationId,
    int limit = 10,
  }) async {
    final snapshot = await _clientsRef
        .where('organizationId', isEqualTo: organizationId)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .get();
    return snapshot.docs
        .map((doc) => Client.fromJson(doc.data(), doc.id))
        .toList();
  }

  Future<List<Client>> searchClientsByName(
    String organizationId,
    String query, {
    int limit = 20,
  }) async {
    if (query.trim().isEmpty) {
      final result = await fetchClients(organizationId: organizationId, limit: limit);
      return result.clients;
    }
    final normalized = query.trim().toLowerCase();
    final snapshot = await _clientsRef
        .where('organizationId', isEqualTo: organizationId)
        .orderBy('name_lc')
        .startAt([normalized])
        .endAt(['$normalized\uf8ff'])
        .limit(limit)
        .get();
    return snapshot.docs
        .map((doc) => Client.fromJson(doc.data(), doc.id))
        .toList();
  }

  Future<List<Client>> searchClientsByPhone(
    String organizationId,
    String digits, {
    int limit = 10,
  }) async {
    final normalized = _normalizePhone(digits);
    final snapshot = await _clientsRef
        .where('organizationId', isEqualTo: organizationId)
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

  Future<void> updatePrimaryPhone({
    required String clientId,
    required String newPhone,
  }) async {
    final normalized = _normalizePhone(newPhone);
    final docRef = _clientsRef.doc(clientId);

    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(docRef);
      if (!snapshot.exists) {
        throw Exception('Client not found');
      }
      final data = snapshot.data()!;
      final phones = List<Map<String, dynamic>>.from(data['phones'] ?? []);
      final phoneIndex = <String>{
        ...List<String>.from(data['phoneIndex'] ?? []),
      };

      final alreadyPresent = phones.any((entry) => entry['e164'] == normalized);
      if (!alreadyPresent) {
        phones.insert(0, {
          'e164': normalized,
          'label': 'main',
        });
      } else {
        for (final entry in phones) {
          if (entry['e164'] == normalized) {
            entry['label'] = entry['label'] ?? 'main';
          }
        }
      }
      phoneIndex.add(normalized);

      transaction.update(docRef, {
        'primaryPhone': normalized,
        'phones': phones,
        'phoneIndex': phoneIndex.toList(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  Future<void> deleteClient(String clientId) {
    return _clientsRef.doc(clientId).delete();
  }

  Future<Client?> findClientByPhone(String organizationId, String phone) async {
    final normalized = _normalizePhone(phone);
    final snapshot = await _clientsRef
        .where('organizationId', isEqualTo: organizationId)
        .where('phoneIndex', arrayContains: normalized)
        .limit(1)
        .get();
    if (snapshot.docs.isEmpty) return null;
    return Client.fromJson(snapshot.docs.first.data(), snapshot.docs.first.id);
  }

  Future<void> addContactToExistingClient({
    required String clientId,
    required String contactName,
    required String phoneNumber,
  }) async {
    final normalized = _normalizePhone(phoneNumber);
    final docRef = _clientsRef.doc(clientId);

    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(docRef);
      if (!snapshot.exists) {
        throw Exception('Client not found');
      }
      final data = snapshot.data()!;
      final phones = List<Map<String, dynamic>>.from(data['phones'] ?? []);
      final phoneIndex = List<String>.from(data['phoneIndex'] ?? []);
      if (phoneIndex.contains(normalized)) {
        return; // Phone already exists
      }
      phones.add({
        'e164': normalized,
        'label': 'contact',
      });
      phoneIndex.add(normalized);

      final contacts = List<Map<String, dynamic>>.from(data['contacts'] ?? []);
      contacts.add({
        'name': contactName.trim(),
        'e164': normalized,
      });

      transaction.update(docRef, {
        'phones': phones,
        'phoneIndex': phoneIndex,
        'contacts': contacts,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  String _normalizePhone(String phone) {
    return phone.replaceAll(RegExp(r'[^0-9+]'), '');
  }
}
