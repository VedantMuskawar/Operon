import 'dart:typed_data';

import 'package:core_datasources/core_datasources.dart';
import 'package:core_models/core_models.dart';
import 'package:core_ui/core_ui.dart' show AuthColors, DashButton, DashButtonVariant, DashCard, DashSnackbar;
import 'package:core_ui/core_ui.dart' show showLedgerDateRangeModal;
import 'package:core_utils/core_utils.dart' show calculateOpeningBalance, LedgerRowData;
import 'package:dash_web/presentation/widgets/ledger_preview_dialog.dart';
import 'package:dash_web/data/repositories/dm_settings_repository.dart';
import 'package:dash_web/data/repositories/employees_repository.dart';
import 'package:dash_web/data/utils/financial_year_utils.dart';
import 'package:dash_web/domain/entities/organization_employee.dart';
import 'package:dash_web/domain/entities/wage_type.dart';
import 'package:dash_web/presentation/blocs/org_context/org_context_cubit.dart';
import 'package:dash_web/presentation/widgets/detail_modal_base.dart';
import 'package:dash_web/presentation/widgets/salary_voucher_modal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;

/// Modal dialog for displaying employee details
class EmployeeDetailModal extends StatefulWidget {
  const EmployeeDetailModal({
    super.key,
    required this.employee,
    this.onEmployeeChanged,
    this.onEdit,
  });

  final OrganizationEmployee employee;
  final ValueChanged<OrganizationEmployee>? onEmployeeChanged;
  final VoidCallback? onEdit;

  @override
  State<EmployeeDetailModal> createState() => _EmployeeDetailModalState();
}

class _EmployeeDetailModalState extends State<EmployeeDetailModal> {

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => _DeleteEmployeeDialog(
        employeeName: widget.employee.name,
      ),
    );

    if (confirmed == true && mounted) {
      try {
        final repository = context.read<EmployeesRepository>();
        await repository.deleteEmployee(widget.employee.id);
        if (!mounted) return;
        DashSnackbar.show(context, message: 'Employee deleted.', isError: false);
        Navigator.of(context).pop();
      } catch (error) {
        if (!mounted) return;
        DashSnackbar.show(context, message: 'Unable to delete employee: $error', isError: true);
      }
    }
  }

  void _editEmployee() {
    if (widget.onEdit != null) {
      Navigator.of(context).pop();
      widget.onEdit!();
    }
  }

  Color _getRoleColor(String? roleTitle) {
    if (roleTitle == null || roleTitle.isEmpty) return const Color(0xFF6F4BFF);
    final hash = roleTitle.hashCode;
    final colors = [
      const Color(0xFF6F4BFF),
      const Color(0xFF5AD8A4),
      const Color(0xFFFF9800),
      const Color(0xFF2196F3),
      const Color(0xFFE91E63),
    ];
    return colors[hash.abs() % colors.length];
  }

  String _getInitials(String name) {
    final parts = name.split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.length >= 2 ? name.substring(0, 2).toUpperCase() : name.toUpperCase();
  }

  String _getWageTypeDisplayName(WageType type) {
    switch (type) {
      case WageType.perMonth:
        return 'Per Month';
      case WageType.perTrip:
        return 'Per Trip';
      case WageType.perBatch:
        return 'Per Batch';
      case WageType.perHour:
        return 'Per Hour';
      case WageType.perKm:
        return 'Per Kilometer';
      case WageType.commission:
        return 'Commission';
      case WageType.hybrid:
        return 'Hybrid';
    }
  }

  @override
  Widget build(BuildContext context) {
    final roleColor = _getRoleColor(widget.employee.primaryJobRoleTitle);
    
    return DetailModalBase(
      onClose: () => Navigator.of(context).pop(),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          _ModalHeader(
            employee: widget.employee,
            roleColor: roleColor,
            onClose: () => Navigator.of(context).pop(),
            onEdit: _editEmployee,
            onDelete: _confirmDelete,
            getInitials: _getInitials,
          ),

          // Content (no tabs - only Ledger section)
          Expanded(
            child: _TransactionsSection(employee: widget.employee),
          ),
        ],
      ),
    );
  }
}

class _ModalHeader extends StatelessWidget {
  const _ModalHeader({
    required this.employee,
    required this.roleColor,
    required this.onClose,
    required this.onEdit,
    required this.onDelete,
    required this.getInitials,
  });

  final OrganizationEmployee employee;
  final Color roleColor;
  final VoidCallback onClose;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final String Function(String) getInitials;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            roleColor.withOpacity(0.3),
            const Color(0xFF1B1B2C),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border(
          bottom: BorderSide(
            color: Colors.white.withOpacity(0.1),
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      roleColor,
                      roleColor.withOpacity(0.7),
                    ],
                  ),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    getInitials(employee.name),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 18,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      employee.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        if (employee.primaryJobRoleTitle.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: roleColor.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: roleColor.withOpacity(0.3),
                              ),
                            ),
                            child: Text(
                              employee.primaryJobRoleTitle,
                              style: TextStyle(
                                color: roleColor,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white70),
                onPressed: onClose,
                tooltip: 'Close',
              ),
              IconButton(
                icon: const Icon(Icons.edit, color: Colors.white70),
                onPressed: onEdit,
                tooltip: 'Edit',
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.white70),
                onPressed: onDelete,
                tooltip: 'Delete',
              ),
            ],
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
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: isSelected
                  ? const Color(0xFF6F4BFF)
                  : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.white70,
            fontSize: 14,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

class _OverviewSection extends StatelessWidget {
  const _OverviewSection({
    required this.employee,
    required this.roleColor,
    required this.balanceDifference,
    required this.isPositive,
    required this.getWageTypeDisplayName,
  });

  final OrganizationEmployee employee;
  final Color roleColor;
  final double balanceDifference;
  final bool isPositive;
  final String Function(WageType) getWageTypeDisplayName;

  String _formatCurrency(double amount) {
    return '₹${amount.toStringAsFixed(2).replaceAllMapped(
          RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]},',
        )}';
  }

  @override
  Widget build(BuildContext context) {
    final percentChange = employee.openingBalance != 0
        ? (balanceDifference / employee.openingBalance * 100)
        : 0.0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Current Balance Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isPositive
                    ? [
                        const Color(0xFF4CAF50).withOpacity(0.2),
                        const Color(0xFF4CAF50).withOpacity(0.05),
                      ]
                    : [
                        const Color(0xFFEF5350).withOpacity(0.2),
                        const Color(0xFFEF5350).withOpacity(0.05),
                      ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: (isPositive ? const Color(0xFF4CAF50) : const Color(0xFFEF5350))
                    .withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Current Balance',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _formatCurrency(employee.currentBalance),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      isPositive ? Icons.trending_up : Icons.trending_down,
                      size: 16,
                      color: isPositive ? const Color(0xFF4CAF50) : const Color(0xFFEF5350),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${isPositive ? '+' : ''}${_formatCurrency(balanceDifference.abs())} from opening',
                      style: TextStyle(
                        color: isPositive ? const Color(0xFF4CAF50) : const Color(0xFFEF5350),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (employee.openingBalance != 0) ...[
                      const SizedBox(width: 8),
                      Text(
                        '(${isPositive ? '+' : ''}${percentChange.abs().toStringAsFixed(1)}%)',
                        style: TextStyle(
                          color: isPositive ? const Color(0xFF4CAF50) : const Color(0xFFEF5350),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Financial Summary Cards
          Row(
            children: [
              Expanded(
                child: _SummaryCard(
                  label: 'Opening Balance',
                  value: _formatCurrency(employee.openingBalance),
                  color: AuthColors.info,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _SummaryCard(
                  label: 'Net Change',
                  value: '${isPositive ? '+' : ''}${_formatCurrency(balanceDifference.abs())}',
                  color: isPositive ? AuthColors.success : AuthColors.error,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Wage Information
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF131324),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.white.withOpacity(0.1),
                width: 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Wage Information',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(
                      Icons.account_balance_wallet_outlined,
                      size: 20,
                      color: Colors.white.withOpacity(0.7),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            getWageTypeDisplayName(employee.wage.type),
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            employee.wage.baseAmount != null || employee.wage.rate != null
                                ? '₹${(employee.wage.baseAmount ?? employee.wage.rate ?? 0).toStringAsFixed(2)}'
                                : 'Not set',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Job Roles
          if (employee.jobRoles.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF131324),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.white.withOpacity(0.1),
                  width: 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Job Roles',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: employee.jobRoles.values.map((jobRole) {
                      final isPrimary = jobRole.isPrimary;
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: isPrimary
                              ? roleColor.withOpacity(0.2)
                              : Colors.white.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isPrimary
                                ? roleColor.withOpacity(0.3)
                                : Colors.white.withOpacity(0.1),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              jobRole.jobRoleTitle,
                              style: TextStyle(
                                color: isPrimary ? roleColor : Colors.white70,
                                fontSize: 12,
                                fontWeight: isPrimary ? FontWeight.w600 : FontWeight.w500,
                              ),
                            ),
                            if (isPrimary) ...[
                              const SizedBox(width: 6),
                              Icon(
                                Icons.star,
                                size: 14,
                                color: roleColor,
                              ),
                            ],
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return DashCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: AuthColors.textSub,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
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
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(20),
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
                transactionsSnapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(
                  color: AuthColors.primary,
                ),
              );
            }

            if (ledgerSnapshot.hasError || transactionsSnapshot.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.error_outline,
                        size: 48,
                        color: AuthColors.error,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Failed to load ledger: ${ledgerSnapshot.error ?? transactionsSnapshot.error}',
                        style: TextStyle(
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
              padding: const EdgeInsets.all(20),
              child: _LedgerTable(
                openingBalance: widget.employee.openingBalance,
                transactions: transactions,
                formatCurrency: _formatCurrency,
                formatDate: _formatDate,
                employeeId: widget.employee.id,
                employeeName: widget.employee.name,
                storedOpeningBalance: widget.employee.openingBalance,
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
      .map((word) => word.isEmpty ? '' : word[0].toUpperCase() + word.substring(1).toLowerCase())
      .join(' ')
      .trim();
}

class _LedgerTable extends StatelessWidget {
  const _LedgerTable({
    required this.openingBalance,
    required this.transactions,
    required this.formatCurrency,
    required this.formatDate,
    required this.employeeId,
    required this.employeeName,
    required this.storedOpeningBalance,
  });

  final double openingBalance;
  final List<Map<String, dynamic>> transactions;
  final String Function(double) formatCurrency;
  final String Function(dynamic) formatDate;
  final String employeeId;
  final String employeeName;
  final double storedOpeningBalance;

  Future<void> _generateLedgerPdf(BuildContext context) async {
    try {
      // Show date range picker
      final dateRange = await showLedgerDateRangeModal(context);
      if (dateRange == null) return; // User cancelled

      // Show loading indicator
      if (!context.mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      // Get organization ID
      final orgContext = context.read<OrganizationContextCubit>().state;
      final organization = orgContext.organization;
      if (organization == null || !context.mounted) {
        Navigator.of(context).pop(); // Close loading
        DashSnackbar.show(context, message: 'No organization selected', isError: true);
        return;
      }

      // Fetch all transactions for opening balance calculation
      final employeeWagesDataSource = EmployeeWagesDataSource();
      final financialYear = FinancialYearUtils.getCurrentFinancialYear();
      final allTransactions = await employeeWagesDataSource.fetchEmployeeTransactions(
        organizationId: organization.id,
        employeeId: employeeId,
        financialYear: financialYear,
      );

      // Calculate opening balance for date range
      // Use stored opening balance if no transactions before start date
      final openingBal = calculateOpeningBalance(
        allTransactions: allTransactions,
        startDate: dateRange.start,
        storedOpeningBalance: storedOpeningBalance,
      );

      // Filter transactions in date range
      final transactionsInRange = allTransactions.where((tx) {
        final txDate = tx.createdAt ?? tx.updatedAt;
        if (txDate == null) return false;
        return txDate.isAfter(dateRange.start.subtract(const Duration(days: 1))) &&
               txDate.isBefore(dateRange.end.add(const Duration(days: 1)));
      }).toList();

      // Sort chronologically
      transactionsInRange.sort((a, b) {
        final aDate = a.createdAt ?? a.updatedAt ?? DateTime(1970);
        final bDate = b.createdAt ?? b.updatedAt ?? DateTime(1970);
        return aDate.compareTo(bDate);
      });

      // Convert to LedgerRowData
      double runningBalance = openingBal;
      final ledgerRows = <LedgerRowData>[];
      
      for (final tx in transactionsInRange) {
        final txDate = tx.createdAt ?? tx.updatedAt ?? DateTime.now();
        final type = tx.type;
        final amount = tx.amount;
        final description = tx.description ?? '';

        // Calculate debit/credit
        double debit = 0.0;
        double credit = 0.0;
        if (type == TransactionType.credit) {
          credit = amount;
          runningBalance += amount;
        } else if (type == TransactionType.debit) {
          debit = amount;
          runningBalance -= amount;
        }

        // Get reference (Batch/Trip from description for employee)
        final reference = description.isNotEmpty ? description : '-';

        // Get type name
        final typeName = _formatCategoryName(tx.category.name);

        ledgerRows.add(LedgerRowData(
          date: txDate,
          reference: reference,
          debit: debit,
          credit: credit,
          balance: runningBalance,
          type: typeName,
          remarks: '-',
        ));
      }

      // Fetch DM settings for company header
      final dmSettingsRepo = context.read<DmSettingsRepository>();
      final dmSettings = await dmSettingsRepo.fetchDmSettings(organization.id);
      if (dmSettings == null || !context.mounted) {
        Navigator.of(context).pop(); // Close loading
        DashSnackbar.show(context, message: 'DM settings not found. Please configure DM settings first.', isError: true);
        return;
      }

      // Load logo if available
      Uint8List? logoBytes;
      if (dmSettings.header.logoImageUrl != null && dmSettings.header.logoImageUrl!.isNotEmpty) {
        try {
          final logoUrl = dmSettings.header.logoImageUrl!;
          final response = await http.get(Uri.parse(logoUrl));
          if (response.statusCode == 200) {
            logoBytes = response.bodyBytes;
          }
        } catch (e) {
          // Logo loading failed, continue without it
        }
      }

      // Close loading dialog and show ledger view (view first; Print generates PDF)
      if (!context.mounted) return;
      Navigator.of(context).pop();

      await showDialog<void>(
        context: context,
        builder: (context) => LedgerPreviewDialog(
          ledgerType: LedgerType.employeeLedger,
          entityName: employeeName,
          transactions: ledgerRows,
          openingBalance: openingBal,
          companyHeader: dmSettings.header,
          startDate: dateRange.start,
          endDate: dateRange.end,
          logoBytes: logoBytes,
          title: 'Ledger of $employeeName',
        ),
      );
    } catch (e) {
      if (context.mounted) {
        Navigator.of(context).pop(); // Close loading if still open
        DashSnackbar.show(context, message: 'Failed to generate ledger PDF: $e', isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    var totalDebit = 0.0;
    var totalCredit = 0.0;
    for (final tx in transactions) {
      final type = (tx['type'] as String? ?? 'credit').toLowerCase();
      final amount = (tx['amount'] as num?)?.toDouble() ?? 0.0;
      final isCredit = type == 'credit';
      if (isCredit) {
        totalCredit += amount;
      } else {
        totalDebit += amount;
      }
    }

    if (transactions.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Ledger',
            style: TextStyle(
              color: AuthColors.textMain,
              fontSize: 15,
              fontWeight: FontWeight.w600,
              fontFamily: 'SF Pro Display',
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'No transactions found.',
            style: TextStyle(color: AuthColors.textSub, fontSize: 13, fontFamily: 'SF Pro Display'),
          ),
          const SizedBox(height: 20),
          _LedgerSummaryFooter(
            openingBalance: openingBalance,
            totalDebit: 0,
            totalCredit: 0,
            formatCurrency: formatCurrency,
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Ledger',
              style: TextStyle(
                color: AuthColors.textMain,
                fontSize: 15,
                fontWeight: FontWeight.w600,
                fontFamily: 'SF Pro Display',
              ),
            ),
            DashButton(
              label: 'Generate Ledger',
              icon: Icons.picture_as_pdf,
              onPressed: () => _generateLedgerPdf(context),
              variant: DashButtonVariant.text,
            ),
          ],
        ),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(
            color: AuthColors.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AuthColors.textMainWithOpacity(0.1), width: 1),
          ),
          child: Column(
            children: [
              _LedgerTableHeader(),
              Divider(height: 1, color: AuthColors.textMain.withOpacity(0.12)),
              ...transactions.map((tx) {
                final type = tx['type'] as String? ?? 'credit';
                final amount = (tx['amount'] as num?)?.toDouble() ?? 0.0;
                final balanceAfter = (tx['balanceAfter'] as num?)?.toDouble() ?? 0.0;
                final date = tx['transactionDate'] ?? tx['createdAt'];
                final desc = (tx['description'] as String?)?.trim();
                final batchTrip = (desc != null && desc.isNotEmpty) ? desc : '-';
                final category = tx['category'] as String?;
                final isCredit = type == 'credit';
                final credit = isCredit ? amount : 0.0;
                final debit = !isCredit ? amount : 0.0;
                final txId = tx['transactionId'] as String? ?? tx['id'] as String?;
                final metadata = tx['metadata'] as Map<String, dynamic>?;
                final voucherUrl = metadata?['cashVoucherPhotoUrl']?.toString();
                final showVoucher = category == 'salaryDebit' &&
                    txId != null &&
                    txId.isNotEmpty &&
                    voucherUrl != null &&
                    voucherUrl.isNotEmpty;

                return _LedgerTableRow(
                  date: date,
                  batchTrip: batchTrip,
                  debit: debit,
                  credit: credit,
                  balance: balanceAfter,
                  type: _formatCategoryName(category),
                  remarks: '-',
                  formatCurrency: formatCurrency,
                  formatDate: formatDate,
                  transactionId: txId,
                  showVoucher: showVoucher,
                );
              }),
            ],
          ),
        ),
        const SizedBox(height: 20),
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
  static const _labelStyle = TextStyle(
    color: AuthColors.textSub,
    fontSize: 13,
    fontFamily: 'SF Pro Display',
  );
  static final _cellBorder = Border(
    right: BorderSide(color: AuthColors.textMain.withOpacity(0.12), width: 1),
  );

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(flex: 1, child: _borderedCell('Date')),
        Expanded(flex: 1, child: _borderedCell('Batch/Trip')),
        Expanded(flex: 1, child: _borderedCell('Debit')),
        Expanded(flex: 1, child: _borderedCell('Credit')),
        Expanded(flex: 1, child: _borderedCell('Balance')),
        Expanded(flex: 1, child: _borderedCell('Type')),
        Expanded(
          flex: 2,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
            alignment: Alignment.center,
            child: Text('Remarks', style: _labelStyle, textAlign: TextAlign.center),
          ),
        ),
      ],
    );
  }

  Widget _borderedCell(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(border: _cellBorder),
      alignment: Alignment.center,
      child: Text(label, style: _labelStyle, textAlign: TextAlign.center),
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

  static const _cellStyle = TextStyle(
    color: AuthColors.textMain,
    fontSize: 13,
    fontFamily: 'SF Pro Display',
  );
  static final _cellBorder = Border(
    right: BorderSide(color: AuthColors.textMain.withOpacity(0.12), width: 1),
  );

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(flex: 1, child: _cell(Text(formatDate(date), style: _cellStyle, textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis))),
        Expanded(flex: 1, child: _cell(Text(batchTrip, style: _cellStyle, textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis))),
        Expanded(flex: 1, child: _cell(Text(debit > 0 ? formatCurrency(debit) : '-', style: _cellStyle, textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis))),
        Expanded(flex: 1, child: _cell(Text(credit > 0 ? formatCurrency(credit) : '-', style: _cellStyle, textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis))),
        Expanded(flex: 1, child: _cell(Text(formatCurrency(balance), style: _cellStyle.copyWith(color: balance >= 0 ? AuthColors.warning : AuthColors.success, fontWeight: FontWeight.w600), textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis))),
        Expanded(flex: 1, child: _cell(Text(type.isEmpty ? '-' : type, style: _cellStyle, textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis))),
        Expanded(
          flex: 2,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            alignment: Alignment.center,
            child: showVoucher && transactionId != null
                ? TextButton(
                    onPressed: () => showSalaryVoucherModal(context, transactionId!),
                    style: TextButton.styleFrom(
                      foregroundColor: AuthColors.primary,
                      padding: EdgeInsets.zero,
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text('View voucher', style: TextStyle(fontSize: 12)),
                  )
                : Text(remarks, style: _cellStyle, textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
        ),
      ],
    );
  }

  Widget _cell(Widget child) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(border: _cellBorder),
      alignment: Alignment.center,
      child: child,
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

  static const _footerLabelStyle = TextStyle(
    color: AuthColors.textSub,
    fontSize: 13,
    fontFamily: 'SF Pro Display',
  );
  static const _footerValueStyle = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w600,
    fontFamily: 'SF Pro Display',
  );

  @override
  Widget build(BuildContext context) {
    final currentBalance = openingBalance + totalCredit - totalDebit;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AuthColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AuthColors.textMainWithOpacity(0.1), width: 1),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Opening Balance', style: _footerLabelStyle, textAlign: TextAlign.center),
              const SizedBox(height: 4),
              Text(formatCurrency(openingBalance), style: _footerValueStyle.copyWith(color: AuthColors.info), textAlign: TextAlign.center),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Total Debit', style: _footerLabelStyle, textAlign: TextAlign.center),
              const SizedBox(height: 4),
              Text(formatCurrency(totalDebit), style: _footerValueStyle.copyWith(color: AuthColors.info), textAlign: TextAlign.center),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Total Credit', style: _footerLabelStyle, textAlign: TextAlign.center),
              const SizedBox(height: 4),
              Text(formatCurrency(totalCredit), style: _footerValueStyle.copyWith(color: AuthColors.info), textAlign: TextAlign.center),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Current Balance', style: _footerLabelStyle, textAlign: TextAlign.center),
              const SizedBox(height: 4),
              Text(formatCurrency(currentBalance), style: _footerValueStyle.copyWith(color: AuthColors.success), textAlign: TextAlign.center),
            ],
          ),
        ],
      ),
    );
  }
}

class _DeleteEmployeeDialog extends StatelessWidget {
  const _DeleteEmployeeDialog({required this.employeeName});

  final String employeeName;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF1B1B2C),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(28),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Delete employee',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'This will permanently remove $employeeName and all related data. This action cannot be undone.',
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: DashButton(
                label: 'Delete employee',
                onPressed: () => Navigator.pop(context, true),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: DashButton(
                label: 'Cancel',
                onPressed: () => Navigator.pop(context, false),
                variant: DashButtonVariant.text,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

