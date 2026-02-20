import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:core_bloc/core_bloc.dart';
import 'package:core_models/core_models.dart';
import 'package:core_ui/core_ui.dart';
import 'package:dash_mobile/presentation/blocs/dm_settings/dm_settings_cubit.dart';
import 'package:dash_mobile/presentation/widgets/modern_page_header.dart';
import 'package:image_picker/image_picker.dart';
import 'package:dash_mobile/shared/constants/app_spacing.dart';
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

  String? _logoImageUrl;
  File? _selectedLogoFile;
  bool _isUploadingLogo = false;
  DmPrintOrientation _printOrientation = DmPrintOrientation.portrait;
  DmPaymentDisplay _paymentDisplay = DmPaymentDisplay.qrCode;
  DmTemplateType _templateType = DmTemplateType.universal;
  String _selectedCustomTemplateId = 'LIT1';
  bool _settingsLoaded = false;
  final ImagePicker _imagePicker = ImagePicker();

  static const List<String> _templateOptions = ['LIT1', 'LIT2'];

  @override
  void initState() {
    super.initState();
    _headerNameController = TextEditingController();
    _headerAddressController = TextEditingController();
    _headerPhoneController = TextEditingController();
    _headerGstNoController = TextEditingController();
    _footerCustomTextController = TextEditingController();

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
      _selectedCustomTemplateId = _normalizeTemplateId(settings.customTemplateId);
      _settingsLoaded = true;
    });
  }

  String _normalizeTemplateId(String? templateId) {
    final id = templateId?.trim();
    if (id == 'LIT2' || id == 'lakshmee_v2') return 'LIT2';
    if (id == 'LIT1' || id == 'lakshmee_v1') return 'LIT1';
    return 'LIT1';
  }

  @override
  void dispose() {
    _headerNameController.dispose();
    _headerAddressController.dispose();
    _headerPhoneController.dispose();
    _headerGstNoController.dispose();
    _footerCustomTextController.dispose();
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

    if (!mounted) return;

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
          ? _selectedCustomTemplateId
          : null,
    );

    if (!mounted) return;

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
                          padding: EdgeInsets.all(AppSpacing.paddingXXXL * 1.25),
                          child: CircularProgressIndicator(),
                        ),
                      )
                    : SingleChildScrollView(
                        padding: const EdgeInsets.all(AppSpacing.paddingLG),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Info Box
                              Container(
                                padding: const EdgeInsets.all(AppSpacing.paddingLG),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(AppSpacing.radiusXL),
                                  color: AuthColors.surface,
                                  border: Border.all(
                                    color: AuthColors.textMain.withValues(alpha: 0.1),
                                  ),
                                ),
                                child: const Text(
                                  'Configure header, footer, and print preferences for Delivery Memos (DM).',
                                  style: TextStyle(color: AuthColors.textSub),
                                ),
                              ),
                              const SizedBox(height: AppSpacing.paddingXL),
                              // Header Section
                              _buildSection(
                                title: 'Header Settings',
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _buildLogoSection(),
                                    const SizedBox(height: AppSpacing.paddingXXL),
                                    TextFormField(
                                      controller: _headerNameController,
                                      style: const TextStyle(color: AuthColors.textMain),
                                      decoration: _inputDecoration('Name *'),
                                      validator: (value) =>
                                          (value == null || value.trim().isEmpty)
                                              ? 'Enter name'
                                              : null,
                                    ),
                                    const SizedBox(height: AppSpacing.paddingLG),
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
                                    const SizedBox(height: AppSpacing.paddingLG),
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
                                    const SizedBox(height: AppSpacing.paddingLG),
                                    TextFormField(
                                      controller: _headerGstNoController,
                                      style: const TextStyle(color: AuthColors.textMain),
                                      decoration: _inputDecoration('GST No (Optional)'),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: AppSpacing.paddingXL),
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
                              const SizedBox(height: AppSpacing.paddingXL),
                              // DM Template
                              _buildSection(
                                title: 'DM Template',
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Template Type',
                                      style: TextStyle(
                                        color: AuthColors.textMain,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: AppSpacing.paddingMD),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: _PrintOption(
                                            label: 'Universal',
                                            icon: Icons.style,
                                            isSelected: _templateType == DmTemplateType.universal,
                                            onTap: () => setState(() {
                                              _templateType = DmTemplateType.universal;
                                            }),
                                          ),
                                        ),
                                        const SizedBox(width: AppSpacing.paddingMD),
                                        Expanded(
                                          child: _PrintOption(
                                            label: 'Custom',
                                            icon: Icons.brush,
                                            isSelected: _templateType == DmTemplateType.custom,
                                            onTap: () => setState(() {
                                              _templateType = DmTemplateType.custom;
                                            }),
                                          ),
                                        ),
                                      ],
                                    ),
                                    if (_templateType == DmTemplateType.custom) ...[
                                      const SizedBox(height: AppSpacing.paddingXL),
                                      DropdownButtonFormField<String>(
                                        value: _selectedCustomTemplateId,
                                        decoration: _inputDecoration('Custom Template *'),
                                        dropdownColor: AuthColors.surface,
                                        style: const TextStyle(color: AuthColors.textMain),
                                        iconEnabledColor: AuthColors.textSub,
                                        items: _templateOptions
                                            .map(
                                              (id) => DropdownMenuItem<String>(
                                                value: id,
                                                child: Text(
                                                  '$id${id == 'LIT2' ? ' (Blank Unit Price + Total)' : ''}',
                                                  style: const TextStyle(color: AuthColors.textMain),
                                                ),
                                              ),
                                            )
                                            .toList(),
                                        onChanged: (value) {
                                          if (value == null) return;
                                          setState(() {
                                            _selectedCustomTemplateId = value;
                                          });
                                        },
                                      ),
                                      const SizedBox(height: AppSpacing.paddingXS),
                                      const Text(
                                        'LIT1: Standard template | LIT2: hides Unit Price and Total.',
                                        style: TextStyle(
                                          color: AuthColors.textSub,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              const SizedBox(height: AppSpacing.paddingXL),
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
                                    const SizedBox(height: AppSpacing.paddingMD),
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
                                        const SizedBox(width: AppSpacing.paddingMD),
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
                                    const SizedBox(height: AppSpacing.paddingXL),
                                    const Text(
                                      'Payment Display',
                                      style: TextStyle(
                                        color: AuthColors.textMain,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: AppSpacing.paddingMD),
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
                                        const SizedBox(width: AppSpacing.paddingMD),
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
                              const SizedBox(height: AppSpacing.paddingXL),
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
                  icon: Icons.event_available_rounded,
                  label: 'Cash Ledger',
                  heroTag: 'nav_cash_ledger',
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
      padding: const EdgeInsets.all(AppSpacing.paddingXL),
      decoration: BoxDecoration(
        color: AuthColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusXL),
        border: Border.all(
          color: AuthColors.textMain.withValues(alpha: 0.1),
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
          const SizedBox(height: AppSpacing.paddingLG),
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
        const SizedBox(height: AppSpacing.paddingMD),
        Row(
          children: [
            if (_logoImageUrl != null || _selectedLogoFile != null)
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: AuthColors.surface,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMD),
                  border: Border.all(
                    color: AuthColors.textMain.withValues(alpha: 0.1),
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMD),
                  child: _logoImageUrl != null
                      ? CachedNetworkImage(
                          imageUrl: _logoImageUrl!,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => const Center(
                            child: CircularProgressIndicator(),
                          ),
                          errorWidget: (context, url, error) => const Icon(
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
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMD),
                  border: Border.all(
                    color: AuthColors.textMain.withValues(alpha: 0.1),
                  ),
                ),
                child: const Icon(
                  Icons.image,
                  color: AuthColors.textSub,
                ),
              ),
            const SizedBox(width: AppSpacing.paddingMD),
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
                    const SizedBox(height: AppSpacing.paddingSM),
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
        borderRadius: BorderRadius.circular(AppSpacing.radiusMD),
        borderSide: BorderSide(
          color: AuthColors.textMain.withValues(alpha: 0.1),
          width: 1,
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusMD),
        borderSide: BorderSide(
          color: AuthColors.textMain.withValues(alpha: 0.1),
          width: 1,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusMD),
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
      borderRadius: BorderRadius.circular(AppSpacing.radiusSM),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.paddingMD),
        decoration: BoxDecoration(
          color: isSelected
              ? AuthColors.primary.withValues(alpha: 0.2)
              : AuthColors.surface,
          borderRadius: BorderRadius.circular(AppSpacing.radiusSM),
          border: Border.all(
            color: isSelected
                ? AuthColors.primary
                : AuthColors.textMain.withValues(alpha: 0.1),
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
            const SizedBox(height: AppSpacing.paddingSM),
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
