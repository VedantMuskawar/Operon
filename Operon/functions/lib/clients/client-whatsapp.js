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
const firestore_helpers_1 = require("../shared/firestore-helpers");
const db = (0, firestore_helpers_1.getFirestore)();
async function loadWhatsappSettings(organizationId) {
    var _a;
    // First, try to load organization-specific settings
    if (organizationId) {
        // Trim whitespace from organizationId to handle document IDs with leading/trailing spaces
        const trimmedOrgId = organizationId.trim();
        const collectionName = 'WHATSAPP_SETTINGS';
        const orgSettingsRef = db.collection(collectionName).doc(trimmedOrgId);
        const docPath = `${collectionName}/${trimmedOrgId}`;
        console.log('[WhatsApp] Attempting to load org settings', {
            organizationId,
            trimmedOrgId,
            docPath,
            collectionName,
        });
        const orgSettingsDoc = await orgSettingsRef.get();
        console.log('[WhatsApp] Document read result', {
            organizationId,
            trimmedOrgId,
            docPath,
            exists: orgSettingsDoc.exists,
            hasData: !!orgSettingsDoc.data(),
        });
        if (orgSettingsDoc.exists) {
            const data = orgSettingsDoc.data();
            console.log('[WhatsApp] Found org settings document', {
                organizationId,
                trimmedOrgId,
                docPath,
                enabled: data === null || data === void 0 ? void 0 : data.enabled,
                enabledType: typeof (data === null || data === void 0 ? void 0 : data.enabled),
                hasToken: !!(data === null || data === void 0 ? void 0 : data.token),
                hasPhoneId: !!(data === null || data === void 0 ? void 0 : data.phoneId),
                dataKeys: data ? Object.keys(data) : [],
            });
            if (data && data.enabled === true) {
                if (!data.token || !data.phoneId) {
                    console.log('[WhatsApp] Org settings missing token or phoneId', {
                        organizationId,
                        trimmedOrgId,
                        hasToken: !!data.token,
                        hasPhoneId: !!data.phoneId,
                    });
                    return null;
                }
                return {
                    enabled: true,
                    token: data.token,
                    phoneId: data.phoneId,
                    welcomeTemplateId: data.welcomeTemplateId,
                    languageCode: data.languageCode,
                };
            }
            else {
                // Org has settings but WhatsApp is disabled for them
                console.log('[WhatsApp] Org settings exist but enabled is false or missing', {
                    organizationId,
                    trimmedOrgId,
                    enabled: data === null || data === void 0 ? void 0 : data.enabled,
                    enabledType: typeof (data === null || data === void 0 ? void 0 : data.enabled),
                });
                return null;
            }
        }
        else {
            // Try to list documents in the collection to debug
            try {
                const snapshot = await db.collection(collectionName).limit(5).get();
                const existingDocIds = snapshot.docs.map((doc) => doc.id);
                console.log('[WhatsApp] No org settings document found', {
                    organizationId,
                    trimmedOrgId,
                    collection: collectionName,
                    docPath,
                    lookingFor: trimmedOrgId,
                    existingDocIds,
                    docCount: snapshot.size,
                });
            }
            catch (error) {
                console.error('[WhatsApp] Error checking collection', { organizationId, trimmedOrgId, collection: collectionName, error });
            }
        }
    }
    // Fallback to global config (for backward compatibility)
    const globalConfig = (_a = functions.config().whatsapp) !== null && _a !== void 0 ? _a : {};
    if (globalConfig.token &&
        globalConfig.phone_id &&
        globalConfig.enabled !== 'false') {
        console.log('[WhatsApp] Using global config fallback');
        return {
            enabled: true,
            token: globalConfig.token,
            phoneId: globalConfig.phone_id,
            welcomeTemplateId: globalConfig.welcome_template_id,
            languageCode: globalConfig.language_code,
        };
    }
    console.log('[WhatsApp] No settings found (neither org-specific nor global)');
    return null;
}
async function sendWhatsappWelcomeMessage(to, clientName, organizationId, clientId) {
    var _a, _b, _c, _d, _e;
    const settings = await loadWhatsappSettings(organizationId);
    if (!settings) {
        console.log('[WhatsApp] Skipping send – no settings or disabled.', { clientId, organizationId });
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
    console.log('[WhatsApp] Sending welcome message', {
        organizationId,
        clientId,
        to: to.substring(0, 4) + '****', // Mask phone number
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
        console.error('[WhatsApp] Failed to send welcome message', {
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
                console.error('[WhatsApp] Phone Number ID issue:', 'The Phone Number ID does not exist, lacks permissions, or belongs to a different WhatsApp Business Account.', 'Verify in Meta Business Suite that:', '1. Phone Number ID matches the one in your settings', '2. Access token has permission for this Phone Number ID', '3. Both token and Phone Number ID belong to the same WhatsApp Business Account');
            }
        }
    }
    else {
        const result = await response.json().catch(() => ({}));
        console.log('[WhatsApp] Welcome message sent successfully', {
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
        console.log('[WhatsApp] No phone found on client, skipping welcome.', context.params.clientId);
        return;
    }
    // Try to get organizationId from client document, or use default
    let organizationId = data.organizationId;
    if (!organizationId) {
        // Fallback: try to infer from global config or use a default org
        const globalConfig = (_a = functions.config().whatsapp) !== null && _a !== void 0 ? _a : {};
        if (globalConfig.default_org_id) {
            organizationId = globalConfig.default_org_id;
            console.log('[WhatsApp] Using default org from config', organizationId);
        }
        else {
            console.log('[WhatsApp] No organizationId on client and no default configured, skipping.', context.params.clientId);
            return;
        }
    }
    await sendWhatsappWelcomeMessage(phone, data.name, organizationId, context.params.clientId);
});
//# sourceMappingURL=client-whatsapp.js.map