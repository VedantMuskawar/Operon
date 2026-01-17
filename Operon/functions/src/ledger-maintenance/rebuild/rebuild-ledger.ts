import { onCall } from 'firebase-functions/v2/https';
import { CALLABLE_FUNCTION_CONFIG } from '../../shared/function-config';
import { logInfo, logError } from '../../shared/logger';
import { LedgerType } from '../ledger-types';
import { rebuildLedgerCore } from './rebuild-ledger-core';

/**
 * Rebuild a specific ledger from its transactions
 */
export const rebuildLedger = onCall(
  CALLABLE_FUNCTION_CONFIG,
  async (request) => {
    try {
      const { ledgerType, entityId, organizationId, financialYear } = request.data;

      logInfo('LedgerMaintenance', 'rebuildLedger', 'Rebuilding ledger', {
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

      const result = await rebuildLedgerCore(
        ledgerType as LedgerType,
        entityId,
        organizationId,
        financialYear,
      );

      logInfo('LedgerMaintenance', 'rebuildLedger', 'Successfully rebuilt ledger', {
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
    } catch (error) {
      logError(
        'LedgerMaintenance',
        'rebuildLedger',
        'Error rebuilding ledger',
        error instanceof Error ? error : String(error),
        request.data,
      );

      throw error;
    }
  },
);
