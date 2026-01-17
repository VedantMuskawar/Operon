"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.checkLedgerConsistency = void 0;
const https_1 = require("firebase-functions/v2/https");
const function_config_1 = require("../../shared/function-config");
const logger_1 = require("../../shared/logger");
const ledger_types_1 = require("../ledger-types");
const { getFirestore } = require('firebase-admin/firestore');
const db = getFirestore();
/**
 * Check if entity.currentBalance matches ledger.currentBalance
 */
exports.checkLedgerConsistency = (0, https_1.onCall)(function_config_1.CALLABLE_FUNCTION_CONFIG, async (request) => {
    var _a, _b, _c, _d;
    try {
        const { ledgerType, entityId, organizationId, financialYear } = request.data;
        (0, logger_1.logInfo)('LedgerMaintenance', 'checkLedgerConsistency', 'Checking consistency', {
            ledgerType,
            entityId,
            organizationId,
            financialYear,
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
            (0, logger_1.logWarning)('LedgerMaintenance', 'checkLedgerConsistency', 'Ledger document not found', {
                ledgerType,
                ledgerId,
                entityId,
            });
            return {
                consistent: false,
                entityBalance: ((_a = entityDoc.data()) === null || _a === void 0 ? void 0 : _a[config.balanceField]) || null,
                ledgerBalance: null,
                difference: ((_b = entityDoc.data()) === null || _b === void 0 ? void 0 : _b[config.balanceField]) || 0,
            };
        }
        const entityData = entityDoc.data();
        const ledgerData = ledgerDoc.data();
        const entityBalance = (_c = entityData[config.balanceField]) !== null && _c !== void 0 ? _c : null;
        const ledgerBalance = (_d = ledgerData.currentBalance) !== null && _d !== void 0 ? _d : null;
        // Check if both are null/undefined
        if (entityBalance === null && ledgerBalance === null) {
            return {
                consistent: true,
                entityBalance: null,
                ledgerBalance: null,
                difference: 0,
            };
        }
        if (entityBalance === null || ledgerBalance === null) {
            (0, logger_1.logWarning)('LedgerMaintenance', 'checkLedgerConsistency', 'One balance is null', {
                ledgerType,
                entityId,
                entityBalance,
                ledgerBalance,
            });
            return {
                consistent: false,
                entityBalance,
                ledgerBalance,
                difference: Math.abs((entityBalance || 0) - (ledgerBalance || 0)),
            };
        }
        // Check if balances match (allow small floating point differences)
        const difference = Math.abs(entityBalance - ledgerBalance);
        const consistent = difference < 0.01; // Allow 0.01 difference for floating point
        if (!consistent) {
            (0, logger_1.logWarning)('LedgerMaintenance', 'checkLedgerConsistency', 'Balance mismatch detected', {
                ledgerType,
                entityId,
                entityBalance,
                ledgerBalance,
                difference,
            });
        }
        else {
            (0, logger_1.logInfo)('LedgerMaintenance', 'checkLedgerConsistency', 'Balances are consistent', {
                ledgerType,
                entityId,
                balance: entityBalance,
            });
        }
        return {
            consistent,
            entityBalance,
            ledgerBalance,
            difference,
        };
    }
    catch (error) {
        (0, logger_1.logError)('LedgerMaintenance', 'checkLedgerConsistency', 'Error checking consistency', error instanceof Error ? error : String(error), request.data);
        throw error;
    }
});
//# sourceMappingURL=check-consistency.js.map