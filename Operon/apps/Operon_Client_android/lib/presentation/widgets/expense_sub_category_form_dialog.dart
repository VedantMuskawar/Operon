import 'package:core_models/core_models.dart';
import 'package:core_ui/core_ui.dart';
import 'package:dash_mobile/shared/constants/app_spacing.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ExpenseSubCategoryFormDialog extends StatefulWidget {
  const ExpenseSubCategoryFormDialog({
    super.key,
    this.subCategory,
    required this.maxOrder,
  });

  final ExpenseSubCategory? subCategory;
  final int maxOrder;

  @override
  State<ExpenseSubCategoryFormDialog> createState() =>
      _ExpenseSubCategoryFormDialogState();
}

class _ExpenseSubCategoryFormDialogState
    extends State<ExpenseSubCategoryFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _orderController;
  String _selectedColor = '#6F4BFF';
  String? _selectedIcon;
  bool _isActive = true;

  final List<String> _colorOptions = [
    '#6F4BFF',
    '#5AD8A4',
    '#FF9800',
    '#2196F3',
    '#E91E63',
    '#9C27B0',
    '#00BCD4',
    '#4CAF50',
    '#FF5722',
    '#795548',
  ];

  final List<Map<String, String>> _iconOptions = [
    {'name': 'home', 'icon': '🏠'},
    {'name': 'wifi', 'icon': '📡'},
    {'name': 'car', 'icon': '🚗'},
    {'name': 'shopping', 'icon': '🛒'},
    {'name': 'food', 'icon': '🍔'},
    {'name': 'phone', 'icon': '📱'},
    {'name': 'laptop', 'icon': '💻'},
    {'name': 'tools', 'icon': '🔧'},
    {'name': 'money', 'icon': '💰'},
    {'name': 'receipt', 'icon': '🧾'},
    {'name': 'building', 'icon': '🏢'},
    {'name': 'gas', 'icon': '⛽'},
  ];

  @override
  void initState() {
    super.initState();
    final subCategory = widget.subCategory;
    _nameController = TextEditingController(text: subCategory?.name ?? '');
    _descriptionController =
        TextEditingController(text: subCategory?.description ?? '');
    _orderController = TextEditingController(
        text: subCategory?.order.toString() ?? widget.maxOrder.toString());
    _selectedColor = subCategory?.colorHex ?? '#6F4BFF';
    _selectedIcon = subCategory?.icon;
    _isActive = subCategory?.isActive ?? true;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _orderController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.subCategory != null;

    return AlertDialog(
      backgroundColor: AuthColors.surface,
      title: Text(
        isEditing ? 'Edit Sub-Category' : 'Add Sub-Category',
        style: const TextStyle(color: AuthColors.textMain),
      ),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _nameController,
                style: const TextStyle(color: AuthColors.textMain),
                decoration: _inputDecoration('Name *'),
                validator: (value) => (value == null || value.trim().isEmpty)
                    ? 'Enter sub-category name'
                    : null,
              ),
              const SizedBox(height: AppSpacing.paddingMD),
              TextFormField(
                controller: _descriptionController,
                style: const TextStyle(color: AuthColors.textMain),
                decoration: _inputDecoration('Description'),
                maxLines: 2,
              ),
              const SizedBox(height: AppSpacing.paddingMD),
              // Icon selector
              const Text(
                'Icon',
                style: TextStyle(color: AuthColors.textSub, fontSize: 14),
              ),
              const SizedBox(height: AppSpacing.paddingSM),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _iconOptions.map((iconOption) {
                  final isSelected = _selectedIcon == iconOption['name'];
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedIcon = iconOption['name'];
                      });
                    },
                    child: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: isSelected
                            ? Color(int.parse(_selectedColor.substring(1),
                                        radix: 16) +
                                    0xFF000000)
                            .withValues(alpha: 0.2)
                            : AuthColors.backgroundAlt,
                        borderRadius:
                            BorderRadius.circular(AppSpacing.radiusMD),
                        border: Border.all(
                          color: isSelected
                              ? Color(int.parse(_selectedColor.substring(1),
                                      radix: 16) +
                                  0xFF000000)
                              : AuthColors.textSubWithOpacity(0.24),
                          width: isSelected ? 2 : 1,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          iconOption['icon']!,
                          style: const TextStyle(fontSize: 24),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: AppSpacing.paddingLG),
              // Color selector
              const Text(
                'Color',
                style: TextStyle(color: AuthColors.textSub, fontSize: 14),
              ),
              const SizedBox(height: AppSpacing.paddingSM),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _colorOptions.map((color) {
                  final isSelected = _selectedColor == color;
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedColor = color;
                      });
                    },
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Color(int.parse(color.substring(1), radix: 16) +
                            0xFF000000),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected
                              ? AuthColors.textMain
                              : AuthColors.transparent,
                          width: isSelected ? 3 : 0,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: AppSpacing.paddingMD),
              TextFormField(
                controller: _orderController,
                style: const TextStyle(color: AuthColors.textMain),
                decoration: _inputDecoration('Display Order'),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Enter display order';
                  }
                  final order = int.tryParse(value);
                  if (order == null || order < 0) {
                    return 'Enter valid order number';
                  }
                  return null;
                },
              ),
              const SizedBox(height: AppSpacing.paddingMD),
              // Active toggle
              Row(
                children: [
                  const Text(
                    'Active',
                    style: TextStyle(color: AuthColors.textSub, fontSize: 14),
                  ),
                  const Spacer(),
                  Switch(
                    value: _isActive,
                    onChanged: (value) {
                      setState(() {
                        _isActive = value;
                      });
                    },
                    activeThumbColor: AuthColors.secondary,
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
          onPressed: _save,
          child: Text(isEditing ? 'Save' : 'Create'),
        ),
      ],
    );
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;

    final subCategory = ExpenseSubCategory(
      id: widget.subCategory?.id ?? '',
      organizationId: widget.subCategory?.organizationId ?? '',
      name: _nameController.text.trim(),
      description: _descriptionController.text.trim().isEmpty
          ? null
          : _descriptionController.text.trim(),
      icon: _selectedIcon,
      colorHex: _selectedColor,
      isActive: _isActive,
      order: int.parse(_orderController.text.trim()),
      createdAt: widget.subCategory?.createdAt ?? DateTime.now(),
      updatedAt: DateTime.now(),
      createdBy: widget.subCategory?.createdBy,
    );

    Navigator.of(context).pop(subCategory);
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
