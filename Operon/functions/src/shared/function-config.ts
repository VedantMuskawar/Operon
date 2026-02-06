/**
 * Cloud Function configuration presets (v2)
 *
 * Standardizes region (asia-south1), concurrency, memory, and retry across the codebase.
 */

export const DEFAULT_REGION = 'asia-south1' as const;

/**
 * Light trigger options – simple Firestore triggers (quick updates, counters, validation).
 */
export const LIGHT_TRIGGER_OPTS = {
  region: DEFAULT_REGION,
  timeoutSeconds: 60,
  memory: '256MiB' as const,
  maxInstances: 10,
};

/**
 * Standard trigger options – moderate processing (subcollection writes, multiple docs).
 */
export const STANDARD_TRIGGER_OPTS = {
  region: DEFAULT_REGION,
  timeoutSeconds: 120,
  memory: '512MiB' as const,
  maxInstances: 10,
};

/**
 * Heavy trigger options – batch processing, complex calculations, multiple API calls.
 */
export const HEAVY_TRIGGER_OPTS = {
  region: DEFAULT_REGION,
  timeoutSeconds: 540,
  memory: '512MiB' as const,
  maxInstances: 10,
};

/**
 * Critical background trigger options – same as standard but with retry enabled (e.g. onTransactionCreated).
 */
export const CRITICAL_TRIGGER_OPTS = {
  ...STANDARD_TRIGGER_OPTS,
  retry: true as const,
};

/**
 * Callable / HTTP options – onCall and onRequest (concurrency 80).
 */
export const CALLABLE_OPTS = {
  region: DEFAULT_REGION,
  timeoutSeconds: 540,
  memory: '512MiB' as const,
  concurrency: 80,
};

/**
 * Scheduled function options.
 */
export const SCHEDULED_FUNCTION_OPTS = {
  region: DEFAULT_REGION,
  timeoutSeconds: 540,
  memory: '512MiB' as const,
  maxInstances: 1,
};

/** @deprecated Use LIGHT_TRIGGER_OPTS */
export const LIGHT_TRIGGER_CONFIG = { ...LIGHT_TRIGGER_OPTS };

/** @deprecated Use STANDARD_TRIGGER_OPTS */
export const STANDARD_TRIGGER_CONFIG = { ...STANDARD_TRIGGER_OPTS };

/** @deprecated Use HEAVY_TRIGGER_OPTS */
export const HEAVY_PROCESSING_CONFIG = { ...HEAVY_TRIGGER_OPTS };

/** @deprecated Use CALLABLE_OPTS */
export const CALLABLE_FUNCTION_CONFIG = { ...CALLABLE_OPTS };

/** @deprecated Use SCHEDULED_FUNCTION_OPTS */
export const SCHEDULED_FUNCTION_CONFIG = { ...SCHEDULED_FUNCTION_OPTS };
