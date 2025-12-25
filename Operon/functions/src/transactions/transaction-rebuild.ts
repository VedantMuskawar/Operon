import * as admin from 'firebase-admin';
import * as functions from 'firebase-functions';
import {
  TRANSACTIONS_COLLECTION,
  CLIENT_LEDGERS_COLLECTION,
  ANALYTICS_COLLECTION,
  TRANSACTIONS_SOURCE_KEY,
} from '../shared/constants';
import { getFinancialContext } from '../shared/financial-year';
import { getFirestore } from '../shared/firestore-helpers';
import { getISOWeek, formatDate, formatMonth, cleanDailyData } from '../shared/date-helpers';

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
 * Get opening balance from previous financial year
 */
async function getOpeningBalance(
  organizationId: string,
  clientId: string,
  currentFY: string
): Promise<number> {
  try {
    const previousFY = getPreviousFinancialYear(currentFY);
    const previousLedgerId = `${clientId}_${previousFY}`;
    const previousLedgerRef = db.collection(CLIENT_LEDGERS_COLLECTION).doc(previousLedgerId);
    const previousLedgerDoc = await previousLedgerRef.get();
    
    if (previousLedgerDoc.exists) {
      const previousLedgerData = previousLedgerDoc.data()!;
      return (previousLedgerData.currentBalance as number) || 0;
    }
  } catch (error) {
    console.warn('[Ledger Rebuild] Error fetching previous FY balance, defaulting to 0', {
      organizationId,
      clientId,
      currentFY,
      error,
    });
  }
  
  return 0;
}

/**
 * Get financial year date range
 */
function getFinancialYearDates(financialYear: string): { start: Date; end: Date } {
  const match = financialYear.match(/FY(\d{2})(\d{2})/);
  if (!match) {
    throw new Error(`Invalid financial year format: ${financialYear}`);
  }
  
  const startYear = 2000 + parseInt(match[1], 10);
  const endYear = 2000 + parseInt(match[2], 10);
  
  const start = new Date(Date.UTC(startYear, 3, 1, 0, 0, 0));
  const end = new Date(Date.UTC(endYear, 3, 1, 0, 0, 0));
  
  return { start, end };
}

/**
 * Rebuild client ledger for a specific client and financial year
 */
async function rebuildClientLedger(
  organizationId: string,
  clientId: string,
  financialYear: string,
): Promise<void> {
  const ledgerId = `${clientId}_${financialYear}`;
  const ledgerRef = db.collection(CLIENT_LEDGERS_COLLECTION).doc(ledgerId);
  
  // Get opening balance from previous FY
  const openingBalance = await getOpeningBalance(organizationId, clientId, financialYear);
  
  // Get FY date range
  const fyDates = getFinancialYearDates(financialYear);
  
  // Get all transactions for this client in this FY (from subcollection)
  const transactionsSubRef = ledgerRef.collection('TRANSACTIONS');
  const transactionsSnapshot = await transactionsSubRef
    .orderBy('transactionDate', 'asc')
    .get();
  
  let currentBalance = openingBalance;
  let totalIncome = 0;
  let totalExpense = 0;
  const incomeByType: Record<string, number> = {};
  let transactionCount = 0;
  let completedTransactionCount = 0;
  let pendingTransactionCount = 0;
  let completedTransactionAmount = 0;
  let pendingTransactionAmount = 0;
  const transactionIds: string[] = [];
  let lastTransactionId: string | undefined;
  let lastTransactionDate: admin.firestore.Timestamp | undefined;
  let lastTransactionAmount: number | undefined;
  let firstTransactionDate: admin.firestore.Timestamp | undefined;
  
  transactionsSnapshot.forEach((doc) => {
    const tx = doc.data();
    const status = tx.status as string;
    const category = tx.category as string;
    const type = tx.type as string;
    const amount = tx.amount as number;
    const isIncome = category === 'income';
    
    // Use ledgerDelta logic (same as in updateClientLedger)
    const ledgerDelta = (() => {
      switch (type) {
        case 'credit':
          return amount;
        case 'payment':
          return -amount;
        case 'advance':
          return -amount;
        case 'refund':
          return -amount;
        case 'debit':
          return -amount;
        case 'adjustment':
          return amount;
        default:
          return 0;
      }
    })();
    
    transactionIds.push(tx.transactionId as string);
    transactionCount++;
    
    // All transactions in database are active (cancelled ones are deleted)
    currentBalance += ledgerDelta;
    
    if (isIncome) {
      totalIncome += amount;
      // Track income by type
      if (!incomeByType[type]) {
        incomeByType[type] = 0;
      }
      incomeByType[type] += amount;
    } else {
      totalExpense += amount;
    }
    
    // Track status-based counts and amounts
    if (status === 'completed') {
      completedTransactionCount++;
      completedTransactionAmount += amount;
    } else if (status === 'pending') {
      pendingTransactionCount++;
      pendingTransactionAmount += amount;
    }
    
    lastTransactionId = tx.transactionId as string;
    lastTransactionDate = tx.transactionDate as admin.firestore.Timestamp;
    lastTransactionAmount = amount;
    
    // Set first transaction date
    if (!firstTransactionDate) {
      firstTransactionDate = tx.transactionDate as admin.firestore.Timestamp;
    }
  });
  
  // Update or create ledger document
  await ledgerRef.set({
    ledgerId,
    organizationId,
    clientId,
    financialYear,
    fyStartDate: admin.firestore.Timestamp.fromDate(fyDates.start),
    fyEndDate: admin.firestore.Timestamp.fromDate(fyDates.end),
    openingBalance,
    currentBalance,
    totalIncome,
    totalExpense,
    incomeByType,
    transactionCount,
    completedTransactionCount,
    pendingTransactionCount,
    completedTransactionAmount,
    pendingTransactionAmount,
    transactionIds,
    lastTransactionId: lastTransactionId || null,
    lastTransactionDate: lastTransactionDate || admin.firestore.FieldValue.serverTimestamp(),
    lastTransactionAmount: lastTransactionAmount || null,
    firstTransactionDate: firstTransactionDate || admin.firestore.FieldValue.serverTimestamp(),
    metadata: {},
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  }, { merge: true });
}

/**
 * Rebuild transaction analytics for a specific organization and financial year
 */
async function rebuildTransactionAnalyticsForOrg(
  organizationId: string,
  financialYear: string,
): Promise<void> {
  const analyticsDocId = `${TRANSACTIONS_SOURCE_KEY}_${organizationId}_${financialYear}`;
  const analyticsRef = db.collection(ANALYTICS_COLLECTION).doc(analyticsDocId);
  
  // Get all transactions for this organization in this FY
  const transactionsSnapshot = await db
    .collection(TRANSACTIONS_COLLECTION)
    .where('organizationId', '==', organizationId)
    .where('financialYear', '==', financialYear)
    .get();
  
  const incomeDaily: Record<string, number> = {};
  const expenseDaily: Record<string, number> = {};
  const incomeWeekly: Record<string, number> = {};
  const expenseWeekly: Record<string, number> = {};
  const incomeMonthly: Record<string, number> = {};
  const expenseMonthly: Record<string, number> = {};
  const byType: Record<string, { count: number; total: number; daily: Record<string, number>; weekly: Record<string, number>; monthly: Record<string, number> }> = {};
  const byPaymentAccount: Record<string, { accountId: string; accountName: string; accountType: string; count: number; total: number; daily: Record<string, number>; weekly: Record<string, number>; monthly: Record<string, number> }> = {};
  const byPaymentMethodType: Record<string, { count: number; total: number; daily: Record<string, number>; weekly: Record<string, number>; monthly: Record<string, number> }> = {};
  
  let transactionCount = 0;
  let completedTransactionCount = 0;
  
  transactionsSnapshot.forEach((doc) => {
    const tx = doc.data();
    const status = tx.status as string;
    const category = tx.category as string;
    const type = tx.type as string;
    const amount = tx.amount as number;
    const paymentAccountId = tx.paymentAccountId as string | undefined;
    const paymentAccountType = tx.paymentAccountType as string | undefined;
    
    // All transactions in database are active (cancelled ones are deleted)
    transactionCount++;
    if (status === 'completed') {
      completedTransactionCount++;
    }
    
    const isIncome = category === 'income';
    const multiplier = 1; // All transactions here are non-cancelled
    
    // Get transaction date
    const createdAt = tx.createdAt as admin.firestore.Timestamp | undefined;
    const transactionDate = createdAt ? createdAt.toDate() : doc.createTime?.toDate() ?? new Date();
    
    const dateString = formatDate(transactionDate);
    const weekString = getISOWeek(transactionDate);
    const monthString = formatMonth(transactionDate);
    
    // Update daily/weekly/monthly breakdowns
    if (isIncome) {
      incomeDaily[dateString] = (incomeDaily[dateString] || 0) + (amount * multiplier);
      incomeWeekly[weekString] = (incomeWeekly[weekString] || 0) + (amount * multiplier);
      incomeMonthly[monthString] = (incomeMonthly[monthString] || 0) + (amount * multiplier);
    } else {
      expenseDaily[dateString] = (expenseDaily[dateString] || 0) + (amount * multiplier);
      expenseWeekly[weekString] = (expenseWeekly[weekString] || 0) + (amount * multiplier);
      expenseMonthly[monthString] = (expenseMonthly[monthString] || 0) + (amount * multiplier);
    }
    
    // Update by type breakdown
    if (!byType[type]) {
      byType[type] = { count: 0, total: 0, daily: {}, weekly: {}, monthly: {} };
    }
    byType[type].count += multiplier;
    byType[type].total += (amount * multiplier);
    byType[type].daily[dateString] = (byType[type].daily[dateString] || 0) + (amount * multiplier);
    byType[type].weekly[weekString] = (byType[type].weekly[weekString] || 0) + (amount * multiplier);
    byType[type].monthly[monthString] = (byType[type].monthly[monthString] || 0) + (amount * multiplier);
    
    // Update by payment account breakdown
    const accountId = paymentAccountId || 'cash';
    if (!byPaymentAccount[accountId]) {
      byPaymentAccount[accountId] = {
        accountId,
        accountName: accountId === 'cash' ? 'Cash' : accountId,
        accountType: paymentAccountType || (accountId === 'cash' ? 'cash' : 'other'),
        count: 0,
        total: 0,
        daily: {},
        weekly: {},
        monthly: {},
      };
    }
    byPaymentAccount[accountId].count += multiplier;
    byPaymentAccount[accountId].total += (amount * multiplier);
    byPaymentAccount[accountId].daily[dateString] = (byPaymentAccount[accountId].daily[dateString] || 0) + (amount * multiplier);
    byPaymentAccount[accountId].weekly[weekString] = (byPaymentAccount[accountId].weekly[weekString] || 0) + (amount * multiplier);
    byPaymentAccount[accountId].monthly[monthString] = (byPaymentAccount[accountId].monthly[monthString] || 0) + (amount * multiplier);
    
    // Update by payment method type breakdown
    const methodType = paymentAccountType || 'cash';
    if (!byPaymentMethodType[methodType]) {
      byPaymentMethodType[methodType] = { count: 0, total: 0, daily: {}, weekly: {}, monthly: {} };
    }
    byPaymentMethodType[methodType].count += multiplier;
    byPaymentMethodType[methodType].total += (amount * multiplier);
    byPaymentMethodType[methodType].daily[dateString] = (byPaymentMethodType[methodType].daily[dateString] || 0) + (amount * multiplier);
    byPaymentMethodType[methodType].weekly[weekString] = (byPaymentMethodType[methodType].weekly[weekString] || 0) + (amount * multiplier);
    byPaymentMethodType[methodType].monthly[monthString] = (byPaymentMethodType[methodType].monthly[monthString] || 0) + (amount * multiplier);
  });
  
  // Clean daily data (keep only last 90 days)
  const cleanedIncomeDaily = cleanDailyData(incomeDaily, 90);
  const cleanedExpenseDaily = cleanDailyData(expenseDaily, 90);
  
  // Clean daily data for each breakdown
  Object.keys(byType).forEach((type) => {
    byType[type].daily = cleanDailyData(byType[type].daily, 90);
  });
  Object.keys(byPaymentAccount).forEach((accountId) => {
    byPaymentAccount[accountId].daily = cleanDailyData(byPaymentAccount[accountId].daily, 90);
  });
  Object.keys(byPaymentMethodType).forEach((methodType) => {
    byPaymentMethodType[methodType].daily = cleanDailyData(byPaymentMethodType[methodType].daily, 90);
  });
  
  // Calculate totals
  const totalIncome = Object.values(incomeMonthly).reduce((sum, val) => sum + (val || 0), 0);
  const totalExpense = Object.values(expenseMonthly).reduce((sum, val) => sum + (val || 0), 0);
  const netIncome = totalIncome - totalExpense;
  
  // Update analytics document
  await analyticsRef.set({
    source: TRANSACTIONS_SOURCE_KEY,
    organizationId,
    financialYear,
    incomeDaily: cleanedIncomeDaily,
    expenseDaily: cleanedExpenseDaily,
    incomeWeekly,
    expenseWeekly,
    incomeMonthly,
    expenseMonthly,
    byType,
    byPaymentAccount,
    byPaymentMethodType,
    totalIncome,
    totalExpense,
    netIncome,
    transactionCount,
    completedTransactionCount,
    lastUpdated: admin.firestore.FieldValue.serverTimestamp(),
  }, { merge: true });
}

/**
 * Cloud Function: Scheduled function to rebuild all client ledgers
 * Runs every 24 hours to recalculate ledger balances
 */
export const rebuildClientLedgers = functions.pubsub
  .schedule('every 24 hours')
  .timeZone('UTC')
  .onRun(async () => {
    const now = new Date();
    const { fyLabel } = getFinancialContext(now);
    
    // Get all client ledger documents for current FY
    const ledgersSnapshot = await db
      .collection(CLIENT_LEDGERS_COLLECTION)
      .where('financialYear', '==', fyLabel)
      .get();
    
    const rebuildPromises = ledgersSnapshot.docs.map(async (ledgerDoc) => {
      const ledgerData = ledgerDoc.data();
      const organizationId = ledgerData.organizationId as string;
      const clientId = ledgerData.clientId as string;
      const financialYear = ledgerData.financialYear as string;
      
      if (!organizationId || !clientId || !financialYear) {
        console.warn('[Client Ledger Rebuild] Missing required fields', {
          ledgerId: ledgerDoc.id,
          organizationId,
          clientId,
          financialYear,
        });
        return;
      }
      
      try {
        await rebuildClientLedger(organizationId, clientId, financialYear);
        console.log('[Client Ledger Rebuild] Successfully rebuilt', {
          organizationId,
          clientId,
          financialYear,
        });
      } catch (error) {
        console.error('[Client Ledger Rebuild] Error rebuilding ledger', {
          organizationId,
          clientId,
          financialYear,
          error,
        });
      }
    });
    
    await Promise.all(rebuildPromises);
    console.log(`[Client Ledger Rebuild] Rebuilt ${ledgersSnapshot.size} client ledgers`);
  });

/**
 * Cloud Function: Scheduled function to rebuild transaction analytics
 * Runs every 24 hours to recalculate analytics for all organizations
 */
export const rebuildTransactionAnalytics = functions.pubsub
  .schedule('every 24 hours')
  .timeZone('UTC')
  .onRun(async () => {
    const now = new Date();
    const { fyLabel } = getFinancialContext(now);
    
    // Get all unique organizations from transactions
    const transactionsSnapshot = await db
      .collection(TRANSACTIONS_COLLECTION)
      .where('financialYear', '==', fyLabel)
      .get();
    
    const organizationIds = new Set<string>();
    transactionsSnapshot.forEach((doc) => {
      const organizationId = doc.data()?.organizationId as string | undefined;
      if (organizationId) {
        organizationIds.add(organizationId);
      }
    });
    
    const rebuildPromises = Array.from(organizationIds).map(async (organizationId) => {
      try {
        await rebuildTransactionAnalyticsForOrg(organizationId, fyLabel);
        console.log('[Transaction Analytics Rebuild] Successfully rebuilt', {
          organizationId,
          financialYear: fyLabel,
        });
      } catch (error) {
        console.error('[Transaction Analytics Rebuild] Error rebuilding analytics', {
          organizationId,
          financialYear: fyLabel,
          error,
        });
      }
    });
    
    await Promise.all(rebuildPromises);
    console.log(`[Transaction Analytics Rebuild] Rebuilt analytics for ${organizationIds.size} organizations`);
  });

