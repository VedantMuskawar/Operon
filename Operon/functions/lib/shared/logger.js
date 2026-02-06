"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.toHttpsError = toHttpsError;
exports.logInfo = logInfo;
exports.logWarning = logWarning;
exports.logError = logError;
const https_1 = require("firebase-functions/v2/https");
/**
 * Map a thrown error to HttpsError for callables. Use in catch blocks.
 */
function toHttpsError(err, defaultCode = 'internal') {
    if (err instanceof https_1.HttpsError)
        return err;
    const message = err instanceof Error ? err.message : String(err);
    return new https_1.HttpsError(defaultCode, message);
}
/**
 * Log an info message
 *
 * @param module - Module name (e.g., 'Transaction', 'Order')
 * @param functionName - Function name (e.g., 'onTransactionCreated')
 * @param message - Log message
 * @param context - Optional context data
 */
function logInfo(module, functionName, message, context) {
    if (context) {
        console.log(`[${module}/${functionName}] ${message}`, context);
    }
    else {
        console.log(`[${module}/${functionName}] ${message}`);
    }
}
/**
 * Log a warning message
 *
 * @param module - Module name
 * @param functionName - Function name
 * @param message - Warning message
 * @param context - Optional context data
 */
function logWarning(module, functionName, message, context) {
    if (context) {
        console.warn(`[${module}/${functionName}] ${message}`, context);
    }
    else {
        console.warn(`[${module}/${functionName}] ${message}`);
    }
}
/**
 * Log an error message
 *
 * @param module - Module name
 * @param functionName - Function name
 * @param message - Error message
 * @param error - Error object or string
 * @param context - Optional context data
 */
function logError(module, functionName, message, error, context) {
    const errorInfo = error instanceof Error
        ? Object.assign({ error: error.message, stack: error.stack }, context) : error
        ? Object.assign({ error }, context) : context;
    if (errorInfo) {
        console.error(`[${module}/${functionName}] ${message}`, errorInfo);
    }
    else {
        console.error(`[${module}/${functionName}] ${message}`);
    }
}
//# sourceMappingURL=logger.js.map