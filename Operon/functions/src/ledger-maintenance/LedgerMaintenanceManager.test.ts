import * as admin from 'firebase-admin';
if (!admin.apps.length) {
  admin.initializeApp();
}
import { describe, it, expect, beforeAll } from 'vitest';
import { LedgerMaintenanceManager, LedgerType, MaintenanceMode } from './LedgerMaintenanceManager';

describe('LedgerMaintenanceManager', () => {
  let manager: LedgerMaintenanceManager;

  beforeAll(() => {
    manager = new LedgerMaintenanceManager();
  });

  it('should run dryRun for client ledgers without error', async () => {
    await expect(manager.maintainLedger(LedgerType.client, MaintenanceMode.dryRun)).resolves.not.toThrow();
  });

  it('should run repair for all ledgers without error', async () => {
    await expect(manager.maintainLedger(LedgerType.all, MaintenanceMode.repair)).resolves.not.toThrow();
  });

  it('should run fullRebuild for vendor ledgers without error', async () => {
    await expect(manager.maintainLedger(LedgerType.vendor, MaintenanceMode.fullRebuild)).resolves.not.toThrow();
  });

  // Add more tests for edge cases, batching, and error handling as needed
});
