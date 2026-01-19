import 'package:core_models/core_models.dart';
import '../../theme/auth_colors.dart';
import '../dash_button.dart';
import 'package:flutter/material.dart';

/// Simplified reusable profile view component
/// 
/// Displays user information and quick actions.
/// Used in both Android (Drawer) and Web (Side Panel) apps.
class ProfileView extends StatelessWidget {
  const ProfileView({
    super.key,
    required this.user,
    required this.organization,
    this.actualUserName,
    this.fetchUserName,
    required this.onChangeOrg,
    required this.onLogout,
    this.onOpenUsers,
    this.onOpenPermissions,
  });

  final UserProfile? user;
  final dynamic organization; // OrganizationMembership (app-specific)
  final String? actualUserName; // Actual user name from organization user record (if already fetched)
  final Future<String?> Function()? fetchUserName; // Optional function to fetch user name
  final VoidCallback onChangeOrg;
  final VoidCallback onLogout;
  final VoidCallback? onOpenUsers;
  final VoidCallback? onOpenPermissions;

  @override
  Widget build(BuildContext context) {
    // Use FutureBuilder if fetchUserName is provided, otherwise use actualUserName or fallback
    Widget nameWidget;
    if (fetchUserName != null) {
      nameWidget = FutureBuilder<String?>(
        future: fetchUserName!(),
        builder: (context, snapshot) {
          final displayName = snapshot.data ?? 
                              actualUserName ?? 
                              user?.displayName ?? 
                              'User';
          return _buildProfileContent(context, displayName: displayName);
        },
      );
    } else {
      final displayName = actualUserName ?? 
                          user?.displayName ?? 
                          'User';
      nameWidget = _buildProfileContent(context, displayName: displayName);
    }

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 40, 20, 20),
        child: nameWidget,
      ),
    );
  }

  Widget _buildProfileContent(
    BuildContext context, {
    required String displayName,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Simplified Profile Header
        Row(
          children: [
            // Avatar
            Container(
              width: 56,
              height: 56,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: AuthColors.primary,
              ),
              child: const Icon(
                Icons.person,
                color: Colors.white,
                size: 28,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                displayName,
                style: const TextStyle(
                  color: AuthColors.textMain,
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'SF Pro Display',
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        
        const SizedBox(height: 32),
        
        // Quick Actions
        _ProfileAction(
          icon: Icons.swap_horiz,
          label: 'Change Organization',
          onTap: onChangeOrg,
        ),
        if (onOpenUsers != null)
          _ProfileAction(
            icon: Icons.group_add_outlined,
            label: 'Users',
            onTap: onOpenUsers!,
          ),
        if (onOpenPermissions != null)
          _ProfileAction(
            icon: Icons.security,
            label: 'Permissions',
            onTap: onOpenPermissions!,
          ),
        
        const SizedBox(height: 24),
        
        // Logout Button
        DashButton(
          label: 'Logout',
          onPressed: onLogout,
        ),
      ],
    );
  }
}

class _ProfileAction extends StatelessWidget {
  const _ProfileAction({
    required this.icon,
    required this.label,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Icon(
              icon,
              color: onTap != null ? AuthColors.textMain : AuthColors.textDisabled,
              size: 22,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: onTap != null ? AuthColors.textMain : AuthColors.textDisabled,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  fontFamily: 'SF Pro Display',
                ),
              ),
            ),
            if (onTap != null)
              const Icon(
                Icons.chevron_right,
                color: AuthColors.textSub,
                size: 20,
              ),
          ],
        ),
      ),
    );
  }
}
