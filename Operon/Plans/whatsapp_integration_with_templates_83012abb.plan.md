---
name: WhatsApp Integration with Templates
overview: Integrate WhatsApp API for 4 key events (Client Added, Order Added, Trip Dispatched, Trip Delivered) with template designs and implementation. Trip dispatch WhatsApp function exists but needs to be exported. Trip delivery notification needs to be implemented.
todos:
  - id: fix-trip-dispatch-export
    content: Export trip-dispatch-whatsapp functions in functions/src/orders/index.ts
    status: completed
  - id: implement-trip-delivery
    content: Create functions/src/orders/trip-delivery-whatsapp.ts with onTripDeliveredSendWhatsapp Cloud Function that triggers when trip status changes to 'delivered'
    status: completed
  - id: update-whatsapp-settings
    content: Add tripDispatchTemplateId and tripDeliveryTemplateId fields to WhatsappSettings interface in all WhatsApp-related files
    status: completed
  - id: export-trip-delivery
    content: Export trip-delivery-whatsapp functions in functions/src/orders/index.ts
    status: completed
    dependencies:
      - implement-trip-delivery
  - id: create-template-docs
    content: Create comprehensive template design documentation with exact parameter formatting for all 4 templates
    status: completed
---

# fWhatsApp API Integration Plan

## Overview

Integrate WhatsApp Business API for automated notifications at 4 key events in the order fulfillment lifecycle. The system already has partial WhatsApp integration - this plan extends it to cover all events with proper template support.

## Current State

### Existing Implementation

- ✅ **Client Welcome** - Uses WhatsApp templates (implemented in `functions/src/clients/client-whatsapp.ts`)
- ✅ **Order Confirmation** - Uses text messages (implemented in `functions/src/orders/order-whatsapp.ts`)
- ✅ **Trip Dispatch** - Uses text messages (implemented in `functions/src/orders/trip-dispatch-whatsapp.ts` but NOT exported)
- ❌ **Trip Delivery** - Not implemented

### Architecture

- Uses Meta WhatsApp Business API (Graph API v19.0)
- Settings stored in `WHATSAPP_SETTINGS/{organizationId}` collection
- Cloud Functions triggered by Firestore document events
- Test number configuration supported via settings

## Implementation Plan

### 1. Fix Trip Dispatch Export

**File**: `functions/src/orders/index.ts`

- Export `trip-dispatch-whatsapp` functions (currently missing from exports)
- This will enable the existing trip dispatch WhatsApp functionality

### 2. Implement Trip Delivery WhatsApp Notification

**New File**: `functions/src/orders/trip-delivery-whatsapp.ts`

- Create new Cloud Function: `onTripDeliveredSendWhatsapp`
- Trigger: `onUpdate` for `SCHEDULE_TRIPS/{tripId}` collection
- Condition: Trip status changes from any status to `'delivered'`
- Similar structure to `trip-dispatch-whatsapp.ts`
- Fetch client phone from trip document or CLIENT collection
- Use shared `loadWhatsappSettings` helper (or create shared utility)

**Export**: Add to `functions/src/orders/index.ts`

### 3. Design Message Templates

#### Template 1: Client Welcome (Already Exists)

- **Template Name**: `client_welcome` (configurable via `welcomeTemplateId`)
- **Category**: UTILITY
- **Parameters**: 
  - `{{1}}` - Client name
- **Trigger**: When client document created in `CLIENTS` collection
- **Status**: ✅ Already implemented

#### Template 2: Order Confirmation

- **Template Name**: `order_confirmation` (configurable via `orderConfirmationTemplateId`)
- **Category**: UTILITY
- **Parameters**:
  - `{{1}}` - Client name
  - `{{2}}` - Order items (formatted text)
  - `{{3}}` - Delivery zone (e.g., "City Name, Region")
  - `{{4}}` - Pricing summary (formatted text)
  - `{{5}}` - Advance payment info (optional, empty if none)
- **Trigger**: When order document created in `PENDING_ORDERS` collection
- **Status**: ⚠️ Currently using text messages (convert to template)

#### Template 3: Trip Dispatch

- **Template Name**: `trip_dispatch` (new field: `tripDispatchTemplateId`)
- **Category**: UTILITY
- **Parameters**:
  - `{{1}}` - Client name
  - `{{2}}` - Trip date (formatted)
  - `{{3}}` - Vehicle number and slot info
  - `{{4}}` - Items list (formatted text)
  - `{{5}}` - Driver name and contact
  - `{{6}}` - Pricing summary (formatted text)
- **Trigger**: When trip status changes to `'dispatched'` in `SCHEDULE_TRIPS` collection
- **Status**: ⚠️ Currently using text messages (convert to template)

#### Template 4: Trip Delivery

- **Template Name**: `trip_delivery` (new field: `tripDeliveryTemplateId`)
- **Category**: UTILITY
- **Parameters**:
  - `{{1}}` - Client name
  - `{{2}}` - Trip date (formatted)
  - `{{3}}` - Items delivered (formatted text)
  - `{{4}}` - Delivery confirmation message
  - `{{5}}` - Next steps or feedback request
- **Trigger**: When trip status changes to `'delivered'` in `SCHEDULE_TRIPS` collection
- **Status**: ❌ Not implemented (new)

### 4. Update WhatsApp Settings Interface

**Files**:

- `functions/src/clients/client-whatsapp.ts`
- `functions/src/orders/order-whatsapp.ts`
- `functions/src/orders/trip-dispatch-whatsapp.ts`
- `functions/src/orders/trip-delivery-whatsapp.ts`

- Add new optional fields to `WhatsappSettings` interface:
  - `tripDispatchTemplateId?: string`
  - `tripDeliveryTemplateId?: string`
  - `orderConfirmationTemplateId?: string` (already exists in order-whatsapp.ts)

### 5. Convert Text Messages to Templates (Optional - For Production)

**Files**:

- `functions/src/orders/order-whatsapp.ts`
- `functions/src/orders/trip-dispatch-whatsapp.ts`
- `functions/src/orders/trip-delivery-whatsapp.ts`

- Update `sendWhatsappMessage` functions to use template format instead of text
- Template format uses `type: 'template'` with `template.name` and `template.components`
- Keep text messages as fallback for development/testing

### 6. Create Shared WhatsApp Utilities (Refactoring)

**New File**: `functions/src/shared/whatsapp-helpers.ts`

- Extract `loadWhatsappSettings` to shared module
- Extract common message formatting utilities
- Centralize WhatsApp API configuration

**Update**: All WhatsApp-related files to use shared utilities

## Template Message Designs

### Template 2: Order Confirmation

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

**Parameter Formatting**:

- `{{2}}` (Items): "1. Product Name\n   Qty: X units (Y trips)\n   Amount: ₹Z.ZZ\n\n2. Product Name..."
- `{{4}}` (Pricing): "Subtotal: ₹X.XX\nGST: ₹Y.YY\nTotal: ₹Z.ZZ"
- `{{5}}` (Advance): "Advance Paid: ₹X.XX\nRemaining: ₹Y.YY" or empty

### Template 3: Trip Dispatch

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

**Parameter Formatting**:

- `{{2}}` (Date): "DD MMM YYYY" format
- `{{3}}` (Vehicle/Slot): "Vehicle: ABC123 | Slot 1" or "Vehicle: ABC123"
- `{{4}}` (Items): "1. Product Name\n   Qty: X units\n   Unit Price: ₹Y.YY\n\n2. Product Name..."
- `{{5}}` (Driver): "Driver: John Doe\nDriver Contact: +919876543210"
- `{{6}}` (Pricing): "Subtotal: ₹X.XX\nGST: ₹Y.YY\nTotal: ₹Z.ZZ"

### Template 4: Trip Delivery

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

**Parameter Formatting**:

- `{{2}}` (Date): "DD MMM YYYY" format
- `{{3}}` (Items): "1. Product Name - X units\n2. Product Name - Y units"
- `{{4}}` (Confirmation): "Delivery completed successfully. We hope you're satisfied with your order!"
- `{{5}}` (Next Steps): "If you have any feedback or need assistance, please let us know. We appreciate your business!"

## File Structure

```
functions/src/
├── shared/
│   └── whatsapp-helpers.ts          # NEW: Shared WhatsApp utilities
├── clients/
│   └── client-whatsapp.ts           # UPDATE: Add new template fields
└── orders/
    ├── index.ts                     # UPDATE: Export trip-dispatch and trip-delivery
    ├── order-whatsapp.ts            # UPDATE: Convert to templates (optional)
    ├── trip-dispatch-whatsapp.ts    # UPDATE: Convert to templates (optional)
    └── trip-delivery-whatsapp.ts    # NEW: Trip delivery notifications
```

## Configuration

### Test Number Setup

Configure in Firestore: `WHATSAPP_SETTINGS/{organizationId}`

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

### Template Creation Checklist

For each template in Meta Business Suite:

1. Create template with suggested name
2. Use UTILITY category
3. Add parameters as specified
4. Submit for approval (24-48 hours)
5. Update Firestore settings with approved template name
6. Test with real events

## Testing Strategy

1. **Unit Tests**: Test message formatting functions
2. **Integration Tests**: Test Cloud Functions with Firestore emulator
3. **Manual Testing**: 

   - Create test client → Verify welcome message
   - Create test order → Verify order confirmation
   - Dispatch test trip → Verify dispatch notification
   - Deliver test trip → Verify delivery notification

4. **Test Number**: Use Meta's test number for development

## Implementation Order

1. Fix trip dispatch export (quick fix)
2. Implement trip delivery notification (core functionality)
3. Update settings interface (configuration)
4. Create template designs documentation
5. (Optional) Convert text messages to templates
6. (Optional) Refactor to shared utilities

## Notes

- Templates work anytime (no 24-hour window restriction)
- Text messages only work within 24-hour window after customer messages
- For production, templates are recommended
- Test number can be used during development
- All templates should be approved in Meta Business Suite before production use