import 'package:core_bloc/core_bloc.dart';
import 'package:core_ui/core_ui.dart';
import 'package:dash_web/data/repositories/job_roles_repository.dart';
import 'package:dash_web/domain/entities/organization_job_role.dart';
import 'package:dash_web/domain/entities/app_access_role.dart';
import 'package:dash_web/domain/entities/wage_type.dart';
import 'package:dash_web/presentation/blocs/job_roles/job_roles_cubit.dart';
import 'package:dash_web/presentation/blocs/org_context/org_context_cubit.dart';
import 'package:dash_web/presentation/widgets/page_workspace_layout.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:go_router/go_router.dart';

class RolesPage extends StatelessWidget {
  const RolesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final orgState = context.watch<OrganizationContextCubit>().state;
    final orgId = orgState.organization?.id;
    
    if (orgId == null) {
      return const Scaffold(
        body: Center(child: Text('No organization selected')),
      );
    }

    return BlocProvider(
      create: (context) => JobRolesCubit(
        repository: context.read<JobRolesRepository>(),
        orgId: orgId,
      ),
      child: BlocListener<JobRolesCubit, JobRolesState>(
        listener: (context, state) {
          if (state.status == ViewStatus.failure && state.message != null) {
            DashSnackbar.show(context, message: state.message!, isError: true);
          }
        },
        child: BlocBuilder<JobRolesCubit, JobRolesState>(
          builder: (context, jobRolesState) {
            final appAccessRole = orgState.appAccessRole;
            final visibleSections = appAccessRole != null
                ? _computeVisibleSections(appAccessRole)
                : const [0, 1, 2, 3, 4];
            
            return PageWorkspaceLayout(
              title: 'Job Roles',
              currentIndex: 4,
              onNavTap: (value) => context.go('/home?section=$value'),
              onBack: () => context.go('/home'),
              allowedSections: visibleSections,
              child: const RolesPageContent(),
            );
          },
        ),
      ),
    );
  }

  List<int> _computeVisibleSections(AppAccessRole? appAccessRole) {
    if (appAccessRole == null) return const [0, 1, 2, 3, 4];
    final visible = <int>[0];
    if (appAccessRole.canAccessSection('pendingOrders')) visible.add(1);
    if (appAccessRole.canAccessSection('scheduleOrders')) visible.add(2);
    if (appAccessRole.canAccessSection('ordersMap')) visible.add(3);
    if (appAccessRole.canAccessSection('analyticsDashboard')) visible.add(4);
    return visible;
  }
}

// Content widget for sidebar use
class RolesPageContent extends StatelessWidget {
  const RolesPageContent({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocListener<JobRolesCubit, JobRolesState>(
      listener: (context, state) {
        if (state.status == ViewStatus.failure && state.message != null) {
          DashSnackbar.show(context, message: state.message!, isError: true);
        }
      },
      child: BlocBuilder<JobRolesCubit, JobRolesState>(
        builder: (context, rolesState) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Add New Role Button - Matching Android style
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AuthColors.primary, AuthColors.primaryVariant],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: AuthColors.primary.withValues(alpha: 0.4),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => _openRoleDialog(context, jobRole: null),
                    borderRadius: BorderRadius.circular(16),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AuthColors.textMain.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.add,
                              color: AuthColors.textMain,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Text(
                            'Add Job Role',
                            style: TextStyle(
                              color: AuthColors.textMain,
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              BlocBuilder<JobRolesCubit, JobRolesState>(
                builder: (context, state) {
                  if (state.status == ViewStatus.loading) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (state.jobRoles.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.only(top: 40),
                      child: Text(
                        'No job roles yet. Tap "Add Job Role" to create one.',
                        style: TextStyle(
                          color: AuthColors.textSub,
                          fontSize: 16,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    );
                  }
                  return AnimationLimiter(
                    child: ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: state.jobRoles.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final jobRole = state.jobRoles[index];
                        return AnimationConfiguration.staggeredList(
                          position: index,
                          duration: const Duration(milliseconds: 200),
                          child: SlideAnimation(
                            verticalOffset: 50.0,
                            child: FadeInAnimation(
                              curve: Curves.easeOut,
                              child: _RoleDataListItem(
                                jobRole: jobRole,
                                onEdit: () => _openRoleDialog(context, jobRole: jobRole),
                                onDelete: () =>
                                    context.read<JobRolesCubit>().deleteJobRole(jobRole.id),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _openRoleDialog(
    BuildContext context, {
    OrganizationJobRole? jobRole,
  }) async {
    final cubit = context.read<JobRolesCubit>();
    await showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Role Dialog',
      barrierColor: AuthColors.background.withValues(alpha: 0.6),
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, animation, secondaryAnimation) {
        return BlocProvider.value(
          value: cubit,
          child: _RoleDialog(jobRole: jobRole),
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(
          opacity: CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
          ),
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.9, end: 1.0).animate(
              CurvedAnimation(
                parent: animation,
                curve: Curves.easeOutCubic,
              ),
            ),
            child: child,
          ),
        );
      },
    );
  }
}

class _RoleDataListItem extends StatefulWidget {
  const _RoleDataListItem({
    required this.jobRole,
    required this.onEdit,
    required this.onDelete,
  });

  final OrganizationJobRole jobRole;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  State<_RoleDataListItem> createState() => _RoleDataListItemState();
}

class _RoleDataListItemState extends State<_RoleDataListItem>
    with SingleTickerProviderStateMixin {
  bool _isExpanded = false;
  late AnimationController _controller;
  late Animation<double> _rotationAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _rotationAnimation = Tween<double>(begin: 0.0, end: 0.5).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutCubic),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _formatSubtitle() {
    if (widget.jobRole.department != null) {
      return widget.jobRole.department!;
    }
    return 'Role';
  }

  Color _getStatusColor() {
    return AuthColors.primary;
  }

  @override
  Widget build(BuildContext context) {
    final jobRole = widget.jobRole;
    return Container(
      decoration: BoxDecoration(
        color: AuthColors.background,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          DataList(
            title: jobRole.title,
            subtitle: _formatSubtitle(),
            leading: DataListAvatar(
              initial: jobRole.title.isNotEmpty ? jobRole.title[0] : '?',
              radius: 28,
              statusRingColor: _hexToColor(jobRole.colorHex),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                DataListStatusDot(
                  color: _getStatusColor(),
                  size: 8,
                ),
                const SizedBox(width: 12),
                IconButton(
                  icon: const Icon(
                    Icons.edit_outlined,
                    color: AuthColors.textSub,
                    size: 20,
                  ),
                  onPressed: widget.onEdit,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(
                    Icons.delete_outline,
                    color: AuthColors.error,
                    size: 20,
                  ),
                  onPressed: widget.onDelete,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
                const SizedBox(width: 8),
                RotationTransition(
                  turns: _rotationAnimation,
                  child: IconButton(
                    icon: const Icon(
                      Icons.keyboard_arrow_down,
                      color: AuthColors.textSub,
                      size: 24,
                    ),
                    onPressed: () {
                      setState(() {
                        _isExpanded = !_isExpanded;
                        if (_isExpanded) {
                          _controller.forward();
                        } else {
                          _controller.reverse();
                        }
                      });
                    },
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ),
              ],
            ),
            onTap: () {
              setState(() {
                _isExpanded = !_isExpanded;
                if (_isExpanded) {
                  _controller.forward();
                } else {
                  _controller.reverse();
                }
              });
            },
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: AuthColors.background,
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(18),
                  bottomRight: Radius.circular(18),
                ),
              ),
              child: _RoleInfoPanel(jobRole: jobRole),
            ),
            crossFadeState: _isExpanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 350),
            sizeCurve: Curves.easeInOutCubic,
          ),
        ],
      ),
    );
  }
}

class _RoleInfoPanel extends StatelessWidget {
  const _RoleInfoPanel({required this.jobRole});

  final OrganizationJobRole jobRole;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AuthColors.primary.withValues(alpha: 0.15),
            AuthColors.primary.withValues(alpha: 0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AuthColors.primary.withValues(alpha: 0.3),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (jobRole.department != null) ...[
            _buildInfoRow(
              icon: Icons.business,
              label: 'Department',
              value: jobRole.department!,
            ),
            const SizedBox(height: 16),
          ],
          if (jobRole.description != null && jobRole.description!.isNotEmpty) ...[
            _buildInfoRow(
              icon: Icons.description,
              label: 'Description',
              value: jobRole.description!,
            ),
            const SizedBox(height: 16),
          ],
          if (jobRole.defaultWageType != null) ...[
            _buildInfoRow(
              icon: Icons.attach_money,
              label: 'Default Wage Type',
              value: jobRole.defaultWageType!.name,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AuthColors.primary.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: AuthColors.primary, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: AuthColors.textSub,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(
                  color: AuthColors.textMain,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

}

class _RoleDialog extends StatefulWidget {
  const _RoleDialog({this.jobRole});

  final OrganizationJobRole? jobRole;

  @override
  State<_RoleDialog> createState() => _RoleDialogState();
}

class _RoleDialogState extends State<_RoleDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _departmentController;
  late final TextEditingController _descriptionController;
  WageType? _defaultWageType;
  late String _colorHex;
  bool _isSubmitting = false;

  static const _colorOptions = [
    '#6F4BFF',
    '#5AD8A4',
    '#FFC857',
    '#FF6B6B',
    '#4BD6FF',
  ];

  @override
  void initState() {
    super.initState();
    final jobRole = widget.jobRole;
    _titleController = TextEditingController(text: jobRole?.title ?? '');
    _departmentController = TextEditingController(text: jobRole?.department ?? '');
    _descriptionController = TextEditingController(text: jobRole?.description ?? '');
    _defaultWageType = jobRole?.defaultWageType;
    _colorHex = jobRole?.colorHex ?? _colorOptions.first;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _departmentController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.jobRole != null;
    final screenWidth = MediaQuery.of(context).size.width;
    final dialogWidth = (screenWidth * 0.9).clamp(400.0, 600.0);

    return AlertDialog(
      backgroundColor: AuthColors.surface,
      title: Text(
        isEditing ? 'Edit Job Role' : 'Add Job Role',
        style: const TextStyle(color: AuthColors.textMain),
      ),
      content: SizedBox(
        width: dialogWidth,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _titleController,
                  style: const TextStyle(color: AuthColors.textMain),
                  decoration: _inputDecoration('Job Role Title *'),
                  validator: (value) =>
                      (value == null || value.trim().isEmpty)
                          ? 'Enter a job role title'
                          : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _departmentController,
                  style: const TextStyle(color: AuthColors.textMain),
                  decoration: _inputDecoration('Department (optional)'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _descriptionController,
                  style: const TextStyle(color: AuthColors.textMain),
                  decoration: _inputDecoration('Description (optional)'),
                  maxLines: 3,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<WageType?>(
                  initialValue: _defaultWageType,
                  dropdownColor: AuthColors.surface,
                  style: const TextStyle(color: AuthColors.textMain),
                  decoration: _inputDecoration('Default Wage Type (optional)'),
                  hint: const Text('Select default wage type', style: TextStyle(color: AuthColors.textSub)),
                  onChanged: (value) {
                    setState(() => _defaultWageType = value);
                  },
                  items: [
                    const DropdownMenuItem<WageType?>(
                      value: null,
                      child: Text('None'),
                    ),
                    ...WageType.values.map((type) {
                      return DropdownMenuItem<WageType?>(
                        value: type,
                        child: Text(_getWageTypeDisplayName(type)),
                      );
                    }),
                  ],
                ),
                const SizedBox(height: 12),
                _ColorSelector(
                  colors: _colorOptions,
                  selected: _colorHex,
                  onSelected: (value) => setState(() => _colorHex = value),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel', style: TextStyle(color: AuthColors.textSub)),
        ),
        DashButton(
          label: isEditing ? 'Save' : 'Create',
          onPressed: _isSubmitting
              ? null
              : () async {
                  if (!(_formKey.currentState?.validate() ?? false)) return;

                  setState(() => _isSubmitting = true);

                  try {
                    final jobRole = OrganizationJobRole(
                      id: widget.jobRole?.id ??
                          DateTime.now().millisecondsSinceEpoch.toString(),
                      title: _titleController.text.trim(),
                      department: _departmentController.text.trim().isEmpty 
                          ? null 
                          : _departmentController.text.trim(),
                      description: _descriptionController.text.trim().isEmpty
                          ? null
                          : _descriptionController.text.trim(),
                      colorHex: _colorHex,
                      defaultWageType: _defaultWageType,
                    );
                    final cubit = context.read<JobRolesCubit>();
                    if (isEditing) {
                      await cubit.updateJobRole(jobRole);
                    } else {
                      await cubit.createJobRole(jobRole);
                    }
                    if (mounted) {
                      Navigator.of(context).pop();
                    }
                  } catch (e) {
                    if (mounted) {
                      DashSnackbar.show(
                        context,
                        message:
                            'Failed to ${isEditing ? 'update' : 'create'} job role: ${e.toString()}',
                        isError: true,
                      );
                    }
                  } finally {
                    if (mounted) {
                      setState(() => _isSubmitting = false);
                    }
                  }
                },
          isLoading: _isSubmitting,
        ),
      ],
    );
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: AuthColors.surface,
      labelStyle: const TextStyle(color: AuthColors.textSub),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
    );
  }

  String _getWageTypeDisplayName(WageType type) {
    switch (type) {
      case WageType.perMonth:
        return 'Per Month';
      case WageType.perTrip:
        return 'Per Trip';
      case WageType.perBatch:
        return 'Per Batch';
      case WageType.perHour:
        return 'Per Hour';
      case WageType.perKm:
        return 'Per Kilometer';
      case WageType.commission:
        return 'Commission';
      case WageType.hybrid:
        return 'Hybrid';
    }
  }
}

class _ColorSelector extends StatelessWidget {
  const _ColorSelector({
    required this.colors,
    required this.selected,
    required this.onSelected,
  });

  final List<String> colors;
  final String selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Accent Color',
          style: TextStyle(color: Colors.white70),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 12,
          children: colors.map((color) {
            final isActive = color == selected;
            return GestureDetector(
              onTap: () => onSelected(color),
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: _hexToColor(color),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isActive ? Colors.white : Colors.transparent,
                    width: 2,
                  ),
                ),
                child: isActive
                    ? const Icon(Icons.check, color: Colors.white, size: 18)
                    : null,
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

Color _hexToColor(String hex) {
  final buffer = StringBuffer();
  if (hex.length == 6 || hex.length == 7) buffer.write('ff');
  buffer.write(hex.replaceFirst('#', ''));
  return Color(int.parse(buffer.toString(), radix: 16));
}
