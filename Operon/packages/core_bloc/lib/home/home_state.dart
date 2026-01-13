import 'package:core_bloc/base/base_state.dart';

/// Profile statistics displayed in the profile view
class ProfileStats {
  const ProfileStats({
    required this.pendingOrdersCount,
  });

  final int pendingOrdersCount;

  ProfileStats copyWith({
    int? pendingOrdersCount,
  }) {
    return ProfileStats(
      pendingOrdersCount: pendingOrdersCount ?? this.pendingOrdersCount,
    );
  }
}

/// State for the Home page
class HomeState extends BaseState {
  const HomeState({
    super.status = ViewStatus.initial,
    super.message,
    this.currentIndex = 0,
    this.allowedSections = const [0],
    this.profileStats,
  });

  final int currentIndex;
  final List<int> allowedSections;
  final ProfileStats? profileStats;

  /// Check if a section index is allowed for the current user
  bool isSectionAllowed(int index) => allowedSections.contains(index);

  @override
  HomeState copyWith({
    ViewStatus? status,
    String? message,
    int? currentIndex,
    List<int>? allowedSections,
    ProfileStats? profileStats,
  }) {
    return HomeState(
      status: status ?? this.status,
      message: message ?? this.message,
      currentIndex: currentIndex ?? this.currentIndex,
      allowedSections: allowedSections ?? this.allowedSections,
      profileStats: profileStats ?? this.profileStats,
    );
  }
}
