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
exports.calculateEddForAllPendingOrders = void 0;
const https_1 = require("firebase-functions/v2/https");
const admin = __importStar(require("firebase-admin"));
const firestore_helpers_1 = require("../shared/firestore-helpers");
const constants_1 = require("../shared/constants");
const function_config_1 = require("../shared/function-config");
const db = (0, firestore_helpers_1.getFirestore)();
const BUFFER_DAYS_NORMAL = 1;
function getVehicleCapacityForProduct(vehicle, productId) {
    var _a, _b;
    if (productId && ((_a = vehicle.productCapacities) === null || _a === void 0 ? void 0 : _a[productId]) != null) {
        return vehicle.productCapacities[productId];
    }
    return (_b = vehicle.vehicleCapacity) !== null && _b !== void 0 ? _b : 0;
}
function scheduleTrips(freeSlots, tripsNeeded, bufferDays) {
    var _a;
    const sorted = Object.keys(freeSlots).sort();
    const out = [];
    let lastDate = null;
    for (const key of sorted) {
        if (out.length >= tripsNeeded)
            break;
        const cap = (_a = freeSlots[key]) !== null && _a !== void 0 ? _a : 0;
        if (cap < 1)
            continue;
        const parts = key.split('-').map(Number);
        const d = new Date(Date.UTC(parts[0], parts[1] - 1, parts[2]));
        if (lastDate != null && bufferDays >= 1) {
            const minNext = new Date(lastDate);
            minNext.setUTCDate(minNext.getUTCDate() + 2);
            if (d < minNext)
                continue;
        }
        out.push(key);
        freeSlots[key] = cap - 1;
        lastDate = d;
    }
    return out;
}
function normalizeEstimatedTrips(value) {
    const parsed = Math.max(0, Math.floor(Number(value)) || 0);
    return parsed <= 0 ? 1 : parsed;
}
function normalizeFixedQuantity(value) {
    const parsed = Math.max(0, Math.floor(Number(value)) || 0);
    return parsed;
}
exports.calculateEddForAllPendingOrders = (0, https_1.onCall)(Object.assign({}, function_config_1.CALLABLE_OPTS), async (request) => {
    var _a, _b, _c, _d;
    if (!request.auth) {
        throw new https_1.HttpsError('unauthenticated', 'Must be signed in.');
    }
    const { organizationId } = (request.data || {});
    if (typeof organizationId !== 'string' || !organizationId.trim()) {
        throw new https_1.HttpsError('invalid-argument', 'organizationId is required.');
    }
    const orgRef = db.collection(constants_1.ORGANIZATIONS_COLLECTION).doc(organizationId);
    const vehiclesSnap = await orgRef.collection('VEHICLES').where('isActive', '==', true).get();
    const vehicles = vehiclesSnap.docs.map((doc) => {
        var _a;
        const data = doc.data();
        return {
            vehicleId: doc.id,
            vehicleName: (_a = data.vehicleNumber) !== null && _a !== void 0 ? _a : doc.id,
            vehicleCapacity: data.vehicleCapacity,
            productCapacities: data.productCapacities,
        };
    });
    if (vehicles.length == 0) {
        return { success: false, message: 'No active vehicles found.', updatedOrders: 0 };
    }
    const pendingSnap = await db
        .collection(constants_1.PENDING_ORDERS_COLLECTION)
        .where('organizationId', '==', organizationId)
        .where('status', '==', 'pending')
        .get();
    const updates = [];
    for (const orderDoc of pendingSnap.docs) {
        const order = orderDoc.data();
        const items = (_a = order.items) !== null && _a !== void 0 ? _a : [];
        if (items.length === 0)
            continue;
        const priority = (_b = order.priority) !== null && _b !== void 0 ? _b : 'normal';
        const bufferDays = priority === 'high' ? 0 : BUFFER_DAYS_NORMAL;
        let bestResult = null;
        for (const vehicle of vehicles) {
            const forecastDoc = await orgRef
                .collection(constants_1.VEHICLE_AVAILABILITY_FORECAST)
                .doc(vehicle.vehicleId)
                .get();
            const freeSlots = (_d = (_c = forecastDoc.data()) === null || _c === void 0 ? void 0 : _c.freeSlots) !== null && _d !== void 0 ? _d : {};
            const mutableSlots = Object.assign({}, freeSlots);
            const itemSchedules = [];
            let scheduleFailed = false;
            items.forEach((item, index) => {
                var _a;
                if (scheduleFailed)
                    return;
                const productId = (_a = item.productId) !== null && _a !== void 0 ? _a : null;
                const fixedQty = normalizeFixedQuantity(item.fixedQuantityPerTrip);
                const estimatedTrips = normalizeEstimatedTrips(item.estimatedTrips);
                const capacity = getVehicleCapacityForProduct(vehicle, productId !== null && productId !== void 0 ? productId : undefined);
                if (capacity <= 0 || fixedQty <= 0) {
                    scheduleFailed = true;
                    return;
                }
                const tripsRequired = fixedQty <= capacity
                    ? estimatedTrips
                    : Math.max(1, Math.ceil((estimatedTrips * fixedQty) / capacity));
                const tripDates = scheduleTrips(mutableSlots, tripsRequired, bufferDays);
                if (tripDates.length < tripsRequired) {
                    scheduleFailed = true;
                    return;
                }
                itemSchedules.push({
                    itemIndex: index,
                    productId,
                    tripsRequired,
                    tripDates,
                });
            });
            if (scheduleFailed || itemSchedules.length === 0) {
                continue;
            }
            const allDates = itemSchedules.flatMap((item) => item.tripDates);
            const sortedDates = allDates.slice().sort();
            const estimatedStartDate = sortedDates[0];
            const estimatedCompletionDate = sortedDates[sortedDates.length - 1];
            if (!bestResult || estimatedCompletionDate < bestResult.estimatedCompletionDate) {
                bestResult = {
                    vehicleId: vehicle.vehicleId,
                    vehicleName: vehicle.vehicleName,
                    estimatedStartDate,
                    estimatedCompletionDate,
                    items: itemSchedules,
                };
            }
        }
        if (!bestResult) {
            continue;
        }
        updates.push(orderDoc.ref.update({
            edd: {
                calculatedAt: admin.firestore.FieldValue.serverTimestamp(),
                vehicleId: bestResult.vehicleId,
                vehicleName: bestResult.vehicleName,
                estimatedStartDate: bestResult.estimatedStartDate,
                estimatedCompletionDate: bestResult.estimatedCompletionDate,
                items: bestResult.items,
            },
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        }));
    }
    await Promise.all(updates);
    return {
        success: true,
        updatedOrders: updates.length,
    };
});
//# sourceMappingURL=batch-calc-edd.js.map