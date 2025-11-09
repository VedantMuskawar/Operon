import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/models/organization.dart';
import '../../../../core/models/user.dart';
import '../../../../core/models/organization_role.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/repositories/user_repository.dart';
import '../../../../core/widgets/custom_text_field.dart';
import '../../../../core/widgets/realtime_list_cache_mixin.dart';

class UserList extends StatefulWidget {
  final Organization organization;
  final ValueNotifier<int>? refreshNotifier;

  const UserList({super.key, required this.organization, this.refreshNotifier});

  @override
  State<UserList> createState() => _UserListState();
}

class _UserListState extends RealtimeListCacheState<UserList, User> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _tableScrollController = ScrollController();
  String _searchQuery = '';
  String _roleFilter = 'all';
  String _statusFilter = 'all';
  bool _isLoading = true;
  VoidCallback? _refreshListener;

  @override
  void initState() {
    super.initState();
    _refreshListener = _handleRefresh;
    if (_refreshListener != null) {
      widget.refreshNotifier?.addListener(_refreshListener!);
    }
    _loadUsers();
  }

  @override
  void dispose() {
    if (_refreshListener != null) {
      widget.refreshNotifier?.removeListener(_refreshListener!);
    }
    _tableScrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant UserList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshNotifier != widget.refreshNotifier &&
        _refreshListener != null) {
      oldWidget.refreshNotifier?.removeListener(_refreshListener!);
      widget.refreshNotifier?.addListener(_refreshListener!);
    }
  }

  void _handleRefresh() {
    _loadUsers();
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

      if (!mounted) return;

      applyRealtimeItems(
        users,
        searchQuery: _searchQuery.isNotEmpty ? _searchQuery : null,
      );
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
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
          Expanded(child: _buildUsersTable()),
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
          child: const Icon(Icons.people, color: Colors.white, size: 24),
        ),
        const SizedBox(width: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Organization Users',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
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
          '${realtimeItems.length} users',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: AppTheme.textSecondaryColor,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildSearchAndFilter() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isCompact = constraints.maxWidth < 900;
        final double filterWidth = (constraints.maxWidth / 3)
            .clamp(220.0, 320.0)
            .toDouble();

        final searchField = CustomTextField(
          controller: _searchController,
          hintText: 'Search users...',
          prefixIcon: const Icon(Icons.search, size: 18),
          suffixIcon: _searchQuery.isNotEmpty
              ? const Icon(Icons.close, size: 18)
              : null,
          onSuffixIconTap: _searchQuery.isNotEmpty
              ? () {
                  _searchController.clear();
                  setState(() {
                    _searchQuery = '';
                  });
                  _loadUsers();
                }
              : null,
          variant: CustomTextFieldVariant.search,
          onChanged: (value) {
            setState(() {
              _searchQuery = value;
            });
            _loadUsers();
          },
        );

        final roleFilter = SizedBox(
          width: isCompact ? constraints.maxWidth : filterWidth,
          child: _buildRoleFilter(),
        );

        final statusFilter = SizedBox(
          width: isCompact ? constraints.maxWidth : filterWidth,
          child: _buildStatusFilter(),
        );

        return Container(
          decoration: BoxDecoration(
            color: const Color(0xFF181C1F),
            borderRadius: BorderRadius.circular(AppTheme.radiusXl),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.08),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.18),
                blurRadius: 12,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          padding: const EdgeInsets.all(AppTheme.spacingLg),
          child: isCompact
              ? Wrap(
                  spacing: AppTheme.spacingLg,
                  runSpacing: AppTheme.spacingLg,
                  children: [
                    SizedBox(width: constraints.maxWidth, child: searchField),
                    roleFilter,
                    statusFilter,
                  ],
                )
              : Row(
                  children: [
                    Expanded(child: searchField),
                    const SizedBox(width: AppTheme.spacingLg),
                    roleFilter,
                    const SizedBox(width: AppTheme.spacingLg),
                    statusFilter,
                  ],
                ),
        );
      },
    );
  }

  Widget _buildRoleFilter() {
    return DropdownButtonFormField<String>(
      value: _roleFilter,
      dropdownColor: AppTheme.surfaceColor,
      icon: const Icon(Icons.expand_more, color: AppTheme.textSecondaryColor),
      decoration: InputDecoration(
        labelText: 'Role',
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppTheme.spacingMd,
          vertical: AppTheme.spacingSm,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          borderSide: const BorderSide(color: AppTheme.borderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          borderSide: const BorderSide(color: AppTheme.borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          borderSide: const BorderSide(color: AppTheme.primaryColor),
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
    );
  }

  Widget _buildStatusFilter() {
    return DropdownButtonFormField<String>(
      value: _statusFilter,
      dropdownColor: AppTheme.surfaceColor,
      icon: const Icon(Icons.expand_more, color: AppTheme.textSecondaryColor),
      decoration: InputDecoration(
        labelText: 'Status',
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppTheme.spacingMd,
          vertical: AppTheme.spacingSm,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          borderSide: const BorderSide(color: AppTheme.borderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          borderSide: const BorderSide(color: AppTheme.borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          borderSide: const BorderSide(color: AppTheme.primaryColor),
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
    );
  }

  Widget _buildUsersTable() {
    final users = realtimeItems;
    final bool waitingForFirstLoad = _isLoading && !hasRealtimeData;

    if (waitingForFirstLoad) {
      return Container(
        decoration: _tableContainerDecoration(),
        alignment: Alignment.center,
        child: const Padding(
          padding: EdgeInsets.all(AppTheme.spacing2xl),
          child: CircularProgressIndicator(color: AppTheme.primaryColor),
        ),
      );
    }

    if (users.isEmpty) {
      return Container(
        decoration: _tableContainerDecoration(),
        padding: const EdgeInsets.all(AppTheme.spacing2xl),
        alignment: Alignment.center,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🧑‍🤝‍🧑', style: TextStyle(fontSize: 56)),
            const SizedBox(height: AppTheme.spacingMd),
            Text(
              'No users found',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: AppTheme.textPrimaryColor,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppTheme.spacingSm),
            Text(
              'Add users to this organization to get started',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppTheme.textSecondaryColor,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    final table = Container(
      decoration: _tableContainerDecoration(),
      padding: const EdgeInsets.all(AppTheme.spacingLg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTableSummary(),
          const SizedBox(height: AppTheme.spacingLg),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                const double minTableWidth = 1040;
                final double tableWidth = constraints.maxWidth >= minTableWidth
                    ? constraints.maxWidth
                    : minTableWidth;

                return Scrollbar(
                  controller: _tableScrollController,
                  thumbVisibility: users.length > 8,
                  child: SingleChildScrollView(
                    controller: _tableScrollController,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: SizedBox(
                        width: tableWidth,
                        child: DataTable(
                          headingRowHeight: 56,
                          dataRowMinHeight: 72,
                          dataRowMaxHeight: 88,
                          horizontalMargin: 0,
                          columnSpacing: 24,
                          dividerThickness: 1,
                          headingRowColor: MaterialStateProperty.all(
                            const Color(0xFF1F2937).withValues(alpha: 0.88),
                          ),
                          dataRowColor:
                              MaterialStateProperty.resolveWith<Color?>((
                                states,
                              ) {
                                if (states.contains(MaterialState.hovered)) {
                                  return AppTheme.borderColor.withValues(
                                    alpha: 0.24,
                                  );
                                }
                                if (states.contains(MaterialState.selected)) {
                                  return AppTheme.primaryColor.withValues(
                                    alpha: 0.12,
                                  );
                                }
                                return Colors.transparent;
                              }),
                          columns: [
                            DataColumn(label: _buildColumnLabel('USER')),
                            DataColumn(label: _buildColumnLabel('ROLE')),
                            DataColumn(label: _buildColumnLabel('PHONE')),
                            DataColumn(label: _buildColumnLabel('STATUS')),
                            DataColumn(label: _buildColumnLabel('JOINED')),
                            DataColumn(label: _buildColumnLabel('ACTIONS')),
                          ],
                          rows: users.map((user) {
                            final organizationRole = user.organizations
                                .firstWhere(
                                  (org) =>
                                      org.orgId == widget.organization.orgId,
                                  orElse: () => const OrganizationRole(
                                    orgId: '',
                                    role: 0,
                                    status: 'inactive',
                                    joinedDate: null,
                                    isPrimary: false,
                                    permissions: [],
                                  ),
                                );

                            return DataRow(
                              cells: [
                                DataCell(
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 14,
                                    ),
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.center,
                                      children: [
                                        CircleAvatar(
                                          radius: 22,
                                          backgroundColor: AppTheme.primaryColor
                                              .withValues(alpha: 0.12),
                                          backgroundImage:
                                              user.profilePhotoUrl != null
                                              ? NetworkImage(
                                                  user.profilePhotoUrl!,
                                                )
                                              : null,
                                          child: user.profilePhotoUrl == null
                                              ? Text(
                                                  user.name.isNotEmpty
                                                      ? user.name[0]
                                                            .toUpperCase()
                                                      : '?',
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    color:
                                                        AppTheme.primaryColor,
                                                  ),
                                                )
                                              : null,
                                        ),
                                        const SizedBox(
                                          width: AppTheme.spacingSm,
                                        ),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text(
                                                user.name,
                                                style: const TextStyle(
                                                  color:
                                                      AppTheme.textPrimaryColor,
                                                  fontWeight: FontWeight.w600,
                                                  fontSize: 14,
                                                ),
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                user.email,
                                                style: const TextStyle(
                                                  color: AppTheme
                                                      .textSecondaryColor,
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                DataCell(
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 14,
                                    ),
                                    child: _buildRoleChip(
                                      organizationRole.role,
                                    ),
                                  ),
                                ),
                                DataCell(
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 14,
                                    ),
                                    child: Text(
                                      user.phoneNo.isNotEmpty
                                          ? user.phoneNo
                                          : '—',
                                      style: const TextStyle(
                                        color: AppTheme.textPrimaryColor,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                ),
                                DataCell(
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 14,
                                    ),
                                    child: _buildStatusChip(user.status),
                                  ),
                                ),
                                DataCell(
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 14,
                                    ),
                                    child: Text(
                                      organizationRole.joinedDate != null
                                          ? _formatDate(
                                              organizationRole.joinedDate!,
                                            )
                                          : 'N/A',
                                      style: const TextStyle(
                                        color: AppTheme.textSecondaryColor,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ),
                                DataCell(
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 14,
                                    ),
                                    child: Wrap(
                                      spacing: AppTheme.spacingXs,
                                      runSpacing: AppTheme.spacingXs,
                                      children: [
                                        _buildActionButton(
                                          color: AppTheme.infoColor,
                                          icon: Icons.edit,
                                          tooltip: 'Edit user',
                                          onPressed: () => _editUser(user),
                                        ),
                                        _buildActionButton(
                                          color: AppTheme.warningColor,
                                          icon: Icons.pause_circle,
                                          tooltip: 'Suspend user',
                                          onPressed: () => _suspendUser(user),
                                        ),
                                        _buildActionButton(
                                          color: AppTheme.errorColor,
                                          icon: Icons.delete,
                                          tooltip: 'Remove user',
                                          onPressed: () => _removeUser(user),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );

    if (_isLoading) {
      return withRealtimeBusyOverlay(
        child: table,
        showOverlay: true,
        overlayColor: Colors.black.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(AppTheme.radiusXl),
        progressIndicator: const CircularProgressIndicator(
          color: AppTheme.primaryColor,
        ),
      );
    }

    return table;
  }

  Widget _buildTableSummary() {
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            gradient: AppTheme.primaryGradient,
            borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          ),
          child: const Icon(Icons.groups, color: Colors.white, size: 22),
        ),
        const SizedBox(width: AppTheme.spacingMd),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Team directory',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: AppTheme.textPrimaryColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'All members in ${widget.organization.orgName}',
                style: const TextStyle(
                  color: AppTheme.textSecondaryColor,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppTheme.spacingMd,
            vertical: AppTheme.spacingXs,
          ),
          decoration: BoxDecoration(
            color: AppTheme.primaryColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(AppTheme.radiusLg),
            border: Border.all(
              color: AppTheme.primaryColor.withValues(alpha: 0.3),
            ),
          ),
          child: Text(
            '${realtimeItems.length} users',
            style: const TextStyle(
              color: AppTheme.primaryColor,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ),
      ],
    );
  }

  BoxDecoration _tableContainerDecoration() {
    return BoxDecoration(
      color: const Color(0xFF141618).withValues(alpha: 0.7),
      borderRadius: BorderRadius.circular(AppTheme.radiusXl),
      border: Border.all(color: Colors.white.withValues(alpha: 0.08), width: 1),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.18),
          blurRadius: 28,
          offset: const Offset(0, 16),
        ),
      ],
    );
  }

  Widget _buildColumnLabel(String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Text(
        label,
        style: const TextStyle(
          color: AppTheme.textSecondaryColor,
          fontWeight: FontWeight.w700,
          fontSize: 11,
          letterSpacing: 0.6,
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required Color color,
    required IconData icon,
    required String tooltip,
    required VoidCallback onPressed,
  }) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      color: color,
      style: IconButton.styleFrom(
        backgroundColor: color.withValues(alpha: 0.12),
        padding: const EdgeInsets.all(AppTheme.spacingSm),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        ),
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
