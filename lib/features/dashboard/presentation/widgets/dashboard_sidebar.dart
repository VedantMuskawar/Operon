import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../auth/bloc/auth_bloc.dart';

class DashboardSidebar extends StatelessWidget {
  final int selectedIndex;
  final Function(int) onItemSelected;

  const DashboardSidebar({
    super.key,
    required this.selectedIndex,
    required this.onItemSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 280,
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        border: Border(
          right: BorderSide(
            color: AppTheme.borderColor,
            width: 1,
          ),
        ),
      ),
      child: Column(
        children: [
          _buildHeader(),
          const SizedBox(height: 32),
          _buildNavigationItems(),
          const Spacer(),
          _buildFooter(context),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              gradient: AppTheme.primaryGradient,
              borderRadius: BorderRadius.circular(16),
              boxShadow: AppTheme.cardShadow,
            ),
            child: const Icon(
              Icons.admin_panel_settings,
              size: 30,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'OPERON',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Super Admin Portal',
            style: TextStyle(
              fontSize: 12,
              color: AppTheme.textSecondaryColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavigationItems() {
    final navigationItems = [
      _NavigationItem(
        icon: Icons.dashboard,
        title: 'Dashboard',
        index: 0,
      ),
      _NavigationItem(
        icon: Icons.business,
        title: 'Organizations',
        index: 1,
      ),
      _NavigationItem(
        icon: Icons.add_business,
        title: 'Add Organization',
        index: 2,
      ),
    ];

    return Column(
      children: navigationItems.map((item) => _buildNavigationItem(item)).toList(),
    );
  }

  Widget _buildNavigationItem(_NavigationItem item) {
    final isSelected = selectedIndex == item.index;
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => onItemSelected(item.index),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isSelected 
                  ? AppTheme.primaryColor.withOpacity(0.1)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              border: isSelected 
                  ? Border.all(color: AppTheme.primaryColor.withOpacity(0.3))
                  : null,
            ),
            child: Row(
              children: [
                Icon(
                  item.icon,
                  color: isSelected ? AppTheme.primaryColor : AppTheme.textSecondaryColor,
                  size: 22,
                ),
                const SizedBox(width: 12),
                Text(
                  item.title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                    color: isSelected ? AppTheme.primaryColor : AppTheme.textPrimaryColor,
                  ),
                ),
                if (isSelected) ...[
                  const Spacer(),
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: AppTheme.primaryColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFooter(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          const Divider(),
          const SizedBox(height: 16),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(
              Icons.person,
              color: AppTheme.textSecondaryColor,
              size: 20,
            ),
            title: const Text(
              'Super Admin',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            subtitle: Text(
              'Last login: Today',
              style: TextStyle(
                fontSize: 12,
                color: AppTheme.textSecondaryColor,
              ),
            ),
            trailing: IconButton(
              icon: const Icon(
                Icons.logout,
                color: AppTheme.errorColor,
                size: 20,
              ),
              onPressed: () {
                context.read<AuthBloc>().add(AuthLogoutRequested());
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _NavigationItem {
  final IconData icon;
  final String title;
  final int index;

  const _NavigationItem({
    required this.icon,
    required this.title,
    required this.index,
  });
}
