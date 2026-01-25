import type { Timestamp } from 'firebase-admin/firestore';

/**
 * Vehicle availability forecast cache.
 * Stored at ORGANIZATIONS/{organizationId}/VEHICLE_AVAILABILITY_FORECAST/{vehicleId}.
 * Doc ID = vehicleId.
 */
export interface VehicleForecast {
  lastUpdated: Timestamp;
  /** Date YYYY-MM-DD -> number of trips remaining that day. Only dates with > 0. */
  freeSlots: Record<string, number>;
}

/**
 * Result of a delivery quote for a single vehicle.
 */
export interface QuoteResult {
  vehicleId: string;
  vehicleName: string;
  tripsRequired: number;
  estimatedStartDate: string; // YYYY-MM-DD
  estimatedCompletionDate: string; // YYYY-MM-DD
  scheduleBreakdown: string[]; // Array of YYYY-MM-DD
}
