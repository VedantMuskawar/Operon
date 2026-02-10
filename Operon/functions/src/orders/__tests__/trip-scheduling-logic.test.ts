import { describe, expect, it } from 'vitest';
import { countScheduledTripsForItem } from '../trip-scheduling-logic';

describe('countScheduledTripsForItem', () => {
  it('counts only matching itemIndex and productId when productId is set', () => {
    const scheduledTrips = [
      { itemIndex: 0, productId: 'p1' },
      { itemIndex: 0, productId: 'p2' },
      { itemIndex: 1, productId: 'p1' },
    ];

    const count = countScheduledTripsForItem({
      scheduledTrips,
      itemIndex: 0,
      productId: 'p1',
    });

    expect(count).toBe(1);
  });

  it('counts all trips for itemIndex when productId is not resolved', () => {
    const scheduledTrips = [
      { itemIndex: 0, productId: 'p1' },
      { itemIndex: 0, productId: 'p2' },
      { itemIndex: 1, productId: 'p1' },
    ];

    const count = countScheduledTripsForItem({
      scheduledTrips,
      itemIndex: 0,
    });

    expect(count).toBe(2);
  });

  it('treats missing itemIndex as 0 (legacy trips)', () => {
    const scheduledTrips = [
      { productId: 'p1' },
      { itemIndex: 0, productId: 'p1' },
      { itemIndex: 1, productId: 'p1' },
    ];

    const count = countScheduledTripsForItem({
      scheduledTrips,
      itemIndex: 0,
      productId: 'p1',
    });

    expect(count).toBe(2);
  });
});