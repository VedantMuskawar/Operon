"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.createTripWage = void 0;
const https_1 = require("firebase-functions/v2/https");
const firestore_1 = require("firebase-admin/firestore");
const function_config_1 = require("../shared/function-config");
const logger_1 = require("../shared/logger");
const db = (0, firestore_1.getFirestore)();
const TRIP_WAGES_COLLECTION = 'TRIP_WAGES';
exports.createTripWage = (0, https_1.onCall)(function_config_1.CALLABLE_FUNCTION_CONFIG, async (request) => {
    var _a, _b;
    try {
        if (!request.auth) {
            throw new https_1.HttpsError('unauthenticated', 'User must be authenticated');
        }
        const tripWage = (_a = request.data) === null || _a === void 0 ? void 0 : _a.tripWage;
        if (!tripWage || typeof tripWage !== 'object') {
            throw new https_1.HttpsError('invalid-argument', 'Missing tripWage payload');
        }
        const docRef = db.collection(TRIP_WAGES_COLLECTION).doc();
        const tripWageId = docRef.id;
        const payload = Object.assign(Object.assign({}, tripWage), { tripWageId, createdBy: request.auth.uid, createdAt: firestore_1.FieldValue.serverTimestamp(), updatedAt: firestore_1.FieldValue.serverTimestamp() });
        await docRef.set(payload);
        (0, logger_1.logInfo)('TripWages', 'createTripWage', 'Trip wage created', {
            tripWageId,
            createdBy: request.auth.uid,
        });
        return { tripWageId };
    }
    catch (error) {
        const errorMessage = error instanceof Error ? error.message : String(error);
        const errorStack = error instanceof Error ? error.stack : '';
        (0, logger_1.logError)('TripWages', 'createTripWage', 'Failed to create trip wage', error instanceof Error ? error : new Error(String(error)));
        console.error('[createTripWage] Full error details:', {
            errorMessage,
            errorStack,
            errorCode: error === null || error === void 0 ? void 0 : error.code,
            errorType: (_b = error === null || error === void 0 ? void 0 : error.constructor) === null || _b === void 0 ? void 0 : _b.name,
        });
        if (error instanceof https_1.HttpsError) {
            throw error;
        }
        // Check for specific Firebase error codes
        if ((error === null || error === void 0 ? void 0 : error.code) === 'permission-denied') {
            throw new https_1.HttpsError('permission-denied', 'You do not have permission to create a trip wage');
        }
        throw new https_1.HttpsError('internal', errorMessage);
    }
});
//# sourceMappingURL=create-trip-wage.js.map