import 'package:cloud_firestore/cloud_firestore.dart';

enum DmTemplatePageSize {
  a4,
  a5,
}

enum DmTemplateOrientation {
  portrait,
  landscape,
}

enum DmTemplateElementType {
  text,
  image,
  table,
  shape,
  barcode,
  qr,
}

class DmTemplateDuplicateSettings {
  const DmTemplateDuplicateSettings({
    required this.enabled,
    required this.invertColors,
  });

  final bool enabled;
  final bool invertColors;

  factory DmTemplateDuplicateSettings.fromMap(Map<String, dynamic>? map) {
    if (map == null) {
      return const DmTemplateDuplicateSettings(
        enabled: false,
        invertColors: true,
      );
    }

    return DmTemplateDuplicateSettings(
      enabled: map['enabled'] as bool? ?? false,
      invertColors: map['invertColors'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'enabled': enabled,
      'invertColors': invertColors,
    };
  }

  DmTemplateDuplicateSettings copyWith({
    bool? enabled,
    bool? invertColors,
  }) {
    return DmTemplateDuplicateSettings(
      enabled: enabled ?? this.enabled,
      invertColors: invertColors ?? this.invertColors,
    );
  }
}

class DmTemplateElement {
  const DmTemplateElement({
    required this.id,
    required this.type,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    required this.zIndex,
    required this.data,
    this.locked = false,
  });

  final String id;
  final DmTemplateElementType type;
  final double x;
  final double y;
  final double width;
  final double height;
  final int zIndex;
  final Map<String, dynamic> data;
  final bool locked;

  factory DmTemplateElement.fromMap(Map<String, dynamic> map) {
    return DmTemplateElement(
      id: map['id'] as String? ?? '',
      type: _elementTypeFromString(map['type'] as String?),
      x: (map['x'] as num?)?.toDouble() ?? 0,
      y: (map['y'] as num?)?.toDouble() ?? 0,
      width: (map['width'] as num?)?.toDouble() ?? 0.2,
      height: (map['height'] as num?)?.toDouble() ?? 0.1,
      zIndex: map['zIndex'] as int? ?? 0,
      data: Map<String, dynamic>.from(map['data'] as Map? ?? {}),
      locked: map['locked'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': type.name,
      'x': x,
      'y': y,
      'width': width,
      'height': height,
      'zIndex': zIndex,
      'data': data,
      'locked': locked,
    };
  }

  DmTemplateElement copyWith({
    String? id,
    DmTemplateElementType? type,
    double? x,
    double? y,
    double? width,
    double? height,
    int? zIndex,
    Map<String, dynamic>? data,
    bool? locked,
  }) {
    return DmTemplateElement(
      id: id ?? this.id,
      type: type ?? this.type,
      x: x ?? this.x,
      y: y ?? this.y,
      width: width ?? this.width,
      height: height ?? this.height,
      zIndex: zIndex ?? this.zIndex,
      data: data ?? this.data,
      locked: locked ?? this.locked,
    );
  }

  static DmTemplateElementType _elementTypeFromString(String? value) {
    if (value == null) return DmTemplateElementType.text;
    return DmTemplateElementType.values.firstWhere(
      (type) => type.name == value,
      orElse: () => DmTemplateElementType.text,
    );
  }
}

class DmTemplate {
  const DmTemplate({
    required this.id,
    required this.organizationId,
    required this.name,
    required this.pageSize,
    required this.orientation,
    required this.elements,
    required this.duplicateSettings,
    required this.updatedAt,
    required this.updatedBy,
    required this.createdAt,
    required this.createdBy,
    this.description,
    this.version = 1,
    this.metadata,
    this.backgroundColor,
    this.marginsMm = const {
      'top': 12.7,
      'right': 12.7,
      'bottom': 12.7,
      'left': 12.7,
    },
  });

  final String id;
  final String organizationId;
  final String name;
  final String? description;
  final DmTemplatePageSize pageSize;
  final DmTemplateOrientation orientation;
  final List<DmTemplateElement> elements;
  final DmTemplateDuplicateSettings duplicateSettings;
  final Map<String, dynamic>? metadata;
  final int version;
  final DateTime updatedAt;
  final String updatedBy;
  final DateTime createdAt;
  final String createdBy;
  final Map<String, double> marginsMm;
  final String? backgroundColor;

  factory DmTemplate.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return DmTemplate(
      id: doc.id,
      organizationId: data['organizationId'] as String? ?? '',
      name: data['name'] as String? ?? 'DM Template',
      description: data['description'] as String?,
      pageSize: _pageSizeFromString(data['pageSize'] as String?),
      orientation: _orientationFromString(data['orientation'] as String?),
      elements: ((data['elements'] as List?) ?? [])
          .map((element) => DmTemplateElement.fromMap(
              Map<String, dynamic>.from(element as Map)))
          .toList(),
      duplicateSettings: DmTemplateDuplicateSettings.fromMap(
        Map<String, dynamic>.from(
          data['duplicateSettings'] as Map? ?? {},
        ),
      ),
      metadata: data['metadata'] == null
          ? null
          : Map<String, dynamic>.from(data['metadata'] as Map),
      version: data['version'] as int? ?? 1,
      updatedAt: _parseTimestamp(data['updatedAt']) ?? DateTime.now(),
      updatedBy: data['updatedBy'] as String? ?? '',
      createdAt: _parseTimestamp(data['createdAt']) ?? DateTime.now(),
      createdBy: data['createdBy'] as String? ?? '',
      marginsMm: Map<String, double>.fromEntries(
        (data['marginsMm'] as Map? ?? {}).entries.map(
              (entry) => MapEntry(
                entry.key as String,
                (entry.value as num?)?.toDouble() ?? 12.7,
              ),
            ),
      ),
      backgroundColor: data['backgroundColor'] as String?,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'organizationId': organizationId,
      'name': name,
      if (description != null) 'description': description,
      'pageSize': pageSize.name,
      'orientation': orientation.name,
      'elements': elements.map((element) => element.toMap()).toList(),
      'duplicateSettings': duplicateSettings.toMap(),
      if (metadata != null) 'metadata': metadata,
      'version': version,
      'updatedAt': Timestamp.fromDate(updatedAt),
      'updatedBy': updatedBy,
      'createdAt': Timestamp.fromDate(createdAt),
      'createdBy': createdBy,
      'marginsMm': marginsMm.map((key, value) => MapEntry(key, value)),
      if (backgroundColor != null) 'backgroundColor': backgroundColor,
    };
  }

  DmTemplate copyWith({
    String? id,
    String? organizationId,
    String? name,
    String? description,
    DmTemplatePageSize? pageSize,
    DmTemplateOrientation? orientation,
    List<DmTemplateElement>? elements,
    DmTemplateDuplicateSettings? duplicateSettings,
    Map<String, dynamic>? metadata,
    int? version,
    DateTime? updatedAt,
    String? updatedBy,
    DateTime? createdAt,
    String? createdBy,
    Map<String, double>? marginsMm,
    String? backgroundColor,
  }) {
    return DmTemplate(
      id: id ?? this.id,
      organizationId: organizationId ?? this.organizationId,
      name: name ?? this.name,
      description: description ?? this.description,
      pageSize: pageSize ?? this.pageSize,
      orientation: orientation ?? this.orientation,
      elements: elements ?? this.elements,
      duplicateSettings: duplicateSettings ?? this.duplicateSettings,
      metadata: metadata ?? this.metadata,
      version: version ?? this.version,
      updatedAt: updatedAt ?? this.updatedAt,
      updatedBy: updatedBy ?? this.updatedBy,
      createdAt: createdAt ?? this.createdAt,
      createdBy: createdBy ?? this.createdBy,
      marginsMm: marginsMm ?? this.marginsMm,
      backgroundColor: backgroundColor ?? this.backgroundColor,
    );
  }

  static DmTemplatePageSize _pageSizeFromString(String? value) {
    if (value == null) return DmTemplatePageSize.a4;
    return DmTemplatePageSize.values.firstWhere(
      (size) => size.name == value,
      orElse: () => DmTemplatePageSize.a4,
    );
  }

  static DmTemplateOrientation _orientationFromString(String? value) {
    if (value == null) return DmTemplateOrientation.portrait;
    return DmTemplateOrientation.values.firstWhere(
      (orientation) => orientation.name == value,
      orElse: () => DmTemplateOrientation.portrait,
    );
  }

  static DateTime? _parseTimestamp(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  static DmTemplate defaultTemplate({
    required String organizationId,
    required String createdBy,
  }) {
    final now = DateTime.now();
    return DmTemplate(
      id: 'default',
      organizationId: organizationId,
      name: 'Default Delivery Memo',
      description: 'Starter template for Delivery Memo',
      pageSize: DmTemplatePageSize.a4,
      orientation: DmTemplateOrientation.portrait,
      elements: const [],
      duplicateSettings: const DmTemplateDuplicateSettings(
        enabled: false,
        invertColors: true,
      ),
      metadata: const {
        'fieldBindings': <String>[],
      },
      version: 1,
      updatedAt: now,
      updatedBy: createdBy,
      createdAt: now,
      createdBy: createdBy,
      marginsMm: const {
        'top': 12.7,
        'right': 12.7,
        'bottom': 12.7,
        'left': 12.7,
      },
      backgroundColor: '#FFFFFFFF',
    );
  }
}


