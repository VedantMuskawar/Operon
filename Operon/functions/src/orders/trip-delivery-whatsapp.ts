import * as functions from 'firebase-functions';
import {
  CLIENTS_COLLECTION,
  WHATSAPP_SETTINGS_COLLECTION,
} from '../shared/constants';
import { getFirestore } from '../shared/firestore-helpers';

const db = getFirestore();
const SCHEDULED_TRIPS_COLLECTION = 'SCHEDULE_TRIPS';

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
    const trimmedOrgId = organizationId.trim();
    const orgSettingsRef = db.collection(WHATSAPP_SETTINGS_COLLECTION).doc(trimmedOrgId);
    const orgSettingsDoc = await orgSettingsRef.get();

    if (orgSettingsDoc.exists) {
      const data = orgSettingsDoc.data();
      if (data && data.enabled === true) {
        if (!data.token || !data.phoneId) {
          return null;
        }
        return {
          enabled: true,
          token: data.token as string,
          phoneId: data.phoneId as string,
          welcomeTemplateId: data.welcomeTemplateId as string | undefined,
          languageCode: data.languageCode as string | undefined,
          orderConfirmationTemplateId: data.orderConfirmationTemplateId as string | undefined,
          tripDispatchTemplateId: data.tripDispatchTemplateId as string | undefined,
          tripDeliveryTemplateId: data.tripDeliveryTemplateId as string | undefined,
        };
      }
      return null;
    }
  }

  // Fallback to global config
  const globalConfig: any = (functions.config() as any).whatsapp ?? {};
  if (
    globalConfig.token &&
    globalConfig.phone_id &&
    globalConfig.enabled !== 'false'
  ) {
    return {
      enabled: true,
      token: globalConfig.token,
      phoneId: globalConfig.phone_id,
      welcomeTemplateId: globalConfig.welcome_template_id,
      languageCode: globalConfig.language_code,
      orderConfirmationTemplateId: globalConfig.order_confirmation_template_id,
      tripDispatchTemplateId: globalConfig.trip_dispatch_template_id,
      tripDeliveryTemplateId: globalConfig.trip_delivery_template_id,
    };
  }

  return null;
}

/**
 * Sends WhatsApp notification to client when a trip is delivered
 */
async function sendTripDeliveryMessage(
  to: string,
  clientName: string | undefined,
  organizationId: string | undefined,
  tripId: string,
  tripData: {
    clientName?: string;
    items?: Array<{
      productName: string;
      fixedQuantityPerTrip: number;
      unitPrice: number;
      gstAmount?: number;
    }>;
    tripPricing?: {
      subtotal: number;
      gstAmount: number;
      total: number;
    };
    scheduledDate?: any;
    deliveredAt?: any;
  },
): Promise<void> {
  const settings = await loadWhatsappSettings(organizationId);
  if (!settings) {
    console.log(
      '[WhatsApp Trip Delivery] Skipping send – no settings or disabled.',
      { tripId, organizationId },
    );
    return;
  }

  const url = `https://graph.facebook.com/v19.0/${settings.phoneId}/messages`;
  const displayName = clientName && clientName.trim().length > 0
    ? clientName.trim()
    : 'there';

  // Format trip items for message
  const itemsText = tripData.items && tripData.items.length > 0
    ? tripData.items
        .map((item, index) => {
          const itemNum = index + 1;
          return `${itemNum}. ${item.productName} - ${item.fixedQuantityPerTrip} units`;
        })
        .join('\n')
    : 'No items';

  // Format trip date
  let scheduledDateText = 'N/A';
  if (tripData.scheduledDate) {
    try {
      const date = tripData.scheduledDate.toDate
        ? tripData.scheduledDate.toDate()
        : new Date(tripData.scheduledDate);
      scheduledDateText = date.toLocaleDateString('en-IN', {
        day: '2-digit',
        month: 'short',
        year: 'numeric',
      });
    } catch (e) {
      console.error('[WhatsApp Trip Delivery] Error formatting date', e);
    }
  }

  // Build message body
  const confirmationMessage = 'Delivery completed successfully. We hope you\'re satisfied with your order!';
  const nextStepsMessage = 'If you have any feedback or need assistance, please let us know. We appreciate your business!';

  const messageBody = `Hello ${displayName}!\n\n` +
    `Your delivery has been completed!\n\n` +
    `Trip Date: ${scheduledDateText}\n\n` +
    `Items Delivered:\n${itemsText}\n\n` +
    `${confirmationMessage}\n\n` +
    `${nextStepsMessage}\n\n` +
    `Thank you for choosing us!`;

  console.log('[WhatsApp Trip Delivery] Sending delivery notification', {
    organizationId,
    tripId,
    to: to.substring(0, 4) + '****', // Mask phone number
    phoneId: settings.phoneId,
    hasItems: tripData.items && tripData.items.length > 0,
  });

  await sendWhatsappMessage(url, settings.token, to, messageBody, {
    organizationId,
    tripId,
  });
}

async function sendWhatsappMessage(
  url: string,
  token: string,
  to: string,
  messageBody: string,
  context: { organizationId?: string; tripId: string },
): Promise<void> {
  const payload = {
    messaging_product: 'whatsapp',
    to: to,
    type: 'text',
    text: {
      body: messageBody,
    },
  };

  const response = await fetch(url, {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${token}`,
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
      '[WhatsApp Trip Delivery] Failed to send delivery notification',
      {
        status: response.status,
        statusText: response.statusText,
        error: errorDetails,
        organizationId: context.organizationId,
        tripId: context.tripId,
        url,
      },
    );
  } else {
    const result = await response.json().catch(() => ({}));
    console.log('[WhatsApp Trip Delivery] Delivery notification sent successfully', {
      tripId: context.tripId,
      to: to.substring(0, 4) + '****',
      organizationId: context.organizationId,
      messageId: result.messages?.[0]?.id,
    });
  }
}

/**
 * Cloud Function: Triggered when a trip status is updated to 'delivered'
 * Sends WhatsApp notification to client with delivery confirmation
 */
export const onTripDeliveredSendWhatsapp = functions.firestore
  .document(`${SCHEDULED_TRIPS_COLLECTION}/{tripId}`)
  .onUpdate(async (change, context) => {
    const tripId = context.params.tripId;
    const before = change.before.data();
    const after = change.after.data();

    // Only proceed if trip status changed to 'delivered'
    const beforeStatus = before.tripStatus as string | undefined;
    const afterStatus = after.tripStatus as string | undefined;

    if (beforeStatus === afterStatus || afterStatus !== 'delivered') {
      console.log('[WhatsApp Trip Delivery] Trip status not changed to delivered, skipping', {
        tripId,
        beforeStatus,
        afterStatus,
      });
      return;
    }

    const tripData = after as {
      clientId?: string;
      clientName?: string;
      customerNumber?: string;
      clientPhone?: string;
      organizationId?: string;
      items?: Array<{
        productName: string;
        fixedQuantityPerTrip: number;
        unitPrice: number;
        gstAmount?: number;
      }>;
      tripPricing?: {
        subtotal: number;
        gstAmount: number;
        total: number;
      };
      scheduledDate?: any;
      deliveredAt?: any;
    };

    if (!tripData) {
      console.log('[WhatsApp Trip Delivery] No trip data found', { tripId });
      return;
    }

    // Get client phone number
    let clientPhone = tripData.customerNumber || tripData.clientPhone;
    let clientName = tripData.clientName;

    // If phone not in trip, fetch from client document
    if (!clientPhone && tripData.clientId) {
      try {
        const clientDoc = await db
          .collection(CLIENTS_COLLECTION)
          .doc(tripData.clientId)
          .get();

        if (clientDoc.exists) {
          const clientData = clientDoc.data();
          clientPhone = clientData?.primaryPhoneNormalized || clientData?.primaryPhone;
          if (!clientName) {
            clientName = clientData?.name;
          }
        }
      } catch (error) {
        console.error('[WhatsApp Trip Delivery] Error fetching client data', {
          tripId,
          clientId: tripData.clientId,
          error,
        });
      }
    }

    if (!clientPhone) {
      console.log(
        '[WhatsApp Trip Delivery] No phone found for trip, skipping notification.',
        { tripId, clientId: tripData.clientId },
      );
      return;
    }

    await sendTripDeliveryMessage(
      clientPhone,
      clientName,
      tripData.organizationId,
      tripId,
      tripData,
    );
  });
