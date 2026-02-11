import 'package:core_ui/core_ui.dart';
import 'package:dash_mobile/shared/constants/app_spacing.dart';
import 'package:dash_mobile/shared/constants/app_typography.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class AccountDetailPage extends StatefulWidget {
  const AccountDetailPage({super.key, required this.ledger});

  final dynamic ledger;

  @override
  State<AccountDetailPage> createState() => _AccountDetailPageState();
}

class _AccountDetailPageState extends State<AccountDetailPage> {
  int _selectedTabIndex = 0;

  dynamic get _ledger => widget.ledger;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AuthColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.paddingXL,
                vertical: AppSpacing.paddingMD,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  IconButton(
                    onPressed: () => context.pop(),
                    icon: const Icon(Icons.close, color: AuthColors.textSub),
                  ),
                  const SizedBox(width: AppSpacing.paddingSM),
                  Expanded(
                    child: Text(
                      'Ledger Details',
                      style: AppTypography.withColor(
                        AppTypography.h2,
                        AuthColors.textMain,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.avatarSM),
                ],
              ),
            ),
            // Ledger Header Info
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: AppSpacing.paddingXL),
              child: _LedgerHeader(ledger: _ledger),
            ),
            const SizedBox(height: AppSpacing.paddingLG),
            // Tab Bar
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: AppSpacing.paddingXL),
              child: Container(
                decoration: BoxDecoration(
                  color: AuthColors.surface,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMD),
                  border: Border.all(
                    color: AuthColors.textMainWithOpacity(0.1),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _TabButton(
                        label: 'Accounts',
                        isSelected: _selectedTabIndex == 0,
                        onTap: () => setState(() => _selectedTabIndex = 0),
                      ),
                    ),
                    Expanded(
                      child: _TabButton(
                        label: 'Details',
                        isSelected: _selectedTabIndex == 1,
                        onTap: () => setState(() => _selectedTabIndex = 1),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.paddingLG),
            // Content
            Expanded(
              child: IndexedStack(
                index: _selectedTabIndex,
                children: [
                  _AccountsListTab(ledger: _ledger),
                  _LedgerDetailsTab(ledger: _ledger),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LedgerHeader extends StatelessWidget {
  const _LedgerHeader({required this.ledger});

  final _CombinedLedger ledger;

  Color _getLedgerColor() {
    final hash = ledger.name.hashCode;
    const colors = [
      AuthColors.primary,
      AuthColors.secondary,
      AuthColors.success,
      AuthColors.warning,
      AuthColors.error,
    ];
    return colors[hash.abs() % colors.length];
  }

  String _getInitials() {
    final words = ledger.name.trim().split(' ');
    if (words.isEmpty) return '?';
    if (words.length == 1) {
      return words[0].isNotEmpty ? words[0][0].toUpperCase() : '?';
    }
    return '${words[0][0]}${words[words.length - 1][0]}'.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final ledgerColor = _getLedgerColor();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.paddingXL),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppSpacing.radiusXXL),
        gradient: LinearGradient(
          colors: [
            ledgerColor.withOpacity(0.3),
            AuthColors.backgroundAlt,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: ledgerColor.withOpacity(0.2),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Avatar
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [
                      ledgerColor.withOpacity(0.4),
                      ledgerColor.withOpacity(0.2),
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: ledgerColor.withOpacity(0.3),
                      blurRadius: 8,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    _getInitials(),
                    style: TextStyle(
                      color: ledgerColor,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.paddingLG),
              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      ledger.name,
                      style: AppTypography.withColor(
                        AppTypography.withWeight(
                          AppTypography.h1,
                          FontWeight.w700,
                        ),
                        AuthColors.textMain,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${ledger.accounts.length} accounts',
                      style: const TextStyle(
                        color: AuthColors.textSub,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AccountsListTab extends StatelessWidget {
  const _AccountsListTab({required this.ledger});

  final _CombinedLedger ledger;

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.all(AppSpacing.paddingLG),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Accounts (${ledger.accounts.length})',
                  style: const TextStyle(
                    color: AuthColors.textMain,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: AppSpacing.paddingLG),
                if (ledger.accounts.isEmpty)
                  const Center(
                    child: Text(
                      'No accounts in this ledger.',
                      style: TextStyle(color: AuthColors.textSub),
                    ),
                  )
                else
                  Wrap(
                    spacing: AppSpacing.paddingSM,
                    runSpacing: AppSpacing.paddingSM,
                    children: ledger.accounts
                        .map((account) => _AccountChip(account: account))
                        .toList(),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _AccountChip extends StatelessWidget {
  const _AccountChip({required this.account});

  final _AccountOption account;

  Color _getTypeColor() {
    return switch (account.type) {
      _AccountType.employee => AuthColors.primary,
      _AccountType.vendor => AuthColors.secondary,
      _AccountType.client => AuthColors.success,
    };
  }

  @override
  Widget build(BuildContext context) {
    final typeColor = _getTypeColor();
    final typeLabel = account.type.name.substring(0, 1).toUpperCase() +
        account.type.name.substring(1);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.paddingMD,
        vertical: AppSpacing.paddingSM,
      ),
      decoration: BoxDecoration(
        color: typeColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMD),
        border: Border.all(color: typeColor.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            account.name,
            style: const TextStyle(
              color: AuthColors.textMain,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            typeLabel,
            style: TextStyle(
              color: typeColor,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _LedgerDetailsTab extends StatelessWidget {
  const _LedgerDetailsTab({required this.ledger});

  final _CombinedLedger ledger;

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.all(AppSpacing.paddingLG),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Ledger Information',
                  style: TextStyle(
                    color: AuthColors.textMain,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: AppSpacing.paddingLG),
                _DetailRow(label: 'Name', value: ledger.name),
                _DetailRow(
                  label: 'Created',
                  value: _formatDateTime(ledger.createdAt),
                ),
                _DetailRow(
                  label: 'Last Refreshed',
                  value: _formatDateTime(ledger.lastRefreshedAt),
                ),
                _DetailRow(
                    label: 'Total Accounts',
                    value: ledger.accounts.length.toString()),
              ],
            ),
          ),
        ),
      ],
    );
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.paddingLG),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: AuthColors.textSub,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: AuthColors.textMain,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  const _TabButton({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.paddingMD),
        decoration: BoxDecoration(
          color: isSelected
              ? AuthColors.primaryWithOpacity(0.1)
              : Colors.transparent,
          border: Border(
            bottom: BorderSide(
              color: isSelected ? AuthColors.primary : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: isSelected ? AuthColors.primary : AuthColors.textSub,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}

enum _AccountType { employee, vendor, client }

class _AccountOption {
  const _AccountOption({
    required this.key,
    required this.id,
    required this.name,
    required this.type,
  });

  final String key;
  final String id;
  final String name;
  final _AccountType type;
}

class _CombinedLedger {
  const _CombinedLedger({
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
  final List<_AccountOption> accounts;
  final DateTime createdAt;
  final DateTime lastRefreshedAt;

  bool get isEmpty => id.isEmpty;
}
