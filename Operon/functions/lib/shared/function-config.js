"use strict";
/**
 * Cloud Function configuration presets
 *
 * These presets standardize function configurations across the codebase
 * to ensure consistent behavior, performance, and resource allocation.
 */
Object.defineProperty(exports, "__esModule", { value: true });
exports.SCHEDULED_FUNCTION_CONFIG = exports.CALLABLE_FUNCTION_CONFIG = exports.HEAVY_PROCESSING_CONFIG = exports.STANDARD_TRIGGER_CONFIG = exports.LIGHT_TRIGGER_CONFIG = exports.ALTERNATIVE_REGION = exports.DEFAULT_REGION = void 0;
exports.getV1TriggerConfig = getV1TriggerConfig;
/**
 * Default region for all Cloud Functions
 * Using us-central1 temporarily to avoid Eventarc issues
 * TODO: Switch back to 'asia-south1' after enabling Eventarc API
 */
exports.DEFAULT_REGION = 'us-central1';
/**
 * Alternative region (for future use)
 */
exports.ALTERNATIVE_REGION = 'asia-south1';
/**
 * Light trigger configuration
 * For simple Firestore triggers that perform quick updates
 *
 * Use for:
 * - Simple document updates
 * - Incrementing counters
 * - Basic validation
 */
exports.LIGHT_TRIGGER_CONFIG = {
    region: exports.DEFAULT_REGION,
    timeoutSeconds: 60,
    memory: '256MiB',
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
exports.STANDARD_TRIGGER_CONFIG = {
    region: exports.DEFAULT_REGION,
    timeoutSeconds: 120,
    memory: '512MiB',
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
exports.HEAVY_PROCESSING_CONFIG = {
    region: exports.DEFAULT_REGION,
    timeoutSeconds: 540, // 9 minutes (max for v2 functions)
    memory: '512MiB',
    maxInstances: 10,
};
/**
 * Callable function configuration
 * For HTTP callable functions (v2)
 */
exports.CALLABLE_FUNCTION_CONFIG = {
    region: exports.DEFAULT_REGION,
    timeoutSeconds: 540, // 9 minutes (max for v2 functions)
    memory: '512MiB',
};
/**
 * Scheduled function configuration
 * For PubSub scheduled functions
 */
exports.SCHEDULED_FUNCTION_CONFIG = {
    region: exports.DEFAULT_REGION,
    timeoutSeconds: 540,
    memory: '512MiB',
    maxInstances: 1,
};
/**
 * Get configuration for v1 Firestore trigger
 *
 * @param config - Configuration preset
 * @returns v1 function builder with applied configuration
 */
function getV1TriggerConfig(config) {
    return {
        region: config.region,
        timeoutSeconds: config.timeoutSeconds,
        memory: config.memory,
        maxInstances: config.maxInstances,
    };
}
//# sourceMappingURL=function-config.js.map