import { onCall, HttpsError } from 'firebase-functions/v2/https';
import { getFirestore, FieldValue } from 'firebase-admin/firestore';
import { CALLABLE_FUNCTION_CONFIG } from '../shared/function-config';
import { logInfo, logError } from '../shared/logger';

const db = getFirestore();
const TRIP_WAGES_COLLECTION = 'TRIP_WAGES';

export const createTripWage = onCall(
  CALLABLE_FUNCTION_CONFIG,
  async (request) => {
    try {
      if (!request.auth) {
        throw new HttpsError('unauthenticated', 'User must be authenticated');
      }

      const tripWage = request.data?.tripWage as Record<string, unknown> | undefined;
      if (!tripWage || typeof tripWage !== 'object') {
        throw new HttpsError('invalid-argument', 'Missing tripWage payload');
      }

      const docRef = db.collection(TRIP_WAGES_COLLECTION).doc();
      const tripWageId = docRef.id;

      const payload = {
        ...tripWage,
        tripWageId,
        createdBy: request.auth.uid,
        createdAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      };

      await docRef.set(payload);

      logInfo('TripWages', 'createTripWage', 'Trip wage created', {
        tripWageId,
        createdBy: request.auth.uid,
      });

      return { tripWageId };
    } catch (error) {
      const errorMessage = error instanceof Error ? error.message : String(error);
      const errorStack = error instanceof Error ? error.stack : '';
      
      logError(
        'TripWages',
        'createTripWage',
        'Failed to create trip wage',
        error instanceof Error ? error : new Error(String(error)),
      );
      
      console.error('[createTripWage] Full error details:', {
        errorMessage,
        errorStack,
        errorCode: (error as any)?.code,
        errorType: error?.constructor?.name,
      });
      
      if (error instanceof HttpsError) {
        throw error;
      }
      
      // Check for specific Firebase error codes
      if ((error as any)?.code === 'permission-denied') {
        throw new HttpsError('permission-denied', 'You do not have permission to create a trip wage');
      }
      
      throw new HttpsError('internal', errorMessage);
    }
  },
);
