import 'package:core_ui/core_ui.dart' show AuthColors, DashButton, DashButtonVariant, DashCard, DashSnackbar;
import 'package:dash_web/data/repositories/employees_repository.dart';
import 'package:dash_web/domain/entities/organization_employee.dart';
import 'package:dash_web/domain/entities/wage_type.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Side panel widget for displaying employee details
/// Slides in from the right with smooth animations
class EmployeeDetailPanel extends StatefulWidget {
  const EmployeeDetailPanel({
    super.key,
    required this.employee,
    required this.onClose,
    this.onEmployeeChanged,
    this.onEdit,
  });

  final OrganizationEmployee employee;
  final VoidCallback onClose;
  final ValueChanged<OrganizationEmployee>? onEmployeeChanged;
  final VoidCallback? onEdit;

  @override
  State<EmployeeDetailPanel> createState() => _EmployeeDetailPanelState();
}

class _EmployeeDetailPanelState extends State<EmployeeDetailPanel>
    with SingleTickerProviderStateMixin {
  int _selectedTabIndex = 0;
  late AnimationController _animationController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    // Animation setup
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(1.0, 0.0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    ));
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    ));

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _closePanel() {
    _animationController.reverse().then((_) {
      widget.onClose();
    });
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => _DeleteEmployeeDialog(
        employeeName: widget.employee.name,
      ),
    );

    if (confirmed == true && mounted) {
      try {
        final repository = context.read<EmployeesRepository>();
        await repository.deleteEmployee(widget.employee.id);
        if (!mounted) return;
        DashSnackbar.show(context, message: 'Employee deleted.', isError: false);
        _closePanel();
      } catch (error) {
        if (!mounted) return;
        DashSnackbar.show(context, message: 'Unable to delete employee: $error', isError: true);
      }
    }
  }

  void _editEmployee() {
    if (widget.onEdit != null) {
      widget.onEdit!();
      _closePanel();
    }
  }

  Color _getRoleColor(String? roleTitle) {
    if (roleTitle == null || roleTitle.isEmpty) return AuthColors.primary;
    final hash = roleTitle.hashCode;
    final colors = [
      AuthColors.primary,
      AuthColors.successVariant,
      AuthColors.warning,
      AuthColors.info,
      AuthColors.error,
    ];
    return colors[hash.abs() % colors.length];
  }

  String _getInitials(String name) {
    final parts = name.split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.length >= 2 ? name.substring(0, 2).toUpperCase() : name.toUpperCase();
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

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final isMobile = screenWidth < 768;
    final panelWidth = isMobile ? screenWidth : (screenWidth > 1200 ? 800.0 : 700.0);
    final roleColor = _getRoleColor(widget.employee.primaryJobRoleTitle);
    final balanceDifference = widget.employee.currentBalance - widget.employee.openingBalance;
    final isPositive = balanceDifference >= 0;

    return SizedBox(
      width: screenWidth,
      height: screenHeight,
      child: Stack(
        children: [
        // Overlay background
        Positioned.fill(
          child: GestureDetector(
            onTap: _closePanel,
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: Container(
                color: AuthColors.background.withOpacity(0.5),
              ),
            ),
          ),
        ),

        // Panel
        Positioned(
          right: 0,
          top: 0,
          bottom: 0,
          child: SlideTransition(
            position: _slideAnimation,
            child: Container(
              width: panelWidth,
              decoration: BoxDecoration(
                color: AuthColors.background,
                boxShadow: [
                  BoxShadow(
                    color: AuthColors.background.withOpacity(0.3),
                    blurRadius: 20,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Header
                  _PanelHeader(
                    employee: widget.employee,
                    roleColor: roleColor,
                    onClose: _closePanel,
                    onEdit: _editEmployee,
                    onDelete: _confirmDelete,
                    getInitials: _getInitials,
                  ),

                  // Tabs
                  Container(
                    decoration: BoxDecoration(
                      color: AuthColors.surface,
                      border: Border(
                        bottom: BorderSide(
                          color: AuthColors.textMainWithOpacity(0.1),
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: _TabButton(
                            label: 'Overview',
                            isSelected: _selectedTabIndex == 0,
                            onTap: () => setState(() => _selectedTabIndex = 0),
                          ),
                        ),
                        Expanded(
                          child: _TabButton(
                            label: 'Transactions',
                            isSelected: _selectedTabIndex == 1,
                            onTap: () => setState(() => _selectedTabIndex = 1),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Content
                  Expanded(
                    child: IndexedStack(
                      index: _selectedTabIndex,
                      children: [
                        _OverviewSection(
                          employee: widget.employee,
                          roleColor: roleColor,
                          balanceDifference: balanceDifference,
                          isPositive: isPositive,
                          getWageTypeDisplayName: _getWageTypeDisplayName,
                        ),
                        _TransactionsSection(employeeId: widget.employee.id),
                      ],
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

class _PanelHeader extends StatelessWidget {
  const _PanelHeader({
    required this.employee,
    required this.roleColor,
    required this.onClose,
    required this.onEdit,
    required this.onDelete,
    required this.getInitials,
  });

  final OrganizationEmployee employee;
  final Color roleColor;
  final VoidCallback onClose;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final String Function(String) getInitials;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            roleColor.withOpacity(0.3),
            AuthColors.surface,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border(
          bottom: BorderSide(
            color: AuthColors.textMainWithOpacity(0.1),
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.close, color: AuthColors.textSub),
                onPressed: onClose,
                tooltip: 'Close',
              ),
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      roleColor,
                      roleColor.withOpacity(0.7),
                    ],
                  ),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    getInitials(employee.name),
                    style: const TextStyle(
                      color: AuthColors.textMain,
                      fontWeight: FontWeight.w700,
                      fontSize: 18,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      employee.name,
                      style: const TextStyle(
                        color: AuthColors.textMain,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    if (employee.primaryJobRoleTitle.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: roleColor.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: roleColor.withOpacity(0.3),
                          ),
                        ),
                        child: Text(
                          employee.primaryJobRoleTitle,
                          style: TextStyle(
                            color: roleColor,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.edit, color: AuthColors.textSub),
                onPressed: onEdit,
                tooltip: 'Edit',
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, color: AuthColors.textSub),
                onPressed: onDelete,
                tooltip: 'Delete',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  const _TabButton({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: isSelected
                  ? AuthColors.primary
                  : AuthColors.background,
              width: 2,
            ),
          ),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: isSelected ? AuthColors.textMain : AuthColors.textSub,
            fontSize: 14,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

class _OverviewSection extends StatelessWidget {
  const _OverviewSection({
    required this.employee,
    required this.roleColor,
    required this.balanceDifference,
    required this.isPositive,
    required this.getWageTypeDisplayName,
  });

  final OrganizationEmployee employee;
  final Color roleColor;
  final double balanceDifference;
  final bool isPositive;
  final String Function(WageType) getWageTypeDisplayName;

  String _formatCurrency(double amount) {
    return '₹${amount.toStringAsFixed(2).replaceAllMapped(
          RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]},',
        )}';
  }

  @override
  Widget build(BuildContext context) {
    final percentChange = employee.openingBalance != 0
        ? (balanceDifference / employee.openingBalance * 100)
        : 0.0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Current Balance Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isPositive
                    ? [
                        AuthColors.success.withOpacity(0.2),
                        AuthColors.success.withOpacity(0.05),
                      ]
                    : [
                        AuthColors.error.withOpacity(0.2),
                        AuthColors.error.withOpacity(0.05),
                      ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: (isPositive ? AuthColors.success : AuthColors.error)
                    .withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Current Balance',
                  style: TextStyle(
                    color: AuthColors.textSub,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _formatCurrency(employee.currentBalance),
                  style: const TextStyle(
                    color: AuthColors.textMain,
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      isPositive ? Icons.trending_up : Icons.trending_down,
                      size: 16,
                      color: isPositive ? AuthColors.success : AuthColors.error,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${isPositive ? '+' : ''}${_formatCurrency(balanceDifference.abs())} from opening',
                      style: TextStyle(
                        color: isPositive ? AuthColors.success : AuthColors.error,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (employee.openingBalance != 0) ...[
                      const SizedBox(width: 8),
                      Text(
                        '(${isPositive ? '+' : ''}${percentChange.abs().toStringAsFixed(1)}%)',
                        style: TextStyle(
                          color: isPositive ? AuthColors.success : AuthColors.error,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Financial Summary Cards
          Row(
            children: [
              Expanded(
                child: _SummaryCard(
                  label: 'Opening Balance',
                  value: _formatCurrency(employee.openingBalance),
                  color: AuthColors.info,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _SummaryCard(
                  label: 'Net Change',
                  value: '${isPositive ? '+' : ''}${_formatCurrency(balanceDifference.abs())}',
                  color: isPositive ? AuthColors.success : AuthColors.error,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Wage Information
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AuthColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AuthColors.textMainWithOpacity(0.1),
                width: 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Wage Information',
                  style: TextStyle(
                    color: AuthColors.textMain,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(
                      Icons.account_balance_wallet_outlined,
                      size: 20,
                      color: AuthColors.textMainWithOpacity(0.7),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            getWageTypeDisplayName(employee.wage.type),
                            style: const TextStyle(
                              color: AuthColors.textSub,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            employee.wage.baseAmount != null || employee.wage.rate != null
                                ? '₹${(employee.wage.baseAmount ?? employee.wage.rate ?? 0).toStringAsFixed(2)}'
                                : 'Not set',
                            style: const TextStyle(
                              color: AuthColors.textMain,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Job Roles
          if (employee.jobRoles.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AuthColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AuthColors.textMainWithOpacity(0.1),
                  width: 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Job Roles',
                    style: TextStyle(
                      color: AuthColors.textMain,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: employee.jobRoles.values.map((jobRole) {
                      final isPrimary = jobRole.isPrimary;
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: isPrimary
                              ? roleColor.withOpacity(0.2)
                              : AuthColors.textMainWithOpacity(0.08),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isPrimary
                                ? roleColor.withOpacity(0.3)
                                : AuthColors.textMainWithOpacity(0.1),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              jobRole.jobRoleTitle,
                              style: TextStyle(
                                color: isPrimary ? roleColor : AuthColors.textSub,
                                fontSize: 12,
                                fontWeight: isPrimary ? FontWeight.w600 : FontWeight.w500,
                              ),
                            ),
                            if (isPrimary) ...[
                              const SizedBox(width: 6),
                              Icon(
                                Icons.star,
                                size: 14,
                                color: roleColor,
                              ),
                            ],
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return DashCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

class _TransactionsSection extends StatelessWidget {
  const _TransactionsSection({required this.employeeId});

  final String employeeId;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.receipt_long_outlined,
              size: 64,
              color: AuthColors.textMainWithOpacity(0.3),
            ),
            const SizedBox(height: 16),
            const Text(
              'Transactions',
              style: TextStyle(
                color: AuthColors.textMain,
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Transaction history will be available here',
              style: TextStyle(
                color: AuthColors.textMainWithOpacity(0.6),
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _DeleteEmployeeDialog extends StatelessWidget {
  const _DeleteEmployeeDialog({required this.employeeName});

  final String employeeName;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AuthColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(28),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Delete employee',
              style: TextStyle(
                color: AuthColors.textMain,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'This will permanently remove $employeeName and all related data. This action cannot be undone.',
              style: const TextStyle(
                color: AuthColors.textSub,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: DashButton(
                label: 'Delete employee',
                onPressed: () => Navigator.pop(context, true),
                isDestructive: true,
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: DashButton(
                label: 'Cancel',
                onPressed: () => Navigator.pop(context, false),
                variant: DashButtonVariant.text,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

