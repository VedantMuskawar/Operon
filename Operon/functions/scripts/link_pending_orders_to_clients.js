/**
 * Script to link migrated pending orders to actual clients in Firestore.
 * Usage: node link_pending_orders_to_clients.js
 *
 * This script assumes:
 * - Orders are in 'orders' collection.
 * - Clients are in 'clients' collection.
 * - Each order has a field (e.g., 'clientLegacyId' or 'clientPhone') to match with a client.
 * - Updates each pending order to reference the correct client document.
 */

const admin = require('firebase-admin');
const serviceAccount = require('../../creds/service-account.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

const db = admin.firestore();

async function linkPendingOrders() {
  const ordersRef = db.collection('PENDING_ORDERS');
  const clientsRef = db.collection('clients');
  const deliveryCitiesRef = db.collection('DELIVERY_CITIES');
  const deliveryZonesRef = db.collection('DELIVERY_ZONES');

  // Helper to normalize phone numbers (remove +91, spaces, etc.)
  function normalizePhone(phone) {
    if (!phone) return '';
    let p = phone.trim();
    p = p.replace(/\s+/g, '');
    if (p.startsWith('+91')) return p;
    if (p.startsWith('91')) return '+' + p;
    if (p.startsWith('+')) return p;
    // Assume it's a 10-digit number
    if (p.length === 10) return '+91' + p;
    return p;
  }

  // Helper to lowercase and trim names
  function normalizeName(name) {
    return (name || '').toLowerCase().trim();
  }

  async function ensureDeliveryCity(cityName, region) {
    if (!cityName) return null;
    const cityId = cityName.toLowerCase().replace(/\s+/g, '_');
    const cityDocRef = deliveryCitiesRef.doc(cityId);
    const cityDoc = await cityDocRef.get();
    if (!cityDoc.exists) {
      await cityDocRef.set({
        city_name: cityName,
        region: region || '',
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        createdBy: 'migration-script',
      });
      console.log(`Created DELIVERY_CITIES/${cityId}`);
    }
    return cityDocRef;
  }

  async function ensureDeliveryZone(zoneId, cityName, region) {
    if (!zoneId) return null;
    const zoneDocRef = deliveryZonesRef.doc(zoneId);
    const zoneDoc = await zoneDocRef.get();
    if (!zoneDoc.exists) {
      await zoneDocRef.set({
        zone_id: zoneId,
        city_name: cityName || '',
        region: region || '',
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        createdBy: 'migration-script',
      });
      console.log(`Created DELIVERY_ZONES/${zoneId}`);
    }
    return zoneDocRef;
  }

  // Query all pending orders
  const pendingOrdersSnap = await ordersRef.where('status', '==', 'pending').get();
  console.log(`Found ${pendingOrdersSnap.size} pending orders.`);

  let updatedCount = 0;
  for (const orderDoc of pendingOrdersSnap.docs) {
    const order = orderDoc.data();
    // Normalize phone and name for matching
    const orderPhone = normalizePhone(order.clientPhone);
    const orderPhoneRaw = (order.clientPhone || '').replace(/\s+/g, '');
    const orderPhoneNorm = normalizePhone(order.clientPhone);
    const orderPhoneNoPlus = orderPhoneNorm.replace(/^\+/, '');
    const orderPhoneNo91 = orderPhoneNorm.replace(/^\+91/, '');
    const orderName = normalizeName(order.clientName);
    if (!orderPhoneNorm && !orderName) {
      console.warn(`Order ${orderDoc.id} missing clientPhone and clientName.`);
      continue;
    }

    // If clientId exists, update clientPhone to match client
    // If clientPhone starts with '91' and not '+', add '+' in front
    if (typeof order.clientPhone === 'string' && order.clientPhone.startsWith('91') && !order.clientPhone.startsWith('+')) {
      const fixedPhone = '+' + order.clientPhone;
      await orderDoc.ref.update({ clientPhone: fixedPhone });
      console.log(`Fixed order ${orderDoc.id} clientPhone from ${order.clientPhone} to ${fixedPhone}`);
      continue;
    }
    if (order.clientId) {
      const clientDoc = await clientsRef.doc(order.clientId).get();
      if (clientDoc.exists) {
        let newPhone = clientDoc.get('primaryPhoneNormalized');
        if (!newPhone && Array.isArray(clientDoc.get('phoneIndex')) && clientDoc.get('phoneIndex').length > 0) {
          newPhone = clientDoc.get('phoneIndex')[0];
        }
        if (newPhone && order.clientPhone !== newPhone) {
          await orderDoc.ref.update({ clientPhone: newPhone });
          console.log(`Updated order ${orderDoc.id} clientPhone from ${order.clientPhone} to ${newPhone}`);
        }
      } else {
        console.warn(`ClientId ${order.clientId} not found for order ${orderDoc.id}`);
      }
      continue;
    }

    // Ensure DELIVERY_CITIES and DELIVERY_ZONES
    const cityName = order.deliveryZone?.city_name;
    const region = order.deliveryZone?.region;
    const zoneId = order.deliveryZone?.zone_id;
    await ensureDeliveryCity(cityName, region);
    await ensureDeliveryZone(zoneId, cityName, region);

    // Update the order's client reference
    await orderDoc.ref.update({
      clientId: clientDoc.id,
      clientRef: clientsRef.doc(clientDoc.id),
    });
    updatedCount++;
    console.log(`Linked order ${orderDoc.id} to client ${clientDoc.id}`);
  }
  console.log(`Updated ${updatedCount} orders.`);
}

linkPendingOrders().then(() => {
  console.log('Script complete.');
  process.exit(0);
}).catch((err) => {
  console.error('Error linking orders:', err);
  process.exit(1);
});
