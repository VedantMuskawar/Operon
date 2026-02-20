import 'package:core_datasources/core_datasources.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:operon_auth_flow/operon_auth_flow.dart';
import 'package:operon_driver_android/data/repositories/users_repository.dart';
import 'package:operon_driver_android/presentation/screens/home/driver_home_screen.dart';
import 'package:operon_driver_android/presentation/widgets/driver_mission_card.dart';

class DriverScheduleTripsPage extends StatefulWidget {
  const DriverScheduleTripsPage({super.key});

  @override
  State<DriverScheduleTripsPage> createState() => _DriverScheduleTripsPageState();
}

class _DriverScheduleTripsPageState extends State<DriverScheduleTripsPage> {
  late DateTime _selectedDate;
  final Set<String> _selectedVehicleIds = <String>{};

  Future<_ScheduleAccess>? _accessFuture;
  String? _accessOrgId;
  String? _accessUserId;
  String? _accessPhone;

  Stream<List<Map<String, dynamic>>>? _tripsStream;
  String? _streamOrgId;
  DateTime? _streamDate;

  Future<_ScheduleAccess> _resolveScheduleAccess({
    required String organizationId,
    required String userId,
    required String phoneNumber,
  }) async {
    try {
      final usersRepository = context.read<UsersRepository>();
      final orgUser = await usersRepository.fetchCurrentUser(
        orgId: organizationId,
        userId: userId,
        phoneNumber: phoneNumber,
      );

      final vehicles = await VehiclesDataSource().fetchVehicles(organizationId);
      final normalizedUserPhone = _normalizePhone(phoneNumber);
      final linkedVehicleIds = <String>{};
      final employeeId = orgUser?.employeeId;
      final orgUserId = orgUser?.id;

      final isLinkedToVehicle = vehicles.any((vehicle) {
        final driver = vehicle.driver;
        if (driver == null) return false;

        final byPhone =
            _normalizePhone(driver.phone ?? '') == normalizedUserPhone;
        final employeeId = orgUser?.employeeId;
        final byEmployeeId =
            employeeId != null && employeeId.isNotEmpty && driver.id == employeeId;
        final byOrgUserId = orgUser != null && driver.id == orgUser.id;

        final isMatch = byPhone || byEmployeeId || byOrgUserId;
        if (isMatch) {
          linkedVehicleIds.add(vehicle.id);
        }

        return isMatch;
      });

      return _ScheduleAccess(
        isDriverLinkedToVehicle: isLinkedToVehicle,
        normalizedUserPhone: normalizedUserPhone,
        employeeId: employeeId,
        orgUserId: orgUserId,
        linkedVehicleIds: linkedVehicleIds,
      );
    } catch (_) {
      // Safe fallback: show read-only org schedule if linkage check fails.
      return const _ScheduleAccess(isDriverLinkedToVehicle: false);
    }
  }

  String _normalizePhone(String value) {
    return value.replaceAll(RegExp(r'[^0-9+]'), '');
  }

  DateTime _normalizeDate(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  void _ensureAccessFuture({
    required String organizationId,
    required String userId,
    required String phoneNumber,
  }) {
    final changed = _accessFuture == null ||
        _accessOrgId != organizationId ||
        _accessUserId != userId ||
        _accessPhone != phoneNumber;

    if (!changed) return;

    _accessOrgId = organizationId;
    _accessUserId = userId;
    _accessPhone = phoneNumber;
    _accessFuture = _resolveScheduleAccess(
      organizationId: organizationId,
      userId: userId,
      phoneNumber: phoneNumber,
    );
  }

  void _ensureTripsStream({
    required ScheduledTripsRepository repository,
    required String organizationId,
    required DateTime selectedDate,
  }) {
    final dateOnly = _normalizeDate(selectedDate);
    final changed = _tripsStream == null ||
        _streamOrgId != organizationId ||
        _streamDate == null ||
        !_isSameDay(_streamDate!, dateOnly);

    if (!changed) return;

    _streamOrgId = organizationId;
    _streamDate = dateOnly;

    _tripsStream = repository.watchScheduledTripsForDate(
      organizationId: organizationId,
      scheduledDate: dateOnly,
    );
  }

  bool _matchesDriverAssignment(
    Map<String, dynamic> trip,
    _ScheduleAccess access,
  ) {
    final tripVehicleId = trip['vehicleId'] as String?;
    if (tripVehicleId != null && access.linkedVehicleIds.contains(tripVehicleId)) {
      return true;
    }

    final tripDriverId = trip['driverId'] as String?;
    if (tripDriverId != null &&
        tripDriverId.isNotEmpty &&
        (tripDriverId == access.employeeId || tripDriverId == access.orgUserId)) {
      return true;
    }

    final tripDriverPhone = trip['driverPhone'] as String?;
    if (tripDriverPhone != null &&
        tripDriverPhone.isNotEmpty &&
        access.normalizedUserPhone != null &&
        _normalizePhone(tripDriverPhone) == access.normalizedUserPhone) {
      return true;
    }

    return false;
  }

  List<Map<String, dynamic>> _filterAssignedTrips(
    List<Map<String, dynamic>> trips,
    _ScheduleAccess access,
  ) {
    if (!access.isDriverLinkedToVehicle) {
      return trips;
    }

    return trips.where((trip) => _matchesDriverAssignment(trip, access)).toList();
  }

  bool _isSameDay(DateTime first, DateTime second) {
    return first.year == second.year &&
        first.month == second.month &&
        first.day == second.day;
  }

  void _onVehicleFilterChanged(String? vehicleId) {
    setState(() {
      if (vehicleId == null) {
        _selectedVehicleIds.clear();
      } else if (_selectedVehicleIds.contains(vehicleId)) {
        _selectedVehicleIds.remove(vehicleId);
      } else {
        _selectedVehicleIds.add(vehicleId);
      }
    });
  }

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

    _ensureAccessFuture(
      organizationId: organization.id,
      userId: user.id,
      phoneNumber: user.phoneNumber,
    );

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
          child: FutureBuilder<_ScheduleAccess>(
            future: _accessFuture,
            builder: (context, accessSnapshot) {
              if (accessSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final access = accessSnapshot.data ??
                  const _ScheduleAccess(isDriverLinkedToVehicle: false);
              final isReadOnly = !access.isDriverLinkedToVehicle;

              _ensureTripsStream(
                repository: scheduledTripsRepo,
                organizationId: organization.id,
                selectedDate: _selectedDate,
              );

              return StreamBuilder<List<Map<String, dynamic>>>(
                stream: _tripsStream,
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

                  final allTrips = snapshot.data ?? const [];
                  final trips = _filterAssignedTrips(allTrips, access);

                  final vehicleOptions = <String, String>{};
                  for (final trip in trips) {
                    final vehicleId = (trip['vehicleId'] as String?) ?? '';
                    if (vehicleId.isEmpty) continue;
                    final vehicleNumber =
                        (trip['vehicleNumber'] as String?) ?? 'Unknown';
                    vehicleOptions[vehicleId] = vehicleNumber;
                  }
                  final vehicleEntries = vehicleOptions.entries.toList()
                    ..sort((a, b) =>
                        a.value.toLowerCase().compareTo(b.value.toLowerCase()));

                  final filteredTrips = _selectedVehicleIds.isEmpty
                      ? trips
                      : trips.where((trip) {
                          final vehicleId = trip['vehicleId'] as String?;
                          return vehicleId != null &&
                              _selectedVehicleIds.contains(vehicleId);
                        }).toList();

                  return Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: SizedBox(
                          height: 40,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            itemCount: vehicleEntries.length + 1,
                            itemBuilder: (context, index) {
                              if (index == 0) {
                                return Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: _VehicleFilterButton(
                                    label: 'All',
                                    isSelected: _selectedVehicleIds.isEmpty,
                                    onTap: () => _onVehicleFilterChanged(null),
                                  ),
                                );
                              }
                              final entry = vehicleEntries[index - 1];
                              return Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: _VehicleFilterButton(
                                  label: entry.value,
                                  isSelected: _selectedVehicleIds.contains(entry.key),
                                  onTap: () => _onVehicleFilterChanged(entry.key),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      Expanded(
                        child: filteredTrips.isEmpty
                            ? Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(24),
                                  child: Text(
                                    trips.isEmpty
                                        ? (isReadOnly
                                            ? 'No scheduled trips found for this organization on selected date.'
                                        : 'No trips assigned to you for the selected date.')
                                        : 'No trips match selected vehicle filters.',
                                    style: const TextStyle(
                                      color: AuthColors.textSub,
                                      fontSize: 14,
                                      fontFamily: 'SF Pro Display',
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              )
                            : ListView.separated(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 12),
                                itemCount: filteredTrips.length,
                                separatorBuilder: (context, index) =>
                                    const SizedBox(height: 12),
                                itemBuilder: (context, index) {
                                  final trip = filteredTrips[index];
                                  return DriverMissionCard(
                                    trip: trip,
                                    isReadOnly: isReadOnly,
                                    onTap: () {
                                      if (isReadOnly) return;
                                      Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder: (_) => DriverHomeScreen(
                                            initialTrip: trip,
                                          ),
                                        ),
                                      );
                                    },
                                  );
                                },
                              ),
                      ),
                    ],
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

class _ScheduleAccess {
  const _ScheduleAccess({
    required this.isDriverLinkedToVehicle,
    this.normalizedUserPhone,
    this.employeeId,
    this.orgUserId,
    this.linkedVehicleIds = const <String>{},
  });

  final bool isDriverLinkedToVehicle;
  final String? normalizedUserPhone;
  final String? employeeId;
  final String? orgUserId;
  final Set<String> linkedVehicleIds;
}

class _VehicleFilterButton extends StatelessWidget {
  const _VehicleFilterButton({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AuthColors.primary : AuthColors.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected
                ? AuthColors.primary
                : AuthColors.textMainWithOpacity(0.1),
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? AuthColors.textMain : AuthColors.textSub,
            fontSize: 12,
            fontFamily: 'SF Pro Display',
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
          ),
        ),
      ),
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

