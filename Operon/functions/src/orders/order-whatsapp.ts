import { onDocumentCreated, onDocumentUpdated } from 'firebase-functions/v2/firestore';
import {
  PENDING_ORDERS_COLLECTION,
  CLIENTS_COLLECTION,
} from '../shared/constants';
import { getFirestore } from '../shared/firestore-helpers';
import { logInfo, logError } from '../shared/logger';
import { LIGHT_TRIGGER_OPTS } from '../shared/function-config';
import { enqueueWhatsappMessage } from '../whatsapp/whatsapp-message-queue';

const db = getFirestore();
const MAX_ORDER_ITEMS = 10;
const MAX_ITEM_NAME_CHARS = 60;
const MAX_ITEMS_TEXT_CHARS = 900;

function buildJobId(eventId: string | undefined, fallbackParts: Array<string | undefined>): string {
  if (eventId) return eventId;
  return fallbackParts.filter(Boolean).join('-');
}

function truncateText(value: string, maxChars: number): string {
  if (value.length <= maxChars) return value;
  const suffix = '...';
  const trimmedLength = Math.max(0, maxChars - suffix.length);
  return `${value.slice(0, trimmedLength)}${suffix}`;
}

function formatOrderItems(
  items: Array<{
    productName: string;
    totalQuantity?: number;
    estimatedTrips?: number;
    fixedQuantityPerTrip?: number;
    total?: number;
  }>,
  multiline: boolean,
): string {
  if (!items || items.length === 0) return 'No items';

  const lines: string[] = [];
  const itemCount = Math.min(items.length, MAX_ORDER_ITEMS);

  for (let index = 0; index < itemCount; index += 1) {
    const item = items[index];
    const itemNum = index + 1;
    const estimatedTrips = item.estimatedTrips ?? 0;
    const fixedQtyPerTrip = item.fixedQuantityPerTrip ?? 1;
    const totalQuantity = item.totalQuantity ?? (estimatedTrips * fixedQtyPerTrip);
    const total = item.total ?? 0;
    const productName = truncateText(item.productName, MAX_ITEM_NAME_CHARS);

    if (multiline) {
      lines.push(
        `${itemNum}. ${productName}\n   Qty: ${totalQuantity} units (${estimatedTrips} trips)\n   Amount: ₹${total.toFixed(2)}`,
      );
    } else {
      lines.push(
        `${itemNum}. ${productName} - Qty: ${totalQuantity} units (${estimatedTrips} trips) - ₹${total.toFixed(2)}`,
      );
    }
  }

  if (items.length > MAX_ORDER_ITEMS) {
    lines.push(`...and ${items.length - MAX_ORDER_ITEMS} more items`);
  }

  const joined = lines.join(multiline ? '\n\n' : '\n');
  return truncateText(joined, MAX_ITEMS_TEXT_CHARS);
}

function didItemsChange(
  beforeItems?: Array<{
    productName: string;
    totalQuantity?: number;
    estimatedTrips?: number;
    fixedQuantityPerTrip?: number;
    total?: number;
  }>,
  afterItems?: Array<{
    productName: string;
    totalQuantity?: number;
    estimatedTrips?: number;
    fixedQuantityPerTrip?: number;
    total?: number;
  }>,
): boolean {
  if (!beforeItems && !afterItems) return false;
  if (!beforeItems || !afterItems) return true;
  if (beforeItems.length !== afterItems.length) return true;

  for (let i = 0; i < beforeItems.length; i += 1) {
    const before = beforeItems[i];
    const after = afterItems[i];
    const beforeTrips = before.estimatedTrips ?? 0;
    const afterTrips = after.estimatedTrips ?? 0;
    const beforeFixed = before.fixedQuantityPerTrip ?? 1;
    const afterFixed = after.fixedQuantityPerTrip ?? 1;
    const beforeTotalQty = before.totalQuantity ?? (beforeTrips * beforeFixed);
    const afterTotalQty = after.totalQuantity ?? (afterTrips * afterFixed);

    if ((before.productName || '') !== (after.productName || '')) return true;
    if (beforeTrips !== afterTrips) return true;
    if (beforeFixed !== afterFixed) return true;
    if (beforeTotalQty !== afterTotalQty) return true;
    if ((before.total ?? 0) !== (after.total ?? 0)) return true;
  }

  return false;
}

function didPricingChange(
  before?: { subtotal: number; totalGst?: number; totalAmount: number; currency: string },
  after?: { subtotal: number; totalGst?: number; totalAmount: number; currency: string },
): boolean {
  if (!before && !after) return false;
  if (!before || !after) return true;
  return (
    before.subtotal !== after.subtotal ||
    (before.totalGst ?? 0) !== (after.totalGst ?? 0) ||
    before.totalAmount !== after.totalAmount ||
    before.currency !== after.currency
  );
}

function didDeliveryZoneChange(
  before?: { city_name: string; region: string },
  after?: { city_name: string; region: string },
): boolean {
  if (!before && !after) return false;
  if (!before || !after) return true;
  return before.city_name !== after.city_name || before.region !== after.region;
}

/**
 * Sends WhatsApp notification to client when an order is created
 */
async function enqueueOrderConfirmationMessage(
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
  jobId: string,
): Promise<void> {
  const displayName = clientName && clientName.trim().length > 0
    ? clientName.trim()
    : 'there';

  // Format order items for template parameter 2
  const itemsText = formatOrderItems(orderData.items, false);

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

  logInfo('Order/WhatsApp', 'enqueueOrderConfirmationMessage', 'Enqueuing order confirmation', {
    organizationId,
    orderId,
    to: to.substring(0, 4) + '****',
    hasItems: orderData.items.length > 0,
  });

  await enqueueWhatsappMessage(jobId, {
    type: 'order-confirmation',
    to,
    organizationId,
    parameters,
    context: {
      organizationId,
      orderId,
    },
  });
}

/**
 * Sends WhatsApp notification to client when an order is updated
 */
async function enqueueOrderUpdateMessage(
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
  jobId: string,
): Promise<void> {
  const displayName = clientName && clientName.trim().length > 0
    ? clientName.trim()
    : 'there';

  // Format order items for message
  const itemsText = formatOrderItems(orderData.items, true);

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

  logInfo('Order/WhatsApp', 'enqueueOrderUpdateMessage', 'Enqueuing order update', {
    organizationId,
    orderId,
    to: to.substring(0, 4) + '****',
    hasItems: orderData.items.length > 0,
    status: orderData.status,
  });

  await enqueueWhatsappMessage(jobId, {
    type: 'order-update',
    to,
    organizationId,
    messageBody,
    context: {
      organizationId,
      orderId,
    },
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

    try {
      const jobId = buildJobId(event.id, [orderId, 'order-created']);
      await enqueueOrderConfirmationMessage(
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
        jobId,
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
    const itemsChanged = didItemsChange(before.items, after.items);
    const pricingChanged = didPricingChange(before.pricing, after.pricing);
    const statusChanged = before.status !== after.status;
    const deliveryZoneChanged = didDeliveryZoneChange(before.deliveryZone, after.deliveryZone);
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

    const jobId = buildJobId(event.id, [orderId, 'order-updated']);
    await enqueueOrderUpdateMessage(
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
      jobId,
    );
  },
);

