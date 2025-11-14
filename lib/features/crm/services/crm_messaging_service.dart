import '../../../core/services/whatsapp_service.dart';
import '../models/crm_settings.dart';
import '../repositories/crm_repository.dart';

class CrmMessagingConfigurationException implements Exception {
  CrmMessagingConfigurationException(this.message);

  final String message;

  @override
  String toString() =>
      'CrmMessagingConfigurationException(message: $message)';
}

class CrmMessagingService {
  CrmMessagingService({
    CrmSettingsDataSource? crmRepository,
    WhatsAppService? whatsappService,
  })  : _crmRepository = crmRepository ?? CrmRepository(),
        _whatsappService = whatsappService ?? WhatsAppService();

  final CrmSettingsDataSource _crmRepository;
  final WhatsAppService _whatsappService;

  static const String _defaultOrderConfirmationTemplate = '''
Hi {{clientName}},

Your order {{orderNumber}} has been placed successfully for {{orderQuantity}} units.

Thank you for choosing Operon.
''';

  Future<WhatsAppSendResult?> sendOrderConfirmation({
    required String organizationId,
    required String recipientPhoneNumber,
    Map<String, String> templateVariables = const {},
  }) async {
    final settings =
        await _crmRepository.fetchSettings(organizationId: organizationId);

    if (!settings.orderConfirmationEnabled) {
      return null;
    }

    return _sendOrderConfirmationWithSettings(
      settings: settings,
      recipientPhoneNumber: recipientPhoneNumber,
      templateVariables: templateVariables,
    );
  }

  Future<WhatsAppSendResult> _sendOrderConfirmationWithSettings({
    required CrmSettings settings,
    required String recipientPhoneNumber,
    required Map<String, String> templateVariables,
  }) async {
    final accessToken = settings.whatsappAccessToken;
    final phoneNumberId = settings.whatsappPhoneNumberId;

    if (accessToken == null || accessToken.isEmpty) {
      throw CrmMessagingConfigurationException(
        'WhatsApp access token is not configured for this organization.',
      );
    }

    if (phoneNumberId == null || phoneNumberId.isEmpty) {
      throw CrmMessagingConfigurationException(
        'WhatsApp phone number ID is not configured for this organization.',
      );
    }

    final template = settings.orderConfirmationTemplate.isNotEmpty
        ? settings.orderConfirmationTemplate
        : _defaultOrderConfirmationTemplate;

    final messageBody = _interpolateTemplate(
      template,
      templateVariables,
      fallbackValues: {
        'clientName': 'Valued Customer',
        'orderNumber': '',
        'orderQuantity': '',
      },
    );

    return _whatsappService.sendOrderConfirmation(
      phoneNumberId: phoneNumberId,
      accessToken: accessToken,
      recipientPhoneNumber: recipientPhoneNumber,
      messageBody: messageBody,
      metadata: {
        'metadata': {
          'source': 'operon_crm',
          'templateVersion': settings.updatedAt?.toIso8601String(),
        },
      },
    );
  }

  String _interpolateTemplate(
    String template,
    Map<String, String> variables, {
    Map<String, String> fallbackValues = const {},
  }) {
    final buffer = StringBuffer();
    int index = 0;

    while (index < template.length) {
      final startIndex = template.indexOf('{{', index);
      if (startIndex == -1) {
        buffer.write(template.substring(index));
        break;
      }

      buffer.write(template.substring(index, startIndex));
      final endIndex = template.indexOf('}}', startIndex + 2);
      if (endIndex == -1) {
        buffer.write(template.substring(startIndex));
        break;
      }

      final key =
          template.substring(startIndex + 2, endIndex).trim().toLowerCase();
      final value = variables[key] ??
          variables[key.replaceAll(' ', '')] ??
          fallbackValues[key] ??
          '';
      buffer.write(value);

      index = endIndex + 2;
    }

    return buffer.toString();
  }
}

