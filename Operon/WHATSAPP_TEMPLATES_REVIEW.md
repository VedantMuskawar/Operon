# WhatsApp Templates Review for Meta Business Suite

This document lists all WhatsApp templates that need to be created/updated in Meta Business Suite for the Operon application.

## Current Implementation Status

### ✅ Using Templates
1. **Client Welcome Message** - Uses template format

### ⚠️ Using Text Messages (Can be converted to templates)
2. **Order Confirmation** - Currently using text messages
3. **Trip Dispatch** - Currently using text messages
4. **Trip Delivery** - Currently using text messages (newly implemented)

---

## Template 1: Client Welcome Message

**Template Name:** `client_welcome` (default) or configured via `welcomeTemplateId` in settings

**Category:** UTILITY

**Language:** English (en) or configured via `languageCode` in settings

**Template Structure:**

```
Hello {{1}}!

Welcome to our service! We're excited to have you on board.

If you have any questions, feel free to reach out to us.

Thank you!
```

**Parameters:**
- `{{1}}` - Client name (text parameter)

**Usage:**
- Triggered when a new client is created
- Sent via `onClientCreatedSendWhatsappWelcome` function

**Settings Location:**
- Firestore: `WHATSAPP_SETTINGS/{organizationId}`
  - Field: `welcomeTemplateId` (optional, defaults to `client_welcome`)
  - Field: `languageCode` (optional, defaults to `en`)

**Status:** ✅ Already implemented and working

---

## Template 2: Order Confirmation (RECOMMENDED - Currently Text)

**Template Name:** `order_confirmation` (suggested) or configured via `orderConfirmationTemplateId` in settings

**Category:** UTILITY

**Language:** English (en) or configured via `languageCode` in settings

**Current Status:** ⚠️ Currently using text messages (24-hour window limitation)

**Recommended Template Structure:**

```
Hello {{1}}!

Your order has been placed successfully!

Items:
{{2}}

Delivery: {{3}}

Pricing:
{{4}}

{{5}}

Thank you for your order!
```

**Parameters:**
- `{{1}}` - Client name (text)
- `{{2}}` - Order items list (text) - formatted as:
  ```
  1. Product Name
     Qty: X units (Y trips)
     Amount: ₹Z.ZZ
  
  2. Product Name
     Qty: X units (Y trips)
     Amount: ₹Z.ZZ
  ```
- `{{3}}` - Delivery zone (text) - e.g., "City Name, Region"
- `{{4}}` - Pricing summary (text) - formatted as:
  ```
  Subtotal: ₹X.XX
  GST: ₹Y.YY
  Total: ₹Z.ZZ
  ```
- `{{5}}` - Advance payment info (text, optional) - formatted as:
  ```
  Advance Paid: ₹X.XX
  Remaining: ₹Y.YY
  ```
  OR empty string if no advance payment

**Usage:**
- Triggered when an order is created in `PENDING_ORDERS` collection
- Sent via `onOrderCreatedSendWhatsapp` function

**Settings Location:**
- Firestore: `WHATSAPP_SETTINGS/{organizationId}`
  - Field: `orderConfirmationTemplateId` (optional, not currently used)
  - Field: `languageCode` (optional, defaults to `en`)

**Note:** Currently implemented as text messages. To use templates, update the code in `functions/src/orders/order-whatsapp.ts` to use template format instead of text format.

---

## Template 3: Trip Dispatch (RECOMMENDED - Currently Text)

**Template Name:** `trip_dispatch` (suggested) or configured via `tripDispatchTemplateId` in settings

**Category:** UTILITY

**Language:** English (en) or configured via `languageCode` in settings

**Current Status:** ⚠️ Currently using text messages (24-hour window limitation)

**Recommended Template Structure:**

```
Hello {{1}}!

Your trip has been dispatched!

Trip Details:
Date: {{2}}
{{3}}

Items:
{{4}}

Pricing:
{{6}}

{{5}}

Thank you!
```

**Parameters:**
- `{{1}}` - Client name (text)
- `{{2}}` - Trip date (text) - formatted as "DD MMM YYYY" (e.g., "15 Jan 2024")
- `{{3}}` - Vehicle and slot info (text) - formatted as:
  ```
  Vehicle: ABC123 | Slot 1
  ```
  OR just "Vehicle: ABC123" if no slot info
- `{{4}}` - Items list (text) - formatted as:
  ```
  1. Product Name
     Qty: X units
     Unit Price: ₹Y.YY
     GST: ₹Z.ZZ
  
  2. Product Name
     Qty: X units
     Unit Price: ₹Y.YY
  ```
- `{{5}}` - Driver information (text) - formatted as:
  ```
  Driver: John Doe
  Driver Contact: +919876543210
  ```
  OR just "Driver: John Doe" if no contact
- `{{6}}` - Pricing summary (text) - formatted as:
  ```
  Subtotal: ₹X.XX
  GST: ₹Y.YY
  Total: ₹Z.ZZ
  ```

**Usage:**
- Triggered when trip status changes to `'dispatched'` in `SCHEDULE_TRIPS` collection
- Sent via `onTripDispatchedSendWhatsapp` function

**Settings Location:**
- Firestore: `WHATSAPP_SETTINGS/{organizationId}`
  - Field: `tripDispatchTemplateId` (optional, not currently used)
  - Field: `languageCode` (optional, defaults to `en`)

**Note:** Currently implemented as text messages. To use templates, update the code in `functions/src/orders/trip-dispatch-whatsapp.ts` to use template format instead of text format.

---

## Template 4: Trip Delivery (NEW - Currently Text)

**Template Name:** `trip_delivery` (suggested) or configured via `tripDeliveryTemplateId` in settings

**Category:** UTILITY

**Language:** English (en) or configured via `languageCode` in settings

**Current Status:** ⚠️ Currently using text messages (24-hour window limitation)

**Recommended Template Structure:**

```
Hello {{1}}!

Your delivery has been completed!

Trip Date: {{2}}

Items Delivered:
{{3}}

{{4}}

{{5}}

Thank you for choosing us!
```

**Parameters:**
- `{{1}}` - Client name (text)
- `{{2}}` - Trip date (text) - formatted as "DD MMM YYYY" (e.g., "15 Jan 2024")
- `{{3}}` - Items delivered (text) - formatted as:
  ```
  1. Product Name - X units
  2. Product Name - Y units
  3. Product Name - Z units
  ```
- `{{4}}` - Delivery confirmation message (text) - static text:
  ```
  Delivery completed successfully. We hope you're satisfied with your order!
  ```
- `{{5}}` - Next steps/feedback request (text) - static text:
  ```
  If you have any feedback or need assistance, please let us know. We appreciate your business!
  ```

**Usage:**
- Triggered when trip status changes to `'delivered'` in `SCHEDULE_TRIPS` collection
- Sent via `onTripDeliveredSendWhatsapp` function (newly implemented)

**Settings Location:**
- Firestore: `WHATSAPP_SETTINGS/{organizationId}`
  - Field: `tripDeliveryTemplateId` (optional, not currently used)
  - Field: `languageCode` (optional, defaults to `en`)

**Note:** Currently implemented as text messages. To use templates, update the code in `functions/src/orders/trip-delivery-whatsapp.ts` to use template format instead of text format.

---

## Template 5: Order Update (RECOMMENDED - Currently Text)

**Template Name:** `order_update` (suggested)

**Category:** UTILITY

**Language:** English (en) or configured via `languageCode` in settings

**Current Status:** ⚠️ Currently using text messages (24-hour window limitation)

**Recommended Template Structure:**

```
Hello {{1}}!

Your order has been updated!

Items:
{{2}}

Delivery: {{3}}

Pricing:
{{4}}

{{5}}

{{6}}

Thank you!
```

**Parameters:**
- `{{1}}` - Client name (text)
- `{{2}}` - Order items list (text) - same format as order confirmation
- `{{3}}` - Delivery zone (text)
- `{{4}}` - Pricing summary (text) - same format as order confirmation
- `{{5}}` - Advance payment info (text, optional) - same format as order confirmation
- `{{6}}` - Order status (text, optional) - e.g., "Status: Completed" or empty string if pending

**Usage:**
- Triggered when an order is updated (only for significant changes)
- Sent via `onOrderUpdatedSendWhatsapp` function
- Only sends when: items, pricing, status, delivery zone, or advance amount changes

**Settings Location:**
- Firestore: `WHATSAPP_SETTINGS/{organizationId}`
  - Field: `orderUpdateTemplateId` (optional, not currently implemented)
  - Field: `languageCode` (optional, defaults to `en`)

**Note:** Currently implemented as text messages. To use templates, update the code in `functions/src/orders/order-whatsapp.ts` to use template format instead of text format.

---

## Implementation Notes

### Current Text Message Limitations

Text messages work only within a 24-hour window after the customer last messaged you. For production use, templates are recommended because they:
- Work anytime (no 24-hour window restriction)
- Are more reliable
- Provide better deliverability
- Allow for structured messaging

### Template Approval Process

1. Create templates in Meta Business Suite
2. Submit for approval (can take 24-48 hours)
3. Once approved, update Firestore settings with template names
4. (Optional) Update code to use template format instead of text

### Settings Configuration

For each organization, configure in Firestore:

```javascript
// Firestore: WHATSAPP_SETTINGS/{organizationId}
{
  enabled: true,
  token: "your_access_token",
  phoneId: "your_phone_number_id",
  languageCode: "en",
  welcomeTemplateId: "client_welcome",           // ✅ Currently used
  orderConfirmationTemplateId: "order_confirmation", // ⚠️ Not yet used
  tripDispatchTemplateId: "trip_dispatch",      // ⚠️ Not yet used
  tripDeliveryTemplateId: "trip_delivery",      // ⚠️ Not yet used
  orderUpdateTemplateId: "order_update"         // ⚠️ Not yet implemented
}
```

### Test Number Setup

For testing with a test number, configure the same settings in Firestore with your test credentials:

```javascript
{
  enabled: true,
  token: "your_test_access_token",
  phoneId: "your_test_phone_number_id",
  languageCode: "en",
  welcomeTemplateId: "client_welcome",
  orderConfirmationTemplateId: "order_confirmation",
  tripDispatchTemplateId: "trip_dispatch",
  tripDeliveryTemplateId: "trip_delivery"
}
```

---

## Action Items

### Immediate (Required)
- [x] **Template 1: Client Welcome** - Already implemented and working

### Newly Implemented (Core Functionality)
- [x] **Template 4: Trip Delivery** - Cloud Function implemented (`onTripDeliveredSendWhatsapp`)
- [x] **Trip Dispatch Export** - Fixed export in `functions/src/orders/index.ts`

### Recommended (For Production)
- [ ] **Template 2: Order Confirmation** - Create template in Meta Business Suite
- [ ] **Template 3: Trip Dispatch** - Create template in Meta Business Suite
- [ ] **Template 4: Trip Delivery** - Create template in Meta Business Suite
- [ ] Update code to use templates instead of text messages for orders and trips
- [ ] Add `orderUpdateTemplateId` field to settings interface (for Template 5)

### Optional Enhancements
- [ ] Support multiple languages (create templates for each language)
- [ ] Add template for order cancellation notifications
- [ ] Add template for payment reminders
- [ ] Create shared WhatsApp utilities module for code reuse

---

## Template Creation Checklist

For each template in Meta Business Suite:

1. ✅ Choose appropriate category (UTILITY, MARKETING, or AUTHENTICATION)
2. ✅ Write clear, concise message
3. ✅ Add parameters with descriptive names
4. ✅ Test template preview
5. ✅ Submit for approval
6. ✅ Wait for approval (24-48 hours typically)
7. ✅ Update Firestore settings with approved template name
8. ✅ Test with real order/client/trip creation

---

## Example Template Approval Status

| Template Name | Status | Approval Date | Notes |
|--------------|--------|---------------|-------|
| `client_welcome` | ✅ Approved | (Check in Meta) | Currently in use |
| `order_confirmation` | ⏳ Pending | - | Create in Meta Business Suite |
| `trip_dispatch` | ⏳ Pending | - | Create in Meta Business Suite |
| `trip_delivery` | ⏳ Pending | - | Create in Meta Business Suite |
| `order_update` | ⏳ Pending | - | Create in Meta Business Suite |

---

## Code Implementation Status

### Functions Implemented

| Function | File | Status | Template Support |
|----------|------|--------|------------------|
| `onClientCreatedSendWhatsappWelcome` | `functions/src/clients/client-whatsapp.ts` | ✅ Working | ✅ Uses templates |
| `onOrderCreatedSendWhatsapp` | `functions/src/orders/order-whatsapp.ts` | ✅ Working | ⚠️ Text messages |
| `onOrderUpdatedSendWhatsapp` | `functions/src/orders/order-whatsapp.ts` | ✅ Working | ⚠️ Text messages |
| `onTripDispatchedSendWhatsapp` | `functions/src/orders/trip-dispatch-whatsapp.ts` | ✅ Working | ⚠️ Text messages |
| `onTripDeliveredSendWhatsapp` | `functions/src/orders/trip-delivery-whatsapp.ts` | ✅ New | ⚠️ Text messages |

---

## Support

For template creation help:
1. Meta Business Suite: https://business.facebook.com/
2. WhatsApp Business API Documentation: https://developers.facebook.com/docs/whatsapp
3. Template Guidelines: https://developers.facebook.com/docs/whatsapp/message-templates/guidelines

---

## Event Triggers Summary| Event | Collection | Trigger Type | Function |
|-------|------------|--------------|----------|
| Client Added | `CLIENTS` | `onCreate` | `onClientCreatedSendWhatsappWelcome` |
| Order Added | `PENDING_ORDERS` | `onCreate` | `onOrderCreatedSendWhatsapp` |
| Order Updated | `PENDING_ORDERS` | `onUpdate` | `onOrderUpdatedSendWhatsapp` |
| Trip Dispatched | `SCHEDULE_TRIPS` | `onUpdate` (status → 'dispatched') | `onTripDispatchedSendWhatsapp` |
| Trip Delivered | `SCHEDULE_TRIPS` | `onUpdate` (status → 'delivered') | `onTripDeliveredSendWhatsapp` |
