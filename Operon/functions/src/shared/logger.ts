/**
 * Standardized logging helper for Cloud Functions
 * 
 * Provides consistent logging format across all functions:
 * Format: [Module/Function] Message with context
 */

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
