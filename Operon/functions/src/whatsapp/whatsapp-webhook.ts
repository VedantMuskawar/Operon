import * as admin from 'firebase-admin';
import { onRequest } from 'firebase-functions/v2/https';
import { defineSecret } from 'firebase-functions/params';
import { getFirestore } from '../shared/firestore-helpers';
import { logInfo, logWarning, logError } from '../shared/logger';
import { DEFAULT_REGION } from '../shared/function-config';
import { WHATSAPP_MESSAGE_JOBS_COLLECTION } from '../shared/constants';
const whatsappWebhookVerifyToken = defineSecret('WHATSAPP_WEBHOOK_VERIFY_TOKEN');
const db = getFirestore();

type WhatsappStatusPayload = {
  id?: string;
  status?: string;
  recipient_id?: string;
  errors?: Array<{ code?: number | string; title?: string; message?: string }>;
};

export const whatsappWebhook = onRequest(
  {
    region: DEFAULT_REGION,
    timeoutSeconds: 30,
    memory: '256MiB',
    maxInstances: 5,
    secrets: [whatsappWebhookVerifyToken],
  },
  async (req, res) => {
    const verifyToken = (whatsappWebhookVerifyToken.value() || process.env.WHATSAPP_WEBHOOK_VERIFY_TOKEN || '').trim();

    if (req.method === 'GET') {
      const mode = String(req.query['hub.mode'] ?? '').trim();
      const token = String(req.query['hub.verify_token'] ?? '').trim();
      const challenge = String(req.query['hub.challenge'] ?? '');

      if (!verifyToken) {
        logWarning('WhatsApp/Webhook', 'verify', 'Missing WHATSAPP_WEBHOOK_VERIFY_TOKEN');
        res.status(403).send('Verify token not configured');
        return;
      }

      if (mode === 'subscribe' && token === verifyToken) {
        logInfo('WhatsApp/Webhook', 'verify', 'Webhook verified');
        res.status(200).type('text/plain').send(challenge);
        return;
      }

      logWarning('WhatsApp/Webhook', 'verify', 'Webhook verification failed', {
        mode,
        tokenMatch: token === verifyToken,
        tokenLength: token.length,
        verifyTokenLength: verifyToken.length,
      });
      res.status(403).send('Verification failed');
      return;
    }

    if (req.method !== 'POST') {
      res.status(405).send('Method Not Allowed');
      return;
    }

    try {
      const body = req.body as { entry?: Array<{ changes?: Array<{ value?: { statuses?: WhatsappStatusPayload[] } }> }> } | undefined;
      const entries = Array.isArray(body?.entry) ? body?.entry ?? [] : [];
      const statuses: WhatsappStatusPayload[] = [];

      for (const entry of entries) {
        const changes = Array.isArray(entry?.changes) ? entry.changes ?? [] : [];
        for (const change of changes) {
          const changeStatuses = Array.isArray(change?.value?.statuses) ? change.value?.statuses ?? [] : [];
          statuses.push(...changeStatuses);
        }
      }

      if (statuses.length === 0) {
        logInfo('WhatsApp/Webhook', 'handle', 'No status updates in webhook payload');
        res.status(200).send('ok');
        return;
      }

      let updatedCount = 0;
      for (const statusPayload of statuses) {
        const messageId = statusPayload?.id;
        const deliveryStatus = statusPayload?.status ?? 'unknown';
        const recipientId = statusPayload?.recipient_id;

        if (!messageId) {
          logWarning('WhatsApp/Webhook', 'handle', 'Missing message id in status payload', {
            recipientId,
            deliveryStatus,
          });
          continue;
        }

        const snapshot = await db
          .collection(WHATSAPP_MESSAGE_JOBS_COLLECTION)
          .where('whatsapp_message_id', '==', messageId)
          .limit(10)
          .get();

        if (snapshot.empty) {
          logWarning('WhatsApp/Webhook', 'handle', 'No WhatsApp job found for message id', {
            messageId,
            recipientId,
            deliveryStatus,
          });
          continue;
        }

        const batch = db.batch();
        snapshot.docs.forEach((doc) => {
          batch.update(doc.ref, {
            delivery_status: deliveryStatus,
            last_updated: admin.firestore.FieldValue.serverTimestamp(),
          });
        });
        await batch.commit();
        updatedCount += snapshot.size;

        if (deliveryStatus === 'failed') {
          const errors = Array.isArray(statusPayload?.errors) ? statusPayload.errors : [];
          const error = errors[0];
          if (error) {
            logError('WhatsApp/Webhook', 'handle', 'WhatsApp delivery failed', new Error('WhatsApp status failed'), {
              messageId,
              recipientId,
              errorCode: error.code,
              errorMessage: error.message ?? error.title,
            });
          } else {
            logError('WhatsApp/Webhook', 'handle', 'WhatsApp delivery failed without error details', new Error('WhatsApp status failed'), {
              messageId,
              recipientId,
            });
          }
        }
      }

      logInfo('WhatsApp/Webhook', 'handle', 'Webhook processed', {
        updatedCount,
        statusCount: statuses.length,
      });
      res.status(200).send('ok');
    } catch (err) {
      logError('WhatsApp/Webhook', 'handle', 'Failed to process webhook payload', err instanceof Error ? err : new Error(String(err)));
      res.status(200).send('ok');
    }
  },
);
