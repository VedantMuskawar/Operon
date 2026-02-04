import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';

class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;

  /// Upload delivery photo to Firebase Storage
  /// Returns the download URL
  Future<String> uploadDeliveryPhoto({
    required File imageFile,
    required String organizationId,
    required String orderId,
    required String tripId,
  }) async {
    try {
      // Create storage path: Delivery Photos/{orgId}/{orderId}/{tripId}/{timestamp}.jpg
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = '$timestamp.jpg';
      final path = 'Delivery Photos/$organizationId/$orderId/$tripId/$fileName';

      // Upload file
      final ref = _storage.ref().child(path);
      final uploadTask = ref.putFile(imageFile);

      // Wait for upload to complete
      final snapshot = await uploadTask;
      
      // Get download URL
      final downloadUrl = await snapshot.ref.getDownloadURL();
      
      return downloadUrl;
    } catch (e) {
      throw Exception('Failed to upload delivery photo: $e');
    }
  }

  /// Upload cash voucher photo for a salary expense.
  /// Path: organizations/{organizationId}/expenses/{transactionId}/cash_voucher.jpg
  /// Returns the download URL.
  Future<String> uploadExpenseVoucher({
    required File imageFile,
    required String organizationId,
    required String transactionId,
  }) async {
    try {
      final path =
          'organizations/$organizationId/expenses/$transactionId/cash_voucher.jpg';
      final ref = _storage.ref().child(path);
      await ref.putFile(imageFile);
      final downloadUrl = await ref.getDownloadURL();
      return downloadUrl;
    } catch (e) {
      throw Exception('Failed to upload expense voucher: $e');
    }
  }
}

