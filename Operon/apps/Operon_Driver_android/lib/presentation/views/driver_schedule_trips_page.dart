import 'package:core_datasources/core_datasources.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:operon_auth_flow/operon_auth_flow.dart';
import 'package:operon_driver_android/presentation/screens/home/driver_home_screen.dart';
import 'package:operon_driver_android/presentation/widgets/driver_mission_card.dart';

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

    // Debug logging (remove in production if needed)
    debugPrint('[DriverScheduleTripsPage] Query params: orgId=${organization.id}, driverPhone=${user.phoneNumber}, date=$_selectedDate');

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
              organizationId: organization.id.toString(),
              driverPhone: user.phoneNumber.toString(),
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
                      'No trips scheduled for the selected date.',
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
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                itemCount: trips.length,
                separatorBuilder: (context, index) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final trip = trips[index];
                  return DriverMissionCard(
                    trip: trip,
                    onTap: () {
                      // Navigate to map screen - it will auto-select the first trip
                      // Since trips are sorted by slot, the tapped trip should be selected
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const DriverHomeScreen(),
                        ),
                      );
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
                  color: isSelected ? AuthColors.primary : AuthColors.surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isSelected ? AuthColors.primary : AuthColors.textMainWithOpacity(0.1),
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

