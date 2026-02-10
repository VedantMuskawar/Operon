import * as admin from 'firebase-admin';
import { onCall } from 'firebase-functions/v2/https';
import { CALLABLE_OPTS } from '../shared/function-config';
import {
  ACCOUNTS_LEDGERS_COLLECTION,
  CLIENT_LEDGERS_COLLECTION,
  EMPLOYEE_LEDGERS_COLLECTION,
  TRANSACTIONS_COLLECTION,
  VENDOR_LEDGERS_COLLECTION,
} from '../shared/constants';
import { getFirestore } from '../shared/firestore-helpers';
import { getFinancialYearDates, getLedgerDelta } from './ledger-helpers';
import { getYearMonthCompact } from '../shared/date-helpers';
import { getTransactionDate, removeUndefinedFields } from '../shared/transaction-helpers';
import { logError, logInfo } from '../shared/logger';

const db = getFirestore();

type AccountLedgerType = 'client' | 'vendor' | 'employee';

interface AccountLedgerRequest {
  organizationId: string;
  financialYear: string;
  accountsLedgerId: string;
  ledgerName?: string;
  accounts: Array<{
    type: AccountLedgerType;
    id: string;
    name?: string;
  }>;
  clearMissingMonths?: boolean;
}

const ledgerTypeMap: Record<AccountLedgerType, string> = {
  client: 'clientLedger',
  vendor: 'vendorLedger',
  employee: 'employeeLedger',
};

const ledgerCollectionMap: Record<AccountLedgerType, string> = {
  client: CLIENT_LEDGERS_COLLECTION,
  vendor: VENDOR_LEDGERS_COLLECTION,
  employee: EMPLOYEE_LEDGERS_COLLECTION,
};

const idFieldMap: Record<AccountLedgerType, string> = {
  client: 'clientId',
  vendor: 'vendorId',
  employee: 'employeeId',
};

function chunkIds(ids: string[], size: number): string[][] {
  const chunks: string[][] = [];
  for (let i = 0; i < ids.length; i += size) {
    chunks.push(ids.slice(i, i + size));
  }
  return chunks;
}

async function getCombinedOpeningBalance(
  accounts: AccountLedgerRequest['accounts'],
  financialYear: string,
): Promise<number> {
  if (!accounts || accounts.length === 0) return 0;

  const balances = await Promise.all(
    accounts.map(async (account) => {
      const collection = ledgerCollectionMap[account.type];
      if (!collection || !account.id) return 0;
      const ledgerId = `${account.id}_${financialYear}`;
      const ledgerDoc = await db.collection(collection).doc(ledgerId).get();
      if (!ledgerDoc.exists) return 0;
      return (ledgerDoc.get('openingBalance') as number) || 0;
    }),
  );

  return balances.reduce((sum, value) => sum + value, 0);
}

async function fetchTransactionsForAccounts(
  organizationId: string,
  financialYear: string,
  type: AccountLedgerType,
  ids: string[],
): Promise<FirebaseFirestore.QueryDocumentSnapshot[]> {
  if (ids.length === 0) return [];
  const chunks = chunkIds(ids, 10);
  const snapshots: FirebaseFirestore.QueryDocumentSnapshot[] = [];

  for (const chunk of chunks) {
    const query = db
      .collection(TRANSACTIONS_COLLECTION)
      .where('organizationId', '==', organizationId)
      .where('financialYear', '==', financialYear)
      .where('ledgerType', '==', ledgerTypeMap[type])
      .where(idFieldMap[type], 'in', chunk);

    const result = await query.get();
    result.docs.forEach((doc) => snapshots.push(doc));
  }

  return snapshots;
}

export const generateAccountsLedger = onCall(
  CALLABLE_OPTS,
  async (request) => {
    const data = request.data as AccountLedgerRequest;

    try {
      const {
        organizationId,
        financialYear,
        accountsLedgerId,
        ledgerName,
        accounts,
        clearMissingMonths = true,
      } = data;

      if (!organizationId || !financialYear || !accountsLedgerId) {
        throw new Error('Missing required parameters: organizationId, financialYear, accountsLedgerId');
      }

      if (!accounts || accounts.length < 2) {
        throw new Error('At least two accounts are required to generate a combined ledger');
      }

      logInfo('AccountsLedger', 'generateAccountsLedger', 'Generating accounts ledger', {
        organizationId,
        financialYear,
        accountsLedgerId,
        accountCount: accounts.length,
      });

      const accountsByType: Record<AccountLedgerType, string[]> = {
        client: [],
        vendor: [],
        employee: [],
      };

      accounts.forEach((account) => {
        if (accountsByType[account.type]) {
          accountsByType[account.type].push(account.id);
        }
      });

      const snapshots = (
        await Promise.all([
          fetchTransactionsForAccounts(organizationId, financialYear, 'client', accountsByType.client),
          fetchTransactionsForAccounts(organizationId, financialYear, 'vendor', accountsByType.vendor),
          fetchTransactionsForAccounts(organizationId, financialYear, 'employee', accountsByType.employee),
        ])
      ).flat();

      const transactionMap = new Map<string, FirebaseFirestore.QueryDocumentSnapshot>();
      snapshots.forEach((doc) => {
        const transactionId = (doc.get('transactionId') as string) || doc.id;
        transactionMap.set(transactionId, doc);
      });

      const transactions = Array.from(transactionMap.values());
      transactions.sort((a, b) => {
        const dateA = getTransactionDate(a).getTime();
        const dateB = getTransactionDate(b).getTime();
        if (dateA !== dateB) return dateA - dateB;
        return a.id.localeCompare(b.id);
      });

      const ledgerId = `${accountsLedgerId}_${financialYear}`;
      const ledgerRef = db.collection(ACCOUNTS_LEDGERS_COLLECTION).doc(ledgerId);
      const fyDates = getFinancialYearDates(financialYear);

      const openingBalance = await getCombinedOpeningBalance(accounts, financialYear);
      let currentBalance = openingBalance;
      const monthlyBuckets = new Map<string, any[]>();
      const transactionIds: string[] = [];
      let firstTransactionDate: admin.firestore.Timestamp | null = null;
      let lastTransactionDate: admin.firestore.Timestamp | null = null;
      let lastTransactionId: string | null = null;
      let lastTransactionAmount: number | null = null;

      transactions.forEach((snapshot) => {
        const transactionId = (snapshot.get('transactionId') as string) || snapshot.id;
        const data = snapshot.data();
        const transactionDate = getTransactionDate(snapshot);
        const yearMonth = getYearMonthCompact(transactionDate);
        const amount = (data.amount as number) || 0;
        const type = (data.type as string) || 'debit';
        const ledgerType = (data.ledgerType as string) || 'organizationLedger';
        const ledgerDelta = getLedgerDelta(ledgerType, type, amount);

        const balanceBefore = currentBalance;
        currentBalance += ledgerDelta;
        const balanceAfter = currentBalance;

        const transactionData: any = {
          transactionId,
          organizationId,
          ledgerType,
          type,
          category: data.category,
          amount,
          financialYear,
          transactionDate: admin.firestore.Timestamp.fromDate(transactionDate),
          updatedAt: admin.firestore.Timestamp.now(),
          balanceBefore,
          balanceAfter,
        };

        if (data.clientId) transactionData.clientId = data.clientId;
        if (data.vendorId) transactionData.vendorId = data.vendorId;
        if (data.employeeId) transactionData.employeeId = data.employeeId;
        if (data.createdAt) {
          transactionData.createdAt = data.createdAt;
        } else {
          transactionData.createdAt = admin.firestore.Timestamp.now();
        }
        if (data.paymentAccountId) transactionData.paymentAccountId = data.paymentAccountId;
        if (data.paymentAccountType) transactionData.paymentAccountType = data.paymentAccountType;
        if (data.referenceNumber) transactionData.referenceNumber = data.referenceNumber;
        if (data.tripId || data.orderId) transactionData.tripId = data.tripId ?? data.orderId;
        if (data.description) transactionData.description = data.description;
        if (data.metadata) transactionData.metadata = data.metadata;
        if (data.createdBy) transactionData.createdBy = data.createdBy;

        const cleanData = removeUndefinedFields(transactionData);
        const bucket = monthlyBuckets.get(yearMonth) ?? [];
        bucket.push(cleanData);
        monthlyBuckets.set(yearMonth, bucket);

        transactionIds.push(transactionId);
        if (!firstTransactionDate) {
          firstTransactionDate = admin.firestore.Timestamp.fromDate(transactionDate);
        }
        lastTransactionDate = admin.firestore.Timestamp.fromDate(transactionDate);
        lastTransactionId = transactionId;
        lastTransactionAmount = amount;
      });

      const batch = db.batch();

      if (clearMissingMonths) {
        const existingDocs = await ledgerRef.collection('TRANSACTIONS').get();
        existingDocs.forEach((doc) => {
          if (!monthlyBuckets.has(doc.id)) {
            batch.delete(doc.ref);
          }
        });
      }

      monthlyBuckets.forEach((bucket, yearMonth) => {
        const monthlyRef = ledgerRef.collection('TRANSACTIONS').doc(yearMonth);
        batch.set(
          monthlyRef,
          {
            yearMonth,
            transactions: bucket,
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
          },
          { merge: true },
        );
      });

      const totals = transactions.reduce(
        (acc, snapshot) => {
          const amount = (snapshot.get('amount') as number) || 0;
          const type = (snapshot.get('type') as string) || 'debit';
          if (type === 'credit') {
            acc.totalCredits += amount;
          } else {
            acc.totalDebits += amount;
          }
          return acc;
        },
        { totalCredits: 0, totalDebits: 0 },
      );

      batch.set(
        ledgerRef,
        {
          ledgerId,
          accountsLedgerId,
          organizationId,
          financialYear,
          ledgerType: 'accountsLedger',
          ledgerName: ledgerName ?? 'Combined Ledger',
          accounts,
          fyStartDate: admin.firestore.Timestamp.fromDate(fyDates.start),
          fyEndDate: admin.firestore.Timestamp.fromDate(fyDates.end),
          openingBalance,
          currentBalance,
          totalCredits: totals.totalCredits,
          totalDebits: totals.totalDebits,
          transactionCount: transactionIds.length,
          transactionIds,
          lastTransactionId: lastTransactionId ?? null,
          lastTransactionDate: lastTransactionDate ?? null,
          lastTransactionAmount: lastTransactionAmount ?? null,
          firstTransactionDate: firstTransactionDate ?? null,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true },
      );

      await batch.commit();

      logInfo('AccountsLedger', 'generateAccountsLedger', 'Accounts ledger generated', {
        ledgerId,
        transactionCount: transactionIds.length,
      });

      return {
        success: true,
        ledgerId,
        transactionCount: transactionIds.length,
      };
    } catch (error) {
      logError(
        'AccountsLedger',
        'generateAccountsLedger',
        'Failed to generate accounts ledger',
        error instanceof Error ? error : String(error),
        data,
      );
      throw error;
    }
  },
);
