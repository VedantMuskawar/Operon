import 'package:core_bloc/core_bloc.dart';
import 'package:core_datasources/core_datasources.dart';
import 'package:core_models/core_models.dart';
import 'package:core_ui/core_ui.dart';
import 'package:dash_web/presentation/blocs/org_context/org_context_cubit.dart';
import 'package:dash_web/presentation/blocs/wage_settings/wage_settings_cubit.dart';
import 'package:dash_web/presentation/blocs/wage_settings/wage_settings_state.dart';
import 'package:dash_web/presentation/widgets/section_workspace_layout.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class WageSettingsPage extends StatelessWidget {
  const WageSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final orgState = context.watch<OrganizationContextCubit>().state;
    final organization = orgState.organization;
    
    if (organization == null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('No organization selected'),
              const SizedBox(height: 16),
              DashButton(
                label: 'Select Organization',
                onPressed: () => context.go('/org-selection'),
              ),
            ],
          ),
        ),
      );
    }

    return BlocProvider(
      create: (context) => WageSettingsCubit(
        repository: context.read<WageSettingsRepository>(),
        organizationId: organization.id,
      )..loadSettings(),
      child: SectionWorkspaceLayout(
        panelTitle: 'Wage Settings',
        currentIndex: -1,
        onNavTap: (index) => context.go('/home?section=$index'),
        child: const _WageSettingsContent(),
      ),
    );
  }
}

// Content widget for sidebar use
class WageSettingsPageContent extends StatelessWidget {
  const WageSettingsPageContent({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocListener<WageSettingsCubit, WageSettingsState>(
      listener: (context, state) {
        if (state.status == ViewStatus.failure && state.message != null) {
          DashSnackbar.show(context, message: state.message!, isError: true);
        }
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              color: AuthColors.surface,
              border: Border.all(color: AuthColors.textMain.withValues(alpha: 0.12)),
            ),
            child: const Text(
              'Configure wage calculation methods for your organization.',
              style: TextStyle(color: AuthColors.textSub),
            ),
          ),
          const SizedBox(height: 20),
          BlocBuilder<WageSettingsCubit, WageSettingsState>(
            builder: (context, state) {
              final settings = state.settings;
              final isEnabled = settings?.enabled ?? false;

              return Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AuthColors.surface,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AuthColors.textMain.withValues(alpha: 0.1)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Enable Wage Calculations',
                            style: TextStyle(
                              color: AuthColors.textMain,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            isEnabled
                                ? 'Wage calculations are active'
                                : 'Wage calculations are disabled',
                            style: const TextStyle(
                              color: AuthColors.textSub,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: isEnabled,
                      onChanged: (value) {
                        context.read<WageSettingsCubit>().toggleEnabled(value);
                      },
                      activeThumbColor: AuthColors.primary,
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 20),
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
                onTap: () => _openMethodDialog(context),
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
                        'Add Wage Method',
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
          BlocBuilder<WageSettingsCubit, WageSettingsState>(
            builder: (context, state) {
              if (state.status == ViewStatus.loading) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(40),
                    child: CircularProgressIndicator(),
                  ),
                );
              }

              final methods = state.settings?.calculationMethods.values.toList() ?? [];
              if (methods.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.only(top: 40),
                  child: Text(
                    'No wage methods yet. Tap "Add Wage Method" to create one.',
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
                itemCount: methods.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final method = methods[index];
                  return _WageMethodDataListItem(
                    method: method,
                    onEdit: () => _openMethodDialog(context, method: method),
                    onDelete: () => _confirmDeleteMethod(context, method),
                    onToggle: (enabled) {
                      context.read<WageSettingsCubit>().toggleWageMethodStatus(
                        method.methodId,
                        enabled,
                      );
                    },
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  Future<void> _openMethodDialog(
    BuildContext context, {
    WageCalculationMethod? method,
  }) async {
    final cubit = context.read<WageSettingsCubit>();
    await showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Wage Method Dialog',
      barrierColor: AuthColors.background.withValues(alpha: 0.6),
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, animation, secondaryAnimation) {
        return BlocProvider.value(
          value: cubit,
          child: _WageMethodDialog(method: method),
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

  Future<void> _confirmDeleteMethod(
    BuildContext context,
    WageCalculationMethod method,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AuthColors.surface,
        title: const Text(
          'Delete Wage Method',
          style: TextStyle(color: AuthColors.textMain),
        ),
        content: Text(
          'Are you sure you want to delete "${method.name}"? This action cannot be undone.',
          style: const TextStyle(color: AuthColors.textSub),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      context.read<WageSettingsCubit>().deleteWageMethod(method.methodId);
    }
  }
}

class _WageMethodDataListItem extends StatelessWidget {
  const _WageMethodDataListItem({
    required this.method,
    required this.onEdit,
    required this.onDelete,
    required this.onToggle,
  });

  final WageCalculationMethod method;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final ValueChanged<bool> onToggle;

  Color get _typeColor {
    switch (method.methodType) {
      case WageMethodType.production:
        return const Color(0xFF00BCD4);
      case WageMethodType.loadingUnloading:
        return const Color(0xFF3F51B5);
      case WageMethodType.dailyRate:
        return const Color(0xFFFF9800);
      case WageMethodType.custom:
        return const Color(0xFF9C27B0);
    }
  }

  String get _typeLabel {
    switch (method.methodType) {
      case WageMethodType.production:
        return 'Production';
      case WageMethodType.loadingUnloading:
        return 'Loading/Unloading';
      case WageMethodType.dailyRate:
        return 'Daily Rate';
      case WageMethodType.custom:
        return 'Custom';
    }
  }

  String _formatSubtitle() {
    final parts = <String>[];
    parts.add(_typeLabel);
    if (method.description != null) {
      parts.add(method.description!);
    }
    parts.add(method.enabled ? 'Enabled' : 'Disabled');
    return parts.join(' • ');
  }

  Color _getStatusColor() {
    if (!method.enabled) {
      return AuthColors.textDisabled;
    }
    return _typeColor;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AuthColors.background,
        borderRadius: BorderRadius.circular(18),
      ),
      child: DataList(
        title: method.name,
        subtitle: _formatSubtitle(),
        leading: DataListAvatar(
          initial: method.name.isNotEmpty ? method.name[0] : 'W',
          radius: 28,
          statusRingColor: _getStatusColor(),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            DataListStatusDot(
              color: _getStatusColor(),
              size: 8,
            ),
            const SizedBox(width: 12),
            Switch(
              value: method.enabled,
              onChanged: onToggle,
              activeThumbColor: _typeColor,
            ),
            const SizedBox(width: 12),
            IconButton(
              icon: const Icon(
                Icons.edit_outlined,
                color: AuthColors.textSub,
                size: 20,
              ),
              onPressed: onEdit,
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
              onPressed: onDelete,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ),
        onTap: onEdit,
      ),
    );
  }
}

class _WageMethodDialog extends StatefulWidget {
  const _WageMethodDialog({this.method});

  final WageCalculationMethod? method;

  @override
  State<_WageMethodDialog> createState() => _WageMethodDialogState();
}

class _WageMethodDialogState extends State<_WageMethodDialog> {
  final _formKey = GlobalKey<FormState>();
  
  // Production config controllers
  late final TextEditingController _productionPriceController;
  late final TextEditingController _stackingPriceController;
  
  // Loading/Unloading config - quantity-wage pairs
  final Map<String, double> _wagePerQuantity = {};
  
  WageMethodType _methodType = WageMethodType.production;
  bool _enabled = true;
  bool _isSubmitting = false;
  
  // Production config state
  bool _requiresBatchApproval = false;
  bool _autoCalculateOnRecord = true;

  @override
  void initState() {
    super.initState();
    final method = widget.method;
    
    _methodType = method?.methodType ?? WageMethodType.production;
    _enabled = method?.enabled ?? true;
    
    // Initialize production config
    if (method?.config is ProductionWageConfig) {
      final config = method!.config as ProductionWageConfig;
      _productionPriceController = TextEditingController(
        text: config.productionPricePerUnit.toStringAsFixed(2),
      );
      _stackingPriceController = TextEditingController(
        text: config.stackingPricePerUnit.toStringAsFixed(2),
      );
      _requiresBatchApproval = config.requiresBatchApproval;
      _autoCalculateOnRecord = config.autoCalculateOnRecord;
    } else {
      _productionPriceController = TextEditingController();
      _stackingPriceController = TextEditingController();
    }
    
    // Initialize loading/unloading config
    if (method?.config is LoadingUnloadingConfig) {
      final config = method!.config as LoadingUnloadingConfig;
      _wagePerQuantity.clear();
      if (config.wagePerQuantity != null) {
        _wagePerQuantity.addAll(config.wagePerQuantity!);
      }
    }
  }

  @override
  void dispose() {
    _productionPriceController.dispose();
    _stackingPriceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.method != null;
    final screenWidth = MediaQuery.of(context).size.width;
    final dialogWidth = (screenWidth * 0.9).clamp(400.0, 700.0);

    return AlertDialog(
      backgroundColor: AuthColors.surface,
      title: Text(
        isEditing ? 'Edit Wage Method' : 'Add Wage Method',
        style: const TextStyle(color: AuthColors.textMain),
      ),
      content: SizedBox(
        width: dialogWidth,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DropdownButtonFormField<WageMethodType>(
                  initialValue: _methodType,
                  dropdownColor: AuthColors.surface,
                  style: const TextStyle(color: AuthColors.textMain),
                  decoration: _inputDecoration('Method Type'),
                  onChanged: isEditing
                      ? null
                      : (value) {
                          if (value != null) {
                            setState(() => _methodType = value);
                          }
                        },
                  items: WageMethodType.values.map((type) {
                    String label;
                    switch (type) {
                      case WageMethodType.production:
                        label = 'Production';
                      case WageMethodType.loadingUnloading:
                        label = 'Loading/Unloading';
                      case WageMethodType.dailyRate:
                        label = 'Daily Rate';
                      case WageMethodType.custom:
                        label = 'Custom';
                    }
                    return DropdownMenuItem(
                      value: type,
                      child: Text(label),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                if (_methodType == WageMethodType.production) ...[
                  _buildSectionTitle('Production Configuration'),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _productionPriceController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    style: const TextStyle(color: AuthColors.textMain),
                    decoration: _inputDecoration('Production Price Per Unit'),
                    validator: (value) {
                      final parsed = double.tryParse(value ?? '');
                      if (parsed == null || parsed < 0) {
                        return 'Enter a valid price';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _stackingPriceController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    style: const TextStyle(color: AuthColors.textMain),
                    decoration: _inputDecoration('Stacking Price Per Unit'),
                    validator: (value) {
                      final parsed = double.tryParse(value ?? '');
                      if (parsed == null || parsed < 0) {
                        return 'Enter a valid price';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    title: const Text(
                      'Require Batch Approval',
                      style: TextStyle(color: Colors.white),
                    ),
                    subtitle: const Text(
                      'Wages require approval before processing',
                      style: TextStyle(color: AuthColors.textSub),
                    ),
                    value: _requiresBatchApproval,
                    onChanged: (value) => setState(() => _requiresBatchApproval = value),
                    activeThumbColor: AuthColors.primary,
                  ),
                  SwitchListTile(
                    title: const Text(
                      'Auto-Calculate on Record',
                      style: TextStyle(color: Colors.white),
                    ),
                    subtitle: const Text(
                      'Automatically calculate wages when batch is recorded',
                      style: TextStyle(color: AuthColors.textSub),
                    ),
                    value: _autoCalculateOnRecord,
                    onChanged: (value) => setState(() => _autoCalculateOnRecord = value),
                    activeThumbColor: AuthColors.primary,
                  ),
                ],
                if (_methodType == WageMethodType.loadingUnloading) ...[
                  _buildSectionTitle('Loading/Unloading Configuration'),
                  const SizedBox(height: 8),
                  const Padding(
                    padding: EdgeInsets.only(bottom: 12.0),
                    child: Text(
                      'Add quantity ranges and wages for each range',
                      style: TextStyle(color: Colors.white60, fontSize: 13),
                    ),
                  ),
                  _buildQuantityWageList(),
                  const SizedBox(height: 12),
                  DashButton(
                    label: 'Add Quantity Range',
                    icon: Icons.add,
                    onPressed: () => _showAddQuantityWageDialog(context),
                  ),
                ],
                if (_methodType == WageMethodType.dailyRate ||
                    _methodType == WageMethodType.custom) ...[
                  _buildSectionTitle('Configuration'),
                  const SizedBox(height: 12),
                  const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Text(
                      'Daily Rate and Custom methods are coming soon.',
                      style: TextStyle(color: AuthColors.textSub),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                SwitchListTile(
                  title: const Text(
                    'Enabled',
                    style: TextStyle(color: Colors.white),
                  ),
                  subtitle: const Text(
                    'Enable this wage calculation method',
                    style: TextStyle(color: Colors.white60),
                  ),
                  value: _enabled,
                  onChanged: (value) => setState(() => _enabled = value),
                  activeThumbColor: const Color(0xFF6F4BFF),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting
              ? null
              : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: _isSubmitting
              ? null
              : () => _handleSubmit(context, isEditing),
          child: _isSubmitting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(isEditing ? 'Save' : 'Create'),
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Text(
        title,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildQuantityWageList() {
    if (_wagePerQuantity.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF1B1B2C).withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.1),
          ),
        ),
        child: const Center(
          child: Text(
            'No quantity ranges added yet',
            style: TextStyle(color: Colors.white60),
          ),
        ),
      );
    }

    return Column(
      children: _wagePerQuantity.entries.map((entry) {
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF1B1B2C),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.1),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Quantity: ${entry.key}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Wage: ₹${entry.value.toStringAsFixed(2)}',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.edit, color: Colors.white70, size: 20),
                onPressed: () => _showEditQuantityWageDialog(
                  context,
                  entry.key,
                  entry.value,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                onPressed: () {
                  setState(() {
                    _wagePerQuantity.remove(entry.key);
                  });
                },
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Future<void> _showAddQuantityWageDialog(BuildContext context) async {
    await _showQuantityWageDialog(context);
  }

  Future<void> _showEditQuantityWageDialog(
    BuildContext context,
    String currentQuantity,
    double currentWage,
  ) async {
    await _showQuantityWageDialog(
      context,
      currentQuantity: currentQuantity,
      currentWage: currentWage,
    );
  }

  Future<void> _showQuantityWageDialog(
    BuildContext context, {
    String? currentQuantity,
    double? currentWage,
  }) async {
    await showDialog(
      context: context,
      builder: (dialogContext) => _QuantityWageDialog(
        currentQuantity: currentQuantity,
        currentWage: currentWage,
        wagePerQuantity: _wagePerQuantity,
        onSave: (quantity, wage) {
          final isEditing = currentQuantity != null;
          if (isEditing && currentQuantity != quantity) {
            _wagePerQuantity.remove(currentQuantity);
          }
          setState(() {
            _wagePerQuantity[quantity] = wage;
          });
          Navigator.of(dialogContext).pop();
        },
        inputDecoration: _inputDecoration,
      ),
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

  Future<void> _handleSubmit(BuildContext context, bool isEditing) async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _isSubmitting = true);

    try {
      final cubit = context.read<WageSettingsCubit>();
      final now = DateTime.now();
      
      final methodId = widget.method?.methodId ??
          DateTime.now().millisecondsSinceEpoch.toString();

      WageMethodConfig config;
      switch (_methodType) {
        case WageMethodType.production:
          config = ProductionWageConfig(
            productionPricePerUnit:
                double.parse(_productionPriceController.text.trim()),
            stackingPricePerUnit:
                double.parse(_stackingPriceController.text.trim()),
            requiresBatchApproval: _requiresBatchApproval,
            autoCalculateOnRecord: _autoCalculateOnRecord,
          );
          break;
        case WageMethodType.loadingUnloading:
          if (_wagePerQuantity.isEmpty) {
            throw Exception('At least one quantity-wage pair is required');
          }
          config = LoadingUnloadingConfig(
            wagePerQuantity: _wagePerQuantity,
            loadingPercentage: 50.0, // Default, not used in UI
            unloadingPercentage: 50.0, // Default, not used in UI
            triggerOnTripDelivery: false, // Default, not used in UI
            requiresEmployeeSelection: true, // Default, not used in UI
          );
          break;
        case WageMethodType.dailyRate:
        case WageMethodType.custom:
          // Placeholder - use production config as fallback
          config = const ProductionWageConfig(
            productionPricePerUnit: 0.0,
            stackingPricePerUnit: 0.0,
            requiresBatchApproval: false,
            autoCalculateOnRecord: true,
          );
          break;
      }

      // Generate method name based on type
      String methodName;
      switch (_methodType) {
        case WageMethodType.production:
          methodName = 'Production Wages';
          break;
        case WageMethodType.loadingUnloading:
          methodName = 'Loading/Unloading Wages';
          break;
        case WageMethodType.dailyRate:
          methodName = 'Daily Rate Wages';
          break;
        case WageMethodType.custom:
          methodName = 'Custom Wages';
          break;
      }
      
      // If editing, keep the existing name
      if (isEditing) {
        methodName = widget.method?.name ?? methodName;
      }

      final method = WageCalculationMethod(
        methodId: methodId,
        methodType: _methodType,
        name: methodName,
        description: null,
        enabled: _enabled,
        config: config,
        createdAt: widget.method?.createdAt ?? now,
        updatedAt: now,
      );

      if (isEditing) {
        await cubit.updateWageMethod(method);
      } else {
        await cubit.addWageMethod(method);
      }

      if (context.mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }
}

class _QuantityWageDialog extends StatefulWidget {
  const _QuantityWageDialog({
    this.currentQuantity,
    this.currentWage,
    required this.wagePerQuantity,
    required this.onSave,
    required this.inputDecoration,
  });

  final String? currentQuantity;
  final double? currentWage;
  final Map<String, double> wagePerQuantity;
  final Function(String quantity, double wage) onSave;
  final InputDecoration Function(String) inputDecoration;

  @override
  State<_QuantityWageDialog> createState() => _QuantityWageDialogState();
}

class _QuantityWageDialogState extends State<_QuantityWageDialog> {
  late final TextEditingController _quantityController;
  late final TextEditingController _wageController;
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _quantityController = TextEditingController(text: widget.currentQuantity ?? '');
    _wageController = TextEditingController(
      text: widget.currentWage?.toStringAsFixed(2) ?? '',
    );
  }

  @override
  void dispose() {
    _quantityController.dispose();
    _wageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.currentQuantity != null;
    
    return AlertDialog(
      backgroundColor: const Color(0xFF11111B),
      title: Text(
        isEditing ? 'Edit Quantity Range' : 'Add Quantity Range',
        style: const TextStyle(color: Colors.white),
      ),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _quantityController,
              style: const TextStyle(color: Colors.white),
              decoration: widget.inputDecoration('Quantity Range (e.g., 0-1000)'),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Enter quantity range';
                }
                // Validate format (e.g., "0-1000" or "1001-2000")
                final parts = value.trim().split('-');
                if (parts.length != 2) {
                  return 'Format: min-max (e.g., 0-1000)';
                }
                final min = int.tryParse(parts[0].trim());
                final max = int.tryParse(parts[1].trim());
                if (min == null || max == null || min >= max) {
                  return 'Enter valid range (min < max)';
                }
                // Check if this quantity already exists (unless editing the same one)
                if (!isEditing && widget.wagePerQuantity.containsKey(value.trim())) {
                  return 'This quantity range already exists';
                }
                if (isEditing && 
                    value.trim() != widget.currentQuantity && 
                    widget.wagePerQuantity.containsKey(value.trim())) {
                  return 'This quantity range already exists';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _wageController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: const TextStyle(color: Colors.white),
              decoration: widget.inputDecoration('Wage for this range'),
              validator: (value) {
                final parsed = double.tryParse(value ?? '');
                if (parsed == null || parsed < 0) {
                  return 'Enter a valid wage';
                }
                return null;
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () {
            if (_formKey.currentState?.validate() ?? false) {
              final quantity = _quantityController.text.trim();
              final wage = double.parse(_wageController.text.trim());
              widget.onSave(quantity, wage);
            }
          },
          child: Text(isEditing ? 'Save' : 'Add'),
        ),
      ],
    );
  }
}

class _WageSettingsContent extends StatelessWidget {
  const _WageSettingsContent();

  @override
  Widget build(BuildContext context) {
    return const WageSettingsPageContent();
  }
}