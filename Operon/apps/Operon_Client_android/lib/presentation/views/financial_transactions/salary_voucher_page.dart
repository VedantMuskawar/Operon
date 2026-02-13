import 'package:core_models/core_models.dart';
import 'package:core_ui/core_ui.dart';
import 'package:core_datasources/core_datasources.dart';
import 'package:dash_mobile/presentation/blocs/org_context/org_context_cubit.dart';
import 'package:dash_mobile/presentation/widgets/modern_page_header.dart';
import 'package:dash_mobile/shared/constants/app_spacing.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

/// Page that fetches a transaction by ID and shows the salary cash voucher view.
/// Route: /salary-voucher?transactionId=... or /salary-voucher/:transactionId
class SalaryVoucherPage extends StatefulWidget {
  const SalaryVoucherPage({super.key});

  @override
  State<SalaryVoucherPage> createState() => _SalaryVoucherPageState();
}

class _SalaryVoucherPageState extends State<SalaryVoucherPage> {
  Transaction? _transaction;
  bool _loading = true;
  String? _error;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final state = GoRouterState.of(context);
    final transactionId = state.uri.queryParameters['transactionId'] ??
        state.pathParameters['transactionId'];
    if (transactionId != null && transactionId.isNotEmpty) {
      _loadTransaction(transactionId);
    } else {
      setState(() {
        _loading = false;
        _error = 'Missing transaction ID';
      });
    }
  }

  Future<void> _loadTransaction(String transactionId) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final repo = context.read<TransactionsRepository>();
      final tx = await repo.getTransaction(transactionId);
      if (!mounted) return;
      if (tx == null) {
        setState(() {
          _loading = false;
          _error = 'Transaction not found';
        });
        return;
      }
      if (tx.category != TransactionCategory.salaryDebit) {
        setState(() {
          _loading = false;
          _error = 'Not a salary payment';
        });
        return;
      }
      setState(() {
        _transaction = tx;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final orgState = context.watch<OrganizationContextCubit>().state;
    final organizationName = orgState.organization?.name;

    return Scaffold(
      backgroundColor: AuthColors.background,
      appBar: const ModernPageHeader(
        title: 'Salary Voucher',
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.paddingXXL),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _error!,
                            style: const TextStyle(
                              color: AuthColors.textSub,
                              fontSize: 16,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: AppSpacing.paddingLG),
                          FilledButton(
                            onPressed: () => context.go('/financial-transactions'),
                            style: FilledButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              foregroundColor: AuthColors.primary,
                              shadowColor: Colors.transparent,
                              side: const BorderSide(color: AuthColors.primary),
                            ),
                            child: const Text('Back'),
                          ),
                        ],
                      ),
                    ),
                  )
                : _transaction != null
                    ? SingleChildScrollView(
                        padding: const EdgeInsets.all(AppSpacing.paddingLG),
                        child: Center(
                          child: CashVoucherView(
                            transaction: _transaction!,
                            organizationName: organizationName,
                          ),
                        ),
                      )
                    : const SizedBox.shrink(),
      ),
    );
  }
}
