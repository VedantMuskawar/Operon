import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../models/crm_settings.dart';
import '../../repositories/crm_repository.dart';
import '../../services/crm_messaging_service.dart';
import '../../../../core/services/whatsapp_service.dart';

class CrmPage extends StatefulWidget {
  const CrmPage({
    super.key,
    required this.organizationId,
    required this.organizationName,
  });

  final String organizationId;
  final String? organizationName;

  @override
  State<CrmPage> createState() => _CrmPageState();
}

class _CrmPageState extends State<CrmPage> {
  late final CrmRepository _crmRepository;
  late final CrmMessagingService _messagingService;

  final TextEditingController _templateController = TextEditingController();
  final TextEditingController _phoneNumberIdController = TextEditingController();
  final TextEditingController _accessTokenController = TextEditingController();
  final TextEditingController _testPhoneController = TextEditingController();

  bool _isLoading = true;
  bool _isSaving = false;
  bool _isTesting = false;
  bool _orderConfirmationEnabled = false;

  String? _statusMessage;
  bool _statusIsError = false;

  @override
  void initState() {
    super.initState();
    _crmRepository = CrmRepository();
    _messagingService = CrmMessagingService(
      crmRepository: _crmRepository,
      whatsappService: WhatsAppService(),
    );
    _loadSettings();
  }

  @override
  void dispose() {
    _templateController.dispose();
    _phoneNumberIdController.dispose();
    _accessTokenController.dispose();
    _testPhoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(AppTheme.getResponsivePadding(context)),
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        borderRadius: BorderRadius.circular(AppTheme.radiusXl),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.08),
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x66000000),
            blurRadius: 24,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Customer Relationship Management',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: AppTheme.spacingXs),
          Text(
            'Configure customer notifications and craft WhatsApp templates for your clients.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.white.withValues(alpha: 0.7),
                ),
          ),
          const SizedBox(height: AppTheme.spacingLg),
          Expanded(child: _buildContent()),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator.adaptive(),
      );
    }

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF1F2937),
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.06),
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppTheme.spacingLg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildStatusBanner(),
              _buildToggleCard(),
              const SizedBox(height: AppTheme.spacingLg),
              _buildTemplateCard(),
              const SizedBox(height: AppTheme.spacingLg),
              _buildCredentialsCard(),
              const SizedBox(height: AppTheme.spacingLg),
              _buildActionsRow(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBanner() {
    if (_statusMessage == null) return const SizedBox.shrink();

    final color = _statusIsError
        ? const Color(0xFFFF6B6B)
        : const Color(0xFF34D399);

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: AppTheme.spacingLg),
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacingMd,
        vertical: AppTheme.spacingSm,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Icon(
            _statusIsError ? Icons.error_outline : Icons.check_circle_outline,
            color: color,
          ),
          const SizedBox(width: AppTheme.spacingSm),
          Expanded(
            child: Text(
              _statusMessage ?? '',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.white,
                  ),
            ),
          ),
          IconButton(
            onPressed: () => setState(() => _statusMessage = null),
            icon: const Icon(
              Icons.close,
              color: Colors.white54,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToggleCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppTheme.spacingLg),
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.04),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF60A5FA), Color(0xFFA855F7)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.chat_bubble_outline,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: AppTheme.spacingMd),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'WhatsApp Order Confirmations',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    const SizedBox(height: AppTheme.spacingXs),
                    Text(
                      'Send an automated WhatsApp message from the admin number whenever a new order is created for a client.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.white70,
                          ),
                    ),
                  ],
                ),
              ),
              Switch.adaptive(
                value: _orderConfirmationEnabled,
                onChanged: (value) {
                  setState(() {
                    _orderConfirmationEnabled = value;
                  });
                },
              ),
            ],
          ),
          if (!_orderConfirmationEnabled)
            Padding(
              padding: const EdgeInsets.only(top: AppTheme.spacingMd),
              child: Text(
                'Order confirmations are currently disabled.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.white54,
                      fontStyle: FontStyle.italic,
                    ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTemplateCard() {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingLg),
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.04),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Message Template',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
              ),
              TextButton.icon(
                onPressed: _applyTemplateExample,
                icon: const Icon(Icons.auto_fix_high_outlined),
                label: const Text('Use Sample'),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spacingSm),
          Text(
            'Use placeholders to personalize your message: {{clientName}}, {{orderNumber}}, {{orderQuantity}}, {{deliveryDate}}.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.white60,
                ),
          ),
          const SizedBox(height: AppTheme.spacingMd),
          _buildMultilineField(
            controller: _templateController,
            hint: 'Hi {{clientName}}, your order {{orderNumber}} is confirmed...',
          ),
        ],
      ),
    );
  }

  Widget _buildCredentialsCard() {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingLg),
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.04),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'WhatsApp Cloud API Credentials',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: AppTheme.spacingSm),
          Text(
            'Use your Meta for Developers account to create a WhatsApp Business app. Paste the numeric phone number ID and a permanent access token below.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.white60,
                ),
          ),
          const SizedBox(height: AppTheme.spacingLg),
          _buildTextField(
            controller: _phoneNumberIdController,
            label: 'Phone Number ID',
            hint: '123456789012345',
          ),
          const SizedBox(height: AppTheme.spacingMd),
          _buildTextField(
            controller: _accessTokenController,
            label: 'Access Token',
            hint: 'EAAB... (keep this secure)',
            obscureText: true,
          ),
        ],
      ),
    );
  }

  Widget _buildActionsRow() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Test Message',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: AppTheme.spacingSm),
        _buildTextField(
          controller: _testPhoneController,
          label: 'Recipient Test Number',
          hint: '+919876543210',
        ),
        const SizedBox(height: AppTheme.spacingMd),
        Row(
          children: [
            ElevatedButton.icon(
              onPressed: _isSaving ? null : _handleSave,
              icon: _isSaving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save_outlined),
              label: Text(_isSaving ? 'Saving...' : 'Save Settings'),
            ),
            const SizedBox(width: AppTheme.spacingSm),
            OutlinedButton.icon(
              onPressed:
                  _isTesting || !_orderConfirmationEnabled ? null : _handleTestSend,
              icon: _isTesting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.send_outlined),
              label: Text(_isTesting ? 'Sending...' : 'Send Test'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    bool obscureText = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.white70,
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: AppTheme.spacingXs),
        TextField(
          controller: controller,
          obscureText: obscureText,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Colors.white38),
            filled: true,
            fillColor: const Color(0xFF0F172A),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              borderSide: BorderSide(
                color: Colors.white.withValues(alpha: 0.08),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              borderSide: BorderSide(
                color: Colors.white.withValues(alpha: 0.08),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              borderSide: const BorderSide(
                color: Color(0xFF60A5FA),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMultilineField({
    required TextEditingController controller,
    required String hint,
  }) {
    return TextField(
      controller: controller,
      minLines: 6,
      maxLines: 12,
      style: const TextStyle(
        color: Colors.white,
        height: 1.4,
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white38),
        filled: true,
        fillColor: const Color(0xFF0F172A),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          borderSide: BorderSide(
            color: Colors.white.withValues(alpha: 0.08),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          borderSide: BorderSide(
            color: Colors.white.withValues(alpha: 0.08),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          borderSide: const BorderSide(
            color: Color(0xFF60A5FA),
          ),
        ),
      ),
    );
  }

  Future<void> _loadSettings() async {
    setState(() {
      _isLoading = true;
      _statusMessage = null;
    });

    try {
      final settings = await _crmRepository.fetchSettings(
        organizationId: widget.organizationId,
      );

      _orderConfirmationEnabled = settings.orderConfirmationEnabled;
      _templateController.text = settings.orderConfirmationTemplate;
      if (settings.whatsappPhoneNumberId != null) {
        _phoneNumberIdController.text = settings.whatsappPhoneNumberId!;
      }
      if (settings.whatsappAccessToken != null) {
        _accessTokenController.text = settings.whatsappAccessToken!;
      }
    } catch (error) {
      _showStatus(
        'Failed to load CRM settings: $error',
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _handleSave() async {
    if (_templateController.text.trim().isEmpty) {
      _showStatus(
        'Please provide a WhatsApp message template before saving.',
        isError: true,
      );
      return;
    }

    setState(() {
      _isSaving = true;
      _statusMessage = null;
    });

    try {
      final now = DateTime.now();
      final userId = FirebaseAuth.instance.currentUser?.uid;
      final updatedSettings = CrmSettings(
        organizationId: widget.organizationId,
        orderConfirmationEnabled: _orderConfirmationEnabled,
        orderConfirmationTemplate: _templateController.text.trim(),
        whatsappPhoneNumberId: _phoneNumberIdController.text.trim().isEmpty
            ? null
            : _phoneNumberIdController.text.trim(),
        whatsappAccessToken: _accessTokenController.text.trim().isEmpty
            ? null
            : _accessTokenController.text.trim(),
        updatedAt: now,
        updatedBy: userId,
      );

      await _crmRepository.saveSettings(settings: updatedSettings);
      _showStatus('CRM settings saved successfully.');
    } catch (error) {
      _showStatus(
        'Failed to save CRM settings: $error',
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _handleTestSend() async {
    final phoneNumber = _normalizePhoneNumber(_testPhoneController.text.trim());

    if (phoneNumber == null) {
      _showStatus(
        'Please enter a valid WhatsApp phone number including country code.',
        isError: true,
      );
      return;
    }

    setState(() {
      _isTesting = true;
      _statusMessage = null;
    });

    try {
      await _handleSave();

      final templateVariables = {
        'clientname': 'Test Client',
        'ordernumber': 'TEST-ORDER',
        'orderquantity': '0',
        'deliverydate': 'N/A',
      };

      final result = await _messagingService.sendOrderConfirmation(
        organizationId: widget.organizationId,
        recipientPhoneNumber: phoneNumber,
        templateVariables: templateVariables,
      );

      if (result == null) {
        _showStatus(
          'Order confirmations are disabled. Enable them to send messages.',
          isError: true,
        );
      } else {
        _showStatus(
          'Test message sent successfully${result.responseId != null ? ' (ID: ${result.responseId})' : ''}.',
        );
      }
    } on CrmMessagingConfigurationException catch (error) {
      _showStatus(error.message, isError: true);
    } on WhatsAppSendException catch (error) {
      final details = error.statusCode != null
          ? ' (${error.statusCode})'
          : '';
      _showStatus(
        'WhatsApp API error$details: ${error.body ?? error.message}',
        isError: true,
      );
    } catch (error) {
      _showStatus(
        'Failed to send test message: $error',
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() => _isTesting = false);
      }
    }
  }

  void _applyTemplateExample() {
    const example = '''
Hi {{clientName}},

Thank you for placing order {{orderNumber}} with Operon.

Quantity: {{orderQuantity}}
Estimated Delivery: {{deliveryDate}}

We appreciate your business!
''';
    setState(() {
      _templateController.text = example.trim();
    });
  }

  void _showStatus(String message, {bool isError = false}) {
    if (!mounted) return;
    setState(() {
      _statusMessage = message;
      _statusIsError = isError;
    });
  }

  String? _normalizePhoneNumber(String input) {
    if (input.isEmpty) return null;

    final digits = input.replaceAll(RegExp(r'[^0-9+]'), '');
    if (digits.isEmpty) return null;

    if (digits.startsWith('+')) {
      if (digits.length < 10) return null;
      return digits;
    }

    if (digits.length >= 10) {
      return '+$digits';
    }
    return null;
  }
}

