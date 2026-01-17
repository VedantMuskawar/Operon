import { onCall } from 'firebase-functions/v2/https';
import { getFirestore } from 'firebase-admin/firestore';
import { CALLABLE_FUNCTION_CONFIG } from '../../shared/function-config';
import { logInfo, logError } from '../../shared/logger';
import { LedgerType, LedgerCheckResult, getLedgerConfig } from '../ledger-types';
import {
  getAllTransactionsFromMonthlyDocs,
  getLedgerDelta,
} from '../ledger-helpers';

const db = getFirestore();

/**
 * Check all ledgers for an organization (or specific type)
 */
export const checkAllLedgers = onCall(
  CALLABLE_FUNCTION_CONFIG,
  async (request) => {
    try {
      const { organizationId, ledgerType, financialYear } = request.data;

      logInfo('LedgerMaintenance', 'checkAllLedgers', 'Checking all ledgers', {
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

      const typesToCheck: LedgerType[] = ledgerType
        ? [ledgerType as LedgerType]
        : ['client', 'vendor', 'employee'];

      const results: LedgerCheckResult[] = [];
      let totalChecked = 0;
      let validCount = 0;
      let invalidCount = 0;

      // Check each ledger type
      for (const type of typesToCheck) {
        const config = getLedgerConfig(type);

        // Build query
        let query: FirebaseFirestore.Query = db
          .collection(config.collectionName)
          .where('organizationId', '==', organizationId);

        if (financialYear) {
          query = query.where('financialYear', '==', financialYear);
        }

        const ledgersSnapshot = await query.get();

        logInfo('LedgerMaintenance', 'checkAllLedgers', `Checking ${type} ledgers`, {
          organizationId,
          type,
          count: ledgersSnapshot.size,
        });

        // Validate each ledger
        for (const ledgerDoc of ledgersSnapshot.docs) {
          totalChecked++;

          const ledgerData = ledgerDoc.data();
          const ledgerId = ledgerDoc.id;
          const entityId = ledgerData[config.idField] as string;
          const fy = (ledgerData.financialYear as string) || financialYear || '';

          try {
            // Validate ledger inline
            const validation = await validateLedgerCore(type, ledgerId, organizationId, fy, config);

            results.push({
              ledgerType: type,
              ledgerId,
              entityId,
              organizationId,
              financialYear: fy,
              valid: validation.valid,
              errors: validation.errors,
              warnings: validation.warnings,
            });

            if (validation.valid) {
              validCount++;
            } else {
              invalidCount++;
            }
          } catch (error) {
            logError('LedgerMaintenance', 'checkAllLedgers', `Error checking ledger ${ledgerId}`, error instanceof Error ? error : String(error), {
              ledgerType: type,
              ledgerId,
            });

            results.push({
              ledgerType: type,
              ledgerId,
              entityId,
              organizationId,
              financialYear: fy,
              valid: false,
              errors: [error instanceof Error ? error.message : String(error)],
              warnings: [],
            });

            invalidCount++;
          }
        }
      }

      logInfo('LedgerMaintenance', 'checkAllLedgers', 'Completed checking all ledgers', {
        organizationId,
        totalChecked,
        validCount,
        invalidCount,
      });

      return {
        totalChecked,
        valid: validCount,
        invalid: invalidCount,
        results,
      };
    } catch (error) {
      logError(
        'LedgerMaintenance',
        'checkAllLedgers',
        'Error checking all ledgers',
        error instanceof Error ? error : String(error),
        request.data,
      );

      throw error;
    }
  },
);

/**
 * Core validation logic (extracted for reuse)
 */
async function validateLedgerCore(
  ledgerType: LedgerType,
  ledgerId: string,
  organizationId: string,
  financialYear: string,
  config: ReturnType<typeof getLedgerConfig>,
): Promise<{ valid: boolean; errors: string[]; warnings: string[] }> {
  const ledgerRef = db.collection(config.collectionName).doc(ledgerId);
  const ledgerDoc = await ledgerRef.get();

  if (!ledgerDoc.exists) {
    throw new Error(`Ledger document not found: ${ledgerId}`);
  }

  const ledgerData = ledgerDoc.data()!;
  const errors: string[] = [];
  const warnings: string[] = [];

  const currentBalance = (ledgerData.currentBalance as number) || 0;
  const openingBalance = (ledgerData.openingBalance as number) || 0;
  const transactionCount = (ledgerData.transactionCount as number) || 0;
  const transactionIds = (ledgerData.transactionIds as string[]) || [];

  if (transactionCount !== transactionIds.length) {
    errors.push(`Transaction count mismatch: ${transactionCount} != ${transactionIds.length}`);
  }

  const allTransactions = await getAllTransactionsFromMonthlyDocs(ledgerRef);
  let calculatedBalance = openingBalance;
  const transactionIdsFromTransactions = new Set<string>();

  for (const transaction of allTransactions) {
    const transactionId = transaction.transactionId as string;
    const ledgerTypeFromTx = (transaction.ledgerType as string) || `${ledgerType}Ledger`;
    const type = transaction.type as string;
    const amount = (transaction.amount as number) || 0;

    const delta = getLedgerDelta(ledgerTypeFromTx, type, amount);
    calculatedBalance += delta;

    if (transactionId) {
      transactionIdsFromTransactions.add(transactionId);
    }
  }

  const balanceDifference = Math.abs(currentBalance - calculatedBalance);
  if (balanceDifference > 0.01) {
    errors.push(`Balance mismatch: ${currentBalance} != ${calculatedBalance.toFixed(2)}, diff: ${balanceDifference.toFixed(2)}`);
  }

  // Check for missing transaction IDs
  const missingInLedger = Array.from(transactionIdsFromTransactions).filter(
    (id) => !transactionIds.includes(id),
  );
  const missingInTransactions = transactionIds.filter(
    (id) => !transactionIdsFromTransactions.has(id),
  );

  if (missingInLedger.length > 0) {
    warnings.push(`Transaction IDs in monthly docs but not in ledger: ${missingInLedger.slice(0, 5).join(', ')}`);
  }

  if (missingInTransactions.length > 0) {
    warnings.push(`Transaction IDs in ledger but not in monthly docs: ${missingInTransactions.slice(0, 5).join(', ')}`);
  }

  return {
    valid: errors.length === 0,
    errors,
    warnings,
  };
}
