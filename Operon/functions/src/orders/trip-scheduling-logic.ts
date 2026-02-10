export type TripRef = {
  itemIndex?: number;
  productId?: string | null;
};

type CountTripsInput = {
  scheduledTrips: Array<TripRef | null | undefined>;
  itemIndex: number;
  productId?: string | null;
  fallbackProductId?: string | null;
};

export function countScheduledTripsForItem({
  scheduledTrips,
  itemIndex,
  productId,
  fallbackProductId,
}: CountTripsInput): number {
  const resolvedProductId = productId || fallbackProductId || null;
  return scheduledTrips.filter((trip) => {
    const tripItemIndex = (trip?.itemIndex as number) ?? 0;
    const tripProductId = (trip?.productId as string) || null;
    return tripItemIndex === itemIndex && (!resolvedProductId || tripProductId === resolvedProductId);
  }).length;
}