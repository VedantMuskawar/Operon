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
exports.syncEmployeeBalance = exports.syncVendorBalance = exports.syncClientBalance = void 0;
// Use v1 for Firestore triggers for compatibility
const functions = __importStar(require("firebase-functions/v1"));
const admin = __importStar(require("firebase-admin"));
if (!admin.apps.length) {
    admin.initializeApp();
}
const db = admin.firestore();
/**
 * Utility to sync balance from ledger to entity
 * @param ledgerSnap Ledger document snapshot
 * @param entityCollection Collection name (CLIENT, VENDOR, EMPLOYEE)
 */
async function syncBalance(ledgerSnap, entityCollection) {
    const ledgerData = ledgerSnap.data();
    if (!ledgerData || typeof ledgerData.CurrentBalance === 'undefined')
        return;
    const entityId = ledgerSnap.id;
    const entityRef = db.collection(entityCollection).doc(entityId);
    try {
        await entityRef.update({ CurrentBalance: ledgerData.CurrentBalance });
    }
    catch (err) {
        console.error(`Failed to sync balance for ${entityCollection}/${entityId}:`, err);
    }
}
// CLIENT_LEDGER -> CLIENT
exports.syncClientBalance = functions.firestore
    .document('CLIENT_LEDGER/{clientId}')
    .onWrite(async (change, context) => {
    const after = change.after;
    if (!after.exists)
        return null;
    await syncBalance(after, 'CLIENT');
    return null;
});
// VENDOR_LEDGER -> VENDOR
exports.syncVendorBalance = functions.firestore
    .document('VENDOR_LEDGER/{vendorId}')
    .onWrite(async (change, context) => {
    const after = change.after;
    if (!after.exists)
        return null;
    await syncBalance(after, 'VENDOR');
    return null;
});
// EMPLOYEE_LEDGER -> EMPLOYEE
exports.syncEmployeeBalance = functions.firestore
    .document('EMPLOYEE_LEDGER/{employeeId}')
    .onWrite(async (change, context) => {
    const after = change.after;
    if (!after.exists)
        return null;
    await syncBalance(after, 'EMPLOYEE');
    return null;
});
//# sourceMappingURL=syncCurrentBalance.js.map