import 'package:cloud_firestore/cloud_firestore.dart';

enum DmPrintOrientation { portrait, landscape }
enum DmPaymentDisplay { qrCode, bankDetails }
enum DmTemplateType { universal, custom }

class DmSettings {
  const DmSettings({
    required this.organizationId,
    required this.header,
    required this.footer,
    required this.updatedAt,
    this.updatedBy,
    this.printOrientation = DmPrintOrientation.portrait,
    this.paymentDisplay = DmPaymentDisplay.qrCode,
    this.templateType = DmTemplateType.universal,
    this.customTemplateId,
  });

  final String organizationId;
  final DmHeaderSettings header;
  final DmFooterSettings footer;
  final DateTime updatedAt;
  final String? updatedBy;
  final DmPrintOrientation printOrientation;
  final DmPaymentDisplay paymentDisplay;
  final DmTemplateType templateType;
  final String? customTemplateId;

  Map<String, dynamic> toJson() {
    return {
      'organizationId': organizationId,
      'header': header.toJson(),
      'footer': footer.toJson(),
      'updatedAt': Timestamp.fromDate(updatedAt),
      if (updatedBy != null) 'updatedBy': updatedBy,
      'printOrientation': printOrientation.name,
      'paymentDisplay': paymentDisplay.name,
      'templateType': templateType.name,
      if (customTemplateId != null) 'customTemplateId': customTemplateId,
    };
  }

  factory DmSettings.fromJson(Map<String, dynamic> json) {
    final headerJson = json['header'] as Map<String, dynamic>? ?? {};
    final footerJson = json['footer'] as Map<String, dynamic>? ?? {};

    final printOrientationStr = json['printOrientation'] as String?;
    final printOrientation = printOrientationStr != null
        ? DmPrintOrientation.values.firstWhere(
            (e) => e.name == printOrientationStr,
            orElse: () => DmPrintOrientation.portrait,
          )
        : DmPrintOrientation.portrait;

    final paymentDisplayStr = json['paymentDisplay'] as String?;
    final paymentDisplay = paymentDisplayStr != null
        ? DmPaymentDisplay.values.firstWhere(
            (e) => e.name == paymentDisplayStr,
            orElse: () => DmPaymentDisplay.qrCode,
          )
        : DmPaymentDisplay.qrCode;

    final templateTypeStr = json['templateType'] as String?;
    final templateType = templateTypeStr != null
        ? DmTemplateType.values.firstWhere(
            (e) => e.name == templateTypeStr,
            orElse: () => DmTemplateType.universal,
          )
        : DmTemplateType.universal;

    return DmSettings(
      organizationId: json['organizationId'] as String? ?? '',
      header: DmHeaderSettings.fromJson(headerJson),
      footer: DmFooterSettings.fromJson(footerJson),
      updatedAt: (json['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedBy: json['updatedBy'] as String?,
      printOrientation: printOrientation,
      paymentDisplay: paymentDisplay,
      templateType: templateType,
      customTemplateId: json['customTemplateId'] as String?,
    );
  }

  DmSettings copyWith({
    String? organizationId,
    DmHeaderSettings? header,
    DmFooterSettings? footer,
    DateTime? updatedAt,
    String? updatedBy,
    DmPrintOrientation? printOrientation,
    DmPaymentDisplay? paymentDisplay,
    DmTemplateType? templateType,
    String? customTemplateId,
  }) {
    return DmSettings(
      organizationId: organizationId ?? this.organizationId,
      header: header ?? this.header,
      footer: footer ?? this.footer,
      updatedAt: updatedAt ?? this.updatedAt,
      updatedBy: updatedBy ?? this.updatedBy,
      printOrientation: printOrientation ?? this.printOrientation,
      paymentDisplay: paymentDisplay ?? this.paymentDisplay,
      templateType: templateType ?? this.templateType,
      customTemplateId: customTemplateId ?? this.customTemplateId,
    );
  }
}

class DmHeaderSettings {
  const DmHeaderSettings({
    required this.name,
    required this.address,
    required this.phone,
    this.logoImageUrl,
    this.gstNo,
  });

  final String name;
  final String address;
  final String phone;
  final String? logoImageUrl;
  final String? gstNo;

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'address': address,
      'phone': phone,
      if (logoImageUrl != null) 'logoImageUrl': logoImageUrl,
      if (gstNo != null) 'gstNo': gstNo,
    };
  }

  factory DmHeaderSettings.fromJson(Map<String, dynamic> json) {
    return DmHeaderSettings(
      name: json['name'] as String? ?? '',
      address: json['address'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      logoImageUrl: json['logoImageUrl'] as String?,
      gstNo: json['gstNo'] as String?,
    );
  }

  DmHeaderSettings copyWith({
    String? name,
    String? address,
    String? phone,
    String? logoImageUrl,
    String? gstNo,
  }) {
    return DmHeaderSettings(
      name: name ?? this.name,
      address: address ?? this.address,
      phone: phone ?? this.phone,
      logoImageUrl: logoImageUrl ?? this.logoImageUrl,
      gstNo: gstNo ?? this.gstNo,
    );
  }
}

class DmFooterSettings {
  const DmFooterSettings({
    this.customText,
  });

  final String? customText;

  Map<String, dynamic> toJson() {
    return {
      if (customText != null) 'customText': customText,
    };
  }

  factory DmFooterSettings.fromJson(Map<String, dynamic> json) {
    return DmFooterSettings(
      customText: json['customText'] as String?,
    );
  }

  DmFooterSettings copyWith({
    String? customText,
  }) {
    return DmFooterSettings(
      customText: customText ?? this.customText,
    );
  }
}
