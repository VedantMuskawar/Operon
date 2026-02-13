
// Use v1 for Firestore triggers for compatibility
import * as functions from 'firebase-functions/v1';
import * as admin from 'firebase-admin';

if (!admin.apps.length) {
  admin.initializeApp();
}
const db = admin.firestore();

/**
 * Utility to sync balance from ledger to entity
 * @param ledgerSnap Ledger document snapshot
 * @param entityCollection Collection name (CLIENT, VENDOR, EMPLOYEE)
 */
async function syncBalance(
  ledgerSnap: FirebaseFirestore.DocumentSnapshot,
  entityCollection: string
) {
  const ledgerData = ledgerSnap.data();
  if (!ledgerData || typeof ledgerData.CurrentBalance === 'undefined') return;
  const entityId = ledgerSnap.id;
  const entityRef = db.collection(entityCollection).doc(entityId);
  try {
    await entityRef.update({ CurrentBalance: ledgerData.CurrentBalance });
  } catch (err) {
    console.error(`Failed to sync balance for ${entityCollection}/${entityId}:`, err);
  }
}

// CLIENT_LEDGER -> CLIENT
export const syncClientBalance = functions.firestore
  .document('CLIENT_LEDGER/{clientId}')
  .onWrite(async (change, context) => {
    const after = change.after;
    if (!after.exists) return null;
    await syncBalance(after, 'CLIENT');
    return null;
  });

// VENDOR_LEDGER -> VENDOR
export const syncVendorBalance = functions.firestore
  .document('VENDOR_LEDGER/{vendorId}')
  .onWrite(async (change, context) => {
    const after = change.after;
    if (!after.exists) return null;
    await syncBalance(after, 'VENDOR');
    return null;
  });

// EMPLOYEE_LEDGER -> EMPLOYEE
export const syncEmployeeBalance = functions.firestore
  .document('EMPLOYEE_LEDGER/{employeeId}')
  .onWrite(async (change, context) => {
    const after = change.after;
    if (!after.exists) return null;
    await syncBalance(after, 'EMPLOYEE');
    return null;
  });
