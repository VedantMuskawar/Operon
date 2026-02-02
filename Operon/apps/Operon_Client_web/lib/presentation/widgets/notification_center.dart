import 'package:core_models/core_models.dart' as core_models;
import 'package:core_ui/core_ui.dart';
import 'package:dash_web/data/repositories/notifications_repository.dart';
import 'package:dash_web/presentation/blocs/auth/auth_bloc.dart';
import 'package:dash_web/presentation/blocs/notifications/notifications_cubit.dart';
import 'package:dash_web/presentation/blocs/org_context/org_context_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class NotificationCenter extends StatelessWidget {
  const NotificationCenter({super.key});

  @override
  Widget build(BuildContext context) {
    final orgState = context.watch<OrganizationContextCubit>().state;
    final organization = orgState.organization;
    final authState = context.watch<AuthBloc>().state;
    final userId = authState.userProfile?.id;

    if (organization == null || userId == null) {
      return const SizedBox.shrink();
    }

    return BlocProvider<NotificationsCubit>(
      create: (context) => NotificationsCubit(
        repository: context.read<NotificationsRepository>(),
        organizationId: organization.id,
        userId: userId,
      ),
      child: _NotificationBell(),
    );
  }
}

class _NotificationBell extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return BlocBuilder<NotificationsCubit, NotificationsState>(
      builder: (context, state) {
        final unreadCount = state.unreadCount;
        final hasUnread = unreadCount > 0;

        return Stack(
          clipBehavior: Clip.none,
          children: [
            IconButton(
              icon: Icon(
                hasUnread ? Icons.notifications : Icons.notifications_outlined,
                color: Colors.white,
                size: 24,
              ),
              onPressed: () => _showNotificationDropdown(context, state),
              tooltip: 'Notifications',
            ),
            if (hasUnread)
              Positioned(
                right: 8,
                top: 8,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(0xFFFF6B6B),
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 16,
                    minHeight: 16,
                  ),
                  child: Text(
                    unreadCount > 99 ? '99+' : unreadCount.toString(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  void _showNotificationDropdown(
    BuildContext context,
    NotificationsState state,
  ) {
    showDialog(
      context: context,
      barrierColor: Colors.transparent,
      builder: (dialogContext) => _NotificationDropdown(
        notifications: state.notifications.take(10).toList(),
        unreadCount: state.unreadCount,
        onViewAll: () {
          Navigator.of(dialogContext).pop();
          context.go('/notifications');
        },
        onMarkAllRead: () {
          context.read<NotificationsCubit>().markAllAsRead();
        },
      ),
    );
  }
}

class _NotificationDropdown extends StatelessWidget {
  const _NotificationDropdown({
    required this.notifications,
    required this.unreadCount,
    required this.onViewAll,
    required this.onMarkAllRead,
  });

  final List<core_models.Notification> notifications;
  final int unreadCount;
  final VoidCallback onViewAll;
  final VoidCallback onMarkAllRead;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 60,
      right: 16,
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: 400,
          constraints: const BoxConstraints(maxHeight: 500),
          decoration: BoxDecoration(
            color: const Color(0xFF1F1F2C),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white24),
            boxShadow: const [
              BoxShadow(
                color: Color(0x55000000),
                blurRadius: 20,
                offset: Offset(0, 12),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Notifications',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (unreadCount > 0)
                      DashButton(
                        label: 'Mark all read',
                        onPressed: () {
                          onMarkAllRead();
                          Navigator.of(context).pop();
                        },
                        variant: DashButtonVariant.text,
                      ),
                  ],
                ),
              ),
              if (notifications.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(32),
                  child: Text(
                    'No notifications',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.6),
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.center,
                  ),
                )
              else
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: notifications.length,
                    separatorBuilder: (_, __) => Divider(
                      height: 1,
                      color: Colors.white.withOpacity(0.1),
                    ),
                    itemBuilder: (context, index) {
                      final notification = notifications[index];
                      return _NotificationItem(notification: notification);
                    },
                  ),
                ),
              if (notifications.length >= 10)
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: SizedBox(
                    width: double.infinity,
                    child: DashButton(
                      label: 'View all notifications',
                      onPressed: () {
                        Navigator.of(context).pop();
                        onViewAll();
                      },
                      variant: DashButtonVariant.text,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NotificationItem extends StatelessWidget {
  const _NotificationItem({required this.notification});

  final core_models.Notification notification;

  @override
  Widget build(BuildContext context) {
    final icon = notification.type == core_models.NotificationType.geofenceEnter
        ? Icons.login
        : Icons.logout;
    final color = notification.type == core_models.NotificationType.geofenceEnter
        ? const Color(0xFF5AD8A4)
        : const Color(0xFFFF6B6B);

    return InkWell(
      onTap: () {
        if (!notification.isRead) {
          // Mark as read handled by cubit
        }
        Navigator.of(context).pop();
        context.go('/notifications');
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        color: notification.isRead
            ? Colors.transparent
            : color.withValues(alpha: 0.1),
        child: Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    notification.title,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: notification.isRead
                          ? FontWeight.normal
                          : FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    notification.message,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 12,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (!notification.isRead)
              Container(
                width: 6,
                height: 6,
                margin: const EdgeInsets.only(left: 8),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
