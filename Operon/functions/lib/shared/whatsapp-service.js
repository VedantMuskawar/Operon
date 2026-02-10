"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.sendWhatsappTemplateMessage = sendWhatsappTemplateMessage;
exports.loadWhatsappSettings = loadWhatsappSettings;
exports.sendWhatsappMessage = sendWhatsappMessage;
exports.normalizePhoneE164 = normalizePhoneE164;
exports.getWhatsappApiUrl = getWhatsappApiUrl;
exports.checkWhatsappMessageStatus = checkWhatsappMessageStatus;
const constants_1 = require("./constants");
const firestore_helpers_1 = require("./firestore-helpers");
const db = (0, firestore_helpers_1.getFirestore)();
const SETTINGS_CACHE_TTL_MS = 60000;
const settingsCache = new Map();
/**
 * Send WhatsApp template message using Meta Graph API
 *
 * @param url - Graph API endpoint URL
 * @param token - WhatsApp API token
 * @param to - Recipient phone number (E.164 format)
 * @param templateName - Template name to use
 * @param languageCode - Language code (default: 'en')
 * @param parameters - Array of text parameters for the template
 * @param messageType - Type of message for logging purposes
 * @param context - Context information for logging
 * @returns Promise that resolves when message is sent
 */
async function sendWhatsappTemplateMessage(url, token, to, templateName, languageCode, parameters, messageType, context) {
    var _a, _b;
    const payload = {
        messaging_product: 'whatsapp',
        to: to,
        type: 'template',
        template: {
            name: templateName,
            language: {
                code: languageCode,
            },
            components: [
                {
                    type: 'body',
                    parameters: parameters.map((param) => ({
                        type: 'text',
                        text: param,
                    })),
                },
            ],
        },
    };
    const response = await fetch(url, {
        method: 'POST',
        headers: {
            'Authorization': `Bearer ${token}`,
            'Content-Type': 'application/json',
        },
        body: JSON.stringify(payload),
    });
    if (!response.ok) {
        const errorText = await response.text();
        let errorDetails;
        try {
            errorDetails = JSON.parse(errorText);
        }
        catch (_c) {
            errorDetails = errorText;
        }
        throw new Error(`WhatsApp API error: ${response.status} ${response.statusText} - ${JSON.stringify(errorDetails)}`);
    }
    const result = await response.json();
    if (result.errors && result.errors.length > 0) {
        const errorMessages = result.errors.map((e) => e.message || 'Unknown error').join(', ');
        throw new Error(`WhatsApp API returned errors: ${errorMessages}`);
    }
    const messageId = (_b = (_a = result.messages) === null || _a === void 0 ? void 0 : _a[0]) === null || _b === void 0 ? void 0 : _b.id;
    console.log(`[WhatsApp Service] ${messageType} template message sent`, Object.assign(Object.assign({}, context), { to: to.substring(0, 4) + '****', templateName,
        messageId }));
    return messageId;
}
/**
 * Load WhatsApp settings for an organization
 * First tries organization-specific settings, then falls back to global config
 *
 * @param organizationId - Organization ID to load settings for
 * @param verbose - If true, logs detailed debug information
 * @returns WhatsApp settings or null if not enabled/configured
 */
async function loadWhatsappSettings(organizationId, verbose = false, useCache = true) {
    var _a, _b, _c, _d, _e, _f, _g, _h, _j, _k;
    const cacheKey = (organizationId === null || organizationId === void 0 ? void 0 : organizationId.trim()) || 'global';
    if (useCache) {
        const cached = settingsCache.get(cacheKey);
        if (cached && cached.expiresAt > Date.now()) {
            return cached.settings;
        }
    }
    // First, try to load organization-specific settings
    if (organizationId) {
        const trimmedOrgId = organizationId.trim();
        const orgSettingsRef = db.collection(constants_1.WHATSAPP_SETTINGS_COLLECTION).doc(trimmedOrgId);
        const docPath = `${constants_1.WHATSAPP_SETTINGS_COLLECTION}/${trimmedOrgId}`;
        if (verbose) {
            console.log('[WhatsApp Service] Attempting to load org settings', {
                organizationId,
                trimmedOrgId,
                docPath,
            });
        }
        const orgSettingsDoc = await orgSettingsRef.get();
        if (verbose) {
            console.log('[WhatsApp Service] Document read result', {
                organizationId,
                trimmedOrgId,
                docPath,
                exists: orgSettingsDoc.exists,
                hasData: !!orgSettingsDoc.data(),
            });
        }
        if (orgSettingsDoc.exists) {
            const data = orgSettingsDoc.data();
            if (verbose) {
                console.log('[WhatsApp Service] Found org settings document', {
                    organizationId,
                    trimmedOrgId,
                    docPath,
                    enabled: data === null || data === void 0 ? void 0 : data.enabled,
                    enabledType: typeof (data === null || data === void 0 ? void 0 : data.enabled),
                    hasToken: !!(data === null || data === void 0 ? void 0 : data.token),
                    hasPhoneId: !!(data === null || data === void 0 ? void 0 : data.phoneId),
                    dataKeys: data ? Object.keys(data) : [],
                });
            }
            if (data && data.enabled === true) {
                if (!data.token || !data.phoneId) {
                    if (verbose) {
                        console.log('[WhatsApp Service] Org settings missing token or phoneId', {
                            organizationId,
                            trimmedOrgId,
                            hasToken: !!data.token,
                            hasPhoneId: !!data.phoneId,
                        });
                    }
                    return null;
                }
                const settings = {
                    enabled: true,
                    token: data.token,
                    phoneId: data.phoneId,
                    welcomeTemplateId: (_a = data.welcomeTemplateId) !== null && _a !== void 0 ? _a : 'lakshmee_client_added',
                    languageCode: (_b = data.languageCode) !== null && _b !== void 0 ? _b : 'en',
                    orderConfirmationTemplateId: (_c = data.orderConfirmationTemplateId) !== null && _c !== void 0 ? _c : 'lakshmee_order_added',
                    tripDispatchTemplateId: (_d = data.tripDispatchTemplateId) !== null && _d !== void 0 ? _d : 'lakshmee_trip_dispatch',
                    tripDeliveryTemplateId: (_e = data.tripDeliveryTemplateId) !== null && _e !== void 0 ? _e : 'lakshmee_trip_delivered',
                };
                if (useCache) {
                    settingsCache.set(cacheKey, {
                        settings,
                        expiresAt: Date.now() + SETTINGS_CACHE_TTL_MS,
                    });
                }
                return settings;
            }
            else {
                if (verbose) {
                    console.log('[WhatsApp Service] Org settings exist but enabled is false or missing', {
                        organizationId,
                        trimmedOrgId,
                        enabled: data === null || data === void 0 ? void 0 : data.enabled,
                        enabledType: typeof (data === null || data === void 0 ? void 0 : data.enabled),
                    });
                }
                if (useCache) {
                    settingsCache.set(cacheKey, {
                        settings: null,
                        expiresAt: Date.now() + SETTINGS_CACHE_TTL_MS,
                    });
                }
                return null;
            }
        }
        else if (verbose) {
            // Try to list documents in the collection to debug
            try {
                const snapshot = await db.collection(constants_1.WHATSAPP_SETTINGS_COLLECTION).limit(5).get();
                const existingDocIds = snapshot.docs.map((doc) => doc.id);
                console.log('[WhatsApp Service] No org settings document found', {
                    organizationId,
                    trimmedOrgId,
                    collection: constants_1.WHATSAPP_SETTINGS_COLLECTION,
                    docPath,
                    lookingFor: trimmedOrgId,
                    existingDocIds,
                    docCount: snapshot.size,
                });
            }
            catch (error) {
                console.error('[WhatsApp Service] Error checking collection', {
                    organizationId,
                    trimmedOrgId,
                    collection: constants_1.WHATSAPP_SETTINGS_COLLECTION,
                    error,
                });
            }
        }
    }
    // Fallback to env (v2: no functions.config(); set WHATSAPP_* in Firebase config or env)
    const envToken = process.env.WHATSAPP_TOKEN;
    const envPhoneId = process.env.WHATSAPP_PHONE_ID;
    const envEnabled = process.env.WHATSAPP_ENABLED;
    if (envToken &&
        envPhoneId &&
        envEnabled !== 'false') {
        if (verbose) {
            console.log('[WhatsApp Service] Using env fallback');
        }
        const settings = {
            enabled: true,
            token: envToken,
            phoneId: envPhoneId,
            welcomeTemplateId: (_f = process.env.WHATSAPP_WELCOME_TEMPLATE_ID) !== null && _f !== void 0 ? _f : 'lakshmee_client_added',
            languageCode: (_g = process.env.WHATSAPP_LANGUAGE_CODE) !== null && _g !== void 0 ? _g : 'en',
            orderConfirmationTemplateId: (_h = process.env.WHATSAPP_ORDER_CONFIRMATION_TEMPLATE_ID) !== null && _h !== void 0 ? _h : 'lakshmee_order_added',
            tripDispatchTemplateId: (_j = process.env.WHATSAPP_TRIP_DISPATCH_TEMPLATE_ID) !== null && _j !== void 0 ? _j : 'lakshmee_trip_dispatch',
            tripDeliveryTemplateId: (_k = process.env.WHATSAPP_TRIP_DELIVERY_TEMPLATE_ID) !== null && _k !== void 0 ? _k : 'lakshmee_trip_delivered',
        };
        if (useCache) {
            settingsCache.set(cacheKey, {
                settings,
                expiresAt: Date.now() + SETTINGS_CACHE_TTL_MS,
            });
        }
        return settings;
    }
    if (verbose) {
        console.log('[WhatsApp Service] No settings found (neither org-specific nor global)');
    }
    if (useCache) {
        settingsCache.set(cacheKey, {
            settings: null,
            expiresAt: Date.now() + SETTINGS_CACHE_TTL_MS,
        });
    }
    return null;
}
/**
 * Send WhatsApp message using Meta Graph API
 *
 * @param url - Graph API endpoint URL
 * @param token - WhatsApp API token
 * @param to - Recipient phone number (E.164 format)
 * @param messageBody - Message text to send
 * @param messageType - Type of message for logging purposes
 * @param context - Context information for logging
 * @returns Promise that resolves when message is sent
 */
async function sendWhatsappMessage(url, token, to, messageBody, messageType, context) {
    var _a, _b;
    const response = await fetch(url, {
        method: 'POST',
        headers: {
            'Authorization': `Bearer ${token}`,
            'Content-Type': 'application/json',
        },
        body: JSON.stringify({
            messaging_product: 'whatsapp',
            to: to,
            type: 'text',
            text: {
                body: messageBody,
            },
        }),
    });
    if (!response.ok) {
        const errorText = await response.text();
        throw new Error(`WhatsApp API error: ${response.status} ${response.statusText} - ${errorText}`);
    }
    const result = await response.json();
    if (result.errors && result.errors.length > 0) {
        const errorMessages = result.errors.map((e) => e.message || 'Unknown error').join(', ');
        throw new Error(`WhatsApp API returned errors: ${errorMessages}`);
    }
    const messageId = (_b = (_a = result.messages) === null || _a === void 0 ? void 0 : _a[0]) === null || _b === void 0 ? void 0 : _b.id;
    console.log(`[WhatsApp Service] ${messageType} message sent`, Object.assign(Object.assign({}, context), { to: to.substring(0, 4) + '****', messageId }));
    return messageId;
}
function normalizePhoneE164(raw) {
    if (!raw)
        return null;
    const trimmed = raw.trim();
    if (!trimmed)
        return null;
    const normalized = trimmed.startsWith('+') ? trimmed : `+${trimmed}`;
    const digitsOnly = normalized.replace(/\D/g, '');
    if (digitsOnly.length < 8)
        return null;
    return normalized;
}
function getWhatsappApiUrl(phoneId) {
    var _a;
    const apiVersion = (_a = process.env.WHATSAPP_GRAPH_VERSION) !== null && _a !== void 0 ? _a : 'v19.0';
    return `https://graph.facebook.com/${apiVersion}/${phoneId}/messages`;
}
/**
 * Check WhatsApp message delivery status using Meta Graph API
 * Note: The Cloud API primarily uses webhooks for status updates, but this can help verify if a message was accepted
 *
 * @param messageId - The WhatsApp message ID (wamid.*) from the send response
 * @param phoneId - The WhatsApp Business Phone Number ID
 * @param token - WhatsApp API access token
 * @returns Promise with message status information
 */
async function checkWhatsappMessageStatus(messageId, phoneId, token) {
    // Note: The Cloud API doesn't have a direct "get status" endpoint
    // Status updates are sent via webhooks. However, we can verify the message was accepted
    // by checking if messageId is valid format
    if (!messageId || !messageId.startsWith('wamid.')) {
        throw new Error(`Invalid message ID format: ${messageId}. Expected format: wamid.*`);
    }
    console.log('[WhatsApp Service] Checking message status', {
        messageId,
        phoneId,
        note: 'Status updates are primarily delivered via webhooks. See Meta Business Suite for real-time status.',
    });
    // Return basic validation - actual status should be checked via webhooks
    return {
        messageId,
        note: 'Message ID is valid. To check delivery status: 1) Use Meta Business Suite 2) Set up webhooks 3) Check webhook payloads',
    };
}
//# sourceMappingURL=whatsapp-service.js.map