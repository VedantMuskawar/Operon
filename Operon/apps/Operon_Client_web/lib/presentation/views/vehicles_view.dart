import 'package:core_bloc/core_bloc.dart';
import 'package:core_ui/core_ui.dart';
import 'package:dash_web/data/repositories/employees_repository.dart';
import 'package:dash_web/data/repositories/products_repository.dart';
import 'package:dash_web/data/repositories/users_repository.dart';
import 'package:dash_web/domain/entities/organization_employee.dart';
import 'package:dash_web/domain/entities/organization_product.dart';
import 'package:dash_web/domain/entities/vehicle.dart';
import 'package:dash_web/presentation/blocs/org_context/org_context_cubit.dart';
import 'package:dash_web/presentation/blocs/vehicles/vehicles_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class VehiclesPageContent extends StatelessWidget {
  const VehiclesPageContent({super.key});

  @override
  Widget build(BuildContext context) {
    final orgState = context.watch<OrganizationContextCubit>().state;
    final organization = orgState.organization;

    if (organization == null) {
      return const Center(child: Text('No organization selected'));
    }

    final employeesRepository = context.read<EmployeesRepository>();
    final productsRepository = context.read<ProductsRepository>();

    return BlocListener<VehiclesCubit, VehiclesState>(
      listener: (context, state) {
        if (state.status == ViewStatus.failure && state.message != null) {
          DashSnackbar.show(
            context,
            message: state.message!,
            isError: true,
          );
        }
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: double.infinity,
            child: DashButton(
              label: 'Add Vehicle',
              onPressed: () => _openVehicleDialog(
                context,
                employeesRepository: employeesRepository,
                productsRepository: productsRepository,
                orgId: organization.id,
              ),
            ),
          ),
          const SizedBox(height: 24),
          BlocBuilder<VehiclesCubit, VehiclesState>(
            builder: (context, state) {
              if (state.status == ViewStatus.loading) {
                return const Center(child: CircularProgressIndicator());
              }
              if (state.vehicles.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(40),
                    child: Text(
                      'No vehicles yet. Tap "Add Vehicle" to get started.',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.6),
                        fontSize: 16,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                );
              }
              return ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: state.vehicles.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final vehicle = state.vehicles[index];
                  return _VehicleTile(
                    vehicle: vehicle,
                    onEdit: () => _openVehicleDialog(
                      context,
                      vehicle: vehicle,
                      employeesRepository: employeesRepository,
                      productsRepository: productsRepository,
                      orgId: organization.id,
                    ),
                    onAssignDriver: () => _openDriverDialog(
                      context,
                      vehicle: vehicle,
                      employeesRepository: employeesRepository,
                      usersRepository: context.read<UsersRepository>(),
                      orgId: organization.id,
                    ),
                    onDelete: () =>
                        context.read<VehiclesCubit>().deleteVehicle(vehicle.id),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  Future<void> _openVehicleDialog(
    BuildContext context, {
    Vehicle? vehicle,
    required EmployeesRepository employeesRepository,
    required ProductsRepository productsRepository,
    required String orgId,
  }) async {
    final cubit = context.read<VehiclesCubit>();
    await showDialog(
      context: context,
      builder: (dialogContext) => BlocProvider.value(
        value: cubit,
        child: _VehicleDialog(
          vehicle: vehicle,
          employeesRepository: employeesRepository,
          productsRepository: productsRepository,
          orgId: orgId,
        ),
      ),
    );
  }

  Future<void> _openDriverDialog(
    BuildContext context, {
    required Vehicle vehicle,
    required EmployeesRepository employeesRepository,
    required UsersRepository usersRepository,
    required String orgId,
  }) async {
    final cubit = context.read<VehiclesCubit>();
    await showDialog(
      context: context,
      builder: (dialogContext) => BlocProvider.value(
        value: cubit,
        child: _DriverAssignmentDialog(
          vehicle: vehicle,
          employeesRepository: employeesRepository,
          usersRepository: usersRepository,
          orgId: orgId,
        ),
      ),
    );
  }
}

class _VehicleTile extends StatelessWidget {
  const _VehicleTile({
    required this.vehicle,
    required this.onEdit,
    required this.onAssignDriver,
    required this.onDelete,
  });

  final Vehicle vehicle;
  final VoidCallback onEdit;
  final VoidCallback onAssignDriver;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1A1A2A), Color(0xFF11111B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: vehicle.isActive ? Colors.white12 : Colors.white10,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white10,
              borderRadius: BorderRadius.circular(14),
            ),
            alignment: Alignment.center,
            child: const Icon(Icons.local_shipping_outlined, color: Colors.white),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  vehicle.vehicleNumber,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.4,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Capacity: ${vehicle.vehicleCapacity?.toStringAsFixed(1) ?? '-'} • '
                  'Weekly avg: ${_calculateWeeklyAverage(vehicle.weeklyCapacity)}',
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
                if (vehicle.driver != null && vehicle.driver!.name != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Driver: ${vehicle.driver!.name} (${vehicle.driver!.phone ?? ''})',
                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                ],
                if (vehicle.productCapacities != null &&
                    vehicle.productCapacities!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Products configured: ${vehicle.productCapacities!.length}',
                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                ],
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    _DocStatusChip(
                      label: 'Insurance',
                      expiry: vehicle.insurance?.expiryDate,
                    ),
                    _DocStatusChip(
                      label: 'Fitness',
                      expiry: vehicle.fitnessCertificate?.expiryDate,
                    ),
                    _DocStatusChip(
                      label: 'PUC',
                      expiry: vehicle.puc?.expiryDate,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              IconButton(
                onPressed: onAssignDriver,
                icon: Icon(
                  vehicle.driver != null
                      ? Icons.person
                      : Icons.person_add_outlined,
                  color: vehicle.driver != null
                      ? Colors.blueAccent
                      : Colors.white54,
                ),
                tooltip: vehicle.driver != null
                    ? 'Change Driver'
                    : 'Assign Driver',
              ),
              const SizedBox(height: 8),
              IconButton(
                onPressed: onEdit,
                icon: const Icon(Icons.edit_outlined, color: Colors.white54),
              ),
              const SizedBox(height: 8),
              IconButton(
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _calculateWeeklyAverage(Map<String, double>? weeklyCapacity) {
    if (weeklyCapacity == null || weeklyCapacity.isEmpty) return '-';
    final total = weeklyCapacity.values.fold<double>(0, (sum, value) => sum + value);
    return (total / weeklyCapacity.length).toStringAsFixed(1);
  }
}

class _DocStatusChip extends StatelessWidget {
  const _DocStatusChip({
    required this.label,
    required this.expiry,
  });

  final String label;
  final DateTime? expiry;

  @override
  Widget build(BuildContext context) {
    final status = _docStatus();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: status.color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: status.color.withOpacity(0.4)),
      ),
      child: Text(
        '$label • ${status.label}',
        style: TextStyle(color: status.color, fontSize: 11, fontWeight: FontWeight.w600),
      ),
    );
  }

  _ExpiryStatus _docStatus() {
    if (expiry == null) return const _ExpiryStatus('N/A', Colors.white38);
    final today = DateTime.now();
    final days = expiry!.difference(DateTime(today.year, today.month, today.day)).inDays;
    if (days < 0) return const _ExpiryStatus('Expired', Colors.redAccent);
    if (days <= 15) return _ExpiryStatus('Due $days d', Colors.orangeAccent);
    return const _ExpiryStatus('OK', Colors.greenAccent);
  }
}

class _ExpiryStatus {
  const _ExpiryStatus(this.label, this.color);
  final String label;
  final Color color;
}

class _VehicleDialog extends StatefulWidget {
  const _VehicleDialog({
    this.vehicle,
    required this.employeesRepository,
    required this.productsRepository,
    required this.orgId,
  });

  final Vehicle? vehicle;
  final EmployeesRepository employeesRepository;
  final ProductsRepository productsRepository;
  final String orgId;

  @override
  State<_VehicleDialog> createState() => _VehicleDialogState();
}

class _VehicleDialogState extends State<_VehicleDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _vehicleNumberController;
  late final TextEditingController _capacityController;
  late final TextEditingController _notesController;
  late final Map<String, TextEditingController> _weeklyControllers;
  Map<String, TextEditingController> _productControllers = {};
  late final TextEditingController _insuranceNumberController;
  DateTime? _insuranceExpiry;
  late final TextEditingController _fitnessNumberController;
  DateTime? _fitnessExpiry;
  late final TextEditingController _pucNumberController;
  DateTime? _pucExpiry;
  bool _isActive = true;

  List<OrganizationProduct> _products = const [];
  bool _isLoadingProducts = true;
  bool _isSubmitting = false;

  static const _weekdays = [
    'monday',
    'tuesday',
    'wednesday',
    'thursday',
    'friday',
    'saturday',
    'sunday',
  ];

  @override
  void initState() {
    super.initState();
    final vehicle = widget.vehicle;
    _vehicleNumberController = TextEditingController(text: vehicle?.vehicleNumber ?? '');
    _capacityController = TextEditingController(
      text: vehicle?.vehicleCapacity?.toString() ?? '',
    );
    _notesController = TextEditingController(text: vehicle?.notes ?? '');
    _weeklyControllers = {
      for (final day in _weekdays)
        day: TextEditingController(text: vehicle?.weeklyCapacity?[day]?.toString() ?? ''),
    };
    _insuranceNumberController = TextEditingController(
      text: vehicle?.insurance?.documentNumber ?? '',
    );
    _fitnessNumberController = TextEditingController(
      text: vehicle?.fitnessCertificate?.documentNumber ?? '',
    );
    _pucNumberController = TextEditingController(
      text: vehicle?.puc?.documentNumber ?? '',
    );
    _insuranceExpiry = vehicle?.insurance?.expiryDate;
    _fitnessExpiry = vehicle?.fitnessCertificate?.expiryDate;
    _pucExpiry = vehicle?.puc?.expiryDate;
    _isActive = vehicle?.isActive ?? true;
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    try {
      final products = await widget.productsRepository.fetchProducts(widget.orgId);
      setState(() {
        _products = products;
        _productControllers = {
          for (final product in products)
            product.id: TextEditingController(
              text: widget.vehicle?.productCapacities?[product.id]?.toString() ?? '',
            ),
        };
        _isLoadingProducts = false;
      });
    } catch (_) {
      setState(() {
        _products = const [];
        _productControllers = {};
        _isLoadingProducts = false;
      });
    }
  }

  @override
  void dispose() {
    _vehicleNumberController.dispose();
    _capacityController.dispose();
    _notesController.dispose();
    _insuranceNumberController.dispose();
    _fitnessNumberController.dispose();
    _pucNumberController.dispose();
    for (final controller in _weeklyControllers.values) {
      controller.dispose();
    }
    for (final controller in _productControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.vehicle != null;
    return AlertDialog(
      backgroundColor: const Color(0xFF11111B),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF6F4BFF).withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.local_shipping_outlined,
              color: Color(0xFF6F4BFF),
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              isEditing ? 'Edit Vehicle' : 'Add Vehicle',
              style: const TextStyle(color: Colors.white, fontSize: 20),
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 600,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Basic Information Section
                _FormSection(
                  title: 'Basic Information',
                  icon: Icons.info_outline,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: TextFormField(
                            controller: _vehicleNumberController,
                            style: const TextStyle(color: Colors.white),
                            decoration: _inputDecoration('Vehicle Number *'),
                            validator: (value) => (value == null || value.trim().isEmpty)
                                ? 'Required'
                                : null,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _capacityController,
                            style: const TextStyle(color: Colors.white),
                            decoration: _inputDecoration('Capacity'),
                            keyboardType:
                                const TextInputType.numberWithOptions(decimal: true),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: SwitchListTile(
                            value: _isActive,
                            onChanged: (value) => setState(() => _isActive = value),
                            title: const Text(
                              'Active',
                              style: TextStyle(color: Colors.white70, fontSize: 14),
                            ),
                            contentPadding: EdgeInsets.zero,
                            activeThumbColor: const Color(0xFF6F4BFF),
                            dense: true,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Capacity Section
                _FormSection(
                  title: 'Capacity Settings',
                  icon: Icons.straighten_outlined,
                  children: [
                    ExpansionTile(
                      backgroundColor: Colors.transparent,
                      collapsedBackgroundColor: Colors.transparent,
                      tilePadding: EdgeInsets.zero,
                      childrenPadding: const EdgeInsets.only(top: 8),
                      title: const Text(
                        'Weekly Capacity',
                        style: TextStyle(color: Colors.white70, fontSize: 14),
                      ),
                      children: [
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: _weekdays.map(
                            (day) => SizedBox(
                              width: 120,
                              child: TextFormField(
                                controller: _weeklyControllers[day],
                                style: const TextStyle(color: Colors.white, fontSize: 13),
                                decoration: _compactInputDecoration(day.capitalize()),
                                keyboardType:
                                    const TextInputType.numberWithOptions(decimal: true),
                              ),
                            ),
                          ).toList(),
                        ),
                      ],
                    ),
                    const Divider(color: Colors.white10, height: 24),
                    _isLoadingProducts
                        ? const Center(
                            child: Padding(
                              padding: EdgeInsets.all(16),
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        : _products.isEmpty
                            ? const Padding(
                                padding: EdgeInsets.symmetric(vertical: 8),
                                child: Text(
                                  'No products available.',
                                  style: TextStyle(
                                    color: Colors.white54,
                                    fontSize: 12,
                                  ),
                                ),
                              )
                            : ExpansionTile(
                                backgroundColor: Colors.transparent,
                                collapsedBackgroundColor: Colors.transparent,
                                tilePadding: EdgeInsets.zero,
                                childrenPadding: const EdgeInsets.only(top: 8),
                                title: const Text(
                                  'Product Capacities',
                                  style: TextStyle(color: Colors.white70, fontSize: 14),
                                ),
                                children: _products
                                    .map(
                                      (product) => Padding(
                                        padding: const EdgeInsets.only(bottom: 10),
                                        child: TextFormField(
                                          controller: _productControllers[product.id],
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 13,
                                          ),
                                          decoration: _compactInputDecoration(
                                            product.name,
                                          ),
                                          keyboardType:
                                              const TextInputType.numberWithOptions(
                                            decimal: true,
                                          ),
                                        ),
                                      ),
                                    )
                                    .toList(),
                              ),
                  ],
                ),
                const SizedBox(height: 16),
                // Documents Section
                _FormSection(
                  title: 'Documents',
                  icon: Icons.description_outlined,
                  children: [
                    _CompactDocumentFields(
                      title: 'Insurance',
                      numberController: _insuranceNumberController,
                      expiry: _insuranceExpiry,
                      onPickDate: (date) => setState(() => _insuranceExpiry = date),
                    ),
                    const SizedBox(height: 10),
                    _CompactDocumentFields(
                      title: 'Fitness',
                      numberController: _fitnessNumberController,
                      expiry: _fitnessExpiry,
                      onPickDate: (date) => setState(() => _fitnessExpiry = date),
                    ),
                    const SizedBox(height: 10),
                    _CompactDocumentFields(
                      title: 'PUC',
                      numberController: _pucNumberController,
                      expiry: _pucExpiry,
                      onPickDate: (date) => setState(() => _pucExpiry = date),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Notes Section
                _FormSection(
                  title: 'Additional Notes',
                  icon: Icons.note_outlined,
                  children: [
                    TextFormField(
                      controller: _notesController,
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      decoration: _compactInputDecoration('Notes (optional)'),
                      maxLines: 2,
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
          child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
        ),
        ElevatedButton(
          onPressed: _isSubmitting ? null : _submit,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF6F4BFF),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: _isSubmitting
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Text(widget.vehicle != null ? 'Save Changes' : 'Create Vehicle'),
        ),
      ],
    );
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _isSubmitting = true);
    try {
      final vehicle = Vehicle(
        id: widget.vehicle?.id ??
            DateTime.now().millisecondsSinceEpoch.toString(),
        organizationId: widget.orgId,
        vehicleNumber: _vehicleNumberController.text.trim(),
        vehicleCapacity: double.tryParse(_capacityController.text.trim()),
        weeklyCapacity: _buildWeeklyCapacity(),
        productCapacities: _buildProductCapacities(),
        insurance: _buildDocumentInfo(
          controller: _insuranceNumberController,
          expiry: _insuranceExpiry,
        ),
        fitnessCertificate: _buildDocumentInfo(
          controller: _fitnessNumberController,
          expiry: _fitnessExpiry,
        ),
        puc: _buildDocumentInfo(
          controller: _pucNumberController,
          expiry: _pucExpiry,
        ),
        driver: null,
        isActive: _isActive,
        notes: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
      );

      final cubit = context.read<VehiclesCubit>();
      if (widget.vehicle != null) {
        await cubit.updateVehicle(vehicle);
      } else {
        await cubit.createVehicle(vehicle);
      }
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (error) {
      if (mounted) {
        DashSnackbar.show(
          context,
          message: 'Failed to save vehicle: $error',
          isError: true,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.white70, fontSize: 14),
      filled: true,
      fillColor: const Color(0xFF1B1B2C),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }

  InputDecoration _compactInputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.white70, fontSize: 12),
      filled: true,
      fillColor: const Color(0xFF1B1B2C),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      isDense: true,
    );
  }

  Map<String, double>? _buildWeeklyCapacity() {
    final data = <String, double>{};
    _weeklyControllers.forEach((day, controller) {
      final text = controller.text.trim();
      if (text.isEmpty) return;
      final value = double.tryParse(text);
      if (value != null) {
        data[day] = value;
      }
    });
    return data.isEmpty ? null : data;
  }

  Map<String, double>? _buildProductCapacities() {
    if (_productControllers.isEmpty) return null;
    final map = <String, double>{};
    _productControllers.forEach((productId, controller) {
      final text = controller.text.trim();
      if (text.isEmpty) return;
      final value = double.tryParse(text);
      if (value != null) {
        map[productId] = value;
      }
    });
    return map.isEmpty ? null : map;
  }

  VehicleDocumentInfo? _buildDocumentInfo({
    required TextEditingController controller,
    required DateTime? expiry,
  }) {
    final number = controller.text.trim();
    if (number.isEmpty && expiry == null) return null;
    return VehicleDocumentInfo(
      documentNumber: number.isEmpty ? null : number,
      expiryDate: expiry,
    );
  }
}

class _DriverAssignmentDialog extends StatefulWidget {
  const _DriverAssignmentDialog({
    required this.vehicle,
    required this.employeesRepository,
    required this.usersRepository,
    required this.orgId,
  });

  final Vehicle vehicle;
  final EmployeesRepository employeesRepository;
  final UsersRepository usersRepository;
  final String orgId;

  @override
  State<_DriverAssignmentDialog> createState() => _DriverAssignmentDialogState();
}

class _DriverAssignmentDialogState extends State<_DriverAssignmentDialog> {
  List<OrganizationEmployee> _employees = const [];
  OrganizationEmployee? _selectedEmployee;
  bool _isLoading = true;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _loadEmployees();
  }

  Future<void> _loadEmployees() async {
    try {
      final employees = await widget.employeesRepository.fetchEmployees(widget.orgId);
      OrganizationEmployee? currentDriver;
      if (widget.vehicle.driver?.id != null) {
        for (final employee in employees) {
          if (employee.id == widget.vehicle.driver?.id) {
            currentDriver = employee;
            break;
          }
        }
      }
      setState(() {
        _employees = employees;
        _selectedEmployee = currentDriver;
        _isLoading = false;
      });
    } catch (_) {
      setState(() {
        _employees = const [];
        _isLoading = false;
      });
    }
  }

  Future<void> _submit() async {
    setState(() => _isSubmitting = true);
    try {
      final cubit = context.read<VehiclesCubit>();
      VehicleDriverInfo? driverInfo;
      if (_selectedEmployee != null) {
        // Fetch phone number from USERS collection by employee ID
        final phone = await widget.usersRepository.fetchPhoneByEmployeeId(
          orgId: widget.orgId,
          employeeId: _selectedEmployee!.id,
        );
        driverInfo = VehicleDriverInfo(
          id: _selectedEmployee!.id,
          name: _selectedEmployee!.name,
          phone: phone,
        );
      } else {
        // Unassign driver - pass null to remove driver
        driverInfo = null;
      }
      await cubit.updateDriver(widget.vehicle.id, driverInfo);
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (error) {
      if (mounted) {
        DashSnackbar.show(
          context,
          message: 'Failed to assign driver: $error',
          isError: true,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.white70),
      filled: true,
      fillColor: const Color(0xFF1B1B2C),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF11111B),
      title: Text(
        'Assign Driver - ${widget.vehicle.vehicleNumber}',
        style: const TextStyle(color: Colors.white),
      ),
      content: SizedBox(
        width: 400,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (widget.vehicle.driver != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blueAccent.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.blueAccent.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.info_outline,
                            color: Colors.blueAccent,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Current: ${widget.vehicle.driver!.name ?? 'Unknown'}'
                              '${widget.vehicle.driver!.phone != null ? ' (${widget.vehicle.driver!.phone})' : ''}',
                              style: const TextStyle(
                                color: Colors.blueAccent,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  DropdownButtonFormField<OrganizationEmployee?>(
                    initialValue: _selectedEmployee,
                    decoration: _inputDecoration('Select Driver'),
                    dropdownColor: const Color(0xFF1B1B2C),
                    style: const TextStyle(color: Colors.white),
                    onChanged: (value) {
                      setState(() {
                        _selectedEmployee = value;
                      });
                    },
                    items: [
                      const DropdownMenuItem<OrganizationEmployee?>(
                        value: null,
                        child: Text('Unassigned'),
                      ),
                      ..._employees.map(
                        (employee) => DropdownMenuItem<OrganizationEmployee?>(
                          value: employee,
                          child: Text(employee.name),
                        ),
                      ),
                    ],
                  ),
                  if (_employees.isEmpty) ...[
                    const SizedBox(height: 12),
                    const Text(
                      'No employees available. Add employees first.',
                      style: TextStyle(color: Colors.white54, fontSize: 12),
                    ),
                  ],
                ],
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
        ),
        TextButton(
          onPressed: _isSubmitting ? null : _submit,
          child: _isSubmitting
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(
                  _selectedEmployee == null ? 'Unassign' : 'Assign',
                  style: const TextStyle(color: Color(0xFF6F4BFF)),
                ),
        ),
      ],
    );
  }
}

class _FormSection extends StatelessWidget {
  const _FormSection({
    required this.title,
    required this.icon,
    required this.children,
  });

  final String title;
  final IconData icon;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2A).withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: const Color(0xFF6F4BFF), size: 18),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }
}

class _CompactDocumentFields extends StatelessWidget {
  const _CompactDocumentFields({
    required this.title,
    required this.numberController,
    required this.expiry,
    required this.onPickDate,
  });

  final String title;
  final TextEditingController numberController;
  final DateTime? expiry;
  final ValueChanged<DateTime?> onPickDate;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: TextFormField(
            controller: numberController,
            style: const TextStyle(color: Colors.white, fontSize: 13),
            decoration: InputDecoration(
              labelText: '$title Number',
              labelStyle: const TextStyle(color: Colors.white70, fontSize: 12),
              filled: true,
              fillColor: const Color(0xFF1B1B2C),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              isDense: true,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: InkWell(
            onTap: () async {
              final now = DateTime.now();
              final picked = await showDatePicker(
                context: context,
                initialDate: expiry ?? now,
                firstDate: DateTime(now.year - 1),
                lastDate: DateTime(now.year + 10),
                builder: (context, child) {
                  return Theme(
                    data: Theme.of(context).copyWith(
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
              onPickDate(picked);
            },
            child: Container(
              height: 48,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF1B1B2C),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white10),
              ),
              alignment: Alignment.centerLeft,
              child: Text(
                expiry == null
                    ? 'Expiry'
                    : '${expiry!.day.toString().padLeft(2, '0')}/'
                        '${expiry!.month.toString().padLeft(2, '0')}/'
                        '${expiry!.year}',
                style: TextStyle(
                  color: expiry == null ? Colors.white54 : Colors.white,
                  fontSize: 13,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

extension on String {
  String capitalize() {
    if (isEmpty) return this;
    return '${this[0].toUpperCase()}${substring(1)}';
  }
}
