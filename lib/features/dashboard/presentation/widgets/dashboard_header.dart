import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'dart:ui';
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
        // Apple-style glossy transparent background
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withOpacity(0.08),
            Colors.white.withOpacity(0.02),
          ],
        ),
        border: Border(
          bottom: BorderSide(
            color: Colors.white.withOpacity(0.1),
            width: 0.5,
          ),
        ),
        // Backdrop blur effect for glassmorphism
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 0),
          ),
        ],
      ),
      child: ClipRRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
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
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            );
                          }
                          return Text(
                            'Welcome to OPERON',
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Manage your organizations and subscriptions',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.white.withOpacity(0.7),
                        ),
                      ),
                    ],
                  ),
                ),
                _buildHeaderActions(context),
              ],
            ),
          ),
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
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withOpacity(0.15),
            Colors.white.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withOpacity(0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: IconButton(
        iconSize: 20,
        icon: Stack(
          children: [
            Icon(
              Icons.notifications_outlined,
              color: Colors.white.withOpacity(0.9),
              size: 20,
            ),
            Positioned(
              right: 0,
              top: 0,
              child: Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: const Color(0xFFFF6B6B),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFF6B6B).withOpacity(0.5),
                      blurRadius: 4,
                    ),
                  ],
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
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withOpacity(0.15),
            Colors.white.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withOpacity(0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: PopupMenuButton<String>(
        icon: Icon(
          Icons.account_circle,
          color: Colors.white.withOpacity(0.9),
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
          PopupMenuItem(
            value: 'profile',
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.white.withOpacity(0.1),
                    Colors.white.withOpacity(0.05),
                  ],
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                children: [
                  Icon(Icons.person, size: 20, color: Colors.white),
                  SizedBox(width: 12),
                  Text('Profile', style: TextStyle(color: Colors.white)),
                ],
              ),
            ),
          ),
          PopupMenuItem(
            value: 'settings',
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.white.withOpacity(0.1),
                    Colors.white.withOpacity(0.05),
                  ],
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                children: [
                  Icon(Icons.settings, size: 20, color: Colors.white),
                  SizedBox(width: 12),
                  Text('Settings', style: TextStyle(color: Colors.white)),
                ],
              ),
            ),
          ),
          const PopupMenuDivider(),
          PopupMenuItem(
            value: 'logout',
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFFFF6B6B).withOpacity(0.2),
                    const Color(0xFFFF6B6B).withOpacity(0.1),
                  ],
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                children: [
                  Icon(Icons.logout, color: Color(0xFFFF6B6B), size: 20),
                  SizedBox(width: 12),
                  Text('Logout', style: TextStyle(color: Color(0xFFFF6B6B))),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}