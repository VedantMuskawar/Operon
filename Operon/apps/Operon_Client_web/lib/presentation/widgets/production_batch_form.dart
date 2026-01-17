import 'package:core_models/core_models.dart';
import 'package:core_datasources/core_datasources.dart';
import 'package:dash_web/data/repositories/employees_repository.dart';
import 'package:dash_web/data/repositories/products_repository.dart';
import 'package:dash_web/domain/entities/organization_employee.dart';
import 'package:dash_web/presentation/blocs/production_batches/production_batches_cubit.dart';
import 'package:dash_web/presentation/widgets/production_batch_selector.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
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
    required this.wageSettingsRepository,
    this.batch,
  });

  final String organizationId;
  final EmployeesRepository employeesRepository;
  final ProductsRepository productsRepository;
  final WageSettingsRepository wageSettingsRepository;
  final ProductionBatch? batch;

  @override
  State<ProductionBatchForm> createState() => _ProductionBatchFormState();
}

class _ProductionBatchFormState extends State<ProductionBatchForm> {
  final _formKey = GlobalKey<FormState>();
  final _bricksProducedController = TextEditingController();
  final _bricksStackedController = TextEditingController();
  final _notesController = TextEditingController();

  DateTime _batchDate = DateTime.now();
  String? _selectedMethodId;
  String? _selectedProductId;
  ProductionBatchTemplate? _selectedTemplate;
  Set<String> _selectedEmployeeIds = {};
  List<OrganizationEmployee> _employees = [];
  List<OrganizationProduct> _products = [];
  WageSettings? _wageSettings;
  bool _isLoading = false;
  bool _isLoadingData = true;
  bool _useCustomEmployees = false;

  // Wage preview
  double? _totalWages;
  double? _wagePerEmployee;

  @override
  void initState() {
    super.initState();
    if (widget.batch != null) {
      _batchDate = widget.batch!.batchDate;
      _selectedMethodId = widget.batch!.methodId;
      _selectedProductId = widget.batch!.productId;
      _selectedEmployeeIds = Set.from(widget.batch!.employeeIds);
      _bricksProducedController.text = widget.batch!.totalBricksProduced.toString();
      _bricksStackedController.text = widget.batch!.totalBricksStacked.toString();
      _notesController.text = widget.batch!.notes ?? '';
      _totalWages = widget.batch!.totalWages;
      _wagePerEmployee = widget.batch!.wagePerEmployee;
    }
    _loadData();
  }

  @override
  void dispose() {
    _bricksProducedController.dispose();
    _bricksStackedController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoadingData = true);
    try {
      final employees = await widget.employeesRepository.fetchEmployees(widget.organizationId);
      final products = await widget.productsRepository.fetchProducts(widget.organizationId);
      final settings = await widget.wageSettingsRepository.fetchWageSettings(widget.organizationId);

      setState(() {
        _employees = employees;
        _products = products.where((p) => p.status == ProductStatus.active).toList();
        _wageSettings = settings;
        if (_wageSettings != null && _wageSettings!.enabled) {
          final productionMethods = _wageSettings!.calculationMethods.values
              .where((m) => m.enabled && m.methodType == WageMethodType.production)
              .toList();
          if (productionMethods.isNotEmpty && _selectedMethodId == null) {
            _selectedMethodId = productionMethods.first.methodId;
          }
        }
        _isLoadingData = false;
      });
      
      // Debug: Print wage settings status
      if (kDebugMode) {
        print('Wage Settings loaded: ${settings != null}');
        if (settings != null) {
          print('Wage Settings enabled: ${settings.enabled}');
          final productionMethods = settings.calculationMethods.values
              .where((m) => m.enabled && m.methodType == WageMethodType.production)
              .toList();
          print('Production methods found: ${productionMethods.length}');
          print('Selected method ID: $_selectedMethodId');
        }
      }

      _updateWagePreview();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading data: $e')),
        );
        setState(() => _isLoadingData = false);
      }
    }
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
      final productPricing = config.productSpecificPricing![_selectedProductId]!;
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
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFF6F4BFF),
              onPrimary: Colors.white,
              surface: Color(0xFF1B1B2C),
              onSurface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _batchDate = picked;
      });
    }
  }

  void _onTemplateSelected(ProductionBatchTemplate template) {
    setState(() {
      _selectedTemplate = template;
      _selectedEmployeeIds = Set.from(template.employeeIds);
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a wage method')),
      );
      return;
    }

    if (_selectedEmployeeIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one employee')),
      );
      return;
    }

    // Validate wage calculation can be performed
    if (_totalWages == null || _wagePerEmployee == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to calculate wages. Please check your inputs.')),
      );
      return;
    }

    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User not authenticated')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final selectedEmployees = _employees
          .where((e) => _selectedEmployeeIds.contains(e.id))
          .toList();
      final employeeNames = selectedEmployees.map((e) => e.name).toList();
      final product = _products.firstWhereOrNull((p) => p.id == _selectedProductId);

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
        );

        final batchId = await cubit.createBatch(batch);
        
        if (kDebugMode) {
          print('[ProductionBatchForm] Created batch with ID: $batchId');
        }
        
        if (batchId.isEmpty) {
          throw Exception('Failed to create batch: batchId is empty');
        }
      }

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.batch != null
                ? 'Batch updated and wages calculated successfully'
                : 'Batch created and wages calculated successfully'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(20),
      child: Container(
        width: 750,
        constraints: const BoxConstraints(maxHeight: 850),
        decoration: BoxDecoration(
          color: const Color(0xFF1B1B2C),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.5),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: _isLoadingData
            ? const Center(
                child: Padding(
                  padding: EdgeInsets.all(40),
                  child: CircularProgressIndicator(),
                ),
              )
            : Form(
                key: _formKey,
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
                            color: Colors.white.withValues(alpha: 0.1),
                            width: 1,
                          ),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0xFF6F4BFF).withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.inventory_2_outlined,
                              color: Color(0xFF6F4BFF),
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.batch != null
                                      ? 'Edit Production Batch'
                                      : 'Create Production Batch',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Record production data and calculate wages',
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.6),
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
                                color: Colors.white.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.close, color: Colors.white70, size: 20),
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
                            // Batch Date
                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    readOnly: true,
                                    controller: TextEditingController(
                                      text: '${_batchDate.day}/${_batchDate.month}/${_batchDate.year}',
                                    ),
                                    decoration: InputDecoration(
                                      labelText: 'Batch Date',
                                      labelStyle: const TextStyle(color: Colors.white70),
                                      suffixIcon: const Icon(Icons.calendar_today,
                                          color: Colors.white70),
                                      filled: true,
                                      fillColor: Colors.white.withValues(alpha: 0.05),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide(
                                          color: Colors.white.withValues(alpha: 0.2),
                                        ),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide(
                                          color: Colors.white.withValues(alpha: 0.2),
                                        ),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: const BorderSide(
                                          color: Color(0xFF6F4BFF),
                                          width: 2,
                                        ),
                                      ),
                                    ),
                                    style: const TextStyle(color: Colors.white),
                                    onTap: _selectDate,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 24),
                            // Wage Method
                            DropdownButtonFormField<String>(
                              value: _selectedMethodId,
                              decoration: InputDecoration(
                                labelText: 'Wage Method *',
                                labelStyle: const TextStyle(color: Colors.white70),
                                filled: true,
                                fillColor: Colors.white.withValues(alpha: 0.05),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                    color: Colors.white.withValues(alpha: 0.2),
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                    color: Colors.white.withValues(alpha: 0.2),
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(
                                    color: Color(0xFF6F4BFF),
                                    width: 2,
                                  ),
                                ),
                              ),
                              dropdownColor: const Color(0xFF1B1B2C),
                              style: const TextStyle(color: Colors.white),
                              items: () {
                                if (_wageSettings == null) {
                                  return [
                                    const DropdownMenuItem<String>(
                                      value: null,
                                      child: Text(
                                        'Loading wage settings...',
                                        style: TextStyle(
                                          color: Colors.white54,
                                          fontStyle: FontStyle.italic,
                                        ),
                                      ),
                                    ),
                                  ];
                                }
                                
                                if (!_wageSettings!.enabled) {
                                  return [
                                    const DropdownMenuItem<String>(
                                      value: null,
                                      child: Text(
                                        'Wage settings disabled',
                                        style: TextStyle(
                                          color: Colors.white54,
                                          fontStyle: FontStyle.italic,
                                        ),
                                      ),
                                    ),
                                  ];
                                }
                                
                                final productionMethods = _wageSettings!.calculationMethods.values
                                    .where((m) =>
                                        m.enabled &&
                                        m.methodType == WageMethodType.production)
                                    .toList();
                                
                                if (productionMethods.isEmpty) {
                                  return [
                                    const DropdownMenuItem<String>(
                                      value: null,
                                      child: Text(
                                        'No production methods available',
                                        style: TextStyle(
                                          color: Colors.white54,
                                          fontStyle: FontStyle.italic,
                                        ),
                                      ),
                                    ),
                                  ];
                                }
                                
                                return productionMethods.map((method) {
                                  return DropdownMenuItem<String>(
                                    value: method.methodId,
                                    child: Text(method.name),
                                  );
                                }).toList();
                              }(),
                              onChanged: _wageSettings != null &&
                                      _wageSettings!.enabled &&
                                      _wageSettings!.calculationMethods.values
                                          .any((m) =>
                                              m.enabled &&
                                              m.methodType ==
                                                  WageMethodType.production)
                                  ? (value) {
                                      setState(() {
                                        _selectedMethodId = value;
                                      });
                                      _updateWagePreview();
                                    }
                                  : null,
                              validator: (value) {
                                if (value == null) {
                                  if (_wageSettings == null) {
                                    return 'Wage settings not loaded';
                                  }
                                  if (!_wageSettings!.enabled) {
                                    return 'Wage settings are disabled';
                                  }
                                  return 'Please select a wage method';
                                }
                                return null;
                              },
                            ),
                            if (_wageSettings == null ||
                                !_wageSettings!.enabled ||
                                _wageSettings!.calculationMethods.values
                                    .where((m) =>
                                        m.enabled &&
                                        m.methodType == WageMethodType.production)
                                    .isEmpty) ...[
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.orange.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: Colors.orange.withValues(alpha: 0.3),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.info_outline,
                                      size: 18,
                                      color: Colors.orange.withValues(alpha: 0.8),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        _wageSettings == null
                                            ? 'Wage settings are not loaded. Please configure wage settings first.'
                                            : !_wageSettings!.enabled
                                                ? 'Wage settings are disabled. Please enable wage settings first.'
                                                : 'No production wage methods are enabled. Please enable at least one production method in wage settings.',
                                        style: TextStyle(
                                          color: Colors.orange.withValues(alpha: 0.9),
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                            const SizedBox(height: 24),
                            // Product (optional)
                            DropdownButtonFormField<String>(
                              value: _selectedProductId,
                              decoration: InputDecoration(
                                labelText: 'Product (Optional)',
                                labelStyle: const TextStyle(color: Colors.white70),
                                filled: true,
                                fillColor: Colors.white.withValues(alpha: 0.05),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                    color: Colors.white.withValues(alpha: 0.2),
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                    color: Colors.white.withValues(alpha: 0.2),
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(
                                    color: Color(0xFF6F4BFF),
                                    width: 2,
                                  ),
                                ),
                              ),
                              dropdownColor: const Color(0xFF1B1B2C),
                              style: const TextStyle(color: Colors.white),
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
                            const SizedBox(height: 24),
                            // Batch Template Selector
                            ProductionBatchSelector(
                              organizationId: widget.organizationId,
                              repository: context.read<ProductionBatchTemplatesRepository>(),
                              selectedTemplateId: _selectedTemplate?.batchId,
                              onTemplateSelected: _onTemplateSelected,
                              onCustomSelected: _onCustomEmployeesSelected,
                            ),
                            const SizedBox(height: 24),
                            // Employee Selection (always show when template is selected or custom mode)
                            if (_selectedTemplate != null || _useCustomEmployees) ...[
                              Text(
                                _selectedTemplate != null
                                    ? 'Employees in Batch (${_selectedEmployeeIds.length})'
                                    : 'Select Employees',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Container(
                                constraints: const BoxConstraints(maxHeight: 200),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.05),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.2),
                                  ),
                                ),
                                child: Builder(
                                  builder: (context) {
                                    // If template is selected, show only template employees
                                    // Otherwise show all employees (custom mode)
                                    final employeesToShow = _selectedTemplate != null
                                        ? _employees.where((e) => 
                                            _selectedTemplate!.employeeIds.contains(e.id))
                                        : _employees;
                                    
                                    if (employeesToShow.isEmpty) {
                                      return const Center(
                                        child: Padding(
                                          padding: EdgeInsets.all(16.0),
                                          child: Text(
                                            'No employees found',
                                            style: TextStyle(color: Colors.white70),
                                          ),
                                        ),
                                      );
                                    }
                                    
                                    return ListView.builder(
                                      shrinkWrap: true,
                                      itemCount: employeesToShow.length,
                                      itemBuilder: (context, index) {
                                        final employee = employeesToShow.elementAt(index);
                                        final isSelected =
                                            _selectedEmployeeIds.contains(employee.id);
                                        return CheckboxListTile(
                                          title: Text(
                                            employee.name,
                                            style: const TextStyle(color: Colors.white),
                                          ),
                                          subtitle: employee.primaryJobRoleTitle.isNotEmpty
                                              ? Text(
                                                  employee.primaryJobRoleTitle,
                                                  style: TextStyle(
                                                    color: Colors.white.withValues(alpha: 0.7),
                                                  ),
                                                )
                                              : null,
                                          value: isSelected,
                                          onChanged: (value) {
                                            setState(() {
                                              if (value == true) {
                                                _selectedEmployeeIds.add(employee.id);
                                              } else {
                                                _selectedEmployeeIds.remove(employee.id);
                                              }
                                            });
                                            _updateWagePreview();
                                          },
                                          activeColor: const Color(0xFF6F4BFF),
                                          checkColor: Colors.white,
                                        );
                                      },
                                    );
                                  },
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '${_selectedEmployeeIds.length} employee${_selectedEmployeeIds.length != 1 ? 's' : ''} selected',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.7),
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 24),
                            ],
                            // Production Quantities
                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: _bricksProducedController,
                                    decoration: InputDecoration(
                                      labelText: 'Bricks Produced (Y) *',
                                      labelStyle: const TextStyle(color: Colors.white70),
                                      filled: true,
                                      fillColor: Colors.white.withValues(alpha: 0.05),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide(
                                          color: Colors.white.withValues(alpha: 0.2),
                                        ),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide(
                                          color: Colors.white.withValues(alpha: 0.2),
                                        ),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: const BorderSide(
                                          color: Color(0xFF6F4BFF),
                                          width: 2,
                                        ),
                                      ),
                                    ),
                                    style: const TextStyle(color: Colors.white),
                                    keyboardType: TextInputType.number,
                                    validator: (value) {
                                      if (value == null || value.isEmpty) {
                                        return 'Please enter bricks produced';
                                      }
                                      if (int.tryParse(value) == null || int.parse(value) < 0) {
                                        return 'Please enter a valid number';
                                      }
                                      return null;
                                    },
                                    onChanged: (_) => _updateWagePreview(),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: TextFormField(
                                    controller: _bricksStackedController,
                                    decoration: InputDecoration(
                                      labelText: 'Bricks Stacked (Z) *',
                                      labelStyle: const TextStyle(color: Colors.white70),
                                      filled: true,
                                      fillColor: Colors.white.withValues(alpha: 0.05),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide(
                                          color: Colors.white.withValues(alpha: 0.2),
                                        ),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide(
                                          color: Colors.white.withValues(alpha: 0.2),
                                        ),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: const BorderSide(
                                          color: Color(0xFF6F4BFF),
                                          width: 2,
                                        ),
                                      ),
                                    ),
                                    style: const TextStyle(color: Colors.white),
                                    keyboardType: TextInputType.number,
                                    validator: (value) {
                                      if (value == null || value.isEmpty) {
                                        return 'Please enter bricks stacked';
                                      }
                                      if (int.tryParse(value) == null || int.parse(value) < 0) {
                                        return 'Please enter a valid number';
                                      }
                                      return null;
                                    },
                                    onChanged: (_) => _updateWagePreview(),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 24),
                            // Wage Calculation Section (Always shown when method is selected)
                            if (_selectedMethodId != null && _wageSettings != null) ...[
                              Container(
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      const Color(0xFF6F4BFF).withValues(alpha: 0.15),
                                      const Color(0xFF9C27B0).withValues(alpha: 0.1),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: const Color(0xFF6F4BFF).withValues(alpha: 0.4),
                                    width: 1.5,
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF6F4BFF).withValues(alpha: 0.2),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: const Icon(
                                            Icons.calculate_outlined,
                                            color: Color(0xFF6F4BFF),
                                            size: 24,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        const Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                'Calculated Wages',
                                                style: TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              SizedBox(height: 4),
                                              Text(
                                                'Wages are calculated automatically',
                                                style: TextStyle(
                                                  color: Colors.white70,
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                    if (_totalWages != null && _wagePerEmployee != null) ...[
                                      const SizedBox(height: 20),
                                      Container(
                                        padding: const EdgeInsets.all(16),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withValues(alpha: 0.05),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Row(
                                          children: [
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    'Total Wages',
                                                    style: TextStyle(
                                                      color: Colors.white.withValues(alpha: 0.7),
                                                      fontSize: 13,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 6),
                                                  Text(
                                                    '₹${_totalWages!.toStringAsFixed(2)}',
                                                    style: const TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 24,
                                                      fontWeight: FontWeight.bold,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            Container(
                                              width: 1,
                                              height: 50,
                                              color: Colors.white.withValues(alpha: 0.2),
                                            ),
                                            const SizedBox(width: 16),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    'Per Employee',
                                                    style: TextStyle(
                                                      color: Colors.white.withValues(alpha: 0.7),
                                                      fontSize: 13,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 6),
                                                  Text(
                                                    '₹${_wagePerEmployee!.toStringAsFixed(2)}',
                                                    style: const TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 22,
                                                      fontWeight: FontWeight.w600,
                                                    ),
                                                  ),
                                                  Text(
                                                    '(${_selectedEmployeeIds.length} employees)',
                                                    style: TextStyle(
                                                      color: Colors.white.withValues(alpha: 0.6),
                                                      fontSize: 11,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ] else ...[
                                      const SizedBox(height: 16),
                                      Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: Colors.orange.withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(
                                            color: Colors.orange.withValues(alpha: 0.3),
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            Icon(
                                              Icons.info_outline,
                                              size: 18,
                                              color: Colors.orange.withValues(alpha: 0.9),
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Text(
                                                'Enter production quantities and select employees to see calculated wages',
                                                style: TextStyle(
                                                  color: Colors.orange.withValues(alpha: 0.9),
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              const SizedBox(height: 24),
                            ],
                            // Notes
                            TextFormField(
                              controller: _notesController,
                              decoration: InputDecoration(
                                labelText: 'Notes (Optional)',
                                labelStyle: const TextStyle(color: Colors.white70),
                                filled: true,
                                fillColor: Colors.white.withValues(alpha: 0.05),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                    color: Colors.white.withValues(alpha: 0.2),
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                    color: Colors.white.withValues(alpha: 0.2),
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(
                                    color: Color(0xFF6F4BFF),
                                    width: 2,
                                  ),
                                ),
                              ),
                              style: const TextStyle(color: Colors.white),
                              maxLines: 3,
                            ),
                          ],
                        ),
                      ),
                    ),
                    // Footer with Actions
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.03),
                        border: Border(
                          top: BorderSide(
                            color: Colors.white.withValues(alpha: 0.1),
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
                                Icon(
                                  Icons.info_outline,
                                  size: 16,
                                  color: Colors.white.withValues(alpha: 0.6),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Wages calculated: ₹${_totalWages!.toStringAsFixed(2)} total',
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.7),
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            )
                          else
                            const SizedBox.shrink(),
                          Row(
                            children: [
                              OutlinedButton(
                                onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.white70,
                                  side: BorderSide(
                                    color: Colors.white.withValues(alpha: 0.2),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 24,
                                    vertical: 14,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: const Text('Cancel'),
                              ),
                              const SizedBox(width: 12),
                              ElevatedButton.icon(
                                onPressed: _isLoading || _totalWages == null ? null : _submit,
                                icon: _isLoading
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(Colors.white),
                                        ),
                                      )
                                    : Icon(
                                        widget.batch != null
                                            ? Icons.update_outlined
                                            : Icons.check_circle_outline,
                                        size: 18,
                                      ),
                                label: Text(
                                  widget.batch != null ? 'Update Batch' : 'Create Batch',
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _totalWages == null
                                      ? Colors.grey
                                      : const Color(0xFF4CAF50),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 28,
                                    vertical: 14,
                                  ),
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
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
    );
  }
}

