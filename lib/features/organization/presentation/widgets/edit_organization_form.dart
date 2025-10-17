import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/models/organization.dart';
import '../../../../core/models/subscription.dart';
import '../../../../core/constants/app_constants.dart';
import '../../bloc/organization_bloc.dart';

class EditOrganizationForm extends StatefulWidget {
  final Organization organization;

  const EditOrganizationForm({
    super.key,
    required this.organization,
  });

  @override
  State<EditOrganizationForm> createState() => _EditOrganizationFormState();
}

class _EditOrganizationFormState extends State<EditOrganizationForm> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _orgNameController;
  late TextEditingController _emailController;
  late TextEditingController _gstNoController;
  late TextEditingController _userLimitController;
  
  File? _selectedLogoFile;
  String _selectedStatus = '';
  String _selectedTier = '';
  String _selectedType = '';

  @override
  void initState() {
    super.initState();
    _initializeControllers();
  }

  void _initializeControllers() {
    _orgNameController = TextEditingController(text: widget.organization.orgName);
    _emailController = TextEditingController(text: widget.organization.email);
    _gstNoController = TextEditingController(text: widget.organization.gstNo ?? '');
    _selectedStatus = widget.organization.status;
    _selectedTier = widget.organization.subscription?.tier ?? AppConstants.subscriptionTierBasic;
    _selectedType = widget.organization.subscription?.subscriptionType ?? AppConstants.subscriptionTypeMonthly;
    _userLimitController = TextEditingController(
      text: widget.organization.subscription?.userLimit.toString() ?? '10',
    );
  }

  @override
  void dispose() {
    _orgNameController.dispose();
    _emailController.dispose();
    _gstNoController.dispose();
    _userLimitController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<OrganizationBloc, OrganizationState>(
      listener: (context, state) {
        if (state is OrganizationUpdated) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Organization updated successfully!'),
              backgroundColor: AppTheme.successColor,
              behavior: SnackBarBehavior.floating,
            ),
          );
          Navigator.of(context).pop();
        } else if (state is OrganizationFailure) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: AppTheme.errorColor,
              behavior: SnackBarBehavior.floating,
            ),
          );
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
            Icons.edit,
            color: Colors.white,
            size: 24,
          ),
        ),
        const SizedBox(width: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Edit Organization',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              'Update organization details and settings',
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
            Row(
              children: [
                Expanded(
                  child: TextFormField(
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
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _selectedStatus,
                    decoration: const InputDecoration(
                      labelText: 'Status',
                      prefixIcon: Icon(Icons.flag),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: AppConstants.orgStatusActive,
                        child: Text('Active'),
                      ),
                      DropdownMenuItem(
                        value: AppConstants.orgStatusInactive,
                        child: Text('Inactive'),
                      ),
                      DropdownMenuItem(
                        value: AppConstants.orgStatusSuspended,
                        child: Text('Suspended'),
                      ),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _selectedStatus = value!;
                      });
                    },
                  ),
                ),
              ],
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
            TextFormField(
              controller: _userLimitController,
              decoration: const InputDecoration(
                labelText: 'User Limit',
                prefixIcon: Icon(Icons.people),
              ),
              keyboardType: TextInputType.number,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter user limit';
                }
                final limit = int.tryParse(value);
                if (limit == null || limit < 1) {
                  return 'Please enter a valid user limit';
                }
                return null;
              },
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
                    label: const Text('Upload New Logo'),
                  ),
                ),
                const SizedBox(width: 16),
                if (widget.organization.orgLogoUrl != null && _selectedLogoFile == null)
                  Expanded(
                    child: Container(
                      height: 60,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppTheme.borderColor),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          widget.organization.orgLogoUrl!,
                          fit: BoxFit.cover,
                          width: double.infinity,
                          errorBuilder: (context, error, stackTrace) {
                            return const Center(
                              child: Icon(Icons.image_not_supported),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
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
                    'Update Organization',
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error picking file: $e'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
    }
  }

  void _submitForm() {
    if (_formKey.currentState!.validate()) {
      final userLimit = int.parse(_userLimitController.text);
      
      // Update the organization object
      final updatedOrganization = widget.organization.copyWith(
        orgName: _orgNameController.text.trim(),
        email: _emailController.text.trim(),
        gstNo: _gstNoController.text.trim(),
        status: _selectedStatus,
        updatedDate: DateTime.now(),
        subscription: widget.organization.subscription?.copyWith(
          tier: _selectedTier,
          subscriptionType: _selectedType,
          userLimit: userLimit,
          updatedDate: DateTime.now(),
        ),
      );

      context.read<OrganizationBloc>().add(
        UpdateOrganization(
          orgId: widget.organization.orgId,
          organization: updatedOrganization,
        ),
      );
    }
  }
}
