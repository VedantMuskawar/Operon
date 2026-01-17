"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.checkAllLedgers = void 0;
const https_1 = require("firebase-functions/v2/https");
const firestore_1 = require("firebase-admin/firestore");
const function_config_1 = require("../../shared/function-config");
const logger_1 = require("../../shared/logger");
const ledger_types_1 = require("../ledger-types");
const ledger_helpers_1 = require("../ledger-helpers");
const db = (0, firestore_1.getFirestore)();
/**
 * Check all ledgers for an organization (or specific type)
 */
exports.checkAllLedgers = (0, https_1.onCall)(function_config_1.CALLABLE_FUNCTION_CONFIG, async (request) => {
    try {
        const { organizationId, ledgerType, financialYear } = request.data;
        (0, logger_1.logInfo)('LedgerMaintenance', 'checkAllLedgers', 'Checking all ledgers', {
            organizationId,
            ledgerType: ledgerType || 'all',
            financialYear: financialYear || 'all',
        });
        // Validate input
        if (!organizationId) {
            throw new Error('Missing required parameter: organizationId');
        }
        if (ledgerType && !['client', 'vendor', 'employee'].includes(ledgerType)) {
            throw new Error(`Invalid ledgerType: ${ledgerType}. Must be 'client', 'vendor', or 'employee'`);
        }
        const typesToCheck = ledgerType
            ? [ledgerType]
            : ['client', 'vendor', 'employee'];
        const results = [];
        let totalChecked = 0;
        let validCount = 0;
        let invalidCount = 0;
        // Check each ledger type
        for (const type of typesToCheck) {
            const config = (0, ledger_types_1.getLedgerConfig)(type);
            // Build query
            let query = db
                .collection(config.collectionName)
                .where('organizationId', '==', organizationId);
            if (financialYear) {
                query = query.where('financialYear', '==', financialYear);
            }
            const ledgersSnapshot = await query.get();
            (0, logger_1.logInfo)('LedgerMaintenance', 'checkAllLedgers', `Checking ${type} ledgers`, {
                organizationId,
                type,
                count: ledgersSnapshot.size,
            });
            // Validate each ledger
            for (const ledgerDoc of ledgersSnapshot.docs) {
                totalChecked++;
                const ledgerData = ledgerDoc.data();
                const ledgerId = ledgerDoc.id;
                const entityId = ledgerData[config.idField];
                const fy = ledgerData.financialYear || financialYear || '';
                try {
                    // Validate ledger inline
                    const validation = await validateLedgerCore(type, ledgerId, organizationId, fy, config);
                    results.push({
                        ledgerType: type,
                        ledgerId,
                        entityId,
                        organizationId,
                        financialYear: fy,
                        valid: validation.valid,
                        errors: validation.errors,
                        warnings: validation.warnings,
                    });
                    if (validation.valid) {
                        validCount++;
                    }
                    else {
                        invalidCount++;
                    }
                }
                catch (error) {
                    (0, logger_1.logError)('LedgerMaintenance', 'checkAllLedgers', `Error checking ledger ${ledgerId}`, error instanceof Error ? error : String(error), {
                        ledgerType: type,
                        ledgerId,
                    });
                    results.push({
                        ledgerType: type,
                        ledgerId,
                        entityId,
                        organizationId,
                        financialYear: fy,
                        valid: false,
                        errors: [error instanceof Error ? error.message : String(error)],
                        warnings: [],
                    });
                    invalidCount++;
                }
            }
        }
        (0, logger_1.logInfo)('LedgerMaintenance', 'checkAllLedgers', 'Completed checking all ledgers', {
            organizationId,
            totalChecked,
            validCount,
            invalidCount,
        });
        return {
            totalChecked,
            valid: validCount,
            invalid: invalidCount,
            results,
        };
    }
    catch (error) {
        (0, logger_1.logError)('LedgerMaintenance', 'checkAllLedgers', 'Error checking all ledgers', error instanceof Error ? error : String(error), request.data);
        throw error;
    }
});
/**
 * Core validation logic (extracted for reuse)
 */
async function validateLedgerCore(ledgerType, ledgerId, organizationId, financialYear, config) {
    const ledgerRef = db.collection(config.collectionName).doc(ledgerId);
    const ledgerDoc = await ledgerRef.get();
    if (!ledgerDoc.exists) {
        throw new Error(`Ledger document not found: ${ledgerId}`);
    }
    const ledgerData = ledgerDoc.data();
    const errors = [];
    const warnings = [];
    const currentBalance = ledgerData.currentBalance || 0;
    const openingBalance = ledgerData.openingBalance || 0;
    const transactionCount = ledgerData.transactionCount || 0;
    const transactionIds = ledgerData.transactionIds || [];
    if (transactionCount !== transactionIds.length) {
        errors.push(`Transaction count mismatch: ${transactionCount} != ${transactionIds.length}`);
    }
    const allTransactions = await (0, ledger_helpers_1.getAllTransactionsFromMonthlyDocs)(ledgerRef);
    let calculatedBalance = openingBalance;
    const transactionIdsFromTransactions = new Set();
    for (const transaction of allTransactions) {
        const transactionId = transaction.transactionId;
        const ledgerTypeFromTx = transaction.ledgerType || `${ledgerType}Ledger`;
        const type = transaction.type;
        const amount = transaction.amount || 0;
        const delta = (0, ledger_helpers_1.getLedgerDelta)(ledgerTypeFromTx, type, amount);
        calculatedBalance += delta;
        if (transactionId) {
            transactionIdsFromTransactions.add(transactionId);
        }
    }
    const balanceDifference = Math.abs(currentBalance - calculatedBalance);
    if (balanceDifference > 0.01) {
        errors.push(`Balance mismatch: ${currentBalance} != ${calculatedBalance.toFixed(2)}, diff: ${balanceDifference.toFixed(2)}`);
    }
    // Check for missing transaction IDs
    const missingInLedger = Array.from(transactionIdsFromTransactions).filter((id) => !transactionIds.includes(id));
    const missingInTransactions = transactionIds.filter((id) => !transactionIdsFromTransactions.has(id));
    if (missingInLedger.length > 0) {
        warnings.push(`Transaction IDs in monthly docs but not in ledger: ${missingInLedger.slice(0, 5).join(', ')}`);
    }
    if (missingInTransactions.length > 0) {
        warnings.push(`Transaction IDs in ledger but not in monthly docs: ${missingInTransactions.slice(0, 5).join(', ')}`);
    }
    return {
        valid: errors.length === 0,
        errors,
        warnings,
    };
}
//# sourceMappingURL=check-all-ledgers.js.map