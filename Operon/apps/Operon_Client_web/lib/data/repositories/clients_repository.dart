import 'package:dash_web/data/datasources/clients_data_source.dart';
import 'package:dash_web/domain/entities/client.dart';

class ClientsRepository {
  ClientsRepository({required ClientsDataSource dataSource})
      : _dataSource = dataSource;

  final ClientsDataSource _dataSource;

  Future<List<Client>> fetchClients({int limit = 20}) {
    return _dataSource.fetchClients(limit: limit);
  }

  Future<List<Client>> fetchRecentClients({int limit = 10}) {
    return _dataSource.fetchRecentClients(limit: limit);
  }

  Future<List<Client>> searchClients(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return [];

    final digitsOnly = trimmed.replaceAll(RegExp(r'[^0-9+]'), '');
    if (digitsOnly.length >= 4) {
      final phoneMatches =
          await _dataSource.searchClientsByPhone(digitsOnly, limit: 10);
      if (phoneMatches.isNotEmpty) {
        return phoneMatches;
      }
    }

    return _dataSource.searchClientsByName(trimmed, limit: 20);
  }

  Future<void> createClient({
    required String name,
    required String primaryPhone,
    required List<String> phones,
    required List<String> tags,
    String? organizationId,
  }) {
    return _dataSource.createClient(
      name: name,
      primaryPhone: primaryPhone,
      phones: phones,
      tags: tags,
      organizationId: organizationId,
    );
  }

  Future<void> updateClient(Client client) {
    return _dataSource.updateClient(client);
  }

  Future<void> updatePrimaryPhone({
    required String clientId,
    required String newPhone,
  }) async {
    return _dataSource.updatePrimaryPhone(
      clientId: clientId,
      newPhone: newPhone,
    );
  }

  Future<void> deleteClient(String clientId) {
    return _dataSource.deleteClient(clientId);
  }

  Future<Client?> findClientByPhone(String phone) {
    return _dataSource.findClientByPhone(phone);
  }

  Future<void> addContactToExistingClient({
    required String clientId,
    required String contactName,
    required String phoneNumber,
  }) {
    return _dataSource.addContactToExistingClient(
      clientId: clientId,
      contactName: contactName,
      phoneNumber: phoneNumber,
    );
  }
}
