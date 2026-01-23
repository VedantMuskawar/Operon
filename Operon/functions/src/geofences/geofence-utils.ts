/**
 * Geofence utility functions for point-in-polygon, distance calculations, and validation
 */

export interface Point {
  lat: number;
  lng: number;
}

export interface Geofence {
  type: 'circle' | 'polygon';
  centerLat: number;
  centerLng: number;
  radiusMeters?: number;
  polygonPoints?: Array<{ lat: number; lng: number }>;
}

/**
 * Calculate distance between two points using Haversine formula
 * Returns distance in meters
 */
export function haversineDistance(
  lat1: number,
  lng1: number,
  lat2: number,
  lng2: number,
): number {
  const R = 6371000; // Earth's radius in meters
  const dLat = toRadians(lat2 - lat1);
  const dLng = toRadians(lng2 - lng1);

  const a =
    Math.sin(dLat / 2) * Math.sin(dLat / 2) +
    Math.cos(toRadians(lat1)) *
      Math.cos(toRadians(lat2)) *
      Math.sin(dLng / 2) *
      Math.sin(dLng / 2);

  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
  return R * c;
}

function toRadians(degrees: number): number {
  return degrees * (Math.PI / 180);
}

/**
 * Check if a point is inside a polygon using ray casting algorithm
 */
export function isPointInPolygon(
  point: Point,
  polygonPoints: Array<{ lat: number; lng: number }>,
): boolean {
  if (polygonPoints.length < 3) {
    return false;
  }

  let inside = false;
  let j = polygonPoints.length - 1;

  for (let i = 0; i < polygonPoints.length; i++) {
    const xi = polygonPoints[i].lng;
    const yi = polygonPoints[i].lat;
    const xj = polygonPoints[j].lng;
    const yj = polygonPoints[j].lat;

    const intersect =
      yi > point.lat !== yj > point.lat &&
      point.lng < ((xj - xi) * (point.lat - yi)) / (yj - yi) + xi;

    if (intersect) {
      inside = !inside;
    }
    j = i;
  }

  return inside;
}

/**
 * Check if a point is inside a circle geofence
 */
export function isPointInCircle(
  point: Point,
  center: Point,
  radiusMeters: number,
): boolean {
  const distance = haversineDistance(
    center.lat,
    center.lng,
    point.lat,
    point.lng,
  );
  return distance <= radiusMeters;
}

/**
 * Check if a point is inside a geofence (circle or polygon)
 */
export function checkPointInGeofence(point: Point, geofence: Geofence): boolean {
  const center: Point = {
    lat: geofence.centerLat,
    lng: geofence.centerLng,
  };

  if (geofence.type === 'circle') {
    if (geofence.radiusMeters == null) {
      return false;
    }
    return isPointInCircle(point, center, geofence.radiusMeters);
  } else if (geofence.type === 'polygon') {
    if (geofence.polygonPoints == null || geofence.polygonPoints.length === 0) {
      return false;
    }
    return isPointInPolygon(point, geofence.polygonPoints);
  }

  return false;
}

/**
 * Quick bounding box check to see if point is near geofence
 * Used as a pre-check before expensive point-in-polygon calculation
 */
export function isNearGeofence(point: Point, geofence: Geofence): boolean {
  const center: Point = {
    lat: geofence.centerLat,
    lng: geofence.centerLng,
  };

  if (geofence.type === 'circle') {
    // For circle, use 20% buffer
    const buffer = geofence.radiusMeters ? geofence.radiusMeters * 1.2 : 0;
    return haversineDistance(point.lat, point.lng, center.lat, center.lng) <= buffer;
  } else if (geofence.type === 'polygon') {
    // For polygon, use 1km buffer from center
    const buffer = 1000; // 1km
    return haversineDistance(point.lat, point.lng, center.lat, center.lng) <= buffer;
  }

  return false;
}

/**
 * Validate geofence data
 */
export function validateGeofence(geofence: Geofence): {
  valid: boolean;
  error?: string;
} {
  // Validate center coordinates
  if (
    geofence.centerLat < -90 ||
    geofence.centerLat > 90 ||
    geofence.centerLng < -180 ||
    geofence.centerLng > 180
  ) {
    return {
      valid: false,
      error: 'Invalid center coordinates',
    };
  }

  if (geofence.type === 'circle') {
    if (geofence.radiusMeters == null || geofence.radiusMeters <= 0) {
      return {
        valid: false,
        error: 'Circle geofence must have a positive radius',
      };
    }
    if (geofence.radiusMeters > 50000) {
      return {
        valid: false,
        error: 'Circle radius cannot exceed 50km',
      };
    }
  } else if (geofence.type === 'polygon') {
    if (geofence.polygonPoints == null || geofence.polygonPoints.length < 3) {
      return {
        valid: false,
        error: 'Polygon must have at least 3 points',
      };
    }
    if (geofence.polygonPoints.length > 100) {
      return {
        valid: false,
        error: 'Polygon cannot have more than 100 points',
      };
    }
    // Validate polygon points
    for (const point of geofence.polygonPoints) {
      if (
        point.lat < -90 ||
        point.lat > 90 ||
        point.lng < -180 ||
        point.lng > 180
      ) {
        return {
          valid: false,
          error: 'Invalid polygon point coordinates',
        };
      }
    }
  }

  return { valid: true };
}
