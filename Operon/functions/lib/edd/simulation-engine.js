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
exports.recalculateVehicleQueue = recalculateVehicleQueue;
const admin = __importStar(require("firebase-admin"));
const firestore_helpers_1 = require("../shared/firestore-helpers");
const date_helpers_1 = require("../shared/date-helpers");
const constants_1 = require("../shared/constants");
const db = (0, firestore_helpers_1.getFirestore)();
const ROCK_STATUSES = ['scheduled', 'dispatched', 'delivered', 'returned'];
const DEFAULT_CAPACITY = 5;
const FORECAST_DAYS = 60;
const DAY_NAMES = ['sunday', 'monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday'];
function getDailyCapacity(vehicle, date) {
    var _a, _b;
    const dayIndex = date.getUTCDay();
    const dayOfWeek = DAY_NAMES[dayIndex];
    if (((_a = vehicle.weeklyCapacity) === null || _a === void 0 ? void 0 : _a[dayOfWeek]) != null) {
        return vehicle.weeklyCapacity[dayOfWeek];
    }
    return (_b = vehicle.vehicleCapacity) !== null && _b !== void 0 ? _b : DEFAULT_CAPACITY;
}
function getVehicleCapacityForProduct(vehicle, productId) {
    var _a, _b;
    if (((_a = vehicle.productCapacities) === null || _a === void 0 ? void 0 : _a[productId]) != null) {
        return vehicle.productCapacities[productId];
    }
    return (_b = vehicle.vehicleCapacity) !== null && _b !== void 0 ? _b : DEFAULT_CAPACITY;
}
function totalQuantityForOrder(order) {
    var _a;
    const first = order.items[0];
    if (!first)
        return 0;
    return ((_a = first.estimatedTrips) !== null && _a !== void 0 ? _a : 0) * (first.fixedQuantityPerTrip || first.totalQuantity || 0) || first.totalQuantity || 0;
}
function productIdForOrder(order) {
    var _a, _b;
    return (_b = (_a = order.items[0]) === null || _a === void 0 ? void 0 : _a.productId) !== null && _b !== void 0 ? _b : null;
}
function parseScheduledDate(raw) {
    if (!raw)
        return null;
    if (typeof raw.toDate === 'function') {
        return raw.toDate();
    }
    const s = raw._seconds;
    if (typeof s === 'number')
        return new Date(s * 1000);
    return null;
}
/**
 * Build timeline map for the next FORECAST_DAYS days. Key = YYYY-MM-DD, value = trips remaining.
 */
function buildInitialTimeline(vehicle) {
    const timeline = new Map();
    const start = new Date();
    start.setUTCHours(0, 0, 0, 0);
    start.setUTCDate(start.getUTCDate() + 1); // start from tomorrow
    for (let i = 0; i < FORECAST_DAYS; i++) {
        const d = new Date(start);
        d.setUTCDate(start.getUTCDate() + i);
        const key = (0, date_helpers_1.formatDate)(d);
        timeline.set(key, getDailyCapacity(vehicle, d));
    }
    return timeline;
}
/**
 * Subtract rocks (fixed trips) from timeline. Each rock occupies 1 slot on its scheduledDate.
 */
function subtractRocks(timeline, rocks) {
    var _a;
    for (const r of rocks) {
        const key = (0, date_helpers_1.formatDate)(r.scheduledDate);
        const cur = (_a = timeline.get(key)) !== null && _a !== void 0 ? _a : 0;
        if (cur > 0)
            timeline.set(key, cur - 1);
    }
}
/**
 * Find earliest valid sequence of dates for `tripsNeeded` trips with given buffer.
 * Buffer 0 = consecutive days ok; 1 = must skip one day between trips.
 * Mutates timeline (occupies slots). Returns array of YYYY-MM-DD.
 */
function findAndOccupySlots(timeline, tripsNeeded, bufferDays) {
    var _a;
    const sorted = Array.from(timeline.keys()).sort();
    const out = [];
    let lastDate = null;
    for (const key of sorted) {
        if (out.length >= tripsNeeded)
            break;
        const capacity = (_a = timeline.get(key)) !== null && _a !== void 0 ? _a : 0;
        if (capacity < 1)
            continue;
        const parts = key.split('-').map(Number);
        const d = new Date(Date.UTC(parts[0], parts[1] - 1, parts[2]));
        if (lastDate != null && bufferDays >= 1) {
            const minNext = new Date(lastDate);
            minNext.setUTCDate(minNext.getUTCDate() + 2); // skip one day
            if (d < minNext)
                continue;
        }
        out.push(key);
        timeline.set(key, capacity - 1);
        lastDate = d;
    }
    return out;
}
/**
 * Recalculate vehicle queue: build timeline, subtract rocks, pour pending orders,
 * produce forecast, batch-update order EDDs, write VehicleForecast.
 */
async function recalculateVehicleQueue(vehicleId, organizationId) {
    var _a, _b, _c, _d, _e, _f, _g, _h;
    const orgRef = db.collection(constants_1.ORGANIZATIONS_COLLECTION).doc(organizationId);
    const vehicleDoc = await orgRef.collection('VEHICLES').doc(vehicleId).get();
    if (!vehicleDoc.exists) {
        console.warn('[EDD] Vehicle not found', { vehicleId, organizationId });
        return;
    }
    const vData = vehicleDoc.data();
    const vehicle = {
        id: vehicleDoc.id,
        vehicleNumber: (_a = vData.vehicleNumber) !== null && _a !== void 0 ? _a : '',
        vehicleCapacity: vData.vehicleCapacity,
        weeklyCapacity: vData.weeklyCapacity,
        productCapacities: vData.productCapacities,
    };
    const today = new Date();
    today.setUTCHours(0, 0, 0, 0);
    const endWindow = new Date(today);
    endWindow.setUTCDate(endWindow.getUTCDate() + FORECAST_DAYS + 1);
    const tripsSnap = await db
        .collection(constants_1.SCHEDULE_TRIPS_COLLECTION)
        .where('organizationId', '==', organizationId)
        .where('scheduledDate', '>=', today)
        .where('scheduledDate', '<', endWindow)
        .get();
    const rocks = [];
    for (const doc of tripsSnap.docs) {
        const data = doc.data();
        if (data.vehicleId !== vehicleId)
            continue;
        const st = (_b = data.tripStatus) === null || _b === void 0 ? void 0 : _b.toLowerCase();
        if (!ROCK_STATUSES.includes(st))
            continue;
        const sd = parseScheduledDate(data.scheduledDate);
        if (sd)
            rocks.push({ scheduledDate: sd });
    }
    const pendingSnap = await db
        .collection(constants_1.PENDING_ORDERS_COLLECTION)
        .where('organizationId', '==', organizationId)
        .where('status', '==', 'pending')
        .get();
    const pending = [];
    for (const doc of pendingSnap.docs) {
        const data = doc.data();
        const suggested = (_c = data.autoSchedule) === null || _c === void 0 ? void 0 : _c.suggestedVehicleId;
        if (suggested !== vehicleId)
            continue;
        pending.push({
            orderId: doc.id,
            organizationId: data.organizationId,
            items: (_d = data.items) !== null && _d !== void 0 ? _d : [],
            priority: (_e = data.priority) !== null && _e !== void 0 ? _e : 'normal',
            createdAt: (_f = data.createdAt) !== null && _f !== void 0 ? _f : admin.firestore.Timestamp.now(),
            status: (_g = data.status) !== null && _g !== void 0 ? _g : 'pending',
            autoSchedule: data.autoSchedule,
        });
    }
    pending.sort((a, b) => {
        if (a.priority === 'high' && b.priority !== 'high')
            return -1;
        if (b.priority === 'high' && a.priority !== 'high')
            return 1;
        return a.createdAt.toMillis() - b.createdAt.toMillis();
    });
    const timeline = buildInitialTimeline(vehicle);
    subtractRocks(timeline, rocks);
    const updates = {};
    const timelineMutable = new Map(timeline);
    for (const order of pending) {
        const productId = productIdForOrder(order);
        const cap = Math.max(productId ? getVehicleCapacityForProduct(vehicle, productId) : ((_h = vehicle.vehicleCapacity) !== null && _h !== void 0 ? _h : DEFAULT_CAPACITY), 1);
        const totalQty = totalQuantityForOrder(order);
        const tripsNeeded = Math.max(1, Math.ceil(totalQty / cap));
        const buffer = order.priority === 'high' ? 0 : 1;
        const seq = findAndOccupySlots(timelineMutable, tripsNeeded, buffer);
        if (seq.length > 0) {
            updates[order.orderId] = seq;
        }
    }
    const freeSlots = {};
    for (const [k, v] of timelineMutable) {
        if (v > 0)
            freeSlots[k] = v;
    }
    const forecastRef = orgRef.collection(constants_1.VEHICLE_AVAILABILITY_FORECAST).doc(vehicleId);
    const forecast = {
        lastUpdated: admin.firestore.Timestamp.now(),
        freeSlots,
    };
    await forecastRef.set(forecast);
    const orderUpdates = Object.entries(updates).map(([orderId, dates]) => {
        const lastDate = dates[dates.length - 1];
        return {
            ref: db.collection(constants_1.PENDING_ORDERS_COLLECTION).doc(orderId),
            estimatedDeliveryDate: admin.firestore.Timestamp.fromDate(new Date(lastDate + 'T12:00:00Z')),
        };
    });
    for (const { ref, estimatedDeliveryDate } of orderUpdates) {
        await ref.update({
            'autoSchedule.estimatedDeliveryDate': estimatedDeliveryDate,
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
    }
    console.log('[EDD] Recalculated vehicle queue', {
        vehicleId,
        organizationId,
        ordersUpdated: orderUpdates.length,
        forecastDates: Object.keys(freeSlots).length,
    });
}
//# sourceMappingURL=simulation-engine.js.map