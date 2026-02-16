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
exports.onPaveDefOrderWritten = exports.onPaveClientWritten = void 0;
const admin = __importStar(require("firebase-admin"));
const firestore_1 = require("firebase-functions/v2/firestore");
const constants_1 = require("../shared/constants");
const function_config_1 = require("../shared/function-config");
const TARGET_APP_NAME = 'pave-operon-sync-target';
function parseBoolean(value, defaultValue) {
    if (value === null || value === undefined || value === '')
        return defaultValue;
    if (typeof value === 'boolean')
        return value;
    if (typeof value === 'number')
        return value !== 0;
    const normalized = String(value).trim().toLowerCase();
    if (['true', 'yes', 'y', '1'].includes(normalized))
        return true;
    if (['false', 'no', 'n', '0'].includes(normalized))
        return false;
    return defaultValue;
}
function resolveUpdateMode(value) {
    const normalized = (value || 'merge').toLowerCase();
    if (normalized === 'skip' || normalized === 'merge' || normalized === 'replace') {
        return normalized;
    }
    return 'merge';
}
function readServiceAccountFromEnv() {
    const jsonRaw = process.env.SYNC_TARGET_SERVICE_ACCOUNT_JSON;
    if (jsonRaw) {
        try {
            return JSON.parse(jsonRaw);
        }
        catch (error) {
            console.error('[Sync] Failed to parse SYNC_TARGET_SERVICE_ACCOUNT_JSON', error);
        }
    }
    const base64 = process.env.SYNC_TARGET_SERVICE_ACCOUNT_JSON_BASE64;
    if (base64) {
        try {
            const decoded = Buffer.from(base64, 'base64').toString('utf8');
            return JSON.parse(decoded);
        }
        catch (error) {
            console.error('[Sync] Failed to parse SYNC_TARGET_SERVICE_ACCOUNT_JSON_BASE64', error);
        }
    }
    return undefined;
}
function resolveSyncConfig() {
    const updateMode = resolveUpdateMode(process.env.SYNC_UPDATE_MODE);
    return {
        enabled: parseBoolean(process.env.SYNC_ENABLED, false),
        legacyOrgId: process.env.SYNC_LEGACY_ORG_ID,
        targetOrgId: process.env.SYNC_TARGET_ORG_ID,
        legacyClientsCollection: process.env.SYNC_LEGACY_CLIENTS_COLLECTION || 'CLIENTS',
        legacyDefOrdersCollection: process.env.SYNC_LEGACY_DEF_ORDERS_COLLECTION || 'DEF_ORDERS',
        clientMapCollection: process.env.SYNC_CLIENT_MAP_COLLECTION || 'CLIENT_ID_MAP',
        updateMode,
        deleteOnLegacyDelete: parseBoolean(process.env.SYNC_DELETE_ON_LEGACY_DELETE, false),
        targetProjectId: process.env.SYNC_TARGET_PROJECT_ID,
        targetServiceAccount: readServiceAccountFromEnv(),
    };
}
function getTargetFirestore(config) {
    var _a, _b;
    try {
        const existingApp = admin.apps.find((app) => (app === null || app === void 0 ? void 0 : app.name) === TARGET_APP_NAME);
        if (existingApp) {
            return existingApp.firestore();
        }
        if (config.targetServiceAccount || config.targetProjectId) {
            const app = admin.initializeApp({
                credential: config.targetServiceAccount
                    ? admin.credential.cert(config.targetServiceAccount)
                    : undefined,
                projectId: config.targetProjectId ||
                    ((_a = config.targetServiceAccount) === null || _a === void 0 ? void 0 : _a.project_id) ||
                    ((_b = config.targetServiceAccount) === null || _b === void 0 ? void 0 : _b.projectId),
            }, TARGET_APP_NAME);
            return app.firestore();
        }
        console.warn('[Sync] Target project credentials not provided; defaulting to current app.');
        return admin.firestore();
    }
    catch (error) {
        console.error('[Sync] Failed to initialize target Firestore', error);
        return null;
    }
}
function normalizePhone(input) {
    if (!input)
        return '';
    return input.replace(/[^0-9+]/g, '');
}
function normalizeName(name) {
    return (name || '').trim().toLowerCase();
}
function slugify(value) {
    return (value || 'product')
        .trim()
        .toLowerCase()
        .replace(/[^a-z0-9]+/g, '-')
        .replace(/(^-|-$)+/g, '') || 'product';
}
function titleCase(value) {
    if (!value)
        return '';
    return value
        .trim()
        .toLowerCase()
        .replace(/\s+/g, ' ')
        .split(' ')
        .map((word) => (word ? word[0].toUpperCase() + word.slice(1) : ''))
        .join(' ')
        .trim();
}
async function ensureDeliveryZone(targetDb, organizationId, cityName, regionName, product, unitPrice) {
    var _a;
    if (!cityName || !regionName)
        return null;
    const citiesRef = targetDb
        .collection('ORGANIZATIONS')
        .doc(organizationId)
        .collection('DELIVERY_CITIES');
    const zonesRef = targetDb
        .collection('ORGANIZATIONS')
        .doc(organizationId)
        .collection('DELIVERY_ZONES');
    const cityNameLc = normalizeName(cityName);
    let citySnapshot = await citiesRef.where('name', '==', cityName).limit(1).get();
    if (citySnapshot.empty) {
        citySnapshot = await citiesRef.where('name_lc', '==', cityNameLc).limit(1).get();
    }
    let cityId = citySnapshot.empty ? null : citySnapshot.docs[0].id;
    if (!cityId) {
        const newCityRef = citiesRef.doc();
        await newCityRef.set({
            name: cityName,
            name_lc: cityNameLc,
            created_at: admin.firestore.FieldValue.serverTimestamp(),
            updated_at: admin.firestore.FieldValue.serverTimestamp(),
        });
        cityId = newCityRef.id;
    }
    const zoneKey = `${cityId}::${regionName.toLowerCase()}`;
    const zoneSnapshot = await zonesRef.where('key', '==', zoneKey).limit(1).get();
    let zoneId = zoneSnapshot.empty ? null : zoneSnapshot.docs[0].id;
    if (!zoneId) {
        const newZoneRef = zonesRef.doc();
        await newZoneRef.set({
            key: zoneKey,
            city_id: cityId,
            region: regionName,
            region_name: regionName,
            prices: {
                [product.productId]: {
                    deliverable: true,
                    product_name: product.productName,
                    unit_price: unitPrice,
                    updated_at: admin.firestore.FieldValue.serverTimestamp(),
                },
            },
            created_at: admin.firestore.FieldValue.serverTimestamp(),
            updated_at: admin.firestore.FieldValue.serverTimestamp(),
        });
        zoneId = newZoneRef.id;
    }
    else {
        const zoneRef = zonesRef.doc(zoneId);
        const zoneDoc = await zoneRef.get();
        const prices = (((_a = zoneDoc.data()) === null || _a === void 0 ? void 0 : _a.prices) || {});
        if (!prices[product.productId]) {
            await zoneRef.set({
                prices: {
                    [product.productId]: {
                        deliverable: true,
                        product_name: product.productName,
                        unit_price: unitPrice,
                        updated_at: admin.firestore.FieldValue.serverTimestamp(),
                    },
                },
                updated_at: admin.firestore.FieldValue.serverTimestamp(),
            }, { merge: true });
        }
    }
    return { cityId, zoneId, cityName, regionName };
}
async function ensureProduct(targetDb, organizationId, productName) {
    const normalizedName = productName.trim() || 'Product';
    const productsRef = targetDb
        .collection('ORGANIZATIONS')
        .doc(organizationId)
        .collection('PRODUCTS');
    const nameLc = normalizeName(normalizedName);
    const nameMatch = await productsRef.where('name_lc', '==', nameLc).limit(1).get();
    if (!nameMatch.empty) {
        const existingDoc = nameMatch.docs[0];
        return {
            productId: existingDoc.id,
            productName: String(existingDoc.data().name || normalizedName),
        };
    }
    const productId = `legacy-${slugify(normalizedName)}`;
    const productRef = productsRef.doc(productId);
    const snapshot = await productRef.get();
    if (!snapshot.exists) {
        await productRef.set({
            name: normalizedName,
            name_lc: nameLc,
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            source: 'legacy',
        });
    }
    return { productId, productName: normalizedName };
}
async function resolveTargetClientId(legacyClientId, targetDb, config) {
    var _a, _b, _c;
    try {
        const mapRef = targetDb.collection(config.clientMapCollection).doc(legacyClientId);
        const mapSnap = await mapRef.get();
        const mappedId = mapSnap.exists
            ? (((_a = mapSnap.data()) === null || _a === void 0 ? void 0 : _a.operonClientId) || ((_b = mapSnap.data()) === null || _b === void 0 ? void 0 : _b.clientId) || ((_c = mapSnap.data()) === null || _c === void 0 ? void 0 : _c.targetClientId))
            : undefined;
        if (mappedId) {
            return String(mappedId);
        }
        const newClientRef = targetDb.collection(constants_1.CLIENTS_COLLECTION).doc();
        await mapRef.set({
            legacyClientId,
            operonClientId: newClientRef.id,
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        }, { merge: true });
        return newClientRef.id;
    }
    catch (error) {
        console.error('[Sync] Failed to resolve target client mapping', {
            legacyClientId,
            error,
        });
        return null;
    }
}
function buildOperonClientPayload(data, targetClientId, config) {
    var _a, _b, _c, _d, _e;
    const phoneList = Array.isArray(data.phoneList) ? data.phoneList : [];
    const primaryPhone = normalizePhone(data.phoneNumber || phoneList[0]);
    const phoneIndex = [primaryPhone, ...phoneList.map((phone) => normalizePhone(phone))]
        .filter((phone) => phone)
        .filter((phone, index, arr) => arr.indexOf(phone) === index);
    const phones = phoneIndex.map((phone, index) => ({
        e164: phone,
        label: index === 0 ? 'main' : `phone_${index + 1}`,
    }));
    const createdAt = data.registeredTime || data.createdAt || admin.firestore.FieldValue.serverTimestamp();
    return {
        clientId: targetClientId,
        name: String(data.name || '').trim(),
        name_lc: normalizeName(data.name),
        organizationId: config.targetOrgId || data.orgID || data.organizationId,
        contacts: Array.isArray(data.contacts) ? data.contacts : [],
        phones,
        phoneIndex,
        primaryPhone,
        primaryPhoneNormalized: primaryPhone,
        currentBalance: Number((_b = (_a = data.totalBalance) !== null && _a !== void 0 ? _a : data.currentBalance) !== null && _b !== void 0 ? _b : 0),
        stats: {
            lifetimeAmount: Number((_d = (_c = data.totalRevenue) !== null && _c !== void 0 ? _c : data.lifetimeAmount) !== null && _d !== void 0 ? _d : 0),
            orders: Number((_e = data.totalOrders) !== null && _e !== void 0 ? _e : 0),
        },
        status: String(data.status || 'active').toLowerCase(),
        tags: Array.isArray(data.tags)
            ? data.tags
            : [data.orgName ? String(data.orgName) : 'Legacy'],
        createdAt,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        syncMetadata: {
            source: 'pave',
            legacyClientId: data.id || undefined,
            syncedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
    };
}
function formatDateOnly(value) {
    if (!value)
        return undefined;
    const date = value.toDate ? value.toDate() : new Date(value);
    if (Number.isNaN(date.getTime()))
        return undefined;
    const yyyy = date.getFullYear();
    const mm = `${date.getMonth() + 1}`.padStart(2, '0');
    const dd = `${date.getDate()}`.padStart(2, '0');
    return `${yyyy}-${mm}-${dd}`;
}
function buildOperonPendingOrderPayload(data, orderId, targetClientId, config, resolved) {
    var _a, _b, _c, _d;
    const productName = resolved.productName;
    const orderCount = Math.max(1, Math.floor(Number((_a = data.orderCount) !== null && _a !== void 0 ? _a : 0)) || 1);
    const productQuant = Number((_b = data.productQuant) !== null && _b !== void 0 ? _b : 0) || 0;
    const unitPrice = Number((_c = data.productUnitPrice) !== null && _c !== void 0 ? _c : 0) || 0;
    const fixedQuantityPerTrip = productQuant;
    const subtotal = fixedQuantityPerTrip * unitPrice * orderCount;
    const estimatedStartDate = formatDateOnly(data.expectedDeliveyDate || data.expectedDeliveryDate);
    return {
        orderId,
        orderKey: data.orderId || data.id || orderId,
        organizationId: config.targetOrgId || data.orgID || data.organizationId,
        clientId: targetClientId,
        clientName: String(data.clientName || '').trim(),
        clientPhone: normalizePhone(data.clientPhoneNumber || data.clientPhone || ''),
        name_lc: normalizeName(data.clientName),
        priority: String(data.priority || 'normal').toLowerCase(),
        status: String(data.status || 'pending').toLowerCase(),
        createdBy: 'sync',
        createdAt: data.createdTime || admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        advanceAmount: Number((_d = data.advanceAmount) !== null && _d !== void 0 ? _d : 0),
        deliveryZone: {
            city_name: resolved.cityName,
            region_name: resolved.regionName,
            region: resolved.regionName,
            zone_id: resolved.zoneId,
        },
        edd: estimatedStartDate
            ? {
                calculatedAt: admin.firestore.FieldValue.serverTimestamp(),
                estimatedStartDate,
                estimatedCompletionDate: estimatedStartDate,
            }
            : undefined,
        items: [
            {
                itemIndex: 0,
                productId: resolved.productId,
                productName,
                estimatedTrips: orderCount,
                scheduledTrips: 0,
                fixedQuantityPerTrip,
                unitPrice,
                subtotal,
                total: subtotal,
            },
        ],
        tripIds: [],
        totalScheduledTrips: 0,
        pricing: {
            subtotal,
            totalAmount: subtotal,
        },
        hasAvailableTrips: orderCount > 0,
        syncMetadata: {
            source: 'pave',
            legacyOrderId: data.id || undefined,
            syncedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
    };
}
async function upsertTargetDoc(docRef, payload, updateMode) {
    if (updateMode === 'replace') {
        await docRef.set(payload);
        return;
    }
    if (updateMode === 'merge') {
        await docRef.set(payload, { merge: true });
        return;
    }
    const existing = await docRef.get();
    if (!existing.exists) {
        await docRef.set(payload);
    }
}
const syncConfig = resolveSyncConfig();
exports.onPaveClientWritten = (0, firestore_1.onDocumentWritten)(Object.assign({ document: `${syncConfig.legacyClientsCollection}/{legacyClientId}` }, function_config_1.LIGHT_TRIGGER_OPTS), async (event) => {
    var _a, _b;
    if (!syncConfig.enabled)
        return;
    const targetDb = getTargetFirestore(syncConfig);
    if (!targetDb)
        return;
    const legacyClientId = event.params.legacyClientId;
    const after = (_a = event.data) === null || _a === void 0 ? void 0 : _a.after;
    if (!after || !after.exists) {
        if (!syncConfig.deleteOnLegacyDelete)
            return;
        try {
            const mapRef = targetDb.collection(syncConfig.clientMapCollection).doc(legacyClientId);
            const mapSnap = await mapRef.get();
            const targetId = (_b = mapSnap.data()) === null || _b === void 0 ? void 0 : _b.operonClientId;
            if (targetId) {
                await targetDb.collection(constants_1.CLIENTS_COLLECTION).doc(String(targetId)).delete();
                await mapRef.delete();
            }
        }
        catch (error) {
            console.error('[Sync] Failed to delete target client on legacy delete', error);
        }
        return;
    }
    const data = after.data();
    if (!data) {
        return;
    }
    if (syncConfig.legacyOrgId && (data === null || data === void 0 ? void 0 : data.orgID) && data.orgID !== syncConfig.legacyOrgId) {
        return;
    }
    try {
        const targetClientId = await resolveTargetClientId(legacyClientId, targetDb, syncConfig);
        if (!targetClientId)
            return;
        const payload = buildOperonClientPayload(Object.assign(Object.assign({}, data), { id: legacyClientId }), targetClientId, syncConfig);
        const targetRef = targetDb.collection(constants_1.CLIENTS_COLLECTION).doc(targetClientId);
        await upsertTargetDoc(targetRef, payload, syncConfig.updateMode);
    }
    catch (error) {
        console.error('[Sync] Failed to sync legacy client', {
            legacyClientId,
            error,
        });
    }
});
exports.onPaveDefOrderWritten = (0, firestore_1.onDocumentWritten)(Object.assign({ document: `${syncConfig.legacyDefOrdersCollection}/{legacyOrderId}` }, function_config_1.LIGHT_TRIGGER_OPTS), async (event) => {
    var _a, _b, _c;
    if (!syncConfig.enabled)
        return;
    const targetDb = getTargetFirestore(syncConfig);
    if (!targetDb)
        return;
    const legacyOrderId = event.params.legacyOrderId;
    const after = (_a = event.data) === null || _a === void 0 ? void 0 : _a.after;
    if (!after || !after.exists) {
        if (!syncConfig.deleteOnLegacyDelete)
            return;
        try {
            const targetId = `pave_${legacyOrderId}`;
            await targetDb.collection(constants_1.PENDING_ORDERS_COLLECTION).doc(targetId).delete();
        }
        catch (error) {
            console.error('[Sync] Failed to delete target order on legacy delete', error);
        }
        return;
    }
    const data = after.data();
    if (!data) {
        return;
    }
    if (syncConfig.legacyOrgId && (data === null || data === void 0 ? void 0 : data.orgID) && data.orgID !== syncConfig.legacyOrgId) {
        return;
    }
    const orderCount = Number((_b = data === null || data === void 0 ? void 0 : data.orderCount) !== null && _b !== void 0 ? _b : 0);
    if (!Number.isFinite(orderCount) || orderCount <= 0) {
        return;
    }
    try {
        const legacyClientId = String(data.clientID || '').trim();
        if (!legacyClientId) {
            console.warn('[Sync] Missing legacy clientID in DEF_ORDERS', { legacyOrderId });
            return;
        }
        const targetClientId = await resolveTargetClientId(legacyClientId, targetDb, syncConfig);
        if (!targetClientId)
            return;
        const organizationId = String(syncConfig.targetOrgId || data.orgID || data.organizationId || '').trim();
        if (!organizationId) {
            console.warn('[Sync] Missing organizationId for DEF_ORDERS sync', { legacyOrderId });
            return;
        }
        const productName = String(data.productName || 'Product').trim();
        const product = await ensureProduct(targetDb, organizationId, productName);
        const unitPrice = Number((_c = data.productUnitPrice) !== null && _c !== void 0 ? _c : 0) || 0;
        const cityName = titleCase(String(data.regionName || data.city || '').trim());
        const regionName = titleCase(String(data.address || data.region || '').trim());
        const deliveryZone = await ensureDeliveryZone(targetDb, organizationId, cityName, regionName, product, unitPrice);
        const targetOrderId = `pave_${legacyOrderId}`;
        const payload = buildOperonPendingOrderPayload(Object.assign(Object.assign({}, data), { id: legacyOrderId }), targetOrderId, targetClientId, syncConfig, {
            zoneId: deliveryZone === null || deliveryZone === void 0 ? void 0 : deliveryZone.zoneId,
            cityName: (deliveryZone === null || deliveryZone === void 0 ? void 0 : deliveryZone.cityName) || cityName,
            regionName: (deliveryZone === null || deliveryZone === void 0 ? void 0 : deliveryZone.regionName) || regionName,
            productId: product.productId,
            productName: product.productName,
        });
        const targetRef = targetDb.collection(constants_1.PENDING_ORDERS_COLLECTION).doc(targetOrderId);
        await upsertTargetDoc(targetRef, payload, syncConfig.updateMode);
    }
    catch (error) {
        console.error('[Sync] Failed to sync DEF_ORDERS order', {
            legacyOrderId,
            error,
        });
    }
});
//# sourceMappingURL=pave-operon-sync.js.map