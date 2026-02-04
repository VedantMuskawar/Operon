import 'dart:convert';
import 'dart:html' as html;
import 'dart:typed_data';
import 'dart:ui_web' as ui_web;

import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';

/// Camera capture dialog that uses getUserMedia in the main document
/// so the browser prompts for camera permission. Returns JPEG bytes or null.
Future<Uint8List?> showCashVoucherCameraDialog(BuildContext context) async {
  return showDialog<Uint8List?>(
    context: context,
    barrierDismissible: false,
    builder: (context) => const _CashVoucherCameraDialog(),
  );
}

class _CashVoucherCameraDialog extends StatefulWidget {
  const _CashVoucherCameraDialog();

  @override
  State<_CashVoucherCameraDialog> createState() =>
      _CashVoucherCameraDialogState();
}

class _CashVoucherCameraDialogState extends State<_CashVoucherCameraDialog> {
  static int _instanceCount = 0;

  late final String _viewType;
  late final String _videoId;
  html.MediaStream? _stream;
  String? _errorMessage;
  bool _streamReady = false;

  @override
  void initState() {
    super.initState();
    _instanceCount++;
    _viewType = 'cash_voucher_camera_$_instanceCount';
    _videoId = 'cash_voucher_video_$_instanceCount';
    _registerView();
    WidgetsBinding.instance.addPostFrameCallback((_) => _startCamera());
  }

  void _registerView() {
    final videoId = _videoId;
    ui_web.platformViewRegistry.registerViewFactory(
      _viewType,
      (int viewId) {
        final container = html.DivElement()
          ..style.width = '100%'
          ..style.height = '100%'
          ..style.backgroundColor = '#000'
          ..style.objectFit = 'contain';
        final video = html.VideoElement()
          ..id = videoId
          ..autoplay = true
          ..muted = true
          ..style.width = '100%'
          ..style.height = '100%'
          ..style.objectFit = 'contain';
        video.setAttribute('playsinline', 'true');
        container.append(video);
        return container;
      },
    );
  }

  Future<void> _startCamera() async {
    if (!mounted) return;
    final nav = html.window.navigator;
    final mediaDevices = nav.mediaDevices;
    if (mediaDevices == null) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Camera not supported in this browser';
        });
      }
      return;
    }
    try {
      final stream = await mediaDevices.getUserMedia({'video': true});
      if (!mounted) {
        _stopStream(stream);
        return;
      }
      _stream = stream;
      final video = html.document.querySelector('#$_videoId') as html.VideoElement?;
      if (video != null) {
        video.srcObject = stream;
        await video.play();
      }
      if (mounted) {
        setState(() {
          _streamReady = true;
          _errorMessage = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Camera access denied or unavailable. Please allow camera when the browser prompts.';
        });
      }
    }
  }

  void _stopStream([html.MediaStream? s]) {
    final stream = s ?? _stream;
    if (stream != null) {
      for (final track in stream.getTracks()) {
        track.stop();
      }
      _stream = null;
    }
  }

  @override
  void dispose() {
    _stopStream();
    super.dispose();
  }

  void _capture() {
    final video = html.document.querySelector('#$_videoId') as html.VideoElement?;
    if (video == null || video.videoWidth == 0) return;
    final canvas = html.CanvasElement(width: video.videoWidth, height: video.videoHeight);
    final ctx = canvas.context2D;
    ctx.drawImage(video, 0, 0);
    final dataUrl = canvas.toDataUrl('image/jpeg', 0.9);
    final parts = dataUrl.split(',');
    if (parts.length < 2) return;
    final bytes = base64Decode(parts[1]);
    Navigator.of(context).pop(bytes);
  }

  void _cancel() {
    _stopStream();
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.black,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
      child: SizedBox(
        width: 560,
        height: 520,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Cash voucher photo',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: _cancel,
                  ),
                ],
              ),
            ),
            Expanded(
              child: _errorMessage != null
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.videocam_off, size: 48, color: Colors.white70),
                            const SizedBox(height: 16),
                            Text(
                              _errorMessage!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Colors.white70, fontSize: 14),
                            ),
                          ],
                        ),
                      ),
                    )
                  : SizedBox(
                      width: double.infinity,
                      height: double.infinity,
                      child: HtmlElementView(viewType: _viewType),
                    ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _cancel,
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 12),
                  DashButton(
                    label: 'Capture',
                    icon: Icons.camera_alt,
                    onPressed: _streamReady ? _capture : null,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
