import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/superadmin_config.dart';
import '../models/system_metadata.dart';
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

  // SystemMetadata methods
  Future<SystemMetadata> getSystemMetadata() async {
    try {
      final docSnapshot = await _firestore
          .collection(AppConstants.systemMetadataCollection)
          .doc('counters')
          .get();

      if (!docSnapshot.exists) {
        // Initialize with default metadata if not exists
        await initializeDefaultSystemMetadata();
        return DefaultSystemMetadata.metadata;
      }

      return SystemMetadata.fromMap(docSnapshot.data()!);
    } catch (e) {
      throw Exception('Failed to fetch system metadata: $e');
    }
  }

  Future<void> updateSystemMetadata(SystemMetadata metadata) async {
    try {
      final updatedMetadata = metadata.copyWith(lastUpdated: DateTime.now());
      
      await _firestore
          .collection(AppConstants.systemMetadataCollection)
          .doc('counters')
          .set(updatedMetadata.toMap());
    } catch (e) {
      throw Exception('Failed to update system metadata: $e');
    }
  }

  Future<void> initializeDefaultSystemMetadata() async {
    try {
      final defaultMetadata = DefaultSystemMetadata.metadata;
      
      await _firestore
          .collection(AppConstants.systemMetadataCollection)
          .doc('counters')
          .set(defaultMetadata.toMap());
    } catch (e) {
      throw Exception('Failed to initialize default system metadata: $e');
    }
  }

  // Increment counters
  Future<void> incrementOrgCounter() async {
    try {
      await _firestore
          .collection(AppConstants.systemMetadataCollection)
          .doc('counters')
          .update({
        'lastOrgIdCounter': FieldValue.increment(1),
        'totalOrganizations': FieldValue.increment(1),
        'lastUpdated': Timestamp.fromDate(DateTime.now()),
      });
    } catch (e) {
      throw Exception('Failed to increment organization counter: $e');
    }
  }

  Future<void> incrementUserCounter() async {
    try {
      await _firestore
          .collection(AppConstants.systemMetadataCollection)
          .doc('counters')
          .update({
        'lastUserIdCounter': FieldValue.increment(1),
        'totalUsers': FieldValue.increment(1),
        'lastUpdated': Timestamp.fromDate(DateTime.now()),
      });
    } catch (e) {
      throw Exception('Failed to increment user counter: $e');
    }
  }

  Future<void> incrementActiveSubscriptions() async {
    try {
      await _firestore
          .collection(AppConstants.systemMetadataCollection)
          .doc('counters')
          .update({
        'activeSubscriptions': FieldValue.increment(1),
        'lastUpdated': Timestamp.fromDate(DateTime.now()),
      });
    } catch (e) {
      throw Exception('Failed to increment active subscriptions: $e');
    }
  }

  Future<void> decrementActiveSubscriptions() async {
    try {
      await _firestore
          .collection(AppConstants.systemMetadataCollection)
          .doc('counters')
          .update({
        'activeSubscriptions': FieldValue.increment(-1),
        'lastUpdated': Timestamp.fromDate(DateTime.now()),
      });
    } catch (e) {
      throw Exception('Failed to decrement active subscriptions: $e');
    }
  }

  Future<void> updateRevenue(double amount) async {
    try {
      await _firestore
          .collection(AppConstants.systemMetadataCollection)
          .doc('counters')
          .update({
        'totalRevenue': FieldValue.increment(amount),
        'lastUpdated': Timestamp.fromDate(DateTime.now()),
      });
    } catch (e) {
      throw Exception('Failed to update revenue: $e');
    }
  }

  // Check if collections are initialized
  Future<bool> areCollectionsInitialized() async {
    try {
      final configSnapshot = await _firestore
          .collection(AppConstants.superadminConfigCollection)
          .doc('settings')
          .get();

      final metadataSnapshot = await _firestore
          .collection(AppConstants.systemMetadataCollection)
          .doc('counters')
          .get();

      return configSnapshot.exists && metadataSnapshot.exists;
    } catch (e) {
      return false;
    }
  }

  // Initialize both collections if they don't exist
  Future<void> initializeCollectionsIfNeeded() async {
    try {
      final isInitialized = await areCollectionsInitialized();
      
      if (!isInitialized) {
        await Future.wait([
          initializeDefaultSuperAdminConfig(),
          initializeDefaultSystemMetadata(),
        ]);
      }
    } catch (e) {
      throw Exception('Failed to initialize collections: $e');
    }
  }
}
