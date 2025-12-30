import 'package:cloud_firestore/cloud_firestore.dart';

enum VendorType {
  rawMaterial,
  vehicle,
  repairMaintenance,
  welfare,
  fuel,
  utilities,
  rent,
  professionalServices,
  marketingAdvertising,
  insurance,
  logistics,
  officeSupplies,
  security,
  cleaning,
  taxConsultant,
  bankingFinancial,
  other,
}

enum VendorStatus {
  active,
  inactive,
  suspended,
  blacklisted,
}

class Vendor {
  const Vendor({
    required this.id,
    required this.vendorCode,
    required this.name,
    required this.nameLowercase,
    required this.phoneNumber,
    required this.phoneNumberNormalized,
    required this.phones,
    required this.phoneIndex,
    required this.openingBalance,
    required this.currentBalance,
    required this.vendorType,
    required this.status,
    required this.organizationId,
    this.vendorSubType,
    this.gstNumber,
    this.panNumber,
    this.businessName,
    this.contactPerson,
    this.contactPersonPhone,
    this.tags = const [],
    this.notes,
    this.paymentTerms,
    this.rawMaterialDetails,
    this.vehicleDetails,
    this.repairMaintenanceDetails,
    this.welfareDetails,
    this.fuelDetails,
    this.utilitiesDetails,
    this.rentDetails,
    this.professionalServicesDetails,
    this.marketingAdvertisingDetails,
    this.insuranceDetails,
    this.logisticsDetails,
    this.officeSuppliesDetails,
    this.securityDetails,
    this.cleaningDetails,
    this.taxConsultantDetails,
    this.bankingFinancialDetails,
    this.createdBy,
    this.createdAt,
    this.updatedBy,
    this.updatedAt,
    this.lastTransactionDate,
  });

  final String id;
  final String vendorCode;
  final String name;
  final String nameLowercase;
  final String phoneNumber;
  final String phoneNumberNormalized;
  final List<Map<String, String>> phones;
  final List<String> phoneIndex;
  final double openingBalance;
  final double currentBalance;
  final VendorType vendorType;
  final VendorStatus status;
  final String organizationId;
  final String? vendorSubType;
  final String? gstNumber;
  final String? panNumber;
  final String? businessName;
  final String? contactPerson;
  final String? contactPersonPhone;
  final List<String> tags;
  final String? notes;
  final PaymentTerms? paymentTerms;
  
  // Vendor type specific details
  final RawMaterialDetails? rawMaterialDetails;
  final VehicleDetails? vehicleDetails;
  final RepairMaintenanceDetails? repairMaintenanceDetails;
  final WelfareDetails? welfareDetails;
  final FuelDetails? fuelDetails;
  final UtilitiesDetails? utilitiesDetails;
  final RentDetails? rentDetails;
  final ProfessionalServicesDetails? professionalServicesDetails;
  final MarketingAdvertisingDetails? marketingAdvertisingDetails;
  final InsuranceDetails? insuranceDetails;
  final LogisticsDetails? logisticsDetails;
  final OfficeSuppliesDetails? officeSuppliesDetails;
  final SecurityDetails? securityDetails;
  final CleaningDetails? cleaningDetails;
  final TaxConsultantDetails? taxConsultantDetails;
  final BankingFinancialDetails? bankingFinancialDetails;
  
  final String? createdBy;
  final DateTime? createdAt;
  final String? updatedBy;
  final DateTime? updatedAt;
  final DateTime? lastTransactionDate;

  Map<String, dynamic> toJson() {
    return {
      'vendorId': id,
      'vendorCode': vendorCode,
      'name': name,
      'name_lowercase': nameLowercase,
      'phoneNumber': phoneNumber,
      'phoneNumberNormalized': phoneNumberNormalized,
      'phones': phones,
      'phoneIndex': phoneIndex,
      'openingBalance': openingBalance,
      'currentBalance': currentBalance,
      'vendorType': vendorType.name,
      'status': status.name,
      'organizationId': organizationId,
      if (vendorSubType != null) 'vendorSubType': vendorSubType,
      if (gstNumber != null) 'gstNumber': gstNumber,
      if (panNumber != null) 'panNumber': panNumber,
      if (businessName != null) 'businessName': businessName,
      if (contactPerson != null) 'contactPerson': contactPerson,
      if (contactPersonPhone != null) 'contactPersonPhone': contactPersonPhone,
      'tags': tags,
      if (notes != null) 'notes': notes,
      if (paymentTerms != null) 'paymentTerms': paymentTerms!.toJson(),
      if (rawMaterialDetails != null) 'rawMaterialDetails': rawMaterialDetails!.toJson(),
      if (vehicleDetails != null) 'vehicleDetails': vehicleDetails!.toJson(),
      if (repairMaintenanceDetails != null) 'repairMaintenanceDetails': repairMaintenanceDetails!.toJson(),
      if (welfareDetails != null) 'welfareDetails': welfareDetails!.toJson(),
      if (fuelDetails != null) 'fuelDetails': fuelDetails!.toJson(),
      if (utilitiesDetails != null) 'utilitiesDetails': utilitiesDetails!.toJson(),
      if (rentDetails != null) 'rentDetails': rentDetails!.toJson(),
      if (professionalServicesDetails != null) 'professionalServicesDetails': professionalServicesDetails!.toJson(),
      if (marketingAdvertisingDetails != null) 'marketingAdvertisingDetails': marketingAdvertisingDetails!.toJson(),
      if (insuranceDetails != null) 'insuranceDetails': insuranceDetails!.toJson(),
      if (logisticsDetails != null) 'logisticsDetails': logisticsDetails!.toJson(),
      if (officeSuppliesDetails != null) 'officeSuppliesDetails': officeSuppliesDetails!.toJson(),
      if (securityDetails != null) 'securityDetails': securityDetails!.toJson(),
      if (cleaningDetails != null) 'cleaningDetails': cleaningDetails!.toJson(),
      if (taxConsultantDetails != null) 'taxConsultantDetails': taxConsultantDetails!.toJson(),
      if (bankingFinancialDetails != null) 'bankingFinancialDetails': bankingFinancialDetails!.toJson(),
      if (createdBy != null) 'createdBy': createdBy,
      if (createdAt != null) 'createdAt': Timestamp.fromDate(createdAt!),
      if (updatedBy != null) 'updatedBy': updatedBy,
      if (updatedAt != null) 'updatedAt': Timestamp.fromDate(updatedAt!),
      if (lastTransactionDate != null) 'lastTransactionDate': Timestamp.fromDate(lastTransactionDate!),
    };
  }

  factory Vendor.fromJson(Map<String, dynamic> json, String docId) {
    return Vendor(
      id: json['vendorId'] as String? ?? docId,
      vendorCode: json['vendorCode'] as String? ?? '',
      name: json['name'] as String? ?? 'Unnamed Vendor',
      nameLowercase: json['name_lowercase'] as String? ?? (json['name'] as String? ?? '').toLowerCase(),
      phoneNumber: json['phoneNumber'] as String? ?? '',
      phoneNumberNormalized: json['phoneNumberNormalized'] as String? ?? '',
      phones: (json['phones'] as List<dynamic>?)
          ?.map((e) => Map<String, String>.from(e as Map))
          .toList() ?? [],
      phoneIndex: (json['phoneIndex'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList() ?? [],
      openingBalance: (json['openingBalance'] as num?)?.toDouble() ?? 0,
      currentBalance: (json['currentBalance'] as num?)?.toDouble() ?? 0,
      vendorType: VendorType.values.firstWhere(
        (type) => type.name == json['vendorType'],
        orElse: () => VendorType.other,
      ),
      status: VendorStatus.values.firstWhere(
        (status) => status.name == json['status'],
        orElse: () => VendorStatus.active,
      ),
      organizationId: json['organizationId'] as String? ?? '',
      vendorSubType: json['vendorSubType'] as String?,
      gstNumber: json['gstNumber'] as String?,
      panNumber: json['panNumber'] as String?,
      businessName: json['businessName'] as String?,
      contactPerson: json['contactPerson'] as String?,
      contactPersonPhone: json['contactPersonPhone'] as String?,
      tags: (json['tags'] as List<dynamic>?)?.map((e) => e as String).toList() ?? [],
      notes: json['notes'] as String?,
      paymentTerms: json['paymentTerms'] != null
          ? PaymentTerms.fromJson(json['paymentTerms'] as Map<String, dynamic>)
          : null,
      rawMaterialDetails: json['rawMaterialDetails'] != null
          ? RawMaterialDetails.fromJson(json['rawMaterialDetails'] as Map<String, dynamic>)
          : null,
      vehicleDetails: json['vehicleDetails'] != null
          ? VehicleDetails.fromJson(json['vehicleDetails'] as Map<String, dynamic>)
          : null,
      repairMaintenanceDetails: json['repairMaintenanceDetails'] != null
          ? RepairMaintenanceDetails.fromJson(json['repairMaintenanceDetails'] as Map<String, dynamic>)
          : null,
      welfareDetails: json['welfareDetails'] != null
          ? WelfareDetails.fromJson(json['welfareDetails'] as Map<String, dynamic>)
          : null,
      fuelDetails: json['fuelDetails'] != null
          ? FuelDetails.fromJson(json['fuelDetails'] as Map<String, dynamic>)
          : null,
      utilitiesDetails: json['utilitiesDetails'] != null
          ? UtilitiesDetails.fromJson(json['utilitiesDetails'] as Map<String, dynamic>)
          : null,
      rentDetails: json['rentDetails'] != null
          ? RentDetails.fromJson(json['rentDetails'] as Map<String, dynamic>)
          : null,
      professionalServicesDetails: json['professionalServicesDetails'] != null
          ? ProfessionalServicesDetails.fromJson(json['professionalServicesDetails'] as Map<String, dynamic>)
          : null,
      marketingAdvertisingDetails: json['marketingAdvertisingDetails'] != null
          ? MarketingAdvertisingDetails.fromJson(json['marketingAdvertisingDetails'] as Map<String, dynamic>)
          : null,
      insuranceDetails: json['insuranceDetails'] != null
          ? InsuranceDetails.fromJson(json['insuranceDetails'] as Map<String, dynamic>)
          : null,
      logisticsDetails: json['logisticsDetails'] != null
          ? LogisticsDetails.fromJson(json['logisticsDetails'] as Map<String, dynamic>)
          : null,
      officeSuppliesDetails: json['officeSuppliesDetails'] != null
          ? OfficeSuppliesDetails.fromJson(json['officeSuppliesDetails'] as Map<String, dynamic>)
          : null,
      securityDetails: json['securityDetails'] != null
          ? SecurityDetails.fromJson(json['securityDetails'] as Map<String, dynamic>)
          : null,
      cleaningDetails: json['cleaningDetails'] != null
          ? CleaningDetails.fromJson(json['cleaningDetails'] as Map<String, dynamic>)
          : null,
      taxConsultantDetails: json['taxConsultantDetails'] != null
          ? TaxConsultantDetails.fromJson(json['taxConsultantDetails'] as Map<String, dynamic>)
          : null,
      bankingFinancialDetails: json['bankingFinancialDetails'] != null
          ? BankingFinancialDetails.fromJson(json['bankingFinancialDetails'] as Map<String, dynamic>)
          : null,
      createdBy: json['createdBy'] as String?,
      createdAt: (json['createdAt'] as Timestamp?)?.toDate(),
      updatedBy: json['updatedBy'] as String?,
      updatedAt: (json['updatedAt'] as Timestamp?)?.toDate(),
      lastTransactionDate: (json['lastTransactionDate'] as Timestamp?)?.toDate(),
    );
  }

  Vendor copyWith({
    String? id,
    String? vendorCode,
    String? name,
    String? nameLowercase,
    String? phoneNumber,
    String? phoneNumberNormalized,
    List<Map<String, String>>? phones,
    List<String>? phoneIndex,
    double? openingBalance,
    double? currentBalance,
    VendorType? vendorType,
    VendorStatus? status,
    String? organizationId,
    String? vendorSubType,
    String? gstNumber,
    String? panNumber,
    String? businessName,
    String? contactPerson,
    String? contactPersonPhone,
    List<String>? tags,
    String? notes,
    PaymentTerms? paymentTerms,
    String? updatedBy,
    DateTime? updatedAt,
  }) {
    return Vendor(
      id: id ?? this.id,
      vendorCode: vendorCode ?? this.vendorCode,
      name: name ?? this.name,
      nameLowercase: nameLowercase ?? this.nameLowercase,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      phoneNumberNormalized: phoneNumberNormalized ?? this.phoneNumberNormalized,
      phones: phones ?? this.phones,
      phoneIndex: phoneIndex ?? this.phoneIndex,
      openingBalance: openingBalance ?? this.openingBalance,
      currentBalance: currentBalance ?? this.currentBalance,
      vendorType: vendorType ?? this.vendorType,
      status: status ?? this.status,
      organizationId: organizationId ?? this.organizationId,
      vendorSubType: vendorSubType ?? this.vendorSubType,
      gstNumber: gstNumber ?? this.gstNumber,
      panNumber: panNumber ?? this.panNumber,
      businessName: businessName ?? this.businessName,
      contactPerson: contactPerson ?? this.contactPerson,
      contactPersonPhone: contactPersonPhone ?? this.contactPersonPhone,
      tags: tags ?? this.tags,
      notes: notes ?? this.notes,
      paymentTerms: paymentTerms ?? this.paymentTerms,
      rawMaterialDetails: rawMaterialDetails,
      vehicleDetails: vehicleDetails,
      repairMaintenanceDetails: repairMaintenanceDetails,
      welfareDetails: welfareDetails,
      fuelDetails: fuelDetails,
      utilitiesDetails: utilitiesDetails,
      rentDetails: rentDetails,
      professionalServicesDetails: professionalServicesDetails,
      marketingAdvertisingDetails: marketingAdvertisingDetails,
      insuranceDetails: insuranceDetails,
      logisticsDetails: logisticsDetails,
      officeSuppliesDetails: officeSuppliesDetails,
      securityDetails: securityDetails,
      cleaningDetails: cleaningDetails,
      taxConsultantDetails: taxConsultantDetails,
      bankingFinancialDetails: bankingFinancialDetails,
      createdBy: createdBy,
      createdAt: createdAt,
      updatedBy: updatedBy ?? this.updatedBy,
      updatedAt: updatedAt ?? this.updatedAt,
      lastTransactionDate: lastTransactionDate,
    );
  }
}

// Payment Terms
class PaymentTerms {
  const PaymentTerms({
    this.creditDays,
    this.creditLimit,
    this.paymentMode,
    this.bankDetails,
  });

  final int? creditDays;
  final double? creditLimit;
  final String? paymentMode;
  final BankDetails? bankDetails;

  Map<String, dynamic> toJson() {
    return {
      if (creditDays != null) 'creditDays': creditDays,
      if (creditLimit != null) 'creditLimit': creditLimit,
      if (paymentMode != null) 'paymentMode': paymentMode,
      if (bankDetails != null) 'bankDetails': bankDetails!.toJson(),
    };
  }

  factory PaymentTerms.fromJson(Map<String, dynamic> json) {
    return PaymentTerms(
      creditDays: json['creditDays'] as int?,
      creditLimit: (json['creditLimit'] as num?)?.toDouble(),
      paymentMode: json['paymentMode'] as String?,
      bankDetails: json['bankDetails'] != null
          ? BankDetails.fromJson(json['bankDetails'] as Map<String, dynamic>)
          : null,
    );
  }
}

class BankDetails {
  const BankDetails({
    this.accountNumber,
    this.ifscCode,
    this.bankName,
    this.accountHolderName,
  });

  final String? accountNumber;
  final String? ifscCode;
  final String? bankName;
  final String? accountHolderName;

  Map<String, dynamic> toJson() {
    return {
      if (accountNumber != null) 'accountNumber': accountNumber,
      if (ifscCode != null) 'ifscCode': ifscCode,
      if (bankName != null) 'bankName': bankName,
      if (accountHolderName != null) 'accountHolderName': accountHolderName,
    };
  }

  factory BankDetails.fromJson(Map<String, dynamic> json) {
    return BankDetails(
      accountNumber: json['accountNumber'] as String?,
      ifscCode: json['ifscCode'] as String?,
      bankName: json['bankName'] as String?,
      accountHolderName: json['accountHolderName'] as String?,
    );
  }
}

// Vendor Type Specific Details Classes
class RawMaterialDetails {
  const RawMaterialDetails({
    this.materialCategories = const [],
    this.unitOfMeasurement,
    this.qualityCertifications = const [],
    this.deliveryCapability,
    this.assignedMaterialIds = const [],
  });

  final List<String> materialCategories;
  final String? unitOfMeasurement;
  final List<String> qualityCertifications;
  final DeliveryCapability? deliveryCapability;
  final List<String> assignedMaterialIds; // List of raw material IDs assigned to this vendor

  Map<String, dynamic> toJson() {
    return {
      'materialCategories': materialCategories,
      if (unitOfMeasurement != null) 'unitOfMeasurement': unitOfMeasurement,
      'qualityCertifications': qualityCertifications,
      if (deliveryCapability != null) 'deliveryCapability': deliveryCapability!.toJson(),
      'assignedMaterialIds': assignedMaterialIds,
    };
  }

  factory RawMaterialDetails.fromJson(Map<String, dynamic> json) {
    return RawMaterialDetails(
      materialCategories: (json['materialCategories'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList() ?? [],
      unitOfMeasurement: json['unitOfMeasurement'] as String?,
      qualityCertifications: (json['qualityCertifications'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList() ?? [],
      deliveryCapability: json['deliveryCapability'] != null
          ? DeliveryCapability.fromJson(json['deliveryCapability'] as Map<String, dynamic>)
          : null,
      assignedMaterialIds: (json['assignedMaterialIds'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList() ?? [],
    );
  }
}

class DeliveryCapability {
  const DeliveryCapability({
    required this.canDeliver,
    this.deliveryRadius,
    this.minOrderQuantity,
  });

  final bool canDeliver;
  final double? deliveryRadius;
  final double? minOrderQuantity;

  Map<String, dynamic> toJson() {
    return {
      'canDeliver': canDeliver,
      if (deliveryRadius != null) 'deliveryRadius': deliveryRadius,
      if (minOrderQuantity != null) 'minOrderQuantity': minOrderQuantity,
    };
  }

  factory DeliveryCapability.fromJson(Map<String, dynamic> json) {
    return DeliveryCapability(
      canDeliver: json['canDeliver'] as bool? ?? false,
      deliveryRadius: (json['deliveryRadius'] as num?)?.toDouble(),
      minOrderQuantity: (json['minOrderQuantity'] as num?)?.toDouble(),
    );
  }
}

// Simplified versions for other vendor types (can be expanded later)
class VehicleDetails {
  const VehicleDetails({
    this.vehicleTypes = const [],
    this.serviceTypes = const [],
    this.fleetSize,
    this.insuranceProvider,
    this.maintenanceIncluded,
  });

  final List<String> vehicleTypes;
  final List<String> serviceTypes;
  final int? fleetSize;
  final bool? insuranceProvider;
  final bool? maintenanceIncluded;

  Map<String, dynamic> toJson() {
    return {
      'vehicleTypes': vehicleTypes,
      'serviceTypes': serviceTypes,
      if (fleetSize != null) 'fleetSize': fleetSize,
      if (insuranceProvider != null) 'insuranceProvider': insuranceProvider,
      if (maintenanceIncluded != null) 'maintenanceIncluded': maintenanceIncluded,
    };
  }

  factory VehicleDetails.fromJson(Map<String, dynamic> json) {
    return VehicleDetails(
      vehicleTypes: (json['vehicleTypes'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList() ?? [],
      serviceTypes: (json['serviceTypes'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList() ?? [],
      fleetSize: json['fleetSize'] as int?,
      insuranceProvider: json['insuranceProvider'] as bool?,
      maintenanceIncluded: json['maintenanceIncluded'] as bool?,
    );
  }
}

class RepairMaintenanceDetails {
  const RepairMaintenanceDetails({
    this.serviceCategories = const [],
    this.specialization = const [],
    this.responseTime,
    this.warrantyPeriod,
    this.serviceRadius,
  });

  final List<String> serviceCategories;
  final List<String> specialization;
  final String? responseTime;
  final int? warrantyPeriod;
  final double? serviceRadius;

  Map<String, dynamic> toJson() {
    return {
      'serviceCategories': serviceCategories,
      'specialization': specialization,
      if (responseTime != null) 'responseTime': responseTime,
      if (warrantyPeriod != null) 'warrantyPeriod': warrantyPeriod,
      if (serviceRadius != null) 'serviceRadius': serviceRadius,
    };
  }

  factory RepairMaintenanceDetails.fromJson(Map<String, dynamic> json) {
    return RepairMaintenanceDetails(
      serviceCategories: (json['serviceCategories'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList() ?? [],
      specialization: (json['specialization'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList() ?? [],
      responseTime: json['responseTime'] as String?,
      warrantyPeriod: json['warrantyPeriod'] as int?,
      serviceRadius: (json['serviceRadius'] as num?)?.toDouble(),
    );
  }
}

class WelfareDetails {
  const WelfareDetails({
    this.serviceTypes = const [],
    this.employeeCapacity,
    this.contractPeriod,
  });

  final List<String> serviceTypes;
  final int? employeeCapacity;
  final ContractPeriod? contractPeriod;

  Map<String, dynamic> toJson() {
    return {
      'serviceTypes': serviceTypes,
      if (employeeCapacity != null) 'employeeCapacity': employeeCapacity,
      if (contractPeriod != null) 'contractPeriod': contractPeriod!.toJson(),
    };
  }

  factory WelfareDetails.fromJson(Map<String, dynamic> json) {
    return WelfareDetails(
      serviceTypes: (json['serviceTypes'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList() ?? [],
      employeeCapacity: json['employeeCapacity'] as int?,
      contractPeriod: json['contractPeriod'] != null
          ? ContractPeriod.fromJson(json['contractPeriod'] as Map<String, dynamic>)
          : null,
    );
  }
}

class ContractPeriod {
  const ContractPeriod({
    this.startDate,
    this.endDate,
  });

  final DateTime? startDate;
  final DateTime? endDate;

  Map<String, dynamic> toJson() {
    return {
      if (startDate != null) 'startDate': Timestamp.fromDate(startDate!),
      if (endDate != null) 'endDate': Timestamp.fromDate(endDate!),
    };
  }

  factory ContractPeriod.fromJson(Map<String, dynamic> json) {
    return ContractPeriod(
      startDate: (json['startDate'] as Timestamp?)?.toDate(),
      endDate: (json['endDate'] as Timestamp?)?.toDate(),
    );
  }
}

class FuelDetails {
  const FuelDetails({
    this.fuelTypes = const [],
    this.stationLocation,
    this.creditLimit,
    this.discountPercentage,
  });

  final List<String> fuelTypes;
  final String? stationLocation;
  final double? creditLimit;
  final double? discountPercentage;

  Map<String, dynamic> toJson() {
    return {
      'fuelTypes': fuelTypes,
      if (stationLocation != null) 'stationLocation': stationLocation,
      if (creditLimit != null) 'creditLimit': creditLimit,
      if (discountPercentage != null) 'discountPercentage': discountPercentage,
    };
  }

  factory FuelDetails.fromJson(Map<String, dynamic> json) {
    return FuelDetails(
      fuelTypes: (json['fuelTypes'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList() ?? [],
      stationLocation: json['stationLocation'] as String?,
      creditLimit: (json['creditLimit'] as num?)?.toDouble(),
      discountPercentage: (json['discountPercentage'] as num?)?.toDouble(),
    );
  }
}

class UtilitiesDetails {
  const UtilitiesDetails({
    this.utilityTypes = const [],
    this.accountNumbers = const [],
    this.billingCycle,
    this.autoPayEnabled,
  });

  final List<String> utilityTypes;
  final List<String> accountNumbers;
  final String? billingCycle;
  final bool? autoPayEnabled;

  Map<String, dynamic> toJson() {
    return {
      'utilityTypes': utilityTypes,
      'accountNumbers': accountNumbers,
      if (billingCycle != null) 'billingCycle': billingCycle,
      if (autoPayEnabled != null) 'autoPayEnabled': autoPayEnabled,
    };
  }

  factory UtilitiesDetails.fromJson(Map<String, dynamic> json) {
    return UtilitiesDetails(
      utilityTypes: (json['utilityTypes'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList() ?? [],
      accountNumbers: (json['accountNumbers'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList() ?? [],
      billingCycle: json['billingCycle'] as String?,
      autoPayEnabled: json['autoPayEnabled'] as bool?,
    );
  }
}

class RentDetails {
  const RentDetails({
    this.propertyType,
    this.monthlyRent,
    this.securityDeposit,
    this.leaseStartDate,
    this.leaseEndDate,
    this.propertyAddress,
  });

  final String? propertyType;
  final double? monthlyRent;
  final double? securityDeposit;
  final DateTime? leaseStartDate;
  final DateTime? leaseEndDate;
  final String? propertyAddress;

  Map<String, dynamic> toJson() {
    return {
      if (propertyType != null) 'propertyType': propertyType,
      if (monthlyRent != null) 'monthlyRent': monthlyRent,
      if (securityDeposit != null) 'securityDeposit': securityDeposit,
      if (leaseStartDate != null) 'leaseStartDate': Timestamp.fromDate(leaseStartDate!),
      if (leaseEndDate != null) 'leaseEndDate': Timestamp.fromDate(leaseEndDate!),
      if (propertyAddress != null) 'propertyAddress': propertyAddress,
    };
  }

  factory RentDetails.fromJson(Map<String, dynamic> json) {
    return RentDetails(
      propertyType: json['propertyType'] as String?,
      monthlyRent: (json['monthlyRent'] as num?)?.toDouble(),
      securityDeposit: (json['securityDeposit'] as num?)?.toDouble(),
      leaseStartDate: (json['leaseStartDate'] as Timestamp?)?.toDate(),
      leaseEndDate: (json['leaseEndDate'] as Timestamp?)?.toDate(),
      propertyAddress: json['propertyAddress'] as String?,
    );
  }
}

class ProfessionalServicesDetails {
  const ProfessionalServicesDetails({
    this.serviceTypes = const [],
    this.hourlyRate,
    this.retainerFee,
    this.licenseNumbers = const [],
  });

  final List<String> serviceTypes;
  final double? hourlyRate;
  final double? retainerFee;
  final List<String> licenseNumbers;

  Map<String, dynamic> toJson() {
    return {
      'serviceTypes': serviceTypes,
      if (hourlyRate != null) 'hourlyRate': hourlyRate,
      if (retainerFee != null) 'retainerFee': retainerFee,
      'licenseNumbers': licenseNumbers,
    };
  }

  factory ProfessionalServicesDetails.fromJson(Map<String, dynamic> json) {
    return ProfessionalServicesDetails(
      serviceTypes: (json['serviceTypes'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList() ?? [],
      hourlyRate: (json['hourlyRate'] as num?)?.toDouble(),
      retainerFee: (json['retainerFee'] as num?)?.toDouble(),
      licenseNumbers: (json['licenseNumbers'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList() ?? [],
    );
  }
}

class MarketingAdvertisingDetails {
  const MarketingAdvertisingDetails({
    this.serviceTypes = const [],
    this.campaignTypes = const [],
  });

  final List<String> serviceTypes;
  final List<String> campaignTypes;

  Map<String, dynamic> toJson() {
    return {
      'serviceTypes': serviceTypes,
      'campaignTypes': campaignTypes,
    };
  }

  factory MarketingAdvertisingDetails.fromJson(Map<String, dynamic> json) {
    return MarketingAdvertisingDetails(
      serviceTypes: (json['serviceTypes'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList() ?? [],
      campaignTypes: (json['campaignTypes'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList() ?? [],
    );
  }
}

class InsuranceDetails {
  const InsuranceDetails({
    this.insuranceTypes = const [],
    this.policyNumbers = const [],
    this.renewalDate,
    this.premiumAmount,
  });

  final List<String> insuranceTypes;
  final List<String> policyNumbers;
  final DateTime? renewalDate;
  final double? premiumAmount;

  Map<String, dynamic> toJson() {
    return {
      'insuranceTypes': insuranceTypes,
      'policyNumbers': policyNumbers,
      if (renewalDate != null) 'renewalDate': Timestamp.fromDate(renewalDate!),
      if (premiumAmount != null) 'premiumAmount': premiumAmount,
    };
  }

  factory InsuranceDetails.fromJson(Map<String, dynamic> json) {
    return InsuranceDetails(
      insuranceTypes: (json['insuranceTypes'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList() ?? [],
      policyNumbers: (json['policyNumbers'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList() ?? [],
      renewalDate: (json['renewalDate'] as Timestamp?)?.toDate(),
      premiumAmount: (json['premiumAmount'] as num?)?.toDouble(),
    );
  }
}

class LogisticsDetails {
  const LogisticsDetails({
    this.serviceTypes = const [],
    this.coverageAreas = const [],
    this.vehicleTypes = const [],
    this.trackingEnabled,
  });

  final List<String> serviceTypes;
  final List<String> coverageAreas;
  final List<String> vehicleTypes;
  final bool? trackingEnabled;

  Map<String, dynamic> toJson() {
    return {
      'serviceTypes': serviceTypes,
      'coverageAreas': coverageAreas,
      'vehicleTypes': vehicleTypes,
      if (trackingEnabled != null) 'trackingEnabled': trackingEnabled,
    };
  }

  factory LogisticsDetails.fromJson(Map<String, dynamic> json) {
    return LogisticsDetails(
      serviceTypes: (json['serviceTypes'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList() ?? [],
      coverageAreas: (json['coverageAreas'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList() ?? [],
      vehicleTypes: (json['vehicleTypes'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList() ?? [],
      trackingEnabled: json['trackingEnabled'] as bool?,
    );
  }
}

class OfficeSuppliesDetails {
  const OfficeSuppliesDetails({
    this.categories = const [],
    this.catalogAvailable,
    this.bulkDiscount,
  });

  final List<String> categories;
  final bool? catalogAvailable;
  final bool? bulkDiscount;

  Map<String, dynamic> toJson() {
    return {
      'categories': categories,
      if (catalogAvailable != null) 'catalogAvailable': catalogAvailable,
      if (bulkDiscount != null) 'bulkDiscount': bulkDiscount,
    };
  }

  factory OfficeSuppliesDetails.fromJson(Map<String, dynamic> json) {
    return OfficeSuppliesDetails(
      categories: (json['categories'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList() ?? [],
      catalogAvailable: json['catalogAvailable'] as bool?,
      bulkDiscount: json['bulkDiscount'] as bool?,
    );
  }
}

class SecurityDetails {
  const SecurityDetails({
    this.serviceTypes = const [],
    this.numberOfGuards,
    this.shiftTimings,
  });

  final List<String> serviceTypes;
  final int? numberOfGuards;
  final String? shiftTimings;

  Map<String, dynamic> toJson() {
    return {
      'serviceTypes': serviceTypes,
      if (numberOfGuards != null) 'numberOfGuards': numberOfGuards,
      if (shiftTimings != null) 'shiftTimings': shiftTimings,
    };
  }

  factory SecurityDetails.fromJson(Map<String, dynamic> json) {
    return SecurityDetails(
      serviceTypes: (json['serviceTypes'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList() ?? [],
      numberOfGuards: json['numberOfGuards'] as int?,
      shiftTimings: json['shiftTimings'] as String?,
    );
  }
}

class CleaningDetails {
  const CleaningDetails({
    this.serviceTypes = const [],
    this.frequency,
    this.numberOfStaff,
  });

  final List<String> serviceTypes;
  final String? frequency;
  final int? numberOfStaff;

  Map<String, dynamic> toJson() {
    return {
      'serviceTypes': serviceTypes,
      if (frequency != null) 'frequency': frequency,
      if (numberOfStaff != null) 'numberOfStaff': numberOfStaff,
    };
  }

  factory CleaningDetails.fromJson(Map<String, dynamic> json) {
    return CleaningDetails(
      serviceTypes: (json['serviceTypes'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList() ?? [],
      frequency: json['frequency'] as String?,
      numberOfStaff: json['numberOfStaff'] as int?,
    );
  }
}

class TaxConsultantDetails {
  const TaxConsultantDetails({
    this.services = const [],
    this.caNumber,
    this.firmName,
  });

  final List<String> services;
  final String? caNumber;
  final String? firmName;

  Map<String, dynamic> toJson() {
    return {
      'services': services,
      if (caNumber != null) 'caNumber': caNumber,
      if (firmName != null) 'firmName': firmName,
    };
  }

  factory TaxConsultantDetails.fromJson(Map<String, dynamic> json) {
    return TaxConsultantDetails(
      services: (json['services'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList() ?? [],
      caNumber: json['caNumber'] as String?,
      firmName: json['firmName'] as String?,
    );
  }
}

class BankingFinancialDetails {
  const BankingFinancialDetails({
    this.serviceTypes = const [],
    this.accountNumbers = const [],
    this.creditLimit,
    this.interestRate,
  });

  final List<String> serviceTypes;
  final List<String> accountNumbers;
  final double? creditLimit;
  final double? interestRate;

  Map<String, dynamic> toJson() {
    return {
      'serviceTypes': serviceTypes,
      'accountNumbers': accountNumbers,
      if (creditLimit != null) 'creditLimit': creditLimit,
      if (interestRate != null) 'interestRate': interestRate,
    };
  }

  factory BankingFinancialDetails.fromJson(Map<String, dynamic> json) {
    return BankingFinancialDetails(
      serviceTypes: (json['serviceTypes'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList() ?? [],
      accountNumbers: (json['accountNumbers'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList() ?? [],
      creditLimit: (json['creditLimit'] as num?)?.toDouble(),
      interestRate: (json['interestRate'] as num?)?.toDouble(),
    );
  }
}


