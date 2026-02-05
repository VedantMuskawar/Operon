import 'package:core_bloc/core_bloc.dart';
import 'package:core_models/core_models.dart';
import 'package:core_ui/core_ui.dart';
import 'package:dash_mobile/data/repositories/employees_repository.dart';
import 'package:dash_mobile/data/repositories/products_repository.dart';
import 'package:dash_mobile/data/repositories/users_repository.dart';
import 'package:dash_mobile/data/repositories/vehicles_repository.dart';
import 'package:dash_mobile/domain/entities/organization_employee.dart';
import 'package:dash_mobile/presentation/blocs/org_context/org_context_cubit.dart';
import 'package:dash_mobile/presentation/blocs/vehicles/vehicles_cubit.dart';
import 'package:dash_mobile/presentation/widgets/modern_page_header.dart';
import 'package:dash_mobile/shared/constants/app_spacing.dart';
import 'package:dash_mobile/shared/constants/app_typography.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:go_router/go_router.dart';

class VehiclesPage extends StatelessWidget {
  const VehiclesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final orgState = context.watch<OrganizationContextCubit>().state;
    final organization = orgState.organization;

    if (organization == null) {
      return Scaffold(
        backgroundColor: AuthColors.background,
        appBar: const ModernPageHeader(
          title: 'Vehicle Management',
        ),
        body: SafeArea(
          child: Column(
            children: [
              const Expanded(
                child: Center(
                  child: Padding(
                    padding: EdgeInsets.all(AppSpacing.paddingLG),
                    child: Text(
                      'Please select an organization to manage vehicles.',
                      style: TextStyle(color: AuthColors.textSub),
                    ),
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
                onItemTapped: (index) {
                  context.go('/home', extra: index);
                },
              ),
            ],
          ),
        ),
      );
    }

    final employeesRepository = context.read<EmployeesRepository>();
    final productsRepository = context.read<ProductsRepository>();

    return BlocProvider(
      create: (context) => VehiclesCubit(
        repository: context.read<VehiclesRepository>(),
        orgId: organization.id,
      )..loadVehicles(),
      child: Scaffold(
        backgroundColor: AuthColors.background,
        appBar: const ModernPageHeader(
          title: 'Vehicle Management',
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
            Builder(
              builder: (innerContext) => SizedBox(
                width: double.infinity,
                child: DashButton(
                  label: 'Add Vehicle',
                  onPressed: () => _openVehicleDialog(
                    innerContext,
                    employeesRepository: employeesRepository,
                    productsRepository: productsRepository,
                    orgId: organization.id,
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.paddingXL),
            BlocBuilder<VehiclesCubit, VehiclesState>(
              builder: (context, state) {
                if (state.status == ViewStatus.loading) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (state.vehicles.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.only(top: AppSpacing.paddingXXXL * 1.25),
                    child: Text(
                      'No vehicles yet. Tap “Add Vehicle” to get started.',
                      style: TextStyle(
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
                    itemCount: state.vehicles.length,
                    separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.paddingMD),
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
                onItemTapped: (index) {
                  context.go('/home', extra: index);
                },
              ),
            ],
          ),
        ),
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
        borderRadius: BorderRadius.circular(AppSpacing.radiusXL),
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
            const SizedBox(width: AppSpacing.paddingMD),
            PopupMenuButton<String>(
              icon: const Icon(
                Icons.more_vert,
                color: AuthColors.textSub,
                size: 20,
              ),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppSpacing.radiusMD),
              ),
              color: AuthColors.surface,
              onSelected: (value) {
                switch (value) {
                  case 'edit':
                    onEdit();
                    break;
                  case 'assign_driver':
                    onAssignDriver();
                    break;
                  case 'delete':
                    onDelete();
                    break;
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem<String>(
                  value: 'edit',
                  child: Row(
                    children: [
                      Icon(
                        Icons.edit_outlined,
                        color: AuthColors.textMain,
                        size: 18,
                      ),
                      SizedBox(width: AppSpacing.paddingMD),
                      Text(
                        'Edit',
                        style: TextStyle(color: AuthColors.textMain),
                      ),
                    ],
                  ),
                ),
                PopupMenuItem<String>(
                  value: 'assign_driver',
                  child: Row(
                    children: [
                      Icon(
                        vehicle.driver != null
                            ? Icons.person
                            : Icons.person_add_outlined,
                        color: vehicle.driver != null
                            ? AuthColors.primary
                            : AuthColors.textMain,
                        size: 18,
                      ),
                      const SizedBox(width: AppSpacing.paddingMD),
                      Text(
                        vehicle.driver != null
                            ? 'Change Driver'
                            : 'Assign Driver',
                        style: const TextStyle(color: AuthColors.textMain),
                      ),
                    ],
                  ),
                ),
                const PopupMenuItem<String>(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(
                        Icons.delete_outline,
                        color: AuthColors.error,
                        size: 18,
                      ),
                      SizedBox(width: AppSpacing.paddingMD),
                      Text(
                        'Delete',
                        style: TextStyle(color: AuthColors.error),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
        onTap: onEdit,
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
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.paddingMD, vertical: AppSpacing.gapSM),
      decoration: BoxDecoration(
        color: status.color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMD),
        border: Border.all(color: status.color.withOpacity(0.4)),
      ),
      child: Text(
        '$label • ${status.label}',
        style: TextStyle(color: status.color, fontSize: 11, fontWeight: FontWeight.w600),
      ),
    );
  }

  _ExpiryStatus _docStatus() {
    if (expiry == null) return const _ExpiryStatus('N/A', AuthColors.textDisabled);
    final today = DateTime.now();
    final days = expiry!.difference(DateTime(today.year, today.month, today.day)).inDays;
    if (days < 0) return const _ExpiryStatus('Expired', AuthColors.error);
    if (days <= 15) return _ExpiryStatus('Due $days d', AuthColors.warning);
    return const _ExpiryStatus('OK', AuthColors.success);
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
  late final TextEditingController _customTagController;
  String? _selectedTag;
  bool _showCustomTag = false;
  String? _selectedMeterType;

  List<OrganizationProduct> _products = const [];
  bool _isLoadingProducts = true;
  bool _isSubmitting = false;

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
      final products =
          await widget.productsRepository.fetchProducts(widget.orgId);
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
            padding: const EdgeInsets.all(AppSpacing.paddingSM),
            decoration: BoxDecoration(
              color: AuthColors.primary.withOpacity(0.2),
              borderRadius: BorderRadius.circular(AppSpacing.radiusSM),
            ),
            child: const Icon(
              Icons.local_shipping_outlined,
              color: AuthColors.primary,
              size: 20,
            ),
          ),
          const SizedBox(width: AppSpacing.paddingMD),
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
                        const SizedBox(width: AppSpacing.paddingMD),
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
                    const SizedBox(height: AppSpacing.paddingMD),
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
                    const SizedBox(height: AppSpacing.paddingMD),
                    const Text(
                      'Meter Type',
                      style: TextStyle(color: AuthColors.textSub, fontSize: 14),
                    ),
                    const SizedBox(height: AppSpacing.paddingSM),
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
                            color: _selectedMeterType == 'KM' ? AuthColors.textMain : AuthColors.textSub,
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
                            color: _selectedMeterType == 'HOUR' ? AuthColors.textMain : AuthColors.textSub,
                          ),
                          backgroundColor: AuthColors.surface,
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.paddingLG),
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
                          selectedColor: AuthColors.legacyAccent,
                          labelStyle: TextStyle(
                            color: _selectedTag == 'Custom' ? AuthColors.textMain : AuthColors.textSub,
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
                      const SizedBox(height: AppSpacing.paddingMD),
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
                const SizedBox(height: AppSpacing.paddingLG),
                // Capacity Section
                _FormSection(
                  title: 'Capacity Settings',
                  icon: Icons.straighten_outlined,
                  children: [
                    ExpansionTile(
                      backgroundColor: Colors.transparent,
                      collapsedBackgroundColor: Colors.transparent,
                      tilePadding: EdgeInsets.zero,
                      childrenPadding: const EdgeInsets.only(top: AppSpacing.paddingSM),
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
                              padding: EdgeInsets.all(AppSpacing.paddingLG),
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        : _products.isEmpty
                            ? const Padding(
                                padding: EdgeInsets.symmetric(vertical: AppSpacing.paddingSM),
                                child: Text(
                                  'No products available.',
                                  style: TextStyle(
                                    color: AuthColors.textSub,
                                    fontSize: 12,
                                  ),
                                ),
                              )
                            : ExpansionTile(
                                backgroundColor: Colors.transparent,
                                collapsedBackgroundColor: Colors.transparent,
                                tilePadding: EdgeInsets.zero,
                                childrenPadding: const EdgeInsets.only(top: AppSpacing.paddingSM),
                                title: const Text(
                                  'Product Capacities',
                                  style: TextStyle(color: AuthColors.textSub, fontSize: 14),
                                ),
                                children: _products
                                    .map(
                                      (product) => Padding(
                                        padding: const EdgeInsets.only(bottom: AppSpacing.paddingMD),
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
                const SizedBox(height: AppSpacing.paddingLG),
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
                    const SizedBox(height: AppSpacing.paddingMD),
                    _CompactDocumentFields(
                      title: 'Fitness',
                      numberController: _fitnessNumberController,
                      expiry: _fitnessExpiry,
                      onPickDate: (date) => setState(() => _fitnessExpiry = date),
                    ),
                    const SizedBox(height: AppSpacing.paddingMD),
                    _CompactDocumentFields(
                      title: 'PUC',
                      numberController: _pucNumberController,
                      expiry: _pucExpiry,
                      onPickDate: (date) => setState(() => _pucExpiry = date),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.paddingLG),
                // Notes Section
                _FormSection(
                  title: 'Additional Notes',
                  icon: Icons.note_outlined,
                  children: [
                    TextFormField(
                      controller: _notesController,
                      style: AppTypography.withColor(AppTypography.bodySmall, AuthColors.textMain),
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
          child: const Text('Cancel', style: TextStyle(color: AuthColors.textSub)),
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save vehicle: $error')),
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
        borderRadius: BorderRadius.circular(AppSpacing.radiusMD),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.paddingLG, vertical: AppSpacing.paddingLG),
    );
  }

  InputDecoration _compactInputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: AppTypography.withColor(AppTypography.labelSmall, AuthColors.textSub),
      filled: true,
      fillColor: AuthColors.surface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusSM),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.paddingMD, vertical: AppSpacing.paddingMD),
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
      final employees =
          await widget.employeesRepository.fetchEmployees(widget.orgId);
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to assign driver: $error')),
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
        borderRadius: BorderRadius.circular(AppSpacing.radiusMD),
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
                      padding: const EdgeInsets.all(AppSpacing.paddingMD),
                      decoration: BoxDecoration(
                        color: AuthColors.primary.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(AppSpacing.radiusMD),
                        border: Border.all(
                          color: AuthColors.primary.withOpacity(0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.info_outline,
                            color: AuthColors.primary,
                            size: 20,
                          ),
                          const SizedBox(width: AppSpacing.paddingSM),
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
                    const SizedBox(height: AppSpacing.paddingLG),
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
                    const SizedBox(height: AppSpacing.paddingMD),
                    const Text(
                      'No employees available. Add employees first.',
                      style: TextStyle(color: AuthColors.textSub, fontSize: 12),
                    ),
                  ],
                ],
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: _isSubmitting ? null : _submit,
          child: _isSubmitting
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(_selectedEmployee == null ? 'Unassign' : 'Assign'),
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
      padding: const EdgeInsets.all(AppSpacing.paddingLG),
      decoration: BoxDecoration(
        color: AuthColors.surface.withOpacity(0.5),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMD),
        border: Border.all(color: AuthColors.textMainWithOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AuthColors.legacyAccent, size: 18),
              const SizedBox(width: AppSpacing.paddingSM),
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
          const SizedBox(height: AppSpacing.paddingMD),
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
              labelStyle: const TextStyle(color: AuthColors.textSub, fontSize: 12),
              filled: true,
              fillColor: AuthColors.surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppSpacing.radiusSM),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.paddingMD, vertical: AppSpacing.paddingMD),
              isDense: true,
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.paddingMD),
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
                        primary: AuthColors.legacyAccent,
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
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.paddingMD),
              decoration: BoxDecoration(
                color: AuthColors.surface,
                borderRadius: BorderRadius.circular(AppSpacing.radiusSM),
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



