import 'package:core_ui/core_ui.dart';
import 'package:dash_web/domain/entities/organization_employee.dart';
import 'package:flutter/material.dart';

class TripWageEmployeeSelectionDialog extends StatefulWidget {
  const TripWageEmployeeSelectionDialog({
    super.key,
    required this.employees,
    required this.totalWage,
    this.loadingEmployeeIds,
    this.unloadingEmployeeIds,
    this.sameEmployees,
  });

  final List<OrganizationEmployee> employees;
  final double totalWage;
  final List<String>? loadingEmployeeIds;
  final List<String>? unloadingEmployeeIds;
  final bool? sameEmployees;

  @override
  State<TripWageEmployeeSelectionDialog> createState() => _TripWageEmployeeSelectionDialogState();
}

class _TripWageEmployeeSelectionDialogState extends State<TripWageEmployeeSelectionDialog> {
  late bool _sameEmployees;
  late Set<String> _loadingEmployeeIds;
  late Set<String> _unloadingEmployeeIds;

  double get _loadingWage => widget.totalWage * 0.5;
  double get _unloadingWage => widget.totalWage * 0.5;

  double get _loadingWagePerEmployee {
    if (_loadingEmployeeIds.isEmpty) return 0.0;
    return _loadingWage / _loadingEmployeeIds.length;
  }

  double get _unloadingWagePerEmployee {
    if (_unloadingEmployeeIds.isEmpty) return 0.0;
    return _unloadingWage / _unloadingEmployeeIds.length;
  }

  double get _totalWagePerEmployee {
    if (_sameEmployees && _loadingEmployeeIds.isNotEmpty) {
      return _loadingWagePerEmployee + _unloadingWagePerEmployee;
    }
    return 0.0;
  }

  @override
  void initState() {
    super.initState();
    _sameEmployees = widget.sameEmployees ?? false;
    _loadingEmployeeIds = Set.from(widget.loadingEmployeeIds ?? []);
    _unloadingEmployeeIds = Set.from(widget.unloadingEmployeeIds ?? []);
    
    // If same employees is true, sync the lists
    if (_sameEmployees) {
      _unloadingEmployeeIds = Set.from(_loadingEmployeeIds);
    }
  }

  void _toggleSameEmployees(bool value) {
    setState(() {
      _sameEmployees = value;
      if (value) {
        // If same employees is checked, use loading employees for unloading too
        _unloadingEmployeeIds = Set.from(_loadingEmployeeIds);
      }
    });
  }

  void _toggleLoadingEmployee(String employeeId, bool selected) {
    setState(() {
      if (selected) {
        _loadingEmployeeIds.add(employeeId);
      } else {
        _loadingEmployeeIds.remove(employeeId);
      }
      
      // If same employees is checked, sync unloading list
      if (_sameEmployees) {
        if (selected) {
          _unloadingEmployeeIds.add(employeeId);
        } else {
          _unloadingEmployeeIds.remove(employeeId);
        }
      }
    });
  }

  void _toggleUnloadingEmployee(String employeeId, bool selected) {
    setState(() {
      if (selected) {
        _unloadingEmployeeIds.add(employeeId);
      } else {
        _unloadingEmployeeIds.remove(employeeId);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(20),
      child: Container(
        width: 800,
        constraints: const BoxConstraints(maxHeight: 850),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.5),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.fromLTRB(28, 24, 16, 20),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: theme.colorScheme.outline.withValues(alpha: 0.1),
                    width: 1,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.people_outline,
                      color: theme.colorScheme.primary,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Select Employees for Trip Wages',
                          style: TextStyle(
                            color: theme.colorScheme.onSurface,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Select employees for loading and unloading tasks',
                          style: TextStyle(
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.close,
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Same employees checkbox
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: theme.colorScheme.outline.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Row(
                        children: [
                          Checkbox(
                            value: _sameEmployees,
                            onChanged: (value) => _toggleSameEmployees(value ?? false),
                            activeColor: theme.colorScheme.primary,
                          ),
                          Expanded(
                            child: Text(
                              'Loaders and Unloaders were same',
                              style: TextStyle(
                                color: theme.colorScheme.onSurface,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    
                    // Employee selection lists
                    if (_sameEmployees) ...[
                      // Single checklist when same employees
                      _buildEmployeeList(
                        title: 'Employees (Loaders & Unloaders)',
                        employeeIds: _loadingEmployeeIds,
                        onToggle: _toggleLoadingEmployee,
                      ),
                    ] else ...[
                      // Two separate checklists
                      _buildEmployeeList(
                        title: 'Loading Employees',
                        employeeIds: _loadingEmployeeIds,
                        onToggle: _toggleLoadingEmployee,
                      ),
                      const SizedBox(height: 24),
                      _buildEmployeeList(
                        title: 'Unloading Employees',
                        employeeIds: _unloadingEmployeeIds,
                        onToggle: _toggleUnloadingEmployee,
                      ),
                    ],
                    
                    const SizedBox(height: 24),
                    
                    // Simplified Wage breakdown
                    if ((_sameEmployees && _loadingEmployeeIds.isNotEmpty) || 
                        (!_sameEmployees && (_loadingEmployeeIds.isNotEmpty || _unloadingEmployeeIds.isNotEmpty)))
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primaryContainer.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: theme.colorScheme.primary.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Total Wage',
                                  style: TextStyle(
                                    color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                                    fontSize: 13,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '₹${widget.totalWage.toStringAsFixed(4)}',
                                  style: TextStyle(
                                    color: theme.colorScheme.primary,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  _sameEmployees 
                                      ? 'Per Employee (${_loadingEmployeeIds.length})'
                                      : 'Per Employee (${<dynamic>{..._loadingEmployeeIds, ..._unloadingEmployeeIds}.length})',
                                  style: TextStyle(
                                    color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                                    fontSize: 13,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _sameEmployees
                                      ? '₹${_totalWagePerEmployee.toStringAsFixed(4)}'
                                      : _loadingEmployeeIds.isNotEmpty && _unloadingEmployeeIds.isNotEmpty
                                          ? '₹${((_loadingWage + _unloadingWage) / <dynamic>{..._loadingEmployeeIds, ..._unloadingEmployeeIds}.length).toStringAsFixed(4)}'
                                          : _loadingEmployeeIds.isNotEmpty
                                              ? '₹${_loadingWagePerEmployee.toStringAsFixed(4)}'
                                              : '₹${_unloadingWagePerEmployee.toStringAsFixed(4)}',
                                  style: TextStyle(
                                    color: theme.colorScheme.primary,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
            
            // Footer with buttons
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: theme.colorScheme.outline.withValues(alpha: 0.1),
                    width: 1,
                  ),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  DashButton(
                    label: 'Cancel',
                    onPressed: () => Navigator.of(context).pop(),
                    variant: DashButtonVariant.text,
                  ),
                  const SizedBox(width: 12),
                  DashButton(
                    label: 'Save',
                    onPressed: (_loadingEmployeeIds.isEmpty && _unloadingEmployeeIds.isEmpty)
                        ? null
                        : () {
                            Navigator.of(context).pop({
                              'loadingEmployeeIds': _loadingEmployeeIds.toList(),
                              'unloadingEmployeeIds': _unloadingEmployeeIds.toList(),
                              'sameEmployees': _sameEmployees,
                            });
                          },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmployeeList({
    required String title,
    required Set<String> employeeIds,
    required Function(String, bool) onToggle,
  }) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            color: theme.colorScheme.onSurface,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          constraints: const BoxConstraints(maxHeight: 300),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: theme.colorScheme.outline.withValues(alpha: 0.2),
            ),
          ),
          child: widget.employees.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(16),
                  child: Center(
                    child: Text(
                      'No employees available',
                      style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.5)),
                    ),
                  ),
                )
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: widget.employees.length,
                  itemBuilder: (context, index) {
                    final employee = widget.employees[index];
                    final isSelected = employeeIds.contains(employee.id);
                    return CheckboxListTile(
                      value: isSelected,
                      onChanged: (value) => onToggle(employee.id, value ?? false),
                      activeColor: theme.colorScheme.primary,
                      title: Text(
                        employee.name,
                        style: TextStyle(color: theme.colorScheme.onSurface),
                      ),
                      subtitle: employee.primaryJobRoleTitle.isNotEmpty
                          ? Text(
                              employee.primaryJobRoleTitle,
                              style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
                            )
                          : null,
                      tileColor: isSelected
                          ? theme.colorScheme.primaryContainer.withValues(alpha: 0.2)
                          : null,
                    );
                  },
                ),
        ),
      ],
    );
  }

}
