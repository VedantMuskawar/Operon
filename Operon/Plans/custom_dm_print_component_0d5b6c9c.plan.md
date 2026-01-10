---
name: Custom DM Print Component with Universal Design
overview: Create both a custom Delivery Memo print component for organization ID NlQgs9kADbZr4ddBRkhS (Lakshmee Intelligent Technologies, matching the old PaveBoard app design) and a universal DM print component for all other organizations. Include UI options for choosing between designs. Components will be shared between web and Android apps, use default payment account for QR code generation, and support GST display.
todos:
  - id: add_dependencies
    content: Add qr_flutter, printing, and pdf packages to core_ui pubspec.yaml
    status: pending
  - id: create_qr_widget
    content: Create shared QR code widget in core_ui/components/qr_code_widget.dart
    status: pending
    dependencies:
      - add_dependencies
  - id: add_payment_account_method
    content: Add getPrimaryPaymentAccount method to payment accounts data source and repository
    status: pending
  - id: create_custom_dm_widget
    content: Create delivery_memo_print_custom_widget.dart with Lakshmee design matching old app
    status: pending
    dependencies:
      - create_qr_widget
      - add_payment_account_method
  - id: create_universal_dm_widget
    content: Create delivery_memo_print_universal_widget.dart with generic design for all organizations
    status: pending
    dependencies:
      - create_qr_widget
      - add_payment_account_method
      - create_dm_settings_model
  - id: create_dm_settings_model
    content: Create DmSettings entity/model with branding and info fields
    status: pending
  - id: create_dm_settings_datasource
    content: Create DM Settings data source and repository for Firestore operations
    status: pending
    dependencies:
      - create_dm_settings_model
  - id: create_dm_settings_cubit
    content: Create DM Settings Cubit for state management
    status: pending
    dependencies:
      - create_dm_settings_datasource
  - id: create_dm_settings_page
    content: Create DM Settings page UI with form fields for branding and info configuration
    status: pending
    dependencies:
      - create_dm_settings_cubit
  - id: add_dm_settings_route
    content: Add DM Settings route to app router with permission checks
    status: pending
    dependencies:
      - create_dm_settings_page
  - id: create_design_selector
    content: Create dm_design_selector_dialog.dart for choosing between custom and universal designs
    status: pending
    dependencies:
      - create_custom_dm_widget
      - create_universal_dm_widget
  - id: create_dm_wrapper
    content: Create delivery_memo_print_widget.dart wrapper/router component that selects design and loads DM Settings
    status: pending
    dependencies:
      - create_custom_dm_widget
      - create_universal_dm_widget
      - create_design_selector
      - create_dm_settings_datasource
  - id: implement_org_settings
    content: Implement organization settings service to store and retrieve DM design preference
    status: pending
  - id: add_print_integration
    content: Integrate print functionality in scheduled_trip_tile.dart and delivery_memos_view.dart with design selection
    status: pending
    dependencies:
      - create_dm_wrapper
      - implement_org_settings
  - id: test_printing
    content: Test PDF generation and printing on both Android and Web platforms
    status: pending
    dependencies:
      - add_print_integration
---

# Custom DM Print Component Implementation

## Overview

Create two Delivery Memo (DM) print designs:

1. **Custom Design**: Replicates the design from the old PaveBoard app, specifically for organization ID `NlQgs9kADbZr4ddBRkhS` (Lakshmee Intelligent Technologies)
2. **Universal Design**: A clean, professional DM template for all other organizations

Both designs will be shared between web and Android apps, use the default payment account for QR code generation, and support GST display. Users will be able to choose which design to use via UI options.

## Architecture

### Shared Components Location

- **Custom DM Component**: `packages/core_ui/lib/components/delivery_memo_print_custom_widget.dart` (Lakshmee design)
- **Universal DM Component**: `packages/core_ui/lib/components/delivery_memo_print_universal_widget.dart` (Generic design)
- **DM Print Wrapper**: `packages/core_ui/lib/components/delivery_memo_print_widget.dart` (Router component)
- **Design Selector Dialog**: `packages/core_ui/lib/components/dm_design_selector_dialog.dart`
- **QR Code Widget**: `packages/core_ui/lib/components/qr_code_widget.dart`
- **Payment Account Service**: Add method to `packages/core_datasources/lib/payment_accounts/payment_accounts_repository.dart`
- **DM Settings Page**: `apps/Operon_Client_android/lib/presentation/views/dm_settings_page.dart` (Android)
- **DM Settings Page**: `apps/Operon_Client_web/lib/presentation/views/dm_settings_page.dart` (Web)
- **DM Settings Model**: `packages/core_models/lib/entities/dm_settings.dart`
- **DM Settings Repository**: `packages/core_datasources/lib/dm_settings/dm_settings_repository.dart`
- **DM Settings Data Source**: `packages/core_datasources/lib/dm_settings/dm_settings_data_source.dart`
- **DM Settings Cubit**: `apps/Operon_Client_android/lib/presentation/blocs/dm_settings/dm_settings_cubit.dart`
- **Organization Settings**: Store DM design preference and branding info in `ORGANIZATIONS/{orgId}/DM_SETTINGS` document

### Key Files to Create/Modify

1. **`packages/core_ui/lib/components/delivery_memo_print_widget.dart`**

   - Main router/wrapper component
   - Determines which design to use based on DM Settings or user selection
   - **Fetches DM Settings** before rendering
   - Falls back to organization document data if DM Settings not configured
   - Provides unified interface for printing
   - Passes DM Settings to child components (custom/universal)

2. **`packages/core_ui/lib/components/delivery_memo_print_custom_widget.dart`**

   - Custom Lakshmee design matching the old app
   - Two tickets per page (original + duplicate with gray background)
   - QR code on left, details on right
   - A4 portrait sizing (210mm x 297mm)
   - **Branded header and styling from DM Settings:**
     - Use `dmSettings.companyName` if set, otherwise org name
     - Use `dmSettings.address` if set, otherwise org address
     - Use `dmSettings.phoneNumber` if set, otherwise org phone
     - Use `dmSettings.logoUrl` if set
     - Use `dmSettings.jurisdictionNote` for footer note
     - Use `dmSettings.watermarkUrl` if watermark enabled

3. **`packages/core_ui/lib/components/delivery_memo_print_universal_widget.dart`**

   - Universal/generic DM design for all organizations
   - Clean, professional layout
   - **Adapts to organization branding from DM Settings:**
     - Use `dmSettings.companyName` if set, otherwise org name
     - Use `dmSettings.address` if set, otherwise org address
     - Use `dmSettings.phoneNumber` if set, otherwise org phone
     - Use `dmSettings.email` if set
     - Use `dmSettings.website` if set
     - Use `dmSettings.logoUrl` if set (logo placeholder)
     - Use `dmSettings.gstNumber` if set
     - Use `dmSettings.jurisdictionNote` for footer note
     - Use `dmSettings.footerNote` for additional footer text
     - Use `dmSettings.watermarkUrl` if watermark enabled
   - Same A4 portrait sizing
   - Flexible layout supporting different content types

4. **`packages/core_ui/lib/components/dm_design_selector_dialog.dart`**

   - Dialog to choose DM design when printing
   - Options: "Custom Design" (Lakshmee) or "Universal Design"
   - Can save preference per organization
   - Shows preview thumbnails if possible

5. **`packages/core_ui/lib/components/qr_code_widget.dart`**

   - Shared QR code widget for both platforms
   - Supports UPI ID generation and image URL display
   - Uses `qr_flutter` package

6. **Payment Account Repository Method**

   - Add `getPrimaryPaymentAccount(String orgId)` method
   - Query `ORGANIZATIONS/{orgId}/PAYMENT_ACCOUNTS` where `isPrimary == true`
   - Return `PaymentAccount` with `upiId` and `qrCodeImageUrl`

7. **Organization Settings Service**

   - Store DM design preference: `dmPrintDesign: 'custom' | 'universal'`
   - Storage options (following codebase patterns):
     - **Option A**: Store in `ORGANIZATIONS/{orgId}` document as a field (simpler, recommended)
     - **Option B**: Store in `ORGANIZATIONS/{orgId}/SETTINGS` subcollection document (more organized)
   - Default logic:
     - If org ID is "NlQgs9kADbZr4ddBRkhS" → default to 'custom' (Lakshmee Intelligent Technologies)
     - Otherwise → default to 'universal'
   - Create data source/repository methods:
     - `getDmPrintDesign(String orgId): Future<String>`
     - `setDmPrintDesign(String orgId, String design): Future<void>`

## Data Mapping

### Old App Structure → New App Structure

- `dmData.productName` → `items[0].productName` (use first item)
- `dmData.productQuant` → Calculate from `items[0].totalQuantity` or trip-specific quantity
- `dmData.productUnitPrice` → `items[0].unitPrice`
- `dmData.clientName` → `clientName`
- `dmData.address` → `deliveryZone.city_name` + `deliveryZone.region` (or `deliveryAddress` if exists)
- `dmData.clientPhoneNumber` → `customerNumber` or `clientPhone`
- `dmData.vehicleNumber` → `vehicleNumber`
- `dmData.driverName` → `driverName`
- `dmData.deliveryDate` → `scheduledDate`

### Pricing Structure (GST Support)

- Subtotal: `tripPricing.subtotal`
- GST: `tripPricing.gstAmount` (if > 0, show as separate row)
- Total: `tripPricing.total`
- Payment Mode: `paymentType` ("pay_on_delivery" → "Cash", "pay_later" → "Credit")

## Implementation Steps

### 0. Define Constants

- Create constants file or add to existing constants:
  - In `packages/core_ui/lib/constants/dm_print_constants.dart`:
    ```dart
    class DmPrintConstants {
      // Organization ID that uses custom DM design
      static const String customDmOrgId = 'NlQgs9kADbZr4ddBRkhS';
      
      // Design types
      static const String designCustom = 'custom';
      static const String designUniversal = 'universal';
    }
    ```


### 1. Create Shared QR Code Widget

- Add `qr_flutter` dependency to `core_ui/pubspec.yaml` (if not already present)
- Create `qr_code_widget.dart` that:
  - Takes `upiId` or `qrCodeImageUrl` and `label`
  - Generates QR code using `qr_flutter` for UPI ID
  - Displays image if `qrCodeImageUrl` is provided
  - Falls back to placeholder if neither available

### 2. Add Payment Account Repository Method

- In `packages/core_datasources/lib/payment_accounts/payment_accounts_data_source.dart`:
  - Add `Future<PaymentAccount?> getPrimaryPaymentAccount(String orgId)`
  - Query where `isPrimary == true` and `isActive == true`
  - Return first match or null
- Expose in repository layer

### 3. Create DM Settings Model & Data Layer

- Create `DmSettings` entity in `packages/core_models/lib/entities/dm_settings.dart`:
  - Include all branding and info fields (company name, address, phone, logo, etc.)
  - `toJson()` and `fromJson()` methods
  - `copyWith()` method for updates

- Create DM Settings Data Source:
  - `getDmSettings(String orgId): Future<DmSettings?>`
  - `saveDmSettings(String orgId, DmSettings settings): Future<void>`
  - Storage path: `ORGANIZATIONS/{orgId}/DM_SETTINGS` (single document)

- Create DM Settings Repository and Cubit:
  - Wrap data source methods
  - Handle default values and fallbacks to organization document
  - States: loading, success, failure

### 3a. Create Custom DM Print Widget (Lakshmee Design)

- Create `delivery_memo_print_custom_widget.dart` with:
  - Same layout as old app (QR left, details right)
  - Two tickets: original (white) + duplicate (gray #e0e0e0)
  - **Branding from DM Settings:**
    - Use `dmSettings.companyName` if set, otherwise "LAKSHMEE INTELLIGENT TECHNOLOGIES"
    - Use `dmSettings.address` if set, otherwise hardcoded address
    - Use `dmSettings.phoneNumber` if set, otherwise hardcoded phone
    - Use `dmSettings.logoUrl` if set
    - Use `dmSettings.watermarkUrl` if watermark enabled
  - Header: "🚩 जय श्री राम 🚩" + "🚚 Delivery Memo"
  - QR code section: 180x180px with label and amount
  - Info section: Client, Address, Phone, Date, Vehicle, Driver
  - Table: Product, Quantity, Unit Price, Subtotal, GST (if > 0), Total, Payment Mode
  - Footer: Use `dmSettings.jurisdictionNote` if set, otherwise "Note: Subject to Chandrapur Jurisdiction" + signature lines
  - Cut line between tickets

### 3b. Create Universal DM Print Widget (Generic Design)

- Create `delivery_memo_print_universal_widget.dart` with:
  - Clean, modern layout suitable for any organization
  - Single ticket per page or two per page (user preference)
  - **Dynamic branding from DM Settings (fallback to organization document):**
    - Use `dmSettings.companyName` if set, otherwise org name
    - Use `dmSettings.address` if set, otherwise org address
    - Use `dmSettings.phoneNumber` if set, otherwise org phone
    - Use `dmSettings.email` if set
    - Use `dmSettings.website` if set
    - Use `dmSettings.gstNumber` if set
    - Use `dmSettings.logoUrl` if set
    - Use `dmSettings.jurisdictionNote` for footer note
    - Use `dmSettings.footerNote` for additional footer text
    - Use `dmSettings.watermarkUrl` if watermark enabled
  - QR code section: Similar size and positioning
  - Info section: Same fields but more flexible layout
  - Table: Product, Quantity, Unit Price, Subtotal, GST, Total, Payment Mode
  - Footer: Signature lines, optional jurisdiction note
  - Print-optimized styling

### 3b. Create Design Selector Dialog

- Create `dm_design_selector_dialog.dart` with:
  - Radio buttons or cards for design selection
  - Options: "Custom Design" (only shown for org ID NlQgs9kADbZr4ddBRkhS) and "Universal Design"
  - Automatically hide "Custom Design" option for other organizations
  - "Remember my choice" checkbox
  - Preview option (show layout description)
  - Save preference to organization settings if checked

### 4. Print/PDF Integration

- For Android: Use `printing` package to generate PDF
- For Web: Use `dart:html` window.print() or `pdf` package
- Add print button/dialog integration points

### 5. Create DM Settings Page UI

- Create `dm_settings_page.dart` for both Android and Web apps:
  - Follow pattern from `payment_accounts_page.dart`
  - Use `ModernPageHeader` with title "DM Settings"
  - Form sections with proper grouping:
    - **Design Selection** (if org ID is NlQgs9kADbZr4ddBRkhS or user has access):
      - Radio buttons: "Custom Design" vs "Universal Design"
    - **Branding Information**:
      - Company Name field (required)
      - Address field (multiline, required)
      - Phone Number field (required)
      - Email field (optional)
      - Website field (optional)
      - GST Number field (optional)
      - Logo upload section with image preview
      - Upload to Firebase Storage, store URL in settings
    - **Additional Information**:
      - Jurisdiction Note field (e.g., "Subject to Chandrapur Jurisdiction")
      - Footer Note field (multiline, optional)
      - Show Watermark toggle
      - Watermark upload (if watermark enabled)
  - Preview section: Show preview of DM with current settings
  - Save button: Update DM Settings and show success message
  - Cancel button: Discard changes
  - Validation: Company name and address are required
  - Permission check: Only admins or users with 'dmSettings' permission can access

- Add route in app router:
  - `/dm-settings` route
  - Check permissions before allowing access
  - Link from settings menu or access control page

### 6. Integration Points

- After DM generation in `scheduled_trip_tile.dart`:
  - **Auto-open print preview**: After successful DM generation, automatically open print preview
  - Load DM Settings
  - Use design from DM Settings (or default based on org ID)
  - Pass DM Settings and DM data to print widget
  - Show print preview dialog/page with branding from settings
  - No extra button needed - print opens automatically after generation

- In `delivery_memos_view.dart` and `delivery_memos_page.dart`:
  - **Make DM tile/number tappable**: Tapping the DM number or entire tile opens print preview directly
  - **Add print button**: Add a print icon button to each DM tile for explicit print action
  - **Print functionality**:
    - Load DM Settings before showing print
    - Use design from DM Settings (or default based on org ID)
    - Pass DM Settings and DM data to print widget
    - Show print preview dialog/page
  - **Implementation**:
    - Wrap DM number in `GestureDetector` or `InkWell` to make it tappable
    - Add print icon button (e.g., `Icons.print`) in the tile actions
    - Both tap and button trigger same print function: `_openPrintPreview(dm)`
    - No separate "open details" needed - tapping opens print directly

- DM Settings Page Integration:
  - Add navigation link in settings/setup section of app
  - Add route `/dm-settings` in app router
  - Show in access control page or settings menu (admin only)
  - Load current DM Settings on page open
  - Save changes to Firestore
  - Show preview of DM with current settings

- Print Widget Integration:
  - Both custom and universal widgets receive DM Settings and DM data as parameters
  - Widgets use settings for branding, falling back to org data if not set
  - Settings override organization document fields when present
  - Print preview can be shown as:
    - **Dialog/Modal**: Overlay dialog with print preview (recommended for mobile)
    - **Full Page**: Navigate to print preview page (recommended for web)
    - Include print button in preview to trigger actual print/PDF generation

- Print Function Implementation:
  - Create `_openPrintPreview(BuildContext context, Map<String, dynamic> dm)` helper function:
    - Load DM Settings for current organization (async)
    - Determine design (from `dmSettings.printDesign` or default based on org ID)
    - Fetch primary payment account for QR code generation
    - Show print preview dialog/page with:
      - DM data (from `dm` parameter)
      - DM Settings (for branding)
      - Payment account (for QR code)
      - Selected design (custom or universal)
    - Handle print/PDF generation when user clicks print button in preview
  - **Usage in DM tiles**:
    - `onTap: () => _openPrintPreview(context, dm)` - for DM number/tile tap
    - `IconButton(icon: Icons.print, onPressed: () => _openPrintPreview(context, dm))` - for print button
  - **Usage after DM generation**:
    - After successful DM generation, call `_openPrintPreview(context, generatedDmData)`
    - No user action needed - print preview opens automatically

## Dependencies

### Add to `packages/core_ui/pubspec.yaml`:

```yaml
dependencies:
  qr_flutter: ^4.1.0
  printing: ^5.12.0  # For PDF generation
  pdf: ^3.10.0       # For PDF creation
```

### Add to `packages/core_datasources/pubspec.yaml`:

- Already has `cloud_firestore` for payment account queries

## Design Specifications

### Custom Design (Lakshmee):

- Page: 210mm x 297mm (A4 portrait)
- Ticket: 190mm x 138mm each
- Padding: 5mm
- Font: Inter (or system default)
- QR Code: 180x180px
- Colors: Black text, gray duplicate background (#e0e0e0)
- Company: "LAKSHMEE INTELLIGENT TECHNOLOGIES"
- Address: "B-24/2, M.I.D.C., CHANDRAPUR - 442406"
- Phone: "+91 8149448822 | +91 9420448822"
- Jurisdiction: "Subject to Chandrapur Jurisdiction"
- Special header: "🚩 जय श्री राम 🚩"

### Universal Design (Generic):

- Page: 210mm x 297mm (A4 portrait)
- Ticket: Flexible sizing, one or two per page
- Padding: 10mm
- Font: System default (Roboto/Inter)
- QR Code: 150-180px (responsive)
- Colors: Black text on white, optional subtle brand colors
- Dynamic branding:
  - Organization name from `org_name` field
  - Address from `address` field or delivery zone
  - Phone from organization settings
  - GST number if available
- Clean header with organization logo placeholder
- Professional footer with signature lines
- Optional jurisdiction note (configurable)

## Testing

- Test QR code generation with UPI ID
- Test QR code display with image URL
- Test fallback when no payment account
- Test GST display (with and without GST) for both designs
- Test print functionality on both platforms
- Test design selector dialog and preference saving
- Test organization settings persistence
- Test default design assignment (org ID NlQgs9kADbZr4ddBRkhS → custom, others → universal)
- Test data mapping from new DM structure for both designs
- Test universal design with different organization data
- Test switching between designs without regenerating DM
- Test print preview for both designs
- Test DM Settings page UI and form validation
- Test tapping DM number/tile to open print preview
- Test print button in DM tile
- Test auto-open print preview after DM generation
- Test print preview dialog/modal on mobile
- Test print preview page on web
- Test saving DM Settings to Firestore
- Test DM widgets using settings vs organization fallback
- Test branding fields (company name, address, phone, logo)
- Test info fields (jurisdiction note, footer note, watermark)
- Test permission checks for DM Settings page access
- Test preview functionality in DM Settings page