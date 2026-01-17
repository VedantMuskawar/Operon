import * as admin from 'firebase-admin';
import { getFirestore } from '../shared/firestore-helpers';
import { getYearMonthCompact } from '../shared/date-helpers';
import { LedgerType, getLedgerConfig } from './ledger-types';
import { logWarning } from '../shared/logger';

const db = getFirestore();

/**
 * Get previous financial year label
 */
function getPreviousFinancialYear(currentFY: string): string {
  const match = currentFY.match(/FY(\d{2})(\d{2})/);
  if (!match) {
    throw new Error(`Invalid financial year format: ${currentFY}`);
  }
  
  const startYear = parseInt(match[1], 10);
  const endYear = parseInt(match[2], 10);
  
  const prevStartYear = startYear - 1;
  const prevEndYear = endYear - 1;
  
  return `FY${String(prevStartYear).padStart(2, '0')}${String(prevEndYear).padStart(2, '0')}`;
}

/**
 * Get financial year date range
 */
export function getFinancialYearDates(financialYear: string): { start: Date; end: Date } {
  const match = financialYear.match(/FY(\d{2})(\d{2})/);
  if (!match) {
    throw new Error(`Invalid financial year format: ${financialYear}`);
  }
  
  const startYear = 2000 + parseInt(match[1], 10);
  const endYear = 2000 + parseInt(match[2], 10);
  
  // FY starts in April (month 3, 0-indexed)
  const start = new Date(Date.UTC(startYear, 3, 1, 0, 0, 0));
  const end = new Date(Date.UTC(endYear, 3, 1, 0, 0, 0));
  
  return { start, end };
}

/**
 * Calculate ledger delta based on ledgerType and transaction type
 */
export function getLedgerDelta(ledgerType: string, type: string, amount: number): number {
  // All ledger types use the same logic: credit increases balance, debit decreases
  // For clients: credit = receivable (client owes), debit = payment (client paid)
  // For vendors: credit = payable (we owe), debit = payment (we paid)
  // For employees: credit = payable (we owe), debit = payment (we paid)
  return type === 'credit' ? amount : -amount;
}

/**
 * Get opening balance from previous financial year (generic for all ledger types)
 */
export async function getOpeningBalance(
  ledgerType: LedgerType,
  entityId: string,
  currentFY: string,
): Promise<number> {
  const config = getLedgerConfig(ledgerType);
  
  try {
    const previousFY = getPreviousFinancialYear(currentFY);
    const previousLedgerId = `${entityId}_${previousFY}`;
    const previousLedgerRef = db.collection(config.collectionName).doc(previousLedgerId);
    const previousLedgerDoc = await previousLedgerRef.get();
    
    if (previousLedgerDoc.exists) {
      const previousLedgerData = previousLedgerDoc.data()!;
      return (previousLedgerData.currentBalance as number) || 0;
    }
  } catch (error) {
    logWarning('LedgerMaintenance', 'getOpeningBalance', 'Error fetching previous FY balance, defaulting to 0', {
      ledgerType,
      entityId,
      currentFY,
      error: error instanceof Error ? error.message : String(error),
    });
  }
  
  return 0;
}

/**
 * Get ledger document ID from entity ID and financial year
 */
export function getLedgerId(entityId: string, financialYear: string): string {
  return `${entityId}_${financialYear}`;
}

/**
 * Get all transactions from monthly subcollection documents
 */
export async function getAllTransactionsFromMonthlyDocs(
  ledgerRef: FirebaseFirestore.DocumentReference,
): Promise<any[]> {
  const transactionsSubRef = ledgerRef.collection('TRANSACTIONS');
  const monthlyDocsSnapshot = await transactionsSubRef.get();
  
  const allTransactions: any[] = [];
  monthlyDocsSnapshot.forEach((monthlyDoc) => {
    const monthlyData = monthlyDoc.data();
    const transactions = (monthlyData.transactions as any[]) || [];
    allTransactions.push(...transactions);
  });
  
  // Sort transactions by transactionDate (ascending)
  allTransactions.sort((a, b) => {
    const dateA = (a.transactionDate as admin.firestore.Timestamp)?.toDate() ?? new Date(0);
    const dateB = (b.transactionDate as admin.firestore.Timestamp)?.toDate() ?? new Date(0);
    return dateA.getTime() - dateB.getTime();
  });
  
  return allTransactions;
}

/**
 * Get transaction date from transaction object
 */
export function getTransactionDateFromData(transaction: any): Date {
  if (transaction.transactionDate?.toDate) {
    return transaction.transactionDate.toDate();
  } else if (transaction.transactionDate?._seconds) {
    return new Date((transaction.transactionDate as any)._seconds * 1000);
  } else if (transaction.transactionDate instanceof admin.firestore.Timestamp) {
    return transaction.transactionDate.toDate();
  } else {
    return new Date(transaction.transactionDate || Date.now());
  }
}

/**
 * Calculate year-month string from date (YYYYMM format for document IDs)
 */
export function getYearMonthFromDate(date: Date): string {
  return getYearMonthCompact(date);
}
