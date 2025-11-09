import 'package:flutter/material.dart';

import '../../../../core/models/organization.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/page_container.dart';
import '../../../../core/widgets/page_header.dart';
import 'add_user_form.dart';
import 'user_list.dart';

class OrganizationUsersView extends StatefulWidget {
  final Organization organization;
  final int userRole;
  final VoidCallback onBack;

  const OrganizationUsersView({
    super.key,
    required this.organization,
    required this.userRole,
    required this.onBack,
  });

  @override
  State<OrganizationUsersView> createState() => _OrganizationUsersViewState();
}

class _OrganizationUsersViewState extends State<OrganizationUsersView> {
  int _selectedTabIndex = 0;

  @override
  Widget build(BuildContext context) {
    return PageContainer(
      fullHeight: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          PageHeader(
            title: 'Organization Users',
            onBack: widget.onBack,
            role: _getRoleString(widget.userRole),
          ),
          const SizedBox(height: AppTheme.spacingLg),
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1200),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildTabBar(),
                  const SizedBox(height: AppTheme.spacingLg),
                  SizedBox(
                    height: 640,
                    child: IndexedStack(
                      index: _selectedTabIndex,
                      children: [
                        _buildUsersTab(),
                        _buildAddUserTab(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF181C1F),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.06),
          width: 1,
        ),
      ),
      padding: const EdgeInsets.all(6),
      child: Row(
        children: [
          Expanded(
            child: _buildTabItem(
              index: 0,
              icon: Icons.people,
              label: 'Users',
            ),
          ),
          Expanded(
            child: _buildTabItem(
              index: 1,
              icon: Icons.person_add,
              label: 'Add User',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabItem({
    required int index,
    required IconData icon,
    required String label,
  }) {
    final isSelected = _selectedTabIndex == index;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedTabIndex = index;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.primaryColor.withOpacity(0.12)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: isSelected
                  ? AppTheme.primaryColor
                  : AppTheme.textSecondaryColor,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: isSelected
                    ? AppTheme.primaryColor
                    : AppTheme.textSecondaryColor,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUsersTab() {
    return Container(
      decoration: _contentDecoration(),
      padding: const EdgeInsets.all(AppTheme.spacingMd),
      child: UserList(organization: widget.organization),
    );
  }

  Widget _buildAddUserTab() {
    return Container(
      decoration: _contentDecoration(),
      padding: const EdgeInsets.all(AppTheme.spacingMd),
      child: AddUserForm(organization: widget.organization),
    );
  }

  BoxDecoration _contentDecoration() {
    return BoxDecoration(
      color: const Color(0xFF141618).withValues(alpha: 0.6),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(
        color: Colors.white.withValues(alpha: 0.08),
        width: 1,
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.12),
          blurRadius: 24,
          offset: const Offset(0, 8),
        ),
      ],
    );
  }

  String _getRoleString(int userRole) {
    switch (userRole) {
      case 0:
      case 1:
        return 'admin';
      case 2:
        return 'manager';
      case 3:
        return 'driver';
      default:
        return 'member';
    }
  }
}

