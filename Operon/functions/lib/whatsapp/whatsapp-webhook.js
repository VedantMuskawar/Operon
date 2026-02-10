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
exports.whatsappWebhook = void 0;
const admin = __importStar(require("firebase-admin"));
const https_1 = require("firebase-functions/v2/https");
const params_1 = require("firebase-functions/params");
const firestore_helpers_1 = require("../shared/firestore-helpers");
const logger_1 = require("../shared/logger");
const function_config_1 = require("../shared/function-config");
const constants_1 = require("../shared/constants");
const db = (0, firestore_helpers_1.getFirestore)();
const whatsappWebhookVerifyToken = (0, params_1.defineSecret)('WHATSAPP_WEBHOOK_VERIFY_TOKEN');
exports.whatsappWebhook = (0, https_1.onRequest)({
    region: function_config_1.DEFAULT_REGION,
    timeoutSeconds: 30,
    memory: '256MiB',
    maxInstances: 5,
    secrets: [whatsappWebhookVerifyToken],
}, async (req, res) => {
    const verifyToken = whatsappWebhookVerifyToken.value() || process.env.WHATSAPP_WEBHOOK_VERIFY_TOKEN;
    if (req.method === 'GET') {
        const mode = req.query['hub.mode'];
        const token = req.query['hub.verify_token'];
        const challenge = req.query['hub.challenge'];
        if (!verifyToken) {
            (0, logger_1.logWarning)('WhatsApp/Webhook', 'verify', 'Missing WHATSAPP_WEBHOOK_VERIFY_TOKEN');
            res.status(403).send('Verify token not configured');
            return;
        }
        if (mode === 'subscribe' && token === verifyToken) {
            (0, logger_1.logInfo)('WhatsApp/Webhook', 'verify', 'Webhook verified');
            res.status(200).send(challenge);
            return;
        }
        (0, logger_1.logWarning)('WhatsApp/Webhook', 'verify', 'Webhook verification failed', {
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
            (0, logger_1.logWarning)('WhatsApp/Webhook', 'handle', 'Missing webhook payload');
            res.status(400).send('Invalid payload');
            return;
        }
        const entries = Array.isArray(body.entry) ? body.entry : [];
        let statusCount = 0;
        for (const entry of entries) {
            const changes = Array.isArray(entry === null || entry === void 0 ? void 0 : entry.changes) ? entry.changes : [];
            for (const change of changes) {
                const value = change === null || change === void 0 ? void 0 : change.value;
                const statuses = Array.isArray(value === null || value === void 0 ? void 0 : value.statuses) ? value.statuses : [];
                for (const status of statuses) {
                    const messageId = status === null || status === void 0 ? void 0 : status.id;
                    if (!messageId)
                        continue;
                    statusCount += 1;
                    await updateMessageStatus(messageId, status);
                }
            }
        }
        (0, logger_1.logInfo)('WhatsApp/Webhook', 'handle', 'Webhook processed', {
            statusCount,
        });
        res.status(200).send('ok');
    }
    catch (err) {
        (0, logger_1.logError)('WhatsApp/Webhook', 'handle', 'Failed to process webhook', err instanceof Error ? err : new Error(String(err)));
        res.status(500).send('Internal error');
    }
});
async function updateMessageStatus(messageId, statusPayload) {
    var _a;
    const snapshot = await db
        .collection(constants_1.WHATSAPP_MESSAGE_JOBS_COLLECTION)
        .where('messageId', '==', messageId)
        .limit(5)
        .get();
    if (snapshot.empty) {
        (0, logger_1.logWarning)('WhatsApp/Webhook', 'updateMessageStatus', 'No job found for message ID', {
            messageId,
        });
        return;
    }
    const timestamp = Number(statusPayload.timestamp);
    const statusAt = Number.isFinite(timestamp)
        ? admin.firestore.Timestamp.fromMillis(timestamp * 1000)
        : admin.firestore.FieldValue.serverTimestamp();
    const updates = {
        deliveryStatus: (_a = statusPayload.status) !== null && _a !== void 0 ? _a : 'unknown',
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
//# sourceMappingURL=whatsapp-webhook.js.map