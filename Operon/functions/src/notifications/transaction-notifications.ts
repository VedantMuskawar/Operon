import * as admin from 'firebase-admin';
import {
  APP_ACCESS_ROLES_COLLECTION,
  DEVICES_COLLECTION,
  NOTIFICATION_JOBS_COLLECTION,
  ORGANIZATIONS_COLLECTION,
} from '../shared/constants';

const db = admin.firestore();

const ROLE_SECTION_KEY = 'TransactionNotifications';
const CLIENT_ANDROID_APP_ID = 'client_android';
const ANDROID_PLATFORM = 'android';

const INVALID_TOKEN_ERRORS = new Set([
  'messaging/invalid-registration-token',
  'messaging/registration-token-not-registered',
]);

function isCashLedgerTransaction(data: FirebaseFirestore.DocumentData): boolean {
  const ledgerType = (data.ledgerType as string) || '';
  const category = (data.category as string) || '';

  if (ledgerType === 'clientLedger') {
    return (
      category === 'advance' ||
      category === 'tripPayment' ||
      category === 'clientCredit'
    );
  }

  if (category === 'clientPayment' || category === 'refund') {
    return true;
  }

  if (ledgerType === 'vendorLedger' && category === 'vendorPurchase') {
    return true;
  }

  if (
    (ledgerType === 'vendorLedger' && category === 'vendorPayment') ||
    (ledgerType === 'employeeLedger' && category === 'salaryDebit') ||
    (ledgerType === 'organizationLedger' && category === 'generalExpense')
  ) {
    return true;
  }

  return false;
}

function formatAmount(amount: number | undefined): string {
  const normalized = typeof amount === 'number' && !Number.isNaN(amount) ? amount : 0;
  return `\u20b9${normalized.toFixed(2)}`;
}

async function fetchAllowedRoleIds(organizationId: string): Promise<Set<string>> {
  const rolesSnap = await db
    .collection(ORGANIZATIONS_COLLECTION)
    .doc(organizationId)
    .collection(APP_ACCESS_ROLES_COLLECTION)
    .get();

  const allowed = new Set<string>();

  for (const doc of rolesSnap.docs) {
    const data = doc.data() as Record<string, any>;
    const roleId = (data.roleId as string) || doc.id;
    const isAdmin = data.isAdmin === true;
    const sectionAllowed = data.permissions?.sections?.[ROLE_SECTION_KEY] === true;

    if (isAdmin || sectionAllowed) {
      allowed.add(roleId);
    }
  }

  return allowed;
}

async function fetchTargetUserIds(
  organizationId: string,
  allowedRoleIds: Set<string>,
): Promise<string[]> {
  if (allowedRoleIds.size === 0) return [];

  const membersSnap = await db
    .collectionGroup(ORGANIZATIONS_COLLECTION)
    .where(admin.firestore.FieldPath.documentId(), '==', organizationId)
    .get();

  const targetUserIds: string[] = [];

  for (const memberDoc of membersSnap.docs) {
    const userId = memberDoc.ref.parent.parent?.id;
    if (!userId) continue;

    const orgData = memberDoc.data() as Record<string, any>;
    const appAccessRoleId = (orgData.app_access_role_id as string) || orgData.role_in_org;
    if (appAccessRoleId && allowedRoleIds.has(appAccessRoleId)) {
      targetUserIds.push(userId);
    }
  }

  return targetUserIds;
}

async function fetchDeviceTokens(
  organizationId: string,
  userIds: string[],
): Promise<{ token: string; deviceId: string }[]> {
  const tokens: { token: string; deviceId: string }[] = [];
  const chunks: string[][] = [];

  for (let i = 0; i < userIds.length; i += 10) {
    chunks.push(userIds.slice(i, i + 10));
  }

  for (const chunk of chunks) {
    const snapshot = await db
      .collection(DEVICES_COLLECTION)
      .where('organizationId', '==', organizationId)
      .where('appId', '==', CLIENT_ANDROID_APP_ID)
      .where('platform', '==', ANDROID_PLATFORM)
      .where('userId', 'in', chunk)
      .get();

    snapshot.forEach((doc) => {
      const data = doc.data() as Record<string, any>;
      const token = data.fcmToken as string | undefined;
      if (token) {
        tokens.push({ token, deviceId: doc.id });
      }
    });
  }

  return tokens;
}

async function removeInvalidTokens(deviceIds: string[]) {
  const batch = db.batch();
  deviceIds.forEach((deviceId) => {
    batch.delete(db.collection(DEVICES_COLLECTION).doc(deviceId));
  });
  await batch.commit();
}

async function sendToTokens(
  tokens: { token: string; deviceId: string }[],
  title: string,
  body: string,
  data: Record<string, string>,
): Promise<{ success: number; failure: number }> {
  let success = 0;
  let failure = 0;
  const invalidDeviceIds: string[] = [];

  for (let i = 0; i < tokens.length; i += 500) {
    const chunk = tokens.slice(i, i + 500);
    const response = await admin.messaging().sendEachForMulticast({
      tokens: chunk.map((entry) => entry.token),
      notification: { title, body },
      data,
    });

    success += response.successCount;
    failure += response.failureCount;

    response.responses.forEach((res, index) => {
      if (!res.success) {
        const code = res.error?.code || '';
        if (INVALID_TOKEN_ERRORS.has(code)) {
          invalidDeviceIds.push(chunk[index].deviceId);
        }
      }
    });
  }

  if (invalidDeviceIds.length > 0) {
    await removeInvalidTokens(invalidDeviceIds);
  }

  return { success, failure };
}

export async function sendCashLedgerTransactionNotification(
  transactionId: string,
  transactionData: FirebaseFirestore.DocumentData,
): Promise<void> {
  if (!isCashLedgerTransaction(transactionData)) return;

  const organizationId = transactionData.organizationId as string | undefined;
  if (!organizationId) return;

  const jobId = `cash_ledger_${transactionId}`;
  const jobRef = db.collection(NOTIFICATION_JOBS_COLLECTION).doc(jobId);
  const jobSnap = await jobRef.get();
  if (jobSnap.exists) return;

  await jobRef.set({
    transactionId,
    organizationId,
    type: 'cashLedgerTransaction',
    status: 'pending',
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  try {
    const allowedRoleIds = await fetchAllowedRoleIds(organizationId);
    const userIds = await fetchTargetUserIds(organizationId, allowedRoleIds);

    if (userIds.length === 0) {
      await jobRef.update({
        status: 'skipped',
        reason: 'no_matching_users',
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      return;
    }

    const tokens = await fetchDeviceTokens(organizationId, userIds);
    if (tokens.length === 0) {
      await jobRef.update({
        status: 'skipped',
        reason: 'no_device_tokens',
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      return;
    }

    const amount = transactionData.amount as number | undefined;
    const title = 'Cash Ledger';
    const body = `Amount: ${formatAmount(amount)}`;
    const payload = {
      transactionId,
      organizationId,
      ledgerType: (transactionData.ledgerType as string) || '',
      category: (transactionData.category as string) || '',
    };

    const result = await sendToTokens(tokens, title, body, payload);

    await jobRef.update({
      status: 'sent',
      successCount: result.success,
      failureCount: result.failure,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  } catch (error) {
    await jobRef.update({
      status: 'error',
      error: error instanceof Error ? error.message : String(error),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  }
}
