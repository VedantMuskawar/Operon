import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../../core/app_theme.dart';
import '../../models/client.dart';
import '../../repositories/android_client_repository.dart';
import 'android_client_pending_orders_page.dart';

class AndroidClientDetailPage extends StatefulWidget {
  final String organizationId;
  final String? initialName;
  final String? initialPhone;
  final Client? existingClient;

  const AndroidClientDetailPage({
    super.key,
    required this.organizationId,
    this.initialName,
    this.initialPhone,
    this.existingClient,
  });

  @override
  State<AndroidClientDetailPage> createState() => _AndroidClientDetailPageState();
}

class _AndroidClientDetailPageState extends State<AndroidClientDetailPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _streetController = TextEditingController();
  final _cityController = TextEditingController();
  final _stateController = TextEditingController();
  final _zipCodeController = TextEditingController();
  final _countryController = TextEditingController();
  final _notesController = TextEditingController();

  final AndroidClientRepository _repository = AndroidClientRepository();
  bool _isLoading = false;

  bool get _isEditing => widget.existingClient != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      final client = widget.existingClient!;
      _nameController.text = client.name;
      _phoneController.text = AndroidClientRepository.normalizePhoneNumber(client.phoneNumber);
      _emailController.text = client.email ?? '';
      _notesController.text = client.notes ?? '';

      final address = client.address;
      if (address != null) {
        _streetController.text = address.street ?? '';
        _cityController.text = address.city ?? '';
        _stateController.text = address.state ?? '';
        _zipCodeController.text = address.zipCode ?? '';
        _countryController.text = address.country ?? '';
      }
    } else {
      _nameController.text = widget.initialName ?? '';
      // Normalize phone number with country code if provided
      if (widget.initialPhone != null && widget.initialPhone!.isNotEmpty) {
        _phoneController.text = AndroidClientRepository.normalizePhoneNumber(widget.initialPhone!);
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _streetController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _zipCodeController.dispose();
    _countryController.dispose();
    _notesController.dispose();
    super.dispose();
  }


  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    if (_isEditing) {
      await _updateExistingClient();
    } else {
      await _createClient();
    }
  }

  Future<void> _createClient() async {
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid ?? '';

      final address = _buildAddressFromInputs();

      final client = Client(
        organizationId: widget.organizationId,
        name: _nameController.text.trim(),
        phoneNumber: _phoneController.text.trim(),
        email: _emailController.text.trim().isNotEmpty ? _emailController.text.trim() : null,
        address: address,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        createdBy: userId,
        updatedBy: userId,
        status: ClientStatus.active,
        notes: _notesController.text.trim().isNotEmpty ? _notesController.text.trim() : null,
      );

      await _repository.createClient(widget.organizationId, client, userId);

      final createdClient = await _repository.getClientByPhoneNumber(
        widget.organizationId,
        client.phoneNumber,
      );

      if (!mounted) return;

      if (createdClient != null) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => AndroidClientPendingOrdersPage(
              organizationId: widget.organizationId,
              clientId: createdClient.clientId,
              clientName: createdClient.name,
              clientPhone: createdClient.phoneNumber,
            ),
          ),
        );
      } else {
        setState(() {
          _isLoading = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Client created successfully')),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error creating client: $e')),
      );
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _updateExistingClient() async {
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid ?? '';
      final existingClient = widget.existingClient!;
      final address = _buildAddressFromInputs();

      final updatedClient = existingClient.copyWith(
        name: _nameController.text.trim(),
        phoneNumber: _phoneController.text.trim(),
        email: _emailController.text.trim().isNotEmpty ? _emailController.text.trim() : null,
        address: address,
        notes: _notesController.text.trim().isNotEmpty ? _notesController.text.trim() : null,
      );

      await _repository.updateClient(
        widget.organizationId,
        existingClient.clientId,
        updatedClient,
        userId,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Client updated successfully')),
      );

      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating client: $e')),
      );
      setState(() {
        _isLoading = false;
      });
    }
  }

  ClientAddress? _buildAddressFromInputs() {
    if (_streetController.text.isEmpty &&
        _cityController.text.isEmpty &&
        _stateController.text.isEmpty &&
        _zipCodeController.text.isEmpty &&
        _countryController.text.isEmpty) {
      return null;
    }

    return ClientAddress(
      street: _streetController.text.isNotEmpty ? _streetController.text : null,
      city: _cityController.text.isNotEmpty ? _cityController.text : null,
      state: _stateController.text.isNotEmpty ? _stateController.text : null,
      zipCode: _zipCodeController.text.isNotEmpty ? _zipCodeController.text : null,
      country: _countryController.text.isNotEmpty ? _countryController.text : null,
    );
  }

  Widget _buildSectionCard({
    required String title,
    required List<Widget> children,
    bool optional = false,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 12),
            child: Row(
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimaryColor,
                  ),
                ),
                if (optional) ...[
                  const SizedBox(width: 8),
                  Text(
                    '(Optional)',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.normal,
                      color: AppTheme.textSecondaryColor,
                    ),
                  ),
                ],
              ],
            ),
          ),
          ...children,
        ],
      ),
    );
  }

  Widget _buildPhoneInputField({
    required TextEditingController controller,
    required String label,
    String? hint,
    String? Function(String?)? validator,
    bool enabled = true,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: TextFormField(
        controller: controller,
        enabled: enabled,
        keyboardType: TextInputType.phone,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint ?? 'Enter phone number with country code (e.g., +919876543210)',
          filled: true,
          fillColor: Colors.transparent,
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
            borderSide: BorderSide.none,
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppTheme.errorColor),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppTheme.errorColor, width: 1.5),
          ),
          prefixIcon: const Icon(Icons.phone_outlined, color: AppTheme.textSecondaryColor, size: 22),
          labelStyle: const TextStyle(
            color: AppTheme.textSecondaryColor,
            fontSize: 14,
          ),
          hintStyle: TextStyle(
            color: AppTheme.textTertiaryColor,
            fontSize: 14,
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
        style: const TextStyle(
          color: AppTheme.textPrimaryColor,
          fontSize: 16,
        ),
        validator: validator,
        onChanged: (value) {
          // Only normalize if user is actively typing (not when programmatically set)
          // If user enters digits without +, check if we need to add country code
          if (value.isNotEmpty && !value.startsWith('+')) {
            final digitsOnly = value.replaceAll(RegExp(r'[^\d]'), '');
            // If user entered exactly 10 digits without country code, add +91
            if (digitsOnly.length == 10) {
              controller.value = TextEditingValue(
                text: '+91$digitsOnly',
                selection: TextSelection.collapsed(offset: '+91$digitsOnly'.length),
              );
            }
          }
          // If user types a + and country code, let them continue typing
          // The normalization will happen when they submit the form
        },
      ),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    String? hint,
    IconData? prefixIcon,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    bool enabled = true,
    int maxLines = 1,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: TextFormField(
        controller: controller,
        enabled: enabled,
        keyboardType: keyboardType,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          filled: true,
          fillColor: Colors.transparent,
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
            borderSide: BorderSide.none,
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppTheme.errorColor),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppTheme.errorColor, width: 1.5),
          ),
          prefixIcon: prefixIcon != null
              ? Icon(prefixIcon, color: AppTheme.textSecondaryColor, size: 22)
              : null,
          labelStyle: const TextStyle(
            color: AppTheme.textSecondaryColor,
            fontSize: 14,
          ),
          hintStyle: TextStyle(
            color: AppTheme.textTertiaryColor,
            fontSize: 14,
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
        style: const TextStyle(
          color: AppTheme.textPrimaryColor,
          fontSize: 16,
        ),
        validator: validator,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final actionLabel = _isEditing ? 'Update Client' : 'Create Client';
    final loadingMessage = _isEditing ? 'Updating client...' : 'Creating client...';
    final actionIcon = _isEditing ? Icons.save : Icons.add;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isEditing ? 'Edit Client' : 'Add Client',
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            letterSpacing: -0.5,
          ),
        ),
        centerTitle: true,
        backgroundColor: AppTheme.surfaceColor,
      ),
      backgroundColor: AppTheme.backgroundColor,
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    loadingMessage,
                    style: TextStyle(
                      color: AppTheme.textSecondaryColor,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Basic Information Section
                    _buildSectionCard(
                      title: 'Basic Information',
                      children: [
                        // Name
                        _buildInputField(
                          controller: _nameController,
                          label: 'Name *',
                          prefixIcon: Icons.person_outline,
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Name is required';
                            }
                            return null;
                          },
                        ),
                        // Phone with country code support
                        _buildPhoneInputField(
                          controller: _phoneController,
                          label: 'Phone Number *',
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Phone number is required';
                            }
                            // Validate that it's a valid phone number format
                            final normalized = AndroidClientRepository.normalizePhoneNumber(value.trim());
                            if (normalized.length < 10) {
                              return 'Please enter a valid phone number';
                            }
                            return null;
                          },
                        ),
                        // Email
                        _buildInputField(
                          controller: _emailController,
                          label: 'Email',
                          hint: 'Optional',
                          prefixIcon: Icons.email_outlined,
                          keyboardType: TextInputType.emailAddress,
                        ),
                      ],
                    ),

                    // Address Section
                    _buildSectionCard(
                      title: 'Address',
                      optional: true,
                      children: [
                        _buildInputField(
                          controller: _streetController,
                          label: 'Street',
                          prefixIcon: Icons.home_outlined,
                        ),
                        Row(
                          children: [
                            Expanded(
                              child: _buildInputField(
                                controller: _cityController,
                                label: 'City',
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildInputField(
                                controller: _stateController,
                                label: 'State',
                              ),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            Expanded(
                              child: _buildInputField(
                                controller: _zipCodeController,
                                label: 'Zip Code',
                                keyboardType: TextInputType.number,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildInputField(
                                controller: _countryController,
                                label: 'Country',
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),

                    // Notes Section
                    _buildSectionCard(
                      title: 'Additional Notes',
                      optional: true,
                      children: [
                        _buildInputField(
                          controller: _notesController,
                          label: 'Notes',
                          hint: 'Optional additional information',
                          prefixIcon: Icons.note_outlined,
                          maxLines: 3,
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // Submit Button with rounded style matching image
                    ElevatedButton(
                      onPressed: _isLoading ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                        elevation: 0,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(actionIcon, size: 22),
                          const SizedBox(width: 8),
                          Text(
                            actionLabel,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
    );
  }
}

