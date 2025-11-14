import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../../core/navigation/organization_navigation_scope.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/models/organization.dart';
import '../../../../core/widgets/animated_background.dart';
import '../../../../core/widgets/navigation_pills.dart';
import '../../../../core/widgets/profile_dropdown.dart';
import '../../../auth/bloc/auth_bloc.dart';
import '../../../auth/presentation/pages/login_page.dart';
import 'organization_select_page.dart';
import '../widgets/organization_settings_view.dart';
import '../widgets/orders_map_view.dart';
import '../../../../contexts/organization_context.dart';
import '../../../vehicle/presentation/pages/vehicle_management_page.dart';
import '../../../vehicle/bloc/vehicle_bloc.dart';
import '../../../vehicle/bloc/vehicle_event.dart';
import '../../../vehicle/repositories/vehicle_repository.dart';
import '../../../payment_accounts/presentation/pages/payment_account_management_page.dart';
import '../../../payment_accounts/bloc/payment_account_bloc.dart';
import '../../../payment_accounts/bloc/payment_account_event.dart';
import '../../../payment_accounts/repositories/payment_account_repository.dart';
import '../../../products/presentation/pages/product_management_page.dart';
import '../../../products/bloc/product_bloc.dart';
import '../../../products/bloc/product_event.dart';
import '../../../products/repositories/product_repository.dart';
import '../../../user/presentation/widgets/organization_users_view.dart';
import '../../../location_pricing/presentation/pages/location_pricing_management_page.dart';
import '../../../location_pricing/bloc/location_pricing_bloc.dart';
import '../../../location_pricing/bloc/location_pricing_event.dart';
import '../../../location_pricing/repositories/location_pricing_repository.dart';
import '../../../orders/bloc/pending_orders_bloc.dart';
import '../../../orders/repositories/order_repository.dart';
import '../../../orders/repositories/scheduled_order_repository.dart';
import '../../../orders/presentation/widgets/pending_orders_view.dart';
import '../../../orders/presentation/widgets/scheduled_orders_dashboard.dart';
import '../../../crm/presentation/pages/crm_page.dart';
import '../../../dashboard/presentation/widgets/clients_metadata_panel.dart';

class OrganizationHomePage extends StatefulWidget {
  const OrganizationHomePage({
    super.key,
    this.sections,
    this.customViewBuilders = const {},
  });

  final List<SectionData>? sections;
  final Map<String, WidgetBuilder> customViewBuilders;

  static List<SectionData> defaultSections() {
    return [
      SectionData(
        label: "Organization Management",
        emoji: "🏢",
        items: [
          SectionItem(
            emoji: "⚙️",
            title: "Organization Settings",
            description: "Configure organization preferences and settings",
            viewId: 'organization-settings',
          ),
          SectionItem(
            emoji: "🚛",
            title: "Vehicle Management",
            description: "Manage fleet vehicles, maintenance, and operations",
            viewId: 'vehicle-management',
          ),
          SectionItem(
            emoji: "💳",
            title: "Payment Account Settings",
            description: "Manage payment methods and billing accounts",
            viewId: 'payment-account-management',
          ),
          SectionItem(
            emoji: "👥",
            title: "Users",
            description: "Manage organization members and roles",
            viewId: 'organization-users',
          ),
          SectionItem(
            emoji: "📋",
            title: "Products",
            description: "Manage product catalog and inventory",
            viewId: 'products',
          ),
          SectionItem(
            emoji: "📍",
            title: "Location Pricing",
            description: "Manage location-based pricing for orders",
            viewId: 'location-pricing',
          ),
          SectionItem(
            emoji: "💬",
            title: "CRM Messaging",
            description: "Craft customer notifications and WhatsApp templates",
            viewId: 'crm',
          ),
        ],
      ),
    ];
  }

  @override
  State<OrganizationHomePage> createState() => _OrganizationHomePageState();
}

class _OrganizationHomePageState extends State<OrganizationHomePage>
    with TickerProviderStateMixin {
  static const double _dashboardTileAspectRatio = 4 / 3;
  int _selectedNavigationIndex = 0;
  bool _showProfileDropdown = false;
  String _currentView =
      'home'; // 'home', 'organization-settings', 'vehicle-management', 'payment-account-management', 'products'
  late AnimationController _headerAnimationController;
  late final ScheduledOrderRepository _scheduledOrderRepository;
  late final OrderRepository _orderRepository;

  List<NavigationPillItem> get _navigationItems {
    final orgContext = context.organizationContext;
    final isAdmin = orgContext.isAdmin;
    final items = [
      const NavigationPillItem(id: 'home', label: 'Home'),
      const NavigationPillItem(id: 'orders-map', label: 'Orders Map'),
      const NavigationPillItem(
        id: 'pending-orders',
        label: 'Pending Orders',
      ),
      const NavigationPillItem(
        id: 'scheduled-orders',
        label: 'Scheduled Orders',
      ),
    ];

    // Add Dashboard only for admin users (like PaveBoard)
    if (isAdmin) {
      items.add(const NavigationPillItem(id: 'dashboard', label: 'Dashboard'));
    }

    return items;
  }

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _scheduledOrderRepository = ScheduledOrderRepository();
    _orderRepository = OrderRepository();
  }

  void _initializeAnimations() {
    _headerAnimationController = AnimationController(
      duration: AppTheme.animationSlow,
      vsync: this,
    );

    // Start header animation
    _headerAnimationController.forward();
  }

  @override
  void dispose() {
    _headerAnimationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = false; // Desktop only app

    return OrganizationAwareWidget(
      builder: (context, orgContext) {
        return BlocListener<AuthBloc, AuthState>(
          listener: (context, state) {
            if (state is AuthUnauthenticated) {
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (context) => const LoginPage()),
                (route) => false,
              );
            }
          },
          child: Scaffold(
            backgroundColor: Colors.transparent,
            body: AnimatedBackground(
              child: SafeArea(
                child: Column(
                  children: [
                    // Header with Navigation and Profile
                    _buildHeader(isMobile, orgContext),

                    // Main Content
                    Expanded(
                      child: OrganizationNavigationScope(
                        goHome: () => setState(() => _currentView = 'home'),
                        goToView: (viewId) => setState(() => _currentView = viewId),
                        currentView: _currentView,
                        child: _buildMainContent(orgContext),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader(bool isMobile, OrganizationContext orgContext) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF0A0A0A), // from-gray-950/95
            Color(0xFF000000), // via-black/95
            Color(0xFF0A0A0A), // to-gray-950/95
          ],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        border: Border(
          bottom: BorderSide(
            color: Colors.white.withValues(alpha: 0.1), // border-white/10
            width: 1,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32), // px-8 (32px)
        child: SizedBox(
          height: 96, // py-6 (24px top + 24px bottom + content height)
          child: Row(
            children: [
              // Left - Operon Title with gradient
              Expanded(flex: 1, child: _buildPaveHomeTitle(orgContext)),

              // Center - Navigation Pills
              Expanded(flex: 2, child: _buildNavigationPills()),

              // Right - Organization and Profile
              Expanded(flex: 1, child: _buildRightSection(orgContext)),
            ],
          ),
        ),
      ),
    );
  }

  double _getPillWidth() {
    // Calculate width based on current selected item's text content + padding
    // PaveBoard exact: padding: 1rem 1.5rem = 16px 24px
    const double horizontalPadding = 48; // 24px * 2

    // Get the current selected item's label
    String currentLabel = _navigationItems[_selectedNavigationIndex].label;

    // Calculate text width using TextPainter (active pill uses 1.05rem)
    final textPainter = TextPainter(
      text: TextSpan(
        text: currentLabel,
        style: const TextStyle(
          fontSize: 16.8, // 1.05rem for active pill
          fontWeight: FontWeight.w600, // var(--font-weight-semibold)
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();

    return horizontalPadding + textPainter.width;
  }

  double _getPillOffset() {
    // Calculate the offset position for the selected pill
    // Account for container padding (8px)
    double offset = 0;
    for (int i = 0; i < _selectedNavigationIndex; i++) {
      offset += _getPillWidthForIndex(i);
    }
    return offset;
  }

  double _getPillWidthForIndex(int index) {
    // Calculate width for a specific pill index
    // PaveBoard exact: padding: 1rem 1.5rem = 16px 24px
    const double horizontalPadding = 48; // 24px * 2

    String label = _navigationItems[index].label;
    bool isActive = index == _selectedNavigationIndex;

    final textPainter = TextPainter(
      text: TextSpan(
        text: label,
        style: TextStyle(
          fontSize: isActive
              ? 16.8
              : 16, // 1.05rem for active, 1rem for inactive
          fontWeight: FontWeight.w600, // var(--font-weight-semibold)
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();

    return horizontalPadding + textPainter.width;
  }

  Widget _buildPaveHomeTitle(OrganizationContext orgContext) {
    return Row(
      children: [
        // Operon with gradient - PaveBoard exact: from-blue-400 via-purple-400 to-cyan-400
        ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(
            colors: [
              Color(0xFF60A5FA), // blue-400
              Color(0xFFA855F7), // purple-400
              Color(0xFF22D3EE), // cyan-400
            ],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ).createShader(bounds),
          child: Text(
            'Operon',
            style: const TextStyle(
              fontSize: 32, // text-3xl
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
        // Organization name removed as requested for web home page
      ],
    );
  }

  Widget _buildNavigationPills() {
    return Center(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Container(
          padding: const EdgeInsets.all(8), // 0.5rem padding
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B), // Dark background for pills container
            borderRadius: BorderRadius.circular(12),
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // Sliding background indicator
              AnimatedPositioned(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                top: 0, // Align with container padding
                bottom: 0, // Align with container padding
                left: _getPillOffset(),
                child: Container(
                  width: _getPillWidth(),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [
                        Color(0xFF667EEA), // #667eea
                        Color(0xFF764BA2), // #764ba2
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(
                      8,
                    ), // var(--radius-md) = 0.5rem = 8px
                  ),
                ),
              ),
              // Pills
              Row(
                mainAxisSize: MainAxisSize.min,
                children: _navigationItems.asMap().entries.map((entry) {
                  final index = entry.key;
                  final item = entry.value;
                  final isSelected = index == _selectedNavigationIndex;

                  return GestureDetector(
                    onTap: () => _onNavigationItemSelected(index),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 16,
                      ), // 1rem 1.5rem (16px 24px)
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(
                          8,
                        ), // var(--radius-md) = 0.5rem = 8px
                      ),
                      child: Text(
                        item.label,
                        style: TextStyle(
                          fontSize: isSelected
                              ? 16.8
                              : 16, // 1.05rem for active, 1rem for inactive
                          fontWeight:
                              FontWeight.w600, // var(--font-weight-semibold)
                          color: isSelected
                              ? Colors.white
                              : const Color(
                                  0xFF94A3B8,
                                ), // Light gray for inactive
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRightSection(OrganizationContext orgContext) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            // Organization button with building icon - PaveBoard style
            GestureDetector(
              onTap: () => _navigateToOrganizationSelector(),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8), // var(--radius-md)
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [
                            Color(0xFF3B82F6),
                            Color(0xFF8B5CF6),
                          ], // blue-500 to purple-500
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Icon(
                        Icons.business,
                        size: 12,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      orgContext.organizationName ?? 'Organization',
                      style: const TextStyle(
                        color: Colors.black,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),

            // Profile icon with dropdown
            GestureDetector(
              onTap: () =>
                  setState(() => _showProfileDropdown = !_showProfileDropdown),
              child: Container(
                width: 40,
                height: 40,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [
                      Color(0xFF8B5CF6), // Purple
                      Color(0xFF3B82F6), // Blue
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Stack(
                  children: [
                    Center(
                      child: Text(
                        _getUserInitial(orgContext),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    // Dropdown chevron
                    Positioned(
                      right: 2,
                      bottom: 2,
                      child: Container(
                        width: 16,
                        height: 16,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.keyboard_arrow_down,
                          size: 12,
                          color: Colors.black,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),

        // Profile Dropdown
        if (_showProfileDropdown)
          Positioned(
            top: 56,
            right: 0,
            child: ProfileDropdown(
              userName: _getUserName(orgContext),
              userPhone: orgContext.userInfo?['phoneNo'],
              organizationName: orgContext.organizationName ?? 'Organization',
              userRole: orgContext.userRole ?? 0,
              onEditProfile: _handleEditProfile,
              onSwitchOrganization: _handleSwitchOrganization,
              onSignOut: _handleSignOut,
            ),
          ),
      ],
    );
  }

  Widget _buildMainContent(OrganizationContext orgContext) {
    final selectedNavId = _navigationItems[_selectedNavigationIndex].id;

    if (widget.customViewBuilders.containsKey(_currentView)) {
      return widget.customViewBuilders[_currentView]!(context);
    }

    if (_currentView == 'home') {
      if (selectedNavId == 'pending-orders') {
        return Padding(
          padding: EdgeInsets.all(AppTheme.getResponsivePadding(context)),
          child: _buildPendingOrdersSection(orgContext),
        );
      }
      if (selectedNavId == 'scheduled-orders') {
        return Padding(
          padding: EdgeInsets.all(AppTheme.getResponsivePadding(context)),
          child: _buildScheduledOrdersSection(orgContext),
        );
      }
      if (selectedNavId == 'crm') {
        return Padding(
          padding: EdgeInsets.all(AppTheme.getResponsivePadding(context)),
          child: _buildCrmSection(orgContext),
        );
      }
      if (selectedNavId == 'orders-map') {
        return Padding(
          padding: EdgeInsets.all(AppTheme.getResponsivePadding(context)),
          child: orgContext.organizationId != null
              ? OrdersMapView(
                  organizationId: orgContext.organizationId!,
                  organizationName: orgContext.organizationName,
                )
              : const Center(
                  child: Padding(
                    padding: EdgeInsets.all(40),
                    child: Text(
                      'Organization not found',
                      style: TextStyle(color: Color(0xFFF5F5F7)),
                    ),
                  ),
                ),
        );
      }
      if (selectedNavId == 'dashboard') {
        return SingleChildScrollView(
          padding: EdgeInsets.all(AppTheme.getResponsivePadding(context)),
          child: ClientsMetadataPanel(),
        );
      }
    }

    return SingleChildScrollView(
      padding: EdgeInsets.all(AppTheme.getResponsivePadding(context)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_currentView == 'home') ...[
            if (_selectedNavigationIndex == 0) ...[
              // Home View - Section Cards (no welcome section like PaveBoard)
              _buildHomeView(),
            ] else ...[
              // Placeholder views for other navigation items
              _buildPlaceholderView(),
            ],
          ] else if (_currentView == 'organization-settings') ...[
            // Organization Settings View
            OrganizationSettingsView(
              onBack: () => setState(() => _currentView = 'home'),
            ),
          ] else if (_currentView == 'vehicle-management') ...[
            // Vehicle Management View
            orgContext.organizationId != null
                ? BlocProvider(
                    create: (context) =>
                        VehicleBloc(vehicleRepository: VehicleRepository())
                          ..add(LoadVehicles(orgContext.organizationId!)),
                    child: VehicleManagementView(
                      organizationId: orgContext.organizationId!,
                      userRole: orgContext.userRole ?? 0,
                      onBack: () => setState(() => _currentView = 'home'),
                    ),
                  )
                : const Center(
                    child: Padding(
                      padding: EdgeInsets.all(40),
                      child: Text(
                        'Organization not found',
                        style: TextStyle(color: Color(0xFFF5F5F7)),
                      ),
                    ),
                  ),
          ] else if (_currentView == 'payment-account-management') ...[
            // Payment Account Management View
            orgContext.organizationId != null
                ? BlocProvider(
                    create: (context) => PaymentAccountBloc(
                      paymentAccountRepository: PaymentAccountRepository(),
                    )..add(LoadPaymentAccounts(orgContext.organizationId!)),
                    child: PaymentAccountManagementView(
                      organizationId: orgContext.organizationId!,
                      userRole: orgContext.userRole ?? 0,
                      onBack: () => setState(() => _currentView = 'home'),
                    ),
                  )
                : const Center(
                    child: Padding(
                      padding: EdgeInsets.all(40),
                      child: Text(
                        'Organization not found',
                        style: TextStyle(color: Color(0xFFF5F5F7)),
                      ),
                    ),
                  ),
          ] else if (_currentView == 'products') ...[
            // Products Management View
            orgContext.organizationId != null
                ? BlocProvider(
                    create: (context) =>
                        ProductBloc(productRepository: ProductRepository())
                          ..add(LoadProducts(orgContext.organizationId!)),
                    child: ProductManagementView(
                      organizationId: orgContext.organizationId!,
                      userRole: orgContext.userRole ?? 0,
                      onBack: () => setState(() => _currentView = 'home'),
                    ),
                  )
                : const Center(
                    child: Padding(
                      padding: EdgeInsets.all(40),
                      child: Text(
                        'Organization not found',
                        style: TextStyle(color: Color(0xFFF5F5F7)),
                      ),
                    ),
                  ),
          ] else if (_currentView == 'location-pricing') ...[
            // Location Pricing Management View
            orgContext.organizationId != null
                ? BlocProvider(
                    create: (context) => LocationPricingBloc(
                      locationPricingRepository: LocationPricingRepository(),
                    )..add(LoadLocationPricing(orgContext.organizationId!)),
                    child: LocationPricingManagementView(
                      organizationId: orgContext.organizationId!,
                      userRole: orgContext.userRole ?? 0,
                      onBack: () => setState(() => _currentView = 'home'),
                    ),
                  )
                : const Center(
                    child: Padding(
                      padding: EdgeInsets.all(40),
                      child: Text(
                        'Organization not found',
                        style: TextStyle(color: Color(0xFFF5F5F7)),
                      ),
                    ),
                  ),
          ] else if (_currentView == 'organization-users') ...[
            _buildUsersManagementView(orgContext),
          ],
        ],
      ),
    );
  }

  Widget _buildHomeView() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Dashboard Grid - Exact PaveBoard style
          _buildDashboardGrid(),
        ],
      ),
    );
  }

  Widget _buildDashboardGrid() {
    final sections = _getSections();
    final screenWidth = MediaQuery.of(context).size.width;

    // Responsive grid matching PaveBoard: grid-cols-1 sm:grid-cols-2 lg:grid-cols-2 xl:grid-cols-4
    int crossAxisCount;
    double spacing;

    if (screenWidth >= 1280) {
      // xl:grid-cols-4
      crossAxisCount = 4;
      spacing = 40; // lg:gap-10
    } else if (screenWidth >= 1024) {
      // lg:grid-cols-2
      crossAxisCount = 2;
      spacing = 40; // lg:gap-10
    } else if (screenWidth >= 640) {
      // sm:grid-cols-2
      crossAxisCount = 2;
      spacing = 32; // sm:gap-8
    } else {
      // grid-cols-1
      crossAxisCount = 1;
      spacing = 24; // gap-6
    }

    return _buildResponsiveGrid(sections, crossAxisCount, spacing);
  }

  Widget _buildResponsiveGrid(
    List<SectionData> sections,
    int crossAxisCount,
    double spacing,
  ) {
    final rows = <Widget>[];
    final sectionWidgets = sections
        .map((section) => _buildSectionCard(section))
        .toList();

    for (int i = 0; i < sectionWidgets.length; i += crossAxisCount) {
      if (i > 0) {
        rows.add(SizedBox(height: spacing));
      }

      final rowItems = sectionWidgets.skip(i).take(crossAxisCount).toList();
      rows.add(
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (int j = 0; j < rowItems.length; j++) ...[
              Expanded(child: rowItems[j]),
              if (j < rowItems.length - 1) SizedBox(width: spacing),
            ],
            // Fill remaining space if fewer items than crossAxisCount
            for (int j = rowItems.length; j < crossAxisCount; j++) ...[
              if (j > 0) SizedBox(width: spacing),
              const Spacer(),
            ],
          ],
        ),
      );
    }

    return Column(children: rows);
  }

  Widget _buildUsersManagementView(OrganizationContext orgContext) {
    final organization = _mapOrganizationFromContext(orgContext);

    if (organization == null) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(40),
          child: Text(
            'Organization not found',
            style: TextStyle(color: Color(0xFFF5F5F7)),
          ),
        ),
      );
    }

    return OrganizationUsersView(
      organization: organization,
      userRole: orgContext.userRole ?? 0,
      onBack: () => setState(() => _currentView = 'home'),
    );
  }

  Organization? _mapOrganizationFromContext(OrganizationContext orgContext) {
    final data = orgContext.currentOrganization;
    if (data == null) {
      return null;
    }

    final sanitized = Map<String, dynamic>.from(data);

    final createdDate = sanitized['createdDate'];
    if (createdDate is DateTime) {
      sanitized['createdDate'] = Timestamp.fromDate(createdDate);
    }

    final updatedDate = sanitized['updatedDate'];
    if (updatedDate is DateTime) {
      sanitized['updatedDate'] = Timestamp.fromDate(updatedDate);
    }

    try {
      return Organization.fromMap(sanitized);
    } catch (_) {
      return null;
    }
  }

  List<SectionData> _getSections() {
    return widget.sections ?? OrganizationHomePage.defaultSections();
  }

  Widget _buildSectionCard(SectionData section) {
    return Container(
      padding: const EdgeInsets.all(32), // p-6 lg:p-8
      decoration: BoxDecoration(
        color: const Color(0xFF1F2937), // card-elevated background
        border: Border.all(
          color: const Color(0xFF374151), // border-white/20 equivalent
          width: 1,
        ),
        borderRadius: BorderRadius.circular(16), // rounded-xl
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min, // Adapt to content height
        children: [
          // Section Header - Exact PaveBoard style
          Container(
            margin: const EdgeInsets.only(bottom: 40), // mb-10
            padding: const EdgeInsets.only(bottom: 24), // pb-6
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: Color(0x33FFFFFF), // border-white/20
                  width: 1,
                ),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  section.emoji,
                  style: const TextStyle(
                    fontSize: 24,
                    shadows: [
                      Shadow(
                        color: Colors.black54,
                        blurRadius: 4,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12), // gap-3
                Flexible(
                  child: Text(
                    section.label,
                    style: const TextStyle(
                      fontSize: 20, // Slightly smaller to prevent overflow
                      fontWeight: FontWeight.bold, // font-bold
                      color: Color(0xFFF3F4F6), // text-gray-100
                      letterSpacing: -0.025, // tracking-tight
                      height: 1.1, // leading-tight
                    ),
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
              ],
            ),
          ),

          // Section Content - Exact 2 columns like PaveBoard: grid grid-cols-2
          Column(children: _buildItemRows(section.items)),
        ],
      ),
    );
  }

  List<Widget> _buildItemRows(List<SectionItem> items) {
    final rows = <Widget>[];
    const int itemsPerRow = 2;

    for (int i = 0; i < items.length; i += itemsPerRow) {
      if (i > 0) {
        rows.add(const SizedBox(height: 24)); // gap between rows
      }

      final rowItems = items.skip(i).take(itemsPerRow).toList();
      rows.add(
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _buildDashboardTile(rowItems[0])),
              if (rowItems.length > 1) ...[
                const SizedBox(width: 24), // gap-6 sm:gap-8
                Expanded(child: _buildDashboardTile(rowItems[1])),
              ] else ...[
                // If only 1 tile in row, add spacer to left-align it
                const Spacer(),
              ],
            ],
          ),
        ),
      );
    }

    return rows;
  }

  Widget _buildDashboardTile(SectionItem item) {
    final screenWidth = MediaQuery.of(context).size.width;

    // Responsive sizing based on screen size
    final padding = screenWidth >= 640 ? 16.0 : 12.0;
    final emojiSize = screenWidth >= 640 ? 36.0 : 28.0;
    final fontSize = screenWidth >= 640 ? 13.0 : 12.0;
    final marginBottom = screenWidth >= 640 ? 12.0 : 8.0;

    return GestureDetector(
      onTap: () => _onTileTapped(item),
      child: AspectRatio(
        aspectRatio: _dashboardTileAspectRatio,
        child: Container(
          padding: EdgeInsets.all(padding),
          constraints: const BoxConstraints(minHeight: 100),
          decoration: BoxDecoration(
            color: const Color(0xFF1F2937), // card background
            border: Border.all(
              color: const Color(0xFF374151), // border color
              width: 1,
            ),
            borderRadius: BorderRadius.circular(16), // rounded-xl
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.center,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Tile Icon - Responsive sizing
                Container(
                  margin: EdgeInsets.only(bottom: marginBottom),
                  child: Text(
                    item.emoji,
                    style: TextStyle(
                      fontSize: emojiSize,
                      shadows: const [
                        Shadow(
                          color: Colors.black54,
                          blurRadius: 4,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                  ),
                ),
                // Tile Title - Responsive sizing
                SizedBox(
                  width: 120,
                  child: Text(
                    item.title,
                    style: TextStyle(
                      fontSize: fontSize,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFFF3F4F6), // text-gray-100
                      height: 1.2, // leading-tight
                      letterSpacing: 0.025, // tracking-wide
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _onTileTapped(SectionItem item) {
    switch (item.viewId) {
      case 'organization-settings':
        setState(() => _currentView = 'organization-settings');
        break;
      case 'vehicle-management':
        setState(() => _currentView = 'vehicle-management');
        break;
      case 'payment-account-management':
        setState(() => _currentView = 'payment-account-management');
        break;
      case 'organization-users':
        setState(() => _currentView = 'organization-users');
        break;
      case 'products':
        setState(() => _currentView = 'products');
        break;
      case 'location-pricing':
        setState(() => _currentView = 'location-pricing');
        break;
      case 'crm':
        setState(() {
          _currentView = 'home';
          final crmIndex =
              _navigationItems.indexWhere((navItem) => navItem.id == 'crm');
          if (crmIndex != -1) {
            _selectedNavigationIndex = crmIndex;
          }
        });
        break;
      default:
        if (widget.customViewBuilders.containsKey(item.viewId)) {
          setState(() => _currentView = item.viewId);
        } else {
          _showPlaceholderDialog(item.title);
        }
    }
  }

  void _showPlaceholderDialog(String title) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF3B82F6), Color(0xFF8B5CF6)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.construction,
                color: Colors.white,
                size: 18,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.construction, size: 48, color: Colors.orange),
            const SizedBox(height: 16),
            Text(
              'Coming Soon!',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'This feature is currently under development and will be available soon.',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.8),
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(
              'OK',
              style: TextStyle(
                color: Color(0xFF3B82F6),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceholderView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.construction,
            size: 64,
            color: AppTheme.textSecondaryColor,
          ),
          const SizedBox(height: AppTheme.spacingLg),
          Text(
            'Coming Soon!',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              color: AppTheme.textPrimaryColor,
            ),
          ),
          const SizedBox(height: AppTheme.spacingSm),
          Text(
            'This feature is under development.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppTheme.textSecondaryColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPendingOrdersSection(OrganizationContext orgContext) {
    final organizationId = orgContext.organizationId;
    final userId = _resolveUserId(orgContext);

    if (organizationId == null || organizationId.isEmpty) {
      return _buildCenteredMessage('Organization not found');
    }

    if (userId.isEmpty) {
      return _buildCenteredMessage('Unable to determine user identity.');
    }

    return BlocProvider(
      key: ValueKey<String>('pending-orders-$organizationId'),
      create: (_) => PendingOrdersBloc(
        orderRepository: _orderRepository,
      ),
      child: PendingOrdersView(
        organizationId: organizationId,
        userId: userId,
        scheduledOrderRepository: _scheduledOrderRepository,
      ),
    );
  }

  Widget _buildScheduledOrdersSection(OrganizationContext orgContext) {
    final organizationId = orgContext.organizationId;
    if (organizationId == null || organizationId.isEmpty) {
      return _buildCenteredMessage('Organization not found');
    }

    final userId = _resolveUserId(orgContext);
    if (userId.isEmpty) {
      return _buildCenteredMessage('Unable to determine user identity.');
    }

    return Container(
      height: double.infinity,
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppTheme.radiusXl),
      ),
      child: ScheduledOrdersDashboard(
        organizationId: organizationId,
        repository: _scheduledOrderRepository,
        orderRepository: _orderRepository,
        userId: userId,
      ),
    );
  }

  Widget _buildCrmSection(OrganizationContext orgContext) {
    final organizationId = orgContext.organizationId;
    if (organizationId == null || organizationId.isEmpty) {
      return _buildCenteredMessage('Organization not found');
    }

    return CrmPage(
      organizationId: organizationId,
      organizationName: orgContext.organizationName,
    );
  }

  Widget _buildCenteredMessage(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Text(
          message,
          style: const TextStyle(color: Color(0xFFF5F5F7)),
        ),
      ),
    );
  }

  String _resolveUserId(OrganizationContext orgContext) {
    final authState = context.read<AuthBloc>().state;
    if (authState is AuthAuthenticated) {
      return authState.firebaseUser.uid;
    }
    if (authState is AuthOrganizationSelectionRequired) {
      return authState.firebaseUser.uid;
    }

    return (orgContext.userInfo?['userId'] as String?) ??
        (orgContext.userInfo?['uid'] as String?) ??
        FirebaseAuth.instance.currentUser?.uid ??
        '';
  }

  void _onNavigationItemSelected(int index) {
    setState(() {
      _selectedNavigationIndex = index;
    });
  }

  void _handleEditProfile() {
    setState(() => _showProfileDropdown = false);
    // TODO: Implement edit profile functionality
  }

  void _handleSwitchOrganization() {
    setState(() => _showProfileDropdown = false);
    // Navigate back to organization selection
    Navigator.of(context).pop();
  }

  void _handleSignOut() {
    setState(() => _showProfileDropdown = false);
    context.read<AuthBloc>().add(AuthLogoutRequested());
  }

  void _navigateToOrganizationSelector() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => const OrganizationSelectPage()),
    );
  }

  String _getUserName(OrganizationContext orgContext) {
    return orgContext.userInfo?['name'] ??
        orgContext.currentOrganization?['name'] ??
        'User';
  }

  String _getUserInitial(OrganizationContext orgContext) {
    final name = _getUserName(orgContext);
    return name.isNotEmpty ? name[0].toUpperCase() : 'U';
  }
}

// Data classes for sections
class SectionData {
  final String label;
  final String emoji;
  final List<SectionItem> items;

  SectionData({required this.label, required this.emoji, required this.items});
}

class SectionItem {
  final String emoji;
  final String title;
  final String description;
  final String viewId;

  SectionItem({
    required this.emoji,
    required this.title,
    required this.description,
    String? viewId,
  }) : viewId = viewId ?? title;
}
