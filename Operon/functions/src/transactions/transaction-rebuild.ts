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
import { getISOWeek, formatDate, formatMonth, cleanDailyData, getYearMonth } from '../shared/date-helpers';

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
  
  // Get all monthly transaction documents for this client in this FY
  // Documents are stored as: TRANSACTIONS/{yearMonth} where yearMonth = YYYYMM
  const transactionsSubRef = ledgerRef.collection('TRANSACTIONS');
  const monthlyDocsSnapshot = await transactionsSubRef.get();
  
  // Extract all transactions from monthly documents and flatten into single array
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
  
  let currentBalance = openingBalance;
  let totalReceivables = 0; // Total receivables (credit transactions - what client owes us)
  let transactionCount = 0;
  const transactionIds: string[] = [];
  let lastTransactionId: string | undefined;
  let lastTransactionDate: admin.firestore.Timestamp | undefined;
  let lastTransactionAmount: number | undefined;
  let firstTransactionDate: admin.firestore.Timestamp | undefined;
  
  allTransactions.forEach((tx) => {
    const type = tx.type as string;
    const amount = tx.amount as number;
    const ledgerType = (tx.ledgerType as string) || 'clientLedger';
    
    // Use ledgerDelta logic (same as in updateClientLedger)
    // For ClientLedger: Credit = increment receivable, Debit = decrement receivable
    const ledgerDelta = ledgerType === 'clientLedger'
      ? (type === 'credit' ? amount : -amount)
      : (type === 'credit' ? amount : -amount); // Default to same semantics
    
    transactionIds.push(tx.transactionId as string);
    transactionCount++;
    
    // All transactions in database are active (cancelled ones are deleted)
    currentBalance += ledgerDelta;
    
    // Track total receivables (only credit transactions)
    // Credit = client owes us (receivables)
    // Debit = client paid us (reduces receivables, but not tracked as receivables)
    if (type === 'credit') {
      totalReceivables += amount;
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
  // For ClientLedger: Only track receivables (currentBalance), not expenses/income
  await ledgerRef.set({
    ledgerId,
    organizationId,
    clientId,
    financialYear,
    fyStartDate: admin.firestore.Timestamp.fromDate(fyDates.start),
    fyEndDate: admin.firestore.Timestamp.fromDate(fyDates.end),
    openingBalance,
    currentBalance, // Total receivables balance (what client owes)
    totalReceivables, // Total receivables created (credit transactions)
    transactionCount,
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
 * Rebuild transaction analytics for a specific organization and financial year.
 * Exported for use by unified analytics rebuild.
 */
export async function rebuildTransactionAnalyticsForOrg(
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
  const fuelPurchaseMonthly: Record<string, number> = {};
  let fuelPurchaseYearly = 0;
  const fuelByVehicleMonthly: Record<string, Record<string, number>> = {};
  const fuelByVehicleYearly: Record<string, number> = {};
  const fuelDistanceByVehicleMonthly: Record<string, Record<string, number>> = {};
  const fuelDistanceByVehicleYearly: Record<string, number> = {};
  const fuelAverageByVehicleMonthly: Record<string, Record<string, number>> = {};
  const fuelAverageByVehicleYearly: Record<string, number> = {};
  let totalPayableToVendors = 0;

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

    // Total payable to vendors: vendorLedger + type credit
    const ledgerType = tx.ledgerType as string | undefined;
    if (ledgerType === 'vendorLedger' && type === 'credit') {
      totalPayableToVendors += amount;
    }

    // Fuel purchases: metadata.purchaseType === 'fuel' or (category vendorPurchase + metadata.purchaseType fuel)
    const metadata = (tx.metadata as Record<string, unknown>) || {};
    const purchaseType = metadata.purchaseType as string | undefined;
    const isFuelPurchase =
      purchaseType === 'fuel' ||
      (category === 'vendorPurchase' && purchaseType === 'fuel');

    if (isFuelPurchase && amount > 0) {
      const monthKey = getYearMonth(transactionDate);
      fuelPurchaseMonthly[monthKey] = (fuelPurchaseMonthly[monthKey] || 0) + amount;
      fuelPurchaseYearly += amount;

      const vehicleNumber = (metadata.vehicleNumber as string) || 'unknown';
      if (!fuelByVehicleMonthly[vehicleNumber]) {
        fuelByVehicleMonthly[vehicleNumber] = {};
        fuelByVehicleYearly[vehicleNumber] = 0;
        fuelDistanceByVehicleMonthly[vehicleNumber] = {};
        fuelDistanceByVehicleYearly[vehicleNumber] = 0;
      }
      fuelByVehicleMonthly[vehicleNumber][monthKey] =
        (fuelByVehicleMonthly[vehicleNumber][monthKey] || 0) + amount;
      fuelByVehicleYearly[vehicleNumber] += amount;

      const linkedTrips = (metadata.linkedTrips as Array<{ distanceKm?: number }>) || [];
      let totalDistance = 0;
      for (const trip of linkedTrips) {
        totalDistance += (trip.distanceKm as number) || 0;
      }
      if (totalDistance > 0) {
        fuelDistanceByVehicleMonthly[vehicleNumber][monthKey] =
          (fuelDistanceByVehicleMonthly[vehicleNumber][monthKey] || 0) + totalDistance;
        fuelDistanceByVehicleYearly[vehicleNumber] += totalDistance;
      }
    }
  });

  // Compute fuel average (amount / distance = cost per km) per vehicle per month/year
  for (const [vehicle, monthlyAmounts] of Object.entries(fuelByVehicleMonthly)) {
    if (!fuelAverageByVehicleMonthly[vehicle]) {
      fuelAverageByVehicleMonthly[vehicle] = {};
    }
    for (const [monthKey, amt] of Object.entries(monthlyAmounts)) {
      const dist = fuelDistanceByVehicleMonthly[vehicle]?.[monthKey] || 0;
      if (dist > 0) {
        fuelAverageByVehicleMonthly[vehicle][monthKey] = amt / dist;
      }
    }
  }
  for (const [vehicle, yearlyAmt] of Object.entries(fuelByVehicleYearly)) {
    const yearlyDist = fuelDistanceByVehicleYearly[vehicle] || 0;
    if (yearlyDist > 0) {
      fuelAverageByVehicleYearly[vehicle] = yearlyAmt / yearlyDist;
    }
  }
  
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
    totalPayableToVendors,
    fuelPurchaseMonthly: { values: fuelPurchaseMonthly },
    fuelPurchaseYearly,
    fuelByVehicleMonthly,
    fuelByVehicleYearly,
    fuelAverageByVehicleMonthly,
    fuelAverageByVehicleYearly,
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

