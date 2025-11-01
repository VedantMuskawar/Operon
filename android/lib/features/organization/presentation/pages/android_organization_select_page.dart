import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../../core/app_theme.dart';
import '../../../../core/config/android_config.dart';
import '../../../auth/android_auth_bloc.dart';
import '../bloc/android_organization_bloc.dart';
import 'android_organization_home_page.dart';

class AndroidOrganizationSelectPage extends StatefulWidget {
  final User firebaseUser;

  const AndroidOrganizationSelectPage({
    super.key,
    required this.firebaseUser,
  });

  @override
  State<AndroidOrganizationSelectPage> createState() => _AndroidOrganizationSelectPageState();
}

class _AndroidOrganizationSelectPageState extends State<AndroidOrganizationSelectPage> {
  @override
  void initState() {
    super.initState();
    // Load organizations when the page initializes
    context.read<AndroidOrganizationBloc>().add(AndroidOrganizationLoadRequested(
      userId: widget.firebaseUser.uid,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppTheme.backgroundColor,
              AppTheme.surfaceColor.withOpacity(0.8),
            ],
          ),
        ),
        child: SafeArea(
          child: BlocBuilder<AndroidOrganizationBloc, AndroidOrganizationState>(
            builder: (context, state) {
              if (state is AndroidOrganizationLoading) {
                return _buildLoadingState();
              } else if (state is AndroidOrganizationLoaded) {
                return _buildOrganizationSelection(context, state);
              } else if (state is AndroidOrganizationError) {
                return _buildErrorState(state.message);
              } else {
                return _buildLoadingState();
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
              gradient: AppTheme.primaryGradient,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primaryColor.withOpacity(0.3),
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
          Text(
            'Loading Organizations',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              color: AppTheme.textPrimaryColor,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Please wait while we fetch your data...',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppTheme.textSecondaryColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String message) {
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
          Text(
            'Something went wrong',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              color: AppTheme.textPrimaryColor,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppTheme.textSecondaryColor,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () {
              context.read<AndroidOrganizationBloc>().add(
                AndroidOrganizationLoadRequested(userId: widget.firebaseUser.uid),
              );
            },
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildOrganizationSelection(BuildContext context, AndroidOrganizationLoaded state) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AndroidConfig.defaultPadding),
        child: Column(
          children: [
            _buildHeader(context, state),
            const SizedBox(height: 32),
            _buildOrganizationsList(context, state),
            const SizedBox(height: 32),
            _buildSignOutOption(context),
            const SizedBox(height: 32),
            _buildFooter(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, AndroidOrganizationLoaded state) {
    return Column(
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            gradient: AppTheme.primaryGradient,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: AppTheme.primaryColor.withOpacity(0.3),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: const Center(
            child: Text(
              '🏢',
              style: TextStyle(fontSize: 32),
            ),
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'Select Organization',
          style: Theme.of(context).textTheme.headlineLarge?.copyWith(
            color: AppTheme.textPrimaryColor,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Choose which organization you\'d like to access',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: AppTheme.textSecondaryColor,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: AppTheme.surfaceColor,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppTheme.borderColor),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.person,
                color: AppTheme.textSecondaryColor,
                size: 16,
              ),
              const SizedBox(width: 8),
              Text(
                widget.firebaseUser.phoneNumber ?? 'User',
                style: const TextStyle(
                  color: AppTheme.textPrimaryColor,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildOrganizationsList(BuildContext context, AndroidOrganizationLoaded state) {
    if (state.organizations.isEmpty) {
      return _buildEmptyState();
    }

    return Column(
      children: state.organizations.map((org) => _buildOrganizationCard(context, org)).toList(),
    );
  }

  Widget _buildOrganizationCard(BuildContext context, Map<String, dynamic> org) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            _navigateToOrganizationDashboard(context, org);
          },
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppTheme.surfaceColor,
                  AppTheme.surfaceColor.withOpacity(0.8),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.borderColor),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    gradient: AppTheme.accentGradient,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Center(
                    child: Text(
                      '🏢',
                      style: TextStyle(fontSize: 20),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        org['orgName'] ?? 'Organization',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: AppTheme.textPrimaryColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Text(
                            'Role: ${_getRoleName(org['role'])}',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: AppTheme.textSecondaryColor,
                            ),
                          ),
                          if (org['member']?['name'] != null) ...[
                            const Text(
                              ' • ',
                              style: TextStyle(
                                color: AppTheme.textSecondaryColor,
                              ),
                            ),
                            Text(
                              org['member']['name'],
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: AppTheme.textSecondaryColor,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: org['status'] == 'active' 
                        ? AppTheme.successColor.withOpacity(0.2)
                        : AppTheme.warningColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    org['status'] ?? 'unknown',
                    style: TextStyle(
                      color: org['status'] == 'active' 
                          ? AppTheme.successColor
                          : AppTheme.warningColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(
                  Icons.arrow_forward_ios,
                  color: AppTheme.textSecondaryColor,
                  size: 16,
                ),
              ],
            ),
          ),
        ),
      ),
    );
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

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        children: [
          const Icon(
            Icons.business_outlined,
            size: 64,
            color: AppTheme.textSecondaryColor,
          ),
          const SizedBox(height: 16),
          Text(
            'No organizations found',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: AppTheme.textPrimaryColor,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Please contact your administrator',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppTheme.textSecondaryColor,
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
          color: AppTheme.surfaceColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.borderColor),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Not you?',
              style: TextStyle(
                color: AppTheme.textSecondaryColor,
                fontSize: 14,
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () {
                context.read<AndroidAuthBloc>().add(AndroidAuthLogoutRequested());
              },
              child: const Text(
                'Sign out',
                style: TextStyle(
                  color: AppTheme.errorColor,
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
          color: AppTheme.textSecondaryColor,
          fontSize: 12,
        ),
      ),
    );
  }

  void _navigateToOrganizationDashboard(BuildContext context, Map<String, dynamic> organization) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => AndroidOrganizationHomePage(
          organization: organization,
        ),
      ),
    );
  }
}
