import 'dart:io';
import 'dart:ui' as ui;

import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:operon_driver_android/data/services/dm_print_service.dart';
import 'package:operon_driver_android/presentation/widgets/delivery_memo_document.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Shows DM content as a native Flutter view first (no PDF until Print).
/// Share to WhatsApp uses PNG capture; Print generates PDF on demand.
class DmPrintDialog extends StatefulWidget {
  const DmPrintDialog({
    super.key,
    required this.dmPrintService,
    required this.organizationId,
    required this.dmData,
    required this.dmNumber,
  });

  final DmPrintService dmPrintService;
  final String organizationId;
  final Map<String, dynamic> dmData;
  final int dmNumber;

  static Future<void> show({
    required BuildContext context,
    required DmPrintService dmPrintService,
    required String organizationId,
    required Map<String, dynamic> dmData,
    required int dmNumber,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: AuthColors.background.withValues(alpha: 0.7),
      builder: (context) => DmPrintDialog(
        dmPrintService: dmPrintService,
        organizationId: organizationId,
        dmData: dmData,
        dmNumber: dmNumber,
      ),
    );
  }

  @override
  State<DmPrintDialog> createState() => _DmPrintDialogState();
}

class _DmPrintDialogState extends State<DmPrintDialog> {
  bool _isLoadingView = true;
  bool _hasError = false;
  String? _errorMessage;
  DmViewPayload? _payload;
  bool _isGeneratingPdf = false;
  final GlobalKey _repaintKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _loadViewData();
  }

  Future<void> _loadViewData() async {
    try {
      final payload = await widget.dmPrintService.loadDmViewData(
        organizationId: widget.organizationId,
        dmData: widget.dmData,
      );
      if (!mounted) return;
      setState(() {
        _payload = payload;
        _isLoadingView = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingView = false;
          _hasError = true;
          _errorMessage = e.toString();
        });
        DashSnackbar.show(
          context,
          message: 'Failed to load DM: $e',
          isError: true,
        );
      }
    }
  }

  Future<void> _shareAsPng() async {
    final boundary =
        _repaintKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) {
      if (mounted) {
        DashSnackbar.show(
          context,
          message: 'Could not capture document',
          isError: true,
        );
      }
      return;
    }
    try {
      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null || !mounted) return;
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/DM-${widget.dmNumber}.png');
      await file.writeAsBytes(byteData.buffer.asUint8List());
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path)],
          text: 'DM-${widget.dmNumber}',
        ),
      );
    } catch (e) {
      if (!mounted) return;
      DashSnackbar.show(
        context,
        message: 'Failed to share: $e',
        isError: true,
      );
    }
  }

  Future<void> _onPrint() async {
    if (_isGeneratingPdf) return;
    setState(() => _isGeneratingPdf = true);
    try {
      await widget.dmPrintService.printDeliveryMemo(
        dmNumber: widget.dmNumber,
        organizationId: widget.organizationId,
        dmData: widget.dmData,
      );
      if (!mounted) return;
      Navigator.of(context).pop();
      DashSnackbar.show(context, message: 'Print preview opened');
    } catch (e) {
      if (!mounted) return;
      DashSnackbar.show(
        context,
        message: 'Failed to print: $e',
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() => _isGeneratingPdf = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final bottomSheetHeight = screenHeight * 0.92;

    return Container(
      height: bottomSheetHeight,
      decoration: const BoxDecoration(
        color: AuthColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AuthColors.textMainWithOpacity(0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.paddingXL),
                child: Column(
                  children: [
                    if (_isLoadingView) ...[
                      const Spacer(),
                      const CircularProgressIndicator(color: AuthColors.info),
                      const SizedBox(height: AppSpacing.paddingXL),
                      Text(
                        'Loading DM-${widget.dmNumber}...',
                        style: const TextStyle(
                          color: AuthColors.textMain,
                          fontSize: 16,
                        ),
                      ),
                      const Spacer(),
                    ] else if (_hasError) ...[
                      const Spacer(),
                      const Icon(Icons.error_outline,
                          color: AuthColors.error, size: 64),
                      const SizedBox(height: AppSpacing.paddingLG),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.paddingXL),
                        child: Text(
                          _errorMessage ?? 'Failed to load',
                          style: const TextStyle(
                            color: AuthColors.textSub,
                            fontSize: 14,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.paddingXL),
                      SizedBox(
                        width: double.infinity,
                        child: DashButton(
                          label: 'Close',
                          onPressed: () => Navigator.of(context).pop(),
                          variant: DashButtonVariant.outlined,
                        ),
                      ),
                      const Spacer(),
                    ] else if (_payload != null) ...[
                      Text(
                        'DM-${widget.dmNumber}',
                        style: const TextStyle(
                          color: AuthColors.textMain,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.paddingLG),
                      Expanded(
                        child: SingleChildScrollView(
                          child: Center(
                            child: ConstrainedBox(
                              constraints: BoxConstraints(
                                maxWidth: MediaQuery.sizeOf(context).width * 0.9,
                              ),
                              child: AspectRatio(
                                aspectRatio: 210 / 297,
                                child: RepaintBoundary(
                                  key: _repaintKey,
                                  child: DeliveryMemoDocument(
                                    dmData: widget.dmData,
                                    payload: _payload!,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      if (_isGeneratingPdf) ...[
                        const SizedBox(height: AppSpacing.paddingLG),
                        const CircularProgressIndicator(color: AuthColors.info),
                        const SizedBox(height: AppSpacing.paddingMD),
                        const Text(
                          'Preparing Document...',
                          style: TextStyle(
                            color: AuthColors.textSub,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.paddingLG),
                      ],
                      const SizedBox(height: AppSpacing.paddingLG),
                      Column(
                        children: [
                          DashButton(
                            label: 'Share',
                            icon: Icons.share_outlined,
                            onPressed:
                                _isGeneratingPdf ? null : _shareAsPng,
                            variant: DashButtonVariant.outlined,
                          ),
                          const SizedBox(height: AppSpacing.paddingMD),
                          DashButton(
                            label: 'Print',
                            icon: Icons.print_outlined,
                            onPressed: _isGeneratingPdf ? null : _onPrint,
                            isLoading: _isGeneratingPdf,
                          ),
                          const SizedBox(height: AppSpacing.paddingMD),
                          DashButton(
                            label: 'Close',
                            icon: Icons.close,
                            onPressed: () => Navigator.of(context).pop(),
                            variant: DashButtonVariant.outlined,
                          ),
                        ],
                      ),
                      SizedBox(
                        height: MediaQuery.of(context).viewInsets.bottom > 0
                            ? MediaQuery.of(context).viewInsets.bottom
                            : AppSpacing.paddingLG,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
