import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart' hide Order;
import 'package:cloud_functions/cloud_functions.dart';

import '../models/order.dart';
import '../models/scheduled_order.dart';
import '../models/trip_location.dart';
import '../../vehicle/models/vehicle.dart';
import '../../vehicle/repositories/android_vehicle_repository.dart';
import '../repositories/android_client_repository.dart';

class AndroidScheduledOrderRepository {
  AndroidScheduledOrderRepository({
    FirebaseFirestore? firestore,
    AndroidVehicleRepository? vehicleRepository,
    AndroidClientRepository? clientRepository,
    FirebaseFunctions? functions,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _vehicleRepository = vehicleRepository ?? AndroidVehicleRepository(),
        _clientRepository = clientRepository ?? AndroidClientRepository(),
        _functions = functions ?? FirebaseFunctions.instance;

  final FirebaseFirestore _firestore;
  final AndroidVehicleRepository _vehicleRepository;
  final AndroidClientRepository _clientRepository;
  final FirebaseFunctions _functions;

  CollectionReference<Map<String, dynamic>> get _scheduledCollection =>
      _firestore.collection('SCH_ORDERS');

  CollectionReference<Map<String, dynamic>> _tripLocationsCollection(
    String scheduleId,
  ) {
    return _scheduledCollection.doc(scheduleId).collection('TRIP_LOCATIONS');
  }

  Future<List<Vehicle>> fetchEligibleVehicles({
    required String organizationId,
    required int requiredQuantity,
  }) async {
    final vehicles = await _vehicleRepository.getVehicles(organizationId);

    final activeVehicles = vehicles
        .where(
          (vehicle) =>
              vehicle.isActive &&
              vehicle.vehicleQuantity > 0,
        )
        .toList();

    if (activeVehicles.isEmpty) {
      return const [];
    }

    final hasCapacityForDay = activeVehicles
        .where((vehicle) => vehicle.weeklyCapacity.values.any((slots) => slots > 0))
        .toList();

    final pool = hasCapacityForDay.isNotEmpty ? hasCapacityForDay : activeVehicles;

    if (requiredQuantity <= 0) {
      pool.sort((a, b) => a.vehicleNo.toLowerCase().compareTo(b.vehicleNo.toLowerCase()));
      return pool;
    }

    final sufficientCapacity = pool
        .where((vehicle) => vehicle.vehicleQuantity >= requiredQuantity)
        .toList();

    if (sufficientCapacity.isNotEmpty) {
      sufficientCapacity.sort(
        (a, b) => a.vehicleNo.toLowerCase().compareTo(b.vehicleNo.toLowerCase()),
      );
      return sufficientCapacity;
    }

    pool.sort((a, b) {
      final diffA = (requiredQuantity - a.vehicleQuantity).abs();
      final diffB = (requiredQuantity - b.vehicleQuantity).abs();
      if (diffA != diffB) {
        return diffA.compareTo(diffB);
      }
      return a.vehicleNo.toLowerCase().compareTo(b.vehicleNo.toLowerCase());
    });

    return pool;
  }

  Future<Vehicle?> fetchVehicleById({
    required String organizationId,
    required String vehicleId,
  }) {
    return _vehicleRepository.getVehicleById(
      organizationId,
      vehicleId,
    );
  }

  Future<List<int>> fetchAvailableSlots({
    required String organizationId,
    required Vehicle vehicle,
    required DateTime scheduledDate,
  }) async {
    final truncatedDate = DateTime(
      scheduledDate.year,
      scheduledDate.month,
      scheduledDate.day,
    );

    final weekdayKey = _weekdayKey(truncatedDate);
    final fallbackSlots = vehicle.weeklyCapacity.isEmpty
        ? 1
        : math.max(0, vehicle.totalWeeklyCapacity ~/ 7);
    final maxSlots = vehicle.weeklyCapacity[weekdayKey] ?? fallbackSlots;
    if (maxSlots <= 0) {
      return const [0];
    }

    final snapshot = await _scheduledCollection
        .where('organizationId', isEqualTo: organizationId)
        .where('vehicleId', isEqualTo: vehicle.id ?? vehicle.vehicleID)
        .where(
          'scheduledDate',
          isEqualTo: Timestamp.fromDate(truncatedDate),
        )
        .where('status', whereIn: const [
          ScheduledOrderStatus.scheduled,
          ScheduledOrderStatus.dispatched,
        ])
        .get();

    final occupied = snapshot.docs
        .map((doc) => (doc.data()['slotIndex'] as num?)?.toInt())
        .whereType<int>()
        .toSet();

    return List<int>.generate(maxSlots, (index) => index)
        .where((index) => !occupied.contains(index))
        .toList();
  }

  Future<void> createSchedule({
    required Order order,
    required Vehicle vehicle,
    required DateTime scheduledDate,
    required int slotIndex,
    required String userId,
    String? notes,
  }) async {
    final truncatedDate = DateTime(
      scheduledDate.year,
      scheduledDate.month,
      scheduledDate.day,
    );

    final schOrderId = _buildScheduleId(
      orderId: order.orderId,
      vehicleId: vehicle.id ?? vehicle.vehicleID,
      date: truncatedDate,
      slotIndex: slotIndex,
    );

    final scheduleRef = _scheduledCollection.doc(schOrderId);
    final orderRef = _firestore
        .collection('ORDERS')
        .doc(order.id);

    final clientInfo = await _fetchClientInfo(
      organizationId: order.organizationId,
      clientId: order.clientId,
    );
    final driverInfo = await _resolveDriverInfo(
      organizationId: order.organizationId,
      vehicle: vehicle,
    );
    final unitPrice = _calculateUnitPrice(order);

    await _firestore.runTransaction((transaction) async {
      final scheduleSnap = await transaction.get(scheduleRef);
      if (scheduleSnap.exists) {
        final existing = ScheduledOrder.fromFirestore(scheduleSnap);
        if (existing.status == ScheduledOrderStatus.scheduled ||
            existing.status == ScheduledOrderStatus.dispatched) {
          throw ScheduleConflictException();
        }
      }

      final orderSnap = await transaction.get(orderRef);
      if (!orderSnap.exists) {
        throw OrderNotFoundException();
      }

      final currentOrder = Order.fromFirestore(orderSnap);

      if (currentOrder.remainingTrips <= 0) {
        throw RemainingTripsExhaustedException();
      }

      final tripAmounts = _computePerTripAmounts(currentOrder);

      final schedule = ScheduledOrder(
        id: scheduleRef.id,
        schOrderId: schOrderId,
        organizationId: order.organizationId,
        orderId: order.orderId,
        clientId: order.clientId,
        vehicleId: vehicle.id ?? vehicle.vehicleID,
        orderRef: orderRef,
        vehicleRef: _firestore
            .collection('ORGANIZATIONS')
            .doc(order.organizationId)
            .collection('VEHICLES')
            .doc(vehicle.id),
        scheduledDate: truncatedDate,
        slotIndex: slotIndex,
        slotLabel: _slotLabel(slotIndex),
        capacityPerSlot: vehicle.vehicleQuantity,
        quantity: order.totalQuantity,
        status: ScheduledOrderStatus.scheduled,
        scheduledAt: DateTime.now(),
        scheduledBy: userId,
        rescheduleCount: 0,
        previousScheduleId: null,
        notes: notes,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        productNames: order.items.map((item) => item.productName).toList(),
        paymentType: order.paymentType,
        totalAmount: tripAmounts.totalAmount,
        gstAmount: tripAmounts.gstAmount,
        orderRegion: order.region,
        orderCity: order.city,
        clientName: clientInfo.name,
        clientPhone: clientInfo.phone,
        driverName: driverInfo.name,
        driverPhone: driverInfo.phone,
        unitPrice: unitPrice,
        gstApplicable: order.gstApplicable,
        gstRate: order.gstRate,
        tripStage: ScheduledOrderTripStage.pending,
      );

      final updatedOrder = currentOrder.copyWith(
        remainingTrips: math.max(currentOrder.remainingTrips - 1, 0),
        lastScheduledAt: truncatedDate,
        lastScheduledBy: userId,
        lastScheduledVehicleId: vehicle.id ?? vehicle.vehicleID,
      );

      transaction.set(scheduleRef, schedule.toFirestore());
      transaction.update(orderRef, {
        'remainingTrips': updatedOrder.remainingTrips,
        'lastScheduledAt': Timestamp.fromDate(truncatedDate),
        'lastScheduledBy': userId,
        'lastScheduledVehicleId': vehicle.id ?? vehicle.vehicleID,
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });
    });
  }

  Future<void> reschedule({
    required ScheduledOrder existingSchedule,
    required Order order,
    required Vehicle vehicle,
    required DateTime scheduledDate,
    required int slotIndex,
    required String userId,
    String? notes,
  }) async {
    if (existingSchedule.dmNumber != null) {
      throw RescheduleNotAllowedDueToDmException();
    }
    final truncatedDate = DateTime(
      scheduledDate.year,
      scheduledDate.month,
      scheduledDate.day,
    );

    final newSchOrderId = _buildScheduleId(
      orderId: order.orderId,
      vehicleId: vehicle.id ?? vehicle.vehicleID,
      date: truncatedDate,
      slotIndex: slotIndex,
    );

    final newScheduleRef = _scheduledCollection.doc(newSchOrderId);
    final existingRef = _scheduledCollection.doc(existingSchedule.id);
    final orderRef = _firestore.collection('ORDERS').doc(order.id);

    final clientInfo = await _fetchClientInfo(
      organizationId: order.organizationId,
      clientId: order.clientId,
    );
    final driverInfo = await _resolveDriverInfo(
      organizationId: order.organizationId,
      vehicle: vehicle,
    );
    final unitPrice = _calculateUnitPrice(order);

    await _firestore.runTransaction((transaction) async {
      final occupiedSnap = await transaction.get(newScheduleRef);
      if (occupiedSnap.exists) {
        final current = ScheduledOrder.fromFirestore(occupiedSnap);
        if (current.status == ScheduledOrderStatus.scheduled ||
            current.status == ScheduledOrderStatus.dispatched) {
          throw ScheduleConflictException();
        }
      }

      final existingSnap = await transaction.get(existingRef);
      if (!existingSnap.exists) {
        throw ScheduleNotFoundException();
      }

      final orderSnap = await transaction.get(orderRef);
      if (!orderSnap.exists) {
        throw OrderNotFoundException();
      }

      final tripAmounts = _computePerTripAmounts(order);

      final newSchedule = ScheduledOrder(
        id: newScheduleRef.id,
        schOrderId: newSchOrderId,
        organizationId: order.organizationId,
        orderId: order.orderId,
        clientId: order.clientId,
        vehicleId: vehicle.id ?? vehicle.vehicleID,
        orderRef: orderRef,
        vehicleRef: _firestore
            .collection('ORGANIZATIONS')
            .doc(order.organizationId)
            .collection('VEHICLES')
            .doc(vehicle.id),
        scheduledDate: truncatedDate,
        slotIndex: slotIndex,
        slotLabel: _slotLabel(slotIndex),
        capacityPerSlot: vehicle.vehicleQuantity,
        quantity: order.totalQuantity,
        status: ScheduledOrderStatus.scheduled,
        scheduledAt: DateTime.now(),
        scheduledBy: userId,
        rescheduleCount: existingSchedule.rescheduleCount + 1,
        previousScheduleId: existingSchedule.id,
        notes: notes,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        productNames: existingSchedule.productNames,
        paymentType: existingSchedule.paymentType,
        totalAmount: tripAmounts.totalAmount,
        gstAmount: tripAmounts.gstAmount,
        orderRegion: existingSchedule.orderRegion,
        orderCity: existingSchedule.orderCity,
        clientName: clientInfo.name ?? existingSchedule.clientName,
        clientPhone: clientInfo.phone ?? existingSchedule.clientPhone,
        driverName: driverInfo.name ?? existingSchedule.driverName,
        driverPhone: driverInfo.phone ?? existingSchedule.driverPhone,
        unitPrice:
            unitPrice > 0 ? unitPrice : existingSchedule.unitPrice,
        gstApplicable:
            existingSchedule.gstApplicable || order.gstApplicable,
        gstRate: existingSchedule.gstApplicable && existingSchedule.gstRate > 0
            ? existingSchedule.gstRate
            : order.gstRate,
        tripStage: ScheduledOrderTripStage.pending,
      );

      transaction.update(existingRef, {
        'status': ScheduledOrderStatus.rescheduled,
        'rescheduledAt': Timestamp.fromDate(DateTime.now()),
        'rescheduledBy': userId,
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });

      transaction.set(newScheduleRef, newSchedule.toFirestore());

      transaction.update(orderRef, {
        'lastScheduledAt': Timestamp.fromDate(truncatedDate),
        'lastScheduledBy': userId,
        'lastScheduledVehicleId': vehicle.id ?? vehicle.vehicleID,
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });
    });
  }

  Future<void> cancelSchedule({
    required ScheduledOrder schedule,
    required Order order,
    required String userId,
  }) async {
    final scheduleRef = _scheduledCollection.doc(schedule.id);
    final orderRef = _firestore.collection('ORDERS').doc(order.id);

    await _firestore.runTransaction((transaction) async {
      final scheduleSnap = await transaction.get(scheduleRef);
      if (!scheduleSnap.exists) {
        throw ScheduleNotFoundException();
      }

      final orderSnap = await transaction.get(orderRef);
      if (!orderSnap.exists) {
        throw OrderNotFoundException();
      }

      final currentOrder = Order.fromFirestore(orderSnap);

      transaction.update(scheduleRef, {
        'status': ScheduledOrderStatus.cancelled,
        'updatedAt': Timestamp.fromDate(DateTime.now()),
        'rescheduledBy': userId,
      });

      transaction.update(orderRef, {
        'remainingTrips':
            math.min(currentOrder.remainingTrips + 1, currentOrder.trips),
        'lastScheduledAt': FieldValue.delete(),
        'lastScheduledBy': FieldValue.delete(),
        'lastScheduledVehicleId': FieldValue.delete(),
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });
    });
  }

  String _weekdayKey(DateTime date) {
    switch (date.weekday) {
      case DateTime.monday:
        return 'Mon';
      case DateTime.tuesday:
        return 'Tue';
      case DateTime.wednesday:
        return 'Wed';
      case DateTime.thursday:
        return 'Thu';
      case DateTime.friday:
        return 'Fri';
      case DateTime.saturday:
        return 'Sat';
      case DateTime.sunday:
      default:
        return 'Sun';
    }
  }

  String _buildScheduleId({
    required String orderId,
    required String vehicleId,
    required DateTime date,
    required int slotIndex,
  }) {
    final dateKey =
        '${date.year.toString().padLeft(4, '0')}${date.month.toString().padLeft(2, '0')}${date.day.toString().padLeft(2, '0')}';
    return '${orderId}_${vehicleId}_${dateKey}_S${slotIndex}'.toUpperCase();
  }

  String _slotLabel(int slotIndex) => 'Trip ${slotIndex + 1}';

  Future<List<ScheduledOrder>> fetchSchedulesByDate({
    required String organizationId,
    required DateTime scheduledDate,
    String? vehicleId,
  }) async {
    final truncatedDate = DateTime(
      scheduledDate.year,
      scheduledDate.month,
      scheduledDate.day,
    );

    Query<Map<String, dynamic>> query = _scheduledCollection
        .where('organizationId', isEqualTo: organizationId)
        .where(
          'scheduledDate',
          isEqualTo: Timestamp.fromDate(truncatedDate),
        )
        .where('status', whereIn: const [
          ScheduledOrderStatus.scheduled,
          ScheduledOrderStatus.dispatched,
          ScheduledOrderStatus.delivered,
          ScheduledOrderStatus.returned,
        ]);

    if (vehicleId != null) {
      query = query.where('vehicleId', isEqualTo: vehicleId);
    }

    final snapshot = await query.get();

    final schedules = snapshot.docs
        .map((doc) => ScheduledOrder.fromFirestore(doc))
        .toList();

    schedules.sort(
      (a, b) => a.scheduledAt.compareTo(b.scheduledAt),
    );

    return schedules;
  }

  Future<ScheduledOrder?> fetchScheduleById(String scheduleId) async {
    final doc = await _scheduledCollection.doc(scheduleId).get();
    if (!doc.exists) {
      return null;
    }
    return ScheduledOrder.fromFirestore(doc);
  }

  Future<ScheduledOrder> generateDmNumber({
    required String organizationId,
    required String scheduleId,
    String? orderId,
  }) async {
    try {
      final callable = _functions.httpsCallable('generateDmNumber');
      final payload = {
        'organizationId': organizationId,
        'scheduleId': scheduleId,
        if (orderId != null) 'orderId': orderId,
      };
      await callable.call(payload);
    } on FirebaseFunctionsException catch (error) {
      throw Exception(
        'Failed to generate DM number: ${error.message ?? error.code}',
      );
    } catch (error) {
      throw Exception('Failed to generate DM number: $error');
    }

    final updatedSchedule = await fetchScheduleById(scheduleId);
    if (updatedSchedule == null) {
      throw Exception('Scheduled order not found after DM generation');
    }
    return updatedSchedule;
  }

  Future<ScheduledOrder> cancelDmNumber({
    required String organizationId,
    required String scheduleId,
  }) async {
    try {
      final callable = _functions.httpsCallable('cancelDmNumber');
      final payload = {
        'organizationId': organizationId,
        'scheduleId': scheduleId,
      };
      await callable.call(payload);
    } on FirebaseFunctionsException catch (error) {
      throw Exception(
        'Failed to cancel DM number: ${error.message ?? error.code}',
      );
    } catch (error) {
      throw Exception('Failed to cancel DM number: $error');
    }

    final updatedSchedule = await fetchScheduleById(scheduleId);
    if (updatedSchedule == null) {
      throw Exception('Scheduled order not found after DM cancellation');
    }
    return updatedSchedule;
  }

  Future<ScheduledOrder> markAsDispatched({
    required String organizationId,
    required ScheduledOrder schedule,
    required String userId,
    double? initialMeterReading,
    DateTime? initialMeterRecordedAt,
  }) async {
    if (schedule.status == ScheduledOrderStatus.dispatched &&
        schedule.dispatchedAt != null) {
      return schedule;
    }

    final scheduleRef = _scheduledCollection.doc(schedule.id);

    await _firestore.runTransaction((transaction) async {
      final scheduleSnap = await transaction.get(scheduleRef);
      if (!scheduleSnap.exists) {
        throw ScheduleNotFoundException();
      }

      final current = ScheduledOrder.fromFirestore(scheduleSnap);
      if (current.dmNumber == null) {
        throw Exception('Cannot dispatch without a generated DM.');
      }

      if (current.status == ScheduledOrderStatus.dispatched) {
        return;
      }

      final now = DateTime.now();
      final meterTimestamp = initialMeterReading != null
          ? (initialMeterRecordedAt ?? now)
          : null;

      final updateData = <String, dynamic>{
        'status': ScheduledOrderStatus.dispatched,
        'dispatchedAt': Timestamp.fromDate(now),
        'dispatchedBy': userId,
        'updatedAt': Timestamp.fromDate(now),
        'tripStage': ScheduledOrderTripStage.dispatched,
      };

      if (initialMeterReading != null) {
        updateData['initialMeterReading'] = initialMeterReading;
        updateData['initialMeterRecordedAt'] =
            Timestamp.fromDate(meterTimestamp!);
        updateData['initialMeterRecordedBy'] = userId;
      }

      transaction.update(scheduleRef, updateData);
    });

    final updatedSchedule = await fetchScheduleById(schedule.id);
    if (updatedSchedule == null) {
      throw Exception('Scheduled order not found after dispatch update');
    }
    return updatedSchedule;
  }

  Future<ScheduledOrder> revertDispatch({
    required ScheduledOrder schedule,
    required String userId,
  }) async {
    final scheduleRef = _scheduledCollection.doc(schedule.id);

    await _firestore.runTransaction((transaction) async {
      final scheduleSnap = await transaction.get(scheduleRef);
      if (!scheduleSnap.exists) {
        throw ScheduleNotFoundException();
      }

      final now = DateTime.now();

      transaction.update(scheduleRef, {
        'status': ScheduledOrderStatus.scheduled,
        'tripStage': ScheduledOrderTripStage.pending,
        'dispatchedAt': FieldValue.delete(),
        'dispatchedBy': FieldValue.delete(),
        'initialMeterReading': FieldValue.delete(),
        'initialMeterRecordedAt': FieldValue.delete(),
        'initialMeterRecordedBy': FieldValue.delete(),
        'finalMeterReading': FieldValue.delete(),
        'finalMeterRecordedAt': FieldValue.delete(),
        'finalMeterRecordedBy': FieldValue.delete(),
        'deliveryProofUrl': FieldValue.delete(),
        'deliveryProofRecordedAt': FieldValue.delete(),
        'deliveryProofRecordedBy': FieldValue.delete(),
        'updatedAt': Timestamp.fromDate(now),
      });
    });

    final updatedSchedule = await fetchScheduleById(schedule.id);
    if (updatedSchedule == null) {
      throw Exception('Scheduled order not found after dispatch revert');
    }
    return updatedSchedule;
  }

  Future<ScheduledOrder> markTripDelivered({
    required ScheduledOrder schedule,
    required String userId,
    required String deliveryPhotoUrl,
    DateTime? recordedAt,
  }) async {
    final scheduleRef = _scheduledCollection.doc(schedule.id);

    await _firestore.runTransaction((transaction) async {
      final scheduleSnap = await transaction.get(scheduleRef);
      if (!scheduleSnap.exists) {
        throw ScheduleNotFoundException();
      }

      final current = ScheduledOrder.fromFirestore(scheduleSnap);
      if (current.tripStage == ScheduledOrderTripStage.returned) {
        return;
      }

      final now = DateTime.now();
      final capturedAt = recordedAt ?? now;

      transaction.update(scheduleRef, {
        'tripStage': ScheduledOrderTripStage.delivered,
        'status': ScheduledOrderStatus.delivered,
        'deliveryProofUrl': deliveryPhotoUrl,
        'deliveryProofRecordedAt': Timestamp.fromDate(capturedAt),
        'deliveryProofRecordedBy': userId,
        'updatedAt': Timestamp.fromDate(now),
      });
    });

    final updatedSchedule = await fetchScheduleById(schedule.id);
    if (updatedSchedule == null) {
      throw Exception('Scheduled order not found after delivery update');
    }
    return updatedSchedule;
  }

  Future<ScheduledOrder> markTripReturned({
    required ScheduledOrder schedule,
    required String userId,
    required double finalMeterReading,
    DateTime? recordedAt,
  }) async {
    final scheduleRef = _scheduledCollection.doc(schedule.id);

    await _firestore.runTransaction((transaction) async {
      final scheduleSnap = await transaction.get(scheduleRef);
      if (!scheduleSnap.exists) {
        throw ScheduleNotFoundException();
      }

      final now = DateTime.now();
      final capturedAt = recordedAt ?? now;

      transaction.update(scheduleRef, {
        'tripStage': ScheduledOrderTripStage.returned,
        'status': ScheduledOrderStatus.returned,
        'finalMeterReading': finalMeterReading,
        'finalMeterRecordedAt': Timestamp.fromDate(capturedAt),
        'finalMeterRecordedBy': userId,
        'updatedAt': Timestamp.fromDate(now),
      });
    });

    final updatedSchedule = await fetchScheduleById(schedule.id);
    if (updatedSchedule == null) {
      throw Exception('Scheduled order not found after trip completion');
    }
    return updatedSchedule;
  }

  Stream<List<TripLocation>> watchTripLocations(
    String scheduleId, {
    int limit = 200,
  }) {
    return _tripLocationsCollection(scheduleId)
        .orderBy('recordedAt', descending: true)
        .limit(limit)
        .snapshots()
        .map(
      (snapshot) {
        return snapshot.docs
            .map((doc) => TripLocation.fromFirestore(doc))
            .toList();
      },
    );
  }

  Future<TripLocation?> fetchLatestTripLocation(String scheduleId) async {
    final snapshot = await _tripLocationsCollection(scheduleId)
        .orderBy('recordedAt', descending: true)
        .limit(1)
        .get();
    if (snapshot.docs.isEmpty) {
      return null;
    }
    return TripLocation.fromFirestore(snapshot.docs.first);
  }

  Future<void> deleteScheduleAndRevert({
    required ScheduledOrder schedule,
  }) async {
    final scheduleRef = _scheduledCollection.doc(schedule.id);
    final orderRef = schedule.orderRef ??
        _firestore.collection('ORDERS').doc(schedule.orderId);

    await _firestore.runTransaction((transaction) async {
      final scheduleSnap = await transaction.get(scheduleRef);
      if (!scheduleSnap.exists) {
        throw ScheduleNotFoundException();
      }

      final orderSnap = await transaction.get(orderRef);
      if (!orderSnap.exists) {
        throw OrderNotFoundException();
      }

      final currentOrder = Order.fromFirestore(orderSnap);

      transaction.delete(scheduleRef);
      transaction.update(orderRef, {
        'remainingTrips':
            math.min(currentOrder.remainingTrips + 1, currentOrder.trips),
        'lastScheduledAt': FieldValue.delete(),
        'lastScheduledBy': FieldValue.delete(),
        'lastScheduledVehicleId': FieldValue.delete(),
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });
    });
  }

  Future<_ClientInfo> _fetchClientInfo({
    required String organizationId,
    required String clientId,
  }) async {
    try {
      final client =
          await _clientRepository.getClient(organizationId, clientId);
      if (client == null) {
        return const _ClientInfo();
      }
      return _ClientInfo(
        name: client.name.isNotEmpty ? client.name : null,
        phone: client.phoneNumber.isNotEmpty ? client.phoneNumber : null,
      );
    } catch (_) {
      return const _ClientInfo();
    }
  }

  Future<_DriverInfo> _resolveDriverInfo({
    required String organizationId,
    required Vehicle vehicle,
  }) async {
    final initial = _extractDriverInfo(vehicle);
    if (initial.hasData) {
      return initial;
    }

    if (vehicle.id == null && vehicle.vehicleID.isEmpty) {
      return initial;
    }

    try {
      final latest = await _vehicleRepository.getVehicleById(
        organizationId,
        vehicle.id ?? vehicle.vehicleID,
      );
      if (latest == null) {
        return initial;
      }
      return _extractDriverInfo(latest);
    } catch (_) {
      return initial;
    }
  }

  _DriverInfo _extractDriverInfo(Vehicle vehicle) {
    final name = vehicle.assignedDriverName?.trim();
    final phone = vehicle.assignedDriverContact?.trim();
    return _DriverInfo(
      name: name?.isEmpty == true ? null : name,
      phone: phone?.isEmpty == true ? null : phone,
    );
  }

  double _calculateUnitPrice(Order order) {
    if (order.items.isNotEmpty) {
      return order.items.first.unitPrice;
    }
    final quantity = order.items.fold<int>(
      0,
      (sum, item) => sum + item.quantity,
    );
    if (quantity > 0) {
      return order.subtotal / quantity;
    }
    return 0;
  }

  _TripAmounts _computePerTripAmounts(Order order) {
    final trips = order.trips > 0 ? order.trips : 1;
    final perTripSubtotal = _roundCurrency(order.subtotal / trips);
    if (!order.gstApplicable || order.gstRate <= 0) {
      return _TripAmounts(
        subtotal: perTripSubtotal,
        gstAmount: 0,
        totalAmount: perTripSubtotal,
      );
    }

    final gstAmount = _roundCurrency(perTripSubtotal * (order.gstRate / 100));
    final total = _roundCurrency(perTripSubtotal + gstAmount);
    return _TripAmounts(
      subtotal: perTripSubtotal,
      gstAmount: gstAmount,
      totalAmount: total,
    );
  }

  double _roundCurrency(double value) =>
      double.parse(value.toStringAsFixed(2));
}

class _TripAmounts {
  const _TripAmounts({
    required this.subtotal,
    required this.gstAmount,
    required this.totalAmount,
  });

  final double subtotal;
  final double gstAmount;
  final double totalAmount;
}

class ScheduleConflictException implements Exception {}

class ScheduleNotFoundException implements Exception {}

class OrderNotFoundException implements Exception {}

class RemainingTripsExhaustedException implements Exception {}

class RescheduleNotAllowedDueToDmException implements Exception {}

class _ClientInfo {
  const _ClientInfo({this.name, this.phone});

  final String? name;
  final String? phone;
}

class _DriverInfo {
  const _DriverInfo({this.name, this.phone});

  final String? name;
  final String? phone;

  bool get hasData =>
      (name != null && name!.isNotEmpty) || (phone != null && phone!.isNotEmpty);
}

