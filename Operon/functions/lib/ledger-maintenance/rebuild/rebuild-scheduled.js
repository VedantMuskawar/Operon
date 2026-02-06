"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.rebuildAllLedgersScheduled = void 0;
const scheduler_1 = require("firebase-functions/v2/scheduler");
const logger_1 = require("../../shared/logger");
const financial_year_1 = require("../../shared/financial-year");
const firestore_helpers_1 = require("../../shared/firestore-helpers");
const function_config_1 = require("../../shared/function-config");
const ledger_types_1 = require("../ledger-types");
const rebuild_ledger_core_1 = require("./rebuild-ledger-core");
const db = (0, firestore_helpers_1.getFirestore)();
/**
 * Scheduled rebuild of all ledgers
 * Runs daily at 2 AM UTC
 */
exports.rebuildAllLedgersScheduled = (0, scheduler_1.onSchedule)(Object.assign({ schedule: '0 2 * * *', timeZone: 'UTC' }, function_config_1.SCHEDULED_FUNCTION_OPTS), async (_event) => {
    const now = new Date();
    const { fyLabel } = (0, financial_year_1.getFinancialContext)(now);
    (0, logger_1.logInfo)('LedgerMaintenance', 'rebuildAllLedgersScheduled', 'Starting scheduled rebuild', {
        financialYear: fyLabel,
        timestamp: now.toISOString(),
    });
    const typesToRebuild = ['client', 'vendor', 'employee'];
    let totalRebuilt = 0;
    let successful = 0;
    let failed = 0;
    // Rebuild each ledger type
    for (const ledgerType of typesToRebuild) {
        const config = (0, ledger_types_1.getLedgerConfig)(ledgerType);
        // Get all ledger documents for current FY
        const ledgersSnapshot = await db
            .collection(config.collectionName)
            .where('financialYear', '==', fyLabel)
            .get();
        (0, logger_1.logInfo)('LedgerMaintenance', 'rebuildAllLedgersScheduled', `Rebuilding ${ledgerType} ledgers`, {
            ledgerType,
            count: ledgersSnapshot.size,
        });
        // Rebuild each ledger
        const rebuildPromises = ledgersSnapshot.docs.map(async (ledgerDoc) => {
            totalRebuilt++;
            const ledgerData = ledgerDoc.data();
            const ledgerId = ledgerDoc.id;
            const organizationId = ledgerData.organizationId;
            const entityId = ledgerData[config.idField];
            const financialYear = ledgerData.financialYear;
            if (!organizationId || !entityId || !financialYear) {
                (0, logger_1.logWarning)('LedgerMaintenance', 'rebuildAllLedgersScheduled', 'Missing required fields', {
                    ledgerType,
                    ledgerId,
                    organizationId,
                    entityId,
                    financialYear,
                });
                return;
            }
            try {
                await (0, rebuild_ledger_core_1.rebuildLedgerCore)(ledgerType, entityId, organizationId, financialYear);
                successful++;
                (0, logger_1.logInfo)('LedgerMaintenance', 'rebuildAllLedgersScheduled', 'Successfully rebuilt ledger', {
                    ledgerType,
                    ledgerId,
                    organizationId,
                    entityId,
                    financialYear,
                });
            }
            catch (error) {
                failed++;
                (0, logger_1.logError)('LedgerMaintenance', 'rebuildAllLedgersScheduled', 'Error rebuilding ledger', error instanceof Error ? error : String(error), {
                    ledgerType,
                    ledgerId,
                    organizationId,
                    entityId,
                    financialYear,
                });
            }
        });
        await Promise.all(rebuildPromises);
    }
    (0, logger_1.logInfo)('LedgerMaintenance', 'rebuildAllLedgersScheduled', 'Completed scheduled rebuild', {
        totalRebuilt,
        successful,
        failed,
        financialYear: fyLabel,
    });
});
//# sourceMappingURL=rebuild-scheduled.js.map