import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:typed_data';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/models/organization.dart';
import '../../../../core/widgets/custom_text_field.dart';
import '../../../../core/widgets/custom_button.dart';
import '../../../../core/widgets/custom_dropdown.dart';
import '../../../../core/widgets/custom_snackbar.dart';
import '../../../../core/widgets/page_container.dart';
import '../../../../core/widgets/page_header.dart';
import '../../../../core/widgets/form_container.dart';
import '../../bloc/organization_bloc.dart';
import '../../../../contexts/organization_context.dart';
import '../../bloc/depot/depot_bloc.dart';
import '../../bloc/depot/depot_event.dart';
import '../../../../core/repositories/depot_repository.dart';
import 'depot_location_section.dart';

class OrganizationSettingsView extends StatefulWidget {
  final VoidCallback onBack;

  const OrganizationSettingsView({
    super.key,
    required this.onBack,
  });

  @override
  State<OrganizationSettingsView> createState() => _OrganizationSettingsViewState();
}

class _OrganizationSettingsViewState extends State<OrganizationSettingsView> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _gstController = TextEditingController();
  final _industryController = TextEditingController();
  final _locationController = TextEditingController();
  
  dynamic _selectedLogoFile; // File on mobile, Uint8List on web
  String? _selectedLogoFileName;
  String? _currentLogoUrl;
  bool _hasChanges = false;
  bool _hasLoadedDetails = false;
  late final DepotBloc _depotBloc;
  String? _loadedDepotOrgId;
  
  final List<String> _industryOptions = [
    'Manufacturing',
    'Manufactoring', // Keep the typo for existing data
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
    _initializeControllers();
    _depotBloc = DepotBloc(depotRepository: DepotRepository());
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _gstController.dispose();
    _industryController.dispose();
    _locationController.dispose();
    _depotBloc.close();
    super.dispose();
  }

  void _initializeControllers() {
    // Initialize with empty values - will be populated when organization data loads
    _nameController.text = '';
    _emailController.text = '';
    _gstController.text = '';
    _industryController.text = '';
    _locationController.text = '';
  }

  void _updateControllersFromOrganization(Map<String, dynamic> organization) {
    print('🔍 DEBUG: Updating controllers with organization data: $organization');
    
    // Extract values with fallbacks for different field names
    final name = organization['orgName'] ?? organization['name'] ?? '';
    final email = organization['email'] ?? '';
    final gst = organization['gstNo'] ?? organization['gst'] ?? '';
    final metadata = organization['metadata'] as Map<String, dynamic>? ?? {};
    final industry = metadata['industry'] ?? '';
    final location = metadata['location'] ?? '';
    
    print('🔍 DEBUG: Extracted values - Name: "$name", Email: "$email", GST: "$gst", Industry: "$industry", Location: "$location"');
    
    _nameController.text = name;
    _emailController.text = email;
    _gstController.text = gst;
    _industryController.text = industry;
    _locationController.text = location;
    
    _currentLogoUrl = organization['orgLogoUrl'];
    
    print('🔍 DEBUG: Controllers updated - Name: ${_nameController.text}, Email: ${_emailController.text}');
  }

  void _loadOrganizationDetails() {
    final orgContext = context.read<OrganizationContext>();
    if (orgContext.organizationId != null) {
      print('🔍 DEBUG: Loading organization details for orgId: ${orgContext.organizationId}');
      context.read<OrganizationBloc>().add(LoadOrganizationDetails(orgContext.organizationId!));
    }
  }


  @override
  Widget build(BuildContext context) {
    return Consumer<OrganizationContext>(
      builder: (context, orgContext, child) {
        print('🔍 DEBUG: OrganizationSettingsView build - hasOrganization: ${orgContext.hasOrganization}');
        print('🔍 DEBUG: Organization data: ${orgContext.currentOrganization}');
        
        // Show loading or error state if no organization data
        if (!orgContext.hasOrganization) {
          return PageContainer(
            fullHeight: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 200), // Top spacing
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
                Text(
                  'Loading organization data...',
                  style: const TextStyle(color: Colors.white),
                ),
                const SizedBox(height: 200), // Bottom spacing
              ],
            ),
          );
        }

        // Load organization details if not already loaded
        if (orgContext.currentOrganization != null && !_hasLoadedDetails) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              print('🔍 DEBUG: Loading organization details for the first time');
              _loadOrganizationDetails();
              _hasLoadedDetails = true;
            }
          });
        }

        if (orgContext.organizationId != null &&
            _loadedDepotOrgId != orgContext.organizationId) {
          _loadedDepotOrgId = orgContext.organizationId;
          _depotBloc.add(LoadDepotLocation(_loadedDepotOrgId!));
        } else if (orgContext.organizationId == null && _loadedDepotOrgId != null) {
          _loadedDepotOrgId = null;
        }

        return BlocListener<OrganizationBloc, OrganizationState>(
          listener: (context, state) {
            print('🔍 DEBUG: BLoC state changed: ${state.runtimeType}');
            if (state is OrganizationDetailsLoaded) {
              print('🔍 DEBUG: Organization details loaded: ${state.organization.toMap()}');
              orgContext.setLoading(false);
              // Update controllers with loaded data
              _updateControllersFromOrganization(state.organization.toMap());
            } else if (state is OrganizationUpdated) {
              orgContext.setLoading(false);
              setState(() {
                _hasChanges = false;
              });
              CustomSnackBar.showSuccess(context, 'Organization updated successfully!');
              widget.onBack();
            } else if (state is OrganizationFailure) {
              print('🔍 DEBUG: Organization error: ${state.message}');
              orgContext.setError(state.message);
            }
          },
          child: PageContainer(
            fullHeight: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                PageHeader(
                  title: 'Organization Settings',
                  onBack: widget.onBack,
                  role: _getRoleString(orgContext.userRole),
                ),
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 800),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(height: AppTheme.spacingLg),
                        FormContainer(
                          title: 'Organization Details',
                          child: _buildOrganizationForm(),
                        ),
                        const SizedBox(height: AppTheme.spacingLg),
                        if (orgContext.organizationId != null) ...[
                          FormContainer(
                            title: 'Depot Location',
                            child: BlocProvider.value(
                              value: _depotBloc,
                              child: DepotLocationSection(
                                orgId: orgContext.organizationId!,
                              ),
                            ),
                          ),
                          const SizedBox(height: AppTheme.spacingLg),
                        ],
                        FormContainer(
                          title: 'Subscription Information',
                          child: _buildSubscriptionInfo(),
                        ),
                        const SizedBox(height: AppTheme.spacingLg),
                        _buildActionButtons(),
                        const SizedBox(height: AppTheme.spacingLg),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _getRoleString(int? userRole) {
    switch (userRole) {
      case 1:
        return 'admin';
      case 2:
        return 'manager';
      case 3:
        return 'driver';
      default:
        return 'member';
    }
  }


  Widget _buildOrganizationForm() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Organization Logo Section
          _buildLogoSection(),
          const SizedBox(height: AppTheme.spacingLg),
          
          // Basic Information
          _buildBasicInfoSection(),
          const SizedBox(height: AppTheme.spacingLg),
          
          // Metadata Section
          _buildMetadataSection(),
        ],
      ),
    );
  }

  Widget _buildLogoSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Organization Logo',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: AppTheme.spacingMd),
        Row(
          children: [
            // Logo Preview
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: const Color(0xFF374151),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF4B5563)),
              ),
              child: _selectedLogoFile != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.memory(
                        _selectedLogoFile as Uint8List,
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
                                color: Colors.white70,
                                size: 32,
                              );
                            },
                          ),
                        )
                      : const Icon(
                          Icons.business,
                          color: Colors.white70,
                          size: 32,
                        ),
            ),
            const SizedBox(width: AppTheme.spacingMd),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CustomButton(
                    text: 'Upload Logo',
                    onPressed: _pickLogo,
                    variant: CustomButtonVariant.secondary,
                    size: CustomButtonSize.medium,
                    icon: const Icon(
                      Icons.cloud_upload_outlined,
                      size: 18,
                      color: Color(0xFF8E8E93),
                    ),
                  ),
                  const SizedBox(height: AppTheme.spacingSm),
                  Text(
                    'Recommended: 200x200px, PNG or JPG',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildBasicInfoSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Basic Information',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: AppTheme.spacingMd),
        CustomTextField(
          controller: _nameController,
          labelText: 'Organization Name',
          hintText: 'Enter organization name',
          onChanged: (_) => setState(() => _hasChanges = true),
        ),
        const SizedBox(height: AppTheme.spacingMd),
        CustomTextField(
          controller: _emailController,
          labelText: 'Email',
          hintText: 'Enter organization email',
          keyboardType: TextInputType.emailAddress,
          onChanged: (_) => setState(() => _hasChanges = true),
        ),
        const SizedBox(height: AppTheme.spacingMd),
        CustomTextField(
          controller: _gstController,
          labelText: 'GST Number',
          hintText: 'Enter GST number',
          onChanged: (_) => setState(() => _hasChanges = true),
        ),
      ],
    );
  }

  Widget _buildMetadataSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Additional Information',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: AppTheme.spacingMd),
        CustomDropdown<String>(
          value: _industryController.text.isEmpty || !_industryOptions.contains(_industryController.text) ? null : _industryController.text,
          items: _industryOptions.map((industry) => DropdownMenuItem<String>(
            value: industry,
            child: Text(industry),
          )).toList(),
          labelText: 'Industry',
          hintText: 'Select industry',
          onChanged: (value) {
            if (value != null) {
              _industryController.text = value;
              setState(() => _hasChanges = true);
            }
          },
        ),
        const SizedBox(height: AppTheme.spacingMd),
        CustomTextField(
          controller: _locationController,
          labelText: 'Location',
          hintText: 'Enter location',
          onChanged: (_) => setState(() => _hasChanges = true),
        ),
      ],
    );
  }

  Widget _buildSubscriptionInfo() {
    return BlocBuilder<OrganizationBloc, OrganizationState>(
      builder: (context, state) {
        if (state is OrganizationDetailsLoaded) {
          final subscription = state.subscription;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Current Subscription',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: AppTheme.spacingMd),
              Container(
                padding: const EdgeInsets.all(AppTheme.spacingMd),
                decoration: BoxDecoration(
                  color: const Color(0xFF1F2937),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF374151)),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Plan',
                          style: TextStyle(color: Colors.white70),
                        ),
                        Text(
                          subscription?.tier.toUpperCase() ?? 'No Plan',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppTheme.spacingSm),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Status',
                          style: TextStyle(color: Colors.white70),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: subscription?.status == 'active' 
                                ? const Color(0x3332D74B)
                                : const Color(0x33FF3B30),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            subscription?.status.toUpperCase() ?? 'UNKNOWN',
                            style: TextStyle(
                              color: subscription?.status == 'active'
                                  ? const Color(0xFF32D74B)
                                  : const Color(0xFFFF3B30),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppTheme.spacingSm),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Next Billing',
                          style: TextStyle(color: Colors.white70),
                        ),
                        Text(
                          subscription?.endDate != null
                              ? _formatDate(subscription!.endDate)
                              : 'N/A',
                          style: const TextStyle(color: Colors.white),
                        ),
                      ],
                    ),
                    if (subscription?.amount != null) ...[
                      const SizedBox(height: AppTheme.spacingSm),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Price',
                            style: TextStyle(color: Colors.white70),
                          ),
                          Text(
                            '${subscription?.currency ?? 'USD'} ${subscription?.amount.toStringAsFixed(2) ?? '0.00'}/${subscription?.subscriptionType ?? 'monthly'}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          );
        } else {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Current Subscription',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: AppTheme.spacingMd),
              Container(
                padding: const EdgeInsets.all(AppTheme.spacingMd),
                decoration: BoxDecoration(
                  color: const Color(0xFF1F2937),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF374151)),
                ),
                child: const Center(
                  child: CircularProgressIndicator(),
                ),
              ),
            ],
          );
        }
      },
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: CustomButton(
            text: 'Cancel',
            onPressed: widget.onBack,
            variant: CustomButtonVariant.danger,
            size: CustomButtonSize.medium,
          ),
        ),
        const SizedBox(width: AppTheme.spacingMd),
        Expanded(
          child: CustomButton(
            text: 'Save Changes',
            onPressed: _hasChanges ? _saveChanges : null,
            variant: CustomButtonVariant.primary,
            size: CustomButtonSize.medium,
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
        CustomSnackBar.showError(context, 'Failed to pick logo: $e');
      }
    }
  }

  void _saveChanges() {
    if (!_formKey.currentState!.validate()) return;

    final orgContext = context.read<OrganizationContext>();
    if (orgContext.organizationId == null) return;

    final organizationData = {
      'orgName': _nameController.text.trim(),
      'email': _emailController.text.trim(),
      'gstNo': _gstController.text.trim(),
      'metadata': {
        'industry': _industryController.text.trim(),
        'location': _locationController.text.trim(),
      },
    };

    context.read<OrganizationBloc>().add(
      UpdateOrganizationDetails(
        orgId: orgContext.organizationId!,
        organization: Organization.fromMap(organizationData),
        logoFile: _selectedLogoFile,
        logoFileName: _selectedLogoFileName,
      ),
    );
  }
}