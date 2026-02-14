"use strict";
var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    var desc = Object.getOwnPropertyDescriptor(m, k);
    if (!desc || ("get" in desc ? !m.__esModule : desc.writable || desc.configurable)) {
      desc = { enumerable: true, get: function() { return m[k]; } };
    }
    Object.defineProperty(o, k2, desc);
}) : (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    o[k2] = m[k];
}));
var __setModuleDefault = (this && this.__setModuleDefault) || (Object.create ? (function(o, v) {
    Object.defineProperty(o, "default", { enumerable: true, value: v });
}) : function(o, v) {
    o["default"] = v;
});
var __importStar = (this && this.__importStar) || (function () {
    var ownKeys = function(o) {
        ownKeys = Object.getOwnPropertyNames || function (o) {
            var ar = [];
            for (var k in o) if (Object.prototype.hasOwnProperty.call(o, k)) ar[ar.length] = k;
            return ar;
        };
        return ownKeys(o);
    };
    return function (mod) {
        if (mod && mod.__esModule) return mod;
        var result = {};
        if (mod != null) for (var k = ownKeys(mod), i = 0; i < k.length; i++) if (k[i] !== "default") __createBinding(result, mod, k[i]);
        __setModuleDefault(result, mod);
        return result;
    };
})();
Object.defineProperty(exports, "__esModule", { value: true });
exports.onFuelAnalyticsTransactionWrite = void 0;
exports.rebuildFuelAnalyticsForOrg = rebuildFuelAnalyticsForOrg;
const admin = __importStar(require("firebase-admin"));
const firestore_1 = require("firebase-functions/v2/firestore");
const constants_1 = require("../shared/constants");
const firestore_helpers_1 = require("../shared/firestore-helpers");
const date_helpers_1 = require("../shared/date-helpers");
const transaction_helpers_1 = require("../shared/transaction-helpers");
const function_config_1 = require("../shared/function-config");
const db = (0, firestore_helpers_1.getFirestore)();
const vendorTypeCache = new Map();
async function getVendorType(vendorId) {
    var _a, _b;
    if (vendorTypeCache.has(vendorId)) {
        return (_a = vendorTypeCache.get(vendorId)) !== null && _a !== void 0 ? _a : null;
    }
    try {
        const vendorDoc = await db
            .collection(constants_1.VENDORS_COLLECTION)
            .doc(vendorId)
            .get();
        const vendorType = ((_b = vendorDoc.data()) === null || _b === void 0 ? void 0 : _b.vendorType) || null;
        vendorTypeCache.set(vendorId, vendorType);
        return vendorType;
    }
    catch (error) {
        console.error('[Fuel Analytics] Failed to load vendor type', {
            vendorId,
            error,
        });
        vendorTypeCache.set(vendorId, null);
        return null;
    }
}
function normalizeVehicleKey(vehicleNumber) {
    return vehicleNumber.trim().replace(/[.#$\[\]/]/g, '_');
}
async function buildFuelImpact(snapshot) {
    var _a;
    if (!snapshot.exists) {
        return null;
    }
    const data = snapshot.data() || {};
    const organizationId = data.organizationId;
    const financialYear = data.financialYear;
    const amount = data.amount || 0;
    const type = data.type;
    const ledgerType = data.ledgerType;
    const category = data.category;
    const vendorId = data.vendorId;
    const metadata = data.metadata || {};
    const purchaseType = metadata.purchaseType;
    const vehicleNumber = (_a = metadata.vehicleNumber) === null || _a === void 0 ? void 0 : _a.trim();
    if (!organizationId || !financialYear || !amount || !type) {
        return null;
    }
    const transactionDate = (0, transaction_helpers_1.getTransactionDate)(snapshot);
    const monthKey = (0, date_helpers_1.getYearMonth)(transactionDate);
    let unpaidDelta = 0;
    if (ledgerType === 'vendorLedger' && vendorId) {
        const vendorType = await getVendorType(vendorId);
        if (vendorType === 'fuel') {
            unpaidDelta = type === 'credit' ? amount : -amount;
        }
    }
    let vehicleAmountDelta = 0;
    let vehicleKey;
    if (ledgerType === 'vendorLedger' &&
        category === 'vendorPurchase' &&
        type === 'credit' &&
        purchaseType === 'fuel' &&
        vehicleNumber) {
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
async function applyFuelImpact(impact, multiplier) {
    const unpaidDelta = impact.unpaidDelta * multiplier;
    const vehicleDelta = impact.vehicleAmountDelta * multiplier;
    if (unpaidDelta === 0 && vehicleDelta === 0) {
        return;
    }
    const analyticsDocId = `${constants_1.FUEL_ANALYTICS_SOURCE_KEY}_${impact.organizationId}_${impact.monthKey}`;
    const analyticsRef = db.collection(constants_1.ANALYTICS_COLLECTION).doc(analyticsDocId);
    try {
        await (0, firestore_helpers_1.seedFuelAnalyticsDoc)(analyticsRef, impact.financialYear, impact.organizationId);
        const updatePayload = {
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
    }
    catch (error) {
        console.error('[Fuel Analytics] Failed to write analytics update', {
            analyticsDocId,
            organizationId: impact.organizationId,
            error,
        });
    }
}
/**
 * Rebuild fuel analytics for a single organization and financial year.
 * Recalculates unpaid fuel balance and fuel consumption by vehicle.
 */
async function rebuildFuelAnalyticsForOrg(organizationId, financialYear, fyStart, fyEnd) {
    // Query all transactions for this org and financial year that impact fuel analytics
    const txSnapshot = await db
        .collection(constants_1.TRANSACTIONS_COLLECTION)
        .where('organizationId', '==', organizationId)
        .where('financialYear', '==', financialYear)
        .where('ledgerType', '==', 'vendorLedger')
        .where('category', '==', 'vendorPurchase')
        .get();
    // Group by month and build metrics
    const fuelByMonth = {};
    txSnapshot.forEach((doc) => {
        const impact = buildFuelImpactSync(doc);
        if (!impact) {
            return;
        }
        const monthKey = impact.monthKey;
        if (!fuelByMonth[monthKey]) {
            fuelByMonth[monthKey] = {
                unpaidDelta: 0,
                vehicleConsumption: {},
                vehicleKeyMap: {},
            };
        }
        fuelByMonth[monthKey].unpaidDelta += impact.unpaidDelta;
        if (impact.vehicleKey) {
            fuelByMonth[monthKey].vehicleConsumption[impact.vehicleKey] =
                (fuelByMonth[monthKey].vehicleConsumption[impact.vehicleKey] || 0) +
                    impact.vehicleAmountDelta;
            if (impact.vehicleNumber) {
                fuelByMonth[monthKey].vehicleKeyMap[impact.vehicleKey] = impact.vehicleNumber;
            }
        }
    });
    // Write monthly fuel analytics documents
    const monthPromises = Object.entries(fuelByMonth).map(async ([monthKey, data]) => {
        const analyticsDocId = `${constants_1.FUEL_ANALYTICS_SOURCE_KEY}_${organizationId}_${monthKey}`;
        const analyticsRef = db.collection(constants_1.ANALYTICS_COLLECTION).doc(analyticsDocId);
        await (0, firestore_helpers_1.seedFuelAnalyticsDoc)(analyticsRef, financialYear, organizationId);
        const updatePayload = {
            generatedAt: admin.firestore.FieldValue.serverTimestamp(),
        };
        if (data.unpaidDelta !== 0) {
            updatePayload['metrics.totalUnpaidFuelBalance'] = data.unpaidDelta;
        }
        if (Object.keys(data.vehicleConsumption).length > 0) {
            updatePayload['metrics.fuelConsumptionByVehicle'] = data.vehicleConsumption;
        }
        if (Object.keys(data.vehicleKeyMap).length > 0) {
            updatePayload['metadata.fuelVehicleKeyMap'] = data.vehicleKeyMap;
        }
        await analyticsRef.set(updatePayload, { merge: true });
    });
    await Promise.all(monthPromises);
}
/**
 * Helper to build FuelImpact synchronously (for rebuild, not real-time)
 */
function buildFuelImpactSync(snapshot) {
    var _a;
    if (!snapshot.exists) {
        return null;
    }
    const data = snapshot.data() || {};
    const organizationId = data.organizationId;
    const financialYear = data.financialYear;
    const amount = data.amount || 0;
    const type = data.type;
    const ledgerType = data.ledgerType;
    const category = data.category;
    const vendorId = data.vendorId;
    const metadata = data.metadata || {};
    const purchaseType = metadata.purchaseType;
    const vehicleNumber = (_a = metadata.vehicleNumber) === null || _a === void 0 ? void 0 : _a.trim();
    if (!organizationId || !financialYear || !amount || !type) {
        return null;
    }
    const transactionDate = (0, transaction_helpers_1.getTransactionDate)(snapshot);
    const monthKey = (0, date_helpers_1.getYearMonth)(transactionDate);
    let unpaidDelta = 0;
    if (ledgerType === 'vendorLedger' && vendorId && purchaseType === 'fuel') {
        unpaidDelta = type === 'credit' ? amount : -amount;
    }
    let vehicleAmountDelta = 0;
    let vehicleKey;
    if (ledgerType === 'vendorLedger' &&
        category === 'vendorPurchase' &&
        type === 'credit' &&
        purchaseType === 'fuel' &&
        vehicleNumber) {
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
exports.onFuelAnalyticsTransactionWrite = (0, firestore_1.onDocumentWritten)(Object.assign({ document: `${constants_1.TRANSACTIONS_COLLECTION}/{transactionId}` }, function_config_1.STANDARD_TRIGGER_OPTS), async (event) => {
    var _a, _b;
    const beforeSnapshot = (_a = event.data) === null || _a === void 0 ? void 0 : _a.before;
    const afterSnapshot = (_b = event.data) === null || _b === void 0 ? void 0 : _b.after;
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
});
//# sourceMappingURL=fuel-analytics.js.map