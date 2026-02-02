import * as functions from 'firebase-functions';
import { getFirestore } from 'firebase-admin/firestore';
import {
  ORGANIZATIONS_COLLECTION,
  TRANSACTIONS_COLLECTION,
} from '../shared/constants';
import { getFinancialContext } from '../shared/financial-year';
import { rebuildClientAnalyticsCore } from '../clients/client-analytics';
import { rebuildEmployeeAnalyticsCore } from '../employees/employee-analytics';
import { rebuildVendorAnalyticsCore } from '../vendors/vendor-analytics';
import { rebuildTransactionAnalyticsForOrg } from '../transactions/transaction-rebuild';
import { rebuildDeliveriesAnalyticsForOrg } from './deliveries-analytics';
import { rebuildProductionsAnalyticsForOrg } from './productions-analytics';
import { rebuildTripWagesAnalyticsForOrg } from './trip-wages-analytics';

const db = getFirestore();

/**
 * Discover all organization IDs for analytics rebuild.
 * Uses ORGANIZATIONS collection and TRANSACTIONS (for orgs with transactions only).
 */
async function discoverOrganizationIds(fyLabel: string): Promise<Set<string>> {
  const orgIds = new Set<string>();

  const orgsSnapshot = await db.collection(ORGANIZATIONS_COLLECTION).get();
  orgsSnapshot.forEach((doc) => {
    if (doc.id) {
      orgIds.add(doc.id);
    }
  });

  const txSnapshot = await db
    .collection(TRANSACTIONS_COLLECTION)
    .where('financialYear', '==', fyLabel)
    .limit(5000)
    .get();
  txSnapshot.forEach((doc) => {
    const organizationId = doc.data()?.organizationId as string | undefined;
    if (organizationId) {
      orgIds.add(organizationId);
    }
  });

  return orgIds;
}

/**
 * Unified scheduled function to rebuild all ANALYTICS documents.
 * Runs every 24 hours. Replaces the four separate scheduled functions.
 */
export const rebuildAllAnalytics = functions.pubsub
  .schedule('every 24 hours')
  .timeZone('UTC')
  .onRun(async () => {
    const now = new Date();
    const { fyLabel, fyStart, fyEnd } = getFinancialContext(now);

    console.log('[Analytics Rebuild] Starting unified rebuild', { fyLabel });

    try {
      // 1. Clients analytics (batch by org from CLIENTS)
      await rebuildClientAnalyticsCore(fyLabel, fyStart, fyEnd);
    } catch (error) {
      console.error('[Analytics Rebuild] Client analytics failed', error);
    }

    try {
      // 2. Employee analytics
      await rebuildEmployeeAnalyticsCore(fyLabel);
    } catch (error) {
      console.error('[Analytics Rebuild] Employee analytics failed', error);
    }

    try {
      // 3. Vendor analytics
      await rebuildVendorAnalyticsCore(fyLabel);
    } catch (error) {
      console.error('[Analytics Rebuild] Vendor analytics failed', error);
    }

    const organizationIds = await discoverOrganizationIds(fyLabel);
    console.log('[Analytics Rebuild] Rebuilding per-org analytics for', organizationIds.size, 'organizations');

    for (const organizationId of organizationIds) {
      try {
        await rebuildTransactionAnalyticsForOrg(organizationId, fyLabel);
      } catch (error) {
        console.error('[Analytics Rebuild] Transaction analytics failed for org', organizationId, error);
      }

      try {
        await rebuildDeliveriesAnalyticsForOrg(organizationId, fyLabel, fyStart, fyEnd);
      } catch (error) {
        console.error('[Analytics Rebuild] Deliveries analytics failed for org', organizationId, error);
      }

      try {
        await rebuildProductionsAnalyticsForOrg(organizationId, fyLabel, fyStart, fyEnd);
      } catch (error) {
        console.error('[Analytics Rebuild] Productions analytics failed for org', organizationId, error);
      }

      try {
        await rebuildTripWagesAnalyticsForOrg(organizationId, fyLabel, fyStart, fyEnd);
      } catch (error) {
        console.error('[Analytics Rebuild] Trip wages analytics failed for org', organizationId, error);
      }
    }

    console.log('[Analytics Rebuild] Unified rebuild completed', { fyLabel });
  });
