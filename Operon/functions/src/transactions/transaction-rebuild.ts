import * as admin from 'firebase-admin';
import {
  TRANSACTIONS_COLLECTION,
  ANALYTICS_COLLECTION,
  TRANSACTIONS_SOURCE_KEY,
} from '../shared/constants';
import { getFirestore } from '../shared/firestore-helpers';
import { formatDate, cleanDailyData, getYearMonth } from '../shared/date-helpers';

const db = getFirestore();


/**
 * Rebuild transaction analytics for a specific organization and financial year.
 * Now writes to monthly documents instead of a single yearly document.
 * Exported for use by unified analytics rebuild.
 */
export async function rebuildTransactionAnalyticsForOrg(
  organizationId: string,
  financialYear: string,
): Promise<void> {
  // Calculate financial year date range from FY label (e.g., "FY2526" -> April 2025 to March 2026)
  const match = financialYear.match(/FY(\d{2})(\d{2})/);
  if (!match) {
    throw new Error(`Invalid financial year format: ${financialYear}`);
  }

  // Get all transactions for this organization in this FY
  const transactionsSnapshot = await db
    .collection(TRANSACTIONS_COLLECTION)
    .where('organizationId', '==', organizationId)
    .where('financialYear', '==', financialYear)
    .select(
      'status',
      'category',
      'type',
      'amount',
      'paymentAccountId',
      'paymentAccountType',
      'ledgerType',
      'createdAt',
    )
    .get();
  
  // Group transactions by month
  const transactionsByMonth: Record<string, typeof transactionsSnapshot.docs> = {};
  
  transactionsSnapshot.forEach((doc) => {
    const tx = doc.data();
    const createdAt = tx.createdAt as admin.firestore.Timestamp | undefined;
    const transactionDate = createdAt ? createdAt.toDate() : doc.createTime?.toDate() ?? new Date();
    const monthKey = getYearMonth(transactionDate);
    
    if (!transactionsByMonth[monthKey]) {
      transactionsByMonth[monthKey] = [];
    }
    transactionsByMonth[monthKey].push(doc);
  });
  
  // Process each month separately
  const monthUpdates = Object.entries(transactionsByMonth).map(async ([monthKey, monthDocs]) => {
    const analyticsDocId = `${TRANSACTIONS_SOURCE_KEY}_${organizationId}_${monthKey}`;
    const analyticsRef = db.collection(ANALYTICS_COLLECTION).doc(analyticsDocId);
    
    const incomeDaily: Record<string, number> = {};
    const receivablesDaily: Record<string, number> = {};
    const expenseDaily: Record<string, number> = {};
    const byType: Record<string, { count: number; total: number; daily: Record<string, number> }> = {};
    const byPaymentAccount: Record<string, { accountId: string; accountName: string; accountType: string; count: number; total: number; daily: Record<string, number> }> = {};
    const byPaymentMethodType: Record<string, { count: number; total: number; daily: Record<string, number> }> = {};
    const incomeByCategory: Record<string, number> = {};
    const receivablesByCategory: Record<string, number> = {};
    let totalPayableToVendors = 0;
    let transactionCount = 0;
    let completedTransactionCount = 0;
    const receivableAging = {
      current: 0,
      days31to60: 0,
      days61to90: 0,
      over90: 0,
    };
    
    monthDocs.forEach((doc) => {
      const tx = doc.data();
      const status = tx.status as string;
      const category = tx.category as string;
      const type = tx.type as string;
      const amount = tx.amount as number;
      const paymentAccountId = tx.paymentAccountId as string | undefined;
      const paymentAccountType = tx.paymentAccountType as string | undefined;
      
      transactionCount++;
      if (status === 'completed') {
        completedTransactionCount++;
      }
      
      const ledgerType = tx.ledgerType as string | undefined;
      const isClientLedgerDebit = ledgerType === 'clientLedger' && type === 'debit';
      const isClientLedgerCredit = ledgerType === 'clientLedger' && type === 'credit';
      const isExpenseByCategory = category !== 'income';
      const multiplier = 1;
      
      const createdAt = tx.createdAt as admin.firestore.Timestamp | undefined;
      const transactionDate = createdAt ? createdAt.toDate() : doc.createTime?.toDate() ?? new Date();
      
      const dateString = formatDate(transactionDate);

      if (isClientLedgerDebit) {
        incomeDaily[dateString] = (incomeDaily[dateString] || 0) + (amount * multiplier);
        incomeByCategory[category] = (incomeByCategory[category] || 0) + (amount * multiplier);
      }
      if (isClientLedgerCredit) {
        receivablesDaily[dateString] = (receivablesDaily[dateString] || 0) + (amount * multiplier);
        receivablesByCategory[category] = (receivablesByCategory[category] || 0) + (amount * multiplier);
        receivableAging.current += amount;
      }
      if (isExpenseByCategory) {
        expenseDaily[dateString] = (expenseDaily[dateString] || 0) + (amount * multiplier);
      }

      if (!byType[type]) {
        byType[type] = { count: 0, total: 0, daily: {} };
      }
      byType[type].count += multiplier;
      byType[type].total += (amount * multiplier);
      byType[type].daily[dateString] = (byType[type].daily[dateString] || 0) + (amount * multiplier);

      const accountId = paymentAccountId || 'cash';
      if (!byPaymentAccount[accountId]) {
        byPaymentAccount[accountId] = {
          accountId,
          accountName: accountId === 'cash' ? 'Cash' : accountId,
          accountType: paymentAccountType || (accountId === 'cash' ? 'cash' : 'other'),
          count: 0,
          total: 0,
          daily: {},
        };
      }
      byPaymentAccount[accountId].count += multiplier;
      byPaymentAccount[accountId].total += (amount * multiplier);
      byPaymentAccount[accountId].daily[dateString] = (byPaymentAccount[accountId].daily[dateString] || 0) + (amount * multiplier);

      const methodType = paymentAccountType || 'cash';
      if (!byPaymentMethodType[methodType]) {
        byPaymentMethodType[methodType] = { count: 0, total: 0, daily: {} };
      }
      byPaymentMethodType[methodType].count += multiplier;
      byPaymentMethodType[methodType].total += (amount * multiplier);
      byPaymentMethodType[methodType].daily[dateString] = (byPaymentMethodType[methodType].daily[dateString] || 0) + (amount * multiplier);

      if (ledgerType === 'vendorLedger' && type === 'credit') {
        totalPayableToVendors += amount;
      }
    });
    
    // Clean daily data
    const cleanedIncomeDaily = cleanDailyData(incomeDaily, 90);
    const cleanedReceivablesDaily = cleanDailyData(receivablesDaily, 90);
    const cleanedExpenseDaily = cleanDailyData(expenseDaily, 90);
    
    Object.keys(byType).forEach((type) => {
      byType[type].daily = cleanDailyData(byType[type].daily, 90);
    });
    Object.keys(byPaymentAccount).forEach((accountId) => {
      byPaymentAccount[accountId].daily = cleanDailyData(byPaymentAccount[accountId].daily, 90);
    });
    Object.keys(byPaymentMethodType).forEach((methodType) => {
      byPaymentMethodType[methodType].daily = cleanDailyData(byPaymentMethodType[methodType].daily, 90);
    });
    
    // Calculate totals for this month
    const totalIncome = Object.values(cleanedIncomeDaily).reduce((sum, val) => sum + (val || 0), 0);
    const totalReceivables = Object.values(cleanedReceivablesDaily).reduce((sum, val) => sum + (val || 0), 0);
    const netReceivables = totalReceivables - totalIncome;
    const totalExpense = Object.values(cleanedExpenseDaily).reduce((sum, val) => sum + (val || 0), 0);
    const netIncome = totalIncome - totalExpense;

    await analyticsRef.set({
      source: TRANSACTIONS_SOURCE_KEY,
      organizationId,
      month: monthKey,
      financialYear,
      incomeDaily: cleanedIncomeDaily,
      receivablesDaily: cleanedReceivablesDaily,
      expenseDaily: cleanedExpenseDaily,
      incomeByCategory,
      receivablesByCategory,
      byType,
      byPaymentAccount,
      byPaymentMethodType,
      totalIncome,
      totalReceivables,
      netReceivables,
      receivableAging,
      totalExpense,
      netIncome,
      transactionCount,
      completedTransactionCount,
      totalPayableToVendors,
      lastUpdated: admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true });
  });
  
  await Promise.all(monthUpdates);
}

/**
 * Cloud Function: Scheduled function to rebuild all client ledgers
 * Runs every 24 hours (midnight UTC) to recalculate ledger balances
 */
// Function removed: replaced by LedgerMaintenanceManager

