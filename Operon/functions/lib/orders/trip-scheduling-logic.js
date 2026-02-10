"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.countScheduledTripsForItem = countScheduledTripsForItem;
function countScheduledTripsForItem({ scheduledTrips, itemIndex, productId, fallbackProductId, }) {
    const resolvedProductId = productId || fallbackProductId || null;
    return scheduledTrips.filter((trip) => {
        var _a;
        const tripItemIndex = (_a = trip === null || trip === void 0 ? void 0 : trip.itemIndex) !== null && _a !== void 0 ? _a : 0;
        const tripProductId = (trip === null || trip === void 0 ? void 0 : trip.productId) || null;
        return tripItemIndex === itemIndex && (!resolvedProductId || tripProductId === resolvedProductId);
    }).length;
}
//# sourceMappingURL=trip-scheduling-logic.js.map