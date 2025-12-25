import 'package:cloud_firestore/cloud_firestore.dart';

class ClientService {
  ClientService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  static const String _collection = 'CLIENTS';

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

    final docRef = await _firestore.collection(_collection).add(docData);
    await docRef.update({'clientId': docRef.id});
  }

  Future<ClientRecord?> findClientByPhone(String phone) async {
    final normalized = _normalizePhone(phone);
    final snapshot = await _firestore
          .collection(_collection)
          .where('phoneIndex', arrayContains: normalized)
          .limit(1)
          .get();
    if (snapshot.docs.isEmpty) return null;
    return ClientRecord.fromDoc(snapshot.docs.first);
  }

  Future<List<ClientRecord>> fetchClients({int limit = 100}) async {
    final snapshot = await _firestore
        .collection(_collection)
        .orderBy('name_lc')
        .limit(limit)
        .get();
    return snapshot.docs.map(ClientRecord.fromDoc).toList();
  }

  Future<List<ClientRecord>> fetchRecentClients({int limit = 10}) async {
    final snapshot = await _firestore
        .collection(_collection)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .get();
    return snapshot.docs.map(ClientRecord.fromDoc).toList();
  }

  Stream<List<ClientRecord>> recentClientsStream({int limit = 10}) {
    return _firestore
        .collection(_collection)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map(ClientRecord.fromDoc).toList(),
        );
  }

  Future<List<ClientRecord>> searchClientsByName(
    String query, {
    int limit = 20,
  }) async {
    if (query.trim().isEmpty) return fetchClients(limit: limit);
    final normalized = query.trim().toLowerCase();
    final snapshot = await _firestore
        .collection(_collection)
        .orderBy('name_lc')
        .startAt([normalized])
        .endAt(['$normalized\uf8ff'])
        .limit(limit)
        .get();
    return snapshot.docs.map(ClientRecord.fromDoc).toList();
  }

  Future<List<ClientRecord>> searchClientsByPhone(
    String digits, {
    int limit = 10,
  }) async {
    final normalized = _normalizePhone(digits);
    if (normalized.isEmpty) return [];
    final snapshot = await _firestore
          .collection(_collection)
          .where('phoneIndex', arrayContains: normalized)
          .limit(limit)
          .get();
    return snapshot.docs.map(ClientRecord.fromDoc).toList();
  }

  Future<void> addContactToExistingClient({
    required String clientId,
    required String contactName,
    required String phoneNumber,
    String? description,
  }) async {
    final normalized = _normalizePhone(phoneNumber);
    final docRef = _firestore.collection(_collection).doc(clientId);

    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(docRef);
      if (!snapshot.exists) {
        throw Exception('Client not found');
      }
      final data = snapshot.data()!;
      final phones = List<Map<String, dynamic>>.from(data['phones'] ?? []);
      final phoneIndex = List<String>.from(data['phoneIndex'] ?? []);
      if (phoneIndex.contains(normalized)) {
        throw ClientPhoneExistsException();
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
        if (description != null && description.trim().isNotEmpty)
          'description': description.trim(),
      });

      transaction.update(docRef, {
        'phones': phones,
        'phoneIndex': phoneIndex,
        'contacts': contacts,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  Future<void> updatePrimaryPhone({
    required String clientId,
    required String newPhone,
  }) async {
    final normalized = _normalizePhone(newPhone);
    final docRef = _firestore.collection(_collection).doc(clientId);

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
    return _firestore.collection(_collection).doc(clientId).delete();
  }

  String _normalizePhone(String input) {
    return input.replaceAll(RegExp(r'[^0-9+]'), '');
  }
}

class ClientRecord {
  ClientRecord({
    required this.id,
    required this.name,
    required this.tags,
    required this.primaryPhone,
    required this.phones,
    required this.phoneIndex,
    required this.status,
    required this.stats,
    required this.organizationId,
    required this.createdAt,
    required this.contacts,
  });

  factory ClientRecord.fromDoc(
      QueryDocumentSnapshot<Map<String, dynamic>> snapshot) {
    final data = snapshot.data();
    final phoneEntries =
        List<Map<String, dynamic>>.from(data['phones'] ?? const <Map>[]);
    final phoneIndex = data['phoneIndex'] != null
        ? List<String>.from(data['phoneIndex'] as List)
        : phoneEntries
            .map((entry) => (entry['e164'] as String?) ?? '')
            .where((value) => value.isNotEmpty)
            .toList();
    final contactEntries =
        List<Map<String, dynamic>>.from(data['contacts'] ?? const <Map>[]);
    return ClientRecord(
      id: snapshot.id,
      name: (data['name'] as String?) ?? 'Unnamed Client',
      tags: List<String>.from(data['tags'] ?? const []),
      primaryPhone: data['primaryPhone'] as String?,
      phones: phoneEntries,
      phoneIndex: phoneIndex,
      status: (data['status'] as String?) ?? 'active',
      stats: Map<String, dynamic>.from(data['stats'] ?? const {}),
      organizationId: data['organizationId'] as String?,
      createdAt: (data['createdAt'] is Timestamp)
          ? (data['createdAt'] as Timestamp).toDate()
          : null,
      contacts: contactEntries
          .map((json) => ClientContact.fromJson(json))
          .toList(),
    );
  }

  final String id;
  final String name;
  final List<String> tags;
  final String? primaryPhone;
  final List<Map<String, dynamic>> phones;
  final List<String> phoneIndex;
  final String status;
  final Map<String, dynamic> stats;
  final String? organizationId;
  final DateTime? createdAt;
  final List<ClientContact> contacts;

  bool get isCorporate =>
      tags.any((tag) => tag.toLowerCase() == 'corporate');
}

class ClientContact {
  const ClientContact({
    required this.name,
    required this.phone,
    this.description,
  });

  factory ClientContact.fromJson(Map<String, dynamic> json) {
    return ClientContact(
      name: (json['name'] as String?) ?? '',
      phone: (json['e164'] as String?) ?? (json['phone'] as String?) ?? '',
      description: json['description'] as String?,
    );
  }

  final String name;
  final String phone;
  final String? description;
}

class ClientPhoneExistsException implements Exception {}

