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
exports.rebuildClientAnalytics = exports.onClientCreated = void 0;
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
        [`metrics.activeClients.values.${monthKey}`]: admin.firestore.FieldValue.increment(1),
        [`metrics.userOnboarding.values.${monthKey}`]: admin.firestore.FieldValue.increment(1),
    }, { merge: true });
});
/**
 * Cloud Function: Scheduled function to rebuild client analytics
 * Runs every 24 hours to recalculate analytics for all organizations
 */
exports.rebuildClientAnalytics = functions.pubsub
    .schedule('every 24 hours')
    .timeZone('UTC')
    .onRun(async () => {
    const now = new Date();
    const { fyLabel, fyStart, fyEnd } = (0, financial_year_1.getFinancialContext)(now);
    // Get all clients and group by organizationId
    const clientsSnapshot = await db.collection(constants_1.CLIENTS_COLLECTION).get();
    // Group clients by organizationId
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
    // Process analytics for each organization
    const analyticsUpdates = Object.entries(clientsByOrg).map(async ([organizationId, orgClients]) => {
        const analyticsRef = db
            .collection(constants_1.ANALYTICS_COLLECTION)
            .doc(`${constants_1.SOURCE_KEY}_${organizationId}_${fyLabel}`);
        const onboardingCounts = {};
        const creationDates = [];
        orgClients.forEach((doc) => {
            var _a;
            const createdAt = (0, firestore_helpers_1.getCreationDate)(doc);
            if (createdAt < fyEnd) {
                creationDates.push(createdAt);
            }
            if (createdAt >= fyStart && createdAt < fyEnd) {
                const { monthKey } = (0, financial_year_1.getFinancialContext)(createdAt);
                onboardingCounts[monthKey] = ((_a = onboardingCounts[monthKey]) !== null && _a !== void 0 ? _a : 0) + 1;
            }
        });
        creationDates.sort((a, b) => a.getTime() - b.getTime());
        const activeCounts = {};
        let pointer = 0;
        for (let i = 0; i < 12; i += 1) {
            const iterMonth = new Date(Date.UTC(fyStart.getUTCFullYear(), fyStart.getUTCMonth() + i, 1));
            const monthKey = `${iterMonth.getUTCFullYear()}-${String(iterMonth.getUTCMonth() + 1).padStart(2, '0')}`;
            const monthEnd = new Date(iterMonth);
            monthEnd.setUTCMonth(monthEnd.getUTCMonth() + 1, 0);
            monthEnd.setUTCHours(23, 59, 59, 999);
            while (pointer < creationDates.length &&
                creationDates[pointer].getTime() <= monthEnd.getTime()) {
                pointer += 1;
            }
            activeCounts[monthKey] = pointer;
        }
        await (0, firestore_helpers_1.seedAnalyticsDoc)(analyticsRef, fyLabel, organizationId);
        await analyticsRef.set({
            generatedAt: admin.firestore.FieldValue.serverTimestamp(),
            'metrics.activeClients.values': activeCounts,
            'metrics.userOnboarding.values': onboardingCounts,
        }, { merge: true });
    });
    await Promise.all(analyticsUpdates);
    console.log(`[Client Analytics] Rebuilt analytics for ${Object.keys(clientsByOrg).length} organizations`);
});
//# sourceMappingURL=client-analytics.js.map