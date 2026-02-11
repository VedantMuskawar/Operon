// Shared models for Accounts Ledger pages
enum AccountType { employee, vendor, client }

class AccountOption {
  const AccountOption({
    required this.key,
    required this.id,
    required this.name,
    required this.type,
  });

  final String key;
  final String id;
  final String name;
  final AccountType type;
}

class CombinedLedger {
  const CombinedLedger({
    required this.id,
    required this.accountsLedgerId,
    required this.name,
    required this.accounts,
    required this.createdAt,
    required this.lastRefreshedAt,
  });

  final String id;
  final String accountsLedgerId;
  final String name;
  final List<AccountOption> accounts;
  final DateTime createdAt;
  final DateTime lastRefreshedAt;

  bool get isEmpty => id.isEmpty;

  CombinedLedger copyWith({
    String? id,
    String? accountsLedgerId,
    String? name,
    List<AccountOption>? accounts,
    DateTime? createdAt,
    DateTime? lastRefreshedAt,
  }) {
    return CombinedLedger(
      id: id ?? this.id,
      accountsLedgerId: accountsLedgerId ?? this.accountsLedgerId,
      name: name ?? this.name,
      accounts: accounts ?? this.accounts,
      createdAt: createdAt ?? this.createdAt,
      lastRefreshedAt: lastRefreshedAt ?? this.lastRefreshedAt,
    );
  }
}
