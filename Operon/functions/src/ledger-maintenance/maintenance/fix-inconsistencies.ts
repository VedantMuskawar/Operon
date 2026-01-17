import { onCall } from 'firebase-functions/v2/https';
import { getFirestore } from 'firebase-admin/firestore';
import * as admin from 'firebase-admin';
import { CALLABLE_FUNCTION_CONFIG } from '../../shared/function-config';
import { logInfo, logError } from '../../shared/logger';
import { LedgerType, getLedgerConfig } from '../ledger-types';
import { rebuildLedgerCore } from '../rebuild/rebuild-ledger-core';

const db = getFirestore();

/**
 * Automatically fix common ledger inconsistencies
 */
export const fixLedgerInconsistencies = onCall(
  CALLABLE_FUNCTION_CONFIG,
  async (request) => {
    try {
      const { ledgerType, ledgerId, organizationId, financialYear, fixes } = request.data;

      logInfo('LedgerMaintenance', 'fixLedgerInconsistencies', 'Fixing ledger inconsistencies', {
        ledgerType,
        ledgerId,
        organizationId,
        financialYear,
        fixes: fixes || 'all',
      });

      // Validate input
      if (!ledgerType || !ledgerId || !organizationId || !financialYear) {
        throw new Error('Missing required parameters: ledgerType, ledgerId, organizationId, financialYear');
      }

      if (!['client', 'vendor', 'employee'].includes(ledgerType)) {
        throw new Error(`Invalid ledgerType: ${ledgerType}. Must be 'client', 'vendor', or 'employee'`);
      }

      const config = getLedgerConfig(ledgerType as LedgerType);
      const ledgerRef = db.collection(config.collectionName).doc(ledgerId);
      const ledgerDoc = await ledgerRef.get();

      if (!ledgerDoc.exists) {
        throw new Error(`Ledger document not found: ${ledgerId}`);
      }

      const ledgerData = ledgerDoc.data()!;
      const entityId = ledgerData[config.idField] as string;
      const fixesToApply = fixes && Array.isArray(fixes) ? fixes : ['sync_balance', 'fix_count', 'remove_duplicates', 'recalculate_totals'];
      const fixesApplied: string[] = [];
      const errors: string[] = [];

      // Fix 1: Sync entity and ledger balances
      if (fixesToApply.includes('sync_balance')) {
        try {
          const entityRef = db.collection(config.entityCollectionName).doc(entityId);
          const entityDoc = await entityRef.get();

          if (entityDoc.exists) {
            const entityBalance = (entityDoc.data()?.[config.balanceField] as number) ?? 0;
            const ledgerBalance = (ledgerData.currentBalance as number) ?? 0;

            if (Math.abs(entityBalance - ledgerBalance) > 0.01) {
              // Prefer ledger balance as authoritative
              await entityRef.update({
                [config.balanceField]: ledgerBalance,
                updatedAt: admin.firestore.FieldValue.serverTimestamp(),
              });

              fixesApplied.push('sync_balance');
              logInfo('LedgerMaintenance', 'fixLedgerInconsistencies', 'Synced entity balance', {
                ledgerType,
                entityId,
                previousBalance: entityBalance,
                newBalance: ledgerBalance,
              });
            }
          }
        } catch (error) {
          errors.push(`Failed to sync balance: ${error instanceof Error ? error.message : String(error)}`);
        }
      }

      // Fix 2: Fix transaction count mismatch
      if (fixesToApply.includes('fix_count')) {
        try {
          const transactionCount = (ledgerData.transactionCount as number) || 0;
          const transactionIds = (ledgerData.transactionIds as string[]) || [];

          if (transactionCount !== transactionIds.length) {
            const correctCount = transactionIds.length;
            await ledgerRef.update({
              transactionCount: correctCount,
              updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            });

            fixesApplied.push('fix_count');
            logInfo('LedgerMaintenance', 'fixLedgerInconsistencies', 'Fixed transaction count', {
              ledgerType,
              ledgerId,
              previousCount: transactionCount,
              newCount: correctCount,
            });
          }
        } catch (error) {
          errors.push(`Failed to fix count: ${error instanceof Error ? error.message : String(error)}`);
        }
      }

      // Fix 3: Remove duplicate transaction IDs
      if (fixesToApply.includes('remove_duplicates')) {
        try {
          const transactionIds = (ledgerData.transactionIds as string[]) || [];
          const uniqueIds = Array.from(new Set(transactionIds));

          if (transactionIds.length !== uniqueIds.length) {
            await ledgerRef.update({
              transactionIds: uniqueIds,
              transactionCount: uniqueIds.length,
              updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            });

            fixesApplied.push('remove_duplicates');
            logInfo('LedgerMaintenance', 'fixLedgerInconsistencies', 'Removed duplicate transaction IDs', {
              ledgerType,
              ledgerId,
              previousCount: transactionIds.length,
              newCount: uniqueIds.length,
            });
          }
        } catch (error) {
          errors.push(`Failed to remove duplicates: ${error instanceof Error ? error.message : String(error)}`);
        }
      }

      // Fix 4: Recalculate totals from transactions
      if (fixesToApply.includes('recalculate_totals')) {
        try {
          // Rebuild the ledger to recalculate all totals
          await rebuildLedgerCore(ledgerType as LedgerType, entityId, organizationId, financialYear);
          fixesApplied.push('recalculate_totals');

          logInfo('LedgerMaintenance', 'fixLedgerInconsistencies', 'Recalculated totals from transactions', {
            ledgerType,
            ledgerId,
          });
        } catch (error) {
          errors.push(`Failed to recalculate totals: ${error instanceof Error ? error.message : String(error)}`);
        }
      }

      const success = fixesApplied.length > 0 && errors.length === 0;

      logInfo('LedgerMaintenance', 'fixLedgerInconsistencies', `Fixes ${success ? 'completed' : 'completed with errors'}`, {
        ledgerType,
        ledgerId,
        fixesApplied: fixesApplied.length,
        errors: errors.length,
      });

      return {
        success,
        fixesApplied,
        errors,
      };
    } catch (error) {
      logError(
        'LedgerMaintenance',
        'fixLedgerInconsistencies',
        'Error fixing inconsistencies',
        error instanceof Error ? error : String(error),
        request.data,
      );

      throw error;
    }
  },
);
