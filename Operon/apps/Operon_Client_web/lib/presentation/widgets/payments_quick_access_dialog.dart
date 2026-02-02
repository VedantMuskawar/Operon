import 'package:core_ui/core_ui.dart' show AuthColors;
import 'package:dash_web/presentation/widgets/record_payment_dialog.dart';
import 'package:dash_web/presentation/blocs/org_context/org_context_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class PaymentsQuickAccessDialog extends StatelessWidget {
  const PaymentsQuickAccessDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 400),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AuthColors.surface, AuthColors.background],
          ),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: AuthColors.textMainWithOpacity(0.1),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: AuthColors.background.withOpacity(0.5),
              blurRadius: 40,
              offset: const Offset(0, 20),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Payments',
                    style: TextStyle(
                      color: AuthColors.textMain,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: Icon(Icons.close, color: AuthColors.textSub),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            const SizedBox(height: 24),
            _PaymentOption(
              icon: Icons.receipt_long_outlined,
              title: 'View Transactions',
              description: 'Browse all payment transactions',
              color: AuthColors.success,
              onTap: () {
                Navigator.of(context).pop();
                context.go('/transactions');
              },
            ),
            const SizedBox(height: 16),
            _PaymentOption(
              icon: Icons.payment_outlined,
              title: 'Record Payment',
              description: 'Record a new client payment',
              color: AuthColors.accentPurple,
              onTap: () {
                Navigator.of(context).pop();
                showDialog(
                  context: context,
                  barrierColor: AuthColors.background.withOpacity(0.7),
                  builder: (dialogContext) => BlocProvider.value(
                    value: context.read<OrganizationContextCubit>(),
                    child: const RecordPaymentDialog(),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _PaymentOption extends StatefulWidget {
  const _PaymentOption({
    required this.icon,
    required this.title,
    required this.description,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String description;
  final Color color;
  final VoidCallback onTap;

  @override
  State<_PaymentOption> createState() => _PaymentOptionState();
}

class _PaymentOptionState extends State<_PaymentOption> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(16),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AuthColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: widget.color.withValues(
                  alpha: _isHovered ? 0.5 : 0.2,
                ),
                width: _isHovered ? 2 : 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: widget.color.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    widget.icon,
                    color: widget.color,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.title,
                        style: TextStyle(
                          color: AuthColors.textMain,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.description,
                        style: TextStyle(
                          color: AuthColors.textMainWithOpacity(0.6),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  color: AuthColors.textMainWithOpacity(0.4),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

