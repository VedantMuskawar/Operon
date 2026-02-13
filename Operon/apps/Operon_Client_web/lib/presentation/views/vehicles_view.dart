import 'package:core_bloc/core_bloc.dart';
import 'package:core_models/core_models.dart';
import 'package:core_ui/core_ui.dart';
import 'package:dash_web/data/repositories/employees_repository.dart';
import 'package:dash_web/data/repositories/products_repository.dart';
import 'package:dash_web/data/repositories/users_repository.dart';
import 'package:dash_web/presentation/blocs/org_context/org_context_cubit.dart';
import 'package:dash_web/presentation/blocs/vehicles/vehicles_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';

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
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SkeletonLoader(
                          height: 40,
                          width: double.infinity,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        const SizedBox(height: 16),
                        ...List.generate(8, (_) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: SkeletonLoader(
                            height: 56,
                            width: double.infinity,
                            borderRadius: BorderRadius.circular(8),
                          ),
                        )),
                      ],
                    ),
                  ),
                );
              }
              if (state.vehicles.isEmpty) {
                return const EmptyState(
                  icon: Icons.directions_car_outlined,
                  title: 'No vehicles yet',
                  message: 'Tap "Add Vehicle" to get started',
                );
              }
              return AnimationLimiter(
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: state.vehicles.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final vehicle = state.vehicles[index];
                    return AnimationConfiguration.staggeredList(
                      position: index,
                      duration: const Duration(milliseconds: 200),
                      child: SlideAnimation(
                        verticalOffset: 50.0,
                        child: FadeInAnimation(
                          curve: Curves.easeOut,
                          child: _VehicleDataListItem(
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

class _VehicleDataListItem extends StatelessWidget {
  const _VehicleDataListItem({
    required this.vehicle,
    required this.onEdit,
    required this.onAssignDriver,
    required this.onDelete,
  });

  final Vehicle vehicle;
  final VoidCallback onEdit;
  final VoidCallback onAssignDriver;
  final VoidCallback onDelete;

  String _formatSubtitle() {
    final parts = <String>[];
    if (vehicle.tag != null) {
      parts.add(vehicle.tag!);
    }
    if (vehicle.vehicleCapacity != null) {
      parts.add('Cap: ${vehicle.vehicleCapacity!.toStringAsFixed(1)}');
    }
    if (vehicle.driver != null && vehicle.driver!.name != null) {
      parts.add('Driver: ${vehicle.driver!.name}');
    }
    return parts.isEmpty ? 'Vehicle' : parts.join(' • ');
  }

  Color _getStatusColor() {
    return vehicle.isActive ? AuthColors.success : AuthColors.textDisabled;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AuthColors.background,
        borderRadius: BorderRadius.circular(18),
      ),
      child: DataList(
        title: vehicle.vehicleNumber,
        subtitle: _formatSubtitle(),
        leading: DataListAvatar(
          initial: vehicle.vehicleNumber.isNotEmpty ? vehicle.vehicleNumber[0] : 'V',
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
              icon: Icon(
                vehicle.driver != null ? Icons.person : Icons.person_add_outlined,
                color: vehicle.driver != null ? AuthColors.primary : AuthColors.textSub,
                size: 20,
              ),
              onPressed: onAssignDriver,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              tooltip: vehicle.driver != null ? 'Change Driver' : 'Assign Driver',
            ),
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
  late final TextEditingController _customTagController;
  String? _selectedTag;
  bool _showCustomTag = false;
  String? _selectedMeterType;

  List<OrganizationProduct> _products = const [];
  bool _isLoadingProducts = true;
  bool _isSubmitting = false;

  static final Map<String, List<OrganizationProduct>> _productsCache = {};

  static const _predefinedTags = [
    'Delivery',
    'Personal',
    'Raw Material',
    'Plant',
  ];

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
    
    // Initialize tag selection
    final vehicleTag = vehicle?.tag;
    if (vehicleTag != null && !_predefinedTags.contains(vehicleTag)) {
      _selectedTag = 'Custom';
      _showCustomTag = true;
      _customTagController = TextEditingController(text: vehicleTag);
    } else {
      _selectedTag = vehicleTag;
      _showCustomTag = false;
      _customTagController = TextEditingController();
    }
    
    // Initialize meter type
    _selectedMeterType = vehicle?.meterType;
    
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    try {
      final cachedProducts = _productsCache[widget.orgId];
      if (cachedProducts != null) {
        setState(() {
          _products = cachedProducts;
          _productControllers = {
            for (final product in cachedProducts)
              product.id: TextEditingController(
                text: widget.vehicle?.productCapacities?[product.id]?.toString() ?? '',
              ),
          };
          _isLoadingProducts = false;
        });
        return;
      }

      final products = await widget.productsRepository.fetchProducts(widget.orgId);
      if (!mounted) return;
      setState(() {
        _productsCache[widget.orgId] = products;
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
      if (!mounted) return;
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
    _customTagController.dispose();
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
      backgroundColor: AuthColors.surface,
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AuthColors.primary.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.local_shipping_outlined,
              color: AuthColors.primary,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              isEditing ? 'Edit Vehicle' : 'Add Vehicle',
              style: const TextStyle(color: AuthColors.textMain, fontSize: 20),
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
                            style: const TextStyle(color: AuthColors.textMain),
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
                            style: const TextStyle(color: AuthColors.textMain),
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
                              style: TextStyle(color: AuthColors.textSub, fontSize: 14),
                            ),
                            contentPadding: EdgeInsets.zero,
                            activeThumbColor: AuthColors.primary,
                            dense: true,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Meter Type',
                      style: TextStyle(color: AuthColors.textSub, fontSize: 14),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ChoiceChip(
                          label: const Text('KM'),
                          selected: _selectedMeterType == 'KM',
                          onSelected: (_) {
                            setState(() {
                              _selectedMeterType = _selectedMeterType == 'KM' ? null : 'KM';
                            });
                          },
                          selectedColor: AuthColors.primary,
                          labelStyle: TextStyle(
                            color: _selectedMeterType == 'KM'
                                ? AuthColors.textMain
                                : AuthColors.textSub,
                          ),
                          backgroundColor: AuthColors.surface,
                        ),
                        ChoiceChip(
                          label: const Text('HOUR'),
                          selected: _selectedMeterType == 'HOUR',
                          onSelected: (_) {
                            setState(() {
                              _selectedMeterType = _selectedMeterType == 'HOUR' ? null : 'HOUR';
                            });
                          },
                          selectedColor: AuthColors.primary,
                          labelStyle: TextStyle(
                            color: _selectedMeterType == 'HOUR'
                                ? AuthColors.textMain
                                : AuthColors.textSub,
                          ),
                          backgroundColor: AuthColors.surface,
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Tag Section
                _FormSection(
                  title: 'Vehicle Tag',
                  icon: Icons.label_outline,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ..._predefinedTags.map((tag) {
                          final isSelected = _selectedTag == tag;
                          return ChoiceChip(
                            label: Text(tag),
                            selected: isSelected,
                            onSelected: (_) {
                              setState(() {
                                _selectedTag = tag;
                                _showCustomTag = false;
                                _customTagController.clear();
                              });
                            },
                            selectedColor: AuthColors.primary,
                            labelStyle: TextStyle(
                              color: isSelected ? AuthColors.textMain : AuthColors.textSub,
                            ),
                            backgroundColor: AuthColors.surface,
                          );
                        }),
                        ChoiceChip(
                          label: const Text('Custom'),
                          selected: _selectedTag == 'Custom',
                          onSelected: (_) {
                            setState(() {
                              _selectedTag = 'Custom';
                              _showCustomTag = true;
                            });
                          },
                          selectedColor: AuthColors.primary,
                          labelStyle: TextStyle(
                            color: _selectedTag == 'Custom'
                                ? AuthColors.textMain
                                : AuthColors.textSub,
                          ),
                          backgroundColor: AuthColors.surface,
                        ),
                        if (_selectedTag == null)
                          ChoiceChip(
                            label: const Text('None'),
                            selected: true,
                            onSelected: (_) {
                              setState(() {
                                _selectedTag = null;
                                _showCustomTag = false;
                                _customTagController.clear();
                              });
                            },
                            selectedColor: AuthColors.surface,
                            labelStyle: const TextStyle(color: AuthColors.textSub),
                            backgroundColor: AuthColors.surface,
                          ),
                      ],
                    ),
                    if (_showCustomTag) ...[
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _customTagController,
                        style: const TextStyle(color: AuthColors.textMain, fontSize: 13),
                        decoration: _compactInputDecoration('Custom Tag'),
                        onChanged: (_) {
                          // Tag will be read from controller on submit
                        },
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 16),
                // Capacity Section
                _FormSection(
                  title: 'Capacity Settings',
                  icon: Icons.straighten_outlined,
                  children: [
                    ExpansionTile(
                      backgroundColor: AuthColors.transparent,
                      collapsedBackgroundColor: AuthColors.transparent,
                      tilePadding: EdgeInsets.zero,
                      childrenPadding: const EdgeInsets.only(top: 8),
                      title: const Text(
                        'Weekly Capacity',
                        style: TextStyle(color: AuthColors.textSub, fontSize: 14),
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
                                style: const TextStyle(color: AuthColors.textMain, fontSize: 13),
                                decoration: _compactInputDecoration(day.capitalize()),
                                keyboardType:
                                    const TextInputType.numberWithOptions(decimal: true),
                              ),
                            ),
                          ).toList(),
                        ),
                      ],
                    ),
                    Divider(color: AuthColors.textMainWithOpacity(0.1), height: 24),
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
                                    color: AuthColors.textSub,
                                    fontSize: 12,
                                  ),
                                ),
                              )
                            : ExpansionTile(
                                backgroundColor: AuthColors.transparent,
                                collapsedBackgroundColor: AuthColors.transparent,
                                tilePadding: EdgeInsets.zero,
                                childrenPadding: const EdgeInsets.only(top: 8),
                                title: const Text(
                                  'Product Capacities',
                                  style: TextStyle(color: AuthColors.textSub, fontSize: 14),
                                ),
                                children: _products
                                    .map(
                                      (product) => Padding(
                                        padding: const EdgeInsets.only(bottom: 10),
                                        child: TextFormField(
                                          controller: _productControllers[product.id],
                                          style: const TextStyle(
                                            color: AuthColors.textMain,
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
                      style: const TextStyle(color: AuthColors.textMain, fontSize: 13),
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
        DashButton(
          label: 'Cancel',
          onPressed: () => Navigator.of(context).pop(),
          variant: DashButtonVariant.text,
        ),
        DashButton(
          label: widget.vehicle != null ? 'Save Changes' : 'Create Vehicle',
          onPressed: _isSubmitting ? null : _submit,
          isLoading: _isSubmitting,
        ),
      ],
    );
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _isSubmitting = true);
    try {
      // Determine tag value
      String? tagValue;
      if (_selectedTag == 'Custom') {
        final customTag = _customTagController.text.trim();
        tagValue = customTag.isEmpty ? null : customTag;
      } else {
        tagValue = _selectedTag;
      }

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
        tag: tagValue,
        meterType: _selectedMeterType,
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
      labelStyle: const TextStyle(color: AuthColors.textSub, fontSize: 14),
      filled: true,
      fillColor: AuthColors.surface,
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
      labelStyle: const TextStyle(color: AuthColors.textSub, fontSize: 12),
      filled: true,
      fillColor: AuthColors.surface,
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

  static final Map<String, List<OrganizationEmployee>> _driverCache = {};
  static final Map<String, List<OrganizationEmployee>> _employeesCache = {};

  @override
  void initState() {
    super.initState();
    _loadEmployees();
  }

  OrganizationEmployee? _findEmployee(
    List<OrganizationEmployee> employees,
    String? employeeId,
  ) {
    if (employeeId == null) return null;
    for (final employee in employees) {
      if (employee.id == employeeId) return employee;
    }
    return null;
  }

  Future<void> _loadEmployees() async {
    try {
      // Driver role ID from migration mapping
      const driverRoleId = '1766649058877';
      final cachedDrivers = _driverCache[widget.orgId];
      final cachedAllEmployees = _employeesCache[widget.orgId];

      if (cachedDrivers != null) {
        final currentDriver = _findEmployee(
              cachedDrivers,
              widget.vehicle.driver?.id,
            ) ??
            _findEmployee(cachedAllEmployees ?? const [], widget.vehicle.driver?.id);
        setState(() {
          _employees = cachedDrivers;
          _selectedEmployee = currentDriver;
          _isLoading = false;
        });
        return;
      }

      List<OrganizationEmployee> employees;
      try {
        employees = await widget.employeesRepository.fetchEmployeesByJobRole(
          widget.orgId,
          driverRoleId,
        );
        _driverCache[widget.orgId] = employees;
      } catch (_) {
        final allEmployees = cachedAllEmployees ??
            await widget.employeesRepository.fetchEmployees(widget.orgId);
        _employeesCache[widget.orgId] = allEmployees;
        employees = allEmployees
            .where((emp) => emp.jobRoleIds.contains(driverRoleId))
            .toList()
          ..sort((a, b) => a.name.compareTo(b.name));
        _driverCache[widget.orgId] = employees;
      }

      OrganizationEmployee? currentDriver = _findEmployee(
        employees,
        widget.vehicle.driver?.id,
      );
      if (currentDriver == null && widget.vehicle.driver?.id != null) {
        final allEmployees = cachedAllEmployees ??
            _employeesCache[widget.orgId] ??
            await widget.employeesRepository.fetchEmployees(widget.orgId);
        _employeesCache[widget.orgId] = allEmployees;
        currentDriver = _findEmployee(allEmployees, widget.vehicle.driver?.id);
      }

      if (!mounted) return;
      setState(() {
        _employees = employees;
        _selectedEmployee = currentDriver;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
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
        // Normalize phone to match format used in scheduled trips queries
        final normalizedPhone = phone != null && phone.isNotEmpty
            ? phone.replaceAll(RegExp(r'[^0-9+]'), '')
            : phone;
        driverInfo = VehicleDriverInfo(
          id: _selectedEmployee!.id,
          name: _selectedEmployee!.name,
          phone: normalizedPhone,
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
      labelStyle: const TextStyle(color: AuthColors.textSub),
      filled: true,
      fillColor: AuthColors.surface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AuthColors.surface,
      title: Text(
        'Assign Driver - ${widget.vehicle.vehicleNumber}',
        style: const TextStyle(color: AuthColors.textMain),
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
                        color: AuthColors.primary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AuthColors.primary.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.info_outline,
                            color: AuthColors.primary,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Current: ${widget.vehicle.driver!.name ?? 'Unknown'}'
                              '${widget.vehicle.driver!.phone != null ? ' (${widget.vehicle.driver!.phone})' : ''}',
                              style: const TextStyle(
                                color: AuthColors.primary,
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
                    dropdownColor: AuthColors.surface,
                    style: const TextStyle(color: AuthColors.textMain),
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
                      style: TextStyle(color: AuthColors.textSub, fontSize: 12),
                    ),
                  ],
                ],
              ),
      ),
      actions: [
        DashButton(
          label: 'Cancel',
          onPressed: () => Navigator.of(context).pop(),
          variant: DashButtonVariant.text,
        ),
        DashButton(
          label: _selectedEmployee == null ? 'Unassign' : 'Assign',
          onPressed: _isSubmitting ? null : _submit,
          isLoading: _isSubmitting,
          variant: DashButtonVariant.text,
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
        color: AuthColors.surface.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AuthColors.textMainWithOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AuthColors.primary, size: 18),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  color: AuthColors.textMain,
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
            style: const TextStyle(color: AuthColors.textMain, fontSize: 13),
            decoration: InputDecoration(
              labelText: '$title Number',
              labelStyle: const TextStyle(color: AuthColors.textSub, fontSize: 12),
              filled: true,
              fillColor: AuthColors.surface,
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
                        primary: AuthColors.primary,
                        onPrimary: AuthColors.textMain,
                        surface: AuthColors.surface,
                        onSurface: AuthColors.textMain,
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
                color: AuthColors.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AuthColors.textMainWithOpacity(0.1)),
              ),
              alignment: Alignment.centerLeft,
              child: Text(
                expiry == null
                    ? 'Expiry'
                    : '${expiry!.day.toString().padLeft(2, '0')}/'
                        '${expiry!.month.toString().padLeft(2, '0')}/'
                        '${expiry!.year}',
                style: TextStyle(
                  color: expiry == null ? AuthColors.textSub : AuthColors.textMain,
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
