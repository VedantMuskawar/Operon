import 'package:dash_web/data/datasources/notification_data_source.dart';
import 'package:core_models/core_models.dart';
import 'dart:async';

class NotificationsRepository {
  NotificationsRepository({
    required NotificationDataSource dataSource,
  }) : _dataSource = dataSource;

  final NotificationDataSource _dataSource;

  Future<List<Notification>> fetchNotifications({
    required String orgId,
    required String userId,
    int? limit,
  }) {
    return _dataSource.fetchNotifications(
      orgId: orgId,
      userId: userId,
      limit: limit,
    );
  }

  Future<List<Notification>> fetchUnreadNotifications({
    required String orgId,
    required String userId,
  }) {
    return _dataSource.fetchUnreadNotifications(
      orgId: orgId,
      userId: userId,
    );
  }

  Stream<int> watchUnreadCount({
    required String orgId,
    required String userId,
  }) {
    return _dataSource.watchUnreadCount(orgId: orgId, userId: userId);
  }

  Stream<List<Notification>> watchNotifications({
    required String orgId,
    required String userId,
    int? limit,
  }) {
    return _dataSource.watchNotifications(
      orgId: orgId,
      userId: userId,
      limit: limit,
    );
  }

  Future<void> markAsRead({
    required String orgId,
    required String notificationId,
  }) {
    return _dataSource.markAsRead(
      orgId: orgId,
      notificationId: notificationId,
    );
  }

  Future<void> markAllAsRead({
    required String orgId,
    required String userId,
  }) {
    return _dataSource.markAllAsRead(orgId: orgId, userId: userId);
  }
}
