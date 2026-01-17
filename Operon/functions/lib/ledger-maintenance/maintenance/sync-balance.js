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
exports.syncEntityBalance = void 0;
const https_1 = require("firebase-functions/v2/https");
const firestore_1 = require("firebase-admin/firestore");
const admin = __importStar(require("firebase-admin"));
const function_config_1 = require("../../shared/function-config");
const logger_1 = require("../../shared/logger");
const ledger_types_1 = require("../ledger-types");
const db = (0, firestore_1.getFirestore)();
/**
 * Sync entity.currentBalance with ledger.currentBalance
 */
exports.syncEntityBalance = (0, https_1.onCall)(function_config_1.CALLABLE_FUNCTION_CONFIG, async (request) => {
    var _a, _b;
    try {
        const { ledgerType, entityId, organizationId, financialYear, preferLedger = true } = request.data;
        (0, logger_1.logInfo)('LedgerMaintenance', 'syncEntityBalance', 'Syncing entity balance', {
            ledgerType,
            entityId,
            organizationId,
            financialYear,
            preferLedger,
        });
        // Validate input
        if (!ledgerType || !entityId || !organizationId || !financialYear) {
            throw new Error('Missing required parameters: ledgerType, entityId, organizationId, financialYear');
        }
        if (!['client', 'vendor', 'employee'].includes(ledgerType)) {
            throw new Error(`Invalid ledgerType: ${ledgerType}. Must be 'client', 'vendor', or 'employee'`);
        }
        const config = (0, ledger_types_1.getLedgerConfig)(ledgerType);
        const ledgerId = (0, ledger_types_1.getLedgerId)(entityId, financialYear);
        // Get entity document
        const entityRef = db.collection(config.entityCollectionName).doc(entityId);
        const entityDoc = await entityRef.get();
        if (!entityDoc.exists) {
            throw new Error(`Entity document not found: ${entityId} in ${config.entityCollectionName}`);
        }
        // Get ledger document
        const ledgerRef = db.collection(config.collectionName).doc(ledgerId);
        const ledgerDoc = await ledgerRef.get();
        if (!ledgerDoc.exists) {
            throw new Error(`Ledger document not found: ${ledgerId} in ${config.collectionName}`);
        }
        const entityData = entityDoc.data();
        const ledgerData = ledgerDoc.data();
        const entityBalance = (_a = entityData[config.balanceField]) !== null && _a !== void 0 ? _a : 0;
        const ledgerBalance = (_b = ledgerData.currentBalance) !== null && _b !== void 0 ? _b : 0;
        const previousEntityBalance = entityBalance;
        const previousLedgerBalance = ledgerBalance;
        // Determine which value to use as authoritative
        // By default, prefer ledger as it's calculated from transactions
        const authoritativeBalance = preferLedger ? ledgerBalance : entityBalance;
        const newBalance = authoritativeBalance;
        // Update the non-authoritative source
        if (preferLedger && Math.abs(entityBalance - ledgerBalance) > 0.01) {
            // Update entity from ledger
            await entityRef.update({
                [config.balanceField]: newBalance,
                updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            });
            (0, logger_1.logInfo)('LedgerMaintenance', 'syncEntityBalance', 'Synced entity balance from ledger', {
                ledgerType,
                entityId,
                previousEntityBalance,
                previousLedgerBalance,
                newBalance,
            });
        }
        else if (!preferLedger && Math.abs(entityBalance - ledgerBalance) > 0.01) {
            // Update ledger from entity (rare, usually wrong)
            await ledgerRef.update({
                currentBalance: newBalance,
                updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            });
            (0, logger_1.logWarning)('LedgerMaintenance', 'syncEntityBalance', 'Synced ledger balance from entity (may be incorrect)', {
                ledgerType,
                entityId,
                previousEntityBalance,
                previousLedgerBalance,
                newBalance,
            });
        }
        else {
            (0, logger_1.logInfo)('LedgerMaintenance', 'syncEntityBalance', 'Balances already in sync', {
                ledgerType,
                entityId,
                balance: entityBalance,
            });
        }
        return {
            success: true,
            previousEntityBalance,
            previousLedgerBalance,
            newBalance,
        };
    }
    catch (error) {
        (0, logger_1.logError)('LedgerMaintenance', 'syncEntityBalance', 'Error syncing balance', error instanceof Error ? error : String(error), request.data);
        throw error;
    }
});
//# sourceMappingURL=sync-balance.js.map