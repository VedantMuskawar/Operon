import 'package:core_datasources/client_ledger/client_ledger_data_source.dart';

class ClientLedgerRepository {
  ClientLedgerRepository({required ClientLedgerDataSource dataSource})
      : _dataSource = dataSource;

  final ClientLedgerDataSource _dataSource;

  Stream<Map<String, dynamic>?> watchClientLedger(
    String organizationId,
    String clientId,
  ) {
    return _dataSource.watchClientLedger(organizationId, clientId);
  }

  Future<Map<String, dynamic>?> fetchClientLedger(
    String organizationId,
    String clientId,
  ) async {
    return _dataSource.fetchClientLedger(organizationId, clientId);
  }

  Stream<List<Map<String, dynamic>>> watchRecentTransactions(
    String organizationId,
    String clientId,
    int limit,
  ) {
    return _dataSource.watchRecentTransactions(organizationId, clientId, limit);
  }

  String getCurrentFinancialYear() {
    return _dataSource.getCurrentFinancialYear();
  }
}

