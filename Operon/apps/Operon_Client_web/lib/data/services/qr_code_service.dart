import 'dart:typed_data';
import 'package:firebase_storage/firebase_storage.dart';

/// Simplified QR code service for web
/// Note: QR code generation can be enhanced later with a web-compatible library
class QrCodeService {
  QrCodeService({FirebaseStorage? storage})
      : _storage = storage ?? FirebaseStorage.instance;

  final FirebaseStorage _storage;

  /// Generate QR code image from UPI data string
  /// For web, this is a placeholder - can be enhanced with web-compatible QR library
  /// Returns empty bytes for now - QR code generation can be added later
  Future<Uint8List> generateQrCodeImage(String data, {int size = 512}) async {
    // TODO: Implement QR code generation for web
    // For now, return empty bytes - QR code generation can be added later
    // with a web-compatible library like qr_flutter (if it supports web) or another solution
    // This allows accounts to be created without QR codes
    return Uint8List(0);
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
