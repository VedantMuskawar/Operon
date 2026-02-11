import * as admin from 'firebase-admin';
import { onDocumentWritten } from 'firebase-functions/v2/firestore';
import {
  ANALYTICS_COLLECTION,
  TRANSACTIONS_COLLECTION,
  VENDORS_COLLECTION,
  FUEL_ANALYTICS_SOURCE_KEY,
} from '../shared/constants';
import { getFirestore, seedFuelAnalyticsDoc } from '../shared/firestore-helpers';
import { getYearMonth } from '../shared/date-helpers';
import { getTransactionDate } from '../shared/transaction-helpers';
import { STANDARD_TRIGGER_OPTS } from '../shared/function-config';

const db = getFirestore();
const vendorTypeCache = new Map<string, string | null>();

type FuelImpact = {
  organizationId: string;
  financialYear: string;
  monthKey: string;
  unpaidDelta: number;
  vehicleKey?: string;
  vehicleNumber?: string;
  vehicleAmountDelta: number;
};

async function getVendorType(vendorId: string): Promise<string | null> {
  if (vendorTypeCache.has(vendorId)) {
    return vendorTypeCache.get(vendorId) ?? null;
  }

  try {
    const vendorDoc = await db
      .collection(VENDORS_COLLECTION)
      .doc(vendorId)
      .get();
    const vendorType =
      (vendorDoc.data()?.vendorType as string | undefined) || null;
    vendorTypeCache.set(vendorId, vendorType);
    return vendorType;
  } catch (error) {
    console.error('[Fuel Analytics] Failed to load vendor type', {
      vendorId,
      error,
    });
    vendorTypeCache.set(vendorId, null);
    return null;
  }
}

function normalizeVehicleKey(vehicleNumber: string): string {
  return vehicleNumber.trim().replace(/[.#$\[\]/]/g, '_');
}

async function buildFuelImpact(
  snapshot: FirebaseFirestore.DocumentSnapshot,
): Promise<FuelImpact | null> {
  if (!snapshot.exists) {
    return null;
  }

  const data = snapshot.data() || {};
  const organizationId = data.organizationId as string | undefined;
  const financialYear = data.financialYear as string | undefined;
  const amount = (data.amount as number) || 0;
  const type = data.type as string | undefined;
  const ledgerType = data.ledgerType as string | undefined;
  const category = data.category as string | undefined;
  const vendorId = data.vendorId as string | undefined;
  const metadata = (data.metadata as Record<string, unknown> | undefined) || {};
  const purchaseType = metadata.purchaseType as string | undefined;
  const vehicleNumber = (metadata.vehicleNumber as string | undefined)?.trim();

  if (!organizationId || !financialYear || !amount || !type) {
    return null;
  }

  const transactionDate = getTransactionDate(snapshot);
  const monthKey = getYearMonth(transactionDate);

  let unpaidDelta = 0;
  if (ledgerType === 'vendorLedger' && vendorId) {
    const vendorType = await getVendorType(vendorId);
    if (vendorType === 'fuel') {
      unpaidDelta = type === 'credit' ? amount : -amount;
    }
  }

  let vehicleAmountDelta = 0;
  let vehicleKey: string | undefined;
  if (
    ledgerType === 'vendorLedger' &&
    category === 'vendorPurchase' &&
    type === 'credit' &&
    purchaseType === 'fuel' &&
    vehicleNumber
  ) {
    vehicleKey = normalizeVehicleKey(vehicleNumber);
    vehicleAmountDelta = amount;
  }

  if (unpaidDelta === 0 && vehicleAmountDelta === 0) {
    return null;
  }

  return {
    organizationId,
    financialYear,
    monthKey,
    unpaidDelta,
    vehicleKey,
    vehicleNumber,
    vehicleAmountDelta,
  };
}

async function applyFuelImpact(impact: FuelImpact, multiplier: number): Promise<void> {
  const unpaidDelta = impact.unpaidDelta * multiplier;
  const vehicleDelta = impact.vehicleAmountDelta * multiplier;

  if (unpaidDelta === 0 && vehicleDelta === 0) {
    return;
  }

  const analyticsDocId = `${FUEL_ANALYTICS_SOURCE_KEY}_${impact.organizationId}_${impact.monthKey}`;
  const analyticsRef = db.collection(ANALYTICS_COLLECTION).doc(analyticsDocId);

  try {
    await seedFuelAnalyticsDoc(
      analyticsRef,
      impact.financialYear,
      impact.organizationId,
    );

    const updatePayload: Record<string, unknown> = {
      generatedAt: admin.firestore.FieldValue.serverTimestamp(),
    };

    if (unpaidDelta !== 0) {
      updatePayload['metrics.totalUnpaidFuelBalance'] =
        admin.firestore.FieldValue.increment(unpaidDelta);
    }

    if (vehicleDelta !== 0 && impact.vehicleKey) {
      updatePayload[`metrics.fuelConsumptionByVehicle.${impact.vehicleKey}`] =
        admin.firestore.FieldValue.increment(vehicleDelta);
    }

    if (impact.vehicleKey && impact.vehicleNumber) {
      updatePayload[`metadata.fuelVehicleKeyMap.${impact.vehicleKey}`] =
        impact.vehicleNumber;
    }

    await analyticsRef.set(updatePayload, { merge: true });
  } catch (error) {
    console.error('[Fuel Analytics] Failed to write analytics update', {
      analyticsDocId,
      organizationId: impact.organizationId,
      error,
    });
  }
}

export const onFuelAnalyticsTransactionWrite = onDocumentWritten(
  {
    document: `${TRANSACTIONS_COLLECTION}/{transactionId}`,
    ...STANDARD_TRIGGER_OPTS,
  },
  async (event) => {
    const beforeSnapshot = event.data?.before;
    const afterSnapshot = event.data?.after;

    const beforeImpact = beforeSnapshot
      ? await buildFuelImpact(beforeSnapshot)
      : null;
    const afterImpact = afterSnapshot ? await buildFuelImpact(afterSnapshot) : null;

    if (!beforeImpact && !afterImpact) {
      return;
    }

    if (beforeImpact) {
      await applyFuelImpact(beforeImpact, -1);
    }

    if (afterImpact) {
      await applyFuelImpact(afterImpact, 1);
    }
  },
);
