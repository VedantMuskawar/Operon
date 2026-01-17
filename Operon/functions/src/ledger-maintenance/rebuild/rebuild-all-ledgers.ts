import { onCall } from 'firebase-functions/v2/https';
import { getFirestore } from 'firebase-admin/firestore';
import { CALLABLE_FUNCTION_CONFIG } from '../../shared/function-config';
import { logInfo, logError } from '../../shared/logger';
import { LedgerType, RebuildResult, getLedgerConfig } from '../ledger-types';
import { rebuildLedgerCore } from './rebuild-ledger-core';

const db = getFirestore();

/**
 * Rebuild all ledgers for an organization (or specific type)
 */
export const rebuildAllLedgers = onCall(
  CALLABLE_FUNCTION_CONFIG,
  async (request) => {
    try {
      const { organizationId, ledgerType, financialYear } = request.data;

      logInfo('LedgerMaintenance', 'rebuildAllLedgers', 'Rebuilding all ledgers', {
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

      const typesToRebuild: LedgerType[] = ledgerType
        ? [ledgerType as LedgerType]
        : ['client', 'vendor', 'employee'];

      const results: RebuildResult[] = [];
      let totalRebuilt = 0;
      let successful = 0;
      let failed = 0;

      // Rebuild each ledger type
      for (const type of typesToRebuild) {
        const config = getLedgerConfig(type);

        // Build query
        let query: FirebaseFirestore.Query = db
          .collection(config.collectionName)
          .where('organizationId', '==', organizationId);

        if (financialYear) {
          query = query.where('financialYear', '==', financialYear);
        }

        const ledgersSnapshot = await query.get();

        logInfo('LedgerMaintenance', 'rebuildAllLedgers', `Rebuilding ${type} ledgers`, {
          organizationId,
          type,
          count: ledgersSnapshot.size,
        });

        // Rebuild each ledger
        const rebuildPromises = ledgersSnapshot.docs.map(async (ledgerDoc) => {
          totalRebuilt++;

          const ledgerData = ledgerDoc.data();
          const ledgerId = ledgerDoc.id;
          const entityId = ledgerData[config.idField] as string;
          const fy = (ledgerData.financialYear as string) || financialYear || '';

          try {
            const result = await rebuildLedgerCore(type, entityId, organizationId, fy);

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
          } catch (error) {
            logError('LedgerMaintenance', 'rebuildAllLedgers', `Error rebuilding ledger ${ledgerId}`, error instanceof Error ? error : String(error), {
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

      logInfo('LedgerMaintenance', 'rebuildAllLedgers', 'Completed rebuilding all ledgers', {
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
    } catch (error) {
      logError(
        'LedgerMaintenance',
        'rebuildAllLedgers',
        'Error rebuilding all ledgers',
        error instanceof Error ? error : String(error),
        request.data,
      );

      throw error;
    }
  },
);
