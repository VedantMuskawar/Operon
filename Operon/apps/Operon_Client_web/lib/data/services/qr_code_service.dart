import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:qr_flutter/qr_flutter.dart';

/// QR code service for web
class QrCodeService {
  QrCodeService({FirebaseStorage? storage})
      : _storage = storage ?? FirebaseStorage.instance;

  final FirebaseStorage _storage;

  /// Generate QR code image from UPI data string
  Future<Uint8List> generateQrCodeImage(String data, {int size = 512}) async {
    try {
      // Create a render object to paint the QR code
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      final paintSize = Size(size.toDouble(), size.toDouble());

      // Paint the QR code using QrPainter with auto version
      QrPainter(
        data: data,
        color: const Color(0xFF000000),
        emptyColor: const Color(0xFFFFFFFF),
        version: QrVersions.auto,
        errorCorrectionLevel: QrErrorCorrectLevel.L,
      ).paint(canvas, paintSize);

      // Convert to image
      final picture = recorder.endRecording();
      final image = await picture.toImage(size, size);

      // Convert image to PNG bytes
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) {
        throw Exception('Failed to convert QR code to bytes');
      }

      return byteData.buffer.asUint8List();
    } catch (e) {
      throw Exception('Failed to generate QR code: $e');
    }
  }

  /// Upload QR code image to Firebase Storage
  /// Returns the download URL
  Future<String> uploadQrCodeImage(
    Uint8List imageBytes,
    String orgId,
    String accountId,
  ) async {
    final ref = _storage
        .ref()
        .child('organizations')
        .child(orgId)
        .child('payment_accounts')
        .child(accountId)
        .child('qr_code.png');

    final uploadTask = ref.putData(
      imageBytes,
      SettableMetadata(
        contentType: 'image/png',
        cacheControl: 'public, max-age=31536000',
      ),
    );

    await uploadTask;
    return await ref.getDownloadURL();
  }

  /// Delete QR code image from Firebase Storage
  Future<void> deleteQrCodeImage(String orgId, String accountId) async {
    try {
      final ref = _storage
          .ref()
          .child('organizations')
          .child(orgId)
          .child('payment_accounts')
          .child(accountId)
          .child('qr_code.png');
      await ref.delete();
    } catch (e) {
      // Ignore if file doesn't exist
      if (e.toString().contains('not found')) {
        return;
      }
      rethrow;
    }
  }
}
