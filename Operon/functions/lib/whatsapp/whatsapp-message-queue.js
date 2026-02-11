"use strict";
var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    var desc = Object.getOwnPropertyDescriptor(m, k);
    if (!desc || ("get" in desc ? !m.__esModule : desc.writable || desc.configurable)) {
      desc = { enumerable: true, get: function() { return m[k]; } };
    }
    Object.defineProperty(o, k2, desc);
}) : (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    o[k2] = m[k];
}));
var __setModuleDefault = (this && this.__setModuleDefault) || (Object.create ? (function(o, v) {
    Object.defineProperty(o, "default", { enumerable: true, value: v });
}) : function(o, v) {
    o["default"] = v;
});
var __importStar = (this && this.__importStar) || (function () {
    var ownKeys = function(o) {
        ownKeys = Object.getOwnPropertyNames || function (o) {
            var ar = [];
            for (var k in o) if (Object.prototype.hasOwnProperty.call(o, k)) ar[ar.length] = k;
            return ar;
        };
        return ownKeys(o);
    };
    return function (mod) {
        if (mod && mod.__esModule) return mod;
        var result = {};
        if (mod != null) for (var k = ownKeys(mod), i = 0; i < k.length; i++) if (k[i] !== "default") __createBinding(result, mod, k[i]);
        __setModuleDefault(result, mod);
        return result;
    };
})();
Object.defineProperty(exports, "__esModule", { value: true });
exports.onWhatsappMessageJobCreated = void 0;
exports.enqueueWhatsappMessage = enqueueWhatsappMessage;
const admin = __importStar(require("firebase-admin"));
const firestore_1 = require("firebase-functions/v2/firestore");
const firestore_helpers_1 = require("../shared/firestore-helpers");
const logger_1 = require("../shared/logger");
const function_config_1 = require("../shared/function-config");
const constants_1 = require("../shared/constants");
const whatsapp_service_1 = require("../shared/whatsapp-service");
const db = (0, firestore_helpers_1.getFirestore)();
const MAX_ATTEMPTS = 5;
async function enqueueWhatsappMessage(jobId, job) {
    const jobRef = db.collection(constants_1.WHATSAPP_MESSAGE_JOBS_COLLECTION).doc(jobId);
    try {
        await jobRef.create(Object.assign(Object.assign({}, job), { status: 'pending', attemptCount: 0, createdAt: admin.firestore.FieldValue.serverTimestamp() }));
        (0, logger_1.logInfo)('WhatsApp/Queue', 'enqueueWhatsappMessage', 'Enqueued WhatsApp job', {
            jobId,
            type: job.type,
            organizationId: job.organizationId,
        });
    }
    catch (err) {
        if ((err === null || err === void 0 ? void 0 : err.code) === 6 || (err === null || err === void 0 ? void 0 : err.code) === 'already-exists') {
            (0, logger_1.logInfo)('WhatsApp/Queue', 'enqueueWhatsappMessage', 'Job already exists, skipping enqueue', {
                jobId,
                type: job.type,
                organizationId: job.organizationId,
            });
            return;
        }
        (0, logger_1.logError)('WhatsApp/Queue', 'enqueueWhatsappMessage', 'Failed to enqueue WhatsApp job', err instanceof Error ? err : new Error(String(err)), {
            jobId,
            type: job.type,
            organizationId: job.organizationId,
        });
        throw err;
    }
}
function resolveTemplateName(type, settings, override) {
    if (override)
        return override;
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
function shouldRetry(attemptCount, err) {
    if (attemptCount >= MAX_ATTEMPTS)
        return false;
    const message = err instanceof Error ? err.message : String(err);
    if (message.includes('400') || message.toLowerCase().includes('invalid')) {
        return false;
    }
    return true;
}
exports.onWhatsappMessageJobCreated = (0, firestore_1.onDocumentCreated)(Object.assign({ document: `${constants_1.WHATSAPP_MESSAGE_JOBS_COLLECTION}/{jobId}` }, function_config_1.CRITICAL_TRIGGER_OPTS), async (event) => {
    var _a, _b, _c, _d;
    const jobId = event.params.jobId;
    const snapshot = event.data;
    if (!snapshot)
        return;
    const jobRef = db.collection(constants_1.WHATSAPP_MESSAGE_JOBS_COLLECTION).doc(jobId);
    const { job, claimed, reason } = await db.runTransaction(async (tx) => {
        const jobSnapshot = await tx.get(jobRef);
        const jobData = jobSnapshot.data();
        if (!jobData) {
            return { job: undefined, claimed: false, reason: 'missing' };
        }
        if (jobData.messageId) {
            return { job: jobData, claimed: false, reason: 'already-sent' };
        }
        if (jobData.status !== 'pending' && jobData.status !== 'retry') {
            return { job: jobData, claimed: false, reason: 'status' };
        }
        if (jobData.attemptCount >= MAX_ATTEMPTS) {
            return { job: jobData, claimed: false, reason: 'attempts' };
        }
        tx.update(jobRef, {
            status: 'processing',
            attemptCount: admin.firestore.FieldValue.increment(1),
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
        return { job: jobData, claimed: true, reason: 'claimed' };
    });
    if (!job)
        return;
    if (!claimed) {
        if (reason === 'attempts') {
            (0, logger_1.logWarning)('WhatsApp/Queue', 'onWhatsappMessageJobCreated', 'Job exceeded max attempts, skipping', {
                jobId,
                attemptCount: job.attemptCount,
            });
            return;
        }
        (0, logger_1.logInfo)('WhatsApp/Queue', 'onWhatsappMessageJobCreated', 'Job already processed, skipping', {
            jobId,
            status: job.status,
            reason,
        });
        return;
    }
    const settings = await (0, whatsapp_service_1.loadWhatsappSettings)(job.organizationId);
    if (!settings) {
        (0, logger_1.logWarning)('WhatsApp/Queue', 'onWhatsappMessageJobCreated', 'No WhatsApp settings, skipping job', {
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
    const normalizedTo = (0, whatsapp_service_1.normalizePhoneE164)(job.to);
    if (!normalizedTo) {
        (0, logger_1.logWarning)('WhatsApp/Queue', 'onWhatsappMessageJobCreated', 'Invalid phone number, skipping job', {
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
    const url = (0, whatsapp_service_1.getWhatsappApiUrl)(settings.phoneId);
    try {
        let messageId;
        if (job.type === 'order-update') {
            if (!job.messageBody) {
                throw new Error('Missing messageBody for order-update');
            }
            messageId = await (0, whatsapp_service_1.sendWhatsappMessage)(url, settings.token, normalizedTo, job.messageBody, job.type, (_a = job.context) !== null && _a !== void 0 ? _a : {});
        }
        else {
            const templateName = resolveTemplateName(job.type, settings, job.templateName);
            if (!templateName) {
                throw new Error(`Missing templateName for job type: ${job.type}`);
            }
            if (!job.parameters || job.parameters.length === 0) {
                throw new Error(`Missing template parameters for job type: ${job.type}`);
            }
            messageId = await (0, whatsapp_service_1.sendWhatsappTemplateMessage)(url, settings.token, normalizedTo, templateName, (_c = (_b = settings.languageCode) !== null && _b !== void 0 ? _b : job.languageCode) !== null && _c !== void 0 ? _c : 'en', job.parameters, job.type, (_d = job.context) !== null && _d !== void 0 ? _d : {});
        }
        await jobRef.update({
            status: 'sent',
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            messageId: messageId !== null && messageId !== void 0 ? messageId : null,
        });
        (0, logger_1.logInfo)('WhatsApp/Queue', 'onWhatsappMessageJobCreated', 'Job sent successfully', {
            jobId,
            type: job.type,
            organizationId: job.organizationId,
            messageId,
        });
    }
    catch (err) {
        const retryable = shouldRetry(job.attemptCount + 1, err);
        const nextStatus = retryable ? 'retry' : 'failed';
        const errorMessage = err instanceof Error ? err.message : String(err);
        await jobRef.update({
            status: nextStatus,
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            lastError: errorMessage,
        });
        (0, logger_1.logError)('WhatsApp/Queue', 'onWhatsappMessageJobCreated', 'Failed to send WhatsApp job', err instanceof Error ? err : new Error(String(err)), {
            jobId,
            type: job.type,
            organizationId: job.organizationId,
            retryable,
        });
        if (retryable) {
            throw err;
        }
    }
});
//# sourceMappingURL=whatsapp-message-queue.js.map