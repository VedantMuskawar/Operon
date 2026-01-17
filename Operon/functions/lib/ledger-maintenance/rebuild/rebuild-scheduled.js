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
exports.rebuildAllLedgersScheduled = void 0;
const functions = __importStar(require("firebase-functions"));
const firestore_1 = require("firebase-admin/firestore");
const logger_1 = require("../../shared/logger");
const financial_year_1 = require("../../shared/financial-year");
const ledger_types_1 = require("../ledger-types");
const rebuild_ledger_core_1 = require("./rebuild-ledger-core");
const db = (0, firestore_1.getFirestore)();
/**
 * Scheduled rebuild of all ledgers
 * Runs daily at 2 AM UTC
 */
exports.rebuildAllLedgersScheduled = functions.pubsub
    .schedule('0 2 * * *') // Daily at 2 AM UTC
    .timeZone('UTC')
    .onRun(async () => {
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
    return {
        success: true,
        totalRebuilt,
        successful,
        failed,
        financialYear: fyLabel,
    };
});
//# sourceMappingURL=rebuild-scheduled.js.map