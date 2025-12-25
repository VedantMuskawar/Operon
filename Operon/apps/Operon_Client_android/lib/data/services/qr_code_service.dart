import 'dart:typed_data';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'dart:ui' as ui;

class QrCodeService {
  QrCodeService({FirebaseStorage? storage})
      : _storage = storage ?? FirebaseStorage.instance;

  final FirebaseStorage _storage;

  /// Generate QR code image from UPI data string
  Future<Uint8List> generateQrCodeImage(String data, {int size = 512}) async {
    // Use QrPainter to generate QR code
    final painter = QrPainter(
      data: data,
      version: QrVersions.auto,
      errorCorrectionLevel: QrErrorCorrectLevel.L,
      color: Colors.black,
      emptyColor: Colors.white,
      gapless: true,
    );

    final picRecorder = ui.PictureRecorder();
    final canvas = Canvas(picRecorder);
    final qrSize = Size(size.toDouble(), size.toDouble());
    painter.paint(canvas, qrSize);
    final picture = picRecorder.endRecording();
    final image = await picture.toImage(size, size);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    
    if (byteData == null) {
      throw Exception('Failed to generate QR code image');
    }

    return byteData.buffer.asUint8List();
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

