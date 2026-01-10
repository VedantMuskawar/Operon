import 'dart:typed_data';
import 'package:core_bloc/core_bloc.dart';
import 'package:core_models/core_models.dart';
import 'package:core_ui/core_ui.dart';
import 'package:dash_web/data/repositories/dm_settings_repository.dart';
import 'package:dash_web/presentation/blocs/auth/auth_bloc.dart';
import 'package:dash_web/presentation/blocs/dm_settings/dm_settings_cubit.dart';
import 'package:dash_web/presentation/blocs/org_context/org_context_cubit.dart';
import 'package:dash_web/presentation/widgets/page_workspace_layout.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class DmSettingsPage extends StatelessWidget {
  const DmSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final orgState = context.watch<OrganizationContextCubit>().state;
    final organization = orgState.organization;
    final userId = context.read<AuthBloc>().state.userProfile?.id ?? '';

    if (organization == null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('No organization selected'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => context.go('/org-selection'),
                child: const Text('Select Organization'),
              ),
            ],
          ),
        ),
      );
    }

    return BlocProvider(
      create: (context) => DmSettingsCubit(
        repository: context.read<DmSettingsRepository>(),
        orgId: organization.id,
        userId: userId,
      )..loadSettings(),
      child: PageWorkspaceLayout(
        title: 'DM Settings',
        currentIndex: -1,
        onBack: () => context.go('/home'),
        onNavTap: (index) => context.go('/home?section=$index'),
        child: const DmSettingsPageContent(),
      ),
    );
  }
}

class DmSettingsPageContent extends StatefulWidget {
  const DmSettingsPageContent({super.key});

  @override
  State<DmSettingsPageContent> createState() => _DmSettingsPageContentState();
}

class _DmSettingsPageContentState extends State<DmSettingsPageContent> {
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

  @override
  void initState() {
    super.initState();
    _headerNameController = TextEditingController();
    _headerAddressController = TextEditingController();
    _headerPhoneController = TextEditingController();
    _headerGstNoController = TextEditingController();
    _footerCustomTextController = TextEditingController();

    // Load existing settings
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final cubit = context.read<DmSettingsCubit>();
      if (cubit.state.settings != null) {
        _loadSettings(cubit.state.settings!);
      }
      cubit.stream.listen((state) {
        if (state.settings != null) {
          _loadSettings(state.settings!);
        }
      });
    });
  }

  void _loadSettings(DmSettings settings) {
    if (!mounted) return;
    setState(() {
      _headerNameController.text = settings.header.name;
      _headerAddressController.text = settings.header.address;
      _headerPhoneController.text = settings.header.phone;
      _headerGstNoController.text = settings.header.gstNo ?? '';
      _footerCustomTextController.text = settings.footer.customText ?? '';
      _logoImageUrl = settings.header.logoImageUrl;
      _printOrientation = settings.printOrientation;
      _paymentDisplay = settings.paymentDisplay;
    });
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
          // Store extension from filename if available
          if (file.extension != null) {
            // Extension will be used during upload
          }
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
        backgroundColor: const Color(0xFF11111B),
        title: const Text('Remove Logo', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Are you sure you want to remove the logo?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Remove', style: TextStyle(color: Colors.red)),
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
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<DmSettingsCubit, DmSettingsState>(
      listener: (context, state) {
        if (state.status == ViewStatus.failure && state.message != null) {
          DashSnackbar.show(context, message: state.message!, isError: true);
        } else if (state.status == ViewStatus.success && state.message != null) {
          DashSnackbar.show(context, message: state.message!);
        }
      },
      child: BlocBuilder<DmSettingsCubit, DmSettingsState>(
        builder: (context, state) {
          final isLoading = state.status == ViewStatus.loading && state.settings == null;

          if (isLoading) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(40),
                child: CircularProgressIndicator(),
              ),
            );
          }

          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Info Box (similar to wage settings and products)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    color: const Color(0xFF13131E),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                  ),
                  child: const Text(
                    'Configure header, footer, and print preferences for Delivery Memos (DM).',
                    style: TextStyle(color: Colors.white70),
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
                              style: const TextStyle(color: Colors.white),
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
                              style: const TextStyle(color: Colors.white),
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
                              style: const TextStyle(color: Colors.white),
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
                              style: const TextStyle(color: Colors.white),
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
            ),
          );
        },
      ),
    );
  }

  Widget _buildSection({required String title, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1A1A2A), Color(0xFF11111B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
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
            color: Colors.white,
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
                color: const Color(0xFF1B1B2C),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
              ),
              child: _logoImageUrl != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                        _logoImageUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return const Center(
                            child: Icon(Icons.image, color: Colors.white54),
                          );
                        },
                      ),
                    )
                  : _selectedLogoBytes != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.memory(
                            _selectedLogoBytes!,
                            fit: BoxFit.cover,
                          ),
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
                    child: OutlinedButton(
                      onPressed: _pickLogo,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF6F4BFF),
                        side: const BorderSide(color: Color(0xFF6F4BFF)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text('Pick Logo'),
                    ),
                  ),
                  if (_logoImageUrl != null || _selectedLogoBytes != null) ...[
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: TextButton(
                        onPressed: _removeLogo,
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.redAccent,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: const Text('Remove Logo'),
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
      fillColor: const Color(0xFF1B1B2C),
      labelStyle: const TextStyle(color: Colors.white70),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF6F4BFF), width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.red, width: 1),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.red, width: 2),
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
              ? const Color(0xFF6F4BFF).withValues(alpha: 0.2)
              : const Color(0xFF1B1B2C),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF6F4BFF)
                : Colors.white.withValues(alpha: 0.1),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: isSelected ? const Color(0xFF6F4BFF) : Colors.white70,
              size: 24,
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? const Color(0xFF6F4BFF) : Colors.white70,
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
