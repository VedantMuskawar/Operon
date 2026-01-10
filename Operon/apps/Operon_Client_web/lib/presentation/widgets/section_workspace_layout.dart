import 'package:core_models/core_models.dart';
import 'package:core_ui/core_ui.dart';
import 'package:dash_web/domain/entities/app_access_role.dart';
import 'package:dash_web/domain/entities/organization_membership.dart';
import 'package:dash_web/presentation/blocs/auth/auth_bloc.dart';
import 'package:dash_web/presentation/blocs/org_context/org_context_cubit.dart';
import 'package:dash_web/data/repositories/users_repository.dart';
import 'package:dash_web/domain/entities/organization_user.dart';
import 'package:dash_web/data/repositories/products_repository.dart';
import 'package:dash_web/data/repositories/raw_materials_repository.dart';
import 'package:dash_web/data/repositories/payment_accounts_repository.dart';
import 'package:dash_web/data/repositories/app_access_roles_repository.dart';
import 'package:dash_web/data/repositories/employees_repository.dart';
import 'package:dash_web/data/repositories/job_roles_repository.dart';
import 'package:dash_web/data/repositories/vehicles_repository.dart';
import 'package:dash_web/data/repositories/delivery_zones_repository.dart';
import 'package:dash_web/data/services/qr_code_service.dart';
import 'package:dash_web/presentation/blocs/job_roles/job_roles_cubit.dart';
import 'package:dash_web/presentation/blocs/products/products_cubit.dart';
import 'package:dash_web/presentation/blocs/raw_materials/raw_materials_cubit.dart';
import 'package:dash_web/presentation/blocs/payment_accounts/payment_accounts_cubit.dart';
import 'package:dash_web/presentation/blocs/users/users_cubit.dart';
import 'package:dash_web/presentation/blocs/employees/employees_cubit.dart';
import 'package:dash_web/presentation/blocs/vehicles/vehicles_cubit.dart';
import 'package:dash_web/presentation/blocs/delivery_zones/delivery_zones_cubit.dart';
import 'package:dash_web/presentation/views/roles_page.dart';
import 'package:dash_web/presentation/views/products_page.dart';
import 'package:dash_web/presentation/views/raw_materials_page.dart';
import 'package:dash_web/presentation/views/payment_accounts_page.dart';
import 'package:dash_web/presentation/views/users_view.dart';
import 'package:dash_web/presentation/views/employees_view.dart';
import 'package:dash_web/presentation/views/vehicles_view.dart';
import 'package:dash_web/presentation/views/zones_view.dart';
import 'package:dash_web/presentation/views/wage_settings_page.dart';
import 'package:dash_web/presentation/blocs/wage_settings/wage_settings_cubit.dart';
import 'package:dash_web/presentation/views/production_batch_templates_page.dart';
import 'package:dash_web/presentation/blocs/production_batch_templates/production_batch_templates_cubit.dart';
import 'package:core_datasources/core_datasources.dart';
import 'package:dash_web/presentation/widgets/quick_action_menu.dart';
import 'package:dash_web/presentation/widgets/select_client_dialog.dart';
import 'package:dash_web/presentation/widgets/record_payment_dialog.dart';
import 'package:dash_web/presentation/widgets/record_purchase_dialog.dart';
import 'package:dash_web/presentation/widgets/record_expense_dialog.dart';
import 'package:dash_web/presentation/blocs/expenses/expenses_cubit.dart';
import 'package:dash_web/data/datasources/payment_accounts_data_source.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

List<int> computeHomeSections(AppAccessRole? appAccessRole) {
  final visible = <int>[0];
  if (appAccessRole == null) return visible;
  if (appAccessRole.canAccessSection('pendingOrders')) visible.add(1);
  if (appAccessRole.canAccessSection('scheduleOrders')) visible.add(2);
  if (appAccessRole.canAccessSection('ordersMap')) visible.add(3);
  if (appAccessRole.canAccessSection('analyticsDashboard')) visible.add(4);
  return visible;
}

class SectionWorkspaceLayout extends StatefulWidget {
  const SectionWorkspaceLayout({
    super.key,
    required this.child,
    required this.currentIndex,
    required this.onNavTap,
    this.allowedSections,
    this.panelTitle,
  });

  final Widget child;
  final String? panelTitle;
  final int currentIndex;
  final ValueChanged<int> onNavTap;
  final List<int>? allowedSections;

  @override
  State<SectionWorkspaceLayout> createState() => _SectionWorkspaceLayoutState();
}

enum ContentPage { none, roles, products, rawMaterials, paymentAccounts, users, employees, vehicles, zones, wageSettings, productionBatchTemplates }

class _SectionWorkspaceLayoutState extends State<SectionWorkspaceLayout> {
  bool _isProfileOpen = false;
  bool _isSettingsOpen = false;
  ContentPage _contentPage = ContentPage.none;

  void _showSelectClientDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.7),
      builder: (dialogContext) => const SelectClientDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = context.watch<AuthBloc>().state;
    final orgState = context.watch<OrganizationContextCubit>().state;
    final organization = orgState.organization;
    final appAccessRole = orgState.appAccessRole;
    // Note: organization.role now contains appAccessRoleId (or role name for backward compat)
    final fallbackAdmin = (organization?.role.toUpperCase() ?? '') == 'ADMIN';
    final isAdminRole = appAccessRole?.isAdmin ?? fallbackAdmin;
    final canManageUsers = appAccessRole?.canCreate('users') ?? isAdminRole;
    final canManageVehicles = appAccessRole?.canAccessPage('vehicles') ?? isAdminRole;
    final visibleSections = widget.allowedSections?.toList() ??
        computeHomeSections(appAccessRole);
    final media = MediaQuery.of(context);

    const scaffoldColor =
        kDebugMode ? Color(0xFF121226) : Color(0xFF010104);

    return Scaffold(
      backgroundColor: scaffoldColor,
      body: SafeArea(
        child: Stack(
          children: [
            // Main Content Panel
            Positioned(
              top: 100,
              left: 20,
              right: 20,
              bottom: 24,
              child: Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1F1F33), Color(0xFF0F0F16)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    const BoxShadow(
                      color: Color(0x66000000),
                      blurRadius: 60,
                      spreadRadius: -10,
                      offset: Offset(0, 30),
                    ),
                    BoxShadow(
                      color: const Color(0xFF6F4BFF).withValues(alpha: 0.1),
                      blurRadius: 40,
                      spreadRadius: -20,
                      offset: const Offset(0, 20),
                    ),
                  ],
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.08),
                    width: 1.5,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: _AnimatedSectionSwitcher(
                    key: ValueKey('section-${widget.currentIndex}'),
                    currentIndex: widget.currentIndex,
                    panelTitle: widget.panelTitle,
                    child: widget.child,
                  ),
                ),
              ),
            ),

            // Top Navigation Bar
            Positioned(
              top: 16,
              left: 16,
              right: 16,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  _FloatingCircleIcon(
                    icon: Icons.person_outline,
                    onTap: () => setState(() {
                      _isProfileOpen = true;
                      _isSettingsOpen = false;
                    }),
                  ),
                  Expanded(
                    child: Center(
                        child: _TopNavBar(
                          currentIndex: widget.currentIndex,
                          onTap: widget.onNavTap,
                          visibleSections: visibleSections,
                          contentPage: _contentPage,
                      ),
                    ),
                  ),
                  _FloatingCircleIcon(
                    icon: Icons.settings_outlined,
                    onTap: () => setState(() {
                      _isSettingsOpen = true;
                      _isProfileOpen = false;
                    }),
                  ),
                ],
              ),
            ),

            // Overlay when side sheets are open
            if (_isProfileOpen || _isSettingsOpen || _contentPage != ContentPage.none)
              Positioned.fill(
                child: GestureDetector(
                  onTap: () => setState(() {
                    _isProfileOpen = false;
                    _isSettingsOpen = false;
                    _contentPage = ContentPage.none;
                  }),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.7),
                          Colors.black.withValues(alpha: 0.5),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

            // Profile Side Sheet
            AnimatedPositioned(
              duration: const Duration(milliseconds: 350),
              curve: Curves.easeOutCubic,
              top: 0,
              bottom: 0,
              left: _isProfileOpen ? 0 : -media.size.width,
              child: _ProfileSideSheet(
                user: authState.userProfile,
                organization: organization,
                usersRepository: context.read<UsersRepository>(),
                onClose: () => setState(() => _isProfileOpen = false),
                onChangeOrg: () {
                  setState(() => _isProfileOpen = false);
                  context.go('/org-selection');
                },
                onOpenPermissions: isAdminRole
                    ? () {
                        setState(() => _isProfileOpen = false);
                        context.go('/access-control');
                      }
                    : null,
                onLogout: () {
                  context.read<AuthBloc>().add(const AuthReset());
                  context.go('/login');
                },
              ),
            ),

            // Settings Side Sheet
            AnimatedPositioned(
              duration: const Duration(milliseconds: 350),
              curve: Curves.easeOutCubic,
              top: 0,
              bottom: 0,
              right: _isSettingsOpen ? 0 : -media.size.width,
              child: _SettingsSideSheet(
                canManageRoles: isAdminRole,
                canManageUsers: canManageUsers,
                canManageVehicles: canManageVehicles,
                canManageProducts: appAccessRole?.canCreate('products') ?? isAdminRole,
                canManageRawMaterials: appAccessRole?.canCreate('rawMaterials') ?? isAdminRole,
                onClose: () => setState(() => _isSettingsOpen = false),
                onOpenUsers: canManageUsers
                    ? () => setState(() {
                        _isSettingsOpen = false;
                        _contentPage = ContentPage.users;
                      })
                    : null,
                onOpenVehicles: canManageVehicles
                    ? () => setState(() {
                        _isSettingsOpen = false;
                        _contentPage = ContentPage.vehicles;
                      })
                    : null,
                onOpenRoles: () => setState(() {
                  _isSettingsOpen = false;
                  _contentPage = ContentPage.roles;
                }),
                onOpenProducts: () => setState(() {
                  _isSettingsOpen = false;
                  _contentPage = ContentPage.products;
                }),
                onOpenRawMaterials: () => setState(() {
                  _isSettingsOpen = false;
                  _contentPage = ContentPage.rawMaterials;
                }),
                onOpenPaymentAccounts: isAdminRole
                    ? () => setState(() {
                        _isSettingsOpen = false;
                        _contentPage = ContentPage.paymentAccounts;
                      })
                    : null,
                onOpenWageSettings: isAdminRole
                    ? () => setState(() {
                        _isSettingsOpen = false;
                        _contentPage = ContentPage.wageSettings;
                      })
                    : null,
                onOpenProductionBatchTemplates: () => setState(() {
                  _isSettingsOpen = false;
                  _contentPage = ContentPage.productionBatchTemplates;
                }),
                onOpenDmSettings: () {
                  setState(() {
                    _isSettingsOpen = false;
                  });
                  context.go('/dm-settings');
                },
              ),
            ),

            // Content Side Sheet
            _AnimatedSideSheet(
              isOpen: _contentPage != ContentPage.none,
              child: _ContentSideSheet(
                page: _contentPage,
                onClose: () => setState(() => _contentPage = ContentPage.none),
                orgId: organization?.id,
                appAccessRole: appAccessRole,
                isAdminRole: isAdminRole,
                canManageProducts: appAccessRole?.canCreate('products') ?? isAdminRole,
                canManageRawMaterials: appAccessRole?.canCreate('rawMaterials') ?? isAdminRole,
                ),
              ),

            // Quick Action Menu - Show on Overview (0) and Pending Orders (1) sections
            // Positioned relative to the viewport, accounting for content panel positioning
            // Content panel: top: 100, left: 20, right: 20, bottom: 24
            // Button should be 40px from right edge of viewport and 40px from bottom
            if (widget.currentIndex == 0 || widget.currentIndex == 1)
              Builder(
                builder: (context) {
                  final actions = <QuickActionItem>[
                    // Payments - Available on both Overview and Pending Orders (opens Record Payment modal)
                    QuickActionItem(
                      icon: Icons.payment,
                      label: 'Payments',
                      onTap: () {
                        final orgState = context.read<OrganizationContextCubit>().state;
                        final organization = orgState.organization;
                        if (organization == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Please select an organization first')),
                          );
                          return;
                        }
                        showDialog(
                          context: context,
                          barrierColor: Colors.black.withValues(alpha: 0.7),
                          builder: (dialogContext) => BlocProvider.value(
                            value: context.read<OrganizationContextCubit>(),
                            child: const RecordPaymentDialog(),
                          ),
                        );
                      },
                    ),
                    // Record Purchase - Available on both Overview and Pending Orders
                    QuickActionItem(
                      icon: Icons.shopping_cart,
                      label: 'Record Purchase',
                      onTap: () {
                        final orgState = context.read<OrganizationContextCubit>().state;
                        final organization = orgState.organization;
                        if (organization == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Please select an organization first')),
                          );
                          return;
                        }
                        showDialog(
                          context: context,
                          barrierColor: Colors.black.withValues(alpha: 0.7),
                          builder: (dialogContext) => BlocProvider.value(
                            value: context.read<OrganizationContextCubit>(),
                            child: const RecordPurchaseDialog(),
                          ),
                        );
                      },
                    ),
                    // Create Order - Available on both Overview and Pending Orders
                    QuickActionItem(
                      icon: Icons.add_shopping_cart_outlined,
                      label: 'Create Order',
                      onTap: () => _showSelectClientDialog(context),
                    ),
                  ];

                  // Add Expense action only on Overview (home) section
                  if (widget.currentIndex == 0) {
                    actions.add(
                      QuickActionItem(
                        icon: Icons.receipt_long,
                        label: 'Add Expense',
                        onTap: () {
                          final orgState = context.read<OrganizationContextCubit>().state;
                          final organization = orgState.organization;
                          if (organization == null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Please select an organization first')),
                            );
                            return;
                          }

                          // Create ExpensesCubit on-demand for the dialog
                          final transactionsRepository = context.read<TransactionsRepository>();
                          final vendorsRepository = context.read<VendorsRepository>();
                          final employeesRepository = context.read<EmployeesRepository>();
                          final subCategoriesRepository = context.read<ExpenseSubCategoriesRepository>();
                          final paymentAccountsDataSource = PaymentAccountsDataSource();
                          final userId = context.read<AuthBloc>().state.userProfile?.id ?? '';

                          final expensesCubit = ExpensesCubit(
                            transactionsRepository: transactionsRepository,
                            vendorsRepository: vendorsRepository,
                            employeesRepository: employeesRepository,
                            subCategoriesRepository: subCategoriesRepository,
                            paymentAccountsDataSource: paymentAccountsDataSource,
                            organizationId: organization.id,
                            userId: userId,
                          );

                          showDialog(
                            context: context,
                            barrierColor: Colors.black.withValues(alpha: 0.7),
                            builder: (dialogContext) => BlocProvider.value(
                              value: expensesCubit,
                              child: const RecordExpenseDialog(),
                            ),
                          );
                        },
                      ),
                    );
                  }

                  return QuickActionMenu(
                    right: 40,
                    bottom: 40, // 40px from bottom of viewport (accounts for content panel bottom: 24 + spacing)
                    actions: actions,
                  );
                },
              ),
            // Quick Action Menu for Expenses page
            if (widget.currentIndex == -1 && widget.panelTitle == 'Expenses')
              Builder(
                builder: (context) {
                  try {
                    final expensesCubit = context.read<ExpensesCubit>();
                    return QuickActionMenu(
                      right: 40,
                      bottom: 40,
                      actions: [
                        QuickActionItem(
                          icon: Icons.add,
                          label: 'Add Expense',
                          onTap: () {
                            showDialog(
                              context: context,
                              barrierColor: Colors.black.withValues(alpha: 0.7),
                              builder: (dialogContext) => BlocProvider.value(
                                value: expensesCubit,
                                child: const RecordExpenseDialog(),
                              ),
                            );
                          },
                        ),
                      ],
                    );
                  } catch (e) {
                    // ExpensesCubit not available, return empty container
                    return const SizedBox.shrink();
                  }
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _TopNavBar extends StatelessWidget {
  const _TopNavBar({
    required this.currentIndex,
    required this.onTap,
    required this.visibleSections,
    this.contentPage,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;
  final List<int> visibleSections;
  final ContentPage? contentPage;

  bool _isAccessControlOpen(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;
    return location == '/access-control';
  }

  static const _items = [
    Icons.home_outlined,
    Icons.pending_actions_outlined,
    Icons.schedule_outlined,
    Icons.map_outlined,
    Icons.dashboard_outlined,
  ];

  static const _labels = [
    'Overview',
    'Pending',
    'Schedule',
    'Map',
    'Analytics',
  ];

  @override
  Widget build(BuildContext context) {
    final allowed = <int>{0};
    if (visibleSections.isNotEmpty) {
      allowed.addAll(
          visibleSections.where((index) => index >= 0 && index < _items.length));
    } else {
      allowed.addAll(List.generate(_items.length, (index) => index));
    }
    final displayed = allowed.toList()..sort();

    final navItems = displayed.map((index) {
      final isActive = index == currentIndex && 
          (contentPage == null || contentPage == ContentPage.none);
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 3),
        child: _AnimatedNavItem(
          key: ValueKey('nav-$index'),
          index: index,
          isActive: isActive,
          icon: _items[index],
          label: _labels[index],
          onTap: () => onTap(index),
        ),
      );
    }).toList();

    if (_isAccessControlOpen(context)) {
      navItems.add(
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 4),
          child: _AnimatedAccessControlItem(
            key: ValueKey('access-control'),
          ),
        ),
      );
    }

    return _AnimatedNavBarContainer(
      key: const ValueKey('nav-bar-container'),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFF11111B).withValues(alpha: 0.98),
              const Color(0xFF0D0D15).withValues(alpha: 0.98),
            ],
          ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.12),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.6),
              blurRadius: 40,
              spreadRadius: -15,
              offset: const Offset(0, 20),
            ),
            BoxShadow(
              color: const Color(0xFF6F4BFF).withValues(alpha: 0.1),
              blurRadius: 30,
              spreadRadius: -20,
              offset: const Offset(0, 15),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: navItems,
        ),
      ),
    );
  }
}

class _AnimatedSideSheet extends StatefulWidget {
  const _AnimatedSideSheet({
    required this.isOpen,
    required this.child,
  });

  final bool isOpen;
  final Widget child;

  @override
  State<_AnimatedSideSheet> createState() => _AnimatedSideSheetState();
}

class _AnimatedSideSheetState extends State<_AnimatedSideSheet>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _slideAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
            duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _slideAnimation = Tween<double>(
      begin: 1.0, // Off-screen to the right
      end: 0.0,  // On-screen
    ).animate(
      CurvedAnimation(
        parent: _controller,
            curve: Curves.easeOutCubic,
      ),
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.7, curve: Curves.easeOut),
      ),
    );

    _scaleAnimation = Tween<double>(
      begin: 0.95,
      end: 1.0,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.8, curve: Curves.easeOutBack),
      ),
    );

    if (widget.isOpen) {
      _controller.forward();
    }
  }

  @override
  void didUpdateWidget(_AnimatedSideSheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isOpen != widget.isOpen) {
      if (widget.isOpen) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final screenWidth = media.size.width;
        final offsetX = _slideAnimation.value * screenWidth;
        
        return Positioned(
          top: 0,
          bottom: 0,
          right: -offsetX,
          child: Transform.scale(
            scale: _scaleAnimation.value,
            child: Opacity(
              opacity: _fadeAnimation.value,
              child: widget.child,
            ),
          ),
        );
      },
    );
  }
}

class _AnimatedSectionSwitcher extends StatefulWidget {
  const _AnimatedSectionSwitcher({
    required this.currentIndex,
    required this.child,
    this.panelTitle,
    super.key,
  });

  final int currentIndex;
  final Widget child;
  final String? panelTitle;

  @override
  State<_AnimatedSectionSwitcher> createState() =>
      _AnimatedSectionSwitcherState();
}

class _AnimatedSectionSwitcherState extends State<_AnimatedSectionSwitcher>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    _setupAnimations();

    _controller.forward();
  }

  void _setupAnimations({Offset? slideBegin, double? scaleBegin}) {
    final slideStart = slideBegin ?? Offset.zero;
    final scaleStart = scaleBegin ?? 1.0;

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.7, curve: Curves.easeOut),
      ),
    );

    _slideAnimation = Tween<Offset>(
      begin: slideStart,
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOutCubic,
      ),
    );

    _scaleAnimation = Tween<double>(
      begin: scaleStart,
      end: 1.0,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.8, curve: Curves.easeOutBack),
      ),
    );
  }

  @override
  void didUpdateWidget(_AnimatedSectionSwitcher oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentIndex != widget.currentIndex) {
      // Determine slide direction based on index change
      final direction = widget.currentIndex > oldWidget.currentIndex ? 1.0 : -1.0;
      final slideBegin = Offset(direction * 40.0, 0.0);
      const scaleBegin = 0.95;
      
      _setupAnimations(slideBegin: slideBegin, scaleBegin: scaleBegin);
      _controller.reset();
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(32, 32, 32, 32),
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return FadeTransition(
            opacity: _fadeAnimation,
            child: SlideTransition(
              position: _slideAnimation,
              child: ScaleTransition(
                scale: _scaleAnimation,
                child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (widget.panelTitle != null &&
                      widget.panelTitle!.isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Color(0xFF1B1C2C),
                            Color(0xFF161622),
                          ],
                        ),
                        border: Border(
                          bottom: BorderSide(
                            color: Colors.white.withValues(alpha: 0.08),
                            width: 1,
                          ),
                        ),
                      ),
                      child: SizedBox(
                        height: 32,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Align(
                              alignment: Alignment.centerLeft,
                              child: IconButton(
                                onPressed: () => context.go('/home'),
                                icon: const Icon(Icons.arrow_back, color: Colors.white70),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                tooltip: 'Back to home',
                              ),
                            ),
                            Center(
                              child: Text(
                                widget.panelTitle!,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 24,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  widget.child,
                ],
              ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _AnimatedNavBarContainer extends StatefulWidget {
  const _AnimatedNavBarContainer({
    required this.child,
    super.key,
  });

  final Widget child;

  @override
  State<_AnimatedNavBarContainer> createState() =>
      _AnimatedNavBarContainerState();
}

class _AnimatedNavBarContainerState extends State<_AnimatedNavBarContainer>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _slideAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _shadowAnimation;
  bool _isVisible = true;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.7, curve: Curves.easeOut),
      ),
    );

    _slideAnimation = Tween<double>(
      begin: 30.0,
      end: 0.0,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.8, curve: Curves.easeOutCubic),
      ),
    );

    _scaleAnimation = Tween<double>(
      begin: 0.85,
      end: 1.0,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.7, curve: Curves.easeOutBack),
      ),
    );

    _shadowAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.3, 1.0, curve: Curves.easeOut),
      ),
    );

    // Start entrance animation
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void exit() {
    if (!_isVisible) return;
    setState(() => _isVisible = false);
    _controller.reverse().then((_) {
      if (mounted && !_isVisible) {
        // Widget is hidden after exit animation
      }
    });
  }

  void enter() {
    if (_isVisible) return;
    setState(() => _isVisible = true);
    _controller.forward();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isVisible && _controller.value == 0.0) {
      return const SizedBox.shrink();
    }

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, _slideAnimation.value),
          child: Transform.scale(
            scale: _scaleAnimation.value,
            child: Opacity(
              opacity: _fadeAnimation.value,
              child: Container(
                decoration: BoxDecoration(
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0x55000000),
                      blurRadius: 20 * _shadowAnimation.value,
                      offset: Offset(0, 12 * _shadowAnimation.value),
                    ),
                  ],
                ),
                child: widget.child,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _AnimatedNavItem extends StatefulWidget {
  const _AnimatedNavItem({
    required this.index,
    required this.isActive,
    required this.icon,
    required this.label,
    required this.onTap,
    super.key,
  });

  final int index;
  final bool isActive;
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  State<_AnimatedNavItem> createState() => _AnimatedNavItemState();
}

class _AnimatedNavItemState extends State<_AnimatedNavItem>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _glowAnimation;
  bool _isHovered = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOutCubic,
      ),
    );
    _glowAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
      ),
    );
    if (widget.isActive) {
      _controller.value = 1.0;
    }
  }

  @override
  void didUpdateWidget(_AnimatedNavItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive != oldWidget.isActive) {
      if (widget.isActive) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            final value = _scaleAnimation.value;
            final glowValue = _glowAnimation.value;
            final hoverScale = _isHovered && !widget.isActive ? 1.05 : 1.0;
            
              return Transform.scale(
                scale: (0.97 + (value * 0.03)) * hoverScale,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOutCubic,
                      padding: EdgeInsets.symmetric(
                        horizontal: 20 + (value * 3),
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        gradient: value > 0.1
                            ? const LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  Color(0xFF6F4BFF),
                                  Color(0xFF5A3FE0),
                                ],
                              )
                            : null,
                        color: value < 0.1
                            ? (_isHovered
                                ? Colors.white.withValues(alpha: 0.08)
                                : Colors.transparent)
                            : null,
                        borderRadius: BorderRadius.circular(14),
                        border: value > 0.1
                            ? Border.all(
                                color: const Color(0xFF8B7AFF).withValues(
                                  alpha: glowValue * 0.6,
                                ),
                                width: 1.5,
                              )
                            : null,
                        boxShadow: [
                          if (value > 0.2)
                            BoxShadow(
                              color: const Color(0xFF6F4BFF)
                                  .withValues(alpha: glowValue * 0.5),
                              blurRadius: 20 * glowValue,
                              spreadRadius: -4,
                              offset: Offset(0, 8 * glowValue),
                            ),
                          if (_isHovered && !widget.isActive)
                            BoxShadow(
                              color: Colors.white.withValues(alpha: 0.15),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          TweenAnimationBuilder<double>(
                            tween: Tween<double>(
                              begin: 0.0,
                              end: value,
                            ),
                            duration: const Duration(milliseconds: 400),
                            curve: Curves.easeOutCubic,
                            builder: (context, iconValue, child) {
                              return Transform.rotate(
                                angle: (1.0 - iconValue) * 0.05,
                                child: Icon(
                                  widget.icon,
                                  color: Color.lerp(
                                    Colors.white54,
                                    Colors.white,
                                    iconValue,
                                  ) ?? Colors.white54,
                                  size: 20 + (iconValue * 2),
                                ),
                              );
                            },
                          ),
                          const SizedBox(width: 12),
                          TweenAnimationBuilder<double>(
                            tween: Tween<double>(
                              begin: 0.0,
                              end: value,
                            ),
                            duration: const Duration(milliseconds: 400),
                            curve: Curves.easeOutCubic,
                            builder: (context, textValue, child) {
                              return AnimatedDefaultTextStyle(
                                duration: const Duration(milliseconds: 200),
                                style: TextStyle(
                                  color: Color.lerp(
                                    Colors.white54,
                                    Colors.white,
                                    textValue,
                                  )!,
                                  fontSize: 14,
                                  fontWeight: textValue > 0.5
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                  letterSpacing: textValue * 0.3,
                                  shadows: textValue > 0.7
                                      ? [
                                          Shadow(
                                            color: Colors.white.withValues(
                                              alpha: 0.3,
                                            ),
                                            blurRadius: 8,
                                          ),
                                        ]
                                      : null,
                                ),
                                child: Text(widget.label),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      );
  }
}

class _AnimatedAccessControlItem extends StatefulWidget {
  const _AnimatedAccessControlItem({super.key});

  @override
  State<_AnimatedAccessControlItem> createState() =>
      _AnimatedAccessControlItemState();
}

class _AnimatedAccessControlItemState
    extends State<_AnimatedAccessControlItem>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _glowAnimation;
  bool _isHovered = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
      ),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0.3, 0.0),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOutCubic,
      ),
    );
    _glowAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.2, 1.0, curve: Curves.easeOut),
      ),
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: SlideTransition(
          position: _slideAnimation,
          child: AnimatedBuilder(
            animation: _glowAnimation,
            builder: (context, child) {
              final hoverScale = _isHovered ? 1.05 : 1.0;
              return Transform.scale(
                scale: hoverScale,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOutCubic,
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [
                        Color(0xFF6F4BFF),
                        Color(0xFF5A3FE0),
                      ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
                    boxShadow: [
          BoxShadow(
                        color: const Color(0xFF6F4BFF)
                            .withValues(alpha: _glowAnimation.value * 0.5),
                        blurRadius: 20 * _glowAnimation.value,
                        offset: Offset(0, 8 * _glowAnimation.value),
                        spreadRadius: -4 * _glowAnimation.value,
                      ),
                      if (_isHovered)
                        BoxShadow(
                          color: const Color(0xFF6F4BFF).withValues(alpha: 0.3),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                    ],
                  ),
                  child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
                      Icon(Icons.security, color: Colors.white, size: 22),
                      SizedBox(width: 10),
                Text(
                        'Access Control',
                        style: TextStyle(
                        color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                      ),
                ),
            ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _FloatingCircleIcon extends StatefulWidget {
  const _FloatingCircleIcon({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  State<_FloatingCircleIcon> createState() => _FloatingCircleIconState();
}

class _FloatingCircleIconState extends State<_FloatingCircleIcon>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const buttonSize = 66.0;
    return MouseRegion(
      onEnter: (_) => _controller.forward(),
      onExit: (_) => _controller.reverse(),
      child: Material(
      color: Colors.transparent,
      child: InkWell(
          onTap: widget.onTap,
        borderRadius: BorderRadius.circular(12),
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return Transform.scale(
                scale: 1.0 + (_controller.value * 0.1),
        child: Container(
          width: buttonSize,
          height: buttonSize,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
                    color: Color.lerp(
                      const Color(0xFF161626).withValues(alpha: 0.9),
                      const Color(0xFF1F1F3A).withValues(alpha: 0.95),
                      _controller.value,
                    ) ?? const Color(0xFF161626).withValues(alpha: 0.9),
                    border: Border.all(
                      color: Color.lerp(
                        Colors.white.withValues(alpha: 0.12),
                        Colors.white.withValues(alpha: 0.2),
                        _controller.value,
                      ) ?? Colors.white.withValues(alpha: 0.12),
                      width: 1.0 + (_controller.value * 0.5),
                    ),
                    boxShadow: [
              BoxShadow(
                        color: Color.lerp(
                          const Color(0x33000000),
                          const Color(0x55000000),
                          _controller.value,
                        ) ?? const Color(0x33000000),
                        blurRadius: 10 + (_controller.value * 8),
                        offset: Offset(0, 6 + (_controller.value * 4)),
              ),
            ],
          ),
                  child: Icon(
                    widget.icon,
                    color: Color.lerp(
                      Colors.white,
                      const Color(0xFF6F4BFF),
                      _controller.value,
                    ) ?? Colors.white,
                    size: 26 + (_controller.value * 2),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _ProfileSideSheet extends StatelessWidget {
  const _ProfileSideSheet({
    required this.user,
    required this.organization,
    required this.usersRepository,
    required this.onClose,
    required this.onChangeOrg,
    this.onOpenPermissions,
    required this.onLogout,
  });

  final UserProfile? user;
  final OrganizationMembership? organization;
  final UsersRepository usersRepository;
  final VoidCallback onClose;
  final VoidCallback onChangeOrg;
  final VoidCallback? onOpenPermissions;
  final VoidCallback onLogout;

  String _maskPhone(String phone) {
    if (phone.isEmpty) return '';
    if (phone.length <= 4) return phone;
    final visible = phone.substring(phone.length - 4);
    final masked =
        phone.substring(0, phone.length - 4).replaceAll(RegExp(r'.'), '•');
    return '$masked$visible';
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final width = (screenWidth * 0.65).clamp(280.0, 400.0);
    final maskedPhone = _maskPhone(user?.phoneNumber ?? '');

    return SizedBox(
      width: width,
      child: Material(
        color: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.fromLTRB(24, 60, 24, 24),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF11111B),
                Color(0xFF0D0D15),
              ],
            ),
            borderRadius: const BorderRadius.only(
              topRight: Radius.circular(32),
              bottomRight: Radius.circular(32),
            ),
            border: Border(
              left: BorderSide(
                color: Colors.white.withValues(alpha: 0.1),
                width: 1,
              ),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.6),
                blurRadius: 40,
                spreadRadius: -10,
                offset: const Offset(-10, 0),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0xFF1F1F2C),
                    ),
                    child: const Icon(Icons.person, color: Colors.white, size: 32),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        FutureBuilder<OrganizationUser?>(
                          future: (user?.id != null && organization?.id != null)
                              ? usersRepository.fetchCurrentUser(
                                  orgId: organization!.id,
                                  userId: user!.id,
                                  phoneNumber: user!.phoneNumber,
                                )
                              : Future.value(null),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState == ConnectionState.waiting) {
                              return const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white54,
                                ),
                              );
                            }
                            final userName = snapshot.data?.name ?? 
                                            user?.displayName ?? 
                                            'User';
                            return Text(
                              userName,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                              ),
                              overflow: TextOverflow.ellipsis,
                            );
                          },
                        ),
                        const SizedBox(height: 4),
                        Text(
                          maskedPhone.isNotEmpty ? maskedPhone : '—',
                          style: const TextStyle(color: Colors.white54),
                        ),
                        if (organization != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            '${organization!.name} • ${organization!.role}',
                            style: const TextStyle(
                              color: Colors.white38,
                              fontSize: 12,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: onClose,
                    icon: const Icon(Icons.close, color: Colors.white70),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              const Text(
                'Quick Actions',
                style: TextStyle(
                  color: Colors.white70,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              _ProfileAction(
                icon: Icons.swap_horiz,
                label: 'Change Organization',
                onTap: () {
                  onClose();
                  onChangeOrg();
                  },
                ),
              const _ProfileAction(
                icon: Icons.notifications_outlined,
                label: 'Notifications',
              ),
              if (onOpenPermissions != null)
                _ProfileAction(
                  icon: Icons.security,
                  label: 'Permissions',
                  onTap: () {
                    onClose();
                    onOpenPermissions!();
                  },
                ),
              const _ProfileAction(
                icon: Icons.lock_outline,
                label: 'Security',
              ),
              const _ProfileAction(
                icon: Icons.support_agent,
                label: 'Support',
              ),
              const Spacer(),
              DashButton(
                label: 'Logout',
                onPressed: () {
                  onClose();
                  onLogout();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileAction extends StatelessWidget {
  const _ProfileAction({
    required this.icon,
    required this.label,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOut,
                width: 40,
                height: 40,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white10,
                ),
                child: Icon(icon, color: Colors.white70, size: 20),
              ),
              const SizedBox(width: 16),
              Text(
                label,
                style: const TextStyle(color: Colors.white),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SettingsSideSheet extends StatelessWidget {
  const _SettingsSideSheet({
    required this.canManageRoles,
    required this.canManageUsers,
    required this.canManageVehicles,
    required this.canManageProducts,
    required this.canManageRawMaterials,
    required this.onClose,
    this.onOpenUsers,
    this.onOpenVehicles,
    required this.onOpenRoles,
    required this.onOpenProducts,
    required this.onOpenRawMaterials,
    this.onOpenPaymentAccounts,
    this.onOpenWageSettings,
    this.onOpenProductionBatchTemplates,
    required this.onOpenDmSettings,
  });

  final bool canManageRoles;
  final bool canManageUsers;
  final bool canManageVehicles;
  final bool canManageProducts;
  final bool canManageRawMaterials;
  final VoidCallback onClose;
  final VoidCallback? onOpenUsers;
  final VoidCallback? onOpenVehicles;
  final VoidCallback onOpenRoles;
  final VoidCallback onOpenProducts;
  final VoidCallback onOpenRawMaterials;
  final VoidCallback? onOpenPaymentAccounts;
  final VoidCallback? onOpenWageSettings;
  final VoidCallback? onOpenProductionBatchTemplates;
  final VoidCallback onOpenDmSettings;

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final width = (screenWidth * 0.65).clamp(280.0, 400.0);
    return SizedBox(
      width: width,
      child: Material(
        color: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.fromLTRB(24, 60, 24, 24),
          decoration: const BoxDecoration(
            color: Color(0xFF11111B),
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(28),
              bottomLeft: Radius.circular(28),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text(
                    'Settings',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: onClose,
                    icon: const Icon(Icons.close, color: Colors.white70),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Text(
                'Pages',
                style: TextStyle(color: Colors.white54),
              ),
              const SizedBox(height: 12),
              if (onOpenUsers != null)
                _SettingsTile(
                  label: 'Users',
                  onTap: () {
                    onClose();
                    onOpenUsers!();
                  },
                ),
              if (onOpenUsers != null) const SizedBox(height: 12),
              if (onOpenVehicles != null)
                _SettingsTile(
                  label: 'Vehicles',
                  onTap: () {
                    onClose();
                    onOpenVehicles!();
                  },
                ),
              if (onOpenVehicles != null) const SizedBox(height: 12),
              if (canManageRoles)
                _SettingsTile(
                  label: 'Roles',
                  onTap: () {
                    onClose();
                    onOpenRoles();
                  },
                )
              else
                const Text(
                  'Role management available for admins only.',
                  style: TextStyle(color: Colors.white38),
                ),
              const SizedBox(height: 12),
              _SettingsTile(
                label: 'Products',
                subtitle: canManageProducts ? null : 'Read only',
                onTap: () {
                  onClose();
                  onOpenProducts();
                },
              ),
              const SizedBox(height: 12),
              _SettingsTile(
                label: 'Raw Materials',
                subtitle: canManageRawMaterials ? null : 'Read only',
                onTap: () {
                  onClose();
                  onOpenRawMaterials();
                },
              ),
              const SizedBox(height: 12),
              if (onOpenPaymentAccounts != null)
                _SettingsTile(
                  label: 'Payment Accounts',
                  onTap: () {
                    onClose();
                    onOpenPaymentAccounts!();
                  },
                )
              else
                const Text(
                  'Payment accounts available for admins only.',
                  style: TextStyle(color: Colors.white38),
                ),
              const SizedBox(height: 12),
              if (onOpenWageSettings != null)
                _SettingsTile(
                  label: 'Wage Settings',
                  onTap: () {
                    onClose();
                    onOpenWageSettings!();
                  },
                ),
              if (onOpenWageSettings != null) const SizedBox(height: 12),
              if (onOpenProductionBatchTemplates != null)
                _SettingsTile(
                  label: 'Production Batches',
                  onTap: () {
                    onClose();
                    onOpenProductionBatchTemplates!();
                  },
                ),
              if (onOpenProductionBatchTemplates != null) const SizedBox(height: 12),
              _SettingsTile(
                label: 'DM Settings',
                onTap: () {
                  onClose();
                  onOpenDmSettings();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.label,
    this.subtitle,
    required this.onTap,
  });

  final String label;
  final String? subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          decoration: BoxDecoration(
            color: const Color(0xFF1B1B2C),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          child: ListTile(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
            title: Text(
              label,
              style: const TextStyle(color: Colors.white),
            ),
            subtitle: subtitle != null
                ? Text(
                    subtitle!,
                    style: const TextStyle(color: Colors.white38),
                  )
                : null,
            trailing: const Icon(Icons.chevron_right, color: Colors.white30),
          ),
        ),
      ),
    );
  }
}

class _ContentSideSheet extends StatelessWidget {
  const _ContentSideSheet({
    required this.page,
    required this.onClose,
    this.orgId,
    required this.appAccessRole,
    required this.isAdminRole,
    required this.canManageProducts,
    required this.canManageRawMaterials,
  });

  final ContentPage page;
  final VoidCallback onClose;
  final String? orgId;
  final AppAccessRole? appAccessRole;
  final bool isAdminRole;
  final bool canManageProducts;
  final bool canManageRawMaterials;

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final width = (screenWidth * 0.65).clamp(350.0, 600.0);

    String title;
    Widget content;

    switch (page) {
      case ContentPage.roles:
        title = 'Roles';
        if (orgId == null) {
          content = const Center(child: Text('No organization selected'));
        } else {
          final orgIdNonNull = orgId!;
          content = BlocProvider(
            create: (context) => JobRolesCubit(
              repository: context.read<JobRolesRepository>(),
              orgId: orgIdNonNull,
            )..load(),
            child: const RolesPageContent(),
          );
        }
        break;
      case ContentPage.products:
        title = 'Products';
        if (orgId == null || appAccessRole == null) {
          content = const Center(child: Text('No organization selected'));
        } else {
          final orgIdNonNull = orgId!;
          final appAccessRoleNonNull = appAccessRole!;
          content = BlocProvider(
            create: (context) => ProductsCubit(
              repository: context.read<ProductsRepository>(),
              orgId: orgIdNonNull,
              canCreate: canManageProducts,
              canEdit: appAccessRoleNonNull.canEdit('products'),
              canDelete: appAccessRoleNonNull.canDelete('products'),
            )..load(),
            child: ProductsPageContent(canCreate: canManageProducts),
          );
        }
        break;
      case ContentPage.rawMaterials:
        title = 'Raw Materials';
        if (orgId == null || appAccessRole == null) {
          content = const Center(child: Text('No organization selected'));
        } else {
          final orgIdNonNull = orgId!;
          final appAccessRoleNonNull = appAccessRole!;
          content = BlocProvider(
            create: (context) => RawMaterialsCubit(
              repository: context.read<RawMaterialsRepository>(),
              orgId: orgIdNonNull,
              canCreate: canManageRawMaterials,
              canEdit: appAccessRoleNonNull.canEdit('rawMaterials'),
              canDelete: appAccessRoleNonNull.canDelete('rawMaterials'),
            )..loadRawMaterials(),
            child: RawMaterialsPageContent(canCreate: canManageRawMaterials),
          );
        }
        break;
      case ContentPage.paymentAccounts:
        title = 'Payment Accounts';
        if (orgId == null) {
          content = const Center(child: Text('No organization selected'));
        } else {
          final orgIdNonNull = orgId!;
          content = BlocProvider(
            create: (context) => PaymentAccountsCubit(
              repository: context.read<PaymentAccountsRepository>(),
              qrCodeService: context.read<QrCodeService>(),
              orgId: orgIdNonNull,
            )..loadAccounts(),
            child: const PaymentAccountsPageContent(),
          );
        }
        break;
      case ContentPage.users:
        title = 'Users';
        if (orgId == null) {
          content = const Center(child: Text('No organization selected'));
        } else {
          content = Builder(
            builder: (context) {
              final orgState = context.read<OrganizationContextCubit>().state;
              final organization = orgState.organization;
              if (organization == null) {
                return const Center(child: Text('No organization selected'));
              }
              return BlocProvider(
                create: (context) => UsersCubit(
                  repository: context.read<UsersRepository>(),
                  appAccessRolesRepository: context.read<AppAccessRolesRepository>(),
                  organizationId: organization.id,
                  organizationName: organization.name,
                )..load(),
                child: const UsersPageContent(),
              );
            },
          );
        }
        break;
      case ContentPage.employees:
        title = 'Employees';
        if (orgId == null) {
          content = const Center(child: Text('No organization selected'));
        } else {
          final orgIdNonNull = orgId!;
          content = BlocProvider(
            create: (context) => EmployeesCubit(
              repository: context.read<EmployeesRepository>(),
              jobRolesRepository: context.read<JobRolesRepository>(),
              orgId: orgIdNonNull,
            )..loadEmployees(),
            child: const EmployeesPageContent(),
          );
        }
        break;
      case ContentPage.vehicles:
        title = 'Vehicles';
        if (orgId == null) {
          content = const Center(child: Text('No organization selected'));
        } else {
          final orgIdNonNull = orgId!;
          content = BlocProvider(
            create: (context) => VehiclesCubit(
              repository: context.read<VehiclesRepository>(),
              orgId: orgIdNonNull,
            )..loadVehicles(),
            child: const VehiclesPageContent(),
          );
        }
        break;
      case ContentPage.zones:
        title = 'Delivery Zones';
        if (orgId == null || appAccessRole == null) {
          content = const Center(child: Text('No organization selected'));
        } else {
          final orgIdNonNull = orgId!;
          final appAccessRoleNonNull = appAccessRole!;
          final zonesCityPerm = ZoneCrudPermission(
            canCreate: appAccessRoleNonNull.canCreate('zonesCity'),
            canEdit: appAccessRoleNonNull.canEdit('zonesCity'),
            canDelete: appAccessRoleNonNull.canDelete('zonesCity'),
          );
          final zonesRegionPerm = ZoneCrudPermission(
            canCreate: appAccessRoleNonNull.canCreate('zonesRegion'),
            canEdit: appAccessRoleNonNull.canEdit('zonesRegion'),
            canDelete: appAccessRoleNonNull.canDelete('zonesRegion'),
          );
          final zonesPricePerm = ZoneCrudPermission(
            canCreate: appAccessRoleNonNull.canCreate('zonesPrice'),
            canEdit: appAccessRoleNonNull.canEdit('zonesPrice'),
            canDelete: appAccessRoleNonNull.canDelete('zonesPrice'),
          );
          content = BlocProvider(
            create: (context) => DeliveryZonesCubit(
              repository: context.read<DeliveryZonesRepository>(),
              productsRepository: context.read<ProductsRepository>(),
              orgId: orgIdNonNull,
            )..loadZones(),
            child: ZonesPageContent(
              cityPermission: zonesCityPerm,
              regionPermission: zonesRegionPerm,
              pricePermission: zonesPricePerm,
              isAdmin: appAccessRoleNonNull.isAdmin,
            ),
          );
        }
        break;
      case ContentPage.wageSettings:
        title = 'Wage Settings';
        if (orgId == null) {
          content = const Center(child: Text('No organization selected'));
        } else {
          final orgIdNonNull = orgId!;
          content = BlocProvider(
            create: (context) => WageSettingsCubit(
              repository: context.read<WageSettingsRepository>(),
              organizationId: orgIdNonNull,
            )..loadSettings(),
            child: const WageSettingsPageContent(),
          );
        }
        break;
      case ContentPage.productionBatchTemplates:
        title = 'Production Batches';
        if (orgId == null) {
          content = const Center(child: Text('No organization selected'));
        } else {
          final orgIdNonNull = orgId!;
          content = BlocProvider(
            create: (context) => ProductionBatchTemplatesCubit(
              repository: context.read<ProductionBatchTemplatesRepository>(),
              organizationId: orgIdNonNull,
            )..loadTemplates(),
            child: const ProductionBatchTemplatesPageContent(),
          );
        }
        break;
      case ContentPage.none:
        title = '';
        content = const SizedBox.shrink();
        break;
    }

    return SizedBox(
      width: width,
      child: Material(
        color: Colors.transparent,
        child: Container(
          decoration: const BoxDecoration(
            color: Color(0xFF11111B),
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(28),
              bottomLeft: Radius.circular(28),
            ),
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFF1B1C2C),
                        Color(0xFF161622),
                      ],
                    ),
                    border: Border(
                      bottom: BorderSide(
                        color: Colors.white.withValues(alpha: 0.08),
                        width: 1,
                      ),
                    ),
                  ),
                child: SizedBox(
                  height: 32,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: IconButton(
                          onPressed: onClose,
                          icon: const Icon(Icons.arrow_back, color: Colors.white70),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          tooltip: 'Close',
                        ),
                      ),
                      Center(
                        child: Text(
                          title,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: content,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
