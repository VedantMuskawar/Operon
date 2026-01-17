/**
 * Cloud Function configuration presets
 * 
 * These presets standardize function configurations across the codebase
 * to ensure consistent behavior, performance, and resource allocation.
 */

/**
 * Default region for all Cloud Functions
 * Using us-central1 temporarily to avoid Eventarc issues
 * TODO: Switch back to 'asia-south1' after enabling Eventarc API
 */
export const DEFAULT_REGION = 'us-central1' as const;

/**
 * Alternative region (for future use)
 */
export const ALTERNATIVE_REGION = 'asia-south1' as const;

/**
 * Light trigger configuration
 * For simple Firestore triggers that perform quick updates
 * 
 * Use for:
 * - Simple document updates
 * - Incrementing counters
 * - Basic validation
 */
export const LIGHT_TRIGGER_CONFIG = {
  region: DEFAULT_REGION,
  timeoutSeconds: 60,
  memory: '256MiB' as const,
  maxInstances: 10,
};

/**
 * Standard trigger configuration
 * For most Firestore triggers with moderate processing
 * 
 * Use for:
 * - Document updates with subcollection writes
 * - Multiple document updates
 * - Basic calculations
 */
export const STANDARD_TRIGGER_CONFIG = {
  region: DEFAULT_REGION,
  timeoutSeconds: 120,
  memory: '512MiB' as const,
  maxInstances: 10,
};

/**
 * Heavy processing configuration
 * For complex operations that require more resources
 * 
 * Use for:
 * - Batch processing multiple documents
 * - Complex calculations
 * - Multiple API calls
 * - Data transformations
 */
export const HEAVY_PROCESSING_CONFIG = {
  region: DEFAULT_REGION,
  timeoutSeconds: 540, // 9 minutes (max for v2 functions)
  memory: '512MiB' as const,
  maxInstances: 10,
};

/**
 * Callable function configuration
 * For HTTP callable functions (v2)
 */
export const CALLABLE_FUNCTION_CONFIG = {
  region: DEFAULT_REGION,
  timeoutSeconds: 540, // 9 minutes (max for v2 functions)
  memory: '512MiB' as const,
};

/**
 * Scheduled function configuration
 * For PubSub scheduled functions
 */
export const SCHEDULED_FUNCTION_CONFIG = {
  region: DEFAULT_REGION,
  timeoutSeconds: 540,
  memory: '512MiB' as const,
  maxInstances: 1,
};

/**
 * Get configuration for v1 Firestore trigger
 * 
 * @param config - Configuration preset
 * @returns v1 function builder with applied configuration
 */
export function getV1TriggerConfig(config: typeof LIGHT_TRIGGER_CONFIG | typeof STANDARD_TRIGGER_CONFIG) {
  return {
    region: config.region,
    timeoutSeconds: config.timeoutSeconds,
    memory: config.memory,
    maxInstances: config.maxInstances,
  };
}
