"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.rebuildAllLedgers = void 0;
const https_1 = require("firebase-functions/v2/https");
const firestore_1 = require("firebase-admin/firestore");
const function_config_1 = require("../../shared/function-config");
const logger_1 = require("../../shared/logger");
const ledger_types_1 = require("../ledger-types");
const rebuild_ledger_core_1 = require("./rebuild-ledger-core");
const db = (0, firestore_1.getFirestore)();
/**
 * Rebuild all ledgers for an organization (or specific type)
 */
exports.rebuildAllLedgers = (0, https_1.onCall)(function_config_1.CALLABLE_FUNCTION_CONFIG, async (request) => {
    try {
        const { organizationId, ledgerType, financialYear } = request.data;
        (0, logger_1.logInfo)('LedgerMaintenance', 'rebuildAllLedgers', 'Rebuilding all ledgers', {
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
        const typesToRebuild = ledgerType
            ? [ledgerType]
            : ['client', 'vendor', 'employee'];
        const results = [];
        let totalRebuilt = 0;
        let successful = 0;
        let failed = 0;
        // Rebuild each ledger type
        for (const type of typesToRebuild) {
            const config = (0, ledger_types_1.getLedgerConfig)(type);
            // Build query
            let query = db
                .collection(config.collectionName)
                .where('organizationId', '==', organizationId);
            if (financialYear) {
                query = query.where('financialYear', '==', financialYear);
            }
            const ledgersSnapshot = await query.get();
            (0, logger_1.logInfo)('LedgerMaintenance', 'rebuildAllLedgers', `Rebuilding ${type} ledgers`, {
                organizationId,
                type,
                count: ledgersSnapshot.size,
            });
            // Rebuild each ledger
            const rebuildPromises = ledgersSnapshot.docs.map(async (ledgerDoc) => {
                totalRebuilt++;
                const ledgerData = ledgerDoc.data();
                const ledgerId = ledgerDoc.id;
                const entityId = ledgerData[config.idField];
                const fy = ledgerData.financialYear || financialYear || '';
                try {
                    const result = await (0, rebuild_ledger_core_1.rebuildLedgerCore)(type, entityId, organizationId, fy);
                    results.push({
                        ledgerType: type,
                        ledgerId,
                        entityId,
                        organizationId,
                        financialYear: fy,
                        success: true,
                        previousBalance: result.previousBalance,
                        newBalance: result.newBalance,
                        transactionCount: result.transactionCount,
                    });
                    successful++;
                }
                catch (error) {
                    (0, logger_1.logError)('LedgerMaintenance', 'rebuildAllLedgers', `Error rebuilding ledger ${ledgerId}`, error instanceof Error ? error : String(error), {
                        ledgerType: type,
                        ledgerId,
                        entityId,
                    });
                    results.push({
                        ledgerType: type,
                        ledgerId,
                        entityId,
                        organizationId,
                        financialYear: fy,
                        success: false,
                        previousBalance: 0,
                        newBalance: 0,
                        transactionCount: 0,
                        error: error instanceof Error ? error.message : String(error),
                    });
                    failed++;
                }
            });
            await Promise.all(rebuildPromises);
        }
        (0, logger_1.logInfo)('LedgerMaintenance', 'rebuildAllLedgers', 'Completed rebuilding all ledgers', {
            organizationId,
            totalRebuilt,
            successful,
            failed,
        });
        return {
            totalRebuilt,
            successful,
            failed,
            results,
        };
    }
    catch (error) {
        (0, logger_1.logError)('LedgerMaintenance', 'rebuildAllLedgers', 'Error rebuilding all ledgers', error instanceof Error ? error : String(error), request.data);
        throw error;
    }
});
//# sourceMappingURL=rebuild-all-ledgers.js.map