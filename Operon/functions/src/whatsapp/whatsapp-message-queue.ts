import * as admin from 'firebase-admin';
import { onDocumentCreated } from 'firebase-functions/v2/firestore';
import { getFirestore } from '../shared/firestore-helpers';
import { logInfo, logWarning, logError } from '../shared/logger';
import { CRITICAL_TRIGGER_OPTS } from '../shared/function-config';
import { WHATSAPP_MESSAGE_JOBS_COLLECTION } from '../shared/constants';
import {
  loadWhatsappSettings,
  normalizePhoneE164,
  getWhatsappApiUrl,
  sendWhatsappMessage,
  sendWhatsappTemplateMessage,
} from '../shared/whatsapp-service';

const db = getFirestore();
const MAX_ATTEMPTS = 5;

export type WhatsappMessageJobType =
  | 'order-confirmation'
  | 'order-update'
  | 'trip-dispatch'
  | 'trip-delivery'
  | 'client-welcome';

export type WhatsappMessageJobStatus =
  | 'pending'
  | 'processing'
  | 'retry'
  | 'sent'
  | 'skipped'
  | 'failed';

export interface WhatsappMessageJob {
  type: WhatsappMessageJobType;
  to: string;
  organizationId?: string;
  templateName?: string;
  languageCode?: string;
  parameters?: string[];
  messageBody?: string;
  context?: Record<string, any>;
  status: WhatsappMessageJobStatus;
  attemptCount: number;
  createdAt: admin.firestore.FieldValue;
  updatedAt?: admin.firestore.FieldValue;
  lastError?: string;
  messageId?: string;
}

export async function enqueueWhatsappMessage(
  jobId: string,
  job: Omit<WhatsappMessageJob, 'status' | 'attemptCount' | 'createdAt' | 'updatedAt'>,
): Promise<void> {
  const jobRef = db.collection(WHATSAPP_MESSAGE_JOBS_COLLECTION).doc(jobId);
  try {
    await jobRef.create({
      ...job,
      status: 'pending',
      attemptCount: 0,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    logInfo('WhatsApp/Queue', 'enqueueWhatsappMessage', 'Enqueued WhatsApp job', {
      jobId,
      type: job.type,
      organizationId: job.organizationId,
    });
  } catch (err: any) {
    if (err?.code === 6 || err?.code === 'already-exists') {
      logInfo('WhatsApp/Queue', 'enqueueWhatsappMessage', 'Job already exists, skipping enqueue', {
        jobId,
        type: job.type,
        organizationId: job.organizationId,
      });
      return;
    }
    logError('WhatsApp/Queue', 'enqueueWhatsappMessage', 'Failed to enqueue WhatsApp job', err instanceof Error ? err : new Error(String(err)), {
      jobId,
      type: job.type,
      organizationId: job.organizationId,
    });
    throw err;
  }
}

function resolveTemplateName(
  type: WhatsappMessageJobType,
  settings: { welcomeTemplateId?: string; orderConfirmationTemplateId?: string; tripDispatchTemplateId?: string; tripDeliveryTemplateId?: string },
  override?: string,
): string | undefined {
  if (override) return override;
  switch (type) {
    case 'client-welcome':
      return settings.welcomeTemplateId;
    case 'order-confirmation':
      return settings.orderConfirmationTemplateId;
    case 'trip-dispatch':
      return settings.tripDispatchTemplateId;
    case 'trip-delivery':
      return settings.tripDeliveryTemplateId;
    default:
      return undefined;
  }
}

function shouldRetry(attemptCount: number, err: unknown): boolean {
  if (attemptCount >= MAX_ATTEMPTS) return false;
  const message = err instanceof Error ? err.message : String(err);
  if (message.includes('400') || message.toLowerCase().includes('invalid')) {
    return false;
  }
  return true;
}

export const onWhatsappMessageJobCreated = onDocumentCreated(
  {
    document: `${WHATSAPP_MESSAGE_JOBS_COLLECTION}/{jobId}`,
    ...CRITICAL_TRIGGER_OPTS,
  },
  async (event) => {
    const jobId = event.params.jobId;
    const snapshot = event.data;
    if (!snapshot) return;

    const jobRef = db.collection(WHATSAPP_MESSAGE_JOBS_COLLECTION).doc(jobId);
    const jobSnapshot = await jobRef.get();
    const job = jobSnapshot.data() as WhatsappMessageJob | undefined;
    if (!job) return;

    if (job.status !== 'pending' && job.status !== 'retry') {
      logInfo('WhatsApp/Queue', 'onWhatsappMessageJobCreated', 'Job already processed, skipping', {
        jobId,
        status: job.status,
      });
      return;
    }

    if (job.attemptCount >= MAX_ATTEMPTS) {
      logWarning('WhatsApp/Queue', 'onWhatsappMessageJobCreated', 'Job exceeded max attempts, skipping', {
        jobId,
        attemptCount: job.attemptCount,
      });
      return;
    }

    await jobRef.update({
      status: 'processing',
      attemptCount: admin.firestore.FieldValue.increment(1),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    const settings = await loadWhatsappSettings(job.organizationId);
    if (!settings) {
      logWarning('WhatsApp/Queue', 'onWhatsappMessageJobCreated', 'No WhatsApp settings, skipping job', {
        jobId,
        organizationId: job.organizationId,
      });
      await jobRef.update({
        status: 'skipped',
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        lastError: 'WhatsApp settings missing or disabled',
      });
      return;
    }

    const normalizedTo = normalizePhoneE164(job.to);
    if (!normalizedTo) {
      logWarning('WhatsApp/Queue', 'onWhatsappMessageJobCreated', 'Invalid phone number, skipping job', {
        jobId,
        to: job.to,
      });
      await jobRef.update({
        status: 'failed',
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        lastError: 'Invalid phone number',
      });
      return;
    }

    const url = getWhatsappApiUrl(settings.phoneId);

    try {
      let messageId: string | undefined;

      if (job.type === 'order-update') {
        if (!job.messageBody) {
          throw new Error('Missing messageBody for order-update');
        }
        messageId = await sendWhatsappMessage(
          url,
          settings.token,
          normalizedTo,
          job.messageBody,
          job.type,
          job.context ?? {},
        );
      } else {
        const templateName = resolveTemplateName(job.type, settings, job.templateName);
        if (!templateName) {
          throw new Error(`Missing templateName for job type: ${job.type}`);
        }
        if (!job.parameters || job.parameters.length === 0) {
          throw new Error(`Missing template parameters for job type: ${job.type}`);
        }
        messageId = await sendWhatsappTemplateMessage(
          url,
          settings.token,
          normalizedTo,
          templateName,
          settings.languageCode ?? job.languageCode ?? 'en',
          job.parameters,
          job.type,
          job.context ?? {},
        );
      }

      await jobRef.update({
        status: 'sent',
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        messageId: messageId ?? null,
      });

      logInfo('WhatsApp/Queue', 'onWhatsappMessageJobCreated', 'Job sent successfully', {
        jobId,
        type: job.type,
        organizationId: job.organizationId,
        messageId,
      });
    } catch (err) {
      const retryable = shouldRetry(job.attemptCount + 1, err);
      const nextStatus: WhatsappMessageJobStatus = retryable ? 'retry' : 'failed';
      const errorMessage = err instanceof Error ? err.message : String(err);

      await jobRef.update({
        status: nextStatus,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        lastError: errorMessage,
      });

      logError('WhatsApp/Queue', 'onWhatsappMessageJobCreated', 'Failed to send WhatsApp job', err instanceof Error ? err : new Error(String(err)), {
        jobId,
        type: job.type,
        organizationId: job.organizationId,
        retryable,
      });

      if (retryable) {
        throw err;
      }
    }
  },
);
