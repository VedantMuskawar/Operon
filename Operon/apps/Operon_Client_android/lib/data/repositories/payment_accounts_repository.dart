import 'package:dash_mobile/data/datasources/payment_accounts_data_source.dart';
import 'package:dash_mobile/domain/entities/payment_account.dart';

class PaymentAccountsRepository {
  PaymentAccountsRepository({required PaymentAccountsDataSource dataSource})
      : _dataSource = dataSource;

  final PaymentAccountsDataSource _dataSource;

  Future<List<PaymentAccount>> fetchAccounts(String orgId) {
    return _dataSource.fetchAccounts(orgId);
  }

  Future<void> createAccount(String orgId, PaymentAccount account) {
    return _dataSource.createAccount(orgId, account);
  }

  Future<void> updateAccount(String orgId, PaymentAccount account) {
    return _dataSource.updateAccount(orgId, account);
  }

  Future<void> deleteAccount(String orgId, String accountId) {
    return _dataSource.deleteAccount(orgId, accountId);
  }

  Future<void> setPrimaryAccount(String orgId, String accountId) {
    return _dataSource.setPrimaryAccount(orgId, accountId);
  }

  Future<void> unsetPrimaryAccount(String orgId, String accountId) {
    return _dataSource.unsetPrimaryAccount(orgId, accountId);
  }
}

