import * as admin from 'firebase-admin';
import * as functions from 'firebase-functions';
import {
  PENDING_ORDERS_COLLECTION,
  ORGANIZATIONS_COLLECTION,
} from '../shared/constants';

const ROLLING_AVERAGE_WINDOW = 10; // Keep last 10 orders for average calculation
import { getFirestore } from '../shared/firestore-helpers';

const db = getFirestore();

interface Vehicle {
  id: string;
  vehicleNumber: string;
  vehicleCapacity?: number;
  productCapacities?: Record<string, number>;
  weeklyCapacity?: Record<string, number>;
  isActive: boolean;
}

interface OrderItem {
  productId: string;
  productName: string;
  totalQuantity: number;
  fixedQuantityPerTrip: number;
  estimatedTrips: number;
  total: number;
}

interface PendingOrder {
  orderId: string;
  organizationId: string;
  items: OrderItem[];
  priority: string;
  createdAt: admin.firestore.Timestamp;
  status: string;
}

const DEFAULT_CAPACITY = 5; // Default trips per day if no capacity specified

/**
 * Calculate total trips required for an order
 */
function calculateTotalTrips(order: PendingOrder): number {
  return order.items.reduce((total, item) => total + item.estimatedTrips, 0);
}

/**
 * Get product-specific capacity for a vehicle
 */
function getVehicleCapacityForProduct(
  vehicle: Vehicle,
  productId: string,
): number {
  // Check product-specific capacity first
  if (vehicle.productCapacities?.[productId]) {
    return vehicle.productCapacities[productId];
  }
  
  // Fallback to general vehicle capacity
  if (vehicle.vehicleCapacity) {
    return vehicle.vehicleCapacity;
  }
  
  // Default capacity
  return DEFAULT_CAPACITY;
}

/**
 * Get daily capacity for a vehicle (considering weekly capacity)
 */
function getDailyCapacity(vehicle: Vehicle, date: Date): number {
  // Get day of week (0 = Sunday, 1 = Monday, etc.)
  const dayIndex = date.getUTCDay();
  const dayNames = ['sunday', 'monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday'];
  const dayOfWeek = dayNames[dayIndex];
  
  // Check weekly capacity first
  if (vehicle.weeklyCapacity?.[dayOfWeek]) {
    return vehicle.weeklyCapacity[dayOfWeek];
  }
  
  // Fallback to general capacity
  if (vehicle.vehicleCapacity) {
    return vehicle.vehicleCapacity;
  }
  
  return DEFAULT_CAPACITY;
}

/**
 * Find best-fit vehicle for an order (smallest capacity that can handle per trip)
 * Also considers existing allocations to avoid over-allocation
 */
async function findBestFitVehicle(
  vehicles: Vehicle[],
  order: PendingOrder,
  organizationId: string,
): Promise<Vehicle | null> {
  if (vehicles.length === 0) {
    return null;
  }

  // Get the primary product from order (first item)
  const primaryProduct = order.items[0];
  if (!primaryProduct) {
    return null;
  }

  const productId = primaryProduct.productId;
  // Use fixedQuantityPerTrip, not totalQuantity!
  const quantityPerTrip = primaryProduct.fixedQuantityPerTrip || primaryProduct.totalQuantity;

  // Get all pending orders to calculate vehicle allocations
  const pendingOrdersSnapshot = await db
    .collection(PENDING_ORDERS_COLLECTION)
    .where('organizationId', '==', organizationId)
    .where('status', '==', 'pending')
    .get();

  // Calculate how much capacity each vehicle has already allocated
  // Track the maximum per-trip quantity allocated to each vehicle
  const vehicleMaxAllocated: Record<string, number> = {};
  pendingOrdersSnapshot.docs.forEach((doc) => {
    const orderData = doc.data();
    const autoSchedule = orderData.autoSchedule;
    if (autoSchedule?.suggestedVehicleId && doc.id !== order.orderId) {
      const vehicleId = autoSchedule.suggestedVehicleId as string;
      const orderItems = (orderData.items as any[]) || [];
      if (orderItems.length > 0) {
        const item = orderItems[0];
        const itemProductId = item.productId as string;
        if (itemProductId === productId) {
          // Track the maximum per-trip quantity for this vehicle
          // A vehicle can handle multiple orders as long as each trip doesn't exceed capacity
          const allocatedQty = (item.fixedQuantityPerTrip as number) || (item.totalQuantity as number);
          vehicleMaxAllocated[vehicleId] = Math.max(
            vehicleMaxAllocated[vehicleId] || 0,
            allocatedQty
          );
        }
      }
    }
  });

  // Filter vehicles that can handle this product per trip
  const eligibleVehicles = vehicles
    .filter((v) => v.isActive)
    .map((v) => {
      const capacity = getVehicleCapacityForProduct(v, productId);
      const maxAllocated = vehicleMaxAllocated[v.id] || 0;
      
      // A vehicle can handle this order if:
      // 1. It can handle the per-trip quantity (capacity >= quantityPerTrip)
      // 2. The new order's per-trip quantity doesn't exceed capacity
      // 3. We prefer vehicles with smaller capacity (best fit)
      const canHandle = capacity >= quantityPerTrip;
      const hasRoom = (maxAllocated + quantityPerTrip) <= capacity || maxAllocated === 0;
      
      return {
        vehicle: v,
        capacity,
        maxAllocated,
        canHandle,
        hasRoom,
        // Score: lower is better (prefer smaller capacity, prefer vehicles with room)
        score: capacity + (hasRoom ? 0 : 10000) + (maxAllocated > 0 ? 1000 : 0),
      };
    })
    .filter((v) => v.canHandle) // Vehicle must be able to handle the trip size
    .sort((a, b) => {
      // Prefer vehicles with room for this order
      if (a.hasRoom && !b.hasRoom) return -1;
      if (!a.hasRoom && b.hasRoom) return 1;
      // Among vehicles with room, prefer smallest capacity (best fit)
      return a.capacity - b.capacity;
    });

  if (eligibleVehicles.length === 0) {
    // No vehicle can handle, return largest capacity vehicle
    const sortedByCapacity = vehicles
      .filter((v) => v.isActive)
      .sort((a, b) => {
        const capA = getVehicleCapacityForProduct(a, productId);
        const capB = getVehicleCapacityForProduct(b, productId);
        return capB - capA; // Descending
      });
    return sortedByCapacity[0] || null;
  }

  // Return best fit: smallest capacity that has available capacity, or smallest capacity overall
  return eligibleVehicles[0].vehicle;
}

/**
 * Calculate estimated delivery date based on vehicle capacity and pending orders
 */
async function calculateEstimatedDeliveryDate(
  organizationId: string,
  newOrder: PendingOrder,
  vehicles: Vehicle[],
): Promise<Date> {
  if (vehicles.length === 0) {
    // No vehicles, can't calculate
    throw new Error('No active vehicles available');
  }

  // Get all pending orders (including the new one)
  const pendingOrdersSnapshot = await db
    .collection(PENDING_ORDERS_COLLECTION)
    .where('organizationId', '==', organizationId)
    .where('status', '==', 'pending')
    .orderBy('createdAt', 'asc')
    .get();

  const pendingOrders: PendingOrder[] = pendingOrdersSnapshot.docs.map(
    (doc) => {
      const data = doc.data();
      return {
        orderId: doc.id,
        organizationId: data.organizationId as string,
        items: (data.items as any[]) || [],
        priority: (data.priority as string) || 'normal',
        createdAt: data.createdAt as admin.firestore.Timestamp,
        status: (data.status as string) || 'pending',
      };
    },
  );

  // Sort orders by priority and age
  pendingOrders.sort((a, b) => {
    // High priority first
    if (a.priority === 'high' && b.priority !== 'high') return -1;
    if (b.priority === 'high' && a.priority !== 'high') return 1;
    
    // Older orders first
    return a.createdAt.toMillis() - b.createdAt.toMillis();
  });

  // Calculate total daily capacity
  // Start from next day, not today
  const today = new Date();
  today.setUTCHours(0, 0, 0, 0);
  
  // Start from tomorrow
  let currentDate = new Date(today);
  currentDate.setUTCDate(currentDate.getUTCDate() + 1);
  
  const newOrderTrips = calculateTotalTrips(newOrder);
  let remainingTrips = newOrderTrips;

  // Allocate orders to days
  while (remainingTrips > 0) {
    // Calculate available capacity for this day
    let availableCapacity = 0;
    for (const vehicle of vehicles.filter((v) => v.isActive)) {
      availableCapacity += getDailyCapacity(vehicle, currentDate);
    }

    // Allocate pending orders to this day
    let allocatedTrips = 0;
    for (const order of pendingOrders) {
      if (order.orderId === newOrder.orderId) {
        // Skip the new order, we'll allocate it separately
        continue;
      }

      const orderTrips = calculateTotalTrips(order);
      if (allocatedTrips + orderTrips <= availableCapacity) {
        allocatedTrips += orderTrips;
      } else {
        // Can't fit more orders today
        break;
      }
    }

    // Check if new order can fit today
    const remainingCapacity = availableCapacity - allocatedTrips;
    if (remainingCapacity >= remainingTrips) {
      // Can fit today
      return currentDate;
    } else {
      // Move to next day
      remainingTrips -= remainingCapacity;
      currentDate = new Date(currentDate);
      currentDate.setUTCDate(currentDate.getUTCDate() + 1);
    }
  }

  return currentDate;
}

/**
 * Calculate priority score for an order
 */
function calculatePriorityScore(order: PendingOrder): number {
  const priorityWeight = order.priority === 'high' ? 100 : 50;
  const daysSinceCreated = Math.floor(
    (Date.now() - order.createdAt.toMillis()) / (1000 * 60 * 60 * 24),
  );
  const totalTrips = calculateTotalTrips(order);
  
  return priorityWeight + daysSinceCreated * 10 + totalTrips * 5;
}

/**
 * Update estimated delivery date reference in organization document
 * Stores latest and rolling average for product + fixedQuantityPerTrip combinations
 */
async function updateEstimatedDeliveryDateReference(
  organizationId: string,
  productId: string,
  fixedQuantityPerTrip: number,
  estimatedDate: Date,
): Promise<void> {
  try {
    const orgRef = db.collection(ORGANIZATIONS_COLLECTION).doc(organizationId);
    const orgDoc = await orgRef.get();
    
    if (!orgDoc.exists) {
      console.warn('[ETA Reference] Organization not found', { organizationId });
      return;
    }
    
    const orgData = orgDoc.data()!;
    const estimatedDeliveryDates = (orgData.estimatedDeliveryDates as Record<string, any>) || {};
    
    // Initialize product entry if not exists
    if (!estimatedDeliveryDates[productId]) {
      estimatedDeliveryDates[productId] = {};
    }
    
    // Initialize fixedQuantityPerTrip entry if not exists
    const productData = estimatedDeliveryDates[productId];
    const key = String(fixedQuantityPerTrip);
    
    if (!productData[key]) {
      productData[key] = {
        latestEstimatedDate: null,
        averageEstimatedDate: null,
        orderCount: 0,
        recentDates: [],
        lastUpdated: null,
      };
    }
    
    const entry = productData[key];
    const recentDates = (entry.recentDates as admin.firestore.Timestamp[]) || [];
    const estimatedTimestamp = admin.firestore.Timestamp.fromDate(estimatedDate);
    
    // Add new date to recent dates (keep only last N orders)
    const updatedRecentDates = [estimatedTimestamp, ...recentDates].slice(0, ROLLING_AVERAGE_WINDOW);
    
    // Calculate average from recent dates
    const totalMillis = updatedRecentDates.reduce((sum, ts) => sum + ts.toMillis(), 0);
    const averageMillis = totalMillis / updatedRecentDates.length;
    const averageDate = admin.firestore.Timestamp.fromMillis(Math.round(averageMillis));
    
    // Update entry
    productData[key] = {
      latestEstimatedDate: estimatedTimestamp,
      averageEstimatedDate: averageDate,
      orderCount: updatedRecentDates.length,
      recentDates: updatedRecentDates,
      lastUpdated: admin.firestore.FieldValue.serverTimestamp(),
    };
    
    // Update organization document
    await orgRef.update({
      estimatedDeliveryDates,
    });
    
    console.log('[ETA Reference] Updated estimated delivery date reference', {
      organizationId,
      productId,
      fixedQuantityPerTrip,
      latestDate: estimatedDate.toISOString(),
      averageDate: new Date(averageMillis).toISOString(),
      orderCount: updatedRecentDates.length,
    });
  } catch (error) {
    console.error('[ETA Reference] Error updating estimated delivery date reference', {
      organizationId,
      productId,
      fixedQuantityPerTrip,
      error,
    });
    // Don't throw - this is a reference update, shouldn't block order creation
  }
}

/**
 * Remove estimated delivery date reference when order is cancelled
 */
export async function removeEstimatedDeliveryDateReference(
  organizationId: string,
  productId: string,
  fixedQuantityPerTrip: number,
  estimatedDate: admin.firestore.Timestamp,
): Promise<void> {
  try {
    const orgRef = db.collection(ORGANIZATIONS_COLLECTION).doc(organizationId);
    const orgDoc = await orgRef.get();
    
    if (!orgDoc.exists) {
      return;
    }
    
    const orgData = orgDoc.data()!;
    const estimatedDeliveryDates = (orgData.estimatedDeliveryDates as Record<string, any>) || {};
    
    if (!estimatedDeliveryDates[productId]) {
      return;
    }
    
    const productData = estimatedDeliveryDates[productId];
    const key = String(fixedQuantityPerTrip);
    
    if (!productData[key]) {
      return;
    }
    
    const entry = productData[key];
    const recentDates = (entry.recentDates as admin.firestore.Timestamp[]) || [];
    
    // Remove the cancelled order's date from recent dates
    const updatedRecentDates = recentDates.filter(
      (ts) => ts.toMillis() !== estimatedDate.toMillis()
    );
    
    if (updatedRecentDates.length === 0) {
      // No more dates, remove the entry
      delete productData[key];
      
      // If no more entries for this product, remove product entry
      if (Object.keys(productData).length === 0) {
        delete estimatedDeliveryDates[productId];
      }
    } else {
      // Recalculate average
      const totalMillis = updatedRecentDates.reduce((sum, ts) => sum + ts.toMillis(), 0);
      const averageMillis = totalMillis / updatedRecentDates.length;
      const averageDate = admin.firestore.Timestamp.fromMillis(Math.round(averageMillis));
      
      // Update latest to most recent
      const sortedDates = [...updatedRecentDates].sort((a, b) => b.toMillis() - a.toMillis());
      
      productData[key] = {
        latestEstimatedDate: sortedDates[0],
        averageEstimatedDate: averageDate,
        orderCount: updatedRecentDates.length,
        recentDates: updatedRecentDates,
        lastUpdated: admin.firestore.FieldValue.serverTimestamp(),
      };
    }
    
    // Update organization document
    await orgRef.update({
      estimatedDeliveryDates,
    });
    
    console.log('[ETA Reference] Removed estimated delivery date reference', {
      organizationId,
      productId,
      fixedQuantityPerTrip,
      remainingCount: updatedRecentDates.length,
    });
  } catch (error) {
    console.error('[ETA Reference] Error removing estimated delivery date reference', {
      organizationId,
      productId,
      fixedQuantityPerTrip,
      error,
    });
    // Don't throw - cleanup failure shouldn't block order cancellation
  }
}

/**
 * Auto-schedule an order
 */
async function autoScheduleOrder(
  orderId: string,
  orderData: any,
): Promise<void> {
  const organizationId = orderData.organizationId as string;
  if (!organizationId) {
    console.log('[Auto-Schedule] No organizationId, skipping', { orderId });
    return;
  }

  // Fetch active vehicles
  const vehiclesSnapshot = await db
    .collection(ORGANIZATIONS_COLLECTION)
    .doc(organizationId)
    .collection('VEHICLES')
    .where('isActive', '==', true)
    .get();

  if (vehiclesSnapshot.empty) {
    console.log('[Auto-Schedule] No active vehicles, skipping', {
      orderId,
      organizationId,
    });
    return;
  }

  const vehicles: Vehicle[] = vehiclesSnapshot.docs.map((doc) => {
    const data = doc.data();
    return {
      id: doc.id,
      vehicleNumber: (data.vehicleNumber as string) || '',
      vehicleCapacity: (data.vehicleCapacity as number) || undefined,
      productCapacities: (data.productCapacities as Record<string, number>) || undefined,
      weeklyCapacity: (data.weeklyCapacity as Record<string, number>) || undefined,
      isActive: (data.isActive as boolean) ?? true,
    };
  });

  // Build order object
  const order: PendingOrder = {
    orderId,
    organizationId,
    items: (orderData.items as any[]) || [],
    priority: (orderData.priority as string) || 'normal',
    createdAt: (orderData.createdAt as admin.firestore.Timestamp) || admin.firestore.Timestamp.now(),
    status: (orderData.status as string) || 'pending',
  };

  try {
    // Calculate estimated delivery date
    const estimatedDeliveryDate = await calculateEstimatedDeliveryDate(
      organizationId,
      order,
      vehicles,
    );

    // Find best-fit vehicle (considering existing allocations)
    const suggestedVehicle = await findBestFitVehicle(vehicles, order, organizationId);
    
    if (!suggestedVehicle) {
      console.log('[Auto-Schedule] No suitable vehicle found', { orderId });
      return;
    }

    // Get product capacity info
    const primaryProduct = order.items[0];
    const productCapacityTotal = primaryProduct
      ? getVehicleCapacityForProduct(suggestedVehicle, primaryProduct.productId)
      : suggestedVehicle.vehicleCapacity || DEFAULT_CAPACITY;
    
    // Calculate how much capacity is already allocated to this vehicle for this product
    // Track the maximum per-trip quantity (not sum, since vehicles can handle multiple orders)
    const pendingOrdersSnapshot = await db
      .collection(PENDING_ORDERS_COLLECTION)
      .where('organizationId', '==', organizationId)
      .where('status', '==', 'pending')
      .get();
    
    let productCapacityUsed = 0;
    if (primaryProduct) {
      const orderQtyPerTrip = primaryProduct.fixedQuantityPerTrip || primaryProduct.totalQuantity;
      productCapacityUsed = orderQtyPerTrip; // Start with this order's quantity
      
      // Find maximum per-trip quantity already allocated to this vehicle
      pendingOrdersSnapshot.docs.forEach((doc) => {
        if (doc.id === orderId) return; // Skip current order
        
        const orderData = doc.data();
        const autoSchedule = orderData.autoSchedule;
        if (autoSchedule?.suggestedVehicleId === suggestedVehicle.id) {
          const orderItems = (orderData.items as any[]) || [];
          if (orderItems.length > 0) {
            const item = orderItems[0];
            if (item.productId === primaryProduct.productId) {
              const allocatedQty = (item.fixedQuantityPerTrip as number) || (item.totalQuantity as number);
              productCapacityUsed = Math.max(productCapacityUsed, allocatedQty);
            }
          }
        }
      });
    }

    // Calculate priority score
    const priorityScore = calculatePriorityScore(order);

    // Update order with auto-schedule data
    const autoScheduleData = {
      estimatedDeliveryDate: admin.firestore.Timestamp.fromDate(estimatedDeliveryDate),
      suggestedVehicleId: suggestedVehicle.id,
      suggestedVehicleNumber: suggestedVehicle.vehicleNumber,
      priorityScore,
      calculatedAt: admin.firestore.FieldValue.serverTimestamp(),
      totalTripsRequired: calculateTotalTrips(order),
      productCapacityUsed,
      productCapacityTotal,
    };

    await db
      .collection(PENDING_ORDERS_COLLECTION)
      .doc(orderId)
      .update({
        autoSchedule: autoScheduleData,
      });

    // Update estimated delivery date reference in organization document
    if (primaryProduct) {
      await updateEstimatedDeliveryDateReference(
        organizationId,
        primaryProduct.productId,
        primaryProduct.fixedQuantityPerTrip || primaryProduct.totalQuantity,
        estimatedDeliveryDate,
      );
    }

    console.log('[Auto-Schedule] Successfully scheduled order', {
      orderId,
      estimatedDeliveryDate: estimatedDeliveryDate.toISOString(),
      suggestedVehicle: suggestedVehicle.vehicleNumber,
      priorityScore,
    });
  } catch (error) {
    console.error('[Auto-Schedule] Error scheduling order', {
      orderId,
      error,
    });
    // Don't throw - we don't want to block order creation
  }
}

/**
 * Cloud Function: Triggered when an order is created
 * Automatically calculates ETA and suggests vehicle assignment
 */
export const onOrderCreatedAutoSchedule = functions
  .region('asia-south1')
  .firestore
  .document(`${PENDING_ORDERS_COLLECTION}/{orderId}`)
  .onCreate(async (snapshot, context) => {
    const orderId = context.params.orderId;
    const orderData = snapshot.data();

    console.log('[Auto-Schedule] Processing new order', { orderId });

    await autoScheduleOrder(orderId, orderData);
  });

