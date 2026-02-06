import { HttpsError } from 'firebase-functions/v2/https';

/**
 * Standardized logging helper for Cloud Functions
 *
 * Provides consistent logging format across all functions:
 * Format: [Module/Function] Message with context
 */

export type HttpsErrorCode =
  | 'ok'
  | 'cancelled'
  | 'unknown'
  | 'invalid-argument'
  | 'deadline-exceeded'
  | 'not-found'
  | 'already-exists'
  | 'permission-denied'
  | 'resource-exhausted'
  | 'failed-precondition'
  | 'aborted'
  | 'out-of-range'
  | 'unauthenticated'
  | 'internal'
  | 'unavailable'
  | 'data-loss';

/**
 * Map a thrown error to HttpsError for callables. Use in catch blocks.
 */
export function toHttpsError(
  err: unknown,
  defaultCode: HttpsErrorCode = 'internal',
): HttpsError {
  if (err instanceof HttpsError) return err;
  const message = err instanceof Error ? err.message : String(err);
  return new HttpsError(defaultCode, message);
}

export interface LogContext {
  [key: string]: any;
}

/**
 * Log an info message
 * 
 * @param module - Module name (e.g., 'Transaction', 'Order')
 * @param functionName - Function name (e.g., 'onTransactionCreated')
 * @param message - Log message
 * @param context - Optional context data
 */
export function logInfo(
  module: string,
  functionName: string,
  message: string,
  context?: LogContext,
): void {
  if (context) {
    console.log(`[${module}/${functionName}] ${message}`, context);
  } else {
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
export function logWarning(
  module: string,
  functionName: string,
  message: string,
  context?: LogContext,
): void {
  if (context) {
    console.warn(`[${module}/${functionName}] ${message}`, context);
  } else {
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
export function logError(
  module: string,
  functionName: string,
  message: string,
  error?: Error | string,
  context?: LogContext,
): void {
  const errorInfo = error instanceof Error
    ? {
        error: error.message,
        stack: error.stack,
        ...context,
      }
    : error
      ? { error, ...context }
      : context;

  if (errorInfo) {
    console.error(`[${module}/${functionName}] ${message}`, errorInfo);
  } else {
    console.error(`[${module}/${functionName}] ${message}`);
  }
}
