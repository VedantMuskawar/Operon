import * as functions from 'firebase-functions';
import { getFirestore } from 'firebase-admin/firestore';
import { logInfo, logWarning, logError } from '../../shared/logger';
import { getFinancialContext } from '../../shared/financial-year';
import { LedgerType, getLedgerConfig } from '../ledger-types';
import { rebuildLedgerCore } from './rebuild-ledger-core';

const db = getFirestore();

/**
 * Scheduled rebuild of all ledgers
 * Runs daily at 2 AM UTC
 */
export const rebuildAllLedgersScheduled = functions.pubsub
  .schedule('0 2 * * *') // Daily at 2 AM UTC
  .timeZone('UTC')
  .onRun(async () => {
    const now = new Date();
    const { fyLabel } = getFinancialContext(now);

    logInfo('LedgerMaintenance', 'rebuildAllLedgersScheduled', 'Starting scheduled rebuild', {
      financialYear: fyLabel,
      timestamp: now.toISOString(),
    });

    const typesToRebuild: LedgerType[] = ['client', 'vendor', 'employee'];
    let totalRebuilt = 0;
    let successful = 0;
    let failed = 0;

    // Rebuild each ledger type
    for (const ledgerType of typesToRebuild) {
      const config = getLedgerConfig(ledgerType);

      // Get all ledger documents for current FY
      const ledgersSnapshot = await db
        .collection(config.collectionName)
        .where('financialYear', '==', fyLabel)
        .get();

      logInfo('LedgerMaintenance', 'rebuildAllLedgersScheduled', `Rebuilding ${ledgerType} ledgers`, {
        ledgerType,
        count: ledgersSnapshot.size,
      });

      // Rebuild each ledger
      const rebuildPromises = ledgersSnapshot.docs.map(async (ledgerDoc) => {
        totalRebuilt++;

        const ledgerData = ledgerDoc.data();
        const ledgerId = ledgerDoc.id;
        const organizationId = ledgerData.organizationId as string;
        const entityId = ledgerData[config.idField] as string;
        const financialYear = ledgerData.financialYear as string;

        if (!organizationId || !entityId || !financialYear) {
          logWarning('LedgerMaintenance', 'rebuildAllLedgersScheduled', 'Missing required fields', {
            ledgerType,
            ledgerId,
            organizationId,
            entityId,
            financialYear,
          });
          return;
        }

        try {
          await rebuildLedgerCore(ledgerType, entityId, organizationId, financialYear);
          successful++;

          logInfo('LedgerMaintenance', 'rebuildAllLedgersScheduled', 'Successfully rebuilt ledger', {
            ledgerType,
            ledgerId,
            organizationId,
            entityId,
            financialYear,
          });
        } catch (error) {
          failed++;

          logError(
            'LedgerMaintenance',
            'rebuildAllLedgersScheduled',
            'Error rebuilding ledger',
            error instanceof Error ? error : String(error),
            {
              ledgerType,
              ledgerId,
              organizationId,
              entityId,
              financialYear,
            },
          );
        }
      });

      await Promise.all(rebuildPromises);
    }

    logInfo('LedgerMaintenance', 'rebuildAllLedgersScheduled', 'Completed scheduled rebuild', {
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
