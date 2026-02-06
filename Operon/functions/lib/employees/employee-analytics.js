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
exports.onEmployeeCreated = void 0;
exports.rebuildEmployeeAnalyticsCore = rebuildEmployeeAnalyticsCore;
const admin = __importStar(require("firebase-admin"));
const firestore_1 = require("firebase-functions/v2/firestore");
const constants_1 = require("../shared/constants");
const firestore_helpers_1 = require("../shared/firestore-helpers");
const date_helpers_1 = require("../shared/date-helpers");
const function_config_1 = require("../shared/function-config");
const db = (0, firestore_helpers_1.getFirestore)();
/**
 * Cloud Function: Triggered when an employee is created
 * Updates employee analytics for the organization
 */
exports.onEmployeeCreated = (0, firestore_1.onDocumentCreated)(Object.assign({ document: `${constants_1.EMPLOYEES_COLLECTION}/{employeeId}` }, function_config_1.LIGHT_TRIGGER_OPTS), async (event) => {
    const snapshot = event.data;
    if (!snapshot)
        return;
    const employeeData = snapshot.data();
    const organizationId = employeeData === null || employeeData === void 0 ? void 0 : employeeData.organizationId;
    if (!organizationId) {
        console.warn('[Employee Analytics] Employee created without organizationId', {
            employeeId: snapshot.id,
        });
        return;
    }
    const createdAt = (0, firestore_helpers_1.getCreationDate)(snapshot);
    const monthKey = (0, date_helpers_1.getYearMonth)(createdAt);
    const analyticsRef = db
        .collection(constants_1.ANALYTICS_COLLECTION)
        .doc(`${constants_1.EMPLOYEES_SOURCE_KEY}_${organizationId}_${monthKey}`);
    await (0, firestore_helpers_1.seedEmployeeAnalyticsDoc)(analyticsRef, monthKey, organizationId);
    await analyticsRef.set({
        generatedAt: admin.firestore.FieldValue.serverTimestamp(),
        'metrics.totalActiveEmployees': admin.firestore.FieldValue.increment(1),
    }, { merge: true });
});
/**
 * Core logic to rebuild employee analytics for all organizations.
 * Now writes to monthly documents instead of yearly.
 * Called by unified analytics scheduler.
 */
async function rebuildEmployeeAnalyticsCore(fyLabel) {
    const employeesSnapshot = await db.collection(constants_1.EMPLOYEES_COLLECTION).get();
    const employeesByOrg = {};
    employeesSnapshot.forEach((doc) => {
        var _a;
        const organizationId = (_a = doc.data()) === null || _a === void 0 ? void 0 : _a.organizationId;
        if (organizationId) {
            if (!employeesByOrg[organizationId]) {
                employeesByOrg[organizationId] = [];
            }
            employeesByOrg[organizationId].push(doc);
        }
    });
    const analyticsUpdates = Object.entries(employeesByOrg).map(async ([organizationId, orgEmployees]) => {
        const totalActiveEmployees = orgEmployees.length;
        const wageCreditsSnapshot = await db
            .collection(constants_1.TRANSACTIONS_COLLECTION)
            .where('organizationId', '==', organizationId)
            .where('ledgerType', '==', 'employeeLedger')
            .where('type', '==', 'credit')
            .where('category', '==', 'wageCredit')
            .get();
        // Group wages by month
        const wagesByMonth = {};
        wageCreditsSnapshot.forEach((doc) => {
            const transactionData = doc.data();
            const transactionDate = transactionData.transactionDate
                || transactionData.paymentDate
                || transactionData.createdAt;
            const amount = transactionData.amount || 0;
            if (transactionDate) {
                const dateObj = transactionDate.toDate();
                const monthKey = (0, date_helpers_1.getYearMonth)(dateObj);
                wagesByMonth[monthKey] = (wagesByMonth[monthKey] || 0) + amount;
            }
        });
        // Write to each month's document
        const monthPromises = Object.entries(wagesByMonth).map(async ([monthKey, wagesAmount]) => {
            const analyticsRef = db
                .collection(constants_1.ANALYTICS_COLLECTION)
                .doc(`${constants_1.EMPLOYEES_SOURCE_KEY}_${organizationId}_${monthKey}`);
            await (0, firestore_helpers_1.seedEmployeeAnalyticsDoc)(analyticsRef, monthKey, organizationId);
            await analyticsRef.set({
                generatedAt: admin.firestore.FieldValue.serverTimestamp(),
                'metrics.totalActiveEmployees': totalActiveEmployees,
                'metrics.wagesCreditMonthly': wagesAmount,
            }, { merge: true });
        });
        await Promise.all(monthPromises);
    });
    await Promise.all(analyticsUpdates);
    console.log(`[Employee Analytics] Rebuilt analytics for ${Object.keys(employeesByOrg).length} organizations`);
}
//# sourceMappingURL=employee-analytics.js.map