import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:core_models/core_models.dart';

class EmployeeAttendanceDataSource {
  EmployeeAttendanceDataSource({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _employeeLedgersRef =>
      _firestore.collection('EMPLOYEE_LEDGERS');

  /// Calculate financial year label from a date
  /// Financial year starts in April (month 4)
  /// Format: FY2425 (for April 2024 - March 2025)
  String _getFinancialYear(DateTime date) {
    final year = date.year;
    final month = date.month;
    // Financial year starts in April (month 4)
    if (month >= 4) {
      final startYear = year % 100;
      final endYear = (year + 1) % 100;
      return 'FY${startYear.toString().padLeft(2, '0')}${endYear.toString().padLeft(2, '0')}';
    } else {
      final startYear = (year - 1) % 100;
      final endYear = year % 100;
      return 'FY${startYear.toString().padLeft(2, '0')}${endYear.toString().padLeft(2, '0')}';
    }
  }

  /// Get year-month string in "YYYY-MM" format
  String _getYearMonth(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}';
  }

  /// Normalize date to start of day for comparison
  DateTime _normalizeDate(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  /// Record attendance for an employee when processing a production batch
  Future<void> recordAttendanceForBatch({
    required String organizationId,
    required String employeeId,
    required DateTime batchDate,
    required String batchId,
  }) async {
    final financialYear = _getFinancialYear(batchDate);
    final yearMonth = _getYearMonth(batchDate);
    final ledgerId = '${employeeId}_$financialYear';
    final normalizedDate = _normalizeDate(batchDate);

    final ledgerRef = _employeeLedgersRef.doc(ledgerId);
    final attendanceRef = ledgerRef.collection('Attendance').doc(yearMonth);

    await _firestore.runTransaction((transaction) async {
      // Read attendance document
      final attendanceDoc = await transaction.get(attendanceRef);
      final attendanceData = attendanceDoc.data();

      List<DailyAttendanceRecord> dailyRecords;
      int totalDaysPresent;
      int totalBatchesWorked;

      if (attendanceDoc.exists && attendanceData != null) {
        // Existing attendance document
        final existingAttendance = EmployeeAttendance.fromJson(
          attendanceData,
          yearMonth,
        );
        dailyRecords = List.from(existingAttendance.dailyRecords);

        // Check if record exists for this date
        final dateIndex = dailyRecords.indexWhere((record) {
          return _normalizeDate(record.date) == normalizedDate;
        });

        if (dateIndex >= 0) {
          // Update existing record - increment batch count
          final existingRecord = dailyRecords[dateIndex];
          if (!existingRecord.batchIds.contains(batchId)) {
            dailyRecords[dateIndex] = existingRecord.copyWith(
              numberOfBatches: existingRecord.numberOfBatches + 1,
              batchIds: [...existingRecord.batchIds, batchId],
            );
          }
        } else {
          // Create new daily record
          dailyRecords.add(
            DailyAttendanceRecord(
              date: normalizedDate,
              isPresent: true,
              numberOfBatches: 1,
              batchIds: [batchId],
            ),
          );
        }

        // Recalculate totals
        totalDaysPresent = dailyRecords
            .where((record) => record.isPresent)
            .length;
        totalBatchesWorked = dailyRecords.fold<int>(
          0,
          (sum, record) => sum + record.numberOfBatches,
        );
      } else {
        // Create new attendance document
        dailyRecords = [
          DailyAttendanceRecord(
            date: normalizedDate,
            isPresent: true,
            numberOfBatches: 1,
            batchIds: [batchId],
          ),
        ];
        totalDaysPresent = 1;
        totalBatchesWorked = 1;
      }

      // Prepare attendance data
      final attendanceJson = {
        'yearMonth': yearMonth,
        'employeeId': employeeId,
        'organizationId': organizationId,
        'financialYear': financialYear,
        'dailyRecords': dailyRecords.map((record) => record.toJson()).toList(),
        'totalDaysPresent': totalDaysPresent,
        'totalBatchesWorked': totalBatchesWorked,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (!attendanceDoc.exists) {
        attendanceJson['createdAt'] = FieldValue.serverTimestamp();
        transaction.set(attendanceRef, attendanceJson);
      } else {
        transaction.update(attendanceRef, attendanceJson);
      }
    });
  }

  /// Fetch attendance for a specific month
  Future<EmployeeAttendance?> fetchAttendanceForMonth({
    required String employeeId,
    required String financialYear,
    required String yearMonth, // "YYYY-MM" format
  }) async {
    final ledgerId = '${employeeId}_$financialYear';
    final attendanceRef = _employeeLedgersRef
        .doc(ledgerId)
        .collection('Attendance')
        .doc(yearMonth);

    final doc = await attendanceRef.get();
    if (!doc.exists) return null;

    return EmployeeAttendance.fromJson(doc.data()!, doc.id);
  }

  /// Fetch attendance for a date range
  Future<List<EmployeeAttendance>> fetchAttendanceForDateRange({
    required String employeeId,
    required String financialYear,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final ledgerId = '${employeeId}_$financialYear';
    final attendanceCollection = _employeeLedgersRef
        .doc(ledgerId)
        .collection('Attendance');

    // Generate all year-month strings in the range
    final yearMonths = <String>[];
    var currentDate = DateTime(startDate.year, startDate.month, 1);
    final endMonth = DateTime(endDate.year, endDate.month, 1);

    while (currentDate.isBefore(endMonth) || currentDate.isAtSameMomentAs(endMonth)) {
      yearMonths.add(_getYearMonth(currentDate));
      currentDate = DateTime(currentDate.year, currentDate.month + 1, 1);
    }

    // Fetch all attendance documents in parallel
    final docs = await Future.wait(
      yearMonths.map((yearMonth) => attendanceCollection.doc(yearMonth).get()),
    );

    final attendanceList = <EmployeeAttendance>[];
    for (int i = 0; i < docs.length; i++) {
      final doc = docs[i];
      if (doc.exists && doc.data() != null) {
        attendanceList.add(
          EmployeeAttendance.fromJson(doc.data()!, yearMonths[i]),
        );
      }
    }

    return attendanceList;
  }

  /// Fetch attendance for a specific month across an organization
  /// Uses a collection group query on Attendance subcollections.
  Future<List<EmployeeAttendance>> fetchAttendanceForMonthForOrganization({
    required String organizationId,
    required String financialYear,
    required String yearMonth, // "YYYY-MM" format
  }) async {
    final querySnapshot = await _firestore
        .collectionGroup('Attendance')
        .where('organizationId', isEqualTo: organizationId)
        .where('financialYear', isEqualTo: financialYear)
        .where('yearMonth', isEqualTo: yearMonth)
        .get();

    return querySnapshot.docs
        .map((doc) => EmployeeAttendance.fromJson(doc.data(), doc.id))
        .toList();
  }

  /// Update an existing attendance record
  Future<void> updateAttendanceRecord({
    required String employeeId,
    required String financialYear,
    required String yearMonth,
    required EmployeeAttendance attendance,
  }) async {
    final ledgerId = '${employeeId}_$financialYear';
    final attendanceRef = _employeeLedgersRef
        .doc(ledgerId)
        .collection('Attendance')
        .doc(yearMonth);

    final attendanceJson = attendance.toJson();
    attendanceJson['updatedAt'] = FieldValue.serverTimestamp();

    await attendanceRef.set(attendanceJson, SetOptions(merge: true));
  }

  /// Revert attendance for a batch (remove batch from attendance records)
  Future<void> revertAttendanceForBatch({
    required String organizationId,
    required String employeeId,
    required DateTime batchDate,
    required String batchId,
  }) async {
    final financialYear = _getFinancialYear(batchDate);
    final yearMonth = _getYearMonth(batchDate);
    final ledgerId = '${employeeId}_$financialYear';
    final normalizedDate = _normalizeDate(batchDate);

    final ledgerRef = _employeeLedgersRef.doc(ledgerId);
    final attendanceRef = ledgerRef.collection('Attendance').doc(yearMonth);

    await _firestore.runTransaction((transaction) async {
      // Read attendance document
      final attendanceDoc = await transaction.get(attendanceRef);
      
      if (!attendanceDoc.exists) {
        // No attendance record exists, nothing to revert
        return;
      }

      final attendanceData = attendanceDoc.data()!;
      final existingAttendance = EmployeeAttendance.fromJson(
        attendanceData,
        yearMonth,
      );

      // Find and remove the batch from daily records
      final dailyRecords = List<DailyAttendanceRecord>.from(
        existingAttendance.dailyRecords,
      );

      final dateIndex = dailyRecords.indexWhere((record) {
        return _normalizeDate(record.date) == normalizedDate;
      });

      if (dateIndex < 0) {
        // No record for this date, nothing to revert
        return;
      }

      final existingRecord = dailyRecords[dateIndex];
      
      // Remove batchId from the record
      final updatedBatchIds = existingRecord.batchIds
          .where((id) => id != batchId)
          .toList();

      if (updatedBatchIds.isEmpty) {
        // No more batches for this day, remove the daily record
        dailyRecords.removeAt(dateIndex);
      } else {
        // Update the record with remaining batches
        dailyRecords[dateIndex] = existingRecord.copyWith(
          numberOfBatches: updatedBatchIds.length,
          batchIds: updatedBatchIds,
        );
      }

      // Recalculate totals
      final totalDaysPresent = dailyRecords
          .where((record) => record.isPresent)
          .length;
      final totalBatchesWorked = dailyRecords.fold<int>(
        0,
        (sum, record) => sum + record.numberOfBatches,
      );

      // If no daily records remain, delete the attendance document
      if (dailyRecords.isEmpty) {
        transaction.delete(attendanceRef);
      } else {
        // Update attendance document
        final attendanceJson = {
          'yearMonth': yearMonth,
          'employeeId': employeeId,
          'organizationId': organizationId,
          'financialYear': financialYear,
          'dailyRecords': dailyRecords.map((record) => record.toJson()).toList(),
          'totalDaysPresent': totalDaysPresent,
          'totalBatchesWorked': totalBatchesWorked,
          'updatedAt': FieldValue.serverTimestamp(),
        };
        transaction.update(attendanceRef, attendanceJson);
      }
    });
  }
}
