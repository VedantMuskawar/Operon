import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/constants/app_constants.dart';
import '../models/crm_settings.dart';

abstract class CrmSettingsDataSource {
  Future<CrmSettings> fetchSettings({
    required String organizationId,
  });
}

class CrmRepository implements CrmSettingsDataSource {
  CrmRepository({
    FirebaseFirestore? firestore,
  }) : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection(AppConstants.crmSettingsCollection);

  Future<CrmSettings> fetchSettings({
    required String organizationId,
  }) async {
    final snapshot = await _collection.doc(organizationId).get();

    if (!snapshot.exists) {
      return CrmSettings(
        organizationId: organizationId,
        orderConfirmationEnabled: false,
        orderConfirmationTemplate: '',
      );
    }

    return CrmSettings.fromFirestore(snapshot);
  }

  Stream<CrmSettings> watchSettings({
    required String organizationId,
  }) {
    return _collection.doc(organizationId).snapshots().map((snapshot) {
      if (!snapshot.exists) {
        return CrmSettings(
          organizationId: organizationId,
          orderConfirmationEnabled: false,
          orderConfirmationTemplate: '',
        );
      }
      return CrmSettings.fromFirestore(snapshot);
    });
  }

  Future<void> saveSettings({
    required CrmSettings settings,
  }) async {
    await _collection.doc(settings.organizationId).set(
          settings.toFirestore(),
          SetOptions(merge: true),
        );
  }

  Future<void> updateOrderConfirmationSettings({
    required String organizationId,
    required bool enabled,
    required String template,
    String? userId,
    DateTime? updatedAt,
  }) async {
    await _collection.doc(organizationId).set(
      {
        'organizationId': organizationId,
        'orderConfirmationEnabled': enabled,
        'orderConfirmationTemplate': template,
        if (userId != null) 'updatedBy': userId,
        if (updatedAt != null)
          'updatedAt': Timestamp.fromDate(updatedAt),
      },
      SetOptions(merge: true),
    );
  }

  Future<void> updateWhatsappCredentials({
    required String organizationId,
    String? phoneNumberId,
    String? accessToken,
    String? userId,
    DateTime? updatedAt,
  }) async {
    await _collection.doc(organizationId).set(
      {
        'organizationId': organizationId,
        if (phoneNumberId != null) 'whatsappPhoneNumberId': phoneNumberId,
        if (accessToken != null) 'whatsappAccessToken': accessToken,
        if (userId != null) 'updatedBy': userId,
        if (updatedAt != null)
          'updatedAt': Timestamp.fromDate(updatedAt),
      },
      SetOptions(merge: true),
    );
  }
}

