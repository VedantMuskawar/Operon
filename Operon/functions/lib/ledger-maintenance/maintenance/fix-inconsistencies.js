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
exports.fixLedgerInconsistencies = void 0;
const https_1 = require("firebase-functions/v2/https");
const firestore_1 = require("firebase-admin/firestore");
const admin = __importStar(require("firebase-admin"));
const function_config_1 = require("../../shared/function-config");
const logger_1 = require("../../shared/logger");
const ledger_types_1 = require("../ledger-types");
const rebuild_ledger_core_1 = require("../rebuild/rebuild-ledger-core");
const db = (0, firestore_1.getFirestore)();
/**
 * Automatically fix common ledger inconsistencies
 */
exports.fixLedgerInconsistencies = (0, https_1.onCall)(function_config_1.CALLABLE_FUNCTION_CONFIG, async (request) => {
    var _a, _b, _c;
    try {
        const { ledgerType, ledgerId, organizationId, financialYear, fixes } = request.data;
        (0, logger_1.logInfo)('LedgerMaintenance', 'fixLedgerInconsistencies', 'Fixing ledger inconsistencies', {
            ledgerType,
            ledgerId,
            organizationId,
            financialYear,
            fixes: fixes || 'all',
        });
        // Validate input
        if (!ledgerType || !ledgerId || !organizationId || !financialYear) {
            throw new Error('Missing required parameters: ledgerType, ledgerId, organizationId, financialYear');
        }
        if (!['client', 'vendor', 'employee'].includes(ledgerType)) {
            throw new Error(`Invalid ledgerType: ${ledgerType}. Must be 'client', 'vendor', or 'employee'`);
        }
        const config = (0, ledger_types_1.getLedgerConfig)(ledgerType);
        const ledgerRef = db.collection(config.collectionName).doc(ledgerId);
        const ledgerDoc = await ledgerRef.get();
        if (!ledgerDoc.exists) {
            throw new Error(`Ledger document not found: ${ledgerId}`);
        }
        const ledgerData = ledgerDoc.data();
        const entityId = ledgerData[config.idField];
        const fixesToApply = fixes && Array.isArray(fixes) ? fixes : ['sync_balance', 'fix_count', 'remove_duplicates', 'recalculate_totals'];
        const fixesApplied = [];
        const errors = [];
        // Fix 1: Sync entity and ledger balances
        if (fixesToApply.includes('sync_balance')) {
            try {
                const entityRef = db.collection(config.entityCollectionName).doc(entityId);
                const entityDoc = await entityRef.get();
                if (entityDoc.exists) {
                    const entityBalance = (_b = (_a = entityDoc.data()) === null || _a === void 0 ? void 0 : _a[config.balanceField]) !== null && _b !== void 0 ? _b : 0;
                    const ledgerBalance = (_c = ledgerData.currentBalance) !== null && _c !== void 0 ? _c : 0;
                    if (Math.abs(entityBalance - ledgerBalance) > 0.01) {
                        // Prefer ledger balance as authoritative
                        await entityRef.update({
                            [config.balanceField]: ledgerBalance,
                            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
                        });
                        fixesApplied.push('sync_balance');
                        (0, logger_1.logInfo)('LedgerMaintenance', 'fixLedgerInconsistencies', 'Synced entity balance', {
                            ledgerType,
                            entityId,
                            previousBalance: entityBalance,
                            newBalance: ledgerBalance,
                        });
                    }
                }
            }
            catch (error) {
                errors.push(`Failed to sync balance: ${error instanceof Error ? error.message : String(error)}`);
            }
        }
        // Fix 2: Fix transaction count mismatch
        if (fixesToApply.includes('fix_count')) {
            try {
                const transactionCount = ledgerData.transactionCount || 0;
                const transactionIds = ledgerData.transactionIds || [];
                if (transactionCount !== transactionIds.length) {
                    const correctCount = transactionIds.length;
                    await ledgerRef.update({
                        transactionCount: correctCount,
                        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
                    });
                    fixesApplied.push('fix_count');
                    (0, logger_1.logInfo)('LedgerMaintenance', 'fixLedgerInconsistencies', 'Fixed transaction count', {
                        ledgerType,
                        ledgerId,
                        previousCount: transactionCount,
                        newCount: correctCount,
                    });
                }
            }
            catch (error) {
                errors.push(`Failed to fix count: ${error instanceof Error ? error.message : String(error)}`);
            }
        }
        // Fix 3: Remove duplicate transaction IDs
        if (fixesToApply.includes('remove_duplicates')) {
            try {
                const transactionIds = ledgerData.transactionIds || [];
                const uniqueIds = Array.from(new Set(transactionIds));
                if (transactionIds.length !== uniqueIds.length) {
                    await ledgerRef.update({
                        transactionIds: uniqueIds,
                        transactionCount: uniqueIds.length,
                        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
                    });
                    fixesApplied.push('remove_duplicates');
                    (0, logger_1.logInfo)('LedgerMaintenance', 'fixLedgerInconsistencies', 'Removed duplicate transaction IDs', {
                        ledgerType,
                        ledgerId,
                        previousCount: transactionIds.length,
                        newCount: uniqueIds.length,
                    });
                }
            }
            catch (error) {
                errors.push(`Failed to remove duplicates: ${error instanceof Error ? error.message : String(error)}`);
            }
        }
        // Fix 4: Recalculate totals from transactions
        if (fixesToApply.includes('recalculate_totals')) {
            try {
                // Rebuild the ledger to recalculate all totals
                await (0, rebuild_ledger_core_1.rebuildLedgerCore)(ledgerType, entityId, organizationId, financialYear);
                fixesApplied.push('recalculate_totals');
                (0, logger_1.logInfo)('LedgerMaintenance', 'fixLedgerInconsistencies', 'Recalculated totals from transactions', {
                    ledgerType,
                    ledgerId,
                });
            }
            catch (error) {
                errors.push(`Failed to recalculate totals: ${error instanceof Error ? error.message : String(error)}`);
            }
        }
        const success = fixesApplied.length > 0 && errors.length === 0;
        (0, logger_1.logInfo)('LedgerMaintenance', 'fixLedgerInconsistencies', `Fixes ${success ? 'completed' : 'completed with errors'}`, {
            ledgerType,
            ledgerId,
            fixesApplied: fixesApplied.length,
            errors: errors.length,
        });
        return {
            success,
            fixesApplied,
            errors,
        };
    }
    catch (error) {
        (0, logger_1.logError)('LedgerMaintenance', 'fixLedgerInconsistencies', 'Error fixing inconsistencies', error instanceof Error ? error : String(error), request.data);
        throw error;
    }
});
//# sourceMappingURL=fix-inconsistencies.js.map