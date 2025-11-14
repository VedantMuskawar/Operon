import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/superadmin_config.dart';
import '../constants/app_constants.dart';

class ConfigRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // SuperAdminConfig methods
  Future<SuperAdminConfig> getSuperAdminConfig() async {
    try {
      final docSnapshot = await _firestore
          .collection(AppConstants.superadminConfigCollection)
          .doc('settings')
          .get();

      if (!docSnapshot.exists) {
        // Initialize with default config if not exists
        await initializeDefaultSuperAdminConfig();
        return DefaultSuperAdminConfig.config;
      }

      return SuperAdminConfig.fromMap(docSnapshot.data()!);
    } catch (e) {
      throw Exception('Failed to fetch SuperAdmin config: $e');
    }
  }

  Future<void> updateSuperAdminConfig(SuperAdminConfig config) async {
    try {
      final updatedConfig = config.copyWith(lastUpdated: DateTime.now());
      
      await _firestore
          .collection(AppConstants.superadminConfigCollection)
          .doc('settings')
          .set(updatedConfig.toMap());
    } catch (e) {
      throw Exception('Failed to update SuperAdmin config: $e');
    }
  }

  Future<void> initializeDefaultSuperAdminConfig() async {
    try {
      final defaultConfig = DefaultSuperAdminConfig.config;
      
      await _firestore
          .collection(AppConstants.superadminConfigCollection)
          .doc('settings')
          .set(defaultConfig.toMap());
    } catch (e) {
      throw Exception('Failed to initialize default SuperAdmin config: $e');
    }
  }
  
  Future<void> ensureSuperAdminConfigExists() async {
    final snapshot = await _firestore
        .collection(AppConstants.superadminConfigCollection)
        .doc('settings')
        .get();

    if (!snapshot.exists) {
      await initializeDefaultSuperAdminConfig();
    }
  }
}
