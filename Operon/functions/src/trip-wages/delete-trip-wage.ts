import { onCall, HttpsError } from 'firebase-functions/v2/https';
import { getFirestore } from 'firebase-admin/firestore';
import { CALLABLE_FUNCTION_CONFIG } from '../shared/function-config';
import { logInfo, logError } from '../shared/logger';

const db = getFirestore();
const TRIP_WAGES_COLLECTION = 'TRIP_WAGES';

export const deleteTripWage = onCall(
  CALLABLE_FUNCTION_CONFIG,
  async (request) => {
    let tripWageId: string | undefined;
    
    try {
      // Validate authentication
      if (!request.auth) {
        throw new HttpsError('unauthenticated', 'User must be authenticated');
      }

      // Extract and validate tripWageId
      tripWageId = request.data?.tripWageId as string | undefined;
      if (!tripWageId || tripWageId.trim().length === 0) {
        throw new HttpsError('invalid-argument', 'Missing or empty tripWageId');
      }

      // Perform the deletion
      const tripWageRef = db.collection(TRIP_WAGES_COLLECTION).doc(tripWageId);
      
      // Check if document exists before deleting
      const docSnapshot = await tripWageRef.get();
      if (!docSnapshot.exists) {
        logInfo('TripWages', 'deleteTripWage', 'Trip wage not found, skipping delete', {
          tripWageId,
        });
        // Return success even if document doesn't exist (idempotent behavior)
        return { success: true, message: 'Trip wage was not found, considered deleted' };
      }

      // Delete the document
      await tripWageRef.delete();

      logInfo('TripWages', 'deleteTripWage', 'Trip wage deleted successfully', {
        tripWageId,
        deletedBy: request.auth.uid,
      });

      return { success: true };
    } catch (error) {
      const errorMessage = error instanceof Error ? error.message : String(error);
      const errorStack = error instanceof Error ? error.stack : '';
      
      logError(
        'TripWages',
        'deleteTripWage',
        'Failed to delete trip wage',
        error instanceof Error ? error : new Error(String(error)),
      );
      
      console.error('[deleteTripWage] Full error details:', {
        tripWageId,
        errorMessage,
        errorStack,
        errorCode: (error as any)?.code,
        errorType: error?.constructor?.name,
      });
      
      // If already an HttpsError, just rethrow
      if (error instanceof HttpsError) {
        throw error;
      }
      
      // Check for specific Firebase error codes
      if ((error as any)?.code === 'permission-denied') {
        throw new HttpsError('permission-denied', 'You do not have permission to delete this trip wage');
      }
      if ((error as any)?.code === 'not-found') {
        throw new HttpsError('not-found', 'Trip wage document not found');
      }
      
      // For any other error, return internal error with the message
      throw new HttpsError('internal', errorMessage || 'Unknown error occurred during deletion');
    }
  },
);
