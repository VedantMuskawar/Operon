import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:typed_data';
import '../../../../core/app_theme.dart';
import '../../../../core/config/android_config.dart';
import '../../bloc/android_organization_settings_bloc.dart';
import '../../repositories/android_organization_repository.dart';

class AndroidOrganizationSettingsPage extends StatefulWidget {
  final String organizationId;

  const AndroidOrganizationSettingsPage({
    super.key,
    required this.organizationId,
  });

  @override
  State<AndroidOrganizationSettingsPage> createState() => _AndroidOrganizationSettingsPageState();
}

class _AndroidOrganizationSettingsPageState extends State<AndroidOrganizationSettingsPage> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _emailController;
  late TextEditingController _gstController;
  late TextEditingController _industryController;
  late TextEditingController _locationController;

  Uint8List? _selectedLogoFile;
  String? _selectedLogoFileName;
  String? _currentLogoUrl;
  bool _hasChanges = false;
  AndroidOrganization? _currentOrganization;

  final List<String> _industryOptions = [
    'Manufacturing',
    'Manufactoring', // Keep typo for existing data
    'Technology',
    'Healthcare',
    'Finance',
    'Retail',
    'Education',
    'Construction',
    'Transportation',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _emailController = TextEditingController();
    _gstController = TextEditingController();
    _industryController = TextEditingController();
    _locationController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _gstController.dispose();
    _industryController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  void _updateControllersFromOrganization(
    AndroidOrganization organization,
    AndroidSubscription? subscription,
  ) {
    if (mounted) {
      setState(() {
        _currentOrganization = organization;
        _nameController.text = organization.orgName;
        _emailController.text = organization.email;
        _gstController.text = organization.gstNo;
        _industryController.text = organization.metadata['industry'] ?? '';
        _locationController.text = organization.metadata['location'] ?? '';
        _currentLogoUrl = organization.orgLogoUrl;
        _hasChanges = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => AndroidOrganizationSettingsBloc(
        repository: AndroidOrganizationRepository(),
      )..add(AndroidLoadOrganizationDetails(widget.organizationId)),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Organization Settings'),
          backgroundColor: AppTheme.surfaceColor,
          actions: [
            if (_hasChanges)
              TextButton(
                onPressed: _saveChanges,
                child: const Text(
                  'Save',
                  style: TextStyle(color: AppTheme.primaryColor),
                ),
              ),
          ],
        ),
        backgroundColor: AppTheme.backgroundColor,
        body: BlocListener<AndroidOrganizationSettingsBloc, AndroidOrganizationSettingsState>(
          listener: (context, state) {
            if (state is AndroidOrganizationDetailsLoaded) {
              _updateControllersFromOrganization(
                state.organization,
                state.subscription,
              );
            } else if (state is AndroidOrganizationSettingsSuccess) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(state.message),
                  backgroundColor: AppTheme.successColor,
                ),
              );
              Navigator.pop(context);
            } else if (state is AndroidOrganizationSettingsError) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(state.message),
                  backgroundColor: AppTheme.errorColor,
                ),
              );
            }
          },
          child: BlocBuilder<AndroidOrganizationSettingsBloc, AndroidOrganizationSettingsState>(
            builder: (context, state) {
              if (state is AndroidOrganizationSettingsLoading ||
                  state is AndroidOrganizationSettingsInitial) {
                return const Center(child: CircularProgressIndicator());
              }

              if (state is AndroidOrganizationSettingsError) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, size: 64, color: AppTheme.errorColor),
                      const SizedBox(height: 16),
                      Text(state.message, style: const TextStyle(color: AppTheme.textPrimaryColor)),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () {
                          context.read<AndroidOrganizationSettingsBloc>().add(
                            AndroidLoadOrganizationDetails(widget.organizationId),
                          );
                        },
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                );
              }

              if (state is AndroidOrganizationDetailsLoaded) {
                return SingleChildScrollView(
                  padding: const EdgeInsets.all(AndroidConfig.defaultPadding),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildLogoSection(state.organization),
                        const SizedBox(height: 24),
                        _buildBasicInfoSection(),
                        const SizedBox(height: 24),
                        _buildMetadataSection(),
                        const SizedBox(height: 24),
                        _buildSubscriptionInfo(state.subscription),
                        const SizedBox(height: 24),
                        _buildActionButtons(),
                      ],
                    ),
                  ),
                );
              }

              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );
  }

  Widget _buildLogoSection(AndroidOrganization organization) {
    return Card(
      color: AppTheme.surfaceColor,
      child: Padding(
        padding: const EdgeInsets.all(AndroidConfig.defaultPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Organization Logo',
              style: TextStyle(
                color: AppTheme.textPrimaryColor,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: AppTheme.cardColor,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.borderColor),
                  ),
                  child: _selectedLogoFile != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.memory(
                            _selectedLogoFile!,
                            fit: BoxFit.cover,
                          ),
                        )
                      : _currentLogoUrl != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(
                                _currentLogoUrl!,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return const Icon(
                                    Icons.business,
                                    color: AppTheme.textSecondaryColor,
                                    size: 40,
                                  );
                                },
                              ),
                            )
                          : const Icon(
                              Icons.business,
                              color: AppTheme.textSecondaryColor,
                              size: 40,
                            ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ElevatedButton.icon(
                        onPressed: _pickLogo,
                        icon: const Icon(Icons.cloud_upload),
                        label: const Text('Upload Logo'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryColor,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Recommended: 200x200px, PNG or JPG',
                        style: TextStyle(
                          color: AppTheme.textSecondaryColor,
                          fontSize: 12,
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

  Widget _buildBasicInfoSection() {
    return Card(
      color: AppTheme.surfaceColor,
      child: Padding(
        padding: const EdgeInsets.all(AndroidConfig.defaultPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Basic Information',
              style: TextStyle(
                color: AppTheme.textPrimaryColor,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: 'Organization Name',
                labelStyle: const TextStyle(color: AppTheme.textSecondaryColor),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AndroidConfig.cardRadius),
                ),
                enabledBorder: OutlineInputBorder(
                  borderSide: const BorderSide(color: AppTheme.borderColor),
                  borderRadius: BorderRadius.circular(AndroidConfig.cardRadius),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: const BorderSide(color: AppTheme.primaryColor),
                  borderRadius: BorderRadius.circular(AndroidConfig.cardRadius),
                ),
              ),
              style: const TextStyle(color: AppTheme.textPrimaryColor),
              onChanged: (_) => setState(() => _hasChanges = true),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Organization name is required';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _emailController,
              decoration: InputDecoration(
                labelText: 'Email',
                labelStyle: const TextStyle(color: AppTheme.textSecondaryColor),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AndroidConfig.cardRadius),
                ),
                enabledBorder: OutlineInputBorder(
                  borderSide: const BorderSide(color: AppTheme.borderColor),
                  borderRadius: BorderRadius.circular(AndroidConfig.cardRadius),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: const BorderSide(color: AppTheme.primaryColor),
                  borderRadius: BorderRadius.circular(AndroidConfig.cardRadius),
                ),
              ),
              keyboardType: TextInputType.emailAddress,
              style: const TextStyle(color: AppTheme.textPrimaryColor),
              onChanged: (_) => setState(() => _hasChanges = true),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Email is required';
                }
                if (!value.contains('@')) {
                  return 'Please enter a valid email';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _gstController,
              decoration: InputDecoration(
                labelText: 'GST Number',
                labelStyle: const TextStyle(color: AppTheme.textSecondaryColor),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AndroidConfig.cardRadius),
                ),
                enabledBorder: OutlineInputBorder(
                  borderSide: const BorderSide(color: AppTheme.borderColor),
                  borderRadius: BorderRadius.circular(AndroidConfig.cardRadius),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: const BorderSide(color: AppTheme.primaryColor),
                  borderRadius: BorderRadius.circular(AndroidConfig.cardRadius),
                ),
              ),
              style: const TextStyle(color: AppTheme.textPrimaryColor),
              onChanged: (_) => setState(() => _hasChanges = true),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetadataSection() {
    return Card(
      color: AppTheme.surfaceColor,
      child: Padding(
        padding: const EdgeInsets.all(AndroidConfig.defaultPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Additional Information',
              style: TextStyle(
                color: AppTheme.textPrimaryColor,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _industryController.text.isEmpty ||
                      !_industryOptions.contains(_industryController.text)
                  ? null
                  : _industryController.text,
              decoration: InputDecoration(
                labelText: 'Industry',
                labelStyle: const TextStyle(color: AppTheme.textSecondaryColor),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AndroidConfig.cardRadius),
                ),
                enabledBorder: OutlineInputBorder(
                  borderSide: const BorderSide(color: AppTheme.borderColor),
                  borderRadius: BorderRadius.circular(AndroidConfig.cardRadius),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: const BorderSide(color: AppTheme.primaryColor),
                  borderRadius: BorderRadius.circular(AndroidConfig.cardRadius),
                ),
              ),
              dropdownColor: AppTheme.surfaceColor,
              style: const TextStyle(color: AppTheme.textPrimaryColor),
              items: _industryOptions.map((industry) {
                return DropdownMenuItem(
                  value: industry,
                  child: Text(industry),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _industryController.text = value;
                    _hasChanges = true;
                  });
                }
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _locationController,
              decoration: InputDecoration(
                labelText: 'Location',
                labelStyle: const TextStyle(color: AppTheme.textSecondaryColor),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AndroidConfig.cardRadius),
                ),
                enabledBorder: OutlineInputBorder(
                  borderSide: const BorderSide(color: AppTheme.borderColor),
                  borderRadius: BorderRadius.circular(AndroidConfig.cardRadius),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: const BorderSide(color: AppTheme.primaryColor),
                  borderRadius: BorderRadius.circular(AndroidConfig.cardRadius),
                ),
              ),
              style: const TextStyle(color: AppTheme.textPrimaryColor),
              onChanged: (_) => setState(() => _hasChanges = true),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubscriptionInfo(AndroidSubscription? subscription) {
    return Card(
      color: AppTheme.surfaceColor,
      child: Padding(
        padding: const EdgeInsets.all(AndroidConfig.defaultPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Subscription Information',
              style: TextStyle(
                color: AppTheme.textPrimaryColor,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.cardColor,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.borderColor),
              ),
              child: subscription != null
                  ? Column(
                      children: [
                        _buildSubscriptionRow('Plan', subscription.tier.toUpperCase()),
                        const SizedBox(height: 12),
                        _buildSubscriptionRow(
                          'Status',
                          subscription.status.toUpperCase(),
                          valueColor: subscription.status == 'active'
                              ? AppTheme.successColor
                              : AppTheme.errorColor,
                        ),
                        const SizedBox(height: 12),
                        _buildSubscriptionRow(
                          'Next Billing',
                          _formatDate(subscription.endDate),
                        ),
                        const SizedBox(height: 12),
                        _buildSubscriptionRow(
                          'Price',
                          '${subscription.currency} ${subscription.amount.toStringAsFixed(2)}/${subscription.subscriptionType}',
                        ),
                      ],
                    )
                  : const Center(
                      child: Text(
                        'No subscription found',
                        style: TextStyle(color: AppTheme.textSecondaryColor),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubscriptionRow(String label, String value, {Color? valueColor}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppTheme.textSecondaryColor,
            fontSize: 14,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: valueColor ?? AppTheme.textPrimaryColor,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: () => Navigator.pop(context),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: AppTheme.errorColor),
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: const Text(
              'Cancel',
              style: TextStyle(color: AppTheme.errorColor),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: ElevatedButton(
            onPressed: _hasChanges ? _saveChanges : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: const Text('Save Changes'),
          ),
        ),
      ],
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
            _hasChanges = true;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to pick logo: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  void _saveChanges() {
    if (!_formKey.currentState!.validate()) return;

    if (_currentOrganization == null) return;

    // Preserve existing metadata and merge with new values
    final metadata = Map<String, dynamic>.from(_currentOrganization!.metadata);
    metadata['industry'] = _industryController.text.trim();
    metadata['location'] = _locationController.text.trim();

    final organization = _currentOrganization!.copyWith(
      orgName: _nameController.text.trim(),
      email: _emailController.text.trim(),
      gstNo: _gstController.text.trim(),
      metadata: metadata,
      // orgLogoUrl will be updated by repository if logo is uploaded
    );

    context.read<AndroidOrganizationSettingsBloc>().add(
      AndroidUpdateOrganizationDetails(
        orgId: widget.organizationId,
        organization: organization,
        logoFile: _selectedLogoFile,
        logoFileName: _selectedLogoFileName,
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}

