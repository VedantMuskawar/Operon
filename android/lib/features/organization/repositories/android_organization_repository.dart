import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:typed_data';
import '../../../core/app_constants.dart';

// Simplified Organization model for Android
class AndroidOrganization {
  final String orgId;
  final String orgName;
  final String email;
  final String gstNo;
  final String? orgLogoUrl;
  final String status;
  final Map<String, dynamic> metadata;

  AndroidOrganization({
    required this.orgId,
    required this.orgName,
    required this.email,
    required this.gstNo,
    this.orgLogoUrl,
    required this.status,
    required this.metadata,
  });

  factory AndroidOrganization.fromMap(Map<String, dynamic> map) {
    return AndroidOrganization(
      orgId: map['orgId'] ?? '',
      orgName: map['orgName'] ?? '',
      email: map['email'] ?? '',
      gstNo: map['gstNo'] ?? '',
      orgLogoUrl: map['orgLogoUrl'],
      status: map['status'] ?? 'active',
      metadata: map['metadata'] as Map<String, dynamic>? ?? {},
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'orgId': orgId,
      'orgName': orgName,
      'email': email,
      'gstNo': gstNo,
      if (orgLogoUrl != null) 'orgLogoUrl': orgLogoUrl,
      'status': status,
      'metadata': metadata,
    };
  }

  AndroidOrganization copyWith({
    String? orgId,
    String? orgName,
    String? email,
    String? gstNo,
    String? orgLogoUrl,
    String? status,
    Map<String, dynamic>? metadata,
  }) {
    return AndroidOrganization(
      orgId: orgId ?? this.orgId,
      orgName: orgName ?? this.orgName,
      email: email ?? this.email,
      gstNo: gstNo ?? this.gstNo,
      orgLogoUrl: orgLogoUrl ?? this.orgLogoUrl,
      status: status ?? this.status,
      metadata: metadata ?? this.metadata,
    );
  }
}

// Simplified Subscription model for Android
class AndroidSubscription {
  final String subscriptionId;
  final String tier;
  final String subscriptionType;
  final DateTime startDate;
  final DateTime endDate;
  final String status;
  final double amount;
  final String currency;

  AndroidSubscription({
    required this.subscriptionId,
    required this.tier,
    required this.subscriptionType,
    required this.startDate,
    required this.endDate,
    required this.status,
    required this.amount,
    required this.currency,
  });

  factory AndroidSubscription.fromMap(Map<String, dynamic> map) {
    return AndroidSubscription(
      subscriptionId: map['subscriptionId'] ?? '',
      tier: map['tier'] ?? 'basic',
      subscriptionType: map['subscriptionType'] ?? 'monthly',
      startDate: (map['startDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      endDate: (map['endDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      status: map['status'] ?? 'active',
      amount: (map['amount'] ?? 0.0).toDouble(),
      currency: map['currency'] ?? 'INR',
    );
  }
}

class AndroidOrganizationRepository {
  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;

  AndroidOrganizationRepository({
    FirebaseFirestore? firestore,
    FirebaseStorage? storage,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _storage = storage ?? FirebaseStorage.instance;

  // Get organization by ID with subscription
  Future<Map<String, dynamic>> getOrganizationWithSubscription(String orgId) async {
    try {
      final orgDoc = await _firestore
          .collection(AppConstants.organizationsCollection)
          .doc(orgId)
          .get();

      if (!orgDoc.exists) {
        throw Exception('Organization not found');
      }

      final orgData = orgDoc.data() as Map<String, dynamic>;
      
      // Try to get subscription
      AndroidSubscription? subscription;
      try {
        final subscriptionSnapshot = await _firestore
            .collection(AppConstants.organizationsCollection)
            .doc(orgId)
            .collection(AppConstants.subscriptionSubcollection)
            .orderBy('createdDate', descending: true)
            .limit(1)
            .get();

        if (subscriptionSnapshot.docs.isNotEmpty) {
          subscription = AndroidSubscription.fromMap(
            subscriptionSnapshot.docs.first.data(),
          );
        }
      } catch (e) {
        print('No subscription found: $e');
      }

      return {
        'organization': AndroidOrganization.fromMap(orgData),
        'subscription': subscription,
      };
    } catch (e) {
      throw Exception('Failed to fetch organization: $e');
    }
  }

  // Update organization details
  Future<void> updateOrganizationDetails({
    required String orgId,
    required AndroidOrganization organization,
    Uint8List? logoFile,
    String? logoFileName,
  }) async {
    try {
      String? logoUrl;

      // Upload logo if provided
      if (logoFile != null) {
        try {
          logoUrl = await _uploadOrganizationLogo(orgId, logoFile, fileName: logoFileName);
        } catch (e) {
          print('Warning: Failed to upload logo: $e');
          // Continue without logo update
        }
      }

      // Update organization
      final updatedOrg = organization.copyWith(
        orgLogoUrl: logoUrl ?? organization.orgLogoUrl,
      );

      final orgMap = updatedOrg.toMap();
      orgMap['updatedDate'] = Timestamp.fromDate(DateTime.now());

      await _firestore
          .collection(AppConstants.organizationsCollection)
          .doc(orgId)
          .update(orgMap);
    } catch (e) {
      throw Exception('Failed to update organization: $e');
    }
  }

  // Upload organization logo
  Future<String> _uploadOrganizationLogo(
    String orgId,
    Uint8List logoBytes, {
    String? fileName,
  }) async {
    try {
      final finalFileName = fileName ?? 'logo_${DateTime.now().millisecondsSinceEpoch}.png';
      final path = AppConstants.orgLogosPath.replaceAll('{orgId}', orgId) + '/$finalFileName';
      
      final ref = _storage.ref(path);
      await ref.putData(logoBytes);

      return await ref.getDownloadURL();
    } catch (e) {
      throw Exception('Failed to upload logo: $e');
    }
  }
}

