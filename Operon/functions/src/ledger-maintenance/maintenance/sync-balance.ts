import { onCall } from 'firebase-functions/v2/https';
import { getFirestore } from 'firebase-admin/firestore';
import * as admin from 'firebase-admin';
import { CALLABLE_FUNCTION_CONFIG } from '../../shared/function-config';
import { logInfo, logWarning, logError } from '../../shared/logger';
import { LedgerType, getLedgerConfig, getLedgerId } from '../ledger-types';

const db = getFirestore();

/**
 * Sync entity.currentBalance with ledger.currentBalance
 */
export const syncEntityBalance = onCall(
  CALLABLE_FUNCTION_CONFIG,
  async (request) => {
    try {
      const { ledgerType, entityId, organizationId, financialYear, preferLedger = true } = request.data;

      logInfo('LedgerMaintenance', 'syncEntityBalance', 'Syncing entity balance', {
        ledgerType,
        entityId,
        organizationId,
        financialYear,
        preferLedger,
      });

      // Validate input
      if (!ledgerType || !entityId || !organizationId || !financialYear) {
        throw new Error('Missing required parameters: ledgerType, entityId, organizationId, financialYear');
      }

      if (!['client', 'vendor', 'employee'].includes(ledgerType)) {
        throw new Error(`Invalid ledgerType: ${ledgerType}. Must be 'client', 'vendor', or 'employee'`);
      }

      const config = getLedgerConfig(ledgerType as LedgerType);
      const ledgerId = getLedgerId(entityId, financialYear);

      // Get entity document
      const entityRef = db.collection(config.entityCollectionName).doc(entityId);
      const entityDoc = await entityRef.get();

      if (!entityDoc.exists) {
        throw new Error(`Entity document not found: ${entityId} in ${config.entityCollectionName}`);
      }

      // Get ledger document
      const ledgerRef = db.collection(config.collectionName).doc(ledgerId);
      const ledgerDoc = await ledgerRef.get();

      if (!ledgerDoc.exists) {
        throw new Error(`Ledger document not found: ${ledgerId} in ${config.collectionName}`);
      }

      const entityData = entityDoc.data()!;
      const ledgerData = ledgerDoc.data()!;

      const entityBalance = (entityData[config.balanceField] as number) ?? 0;
      const ledgerBalance = (ledgerData.currentBalance as number) ?? 0;

      const previousEntityBalance = entityBalance;
      const previousLedgerBalance = ledgerBalance;

      // Determine which value to use as authoritative
      // By default, prefer ledger as it's calculated from transactions
      const authoritativeBalance = preferLedger ? ledgerBalance : entityBalance;
      const newBalance = authoritativeBalance;

      // Update the non-authoritative source
      if (preferLedger && Math.abs(entityBalance - ledgerBalance) > 0.01) {
        // Update entity from ledger
        await entityRef.update({
          [config.balanceField]: newBalance,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });

        logInfo('LedgerMaintenance', 'syncEntityBalance', 'Synced entity balance from ledger', {
          ledgerType,
          entityId,
          previousEntityBalance,
          previousLedgerBalance,
          newBalance,
        });
      } else if (!preferLedger && Math.abs(entityBalance - ledgerBalance) > 0.01) {
        // Update ledger from entity (rare, usually wrong)
        await ledgerRef.update({
          currentBalance: newBalance,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });

        logWarning('LedgerMaintenance', 'syncEntityBalance', 'Synced ledger balance from entity (may be incorrect)', {
          ledgerType,
          entityId,
          previousEntityBalance,
          previousLedgerBalance,
          newBalance,
        });
      } else {
        logInfo('LedgerMaintenance', 'syncEntityBalance', 'Balances already in sync', {
          ledgerType,
          entityId,
          balance: entityBalance,
        });
      }

      return {
        success: true,
        previousEntityBalance,
        previousLedgerBalance,
        newBalance,
      };
    } catch (error) {
      logError(
        'LedgerMaintenance',
        'syncEntityBalance',
        'Error syncing balance',
        error instanceof Error ? error : String(error),
        request.data,
      );

      throw error;
    }
  },
);
