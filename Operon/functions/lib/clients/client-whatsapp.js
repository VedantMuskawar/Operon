"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.onClientCreatedSendWhatsappWelcome = void 0;
const firestore_1 = require("firebase-functions/v2/firestore");
const constants_1 = require("../shared/constants");
const logger_1 = require("../shared/logger");
const function_config_1 = require("../shared/function-config");
const whatsapp_message_queue_1 = require("../whatsapp/whatsapp-message-queue");
function buildJobId(eventId, fallbackParts) {
    if (eventId)
        return eventId;
    return fallbackParts.filter(Boolean).join('-');
}
async function enqueueWhatsappWelcomeMessage(to, clientName, organizationId, clientId, jobId) {
    const displayName = clientName && clientName.trim().length > 0
        ? clientName.trim()
        : 'there';
    (0, logger_1.logInfo)('Client/WhatsApp', 'enqueueWhatsappWelcomeMessage', 'Enqueuing welcome message', {
        organizationId,
        clientId,
        to: to.substring(0, 4) + '****',
    });
    await (0, whatsapp_message_queue_1.enqueueWhatsappMessage)(jobId, {
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
exports.onClientCreatedSendWhatsappWelcome = (0, firestore_1.onDocumentCreated)(Object.assign({ document: `${constants_1.CLIENTS_COLLECTION}/{clientId}` }, function_config_1.LIGHT_TRIGGER_OPTS), async (event) => {
    const snapshot = event.data;
    if (!snapshot)
        return;
    const data = snapshot.data();
    if (!data)
        return;
    const clientId = event.params.clientId;
    const phone = (data.primaryPhoneNormalized || data.primaryPhone || '').trim();
    if (!phone) {
        (0, logger_1.logWarning)('Client/WhatsApp', 'onClientCreatedSendWhatsappWelcome', 'No phone found on client, skipping welcome', {
            clientId,
        });
        return;
    }
    let organizationId = data.organizationId;
    if (!organizationId) {
        const defaultOrgId = process.env.WHATSAPP_DEFAULT_ORG_ID;
        if (defaultOrgId) {
            organizationId = defaultOrgId;
            (0, logger_1.logInfo)('Client/WhatsApp', 'onClientCreatedSendWhatsappWelcome', 'Using default org from env', {
                organizationId,
            });
        }
        else {
            (0, logger_1.logWarning)('Client/WhatsApp', 'onClientCreatedSendWhatsappWelcome', 'No organizationId on client and no default configured, skipping', {
                clientId,
            });
            return;
        }
    }
    const jobId = buildJobId(event.id, [clientId, 'client-welcome']);
    await enqueueWhatsappWelcomeMessage(phone, data.name, organizationId, clientId, jobId);
});
//# sourceMappingURL=client-whatsapp.js.map