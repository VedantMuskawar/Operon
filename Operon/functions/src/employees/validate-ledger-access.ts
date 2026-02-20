import { HttpsError, onCall } from 'firebase-functions/v2/https';
import { getFirestore } from '../shared/firestore-helpers';
import { CALLABLE_OPTS } from '../shared/function-config';
import { ORGANIZATIONS_COLLECTION, USERS_COLLECTION } from '../shared/constants';

const db = getFirestore();

type ValidateLedgerAccessRequest = {
  organizationId?: string;
  ledgerEmployeeId?: string;
};

function normalizeString(value: unknown): string | null {
  if (typeof value != 'string') return null;
  const trimmed = value.trim();
  return trimmed.length == 0 ? null : trimmed;
}

function toUniqueStringList(value: unknown): string[] {
  if (!(value instanceof Array)) return [];
  const set = new Set<string>();
  for (const item of value) {
    const normalized = normalizeString(item);
    if (normalized != null) set.add(normalized);
  }
  return Array.from(set);
}

function isAdminRole(rawRole: unknown): boolean {
  if (typeof rawRole != 'string') return false;
  const role = rawRole.trim().toLowerCase();
  return role == 'admin';
}

function buildAllowedLedgerEmployeeIds(userData: Record<string, unknown>): string[] {
  const allowedIds = new Set<string>();

  const legacyEmployeeId = normalizeString(userData['employee_id']);
  const trackingEmployeeId = normalizeString(userData['trackingEmployeeId']);
  const defaultLedgerEmployeeId = normalizeString(userData['defaultLedgerEmployeeId']);

  for (const id of toUniqueStringList(userData['ledgerEmployeeIds'])) {
    allowedIds.add(id);
  }

  if (defaultLedgerEmployeeId != null) allowedIds.add(defaultLedgerEmployeeId);
  if (trackingEmployeeId != null) allowedIds.add(trackingEmployeeId);
  if (legacyEmployeeId != null) allowedIds.add(legacyEmployeeId);

  return Array.from(allowedIds);
}

async function fetchOrganizationUser(
  organizationId: string,
  uid: string,
  phoneNumber?: string,
): Promise<{ id: string; data: Record<string, unknown> } | null> {
  const byDocId = await db
    .collection(ORGANIZATIONS_COLLECTION)
    .doc(organizationId)
    .collection(USERS_COLLECTION)
    .doc(uid)
    .get();

  if (byDocId.exists) {
    return {
      id: byDocId.id,
      data: (byDocId.data() ?? {}) as Record<string, unknown>,
    };
  }

  const usersCollection = db
    .collection(ORGANIZATIONS_COLLECTION)
    .doc(organizationId)
    .collection(USERS_COLLECTION);

  const byUid = await usersCollection.where('uid', '==', uid).limit(1).get();
  if (byUid.docs.length > 0) {
    const doc = byUid.docs[0];
    return { id: doc.id, data: (doc.data() ?? {}) as Record<string, unknown> };
  }

  if (phoneNumber != null && phoneNumber.trim().length > 0) {
    const byPhone = await usersCollection.where('phone', '==', phoneNumber).limit(1).get();
    if (byPhone.docs.length > 0) {
      const doc = byPhone.docs[0];
      return { id: doc.id, data: (doc.data() ?? {}) as Record<string, unknown> };
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
export const validateLedgerAccess = onCall(
  CALLABLE_OPTS,
  async (request) => {
    if (request.auth == null) {
      throw new HttpsError('unauthenticated', 'Authentication required');
    }

    const data = (request.data ?? {}) as ValidateLedgerAccessRequest;
    const organizationId = normalizeString(data.organizationId);
    const ledgerEmployeeId = normalizeString(data.ledgerEmployeeId);

    if (organizationId == null || ledgerEmployeeId == null) {
      throw new HttpsError(
        'invalid-argument',
        'organizationId and ledgerEmployeeId are required',
      );
    }

    try {
      const orgUser = await fetchOrganizationUser(
        organizationId,
        request.auth.uid,
        request.auth.token.phone_number as string | undefined,
      );

      if (orgUser == null) {
        return {
          allowed: false,
          reason: 'USER_NOT_MAPPED',
          allowedLedgerEmployeeIds: [] as string[],
          userDocId: null,
        };
      }

      const userData = orgUser.data;
      const allowedLedgerEmployeeIds = buildAllowedLedgerEmployeeIds(userData);

      const roleInOrg = userData['role_in_org'];
      const roleId = userData['role_id'];
      const roleTitle = userData['roleTitle'];
      const isAdmin =
        isAdminRole(roleInOrg) || isAdminRole(roleId) || isAdminRole(roleTitle);

      const allowed = isAdmin || allowedLedgerEmployeeIds.includes(ledgerEmployeeId);

      return {
        allowed,
        reason: allowed ? 'OK' : 'LEDGER_NOT_ASSIGNED',
        allowedLedgerEmployeeIds,
        userDocId: orgUser.id,
        isAdmin,
      };
    } catch (error) {
      console.error('[validateLedgerAccess] Failed to validate ledger access', {
        organizationId,
        ledgerEmployeeId,
        uid: request.auth.uid,
        error,
      });
      throw new HttpsError('internal', 'Failed to validate ledger access');
    }
  },
);
