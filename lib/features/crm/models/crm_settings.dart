import 'package:cloud_firestore/cloud_firestore.dart';

class CrmSettings {
  const CrmSettings({
    required this.organizationId,
    required this.orderConfirmationEnabled,
    required this.orderConfirmationTemplate,
    this.whatsappPhoneNumberId,
    this.whatsappAccessToken,
    this.updatedAt,
    this.updatedBy,
  });

  final String organizationId;
  final bool orderConfirmationEnabled;
  final String orderConfirmationTemplate;
  final String? whatsappPhoneNumberId;
  final String? whatsappAccessToken;
  final DateTime? updatedAt;
  final String? updatedBy;

  factory CrmSettings.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data() ?? <String, dynamic>{};
    return CrmSettings(
      organizationId:
          data['organizationId'] as String? ?? snapshot.id,
      orderConfirmationEnabled:
          data['orderConfirmationEnabled'] as bool? ?? false,
      orderConfirmationTemplate:
          data['orderConfirmationTemplate'] as String? ?? '',
      whatsappPhoneNumberId:
          data['whatsappPhoneNumberId'] as String?,
      whatsappAccessToken: data['whatsappAccessToken'] as String?,
      updatedAt: _parseTimestamp(data['updatedAt']),
      updatedBy: data['updatedBy'] as String?,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'organizationId': organizationId,
      'orderConfirmationEnabled': orderConfirmationEnabled,
      'orderConfirmationTemplate': orderConfirmationTemplate,
      if (whatsappPhoneNumberId != null)
        'whatsappPhoneNumberId': whatsappPhoneNumberId,
      if (whatsappAccessToken != null)
        'whatsappAccessToken': whatsappAccessToken,
      if (updatedAt != null)
        'updatedAt': Timestamp.fromDate(updatedAt!),
      if (updatedBy != null) 'updatedBy': updatedBy,
    };
  }

  CrmSettings copyWith({
    bool? orderConfirmationEnabled,
    String? orderConfirmationTemplate,
    String? whatsappPhoneNumberId,
    String? whatsappAccessToken,
    DateTime? updatedAt,
    String? updatedBy,
  }) {
    return CrmSettings(
      organizationId: organizationId,
      orderConfirmationEnabled:
          orderConfirmationEnabled ?? this.orderConfirmationEnabled,
      orderConfirmationTemplate:
          orderConfirmationTemplate ?? this.orderConfirmationTemplate,
      whatsappPhoneNumberId:
          whatsappPhoneNumberId ?? this.whatsappPhoneNumberId,
      whatsappAccessToken:
          whatsappAccessToken ?? this.whatsappAccessToken,
      updatedAt: updatedAt ?? this.updatedAt,
      updatedBy: updatedBy ?? this.updatedBy,
    );
  }

  static DateTime? _parseTimestamp(dynamic value) {
    if (value is Timestamp) {
      return value.toDate();
    }
    if (value is DateTime) {
      return value;
    }
    return null;
  }
}

