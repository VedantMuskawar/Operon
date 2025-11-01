import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import '../core/repositories/organization_repository.dart';
import '../core/models/organization.dart';
import '../features/organization/bloc/organization_bloc.dart';
import '../features/organization/presentation/pages/organization_select_page.dart';
import '../features/auth/bloc/auth_bloc.dart';
import '../features/auth/presentation/pages/login_page.dart';

class OrganizationContext extends ChangeNotifier {
  Map<String, dynamic>? _currentOrganization;
  OrganizationRepository? _organizationRepository;
  OrganizationBloc? _organizationBloc;
  bool _isLoading = false;
  String? _error;

  // Getters
  Map<String, dynamic>? get currentOrganization => _currentOrganization;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get hasOrganization {
    print('🔍 DEBUG: hasOrganization called - _currentOrganization: $_currentOrganization');
    return _currentOrganization != null;
  }
  String? get organizationId => _currentOrganization?['orgId'];
  String? get organizationName => _currentOrganization?['orgName'];
  int? get userRole => _currentOrganization?['role'];
  bool get isAdmin => userRole == 1;

  // Initialize with organization data
  void initializeOrganization(Map<String, dynamic> organization) {
    print('🔍 DEBUG: OrganizationContext.initializeOrganization called with: ${organization.toString()}');
    _currentOrganization = organization;
    _error = null;
    notifyListeners();
    print('🔍 DEBUG: OrganizationContext initialized - orgName: ${_currentOrganization?['orgName']}');
  }

  // Set organization repository and bloc
  void setRepositoryAndBloc(OrganizationRepository repository, OrganizationBloc bloc) {
    _organizationRepository = repository;
    _organizationBloc = bloc;
  }

  // Load organization details with subscription
  Future<void> loadOrganizationDetails() async {
    if (_organizationBloc == null || organizationId == null) return;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _organizationBloc!.add(LoadOrganizationDetails(organizationId!));
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  // Update organization details
  Future<void> updateOrganizationDetails(Map<String, dynamic> updatedData, {File? logoFile}) async {
    if (_organizationBloc == null || organizationId == null) return;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Create updated organization object
      final updatedOrg = Map<String, dynamic>.from(_currentOrganization!);
      updatedOrg.addAll(updatedData);
      
      // Convert to Organization model
      final organization = Organization.fromMap(updatedOrg);
      
      _organizationBloc!.add(UpdateOrganizationDetails(
        orgId: organizationId!,
        organization: organization,
        logoFile: logoFile,
      ));
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  // Switch to different organization
  Future<void> switchOrganization(Map<String, dynamic> newOrganization) async {
    _currentOrganization = newOrganization;
    _error = null;
    notifyListeners();
    
    // Load details for the new organization
    await loadOrganizationDetails();
  }

  // Clear current organization (logout)
  void clearOrganization() {
    _currentOrganization = null;
    _isLoading = false;
    _error = null;
    notifyListeners();
  }

  // Update loading state
  void setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  // Update error state
  void setError(String? error) {
    _error = error;
    notifyListeners();
  }

  // Get organization metadata
  Map<String, dynamic>? get metadata => _currentOrganization?['metadata'];

  // Get organization subscription info
  Map<String, dynamic>? get subscription => _currentOrganization?['subscription'];

  // Check if user has specific permission
  bool hasPermission(String permission) {
    final permissions = _currentOrganization?['permissions'] as List<dynamic>?;
    return permissions?.contains(permission) ?? false;
  }

  // Get user info from organization
  Map<String, dynamic>? get userInfo => _currentOrganization?['member'];

  // Get organization status
  String? get organizationStatus => _currentOrganization?['status'];

  // Check if organization is active
  bool get isOrganizationActive => organizationStatus == 'active';
}

class OrganizationProvider extends StatelessWidget {
  final Widget child;

  const OrganizationProvider({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<OrganizationContext>(
      create: (context) => OrganizationContext(),
      child: child,
    );
  }
}

// Extension for easy access to OrganizationContext
extension OrganizationContextExtension on BuildContext {
  OrganizationContext get organizationContext => Provider.of<OrganizationContext>(this, listen: false);
  OrganizationContext get watchOrganizationContext => Provider.of<OrganizationContext>(this);
}

// Organization-aware widget that automatically handles organization switching
class OrganizationAwareWidget extends StatelessWidget {
  final Widget Function(BuildContext context, OrganizationContext orgContext) builder;
  final Widget? loadingWidget;
  final Widget? errorWidget;
  final Widget? noOrganizationWidget;

  const OrganizationAwareWidget({
    super.key,
    required this.builder,
    this.loadingWidget,
    this.errorWidget,
    this.noOrganizationWidget,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<OrganizationContext>(
      builder: (context, orgContext, child) {
        // Show loading state
        if (orgContext.isLoading) {
          return loadingWidget ?? const Center(
            child: CircularProgressIndicator(
              color: Color(0xFF3B82F6),
            ),
          );
        }

        // Show error state
        if (orgContext.error != null) {
          return errorWidget ?? Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.error_outline,
                  color: Colors.red,
                  size: 48,
                ),
                const SizedBox(height: 16),
                Text(
                  'Error: ${orgContext.error}',
                  style: const TextStyle(color: Colors.red),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => orgContext.loadOrganizationDetails(),
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
        }

        // Show no organization state
        if (!orgContext.hasOrganization) {
          return noOrganizationWidget ?? Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.business_outlined,
                  color: Colors.grey,
                  size: 48,
                ),
                const SizedBox(height: 16),
                const Text(
                  'No Organization Selected',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(
                        builder: (context) => const OrganizationSelectPage(),
                      ),
                    );
                  },
                  child: const Text('Select Organization'),
                ),
              ],
            ),
          );
        }

        // Build the main widget with organization context
        return builder(context, orgContext);
      },
    );
  }
}

// Organization data filter mixin for repositories
mixin OrganizationDataFilter {
  String? _currentOrganizationId;

  void setCurrentOrganizationId(String? orgId) {
    _currentOrganizationId = orgId;
  }

  String? get currentOrganizationId => _currentOrganizationId;

  // Helper method to ensure queries are scoped to current organization
  Map<String, dynamic> addOrganizationFilter(Map<String, dynamic> query) {
    if (_currentOrganizationId != null) {
      query['orgId'] = _currentOrganizationId;
    }
    return query;
  }

  // Helper method to validate organization access
  bool canAccessOrganization(String? orgId) {
    return _currentOrganizationId == null || _currentOrganizationId == orgId;
  }
}

// Organization navigation helper
class OrganizationNavigation {
  static void navigateToOrganizationSelect(BuildContext context) {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (context) => const OrganizationSelectPage(),
      ),
      (route) => false,
    );
  }

  static void navigateToLogin(BuildContext context) {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (context) => const LoginPage(),
      ),
      (route) => false,
    );
  }

  static void logout(BuildContext context) {
    final orgContext = context.organizationContext;
    final authBloc = context.read<AuthBloc>();
    
    // Clear organization context
    orgContext.clearOrganization();
    
    // Trigger auth logout
    authBloc.add(AuthLogoutRequested());
  }
}
