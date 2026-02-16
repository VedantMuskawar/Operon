import { getFirestore } from 'firebase-admin/firestore';
import * as admin from 'firebase-admin';
import { LedgerType, getLedgerConfig, getLedgerId } from '../ledger-types';
import {
  getOpeningBalance,
  getAllTransactionsFromMonthlyDocs,
  getLedgerDelta,
  getFinancialYearDates,
  getTransactionDateFromData,
} from '../ledger-helpers';

const db = getFirestore();

/**
 * Core rebuild logic (extracted for reuse)
 */
export async function rebuildLedgerCore(
  ledgerType: LedgerType,
  entityId: string,
  organizationId: string,
  financialYear: string,
): Promise<{ previousBalance: number; newBalance: number; transactionCount: number }> {
  const config = getLedgerConfig(ledgerType);
  const ledgerId = getLedgerId(entityId, financialYear);
  const ledgerRef = db.collection(config.collectionName).doc(ledgerId);

  // Get existing ledger to track previous balance
  const ledgerDoc = await ledgerRef.get();
  const previousBalance = ledgerDoc.exists
    ? ((ledgerDoc.data()?.currentBalance as number) || 0)
    : 0;

  // Get opening balance from previous FY
  const openingBalance = await getOpeningBalance(ledgerType, entityId, financialYear);

  // Get FY date range
  const fyDates = getFinancialYearDates(financialYear);

  // Get all transactions from monthly subcollections
  const allTransactions = await getAllTransactionsFromMonthlyDocs(ledgerRef);

  // Recalculate balance and totals
  let currentBalance = openingBalance;
  let totalReceivables = 0;
  let totalIncome = 0;
  let totalPayables = 0;
  let totalPayments = 0;
  let totalCredited = 0;
  let transactionCount = 0;
  const transactionIds: string[] = [];
  let lastTransactionId: string | null = null;
  let lastTransactionDate: admin.firestore.Timestamp | null = null;
  let lastTransactionAmount: number | null = null;
  let firstTransactionDate: admin.firestore.Timestamp | null = null;

  for (const transaction of allTransactions) {
    const transactionId = transaction.transactionId as string;
    const ledgerTypeFromTx = (transaction.ledgerType as string) || `${ledgerType}Ledger`;
    const type = transaction.type as string;
    const amount = (transaction.amount as number) || 0;
    const transactionDate = getTransactionDateFromData(transaction);

    // Calculate delta
    const delta = getLedgerDelta(ledgerTypeFromTx, type, amount);
    currentBalance += delta;

    // Update totals based on ledger type
    if (ledgerType === 'client') {
      if (type === 'credit') {
        totalReceivables += amount;
      } else {
        totalIncome += amount;
      }
    } else if (ledgerType === 'vendor') {
      if (type === 'credit') {
        totalPayables += amount;
      } else {
        totalPayments += amount;
      }
    } else if (ledgerType === 'employee') {
      if (type === 'credit') {
        totalCredited += amount;
      }
    }

    transactionCount++;
    if (transactionId && !transactionIds.includes(transactionId)) {
      transactionIds.push(transactionId);
    }

    // Track first and last transaction
    if (!firstTransactionDate || transactionDate < firstTransactionDate.toDate()) {
      firstTransactionDate = admin.firestore.Timestamp.fromDate(transactionDate);
    }

    if (!lastTransactionDate || transactionDate > lastTransactionDate.toDate()) {
      lastTransactionId = transactionId;
      lastTransactionDate = admin.firestore.Timestamp.fromDate(transactionDate);
      lastTransactionAmount = amount;
    }
  }

  // Build ledger data (type-specific fields)
  const baseLedgerData: any = {
    ledgerId,
    organizationId,
    [config.idField]: entityId,
    financialYear,
    fyStartDate: admin.firestore.Timestamp.fromDate(fyDates.start),
    fyEndDate: admin.firestore.Timestamp.fromDate(fyDates.end),
    openingBalance,
    currentBalance,
    transactionCount,
    transactionIds,
    lastTransactionId: lastTransactionId || null,
    lastTransactionDate: lastTransactionDate || admin.firestore.FieldValue.serverTimestamp(),
    lastTransactionAmount: lastTransactionAmount || null,
    firstTransactionDate: firstTransactionDate || admin.firestore.FieldValue.serverTimestamp(),
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  };

  // Add type-specific totals
  if (ledgerType === 'client') {
    baseLedgerData.totalReceivables = totalReceivables;
    baseLedgerData.totalIncome = totalIncome;
    baseLedgerData.netBalance = currentBalance;
  } else if (ledgerType === 'vendor') {
    baseLedgerData.totalPayables = totalPayables;
    baseLedgerData.totalPayments = totalPayments;
    baseLedgerData.lastUpdated = admin.firestore.Timestamp.now();
  } else if (ledgerType === 'employee') {
    baseLedgerData.totalCredited = totalCredited;
    baseLedgerData.totalTransactions = transactionCount;
    baseLedgerData.createdAt = ledgerDoc.exists
      ? (ledgerDoc.data()?.createdAt || admin.firestore.Timestamp.now())
      : admin.firestore.Timestamp.now();
    baseLedgerData.updatedAt = admin.firestore.Timestamp.now();
  }

  // Update or create ledger document
  if (ledgerDoc.exists) {
    await ledgerRef.update(baseLedgerData);
  } else {
    baseLedgerData.metadata = {};
    baseLedgerData.createdAt = admin.firestore.FieldValue.serverTimestamp();
    await ledgerRef.set(baseLedgerData);
  }

  // Update entity.currentBalance to match ledger (skip if entity missing)
  const entityRef = db.collection(config.entityCollectionName).doc(entityId);
  const entityDoc = await entityRef.get();
  if (entityDoc.exists) {
    await entityRef.update({
      [config.balanceField]: currentBalance,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  } else {
    console.warn('[Ledger Rebuild] Entity document missing; skipped entity balance update', {
      ledgerType,
      entityId,
      organizationId,
      financialYear,
    });
  }

  return {
    previousBalance,
    newBalance: currentBalance,
    transactionCount,
  };
}
