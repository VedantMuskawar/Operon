"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.validateLedger = void 0;
const https_1 = require("firebase-functions/v2/https");
const firestore_1 = require("firebase-admin/firestore");
const function_config_1 = require("../../shared/function-config");
const logger_1 = require("../../shared/logger");
const ledger_types_1 = require("../ledger-types");
const ledger_helpers_1 = require("../ledger-helpers");
const db = (0, firestore_1.getFirestore)();
/**
 * Validate a specific ledger document
 * Checks balance integrity, transaction counts, and monthly totals
 */
exports.validateLedger = (0, https_1.onCall)(function_config_1.CALLABLE_FUNCTION_CONFIG, async (request) => {
    var _a, _b;
    try {
        const { ledgerType, ledgerId, organizationId, financialYear } = request.data;
        (0, logger_1.logInfo)('LedgerMaintenance', 'validateLedger', 'Validating ledger', {
            ledgerType,
            ledgerId,
            organizationId,
            financialYear,
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
        const errors = [];
        const warnings = [];
        // Extract ledger fields
        const currentBalance = ledgerData.currentBalance || 0;
        const openingBalance = ledgerData.openingBalance || 0;
        const transactionCount = ledgerData.transactionCount || 0;
        const transactionIds = ledgerData.transactionIds || [];
        // Check 1: Transaction count matches transactionIds array length
        if (transactionCount !== transactionIds.length) {
            errors.push(`Transaction count mismatch: ledger.transactionCount (${transactionCount}) != transactionIds.length (${transactionIds.length})`);
        }
        // Check 2: Get all transactions and verify balance calculation
        const allTransactions = await (0, ledger_helpers_1.getAllTransactionsFromMonthlyDocs)(ledgerRef);
        // Calculate expected balance from transactions
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
        // Check 3: Balance matches calculated balance from transactions
        const balanceDifference = Math.abs(currentBalance - calculatedBalance);
        if (balanceDifference > 0.01) {
            // Allow small floating point differences
            errors.push(`Balance mismatch: ledger.currentBalance (${currentBalance}) != calculated from transactions (${calculatedBalance.toFixed(2)}), difference: ${balanceDifference.toFixed(2)}`);
        }
        // Check 4: Transaction IDs in ledger match transaction IDs from monthly docs
        const missingInLedger = Array.from(transactionIdsFromTransactions).filter((id) => !transactionIds.includes(id));
        const missingInTransactions = transactionIds.filter((id) => !transactionIdsFromTransactions.has(id));
        if (missingInLedger.length > 0) {
            warnings.push(`Transaction IDs in monthly docs but not in ledger.transactionIds: ${missingInLedger.slice(0, 5).join(', ')}${missingInLedger.length > 5 ? '...' : ''}`);
        }
        if (missingInTransactions.length > 0) {
            warnings.push(`Transaction IDs in ledger.transactionIds but not found in monthly docs: ${missingInTransactions.slice(0, 5).join(', ')}${missingInTransactions.length > 5 ? '...' : ''}`);
        }
        // Check 5: Verify opening balance from previous FY (if applicable)
        try {
            const expectedOpeningBalance = await (0, ledger_helpers_1.getOpeningBalance)(ledgerType, ledgerData[config.idField], financialYear);
            if (Math.abs(openingBalance - expectedOpeningBalance) > 0.01) {
                warnings.push(`Opening balance may be incorrect: ledger.openingBalance (${openingBalance}) != expected from previous FY (${expectedOpeningBalance})`);
            }
        }
        catch (error) {
            warnings.push(`Could not verify opening balance: ${error instanceof Error ? error.message : String(error)}`);
        }
        // Check 6: Verify financial year dates match FY
        try {
            const fyDates = (0, ledger_helpers_1.getFinancialYearDates)(financialYear);
            const ledgerFyStart = (_a = ledgerData.fyStartDate) === null || _a === void 0 ? void 0 : _a.toDate();
            const ledgerFyEnd = (_b = ledgerData.fyEndDate) === null || _b === void 0 ? void 0 : _b.toDate();
            if (ledgerFyStart && Math.abs(ledgerFyStart.getTime() - fyDates.start.getTime()) > 86400000) {
                // Allow 1 day difference
                warnings.push(`FY start date may be incorrect: expected ${fyDates.start.toISOString()}, found ${ledgerFyStart.toISOString()}`);
            }
            if (ledgerFyEnd && Math.abs(ledgerFyEnd.getTime() - fyDates.end.getTime()) > 86400000) {
                warnings.push(`FY end date may be incorrect: expected ${fyDates.end.toISOString()}, found ${ledgerFyEnd === null || ledgerFyEnd === void 0 ? void 0 : ledgerFyEnd.toISOString()}`);
            }
        }
        catch (error) {
            warnings.push(`Could not verify FY dates: ${error instanceof Error ? error.message : String(error)}`);
        }
        const valid = errors.length === 0;
        (0, logger_1.logInfo)('LedgerMaintenance', 'validateLedger', `Ledger validation ${valid ? 'passed' : 'failed'}`, {
            ledgerType,
            ledgerId,
            valid,
            errorCount: errors.length,
            warningCount: warnings.length,
        });
        return {
            valid,
            errors,
            warnings,
        };
    }
    catch (error) {
        (0, logger_1.logError)('LedgerMaintenance', 'validateLedger', 'Error validating ledger', error instanceof Error ? error : String(error), request.data);
        throw error;
    }
});
//# sourceMappingURL=validate-ledger.js.map