import * as functions from 'firebase-functions';
import {
  PENDING_ORDERS_COLLECTION,
  CLIENTS_COLLECTION,
  WHATSAPP_SETTINGS_COLLECTION,
} from '../shared/constants';
import { getFirestore } from '../shared/firestore-helpers';

const db = getFirestore();

interface WhatsappSettings {
  enabled: boolean;
  token: string;
  phoneId: string;
  welcomeTemplateId?: string;
  languageCode?: string;
  orderConfirmationTemplateId?: string;
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
    };
  }

  return null;
}

/**
 * Sends WhatsApp notification to client when an order is created
 */
async function sendOrderConfirmationMessage(
  to: string,
  clientName: string | undefined,
  organizationId: string | undefined,
  orderId: string,
  orderData: {
    orderNumber?: string;
    items: Array<{
      productName: string;
      totalQuantity: number;
      estimatedTrips: number;
      total: number;
    }>;
    pricing: {
      subtotal: number;
      totalGst: number;
      totalAmount: number;
      currency: string;
    };
    deliveryZone?: {
      city_name: string;
      region: string;
    };
    advanceAmount?: number;
  },
): Promise<void> {
  const settings = await loadWhatsappSettings(organizationId);
  if (!settings) {
    console.log(
      '[WhatsApp Order] Skipping send – no settings or disabled.',
      { orderId, organizationId },
    );
    return;
  }

  const url = `https://graph.facebook.com/v19.0/${settings.phoneId}/messages`;
  const displayName = clientName && clientName.trim().length > 0
    ? clientName.trim()
    : 'there';

  // Format order items for message
  const itemsText = orderData.items
    .map((item, index) => {
      const itemNum = index + 1;
      return `${itemNum}. ${item.productName}\n   Qty: ${item.totalQuantity} units (${item.estimatedTrips} trips)\n   Amount: ₹${item.total.toFixed(2)}`;
    })
    .join('\n\n');

  // Format delivery zone
  const deliveryInfo = orderData.deliveryZone
    ? `${orderData.deliveryZone.city_name}, ${orderData.deliveryZone.region}`
    : 'To be confirmed';

  // Format pricing summary
  const pricingText = `Subtotal: ₹${orderData.pricing.subtotal.toFixed(2)}\n` +
    (orderData.pricing.totalGst > 0
      ? `GST: ₹${orderData.pricing.totalGst.toFixed(2)}\n`
      : '') +
    `Total: ₹${orderData.pricing.totalAmount.toFixed(2)}`;

  // Format advance payment info if applicable
  const advanceText = orderData.advanceAmount && orderData.advanceAmount > 0
    ? `\n\nAdvance Paid: ₹${orderData.advanceAmount.toFixed(2)}\nRemaining: ₹${(orderData.pricing.totalAmount - orderData.advanceAmount).toFixed(2)}`
    : '';

  // Build message body
  const messageBody = `Hello ${displayName}!\n\n` +
    `Your order has been placed successfully!\n\n` +
    `Items:\n${itemsText}\n\n` +
    `Delivery: ${deliveryInfo}\n\n` +
    `Pricing:\n${pricingText}${advanceText}\n\n` +
    `Thank you for your order!`;

  console.log('[WhatsApp Order] Sending order confirmation', {
    organizationId,
    orderId,
    to: to.substring(0, 4) + '****', // Mask phone number
    phoneId: settings.phoneId,
    hasItems: orderData.items.length > 0,
  });

  await sendWhatsappMessage(url, settings.token, to, messageBody, 'confirmation', {
    organizationId,
    orderId,
  });
}

/**
 * Sends WhatsApp notification to client when an order is updated
 */
async function sendOrderUpdateMessage(
  to: string,
  clientName: string | undefined,
  organizationId: string | undefined,
  orderId: string,
  orderData: {
    orderNumber?: string;
    items: Array<{
      productName: string;
      totalQuantity: number;
      estimatedTrips: number;
      total: number;
    }>;
    pricing: {
      subtotal: number;
      totalGst: number;
      totalAmount: number;
      currency: string;
    };
    deliveryZone?: {
      city_name: string;
      region: string;
    };
    advanceAmount?: number;
    status?: string;
  },
): Promise<void> {
  const settings = await loadWhatsappSettings(organizationId);
  if (!settings) {
    console.log(
      '[WhatsApp Order] Skipping send – no settings or disabled.',
      { orderId, organizationId },
    );
    return;
  }

  const url = `https://graph.facebook.com/v19.0/${settings.phoneId}/messages`;
  const displayName = clientName && clientName.trim().length > 0
    ? clientName.trim()
    : 'there';

  // Format order items for message
  const itemsText = orderData.items
    .map((item, index) => {
      const itemNum = index + 1;
      return `${itemNum}. ${item.productName}\n   Qty: ${item.totalQuantity} units (${item.estimatedTrips} trips)\n   Amount: ₹${item.total.toFixed(2)}`;
    })
    .join('\n\n');

  // Format delivery zone
  const deliveryInfo = orderData.deliveryZone
    ? `${orderData.deliveryZone.city_name}, ${orderData.deliveryZone.region}`
    : 'To be confirmed';

  // Format pricing summary
  const pricingText = `Subtotal: ₹${orderData.pricing.subtotal.toFixed(2)}\n` +
    (orderData.pricing.totalGst > 0
      ? `GST: ₹${orderData.pricing.totalGst.toFixed(2)}\n`
      : '') +
    `Total: ₹${orderData.pricing.totalAmount.toFixed(2)}`;

  // Format advance payment info if applicable
  const advanceText = orderData.advanceAmount && orderData.advanceAmount > 0
    ? `\n\nAdvance Paid: ₹${orderData.advanceAmount.toFixed(2)}\nRemaining: ₹${(orderData.pricing.totalAmount - orderData.advanceAmount).toFixed(2)}`
    : '';

  // Format status if available
  const statusText = orderData.status && orderData.status !== 'pending'
    ? `\n\nStatus: ${orderData.status.charAt(0).toUpperCase() + orderData.status.slice(1)}`
    : '';

  // Build message body
  const messageBody = `Hello ${displayName}!\n\n` +
    `Your order has been updated!\n\n` +
    `Items:\n${itemsText}\n\n` +
    `Delivery: ${deliveryInfo}\n\n` +
    `Pricing:\n${pricingText}${advanceText}${statusText}\n\n` +
    `Thank you!`;

  console.log('[WhatsApp Order] Sending order update', {
    organizationId,
    orderId,
    to: to.substring(0, 4) + '****', // Mask phone number
    phoneId: settings.phoneId,
    hasItems: orderData.items.length > 0,
    status: orderData.status,
  });

  await sendWhatsappMessage(url, settings.token, to, messageBody, 'update', {
    organizationId,
    orderId,
  });
}

async function sendWhatsappMessage(
  url: string,
  token: string,
  to: string,
  messageBody: string,
  messageType: 'confirmation' | 'update',
  context: { organizationId?: string; orderId: string },
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
      `[WhatsApp Order] Failed to send order ${messageType}`,
      {
        status: response.status,
        statusText: response.statusText,
        error: errorDetails,
        organizationId: context.organizationId,
        orderId: context.orderId,
        url,
      },
    );
  } else {
    const result = await response.json().catch(() => ({}));
    console.log(`[WhatsApp Order] Order ${messageType} sent successfully`, {
      orderId: context.orderId,
      to: to.substring(0, 4) + '****',
      organizationId: context.organizationId,
      messageId: result.messages?.[0]?.id,
    });
  }
}

/**
 * Cloud Function: Triggered when an order is created
 * Sends WhatsApp notification to client with order details
 */
export const onOrderCreatedSendWhatsapp = functions.firestore
  .document(`${PENDING_ORDERS_COLLECTION}/{orderId}`)
  .onCreate(async (snapshot, context) => {
    const orderId = context.params.orderId;
    const orderData = snapshot.data() as {
      clientId?: string;
      clientName?: string;
      clientPhone?: string;
      organizationId?: string;
      orderNumber?: string;
      items?: Array<{
        productName: string;
        totalQuantity: number;
        estimatedTrips: number;
        total: number;
      }>;
      pricing?: {
        subtotal: number;
        totalGst: number;
        totalAmount: number;
        currency: string;
      };
      deliveryZone?: {
        city_name: string;
        region: string;
      };
      advanceAmount?: number;
    };

    if (!orderData) {
      console.log('[WhatsApp Order] No order data found', { orderId });
      return;
    }

    // Get client phone number
    let clientPhone = orderData.clientPhone;
    let clientName = orderData.clientName;

    // If phone not in order, fetch from client document
    if (!clientPhone && orderData.clientId) {
      try {
        const clientDoc = await db
          .collection(CLIENTS_COLLECTION)
          .doc(orderData.clientId)
          .get();

        if (clientDoc.exists) {
          const clientData = clientDoc.data();
          clientPhone = clientData?.primaryPhoneNormalized || clientData?.primaryPhone;
          if (!clientName) {
            clientName = clientData?.name;
          }
        }
      } catch (error) {
        console.error('[WhatsApp Order] Error fetching client data', {
          orderId,
          clientId: orderData.clientId,
          error,
        });
      }
    }

    if (!clientPhone) {
      console.log(
        '[WhatsApp Order] No phone found for order, skipping notification.',
        { orderId, clientId: orderData.clientId },
      );
      return;
    }

    // Validate required order data
    if (!orderData.items || !orderData.pricing) {
      console.log('[WhatsApp Order] Missing required order data', {
        orderId,
        hasItems: !!orderData.items,
        hasPricing: !!orderData.pricing,
      });
      return;
    }

    await sendOrderConfirmationMessage(
      clientPhone,
      clientName,
      orderData.organizationId,
      orderId,
      {
        orderNumber: orderData.orderNumber,
        items: orderData.items,
        pricing: orderData.pricing,
        deliveryZone: orderData.deliveryZone,
        advanceAmount: orderData.advanceAmount,
      },
    );
  });

/**
 * Cloud Function: Triggered when an order is updated
 * Sends WhatsApp notification to client with updated order details
 * Only sends for significant changes (items, pricing, status, delivery zone)
 */
export const onOrderUpdatedSendWhatsapp = functions.firestore
  .document(`${PENDING_ORDERS_COLLECTION}/{orderId}`)
  .onUpdate(async (change, context) => {
    const orderId = context.params.orderId;
    const before = change.before.data();
    const after = change.after.data();

    // Check if significant fields changed
    const itemsChanged = JSON.stringify(before.items) !== JSON.stringify(after.items);
    const pricingChanged = JSON.stringify(before.pricing) !== JSON.stringify(after.pricing);
    const statusChanged = before.status !== after.status;
    const deliveryZoneChanged = JSON.stringify(before.deliveryZone) !== JSON.stringify(after.deliveryZone);
    const advanceAmountChanged = before.advanceAmount !== after.advanceAmount;

    // Only send notification if significant changes occurred
    if (!itemsChanged && !pricingChanged && !statusChanged && !deliveryZoneChanged && !advanceAmountChanged) {
      console.log('[WhatsApp Order] No significant changes detected, skipping update notification', {
        orderId,
      });
      return;
    }

    const orderData = after as {
      clientId?: string;
      clientName?: string;
      clientPhone?: string;
      organizationId?: string;
      orderNumber?: string;
      items?: Array<{
        productName: string;
        totalQuantity: number;
        estimatedTrips: number;
        total: number;
      }>;
      pricing?: {
        subtotal: number;
        totalGst: number;
        totalAmount: number;
        currency: string;
      };
      deliveryZone?: {
        city_name: string;
        region: string;
      };
      advanceAmount?: number;
      status?: string;
    };

    if (!orderData) {
      console.log('[WhatsApp Order] No order data found', { orderId });
      return;
    }

    // Get client phone number
    let clientPhone = orderData.clientPhone;
    let clientName = orderData.clientName;

    // If phone not in order, fetch from client document
    if (!clientPhone && orderData.clientId) {
      try {
        const clientDoc = await db
          .collection(CLIENTS_COLLECTION)
          .doc(orderData.clientId)
          .get();

        if (clientDoc.exists) {
          const clientData = clientDoc.data();
          clientPhone = clientData?.primaryPhoneNormalized || clientData?.primaryPhone;
          if (!clientName) {
            clientName = clientData?.name;
          }
        }
      } catch (error) {
        console.error('[WhatsApp Order] Error fetching client data', {
          orderId,
          clientId: orderData.clientId,
          error,
        });
      }
    }

    if (!clientPhone) {
      console.log(
        '[WhatsApp Order] No phone found for order, skipping notification.',
        { orderId, clientId: orderData.clientId },
      );
      return;
    }

    // Validate required order data
    if (!orderData.items || !orderData.pricing) {
      console.log('[WhatsApp Order] Missing required order data', {
        orderId,
        hasItems: !!orderData.items,
        hasPricing: !!orderData.pricing,
      });
      return;
    }

    await sendOrderUpdateMessage(
      clientPhone,
      clientName,
      orderData.organizationId,
      orderId,
      {
        orderNumber: orderData.orderNumber,
        items: orderData.items,
        pricing: orderData.pricing,
        deliveryZone: orderData.deliveryZone,
        advanceAmount: orderData.advanceAmount,
        status: orderData.status,
      },
    );
  });

