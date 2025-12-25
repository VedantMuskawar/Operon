import * as admin from 'firebase-admin';
import * as functions from 'firebase-functions';
import {
  TRANSACTIONS_COLLECTION,
  CLIENT_LEDGERS_COLLECTION,
  ANALYTICS_COLLECTION,
  TRANSACTIONS_SOURCE_KEY,
} from '../shared/constants';
import { getFirestore } from '../shared/firestore-helpers';
import { getISOWeek, formatDate, formatMonth, cleanDailyData } from '../shared/date-helpers';

const db = getFirestore();

/**
 * Get transaction date from transaction document
 */
function getTransactionDate(snapshot: FirebaseFirestore.DocumentSnapshot): Date {
  const createdAt = snapshot.get('createdAt') as admin.firestore.Timestamp | undefined;
  if (createdAt) {
    return createdAt.toDate();
  }
  return snapshot.createTime?.toDate() ?? new Date();
}

/**
 * Get previous financial year label
 */
function getPreviousFinancialYear(currentFY: string): string {
  // Extract years from FY label (e.g., "FY2425" -> 2024, 2025)
  const match = currentFY.match(/FY(\d{2})(\d{2})/);
  if (!match) {
    throw new Error(`Invalid financial year format: ${currentFY}`);
  }
  
  const startYear = parseInt(match[1], 10);
  const endYear = parseInt(match[2], 10);
  
  // Calculate previous FY
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
    console.warn('[Ledger] Error fetching previous FY balance, defaulting to 0', {
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
  
  // FY starts in April (month 3, 0-indexed)
  const start = new Date(Date.UTC(startYear, 3, 1, 0, 0, 0));
  const end = new Date(Date.UTC(endYear, 3, 1, 0, 0, 0));
  
  return { start, end };
}

/**
 * Update client ledger when transaction is created or cancelled
 */
async function updateClientLedger(
  organizationId: string,
  clientId: string,
  financialYear: string,
  transaction: any,
  transactionId: string,
  snapshot: FirebaseFirestore.DocumentSnapshot,
  isCancellation: boolean = false,
  previousStatus?: string
): Promise<void> {
  const ledgerId = `${clientId}_${financialYear}`;
  const ledgerRef = db.collection(CLIENT_LEDGERS_COLLECTION).doc(ledgerId);
  
  const amount = transaction.amount as number;
  const category = transaction.category as string; // 'income' or 'expense'
  const type = transaction.type as string; // Transaction type (e.g., "advance_on_order")
  const status = transaction.status as string;
  const isIncome = category === 'income';
  const multiplier = isCancellation ? -1 : 1;
  const dmNumber = (transaction.metadata as any)?.dmNumber as number | undefined;

  // Ledger delta semantics (receivables):
  // credit  -> +amount  (client owes us)
  // payment -> -amount  (client pays us)
  // advance -> -amount  (we already got paid)
  // refund  -> -amount  (we pay them back)
  // debit   -> -amount  (org paid on behalf; reduces receivable)
  // adjustment -> signed amount (as provided)
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
  
  // Get FY date range
  const fyDates = getFinancialYearDates(financialYear);
  
  await db.runTransaction(async (tx) => {
    const ledgerDoc = await tx.get(ledgerRef);
    
    if (!ledgerDoc.exists && !isCancellation) {
      // Get opening balance from previous FY
      const openingBalance = await getOpeningBalance(organizationId, clientId, financialYear);
      
      // Create new ledger document (ledger balance uses ledgerDelta semantics)
      const currentBalance = openingBalance + (ledgerDelta * multiplier);
      
      // Initialize income breakdown by type
      const incomeByType: Record<string, number> = {};
      if (isIncome) {
        incomeByType[type] = amount * multiplier;
      }
      
      // Initialize transaction counts
      const pendingTransactionCount = status === 'pending' ? 1 : 0;
      const completedTransactionCount = status === 'completed' ? 1 : 0;
      const pendingTransactionAmount = status === 'pending' ? (amount * multiplier) : 0;
      const completedTransactionAmount = status === 'completed' ? (amount * multiplier) : 0;
      
      const transactionDate = getTransactionDate(snapshot);
      
      tx.set(ledgerRef, {
        ledgerId,
        organizationId,
        clientId,
        financialYear,
        fyStartDate: admin.firestore.Timestamp.fromDate(fyDates.start),
        fyEndDate: admin.firestore.Timestamp.fromDate(fyDates.end),
        openingBalance,
        currentBalance,
        totalIncome: isIncome ? amount * multiplier : 0,
        totalExpense: !isIncome ? amount * multiplier : 0,
        incomeByType,
        transactionCount: 1,
        completedTransactionCount,
        pendingTransactionCount,
        completedTransactionAmount,
        pendingTransactionAmount,
        transactionIds: [transactionId],
        ...(dmNumber !== undefined ? { dmNumbers: [dmNumber] } : {}),
        lastTransactionId: transactionId,
        lastTransactionDate: admin.firestore.Timestamp.fromDate(transactionDate),
        lastTransactionAmount: amount,
        firstTransactionDate: admin.firestore.Timestamp.fromDate(transactionDate),
        metadata: {},
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    } else if (ledgerDoc.exists) {
      // Update existing ledger
      const ledgerData = ledgerDoc.data()!;
      const currentBalance = (ledgerData.currentBalance as number) || 0;
      const totalIncome = (ledgerData.totalIncome as number) || 0;
      const totalExpense = (ledgerData.totalExpense as number) || 0;
      const incomeByType = (ledgerData.incomeByType as Record<string, number>) || {};
      const transactionIds = (ledgerData.transactionIds as string[]) || [];
      const pendingTransactionCount = (ledgerData.pendingTransactionCount as number) || 0;
      const completedTransactionCount = (ledgerData.completedTransactionCount as number) || 0;
      const pendingTransactionAmount = (ledgerData.pendingTransactionAmount as number) || 0;
      const completedTransactionAmount = (ledgerData.completedTransactionAmount as number) || 0;
      
      const newBalance = currentBalance + (ledgerDelta * multiplier);
      
      const updates: any = {
        currentBalance: newBalance,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      };
      
      if (isIncome) {
        updates.totalIncome = totalIncome + (amount * multiplier);
        // Update income breakdown by type
        if (!incomeByType[type]) {
          incomeByType[type] = 0;
        }
        incomeByType[type] = incomeByType[type] + (amount * multiplier);
        updates.incomeByType = incomeByType;
      } else {
        updates.totalExpense = totalExpense + (amount * multiplier);
      }
      
      // Update transaction status counts and amounts
      if (isCancellation) {
        // When transaction is deleted, reverse its effects
        // Decrease transaction count
        updates.transactionCount = Math.max(0, ((ledgerData.transactionCount as number) || 0) - 1);
        
        // Remove transaction ID from array
        updates.transactionIds = admin.firestore.FieldValue.arrayRemove(transactionId);
        
        // Decrease counts/amounts based on previous status (before deletion)
        // When deleting, we subtract the original amount (not multiplied)
        const statusToCheck = previousStatus || status;
        if (statusToCheck === 'completed') {
          updates.completedTransactionCount = Math.max(0, completedTransactionCount - 1);
          updates.completedTransactionAmount = Math.max(0, completedTransactionAmount - amount);
        } else if (statusToCheck === 'pending') {
          updates.pendingTransactionCount = Math.max(0, pendingTransactionCount - 1);
          updates.pendingTransactionAmount = Math.max(0, pendingTransactionAmount - amount);
        }
      } else {
        updates.transactionCount = ((ledgerData.transactionCount as number) || 0) + 1;
        
        // Update status-based counts and amounts
        if (status === 'completed') {
          updates.completedTransactionCount = completedTransactionCount + 1;
          updates.completedTransactionAmount = completedTransactionAmount + (amount * multiplier);
          
          // If was pending before, decrease pending
          // Note: This assumes status transitions from pending -> completed
          // If transaction is created directly as completed, this is fine
        } else if (status === 'pending') {
          updates.pendingTransactionCount = pendingTransactionCount + 1;
          updates.pendingTransactionAmount = pendingTransactionAmount + (amount * multiplier);
        }
        
        if (!transactionIds.includes(transactionId)) {
          updates.transactionIds = admin.firestore.FieldValue.arrayUnion(transactionId);
        }
        if (dmNumber !== undefined) {
          updates.dmNumbers = admin.firestore.FieldValue.arrayUnion(dmNumber);
        }
        
        const transactionDate = getTransactionDate(snapshot);
        updates.lastTransactionId = transactionId;
        updates.lastTransactionDate = admin.firestore.Timestamp.fromDate(transactionDate);
        updates.lastTransactionAmount = amount;
        
        // Set first transaction date if not exists
        if (!ledgerData.firstTransactionDate) {
          updates.firstTransactionDate = admin.firestore.Timestamp.fromDate(transactionDate);
        }
      }
      
      tx.update(ledgerRef, updates);
    }
  });
  
  // Create/update or delete transaction in subcollection
  const transactionSubRef = ledgerRef.collection('TRANSACTIONS').doc(transactionId);
  
  if (isCancellation) {
    // Delete transaction from subcollection when cancelled
    await transactionSubRef.delete();
  } else {
    // Create/update transaction in subcollection
    const transactionDate = getTransactionDate(snapshot);
    
    const transactionData: any = {
      transactionId,
      organizationId,
      clientId,
      type: transaction.type,
      category: transaction.category,
      amount: transaction.amount,
      status: transaction.status,
      financialYear: transaction.financialYear,
      transactionDate: admin.firestore.Timestamp.fromDate(transactionDate),
      transactionType: transaction.type,
      createdAt: transaction.createdAt || admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    };
    
    if (transaction.paymentAccountId) {
      transactionData.paymentAccountId = transaction.paymentAccountId;
    }
    if (transaction.paymentAccountType) {
      transactionData.paymentAccountType = transaction.paymentAccountType;
    }
    if (transaction.referenceNumber) {
      transactionData.referenceNumber = transaction.referenceNumber;
    }
    if (transaction.orderId) {
      transactionData.orderId = transaction.orderId;
    }
    if (transaction.description) {
      transactionData.description = transaction.description;
    }
    if (transaction.metadata) {
      transactionData.metadata = transaction.metadata;
    }
    if (transaction.createdBy) {
      transactionData.createdBy = transaction.createdBy;
    }
    if (transaction.balanceBefore !== undefined) {
      transactionData.balanceBefore = transaction.balanceBefore;
    }
    if (transaction.balanceAfter !== undefined) {
      transactionData.balanceAfter = transaction.balanceAfter;
    }
    
    await transactionSubRef.set(transactionData, { merge: true });
  }
}

/**
 * Update analytics when transaction is created or cancelled
 */
async function updateTransactionAnalytics(
  organizationId: string,
  financialYear: string,
  transaction: any,
  transactionDate: Date,
  isCancellation: boolean = false
): Promise<void> {
  const analyticsDocId = `${TRANSACTIONS_SOURCE_KEY}_${organizationId}_${financialYear}`;
  const analyticsRef = db.collection(ANALYTICS_COLLECTION).doc(analyticsDocId);
  
  const amount = transaction.amount as number;
  const category = transaction.category as string;
  const type = transaction.type as string;
  const status = transaction.status as string;
  const paymentAccountId = transaction.paymentAccountId as string | undefined;
  const paymentAccountType = transaction.paymentAccountType as string | undefined;
  
  const multiplier = isCancellation ? -1 : 1;
  const isIncome = category === 'income';
  
  const dateString = formatDate(transactionDate);
  const weekString = getISOWeek(transactionDate);
  const monthString = formatMonth(transactionDate);
  
  // Get current analytics data
  const analyticsDoc = await analyticsRef.get();
  const analyticsData = analyticsDoc.exists ? analyticsDoc.data()! : {};
  
  // Clean daily data (keep only last 90 days)
  const incomeDaily = cleanDailyData(analyticsData.incomeDaily || {}, 90);
  const expenseDaily = cleanDailyData(analyticsData.expenseDaily || {}, 90);
  
  // Update daily breakdown
  if (isIncome) {
    incomeDaily[dateString] = (incomeDaily[dateString] || 0) + (amount * multiplier);
  } else {
    expenseDaily[dateString] = (expenseDaily[dateString] || 0) + (amount * multiplier);
  }
  
  // Update weekly breakdown
  const incomeWeekly = analyticsData.incomeWeekly || {};
  const expenseWeekly = analyticsData.expenseWeekly || {};
  if (isIncome) {
    incomeWeekly[weekString] = (incomeWeekly[weekString] || 0) + (amount * multiplier);
  } else {
    expenseWeekly[weekString] = (expenseWeekly[weekString] || 0) + (amount * multiplier);
  }
  
  // Update monthly breakdown
  const incomeMonthly = analyticsData.incomeMonthly || {};
  const expenseMonthly = analyticsData.expenseMonthly || {};
  if (isIncome) {
    incomeMonthly[monthString] = (incomeMonthly[monthString] || 0) + (amount * multiplier);
  } else {
    expenseMonthly[monthString] = (expenseMonthly[monthString] || 0) + (amount * multiplier);
  }
  
  // Update by type breakdown
  const byType = analyticsData.byType || {};
  if (!byType[type]) {
    byType[type] = { count: 0, total: 0, daily: {}, weekly: {}, monthly: {} };
  }
  byType[type].count += multiplier;
  byType[type].total += (amount * multiplier);
  
  // Update type daily/weekly/monthly
  if (!byType[type].daily) byType[type].daily = {};
  if (!byType[type].weekly) byType[type].weekly = {};
  if (!byType[type].monthly) byType[type].monthly = {};
  
  byType[type].daily[dateString] = (byType[type].daily[dateString] || 0) + (amount * multiplier);
  byType[type].weekly[weekString] = (byType[type].weekly[weekString] || 0) + (amount * multiplier);
  byType[type].monthly[monthString] = (byType[type].monthly[monthString] || 0) + (amount * multiplier);
  
  // Clean type daily data
  byType[type].daily = cleanDailyData(byType[type].daily, 90);
  
  // Update by payment account breakdown
  const byPaymentAccount = analyticsData.byPaymentAccount || {};
  const accountId = paymentAccountId || 'cash';
  
  if (paymentAccountId && paymentAccountId !== 'cash') {
    if (!byPaymentAccount[accountId]) {
      byPaymentAccount[accountId] = {
        accountId,
        accountName: accountId,
        accountType: paymentAccountType || 'other',
        count: 0,
        total: 0,
        daily: {},
        weekly: {},
        monthly: {},
      };
    }
    byPaymentAccount[accountId].count += multiplier;
    byPaymentAccount[accountId].total += (amount * multiplier);
    
    if (!byPaymentAccount[accountId].daily) byPaymentAccount[accountId].daily = {};
    if (!byPaymentAccount[accountId].weekly) byPaymentAccount[accountId].weekly = {};
    if (!byPaymentAccount[accountId].monthly) byPaymentAccount[accountId].monthly = {};
    
    byPaymentAccount[accountId].daily[dateString] = (byPaymentAccount[accountId].daily[dateString] || 0) + (amount * multiplier);
    byPaymentAccount[accountId].weekly[weekString] = (byPaymentAccount[accountId].weekly[weekString] || 0) + (amount * multiplier);
    byPaymentAccount[accountId].monthly[monthString] = (byPaymentAccount[accountId].monthly[monthString] || 0) + (amount * multiplier);
    
    byPaymentAccount[accountId].daily = cleanDailyData(byPaymentAccount[accountId].daily, 90);
  } else if (accountId === 'cash') {
    if (!byPaymentAccount[accountId]) {
      byPaymentAccount[accountId] = {
        accountId: 'cash',
        accountName: 'Cash',
        accountType: 'cash',
        count: 0,
        total: 0,
        daily: {},
        weekly: {},
        monthly: {},
      };
    }
    byPaymentAccount[accountId].count += multiplier;
    byPaymentAccount[accountId].total += (amount * multiplier);
    
    if (!byPaymentAccount[accountId].daily) byPaymentAccount[accountId].daily = {};
    if (!byPaymentAccount[accountId].weekly) byPaymentAccount[accountId].weekly = {};
    if (!byPaymentAccount[accountId].monthly) byPaymentAccount[accountId].monthly = {};
    
    byPaymentAccount[accountId].daily[dateString] = (byPaymentAccount[accountId].daily[dateString] || 0) + (amount * multiplier);
    byPaymentAccount[accountId].weekly[weekString] = (byPaymentAccount[accountId].weekly[weekString] || 0) + (amount * multiplier);
    byPaymentAccount[accountId].monthly[monthString] = (byPaymentAccount[accountId].monthly[monthString] || 0) + (amount * multiplier);
    
    byPaymentAccount[accountId].daily = cleanDailyData(byPaymentAccount[accountId].daily, 90);
  }
  
  // Update by payment method type breakdown
  const byPaymentMethodType = analyticsData.byPaymentMethodType || {};
  const methodType = paymentAccountType || 'cash';
  
  if (!byPaymentMethodType[methodType]) {
    byPaymentMethodType[methodType] = { count: 0, total: 0, daily: {}, weekly: {}, monthly: {} };
  }
  byPaymentMethodType[methodType].count += multiplier;
  byPaymentMethodType[methodType].total += (amount * multiplier);
  
  if (!byPaymentMethodType[methodType].daily) byPaymentMethodType[methodType].daily = {};
  if (!byPaymentMethodType[methodType].weekly) byPaymentMethodType[methodType].weekly = {};
  if (!byPaymentMethodType[methodType].monthly) byPaymentMethodType[methodType].monthly = {};
  
  byPaymentMethodType[methodType].daily[dateString] = (byPaymentMethodType[methodType].daily[dateString] || 0) + (amount * multiplier);
  byPaymentMethodType[methodType].weekly[weekString] = (byPaymentMethodType[methodType].weekly[weekString] || 0) + (amount * multiplier);
  byPaymentMethodType[methodType].monthly[monthString] = (byPaymentMethodType[methodType].monthly[monthString] || 0) + (amount * multiplier);
  
  byPaymentMethodType[methodType].daily = cleanDailyData(byPaymentMethodType[methodType].daily, 90);
  
  // Calculate totals
  const totalIncome = Object.values(incomeMonthly).reduce((sum: number, val: any) => sum + (val || 0), 0);
  const totalExpense = Object.values(expenseMonthly).reduce((sum: number, val: any) => sum + (val || 0), 0);
  const netIncome = totalIncome - totalExpense;
  
  const transactionCount = (analyticsData.transactionCount || 0) + multiplier;
  const completedTransactionCount = status === 'completed' 
    ? ((analyticsData.completedTransactionCount || 0) + multiplier)
    : (analyticsData.completedTransactionCount || 0);
  
  // Update analytics document
  // Note: cancelledTransactionCount removed since we delete transactions instead of marking as cancelled
  await analyticsRef.set({
    source: TRANSACTIONS_SOURCE_KEY,
    organizationId,
    financialYear,
    incomeDaily,
    expenseDaily,
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
    transactionCount: Math.max(0, transactionCount),
    completedTransactionCount: Math.max(0, completedTransactionCount),
    lastUpdated: admin.firestore.FieldValue.serverTimestamp(),
  }, { merge: true });
}

/**
 * Cloud Function: Triggered when a transaction is created
 */
export const onTransactionCreated = functions.firestore
  .document(`${TRANSACTIONS_COLLECTION}/{transactionId}`)
  .onCreate(async (snapshot, context) => {
    const transaction = snapshot.data();
    const transactionId = context.params.transactionId;
    
    const organizationId = transaction.organizationId as string;
    const clientId = transaction.clientId as string;
    const financialYear = transaction.financialYear as string;
    
    if (!organizationId || !clientId || !financialYear) {
      console.error('[Transaction] Missing required fields', {
        transactionId,
        organizationId,
        clientId,
        financialYear,
      });
      return;
    }
    
    const transactionDate = getTransactionDate(snapshot);
    
    try {
      // Get current balance from ledger to set balanceBefore and balanceAfter
      const ledgerId = `${clientId}_${financialYear}`;
      const ledgerRef = db.collection(CLIENT_LEDGERS_COLLECTION).doc(ledgerId);
      const ledgerDoc = await ledgerRef.get();
      
      const balanceBefore = ledgerDoc.exists 
        ? ((ledgerDoc.data()?.currentBalance as number) || 0)
        : 0;
      
      const amount = transaction.amount as number;
      const type = transaction.type as string;
      
      // Use ledgerDelta logic (same as in updateClientLedger)
      // Credit adds to balance (+), Payment/Debit subtracts from balance (-)
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
      
      const balanceAfter = balanceBefore + ledgerDelta;
      
      // Update transaction with balance information
      await snapshot.ref.update({
        balanceBefore,
        balanceAfter,
      });
      
      // Update client ledger
      await updateClientLedger(
        organizationId,
        clientId,
        financialYear,
        { ...transaction, balanceBefore, balanceAfter },
        transactionId,
        snapshot,
        false
      );
      
      // Update analytics
      await updateTransactionAnalytics(
        organizationId,
        financialYear,
        { ...transaction, balanceBefore, balanceAfter },
        transactionDate,
        false
      );
      
      console.log('[Transaction] Successfully processed transaction creation', {
        transactionId,
        organizationId,
        clientId,
        financialYear,
      });
    } catch (error) {
      console.error('[Transaction] Error processing transaction creation', {
        transactionId,
        error,
      });
      throw error;
    }
  });

/**
 * Cloud Function: Triggered when a transaction is deleted (for cancellations)
 * When a transaction is deleted, reverse its effects in ledger and analytics
 */
export const onTransactionDeleted = functions.firestore
  .document(`${TRANSACTIONS_COLLECTION}/{transactionId}`)
  .onDelete(async (snapshot, context) => {
    const transaction = snapshot.data();
    const transactionId = context.params.transactionId;
    
    if (!transaction) {
      console.error('[Transaction] No transaction data found for deletion', { transactionId });
      return;
    }
    
    const organizationId = transaction.organizationId as string;
    const clientId = transaction.clientId as string;
    const financialYear = transaction.financialYear as string;
    const status = transaction.status as string;
    
    if (!organizationId || !clientId || !financialYear) {
      console.error('[Transaction] Missing required fields for deletion', {
        transactionId,
        organizationId,
        clientId,
        financialYear,
      });
      return;
    }
    
    const transactionDate = getTransactionDate(snapshot);
    
    try {
      // Reverse the transaction in ledger
      // Pass previous status to properly update counts
      await updateClientLedger(
        organizationId,
        clientId,
        financialYear,
        transaction,
        transactionId,
        snapshot,
        true, // isCancellation
        status // previous status (before deletion)
      );
      
      // Reverse in analytics
      await updateTransactionAnalytics(
        organizationId,
        financialYear,
        transaction,
        transactionDate,
        true // isCancellation
      );
      
      console.log('[Transaction] Successfully processed transaction deletion', {
        transactionId,
        organizationId,
        clientId,
        financialYear,
      });
    } catch (error) {
      console.error('[Transaction] Error processing transaction deletion', {
        transactionId,
        error,
      });
      throw error;
    }
  });

