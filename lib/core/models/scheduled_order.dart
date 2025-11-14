import 'package:cloud_firestore/cloud_firestore.dart';

class ScheduledOrder {
  final String id;
  final String schOrderId;
  final String organizationId;
  final String orderId;
  final String clientId;
  final String vehicleId;
  final DocumentReference<Map<String, dynamic>>? orderRef;
  final DocumentReference<Map<String, dynamic>>? vehicleRef;
  final DateTime scheduledDate;
  final int slotIndex;
  final String slotLabel;
  final int capacityPerSlot;
  final int quantity;
  final String status;
  final DateTime scheduledAt;
  final String scheduledBy;
  final DateTime? rescheduledAt;
  final String? rescheduledBy;
  final int rescheduleCount;
  final String? previousScheduleId;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<String> productNames;
  final String paymentType;
  final double totalAmount;
  final double gstAmount;
  final String orderRegion;
  final String orderCity;
  final String? clientName;
  final String? clientPhone;
  final String? driverName;
  final String? driverPhone;
  final double unitPrice;
  final bool gstApplicable;
  final double gstRate;
  final DateTime? dispatchedAt;
  final String? dispatchedBy;
  final int? dmNumber;
  final String? dmFinancialYearId;
  final DateTime? dmGeneratedAt;
  final String? dmOrderId;
  final String tripStage;
  final double? initialMeterReading;
  final DateTime? initialMeterRecordedAt;
  final String? initialMeterRecordedBy;
  final double? finalMeterReading;
  final DateTime? finalMeterRecordedAt;
  final String? finalMeterRecordedBy;
  final String? deliveryProofUrl;
  final DateTime? deliveryProofRecordedAt;
  final String? deliveryProofRecordedBy;

  const ScheduledOrder({
    required this.id,
    required this.schOrderId,
    required this.organizationId,
    required this.orderId,
    required this.clientId,
    required this.vehicleId,
    this.orderRef,
    this.vehicleRef,
    required this.scheduledDate,
    required this.slotIndex,
    required this.slotLabel,
    required this.capacityPerSlot,
    required this.quantity,
    required this.status,
    required this.scheduledAt,
    required this.scheduledBy,
    this.rescheduledAt,
    this.rescheduledBy,
    required this.rescheduleCount,
    this.previousScheduleId,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
    required this.productNames,
    required this.paymentType,
    required this.totalAmount,
    required this.gstAmount,
    required this.orderRegion,
    required this.orderCity,
    this.clientName,
    this.clientPhone,
    this.driverName,
    this.driverPhone,
    required this.unitPrice,
    this.gstApplicable = false,
    this.gstRate = 0,
    this.dispatchedAt,
    this.dispatchedBy,
    this.dmNumber,
    this.dmFinancialYearId,
    this.dmGeneratedAt,
    this.dmOrderId,
    this.tripStage = ScheduledOrderTripStage.pending,
    this.initialMeterReading,
    this.initialMeterRecordedAt,
    this.initialMeterRecordedBy,
    this.finalMeterReading,
    this.finalMeterRecordedAt,
    this.finalMeterRecordedBy,
    this.deliveryProofUrl,
    this.deliveryProofRecordedAt,
    this.deliveryProofRecordedBy,
  });

  factory ScheduledOrder.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data() ?? <String, dynamic>{};

    return ScheduledOrder(
      id: snapshot.id,
      schOrderId: (data['schOrderId'] as String?) ?? snapshot.id,
      organizationId: (data['organizationId'] as String?) ?? '',
      orderId: (data['orderId'] as String?) ?? '',
      clientId: (data['clientId'] as String?) ?? '',
      vehicleId: (data['vehicleId'] as String?) ?? '',
      orderRef: data['orderRef'] is DocumentReference
          ? data['orderRef'] as DocumentReference<Map<String, dynamic>>
          : null,
      vehicleRef: data['vehicleRef'] is DocumentReference
          ? data['vehicleRef'] as DocumentReference<Map<String, dynamic>>
          : null,
      scheduledDate: _parseTimestamp(data['scheduledDate']),
      slotIndex: _parseInt(data['slotIndex']),
      slotLabel: (data['slotLabel'] as String?) ?? 'Slot',
      capacityPerSlot: _parseInt(data['capacityPerSlot']),
      quantity: _parseInt(data['quantity']),
      status: (data['status'] as String?) ?? ScheduledOrderStatus.scheduled,
      scheduledAt: _parseTimestamp(data['scheduledAt']),
      scheduledBy: (data['scheduledBy'] as String?) ?? '',
      rescheduledAt: _parseNullableTimestamp(data['rescheduledAt']),
      rescheduledBy: data['rescheduledBy'] as String?,
      rescheduleCount: _parseInt(data['rescheduleCount']),
      previousScheduleId: data['previousScheduleId'] as String?,
      notes: data['notes'] as String?,
      createdAt: _parseTimestamp(data['createdAt']),
      updatedAt: _parseTimestamp(data['updatedAt']),
      productNames: _parseStringList(data['productNames']),
      paymentType: (data['paymentType'] as String?) ?? '',
      totalAmount: _parseDouble(data['totalAmount']),
      gstAmount: _parseDouble(data['gstAmount']),
      orderRegion: (data['orderRegion'] as String?) ?? '',
      orderCity: (data['orderCity'] as String?) ?? '',
      clientName: data['clientName'] as String?,
      clientPhone: data['clientPhone'] as String?,
      driverName: data['driverName'] as String?,
      driverPhone: data['driverPhone'] as String?,
      unitPrice: _parseDouble(data['unitPrice']),
      gstApplicable: (data['gstApplicable'] as bool?) ?? false,
      gstRate: _parseDouble(data['gstRate']),
      dispatchedAt: _parseNullableTimestamp(data['dispatchedAt']),
      dispatchedBy: data['dispatchedBy'] as String?,
      dmNumber: _parseNullableInt(data['dmNumber']),
      dmFinancialYearId: data['dmFinancialYearId'] as String?,
      dmGeneratedAt: _parseNullableTimestamp(data['dmGeneratedAt']),
      dmOrderId: data['dmOrderId'] as String?,
      tripStage:
          (data['tripStage'] as String?) ?? ScheduledOrderTripStage.pending,
      initialMeterReading:
          _parseNullableDouble(data['initialMeterReading']),
      initialMeterRecordedAt:
          _parseNullableTimestamp(data['initialMeterRecordedAt']),
      initialMeterRecordedBy: data['initialMeterRecordedBy'] as String?,
      finalMeterReading: _parseNullableDouble(data['finalMeterReading']),
      finalMeterRecordedAt:
          _parseNullableTimestamp(data['finalMeterRecordedAt']),
      finalMeterRecordedBy: data['finalMeterRecordedBy'] as String?,
      deliveryProofUrl: data['deliveryProofUrl'] as String?,
      deliveryProofRecordedAt:
          _parseNullableTimestamp(data['deliveryProofRecordedAt']),
      deliveryProofRecordedBy: data['deliveryProofRecordedBy'] as String?,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'schOrderId': schOrderId,
      'organizationId': organizationId,
      'orderId': orderId,
      'clientId': clientId,
      'vehicleId': vehicleId,
      if (orderRef != null) 'orderRef': orderRef,
      if (vehicleRef != null) 'vehicleRef': vehicleRef,
      'scheduledDate': Timestamp.fromDate(_truncateToDate(scheduledDate)),
      'slotIndex': slotIndex,
      'slotLabel': slotLabel,
      'capacityPerSlot': capacityPerSlot,
      'quantity': quantity,
      'status': status,
      'scheduledAt': Timestamp.fromDate(scheduledAt),
      'scheduledBy': scheduledBy,
      if (rescheduledAt != null)
        'rescheduledAt': Timestamp.fromDate(rescheduledAt!),
      if (rescheduledBy != null) 'rescheduledBy': rescheduledBy,
      'rescheduleCount': rescheduleCount,
      if (previousScheduleId != null)
        'previousScheduleId': previousScheduleId,
      if (notes != null) 'notes': notes,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'productNames': productNames,
      'paymentType': paymentType,
      'totalAmount': totalAmount,
      'gstAmount': gstAmount,
      'orderRegion': orderRegion,
      'orderCity': orderCity,
      if (clientName != null) 'clientName': clientName,
      if (clientPhone != null) 'clientPhone': clientPhone,
      if (driverName != null) 'driverName': driverName,
      if (driverPhone != null) 'driverPhone': driverPhone,
      'unitPrice': unitPrice,
      'gstApplicable': gstApplicable,
      'gstRate': gstRate,
      if (dispatchedAt != null)
        'dispatchedAt': Timestamp.fromDate(dispatchedAt!),
      if (dispatchedBy != null) 'dispatchedBy': dispatchedBy,
      if (dmNumber != null) 'dmNumber': dmNumber,
      if (dmFinancialYearId != null) 'dmFinancialYearId': dmFinancialYearId,
      if (dmGeneratedAt != null)
        'dmGeneratedAt': Timestamp.fromDate(dmGeneratedAt!),
      if (dmOrderId != null) 'dmOrderId': dmOrderId,
      'tripStage': tripStage,
      if (initialMeterReading != null)
        'initialMeterReading': initialMeterReading,
      if (initialMeterRecordedAt != null)
        'initialMeterRecordedAt':
            Timestamp.fromDate(initialMeterRecordedAt!),
      if (initialMeterRecordedBy != null)
        'initialMeterRecordedBy': initialMeterRecordedBy,
      if (finalMeterReading != null)
        'finalMeterReading': finalMeterReading,
      if (finalMeterRecordedAt != null)
        'finalMeterRecordedAt': Timestamp.fromDate(finalMeterRecordedAt!),
      if (finalMeterRecordedBy != null)
        'finalMeterRecordedBy': finalMeterRecordedBy,
      if (deliveryProofUrl != null) 'deliveryProofUrl': deliveryProofUrl,
      if (deliveryProofRecordedAt != null)
        'deliveryProofRecordedAt':
            Timestamp.fromDate(deliveryProofRecordedAt!),
      if (deliveryProofRecordedBy != null)
        'deliveryProofRecordedBy': deliveryProofRecordedBy,
    };
  }

  ScheduledOrder copyWith({
    String? status,
    DateTime? scheduledDate,
    int? slotIndex,
    String? slotLabel,
    int? capacityPerSlot,
    int? quantity,
    DateTime? scheduledAt,
    String? scheduledBy,
    DateTime? rescheduledAt,
    String? rescheduledBy,
    int? rescheduleCount,
    String? previousScheduleId,
    String? notes,
    DateTime? updatedAt,
    List<String>? productNames,
    String? paymentType,
    double? totalAmount,
    double? gstAmount,
    String? orderRegion,
    String? orderCity,
    String? clientName,
    String? clientPhone,
    String? driverName,
    String? driverPhone,
    double? unitPrice,
    bool? gstApplicable,
    double? gstRate,
    DateTime? dispatchedAt,
    String? dispatchedBy,
    int? dmNumber,
    String? dmFinancialYearId,
    DateTime? dmGeneratedAt,
    String? dmOrderId,
    String? tripStage,
    double? initialMeterReading,
    DateTime? initialMeterRecordedAt,
    String? initialMeterRecordedBy,
    double? finalMeterReading,
    DateTime? finalMeterRecordedAt,
    String? finalMeterRecordedBy,
    String? deliveryProofUrl,
    DateTime? deliveryProofRecordedAt,
    String? deliveryProofRecordedBy,
  }) {
    return ScheduledOrder(
      id: id,
      schOrderId: schOrderId,
      organizationId: organizationId,
      orderId: orderId,
      clientId: clientId,
      vehicleId: vehicleId,
      orderRef: orderRef,
      vehicleRef: vehicleRef,
      scheduledDate: scheduledDate ?? this.scheduledDate,
      slotIndex: slotIndex ?? this.slotIndex,
      slotLabel: slotLabel ?? this.slotLabel,
      capacityPerSlot: capacityPerSlot ?? this.capacityPerSlot,
      quantity: quantity ?? this.quantity,
      status: status ?? this.status,
      scheduledAt: scheduledAt ?? this.scheduledAt,
      scheduledBy: scheduledBy ?? this.scheduledBy,
      rescheduledAt: rescheduledAt ?? this.rescheduledAt,
      rescheduledBy: rescheduledBy ?? this.rescheduledBy,
      rescheduleCount: rescheduleCount ?? this.rescheduleCount,
      previousScheduleId: previousScheduleId ?? this.previousScheduleId,
      notes: notes ?? this.notes,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      productNames: productNames ?? this.productNames,
      paymentType: paymentType ?? this.paymentType,
      totalAmount: totalAmount ?? this.totalAmount,
      gstAmount: gstAmount ?? this.gstAmount,
      orderRegion: orderRegion ?? this.orderRegion,
      orderCity: orderCity ?? this.orderCity,
      clientName: clientName ?? this.clientName,
      clientPhone: clientPhone ?? this.clientPhone,
      driverName: driverName ?? this.driverName,
      driverPhone: driverPhone ?? this.driverPhone,
      unitPrice: unitPrice ?? this.unitPrice,
      gstApplicable: gstApplicable ?? this.gstApplicable,
      gstRate: gstRate ?? this.gstRate,
      dispatchedAt: dispatchedAt ?? this.dispatchedAt,
      dispatchedBy: dispatchedBy ?? this.dispatchedBy,
      dmNumber: dmNumber ?? this.dmNumber,
      dmFinancialYearId: dmFinancialYearId ?? this.dmFinancialYearId,
      dmGeneratedAt: dmGeneratedAt ?? this.dmGeneratedAt,
      dmOrderId: dmOrderId ?? this.dmOrderId,
      tripStage: tripStage ?? this.tripStage,
      initialMeterReading: initialMeterReading ?? this.initialMeterReading,
      initialMeterRecordedAt:
          initialMeterRecordedAt ?? this.initialMeterRecordedAt,
      initialMeterRecordedBy:
          initialMeterRecordedBy ?? this.initialMeterRecordedBy,
      finalMeterReading: finalMeterReading ?? this.finalMeterReading,
      finalMeterRecordedAt:
          finalMeterRecordedAt ?? this.finalMeterRecordedAt,
      finalMeterRecordedBy:
          finalMeterRecordedBy ?? this.finalMeterRecordedBy,
      deliveryProofUrl: deliveryProofUrl ?? this.deliveryProofUrl,
      deliveryProofRecordedAt:
          deliveryProofRecordedAt ?? this.deliveryProofRecordedAt,
      deliveryProofRecordedBy:
          deliveryProofRecordedBy ?? this.deliveryProofRecordedBy,
    );
  }

  static DateTime _truncateToDate(DateTime value) {
    return DateTime(value.year, value.month, value.day);
  }

  static DateTime _parseTimestamp(dynamic value) {
    if (value is Timestamp) {
      return value.toDate();
    }
    if (value is DateTime) {
      return value;
    }
    if (value is String) {
      return DateTime.tryParse(value) ?? DateTime.now();
    }
    return DateTime.now();
  }

  static DateTime? _parseNullableTimestamp(dynamic value) {
    if (value == null) {
      return null;
    }
    if (value is Timestamp) {
      return value.toDate();
    }
    if (value is DateTime) {
      return value;
    }
    if (value is String) {
      return DateTime.tryParse(value);
    }
    return null;
  }

  static int _parseInt(dynamic value, {int fallback = 0}) {
    if (value is num) {
      return value.toInt();
    }
    return int.tryParse('$value') ?? fallback;
  }

  static double _parseDouble(dynamic value, {double fallback = 0}) {
    if (value is num) {
      return value.toDouble();
    }
    return double.tryParse('$value') ?? fallback;
  }

  static double? _parseNullableDouble(dynamic value) {
    if (value == null) {
      return null;
    }
    if (value is num) {
      return value.toDouble();
    }
    return double.tryParse('$value');
  }

  static int? _parseNullableInt(dynamic value) {
    if (value == null) {
      return null;
    }
    if (value is num) {
      return value.toInt();
    }
    return int.tryParse('$value');
  }

  static List<String> _parseStringList(dynamic value) {
    if (value is Iterable) {
      return value
          .map((item) => item?.toString())
          .whereType<String>()
          .toList();
    }
    return const [];
  }
}

class ScheduledOrderStatus {
  static const String scheduled = 'scheduled';
  static const String dispatched = 'dispatched';
  static const String delivered = 'delivered';
  static const String returned = 'returned';
  static const String rescheduled = 'rescheduled';
  static const String completed = 'completed';
  static const String cancelled = 'cancelled';

  static const List<String> values = [
    scheduled,
    dispatched,
    delivered,
    returned,
    rescheduled,
    completed,
    cancelled,
  ];
}

class ScheduledOrderTripStage {
  static const String pending = 'pending';
  static const String dispatched = 'dispatched';
  static const String delivered = 'delivered';
  static const String returned = 'returned';

  static const List<String> values = [
    pending,
    dispatched,
    delivered,
    returned,
  ];
}


