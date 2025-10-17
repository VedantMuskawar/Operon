import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/models/subscription.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/widgets/custom_snackbar.dart';
import '../../bloc/organization_bloc.dart';
import '../../../dashboard/presentation/widgets/dashboard_sidebar.dart';

class AddOrganizationForm extends StatefulWidget {
  const AddOrganizationForm({super.key});

  @override
  State<AddOrganizationForm> createState() => _AddOrganizationFormState();
}

class _AddOrganizationFormState extends State<AddOrganizationForm> {
  final _formKey = GlobalKey<FormState>();
  final _orgNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _gstNoController = TextEditingController();
  final _adminNameController = TextEditingController();
  final _adminPhoneController = TextEditingController();
  final _adminEmailController = TextEditingController();
  
  File? _selectedLogoFile;
  String _selectedTier = AppConstants.subscriptionTierBasic;
  String _selectedType = AppConstants.subscriptionTypeMonthly;
  int _userLimit = 10;
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now().add(const Duration(days: 30));

  @override
  void dispose() {
    _orgNameController.dispose();
    _emailController.dispose();
    _gstNoController.dispose();
    _adminNameController.dispose();
    _adminPhoneController.dispose();
    _adminEmailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<OrganizationBloc, OrganizationState>(
      listener: (context, state) {
        if (state is OrganizationCreated) {
          CustomSnackBar.showSuccess(context, 'Organization created successfully!');
          _clearForm();
          // TODO: Navigate to organization details or list
        } else if (state is OrganizationFailure) {
          CustomSnackBar.showError(context, state.message);
        }
      },
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              const SizedBox(height: 32),
              _buildOrganizationSection(),
              const SizedBox(height: 32),
              _buildAdminSection(),
              const SizedBox(height: 32),
              _buildSubscriptionSection(),
              const SizedBox(height: 32),
              _buildLogoSection(),
              const SizedBox(height: 32),
              _buildSubmitButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            gradient: AppTheme.primaryGradient,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(
            Icons.add_business,
            color: Colors.white,
            size: 24,
          ),
        ),
        const SizedBox(width: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Add New Organization',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              'Create a new organization with admin user',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppTheme.textSecondaryColor,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildOrganizationSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Organization Details',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _orgNameController,
                    decoration: const InputDecoration(
                      labelText: 'Organization Name *',
                      hintText: 'Enter organization name',
                      prefixIcon: Icon(Icons.business),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter organization name';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    controller: _gstNoController,
                    decoration: const InputDecoration(
                      labelText: 'GST Number',
                      hintText: 'Enter GST number',
                      prefixIcon: Icon(Icons.receipt),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _emailController,
              decoration: const InputDecoration(
                labelText: 'Organization Email *',
                hintText: 'Enter organization email',
                prefixIcon: Icon(Icons.email),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter organization email';
                }
                if (!value.contains('@')) {
                  return 'Please enter a valid email';
                }
                return null;
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAdminSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Admin User Details',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _adminNameController,
                    decoration: const InputDecoration(
                      labelText: 'Admin Name *',
                      hintText: 'Enter admin name',
                      prefixIcon: Icon(Icons.person),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter admin name';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    controller: _adminPhoneController,
                    decoration: const InputDecoration(
                      labelText: 'Admin Phone *',
                      hintText: 'Enter admin phone',
                      prefixIcon: Icon(Icons.phone),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter admin phone';
                      }
                      return null;
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _adminEmailController,
              decoration: const InputDecoration(
                labelText: 'Admin Email *',
                hintText: 'Enter admin email',
                prefixIcon: Icon(Icons.email),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter admin email';
                }
                if (!value.contains('@')) {
                  return 'Please enter a valid email';
                }
                return null;
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubscriptionSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Subscription Details',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _selectedTier,
                    decoration: const InputDecoration(
                      labelText: 'Subscription Tier',
                      prefixIcon: Icon(Icons.star),
                    ),
                    items: [
                      DropdownMenuItem(
                        value: AppConstants.subscriptionTierBasic,
                        child: Text(SubscriptionTier.basic.displayName),
                      ),
                      DropdownMenuItem(
                        value: AppConstants.subscriptionTierPremium,
                        child: Text(SubscriptionTier.premium.displayName),
                      ),
                      DropdownMenuItem(
                        value: AppConstants.subscriptionTierEnterprise,
                        child: Text(SubscriptionTier.enterprise.displayName),
                      ),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _selectedTier = value!;
                      });
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _selectedType,
                    decoration: const InputDecoration(
                      labelText: 'Billing Type',
                      prefixIcon: Icon(Icons.schedule),
                    ),
                    items: [
                      DropdownMenuItem(
                        value: AppConstants.subscriptionTypeMonthly,
                        child: Text(SubscriptionType.monthly.displayName),
                      ),
                      DropdownMenuItem(
                        value: AppConstants.subscriptionTypeYearly,
                        child: Text(SubscriptionType.yearly.displayName),
                      ),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _selectedType = value!;
                      });
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    initialValue: _userLimit.toString(),
                    decoration: const InputDecoration(
                      labelText: 'User Limit',
                      prefixIcon: Icon(Icons.people),
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (value) {
                      _userLimit = int.tryParse(value) ?? 10;
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    initialValue: '30 days',
                    decoration: const InputDecoration(
                      labelText: 'Duration',
                      prefixIcon: Icon(Icons.calendar_today),
                    ),
                    readOnly: true,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLogoSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Organization Logo',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickLogo,
                    icon: const Icon(Icons.upload),
                    label: const Text('Upload Logo'),
                  ),
                ),
                const SizedBox(width: 16),
                if (_selectedLogoFile != null)
                  Expanded(
                    child: Container(
                      height: 60,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppTheme.borderColor),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.file(
                          _selectedLogoFile!,
                          fit: BoxFit.cover,
                          width: double.infinity,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            if (_selectedLogoFile != null)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text(
                  _selectedLogoFile!.path.split('/').last,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.textSecondaryColor,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubmitButton() {
    return BlocBuilder<OrganizationBloc, OrganizationState>(
      builder: (context, state) {
        return SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: state is OrganizationLoading ? null : _submitForm,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: state is OrganizationLoading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Text(
                    'Create Organization',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
        );
      },
    );
  }

  Future<void> _pickLogo() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = File(result.files.first.path!);
        setState(() {
          _selectedLogoFile = file;
        });
      }
    } catch (e) {
      CustomSnackBar.showError(context, 'Error picking file: $e');
    }
  }

  void _submitForm() {
    if (_formKey.currentState!.validate()) {
      final subscription = Subscription(
        subscriptionId: DateTime.now().millisecondsSinceEpoch.toString(),
        tier: _selectedTier,
        subscriptionType: _selectedType,
        startDate: _startDate,
        endDate: _endDate,
        userLimit: _userLimit,
        status: AppConstants.subscriptionStatusActive,
        amount: 0.0,
        currency: AppConstants.defaultCurrency,
        isActive: true,
        autoRenew: false,
        createdDate: DateTime.now(),
        updatedDate: DateTime.now(),
      );

      context.read<OrganizationBloc>().add(
        CreateOrganization(
          orgName: _orgNameController.text.trim(),
          email: _emailController.text.trim(),
          gstNo: _gstNoController.text.trim(),
          adminName: _adminNameController.text.trim(),
          adminPhone: _adminPhoneController.text.trim(),
          adminEmail: _adminEmailController.text.trim(),
          subscription: subscription,
          logoFile: _selectedLogoFile,
        ),
      );
    }
  }

  void _clearForm() {
    _orgNameController.clear();
    _emailController.clear();
    _gstNoController.clear();
    _adminNameController.clear();
    _adminPhoneController.clear();
    _adminEmailController.clear();
    setState(() {
      _selectedLogoFile = null;
    });
  }
}
