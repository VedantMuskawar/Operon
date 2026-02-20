"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.validateLedgerAccess = void 0;
const https_1 = require("firebase-functions/v2/https");
const firestore_helpers_1 = require("../shared/firestore-helpers");
const function_config_1 = require("../shared/function-config");
const constants_1 = require("../shared/constants");
const db = (0, firestore_helpers_1.getFirestore)();
function normalizeString(value) {
    if (typeof value != 'string')
        return null;
    const trimmed = value.trim();
    return trimmed.length == 0 ? null : trimmed;
}
function toUniqueStringList(value) {
    if (!(value instanceof Array))
        return [];
    const set = new Set();
    for (const item of value) {
        const normalized = normalizeString(item);
        if (normalized != null)
            set.add(normalized);
    }
    return Array.from(set);
}
function isAdminRole(rawRole) {
    if (typeof rawRole != 'string')
        return false;
    const role = rawRole.trim().toLowerCase();
    return role == 'admin';
}
function buildAllowedLedgerEmployeeIds(userData) {
    const allowedIds = new Set();
    const legacyEmployeeId = normalizeString(userData['employee_id']);
    const trackingEmployeeId = normalizeString(userData['trackingEmployeeId']);
    const defaultLedgerEmployeeId = normalizeString(userData['defaultLedgerEmployeeId']);
    for (const id of toUniqueStringList(userData['ledgerEmployeeIds'])) {
        allowedIds.add(id);
    }
    if (defaultLedgerEmployeeId != null)
        allowedIds.add(defaultLedgerEmployeeId);
    if (trackingEmployeeId != null)
        allowedIds.add(trackingEmployeeId);
    if (legacyEmployeeId != null)
        allowedIds.add(legacyEmployeeId);
    return Array.from(allowedIds);
}
async function fetchOrganizationUser(organizationId, uid, phoneNumber) {
    var _a, _b, _c;
    const byDocId = await db
        .collection(constants_1.ORGANIZATIONS_COLLECTION)
        .doc(organizationId)
        .collection(constants_1.USERS_COLLECTION)
        .doc(uid)
        .get();
    if (byDocId.exists) {
        return {
            id: byDocId.id,
            data: ((_a = byDocId.data()) !== null && _a !== void 0 ? _a : {}),
        };
    }
    const usersCollection = db
        .collection(constants_1.ORGANIZATIONS_COLLECTION)
        .doc(organizationId)
        .collection(constants_1.USERS_COLLECTION);
    const byUid = await usersCollection.where('uid', '==', uid).limit(1).get();
    if (byUid.docs.length > 0) {
        const doc = byUid.docs[0];
        return { id: doc.id, data: ((_b = doc.data()) !== null && _b !== void 0 ? _b : {}) };
    }
    if (phoneNumber != null && phoneNumber.trim().length > 0) {
        const byPhone = await usersCollection.where('phone', '==', phoneNumber).limit(1).get();
        if (byPhone.docs.length > 0) {
            const doc = byPhone.docs[0];
            return { id: doc.id, data: ((_c = doc.data()) !== null && _c !== void 0 ? _c : {}) };
        }
    }
    return null;
}
/**
 * Validates whether the authenticated user can access a given employee ledger.
 *
 * This is intentionally additive and backward-compatible:
 * - Existing users with only `employee_id` still pass.
 * - New schema supports `trackingEmployeeId` + `ledgerEmployeeIds`.
 */
exports.validateLedgerAccess = (0, https_1.onCall)(function_config_1.CALLABLE_OPTS, async (request) => {
    var _a;
    if (request.auth == null) {
        throw new https_1.HttpsError('unauthenticated', 'Authentication required');
    }
    const data = ((_a = request.data) !== null && _a !== void 0 ? _a : {});
    const organizationId = normalizeString(data.organizationId);
    const ledgerEmployeeId = normalizeString(data.ledgerEmployeeId);
    if (organizationId == null || ledgerEmployeeId == null) {
        throw new https_1.HttpsError('invalid-argument', 'organizationId and ledgerEmployeeId are required');
    }
    try {
        const orgUser = await fetchOrganizationUser(organizationId, request.auth.uid, request.auth.token.phone_number);
        if (orgUser == null) {
            return {
                allowed: false,
                reason: 'USER_NOT_MAPPED',
                allowedLedgerEmployeeIds: [],
                userDocId: null,
            };
        }
        const userData = orgUser.data;
        const allowedLedgerEmployeeIds = buildAllowedLedgerEmployeeIds(userData);
        const roleInOrg = userData['role_in_org'];
        const roleId = userData['role_id'];
        const roleTitle = userData['roleTitle'];
        const isAdmin = isAdminRole(roleInOrg) || isAdminRole(roleId) || isAdminRole(roleTitle);
        const allowed = isAdmin || allowedLedgerEmployeeIds.includes(ledgerEmployeeId);
        return {
            allowed,
            reason: allowed ? 'OK' : 'LEDGER_NOT_ASSIGNED',
            allowedLedgerEmployeeIds,
            userDocId: orgUser.id,
            isAdmin,
        };
    }
    catch (error) {
        console.error('[validateLedgerAccess] Failed to validate ledger access', {
            organizationId,
            ledgerEmployeeId,
            uid: request.auth.uid,
            error,
        });
        throw new https_1.HttpsError('internal', 'Failed to validate ledger access');
    }
});
//# sourceMappingURL=validate-ledger-access.js.map