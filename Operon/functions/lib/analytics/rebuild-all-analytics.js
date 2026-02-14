"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.rebuildAllAnalytics = void 0;
const scheduler_1 = require("firebase-functions/v2/scheduler");
const constants_1 = require("../shared/constants");
const financial_year_1 = require("../shared/financial-year");
const firestore_helpers_1 = require("../shared/firestore-helpers");
const client_analytics_1 = require("../clients/client-analytics");
const employee_analytics_1 = require("../employees/employee-analytics");
const vendor_analytics_1 = require("../vendors/vendor-analytics");
const transaction_rebuild_1 = require("../transactions/transaction-rebuild");
const deliveries_analytics_1 = require("./deliveries-analytics");
const productions_analytics_1 = require("./productions-analytics");
const trip_wages_analytics_1 = require("./trip-wages-analytics");
const fuel_analytics_1 = require("./fuel-analytics");
const function_config_1 = require("../shared/function-config");
const db = (0, firestore_helpers_1.getFirestore)();
/**
 * Discover all organization IDs for analytics rebuild.
 * Uses ORGANIZATIONS collection and TRANSACTIONS (for orgs with transactions only).
 */
async function discoverOrganizationIds(fyLabel) {
    const orgIds = new Set();
    const orgsSnapshot = await db.collection(constants_1.ORGANIZATIONS_COLLECTION).get();
    orgsSnapshot.forEach((doc) => {
        if (doc.id) {
            orgIds.add(doc.id);
        }
    });
    const txSnapshot = await db
        .collection(constants_1.TRANSACTIONS_COLLECTION)
        .where('financialYear', '==', fyLabel)
        .limit(5000)
        .get();
    txSnapshot.forEach((doc) => {
        var _a;
        const organizationId = (_a = doc.data()) === null || _a === void 0 ? void 0 : _a.organizationId;
        if (organizationId) {
            orgIds.add(organizationId);
        }
    });
    return orgIds;
}
/**
 * Unified scheduled function to rebuild all ANALYTICS documents.
 * Runs every 24 hours (midnight UTC).
 */
exports.rebuildAllAnalytics = (0, scheduler_1.onSchedule)(Object.assign({ schedule: '0 0 * * *', timeZone: 'UTC' }, function_config_1.SCHEDULED_FUNCTION_OPTS), async () => {
    const now = new Date();
    const { fyLabel, fyStart, fyEnd } = (0, financial_year_1.getFinancialContext)(now);
    console.log('[Analytics Rebuild] Starting unified rebuild', { fyLabel });
    try {
        await (0, client_analytics_1.rebuildClientAnalyticsCore)(fyLabel, fyStart, fyEnd);
    }
    catch (error) {
        console.error('[Analytics Rebuild] Client analytics failed', error);
    }
    try {
        await (0, employee_analytics_1.rebuildEmployeeAnalyticsCore)(fyLabel);
    }
    catch (error) {
        console.error('[Analytics Rebuild] Employee analytics failed', error);
    }
    try {
        await (0, vendor_analytics_1.rebuildVendorAnalyticsCore)(fyLabel);
    }
    catch (error) {
        console.error('[Analytics Rebuild] Vendor analytics failed', error);
    }
    const organizationIds = await discoverOrganizationIds(fyLabel);
    console.log('[Analytics Rebuild] Rebuilding per-org analytics for', organizationIds.size, 'organizations');
    for (const organizationId of organizationIds) {
        try {
            await (0, transaction_rebuild_1.rebuildTransactionAnalyticsForOrg)(organizationId, fyLabel);
        }
        catch (error) {
            console.error('[Analytics Rebuild] Transaction analytics failed for org', organizationId, error);
        }
        try {
            await (0, deliveries_analytics_1.rebuildDeliveriesAnalyticsForOrg)(organizationId, fyLabel, fyStart, fyEnd);
        }
        catch (error) {
            console.error('[Analytics Rebuild] Deliveries analytics failed for org', organizationId, error);
        }
        try {
            await (0, productions_analytics_1.rebuildProductionsAnalyticsForOrg)(organizationId, fyLabel, fyStart, fyEnd);
        }
        catch (error) {
            console.error('[Analytics Rebuild] Productions analytics failed for org', organizationId, error);
        }
        try {
            await (0, trip_wages_analytics_1.rebuildTripWagesAnalyticsForOrg)(organizationId, fyLabel, fyStart, fyEnd);
        }
        catch (error) {
            console.error('[Analytics Rebuild] Trip wages analytics failed for org', organizationId, error);
        }
        try {
            await (0, fuel_analytics_1.rebuildFuelAnalyticsForOrg)(organizationId, fyLabel, fyStart, fyEnd);
        }
        catch (error) {
            console.error('[Analytics Rebuild] Fuel analytics failed for org', organizationId, error);
        }
    }
    console.log('[Analytics Rebuild] Unified rebuild completed', { fyLabel });
});
//# sourceMappingURL=rebuild-all-analytics.js.map