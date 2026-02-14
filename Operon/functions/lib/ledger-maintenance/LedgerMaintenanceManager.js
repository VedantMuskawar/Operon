"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.scheduledLedgerRepair = exports.LedgerMaintenanceManager = exports.MaintenanceMode = exports.LedgerType = void 0;
const firebase_admin_1 = require("firebase-admin");
const debug_1 = require("debug");
/**
 * Enum for ledger types
 */
var LedgerType;
(function (LedgerType) {
    LedgerType["client"] = "CLIENT";
    LedgerType["vendor"] = "VENDOR";
    LedgerType["employee"] = "EMPLOYEE";
    LedgerType["all"] = "ALL";
})(LedgerType || (exports.LedgerType = LedgerType = {}));
/**
 * Enum for maintenance modes
 */
var MaintenanceMode;
(function (MaintenanceMode) {
    MaintenanceMode["dryRun"] = "DRY_RUN";
    MaintenanceMode["repair"] = "REPAIR";
    MaintenanceMode["fullRebuild"] = "FULL_REBUILD";
})(MaintenanceMode || (exports.MaintenanceMode = MaintenanceMode = {}));
/**
 * LedgerMaintenanceManager: Unified, high-performance ledger maintenance service
 * Implements GetxService for global injection
 */
class LedgerMaintenanceManager {
    constructor() {
        this.db = (0, firebase_admin_1.firestore)();
        this.logger = (0, debug_1.debug)('ledger-maintenance');
        this.batchSize = 100;
    }
    /**
     * Unified entry point for all ledger maintenance actions
     */
    async maintainLedger(type, mode) {
        this.logger(`Starting maintenance: type=${type}, mode=${mode}`);
        switch (type) {
            case LedgerType.client:
                await this._processLedger('CLIENT', 'CLIENT_LEDGER', 'CLIENT_TRANSACTIONS', mode);
                break;
            case LedgerType.vendor:
                await this._processLedger('VENDOR', 'VENDOR_LEDGER', 'VENDOR_TRANSACTIONS', mode);
                break;
            case LedgerType.employee:
                await this._processLedger('EMPLOYEE', 'EMPLOYEE_LEDGER', 'EMPLOYEE_TRANSACTIONS', mode);
                break;
            case LedgerType.all:
                await this._processAllLedgers(mode);
                break;
            default:
                this.logger('Unknown ledger type');
        }
        this.logger('Maintenance complete.');
    }
    /**
     * Batch process all ledgers of all types
     */
    async _processAllLedgers(mode) {
        for (const type of [LedgerType.client, LedgerType.vendor, LedgerType.employee]) {
            await this._processLedger(type, `${type}_LEDGER`, `${type}_TRANSACTIONS`, mode);
        }
    }
    /**
     * Core logic for processing a single ledger type
     */
    async _processLedger(entityCollection, ledgerCollection, transactionCollection, mode) {
        this.logger(`Processing ${entityCollection} ledgers in mode ${mode}`);
        const entitySnap = await this.db.collection(entityCollection).get();
        const entities = entitySnap.docs;
        for (let i = 0; i < entities.length; i += this.batchSize) {
            const batch = this.db.batch();
            const chunk = entities.slice(i, i + this.batchSize);
            for (const entity of chunk) {
                const entityId = entity.id;
                const txSnap = await this.db
                    .collection(transactionCollection)
                    .where('entityId', '==', entityId)
                    .orderBy('timestamp')
                    .get();
                let runningBalance = 0;
                for (const tx of txSnap.docs) {
                    runningBalance += tx.data().amount || 0;
                }
                if (mode === MaintenanceMode.dryRun) {
                    this.logger(`[DRY_RUN] ${entityCollection}/${entityId} calculated balance: ${runningBalance}`);
                }
                else {
                    // Update ledger and entity cache
                    batch.update(this.db.collection(ledgerCollection).doc(entityId), { CurrentBalance: runningBalance });
                    batch.update(this.db.collection(entityCollection).doc(entityId), { CurrentBalance: runningBalance });
                }
            }
            if (mode !== MaintenanceMode.dryRun) {
                await batch.commit();
                this.logger(`Batch updated ${chunk.length} ${entityCollection} ledgers.`);
            }
        }
    }
}
exports.LedgerMaintenanceManager = LedgerMaintenanceManager;
// Example scheduled wrapper (for Firebase Cloud Functions)
const scheduledLedgerRepair = async () => {
    const manager = new LedgerMaintenanceManager();
    await manager.maintainLedger(LedgerType.all, MaintenanceMode.repair);
};
exports.scheduledLedgerRepair = scheduledLedgerRepair;
// Usage (GetX):
// final manager = Get.find<LedgerMaintenanceManager>();
// await manager.maintainLedger(LedgerType.client, MaintenanceMode.fullRebuild);
//# sourceMappingURL=LedgerMaintenanceManager.js.map