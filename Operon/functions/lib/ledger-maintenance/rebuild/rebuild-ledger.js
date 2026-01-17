"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.rebuildLedger = void 0;
const https_1 = require("firebase-functions/v2/https");
const function_config_1 = require("../../shared/function-config");
const logger_1 = require("../../shared/logger");
const rebuild_ledger_core_1 = require("./rebuild-ledger-core");
/**
 * Rebuild a specific ledger from its transactions
 */
exports.rebuildLedger = (0, https_1.onCall)(function_config_1.CALLABLE_FUNCTION_CONFIG, async (request) => {
    try {
        const { ledgerType, entityId, organizationId, financialYear } = request.data;
        (0, logger_1.logInfo)('LedgerMaintenance', 'rebuildLedger', 'Rebuilding ledger', {
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
        const result = await (0, rebuild_ledger_core_1.rebuildLedgerCore)(ledgerType, entityId, organizationId, financialYear);
        (0, logger_1.logInfo)('LedgerMaintenance', 'rebuildLedger', 'Successfully rebuilt ledger', {
            ledgerType,
            entityId,
            previousBalance: result.previousBalance,
            newBalance: result.newBalance,
            transactionCount: result.transactionCount,
        });
        return {
            success: true,
            previousBalance: result.previousBalance,
            newBalance: result.newBalance,
            transactionCount: result.transactionCount,
        };
    }
    catch (error) {
        (0, logger_1.logError)('LedgerMaintenance', 'rebuildLedger', 'Error rebuilding ledger', error instanceof Error ? error : String(error), request.data);
        throw error;
    }
});
//# sourceMappingURL=rebuild-ledger.js.map