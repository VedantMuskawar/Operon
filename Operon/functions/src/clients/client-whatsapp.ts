import * as functions from 'firebase-functions';
import { CLIENTS_COLLECTION } from '../shared/constants';
import { getFirestore } from '../shared/firestore-helpers';

const db = getFirestore();

interface WhatsappSettings {
  enabled: boolean;
  token: string;
  phoneId: string;
  welcomeTemplateId?: string;
  languageCode?: string;
  orderConfirmationTemplateId?: string;
  tripDispatchTemplateId?: string;
  tripDeliveryTemplateId?: string;
}

async function loadWhatsappSettings(
  organizationId: string | undefined,
): Promise<WhatsappSettings | null> {
  // First, try to load organization-specific settings
  if (organizationId) {
    // Trim whitespace from organizationId to handle document IDs with leading/trailing spaces
    const trimmedOrgId = organizationId.trim();
    const collectionName = 'WHATSAPP_SETTINGS';
    const orgSettingsRef = db.collection(collectionName).doc(trimmedOrgId);
    const docPath = `${collectionName}/${trimmedOrgId}`;

    console.log(
      '[WhatsApp] Attempting to load org settings',
      {
        organizationId,
        trimmedOrgId,
        docPath,
        collectionName,
      },
    );

    const orgSettingsDoc = await orgSettingsRef.get();

    console.log(
      '[WhatsApp] Document read result',
      {
        organizationId,
        trimmedOrgId,
        docPath,
        exists: orgSettingsDoc.exists,
        hasData: !!orgSettingsDoc.data(),
      },
    );

    if (orgSettingsDoc.exists) {
      const data = orgSettingsDoc.data();
      console.log(
        '[WhatsApp] Found org settings document',
        {
          organizationId,
          trimmedOrgId,
          docPath,
          enabled: data?.enabled,
          enabledType: typeof data?.enabled,
          hasToken: !!data?.token,
          hasPhoneId: !!data?.phoneId,
          dataKeys: data ? Object.keys(data) : [],
        },
      );

      if (data && data.enabled === true) {
        if (!data.token || !data.phoneId) {
          console.log(
            '[WhatsApp] Org settings missing token or phoneId',
            {
              organizationId,
              trimmedOrgId,
              hasToken: !!data.token,
              hasPhoneId: !!data.phoneId,
            },
          );
          return null;
        }
        return {
          enabled: true,
          token: data.token as string,
          phoneId: data.phoneId as string,
          welcomeTemplateId: data.welcomeTemplateId as string | undefined,
          languageCode: data.languageCode as string | undefined,
        };
      } else {
        // Org has settings but WhatsApp is disabled for them
        console.log(
          '[WhatsApp] Org settings exist but enabled is false or missing',
          {
            organizationId,
            trimmedOrgId,
            enabled: data?.enabled,
            enabledType: typeof data?.enabled,
          },
        );
        return null;
      }
    } else {
      // Try to list documents in the collection to debug
      try {
        const snapshot = await db.collection(collectionName).limit(5).get();
        const existingDocIds = snapshot.docs.map((doc) => doc.id);
        console.log(
          '[WhatsApp] No org settings document found',
          {
            organizationId,
            trimmedOrgId,
            collection: collectionName,
            docPath,
            lookingFor: trimmedOrgId,
            existingDocIds,
            docCount: snapshot.size,
          },
        );
      } catch (error) {
        console.error(
          '[WhatsApp] Error checking collection',
          { organizationId, trimmedOrgId, collection: collectionName, error },
        );
      }
    }
  }

  // Fallback to global config (for backward compatibility)
  const globalConfig: any = (functions.config() as any).whatsapp ?? {};
  if (
    globalConfig.token &&
    globalConfig.phone_id &&
    globalConfig.enabled !== 'false'
  ) {
    console.log('[WhatsApp] Using global config fallback');
    return {
      enabled: true,
      token: globalConfig.token,
      phoneId: globalConfig.phone_id,
      welcomeTemplateId: globalConfig.welcome_template_id,
      languageCode: globalConfig.language_code,
    };
  }

  console.log('[WhatsApp] No settings found (neither org-specific nor global)');
  return null;
}

async function sendWhatsappWelcomeMessage(
  to: string,
  clientName: string | undefined,
  organizationId: string | undefined,
  clientId: string,
): Promise<void> {
  const settings = await loadWhatsappSettings(organizationId);
  if (!settings) {
    console.log(
      '[WhatsApp] Skipping send – no settings or disabled.',
      { clientId, organizationId },
    );
    return;
  }

  const url = `https://graph.facebook.com/v19.0/${settings.phoneId}/messages`;
  const displayName = clientName && clientName.trim().length > 0
    ? clientName.trim()
    : 'there';

  // Mask token for logging (show first 10 chars only)
  const maskedToken = settings.token
    ? `${settings.token.substring(0, 10)}...${settings.token.substring(settings.token.length - 4)}`
    : 'missing';

  console.log('[WhatsApp] Sending welcome message', {
    organizationId,
    clientId,
    to: to.substring(0, 4) + '****', // Mask phone number
    phoneId: settings.phoneId,
    templateId: settings.welcomeTemplateId ?? 'client_welcome',
    tokenPreview: maskedToken,
  });

  const payload = {
    messaging_product: 'whatsapp',
    to: to,
    type: 'template',
    template: {
      name: settings.welcomeTemplateId ?? 'client_welcome',
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

    console.error(
      '[WhatsApp] Failed to send welcome message',
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
        console.error(
          '[WhatsApp] Phone Number ID issue:',
          'The Phone Number ID does not exist, lacks permissions, or belongs to a different WhatsApp Business Account.',
          'Verify in Meta Business Suite that:',
          '1. Phone Number ID matches the one in your settings',
          '2. Access token has permission for this Phone Number ID',
          '3. Both token and Phone Number ID belong to the same WhatsApp Business Account',
        );
      }
    }
  } else {
    const result = await response.json().catch(() => ({}));
    console.log('[WhatsApp] Welcome message sent successfully', {
      clientId,
      to: to.substring(0, 4) + '****',
      organizationId,
      messageId: result.messages?.[0]?.id,
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
      console.log(
        '[WhatsApp] No phone found on client, skipping welcome.',
        context.params.clientId,
      );
      return;
    }

    // Try to get organizationId from client document, or use default
    let organizationId = data.organizationId;
    if (!organizationId) {
      // Fallback: try to infer from global config or use a default org
      const globalConfig: any = (functions.config() as any).whatsapp ?? {};
      if (globalConfig.default_org_id) {
        organizationId = globalConfig.default_org_id;
        console.log(
          '[WhatsApp] Using default org from config',
          organizationId,
        );
      } else {
        console.log(
          '[WhatsApp] No organizationId on client and no default configured, skipping.',
          context.params.clientId,
        );
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

