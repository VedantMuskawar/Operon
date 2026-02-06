import { onDocumentCreated, onDocumentUpdated } from 'firebase-functions/v2/firestore';
import {
  PENDING_ORDERS_COLLECTION,
  CLIENTS_COLLECTION,
} from '../shared/constants';
import { getFirestore } from '../shared/firestore-helpers';
import { logInfo, logError } from '../shared/logger';
import { LIGHT_TRIGGER_OPTS } from '../shared/function-config';
import type { WhatsappSettings } from '../shared/whatsapp-service';

const db = getFirestore();

type WhatsappModule = {
  loadWhatsappSettings: (orgId: string | undefined, verbose?: boolean) => Promise<WhatsappSettings | null>;
  sendWhatsappTemplateMessage: (url: string, token: string, to: string, templateName: string, languageCode: string, parameters: string[], messageType: string, context: any) => Promise<void>;
  sendWhatsappMessage: (url: string, token: string, to: string, messageBody: string, messageType: string, context: any) => Promise<void>;
};

/**
 * Sends WhatsApp notification to client when an order is created
 */
async function sendOrderConfirmationMessage(
  whatsapp: WhatsappModule,
  to: string,
  clientName: string | undefined,
  organizationId: string | undefined,
  orderId: string,
  orderData: {
    orderNumber?: string;
    items: Array<{
      productName: string;
      totalQuantity?: number;
      estimatedTrips?: number;
      fixedQuantityPerTrip?: number;
      total?: number;
    }>;
    pricing: {
      subtotal: number;
      totalGst?: number;
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
  const settings = await whatsapp.loadWhatsappSettings(organizationId, true);
  if (!settings?.orderConfirmationTemplateId) {
    logInfo('Order/WhatsApp', 'sendOrderConfirmationMessage', 'Skipping – no WhatsApp settings or orderConfirmationTemplateId for org', {
      orderId,
      organizationId: organizationId ?? 'missing',
    });
    return;
  }

  const url = `https://graph.facebook.com/v19.0/${settings.phoneId}/messages`;
  const displayName = clientName && clientName.trim().length > 0
    ? clientName.trim()
    : 'there';

  // Format order items for template parameter 2
  const itemsText = orderData.items
    .map((item, index) => {
      const itemNum = index + 1;
      // Calculate totalQuantity if not present: estimatedTrips × fixedQuantityPerTrip
      const estimatedTrips = item.estimatedTrips ?? 0;
      const fixedQtyPerTrip = item.fixedQuantityPerTrip ?? 1;
      const totalQuantity = item.totalQuantity ?? (estimatedTrips * fixedQtyPerTrip);
      const total = item.total ?? 0;
      
      return `${itemNum}. ${item.productName} - Qty: ${totalQuantity} units (${estimatedTrips} trips) - ₹${total.toFixed(2)}`;
    })
    .join('\n');

  // Format delivery zone for parameter 3
  const deliveryInfo = orderData.deliveryZone
    ? `${orderData.deliveryZone.city_name}, ${orderData.deliveryZone.region}`
    : 'To be confirmed';

  // Format total amount for parameter 4
  const totalGst = orderData.pricing.totalGst ?? 0;
  const totalAmountText = totalGst > 0
    ? `₹${orderData.pricing.totalAmount.toFixed(2)} (Subtotal: ₹${orderData.pricing.subtotal.toFixed(2)}, GST: ₹${totalGst.toFixed(2)})`
    : `₹${orderData.pricing.totalAmount.toFixed(2)} (Subtotal: ₹${orderData.pricing.subtotal.toFixed(2)})`;

  // Format advance payment info for parameter 5
  // WhatsApp rejects empty template parameters – use placeholder when no advance
  const advanceText = orderData.advanceAmount && orderData.advanceAmount > 0
    ? `Advance Paid: ₹${orderData.advanceAmount.toFixed(2)} | Remaining: ₹${(orderData.pricing.totalAmount - orderData.advanceAmount).toFixed(2)}`
    : '—';

  // Prepare template parameters
  const parameters = [
    displayName,        // Parameter 1: Client name
    itemsText,          // Parameter 2: Order items list
    deliveryInfo,       // Parameter 3: Delivery zone
    totalAmountText,    // Parameter 4: Total amount with breakdown
    advanceText,        // Parameter 5: Advance payment info (never empty)
  ];

  logInfo('Order/WhatsApp', 'sendOrderConfirmationMessage', 'Sending order confirmation', {
    organizationId,
    orderId,
    to: to.substring(0, 4) + '****',
    phoneId: settings.phoneId,
    templateId: settings.orderConfirmationTemplateId,
    hasItems: orderData.items.length > 0,
  });

  await whatsapp.sendWhatsappTemplateMessage(
    url,
    settings.token,
    to,
    settings.orderConfirmationTemplateId!,
    settings.languageCode ?? 'en',
    parameters,
    'order-confirmation',
    {
      organizationId,
      orderId,
    },
  );
}

/**
 * Sends WhatsApp notification to client when an order is updated
 */
async function sendOrderUpdateMessage(
  whatsapp: WhatsappModule,
  to: string,
  clientName: string | undefined,
  organizationId: string | undefined,
  orderId: string,
  orderData: {
    orderNumber?: string;
    items: Array<{
      productName: string;
      totalQuantity?: number;
      estimatedTrips?: number;
      fixedQuantityPerTrip?: number;
      total?: number;
    }>;
    pricing: {
      subtotal: number;
      totalGst?: number;
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
  const settings = await whatsapp.loadWhatsappSettings(organizationId);
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
      // Calculate totalQuantity if not present: estimatedTrips × fixedQuantityPerTrip
      const estimatedTrips = item.estimatedTrips ?? 0;
      const fixedQtyPerTrip = item.fixedQuantityPerTrip ?? 1;
      const totalQuantity = item.totalQuantity ?? (estimatedTrips * fixedQtyPerTrip);
      const total = item.total ?? 0;
      
      return `${itemNum}. ${item.productName}\n   Qty: ${totalQuantity} units (${estimatedTrips} trips)\n   Amount: ₹${total.toFixed(2)}`;
    })
    .join('\n\n');

  // Format delivery zone
  const deliveryInfo = orderData.deliveryZone
    ? `${orderData.deliveryZone.city_name}, ${orderData.deliveryZone.region}`
    : 'To be confirmed';

  // Format pricing summary
  const totalGst = orderData.pricing.totalGst ?? 0;
  const pricingText = `Subtotal: ₹${orderData.pricing.subtotal.toFixed(2)}\n` +
    (totalGst > 0 ? `GST: ₹${totalGst.toFixed(2)}\n` : '') +
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

  logInfo('Order/WhatsApp', 'sendOrderUpdateMessage', 'Sending order update', {
    organizationId,
    orderId,
    to: to.substring(0, 4) + '****',
    phoneId: settings.phoneId,
    hasItems: orderData.items.length > 0,
    status: orderData.status,
  });

  await whatsapp.sendWhatsappMessage(url, settings.token, to, messageBody, 'update', {
    organizationId,
    orderId,
  });
}

/**
 * Cloud Function: Triggered when an order is created
 * Sends WhatsApp notification to client with order details
 */
export const onOrderCreatedSendWhatsapp = onDocumentCreated(
  {
    document: `${PENDING_ORDERS_COLLECTION}/{orderId}`,
    ...LIGHT_TRIGGER_OPTS,
  },
  async (event) => {
    const snapshot = event.data;
    if (!snapshot) return;
    const orderId = event.params.orderId;
    const orderData = snapshot.data() as {
      clientId?: string;
      clientName?: string;
      clientPhone?: string;
      organizationId?: string;
      orderNumber?: string;
      items?: Array<{
        productName: string;
        totalQuantity?: number;
        estimatedTrips?: number;
        fixedQuantityPerTrip?: number;
        total?: number;
      }>;
      pricing?: {
        subtotal: number;
        totalGst?: number;
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
      logInfo('Order/WhatsApp', 'onOrderCreatedSendWhatsapp', 'No order data in snapshot, skipping', { orderId });
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
        logError('Order/WhatsApp', 'onOrderCreatedSendWhatsapp', 'Error fetching client data', error instanceof Error ? error : undefined, {
          orderId,
          clientId: orderData.clientId,
        });
      }
    }

    if (!clientPhone) {
      logInfo('Order/WhatsApp', 'onOrderCreatedSendWhatsapp', 'No client phone for order, skipping WhatsApp', {
        orderId,
        clientId: orderData.clientId,
        hadClientPhoneOnOrder: !!orderData.clientPhone,
      });
      return;
    }

    // Validate required order data
    if (!orderData.items || !orderData.pricing) {
      logInfo('Order/WhatsApp', 'onOrderCreatedSendWhatsapp', 'Missing items or pricing, skipping WhatsApp', {
        orderId,
        hasItems: !!orderData.items,
        hasPricing: !!orderData.pricing,
      });
      return;
    }

    const whatsapp = await import('../shared/whatsapp-service');
    try {
      await sendOrderConfirmationMessage(
        whatsapp,
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
    } catch (err) {
      logError('Order/WhatsApp', 'onOrderCreatedSendWhatsapp', 'Failed to send order confirmation WhatsApp', err instanceof Error ? err : undefined, {
        orderId,
        organizationId: orderData.organizationId,
        clientId: orderData.clientId,
      });
      throw err;
    }
  },
);

/**
 * Cloud Function: Triggered when an order is updated
 * Sends WhatsApp notification to client with updated order details
 * Only sends for significant changes (items, pricing, status, delivery zone)
 */
export const onOrderUpdatedSendWhatsapp = onDocumentUpdated(
  {
    document: `${PENDING_ORDERS_COLLECTION}/{orderId}`,
    ...LIGHT_TRIGGER_OPTS,
  },
  async (event) => {
    const orderId = event.params.orderId;
    const before = event.data?.before.data();
    const after = event.data?.after.data();
    if (!before || !after) return;

    // Check if significant fields changed
    const itemsChanged = JSON.stringify(before.items) !== JSON.stringify(after.items);
    const pricingChanged = JSON.stringify(before.pricing) !== JSON.stringify(after.pricing);
    const statusChanged = before.status !== after.status;
    const deliveryZoneChanged = JSON.stringify(before.deliveryZone) !== JSON.stringify(after.deliveryZone);
    const advanceAmountChanged = before.advanceAmount !== after.advanceAmount;

    // Only send notification if significant changes occurred
    if (!itemsChanged && !pricingChanged && !statusChanged && !deliveryZoneChanged && !advanceAmountChanged) {
      logInfo('Order/WhatsApp', 'onOrderUpdatedSendWhatsapp', 'No significant changes detected, skipping update notification', {
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
        totalGst?: number;
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
      logInfo('Order/WhatsApp', 'onOrderUpdatedSendWhatsapp', 'No order data in snapshot, skipping', { orderId });
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
        logError('Order/WhatsApp', 'onOrderUpdatedSendWhatsapp', 'Error fetching client data', error instanceof Error ? error : undefined, {
          orderId,
          clientId: orderData.clientId,
        });
      }
    }

    if (!clientPhone) {
      logInfo('Order/WhatsApp', 'onOrderUpdatedSendWhatsapp', 'No client phone, skipping update notification', {
        orderId,
        clientId: orderData.clientId,
      });
      return;
    }

    // Validate required order data
    if (!orderData.items || !orderData.pricing) {
      logInfo('Order/WhatsApp', 'onOrderUpdatedSendWhatsapp', 'Missing items or pricing, skipping', {
        orderId,
        hasItems: !!orderData.items,
        hasPricing: !!orderData.pricing,
      });
      return;
    }

    const whatsapp = await import('../shared/whatsapp-service');
    await sendOrderUpdateMessage(
      whatsapp,
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
  },
);

