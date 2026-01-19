import 'package:core_datasources/core_datasources.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:operon_auth_flow/operon_auth_flow.dart';

class DriverTripDetailPage extends StatefulWidget {
  const DriverTripDetailPage({
    super.key,
    required this.trip,
  });

  final Map<String, dynamic> trip;

  @override
  State<DriverTripDetailPage> createState() => _DriverTripDetailPageState();
}

class _DriverTripDetailPageState extends State<DriverTripDetailPage> {
  late Map<String, dynamic> _trip;
  bool _isUpdating = false;

  @override
  void initState() {
    super.initState();
    _trip = Map<String, dynamic>.from(widget.trip);
  }

  String get _status {
    return ((_trip['orderStatus'] ?? _trip['tripStatus'] ?? 'scheduled') as String).toLowerCase();
  }

  String? get _tripId => _trip['id'] as String?;

  double? get _initialReading => (_trip['initialReading'] as num?)?.toDouble();

  Future<void> _startTrip() async {
    final tripId = _tripId;
    if (tripId == null) return;

    final reading = await _askForReading(
      title: 'Start trip',
      label: 'Initial odometer reading',
    );
    if (reading == null) return;
    if (!mounted) return;

    final authState = context.read<AuthBloc>().state;
    final user = authState.userProfile;
    if (user == null) return;

    setState(() => _isUpdating = true);
    try {
      await context.read<ScheduledTripsRepository>().updateTripStatus(
            tripId: tripId,
            tripStatus: 'dispatched',
            initialReading: reading,
            // keep optional audit fields
            deliveredByRole: 'driver',
          );

      setState(() {
        _trip['tripStatus'] = 'dispatched';
        _trip['orderStatus'] = 'dispatched';
        _trip['initialReading'] = reading;
      });
    } finally {
      if (mounted) setState(() => _isUpdating = false);
    }
  }

  Future<void> _markDelivered() async {
    final tripId = _tripId;
    if (tripId == null) return;

    final authState = context.read<AuthBloc>().state;
    final user = authState.userProfile;
    if (user == null) return;

    setState(() => _isUpdating = true);
    try {
      await context.read<ScheduledTripsRepository>().updateTripStatus(
            tripId: tripId,
            tripStatus: 'delivered',
            deliveredBy: user.id,
            deliveredByRole: 'driver',
          );

      setState(() {
        _trip['tripStatus'] = 'delivered';
        _trip['orderStatus'] = 'delivered';
      });
    } finally {
      if (mounted) setState(() => _isUpdating = false);
    }
  }

  Future<void> _markReturned() async {
    final tripId = _tripId;
    if (tripId == null) return;

    final reading = await _askForReading(
      title: 'Return trip',
      label: 'Final odometer reading',
    );
    if (reading == null) return;
    if (!mounted) return;

    final authState = context.read<AuthBloc>().state;
    final user = authState.userProfile;
    if (user == null) return;

    final initial = _initialReading;
    final distance = (initial != null && reading >= initial) ? (reading - initial) : null;

    setState(() => _isUpdating = true);
    try {
      await context.read<ScheduledTripsRepository>().updateTripStatus(
            tripId: tripId,
            tripStatus: 'returned',
            finalReading: reading,
            distanceTravelled: distance,
            returnedBy: user.id,
            returnedByRole: 'driver',
          );

      setState(() {
        _trip['tripStatus'] = 'returned';
        _trip['orderStatus'] = 'returned';
        _trip['finalReading'] = reading;
        if (distance != null) _trip['distanceTravelled'] = distance;
      });
    } finally {
      if (mounted) setState(() => _isUpdating = false);
    }
  }

  Future<double?> _askForReading({
    required String title,
    required String label,
  }) async {
    final controller = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final result = await showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AuthColors.surface,
        title: Text(title, style: const TextStyle(color: AuthColors.textMain)),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: controller,
            keyboardType: TextInputType.number,
            style: const TextStyle(color: AuthColors.textMain),
            decoration: InputDecoration(
              labelText: label,
              labelStyle: const TextStyle(color: AuthColors.textSub),
              enabledBorder: OutlineInputBorder(
                borderSide: BorderSide(color: AuthColors.textMainWithOpacity(0.2)),
                borderRadius: BorderRadius.circular(10),
              ),
              focusedBorder: OutlineInputBorder(
                borderSide: const BorderSide(color: AuthColors.legacyAccent),
                borderRadius: BorderRadius.circular(10),
              ),
              filled: true,
              fillColor: AuthColors.surface,
            ),
            validator: (value) {
              final v = double.tryParse((value ?? '').trim());
              if (v == null || v < 0) return 'Enter a valid number';
              return null;
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (!(formKey.currentState?.validate() ?? false)) return;
              final v = double.parse(controller.text.trim());
              Navigator.of(context).pop(v);
            },
            child: const Text('Confirm'),
          ),
        ],
      ),
    );

    controller.dispose();
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final clientName = (_trip['clientName'] as String?) ?? 'Client';
    final vehicleNumber = _trip['vehicleNumber'] as String?;
    final slotName = _trip['slotName'] as String?;
    final customerNumber = _trip['customerNumber'] as String? ?? _trip['clientPhone'] as String?;

    return Scaffold(
      backgroundColor: AuthColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Trip',
          style: TextStyle(
            color: AuthColors.textMain,
            fontFamily: 'SF Pro Display',
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: Stack(
        children: [
          const Positioned.fill(child: RepaintBoundary(child: DotGridPattern())),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    clientName,
                    style: const TextStyle(
                      color: AuthColors.textMain,
                      fontSize: 20,
                      fontFamily: 'SF Pro Display',
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    [
                      if (vehicleNumber != null && vehicleNumber.isNotEmpty) 'Vehicle: $vehicleNumber',
                      if (slotName != null && slotName.isNotEmpty) 'Slot: $slotName',
                      if (customerNumber != null && customerNumber.isNotEmpty) 'Client: $customerNumber',
                      'Status: ${_status.toUpperCase()}',
                    ].join(' • '),
                    style: const TextStyle(
                      color: AuthColors.textSub,
                      fontSize: 12,
                      fontFamily: 'SF Pro Display',
                      fontWeight: FontWeight.w600,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _ActionSection(
                    status: _status,
                    isUpdating: _isUpdating,
                    onStart: _startTrip,
                    onDelivered: _markDelivered,
                    onReturned: _markReturned,
                  ),
                  const SizedBox(height: 16),
                  _DetailCard(trip: _trip),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionSection extends StatelessWidget {
  const _ActionSection({
    required this.status,
    required this.isUpdating,
    required this.onStart,
    required this.onDelivered,
    required this.onReturned,
  });

  final String status;
  final bool isUpdating;
  final Future<void> Function() onStart;
  final Future<void> Function() onDelivered;
  final Future<void> Function() onReturned;

  @override
  Widget build(BuildContext context) {
    final canStart = status == 'scheduled' || status == 'pending';
    final canDeliver = status == 'dispatched';
    final canReturn = status == 'delivered';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (canStart)
          DashButton(
            label: isUpdating ? 'Starting…' : 'Start / Dispatch',
            onPressed: isUpdating ? null : () => onStart(),
          ),
        if (canDeliver) ...[
          DashButton(
            label: isUpdating ? 'Updating…' : 'Mark Delivered',
            onPressed: isUpdating ? null : () => onDelivered(),
          ),
        ],
        if (canReturn) ...[
          DashButton(
            label: isUpdating ? 'Updating…' : 'Mark Returned',
            onPressed: isUpdating ? null : () => onReturned(),
          ),
        ],
      ],
    );
  }
}

class _DetailCard extends StatelessWidget {
  const _DetailCard({required this.trip});

  final Map<String, dynamic> trip;

  @override
  Widget build(BuildContext context) {
    final initialReading = (trip['initialReading'] as num?)?.toDouble();
    final finalReading = (trip['finalReading'] as num?)?.toDouble();
    final distance = (trip['distanceTravelled'] as num?)?.toDouble();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AuthColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AuthColors.textMainWithOpacity(0.08),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Details',
            style: TextStyle(
              color: AuthColors.textMain,
              fontSize: 14,
              fontFamily: 'SF Pro Display',
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          _kv('Trip ID', trip['id']?.toString()),
          _kv('Schedule Trip ID', trip['scheduleTripId']?.toString()),
          _kv('Vehicle', trip['vehicleNumber']?.toString()),
          _kv('Slot', trip['slotName']?.toString()),
          _kv('Initial reading', initialReading?.toString()),
          _kv('Final reading', finalReading?.toString()),
          _kv('Distance', distance?.toString()),
        ],
      ),
    );
  }

  Widget _kv(String k, String? v) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          SizedBox(
            width: 140,
            child: Text(
              k,
              style: const TextStyle(
                color: AuthColors.textSub,
                fontSize: 12,
                fontFamily: 'SF Pro Display',
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              (v == null || v.isEmpty) ? '-' : v,
              style: const TextStyle(
                color: AuthColors.textMain,
                fontSize: 12,
                fontFamily: 'SF Pro Display',
                fontWeight: FontWeight.w600,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

