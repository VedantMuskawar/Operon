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
const functions = __importStar(require("firebase-functions"));
const constants_1 = require("../shared/constants");
const financial_year_1 = require("../shared/financial-year");
const firestore_helpers_1 = require("../shared/firestore-helpers");
const date_helpers_1 = require("../shared/date-helpers");
const db = (0, firestore_helpers_1.getFirestore)();
/**
 * Cloud Function: Triggered when an employee is created
 * Updates employee analytics for the organization
 */
exports.onEmployeeCreated = functions.firestore
    .document(`${constants_1.EMPLOYEES_COLLECTION}/{employeeId}`)
    .onCreate(async (snapshot) => {
    const employeeData = snapshot.data();
    const organizationId = employeeData === null || employeeData === void 0 ? void 0 : employeeData.organizationId;
    if (!organizationId) {
        console.warn('[Employee Analytics] Employee created without organizationId', {
            employeeId: snapshot.id,
        });
        return;
    }
    const createdAt = (0, firestore_helpers_1.getCreationDate)(snapshot);
    const { fyLabel } = (0, financial_year_1.getFinancialContext)(createdAt);
    const analyticsRef = db
        .collection(constants_1.ANALYTICS_COLLECTION)
        .doc(`${constants_1.EMPLOYEES_SOURCE_KEY}_${organizationId}_${fyLabel}`);
    await (0, firestore_helpers_1.seedEmployeeAnalyticsDoc)(analyticsRef, fyLabel, organizationId);
    await analyticsRef.set({
        generatedAt: admin.firestore.FieldValue.serverTimestamp(),
        'metrics.totalActiveEmployees': admin.firestore.FieldValue.increment(1),
    }, { merge: true });
});
/**
 * Core logic to rebuild employee analytics for all organizations.
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
        const analyticsRef = db
            .collection(constants_1.ANALYTICS_COLLECTION)
            .doc(`${constants_1.EMPLOYEES_SOURCE_KEY}_${organizationId}_${fyLabel}`);
        const totalActiveEmployees = orgEmployees.length;
        const wageCreditsSnapshot = await db
            .collection(constants_1.TRANSACTIONS_COLLECTION)
            .where('organizationId', '==', organizationId)
            .where('ledgerType', '==', 'employeeLedger')
            .where('type', '==', 'credit')
            .where('category', '==', 'wageCredit')
            .get();
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
        await (0, firestore_helpers_1.seedEmployeeAnalyticsDoc)(analyticsRef, fyLabel, organizationId);
        await analyticsRef.set({
            generatedAt: admin.firestore.FieldValue.serverTimestamp(),
            'metrics.totalActiveEmployees': totalActiveEmployees,
            'metrics.wagesCreditMonthly.values': wagesByMonth,
        }, { merge: true });
    });
    await Promise.all(analyticsUpdates);
    console.log(`[Employee Analytics] Rebuilt analytics for ${Object.keys(employeesByOrg).length} organizations`);
}
//# sourceMappingURL=employee-analytics.js.map