import 'package:core_models/core_models.dart';
import 'package:core_datasources/core_datasources.dart';
import 'package:core_ui/core_ui.dart' show AuthColors, DashButton, DashButtonVariant, DashFormField, DashSnackbar, DashTheme;
import 'package:dash_web/data/repositories/employees_repository.dart';
import 'package:dash_web/data/repositories/products_repository.dart';
import 'package:dash_web/data/repositories/raw_materials_repository.dart';
import 'package:dash_web/presentation/blocs/production_batches/production_batches_cubit.dart';
import 'package:dash_web/presentation/widgets/production_batch_selector.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

extension FirstWhereOrNull<T> on List<T> {
  T? firstWhereOrNull(bool Function(T) test) {
    try {
      return firstWhere(test);
    } catch (e) {
      return null;
    }
  }
}

class ProductionBatchForm extends StatefulWidget {
  const ProductionBatchForm({
    super.key,
    required this.organizationId,
    required this.employeesRepository,
    required this.productsRepository,
    required this.rawMaterialsRepository,
    required this.wageSettingsRepository,
    this.batch,
  });

  final String organizationId;
  final EmployeesRepository employeesRepository;
  final ProductsRepository productsRepository;
  final RawMaterialsRepository rawMaterialsRepository;
  final WageSettingsRepository wageSettingsRepository;
  final ProductionBatch? batch;

  @override
  State<ProductionBatchForm> createState() => _ProductionBatchFormState();
}

class _ProductionBatchFormState extends State<ProductionBatchForm> {
  final _formKey = GlobalKey<FormState>();
  final _batchDateController = TextEditingController();
  final _bricksProducedController = TextEditingController();
  final _bricksStackedController = TextEditingController();
  final _notesController = TextEditingController();

  static final Map<String, List<OrganizationEmployee>> _employeesCache = {};
  static final Map<String, List<OrganizationProduct>> _productsCache = {};
  static final Map<String, WageSettings?> _wageSettingsCache = {};
  static final Map<String, List<RawMaterial>> _rawMaterialsCache = {};

  DateTime _batchDate = DateTime.now();
  String? _selectedMethodId;
  String? _selectedProductId;
  ProductionBatchTemplate? _selectedTemplate;
  Set<String> _selectedEmployeeIds = {};
  List<OrganizationEmployee> _employees = [];
  List<OrganizationProduct> _products = [];
  List<RawMaterial> _rawMaterials = [];
  WageSettings? _wageSettings;
  bool _isLoading = false;
  bool _isLoadingData = true;
  bool _useCustomEmployees = false;
  final Map<String, TextEditingController> _rawMaterialQtyControllers = {};
  final Set<String> _selectedRawMaterialIds = {};

  // Wage preview
  double? _totalWages;
  double? _wagePerEmployee;

  void _updateBatchDateDisplay() {
    _batchDateController.text =
        '${_batchDate.day}/${_batchDate.month}/${_batchDate.year}';
  }

  @override
  void initState() {
    super.initState();
    if (widget.batch != null) {
      _batchDate = widget.batch!.batchDate;
      _selectedMethodId = widget.batch!.methodId;
      _selectedProductId = widget.batch!.productId;
      _selectedEmployeeIds = Set.from(widget.batch!.employeeIds);
      _bricksProducedController.text =
          widget.batch!.totalBricksProduced.toString();
      _bricksStackedController.text =
          widget.batch!.totalBricksStacked.toString();
      _notesController.text = widget.batch!.notes ?? '';
      _totalWages = widget.batch!.totalWages;
      _wagePerEmployee = widget.batch!.wagePerEmployee;
      if (widget.batch!.rawMaterialsUsed != null) {
        for (final material in widget.batch!.rawMaterialsUsed!) {
          _selectedRawMaterialIds.add(material.materialId);
          _rawMaterialController(material.materialId).text =
              material.quantity.toString();
        }
      }
    }
    _updateBatchDateDisplay();
    _loadData();
  }

  @override
  void dispose() {
    _batchDateController.dispose();
    _bricksProducedController.dispose();
    _bricksStackedController.dispose();
    _notesController.dispose();
    for (final controller in _rawMaterialQtyControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoadingData = true);
    try {
      final cachedEmployees = _employeesCache[widget.organizationId];
      final cachedProducts = _productsCache[widget.organizationId];
      final cachedSettings = _wageSettingsCache[widget.organizationId];
      final cachedRawMaterials = _rawMaterialsCache[widget.organizationId];

      final employeesFuture = cachedEmployees != null
          ? Future.value(cachedEmployees)
          : widget.employeesRepository.fetchEmployees(widget.organizationId);
      final productsFuture = cachedProducts != null
          ? Future.value(cachedProducts)
          : widget.productsRepository.fetchProducts(widget.organizationId);
        final settingsFuture = cachedSettings != null
          ? Future.value(cachedSettings)
          : widget.wageSettingsRepository
              .fetchWageSettings(widget.organizationId);
        final rawMaterialsFuture = cachedRawMaterials != null
          ? Future.value(cachedRawMaterials)
          : widget.rawMaterialsRepository.fetchRawMaterials(widget.organizationId);

      final results = await Future.wait([
        employeesFuture,
        productsFuture,
        settingsFuture,
        rawMaterialsFuture,
      ]);

      final employees = results[0] as List<OrganizationEmployee>;
      final products = results[1] as List<OrganizationProduct>;
      final settings = results[2] as WageSettings?;
      final rawMaterials = results[3] as List<RawMaterial>;

      _employeesCache[widget.organizationId] = employees;
      _productsCache[widget.organizationId] = products;
      _wageSettingsCache[widget.organizationId] = settings;
      _rawMaterialsCache[widget.organizationId] = rawMaterials;

      if (!mounted) return;
      setState(() {
        _employees = _filterProductionEmployees(employees);
        _products =
            products.where((p) => p.status == ProductStatus.active).toList();
        _rawMaterials =
            rawMaterials.where((m) => m.status == RawMaterialStatus.active).toList();
        _wageSettings = settings;
        if (_selectedEmployeeIds.isNotEmpty) {
          final productionEmployeeIds = _employees.map((e) => e.id).toSet();
          _selectedEmployeeIds =
              _selectedEmployeeIds.intersection(productionEmployeeIds).toSet();
        }
        if (_wageSettings != null && _wageSettings!.enabled) {
          final productionMethods = _wageSettings!.calculationMethods.values
              .where((m) =>
                  m.enabled && m.methodType == WageMethodType.production)
              .toList();
          if (productionMethods.isNotEmpty && _selectedMethodId == null) {
            _selectedMethodId = productionMethods.first.methodId;
          }
        }
        _isLoadingData = false;
      });

      _updateWagePreview();
    } catch (e) {
      if (mounted) {
        DashSnackbar.show(context,
            message: 'Error loading data: $e', isError: true);
        setState(() => _isLoadingData = false);
      }
    }
  }

  List<OrganizationEmployee> _filterProductionEmployees(
    List<OrganizationEmployee> employees,
  ) {
    return employees.where((employee) {
      return employee.jobRoles.values.any(
            (jobRole) =>
                jobRole.jobRoleTitle.toLowerCase().contains('production'),
          ) ||
          employee.primaryJobRoleTitle.toLowerCase().contains('production');
    }).toList();
  }

  TextEditingController _rawMaterialController(String materialId) {
    return _rawMaterialQtyControllers.putIfAbsent(
      materialId,
      () => TextEditingController(),
    );
  }

  void _updateWagePreview() {
    if (_selectedMethodId == null ||
        _wageSettings == null ||
        _selectedEmployeeIds.isEmpty) {
      setState(() {
        _totalWages = null;
        _wagePerEmployee = null;
      });
      return;
    }

    final method = _wageSettings!.calculationMethods[_selectedMethodId];
    if (method == null || method.methodType != WageMethodType.production) {
      setState(() {
        _totalWages = null;
        _wagePerEmployee = null;
      });
      return;
    }

    final config = method.config as ProductionWageConfig;
    final bricksProduced = int.tryParse(_bricksProducedController.text) ?? 0;
    final bricksStacked = int.tryParse(_bricksStackedController.text) ?? 0;

    // Get product-specific pricing if available
    double productionPricePerUnit = config.productionPricePerUnit;
    double stackingPricePerUnit = config.stackingPricePerUnit;

    if (_selectedProductId != null &&
        config.productSpecificPricing != null &&
        config.productSpecificPricing!.containsKey(_selectedProductId)) {
      final productPricing =
          config.productSpecificPricing![_selectedProductId]!;
      productionPricePerUnit = productPricing.productionPricePerUnit;
      stackingPricePerUnit = productPricing.stackingPricePerUnit;
    }

    final totalWages = (bricksProduced * productionPricePerUnit) +
        (bricksStacked * stackingPricePerUnit);
    final wagePerEmployee = totalWages / _selectedEmployeeIds.length;

    setState(() {
      _totalWages = totalWages;
      _wagePerEmployee = wagePerEmployee;
    });
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _batchDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: DashTheme.light(),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _batchDate = picked;
        _updateBatchDateDisplay();
      });
    }
  }

  void _onTemplateSelected(ProductionBatchTemplate template) {
    setState(() {
      _selectedTemplate = template;
      final productionEmployeeIds = _employees.map((e) => e.id).toSet();
        _selectedEmployeeIds = Set<String>.from(template.employeeIds)
          .intersection(productionEmployeeIds)
          .toSet();
      _useCustomEmployees = false;
      
      // Pre-select the first production method if not already selected
      if (_selectedMethodId == null && _wageSettings != null && _wageSettings!.enabled) {
        final productionMethods = _wageSettings!.calculationMethods.values
            .where((m) => m.enabled && m.methodType == WageMethodType.production)
            .toList();
        if (productionMethods.isNotEmpty) {
          _selectedMethodId = productionMethods.first.methodId;
        }
      }
    });
    _updateWagePreview();
  }

  void _onCustomEmployeesSelected() {
    setState(() {
      _useCustomEmployees = true;
      _selectedTemplate = null;
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedMethodId == null) {
      DashSnackbar.show(context, message: 'Please select a wage method', isError: true);
      return;
    }

    if (_selectedEmployeeIds.isEmpty) {
      DashSnackbar.show(context, message: 'Please select at least one employee', isError: true);
      return;
    }

    // Validate wage calculation can be performed
    if (_totalWages == null || _wagePerEmployee == null) {
      DashSnackbar.show(context, message: 'Unable to calculate wages. Please check your inputs.', isError: true);
      return;
    }

    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      DashSnackbar.show(context, message: 'User not authenticated', isError: true);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final selectedEmployees = _employees
          .where((e) => _selectedEmployeeIds.contains(e.id))
          .toList();
      final employeeNames = selectedEmployees.map((e) => e.name).toList();
      final product = _products.firstWhereOrNull((p) => p.id == _selectedProductId);
      final rawMaterialsUsed = _rawMaterials
          .where((m) => _selectedRawMaterialIds.contains(m.id))
          .map((material) {
        final qtyText =
            _rawMaterialController(material.id).text.trim();
        final quantity = double.tryParse(qtyText) ?? 0;
        if (quantity <= 0) {
          return null;
        }
        return RawMaterialUsage(
          materialId: material.id,
          materialName: material.name,
          quantity: quantity,
          unitOfMeasurement: material.unitOfMeasurement,
        );
      }).whereType<RawMaterialUsage>().toList();

      final now = DateTime.now();
      final cubit = context.read<ProductionBatchesCubit>();

      if (widget.batch != null) {
        // Update existing batch with calculated wages
        await cubit.updateBatch(widget.batch!.batchId, {
          'batchDate': _batchDate,
          'methodId': _selectedMethodId!,
          'productId': _selectedProductId,
          'productName': product?.name,
          'totalBricksProduced': int.parse(_bricksProducedController.text),
          'totalBricksStacked': int.parse(_bricksStackedController.text),
          'employeeIds': _selectedEmployeeIds.toList(),
          'employeeNames': employeeNames,
          'rawMaterialsUsed': rawMaterialsUsed.map((m) => m.toJson()).toList(),
          'notes': _notesController.text.trim().isEmpty
              ? null
              : _notesController.text.trim(),
          'totalWages': _totalWages,
          'wagePerEmployee': _wagePerEmployee,
          'status': ProductionBatchStatus.calculated.name,
        });
      } else {
        // Create new batch with calculated wages
        final batch = ProductionBatch(
          batchId: '', // Will be set by data source
          organizationId: widget.organizationId,
          batchDate: _batchDate,
          methodId: _selectedMethodId!,
          totalBricksProduced: int.parse(_bricksProducedController.text),
          totalBricksStacked: int.parse(_bricksStackedController.text),
          employeeIds: _selectedEmployeeIds.toList(),
          employeeNames: employeeNames,
          status: ProductionBatchStatus.calculated, // Directly set to calculated
          createdBy: currentUser.uid,
          createdAt: now,
          updatedAt: now,
          productId: _selectedProductId,
          productName: product?.name,
          notes: _notesController.text.trim().isEmpty
              ? null
              : _notesController.text.trim(),
          totalWages: _totalWages,
          wagePerEmployee: _wagePerEmployee,
          rawMaterialsUsed: rawMaterialsUsed.isEmpty ? null : rawMaterialsUsed,
        );

        final batchId = await cubit.createBatch(batch);
        
        if (batchId.isEmpty) {
          throw Exception('Failed to create batch: batchId is empty');
        }
      }

      if (mounted) {
        Navigator.of(context).pop();
        DashSnackbar.show(
          context,
          message: widget.batch != null
              ? 'Batch updated and wages calculated successfully'
              : 'Batch created and wages calculated successfully',
          isError: false,
        );
      }
    } catch (e) {
      if (mounted) {
        DashSnackbar.show(context, message: 'Error: $e', isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final productName = _products
        .firstWhereOrNull((p) => p.id == _selectedProductId)
        ?.name;
    final produced = int.tryParse(_bricksProducedController.text) ?? 0;
    final stacked = int.tryParse(_bricksStackedController.text) ?? 0;
    final rawMaterialsSummary = _rawMaterials
        .where((m) => _selectedRawMaterialIds.contains(m.id))
        .map((material) {
      final qtyText = _rawMaterialController(material.id).text.trim();
      final quantity = double.tryParse(qtyText) ?? 0;
      if (quantity <= 0) return null;
      return RawMaterialUsage(
        materialId: material.id,
        materialName: material.name,
        quantity: quantity,
        unitOfMeasurement: material.unitOfMeasurement,
      );
    }).whereType<RawMaterialUsage>().toList();

    Widget buildSectionCard({
      required String title,
      required Widget child,
      IconData? icon,
    }) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AuthColors.textMainWithOpacity(0.03),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AuthColors.textMainWithOpacity(0.08),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (icon != null)
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AuthColors.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icon, color: AuthColors.primary, size: 18),
                  ),
                if (icon != null) const SizedBox(width: 10),
                Text(
                  title,
                  style: const TextStyle(
                    color: AuthColors.textMain,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            child,
          ],
        ),
      );
    }

    return Dialog(
      backgroundColor: AuthColors.transparent,
      insetPadding: const EdgeInsets.all(20),
      child: Container(
        width: 980,
        constraints: const BoxConstraints(maxHeight: 850),
        decoration: BoxDecoration(
          color: AuthColors.surface,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: AuthColors.background.withValues(alpha: 0.5),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(24, 24, 16, 16),
                decoration: BoxDecoration(
                  color: AuthColors.textMainWithOpacity(0.02),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(24),
                  ),
                  border: Border(
                    bottom: BorderSide(
                      color: AuthColors.textMainWithOpacity(0.08),
                    ),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.batch != null
                                ? 'Update Production Batch'
                                : 'Create Production Batch',
                            style: const TextStyle(
                              color: AuthColors.textMain,
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Capture quantities, employees, and materials. Wages preview updates live.',
                            style: TextStyle(
                              color: AuthColors.textMainWithOpacity(0.7),
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close, color: AuthColors.textSub),
                      tooltip: 'Close',
                    ),
                  ],
                ),
              ),
              Expanded(
                child: _isLoadingData
                    ? const Center(
                        child: CircularProgressIndicator(),
                      )
                    : LayoutBuilder(
                        builder: (context, constraints) {
                          final isWide = constraints.maxWidth >= 900;
                          final leftColumn = Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              buildSectionCard(
                                title: 'Production Details',
                                icon: Icons.factory_outlined,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: InkWell(
                                            onTap: _selectDate,
                                            borderRadius:
                                                BorderRadius.circular(14),
                                            child: IgnorePointer(
                                              child: DashFormField(
                                                controller: _batchDateController,
                                                label: 'Batch Date',
                                                readOnly: true,
                                                prefix: const Icon(
                                                  Icons.calendar_today,
                                                  color: AuthColors.textSub,
                                                ),
                                                style: const TextStyle(
                                                  color: AuthColors.textMain,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 16),
                                    DropdownButtonFormField<String>(
                                      initialValue: _selectedProductId,
                                      decoration: InputDecoration(
                                        labelText: 'Product (Optional)',
                                        labelStyle:
                                            const TextStyle(color: AuthColors.textSub),
                                        filled: true,
                                        fillColor:
                                            AuthColors.textMainWithOpacity(0.05),
                                        border: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(12),
                                          borderSide: BorderSide(
                                            color: AuthColors.textMainWithOpacity(0.2),
                                          ),
                                        ),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(12),
                                          borderSide: BorderSide(
                                            color: AuthColors.textMainWithOpacity(0.2),
                                          ),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(12),
                                          borderSide: const BorderSide(
                                            color: AuthColors.primary,
                                            width: 2,
                                          ),
                                        ),
                                      ),
                                      dropdownColor: AuthColors.surface,
                                      style: const TextStyle(
                                        color: AuthColors.textMain,
                                      ),
                                      items: [
                                        const DropdownMenuItem<String>(
                                          value: null,
                                          child: Text('No Product'),
                                        ),
                                        ..._products.map((product) {
                                          return DropdownMenuItem<String>(
                                            value: product.id,
                                            child: Text(product.name),
                                          );
                                        }),
                                      ],
                                      onChanged: (value) {
                                        setState(() {
                                          _selectedProductId = value;
                                        });
                                        _updateWagePreview();
                                      },
                                    ),
                                    const SizedBox(height: 16),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: DashFormField(
                                            controller: _bricksProducedController,
                                            label: 'Bricks Produced (Y) *',
                                            keyboardType: TextInputType.number,
                                            style: const TextStyle(
                                              color: AuthColors.textMain,
                                            ),
                                            validator: (value) {
                                              if (value == null || value.isEmpty) {
                                                return 'Please enter bricks produced';
                                              }
                                              if (int.tryParse(value) == null ||
                                                  int.parse(value) < 0) {
                                                return 'Please enter a valid number';
                                              }
                                              return null;
                                            },
                                            onChanged: (_) => _updateWagePreview(),
                                          ),
                                        ),
                                        const SizedBox(width: 16),
                                        Expanded(
                                          child: DashFormField(
                                            controller: _bricksStackedController,
                                            label: 'Bricks Stacked (Z) *',
                                            keyboardType: TextInputType.number,
                                            style: const TextStyle(
                                              color: AuthColors.textMain,
                                            ),
                                            validator: (value) {
                                              if (value == null || value.isEmpty) {
                                                return 'Please enter bricks stacked';
                                              }
                                              if (int.tryParse(value) == null ||
                                                  int.parse(value) < 0) {
                                                return 'Please enter a valid number';
                                              }
                                              return null;
                                            },
                                            onChanged: (_) => _updateWagePreview(),
                                          ),
                                        ),
                                      ],
                                    ),
                                    if (_selectedMethodId != null &&
                                        _wageSettings != null) ...[
                                      const SizedBox(height: 16),
                                      Container(
                                        padding: const EdgeInsets.all(16),
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                            colors: [
                                              AuthColors.primary
                                                  .withValues(alpha: 0.12),
                                              AuthColors.secondary
                                                  .withValues(alpha: 0.08),
                                            ],
                                          ),
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(
                                            color: AuthColors.primary
                                                .withValues(alpha: 0.35),
                                          ),
                                        ),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            const Text(
                                              'Wage Preview',
                                              style: TextStyle(
                                                color: AuthColors.textMain,
                                                fontSize: 14,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                            const SizedBox(height: 10),
                                            if (_totalWages != null &&
                                                _wagePerEmployee != null)
                                              Row(
                                                children: [
                                                  Expanded(
                                                    child: _SummaryTile(
                                                      label: 'Total Wages',
                                                      value:
                                                          '₹${_totalWages!.toStringAsFixed(4)}',
                                                    ),
                                                  ),
                                                  const SizedBox(width: 12),
                                                  Expanded(
                                                    child: _SummaryTile(
                                                      label: 'Per Employee',
                                                      value:
                                                          '₹${_wagePerEmployee!.toStringAsFixed(4)}',
                                                    ),
                                                  ),
                                                ],
                                              )
                                            else
                                              Text(
                                                'Enter quantities and select employees to calculate wages.',
                                                style: TextStyle(
                                                  color: AuthColors.textSub,
                                                  fontSize: 12,
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              const SizedBox(height: 20),
                              buildSectionCard(
                                title: 'Raw Materials Used',
                                icon: Icons.science_outlined,
                                child: _rawMaterials.isEmpty
                                    ? Text(
                                        'No raw materials found for this organization.',
                                        style: TextStyle(
                                          color: AuthColors.textSub,
                                          fontSize: 12,
                                        ),
                                      )
                                    : Container(
                                        constraints:
                                            const BoxConstraints(maxHeight: 130),
                                        decoration: BoxDecoration(
                                          color: AuthColors.textMainWithOpacity(0.03),
                                          borderRadius:
                                              BorderRadius.circular(12),
                                          border: Border.all(
                                            color: AuthColors.textMain
                                                .withOpacity(0.08),
                                          ),
                                        ),
                                        child: ListView.separated(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 6,
                                          ),
                                          itemCount: _rawMaterials.length,
                                          separatorBuilder: (_, __) =>
                                              const SizedBox(height: 6),
                                          itemBuilder: (context, index) {
                                            final material = _rawMaterials[index];
                                            final isSelected =
                                                _selectedRawMaterialIds
                                                    .contains(material.id);
                                            final qtyController =
                                                _rawMaterialController(material.id);
                                            return Row(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.center,
                                              children: [
                                                Checkbox(
                                                  value: isSelected,
                                                  onChanged: (value) {
                                                    setState(() {
                                                      if (value == true) {
                                                        _selectedRawMaterialIds
                                                            .add(material.id);
                                                      } else {
                                                        _selectedRawMaterialIds
                                                            .remove(material.id);
                                                        qtyController.text = '';
                                                      }
                                                    });
                                                  },
                                                  activeColor: AuthColors.primary,
                                                  checkColor: AuthColors.textMain,
                                                  materialTapTargetSize:
                                                      MaterialTapTargetSize.shrinkWrap,
                                                  visualDensity: VisualDensity.compact,
                                                ),
                                                Expanded(
                                                  child: Text(
                                                    material.name,
                                                    style: const TextStyle(
                                                      color: AuthColors.textMain,
                                                      fontWeight: FontWeight.w600,
                                                      fontSize: 12,
                                                    ),
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ),
                                                if (material.unitOfMeasurement
                                                    .isNotEmpty) ...[
                                                  const SizedBox(width: 6),
                                                  Text(
                                                    material.unitOfMeasurement,
                                                    style: TextStyle(
                                                      color: AuthColors
                                                          .textMainWithOpacity(0.6),
                                                      fontSize: 10,
                                                    ),
                                                  ),
                                                ],
                                                const SizedBox(width: 8),
                                                SizedBox(
                                                  width: 78,
                                                  child: TextField(
                                                    controller: qtyController,
                                                    enabled: isSelected,
                                                    keyboardType:
                                                        const TextInputType
                                                            .numberWithOptions(
                                                      decimal: true,
                                                    ),
                                                    decoration: InputDecoration(
                                                      labelText: 'Qty',
                                                      labelStyle: TextStyle(
                                                        color: AuthColors.textSub,
                                                        fontSize: 10,
                                                      ),
                                                      filled: true,
                                                      fillColor: AuthColors
                                                          .textMainWithOpacity(0.05),
                                                      border: OutlineInputBorder(
                                                        borderRadius:
                                                            BorderRadius.circular(8),
                                                        borderSide: BorderSide(
                                                          color: AuthColors
                                                              .textMainWithOpacity(0.2),
                                                        ),
                                                      ),
                                                      enabledBorder: OutlineInputBorder(
                                                        borderRadius:
                                                            BorderRadius.circular(8),
                                                        borderSide: BorderSide(
                                                          color: AuthColors
                                                              .textMainWithOpacity(0.2),
                                                        ),
                                                      ),
                                                      focusedBorder: OutlineInputBorder(
                                                        borderRadius:
                                                            BorderRadius.circular(8),
                                                        borderSide: const BorderSide(
                                                          color: AuthColors.primary,
                                                          width: 2,
                                                        ),
                                                      ),
                                                      contentPadding:
                                                          const EdgeInsets.symmetric(
                                                        horizontal: 6,
                                                        vertical: 4,
                                                      ),
                                                    ),
                                                    style: const TextStyle(
                                                      color: AuthColors.textMain,
                                                      fontSize: 11,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            );
                                          },
                                        ),
                                      ),
                              ),
                              const SizedBox(height: 20),
                              buildSectionCard(
                                title: 'Employees',
                                icon: Icons.groups_outlined,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    ProductionBatchSelector(
                                      organizationId: widget.organizationId,
                                      repository: context
                                          .read<ProductionBatchTemplatesRepository>(),
                                      selectedTemplateId: _selectedTemplate?.batchId,
                                      onTemplateSelected: _onTemplateSelected,
                                      onCustomSelected: _onCustomEmployeesSelected,
                                    ),
                                    const SizedBox(height: 16),
                                    if (_selectedTemplate != null ||
                                        _useCustomEmployees) ...[
                                      Container(
                                        constraints:
                                            const BoxConstraints(maxHeight: 200),
                                        decoration: BoxDecoration(
                                          color: AuthColors.textMainWithOpacity(0.04),
                                          borderRadius:
                                              BorderRadius.circular(12),
                                          border: Border.all(
                                            color: AuthColors.textMain
                                                .withOpacity(0.08),
                                          ),
                                        ),
                                        child: Builder(
                                          builder: (context) {
                                            final employeesToShow =
                                                _selectedTemplate != null
                                                    ? _employees.where(
                                                        (e) => _selectedTemplate!
                                                            .employeeIds
                                                            .contains(e.id),
                                                      )
                                                    : _employees;

                                            if (employeesToShow.isEmpty) {
                                              return const Center(
                                                child: Padding(
                                                  padding: EdgeInsets.all(16.0),
                                                  child: Text(
                                                    'No employees found',
                                                    style: TextStyle(
                                                      color: AuthColors.textSub,
                                                    ),
                                                  ),
                                                ),
                                              );
                                            }

                                            return SingleChildScrollView(
                                              padding: const EdgeInsets.all(12),
                                              child: Wrap(
                                                spacing: 8,
                                                runSpacing: 8,
                                                children:
                                                    employeesToShow.map((employee) {
                                                  final isSelected =
                                                      _selectedEmployeeIds
                                                          .contains(employee.id);
                                                  return Material(
                                                    color: Colors.transparent,
                                                    child: InkWell(
                                                      onTap: () {
                                                        setState(() {
                                                          if (isSelected) {
                                                            _selectedEmployeeIds
                                                                .remove(employee.id);
                                                          } else {
                                                            _selectedEmployeeIds
                                                                .add(employee.id);
                                                          }
                                                        });
                                                        _updateWagePreview();
                                                      },
                                                      borderRadius:
                                                          BorderRadius.circular(10),
                                                      child: Container(
                                                        padding: const EdgeInsets
                                                            .symmetric(
                                                          horizontal: 14,
                                                          vertical: 10,
                                                        ),
                                                        decoration: BoxDecoration(
                                                          color: isSelected
                                                              ? AuthColors.primary
                                                                  .withValues(
                                                                    alpha: 0.15,
                                                                  )
                                                              : AuthColors.textMain
                                                                  .withOpacity(0.05),
                                                          border: Border.all(
                                                            color: isSelected
                                                                ? AuthColors.primary
                                                                : AuthColors.textMain
                                                                    .withOpacity(0.15),
                                                            width: isSelected ? 2 : 1,
                                                          ),
                                                          borderRadius:
                                                              BorderRadius.circular(
                                                                10,
                                                              ),
                                                        ),
                                                        child: Row(
                                                          mainAxisSize:
                                                              MainAxisSize.min,
                                                          children: [
                                                            if (isSelected)
                                                              Container(
                                                                margin:
                                                                    const EdgeInsets
                                                                        .only(
                                                                      right: 8,
                                                                    ),
                                                                padding:
                                                                    const EdgeInsets
                                                                        .all(3),
                                                                decoration:
                                                                    BoxDecoration(
                                                                  color: AuthColors
                                                                      .primary,
                                                                  borderRadius:
                                                                      BorderRadius
                                                                          .circular(
                                                                            4,
                                                                          ),
                                                                ),
                                                                child: const Icon(
                                                                  Icons.check,
                                                                  size: 14,
                                                                  color: AuthColors
                                                                      .surface,
                                                                ),
                                                              ),
                                                            Text(
                                                              employee.name,
                                                              style: TextStyle(
                                                                color: isSelected
                                                                    ? AuthColors
                                                                        .textMain
                                                                    : AuthColors
                                                                        .textSub,
                                                                fontSize: 13,
                                                                fontWeight:
                                                                    isSelected
                                                                        ? FontWeight
                                                                            .w600
                                                                        : FontWeight
                                                                            .w500,
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                    ),
                                                  );
                                                }).toList(),
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        '${_selectedEmployeeIds.length} employee${_selectedEmployeeIds.length != 1 ? 's' : ''} selected',
                                        style: TextStyle(
                                          color:
                                              AuthColors.textMainWithOpacity(0.7),
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              const SizedBox(height: 20),
                              buildSectionCard(
                                title: 'Notes',
                                icon: Icons.note_alt_outlined,
                                child: DashFormField(
                                  controller: _notesController,
                                  label: 'Notes (Optional)',
                                  maxLines: 3,
                                  style: const TextStyle(
                                    color: AuthColors.textMain,
                                  ),
                                ),
                              ),
                            ],
                          );

                          final summaryCard = Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: AuthColors.textMainWithOpacity(0.03),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: AuthColors.textMainWithOpacity(0.08),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Summary',
                                  style: TextStyle(
                                    color: AuthColors.textMain,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 14),
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: AuthColors.textMainWithOpacity(0.05),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: AuthColors.textMainWithOpacity(0.08),
                                    ),
                                  ),
                                  child: Column(
                                    children: [
                                      _SummaryRow(
                                        label: 'Total Wages',
                                        value: _totalWages == null
                                            ? '—'
                                            : '₹${_totalWages!.toStringAsFixed(4)}',
                                        isEmphasis: true,
                                      ),
                                      const SizedBox(height: 8),
                                      _SummaryRow(
                                        label: 'Per Employee',
                                        value: _wagePerEmployee == null
                                            ? '—'
                                            : '₹${_wagePerEmployee!.toStringAsFixed(4)}',
                                      ),
                                      const Divider(height: 18),
                                      _SummaryRow(
                                        label: 'Employees',
                                        value: '${_selectedEmployeeIds.length}',
                                      ),
                                      const SizedBox(height: 6),
                                      _SummaryRow(
                                        label: 'Bricks Produced',
                                        value: produced.toString(),
                                      ),
                                      const SizedBox(height: 6),
                                      _SummaryRow(
                                        label: 'Bricks Stacked',
                                        value: stacked.toString(),
                                      ),
                                      const SizedBox(height: 6),
                                      _SummaryRow(
                                        label: 'Product',
                                        value: productName ?? 'None',
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 14),
                                Text(
                                  'Raw Materials',
                                  style: TextStyle(
                                    color: AuthColors.textSub,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                if (rawMaterialsSummary.isEmpty)
                                  Text(
                                    'No materials selected',
                                    style: TextStyle(
                                      color: AuthColors.textMainWithOpacity(0.6),
                                      fontSize: 12,
                                    ),
                                  )
                                else
                                  ...rawMaterialsSummary.map((item) => Padding(
                                        padding:
                                            const EdgeInsets.only(bottom: 6),
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Expanded(
                                              child: Text(
                                                item.materialName,
                                                style: const TextStyle(
                                                  color: AuthColors.textMain,
                                                  fontSize: 12,
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              '${item.quantity}${item.unitOfMeasurement?.isNotEmpty == true ? ' ${item.unitOfMeasurement}' : ''}',
                                              style: TextStyle(
                                                color: AuthColors.textSub,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ],
                                        ),
                                      )),
                              ],
                            ),
                          );

                          if (!isWide) {
                            return SingleChildScrollView(
                              padding: const EdgeInsets.all(24),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  summaryCard,
                                  const SizedBox(height: 20),
                                  leftColumn,
                                ],
                              ),
                            );
                          }

                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                flex: 3,
                                child: SingleChildScrollView(
                                  padding:
                                      const EdgeInsets.fromLTRB(24, 24, 16, 24),
                                  child: leftColumn,
                                ),
                              ),
                              Expanded(
                                flex: 2,
                                child: SingleChildScrollView(
                                  padding:
                                      const EdgeInsets.fromLTRB(8, 24, 24, 24),
                                  child: summaryCard,
                                ),
                              ),
                            ],
                          );
                        },
                      ),
              ),
              // Footer with Actions
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AuthColors.textMainWithOpacity(0.03),
                  border: Border(
                    top: BorderSide(
                      color: AuthColors.textMainWithOpacity(0.1),
                      width: 1,
                    ),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    if (_totalWages != null && _wagePerEmployee != null)
                      Row(
                        children: [
                          const Icon(
                            Icons.info_outline,
                            size: 16,
                            color: AuthColors.textSub,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Wages calculated: ₹${_totalWages!.toStringAsFixed(4)} total',
                            style: TextStyle(
                              color: AuthColors.textMainWithOpacity(0.7),
                              fontSize: 13,
                            ),
                          ),
                        ],
                      )
                    else
                      const SizedBox.shrink(),
                    Row(
                      children: [
                        DashButton(
                          label: 'Cancel',
                          onPressed: _isLoading
                              ? null
                              : () => Navigator.of(context).pop(),
                          variant: DashButtonVariant.text,
                        ),
                        const SizedBox(width: 12),
                        DashButton(
                          label:
                              widget.batch != null ? 'Update Batch' : 'Create Batch',
                          icon: widget.batch != null
                              ? Icons.update_outlined
                              : Icons.check_circle_outline,
                          onPressed:
                              (_isLoading || _totalWages == null) ? null : _submit,
                          isLoading: _isLoading,
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
    );
  }
}

class _SummaryTile extends StatelessWidget {
  const _SummaryTile({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AuthColors.textMainWithOpacity(0.05),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: AuthColors.textMainWithOpacity(0.7),
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              color: AuthColors.textMain,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.label,
    required this.value,
    this.isEmphasis = false,
  });

  final String label;
  final String value;
  final bool isEmphasis;

  @override
  Widget build(BuildContext context) {
    final valueStyle = isEmphasis
        ? const TextStyle(
            color: AuthColors.textMain,
            fontSize: 15,
            fontWeight: FontWeight.w700,
          )
        : const TextStyle(
            color: AuthColors.textMain,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          );
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: AuthColors.textMainWithOpacity(0.7),
              fontSize: 12,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(value, style: valueStyle),
      ],
    );
  }
}

