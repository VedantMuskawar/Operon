import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../../../../core/theme/app_theme.dart';
import '../../../../core/models/subscription.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/widgets/custom_snackbar.dart';
import '../../../../core/widgets/custom_text_field.dart';
import '../../../../core/widgets/custom_button.dart';
import '../../../../core/widgets/custom_dropdown.dart';
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
  final _industryController = TextEditingController();
  final _locationController = TextEditingController();
  final _adminNameController = TextEditingController();
  final _adminPhoneController = TextEditingController();
  final _adminEmailController = TextEditingController();
  
  dynamic _selectedLogoFile; // File on mobile, Uint8List on web
  String? _selectedLogoFileName;
  String _selectedTier = AppConstants.subscriptionTierBasic;
  String _selectedType = AppConstants.subscriptionTypeMonthly;
  int _userLimit = 10;
  double _amount = 0.0;
  String _currency = 'INR';
  bool _autoRenew = false;
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now().add(const Duration(days: 30));

  @override
  void dispose() {
    _orgNameController.dispose();
    _emailController.dispose();
    _gstNoController.dispose();
    _industryController.dispose();
    _locationController.dispose();
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
                  child: CustomTextField(
                    controller: _orgNameController,
                    labelText: 'Organization Name *',
                    hintText: 'Enter organization name',
                    variant: CustomTextFieldVariant.defaultField,
                    prefixIcon: const Icon(Icons.business),
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
                  child: CustomTextField(
                    controller: _gstNoController,
                    labelText: 'GST Number',
                    hintText: 'Enter GST number',
                    variant: CustomTextFieldVariant.defaultField,
                    prefixIcon: const Icon(Icons.receipt),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            CustomTextField(
              controller: _emailController,
              labelText: 'Organization Email *',
              hintText: 'Enter organization email',
              variant: CustomTextFieldVariant.email,
              prefixIcon: const Icon(Icons.email),
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
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: CustomTextField(
                    controller: _industryController,
                    labelText: 'Industry',
                    hintText: 'e.g., Technology, Healthcare',
                    variant: CustomTextFieldVariant.defaultField,
                    prefixIcon: const Icon(Icons.work),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: CustomTextField(
                    controller: _locationController,
                    labelText: 'Location',
                    hintText: 'e.g., Mumbai, Delhi',
                    variant: CustomTextFieldVariant.defaultField,
                    prefixIcon: const Icon(Icons.location_on),
                  ),
                ),
              ],
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
                  child: CustomTextField(
                    controller: _adminNameController,
                    labelText: 'Admin Name *',
                    hintText: 'Enter admin name',
                    variant: CustomTextFieldVariant.defaultField,
                    prefixIcon: const Icon(Icons.person),
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
                  child: CustomTextField(
                    controller: _adminPhoneController,
                    labelText: 'Admin Phone *',
                    hintText: 'Enter admin phone',
                    variant: CustomTextFieldVariant.number,
                    keyboardType: TextInputType.phone,
                    prefixIcon: const Icon(Icons.phone),
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
            CustomTextField(
              controller: _adminEmailController,
              labelText: 'Admin Email *',
              hintText: 'Enter admin email',
              variant: CustomTextFieldVariant.email,
              prefixIcon: const Icon(Icons.email),
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
                  child: CustomDropdown<String>(
                    value: _selectedTier,
                    labelText: 'Subscription Tier',
                    prefixIcon: const Icon(Icons.star),
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
                  child: CustomDropdown<String>(
                    value: _selectedType,
                    labelText: 'Billing Type',
                    prefixIcon: const Icon(Icons.schedule),
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
                  child: CustomTextField(
                    initialValue: _userLimit.toString(),
                    labelText: 'User Limit',
                    variant: CustomTextFieldVariant.number,
                    keyboardType: TextInputType.number,
                    prefixIcon: const Icon(Icons.people),
                    onChanged: (value) {
                      _userLimit = int.tryParse(value) ?? 10;
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: CustomTextField(
                    initialValue: _amount.toString(),
                    labelText: 'Amount (₹)',
                    variant: CustomTextFieldVariant.number,
                    keyboardType: TextInputType.number,
                    prefixIcon: const Icon(Icons.attach_money),
                    onChanged: (value) {
                      _amount = double.tryParse(value) ?? 0.0;
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: CustomDropdown<String>(
                    value: _currency,
                    labelText: 'Currency',
                    prefixIcon: const Icon(Icons.monetization_on),
                    items: const [
                      DropdownMenuItem(value: 'INR', child: Text('INR (₹)')),
                      DropdownMenuItem(value: 'USD', child: Text('USD (\$)')),
                      DropdownMenuItem(value: 'EUR', child: Text('EUR (€)')),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _currency = value!;
                      });
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.borderColor),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.autorenew, color: AppTheme.textSecondaryColor),
                        const SizedBox(width: 12),
                        const Text('Auto Renew'),
                        const Spacer(),
                        Switch(
                          value: _autoRenew,
                          onChanged: (value) {
                            setState(() {
                              _autoRenew = value;
                            });
                          },
                          activeColor: AppTheme.primaryColor,
                        ),
                      ],
                    ),
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
                  child: CustomButton(
                    text: 'Upload Logo',
                    onPressed: _pickLogo,
                    variant: CustomButtonVariant.outline,
                    icon: const Icon(Icons.upload),
                    iconPosition: IconPosition.left,
                  ),
                ),
                const SizedBox(width: 16),
                if (_selectedLogoFile != null)
                  Expanded(
                    child: Container(
                      height: 60,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.borderColor),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.memory(
                          _selectedLogoFile as Uint8List,
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
                  _selectedLogoFileName ?? 'logo',
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
        return CustomButton(
          text: 'Create Organization',
          onPressed: state is OrganizationLoading ? null : _submitForm,
          isLoading: state is OrganizationLoading,
          variant: CustomButtonVariant.primary,
          size: CustomButtonSize.large,
          width: double.infinity,
        );
      },
    );
  }

  Future<void> _pickLogo() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
        withData: true,
      );

      if (result != null && result.files.isNotEmpty) {
        final pickedFile = result.files.first;
        if (pickedFile.bytes != null) {
          setState(() {
            _selectedLogoFile = pickedFile.bytes;
            _selectedLogoFileName = pickedFile.name;
          });
        }
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
        amount: _amount,
        currency: _currency,
        isActive: true,
        autoRenew: _autoRenew,
        createdDate: DateTime.now(),
        updatedDate: DateTime.now(),
      );

      context.read<OrganizationBloc>().add(
        CreateOrganization(
          orgName: _orgNameController.text.trim(),
          email: _emailController.text.trim(),
          gstNo: _gstNoController.text.trim(),
          industry: _industryController.text.trim().isEmpty ? null : _industryController.text.trim(),
          location: _locationController.text.trim().isEmpty ? null : _locationController.text.trim(),
          adminName: _adminNameController.text.trim(),
          adminPhone: _adminPhoneController.text.trim(),
          adminEmail: _adminEmailController.text.trim(),
          subscription: subscription,
          logoFile: _selectedLogoFile,
          logoFileName: _selectedLogoFileName,
        ),
      );
    }
  }

  void _clearForm() {
    _orgNameController.clear();
    _emailController.clear();
    _gstNoController.clear();
    _industryController.clear();
    _locationController.clear();
    _adminNameController.clear();
    _adminPhoneController.clear();
    _adminEmailController.clear();
    setState(() {
      _selectedLogoFile = null;
      _selectedTier = AppConstants.subscriptionTierBasic;
      _selectedType = AppConstants.subscriptionTypeMonthly;
      _userLimit = 10;
      _amount = 0.0;
      _currency = 'INR';
      _autoRenew = false;
    });
  }
}
