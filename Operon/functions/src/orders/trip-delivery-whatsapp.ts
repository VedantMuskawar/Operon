import { onDocumentUpdated } from 'firebase-functions/v2/firestore';
import { CLIENTS_COLLECTION } from '../shared/constants';
import { getFirestore } from '../shared/firestore-helpers';
import { logInfo, logWarning, logError } from '../shared/logger';
import { LIGHT_TRIGGER_OPTS } from '../shared/function-config';
import { enqueueWhatsappMessage } from '../whatsapp/whatsapp-message-queue';

const db = getFirestore();
const SCHEDULED_TRIPS_COLLECTION = 'SCHEDULE_TRIPS';

function buildJobId(eventId: string | undefined, fallbackParts: Array<string | undefined>): string {
  if (eventId) return eventId;
  return fallbackParts.filter(Boolean).join('-');
}

/**
 * Sends WhatsApp notification to client when a trip is delivered
 */
async function enqueueTripDeliveryMessage(
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
  jobId: string,
): Promise<void> {
  const displayName = clientName && clientName.trim().length > 0
    ? clientName.trim()
    : 'there';

  // Format trip date for parameter 2
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
      logError('Trip/WhatsApp', 'sendTripDeliveryMessage', 'Error formatting date', e instanceof Error ? e : new Error(String(e)));
    }
  }

  // Format items delivered for parameter 3
  const itemsText = tripData.items && tripData.items.length > 0
    ? tripData.items
        .map((item, index) => {
          const itemNum = index + 1;
          return `${itemNum}. ${item.productName} - ${item.fixedQuantityPerTrip} units`;
        })
        .join('\n')
    : 'No items';

  // Prepare template parameters
  const parameters = [
    displayName,        // Parameter 1: Client name
    scheduledDateText,  // Parameter 2: Trip date
    itemsText,          // Parameter 3: Items delivered list
  ];

  logInfo('Trip/WhatsApp', 'enqueueTripDeliveryMessage', 'Enqueuing delivery notification', {
    organizationId,
    tripId,
    to: to.substring(0, 4) + '****',
    hasItems: tripData.items && tripData.items.length > 0,
  });

  await enqueueWhatsappMessage(jobId, {
    type: 'trip-delivery',
    to,
    organizationId,
    parameters,
    context: {
      organizationId,
      tripId,
    },
  });
}

/**
 * Cloud Function: Triggered when a trip status is updated to 'delivered'
 * Sends WhatsApp notification to client with delivery confirmation
 */
export const onTripDeliveredSendWhatsapp = onDocumentUpdated(
  {
    document: `${SCHEDULED_TRIPS_COLLECTION}/{tripId}`,
    ...LIGHT_TRIGGER_OPTS,
  },
  async (event) => {
    const tripId = event.params.tripId;
    const before = event.data?.before.data();
    const after = event.data?.after.data();
    if (!before || !after) return;

    // Only proceed if trip status changed to 'delivered'
    const beforeStatus = (before.tripStatus as string | undefined)?.toLowerCase();
    const afterStatus = (after.tripStatus as string | undefined)?.toLowerCase();

    if (beforeStatus === afterStatus || afterStatus !== 'delivered') {
      logInfo('Trip/WhatsApp', 'onTripDeliveredSendWhatsapp', 'Trip status not changed to delivered, skipping', {
        tripId,
        beforeStatus,
        afterStatus,
      });
      return;
    }

    // Do not send when return is reverted (returned → delivered)
    if (beforeStatus === 'returned' && afterStatus === 'delivered') {
      logInfo('Trip/WhatsApp', 'onTripDeliveredSendWhatsapp', 'Trip return reverted, skipping WhatsApp', {
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
      logWarning('Trip/WhatsApp', 'onTripDeliveredSendWhatsapp', 'No trip data found', { tripId });
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
        logError('Trip/WhatsApp', 'onTripDeliveredSendWhatsapp', 'Error fetching client data', error instanceof Error ? error : new Error(String(error)), {
          tripId,
          clientId: tripData.clientId,
        });
      }
    }

    if (!clientPhone) {
      logWarning('Trip/WhatsApp', 'onTripDeliveredSendWhatsapp', 'No phone found for trip, skipping notification', {
        tripId,
        clientId: tripData.clientId,
      });
      return;
    }

    const jobId = buildJobId(event.id, [tripId, 'trip-delivery']);
    await enqueueTripDeliveryMessage(
      clientPhone,
      clientName,
      tripData.organizationId,
      tripId,
      tripData,
      jobId,
    );
  },
);
