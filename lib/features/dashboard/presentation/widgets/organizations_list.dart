import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/repositories/organization_repository.dart';
import '../../../../core/models/organization.dart';
import '../../../../core/widgets/error_widget.dart';
import '../../../../core/widgets/custom_snackbar.dart';
import '../../../organization/bloc/organization_bloc.dart';
import '../../../organization/presentation/widgets/edit_organization_form.dart';
import '../../../user/presentation/pages/user_management_page.dart';

class OrganizationsList extends StatefulWidget {
  final bool showRecentOnly;

  const OrganizationsList({
    super.key,
    this.showRecentOnly = false,
  });

  @override
  State<OrganizationsList> createState() => _OrganizationsListState();
}

class _OrganizationsListState extends State<OrganizationsList> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _statusFilter = 'all';

  @override
  void initState() {
    super.initState();
    _loadOrganizations();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _loadOrganizations() {
    context.read<OrganizationBloc>().add(
      LoadOrganizations(
        searchQuery: _searchQuery.isNotEmpty ? _searchQuery : null,
        statusFilter: _statusFilter != 'all' ? _statusFilter : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      shadowColor: Colors.black.withOpacity(0.1),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: AppTheme.cardGradient,
        ),
        child: Column(
          children: [
            _buildHeader(),
            _buildSearchAndFilter(),
            const SizedBox(height: 16),
            Expanded(
              child: _buildOrganizationsTable(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Text(
            widget.showRecentOnly ? 'Recent Organizations' : 'All Organizations',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimaryColor,
            ),
          ),
          const Spacer(),
          if (!widget.showRecentOnly) ...[
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () {
                // TODO: Implement refresh
              },
            ),
            IconButton(
              icon: const Icon(Icons.download),
              onPressed: () {
                // TODO: Implement export
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSearchAndFilter() {
    if (widget.showRecentOnly) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: TextField(
              controller: _searchController,
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
                _loadOrganizations();
              },
              decoration: InputDecoration(
                hintText: 'Search organizations...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _searchQuery = '';
                          });
                        },
                      )
                    : null,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: DropdownButtonFormField<String>(
              value: _statusFilter,
              decoration: const InputDecoration(
                labelText: 'Status',
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
              items: const [
                DropdownMenuItem(value: 'all', child: Text('All Status')),
                DropdownMenuItem(value: 'active', child: Text('Active')),
                DropdownMenuItem(value: 'inactive', child: Text('Inactive')),
                DropdownMenuItem(value: 'suspended', child: Text('Suspended')),
              ],
              onChanged: (value) {
                setState(() {
                  _statusFilter = value ?? 'all';
                });
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrganizationsTable() {
    return BlocBuilder<OrganizationBloc, OrganizationState>(
      builder: (context, state) {
        if (state is OrganizationLoading) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(32.0),
              child: CircularProgressIndicator(),
            ),
          );
        }

        if (state is OrganizationsLoaded) {
          if (state.organizations.isEmpty) {
            return EmptyStateWidget(
              title: 'No organizations found',
              message: 'Create your first organization to get started',
              icon: Icons.business_outlined,
              actionLabel: 'Add Organization',
              onAction: () {
                // TODO: Navigate to add organization page
              },
            );
          }

          return Column(
            children: [
              _buildTableHeader(),
              Expanded(
                child: ListView.builder(
                  itemCount: state.organizations.length,
                  itemBuilder: (context, index) {
                    return _buildOrganizationRow(state.organizations[index]);
                  },
                ),
              ),
            ],
          );
        }

        if (state is OrganizationFailure) {
          return CustomErrorWidget(
            message: state.message,
            onRetry: _loadOrganizations,
          );
        }

        return const SizedBox.shrink();
      },
    );
  }

  Widget _buildTableHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor.withOpacity(0.5),
        border: const Border(
          bottom: BorderSide(color: AppTheme.borderColor, width: 1),
        ),
      ),
      child: const Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              'Organization',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimaryColor,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              'Email',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimaryColor,
              ),
            ),
          ),
          Expanded(
            child: Text(
              'Status',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimaryColor,
              ),
            ),
          ),
          Expanded(
            child: Text(
              'Users',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimaryColor,
              ),
            ),
          ),
          Expanded(
            child: Text(
              'Created',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimaryColor,
              ),
            ),
          ),
          SizedBox(width: 40), // Actions column
        ],
      ),
    );
  }

  Widget _buildOrganizationRow(Organization organization) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AppTheme.borderColor, width: 0.5),
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
                  backgroundImage: organization.orgLogoUrl != null
                      ? NetworkImage(organization.orgLogoUrl!)
                      : null,
                  child: organization.orgLogoUrl == null
                      ? Text(
                          organization.orgName[0].toUpperCase(),
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
                        organization.orgName,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimaryColor,
                        ),
                      ),
                      Text(
                        organization.gstNo,
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
            child: Text(
              organization.email,
              style: const TextStyle(
                color: AppTheme.textPrimaryColor,
              ),
            ),
          ),
          Expanded(
            child: _buildStatusChip(organization.status),
          ),
          Expanded(
            child: Text(
              '${organization.metadata.totalUsers}',
              style: const TextStyle(
                color: AppTheme.textPrimaryColor,
              ),
            ),
          ),
          Expanded(
            child: Text(
              _formatDate(organization.createdDate),
              style: const TextStyle(
                color: AppTheme.textPrimaryColor,
              ),
            ),
          ),
          SizedBox(
            width: 40,
            child: PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert),
              onSelected: (value) {
                switch (value) {
                  case 'view':
                    _viewOrganization(organization);
                    break;
                  case 'edit':
                    _editOrganization(organization);
                    break;
                  case 'users':
                    _manageUsers(organization);
                    break;
                  case 'suspend':
                    _suspendOrganization(organization);
                    break;
                  case 'delete':
                    _deleteOrganization(organization);
                    break;
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'view',
                  child: Row(
                    children: [
                      Icon(Icons.visibility, size: 18),
                      SizedBox(width: 8),
                      Text('View'),
                    ],
                  ),
                ),
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
                  value: 'users',
                  child: Row(
                    children: [
                      Icon(Icons.people, size: 18),
                      SizedBox(width: 8),
                      Text('Manage Users'),
                    ],
                  ),
                ),
                const PopupMenuDivider(),
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
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    Color color;
    switch (status.toLowerCase()) {
      case 'active':
        color = AppTheme.successColor;
        break;
      case 'inactive':
        color = AppTheme.textSecondaryColor;
        break;
      case 'suspended':
        color = AppTheme.errorColor;
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

  void _viewOrganization(Organization organization) {
    // TODO: Navigate to organization details page
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Viewing ${organization.orgName}'),
        backgroundColor: AppTheme.primaryColor,
      ),
    );
  }

  void _editOrganization(Organization organization) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => BlocProvider.value(
          value: context.read<OrganizationBloc>(),
          child: Scaffold(
            backgroundColor: AppTheme.backgroundColor,
            appBar: AppBar(
              backgroundColor: AppTheme.surfaceColor,
              foregroundColor: AppTheme.textPrimaryColor,
              title: Text('Edit ${organization.orgName}'),
              elevation: 0,
            ),
            body: EditOrganizationForm(organization: organization),
          ),
        ),
      ),
    );
  }

  void _manageUsers(Organization organization) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => Scaffold(
          backgroundColor: AppTheme.backgroundColor,
          body: UserManagementPage(organization: organization),
        ),
      ),
    );
  }

  void _suspendOrganization(Organization organization) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surfaceColor,
        title: const Text('Suspend Organization'),
        content: Text(
          'Are you sure you want to suspend ${organization.orgName}? This will prevent users from accessing the organization.',
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
                  content: Text('${organization.orgName} has been suspended'),
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

  void _deleteOrganization(Organization organization) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surfaceColor,
        title: const Text('Delete Organization'),
        content: Text(
          'Are you sure you want to delete ${organization.orgName}? This action cannot be undone and will remove all associated data.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              context.read<OrganizationBloc>().add(
                DeleteOrganization(orgId: organization.orgId),
              );
              Navigator.of(context).pop();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.errorColor,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
