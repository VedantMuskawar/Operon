import 'dart:typed_data';
import 'package:core_bloc/core_bloc.dart';
import 'package:core_models/core_models.dart';
import 'package:core_ui/core_ui.dart';
import 'package:dash_web/data/repositories/dm_settings_repository.dart';
import 'package:dash_web/presentation/blocs/auth/auth_bloc.dart';
import 'package:dash_web/presentation/blocs/dm_settings/dm_settings_cubit.dart';
import 'package:dash_web/presentation/blocs/org_context/org_context_cubit.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Shows the DM Settings modal dialog
void showDmSettingsDialog(BuildContext context) {
  final orgState = context.read<OrganizationContextCubit>().state;
  final organization = orgState.organization;
  final authState = context.read<AuthBloc>().state;
  final userId = authState.userProfile?.id ?? '';

  if (organization == null) return;

  final dmSettingsRepository = context.read<DmSettingsRepository>();

  showDialog(
    context: context,
      barrierColor: AuthColors.background.withValues(alpha: 0.7),
    builder: (dialogContext) => BlocProvider(
      create: (_) => DmSettingsCubit(
        repository: dmSettingsRepository,
        orgId: organization.id,
        userId: userId,
      ),
      child: const _DmSettingsDialog(),
    ),
  );
}

class _DmSettingsDialog extends StatelessWidget {
  const _DmSettingsDialog();

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 900, maxHeight: 800),
        decoration: BoxDecoration(
          color: AuthColors.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: AuthColors.textMain.withValues(alpha: 0.1),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.5),
              blurRadius: 30,
              spreadRadius: -10,
              offset: const Offset(0, 20),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AuthColors.surface,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(24),
                ),
                border: Border(
                  bottom: BorderSide(
                    color: AuthColors.textMain.withValues(alpha: 0.08),
                  ),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AuthColors.primary.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.settings_outlined,
                      color: AuthColors.primary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 16),
                  const Expanded(
                    child: Text(
                      'DM Settings',
                      style: TextStyle(
                        color: AuthColors.textMain,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      if (Navigator.of(context).canPop()) {
                        Navigator.of(context).pop();
                      }
                    },
                    icon: const Icon(Icons.close, color: AuthColors.textSub),
                    tooltip: 'Close',
                  ),
                ],
              ),
            ),
            // Content
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: BlocListener<DmSettingsCubit, DmSettingsState>(
                  listener: (context, state) {
                    if (state.status == ViewStatus.failure && state.message != null) {
                      DashSnackbar.show(context, message: state.message!, isError: true);
                    }
                    if (state.status == ViewStatus.success && state.message != null) {
                      DashSnackbar.show(context, message: state.message!);
                    }
                  },
                  child: const _DmSettingsContent(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Content widget for sidebar use
class DmSettingsPageContent extends StatelessWidget {
  const DmSettingsPageContent({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocListener<DmSettingsCubit, DmSettingsState>(
      listener: (context, state) {
        if (state.status == ViewStatus.failure && state.message != null) {
          DashSnackbar.show(context, message: state.message!, isError: true);
        }
        if (state.status == ViewStatus.success && state.message != null) {
          DashSnackbar.show(context, message: state.message!);
        }
      },
      child: const _DmSettingsContent(),
    );
  }
}

class _DmSettingsContent extends StatefulWidget {
  const _DmSettingsContent();

  @override
  State<_DmSettingsContent> createState() => _DmSettingsContentState();
}

class _DmSettingsContentState extends State<_DmSettingsContent> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _headerNameController;
  late final TextEditingController _headerAddressController;
  late final TextEditingController _headerPhoneController;
  late final TextEditingController _headerGstNoController;
  late final TextEditingController _footerCustomTextController;

  String? _logoImageUrl;
  Uint8List? _selectedLogoBytes;
  bool _isUploadingLogo = false;
  DmPrintOrientation _printOrientation = DmPrintOrientation.portrait;
  DmPaymentDisplay _paymentDisplay = DmPaymentDisplay.qrCode;
  DmTemplateType _templateType = DmTemplateType.universal;
  String _selectedCustomTemplateId = 'LIT1';
  bool _settingsLoaded = false;

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
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['png', 'jpg', 'jpeg'],
      );

      if (result != null && result.files.single.bytes != null) {
        final file = result.files.single;
        setState(() {
          _selectedLogoBytes = file.bytes;
        });
      }
    } catch (e) {
      if (mounted) {
        DashSnackbar.show(
          context,
          message: 'Failed to pick image: $e',
          isError: true,
        );
      }
    }
  }

  Future<void> _uploadLogo() async {
    if (_selectedLogoBytes == null) return;

    setState(() => _isUploadingLogo = true);
    try {
      final cubit = context.read<DmSettingsCubit>();
      
      // Detect file extension from bytes (check magic numbers)
      String extension = 'png'; // Default
      
      // Check for PNG signature: 89 50 4E 47 0D 0A 1A 0A
      if (_selectedLogoBytes!.length >= 8) {
        if (_selectedLogoBytes![0] == 0x89 &&
            _selectedLogoBytes![1] == 0x50 &&
            _selectedLogoBytes![2] == 0x4E &&
            _selectedLogoBytes![3] == 0x47) {
          extension = 'png';
        }
        // Check for JPEG signature: FF D8 FF
        else if (_selectedLogoBytes![0] == 0xFF &&
                 _selectedLogoBytes![1] == 0xD8 &&
                 _selectedLogoBytes![2] == 0xFF) {
          // Check if it's JPEG or JFIF
          if (_selectedLogoBytes!.length >= 4 &&
              (_selectedLogoBytes![3] == 0xE0 || // JFIF
               _selectedLogoBytes![3] == 0xE1 || // EXIF
               _selectedLogoBytes![3] == 0xDB)) {
            extension = 'jpg';
          }
        }
      }
      
      final logoUrl = await cubit.uploadLogo(_selectedLogoBytes!, extension);
      if (mounted) {
        setState(() {
          _logoImageUrl = logoUrl;
          _selectedLogoBytes = null;
          _isUploadingLogo = false;
        });
        DashSnackbar.show(
          context,
          message: 'Logo uploaded successfully',
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isUploadingLogo = false);
        DashSnackbar.show(
          context,
          message: 'Failed to upload logo: ${e.toString()}',
          isError: true,
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
          DashButton(
            label: 'Cancel',
            onPressed: () => Navigator.of(context).pop(false),
            variant: DashButtonVariant.text,
          ),
          DashButton(
            label: 'Remove',
            onPressed: () => Navigator.of(context).pop(true),
            isDestructive: true,
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
            _selectedLogoBytes = null;
          });
        }
      } catch (e) {
        if (mounted) {
          DashSnackbar.show(
            context,
            message: 'Failed to remove logo: $e',
            isError: true,
          );
        }
      }
    }
  }

  Future<void> _saveSettings() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    // Upload logo if selected but not uploaded yet
    if (_selectedLogoBytes != null && _logoImageUrl == null) {
      await _uploadLogo();
      if (_logoImageUrl == null) {
        // Upload failed
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

    if (mounted && cubit.state.status == ViewStatus.success) {
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.watch<DmSettingsCubit>();
    final state = cubit.state;
    
    // Load settings when they become available (defer setState to avoid calling it in build)
    if (state.settings != null && !_settingsLoaded) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && state.settings != null && !_settingsLoaded) {
          _loadSettings(state.settings!);
        }
      });
    }
    
    final isLoading = state.status == ViewStatus.loading && state.settings == null;

    if (isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(40),
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Info Box
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            color: AuthColors.surface,
            border: Border.all(color: AuthColors.textMain.withValues(alpha: 0.12)),
          ),
          child: const Text(
            'Configure header, footer, and print preferences for Delivery Memos (DM).',
            style: TextStyle(color: AuthColors.textSub),
          ),
        ),
        const SizedBox(height: 20),
        // Form Content
        Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Section
              _buildSection(
                title: 'Header Settings',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Logo Upload
                    _buildLogoSection(),
                    const SizedBox(height: 24),
                    // Name
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
                    // Address
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
                    // Phone
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
                    // GST No
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
                  style: const TextStyle(color: Colors.white),
                  decoration: _inputDecoration('Custom Text (Optional)'),
                  maxLines: 3,
                ),
              ),
              const SizedBox(height: 20),
              // DM Template Section
              _buildSection(
                title: 'DM Template',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Template Type',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _PrintOption(
                            label: 'Universal',
                            icon: Icons.style,
                            isSelected: _templateType == DmTemplateType.universal,
                            onTap: () {
                              setState(() {
                                _templateType = DmTemplateType.universal;
                              });
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _PrintOption(
                            label: 'Custom',
                            icon: Icons.brush,
                            isSelected: _templateType == DmTemplateType.custom,
                            onTap: () {
                              setState(() {
                                _templateType = DmTemplateType.custom;
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                    if (_templateType == DmTemplateType.custom) ...[
                      const SizedBox(height: 24),
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
                      const SizedBox(height: 8),
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
              const SizedBox(height: 20),
              // Print Preferences Section
              _buildSection(
                title: 'Print Preferences',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Orientation Selection
                    const Text(
                      'Print Orientation',
                      style: TextStyle(
                        color: Colors.white,
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
                            onTap: () {
                              setState(() {
                                _printOrientation = DmPrintOrientation.portrait;
                              });
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _PrintOption(
                            label: 'Landscape',
                            icon: Icons.landscape,
                            isSelected: _printOrientation == DmPrintOrientation.landscape,
                            onTap: () {
                              setState(() {
                                _printOrientation = DmPrintOrientation.landscape;
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    // Payment Display Selection
                    const Text(
                      'Payment Display',
                      style: TextStyle(
                        color: Colors.white,
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
                            onTap: () {
                              setState(() {
                                _paymentDisplay = DmPaymentDisplay.qrCode;
                              });
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _PrintOption(
                            label: 'Bank Details',
                            icon: Icons.account_balance,
                            isSelected: _paymentDisplay == DmPaymentDisplay.bankDetails,
                            onTap: () {
                              setState(() {
                                _paymentDisplay = DmPaymentDisplay.bankDetails;
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              // Save Button
              SizedBox(
                width: double.infinity,
                child: DashButton(
                  label: 'Save Settings',
                  onPressed: state.status == ViewStatus.loading
                      ? null
                      : _saveSettings,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSection({required String title, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AuthColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AuthColors.textMain.withValues(alpha: 0.1)),
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
          const SizedBox(height: 20),
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
          'Logo (Optional)',
          style: TextStyle(
            color: AuthColors.textMain,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            // Logo Preview
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: AuthColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AuthColors.textMain.withValues(alpha: 0.1)),
              ),
              child: _logoImageUrl != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                        _logoImageUrl!,
                        fit: BoxFit.cover,
                        // Optimize memory usage for web
                        cacheWidth: 400,
                        cacheHeight: 400,
                        errorBuilder: (context, error, stackTrace) {
                          return const Center(
                            child: Icon(Icons.image, color: AuthColors.textSub),
                          );
                        },
                        frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
                          if (wasSynchronouslyLoaded) {
                            return child;
                          }
                          if (frame == null) {
                            return const Center(
                              child: Padding(
                                padding: EdgeInsets.all(16.0),
                                child: CircularProgressIndicator(
                                  color: AuthColors.textSub,
                                  strokeWidth: 2,
                                ),
                              ),
                            );
                          }
                          return child;
                        },
                      ),
                    )
                  : _selectedLogoBytes != null
                      ? FutureBuilder<Uint8List>(
                          future: Future.value(_selectedLogoBytes!),
                          builder: (context, snapshot) {
                            if (snapshot.hasError) {
                              return const Center(
                                child: Icon(Icons.error_outline, color: Colors.white54),
                              );
                            }
                            if (!snapshot.hasData) {
                              return const Center(
                                child: Padding(
                                  padding: EdgeInsets.all(16.0),
                                  child: CircularProgressIndicator(
                                    color: AuthColors.textSub,
                                    strokeWidth: 2,
                                  ),
                                ),
                              );
                            }
                            return ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.memory(
                                snapshot.data!,
                                fit: BoxFit.cover,
                                // Optimize memory usage for web
                                cacheWidth: 400,
                                cacheHeight: 400,
                                errorBuilder: (context, error, stackTrace) {
                                  return const Center(
                                    child: Icon(Icons.error_outline, color: Colors.white54),
                                  );
                                },
                                frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
                                  if (wasSynchronouslyLoaded) {
                                    return child;
                                  }
                                  if (frame == null) {
                                    return const Center(
                                      child: Padding(
                                        padding: EdgeInsets.all(16.0),
                                        child: CircularProgressIndicator(
                                          color: AuthColors.textSub,
                                          strokeWidth: 2,
                                        ),
                                      ),
                                    );
                                  }
                                  return child;
                                },
                              ),
                            );
                          },
                        )
                      : const Center(
                          child: Icon(Icons.image, color: Colors.white54),
                        ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_selectedLogoBytes != null && _logoImageUrl == null) ...[
                    SizedBox(
                      width: double.infinity,
                      child: DashButton(
                        label: _isUploadingLogo
                            ? 'Uploading...'
                            : 'Upload Logo',
                        onPressed: _isUploadingLogo ? null : _uploadLogo,
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                  SizedBox(
                    width: double.infinity,
                    child: DashButton(
                      label: 'Pick Logo',
                      icon: Icons.image,
                      onPressed: _pickLogo,
                    ),
                  ),
                  if (_logoImageUrl != null || _selectedLogoBytes != null) ...[
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: DashButton(
                        label: 'Remove Logo',
                        icon: Icons.delete_outline,
                        onPressed: _removeLogo,
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
      filled: true,
      fillColor: AuthColors.surface,
      labelStyle: const TextStyle(color: AuthColors.textSub),
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
        borderSide: const BorderSide(color: AuthColors.primary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AuthColors.error, width: 1),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AuthColors.error, width: 2),
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
              ? AuthColors.primary.withValues(alpha: 0.2)
              : AuthColors.surface,
          borderRadius: BorderRadius.circular(8),
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
