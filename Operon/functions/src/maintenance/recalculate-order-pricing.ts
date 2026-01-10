import {onCall} from 'firebase-functions/v2/https';
import {getFirestore} from 'firebase-admin/firestore';
import {PENDING_ORDERS_COLLECTION} from '../shared/constants';

const db = getFirestore();

/**
 * Recalculate order pricing from items
 * Useful after schema changes or data corrections
 */
export const recalculateOrderPricing = onCall(async (request) => {
  const {orderId} = request.data;
  
  const orderRef = db.collection(PENDING_ORDERS_COLLECTION).doc(orderId);
  const orderDoc = await orderRef.get();
  
  if (!orderDoc.exists) {
    return {success: false, error: 'Order not found'};
  }
  
  const orderData = orderDoc.data()!;
  const items = (orderData.items as any[]) || [];
  
  // Recalculate item pricing
  const updatedItems = items.map((item: any) => {
    const subtotal = item.estimatedTrips * item.fixedQuantityPerTrip * item.unitPrice;
    let gstAmount: number | undefined;
    
    if (item.gstPercent && item.gstPercent > 0) {
      gstAmount = subtotal * (item.gstPercent / 100);
    }
    
    const total = subtotal + (gstAmount || 0);
    
    const updatedItem: any = {
      ...item,
      subtotal,
      total
    };
    
    // Only include GST fields if applicable
    if (gstAmount !== undefined && gstAmount > 0) {
      updatedItem.gstPercent = item.gstPercent;
      updatedItem.gstAmount = gstAmount;
    } else {
      // Remove GST fields if not applicable
      delete updatedItem.gstPercent;
      delete updatedItem.gstAmount;
    }
    
    return updatedItem;
  });
  
  // Recalculate order pricing
  const subtotal = updatedItems.reduce((sum: number, item: any) => sum + item.subtotal, 0);
  const totalGst = updatedItems.reduce((sum: number, item: any) => sum + (item.gstAmount || 0), 0);
  const totalAmount = subtotal + totalGst;
  
  const pricing: any = {
    subtotal,
    totalAmount,
    currency: orderData.pricing?.currency || 'INR'
  };
  
  // Only include totalGst if there's actual GST
  if (totalGst > 0) {
    pricing.totalGst = totalGst;
  }
  
  // Update order
  await orderRef.update({
    items: updatedItems,
    pricing,
    updatedAt: new Date()
  });
  
  return {
    success: true,
    orderId,
    pricing,
    itemsUpdated: updatedItems.length
  };
});

