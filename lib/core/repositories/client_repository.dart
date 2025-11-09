import 'package:cloud_firestore/cloud_firestore.dart';

import '../constants/app_constants.dart';
import '../models/client.dart';

class ClientPageResult {
  final List<Client> clients;
  final DocumentSnapshot<Map<String, dynamic>>? lastDocument;
  final bool hasMore;

  const ClientPageResult({
    required this.clients,
    required this.lastDocument,
    required this.hasMore,
  });
}

class ClientRepository {
  ClientRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  Query<Map<String, dynamic>> _baseQuery(String organizationId) {
    return _firestore
        .collection(AppConstants.clientsCollection)
        .where('organizationId', isEqualTo: organizationId)
        .orderBy('name');
  }

  Future<ClientPageResult> fetchClientsPage({
    required String organizationId,
    int limit = AppConstants.defaultPageSize,
    DocumentSnapshot<Map<String, dynamic>>? startAfter,
  }) async {
    var query = _baseQuery(organizationId).limit(limit);

    if (startAfter != null) {
      query = query.startAfterDocument(startAfter);
    }

    final snapshot = await query.get();
    final clients = snapshot.docs
        .map((doc) => Client.fromFirestore(doc))
        .where((client) => client.name.isNotEmpty)
        .toList(growable: false);

    final lastDocument = snapshot.docs.isNotEmpty ? snapshot.docs.last : null;

    return ClientPageResult(
      clients: clients,
      lastDocument: lastDocument,
      hasMore: snapshot.docs.length == limit,
    );
  }

  Future<List<Client>> fetchAllClients({
    required String organizationId,
    int? maxDocuments,
  }) async {
    final snapshot = await _baseQuery(organizationId).get();
    final docs = maxDocuments != null
        ? snapshot.docs.take(maxDocuments).toList()
        : snapshot.docs;

    return docs
        .map((doc) => Client.fromFirestore(doc))
        .where((client) => client.name.isNotEmpty)
        .toList(growable: false);
  }
}
