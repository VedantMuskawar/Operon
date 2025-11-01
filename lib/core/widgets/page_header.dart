import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class PageHeader extends StatelessWidget {
  final String title;
  final VoidCallback? onBack;
  final List<Widget>? actions;
  final bool showBackButton;
  final String? role;
  final String? roleDisplay;
  final bool sticky;

  const PageHeader({
    super.key,
    required this.title,
    this.onBack,
    this.actions,
    this.showBackButton = true,
    this.role,
    this.roleDisplay,
    this.sticky = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF141416).withValues(alpha: 0.6),
        border: const Border(
          bottom: BorderSide(
            color: Color(0x0FFFFFFF),
            width: 1,
          ),
        ),
        boxShadow: sticky ? [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ] : null,
      ),
      child: Container(
        height: 64,
        padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.spacingMd,
          vertical: AppTheme.spacingSm,
        ),
        child: Row(
          children: [
            // Left side - Back button
            if (showBackButton) ...[
              _buildBackButton(),
              const SizedBox(width: AppTheme.spacingMd),
            ],
            
            // Center - Title
            Expanded(
              child: Center(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 19.2,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFFF5F5F7),
                  ),
                ),
              ),
            ),
            
            // Right side - Actions and Role badge
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (actions != null) ...[
                  ...actions!,
                  const SizedBox(width: AppTheme.spacingMd),
                ],
                if (role != null) ...[
                  _buildRoleBadge(),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBackButton() {
    return GestureDetector(
      onTap: onBack,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 10,
          vertical: 6,
        ),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF28282A),
              Color(0xFF1A1A1C),
            ],
          ),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: const Color(0x14FFFFFF),
            width: 1,
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x40000000),
              blurRadius: 18,
              offset: Offset(0, 6),
            ),
          ],
        ),
        child: const Text(
          '←',
          style: TextStyle(
            fontSize: 15.2,
            color: Color(0xFF9BA3AE),
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildRoleBadge() {
    final roleData = _getRoleData(role!);
    
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: roleData['backgroundColor'],
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: roleData['borderColor'],
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            roleData['icon'],
            style: const TextStyle(fontSize: 12),
          ),
          const SizedBox(width: 4),
          Text(
            roleDisplay ?? roleData['text'],
            style: TextStyle(
              fontSize: 14.4,
              fontWeight: FontWeight.w600,
              color: roleData['textColor'],
            ),
          ),
        ],
      ),
    );
  }

  Map<String, dynamic> _getRoleData(String role) {
    switch (role.toLowerCase()) {
      case 'admin':
        return {
          'backgroundColor': const Color(0x3332D74B),
          'borderColor': const Color(0x6632D74B),
          'textColor': const Color(0xFF32D74B),
          'icon': '👑',
          'text': 'Admin',
        };
      case 'manager':
        return {
          'backgroundColor': const Color(0x330A84FF),
          'borderColor': const Color(0x660A84FF),
          'textColor': const Color(0xFF0A84FF),
          'icon': '👔',
          'text': 'Manager',
        };
      case 'driver':
        return {
          'backgroundColor': const Color(0x33FF9500),
          'borderColor': const Color(0x66FF9500),
          'textColor': const Color(0xFFFF9500),
          'icon': '🚛',
          'text': 'Driver',
        };
      case 'member':
        return {
          'backgroundColor': const Color(0x338E8E93),
          'borderColor': const Color(0x668E8E93),
          'textColor': const Color(0xFF8E8E93),
          'icon': '👤',
          'text': 'Member',
        };
      default:
        return {
          'backgroundColor': const Color(0x338E8E93),
          'borderColor': const Color(0x668E8E93),
          'textColor': const Color(0xFF8E8E93),
          'icon': '👤',
          'text': 'User',
        };
    }
  }
}