"use strict";
/**
 * Cloud Function configuration presets (v2)
 *
 * Standardizes region (asia-south1), concurrency, memory, and retry across the codebase.
 */
Object.defineProperty(exports, "__esModule", { value: true });
exports.SCHEDULED_FUNCTION_CONFIG = exports.CALLABLE_FUNCTION_CONFIG = exports.HEAVY_PROCESSING_CONFIG = exports.STANDARD_TRIGGER_CONFIG = exports.LIGHT_TRIGGER_CONFIG = exports.SCHEDULED_FUNCTION_OPTS = exports.CALLABLE_OPTS = exports.CRITICAL_TRIGGER_OPTS = exports.HEAVY_TRIGGER_OPTS = exports.STANDARD_TRIGGER_OPTS = exports.LIGHT_TRIGGER_OPTS = exports.DEFAULT_REGION = void 0;
exports.DEFAULT_REGION = 'asia-south1';
/**
 * Light trigger options – simple Firestore triggers (quick updates, counters, validation).
 */
exports.LIGHT_TRIGGER_OPTS = {
    region: exports.DEFAULT_REGION,
    timeoutSeconds: 60,
    memory: '256MiB',
    maxInstances: 10,
};
/**
 * Standard trigger options – moderate processing (subcollection writes, multiple docs).
 */
exports.STANDARD_TRIGGER_OPTS = {
    region: exports.DEFAULT_REGION,
    timeoutSeconds: 120,
    memory: '512MiB',
    maxInstances: 10,
};
/**
 * Heavy trigger options – batch processing, complex calculations, multiple API calls.
 */
exports.HEAVY_TRIGGER_OPTS = {
    region: exports.DEFAULT_REGION,
    timeoutSeconds: 540,
    memory: '512MiB',
    maxInstances: 10,
};
/**
 * Critical background trigger options – same as standard but with retry enabled (e.g. onTransactionCreated).
 */
exports.CRITICAL_TRIGGER_OPTS = Object.assign(Object.assign({}, exports.STANDARD_TRIGGER_OPTS), { retry: true });
/**
 * Callable / HTTP options – onCall and onRequest (concurrency 80).
 */
exports.CALLABLE_OPTS = {
    region: exports.DEFAULT_REGION,
    timeoutSeconds: 540,
    memory: '512MiB',
    concurrency: 80,
};
/**
 * Scheduled function options.
 */
exports.SCHEDULED_FUNCTION_OPTS = {
    region: exports.DEFAULT_REGION,
    timeoutSeconds: 540,
    memory: '512MiB',
    maxInstances: 1,
};
/** @deprecated Use LIGHT_TRIGGER_OPTS */
exports.LIGHT_TRIGGER_CONFIG = Object.assign({}, exports.LIGHT_TRIGGER_OPTS);
/** @deprecated Use STANDARD_TRIGGER_OPTS */
exports.STANDARD_TRIGGER_CONFIG = Object.assign({}, exports.STANDARD_TRIGGER_OPTS);
/** @deprecated Use HEAVY_TRIGGER_OPTS */
exports.HEAVY_PROCESSING_CONFIG = Object.assign({}, exports.HEAVY_TRIGGER_OPTS);
/** @deprecated Use CALLABLE_OPTS */
exports.CALLABLE_FUNCTION_CONFIG = Object.assign({}, exports.CALLABLE_OPTS);
/** @deprecated Use SCHEDULED_FUNCTION_OPTS */
exports.SCHEDULED_FUNCTION_CONFIG = Object.assign({}, exports.SCHEDULED_FUNCTION_OPTS);
//# sourceMappingURL=function-config.js.map