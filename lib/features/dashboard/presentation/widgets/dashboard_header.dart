import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../auth/bloc/auth_bloc.dart';
import '../../../profile/presentation/pages/profile_page.dart';
import '../../../settings/presentation/pages/settings_page.dart';
import '../../../settings/bloc/settings_bloc.dart';
import '../../../../core/repositories/config_repository.dart';

class DashboardHeader extends StatelessWidget {
  const DashboardHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 80,
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        border: Border(
          bottom: BorderSide(
            color: AppTheme.borderColor,
            width: 1,
          ),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  BlocBuilder<AuthBloc, AuthState>(
                    builder: (context, state) {
                      if (state is AuthAuthenticated) {
                        return Text(
                          'Welcome back, Super Admin!',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: AppTheme.textPrimaryColor,
                            fontWeight: FontWeight.w600,
                          ),
                        );
                      }
                      return Text(
                        'Welcome to OPERON',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: AppTheme.textPrimaryColor,
                          fontWeight: FontWeight.w600,
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Manage your organizations and subscriptions',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppTheme.textSecondaryColor,
                    ),
                  ),
                ],
              ),
            ),
            _buildHeaderActions(context),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderActions(BuildContext context) {
    return Row(
      children: [
        _buildNotificationButton(),
        const SizedBox(width: 16),
        _buildProfileButton(context),
      ],
    );
  }

  Widget _buildNotificationButton() {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: AppTheme.borderColor,
          width: 1,
        ),
      ),
      child: IconButton(
        iconSize: 20,
        icon: Stack(
          children: [
            const Icon(
              Icons.notifications_outlined,
              color: AppTheme.textPrimaryColor,
              size: 20,
            ),
            Positioned(
              right: 0,
              top: 0,
              child: Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: AppTheme.errorColor,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ],
        ),
        onPressed: () {
          // TODO: Implement notifications
        },
      ),
    );
  }

  Widget _buildProfileButton(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: AppTheme.borderColor,
          width: 1,
        ),
      ),
      child: PopupMenuButton<String>(
        icon: const Icon(
          Icons.account_circle,
          color: AppTheme.textPrimaryColor,
          size: 20,
        ),
        onSelected: (value) {
          switch (value) {
            case 'profile':
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const ProfilePage(),
                ),
              );
              break;
            case 'settings':
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => BlocProvider(
                    create: (context) => SettingsBloc(
                      configRepository: ConfigRepository(),
                    ),
                    child: const SettingsPage(),
                  ),
                ),
              );
              break;
            case 'logout':
              context.read<AuthBloc>().add(AuthLogoutRequested());
              break;
          }
        },
        itemBuilder: (context) => [
          const PopupMenuItem(
            value: 'profile',
            child: Row(
              children: [
                Icon(Icons.person, size: 20),
                SizedBox(width: 12),
                Text('Profile'),
              ],
            ),
          ),
          const PopupMenuItem(
            value: 'settings',
            child: Row(
              children: [
                Icon(Icons.settings, size: 20),
                SizedBox(width: 12),
                Text('Settings'),
              ],
            ),
          ),
          const PopupMenuDivider(),
          const PopupMenuItem(
            value: 'logout',
            child: Row(
              children: [
                Icon(Icons.logout, color: AppTheme.errorColor, size: 20),
                SizedBox(width: 12),
                Text('Logout', style: TextStyle(color: AppTheme.errorColor)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
