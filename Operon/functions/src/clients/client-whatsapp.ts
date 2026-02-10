import { onDocumentCreated } from 'firebase-functions/v2/firestore';
import { CLIENTS_COLLECTION } from '../shared/constants';
import { logInfo, logWarning } from '../shared/logger';
import { LIGHT_TRIGGER_OPTS } from '../shared/function-config';
import { enqueueWhatsappMessage } from '../whatsapp/whatsapp-message-queue';

function buildJobId(eventId: string | undefined, fallbackParts: Array<string | undefined>): string {
  if (eventId) return eventId;
  return fallbackParts.filter(Boolean).join('-');
}

async function enqueueWhatsappWelcomeMessage(
  to: string,
  clientName: string | undefined,
  organizationId: string | undefined,
  clientId: string,
  jobId: string,
): Promise<void> {
  const displayName = clientName && clientName.trim().length > 0
    ? clientName.trim()
    : 'there';

  logInfo('Client/WhatsApp', 'enqueueWhatsappWelcomeMessage', 'Enqueuing welcome message', {
    organizationId,
    clientId,
    to: to.substring(0, 4) + '****',
  });

  await enqueueWhatsappMessage(jobId, {
    type: 'client-welcome',
    to,
    organizationId,
    parameters: [displayName],
    context: {
      organizationId,
      clientId,
    },
  });
}

/**
 * Cloud Function: Triggered when a client is created
 * Sends a WhatsApp welcome message to the new client
 */
export const onClientCreatedSendWhatsappWelcome = onDocumentCreated(
  {
    document: `${CLIENTS_COLLECTION}/{clientId}`,
    ...LIGHT_TRIGGER_OPTS,
  },
  async (event) => {
    const snapshot = event.data;
    if (!snapshot) return;
    const data = snapshot.data() as {
      name?: string;
      primaryPhone?: string;
      primaryPhoneNormalized?: string;
      organizationId?: string;
    } | undefined;

    if (!data) return;

    const clientId = event.params.clientId;
    const phone = (data.primaryPhoneNormalized || data.primaryPhone || '').trim();
    if (!phone) {
      logWarning('Client/WhatsApp', 'onClientCreatedSendWhatsappWelcome', 'No phone found on client, skipping welcome', {
        clientId,
      });
      return;
    }

    let organizationId = data.organizationId;
    if (!organizationId) {
      const defaultOrgId = process.env.WHATSAPP_DEFAULT_ORG_ID;
      if (defaultOrgId) {
        organizationId = defaultOrgId;
        logInfo('Client/WhatsApp', 'onClientCreatedSendWhatsappWelcome', 'Using default org from env', {
          organizationId,
        });
      } else {
        logWarning('Client/WhatsApp', 'onClientCreatedSendWhatsappWelcome', 'No organizationId on client and no default configured, skipping', {
          clientId,
        });
        return;
      }
    }

    const jobId = buildJobId(event.id, [clientId, 'client-welcome']);
    await enqueueWhatsappWelcomeMessage(phone, data.name, organizationId, clientId, jobId);
  },
);

