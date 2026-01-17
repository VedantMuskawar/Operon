import 'package:core_bloc/core_bloc.dart';
import 'package:core_models/core_models.dart';
import 'package:dash_mobile/presentation/blocs/roles/roles_cubit.dart';
import 'package:core_ui/core_ui.dart';
import 'package:dash_mobile/presentation/widgets/modern_page_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class RolesPage extends StatelessWidget {
  const RolesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocListener<RolesCubit, RolesState>(
      listener: (context, state) {
        if (state.status == ViewStatus.failure && state.message != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.message!)),
          );
        }
      },
      child: Scaffold(
        backgroundColor: AuthColors.background,
        appBar: const ModernPageHeader(
          title: 'Roles',
        ),
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [AuthColors.primary, AuthColors.primaryVariant],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: AuthColors.primary.withOpacity(0.4),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => _openRoleDialog(context),
                  borderRadius: BorderRadius.circular(16),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AuthColors.textMain.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            Icons.add,
                            color: AuthColors.textMain,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Add New Role',
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
            BlocBuilder<RolesCubit, RolesState>(
              builder: (context, state) {
                if (state.status == ViewStatus.loading) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (state.roles.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 40),
                    child: Text(
                      'No roles yet. Tap “Add Role” to create one.',
                      style: TextStyle(
                        color: AuthColors.textSub,
                        fontSize: 16,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  );
                }
                return ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: state.roles.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final role = state.roles[index];
                    return _RoleDataListItem(
                      role: role,
                      onEdit: () => _openRoleDialog(context, role: role),
                      onDelete: () =>
                          context.read<RolesCubit>().deleteRole(role.id),
                    );
                  },
                );
              },
            ),
          ],
                ),
                      ),
                    ),
            FloatingNavBar(
              items: const [
                NavBarItem(
                  icon: Icons.home_rounded,
                  label: 'Home',
                  heroTag: 'nav_home',
                ),
                NavBarItem(
                  icon: Icons.pending_actions_rounded,
                  label: 'Pending',
                  heroTag: 'nav_pending',
                ),
                NavBarItem(
                  icon: Icons.schedule_rounded,
                  label: 'Schedule',
                  heroTag: 'nav_schedule',
                ),
                NavBarItem(
                  icon: Icons.map_rounded,
                  label: 'Map',
                  heroTag: 'nav_map',
                ),
                NavBarItem(
                  icon: Icons.dashboard_rounded,
                  label: 'Analytics',
                  heroTag: 'nav_analytics',
                ),
              ],
              currentIndex: -1,
              onItemTapped: (index) {
                context.go('/home', extra: index);
              },
            ),
          ],
        ),
      ),
      ),
    );
  }

  Future<void> _openRoleDialog(
    BuildContext context, {
    OrganizationRole? role,
  }) async {
    final cubit = context.read<RolesCubit>();
    await showDialog(
      context: context,
      builder: (dialogContext) => BlocProvider.value(
        value: cubit,
        child: _RoleDialog(role: role),
      ),
    );
  }
}

class _RoleDataListItem extends StatefulWidget {
  const _RoleDataListItem({
    required this.role,
    required this.onEdit,
    required this.onDelete,
  });

  final OrganizationRole role;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  State<_RoleDataListItem> createState() => _RoleDataListItemState();
}

class _RoleDataListItemState extends State<_RoleDataListItem> with SingleTickerProviderStateMixin {
  bool _isExpanded = false;
  late AnimationController _controller;
  late Animation<double> _rotationAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _rotationAnimation = Tween<double>(begin: 0.0, end: 0.5).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _formatSubtitle() {
    final parts = <String>[];
    if (widget.role.isAdmin) {
      parts.add('Admin');
    }
    parts.add(widget.role.salaryType.name);
    return parts.join(' • ');
  }

  Color _getStatusColor() {
    return widget.role.isAdmin ? AuthColors.success : AuthColors.primary;
  }

  @override
  Widget build(BuildContext context) {
    final role = widget.role;
    return Container(
      decoration: BoxDecoration(
        color: AuthColors.background,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          DataList(
            title: role.title,
            subtitle: _formatSubtitle(),
            leading: DataListAvatar(
              initial: role.title.isNotEmpty ? role.title[0] : '?',
              radius: 28,
              statusRingColor: _hexToColor(role.colorHex),
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
                  icon: Icon(
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
                  icon: Icon(
                    Icons.delete_outline,
                    color: AuthColors.textSub,
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
              decoration: BoxDecoration(
                color: AuthColors.background,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(18),
                  bottomRight: Radius.circular(18),
                ),
              ),
              child: _RoleInfoPanel(role: role),
            ),
            crossFadeState: _isExpanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 300),
          ),
        ],
      ),
    );
  }
}

class _RoleInfoPanel extends StatelessWidget {
  const _RoleInfoPanel({required this.role});

  final OrganizationRole role;

  @override
  Widget build(BuildContext context) {
    if (role.isAdmin) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AuthColors.success.withOpacity(0.15),
              AuthColors.success.withOpacity(0.05),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AuthColors.success.withOpacity(0.3),
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AuthColors.success.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.verified,
                color: AuthColors.success,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Full Access Granted',
                    style: TextStyle(
                      color: AuthColors.textMain,
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Admins have unrestricted access to all sections and pages.',
                    style: TextStyle(
                      color: AuthColors.textSub,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AuthColors.primary.withOpacity(0.15),
            AuthColors.primary.withOpacity(0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AuthColors.primary.withOpacity(0.3),
          width: 1.5,
        ),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AuthColors.primary.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.security,
              color: AuthColors.primary,
              size: 24,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Permissions Managed in Access Control',
            style: TextStyle(
              color: AuthColors.textMain,
              fontWeight: FontWeight.w700,
              fontSize: 16,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Manage this role\'s permissions from the Access Control page in Settings.',
            style: TextStyle(
              color: AuthColors.textMainWithOpacity(0.7),
              fontSize: 13,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => context.go('/access-control'),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AuthColors.primary, AuthColors.primaryVariant],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.arrow_forward, color: AuthColors.textMain, size: 18),
                    SizedBox(width: 8),
                    Text(
                      'Go to Access Control',
                      style: TextStyle(
                        color: AuthColors.textMain,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RoleDialog extends StatefulWidget {
  const _RoleDialog({this.role});

  final OrganizationRole? role;

  @override
  State<_RoleDialog> createState() => _RoleDialogState();
}

class _RoleDialogState extends State<_RoleDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  SalaryType _salaryType = SalaryType.salaryMonthly;
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
    final role = widget.role;
    _titleController = TextEditingController(text: role?.title ?? '');
    _salaryType = role?.salaryType ?? SalaryType.salaryMonthly;
    _colorHex = role?.colorHex ?? _colorOptions.first;

  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.role != null;
    final screenWidth = MediaQuery.of(context).size.width;
    final dialogWidth = (screenWidth * 0.9).clamp(400.0, 600.0);
    
    return AlertDialog(
      backgroundColor: AuthColors.surface,
      title: Text(
        isEditing ? 'Edit Role' : 'Add Role',
        style: TextStyle(color: AuthColors.textMain),
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
                style: TextStyle(color: AuthColors.textMain),
                decoration: _inputDecoration('Role title'),
                enabled: !isEditing,
                validator: (value) =>
                    (value == null || value.trim().isEmpty)
                        ? 'Enter a role title'
                        : null,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<SalaryType>(
                initialValue: _salaryType,
                dropdownColor: AuthColors.surface,
                style: TextStyle(color: AuthColors.textMain),
                decoration: _inputDecoration('Salary type'),
                onChanged: (value) {
                  if (value != null) setState(() => _salaryType = value);
                },
                items: const [
                  DropdownMenuItem(
                    value: SalaryType.salaryMonthly,
                    child: Text('Salary Monthly'),
                  ),
                  DropdownMenuItem(
                    value: SalaryType.wages,
                    child: Text('Wages'),
                  ),
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
          child: Text('Cancel', style: TextStyle(color: AuthColors.textSub)),
        ),
        DashButton(
          label: isEditing ? 'Save' : 'Create',
          onPressed: _isSubmitting
              ? null
              : () async {
                  if (!(_formKey.currentState?.validate() ?? false)) return;

                  setState(() => _isSubmitting = true);

                  try {
                    final role = OrganizationRole(
                      id: widget.role?.id ??
                          DateTime.now().millisecondsSinceEpoch.toString(),
                      title: _titleController.text.trim(),
                      salaryType: _salaryType,
                      colorHex: _colorHex,
                      permissions: widget.role?.permissions ?? const RolePermissions(),
                    );
                    final cubit = context.read<RolesCubit>();
                    if (isEditing) {
                      await cubit.updateRole(role);
                    } else {
                      await cubit.createRole(role);
                    }
                    if (mounted) {
                      Navigator.of(context).pop();
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Failed to ${isEditing ? 'update' : 'create'} role: ${e.toString()}',
                          ),
                        ),
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
      labelStyle: TextStyle(color: AuthColors.textSub),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
    );
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
          style: TextStyle(color: AuthColors.textSub),
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
                    color: isActive ? AuthColors.textMain : Colors.transparent,
                    width: 2,
                  ),
                ),
                child: isActive
                    ? Icon(Icons.check, color: AuthColors.textMain, size: 18)
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

