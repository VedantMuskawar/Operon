import 'package:core_bloc/core_bloc.dart';
import 'package:core_ui/core_ui.dart';
import 'package:core_models/core_models.dart' as core_models;
import 'package:dash_web/data/repositories/notifications_repository.dart';
import 'package:dash_web/presentation/blocs/auth/auth_bloc.dart';
import 'package:dash_web/presentation/blocs/notifications/notifications_cubit.dart';
import 'package:dash_web/presentation/blocs/org_context/org_context_cubit.dart';
import 'package:dash_web/presentation/widgets/section_workspace_layout.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:go_router/go_router.dart';

class NotificationsPage extends StatelessWidget {
  const NotificationsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final orgState = context.watch<OrganizationContextCubit>().state;
    final organization = orgState.organization;
    final authState = context.watch<AuthBloc>().state;
    final userId = authState.userProfile?.id;

    if (organization == null || userId == null) {
      return const Scaffold(
        body: Center(child: Text('No organization selected')),
      );
    }

    return MultiBlocProvider(
      providers: [
        BlocProvider<NotificationsCubit>(
          create: (context) => NotificationsCubit(
            repository: context.read<NotificationsRepository>(),
            organizationId: organization.id,
            userId: userId,
          ),
        ),
      ],
      child: SectionWorkspaceLayout(
        panelTitle: 'Notifications',
        currentIndex: -1,
        onNavTap: (index) => context.go('/home?section=$index'),
        child: const NotificationsPageContent(),
      ),
    );
  }
}

class NotificationsPageContent extends StatelessWidget {
  const NotificationsPageContent({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocListener<NotificationsCubit, NotificationsState>(
      listener: (context, state) {
        if (state.status == ViewStatus.failure && state.message != null) {
          DashSnackbar.show(
            context,
            message: state.message!,
            isError: true,
          );
        }
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          BlocBuilder<NotificationsCubit, NotificationsState>(
            builder: (context, state) {
              if (state.unreadCount > 0) {
                return Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: const Color(0xFF6F4BFF).withValues(alpha: 0.2),
                    border: Border.all(
                      color: const Color(0xFF6F4BFF),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${state.unreadCount} unread notification${state.unreadCount == 1 ? '' : 's'}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          context.read<NotificationsCubit>().markAllAsRead();
                        },
                        child: const Text('Mark all as read'),
                      ),
                    ],
                  ),
                );
              }
              return const SizedBox.shrink();
            },
          ),
          BlocBuilder<NotificationsCubit, NotificationsState>(
            builder: (context, state) {
              if (state.status == ViewStatus.loading) {
                return const Center(child: CircularProgressIndicator());
              }
              if (state.notifications.isEmpty) {
                return Center(
                  child: Text(
                    'No notifications yet.',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.6),
                      fontSize: 16,
                    ),
                    textAlign: TextAlign.center,
                  ),
                );
              }
              return AnimationLimiter(
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: state.notifications.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final notification = state.notifications[index];
                    return AnimationConfiguration.staggeredList(
                      position: index,
                      duration: const Duration(milliseconds: 200),
                      child: SlideAnimation(
                        verticalOffset: 50.0,
                        child: FadeInAnimation(
                          curve: Curves.easeOut,
                          child: _NotificationTile(
                            notification: notification,
                            onTap: () {
                              if (!notification.isRead) {
                                context.read<NotificationsCubit>().markAsRead(notification.id);
                              }
                            },
                          ),
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({
    required this.notification,
    required this.onTap,
  });

  final core_models.Notification notification;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final icon = notification.type == core_models.NotificationType.geofenceEnter
        ? Icons.login
        : Icons.logout;
    final color = notification.type == core_models.NotificationType.geofenceEnter
        ? const Color(0xFF5AD8A4)
        : const Color(0xFFFF6B6B);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: notification.isRead
              ? const Color(0xFF1F1F2C)
              : const Color(0xFF1F1F2C).withValues(alpha: 0.8),
          border: Border.all(
            color: notification.isRead
                ? Colors.white.withValues(alpha: 0.1)
                : color.withValues(alpha: 0.5),
            width: notification.isRead ? 1 : 2,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: color.withValues(alpha: 0.2),
              ),
              child: Icon(
                icon,
                color: color,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    notification.title,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: notification.isRead
                          ? FontWeight.w500
                          : FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    notification.message,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 14,
                    ),
                  ),
                  if (notification.vehicleNumber != null ||
                      notification.driverName != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      [
                        if (notification.driverName != null)
                          notification.driverName,
                        if (notification.vehicleNumber != null)
                          notification.vehicleNumber,
                      ].join(' • '),
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.5),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (!notification.isRead)
              Container(
                width: 8,
                height: 8,
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
