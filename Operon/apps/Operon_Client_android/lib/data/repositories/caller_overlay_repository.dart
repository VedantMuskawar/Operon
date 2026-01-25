import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dash_mobile/data/datasources/pending_orders_data_source.dart';
import 'package:dash_mobile/data/datasources/scheduled_trips_data_source.dart';
import 'package:dash_mobile/data/datasources/transactions_data_source.dart';
import 'package:dash_mobile/data/services/client_service.dart';
import 'package:dash_mobile/data/utils/caller_overlay_utils.dart';
import 'package:dash_mobile/data/utils/financial_year_utils.dart';

/// DTO for overlay "Pending order" row.
class CallerOverlayPendingOrder {
  const CallerOverlayPendingOrder({
    required this.orderId,
    required this.amount,
    required this.status,
    this.createdAt,
    this.zone,
    this.unitPrice,
    this.tripTimesFixedQty,
  });
  final String orderId;
  final double amount;
  final String status;
  final DateTime? createdAt;
  final String? zone;
  final double? unitPrice;
  final String? tripTimesFixedQty;
}

/// DTO for overlay "Scheduled trip" row (excludes delivered/returned).
class CallerOverlayScheduledTrip {
  const CallerOverlayScheduledTrip({
    required this.tripId,
    required this.scheduledDate,
    this.vehicleNumber,
    this.slotName,
    this.tripStatus,
    this.zone,
  });
  final String tripId;
  final DateTime? scheduledDate;
  final String? vehicleNumber;
  final String? slotName;
  final String? tripStatus;
  final String? zone;
}

/// DTO for overlay "Last transaction" row.
class CallerOverlayLastTransaction {
  const CallerOverlayLastTransaction({
    required this.date,
    required this.amount,
    this.category,
  });
  final DateTime? date;
  final double amount;
  final String? category;
}

/// Orchestrates fetches for Caller ID overlay: client by phone, then
/// orders/trips/transactions/quote for that client.
class CallerOverlayRepository {
  CallerOverlayRepository({
    required ClientService clientService,
    required PendingOrdersDataSource pendingOrdersDataSource,
    required ScheduledTripsDataSource scheduledTripsDataSource,
    required TransactionsDataSource transactionsDataSource,
  })  : _clientService = clientService,
        _pendingOrders = pendingOrdersDataSource,
        _scheduledTrips = scheduledTripsDataSource,
        _transactions = transactionsDataSource;

  final ClientService _clientService;
  final PendingOrdersDataSource _pendingOrders;
  final ScheduledTripsDataSource _scheduledTrips;
  final TransactionsDataSource _transactions;

  Future<ClientRecord?> fetchClientByPhone(String phone) async {
    final normalized = normalizePhone(phone);
    if (normalized.isEmpty) return null;
    return _clientService.findClientByPhone(normalized);
  }

  /// First non-completed order for client in org. Excludes status == 'completed'.
  Future<CallerOverlayPendingOrder?> fetchPendingOrderForClient({
    required String organizationId,
    required String clientId,
  }) async {
    final orders = await _pendingOrders.fetchPendingOrders(organizationId);
    final match = orders.where((o) {
      final cid = o['clientId'] as String?;
      final status = o['status'] as String?;
      return cid == clientId && status != 'completed';
    }).toList();
    if (match.isEmpty) return null;
    final o = match.first;
    final orderId = o['orderId'] as String? ?? o['id'] as String? ?? '';
    final pricing = o['pricing'] as Map<String, dynamic>?;
    final amount = (pricing?['totalAmount'] as num?)?.toDouble() ?? 0.0;
    final status = (o['status'] as String?) ?? 'pending';

    DateTime? createdAt;
    final ca = o['createdAt'];
    if (ca is Timestamp) {
      createdAt = ca.toDate();
    } else if (ca is DateTime) {
      createdAt = ca;
    }

    String? zone;
    final dz = o['deliveryZone'] as Map<String, dynamic>?;
    if (dz != null) {
      final region = dz['region'] as String? ?? '';
      final city = dz['city_name'] as String? ?? dz['city'] as String? ?? '';
      final zoneStr = [region, city].where((s) => s.isNotEmpty).join(', ');
      zone = zoneStr.isEmpty ? null : zoneStr;
    }

    double? unitPrice;
    String? tripTimesFixedQty;
    final items = o['items'] as List<dynamic>? ?? [];
    final firstItem = items.isNotEmpty ? items.first as Map<String, dynamic>? : null;
    if (firstItem != null) {
      unitPrice = (firstItem['unitPrice'] as num?)?.toDouble();
      final trips = (firstItem['estimatedTrips'] as num?)?.toInt() ?? 0;
      final fixedQty = (firstItem['fixedQuantityPerTrip'] as num?)?.toInt() ?? 0;
      if (trips > 0 && fixedQty > 0) {
        tripTimesFixedQty = '$trips×$fixedQty';
      }
    }

    final dto = CallerOverlayPendingOrder(
      orderId: orderId,
      amount: amount,
      status: status,
      createdAt: createdAt,
      zone: zone,
      unitPrice: unitPrice,
      tripTimesFixedQty: tripTimesFixedQty,
    );
    return dto;
  }

  /// First scheduled trip for order with tripStatus NOT in [delivered, returned].
  Future<CallerOverlayScheduledTrip?> fetchActiveTripForOrder(String orderId) async {
    final trips = await _scheduledTrips.getScheduledTripsForOrder(orderId);
    const exclude = ['delivered', 'returned'];
    final active = trips.where((t) {
      final s = t['tripStatus'] as String?;
      return s != null && !exclude.contains(s);
    }).toList();
    if (active.isEmpty) return null;
    final t = active.first;
    final id = t['id'] as String? ?? '';
    DateTime? scheduledDate;
    final sd = t['scheduledDate'];
    if (sd is Timestamp) {
      scheduledDate = sd.toDate();
    } else if (sd is DateTime) {
      scheduledDate = sd;
    }

    String? zone;
    final dz = t['deliveryZone'] as Map<String, dynamic>?;
    if (dz != null) {
      final region = dz['region'] as String? ?? dz['zone'] as String? ?? '';
      final city = dz['city_name'] as String? ?? dz['city'] as String? ?? '';
      final zoneStr = [region, city].where((s) => s.isNotEmpty).join(', ');
      zone = zoneStr.isEmpty ? null : zoneStr;
    }

    return CallerOverlayScheduledTrip(
      tripId: id,
      scheduledDate: scheduledDate,
      vehicleNumber: t['vehicleNumber'] as String?,
      slotName: t['slotName'] as String?,
      tripStatus: t['tripStatus'] as String?,
      zone: zone,
    );
  }

  Future<CallerOverlayLastTransaction?> fetchLastTransactionForClient({
    required String organizationId,
    required String clientId,
  }) async {
    final fy = FinancialYearUtils.getCurrentFinancialYear();
    final list = await _transactions.getClientTransactions(
      organizationId: organizationId,
      clientId: clientId,
      financialYear: fy,
      limit: 1,
    );
    if (list.isEmpty) return null;
    final tx = list.first;
    return CallerOverlayLastTransaction(
      date: tx.createdAt,
      amount: tx.amount,
      category: tx.category.name,
    );
  }
}
