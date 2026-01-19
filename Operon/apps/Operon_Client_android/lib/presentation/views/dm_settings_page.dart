import 'dart:io';
import 'package:core_bloc/core_bloc.dart';
import 'package:core_models/core_models.dart';
import 'package:core_ui/core_ui.dart';
import 'package:dash_mobile/presentation/blocs/dm_settings/dm_settings_cubit.dart';
import 'package:dash_mobile/presentation/widgets/modern_page_header.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class DmSettingsPage extends StatefulWidget {
  const DmSettingsPage({super.key});

  @override
  State<DmSettingsPage> createState() => _DmSettingsPageState();
}

class _DmSettingsPageState extends State<DmSettingsPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _headerNameController;
  late final TextEditingController _headerAddressController;
  late final TextEditingController _headerPhoneController;
  late final TextEditingController _headerGstNoController;
  late final TextEditingController _footerCustomTextController;
  late final TextEditingController _customTemplateIdController;

  String? _logoImageUrl;
  File? _selectedLogoFile;
  bool _isUploadingLogo = false;
  DmPrintOrientation _printOrientation = DmPrintOrientation.portrait;
  DmPaymentDisplay _paymentDisplay = DmPaymentDisplay.qrCode;
  DmTemplateType _templateType = DmTemplateType.universal;
  bool _settingsLoaded = false;
  final ImagePicker _imagePicker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _headerNameController = TextEditingController();
    _headerAddressController = TextEditingController();
    _headerPhoneController = TextEditingController();
    _headerGstNoController = TextEditingController();
    _footerCustomTextController = TextEditingController();
    _customTemplateIdController = TextEditingController();

    // Load existing settings when available
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final cubit = context.read<DmSettingsCubit>();
        if (cubit.state.settings != null && !_settingsLoaded) {
          _loadSettings(cubit.state.settings!);
        }
      }
    });
  }

  void _loadSettings(DmSettings settings) {
    if (!mounted || _settingsLoaded) return;
    setState(() {
      _headerNameController.text = settings.header.name;
      _headerAddressController.text = settings.header.address;
      _headerPhoneController.text = settings.header.phone;
      _headerGstNoController.text = settings.header.gstNo ?? '';
      _footerCustomTextController.text = settings.footer.customText ?? '';
      _logoImageUrl = settings.header.logoImageUrl;
      _printOrientation = settings.printOrientation;
      _paymentDisplay = settings.paymentDisplay;
      _templateType = settings.templateType;
      _customTemplateIdController.text = settings.customTemplateId ?? '';
      _settingsLoaded = true;
    });
  }

  @override
  void dispose() {
    _headerNameController.dispose();
    _headerAddressController.dispose();
    _headerPhoneController.dispose();
    _headerGstNoController.dispose();
    _footerCustomTextController.dispose();
    _customTemplateIdController.dispose();
    super.dispose();
  }

  Future<void> _pickLogo() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 1920,
        maxHeight: 1920,
      );

      if (image != null && mounted) {
        setState(() {
          _selectedLogoFile = File(image.path);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to pick image: $e')),
        );
      }
    }
  }

  Future<void> _uploadLogo() async {
    if (_selectedLogoFile == null) return;

    setState(() => _isUploadingLogo = true);
    try {
      final cubit = context.read<DmSettingsCubit>();
      final bytes = await _selectedLogoFile!.readAsBytes();
      final extension = _selectedLogoFile!.path.split('.').last.toLowerCase();
      final logoUrl = await cubit.uploadLogo(bytes, extension);
      if (mounted) {
        setState(() {
          _logoImageUrl = logoUrl;
          _selectedLogoFile = null;
          _isUploadingLogo = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Logo uploaded successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isUploadingLogo = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to upload logo: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _removeLogo() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AuthColors.surface,
        title: const Text('Remove Logo', style: TextStyle(color: AuthColors.textMain)),
        content: const Text(
          'Are you sure you want to remove the logo?',
          style: TextStyle(color: AuthColors.textSub),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel', style: TextStyle(color: AuthColors.textSub)),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Remove', style: TextStyle(color: AuthColors.error)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final cubit = context.read<DmSettingsCubit>();
        await cubit.deleteLogo();
        if (mounted) {
          setState(() {
            _logoImageUrl = null;
            _selectedLogoFile = null;
          });
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to remove logo: $e')),
          );
        }
      }
    }
  }

  Future<void> _saveSettings() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    // Upload logo if selected but not uploaded yet
    if (_selectedLogoFile != null && _logoImageUrl == null) {
      await _uploadLogo();
      if (_logoImageUrl == null) {
        return;
      }
    }

    final cubit = context.read<DmSettingsCubit>();
    await cubit.saveSettings(
      name: _headerNameController.text.trim(),
      address: _headerAddressController.text.trim(),
      phone: _headerPhoneController.text.trim(),
      gstNo: _headerGstNoController.text.trim(),
      customText: _footerCustomTextController.text.trim(),
      logoImageUrl: _logoImageUrl,
      printOrientation: _printOrientation,
      paymentDisplay: _paymentDisplay,
      templateType: _templateType,
      customTemplateId: _templateType == DmTemplateType.custom
          ? _customTemplateIdController.text.trim()
          : null,
    );

    if (mounted && cubit.state.status == ViewStatus.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('DM settings saved successfully')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.watch<DmSettingsCubit>();
    final state = cubit.state;
    
    // Load settings when they become available
    if (state.settings != null && !_settingsLoaded) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && state.settings != null && !_settingsLoaded) {
          _loadSettings(state.settings!);
        }
      });
    }
    
    final isLoading = state.status == ViewStatus.loading && state.settings == null;

    return BlocListener<DmSettingsCubit, DmSettingsState>(
      listener: (context, state) {
        if (state.status == ViewStatus.failure && state.message != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.message!)),
          );
        }
      },
      child: Scaffold(
        appBar: const ModernPageHeader(
          title: 'DM Settings',
        ),
        body: Column(
          children: [
            Expanded(
              child: SafeArea(
                bottom: false,
                child: isLoading
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(40),
                          child: CircularProgressIndicator(),
                        ),
                      )
                    : SingleChildScrollView(
                        padding: const EdgeInsets.all(16),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Info Box
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(18),
                                  color: AuthColors.surface,
                                  border: Border.all(
                                    color: AuthColors.textMain.withOpacity(0.1),
                                  ),
                                ),
                                child: const Text(
                                  'Configure header, footer, and print preferences for Delivery Memos (DM).',
                                  style: TextStyle(color: AuthColors.textSub),
                                ),
                              ),
                              const SizedBox(height: 20),
                              // Header Section
                              _buildSection(
                                title: 'Header Settings',
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _buildLogoSection(),
                                    const SizedBox(height: 24),
                                    TextFormField(
                                      controller: _headerNameController,
                                      style: const TextStyle(color: AuthColors.textMain),
                                      decoration: _inputDecoration('Name *'),
                                      validator: (value) =>
                                          (value == null || value.trim().isEmpty)
                                              ? 'Enter name'
                                              : null,
                                    ),
                                    const SizedBox(height: 16),
                                    TextFormField(
                                      controller: _headerAddressController,
                                      style: const TextStyle(color: AuthColors.textMain),
                                      decoration: _inputDecoration('Address *'),
                                      maxLines: 3,
                                      validator: (value) =>
                                          (value == null || value.trim().isEmpty)
                                              ? 'Enter address'
                                              : null,
                                    ),
                                    const SizedBox(height: 16),
                                    TextFormField(
                                      controller: _headerPhoneController,
                                      style: const TextStyle(color: AuthColors.textMain),
                                      decoration: _inputDecoration('Phone *'),
                                      keyboardType: TextInputType.phone,
                                      validator: (value) =>
                                          (value == null || value.trim().isEmpty)
                                              ? 'Enter phone number'
                                              : null,
                                    ),
                                    const SizedBox(height: 16),
                                    TextFormField(
                                      controller: _headerGstNoController,
                                      style: const TextStyle(color: AuthColors.textMain),
                                      decoration: _inputDecoration('GST No (Optional)'),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 20),
                              // Footer Section
                              _buildSection(
                                title: 'Footer Settings',
                                child: TextFormField(
                                  controller: _footerCustomTextController,
                                  style: const TextStyle(color: AuthColors.textMain),
                                  decoration: _inputDecoration('Custom Text (Optional)'),
                                  maxLines: 3,
                                ),
                              ),
                              const SizedBox(height: 20),
                              // Print Preferences
                              _buildSection(
                                title: 'Print Preferences',
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Orientation',
                                      style: TextStyle(
                                        color: AuthColors.textMain,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: _PrintOption(
                                            label: 'Portrait',
                                            icon: Icons.portrait,
                                            isSelected: _printOrientation == DmPrintOrientation.portrait,
                                            onTap: () => setState(() {
                                              _printOrientation = DmPrintOrientation.portrait;
                                            }),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: _PrintOption(
                                            label: 'Landscape',
                                            icon: Icons.landscape,
                                            isSelected: _printOrientation == DmPrintOrientation.landscape,
                                            onTap: () => setState(() {
                                              _printOrientation = DmPrintOrientation.landscape;
                                            }),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 20),
                                    const Text(
                                      'Payment Display',
                                      style: TextStyle(
                                        color: AuthColors.textMain,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: _PrintOption(
                                            label: 'QR Code',
                                            icon: Icons.qr_code,
                                            isSelected: _paymentDisplay == DmPaymentDisplay.qrCode,
                                            onTap: () => setState(() {
                                              _paymentDisplay = DmPaymentDisplay.qrCode;
                                            }),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: _PrintOption(
                                            label: 'Bank Details',
                                            icon: Icons.account_balance,
                                            isSelected: _paymentDisplay == DmPaymentDisplay.bankDetails,
                                            onTap: () => setState(() {
                                              _paymentDisplay = DmPaymentDisplay.bankDetails;
                                            }),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 20),
                              // Save Button
                              SizedBox(
                                width: double.infinity,
                                child: DashButton(
                                  label: 'Save Settings',
                                  onPressed: _saveSettings,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
              ),
            ),
            FloatingNavBar(
              items: const [
                NavBarItem(
                  icon: Icons.home_rounded,
                  label: 'Home',
                  heroTag: 'nav_home',
                ),
                NavBarItem(
                  icon: Icons.pending_actions_rounded,
                  label: 'Pending',
                  heroTag: 'nav_pending',
                ),
                NavBarItem(
                  icon: Icons.schedule_rounded,
                  label: 'Schedule',
                  heroTag: 'nav_schedule',
                ),
                NavBarItem(
                  icon: Icons.map_rounded,
                  label: 'Map',
                  heroTag: 'nav_map',
                ),
                NavBarItem(
                  icon: Icons.dashboard_rounded,
                  label: 'Analytics',
                  heroTag: 'nav_analytics',
                ),
              ],
              currentIndex: -1,
              onItemTapped: (index) {
                context.go('/home', extra: index);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AuthColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AuthColors.textMain.withOpacity(0.1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: AuthColors.textMain,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  Widget _buildLogoSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Logo',
          style: TextStyle(
            color: AuthColors.textMain,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            if (_logoImageUrl != null || _selectedLogoFile != null)
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: AuthColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AuthColors.textMain.withOpacity(0.1),
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: _logoImageUrl != null
                      ? Image.network(
                          _logoImageUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const Icon(
                            Icons.image,
                            color: AuthColors.textSub,
                          ),
                        )
                      : _selectedLogoFile != null
                          ? Image.file(
                              _selectedLogoFile!,
                              fit: BoxFit.cover,
                            )
                          : const SizedBox(),
                ),
              )
            else
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: AuthColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AuthColors.textMain.withOpacity(0.1),
                  ),
                ),
                child: const Icon(
                  Icons.image,
                  color: AuthColors.textSub,
                ),
              ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_isUploadingLogo)
                    const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  else
                    DashButton(
                      label: _selectedLogoFile != null ? 'Upload Logo' : 'Pick Logo',
                      onPressed: _selectedLogoFile != null ? _uploadLogo : _pickLogo,
                    ),
                  if (_logoImageUrl != null || _selectedLogoFile != null) ...[
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: _removeLogo,
                      child: const Text(
                        'Remove',
                        style: TextStyle(color: AuthColors.error),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: AuthColors.textSub),
      filled: true,
      fillColor: AuthColors.surface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: AuthColors.textMain.withOpacity(0.1),
          width: 1,
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: AuthColors.textMain.withOpacity(0.1),
          width: 1,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(
          color: AuthColors.primary,
          width: 2,
        ),
      ),
    );
  }
}

class _PrintOption extends StatelessWidget {
  const _PrintOption({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected
              ? AuthColors.primary.withOpacity(0.2)
              : AuthColors.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected
                ? AuthColors.primary
                : AuthColors.textMain.withOpacity(0.1),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: isSelected ? AuthColors.primary : AuthColors.textSub,
              size: 24,
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? AuthColors.primary : AuthColors.textSub,
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
