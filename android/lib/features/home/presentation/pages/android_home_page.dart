import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/app_theme.dart';
import '../../../../core/config/android_config.dart';
import '../../../../core/services/android_auth_repository.dart';
import '../../../auth/android_auth_bloc.dart';

class AndroidHomePage extends StatefulWidget {
  const AndroidHomePage({super.key});

  @override
  State<AndroidHomePage> createState() => _AndroidHomePageState();
}

class _AndroidHomePageState extends State<AndroidHomePage> {
  final AndroidAuthRepository _authRepository = AndroidAuthRepository();
  
  Map<String, dynamic>? _userData;
  List<Map<String, dynamic>> _organizations = [];

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final user = _authRepository.getCurrentUser();
    if (user != null) {
      final userDoc = await _authRepository.getUserDocument(user.uid);
      final organizations = await _authRepository.getUserOrganizations(user.uid);
      
      setState(() {
        _userData = userDoc;
        _organizations = organizations;
      });
    }
  }

  void _logout() {
    context.read<AndroidAuthBloc>().add(AndroidAuthLogoutRequested());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('OPERON'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,
            tooltip: 'Logout',
          ),
        ],
      ),
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
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AndroidConfig.defaultPadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildWelcomeCard(),
                const SizedBox(height: 24),
                _buildUserInfoCard(),
                const SizedBox(height: 24),
                _buildOrganizationsCard(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWelcomeCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AndroidConfig.cardRadius),
      ),
      child: Container(
        decoration: BoxDecoration(
          gradient: AppTheme.primaryGradient,
          borderRadius: BorderRadius.circular(AndroidConfig.cardRadius),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(
                    Icons.business,
                    size: 30,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Welcome to OPERON',
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Organization Management System',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.white.withOpacity(0.9),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUserInfoCard() {
    if (_userData == null) {
      return Card(
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AndroidConfig.cardRadius),
        ),
        child: const Padding(
          padding: EdgeInsets.all(24),
          child: Center(
            child: CircularProgressIndicator(),
          ),
        ),
      );
    }

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AndroidConfig.cardRadius),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'User Information',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            _buildInfoRow('Name', _userData!['name'] ?? 'N/A'),
            _buildInfoRow('Phone', _userData!['phoneNo'] ?? 'N/A'),
            _buildInfoRow('Email', _userData!['email'] ?? 'N/A'),
            _buildInfoRow('Status', _userData!['status'] ?? 'N/A'),
            if (_userData!['lastLoginDate'] != null)
              _buildInfoRow(
                'Last Login',
                _formatDate(_userData!['lastLoginDate']),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrganizationsCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AndroidConfig.cardRadius),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Organizations',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            if (_organizations.isEmpty)
              const Center(
                child: Text(
                  'No organizations found',
                  style: TextStyle(color: AppTheme.textSecondaryColor),
                ),
              )
            else
              ..._organizations.map((org) => _buildOrganizationItem(org)),
          ],
        ),
      ),
    );
  }

  Widget _buildOrganizationItem(Map<String, dynamic> org) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              gradient: AppTheme.accentGradient,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.business,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  org['orgName'] ?? 'Unknown Organization',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Role: ${_getRoleName(org['role'] ?? 1)}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.textSecondaryColor,
                  ),
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
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppTheme.textSecondaryColor,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(dynamic date) {
    if (date == null) return 'N/A';
    try {
      if (date is Timestamp) {
        return '${date.toDate().day}/${date.toDate().month}/${date.toDate().year}';
      }
      return date.toString();
    } catch (e) {
      return 'N/A';
    }
  }

  String _getRoleName(int role) {
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
        return 'Unknown';
    }
  }
}



