import 'package:core_models/core_models.dart';
import 'package:core_ui/core_ui.dart';
import 'package:core_datasources/core_datasources.dart';
import 'package:dash_web/presentation/blocs/org_context/org_context_cubit.dart';
import 'package:dash_web/presentation/widgets/section_workspace_layout.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

/// Page that fetches a transaction by ID and shows the salary cash voucher view.
/// Route: /salary-voucher?transactionId=...
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
    final transactionId = GoRouterState.of(context).uri.queryParameters['transactionId'];
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

    return SectionWorkspaceLayout(
      panelTitle: 'Salary Voucher',
      currentIndex: -1,
      onNavTap: (index) => context.go('/home?section=$index'),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(
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
                        const SizedBox(height: 16),
                        DashButton(
                          label: 'Back',
                          onPressed: () => context.go('/financial-transactions'),
                          variant: DashButtonVariant.outlined,
                        ),
                      ],
                    ),
                  )
                : _transaction != null
                    ? Center(
                        child: CashVoucherView(
                          transaction: _transaction!,
                          organizationName: organizationName,
                        ),
                      )
                    : const SizedBox.shrink(),
      ),
    );
  }
}
