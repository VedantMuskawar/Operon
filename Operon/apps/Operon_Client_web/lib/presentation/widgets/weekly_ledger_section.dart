import 'dart:ui' as ui;

import 'package:core_bloc/core_bloc.dart';
import 'package:core_ui/core_ui.dart';
import 'package:dash_web/presentation/blocs/weekly_ledger/weekly_ledger_cubit.dart';
import 'package:dash_web/presentation/blocs/weekly_ledger/weekly_ledger_state.dart';
import 'package:dash_web/presentation/widgets/weekly_ledger_table.dart';
import 'package:dash_web/presentation/widgets/weekly_ledger_week_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'weekly_ledger_excel_generator.dart';
import 'weekly_ledger_pdf_generator.dart';

/// Section containing Weekly Ledger table, Generate button, Share PNG, Print PDF and Export Excel.
class WeeklyLedgerActionController {
  WeeklyLedgerActionController();

  final GlobalKey repaintKey = GlobalKey();
  final ValueNotifier<bool> isGeneratingPdf = ValueNotifier(false);

  Future<void> shareAsPng(BuildContext context) async {
    final boundary = repaintKey.currentContext?.findRenderObject()
        as RenderRepaintBoundary?;
    if (boundary == null) {
      if (context.mounted) {
        DashSnackbar.show(context, message: 'Could not capture table', isError: true);
      }
      return;
    }
    try {
      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null || !context.mounted) return;
      final bytes = byteData.buffer.asUint8List();
      final name = 'weekly-ledger-${DateTime.now().millisecondsSinceEpoch}.png';
      await Share.shareXFiles(
        [XFile.fromData(bytes, name: name, mimeType: 'image/png')],
        text: 'Weekly Ledger',
      );
    } catch (e) {
      if (context.mounted) {
        DashSnackbar.show(context, message: 'Failed to share: $e', isError: true);
      }
    }
  }

  Future<void> printPdf(BuildContext context, WeeklyLedgerState state) async {
    if (!state.hasData) return;
    if (isGeneratingPdf.value) return;
    isGeneratingPdf.value = true;
    try {
      final pdf = await WeeklyLedgerPdfGenerator.generate(
        weekStart: state.weekStart!,
        weekEnd: state.weekEnd!,
        productionEntries: state.productionEntries,
        tripEntries: state.tripEntries,
        debitByEmployeeId: state.debitByEmployeeId,
        currentBalanceByEmployeeId: state.currentBalanceByEmployeeId,
      );
      final pdfBytes = await pdf.save();
      isGeneratingPdf.value = false;
      await Printing.layoutPdf(
        onLayout: (_) => Future.value(pdfBytes),
        name: 'weekly-ledger-${state.weekStart!.year}-${state.weekStart!.month}-${state.weekStart!.day}.pdf',
      );
      if (context.mounted) {
        DashSnackbar.show(context, message: 'PDF ready to print');
      }
    } catch (e) {
      isGeneratingPdf.value = false;
      if (context.mounted) {
        DashSnackbar.show(context, message: 'Failed to generate PDF: $e', isError: true);
      }
    }
  }

  Future<void> exportExcel(BuildContext context, WeeklyLedgerState state) async {
    if (!state.hasData) return;
    try {
      await WeeklyLedgerExcelGenerator.export(
        weekStart: state.weekStart!,
        weekEnd: state.weekEnd!,
        productionEntries: state.productionEntries,
        tripEntries: state.tripEntries,
        debitByEmployeeId: state.debitByEmployeeId,
        currentBalanceByEmployeeId: state.currentBalanceByEmployeeId,
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

class WeeklyLedgerSection extends StatefulWidget {
  const WeeklyLedgerSection({
    super.key,
    required this.organizationId,
    required this.weeklyLedgerCubit,
    this.actionsController,
    this.showActionsRow = true,
  });

  final String organizationId;
  final WeeklyLedgerCubit weeklyLedgerCubit;
  final WeeklyLedgerActionController? actionsController;
  final bool showActionsRow;

  @override
  State<WeeklyLedgerSection> createState() => _WeeklyLedgerSectionState();
}

class _WeeklyLedgerSectionState extends State<WeeklyLedgerSection> {
  late final WeeklyLedgerActionController _defaultActions;

  @override
  void initState() {
    super.initState();
    if (widget.actionsController == null) {
      _defaultActions = WeeklyLedgerActionController();
    }
  }

  WeeklyLedgerActionController get _actions => widget.actionsController ?? _defaultActions;

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: widget.weeklyLedgerCubit,
      child: BlocBuilder<WeeklyLedgerCubit, WeeklyLedgerState>(
        builder: (context, state) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (widget.showActionsRow)
                ValueListenableBuilder<bool>(
                  valueListenable: _actions.isGeneratingPdf,
                  builder: (context, isGeneratingPdf, _) {
                    return SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
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
                              icon: Icons.share,
                              label: 'Share',
                              variant: DashButtonVariant.outlined,
                              onPressed: isGeneratingPdf ? null : () => _actions.shareAsPng(context),
                            ),
                            const SizedBox(width: 12),
                            DashButton(
                              icon: Icons.picture_as_pdf,
                              label: 'Print PDF',
                              variant: DashButtonVariant.outlined,
                              onPressed: isGeneratingPdf ? null : () => _actions.printPdf(context, state),
                            ),
                            const SizedBox(width: 12),
                            DashButton(
                              icon: Icons.table_chart,
                              label: 'Export Excel',
                              variant: DashButtonVariant.outlined,
                              onPressed: () => _actions.exportExcel(context, state),
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                ),
              if (state.message != null && state.status == ViewStatus.failure) ...[
                const SizedBox(height: 12),
                Text(
                  state.message!,
                  style: const TextStyle(color: AuthColors.error, fontSize: 13),
                ),
              ],
              ValueListenableBuilder<bool>(
                valueListenable: _actions.isGeneratingPdf,
                builder: (context, isGeneratingPdf, _) =>
                    isGeneratingPdf ? const LinearProgressIndicator(color: AuthColors.info) : const SizedBox.shrink(),
              ),
              const SizedBox(height: 20),
              if (state.status == ViewStatus.loading)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: CircularProgressIndicator(color: AuthColors.info),
                  ),
                )
              else
                RepaintBoundary(
                  key: _actions.repaintKey,
                  child: WeeklyLedgerTable(
                    productionEntries: state.productionEntries,
                    tripEntries: state.tripEntries,
                    debitByEmployeeId: state.debitByEmployeeId,
                    currentBalanceByEmployeeId: state.currentBalanceByEmployeeId,
                  ),
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

}
