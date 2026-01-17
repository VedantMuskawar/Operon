import * as functions from 'firebase-functions';
import {
  CLIENTS_COLLECTION,
} from '../shared/constants';
import { getFirestore } from '../shared/firestore-helpers';
import { loadWhatsappSettings, sendWhatsappTemplateMessage } from '../shared/whatsapp-service';
import { logInfo, logWarning, logError } from '../shared/logger';

const db = getFirestore();
const SCHEDULED_TRIPS_COLLECTION = 'SCHEDULE_TRIPS';

/**
 * Sends WhatsApp notification to client when a trip is dispatched
 */
async function sendTripDispatchMessage(
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
    driverName?: string;
    driverPhone?: string;
    vehicleNumber?: string;
    scheduledDate?: any;
    scheduledDay?: string;
    slot?: number;
    slotName?: string;
  },
): Promise<void> {
  const settings = await loadWhatsappSettings(organizationId);
  if (!settings) {
    logWarning('Trip/WhatsApp', 'sendTripDispatchMessage', 'Skipping send – no settings or disabled', {
      tripId,
      organizationId,
    });
    return;
  }

  const url = `https://graph.facebook.com/v19.0/${settings.phoneId}/messages`;
  const displayName = clientName && clientName.trim().length > 0
    ? clientName.trim()
    : 'there';

  // Format scheduled date for parameter 2
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
      logError('Trip/WhatsApp', 'sendTripDispatchMessage', 'Error formatting date', e instanceof Error ? e : new Error(String(e)));
    }
  }

  // Format vehicle and slot info for parameter 3
  const vehicleInfo = tripData.vehicleNumber
    ? `Vehicle: ${tripData.vehicleNumber}`
    : '';
  const slotInfo = tripData.slotName || (tripData.slot ? `Slot ${tripData.slot}` : '');
  const scheduleInfo = [vehicleInfo, slotInfo].filter(Boolean).join(' | ') || '';

  // Format items list for parameter 4
  const itemsText = tripData.items && tripData.items.length > 0
    ? tripData.items
        .map((item, index) => {
          const itemNum = index + 1;
          return `${itemNum}. ${item.productName} - Qty: ${item.fixedQuantityPerTrip} units - ₹${item.unitPrice.toFixed(2)}`;
        })
        .join('\n')
    : 'No items';

  // Format total amount for parameter 5
  const pricing = tripData.tripPricing;
  const totalAmountText = pricing
    ? pricing.gstAmount > 0
      ? `₹${pricing.total.toFixed(2)} (Subtotal: ₹${pricing.subtotal.toFixed(2)}, GST: ₹${pricing.gstAmount.toFixed(2)})`
      : `₹${pricing.total.toFixed(2)} (Subtotal: ₹${pricing.subtotal.toFixed(2)})`
    : 'Pricing not available';

  // Format driver information for parameter 6
  const driverInfo = tripData.driverName && tripData.driverPhone
    ? `Driver: ${tripData.driverName} | Contact: ${tripData.driverPhone}`
    : tripData.driverName
      ? `Driver: ${tripData.driverName}`
      : 'Driver information not available';

  // Prepare template parameters
  const parameters = [
    displayName,        // Parameter 1: Client name
    scheduledDateText,  // Parameter 2: Trip date
    scheduleInfo,      // Parameter 3: Vehicle and slot info
    itemsText,         // Parameter 4: Items list
    totalAmountText,   // Parameter 5: Total amount with breakdown
    driverInfo,        // Parameter 6: Driver information
  ];

  logInfo('Trip/WhatsApp', 'sendTripDispatchMessage', 'Sending dispatch notification', {
    organizationId,
    tripId,
    to: to.substring(0, 4) + '****',
    phoneId: settings.phoneId,
    templateId: settings.tripDispatchTemplateId,
    hasItems: tripData.items && tripData.items.length > 0,
  });

  await sendWhatsappTemplateMessage(
    url,
    settings.token,
    to,
    settings.tripDispatchTemplateId,
    settings.languageCode ?? 'en',
    parameters,
    'trip-dispatch',
    {
      organizationId,
      tripId,
    },
  );
}

/**
 * Cloud Function: Triggered when a trip status is updated to 'dispatched'
 * Sends WhatsApp notification to client with trip details and driver information
 */
export const onTripDispatchedSendWhatsapp = functions.firestore
  .document(`${SCHEDULED_TRIPS_COLLECTION}/{tripId}`)
  .onUpdate(async (change, context) => {
    const tripId = context.params.tripId;
    const before = change.before.data();
    const after = change.after.data();

    // Only proceed if trip status changed to 'dispatched'
    const beforeStatus = before.tripStatus as string | undefined;
    const afterStatus = after.tripStatus as string | undefined;

    if (beforeStatus === afterStatus || afterStatus !== 'dispatched') {
      logInfo('Trip/WhatsApp', 'onTripDispatchedSendWhatsapp', 'Trip status not changed to dispatched, skipping', {
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
      driverName?: string;
      driverPhone?: string;
      vehicleNumber?: string;
      scheduledDate?: any;
      scheduledDay?: string;
      slot?: number;
      slotName?: string;
    };

    if (!tripData) {
      logWarning('Trip/WhatsApp', 'onTripDispatchedSendWhatsapp', 'No trip data found', { tripId });
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
        logError('Trip/WhatsApp', 'onTripDispatchedSendWhatsapp', 'Error fetching client data', error instanceof Error ? error : new Error(String(error)), {
          tripId,
          clientId: tripData.clientId,
        });
      }
    }

    if (!clientPhone) {
      logWarning('Trip/WhatsApp', 'onTripDispatchedSendWhatsapp', 'No phone found for trip, skipping notification', {
        tripId,
        clientId: tripData.clientId,
      });
      return;
    }

    await sendTripDispatchMessage(
      clientPhone,
      clientName,
      tripData.organizationId,
      tripId,
      tripData,
    );
  });

