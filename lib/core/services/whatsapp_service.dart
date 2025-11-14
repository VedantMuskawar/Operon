import 'dart:convert';

import 'package:http/http.dart' as http;

class WhatsAppSendException implements Exception {
  WhatsAppSendException(this.message, {this.statusCode, this.body});

  final String message;
  final int? statusCode;
  final String? body;

  @override
  String toString() =>
      'WhatsAppSendException(statusCode: $statusCode, message: $message)';
}

class WhatsAppSendResult {
  const WhatsAppSendResult({
    required this.success,
    this.responseId,
    this.errorMessage,
  });

  final bool success;
  final String? responseId;
  final String? errorMessage;
}

class WhatsAppService {
  WhatsAppService({
    http.Client? httpClient,
    String? graphBaseUrl,
    String apiVersion = 'v21.0',
  })  : _httpClient = httpClient ?? http.Client(),
        _graphBaseUrl = graphBaseUrl ?? 'https://graph.facebook.com',
        _apiVersion = apiVersion;

  final http.Client _httpClient;
  final String _graphBaseUrl;
  final String _apiVersion;

  Uri _buildMessagesUri(String phoneNumberId) {
    return Uri.parse(
      '$_graphBaseUrl/$_apiVersion/$phoneNumberId/messages',
    );
  }

  Future<WhatsAppSendResult> sendTextMessage({
    required String phoneNumberId,
    required String accessToken,
    required String recipientPhoneNumber,
    required String messageBody,
    Map<String, dynamic>? context,
  }) async {
    final uri = _buildMessagesUri(phoneNumberId);
    final payload = <String, dynamic>{
      'messaging_product': 'whatsapp',
      'to': recipientPhoneNumber,
      'type': 'text',
      'text': {
        'preview_url': false,
        'body': messageBody,
      },
      if (context != null) 'context': context,
    };

    final response = await _httpClient.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
      body: jsonEncode(payload),
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final messages = body['messages'] as List<dynamic>?;
      final firstMessage = messages?.isNotEmpty == true ? messages!.first : null;
      final messageId = firstMessage is Map<String, dynamic>
          ? firstMessage['id'] as String?
          : null;
      return WhatsAppSendResult(
        success: true,
        responseId: messageId,
      );
    }

    throw WhatsAppSendException(
      'Failed to send WhatsApp message',
      statusCode: response.statusCode,
      body: response.body,
    );
  }

  Future<WhatsAppSendResult> sendOrderConfirmation({
    required String phoneNumberId,
    required String accessToken,
    required String recipientPhoneNumber,
    required String messageBody,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      return await sendTextMessage(
        phoneNumberId: phoneNumberId,
        accessToken: accessToken,
        recipientPhoneNumber: recipientPhoneNumber,
        messageBody: messageBody,
        context: metadata,
      );
    } on WhatsAppSendException {
      rethrow;
    } catch (error) {
      throw WhatsAppSendException(
        'Unexpected error sending order confirmation: $error',
      );
    }
  }
}

