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
const functions = __importStar(require("firebase-functions"));
const constants_1 = require("../shared/constants");
const financial_year_1 = require("../shared/financial-year");
const firestore_helpers_1 = require("../shared/firestore-helpers");
const db = (0, firestore_helpers_1.getFirestore)();
/**
 * Cloud Function: Triggered when a client is created
 * Updates client analytics for the organization
 */
exports.onClientCreated = functions.firestore
    .document(`${constants_1.CLIENTS_COLLECTION}/{clientId}`)
    .onCreate(async (snapshot) => {
    const clientData = snapshot.data();
    const organizationId = clientData === null || clientData === void 0 ? void 0 : clientData.organizationId;
    if (!organizationId) {
        console.warn('[Client Analytics] Client created without organizationId', {
            clientId: snapshot.id,
        });
        return;
    }
    const createdAt = (0, firestore_helpers_1.getCreationDate)(snapshot);
    const { fyLabel, monthKey } = (0, financial_year_1.getFinancialContext)(createdAt);
    const analyticsRef = db
        .collection(constants_1.ANALYTICS_COLLECTION)
        .doc(`${constants_1.SOURCE_KEY}_${organizationId}_${fyLabel}`);
    await (0, firestore_helpers_1.seedAnalyticsDoc)(analyticsRef, fyLabel, organizationId);
    await analyticsRef.set({
        generatedAt: admin.firestore.FieldValue.serverTimestamp(),
        'metrics.totalActiveClients': admin.firestore.FieldValue.increment(1),
        [`metrics.userOnboarding.values.${monthKey}`]: admin.firestore.FieldValue.increment(1),
    }, { merge: true });
});
/**
 * Core logic to rebuild client analytics for all organizations.
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
    const analyticsUpdates = Object.entries(clientsByOrg).map(async ([organizationId, orgClients]) => {
        const analyticsRef = db
            .collection(constants_1.ANALYTICS_COLLECTION)
            .doc(`${constants_1.SOURCE_KEY}_${organizationId}_${fyLabel}`);
        const onboardingCounts = {};
        const totalActiveClients = orgClients.length;
        orgClients.forEach((doc) => {
            var _a;
            const createdAt = (0, firestore_helpers_1.getCreationDate)(doc);
            if (createdAt >= fyStart && createdAt < fyEnd) {
                const { monthKey } = (0, financial_year_1.getFinancialContext)(createdAt);
                onboardingCounts[monthKey] = ((_a = onboardingCounts[monthKey]) !== null && _a !== void 0 ? _a : 0) + 1;
            }
        });
        await (0, firestore_helpers_1.seedAnalyticsDoc)(analyticsRef, fyLabel, organizationId);
        await analyticsRef.set({
            generatedAt: admin.firestore.FieldValue.serverTimestamp(),
            'metrics.totalActiveClients': totalActiveClients,
            'metrics.userOnboarding.values': onboardingCounts,
        }, { merge: true });
    });
    await Promise.all(analyticsUpdates);
    console.log(`[Client Analytics] Rebuilt analytics for ${Object.keys(clientsByOrg).length} organizations`);
}
//# sourceMappingURL=client-analytics.js.map