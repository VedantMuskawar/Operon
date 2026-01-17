import { onCall } from 'firebase-functions/v2/https';
import { getFirestore } from 'firebase-admin/firestore';
import * as admin from 'firebase-admin';
import { CALLABLE_FUNCTION_CONFIG } from '../../shared/function-config';
import { logInfo, logError } from '../../shared/logger';
import {
  LedgerType,
  LedgerValidationResult,
  getLedgerConfig,
} from '../ledger-types';
import {
  getOpeningBalance,
  getAllTransactionsFromMonthlyDocs,
  getLedgerDelta,
  getFinancialYearDates,
} from '../ledger-helpers';

const db = getFirestore();

/**
 * Validate a specific ledger document
 * Checks balance integrity, transaction counts, and monthly totals
 */
export const validateLedger = onCall(
  CALLABLE_FUNCTION_CONFIG,
  async (request) => {
    try {
      const { ledgerType, ledgerId, organizationId, financialYear } = request.data;

      logInfo('LedgerMaintenance', 'validateLedger', 'Validating ledger', {
        ledgerType,
        ledgerId,
        organizationId,
        financialYear,
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
      const errors: string[] = [];
      const warnings: string[] = [];

      // Extract ledger fields
      const currentBalance = (ledgerData.currentBalance as number) || 0;
      const openingBalance = (ledgerData.openingBalance as number) || 0;
      const transactionCount = (ledgerData.transactionCount as number) || 0;
      const transactionIds = (ledgerData.transactionIds as string[]) || [];

      // Check 1: Transaction count matches transactionIds array length
      if (transactionCount !== transactionIds.length) {
        errors.push(
          `Transaction count mismatch: ledger.transactionCount (${transactionCount}) != transactionIds.length (${transactionIds.length})`,
        );
      }

      // Check 2: Get all transactions and verify balance calculation
      const allTransactions = await getAllTransactionsFromMonthlyDocs(ledgerRef);

      // Calculate expected balance from transactions
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

      // Check 3: Balance matches calculated balance from transactions
      const balanceDifference = Math.abs(currentBalance - calculatedBalance);
      if (balanceDifference > 0.01) {
        // Allow small floating point differences
        errors.push(
          `Balance mismatch: ledger.currentBalance (${currentBalance}) != calculated from transactions (${calculatedBalance.toFixed(2)}), difference: ${balanceDifference.toFixed(2)}`,
        );
      }

      // Check 4: Transaction IDs in ledger match transaction IDs from monthly docs
      const missingInLedger = Array.from(transactionIdsFromTransactions).filter(
        (id) => !transactionIds.includes(id),
      );
      const missingInTransactions = transactionIds.filter(
        (id) => !transactionIdsFromTransactions.has(id),
      );

      if (missingInLedger.length > 0) {
        warnings.push(
          `Transaction IDs in monthly docs but not in ledger.transactionIds: ${missingInLedger.slice(0, 5).join(', ')}${missingInLedger.length > 5 ? '...' : ''}`,
        );
      }

      if (missingInTransactions.length > 0) {
        warnings.push(
          `Transaction IDs in ledger.transactionIds but not found in monthly docs: ${missingInTransactions.slice(0, 5).join(', ')}${missingInTransactions.length > 5 ? '...' : ''}`,
        );
      }

      // Check 5: Verify opening balance from previous FY (if applicable)
      try {
        const expectedOpeningBalance = await getOpeningBalance(
          ledgerType as LedgerType,
          ledgerData[config.idField] as string,
          financialYear,
        );

        if (Math.abs(openingBalance - expectedOpeningBalance) > 0.01) {
          warnings.push(
            `Opening balance may be incorrect: ledger.openingBalance (${openingBalance}) != expected from previous FY (${expectedOpeningBalance})`,
          );
        }
      } catch (error) {
        warnings.push(`Could not verify opening balance: ${error instanceof Error ? error.message : String(error)}`);
      }

      // Check 6: Verify financial year dates match FY
      try {
        const fyDates = getFinancialYearDates(financialYear);
        const ledgerFyStart = (ledgerData.fyStartDate as admin.firestore.Timestamp)?.toDate();
        const ledgerFyEnd = (ledgerData.fyEndDate as admin.firestore.Timestamp)?.toDate();

        if (ledgerFyStart && Math.abs(ledgerFyStart.getTime() - fyDates.start.getTime()) > 86400000) {
          // Allow 1 day difference
          warnings.push(`FY start date may be incorrect: expected ${fyDates.start.toISOString()}, found ${ledgerFyStart.toISOString()}`);
        }

        if (ledgerFyEnd && Math.abs(ledgerFyEnd.getTime() - fyDates.end.getTime()) > 86400000) {
          warnings.push(`FY end date may be incorrect: expected ${fyDates.end.toISOString()}, found ${ledgerFyEnd?.toISOString()}`);
        }
      } catch (error) {
        warnings.push(`Could not verify FY dates: ${error instanceof Error ? error.message : String(error)}`);
      }

      const valid = errors.length === 0;

      logInfo('LedgerMaintenance', 'validateLedger', `Ledger validation ${valid ? 'passed' : 'failed'}`, {
        ledgerType,
        ledgerId,
        valid,
        errorCount: errors.length,
        warningCount: warnings.length,
      });

      return {
        valid,
        errors,
        warnings,
      } as LedgerValidationResult;
    } catch (error) {
      logError(
        'LedgerMaintenance',
        'validateLedger',
        'Error validating ledger',
        error instanceof Error ? error : String(error),
        request.data,
      );

      throw error;
    }
  },
);
