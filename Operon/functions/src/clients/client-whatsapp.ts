import * as functions from 'firebase-functions';
import { CLIENTS_COLLECTION } from '../shared/constants';
import { loadWhatsappSettings } from '../shared/whatsapp-service';
import { logInfo, logWarning, logError } from '../shared/logger';

async function sendWhatsappWelcomeMessage(
  to: string,
  clientName: string | undefined,
  organizationId: string | undefined,
  clientId: string,
): Promise<void> {
  // Normalize phone number format (E.164: should have + but WhatsApp also accepts without)
  let normalizedPhone = to.trim();
  // If phone doesn't start with +, add it (E.164 standard)
  // WhatsApp API accepts both formats, but + is standard
  if (!normalizedPhone.startsWith('+')) {
    normalizedPhone = '+' + normalizedPhone;
  }

  const settings = await loadWhatsappSettings(organizationId, true); // verbose=true for client welcome
  if (!settings) {
    logWarning('Client/WhatsApp', 'sendWhatsappWelcomeMessage', 'Skipping send – no settings or disabled', {
      clientId,
      organizationId,
    });
    return;
  }

  const url = `https://graph.facebook.com/v22.0/${settings.phoneId}/messages`;
  const displayName = clientName && clientName.trim().length > 0
    ? clientName.trim()
    : 'there';

  // Mask token for logging (show first 10 chars only)
  const maskedToken = settings.token
    ? `${settings.token.substring(0, 10)}...${settings.token.substring(settings.token.length - 4)}`
    : 'missing';

  logInfo('Client/WhatsApp', 'sendWhatsappWelcomeMessage', 'Sending welcome message', {
    organizationId,
    clientId,
    to: normalizedPhone.substring(0, 4) + '****',
    phoneId: settings.phoneId,
    templateId: settings.welcomeTemplateId ?? 'lakshmee_client_added',
    languageCode: settings.languageCode ?? 'en',
    tokenPreview: maskedToken,
  });

  const payload = {
    messaging_product: 'whatsapp',
    to: normalizedPhone,
    type: 'template',
    template: {
      name: settings.welcomeTemplateId ?? 'lakshmee_client_added',
      language: {
        code: settings.languageCode ?? 'en',
      },
      components: [
        {
          type: 'body',
          parameters: [
            {
              type: 'text',
              text: displayName,
            },
          ],
        },
      ],
    },
  };

  const response = await fetch(url, {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${settings.token}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify(payload),
  });

  if (!response.ok) {
    const text = await response.text();
    let errorDetails: any;
    try {
      errorDetails = JSON.parse(text);
    } catch {
      errorDetails = text;
    }

    logError(
      'Client/WhatsApp',
      'sendWhatsappWelcomeMessage',
      'Failed to send welcome message',
      new Error(`WhatsApp API error: ${response.status} ${response.statusText}`),
      {
        status: response.status,
        statusText: response.statusText,
        error: errorDetails,
        organizationId,
        clientId,
        phoneId: settings.phoneId,
        url,
      },
    );

    // Provide helpful error messages for common issues
    if (response.status === 400 && errorDetails?.error) {
      const errorCode = errorDetails.error.code;
      const errorSubcode = errorDetails.error.error_subcode;
      if (errorCode === 100 && errorSubcode === 33) {
        logError(
          'Client/WhatsApp',
          'sendWhatsappWelcomeMessage',
          'Phone Number ID issue: The Phone Number ID does not exist, lacks permissions, or belongs to a different WhatsApp Business Account. Verify in Meta Business Suite that: 1. Phone Number ID matches the one in your settings, 2. Access token has permission for this Phone Number ID, 3. Both token and Phone Number ID belong to the same WhatsApp Business Account',
        );
      }
    }
    throw new Error(`Failed to send WhatsApp welcome message: ${response.status} ${response.statusText}`);
  } else {
    const result = await response.json().catch(() => ({}));
    
    // Check for errors in response body (WhatsApp API can return 200 with errors)
    if (result.errors && result.errors.length > 0) {
      const errorMessages = result.errors.map((e: any) => e.message || `Code ${e.code}`).join(', ');
      logError(
        'Client/WhatsApp',
        'sendWhatsappWelcomeMessage',
        'WhatsApp API returned errors in response body',
        new Error(`WhatsApp API errors: ${errorMessages}`),
        {
          organizationId,
          clientId,
          to: normalizedPhone.substring(0, 4) + '****',
          phoneId: settings.phoneId,
          errors: result.errors,
          fullResponse: result,
        },
      );
      throw new Error(`Failed to send WhatsApp welcome message: ${errorMessages}`);
    }
    
    // Check if message ID was returned (indicates message was accepted)
    const messageId = result.messages?.[0]?.id;
    if (!messageId) {
      logWarning('Client/WhatsApp', 'sendWhatsappWelcomeMessage', 'No message ID in response - message may not have been accepted', {
        clientId,
        to: normalizedPhone.substring(0, 4) + '****',
        organizationId,
        fullResponse: result,
      });
    }
    
    logInfo('Client/WhatsApp', 'sendWhatsappWelcomeMessage', 'Welcome message sent successfully', {
      clientId,
      to: normalizedPhone.substring(0, 4) + '****',
      organizationId,
      messageId,
      // Note: messageId means API accepted the message, but delivery is asynchronous
      // Delivery status should be checked via webhooks or status API
    });
  }
}

/**
 * Cloud Function: Triggered when a client is created
 * Sends a WhatsApp welcome message to the new client
 */
export const onClientCreatedSendWhatsappWelcome = functions.firestore
  .document(`${CLIENTS_COLLECTION}/{clientId}`)
  .onCreate(async (snapshot, context) => {
    const data = snapshot.data() as {
      name?: string;
      primaryPhone?: string;
      primaryPhoneNormalized?: string;
      organizationId?: string;
    } | undefined;

    if (!data) return;

    const phone = (data.primaryPhoneNormalized || data.primaryPhone || '').trim();
    if (!phone) {
      logWarning('Client/WhatsApp', 'onClientCreatedSendWhatsappWelcome', 'No phone found on client, skipping welcome', {
        clientId: context.params.clientId,
      });
      return;
    }

    // Try to get organizationId from client document, or use default
    let organizationId = data.organizationId;
    if (!organizationId) {
      // Fallback: try to infer from global config or use a default org
      const globalConfig: any = (functions.config() as any).whatsapp ?? {};
      if (globalConfig.default_org_id) {
        organizationId = globalConfig.default_org_id;
        logInfo('Client/WhatsApp', 'onClientCreatedSendWhatsappWelcome', 'Using default org from config', {
          organizationId,
        });
      } else {
        logWarning('Client/WhatsApp', 'onClientCreatedSendWhatsappWelcome', 'No organizationId on client and no default configured, skipping', {
          clientId: context.params.clientId,
        });
        return;
      }
    }

    await sendWhatsappWelcomeMessage(
      phone,
      data.name,
      organizationId,
      context.params.clientId,
    );
  });

