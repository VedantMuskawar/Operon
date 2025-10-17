import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';

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

  // Upload file to specified path
  static Future<String> uploadFile(String path, File file) async {
    try {
      final ref = _storage.ref().child(path);
      final uploadTask = await ref.putFile(file);
      return await uploadTask.ref.getDownloadURL();
    } catch (e) {
      throw Exception('Failed to upload file: $e');
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

  // Upload organization logo
  static Future<String> uploadOrganizationLogo(String orgId, File logoFile) async {
    final fileName = generateUniqueFileName(logoFile.path, '${orgId}_logo');
    final path = getOrganizationLogoPath(orgId, fileName);
    return await uploadFile(path, logoFile);
  }

  // Upload user profile photo
  static Future<String> uploadUserProfilePhoto(String userId, File photoFile) async {
    final fileName = generateUniqueFileName(photoFile.path, '${userId}_profile');
    final path = getUserProfilePhotoPath(userId, fileName);
    return await uploadFile(path, photoFile);
  }

  // Upload organization document
  static Future<String> uploadOrganizationDocument(String orgId, File documentFile) async {
    final fileName = generateUniqueFileName(documentFile.path, '${orgId}_doc');
    final path = getOrganizationDocumentPath(orgId, fileName);
    return await uploadFile(path, documentFile);
  }

  // Upload user document
  static Future<String> uploadUserDocument(String userId, File documentFile) async {
    final fileName = generateUniqueFileName(documentFile.path, '${userId}_doc');
    final path = getUserDocumentPath(userId, fileName);
    return await uploadFile(path, documentFile);
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
