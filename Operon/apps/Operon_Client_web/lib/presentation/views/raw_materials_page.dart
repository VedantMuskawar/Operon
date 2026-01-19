import 'package:core_bloc/core_bloc.dart';
import 'package:core_ui/core_ui.dart';
import 'package:core_models/core_models.dart';
import 'package:dash_web/presentation/blocs/raw_materials/raw_materials_cubit.dart';
import 'package:dash_web/presentation/widgets/page_workspace_layout.dart';
import 'package:dash_web/presentation/widgets/stock_history_dialog.dart';
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
          DashSnackbar.show(context, message: state.message!, isError: true);
        }
      },
      child: PageWorkspaceLayout(
        title: 'Raw Materials',
        currentIndex: 4,
        onBack: () => context.go('/home'),
        onNavTap: (value) => context.go('/home?section=$value'),
        child: RawMaterialsPageContent(canCreate: cubit.canCreate),
      ),
    );
  }
}

// Content widget for sidebar use
class RawMaterialsPageContent extends StatelessWidget {
  const RawMaterialsPageContent({required this.canCreate, super.key});

  final bool canCreate;

  @override
  Widget build(BuildContext context) {
    final cubit = context.watch<RawMaterialsCubit>();
    return Column(
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
            'Manage raw materials, stock levels, and purchase prices for this organization.',
            style: TextStyle(color: Colors.white70),
          ),
        ),
        const SizedBox(height: 20),
        if (canCreate)
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
                onTap: () => _openRawMaterialDialog(context),
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
                            'Add Raw Material',
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
          )
        else
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: AuthColors.textMain.withValues(alpha: 0.13),
            ),
            child: const Text(
              'You have read-only access to raw materials.',
              style: TextStyle(color: AuthColors.textSub),
            ),
          ),
        const SizedBox(height: 20),
        BlocBuilder<RawMaterialsCubit, RawMaterialsState>(
          builder: (context, state) {
            if (state.status == ViewStatus.loading) {
              return const Center(child: CircularProgressIndicator());
            }
            if (state.materials.isEmpty) {
              return Padding(
                padding: const EdgeInsets.only(top: 40),
                child: Text(
                  canCreate
                      ? 'No raw materials yet. Tap "Add Raw Material".'
                      : 'No raw materials to display.',
                  style: const TextStyle(
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
                itemCount: state.materials.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final material = state.materials[index];
                  return AnimationConfiguration.staggeredList(
                    position: index,
                    duration: const Duration(milliseconds: 200),
                    child: SlideAnimation(
                      verticalOffset: 50.0,
                      child: FadeInAnimation(
                        curve: Curves.easeOut,
                        child: _RawMaterialDataListItem(
                          material: material,
                          canEdit: cubit.canEdit,
                          canDelete: cubit.canDelete,
                          onEdit: () =>
                              _openRawMaterialDialog(context, material: material),
                          onDelete: () => cubit.deleteRawMaterial(material.id),
                          onViewHistory: () => _openStockHistoryDialog(context, material),
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
  }

  Future<void> _openRawMaterialDialog(
    BuildContext context, {
    RawMaterial? material,
  }) async {
    final cubit = context.read<RawMaterialsCubit>();
    await showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Raw Material Dialog',
      barrierColor: AuthColors.background.withValues(alpha: 0.6),
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, animation, secondaryAnimation) {
        return BlocProvider.value(
          value: cubit,
          child: _RawMaterialDialog(material: material),
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

  Future<void> _openStockHistoryDialog(
    BuildContext context,
    RawMaterial material,
  ) async {
    await showDialog(
      context: context,
      barrierColor: AuthColors.background.withValues(alpha: 0.7),
      builder: (dialogContext) => StockHistoryDialog(material: material),
    );
  }
}

class _RawMaterialDataListItem extends StatelessWidget {
  const _RawMaterialDataListItem({
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

  String _formatSubtitle() {
    final parts = <String>[];
    parts.add('₹${material.purchasePrice.toStringAsFixed(2)}/unit');
    if (material.hasGst) {
      parts.add('GST ${material.gstPercent!.toStringAsFixed(1)}%');
    }
    parts.add('Stock: ${material.stock} ${material.unitOfMeasurement}');
    if (material.isLowStock) {
      parts.add('Low Stock');
    }
    return parts.join(' • ');
  }

  Color _getStatusColor() {
    if (material.isLowStock) {
      return const Color(0xFFFF9800); // Orange for low stock
    }
    return material.status == RawMaterialStatus.active
        ? AuthColors.success
        : AuthColors.textDisabled;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AuthColors.background,
        borderRadius: BorderRadius.circular(18),
      ),
      child: DataList(
        title: material.name,
        subtitle: _formatSubtitle(),
        leading: DataListAvatar(
          initial: material.name.isNotEmpty ? material.name[0] : 'R',
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
            IconButton(
              icon: const Icon(
                Icons.history,
                color: AuthColors.textSub,
                size: 20,
              ),
              onPressed: onViewHistory,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              tooltip: 'View Stock History',
            ),
            if (canEdit) ...[
              const SizedBox(width: 8),
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
            ],
            if (canDelete) ...[
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
          ],
        ),
        onTap: canEdit ? onEdit : null,
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
    final screenWidth = MediaQuery.of(context).size.width;
    final dialogWidth = (screenWidth * 0.9).clamp(400.0, 600.0);

    return AlertDialog(
      backgroundColor: AuthColors.surface,
      title: Text(
        isEditing ? 'Edit Raw Material' : 'Add Raw Material',
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
                  controller: _nameController,
                  style: const TextStyle(color: AuthColors.textMain),
                  decoration: _inputDecoration('Material name'),
                  validator: (value) =>
                      (value == null || value.trim().isEmpty)
                          ? 'Enter material name'
                          : null,
                ),
                const SizedBox(height: 12),
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
                const SizedBox(height: 12),
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
                const SizedBox(height: 12),
                TextFormField(
                  controller: _unitController,
                  style: const TextStyle(color: AuthColors.textMain),
                  decoration: _inputDecoration('Unit of Measurement (e.g., kg, liters, pieces)'),
                  validator: (value) =>
                      (value == null || value.trim().isEmpty)
                          ? 'Enter unit of measurement'
                          : null,
                ),
                const SizedBox(height: 12),
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
                const SizedBox(height: 12),
                TextFormField(
                  controller: _minimumStockController,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: AuthColors.textMain),
                  decoration: _inputDecoration('Minimum Stock Level'),
                  validator: (value) {
                    final parsed = int.tryParse(value ?? '');
                    if (parsed == null || parsed < 0) {
                      return 'Enter a valid minimum stock level';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<RawMaterialStatus>(
                  initialValue: _status,
                  dropdownColor: AuthColors.surface,
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
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel', style: TextStyle(color: AuthColors.textSub)),
        ),
        DashButton(
          label: isEditing ? 'Save' : 'Create',
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
}

