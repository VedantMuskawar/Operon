import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../../core/app_theme.dart';
import '../../../auth/android_auth_bloc.dart';
import '../../../vehicle/presentation/pages/android_vehicle_management_page.dart';
import '../../../payment_accounts/presentation/pages/android_payment_account_management_page.dart';
import '../../../products/presentation/pages/android_product_management_page.dart';
import '../../../location_pricing/presentation/pages/android_location_pricing_management_page.dart';
import 'android_organization_settings_page.dart';

class AndroidOrganizationHomePage extends StatefulWidget {
  final Map<String, dynamic> organization;

  const AndroidOrganizationHomePage({
    super.key,
    required this.organization,
  });

  @override
  State<AndroidOrganizationHomePage> createState() => _AndroidOrganizationHomePageState();
}

class _AndroidOrganizationHomePageState extends State<AndroidOrganizationHomePage> {
  int _currentBottomNavIndex = 0; // Default to Home (0), Settings is 4
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final firebaseUser = FirebaseAuth.instance.currentUser;
    
    return Scaffold(
      appBar: AppBar(
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        title: Text(
          widget.organization['orgName'] ?? 'OPERON',
          style: const TextStyle(
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
        backgroundColor: AppTheme.surfaceColor,
      ),
      drawer: _buildDrawer(context, firebaseUser),
      backgroundColor: AppTheme.backgroundColor,
      body: _buildBodyContent(context),
      bottomNavigationBar: _buildBottomNavigationBar(context),
    );
  }

  Widget _buildDrawer(BuildContext context, User? firebaseUser) {
    return Drawer(
      backgroundColor: AppTheme.surfaceColor,
      child: SafeArea(
        child: Column(
          children: [
            // Profile Header
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppTheme.cardColor,
                border: Border(
                  bottom: BorderSide(color: AppTheme.borderColor),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 32,
                    backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.3),
                    child: Icon(
                      Icons.person,
                      size: 32,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    firebaseUser?.phoneNumber ?? 'User',
                    style: const TextStyle(
                      color: AppTheme.textPrimaryColor,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (firebaseUser?.email != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      firebaseUser!.email!,
                      style: const TextStyle(
                        color: AppTheme.textSecondaryColor,
                        fontSize: 14,
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _getRoleName(widget.organization['role']),
                      style: const TextStyle(
                        color: AppTheme.primaryColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Organization Info
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Organization',
                    style: TextStyle(
                      color: AppTheme.textSecondaryColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.organization['orgName'] ?? 'N/A',
                    style: const TextStyle(
                      color: AppTheme.textPrimaryColor,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Status: ${widget.organization['status'] ?? 'N/A'}',
                    style: const TextStyle(
                      color: AppTheme.textSecondaryColor,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            // Menu Items
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  ListTile(
                    leading: const Icon(Icons.business, color: AppTheme.textPrimaryColor),
                    title: const Text(
                      'Switch Organization',
                      style: TextStyle(color: AppTheme.textPrimaryColor),
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      // Navigate back to organization selection
                      if (mounted) {
                        Navigator.of(context).popUntil((route) => route.isFirst);
                      }
                    },
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.settings, color: AppTheme.textPrimaryColor),
                    title: const Text(
                      'Settings',
                      style: TextStyle(color: AppTheme.textPrimaryColor),
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      if (mounted) {
                        final orgId = widget.organization['orgId'] ?? widget.organization['id'];
                        if (orgId != null) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => AndroidOrganizationSettingsPage(
                                organizationId: orgId.toString(),
                              ),
                            ),
                          );
                        }
                      }
                    },
                  ),
                  const Divider(height: 1),
                ],
              ),
            ),
            // Logout Button
            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    final authBloc = context.read<AndroidAuthBloc>();
                    Navigator.pop(context);
                    if (mounted) {
                      authBloc.add(AndroidAuthLogoutRequested());
                    }
                  },
                  icon: const Icon(Icons.logout),
                  label: const Text('Logout'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.errorColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBodyContent(BuildContext context) {
    switch (_currentBottomNavIndex) {
      case 0:
        return _buildHomeContent(context);
      case 1:
        return _buildTasksContent(context);
      case 2:
        return _buildAnalyticsContent(context);
      case 3:
        return _buildExploreContent(context);
      case 4:
        return _buildNavigationList(context); // Show grid only when Settings is selected
      default:
        return _buildHomeContent(context);
    }
  }

  Widget _buildHomeContent(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.dashboard,
            size: 64,
            color: AppTheme.textSecondaryColor,
          ),
          const SizedBox(height: 16),
          Text(
            'Home Dashboard',
            style: TextStyle(
              color: AppTheme.textPrimaryColor,
              fontSize: 24,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Welcome to OPERON',
            style: TextStyle(
              color: AppTheme.textSecondaryColor,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTasksContent(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.business_center,
            size: 64,
            color: AppTheme.textSecondaryColor,
          ),
          const SizedBox(height: 16),
          Text(
            'Tasks & Activities',
            style: TextStyle(
              color: AppTheme.textPrimaryColor,
              fontSize: 24,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Coming Soon',
            style: TextStyle(
              color: AppTheme.textSecondaryColor,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnalyticsContent(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.bar_chart,
            size: 64,
            color: AppTheme.textSecondaryColor,
          ),
          const SizedBox(height: 16),
          Text(
            'Analytics & Reports',
            style: TextStyle(
              color: AppTheme.textPrimaryColor,
              fontSize: 24,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Coming Soon',
            style: TextStyle(
              color: AppTheme.textSecondaryColor,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExploreContent(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.public,
            size: 64,
            color: AppTheme.textSecondaryColor,
          ),
          const SizedBox(height: 16),
          Text(
            'Explore',
            style: TextStyle(
              color: AppTheme.textPrimaryColor,
              fontSize: 24,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Coming Soon',
            style: TextStyle(
              color: AppTheme.textSecondaryColor,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavigationList(BuildContext context) {
    final navItems = [
      _NavItem(
        title: 'Organization Manager',
        icon: Icons.storefront,
        onTap: () {
          final orgId = widget.organization['orgId'] ?? widget.organization['id'];
          if (orgId != null) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => AndroidOrganizationSettingsPage(
                  organizationId: orgId.toString(),
                ),
              ),
            );
          }
        },
      ),
      _NavItem(
        title: 'Vehicle Management',
        icon: Icons.two_wheeler,
        onTap: () {
          final orgId = widget.organization['orgId'] ?? widget.organization['id'];
          final userId = FirebaseAuth.instance.currentUser?.uid ?? '';
          if (orgId != null && userId.isNotEmpty) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => AndroidVehicleManagementPage(
                  organizationId: orgId.toString(),
                  userId: userId,
                ),
              ),
            );
          }
        },
      ),
      _NavItem(
        title: 'Payment Store',
        icon: Icons.account_balance,
        onTap: () {
          final orgId = widget.organization['orgId'] ?? widget.organization['id'];
          final userId = FirebaseAuth.instance.currentUser?.uid ?? '';
          if (orgId != null && userId.isNotEmpty) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => AndroidPaymentAccountManagementPage(
                  organizationId: orgId.toString(),
                  userId: userId,
                ),
              ),
            );
          }
        },
      ),
      _NavItem(
        title: 'Product Store',
        icon: Icons.shopping_cart,
        onTap: () {
          final orgId = widget.organization['orgId'] ?? widget.organization['id'];
          final userId = FirebaseAuth.instance.currentUser?.uid ?? '';
          if (orgId != null && userId.isNotEmpty) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => AndroidProductManagementPage(
                  organizationId: orgId.toString(),
                  userId: userId,
                ),
              ),
            );
          }
        },
      ),
      _NavItem(
        title: 'Region Store',
        icon: Icons.location_on,
        onTap: () {
          final orgId = widget.organization['orgId'] ?? widget.organization['id'];
          final userId = FirebaseAuth.instance.currentUser?.uid ?? '';
          if (orgId != null && userId.isNotEmpty) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => AndroidLocationPricingManagementPage(
                  organizationId: orgId.toString(),
                  userId: userId,
                ),
              ),
            );
          }
        },
      ),
    ];

    return GridView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 1.0, // Square tiles
      ),
      itemCount: navItems.length,
      itemBuilder: (context, index) {
        final item = navItems[index];
        return _buildNavTile(context, item);
      },
    );
  }

  Widget _buildNavTile(BuildContext context, _NavItem item) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: AppTheme.borderColor,
          width: 1,
        ),
      ),
      color: AppTheme.surfaceColor,
      child: InkWell(
        onTap: item.onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                item.icon,
                color: AppTheme.primaryColor,
                size: 48,
              ),
              const SizedBox(height: 12),
              Text(
                item.title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppTheme.textPrimaryColor,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomNavigationBar(BuildContext context) {
    final navItems = [
      _BottomNavItem(icon: Icons.list, id: 'home'),
      _BottomNavItem(icon: Icons.business_center, id: 'tasks'),
      _BottomNavItem(icon: Icons.bar_chart, id: 'analytics'),
      _BottomNavItem(icon: Icons.public, id: 'explore'),
      _BottomNavItem(icon: Icons.settings, id: 'settings'),
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.backgroundColor,
        border: Border(
          top: BorderSide(
            color: AppTheme.borderColor,
            width: 1,
          ),
        ),
      ),
      child: SafeArea(
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppTheme.cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppTheme.borderColor,
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(navItems.length, (index) {
              final item = navItems[index];
              final isSelected = index == _currentBottomNavIndex;
              
              return Expanded(
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _currentBottomNavIndex = index;
                    });
                    _handleBottomNavTap(context, index);
                  },
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      gradient: isSelected 
                          ? AppTheme.primaryGradient 
                          : null,
                      color: isSelected 
                          ? null 
                          : Colors.transparent,
                    ),
                    child: Icon(
                      item.icon,
                      color: isSelected 
                          ? Colors.white 
                          : AppTheme.textSecondaryColor,
                      size: 24,
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }

  void _handleBottomNavTap(BuildContext context, int index) {
    if (!mounted) return;
    
    // If navigating from Settings to another tab, pop any child pages first
    if (_currentBottomNavIndex == 4 && index != 4) {
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    }
    
    // If navigating to Settings, ensure we're on the home page
    if (index == 4) {
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
      // Scroll to top when Settings is selected
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _scrollController.hasClients) {
          _scrollController.animateTo(
            0,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  String _getRoleName(dynamic role) {
    switch (role) {
      case 0:
        return 'Super Admin';
      case 1:
        return 'Admin';
      case 2:
        return 'Manager';
      case 3:
        return 'Driver';
      default:
        return 'Member';
    }
  }
}

class _NavItem {
  final String title;
  final IconData icon;
  final VoidCallback onTap;

  _NavItem({
    required this.title,
    required this.icon,
    required this.onTap,
  });
}

class _BottomNavItem {
  final IconData icon;
  final String id;

  _BottomNavItem({
    required this.icon,
    required this.id,
  });
}

