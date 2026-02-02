import 'package:core_bloc/core_bloc.dart';
import 'package:core_ui/core_ui.dart';
import 'package:dash_web/presentation/blocs/weekly_ledger/weekly_ledger_cubit.dart';
import 'package:dash_web/presentation/blocs/weekly_ledger/weekly_ledger_state.dart';
import 'package:dash_web/presentation/widgets/weekly_ledger_table.dart';
import 'package:dash_web/presentation/widgets/weekly_ledger_week_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:printing/printing.dart';
import 'weekly_ledger_excel_generator.dart';
import 'weekly_ledger_pdf_generator.dart';

/// Section containing Weekly Ledger table, Generate button, Print PDF and Export Excel.
class WeeklyLedgerSection extends StatelessWidget {
  const WeeklyLedgerSection({
    super.key,
    required this.organizationId,
    required this.weeklyLedgerCubit,
  });

  final String organizationId;
  final WeeklyLedgerCubit weeklyLedgerCubit;

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: weeklyLedgerCubit,
      child: BlocBuilder<WeeklyLedgerCubit, WeeklyLedgerState>(
        builder: (context, state) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  DashButton(
                    icon: Icons.calendar_month,
                    label: 'Generate Weekly Ledger',
                    onPressed: state.status == ViewStatus.loading
                        ? null
                        : () => _openWeekDialog(context),
                  ),
                  if (state.hasData) ...[
                    const SizedBox(width: 12),
                    DashButton(
                      icon: Icons.picture_as_pdf,
                      label: 'Print PDF',
                      variant: DashButtonVariant.outlined,
                      onPressed: () => _printPdf(context, state),
                    ),
                    const SizedBox(width: 12),
                    DashButton(
                      icon: Icons.table_chart,
                      label: 'Export Excel',
                      variant: DashButtonVariant.outlined,
                      onPressed: () => _exportExcel(context, state),
                    ),
                  ],
                ],
              ),
              if (state.message != null && state.status == ViewStatus.failure) ...[
                const SizedBox(height: 12),
                Text(
                  state.message!,
                  style: const TextStyle(color: AuthColors.error, fontSize: 13),
                ),
              ],
              const SizedBox(height: 20),
              if (state.status == ViewStatus.loading)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: CircularProgressIndicator(color: AuthColors.info),
                  ),
                )
              else
                WeeklyLedgerTable(
                  productionEntries: state.productionEntries,
                  tripEntries: state.tripEntries,
                ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _openWeekDialog(BuildContext context) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => const WeeklyLedgerWeekDialog(),
    );
    if (result != null && context.mounted) {
      final weekStart = result['weekStart'] as DateTime?;
      final weekEnd = result['weekEnd'] as DateTime?;
      if (weekStart != null && weekEnd != null) {
        context.read<WeeklyLedgerCubit>().loadWeeklyLedger(weekStart, weekEnd);
      }
    }
  }

  Future<void> _printPdf(BuildContext context, WeeklyLedgerState state) async {
    if (!state.hasData) return;
    try {
      final pdf = WeeklyLedgerPdfGenerator.generate(
        weekStart: state.weekStart!,
        weekEnd: state.weekEnd!,
        productionEntries: state.productionEntries,
        tripEntries: state.tripEntries,
      );
      await Printing.layoutPdf(
        onLayout: (_) => pdf.save(),
        name: 'weekly-ledger-${state.weekStart!.year}-${state.weekStart!.month}-${state.weekStart!.day}.pdf',
      );
      if (context.mounted) {
        DashSnackbar.show(context, message: 'PDF ready to print');
      }
    } catch (e) {
      if (context.mounted) {
        DashSnackbar.show(context, message: 'Failed to generate PDF: $e', isError: true);
      }
    }
  }

  Future<void> _exportExcel(BuildContext context, WeeklyLedgerState state) async {
    if (!state.hasData) return;
    try {
      await WeeklyLedgerExcelGenerator.export(
        weekStart: state.weekStart!,
        weekEnd: state.weekEnd!,
        productionEntries: state.productionEntries,
        tripEntries: state.tripEntries,
      );
      if (context.mounted) {
        DashSnackbar.show(context, message: 'Excel exported');
      }
    } catch (e) {
      if (context.mounted) {
        DashSnackbar.show(context, message: 'Failed to export Excel: $e', isError: true);
      }
    }
  }
}
