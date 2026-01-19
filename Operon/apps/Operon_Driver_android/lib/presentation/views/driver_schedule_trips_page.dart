import 'package:core_datasources/core_datasources.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:operon_auth_flow/operon_auth_flow.dart';
import 'package:operon_driver_android/presentation/views/driver_trip_detail_page.dart';

class DriverScheduleTripsPage extends StatefulWidget {
  const DriverScheduleTripsPage({super.key});

  @override
  State<DriverScheduleTripsPage> createState() => _DriverScheduleTripsPageState();
}

class _DriverScheduleTripsPageState extends State<DriverScheduleTripsPage> {
  late DateTime _selectedDate;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedDate = DateTime(now.year, now.month, now.day);
  }

  @override
  Widget build(BuildContext context) {
    final authState = context.watch<AuthBloc>().state;
    final orgState = context.watch<OrganizationContextCubit>().state;
    final organization = orgState.organization;
    final user = authState.userProfile;

    if (organization == null) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Select an organization to view trips.',
            style: TextStyle(
              color: AuthColors.textSub,
              fontSize: 14,
              fontFamily: 'SF Pro Display',
            ),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    if (user == null || user.phoneNumber.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'No driver phone number found for this account.',
            style: TextStyle(
              color: AuthColors.textSub,
              fontSize: 14,
              fontFamily: 'SF Pro Display',
            ),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    final scheduledTripsRepo = context.read<ScheduledTripsRepository>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: _DateSelector(
            selectedDate: _selectedDate,
            onSelect: (d) => setState(() => _selectedDate = d),
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: StreamBuilder<List<Map<String, dynamic>>>(
            stream: scheduledTripsRepo.watchDriverScheduledTripsForDate(
              organizationId: organization.id,
              driverPhone: user.phoneNumber,
              scheduledDate: _selectedDate,
            ),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    'Failed to load trips: ${snapshot.error}',
                    style: const TextStyle(
                      color: AuthColors.textSub,
                      fontSize: 14,
                      fontFamily: 'SF Pro Display',
                    ),
                  ),
                );
              }

              final trips = snapshot.data ?? const [];
              if (trips.isEmpty) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'No trips for the selected date.',
                      style: TextStyle(
                        color: AuthColors.textSub,
                        fontSize: 14,
                        fontFamily: 'SF Pro Display',
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                itemCount: trips.length,
                separatorBuilder: (context, index) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final trip = trips[index];
                  return _DriverTripTile(
                    trip: trip,
                    onTap: () async {
                      final result = await Navigator.of(context).push<bool>(
                        MaterialPageRoute(
                          builder: (_) => DriverTripDetailPage(trip: trip),
                        ),
                      );
                      // Stream updates automatically; result is only for future extensions.
                      if (result == true && context.mounted) {}
                    },
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _DateSelector extends StatelessWidget {
  const _DateSelector({
    required this.selectedDate,
    required this.onSelect,
  });

  final DateTime selectedDate;
  final ValueChanged<DateTime> onSelect;

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);
    final dates = [
      todayDate.subtract(const Duration(days: 1)),
      todayDate,
      todayDate.add(const Duration(days: 1)),
    ];

    return Row(
      children: dates.map((date) {
        final isSelected =
            date.year == selectedDate.year && date.month == selectedDate.month && date.day == selectedDate.day;
        final label = _labelFor(date, todayDate);

        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: InkWell(
              onTap: () => onSelect(date),
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected ? AuthColors.legacyAccent : AuthColors.surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isSelected ? AuthColors.legacyAccent : AuthColors.textMainWithOpacity(0.1),
                    width: 1,
                  ),
                ),
                child: Text(
                  label,
                  style: TextStyle(
                    color: isSelected ? AuthColors.textMain : AuthColors.textSub,
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                    fontFamily: 'SF Pro Display',
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  String _labelFor(DateTime date, DateTime todayDate) {
    if (_isSameDay(date, todayDate)) return 'Today';
    if (_isSameDay(date, todayDate.subtract(const Duration(days: 1)))) return 'Yesterday';
    if (_isSameDay(date, todayDate.add(const Duration(days: 1)))) return 'Tomorrow';
    return '${date.day}/${date.month}';
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

class _DriverTripTile extends StatelessWidget {
  const _DriverTripTile({
    required this.trip,
    required this.onTap,
  });

  final Map<String, dynamic> trip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final slot = trip['slot'] as int?;
    final slotName = trip['slotName'] as String?;
    final vehicleNumber = trip['vehicleNumber'] as String?;
    final clientName = (trip['clientName'] as String?) ?? 'Client';
    final customerNumber = trip['customerNumber'] as String? ?? trip['clientPhone'] as String?;
    final status = ((trip['orderStatus'] ?? trip['tripStatus'] ?? 'scheduled') as String).toLowerCase();

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
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
            Row(
              children: [
                Expanded(
                  child: Text(
                    clientName,
                    style: const TextStyle(
                      color: AuthColors.textMain,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      fontFamily: 'SF Pro Display',
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                _StatusPill(status: status),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              [
                if (vehicleNumber != null && vehicleNumber.isNotEmpty) 'Vehicle: $vehicleNumber',
                if (slotName != null && slotName.isNotEmpty)
                  'Slot: $slotName${slot != null ? ' (#$slot)' : ''}',
                if (customerNumber != null && customerNumber.isNotEmpty) 'Client: $customerNumber',
              ].join(' • '),
              style: const TextStyle(
                color: AuthColors.textSub,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                fontFamily: 'SF Pro Display',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      'scheduled' || 'pending' => AuthColors.warning,
      'dispatched' => AuthColors.info,
      'delivered' => AuthColors.success,
      'returned' => AuthColors.success,
      'cancelled' => AuthColors.error,
      _ => AuthColors.textSub,
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.18),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.35), width: 1),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.3,
          fontFamily: 'SF Pro Display',
        ),
      ),
    );
  }
}

