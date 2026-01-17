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
exports.removeUndefinedFields = removeUndefinedFields;
exports.getTransactionDate = getTransactionDate;
exports.validateTransaction = validateTransaction;
const admin = __importStar(require("firebase-admin"));
/**
 * Remove all undefined values from an object (recursive cleanup for nested objects)
 * Also explicitly excludes the 'status' field which is no longer part of the transaction model
 *
 * @param obj - The object to clean
 * @returns A cleaned object without undefined values and without 'status' field
 */
function removeUndefinedFields(obj) {
    if (obj === null || obj === undefined) {
        return obj;
    }
    if (Array.isArray(obj)) {
        return obj.map(item => removeUndefinedFields(item));
    }
    if (typeof obj !== 'object') {
        return obj;
    }
    const cleaned = {};
    const excludeFields = ['status']; // Fields to explicitly exclude
    for (const key in obj) {
        if (obj.hasOwnProperty(key)) {
            // Skip excluded fields (like status)
            if (excludeFields.includes(key)) {
                continue;
            }
            const value = obj[key];
            // Skip undefined values
            if (value !== undefined) {
                if (typeof value === 'object' && value !== null && !(value instanceof admin.firestore.Timestamp) && !(value instanceof admin.firestore.FieldValue)) {
                    cleaned[key] = removeUndefinedFields(value);
                }
                else {
                    cleaned[key] = value;
                }
            }
        }
    }
    return cleaned;
}
/**
 * Get transaction date from transaction document snapshot
 * Falls back to createTime or current date if createdAt is missing
 *
 * @param snapshot - Firestore document snapshot
 * @returns Transaction date
 */
function getTransactionDate(snapshot) {
    var _a, _b;
    const createdAt = snapshot.get('createdAt');
    if (createdAt) {
        return createdAt.toDate();
    }
    return (_b = (_a = snapshot.createTime) === null || _a === void 0 ? void 0 : _a.toDate()) !== null && _b !== void 0 ? _b : new Date();
}
/**
 * Validate transaction has required fields
 *
 * @param transaction - Transaction data
 * @returns True if valid, false otherwise
 */
function validateTransaction(transaction) {
    return !!((transaction === null || transaction === void 0 ? void 0 : transaction.organizationId) &&
        (transaction === null || transaction === void 0 ? void 0 : transaction.financialYear) &&
        (transaction === null || transaction === void 0 ? void 0 : transaction.amount) !== undefined &&
        (transaction === null || transaction === void 0 ? void 0 : transaction.type) &&
        (transaction === null || transaction === void 0 ? void 0 : transaction.ledgerType));
}
//# sourceMappingURL=transaction-helpers.js.map