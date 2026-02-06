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
exports.onClientCreated = void 0;
exports.rebuildClientAnalyticsCore = rebuildClientAnalyticsCore;
const admin = __importStar(require("firebase-admin"));
const firestore_1 = require("firebase-functions/v2/firestore");
const constants_1 = require("../shared/constants");
const firestore_helpers_1 = require("../shared/firestore-helpers");
const date_helpers_1 = require("../shared/date-helpers");
const function_config_1 = require("../shared/function-config");
const db = (0, firestore_helpers_1.getFirestore)();
/**
 * Cloud Function: Triggered when a client is created
 * Updates client analytics for the organization
 */
exports.onClientCreated = (0, firestore_1.onDocumentCreated)(Object.assign({ document: `${constants_1.CLIENTS_COLLECTION}/{clientId}` }, function_config_1.LIGHT_TRIGGER_OPTS), async (event) => {
    const snapshot = event.data;
    if (!snapshot)
        return;
    const clientData = snapshot.data();
    const organizationId = clientData === null || clientData === void 0 ? void 0 : clientData.organizationId;
    if (!organizationId) {
        console.warn('[Client Analytics] Client created without organizationId', {
            clientId: snapshot.id,
        });
        return;
    }
    const createdAt = (0, firestore_helpers_1.getCreationDate)(snapshot);
    const monthKey = (0, date_helpers_1.getYearMonth)(createdAt);
    const analyticsRef = db
        .collection(constants_1.ANALYTICS_COLLECTION)
        .doc(`${constants_1.SOURCE_KEY}_${organizationId}_${monthKey}`);
    await (0, firestore_helpers_1.seedAnalyticsDoc)(analyticsRef, monthKey, organizationId);
    await analyticsRef.set({
        generatedAt: admin.firestore.FieldValue.serverTimestamp(),
        'metrics.totalActiveClients': admin.firestore.FieldValue.increment(1),
        'metrics.userOnboarding': admin.firestore.FieldValue.increment(1),
    }, { merge: true });
});
/**
 * Core logic to rebuild client analytics for all organizations.
 * Now writes to monthly documents instead of yearly.
 * Called by unified analytics scheduler.
 */
async function rebuildClientAnalyticsCore(fyLabel, fyStart, fyEnd) {
    const clientsSnapshot = await db.collection(constants_1.CLIENTS_COLLECTION).get();
    const clientsByOrg = {};
    clientsSnapshot.forEach((doc) => {
        var _a;
        const organizationId = (_a = doc.data()) === null || _a === void 0 ? void 0 : _a.organizationId;
        if (organizationId) {
            if (!clientsByOrg[organizationId]) {
                clientsByOrg[organizationId] = [];
            }
            clientsByOrg[organizationId].push(doc);
        }
    });
    // Group clients by organization and month
    const clientsByOrgMonth = {};
    Object.entries(clientsByOrg).forEach(([organizationId, orgClients]) => {
        clientsByOrgMonth[organizationId] = {};
        orgClients.forEach((doc) => {
            const createdAt = (0, firestore_helpers_1.getCreationDate)(doc);
            if (createdAt >= fyStart && createdAt < fyEnd) {
                const monthKey = (0, date_helpers_1.getYearMonth)(createdAt);
                if (!clientsByOrgMonth[organizationId][monthKey]) {
                    clientsByOrgMonth[organizationId][monthKey] = [];
                }
                clientsByOrgMonth[organizationId][monthKey].push(doc);
            }
        });
    });
    const analyticsUpdates = [];
    Object.entries(clientsByOrgMonth).forEach(([organizationId, monthClients]) => {
        // Calculate total active clients (all clients, not just in FY)
        const totalActiveClients = clientsByOrg[organizationId].length;
        Object.entries(monthClients).forEach(([monthKey, monthDocs]) => {
            const analyticsRef = db
                .collection(constants_1.ANALYTICS_COLLECTION)
                .doc(`${constants_1.SOURCE_KEY}_${organizationId}_${monthKey}`);
            const onboardingCount = monthDocs.length;
            analyticsUpdates.push((0, firestore_helpers_1.seedAnalyticsDoc)(analyticsRef, monthKey, organizationId).then(async () => {
                await analyticsRef.set({
                    generatedAt: admin.firestore.FieldValue.serverTimestamp(),
                    'metrics.totalActiveClients': totalActiveClients,
                    'metrics.userOnboarding': onboardingCount,
                }, { merge: true });
            }));
        });
    });
    await Promise.all(analyticsUpdates);
    console.log(`[Client Analytics] Rebuilt analytics for ${Object.keys(clientsByOrg).length} organizations`);
}
//# sourceMappingURL=client-analytics.js.map