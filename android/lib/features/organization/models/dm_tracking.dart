import 'package:cloud_firestore/cloud_firestore.dart';

class DmTracking {
  const DmTracking({
    required this.financialYearId,
    required this.startDmNumber,
    required this.currentDmNumber,
    required this.lastDmNumber,
    this.lastAssignedOrderId,
    this.lastAssignedAt,
    this.updatedAt,
  });

  final String financialYearId;
  final int startDmNumber;
  final int currentDmNumber;
  final int lastDmNumber;
  final String? lastAssignedOrderId;
  final DateTime? lastAssignedAt;
  final DateTime? updatedAt;

  factory DmTracking.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data() ?? {};
    return DmTracking(
      financialYearId: snapshot.id,
      startDmNumber: _parseInt(data['startDmNumber'], fallback: 1),
      currentDmNumber: _parseInt(data['currentDmNumber'], fallback: 0),
      lastDmNumber: _parseInt(data['lastDmNumber'], fallback: 0),
      lastAssignedOrderId: data['lastAssignedOrderId'] as String?,
      lastAssignedAt: _parseTimestamp(data['lastAssignedAt']),
      updatedAt: _parseTimestamp(data['updatedAt']),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'startDmNumber': startDmNumber,
      'currentDmNumber': currentDmNumber,
      'lastDmNumber': lastDmNumber,
      if (lastAssignedOrderId != null)
        'lastAssignedOrderId': lastAssignedOrderId,
      if (lastAssignedAt != null)
        'lastAssignedAt': Timestamp.fromDate(lastAssignedAt!),
      if (updatedAt != null) 'updatedAt': Timestamp.fromDate(updatedAt!),
    };
  }

  DmTracking copyWith({
    int? startDmNumber,
    int? currentDmNumber,
    int? lastDmNumber,
    String? lastAssignedOrderId,
    DateTime? lastAssignedAt,
    DateTime? updatedAt,
  }) {
    return DmTracking(
      financialYearId: financialYearId,
      startDmNumber: startDmNumber ?? this.startDmNumber,
      currentDmNumber: currentDmNumber ?? this.currentDmNumber,
      lastDmNumber: lastDmNumber ?? this.lastDmNumber,
      lastAssignedOrderId: lastAssignedOrderId ?? this.lastAssignedOrderId,
      lastAssignedAt: lastAssignedAt ?? this.lastAssignedAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  static int _parseInt(dynamic value, {int fallback = 0}) {
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }

  static DateTime? _parseTimestamp(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }
}


