"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.deleteTripWage = void 0;
const https_1 = require("firebase-functions/v2/https");
const firestore_1 = require("firebase-admin/firestore");
const function_config_1 = require("../shared/function-config");
const logger_1 = require("../shared/logger");
const db = (0, firestore_1.getFirestore)();
const TRIP_WAGES_COLLECTION = 'TRIP_WAGES';
exports.deleteTripWage = (0, https_1.onCall)(function_config_1.CALLABLE_FUNCTION_CONFIG, async (request) => {
    var _a, _b;
    let tripWageId;
    try {
        // Validate authentication
        if (!request.auth) {
            throw new https_1.HttpsError('unauthenticated', 'User must be authenticated');
        }
        // Extract and validate tripWageId
        tripWageId = (_a = request.data) === null || _a === void 0 ? void 0 : _a.tripWageId;
        if (!tripWageId || tripWageId.trim().length === 0) {
            throw new https_1.HttpsError('invalid-argument', 'Missing or empty tripWageId');
        }
        // Perform the deletion
        const tripWageRef = db.collection(TRIP_WAGES_COLLECTION).doc(tripWageId);
        // Check if document exists before deleting
        const docSnapshot = await tripWageRef.get();
        if (!docSnapshot.exists) {
            (0, logger_1.logInfo)('TripWages', 'deleteTripWage', 'Trip wage not found, skipping delete', {
                tripWageId,
            });
            // Return success even if document doesn't exist (idempotent behavior)
            return { success: true, message: 'Trip wage was not found, considered deleted' };
        }
        // Delete the document
        await tripWageRef.delete();
        (0, logger_1.logInfo)('TripWages', 'deleteTripWage', 'Trip wage deleted successfully', {
            tripWageId,
            deletedBy: request.auth.uid,
        });
        return { success: true };
    }
    catch (error) {
        const errorMessage = error instanceof Error ? error.message : String(error);
        const errorStack = error instanceof Error ? error.stack : '';
        (0, logger_1.logError)('TripWages', 'deleteTripWage', 'Failed to delete trip wage', error instanceof Error ? error : new Error(String(error)));
        console.error('[deleteTripWage] Full error details:', {
            tripWageId,
            errorMessage,
            errorStack,
            errorCode: error === null || error === void 0 ? void 0 : error.code,
            errorType: (_b = error === null || error === void 0 ? void 0 : error.constructor) === null || _b === void 0 ? void 0 : _b.name,
        });
        // If already an HttpsError, just rethrow
        if (error instanceof https_1.HttpsError) {
            throw error;
        }
        // Check for specific Firebase error codes
        if ((error === null || error === void 0 ? void 0 : error.code) === 'permission-denied') {
            throw new https_1.HttpsError('permission-denied', 'You do not have permission to delete this trip wage');
        }
        if ((error === null || error === void 0 ? void 0 : error.code) === 'not-found') {
            throw new https_1.HttpsError('not-found', 'Trip wage document not found');
        }
        // For any other error, return internal error with the message
        throw new https_1.HttpsError('internal', errorMessage || 'Unknown error occurred during deletion');
    }
});
//# sourceMappingURL=delete-trip-wage.js.map