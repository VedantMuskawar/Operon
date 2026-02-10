import { WHATSAPP_SETTINGS_COLLECTION } from './constants';
import { getFirestore } from './firestore-helpers';

const db = getFirestore();
const SETTINGS_CACHE_TTL_MS = 60_000;
const settingsCache = new Map<string, { settings: WhatsappSettings | null; expiresAt: number }>();

/**
 * WhatsApp settings interface
 */
export interface WhatsappSettings {
  enabled: boolean;
  token: string;
  phoneId: string;
  welcomeTemplateId?: string;
  languageCode?: string;
  orderConfirmationTemplateId?: string;
  tripDispatchTemplateId?: string;
  tripDeliveryTemplateId?: string;
}

/**
 * Send WhatsApp template message using Meta Graph API
 * 
 * @param url - Graph API endpoint URL
 * @param token - WhatsApp API token
 * @param to - Recipient phone number (E.164 format)
 * @param templateName - Template name to use
 * @param languageCode - Language code (default: 'en')
 * @param parameters - Array of text parameters for the template
 * @param messageType - Type of message for logging purposes
 * @param context - Context information for logging
 * @returns Promise that resolves when message is sent
 */
export async function sendWhatsappTemplateMessage(
  url: string,
  token: string,
  to: string,
  templateName: string,
  languageCode: string,
  parameters: string[],
  messageType: string,
  context: { organizationId?: string; [key: string]: any },
): Promise<string | undefined> {
  const payload = {
    messaging_product: 'whatsapp',
    to: to,
    type: 'template',
    template: {
      name: templateName,
      language: {
        code: languageCode,
      },
      components: [
        {
          type: 'body',
          parameters: parameters.map((param) => ({
            type: 'text',
            text: param,
          })),
        },
      ],
    },
  };

  const response = await fetch(url, {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${token}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify(payload),
  });

  if (!response.ok) {
    const errorText = await response.text();
    let errorDetails: any;
    try {
      errorDetails = JSON.parse(errorText);
    } catch {
      errorDetails = errorText;
    }
    throw new Error(`WhatsApp API error: ${response.status} ${response.statusText} - ${JSON.stringify(errorDetails)}`);
  }

  const result = await response.json() as {
    messages?: Array<{ id?: string }>;
    errors?: Array<{ message?: string; code?: number }>;
  };

  if (result.errors && result.errors.length > 0) {
    const errorMessages = result.errors.map((e) => e.message || 'Unknown error').join(', ');
    throw new Error(`WhatsApp API returned errors: ${errorMessages}`);
  }

  const messageId = result.messages?.[0]?.id;

  console.log(`[WhatsApp Service] ${messageType} template message sent`, {
    ...context,
    to: to.substring(0, 4) + '****',
    templateName,
    messageId,
  });

  return messageId;
}

/**
 * Load WhatsApp settings for an organization
 * First tries organization-specific settings, then falls back to global config
 * 
 * @param organizationId - Organization ID to load settings for
 * @param verbose - If true, logs detailed debug information
 * @returns WhatsApp settings or null if not enabled/configured
 */
export async function loadWhatsappSettings(
  organizationId: string | undefined,
  verbose: boolean = false,
  useCache: boolean = true,
): Promise<WhatsappSettings | null> {
  const cacheKey = organizationId?.trim() || 'global';
  if (useCache) {
    const cached = settingsCache.get(cacheKey);
    if (cached && cached.expiresAt > Date.now()) {
      return cached.settings;
    }
  }
  // First, try to load organization-specific settings
  if (organizationId) {
    const trimmedOrgId = organizationId.trim();
    const orgSettingsRef = db.collection(WHATSAPP_SETTINGS_COLLECTION).doc(trimmedOrgId);
    const docPath = `${WHATSAPP_SETTINGS_COLLECTION}/${trimmedOrgId}`;

    if (verbose) {
      console.log('[WhatsApp Service] Attempting to load org settings', {
        organizationId,
        trimmedOrgId,
        docPath,
      });
    }

    const orgSettingsDoc = await orgSettingsRef.get();

    if (verbose) {
      console.log('[WhatsApp Service] Document read result', {
        organizationId,
        trimmedOrgId,
        docPath,
        exists: orgSettingsDoc.exists,
        hasData: !!orgSettingsDoc.data(),
      });
    }

    if (orgSettingsDoc.exists) {
      const data = orgSettingsDoc.data();

      if (verbose) {
        console.log('[WhatsApp Service] Found org settings document', {
          organizationId,
          trimmedOrgId,
          docPath,
          enabled: data?.enabled,
          enabledType: typeof data?.enabled,
          hasToken: !!data?.token,
          hasPhoneId: !!data?.phoneId,
          dataKeys: data ? Object.keys(data) : [],
        });
      }

      if (data && data.enabled === true) {
        if (!data.token || !data.phoneId) {
          if (verbose) {
            console.log('[WhatsApp Service] Org settings missing token or phoneId', {
              organizationId,
              trimmedOrgId,
              hasToken: !!data.token,
              hasPhoneId: !!data.phoneId,
            });
          }
          return null;
        }
        const settings = {
          enabled: true,
          token: data.token as string,
          phoneId: data.phoneId as string,
          welcomeTemplateId: (data.welcomeTemplateId as string | undefined) ?? 'lakshmee_client_added',
          languageCode: (data.languageCode as string | undefined) ?? 'en',
          orderConfirmationTemplateId: (data.orderConfirmationTemplateId as string | undefined) ?? 'lakshmee_order_added',
          tripDispatchTemplateId: (data.tripDispatchTemplateId as string | undefined) ?? 'lakshmee_trip_dispatch',
          tripDeliveryTemplateId: (data.tripDeliveryTemplateId as string | undefined) ?? 'lakshmee_trip_delivered',
        };
        if (useCache) {
          settingsCache.set(cacheKey, {
            settings,
            expiresAt: Date.now() + SETTINGS_CACHE_TTL_MS,
          });
        }
        return settings;
      } else {
        if (verbose) {
          console.log('[WhatsApp Service] Org settings exist but enabled is false or missing', {
            organizationId,
            trimmedOrgId,
            enabled: data?.enabled,
            enabledType: typeof data?.enabled,
          });
        }
          if (useCache) {
            settingsCache.set(cacheKey, {
              settings: null,
              expiresAt: Date.now() + SETTINGS_CACHE_TTL_MS,
            });
          }
          return null;
      }
    } else if (verbose) {
      // Try to list documents in the collection to debug
      try {
        const snapshot = await db.collection(WHATSAPP_SETTINGS_COLLECTION).limit(5).get();
        const existingDocIds = snapshot.docs.map((doc) => doc.id);
        console.log('[WhatsApp Service] No org settings document found', {
          organizationId,
          trimmedOrgId,
          collection: WHATSAPP_SETTINGS_COLLECTION,
          docPath,
          lookingFor: trimmedOrgId,
          existingDocIds,
          docCount: snapshot.size,
        });
      } catch (error) {
        console.error('[WhatsApp Service] Error checking collection', {
          organizationId,
          trimmedOrgId,
          collection: WHATSAPP_SETTINGS_COLLECTION,
          error,
        });
      }
    }
  }

  // Fallback to env (v2: no functions.config(); set WHATSAPP_* in Firebase config or env)
  const envToken = process.env.WHATSAPP_TOKEN;
  const envPhoneId = process.env.WHATSAPP_PHONE_ID;
  const envEnabled = process.env.WHATSAPP_ENABLED;
  if (
    envToken &&
    envPhoneId &&
    envEnabled !== 'false'
  ) {
    if (verbose) {
      console.log('[WhatsApp Service] Using env fallback');
    }
    const settings = {
      enabled: true,
      token: envToken,
      phoneId: envPhoneId,
      welcomeTemplateId: process.env.WHATSAPP_WELCOME_TEMPLATE_ID ?? 'lakshmee_client_added',
      languageCode: process.env.WHATSAPP_LANGUAGE_CODE ?? 'en',
      orderConfirmationTemplateId: process.env.WHATSAPP_ORDER_CONFIRMATION_TEMPLATE_ID ?? 'lakshmee_order_added',
      tripDispatchTemplateId: process.env.WHATSAPP_TRIP_DISPATCH_TEMPLATE_ID ?? 'lakshmee_trip_dispatch',
      tripDeliveryTemplateId: process.env.WHATSAPP_TRIP_DELIVERY_TEMPLATE_ID ?? 'lakshmee_trip_delivered',
    };
    if (useCache) {
      settingsCache.set(cacheKey, {
        settings,
        expiresAt: Date.now() + SETTINGS_CACHE_TTL_MS,
      });
    }
    return settings;
  }

  if (verbose) {
    console.log('[WhatsApp Service] No settings found (neither org-specific nor global)');
  }
  if (useCache) {
    settingsCache.set(cacheKey, {
      settings: null,
      expiresAt: Date.now() + SETTINGS_CACHE_TTL_MS,
    });
  }
  return null;
}

/**
 * Send WhatsApp message using Meta Graph API
 * 
 * @param url - Graph API endpoint URL
 * @param token - WhatsApp API token
 * @param to - Recipient phone number (E.164 format)
 * @param messageBody - Message text to send
 * @param messageType - Type of message for logging purposes
 * @param context - Context information for logging
 * @returns Promise that resolves when message is sent
 */
export async function sendWhatsappMessage(
  url: string,
  token: string,
  to: string,
  messageBody: string,
  messageType: string,
  context: { organizationId?: string; [key: string]: any },
): Promise<string | undefined> {
  const response = await fetch(url, {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${token}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      messaging_product: 'whatsapp',
      to: to,
      type: 'text',
      text: {
        body: messageBody,
      },
    }),
  });

  if (!response.ok) {
    const errorText = await response.text();
    throw new Error(`WhatsApp API error: ${response.status} ${response.statusText} - ${errorText}`);
  }

  const result = await response.json() as {
    messages?: Array<{ id?: string }>;
    errors?: Array<{ message?: string; code?: number }>;
  };

  if (result.errors && result.errors.length > 0) {
    const errorMessages = result.errors.map((e) => e.message || 'Unknown error').join(', ');
    throw new Error(`WhatsApp API returned errors: ${errorMessages}`);
  }

  const messageId = result.messages?.[0]?.id;

  console.log(`[WhatsApp Service] ${messageType} message sent`, {
    ...context,
    to: to.substring(0, 4) + '****',
    messageId,
  });

  return messageId;
}

export function normalizePhoneE164(raw: string | undefined): string | null {
  if (!raw) return null;
  const trimmed = raw.trim();
  if (!trimmed) return null;
  const normalized = trimmed.startsWith('+') ? trimmed : `+${trimmed}`;
  const digitsOnly = normalized.replace(/\D/g, '');
  if (digitsOnly.length < 8) return null;
  return normalized;
}

export function getWhatsappApiUrl(phoneId: string): string {
  const apiVersion = process.env.WHATSAPP_GRAPH_VERSION ?? 'v19.0';
  return `https://graph.facebook.com/${apiVersion}/${phoneId}/messages`;
}

/**
 * Check WhatsApp message delivery status using Meta Graph API
 * Note: The Cloud API primarily uses webhooks for status updates, but this can help verify if a message was accepted
 * 
 * @param messageId - The WhatsApp message ID (wamid.*) from the send response
 * @param phoneId - The WhatsApp Business Phone Number ID
 * @param token - WhatsApp API access token
 * @returns Promise with message status information
 */
export async function checkWhatsappMessageStatus(
  messageId: string,
  phoneId: string,
  token: string,
): Promise<{
  status?: string;
  errors?: Array<{ message?: string; code?: number }>;
  [key: string]: any;
}> {
  // Note: The Cloud API doesn't have a direct "get status" endpoint
  // Status updates are sent via webhooks. However, we can verify the message was accepted
  // by checking if messageId is valid format
  
  if (!messageId || !messageId.startsWith('wamid.')) {
    throw new Error(`Invalid message ID format: ${messageId}. Expected format: wamid.*`);
  }

  console.log('[WhatsApp Service] Checking message status', {
    messageId,
    phoneId,
    note: 'Status updates are primarily delivered via webhooks. See Meta Business Suite for real-time status.',
  });

  // Return basic validation - actual status should be checked via webhooks
  return {
    messageId,
    note: 'Message ID is valid. To check delivery status: 1) Use Meta Business Suite 2) Set up webhooks 3) Check webhook payloads',
  };
}
