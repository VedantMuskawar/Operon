import 'package:cloud_firestore/cloud_firestore.dart';

enum WageMethodType {
  production,
  loadingUnloading,
  dailyRate,
  custom,
}

class WageSettings {
  const WageSettings({
    required this.organizationId,
    required this.enabled,
    required this.calculationMethods,
    required this.createdAt,
    required this.updatedAt,
  });

  final String organizationId;
  final bool enabled;
  final Map<String, WageCalculationMethod> calculationMethods;
  final DateTime createdAt;
  final DateTime updatedAt;

  Map<String, dynamic> toJson() {
    return {
      'organizationId': organizationId,
      'enabled': enabled,
      'calculationMethods': calculationMethods.map(
        (key, value) => MapEntry(key, value.toJson()),
      ),
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  factory WageSettings.fromJson(Map<String, dynamic> json) {
    final methodsMap = json['calculationMethods'] as Map<String, dynamic>? ?? {};
    final calculationMethods = methodsMap.map(
      (key, value) => MapEntry(
        key,
        WageCalculationMethod.fromJson(value as Map<String, dynamic>),
      ),
    );

    return WageSettings(
      organizationId: json['organizationId'] as String? ?? '',
      enabled: json['enabled'] as bool? ?? false,
      calculationMethods: calculationMethods,
      createdAt: (json['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (json['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  WageSettings copyWith({
    String? organizationId,
    bool? enabled,
    Map<String, WageCalculationMethod>? calculationMethods,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return WageSettings(
      organizationId: organizationId ?? this.organizationId,
      enabled: enabled ?? this.enabled,
      calculationMethods: calculationMethods ?? this.calculationMethods,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class WageCalculationMethod {
  const WageCalculationMethod({
    required this.methodId,
    required this.methodType,
    required this.name,
    required this.enabled,
    required this.config,
    this.description,
    this.roleIds,
    required this.createdAt,
    required this.updatedAt,
  });

  final String methodId;
  final WageMethodType methodType;
  final String name;
  final String? description;
  final bool enabled;
  final List<String>? roleIds;
  final WageMethodConfig config;
  final DateTime createdAt;
  final DateTime updatedAt;

  Map<String, dynamic> toJson() {
    return {
      'methodId': methodId,
      'methodType': methodType.name,
      'name': name,
      if (description != null) 'description': description,
      'enabled': enabled,
      if (roleIds != null) 'roleIds': roleIds,
      'config': config.toJson(),
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  factory WageCalculationMethod.fromJson(Map<String, dynamic> json) {
    final methodTypeStr = json['methodType'] as String? ?? 'production';
    final methodType = WageMethodType.values.firstWhere(
      (e) => e.name == methodTypeStr,
      orElse: () => WageMethodType.production,
    );

    final configJson = json['config'] as Map<String, dynamic>? ?? {};
    final config = _parseConfig(methodType, configJson);

    return WageCalculationMethod(
      methodId: json['methodId'] as String? ?? '',
      methodType: methodType,
      name: json['name'] as String? ?? '',
      description: json['description'] as String?,
      enabled: json['enabled'] as bool? ?? true,
      roleIds: json['roleIds'] != null
          ? List<String>.from(json['roleIds'] as List)
          : null,
      config: config,
      createdAt: (json['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (json['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  static WageMethodConfig _parseConfig(
    WageMethodType methodType,
    Map<String, dynamic> json,
  ) {
    switch (methodType) {
      case WageMethodType.production:
        return ProductionWageConfig.fromJson(json);
      case WageMethodType.loadingUnloading:
        return LoadingUnloadingConfig.fromJson(json);
      case WageMethodType.dailyRate:
      case WageMethodType.custom:
        // Placeholder for future implementations
        return ProductionWageConfig.fromJson(json);
    }
  }

  WageCalculationMethod copyWith({
    String? methodId,
    WageMethodType? methodType,
    String? name,
    String? description,
    bool? enabled,
    List<String>? roleIds,
    WageMethodConfig? config,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return WageCalculationMethod(
      methodId: methodId ?? this.methodId,
      methodType: methodType ?? this.methodType,
      name: name ?? this.name,
      description: description ?? this.description,
      enabled: enabled ?? this.enabled,
      roleIds: roleIds ?? this.roleIds,
      config: config ?? this.config,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

abstract class WageMethodConfig {
  Map<String, dynamic> toJson();
}

class ProductionWageConfig implements WageMethodConfig {
  const ProductionWageConfig({
    required this.productionPricePerUnit,
    required this.stackingPricePerUnit,
    required this.requiresBatchApproval,
    required this.autoCalculateOnRecord,
    this.productSpecificPricing,
  });

  final double productionPricePerUnit;
  final double stackingPricePerUnit;
  final bool requiresBatchApproval;
  final bool autoCalculateOnRecord;
  final Map<String, ProductWagePricing>? productSpecificPricing;

  @override
  Map<String, dynamic> toJson() {
    return {
      'methodType': 'production',
      'productionPricePerUnit': productionPricePerUnit,
      'stackingPricePerUnit': stackingPricePerUnit,
      'requiresBatchApproval': requiresBatchApproval,
      'autoCalculateOnRecord': autoCalculateOnRecord,
      if (productSpecificPricing != null)
        'productSpecificPricing': productSpecificPricing!.map(
          (key, value) => MapEntry(key, value.toJson()),
        ),
    };
  }

  factory ProductionWageConfig.fromJson(Map<String, dynamic> json) {
    final productPricingJson =
        json['productSpecificPricing'] as Map<String, dynamic>?;
    final productSpecificPricing = productPricingJson?.map(
      (key, value) => MapEntry(
        key,
        ProductWagePricing.fromJson(value as Map<String, dynamic>),
      ),
    );

    return ProductionWageConfig(
      productionPricePerUnit:
          (json['productionPricePerUnit'] as num?)?.toDouble() ?? 0.0,
      stackingPricePerUnit:
          (json['stackingPricePerUnit'] as num?)?.toDouble() ?? 0.0,
      requiresBatchApproval:
          json['requiresBatchApproval'] as bool? ?? false,
      autoCalculateOnRecord: json['autoCalculateOnRecord'] as bool? ?? true,
      productSpecificPricing: productSpecificPricing,
    );
  }
}

class ProductWagePricing {
  const ProductWagePricing({
    required this.productionPricePerUnit,
    required this.stackingPricePerUnit,
  });

  final double productionPricePerUnit;
  final double stackingPricePerUnit;

  Map<String, dynamic> toJson() {
    return {
      'productionPricePerUnit': productionPricePerUnit,
      'stackingPricePerUnit': stackingPricePerUnit,
    };
  }

  factory ProductWagePricing.fromJson(Map<String, dynamic> json) {
    return ProductWagePricing(
      productionPricePerUnit:
          (json['productionPricePerUnit'] as num?)?.toDouble() ?? 0.0,
      stackingPricePerUnit:
          (json['stackingPricePerUnit'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class LoadingUnloadingConfig implements WageMethodConfig {
  const LoadingUnloadingConfig({
    required this.loadingPercentage,
    required this.unloadingPercentage,
    required this.triggerOnTripDelivery,
    required this.requiresEmployeeSelection,
    this.wagePerQuantity,
    this.wagePerUnit,
  });

  final Map<String, double>? wagePerQuantity; // e.g., "0-1000": 500.0
  final double? wagePerUnit; // Alternative: Fixed rate per unit
  final double loadingPercentage; // Default: 50
  final double unloadingPercentage; // Default: 50
  final bool triggerOnTripDelivery;
  final bool requiresEmployeeSelection;

  @override
  Map<String, dynamic> toJson() {
    return {
      'methodType': 'loadingUnloading',
      if (wagePerQuantity != null) 'wagePerQuantity': wagePerQuantity,
      if (wagePerUnit != null) 'wagePerUnit': wagePerUnit,
      'loadingPercentage': loadingPercentage,
      'unloadingPercentage': unloadingPercentage,
      'triggerOnTripDelivery': triggerOnTripDelivery,
      'requiresEmployeeSelection': requiresEmployeeSelection,
    };
  }

  factory LoadingUnloadingConfig.fromJson(Map<String, dynamic> json) {
    final wagePerQuantityJson = json['wagePerQuantity'] as Map<String, dynamic>?;
    final wagePerQuantity = wagePerQuantityJson?.map(
      (key, value) => MapEntry(key, (value as num).toDouble()),
    );

    return LoadingUnloadingConfig(
      wagePerQuantity: wagePerQuantity,
      wagePerUnit: (json['wagePerUnit'] as num?)?.toDouble(),
      loadingPercentage: (json['loadingPercentage'] as num?)?.toDouble() ?? 50.0,
      unloadingPercentage:
          (json['unloadingPercentage'] as num?)?.toDouble() ?? 50.0,
      triggerOnTripDelivery: json['triggerOnTripDelivery'] as bool? ?? false,
      requiresEmployeeSelection:
          json['requiresEmployeeSelection'] as bool? ?? true,
    );
  }
}

