import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dash_mobile/data/services/client_service.dart';

class ClientsRepository {
  ClientsRepository({ClientService? service})
      : _service = service ?? ClientService();

  final ClientService _service;

  Future<List<ClientRecord>> fetchRecentClients({
    required String orgId,
    int limit = 10,
  }) {
    return _service.fetchRecentClients(
      limit: limit,
      organizationId: orgId,
    );
  }

  Future<
      ({
        List<ClientRecord> clients,
        DocumentSnapshot<Map<String, dynamic>>? lastDoc,
      })> fetchClientsPage({
    required String orgId,
    int limit = 30,
    DocumentSnapshot<Map<String, dynamic>>? startAfterDocument,
  }) {
    return _service.fetchClientsPage(
      limit: limit,
      startAfterDocument: startAfterDocument,
      organizationId: orgId,
    );
  }

  Future<
      ({
        List<ClientRecord> clients,
        DocumentSnapshot<Map<String, dynamic>>? lastDoc,
      })> fetchRecentClientsPage({
    required String orgId,
    int limit = 20,
    DocumentSnapshot<Map<String, dynamic>>? startAfterDocument,
  }) {
    return _service.fetchRecentClientsPage(
      limit: limit,
      startAfterDocument: startAfterDocument,
      organizationId: orgId,
    );
  }

  Stream<List<ClientRecord>> recentClientsStream({
    required String orgId,
    int limit = 10,
  }) {
    return _service.recentClientsStream(
      limit: limit,
      organizationId: orgId,
    );
  }

  Future<List<ClientRecord>> searchClients(String orgId, String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return [];

    final digitsOnly = trimmed.replaceAll(RegExp(r'[^0-9+]'), '');
    if (digitsOnly.length >= 4) {
      final phoneMatches = await _service.searchClientsByPhone(
        digitsOnly,
        limit: 10,
        organizationId: orgId,
      );
      if (phoneMatches.isNotEmpty) {
        return phoneMatches;
      }
    }

    return _service.searchClientsByName(
      trimmed,
      limit: 20,
      organizationId: orgId,
    );
  }
}
