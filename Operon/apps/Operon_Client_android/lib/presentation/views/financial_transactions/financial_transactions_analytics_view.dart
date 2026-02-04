import 'package:core_bloc/core_bloc.dart';
import 'package:core_ui/core_ui.dart';
import 'package:dash_mobile/presentation/blocs/financial_transactions/unified_financial_transactions_cubit.dart';
import 'package:dash_mobile/presentation/blocs/financial_transactions/unified_financial_transactions_state.dart';
import 'package:dash_mobile/shared/constants/app_spacing.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Analytics view for Financial Transactions (Android)
class FinancialTransactionsAnalyticsView extends StatelessWidget {
  const FinancialTransactionsAnalyticsView({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<UnifiedFinancialTransactionsCubit,
        UnifiedFinancialTransactionsState>(
      builder: (context, state) {
        if (state.status == ViewStatus.loading && 
            state.transactions.isEmpty && 
            state.purchases.isEmpty && 
            state.expenses.isEmpty) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.paddingLG),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Summary Cards
              TransactionSummaryCards(
                totalPayments: state.totalIncome,
                totalPurchases: state.totalPurchases,
                totalExpenses: state.totalExpenses,
              ),
              const SizedBox(height: AppSpacing.paddingXXL),
              // Analytics Section (can be expanded later)
              _buildAnalyticsSection(state),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAnalyticsSection(UnifiedFinancialTransactionsState state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Summary Statistics',
          style: TextStyle(
            color: AuthColors.textMain,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: AppSpacing.paddingLG),
        Container(
          padding: const EdgeInsets.all(AppSpacing.paddingLG),
          decoration: BoxDecoration(
            color: AuthColors.surface,
            borderRadius: BorderRadius.circular(AppSpacing.radiusMD),
            border: Border.all(
              color: AuthColors.textMainWithOpacity(0.1),
            ),
          ),
          child: Column(
            children: [
              _buildStatRow('Total Transactions', state.transactions.length),
              const Divider(color: AuthColors.textDisabled, height: 24),
              _buildStatRow('Total Purchases', state.purchases.length),
              const Divider(color: AuthColors.textDisabled, height: 24),
              _buildStatRow('Total Expenses', state.expenses.length),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatRow(String label, int value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AuthColors.textSub,
            fontSize: 14,
          ),
        ),
        Text(
          value.toString(),
          style: const TextStyle(
            color: AuthColors.textMain,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
