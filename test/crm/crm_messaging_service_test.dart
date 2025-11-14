import 'package:flutter_test/flutter_test.dart';

import 'package:operon/features/crm/models/crm_settings.dart';
import 'package:operon/features/crm/repositories/crm_repository.dart';
import 'package:operon/features/crm/services/crm_messaging_service.dart';
import 'package:operon/core/services/whatsapp_service.dart';

class _FakeCrmRepository implements CrmSettingsDataSource {
  _FakeCrmRepository(this._settings);

  CrmSettings _settings;

  Future<CrmSettings> fetchSettings({required String organizationId}) async {
    return _settings;
  }

  void updateSettings(CrmSettings settings) {
    _settings = settings;
  }
}

class _RecordingWhatsAppService extends WhatsAppService {
  final List<Map<String, String>> sentMessages = [];

  @override
  Future<WhatsAppSendResult> sendOrderConfirmation({
    required String phoneNumberId,
    required String accessToken,
    required String recipientPhoneNumber,
    required String messageBody,
    Map<String, dynamic>? metadata,
  }) async {
    sentMessages.add({
      'phoneNumberId': phoneNumberId,
      'accessToken': accessToken,
      'to': recipientPhoneNumber,
      'body': messageBody,
    });
    return const WhatsAppSendResult(success: true, responseId: 'msg_123');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CrmMessagingService', () {
    test('returns null when order confirmations are disabled', () async {
      final fakeRepository = _FakeCrmRepository(
        const CrmSettings(
          organizationId: 'org',
          orderConfirmationEnabled: false,
          orderConfirmationTemplate: '',
        ),
      );

      final recordingService = _RecordingWhatsAppService();
      final crmService = CrmMessagingService(
        crmRepository: fakeRepository,
        whatsappService: recordingService,
      );

      final result = await crmService.sendOrderConfirmation(
        organizationId: 'org',
        recipientPhoneNumber: '+911234567890',
        templateVariables: const {
          'clientname': 'Alice',
        },
      );

      expect(result, isNull);
      expect(recordingService.sentMessages, isEmpty);
    });

    test('throws configuration exception when credentials missing', () async {
      final fakeRepository = _FakeCrmRepository(
        const CrmSettings(
          organizationId: 'org',
          orderConfirmationEnabled: true,
          orderConfirmationTemplate: 'Hello {{clientName}}',
        ),
      );

      final crmService = CrmMessagingService(
        crmRepository: fakeRepository,
        whatsappService: _RecordingWhatsAppService(),
      );

      expect(
        () => crmService.sendOrderConfirmation(
          organizationId: 'org',
          recipientPhoneNumber: '+911234567890',
          templateVariables: const {
            'clientname': 'Alice',
          },
        ),
        throwsA(isA<CrmMessagingConfigurationException>()),
      );
    });

    test('sends templated message when configuration is valid', () async {
      final fakeRepository = _FakeCrmRepository(
        const CrmSettings(
          organizationId: 'org',
          orderConfirmationEnabled: true,
          orderConfirmationTemplate:
              'Hi {{clientName}}, order {{orderNumber}} for {{orderQuantity}} units is confirmed.',
          whatsappPhoneNumberId: 'phone123',
          whatsappAccessToken: 'token-abc',
        ),
      );

      final recordingService = _RecordingWhatsAppService();
      final crmService = CrmMessagingService(
        crmRepository: fakeRepository,
        whatsappService: recordingService,
      );

      final result = await crmService.sendOrderConfirmation(
        organizationId: 'org',
        recipientPhoneNumber: '+911234567890',
        templateVariables: const {
          'clientname': 'Alice',
          'ordernumber': 'ORD-42',
          'orderquantity': '10',
        },
      );

      expect(result, isNotNull);
      expect(result!.success, isTrue);
      expect(recordingService.sentMessages, hasLength(1));
      final sentBody = recordingService.sentMessages.first['body'];
      expect(
        sentBody,
        'Hi Alice, order ORD-42 for 10 units is confirmed.',
      );
    });
  });
}

