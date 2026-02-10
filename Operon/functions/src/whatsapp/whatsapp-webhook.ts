import * as admin from 'firebase-admin';
import { onRequest } from 'firebase-functions/v2/https';
import { defineSecret } from 'firebase-functions/params';
import { getFirestore } from '../shared/firestore-helpers';
import { logInfo, logWarning, logError } from '../shared/logger';
import { DEFAULT_REGION } from '../shared/function-config';
import { WHATSAPP_MESSAGE_JOBS_COLLECTION } from '../shared/constants';

const db = getFirestore();
const whatsappWebhookVerifyToken = defineSecret('WHATSAPP_WEBHOOK_VERIFY_TOKEN');

export const whatsappWebhook = onRequest(
  {
    region: DEFAULT_REGION,
    timeoutSeconds: 30,
    memory: '256MiB',
    maxInstances: 5,
    secrets: [whatsappWebhookVerifyToken],
  },
  async (req, res) => {
    const verifyToken = whatsappWebhookVerifyToken.value() || process.env.WHATSAPP_WEBHOOK_VERIFY_TOKEN;

    if (req.method === 'GET') {
      const mode = req.query['hub.mode'];
      const token = req.query['hub.verify_token'];
      const challenge = req.query['hub.challenge'];

      if (!verifyToken) {
        logWarning('WhatsApp/Webhook', 'verify', 'Missing WHATSAPP_WEBHOOK_VERIFY_TOKEN');
        res.status(403).send('Verify token not configured');
        return;
      }

      if (mode === 'subscribe' && token === verifyToken) {
        logInfo('WhatsApp/Webhook', 'verify', 'Webhook verified');
        res.status(200).send(challenge);
        return;
      }

      logWarning('WhatsApp/Webhook', 'verify', 'Webhook verification failed', {
        mode,
      });
      res.status(403).send('Verification failed');
      return;
    }

    if (req.method !== 'POST') {
      res.status(405).send('Method Not Allowed');
      return;
    }

    try {
      const body = req.body;
      if (!body || !body.entry) {
        logWarning('WhatsApp/Webhook', 'handle', 'Missing webhook payload');
        res.status(400).send('Invalid payload');
        return;
      }

      const entries = Array.isArray(body.entry) ? body.entry : [];
      let statusCount = 0;

      for (const entry of entries) {
        const changes = Array.isArray(entry?.changes) ? entry.changes : [];
        for (const change of changes) {
          const value = change?.value;
          const statuses = Array.isArray(value?.statuses) ? value.statuses : [];
          for (const status of statuses) {
            const messageId = status?.id as string | undefined;
            if (!messageId) continue;

            statusCount += 1;
            await updateMessageStatus(messageId, status);
          }
        }
      }

      logInfo('WhatsApp/Webhook', 'handle', 'Webhook processed', {
        statusCount,
      });

      res.status(200).send('ok');
    } catch (err) {
      logError('WhatsApp/Webhook', 'handle', 'Failed to process webhook', err instanceof Error ? err : new Error(String(err)));
      res.status(500).send('Internal error');
    }
  },
);

async function updateMessageStatus(messageId: string, statusPayload: Record<string, any>): Promise<void> {
  const snapshot = await db
    .collection(WHATSAPP_MESSAGE_JOBS_COLLECTION)
    .where('messageId', '==', messageId)
    .limit(5)
    .get();

  if (snapshot.empty) {
    logWarning('WhatsApp/Webhook', 'updateMessageStatus', 'No job found for message ID', {
      messageId,
    });
    return;
  }

  const timestamp = Number(statusPayload.timestamp);
  const statusAt = Number.isFinite(timestamp)
    ? admin.firestore.Timestamp.fromMillis(timestamp * 1000)
    : admin.firestore.FieldValue.serverTimestamp();

  const updates = {
    deliveryStatus: statusPayload.status ?? 'unknown',
    deliveryStatusAt: statusAt,
    deliveryDetails: statusPayload,
    deliveryStatusUpdatedAt: admin.firestore.FieldValue.serverTimestamp(),
    lastError: statusPayload.errors ? JSON.stringify(statusPayload.errors) : undefined,
  };

  const batch = db.batch();
  snapshot.docs.forEach((doc) => {
    batch.update(doc.ref, updates);
  });

  await batch.commit();
}
