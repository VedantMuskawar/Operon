"use strict";
var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    var desc = Object.getOwnPropertyDescriptor(m, k);
    if (!desc || ("get" in desc ? !m.__esModule : desc.writable || desc.configurable)) {
      desc = { enumerable: true, get: function() { return m[k]; } };
    }
    Object.defineProperty(o, k2, desc);
}) : (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    o[k2] = m[k];
}));
var __setModuleDefault = (this && this.__setModuleDefault) || (Object.create ? (function(o, v) {
    Object.defineProperty(o, "default", { enumerable: true, value: v });
}) : function(o, v) {
    o["default"] = v;
});
var __importStar = (this && this.__importStar) || (function () {
    var ownKeys = function(o) {
        ownKeys = Object.getOwnPropertyNames || function (o) {
            var ar = [];
            for (var k in o) if (Object.prototype.hasOwnProperty.call(o, k)) ar[ar.length] = k;
            return ar;
        };
        return ownKeys(o);
    };
    return function (mod) {
        if (mod && mod.__esModule) return mod;
        var result = {};
        if (mod != null) for (var k = ownKeys(mod), i = 0; i < k.length; i++) if (k[i] !== "default") __createBinding(result, mod, k[i]);
        __setModuleDefault(result, mod);
        return result;
    };
})();
Object.defineProperty(exports, "__esModule", { value: true });
exports.sendCashLedgerTransactionNotification = sendCashLedgerTransactionNotification;
const admin = __importStar(require("firebase-admin"));
const constants_1 = require("../shared/constants");
const db = admin.firestore();
const ROLE_SECTION_KEY = 'TransactionNotifications';
const CLIENT_ANDROID_APP_ID = 'client_android';
const ANDROID_PLATFORM = 'android';
const INVALID_TOKEN_ERRORS = new Set([
    'messaging/invalid-registration-token',
    'messaging/registration-token-not-registered',
]);
function isCashLedgerTransaction(data) {
    const ledgerType = data.ledgerType || '';
    const category = data.category || '';
    if (ledgerType === 'clientLedger') {
        return (category === 'advance' ||
            category === 'tripPayment' ||
            category === 'clientCredit');
    }
    if (category === 'clientPayment' || category === 'refund') {
        return true;
    }
    if (ledgerType === 'vendorLedger' && category === 'vendorPurchase') {
        return true;
    }
    if ((ledgerType === 'vendorLedger' && category === 'vendorPayment') ||
        (ledgerType === 'employeeLedger' && category === 'salaryDebit') ||
        (ledgerType === 'organizationLedger' && category === 'generalExpense')) {
        return true;
    }
    return false;
}
function formatAmount(amount) {
    const normalized = typeof amount === 'number' && !Number.isNaN(amount) ? amount : 0;
    return `\u20b9${normalized.toFixed(2)}`;
}
async function fetchAllowedRoleIds(organizationId) {
    var _a, _b;
    const rolesSnap = await db
        .collection(constants_1.ORGANIZATIONS_COLLECTION)
        .doc(organizationId)
        .collection(constants_1.APP_ACCESS_ROLES_COLLECTION)
        .get();
    const allowed = new Set();
    for (const doc of rolesSnap.docs) {
        const data = doc.data();
        const roleId = data.roleId || doc.id;
        const isAdmin = data.isAdmin === true;
        const sectionAllowed = ((_b = (_a = data.permissions) === null || _a === void 0 ? void 0 : _a.sections) === null || _b === void 0 ? void 0 : _b[ROLE_SECTION_KEY]) === true;
        if (isAdmin || sectionAllowed) {
            allowed.add(roleId);
        }
    }
    return allowed;
}
async function fetchTargetUserIds(organizationId, allowedRoleIds) {
    var _a;
    if (allowedRoleIds.size === 0)
        return [];
    const membersSnap = await db
        .collectionGroup(constants_1.ORGANIZATIONS_COLLECTION)
        .where(admin.firestore.FieldPath.documentId(), '==', organizationId)
        .get();
    const targetUserIds = [];
    for (const memberDoc of membersSnap.docs) {
        const userId = (_a = memberDoc.ref.parent.parent) === null || _a === void 0 ? void 0 : _a.id;
        if (!userId)
            continue;
        const orgData = memberDoc.data();
        const appAccessRoleId = orgData.app_access_role_id || orgData.role_in_org;
        if (appAccessRoleId && allowedRoleIds.has(appAccessRoleId)) {
            targetUserIds.push(userId);
        }
    }
    return targetUserIds;
}
async function fetchDeviceTokens(organizationId, userIds) {
    const tokens = [];
    const chunks = [];
    for (let i = 0; i < userIds.length; i += 10) {
        chunks.push(userIds.slice(i, i + 10));
    }
    for (const chunk of chunks) {
        const snapshot = await db
            .collection(constants_1.DEVICES_COLLECTION)
            .where('organizationId', '==', organizationId)
            .where('appId', '==', CLIENT_ANDROID_APP_ID)
            .where('platform', '==', ANDROID_PLATFORM)
            .where('userId', 'in', chunk)
            .select('fcmToken')
            .get();
        snapshot.forEach((doc) => {
            const data = doc.data();
            const token = data.fcmToken;
            if (token) {
                tokens.push({ token, deviceId: doc.id });
            }
        });
    }
    return tokens;
}
async function removeInvalidTokens(deviceIds) {
    const batch = db.batch();
    deviceIds.forEach((deviceId) => {
        batch.delete(db.collection(constants_1.DEVICES_COLLECTION).doc(deviceId));
    });
    await batch.commit();
}
async function sendToTokens(tokens, title, body, data) {
    let success = 0;
    let failure = 0;
    const invalidDeviceIds = [];
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
            var _a;
            if (!res.success) {
                const code = ((_a = res.error) === null || _a === void 0 ? void 0 : _a.code) || '';
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
async function sendCashLedgerTransactionNotification(transactionId, transactionData) {
    if (!isCashLedgerTransaction(transactionData))
        return;
    const organizationId = transactionData.organizationId;
    if (!organizationId)
        return;
    const jobId = `cash_ledger_${transactionId}`;
    const jobRef = db.collection(constants_1.NOTIFICATION_JOBS_COLLECTION).doc(jobId);
    const jobSnap = await jobRef.get();
    if (jobSnap.exists)
        return;
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
        const amount = transactionData.amount;
        const title = 'Cash Ledger';
        const body = `Amount: ${formatAmount(amount)}`;
        const payload = {
            transactionId,
            organizationId,
            ledgerType: transactionData.ledgerType || '',
            category: transactionData.category || '',
        };
        const result = await sendToTokens(tokens, title, body, payload);
        await jobRef.update({
            status: 'sent',
            successCount: result.success,
            failureCount: result.failure,
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
    }
    catch (error) {
        await jobRef.update({
            status: 'error',
            error: error instanceof Error ? error.message : String(error),
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
    }
}
//# sourceMappingURL=transaction-notifications.js.map