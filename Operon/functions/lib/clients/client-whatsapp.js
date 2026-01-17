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
exports.onClientCreatedSendWhatsappWelcome = void 0;
const functions = __importStar(require("firebase-functions"));
const constants_1 = require("../shared/constants");
const whatsapp_service_1 = require("../shared/whatsapp-service");
const logger_1 = require("../shared/logger");
async function sendWhatsappWelcomeMessage(to, clientName, organizationId, clientId) {
    var _a, _b, _c, _d, _e;
    const settings = await (0, whatsapp_service_1.loadWhatsappSettings)(organizationId, true); // verbose=true for client welcome
    if (!settings) {
        (0, logger_1.logWarning)('Client/WhatsApp', 'sendWhatsappWelcomeMessage', 'Skipping send – no settings or disabled', {
            clientId,
            organizationId,
        });
        return;
    }
    const url = `https://graph.facebook.com/v19.0/${settings.phoneId}/messages`;
    const displayName = clientName && clientName.trim().length > 0
        ? clientName.trim()
        : 'there';
    // Mask token for logging (show first 10 chars only)
    const maskedToken = settings.token
        ? `${settings.token.substring(0, 10)}...${settings.token.substring(settings.token.length - 4)}`
        : 'missing';
    (0, logger_1.logInfo)('Client/WhatsApp', 'sendWhatsappWelcomeMessage', 'Sending welcome message', {
        organizationId,
        clientId,
        to: to.substring(0, 4) + '****',
        phoneId: settings.phoneId,
        templateId: (_a = settings.welcomeTemplateId) !== null && _a !== void 0 ? _a : 'client_welcome',
        tokenPreview: maskedToken,
    });
    const payload = {
        messaging_product: 'whatsapp',
        to: to,
        type: 'template',
        template: {
            name: (_b = settings.welcomeTemplateId) !== null && _b !== void 0 ? _b : 'client_welcome',
            language: {
                code: (_c = settings.languageCode) !== null && _c !== void 0 ? _c : 'en',
            },
            components: [
                {
                    type: 'body',
                    parameters: [
                        {
                            type: 'text',
                            text: displayName,
                        },
                    ],
                },
            ],
        },
    };
    const response = await fetch(url, {
        method: 'POST',
        headers: {
            Authorization: `Bearer ${settings.token}`,
            'Content-Type': 'application/json',
        },
        body: JSON.stringify(payload),
    });
    if (!response.ok) {
        const text = await response.text();
        let errorDetails;
        try {
            errorDetails = JSON.parse(text);
        }
        catch (_f) {
            errorDetails = text;
        }
        (0, logger_1.logError)('Client/WhatsApp', 'sendWhatsappWelcomeMessage', 'Failed to send welcome message', new Error(`WhatsApp API error: ${response.status} ${response.statusText}`), {
            status: response.status,
            statusText: response.statusText,
            error: errorDetails,
            organizationId,
            clientId,
            phoneId: settings.phoneId,
            url,
        });
        // Provide helpful error messages for common issues
        if (response.status === 400 && (errorDetails === null || errorDetails === void 0 ? void 0 : errorDetails.error)) {
            const errorCode = errorDetails.error.code;
            const errorSubcode = errorDetails.error.error_subcode;
            if (errorCode === 100 && errorSubcode === 33) {
                (0, logger_1.logError)('Client/WhatsApp', 'sendWhatsappWelcomeMessage', 'Phone Number ID issue: The Phone Number ID does not exist, lacks permissions, or belongs to a different WhatsApp Business Account. Verify in Meta Business Suite that: 1. Phone Number ID matches the one in your settings, 2. Access token has permission for this Phone Number ID, 3. Both token and Phone Number ID belong to the same WhatsApp Business Account');
            }
        }
        throw new Error(`Failed to send WhatsApp welcome message: ${response.status} ${response.statusText}`);
    }
    else {
        const result = await response.json().catch(() => ({}));
        (0, logger_1.logInfo)('Client/WhatsApp', 'sendWhatsappWelcomeMessage', 'Welcome message sent successfully', {
            clientId,
            to: to.substring(0, 4) + '****',
            organizationId,
            messageId: (_e = (_d = result.messages) === null || _d === void 0 ? void 0 : _d[0]) === null || _e === void 0 ? void 0 : _e.id,
        });
    }
}
/**
 * Cloud Function: Triggered when a client is created
 * Sends a WhatsApp welcome message to the new client
 */
exports.onClientCreatedSendWhatsappWelcome = functions.firestore
    .document(`${constants_1.CLIENTS_COLLECTION}/{clientId}`)
    .onCreate(async (snapshot, context) => {
    var _a;
    const data = snapshot.data();
    if (!data)
        return;
    const phone = (data.primaryPhoneNormalized || data.primaryPhone || '').trim();
    if (!phone) {
        (0, logger_1.logWarning)('Client/WhatsApp', 'onClientCreatedSendWhatsappWelcome', 'No phone found on client, skipping welcome', {
            clientId: context.params.clientId,
        });
        return;
    }
    // Try to get organizationId from client document, or use default
    let organizationId = data.organizationId;
    if (!organizationId) {
        // Fallback: try to infer from global config or use a default org
        const globalConfig = (_a = functions.config().whatsapp) !== null && _a !== void 0 ? _a : {};
        if (globalConfig.default_org_id) {
            organizationId = globalConfig.default_org_id;
            (0, logger_1.logInfo)('Client/WhatsApp', 'onClientCreatedSendWhatsappWelcome', 'Using default org from config', {
                organizationId,
            });
        }
        else {
            (0, logger_1.logWarning)('Client/WhatsApp', 'onClientCreatedSendWhatsappWelcome', 'No organizationId on client and no default configured, skipping', {
                clientId: context.params.clientId,
            });
            return;
        }
    }
    await sendWhatsappWelcomeMessage(phone, data.name, organizationId, context.params.clientId);
});
//# sourceMappingURL=client-whatsapp.js.map