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
    this.extraActions,
    /// @deprecated Use [extraActions] instead. This parameter is kept for backward compatibility.
    this.trailingSection,
  });

  final UserProfile? user;
  final dynamic organization; // OrganizationMembership (app-specific)
  final String? actualUserName; // Actual user name from organization user record (if already fetched)
  final Future<String?> Function()? fetchUserName; // Optional function to fetch user name
  final VoidCallback onChangeOrg;
  final VoidCallback onLogout;
  final VoidCallback? onOpenUsers;
  /// Optional list of widgets shown after quick actions, before Logout (e.g. Caller ID switch on Android).
  /// Prefer this over [trailingSection] for multiple widgets.
  final List<Widget>? extraActions;
  /// @deprecated Use [extraActions] instead. Optional widget shown after quick actions, before Logout.
  final Widget? trailingSection;

  @override
  Widget build(BuildContext context) {
    // Use FutureBuilder if fetchUserName is provided, otherwise use actualUserName or fallback
    Widget nameWidget;
    
    // Helper to get initial display name for immediate display (without phone fallback)
    String getInitialDisplayName() {
      if (actualUserName != null && actualUserName!.isNotEmpty) return actualUserName!;
      final displayName = user?.displayName;
      if (displayName != null && displayName.isNotEmpty) return displayName;
      return 'User';
    }

    if (fetchUserName != null) {
      nameWidget = FutureBuilder<String?>(
        future: fetchUserName!(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return _buildProfileContent(
              context,
              displayName: getInitialDisplayName(),
              isLoading: true,
            );
          }
          String displayName = snapshot.data ??
              actualUserName ??
              user?.displayName ??
              '';
          if (displayName.isEmpty || displayName == 'Unnamed') displayName = 'User';
          return _buildProfileContent(context, displayName: displayName);
        },
      );
    } else {
      nameWidget = _buildProfileContent(context, displayName: getInitialDisplayName());
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 0),
      child: nameWidget,
    );
  }

  Widget _buildProfileContent(
    BuildContext context, {
    required String displayName,
    bool isLoading = false,
  }) {
    // Get organization name if available
    String? orgName;
    if (organization != null) {
      try {
        orgName = organization.name as String?;
      } catch (_) {
        try {
          orgName = organization['name'] as String?;
        } catch (_) {}
      }
    }

    // Get phone number if available
    final phoneNumber = user?.phoneNumber;
    final maskedPhone = (phoneNumber != null && phoneNumber.length >= 10)
        ? '${phoneNumber.substring(0, 2)}****${phoneNumber.substring(phoneNumber.length - 4)}'
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Avatar and Name Row
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Avatar with gradient
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AuthColors.primary,
                    AuthColors.primary.withValues(alpha: 0.75),
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: AuthColors.primary.withValues(alpha: 0.4),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                    spreadRadius: 0,
                  ),
                ],
              ),
              child: const Icon(
                Icons.person,
                color: Colors.white,
                size: 36,
              ),
            ),
            const SizedBox(width: 20),
            // Name and details column
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // User Name - Large and prominent
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          displayName,
                          style: const TextStyle(
                            color: AuthColors.textMain,
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            fontFamily: 'SF Pro Display',
                            height: 1.3,
                            letterSpacing: -0.3,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isLoading)
                        Padding(
                          padding: const EdgeInsets.only(left: 8),
                          child: const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AuthColors.textSub,
                            ),
                          ),
                        ),
                    ],
                  ),
                  if (orgName != null) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(
                          Icons.business_outlined,
                          size: 14,
                          color: AuthColors.textSub.withValues(alpha: 0.8),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            orgName,
                            style: TextStyle(
                              color: AuthColors.textSub,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              fontFamily: 'SF Pro Display',
                              height: 1.4,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (maskedPhone != null) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.phone_outlined,
                          size: 13,
                          color: AuthColors.textSub.withValues(alpha: 0.7),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          maskedPhone,
                          style: TextStyle(
                            color: AuthColors.textSub.withValues(alpha: 0.9),
                            fontSize: 13,
                            fontFamily: 'SF Pro Display',
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
        
        const SizedBox(height: 24),
        
        // Quick Actions Section
        Column(
          children: [
            _ProfileAction(
              icon: Icons.swap_horiz_rounded,
              label: 'Change Organization',
              onTap: onChangeOrg,
            ),
            if (onOpenUsers != null) ...[
              Divider(
                height: 1,
                thickness: 1,
                color: AuthColors.textMainWithOpacity(0.08),
                indent: 64,
                endIndent: 0,
              ),
              _ProfileAction(
                icon: Icons.people_outline_rounded,
                label: 'Users',
                onTap: onOpenUsers!,
              ),
            ],
          ],
        ),
        
        if (extraActions != null && extraActions!.isNotEmpty) ...[
          const SizedBox(height: 16),
          ...extraActions!,
        ],
        // Keep trailingSection for backward compatibility
        if (trailingSection != null) ...[
          const SizedBox(height: 16),
          trailingSection!,
        ],
        
        const SizedBox(height: 24),
        
        // Logout Button
        DashButton(
          label: 'Logout',
          onPressed: onLogout,
          icon: Icons.logout,
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
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        splashColor: AuthColors.primary.withValues(alpha: 0.1),
        highlightColor: AuthColors.primary.withValues(alpha: 0.05),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: onTap != null
                      ? AuthColors.primary.withValues(alpha: 0.12)
                      : AuthColors.textMainWithOpacity(0.06),
                  borderRadius: BorderRadius.circular(12),
                  border: onTap != null
                      ? Border.all(
                          color: AuthColors.primary.withValues(alpha: 0.2),
                          width: 1,
                        )
                      : null,
                ),
                child: Icon(
                  icon,
                  color: onTap != null 
                      ? AuthColors.primary 
                      : AuthColors.textDisabled,
                  size: 22,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: onTap != null 
                        ? AuthColors.textMain 
                        : AuthColors.textDisabled,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'SF Pro Display',
                    height: 1.4,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
              if (onTap != null)
                Icon(
                  Icons.chevron_right_rounded,
                  color: AuthColors.textSub.withValues(alpha: 0.7),
                  size: 22,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
