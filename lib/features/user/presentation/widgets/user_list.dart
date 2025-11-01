import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/models/organization.dart';
import '../../../../core/models/user.dart';
import '../../../../core/models/organization_role.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/repositories/user_repository.dart';

class UserList extends StatefulWidget {
  final Organization organization;

  const UserList({
    super.key,
    required this.organization,
  });

  @override
  State<UserList> createState() => _UserListState();
}

class _UserListState extends State<UserList> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _roleFilter = 'all';
  String _statusFilter = 'all';
  List<User> _users = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadUsers() async {
    try {
      setState(() {
        _isLoading = true;
      });
      
      final userRepository = UserRepository();
      final users = await userRepository.getUsersByOrganization(
        widget.organization.orgId,
        searchQuery: _searchQuery.isNotEmpty ? _searchQuery : null,
        roleFilter: _roleFilter != 'all' ? int.tryParse(_roleFilter) : null,
        statusFilter: _statusFilter != 'all' ? _statusFilter : null,
      );
      
      setState(() {
        _users = users;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading users: $e'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          const SizedBox(height: 16),
          _buildSearchAndFilter(),
          const SizedBox(height: 16),
          Expanded(
            child: _buildUsersTable(),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            gradient: AppTheme.primaryGradient,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(
            Icons.people,
            color: Colors.white,
            size: 24,
          ),
        ),
        const SizedBox(width: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Organization Users',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              'Manage users and their roles in ${widget.organization.orgName}',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppTheme.textSecondaryColor,
              ),
            ),
          ],
        ),
        const Spacer(),
        Text(
          '${_users.length} users',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: AppTheme.textSecondaryColor,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildSearchAndFilter() {
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search users...',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: AppTheme.borderColor),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: AppTheme.primaryColor),
              ),
            ),
            onChanged: (value) {
              setState(() {
                _searchQuery = value;
              });
              _loadUsers();
            },
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: DropdownButtonFormField<String>(
            value: _roleFilter,
            decoration: InputDecoration(
              labelText: 'Role',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: AppTheme.borderColor),
              ),
            ),
            items: const [
              DropdownMenuItem(value: 'all', child: Text('All Roles')),
              DropdownMenuItem(value: '1', child: Text('Admin')),
              DropdownMenuItem(value: '2', child: Text('Manager')),
              DropdownMenuItem(value: '3', child: Text('Driver')),
            ],
            onChanged: (value) {
              setState(() {
                _roleFilter = value!;
              });
              _loadUsers();
            },
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: DropdownButtonFormField<String>(
            value: _statusFilter,
            decoration: InputDecoration(
              labelText: 'Status',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: AppTheme.borderColor),
              ),
            ),
            items: const [
              DropdownMenuItem(value: 'all', child: Text('All Status')),
              DropdownMenuItem(value: 'active', child: Text('Active')),
              DropdownMenuItem(value: 'inactive', child: Text('Inactive')),
              DropdownMenuItem(value: 'pending', child: Text('Pending')),
            ],
            onChanged: (value) {
              setState(() {
                _statusFilter = value!;
              });
              _loadUsers();
            },
          ),
        ),
      ],
    );
  }

  Widget _buildUsersTable() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_users.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.people_outline,
              size: 64,
              color: AppTheme.textSecondaryColor,
            ),
            const SizedBox(height: 16),
            Text(
              'No users found',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: AppTheme.textSecondaryColor,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Add users to this organization to get started',
              style: TextStyle(
                color: AppTheme.textSecondaryColor,
              ),
            ),
          ],
        ),
      );
    }

    return Card(
      child: Column(
        children: [
          _buildTableHeader(),
          Expanded(
            child: ListView.builder(
              itemCount: _users.length,
              itemBuilder: (context, index) {
                return _buildUserRow(_users[index]);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTableHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        border: Border(
          bottom: BorderSide(
            color: AppTheme.borderColor.withOpacity(0.1),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(flex: 3, child: _buildHeaderText('User')),
          Expanded(flex: 2, child: _buildHeaderText('Role')),
          Expanded(flex: 2, child: _buildHeaderText('Phone')),
          Expanded(flex: 2, child: _buildHeaderText('Status')),
          Expanded(flex: 2, child: _buildHeaderText('Joined')),
          Expanded(flex: 1, child: _buildHeaderText('Actions')),
        ],
      ),
    );
  }

  Widget _buildHeaderText(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontWeight: FontWeight.w600,
        color: AppTheme.textSecondaryColor,
        fontSize: 12,
      ),
    );
  }

  Widget _buildUserRow(User user) {
    final organizationRole = user.organizations
        .firstWhere(
          (org) => org.orgId == widget.organization.orgId,
          orElse: () => const OrganizationRole(
            orgId: '',
            role: 0,
            status: 'inactive',
            joinedDate: null,
            isPrimary: false,
            permissions: [],
          ),
        );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: AppTheme.borderColor.withOpacity(0.1),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
                  backgroundImage: user.profilePhotoUrl != null
                      ? NetworkImage(user.profilePhotoUrl!)
                      : null,
                  child: user.profilePhotoUrl == null
                      ? Text(
                          user.name[0].toUpperCase(),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primaryColor,
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimaryColor,
                        ),
                      ),
                      Text(
                        user.email,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.textSecondaryColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: _buildRoleChip(organizationRole.role),
          ),
          Expanded(
            flex: 2,
            child: Text(
              user.phoneNo,
              style: const TextStyle(
                color: AppTheme.textPrimaryColor,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: _buildStatusChip(user.status),
          ),
          Expanded(
            flex: 2,
            child: Text(
              organizationRole.joinedDate != null
                  ? _formatDate(organizationRole.joinedDate!)
                  : 'N/A',
              style: const TextStyle(
                color: AppTheme.textSecondaryColor,
                fontSize: 12,
              ),
            ),
          ),
          Expanded(
            flex: 1,
            child: PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert),
              onSelected: (value) {
                switch (value) {
                  case 'edit':
                    _editUser(user);
                    break;
                  case 'suspend':
                    _suspendUser(user);
                    break;
                  case 'remove':
                    _removeUser(user);
                    break;
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'edit',
                  child: Row(
                    children: [
                      Icon(Icons.edit, size: 18),
                      SizedBox(width: 8),
                      Text('Edit'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'suspend',
                  child: Row(
                    children: [
                      Icon(Icons.pause_circle, color: AppTheme.warningColor, size: 18),
                      SizedBox(width: 8),
                      Text('Suspend', style: TextStyle(color: AppTheme.warningColor)),
                    ],
                  ),
                ),
                const PopupMenuDivider(),
                const PopupMenuItem(
                  value: 'remove',
                  child: Row(
                    children: [
                      Icon(Icons.person_remove, color: AppTheme.errorColor, size: 18),
                      SizedBox(width: 8),
                      Text('Remove', style: TextStyle(color: AppTheme.errorColor)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoleChip(int role) {
    String roleText;
    Color roleColor;

    switch (role) {
      case 0:
        roleText = 'Super Admin';
        roleColor = AppTheme.errorColor;
        break;
      case 1:
        roleText = 'Admin';
        roleColor = AppTheme.warningColor;
        break;
      case 2:
        roleText = 'Manager';
        roleColor = AppTheme.primaryColor;
        break;
      case 3:
        roleText = 'Driver';
        roleColor = AppTheme.successColor;
        break;
      default:
        roleText = 'Unknown';
        roleColor = AppTheme.textSecondaryColor;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: roleColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        roleText,
        style: TextStyle(
          color: roleColor,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    Color color;
    switch (status) {
      case 'active':
        color = AppTheme.successColor;
        break;
      case 'inactive':
        color = AppTheme.textSecondaryColor;
        break;
      case 'pending':
        color = AppTheme.warningColor;
        break;
      default:
        color = AppTheme.textSecondaryColor;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date).inDays;

    if (difference == 0) {
      return 'Today';
    } else if (difference == 1) {
      return 'Yesterday';
    } else if (difference < 7) {
      return '$difference days ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  void _editUser(User user) {
    // TODO: Navigate to edit user form
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Editing ${user.name}'),
        backgroundColor: AppTheme.primaryColor,
      ),
    );
  }

  void _suspendUser(User user) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surfaceColor,
        title: const Text('Suspend User'),
        content: Text(
          'Are you sure you want to suspend ${user.name}? They will not be able to access the organization.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              // TODO: Implement suspend functionality
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('${user.name} has been suspended'),
                  backgroundColor: AppTheme.warningColor,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.warningColor,
            ),
            child: const Text('Suspend'),
          ),
        ],
      ),
    );
  }

  void _removeUser(User user) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surfaceColor,
        title: const Text('Remove User'),
        content: Text(
          'Are you sure you want to remove ${user.name} from this organization?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              // TODO: Implement remove functionality
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('${user.name} has been removed'),
                  backgroundColor: AppTheme.errorColor,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.errorColor,
            ),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }
}
