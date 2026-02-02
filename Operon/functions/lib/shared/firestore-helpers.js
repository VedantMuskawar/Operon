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
exports.getCreationDate = getCreationDate;
exports.seedAnalyticsDoc = seedAnalyticsDoc;
exports.seedEmployeeAnalyticsDoc = seedEmployeeAnalyticsDoc;
exports.seedVendorAnalyticsDoc = seedVendorAnalyticsDoc;
exports.seedDeliveriesAnalyticsDoc = seedDeliveriesAnalyticsDoc;
exports.seedProductionsAnalyticsDoc = seedProductionsAnalyticsDoc;
exports.seedTripWagesAnalyticsDoc = seedTripWagesAnalyticsDoc;
exports.getFirestore = getFirestore;
const admin = __importStar(require("firebase-admin"));
const constants_1 = require("./constants");
const db = admin.firestore();
/**
 * Get creation date from a Firestore document snapshot
 */
function getCreationDate(snapshot) {
    var _a, _b;
    const createdAt = snapshot.get('createdAt');
    if (createdAt) {
        return createdAt.toDate();
    }
    return (_b = (_a = snapshot.createTime) === null || _a === void 0 ? void 0 : _a.toDate()) !== null && _b !== void 0 ? _b : new Date();
}
/**
 * Seed/initialize an analytics document with default structure
 */
async function seedAnalyticsDoc(docRef, fyLabel, organizationId) {
    await docRef.set(Object.assign(Object.assign({ source: constants_1.SOURCE_KEY, financialYear: fyLabel }, (organizationId && { organizationId })), { generatedAt: admin.firestore.FieldValue.serverTimestamp(), 'metadata.sourceCollections': admin.firestore.FieldValue.arrayUnion('CLIENTS'), 'metrics.activeClients.type': 'monthly', 'metrics.activeClients.unit': 'count', 'metrics.userOnboarding.type': 'monthly', 'metrics.userOnboarding.unit': 'count' }), { merge: true });
}
/**
 * Seed/initialize an employee analytics document with default structure
 */
async function seedEmployeeAnalyticsDoc(docRef, fyLabel, organizationId) {
    await docRef.set(Object.assign(Object.assign({ source: constants_1.EMPLOYEES_SOURCE_KEY, financialYear: fyLabel }, (organizationId && { organizationId })), { generatedAt: admin.firestore.FieldValue.serverTimestamp(), 'metadata.sourceCollections': admin.firestore.FieldValue.arrayUnion('EMPLOYEES', 'TRANSACTIONS'), 'metrics.wagesCreditMonthly.type': 'monthly', 'metrics.wagesCreditMonthly.unit': 'currency' }), { merge: true });
}
/**
 * Seed/initialize a vendor analytics document with default structure
 */
async function seedVendorAnalyticsDoc(docRef, fyLabel, organizationId) {
    await docRef.set(Object.assign(Object.assign({ source: constants_1.VENDORS_SOURCE_KEY, financialYear: fyLabel }, (organizationId && { organizationId })), { generatedAt: admin.firestore.FieldValue.serverTimestamp(), 'metadata.sourceCollections': admin.firestore.FieldValue.arrayUnion('VENDORS', 'TRANSACTIONS'), 'metrics.purchasesByVendorType.type': 'monthly', 'metrics.purchasesByVendorType.unit': 'currency' }), { merge: true });
}
/**
 * Seed/initialize a deliveries analytics document with default structure
 */
async function seedDeliveriesAnalyticsDoc(docRef, fyLabel, organizationId) {
    await docRef.set(Object.assign(Object.assign({ source: constants_1.DELIVERIES_SOURCE_KEY, financialYear: fyLabel }, (organizationId && { organizationId })), { generatedAt: admin.firestore.FieldValue.serverTimestamp(), 'metadata.sourceCollections': admin.firestore.FieldValue.arrayUnion('DELIVERY_MEMOS') }), { merge: true });
}
/**
 * Seed/initialize a productions analytics document with default structure
 */
async function seedProductionsAnalyticsDoc(docRef, fyLabel, organizationId) {
    await docRef.set(Object.assign(Object.assign({ source: constants_1.PRODUCTIONS_SOURCE_KEY, financialYear: fyLabel }, (organizationId && { organizationId })), { generatedAt: admin.firestore.FieldValue.serverTimestamp(), 'metadata.sourceCollections': admin.firestore.FieldValue.arrayUnion('PRODUCTION_BATCHES') }), { merge: true });
}
/**
 * Seed/initialize a trip wages analytics document with default structure
 */
async function seedTripWagesAnalyticsDoc(docRef, fyLabel, organizationId) {
    await docRef.set(Object.assign(Object.assign({ source: constants_1.TRIP_WAGES_ANALYTICS_SOURCE_KEY, financialYear: fyLabel }, (organizationId && { organizationId })), { generatedAt: admin.firestore.FieldValue.serverTimestamp(), 'metadata.sourceCollections': admin.firestore.FieldValue.arrayUnion('TRIP_WAGES', 'TRANSACTIONS') }), { merge: true });
}
/**
 * Get Firestore database instance
 */
function getFirestore() {
    return db;
}
//# sourceMappingURL=firestore-helpers.js.map