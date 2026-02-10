"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
const vitest_1 = require("vitest");
const trip_scheduling_logic_1 = require("../trip-scheduling-logic");
(0, vitest_1.describe)('countScheduledTripsForItem', () => {
    (0, vitest_1.it)('counts only matching itemIndex and productId when productId is set', () => {
        const scheduledTrips = [
            { itemIndex: 0, productId: 'p1' },
            { itemIndex: 0, productId: 'p2' },
            { itemIndex: 1, productId: 'p1' },
        ];
        const count = (0, trip_scheduling_logic_1.countScheduledTripsForItem)({
            scheduledTrips,
            itemIndex: 0,
            productId: 'p1',
        });
        (0, vitest_1.expect)(count).toBe(1);
    });
    (0, vitest_1.it)('counts all trips for itemIndex when productId is not resolved', () => {
        const scheduledTrips = [
            { itemIndex: 0, productId: 'p1' },
            { itemIndex: 0, productId: 'p2' },
            { itemIndex: 1, productId: 'p1' },
        ];
        const count = (0, trip_scheduling_logic_1.countScheduledTripsForItem)({
            scheduledTrips,
            itemIndex: 0,
        });
        (0, vitest_1.expect)(count).toBe(2);
    });
    (0, vitest_1.it)('treats missing itemIndex as 0 (legacy trips)', () => {
        const scheduledTrips = [
            { productId: 'p1' },
            { itemIndex: 0, productId: 'p1' },
            { itemIndex: 1, productId: 'p1' },
        ];
        const count = (0, trip_scheduling_logic_1.countScheduledTripsForItem)({
            scheduledTrips,
            itemIndex: 0,
            productId: 'p1',
        });
        (0, vitest_1.expect)(count).toBe(2);
    });
});
//# sourceMappingURL=trip-scheduling-logic.test.js.map