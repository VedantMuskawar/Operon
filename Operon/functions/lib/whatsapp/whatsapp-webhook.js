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
const whatsappWebhookVerifyToken = (0, params_1.defineSecret)('WHATSAPP_WEBHOOK_VERIFY_TOKEN');
const db = (0, firestore_helpers_1.getFirestore)();
exports.whatsappWebhook = (0, https_1.onRequest)({
    region: function_config_1.DEFAULT_REGION,
    timeoutSeconds: 30,
    memory: '256MiB',
    maxInstances: 5,
    secrets: [whatsappWebhookVerifyToken],
}, async (req, res) => {
    var _a, _b, _c, _d, _e, _f, _g, _h, _j, _k;
    const verifyToken = (whatsappWebhookVerifyToken.value() || process.env.WHATSAPP_WEBHOOK_VERIFY_TOKEN || '').trim();
    if (req.method === 'GET') {
        const mode = String((_a = req.query['hub.mode']) !== null && _a !== void 0 ? _a : '').trim();
        const token = String((_b = req.query['hub.verify_token']) !== null && _b !== void 0 ? _b : '').trim();
        const challenge = String((_c = req.query['hub.challenge']) !== null && _c !== void 0 ? _c : '');
        if (!verifyToken) {
            (0, logger_1.logWarning)('WhatsApp/Webhook', 'verify', 'Missing WHATSAPP_WEBHOOK_VERIFY_TOKEN');
            res.status(403).send('Verify token not configured');
            return;
        }
        if (mode === 'subscribe' && token === verifyToken) {
            (0, logger_1.logInfo)('WhatsApp/Webhook', 'verify', 'Webhook verified');
            res.status(200).type('text/plain').send(challenge);
            return;
        }
        (0, logger_1.logWarning)('WhatsApp/Webhook', 'verify', 'Webhook verification failed', {
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
        const body = req.body;
        const entries = Array.isArray(body === null || body === void 0 ? void 0 : body.entry) ? (_d = body === null || body === void 0 ? void 0 : body.entry) !== null && _d !== void 0 ? _d : [] : [];
        const statuses = [];
        for (const entry of entries) {
            const changes = Array.isArray(entry === null || entry === void 0 ? void 0 : entry.changes) ? (_e = entry.changes) !== null && _e !== void 0 ? _e : [] : [];
            for (const change of changes) {
                const changeStatuses = Array.isArray((_f = change === null || change === void 0 ? void 0 : change.value) === null || _f === void 0 ? void 0 : _f.statuses) ? (_h = (_g = change.value) === null || _g === void 0 ? void 0 : _g.statuses) !== null && _h !== void 0 ? _h : [] : [];
                statuses.push(...changeStatuses);
            }
        }
        if (statuses.length === 0) {
            (0, logger_1.logInfo)('WhatsApp/Webhook', 'handle', 'No status updates in webhook payload');
            res.status(200).send('ok');
            return;
        }
        let updatedCount = 0;
        for (const statusPayload of statuses) {
            const messageId = statusPayload === null || statusPayload === void 0 ? void 0 : statusPayload.id;
            const deliveryStatus = (_j = statusPayload === null || statusPayload === void 0 ? void 0 : statusPayload.status) !== null && _j !== void 0 ? _j : 'unknown';
            const recipientId = statusPayload === null || statusPayload === void 0 ? void 0 : statusPayload.recipient_id;
            if (!messageId) {
                (0, logger_1.logWarning)('WhatsApp/Webhook', 'handle', 'Missing message id in status payload', {
                    recipientId,
                    deliveryStatus,
                });
                continue;
            }
            const snapshot = await db
                .collection(constants_1.WHATSAPP_MESSAGE_JOBS_COLLECTION)
                .where('whatsapp_message_id', '==', messageId)
                .limit(10)
                .get();
            if (snapshot.empty) {
                (0, logger_1.logWarning)('WhatsApp/Webhook', 'handle', 'No WhatsApp job found for message id', {
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
                const errors = Array.isArray(statusPayload === null || statusPayload === void 0 ? void 0 : statusPayload.errors) ? statusPayload.errors : [];
                const error = errors[0];
                if (error) {
                    (0, logger_1.logError)('WhatsApp/Webhook', 'handle', 'WhatsApp delivery failed', new Error('WhatsApp status failed'), {
                        messageId,
                        recipientId,
                        errorCode: error.code,
                        errorMessage: (_k = error.message) !== null && _k !== void 0 ? _k : error.title,
                    });
                }
                else {
                    (0, logger_1.logError)('WhatsApp/Webhook', 'handle', 'WhatsApp delivery failed without error details', new Error('WhatsApp status failed'), {
                        messageId,
                        recipientId,
                    });
                }
            }
        }
        (0, logger_1.logInfo)('WhatsApp/Webhook', 'handle', 'Webhook processed', {
            updatedCount,
            statusCount: statuses.length,
        });
        res.status(200).send('ok');
    }
    catch (err) {
        (0, logger_1.logError)('WhatsApp/Webhook', 'handle', 'Failed to process webhook payload', err instanceof Error ? err : new Error(String(err)));
        res.status(200).send('ok');
    }
});
//# sourceMappingURL=whatsapp-webhook.js.map