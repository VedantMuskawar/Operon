import 'package:cloud_firestore/cloud_firestore.dart';

class DailyAttendanceRecord {
  const DailyAttendanceRecord({
    required this.date,
    required this.isPresent,
    required this.numberOfBatches,
    required this.batchIds,
  });

  final DateTime date;
  final bool isPresent;
  final int numberOfBatches;
  final List<String> batchIds;

  Map<String, dynamic> toJson() {
    return {
      'date': Timestamp.fromDate(date),
      'isPresent': isPresent,
      'numberOfBatches': numberOfBatches,
      'batchIds': batchIds,
    };
  }

  factory DailyAttendanceRecord.fromJson(Map<String, dynamic> json) {
    return DailyAttendanceRecord(
      date: (json['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isPresent: json['isPresent'] as bool? ?? false,
      numberOfBatches: (json['numberOfBatches'] as num?)?.toInt() ?? 0,
      batchIds: json['batchIds'] != null
          ? List<String>.from(json['batchIds'] as List)
          : [],
    );
  }

  DailyAttendanceRecord copyWith({
    DateTime? date,
    bool? isPresent,
    int? numberOfBatches,
    List<String>? batchIds,
  }) {
    return DailyAttendanceRecord(
      date: date ?? this.date,
      isPresent: isPresent ?? this.isPresent,
      numberOfBatches: numberOfBatches ?? this.numberOfBatches,
      batchIds: batchIds ?? this.batchIds,
    );
  }
}

class EmployeeAttendance {
  const EmployeeAttendance({
    required this.yearMonth,
    required this.employeeId,
    required this.organizationId,
    required this.financialYear,
    required this.dailyRecords,
    required this.totalDaysPresent,
    required this.totalBatchesWorked,
    required this.createdAt,
    required this.updatedAt,
  });

  final String yearMonth; // "YYYY-MM" format
  final String employeeId;
  final String organizationId;
  final String financialYear;
  final List<DailyAttendanceRecord> dailyRecords;
  final int totalDaysPresent;
  final int totalBatchesWorked;
  final DateTime createdAt;
  final DateTime updatedAt;

  Map<String, dynamic> toJson() {
    return {
      'yearMonth': yearMonth,
      'employeeId': employeeId,
      'organizationId': organizationId,
      'financialYear': financialYear,
      'dailyRecords': dailyRecords.map((record) => record.toJson()).toList(),
      'totalDaysPresent': totalDaysPresent,
      'totalBatchesWorked': totalBatchesWorked,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  factory EmployeeAttendance.fromJson(
    Map<String, dynamic> json,
    String docId,
  ) {
    final dailyRecordsList = json['dailyRecords'] as List<dynamic>? ?? [];
    final dailyRecords = dailyRecordsList
        .map((record) => DailyAttendanceRecord.fromJson(
              record as Map<String, dynamic>,
            ))
        .toList();

    return EmployeeAttendance(
      yearMonth: json['yearMonth'] as String? ?? docId,
      employeeId: json['employeeId'] as String? ?? '',
      organizationId: json['organizationId'] as String? ?? '',
      financialYear: json['financialYear'] as String? ?? '',
      dailyRecords: dailyRecords,
      totalDaysPresent: (json['totalDaysPresent'] as num?)?.toInt() ?? 0,
      totalBatchesWorked: (json['totalBatchesWorked'] as num?)?.toInt() ?? 0,
      createdAt: (json['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (json['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  EmployeeAttendance copyWith({
    String? yearMonth,
    String? employeeId,
    String? organizationId,
    String? financialYear,
    List<DailyAttendanceRecord>? dailyRecords,
    int? totalDaysPresent,
    int? totalBatchesWorked,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return EmployeeAttendance(
      yearMonth: yearMonth ?? this.yearMonth,
      employeeId: employeeId ?? this.employeeId,
      organizationId: organizationId ?? this.organizationId,
      financialYear: financialYear ?? this.financialYear,
      dailyRecords: dailyRecords ?? this.dailyRecords,
      totalDaysPresent: totalDaysPresent ?? this.totalDaysPresent,
      totalBatchesWorked: totalBatchesWorked ?? this.totalBatchesWorked,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
