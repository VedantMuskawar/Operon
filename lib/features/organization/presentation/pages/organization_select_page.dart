import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/repositories/organization_repository.dart';
import '../../../auth/bloc/auth_bloc.dart';
import '../../../dashboard/presentation/pages/super_admin_dashboard.dart';
import '../../bloc/organization_bloc.dart';
import 'organization_home_page.dart';
import 'web_organization_home_page.dart';
import '../../../../contexts/organization_context.dart';

class OrganizationSelectPage extends StatelessWidget {
  const OrganizationSelectPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF141416), // PaveBoard background
              Color(0xFF0A0A0B),
            ],
          ),
        ),
        child: SafeArea(
          child: BlocBuilder<AuthBloc, AuthState>(
            builder: (context, state) {
              if (state is AuthOrganizationSelectionRequired) {
                return _buildOrganizationSelection(context, state);
              } else if (state is AuthLoading) {
                return _buildLoadingState();
              } else {
                return _buildErrorState();
              }
            },
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF3B82F6), Color(0xFF8B5CF6)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: const Color.fromRGBO(59, 130, 246, 0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: const Center(
              child: SizedBox(
                width: 40,
                height: 40,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Loading Organizations',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Color(0xFFF9FAFB), // gray-50
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Please wait while we fetch your data...',
            style: TextStyle(
              color: Color(0xFF9CA3AF), // gray-400
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFEF4444), Color(0xFFDC2626)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(
              Icons.error_outline,
              size: 40,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Something went wrong',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Color(0xFFF9FAFB), // gray-50
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Please try again',
            style: TextStyle(
              color: Color(0xFF9CA3AF), // gray-400
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrganizationSelection(
    BuildContext context,
    AuthOrganizationSelectionRequired state,
  ) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: 896, // max-w-4xl = 56rem = 896px (PaveBoard exact)
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(
            24.0,
          ), // px-6 py-12 = 24px horizontal, 48px vertical
          child: Column(
            children: [
              _buildHeader(context, state),
              const SizedBox(height: 48), // mb-12 = 48px
              _buildOrganizationsList(context, state),
              const SizedBox(height: 48), // mb-12 = 48px
              _buildSignOutOption(context),
              const SizedBox(height: 48), // mt-12 = 48px
              _buildFooter(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(
    BuildContext context,
    AuthOrganizationSelectionRequired state,
  ) {
    return Column(
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [
                Color(0xFF8B5CF6),
                Color(0xFFEC4899),
              ], // purple-500 to pink-600
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF8B5CF6).withValues(alpha: 0.3),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: const Center(
            child: Text('🏢', style: TextStyle(fontSize: 32)),
          ),
        ),
        const SizedBox(height: 24), // mb-6 = 24px
        ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(
            colors: [
              Color(0xFFA78BFA),
              Color(0xFFF472B6),
            ], // purple-400 to pink-400
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ).createShader(bounds),
          child: const Text(
            'Select Organization',
            style: TextStyle(
              fontSize: 36, // text-4xl = 36px
              fontWeight: FontWeight.bold, // font-bold
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(height: 16), // mb-4 = 16px
        const Text(
          'Choose which organization you\'d like to access',
          style: TextStyle(
            color: Color(0xFF9CA3AF), // text-gray-400
            fontSize: 18, // text-lg = 18px
          ),
        ),
        const SizedBox(height: 16), // mt-4 = 16px
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(
              0xFF1F2937,
            ).withValues(alpha: 0.5), // gray-800/50
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: const Color(
                0xFF4B5563,
              ).withValues(alpha: 0.3), // gray-600/30
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.person,
                color: Color(0xFF9CA3AF), // gray-400
                size: 16,
              ),
              const SizedBox(width: 8),
              Text(
                state.firebaseUser.phoneNumber ?? 'User',
                style: const TextStyle(
                  color: Color(0xFFD1D5DB), // gray-300
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildOrganizationsList(
    BuildContext context,
    AuthOrganizationSelectionRequired state,
  ) {
    List<Widget> cards = [];

    // Debug: Print all organizations
    print(
      '🔍 DEBUG: Total organizations loaded: ${state.organizations.length}',
    );
    for (var org in state.organizations) {
      print(
        '🔍 DEBUG: Organization - ID: ${org['orgId']}, Name: ${org['orgName']}, Role: ${org['role']}',
      );
    }
    print('🔍 DEBUG: User is SuperAdmin: ${state.isSuperAdmin}');

    // Add Super Admin Dashboard card if user is Super Admin
    if (state.isSuperAdmin) {
      cards.add(_buildSuperAdminCard(context));
    }

    // Add organization cards (excluding SuperAdmin organization)
    print('🔍 DEBUG: Processing organizations for regular cards...');
    for (var org in state.organizations) {
      print(
        '🔍 DEBUG: Checking organization: ${org['orgId']} (${org['orgName']})',
      );

      // Skip SuperAdmin organization as it has its own special card
      if (org['orgId'] == AppConstants.superAdminOrgId) {
        print('🔍 DEBUG: Skipping SuperAdmin organization (${org['orgName']})');
        continue;
      }

      print(
        '🔍 DEBUG: Adding regular organization card for: ${org['orgName']}',
      );
      cards.add(_buildOrganizationCard(context, org));
    }
    print('🔍 DEBUG: Total cards created: ${cards.length}');

    if (cards.isEmpty) {
      return _buildEmptyState();
    }

    return Column(children: cards);
  }

  Widget _buildSuperAdminCard(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16), // space-y-4 = 16px
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            print(
              '🔍 DEBUG: SuperAdmin card tapped - calling _navigateToSuperAdminDashboard',
            );
            _navigateToSuperAdminDashboard(context);
          },
          borderRadius: BorderRadius.circular(16), // rounded-2xl
          child: Container(
            padding: const EdgeInsets.all(24), // p-6 = 24px
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color.fromRGBO(31, 41, 55, 0.4), // from-gray-800/40
                  Color.fromRGBO(55, 65, 81, 0.3), // via-gray-700/30
                  Color.fromRGBO(31, 41, 55, 0.4), // to-gray-800/40
                ],
              ),
              borderRadius: BorderRadius.circular(16), // rounded-2xl
              border: Border.all(
                color: const Color.fromRGBO(
                  75,
                  85,
                  99,
                  0.4,
                ), // border-gray-600/40
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.25),
                  blurRadius: 32, // shadow-xl
                  offset: const Offset(0, 16),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 48, // w-12
                  height: 48, // h-12
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [
                        Color.fromRGBO(59, 130, 246, 0.2), // from-blue-500/20
                        Color.fromRGBO(139, 92, 246, 0.2), // to-purple-500/20
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12), // rounded-xl
                    border: Border.all(
                      color: const Color.fromRGBO(
                        59,
                        130,
                        246,
                        0.3,
                      ), // border-blue-500/30
                    ),
                  ),
                  child: const Icon(
                    Icons.admin_panel_settings,
                    color: Colors.white,
                    size: 20, // text-xl
                  ),
                ),
                const SizedBox(width: 16), // gap-4 = 16px
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'OPERON Dashboard',
                        style: TextStyle(
                          fontSize: 20, // text-xl
                          fontWeight: FontWeight.bold, // font-bold
                          color: Color(0xFFF3F4F6), // text-gray-100
                        ),
                      ),
                      const SizedBox(height: 4), // mb-1
                      Row(
                        children: [
                          const Text(
                            'Role: ',
                            style: TextStyle(
                              color: Color(0xFF9CA3AF), // text-gray-400
                              fontSize: 14, // text-sm
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(
                                0xFF8B5CF6,
                              ).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: const Color(
                                  0xFF8B5CF6,
                                ).withValues(alpha: 0.3),
                              ),
                            ),
                            child: const Text(
                              'Super Admin',
                              style: TextStyle(
                                color: Color(0xFF8B5CF6), // purple-500
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.arrow_forward_ios,
                  color: Color(0xFF9CA3AF), // text-gray-400
                  size: 24, // w-6 h-6 = 24px
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOrganizationCard(
    BuildContext context,
    Map<String, dynamic> org,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16), // space-y-4 = 16px
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            print(
              '🔍 DEBUG: Organization card tapped - calling _navigateToOrganizationDashboard',
            );
            print('🔍 DEBUG: Organization: ${org['orgName']}');
            _navigateToOrganizationDashboard(context, org);
          },
          borderRadius: BorderRadius.circular(16), // rounded-2xl
          child: Container(
            padding: const EdgeInsets.all(24), // p-6 = 24px
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color.fromRGBO(31, 41, 55, 0.4), // from-gray-800/40
                  Color.fromRGBO(55, 65, 81, 0.3), // via-gray-700/30
                  Color.fromRGBO(31, 41, 55, 0.4), // to-gray-800/40
                ],
              ),
              borderRadius: BorderRadius.circular(16), // rounded-2xl
              border: Border.all(
                color: const Color.fromRGBO(
                  75,
                  85,
                  99,
                  0.4,
                ), // border-gray-600/40
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.25),
                  blurRadius: 32, // shadow-xl
                  offset: const Offset(0, 16),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 48, // w-12
                  height: 48, // h-12
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [
                        Color.fromRGBO(59, 130, 246, 0.2), // from-blue-500/20
                        Color.fromRGBO(139, 92, 246, 0.2), // to-purple-500/20
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12), // rounded-xl
                    border: Border.all(
                      color: const Color.fromRGBO(
                        59,
                        130,
                        246,
                        0.3,
                      ), // border-blue-500/30
                    ),
                  ),
                  child: const Center(
                    child: Text(
                      '🏢',
                      style: TextStyle(fontSize: 20), // text-xl
                    ),
                  ),
                ),
                const SizedBox(width: 16), // gap-4 = 16px
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        org['orgName'] ?? 'Organization',
                        style: const TextStyle(
                          fontSize: 20, // text-xl
                          fontWeight: FontWeight.bold, // font-bold
                          color: Color(0xFFF3F4F6), // text-gray-100
                        ),
                      ),
                      const SizedBox(height: 4), // mb-1
                      Row(
                        children: [
                          Text(
                            'Role: ${_getRoleName(org['role'])}',
                            style: const TextStyle(
                              color: Color(0xFF9CA3AF), // text-gray-400
                              fontSize: 14, // text-sm
                            ),
                          ),
                          if (org['member']?['name'] != null) ...[
                            const Text(
                              ' • ',
                              style: TextStyle(
                                color: Color(0xFF9CA3AF), // text-gray-400
                                fontSize: 14, // text-sm
                              ),
                            ),
                            Text(
                              org['member']['name'],
                              style: const TextStyle(
                                color: Color(0xFF9CA3AF), // text-gray-400
                                fontSize: 14, // text-sm
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.arrow_forward_ios,
                  color: Color(0xFF9CA3AF), // text-gray-400
                  size: 24, // w-6 h-6 = 24px
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _getRoleName(dynamic role) {
    if (role == 0) return 'Admin';
    if (role == 1) return 'Manager';
    return 'Member';
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        children: [
          const Icon(
            Icons.business_outlined,
            size: 64,
            color: Color(0xFF9CA3AF), // gray-400
          ),
          const SizedBox(height: 16),
          const Text(
            'No organizations found',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFFF9FAFB), // gray-50
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Please contact your administrator',
            style: TextStyle(
              color: Color(0xFF9CA3AF), // gray-400
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSignOutOption(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF1F2937).withValues(alpha: 0.5), // gray-800/50
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: const Color(
              0xFF4B5563,
            ).withValues(alpha: 0.3), // gray-600/30
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Not you?',
              style: TextStyle(
                color: Color(0xFF9CA3AF), // gray-400
                fontSize: 14,
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () {
                // Handle sign out
                context.read<AuthBloc>().add(AuthLogoutRequested());
              },
              child: const Text(
                'Sign out',
                style: TextStyle(
                  color: Color(0xFFEF4444), // red-400
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFooter() {
    return const Center(
      child: Text(
        'OPERON - Modern Business Management Platform',
        style: TextStyle(
          color: Color(0xFF6B7280), // gray-500
          fontSize: 12,
        ),
      ),
    );
  }

  void _navigateToSuperAdminDashboard(BuildContext context) {
    print(
      '🔍 DEBUG: _navigateToSuperAdminDashboard called - routing to SuperAdminDashboard',
    );
    // Redirect to SuperAdmin management dashboard
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => const SuperAdminDashboard()),
    );
  }

  void _navigateToOrganizationDashboard(
    BuildContext context,
    Map<String, dynamic> organization,
  ) {
    print(
      '🔍 DEBUG: _navigateToOrganizationDashboard called - routing to OrganizationHomePage',
    );
    print('🔍 DEBUG: Organization data: ${organization.toString()}');

    // Initialize organization context
    final orgContext = context.organizationContext;
    orgContext.initializeOrganization(organization);

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => MultiRepositoryProvider(
          providers: [
            RepositoryProvider<OrganizationRepository>(
              create: (context) => OrganizationRepository(),
            ),
          ],
          child: MultiBlocProvider(
            providers: [
              BlocProvider<OrganizationBloc>(
                create: (context) {
                  final bloc = OrganizationBloc(
                    organizationRepository: context
                        .read<OrganizationRepository>(),
                  );
                  // Set repository and bloc in organization context
                  orgContext.setRepositoryAndBloc(
                    context.read<OrganizationRepository>(),
                    bloc,
                  );
                  return bloc;
                },
              ),
            ],
            child: kIsWeb
                ? const WebOrganizationHomePage()
                : const OrganizationHomePage(),
          ),
        ),
      ),
    );
  }
}
