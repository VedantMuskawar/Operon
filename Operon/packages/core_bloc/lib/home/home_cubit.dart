import 'package:core_bloc/base/base_state.dart';
import 'package:core_bloc/home/home_state.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Abstract interface for fetching profile statistics
/// Implementations should be provided by each app
abstract class ProfileStatsRepository {
  Future<int> getPendingOrdersCount(String orgId);
}

/// Cubit for managing home page state and navigation
class HomeCubit extends Cubit<HomeState> {
  HomeCubit({
    required ProfileStatsRepository profileStatsRepository,
  })  : _profileStatsRepository = profileStatsRepository,
        super(const HomeState());

  final ProfileStatsRepository _profileStatsRepository;

  /// Update allowed sections based on AppAccessRole
  /// This should be called when the role changes
  void updateAppAccessRole(dynamic appAccessRole) {
    final allowedSections = _computeAllowedSections(appAccessRole);
    
    // If current index is no longer allowed, switch to first allowed section
    int newIndex = state.currentIndex;
    if (!allowedSections.contains(newIndex)) {
      newIndex = allowedSections.isNotEmpty ? allowedSections.first : 0;
    }

    emit(state.copyWith(
      allowedSections: allowedSections,
      currentIndex: newIndex,
    ));
  }

  /// Switch to a specific section index
  /// Validates that the index is allowed before switching
  void switchToSection(int index) {
    if (!state.isSectionAllowed(index)) {
      return;
    }
    emit(state.copyWith(currentIndex: index));
  }

  /// Load profile statistics for the given organization
  Future<void> loadProfileStats(String orgId) async {
    if (orgId.isEmpty) {
      emit(state.copyWith(profileStats: null));
      return;
    }

    emit(state.copyWith(status: ViewStatus.loading));

    try {
      final pendingOrdersCount = await _profileStatsRepository.getPendingOrdersCount(orgId);
      
      emit(state.copyWith(
        status: ViewStatus.success,
        profileStats: ProfileStats(pendingOrdersCount: pendingOrdersCount),
      ));
    } catch (e) {
      emit(state.copyWith(
        status: ViewStatus.failure,
        message: 'Failed to load profile stats: ${e.toString()}',
      ));
    }
  }

  /// Set profile statistics directly (used for pre-fetched data)
  void setProfileStats(ProfileStats profileStats) {
    emit(state.copyWith(
      status: ViewStatus.success,
      profileStats: profileStats,
    ));
  }

  /// Compute allowed sections based on AppAccessRole
  /// Returns list of section indices the user can access
  List<int> _computeAllowedSections(dynamic appAccessRole) {
    final visible = <int>[0]; // Overview is always visible

    if (appAccessRole == null) {
      visible.add(5); // Cash Ledger: page access for all
      return visible;
    }

    // Check section access using the role's canAccessSection method
    // Section indices: 0=Overview, 1=PendingOrders, 2=ScheduleOrders, 3=OrdersMap, 4=Analytics, 5=Attendance
    final canAccessPendingOrders = _canAccessSection(appAccessRole, 'pendingOrders');
    if (canAccessPendingOrders) {
      visible.add(1);
    }
    // Schedule Orders is accessible if user can access pending orders OR has explicit scheduleOrders permission
    // This makes sense because scheduling trips is a natural extension of managing pending orders
    if (canAccessPendingOrders || _canAccessSection(appAccessRole, 'scheduleOrders')) {
      visible.add(2);
    }
    if (_canAccessSection(appAccessRole, 'ordersMap')) {
      visible.add(3);
    }
    if (_canAccessSection(appAccessRole, 'analyticsDashboard')) {
      visible.add(4);
    }
    // Attendance (section 5 on Android) is accessible if user can access employees page
    if (_canAccessPage(appAccessRole, 'employees')) {
      visible.add(5);
    }
    // Cash Ledger (section 5 on web as 6th nav item): page access for all; Verify/Unverify remain admin-only in UI
    if (!visible.contains(5)) {
      visible.add(5);
    }

    return visible;
  }

  /// Helper to check section access
  /// Works with AppAccessRole from both Android and Web apps
  bool _canAccessSection(dynamic appAccessRole, String sectionName) {
    try {
      // Try to call canAccessSection method
      if (appAccessRole is! Map && appAccessRole != null) {
        // Use dynamic invocation for flexibility across apps
        final result = (appAccessRole as dynamic).canAccessSection(sectionName);
        if (result is bool) {
          return result;
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error checking section access: $e');
      }
    }
    return false;
  }

  /// Helper to check page access
  /// Works with AppAccessRole from both Android and Web apps
  bool _canAccessPage(dynamic appAccessRole, String pageName) {
    try {
      // Try to call canAccessPage method
      if (appAccessRole is! Map && appAccessRole != null) {
        // Use dynamic invocation for flexibility across apps
        final result = (appAccessRole as dynamic).canAccessPage(pageName);
        if (result is bool) {
          return result;
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error checking page access: $e');
      }
    }
    return false;
  }
}
