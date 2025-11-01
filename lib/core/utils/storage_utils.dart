import 'package:firebase_storage/firebase_storage.dart';
import 'dart:typed_data';

class StorageUtils {
  static final FirebaseStorage _storage = FirebaseStorage.instance;

  // Organization Storage Paths
  static String getOrganizationLogoPath(String orgId, String fileName) {
    return 'organizations/$orgId/logos/$fileName';
  }

  static String getOrganizationDocumentPath(String orgId, String fileName) {
    return 'organizations/$orgId/documents/$fileName';
  }

  static String getOrganizationAttachmentPath(String orgId, String fileName) {
    return 'organizations/$orgId/attachments/$fileName';
  }

  // User Storage Paths
  static String getUserProfilePhotoPath(String userId, String fileName) {
    return 'users/$userId/profile_photos/$fileName';
  }

  static String getUserDocumentPath(String userId, String fileName) {
    return 'users/$userId/documents/$fileName';
  }

  static String getUserAttachmentPath(String userId, String fileName) {
    return 'users/$userId/attachments/$fileName';
  }

  // System Storage Paths
  static String getSystemTemplatePath(String fileName) {
    return 'system/templates/$fileName';
  }

  static String getSystemAssetPath(String fileName) {
    return 'system/assets/$fileName';
  }

  // Generate unique filename with timestamp
  static String generateUniqueFileName(String originalName, String suffix) {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final extension = originalName.split('.').last;
    return '${suffix}_$timestamp.$extension';
  }

  // Upload file to specified path (always using bytes)
  static Future<String> uploadFile(String path, Uint8List fileBytes, {String? fileName}) async {
    try {
      final ref = _storage.ref().child(path);
      final metadata = SettableMetadata(
        contentType: _getContentType(fileName ?? ''),
      );
      final uploadTask = ref.putData(fileBytes, metadata);
      final snapshot = await uploadTask;
      return await snapshot.ref.getDownloadURL();
    } catch (e) {
      throw Exception('Failed to upload file: $e');
    }
  }

  // Get content type from file name
  static String _getContentType(String fileName) {
    final extension = fileName.split('.').last.toLowerCase();
    switch (extension) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'webp':
        return 'image/webp';
      default:
        return 'image/jpeg';
    }
  }

  // Delete file from specified path
  static Future<void> deleteFile(String path) async {
    try {
      final ref = _storage.ref().child(path);
      await ref.delete();
    } catch (e) {
      throw Exception('Failed to delete file: $e');
    }
  }

  // Get download URL for file
  static Future<String> getDownloadUrl(String path) async {
    try {
      final ref = _storage.ref().child(path);
      return await ref.getDownloadURL();
    } catch (e) {
      throw Exception('Failed to get download URL: $e');
    }
  }

  // List files in a directory
  static Future<List<Reference>> listFiles(String directoryPath) async {
    try {
      final ref = _storage.ref().child(directoryPath);
      final result = await ref.listAll();
      return result.items;
    } catch (e) {
      throw Exception('Failed to list files: $e');
    }
  }

  // Upload organization logo (platform-agnostic)
  static Future<String> uploadOrganizationLogo(
    String orgId,
    Uint8List logoBytes, {
    String? fileName,
  }) async {
    final finalFileName = fileName ?? generateUniqueFileName('logo.jpg', '${orgId}_logo');
    final path = getOrganizationLogoPath(orgId, finalFileName);
    return await uploadFile(path, logoBytes, fileName: finalFileName);
  }

  // Upload user profile photo (platform-agnostic)
  static Future<String> uploadUserProfilePhoto(
    String userId,
    Uint8List photoBytes, {
    String? fileName,
  }) async {
    final finalFileName = fileName ?? generateUniqueFileName('photo.jpg', '${userId}_profile');
    final path = getUserProfilePhotoPath(userId, finalFileName);
    return await uploadFile(path, photoBytes, fileName: finalFileName);
  }

  // Upload organization document (platform-agnostic)
  static Future<String> uploadOrganizationDocument(
    String orgId,
    Uint8List documentBytes, {
    String? fileName,
  }) async {
    final finalFileName = fileName ?? generateUniqueFileName('document.pdf', '${orgId}_doc');
    final path = getOrganizationDocumentPath(orgId, finalFileName);
    return await uploadFile(path, documentBytes, fileName: finalFileName);
  }

  // Upload user document (platform-agnostic)
  static Future<String> uploadUserDocument(
    String userId,
    Uint8List documentBytes, {
    String? fileName,
  }) async {
    final finalFileName = fileName ?? generateUniqueFileName('document.pdf', '${userId}_doc');
    final path = getUserDocumentPath(userId, finalFileName);
    return await uploadFile(path, documentBytes, fileName: finalFileName);
  }

  // Delete organization logo
  static Future<void> deleteOrganizationLogo(String orgId, String fileName) async {
    final path = getOrganizationLogoPath(orgId, fileName);
    await deleteFile(path);
  }

  // Delete user profile photo
  static Future<void> deleteUserProfilePhoto(String userId, String fileName) async {
    final path = getUserProfilePhotoPath(userId, fileName);
    await deleteFile(path);
  }

  // Get organization logos list
  static Future<List<Reference>> getOrganizationLogos(String orgId) async {
    final directoryPath = 'organizations/$orgId/logos';
    return await listFiles(directoryPath);
  }

  // Get user profile photos list
  static Future<List<Reference>> getUserProfilePhotos(String userId) async {
    final directoryPath = 'users/$userId/profile_photos';
    return await listFiles(directoryPath);
  }
}
