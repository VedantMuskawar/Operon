import * as admin from 'firebase-admin';

/**
 * Remove all undefined values from an object (recursive cleanup for nested objects)
 * Also explicitly excludes the 'status' field which is no longer part of the transaction model
 * 
 * @param obj - The object to clean
 * @returns A cleaned object without undefined values and without 'status' field
 */
export function removeUndefinedFields(obj: any): any {
  if (obj === null || obj === undefined) {
    return obj;
  }
  
  if (Array.isArray(obj)) {
    return obj.map(item => removeUndefinedFields(item));
  }
  
  if (typeof obj !== 'object') {
    return obj;
  }
  
  const cleaned: any = {};
  const excludeFields = ['status']; // Fields to explicitly exclude
  
  for (const key in obj) {
    if (obj.hasOwnProperty(key)) {
      // Skip excluded fields (like status)
      if (excludeFields.includes(key)) {
        continue;
      }
      
      const value = obj[key];
      // Skip undefined values
      if (value !== undefined) {
        if (typeof value === 'object' && value !== null && !(value instanceof admin.firestore.Timestamp) && !(value instanceof admin.firestore.FieldValue)) {
          cleaned[key] = removeUndefinedFields(value);
        } else {
          cleaned[key] = value;
        }
      }
    }
  }
  return cleaned;
}

/**
 * Get transaction date from transaction document snapshot
 * Falls back to createTime or current date if createdAt is missing
 * 
 * @param snapshot - Firestore document snapshot
 * @returns Transaction date
 */
export function getTransactionDate(snapshot: FirebaseFirestore.DocumentSnapshot): Date {
  const createdAt = snapshot.get('createdAt') as admin.firestore.Timestamp | undefined;
  if (createdAt) {
    return createdAt.toDate();
  }
  return snapshot.createTime?.toDate() ?? new Date();
}

/**
 * Validate transaction has required fields
 * 
 * @param transaction - Transaction data
 * @returns True if valid, false otherwise
 */
export function validateTransaction(transaction: any): boolean {
  return !!(
    transaction?.organizationId &&
    transaction?.financialYear &&
    transaction?.amount !== undefined &&
    transaction?.type &&
    transaction?.ledgerType
  );
}
