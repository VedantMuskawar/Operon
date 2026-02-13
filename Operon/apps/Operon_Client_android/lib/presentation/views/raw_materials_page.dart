import 'package:core_bloc/core_bloc.dart';
import 'package:core_models/core_models.dart';
import 'package:core_ui/core_ui.dart';
import 'package:dash_mobile/presentation/blocs/raw_materials/raw_materials_cubit.dart';
import 'package:dash_mobile/presentation/widgets/modern_page_header.dart';
import 'package:dash_mobile/presentation/widgets/stock_history_dialog.dart';
import 'package:dash_mobile/shared/constants/app_spacing.dart';
import 'package:dash_mobile/shared/constants/app_typography.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:go_router/go_router.dart';

class RawMaterialsPage extends StatelessWidget {
  const RawMaterialsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final cubit = context.watch<RawMaterialsCubit>();
    return BlocListener<RawMaterialsCubit, RawMaterialsState>(
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
          title: 'Raw Materials',
        ),
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(AppSpacing.paddingLG),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(AppSpacing.paddingLG),
                        decoration: BoxDecoration(
                          borderRadius:
                              BorderRadius.circular(AppSpacing.radiusXL),
                          color: AuthColors.backgroundAlt,
                          border: Border.all(
                              color: AuthColors.textMainWithOpacity(0.12)),
                        ),
                        child: const Text(
                          'Manage raw materials, stock levels, and purchase prices for this organization.',
                          style: TextStyle(color: AuthColors.textSub),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.paddingXL),
                      if (cubit.canCreate)
                        SizedBox(
                          width: double.infinity,
                          child: DashButton(
                            label: 'Add Raw Material',
                            onPressed: () => _openRawMaterialDialog(context),
                          ),
                        )
                      else
                        Container(
                          padding: const EdgeInsets.all(AppSpacing.paddingMD),
                          decoration: BoxDecoration(
                            borderRadius:
                                BorderRadius.circular(AppSpacing.radiusMD),
                            color: AuthColors.textMainWithOpacity(0.13),
                          ),
                          child: const Text(
                            'You have read-only access to raw materials.',
                            style: TextStyle(color: Colors.white70),
                          ),
                        ),
                      const SizedBox(height: AppSpacing.paddingXL),
                      BlocBuilder<RawMaterialsCubit, RawMaterialsState>(
                        builder: (context, state) {
                          if (state.status == ViewStatus.loading) {
                            return const Center(
                                child: CircularProgressIndicator());
                          }
                          if (state.materials.isEmpty) {
                            return Padding(
                              padding: const EdgeInsets.only(
                                  top: AppSpacing.paddingXXXL * 1.25),
                              child: Text(
                                cubit.canCreate
                                    ? 'No raw materials yet. Tap "Add Raw Material".'
                                    : 'No raw materials to display.',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.6),
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
                              itemCount: state.materials.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: AppSpacing.paddingMD),
                              itemBuilder: (context, index) {
                                final material = state.materials[index];
                                return AnimationConfiguration.staggeredList(
                                  position: index,
                                  duration: const Duration(milliseconds: 200),
                                  child: SlideAnimation(
                                    verticalOffset: 50.0,
                                    child: FadeInAnimation(
                                      curve: Curves.easeOut,
                                      child: _RawMaterialTile(
                                        material: material,
                                        canEdit: cubit.canEdit,
                                        canDelete: cubit.canDelete,
                                        onEdit: () => _openRawMaterialDialog(
                                            context,
                                            material: material),
                                        onDelete: () => cubit
                                            .deleteRawMaterial(material.id),
                                        onViewHistory: () =>
                                            _openStockHistoryDialog(
                                                context, material),
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
                    icon: Icons.event_available_rounded,
                    label: 'Cash Ledger',
                    heroTag: 'nav_cash_ledger',
                  ),
                ],
                currentIndex: -1,
                onItemTapped: (value) => context.go('/home', extra: value),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openRawMaterialDialog(
    BuildContext context, {
    RawMaterial? material,
  }) async {
    final cubit = context.read<RawMaterialsCubit>();
    await showDialog(
      context: context,
      builder: (dialogContext) => BlocProvider.value(
        value: cubit,
        child: _RawMaterialDialog(material: material),
      ),
    );
  }

  Future<void> _openStockHistoryDialog(
    BuildContext context,
    RawMaterial material,
  ) async {
    await showDialog(
      context: context,
      builder: (dialogContext) => StockHistoryDialog(material: material),
    );
  }
}

class _RawMaterialTile extends StatelessWidget {
  const _RawMaterialTile({
    required this.material,
    required this.canEdit,
    required this.canDelete,
    required this.onEdit,
    required this.onDelete,
    required this.onViewHistory,
  });

  final RawMaterial material;
  final bool canEdit;
  final bool canDelete;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onViewHistory;

  @override
  Widget build(BuildContext context) {
    final isLowStock = material.isLowStock;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.paddingLG),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isLowStock
              ? [
                  AuthColors.error.withValues(alpha: 0.2),
                  AuthColors.error.withValues(alpha: 0.1)
                ]
              : [AuthColors.surface, AuthColors.backgroundAlt],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppSpacing.radiusXL),
        border: Border.all(
          color: isLowStock
              ? Colors.orange.withValues(alpha: 0.5)
              : AuthColors.textMainWithOpacity(0.1),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: isLowStock
                  ? Colors.orange.withValues(alpha: 0.2)
                  : AuthColors.textMainWithOpacity(0.1),
              borderRadius: BorderRadius.circular(AppSpacing.radiusLG),
            ),
            alignment: Alignment.center,
            child: Icon(
              isLowStock
                  ? Icons.warning_amber_rounded
                  : Icons.inventory_2_outlined,
              color: isLowStock ? Colors.orange : Colors.white,
            ),
          ),
          const SizedBox(width: AppSpacing.paddingMD),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        material.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (isLowStock)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.orange.withValues(alpha: 0.2),
                          borderRadius:
                              BorderRadius.circular(AppSpacing.radiusSM),
                        ),
                        child: const Text(
                          'Low Stock',
                          style: TextStyle(
                            color: Colors.orange,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.gapSM),
                Text(
                  material.hasGst
                      ? '₹${material.purchasePrice.toStringAsFixed(2)}/unit • GST ${material.gstPercent!.toStringAsFixed(1)}%'
                      : '₹${material.purchasePrice.toStringAsFixed(2)}/unit • No GST',
                  style: AppTypography.withColor(
                      AppTypography.labelSmall, AuthColors.textSub),
                ),
                const SizedBox(height: AppSpacing.paddingXS),
                Text(
                  'Stock: ${material.stock} ${material.unitOfMeasurement} • Min: ${material.minimumStockLevel} ${material.unitOfMeasurement}',
                  style: TextStyle(
                    color: isLowStock
                        ? AuthColors.warning
                        : AuthColors.textDisabled,
                    fontSize: 12,
                    fontWeight:
                        isLowStock ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
                const SizedBox(height: AppSpacing.paddingXS),
                Text(
                  'Status: ${material.status.name}',
                  style: AppTypography.withColor(
                      AppTypography.labelSmall, AuthColors.textDisabled),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              IconButton(
                icon: const Icon(Icons.history, color: AuthColors.textSub),
                onPressed: onViewHistory,
                tooltip: 'View Stock History',
              ),
              if (canEdit || canDelete) ...[
                if (canEdit)
                  IconButton(
                    icon: const Icon(Icons.edit, color: AuthColors.textSub),
                    onPressed: onEdit,
                  ),
                if (canEdit && canDelete)
                  const SizedBox(height: AppSpacing.paddingSM),
                if (canDelete)
                  IconButton(
                    icon: const Icon(Icons.delete_outline,
                        color: Colors.redAccent),
                    onPressed: onDelete,
                  ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _RawMaterialDialog extends StatefulWidget {
  const _RawMaterialDialog({this.material});

  final RawMaterial? material;

  @override
  State<_RawMaterialDialog> createState() => _RawMaterialDialogState();
}

class _RawMaterialDialogState extends State<_RawMaterialDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _purchasePriceController;
  late final TextEditingController _gstController;
  late final TextEditingController _unitController;
  late final TextEditingController _stockController;
  late final TextEditingController _minimumStockController;
  RawMaterialStatus _status = RawMaterialStatus.active;

  @override
  void initState() {
    super.initState();
    final material = widget.material;
    _nameController = TextEditingController(text: material?.name ?? '');
    _purchasePriceController = TextEditingController(
      text: material != null ? material.purchasePrice.toStringAsFixed(2) : '',
    );
    _gstController = TextEditingController(
      text: material != null && material.gstPercent != null
          ? material.gstPercent!.toStringAsFixed(1)
          : '',
    );
    _unitController = TextEditingController(
      text: material?.unitOfMeasurement ?? '',
    );
    _stockController = TextEditingController(
      text: material != null ? material.stock.toString() : '0',
    );
    _minimumStockController = TextEditingController(
      text: material != null ? material.minimumStockLevel.toString() : '0',
    );
    _status = material?.status ?? RawMaterialStatus.active;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _purchasePriceController.dispose();
    _gstController.dispose();
    _unitController.dispose();
    _stockController.dispose();
    _minimumStockController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.material != null;
    final cubit = context.read<RawMaterialsCubit>();
    final canCreate = cubit.canCreate;
    final canEdit = cubit.canEdit;

    return AlertDialog(
      backgroundColor: AuthColors.backgroundAlt,
      title: Text(
        isEditing ? 'Edit Raw Material' : 'Add Raw Material',
        style: AppTypography.withColor(AppTypography.h3, AuthColors.textMain),
      ),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameController,
                style: const TextStyle(color: AuthColors.textMain),
                decoration: _inputDecoration('Material name'),
                validator: (value) => (value == null || value.trim().isEmpty)
                    ? 'Enter material name'
                    : null,
              ),
              const SizedBox(height: AppSpacing.paddingMD),
              TextFormField(
                controller: _purchasePriceController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                style: const TextStyle(color: AuthColors.textMain),
                decoration: _inputDecoration('Purchase Price (per unit)'),
                validator: (value) {
                  final parsed = double.tryParse(value ?? '');
                  if (parsed == null || parsed < 0) {
                    return 'Enter a valid price';
                  }
                  return null;
                },
              ),
              const SizedBox(height: AppSpacing.paddingMD),
              TextFormField(
                controller: _gstController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                style: const TextStyle(color: AuthColors.textMain),
                decoration: _inputDecoration('GST (%) - Optional'),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return null; // GST is optional
                  }
                  final parsed = double.tryParse(value);
                  if (parsed == null || parsed < 0 || parsed > 100) {
                    return 'Enter value between 0 and 100';
                  }
                  return null;
                },
              ),
              const SizedBox(height: AppSpacing.paddingMD),
              TextFormField(
                controller: _unitController,
                style: const TextStyle(color: AuthColors.textMain),
                decoration: _inputDecoration(
                    'Unit of Measurement (e.g., kg, liters, pieces)'),
                validator: (value) => (value == null || value.trim().isEmpty)
                    ? 'Enter unit of measurement'
                    : null,
              ),
              const SizedBox(height: AppSpacing.paddingMD),
              TextFormField(
                controller: _stockController,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: AuthColors.textMain),
                decoration: _inputDecoration('Current Stock'),
                validator: (value) {
                  final parsed = int.tryParse(value ?? '');
                  if (parsed == null || parsed < 0) {
                    return 'Enter a valid stock quantity';
                  }
                  return null;
                },
              ),
              const SizedBox(height: AppSpacing.paddingMD),
              TextFormField(
                controller: _minimumStockController,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: Colors.white),
                decoration: _inputDecoration('Minimum Stock Level'),
                validator: (value) {
                  final parsed = int.tryParse(value ?? '');
                  if (parsed == null || parsed < 0) {
                    return 'Enter a valid minimum stock level';
                  }
                  return null;
                },
              ),
              const SizedBox(height: AppSpacing.paddingMD),
              DropdownButtonFormField<RawMaterialStatus>(
                initialValue: _status,
                dropdownColor: AuthColors.backgroundAlt,
                style: const TextStyle(color: AuthColors.textMain),
                decoration: _inputDecoration('Status'),
                onChanged: (value) {
                  if (value != null) setState(() => _status = value);
                },
                items: const [
                  DropdownMenuItem(
                    value: RawMaterialStatus.active,
                    child: Text('Active'),
                  ),
                  DropdownMenuItem(
                    value: RawMaterialStatus.paused,
                    child: Text('Paused'),
                  ),
                  DropdownMenuItem(
                    value: RawMaterialStatus.archived,
                    child: Text('Archived'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: (isEditing ? canEdit : canCreate)
              ? () {
                  if (!(_formKey.currentState?.validate() ?? false)) return;
                  final cubit = context.read<RawMaterialsCubit>();

                  // Parse GST (optional)
                  final gstText = _gstController.text.trim();
                  final double? gstPercent =
                      gstText.isEmpty ? null : double.tryParse(gstText);

                  final material = RawMaterial(
                    id: widget.material?.id ??
                        DateTime.now().millisecondsSinceEpoch.toString(),
                    name: _nameController.text.trim(),
                    purchasePrice: double.tryParse(
                          _purchasePriceController.text.trim(),
                        ) ??
                        0,
                    gstPercent: gstPercent,
                    unitOfMeasurement: _unitController.text.trim(),
                    stock: int.tryParse(_stockController.text.trim()) ?? 0,
                    minimumStockLevel:
                        int.tryParse(_minimumStockController.text.trim()) ?? 0,
                    status: _status,
                  );
                  if (widget.material == null) {
                    cubit.createRawMaterial(material);
                  } else {
                    cubit.updateRawMaterial(material);
                  }
                  Navigator.of(context).pop();
                }
              : null,
          child: Text(isEditing ? 'Save' : 'Create'),
        ),
      ],
    );
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: AuthColors.backgroundAlt,
      labelStyle: const TextStyle(color: AuthColors.textSub),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusMD),
        borderSide: BorderSide.none,
      ),
    );
  }
}
