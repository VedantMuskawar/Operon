import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/models/organization.dart';
import '../../../../core/models/user.dart';
import '../../../../core/constants/app_constants.dart';
import '../widgets/user_list.dart';
import '../widgets/add_user_form.dart';

class UserManagementPage extends StatefulWidget {
  final Organization organization;

  const UserManagementPage({
    super.key,
    required this.organization,
  });

  @override
  State<UserManagementPage> createState() => _UserManagementPageState();
}

class _UserManagementPageState extends State<UserManagementPage> {
  int _selectedTabIndex = 0;
  final ValueNotifier<int> _userListRefresh = ValueNotifier<int>(0);

  @override
  void dispose() {
    _userListRefresh.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: AppTheme.surfaceColor,
        foregroundColor: AppTheme.textPrimaryColor,
        title: Text('Manage Users - ${widget.organization.orgName}'),
        elevation: 0,
        actions: [
          IconButton(
            onPressed: () {
              setState(() {
                _selectedTabIndex = 1;
              });
            },
            icon: const Icon(Icons.person_add),
            tooltip: 'Add User',
          ),
        ],
      ),
      body: Column(
        children: [
          _buildTabBar(),
          Expanded(
            child: IndexedStack(
              index: _selectedTabIndex,
              children: [
                UserList(
                  organization: widget.organization,
                  refreshNotifier: _userListRefresh,
                ),
                AddUserForm(
                  organization: widget.organization,
                  refreshNotifier: _userListRefresh,
                  onUserAdded: () {
                    setState(() {
                      _selectedTabIndex = 0;
                    });
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderColor),
      ),
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
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryColor.withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: isSelected ? AppTheme.primaryColor : AppTheme.textSecondaryColor,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? AppTheme.primaryColor : AppTheme.textSecondaryColor,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
