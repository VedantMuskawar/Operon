import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class ProfileDropdown extends StatefulWidget {
  final String userName;
  final String? userPhone;
  final String organizationName;
  final int userRole;
  final VoidCallback? onEditProfile;
  final VoidCallback? onSwitchOrganization;
  final VoidCallback? onSignOut;

  const ProfileDropdown({
    super.key,
    required this.userName,
    this.userPhone,
    required this.organizationName,
    required this.userRole,
    this.onEditProfile,
    this.onSwitchOrganization,
    this.onSignOut,
  });

  @override
  State<ProfileDropdown> createState() => _ProfileDropdownState();
}

class _ProfileDropdownState extends State<ProfileDropdown>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
  }

  void _initializeAnimations() {
    _animationController = AnimationController(
      duration: AppTheme.animationNormal,
      vsync: this,
    );
    
    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: AppTheme.animationCurve,
    ));

    _opacityAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: AppTheme.animationCurve,
    ));

    // Start animation
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: Opacity(
            opacity: _opacityAnimation.value,
            child: Container(
              width: 288, // w-72 (18rem) matching PaveBoard
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A1A), // Darker background like PaveBoard
                borderRadius: BorderRadius.circular(AppTheme.radiusXl),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.1), // Subtle border
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.5),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // User Info Section
                  _buildUserInfoSection(),
                  
                  // Divider
                  Divider(
                    color: AppTheme.borderColor.withValues(alpha: 0.5),
                    height: 1,
                    thickness: 1,
                  ),
                  
                  // Organization Info Section
                  _buildOrganizationInfoSection(),
                  
                  // Divider
                  Divider(
                    color: AppTheme.borderColor.withValues(alpha: 0.5),
                    height: 1,
                    thickness: 1,
                  ),
                  
                  // Actions Section
                  _buildActionsSection(),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildUserInfoSection() {
    return Padding(
      padding: const EdgeInsets.all(16), // p-4 matching PaveBoard
      child: Row(
        children: [
          // Avatar - larger to match PaveBoard
          Container(
            width: 56,
            height: 56,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [
                  Color(0xFF3B82F6), // blue-500
                  Color(0xFF8B5CF6), // purple-600
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Center(
              child: Text(
                widget.userName.isNotEmpty 
                    ? widget.userName[0].toUpperCase()
                    : 'U',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12), // space-x-3
          // User Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.userName,
                  style: const TextStyle(
                    color: Color(0xFFE5E7EB), // text-gray-200
                    fontSize: 16, // text-base
                    fontWeight: FontWeight.w600, // font-semibold
                  ),
                ),
                if (widget.userPhone != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    widget.userPhone!,
                    style: const TextStyle(
                      color: Color(0xFF9CA3AF), // text-gray-400
                      fontSize: 12, // text-xs
                    ),
                  ),
                ],
                const SizedBox(height: 8), // mt-1
                // Role Badge
                _buildRoleBadge(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoleBadge() {
    final roleInfo = _getRoleInfo();
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: roleInfo.color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(999), // rounded-full
      ),
      child: Text(
        roleInfo.name,
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w500,
          fontSize: 12, // text-xs matching PaveBoard
        ),
      ),
    );
  }

  Widget _buildOrganizationInfoSection() {
    return Padding(
      padding: const EdgeInsets.all(16), // p-4 matching PaveBoard
      child: Column(
        children: [
          // Organization row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Organization',
                style: const TextStyle(
                  color: Color(0xFF9CA3AF), // text-gray-400
                  fontSize: 12, // text-xs
                ),
              ),
              Flexible(
                child: Text(
                  widget.organizationName,
                  style: const TextStyle(
                    color: Color(0xFFE5E7EB), // text-gray-200
                    fontSize: 12, // text-xs
                    fontWeight: FontWeight.w500, // font-medium
                  ),
                  textAlign: TextAlign.right,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8), // space-y-2
          // Status row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Status',
                style: const TextStyle(
                  color: Color(0xFF9CA3AF), // text-gray-400
                  fontSize: 12, // text-xs
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.2), // success color
                  borderRadius: BorderRadius.circular(999), // rounded-full
                ),
                child: const Text(
                  'Active',
                  style: TextStyle(
                    color: Color(0xFF10B981), // success color
                    fontWeight: FontWeight.w500,
                    fontSize: 12, // text-xs matching PaveBoard
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionsSection() {
    return Padding(
      padding: const EdgeInsets.all(16), // p-4 matching PaveBoard
      child: Column(
        children: [
          // Edit Profile
          _buildActionButton(
            icon: Icons.edit,
            title: 'Edit Profile',
            onTap: widget.onEditProfile,
          ),
          
          const SizedBox(height: 6), // space-y-1.5
          
          // Switch Organization
          _buildActionButton(
            icon: Icons.business,
            title: 'Switch Organization',
            onTap: widget.onSwitchOrganization,
          ),
          
          const SizedBox(height: 6), // space-y-1.5
          
          // Sign Out
          _buildActionButton(
            icon: Icons.logout,
            title: 'Sign Out',
            onTap: widget.onSignOut,
            isDestructive: true,
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String title,
    VoidCallback? onTap,
    bool isDestructive = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 8, // py-2 matching PaveBoard
        ),
        decoration: BoxDecoration(
          color: isDestructive 
              ? const Color(0xFFEF4444).withValues(alpha: 0.1) // danger/error color
              : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isDestructive 
                ? const Color(0xFFEF4444).withValues(alpha: 0.3)
                : Colors.white.withValues(alpha: 0.1),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 16,
              color: isDestructive 
                  ? const Color(0xFFEF4444) // error color
                  : const Color(0xFF9CA3AF), // text-gray-400
            ),
            const SizedBox(width: 8), // mr-2
            Text(
              title,
              style: TextStyle(
                color: isDestructive 
                    ? const Color(0xFFEF4444)
                    : const Color(0xFFE5E7EB), // text-gray-200
                fontWeight: FontWeight.w500,
                fontSize: 12, // text-xs matching PaveBoard
              ),
            ),
          ],
        ),
      ),
    );
  }

  ({String name, Color color}) _getRoleInfo() {
    switch (widget.userRole) {
      case 0:
        return (name: 'Super Admin', color: Colors.purple);
      case 1:
        return (name: 'Admin', color: Colors.red);
      case 2:
        return (name: 'Manager', color: Colors.blue);
      case 3:
        return (name: 'Driver', color: Colors.green);
      default:
        return (name: 'User', color: AppTheme.textSecondaryColor);
    }
  }
}


