import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:core_datasources/core_datasources.dart';
import 'package:core_models/core_models.dart';
import 'package:core_ui/core_ui.dart' show AuthColors;
import 'package:dash_mobile/data/services/recently_viewed_employees_service.dart';
import 'package:dash_mobile/presentation/blocs/employees/employees_cubit.dart';
import 'package:dash_mobile/presentation/blocs/org_context/org_context_cubit.dart';
import 'package:dash_mobile/shared/constants/app_spacing.dart';
import 'package:dash_mobile/shared/constants/app_typography.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class EmployeeDetailPage extends StatefulWidget {
  const EmployeeDetailPage({super.key, required this.employee});

  final OrganizationEmployee employee;

  @override
  State<EmployeeDetailPage> createState() => _EmployeeDetailPageState();
}

class _EmployeeDetailPageState extends State<EmployeeDetailPage> {
  @override
  void initState() {
    super.initState();
    // Track employee view when page is opened
    _trackEmployeeView();
  }

  Future<void> _trackEmployeeView() async {
    final orgState = context.read<OrganizationContextCubit>().state;
    final organizationId = orgState.organization?.id;
    if (organizationId != null) {
      await RecentlyViewedEmployeesService.trackEmployeeView(
        organizationId: organizationId,
        employeeId: widget.employee.id,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final employee = widget.employee;
    return Scaffold(
      backgroundColor: AuthColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.paddingXL,
                  vertical: AppSpacing.paddingMD),
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
                      'Employee Details',
                      style: AppTypography.withColor(
                          AppTypography.h2, AuthColors.textMain),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.avatarSM),
                ],
              ),
            ),
            // Employee Header Info
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: AppSpacing.paddingXL),
              child: _EmployeeHeader(
                employee: employee,
                onEdit: _openEditDialog,
                onDelete: _confirmDelete,
              ),
            ),
            const SizedBox(height: AppSpacing.paddingLG),
            // Transactions Section
            Expanded(
              child: _TransactionsSection(employee: widget.employee),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openEditDialog() async {
    await showDialog(
      context: context,
      builder: (dialogContext) => BlocProvider.value(
        value: context.read<EmployeesCubit>(),
        child: _EmployeeDialog(employee: widget.employee),
      ),
    );
    // Refresh employee data after edit
    if (mounted) {
      context.read<EmployeesCubit>().load();
    }
  }

  Future<void> _confirmDelete() async {
    final confirm = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _DeleteEmployeeSheet(
        employeeName: widget.employee.name,
      ),
    );

    if (confirm != true) return;

    try {
      context.read<EmployeesCubit>().deleteEmployee(widget.employee.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Employee deleted.')),
      );
      context.go('/employees');
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to delete employee: $error')),
      );
    }
  }
}

class _EmployeeHeader extends StatelessWidget {
  const _EmployeeHeader({
    required this.employee,
    required this.onEdit,
    required this.onDelete,
  });

  final OrganizationEmployee employee;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  Color _getEmployeeColor() {
    final hash = employee.primaryJobRoleTitle.hashCode;
    final colors = [
      AuthColors.secondary, // 0xFF9C27B0 (closest to 0xFF6F4BFF)
      AuthColors.successVariant, // 0xFF5AD8A4
      AuthColors.warning, // 0xFFFF9800
      AuthColors.info, // 0xFF2196F3
      AuthColors.error, // 0xFFFF5252 (closest to 0xFFE91E63)
      AuthColors.secondary, // 0xFF9C27B0
    ];
    return colors[hash.abs() % colors.length];
  }

  String _getInitials() {
    final words = employee.name.trim().split(' ');
    if (words.isEmpty) return '?';
    if (words.length == 1) {
      return words[0].isNotEmpty ? words[0][0].toUpperCase() : '?';
    }
    return '${words[0][0]}${words[words.length - 1][0]}'.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final employeeColor = _getEmployeeColor();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.paddingXL),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppSpacing.radiusXXL),
        gradient: LinearGradient(
          colors: [
            employeeColor.withValues(alpha: 0.3),
            AuthColors.backgroundAlt,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: employeeColor.withValues(alpha: 0.2),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
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
                  employeeColor.withValues(alpha: 0.4),
                  employeeColor.withValues(alpha: 0.2),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: employeeColor.withValues(alpha: 0.3),
                  blurRadius: 8,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Center(
              child: Text(
                _getInitials(),
                style: TextStyle(
                  color: employeeColor,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.paddingLG),
          // Name and Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  employee.name,
                  style: const TextStyle(
                    color: AuthColors.textMain,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppSpacing.paddingSM),
                // Role Badge
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: employeeColor.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(AppSpacing.radiusSM),
                    border: Border.all(
                      color: employeeColor.withValues(alpha: 0.5),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.badge_outlined,
                        size: 14,
                        color: employeeColor,
                      ),
                      const SizedBox(width: AppSpacing.paddingXS),
                      Text(
                        employee.primaryJobRoleTitle.isEmpty
                            ? 'No Role'
                            : employee.primaryJobRoleTitle,
                        style: TextStyle(
                          color: employeeColor,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Action Buttons
          IconButton(
            onPressed: onDelete,
            icon: const Icon(Icons.delete_outline, color: AuthColors.textSub),
            tooltip: 'Delete',
          ),
          IconButton(
            onPressed: onEdit,
            icon: const Icon(Icons.edit, color: AuthColors.textSub),
            tooltip: 'Edit',
          ),
        ],
      ),
    );
  }
}

class _TransactionsSection extends StatefulWidget {
  const _TransactionsSection({required this.employee});

  final OrganizationEmployee employee;

  @override
  State<_TransactionsSection> createState() => _TransactionsSectionState();
}

class _TransactionsSectionState extends State<_TransactionsSection> {
  @override
  Widget build(BuildContext context) {
    final orgState = context.watch<OrganizationContextCubit>().state;
    final organization = orgState.organization;

    if (organization == null) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(AppSpacing.paddingXL),
          child: Text(
            'No organization selected',
            style: TextStyle(color: AuthColors.textSub),
          ),
        ),
      );
    }

    final repository = context.read<EmployeeWagesRepository>();

    return StreamBuilder<Map<String, dynamic>?>(
      stream: repository.watchEmployeeLedger(employeeId: widget.employee.id),
      builder: (context, ledgerSnapshot) {
        return StreamBuilder<List<Map<String, dynamic>>>(
          stream: repository.watchEmployeeLedgerTransactions(
            employeeId: widget.employee.id,
            limit: 100,
          ),
          builder: (context, transactionsSnapshot) {
            if (ledgerSnapshot.connectionState == ConnectionState.waiting ||
                transactionsSnapshot.connectionState ==
                    ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(
                  color: AuthColors.primary,
                ),
              );
            }

            if (ledgerSnapshot.hasError || transactionsSnapshot.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.paddingXL),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.error_outline,
                        size: 48,
                        color: AuthColors.error,
                      ),
                      const SizedBox(height: AppSpacing.paddingLG),
                      Text(
                        'Failed to load ledger: ${ledgerSnapshot.error ?? transactionsSnapshot.error}',
                        style: const TextStyle(
                          color: AuthColors.textSub,
                          fontSize: 14,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              );
            }

            final transactions = transactionsSnapshot.data ?? [];

            return SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.paddingXL),
              child: _LedgerTable(
                openingBalance: widget.employee.openingBalance,
                transactions: transactions,
                formatCurrency: _formatCurrency,
                formatDate: _formatDate,
              ),
            );
          },
        );
      },
    );
  }

  String _formatCurrency(double amount) {
    return '₹${amount.toStringAsFixed(0).replaceAllMapped(
          RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]},',
        )}';
  }

  String _formatDate(dynamic timestamp) {
    if (timestamp == null) return 'N/A';
    try {
      DateTime date;
      if (timestamp is DateTime) {
        date = timestamp;
      } else {
        // Try to call toDate() if it's a Firestore Timestamp
        try {
          date = (timestamp as dynamic).toDate() as DateTime;
        } catch (_) {
          return 'N/A';
        }
      }
      return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year.toString().substring(2)}';
    } catch (e) {
      return 'N/A';
    }
  }
}

String _formatCategoryName(String? category) {
  if (category == null || category.isEmpty) return '';
  return category
      .replaceAllMapped(RegExp(r'([A-Z])'), (match) => ' ${match.group(1)}')
      .split(' ')
      .map((word) => word.isEmpty
          ? ''
          : word[0].toUpperCase() + word.substring(1).toLowerCase())
      .join(' ')
      .trim();
}

class _LedgerTable extends StatelessWidget {
  const _LedgerTable({
    required this.openingBalance,
    required this.transactions,
    required this.formatCurrency,
    required this.formatDate,
  });

  final double openingBalance;
  final List<Map<String, dynamic>> transactions;
  final String Function(double) formatCurrency;
  final String Function(dynamic) formatDate;

  @override
  Widget build(BuildContext context) {
    final visible = List<Map<String, dynamic>>.from(transactions);
    if (visible.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Ledger',
            style: TextStyle(
              color: AuthColors.textMain,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppSpacing.paddingMD),
          const Text(
            'No transactions found.',
            style: TextStyle(color: AuthColors.textSub),
          ),
          const SizedBox(height: AppSpacing.paddingXL),
          _LedgerSummaryFooter(
            openingBalance: openingBalance,
            totalDebit: 0,
            totalCredit: 0,
            formatCurrency: formatCurrency,
          ),
        ],
      );
    }

    visible.sort((a, b) {
      final aDate = a['transactionDate'];
      final bDate = b['transactionDate'];
      try {
        final ad = aDate is Timestamp ? aDate.toDate() : (aDate as DateTime);
        final bd = bDate is Timestamp ? bDate.toDate() : (bDate as DateTime);
        return ad.compareTo(bd);
      } catch (_) {
        return 0;
      }
    });

    var totalDebit = 0.0;
    var totalCredit = 0.0;
    var running = openingBalance;
    final rows = <Widget>[];
    for (final tx in visible) {
      final type = (tx['type'] as String? ?? 'credit').toLowerCase();
      final amount = (tx['amount'] as num?)?.toDouble() ?? 0.0;
      final date = tx['transactionDate'] ?? tx['createdAt'];
      final desc = (tx['description'] as String?)?.trim();
      final batchTrip = (desc != null && desc.isNotEmpty) ? desc : '-';
      final category = tx['category'] as String?;
      final isCredit = type == 'credit';
      final credit = isCredit ? amount : 0.0;
      final debit = isCredit ? 0.0 : amount;
      final txId = tx['transactionId'] as String? ?? tx['id'] as String?;
      final metadata = tx['metadata'] as Map<String, dynamic>?;
      final voucherUrl = metadata?['cashVoucherPhotoUrl']?.toString();
      final showVoucher = category == 'salaryDebit' &&
          txId != null &&
          txId.isNotEmpty &&
          voucherUrl != null &&
          voucherUrl.isNotEmpty;

      running += isCredit ? amount : -amount;
      totalCredit += credit;
      totalDebit += debit;

      rows.add(
        _LedgerTableRow(
          date: date,
          batchTrip: batchTrip,
          debit: debit,
          credit: credit,
          balance: running,
          type: _formatCategoryName(category),
          remarks: '-',
          formatCurrency: formatCurrency,
          formatDate: formatDate,
          transactionId: txId,
          showVoucher: showVoucher,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Ledger',
          style: TextStyle(
            color: AuthColors.textMain,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: AppSpacing.paddingMD),
        Container(
          decoration: BoxDecoration(
            color: AuthColors.surface,
            borderRadius: BorderRadius.circular(AppSpacing.radiusMD),
            border: Border.all(
                color: AuthColors.textMainWithOpacity(0.1), width: 1),
          ),
          child: Column(
            children: [
              _LedgerTableHeader(),
              Divider(height: 1, color: AuthColors.textMain.withValues(alpha: 0.12)),
              ...rows,
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.paddingXL),
        _LedgerSummaryFooter(
          openingBalance: openingBalance,
          totalDebit: totalDebit,
          totalCredit: totalCredit,
          formatCurrency: formatCurrency,
        ),
      ],
    );
  }
}

class _LedgerTableHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(
          horizontal: AppSpacing.paddingMD, vertical: AppSpacing.paddingMD),
      child: Row(
        children: [
          Expanded(
              flex: 1,
              child: Text('Date',
                  style: TextStyle(color: AuthColors.textSub, fontSize: 11),
                  textAlign: TextAlign.center)),
          Expanded(
              flex: 1,
              child: Text('Reference',
                  style: TextStyle(color: AuthColors.textSub, fontSize: 11),
                  textAlign: TextAlign.center)),
          Expanded(
              flex: 1,
              child: Text('Debit',
                  style: TextStyle(color: AuthColors.textSub, fontSize: 11),
                  textAlign: TextAlign.center)),
          Expanded(
              flex: 1,
              child: Text('Credit',
                  style: TextStyle(color: AuthColors.textSub, fontSize: 11),
                  textAlign: TextAlign.center)),
          Expanded(
              flex: 1,
              child: Text('Balance',
                  style: TextStyle(color: AuthColors.textSub, fontSize: 11),
                  textAlign: TextAlign.center)),
          Expanded(
              flex: 1,
              child: Text('Type',
                  style: TextStyle(color: AuthColors.textSub, fontSize: 11),
                  textAlign: TextAlign.center)),
          Expanded(
              flex: 2,
              child: Text('Remarks',
                  style: TextStyle(color: AuthColors.textSub, fontSize: 11),
                  textAlign: TextAlign.center)),
        ],
      ),
    );
  }
}

class _LedgerTableRow extends StatelessWidget {
  const _LedgerTableRow({
    required this.date,
    required this.batchTrip,
    required this.debit,
    required this.credit,
    required this.balance,
    required this.type,
    required this.remarks,
    required this.formatCurrency,
    required this.formatDate,
    this.transactionId,
    this.showVoucher = false,
  });

  final dynamic date;
  final String batchTrip;
  final double debit;
  final double credit;
  final double balance;
  final String type;
  final String remarks;
  final String Function(double) formatCurrency;
  final String Function(dynamic) formatDate;
  final String? transactionId;
  final bool showVoucher;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.paddingMD, vertical: AppSpacing.paddingSM),
      child: Row(
        children: [
          Expanded(
              flex: 1,
              child: Text(formatDate(date),
                  style:
                      const TextStyle(color: AuthColors.textMain, fontSize: 11),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis)),
          Expanded(
              flex: 1,
              child: Text(batchTrip,
                  style:
                      const TextStyle(color: AuthColors.textMain, fontSize: 11),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis)),
          Expanded(
              flex: 1,
              child: Text(debit > 0 ? formatCurrency(debit) : '-',
                  style:
                      const TextStyle(color: AuthColors.textMain, fontSize: 11),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis)),
          Expanded(
              flex: 1,
              child: Text(credit > 0 ? formatCurrency(credit) : '-',
                  style:
                      const TextStyle(color: AuthColors.textMain, fontSize: 11),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis)),
          Expanded(
              flex: 1,
              child: Text(formatCurrency(balance),
                  style: TextStyle(
                      color: balance >= 0
                          ? AuthColors.warning
                          : AuthColors.success,
                      fontSize: 11,
                      fontWeight: FontWeight.w600),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis)),
          Expanded(
              flex: 1,
              child: Text(type.isEmpty ? '-' : type,
                  style:
                      const TextStyle(color: AuthColors.textMain, fontSize: 11),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis)),
          Expanded(
            flex: 2,
            child: showVoucher && transactionId != null
                ? TextButton(
                    onPressed: () => context
                        .go('/salary-voucher?transactionId=$transactionId'),
                    style: TextButton.styleFrom(
                      foregroundColor: AuthColors.primary,
                      padding: EdgeInsets.zero,
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text('View voucher',
                        style: TextStyle(fontSize: 11)),
                  )
                : Text(remarks,
                    style: const TextStyle(
                        color: AuthColors.textMain, fontSize: 11),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }
}

class _LedgerSummaryFooter extends StatelessWidget {
  const _LedgerSummaryFooter({
    required this.openingBalance,
    required this.totalDebit,
    required this.totalCredit,
    required this.formatCurrency,
  });

  final double openingBalance;
  final double totalDebit;
  final double totalCredit;
  final String Function(double) formatCurrency;

  @override
  Widget build(BuildContext context) {
    final currentBalance = openingBalance + totalCredit - totalDebit;
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.paddingMD, vertical: AppSpacing.paddingMD),
      decoration: BoxDecoration(
        color: AuthColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMD),
        border:
            Border.all(color: AuthColors.textMainWithOpacity(0.1), width: 1),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Opening Balance',
                  style: TextStyle(color: AuthColors.textSub, fontSize: 11),
                  textAlign: TextAlign.center),
              const SizedBox(height: AppSpacing.paddingXS),
              Text(formatCurrency(openingBalance),
                  style: const TextStyle(
                      color: AuthColors.info,
                      fontSize: 13,
                      fontWeight: FontWeight.w600),
                  textAlign: TextAlign.center),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Total Debit',
                  style: TextStyle(color: AuthColors.textSub, fontSize: 11),
                  textAlign: TextAlign.center),
              const SizedBox(height: AppSpacing.paddingXS),
              Text(formatCurrency(totalDebit),
                  style: const TextStyle(
                      color: AuthColors.info,
                      fontSize: 13,
                      fontWeight: FontWeight.w600),
                  textAlign: TextAlign.center),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Total Credit',
                  style: TextStyle(color: AuthColors.textSub, fontSize: 11),
                  textAlign: TextAlign.center),
              const SizedBox(height: AppSpacing.paddingXS),
              Text(formatCurrency(totalCredit),
                  style: const TextStyle(
                      color: AuthColors.info,
                      fontSize: 13,
                      fontWeight: FontWeight.w600),
                  textAlign: TextAlign.center),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Current Balance',
                  style: TextStyle(color: AuthColors.textSub, fontSize: 11),
                  textAlign: TextAlign.center),
              const SizedBox(height: AppSpacing.paddingXS),
              Text(formatCurrency(currentBalance),
                  style: const TextStyle(
                      color: AuthColors.success,
                      fontSize: 13,
                      fontWeight: FontWeight.w600),
                  textAlign: TextAlign.center),
            ],
          ),
        ],
      ),
    );
  }
}

class _DeleteEmployeeSheet extends StatelessWidget {
  const _DeleteEmployeeSheet({required this.employeeName});

  final String employeeName;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      decoration: const BoxDecoration(
        color: AuthColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: AppSpacing.paddingLG),
              decoration: BoxDecoration(
                color: AuthColors.textMainWithOpacity(0.24),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            Text(
              'Delete employee',
              style: AppTypography.withColor(
                  AppTypography.h3, AuthColors.textMain),
            ),
            const SizedBox(height: AppSpacing.gapSM),
            Text(
              'This will permanently remove $employeeName and all related data. This action cannot be undone.',
              style: AppTypography.withColor(
                  AppTypography.bodySmall, AuthColors.textSub),
            ),
            const SizedBox(height: AppSpacing.paddingXXL),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: AuthColors.error,
                  foregroundColor: AuthColors.textMain,
                  padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.paddingLG),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppSpacing.radiusLG),
                  ),
                ),
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Delete employee'),
              ),
            ),
            const SizedBox(height: AppSpacing.paddingMD),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmployeeDialog extends StatefulWidget {
  const _EmployeeDialog({this.employee});

  final OrganizationEmployee? employee;

  @override
  State<_EmployeeDialog> createState() => _EmployeeDialogState();
}

class _EmployeeDialogState extends State<_EmployeeDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _openingBalanceController;
  late final TextEditingController _salaryController;
  String? _selectedRoleId;
  bool _hasInitializedRole = false;

  @override
  void initState() {
    super.initState();
    final employee = widget.employee;
    _nameController = TextEditingController(text: employee?.name ?? '');
    _openingBalanceController = TextEditingController(
      text: employee != null ? employee.openingBalance.toStringAsFixed(2) : '',
    );
    _salaryController = TextEditingController(
      text: employee?.wage.baseAmount?.toStringAsFixed(2) ?? '',
    );
  }

  void _initializeRole(List<OrganizationRole> roles) {
    if (_hasInitializedRole || roles.isEmpty) return;

    if (widget.employee != null) {
      final match = roles.where(
        (role) => role.id == widget.employee?.primaryJobRoleId,
      );
      if (match.isNotEmpty) {
        _selectedRoleId = match.first.id;
        _hasInitializedRole = true;
      }
    } else {
      _selectedRoleId = roles.first.id;
      _hasInitializedRole = true;
    }
  }

  OrganizationRole? _findSelectedRole(List<OrganizationRole> roles) {
    if (_selectedRoleId == null) return null;
    try {
      return roles.firstWhere((role) => role.id == _selectedRoleId);
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<EmployeesCubit>();
    final roles = context.watch<EmployeesCubit>().state.roles;
    final isEditing = widget.employee != null;

    if (roles.isNotEmpty && !_hasInitializedRole) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _initializeRole(roles);
          });
        }
      });
    }

    final selectedRole = _findSelectedRole(roles);

    return AlertDialog(
      backgroundColor: AuthColors.backgroundAlt,
      title: Text(
        isEditing ? 'Edit Employee' : 'Add Employee',
        style: AppTypography.withColor(AppTypography.body, AuthColors.textMain),
      ),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameController,
                style: AppTypography.withColor(
                    AppTypography.body, AuthColors.textMain),
                decoration: _inputDecoration('Employee name'),
                validator: (value) => (value == null || value.trim().isEmpty)
                    ? 'Enter employee name'
                    : null,
              ),
              const SizedBox(height: AppSpacing.paddingMD),
              DropdownButtonFormField<String>(
                initialValue: _selectedRoleId,
                dropdownColor: AuthColors.surface,
                style: AppTypography.withColor(
                    AppTypography.body, AuthColors.textMain),
                items: roles
                    .map(
                      (role) => DropdownMenuItem(
                        value: role.id,
                        child: Text(role.title),
                      ),
                    )
                    .toList(),
                onChanged: (cubit.canEdit || cubit.canCreate)
                    ? (value) {
                        if (value == null) return;
                        setState(() {
                          _selectedRoleId = value;
                        });
                      }
                    : null,
                decoration: _inputDecoration('Role'),
                validator: (value) => value == null ? 'Select a role' : null,
              ),
              const SizedBox(height: AppSpacing.paddingMD),
              TextFormField(
                controller: _openingBalanceController,
                enabled: !isEditing && cubit.canCreate,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                style: AppTypography.withColor(
                    AppTypography.body, AuthColors.textMain),
                decoration: _inputDecoration('Opening balance'),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Enter opening balance';
                  }
                  final parsed = double.tryParse(value);
                  if (parsed == null) return 'Enter valid number';
                  return null;
                },
              ),
              const SizedBox(height: AppSpacing.paddingMD),
              if (selectedRole?.salaryType == SalaryType.salaryMonthly ||
                  selectedRole?.salaryType == null)
                TextFormField(
                  controller: _salaryController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  style: AppTypography.withColor(
                      AppTypography.body, AuthColors.textMain),
                  decoration: _inputDecoration('Salary amount'),
                  validator: (value) {
                    final parsed = double.tryParse(value ?? '');
                    if (parsed == null || parsed < 0) {
                      return 'Enter a valid salary';
                    }
                    return null;
                  },
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: (cubit.canCreate && !isEditing) ||
                  (cubit.canEdit && isEditing)
              ? () {
                  if (!(_formKey.currentState?.validate() ?? false)) return;
                  final selectedRole = _findSelectedRole(roles);
                  if (selectedRole == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Select a role')),
                    );
                    return;
                  }

                  final salaryAmount =
                      selectedRole.salaryType == SalaryType.salaryMonthly
                          ? double.tryParse(_salaryController.text.trim()) ?? 0
                          : null;

                  final organizationId =
                      context.read<EmployeesCubit>().organizationId;

                  // Convert to new structure with jobRoles
                  final jobRole = EmployeeJobRole(
                    jobRoleId: selectedRole.id,
                    jobRoleTitle: selectedRole.title,
                    assignedAt: DateTime.now(),
                    isPrimary: true,
                  );

                  // Convert SalaryType to WageType
                  WageType wageType = WageType.perMonth;
                  if (selectedRole.salaryType == SalaryType.wages) {
                    wageType = WageType.perMonth; // Default wages to perMonth
                  }

                  final wage = EmployeeWage(
                    type: wageType,
                    baseAmount: salaryAmount,
                  );

                  final employee = OrganizationEmployee(
                    id: widget.employee?.id ??
                        DateTime.now().millisecondsSinceEpoch.toString(),
                    organizationId:
                        widget.employee?.organizationId ?? organizationId,
                    name: _nameController.text.trim(),
                    jobRoleIds: [selectedRole.id],
                    jobRoles: {selectedRole.id: jobRole},
                    wage: wage,
                    openingBalance: widget.employee?.openingBalance ??
                        double.parse(_openingBalanceController.text.trim()),
                    currentBalance: widget.employee?.currentBalance ??
                        double.parse(_openingBalanceController.text.trim()),
                  );

                  if (widget.employee == null) {
                    context.read<EmployeesCubit>().createEmployee(employee);
                  } else {
                    context.read<EmployeesCubit>().updateEmployee(employee);
                  }
                  Navigator.of(context).pop();
                }
              : null,
          child: Text(isEditing ? 'Save' : 'Create'),
        ),
      ],
    );
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: AuthColors.surface,
      labelStyle:
          AppTypography.withColor(AppTypography.label, AuthColors.textSub),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusMD),
        borderSide: BorderSide.none,
      ),
    );
  }
}
