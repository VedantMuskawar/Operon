import 'package:core_bloc/core_bloc.dart';
import 'package:dash_web/data/repositories/notifications_repository.dart';
import 'package:core_models/core_models.dart' as core_models;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'dart:async';

class NotificationsState extends BaseState {
  const NotificationsState({
    super.status = ViewStatus.initial,
    this.notifications = const [],
    this.unreadCount = 0,
    this.message,
  }) : super(message: message);

  final List<core_models.Notification> notifications;
  final int unreadCount;
  @override
  final String? message;

  @override
  NotificationsState copyWith({
    ViewStatus? status,
    List<core_models.Notification>? notifications,
    int? unreadCount,
    String? message,
  }) {
    return NotificationsState(
      status: status ?? this.status,
      notifications: notifications ?? this.notifications,
      unreadCount: unreadCount ?? this.unreadCount,
      message: message ?? this.message,
    );
  }
}

class NotificationsCubit extends Cubit<NotificationsState> {
  NotificationsCubit({
    required NotificationsRepository repository,
    required String organizationId,
    required String userId,
  })  : _repository = repository,
        _organizationId = organizationId,
        _userId = userId,
        super(const NotificationsState()) {
    _startListening();
  }

  final NotificationsRepository _repository;
  final String _organizationId;
  final String _userId;
  StreamSubscription<List<core_models.Notification>>? _notificationsSubscription;
  StreamSubscription<int>? _unreadCountSubscription;

  void _startListening() {
    // Listen to notifications stream
    _notificationsSubscription = _repository
        .watchNotifications(
          orgId: _organizationId,
          userId: _userId,
          limit: 50,
        )
        .listen(
      (notifications) {
        emit(state.copyWith(
          status: ViewStatus.success,
          notifications: notifications,
        ));
      },
      onError: (error) {
        emit(state.copyWith(
          status: ViewStatus.failure,
          message: 'Unable to load notifications. Please try again.',
        ));
      },
    );

    // Listen to unread count stream
    _unreadCountSubscription = _repository
        .watchUnreadCount(orgId: _organizationId, userId: _userId)
        .listen(
      (count) {
        emit(state.copyWith(unreadCount: count));
      },
      onError: (error) {
        // Silently handle unread count errors
      },
    );
  }

  Future<void> load() async {
    emit(state.copyWith(status: ViewStatus.loading, message: null));
    try {
      final notifications = await _repository.fetchNotifications(
        orgId: _organizationId,
        userId: _userId,
        limit: 50,
      );
      emit(state.copyWith(
        status: ViewStatus.success,
        notifications: notifications,
      ));
    } catch (err) {
      emit(state.copyWith(
        status: ViewStatus.failure,
        message: 'Unable to load notifications. Please try again.',
      ));
    }
  }

  Future<void> markAsRead(String notificationId) async {
    try {
      await _repository.markAsRead(
        orgId: _organizationId,
        notificationId: notificationId,
      );
      // State will update automatically via stream
    } catch (err) {
      emit(state.copyWith(
        status: ViewStatus.failure,
        message: 'Unable to mark notification as read. Please try again.',
      ));
    }
  }

  Future<void> markAllAsRead() async {
    emit(state.copyWith(status: ViewStatus.loading, message: null));
    try {
      await _repository.markAllAsRead(
        orgId: _organizationId,
        userId: _userId,
      );
      // State will update automatically via stream
    } catch (err) {
      emit(state.copyWith(
        status: ViewStatus.failure,
        message: 'Unable to mark all notifications as read. Please try again.',
      ));
    }
  }

  @override
  Future<void> close() {
    _notificationsSubscription?.cancel();
    _unreadCountSubscription?.cancel();
    return super.close();
  }
}
