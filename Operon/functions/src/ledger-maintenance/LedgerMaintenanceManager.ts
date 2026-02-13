import { firestore } from 'firebase-admin';
import { debug } from 'debug';


/**
 * Enum for ledger types
 */
export enum LedgerType {
  client = 'CLIENT',
  vendor = 'VENDOR',
  employee = 'EMPLOYEE',
  all = 'ALL',
}

/**
 * Enum for maintenance modes
 */
export enum MaintenanceMode {
  dryRun = 'DRY_RUN',
  repair = 'REPAIR',
  fullRebuild = 'FULL_REBUILD',
}

/**
 * LedgerMaintenanceManager: Unified, high-performance ledger maintenance service
 * Implements GetxService for global injection
 */
export class LedgerMaintenanceManager {
  private db = firestore();
  private logger = debug('ledger-maintenance');
  private batchSize = 100;

  /**
   * Unified entry point for all ledger maintenance actions
   */
  async maintainLedger(
    type: LedgerType,
    mode: MaintenanceMode
  ): Promise<void> {
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
  private async _processAllLedgers(mode: MaintenanceMode) {
    for (const type of [LedgerType.client, LedgerType.vendor, LedgerType.employee]) {
      await this._processLedger(type, `${type}_LEDGER`, `${type}_TRANSACTIONS`, mode);
    }
  }

  /**
   * Core logic for processing a single ledger type
   */
  private async _processLedger(
    entityCollection: string,
    ledgerCollection: string,
    transactionCollection: string,
    mode: MaintenanceMode
  ) {
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
        } else {
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

// Example scheduled wrapper (for Firebase Cloud Functions)
export const scheduledLedgerRepair = async () => {
  const manager = new LedgerMaintenanceManager();
  await manager.maintainLedger(LedgerType.all, MaintenanceMode.repair);
};

// Usage (GetX):
// final manager = Get.find<LedgerMaintenanceManager>();
// await manager.maintainLedger(LedgerType.client, MaintenanceMode.fullRebuild);
