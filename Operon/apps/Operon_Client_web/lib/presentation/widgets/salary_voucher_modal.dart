import 'package:core_models/core_models.dart';
import 'package:core_ui/core_ui.dart';
import 'package:core_datasources/core_datasources.dart';
import 'package:dash_web/presentation/blocs/org_context/org_context_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Shows the salary voucher in a modal dialog.
/// Fetches the transaction by ID and displays CashVoucherView.
Future<void> showSalaryVoucherModal(BuildContext context, String transactionId) async {
  Transaction? transaction;
  bool loading = true;
  String? error;

  // Fetch transaction
  try {
    final repo = context.read<TransactionsRepository>();
    final tx = await repo.getTransaction(transactionId);
    if (tx == null) {
      error = 'Transaction not found';
      loading = false;
    } else if (tx.category != TransactionCategory.salaryDebit) {
      error = 'Not a salary payment';
      loading = false;
    } else {
      transaction = tx;
      loading = false;
    }
  } catch (e) {
    error = e.toString();
    loading = false;
  }

  if (!context.mounted) return;

  final orgState = context.read<OrganizationContextCubit>().state;
  final organizationName = orgState.organization?.name;

  return showDialog(
    context: context,
    barrierDismissible: true,
    builder: (dialogContext) => Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 600, maxHeight: 800),
        decoration: BoxDecoration(
          color: AuthColors.surface,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header with close button
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Salary Voucher',
                    style: TextStyle(
                      color: AuthColors.textMain,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: AuthColors.textSub),
                    onPressed: () => Navigator.of(dialogContext).pop(),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            // Content
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: loading
                    ? const SizedBox(
                        height: 200,
                        child: Center(child: CircularProgressIndicator()),
                      )
                    : error != null
                        ? SizedBox(
                            height: 200,
                            child: Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.error_outline,
                                      size: 48, color: AuthColors.error),
                                  const SizedBox(height: 16),
                                  Text(
                                    error ?? 'Unknown error',
                                    style: const TextStyle(
                                      color: AuthColors.textSub,
                                      fontSize: 14,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            ),
                          )
                        : transaction != null
                            ? CashVoucherView(
                                transaction: transaction,
                                organizationName: organizationName,
                              )
                            : const SizedBox.shrink(),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
