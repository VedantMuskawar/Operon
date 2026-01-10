# SCHEDULE_TRIPS Excel Migration Template

## Required Columns

The following columns are **REQUIRED** for SCHEDULE_TRIPS migration:

| Column Name | Description | Example | Notes |
|------------|-------------|---------|-------|
| **Order ID** or **Def Order ID** | Order document ID | `IQ52jkD8AHjNJnDsuzIF` | Required - Links to PENDING_ORDERS |
| **Client ID** | Client document ID | `TDeBBWF3dnWGEgyFqKYG` | Required |
| **Client Name** | Client name | `Kaniram Pawar` | Required |
| **Delivery Date** | Scheduled delivery date | `2025-04-15` or `15/04/2025` | Required - Used for scheduling |

## Optional Columns

| Column Name | Description | Example | Notes |
|------------|-------------|---------|-------|
| Schedule Trip ID | Human-readable trip ID | `TRIP-001` | Optional - If not provided, will use document ID |
| Client Phone Number | Client phone number | `+919876543210` | Will be normalized to E.164 format |
| Vehicle ID | Vehicle document ID | `xhEn4S62VCz6wm5b57La` | Optional - Will be looked up if Vehicle Number provided |
| Vehicle Number | Vehicle registration number | `MH34 AB8930` | Optional - Will lookup Vehicle ID |
| Driver ID | Driver/Employee document ID | `driver123` | Optional - Will be looked up if Driver Name provided |
| Driver Name | Driver name | `2039 Lekhram` | Optional - Will lookup Driver ID |
| Driver Phone Number | Driver phone number | `+919423506397` | Will be normalized to E.164 format |
| Dispatch Start | Dispatch start time | `12:00:00` or `2025-04-15T12:00:00Z` | Used to calculate slot number |
| Dispatch End | Dispatch end time | `18:00:00` or `2025-04-15T18:00:00Z` | Optional |
| Pay Schedule | Payment schedule | `POD`, `PL`, `cash` | Maps to paymentType: `POD`→`pay_on_delivery`, `PL`→`pay_later`, else→`cash` |
| To Account | Payment account name | `CASH`, `CREDIT` | Optional - Used for POD payment details |
| City Name | City name | `Chandrapur` | Optional - Part of deliveryZone |
| Region | Region name | `Gadchandur` | Optional - Part of deliveryZone |
| Region ID | Region document ID | `GzwqU5T45gVUKVcINg76` | Optional |
| Product Name | Product name | `BRICKS`, `TUKDA` | Optional - Will lookup Product ID |
| Product Quantity | Product quantity | `4000` or `1` | Optional - Used for items array |
| Product Unit Price | Product unit price | `5.75` or `1500` | Optional - Used for items array |
| DM Number | Delivery memo number | `3442` | Optional - If DM was already generated |
| Status | Trip status | `active`, `cancelled` | Optional - Defaults based on deliveryStatus |
| Delivery Status | Delivery completion status | `true` or `false` | Optional - If true, tripStatus will be `returned` |

## Special Notes

### Date Formats Supported
- Excel date format (serial number)
- ISO format: `2025-04-15` or `2025-04-15T00:00:00Z`
- DD/MM/YYYY: `15/04/2025`
- MM/DD/YYYY: `04/15/2025`
- DD-MM-YYYY: `15-04-2025`

### Time Formats Supported
- 24-hour format: `12:00:00`, `18:00:00`
- 12-hour format: `12:00 PM`, `6:00 PM`
- ISO format: `2025-04-15T12:00:00Z`

### Phone Number Format
Phone numbers will be automatically normalized to E.164 format:
- `9876543210` → `+919876543210`
- `919876543210` → `+919876543210`
- `+919876543210` → `+919876543210` (unchanged)

### Slot Calculation
- Slots are automatically calculated based on **Dispatch Start** times
- Trips are sorted by dispatch time within each date
- Slot numbers are assigned sequentially (1, 2, 3...)
- Slot names are determined by time:
  - 6:00 AM - 12:00 PM → `Morning`
  - 12:00 PM - 5:00 PM → `Afternoon`
  - 5:00 PM - 9:00 PM → `Evening`
  - 9:00 PM - 6:00 AM → `Night`

### Payment Type Mapping
- `POD` → `pay_on_delivery`
- `PL` → `pay_later`
- Other values → `cash`

### Product Lookup
- Product ID will be looked up by Product Name in the target project
- If Product Name is not found, productId will be empty string
- Product lookup is case-insensitive

### Vehicle Lookup
- Vehicle ID will be looked up by Vehicle Number in the target project
- If Vehicle Number is not found, vehicleId will be null
- Vehicle lookup is done in `ORGANIZATIONS/{orgId}/VEHICLES` collection

### Driver Lookup
- Driver ID will be looked up by Driver Name in the target project
- If Driver Name is not found, driverId will be null
- Driver lookup is done in `EMPLOYEES` collection

### Items Array
If **Product Name**, **Product Quantity**, and **Product Unit Price** are provided, an items array will be created:
```json
[{
  "productId": "looked-up-id",
  "productName": "BRICKS",
  "quantity": 4000,
  "unitPrice": 5.75,
  "tripSubtotal": 23000,
  "tripGstAmount": 0,
  "tripTotal": 23000
}]
```

### Trip Status
- If **Delivery Status** = `true`, tripStatus will be set to `returned`
- Otherwise, tripStatus will be based on **Status** field or default to `scheduled`

## Example Excel Row

| Order ID | Client ID | Client Name | Delivery Date | Vehicle Number | Driver Name | Dispatch Start | Pay Schedule | Product Name | Product Quantity | Product Unit Price | Region Name |
|---------|-----------|-------------|--------------|---------------|-------------|----------------|--------------|--------------|-------------------|-------------------|-------------|
| IQ52jkD8AHjNJnDsuzIF | TDeBBWF3dnWGEgyFqKYG | Kaniram Pawar | 2025-04-18 | MH34 AV2039 | 2039 Lekhram | 12:00:00 | POD | BRICKS | 4000 | 5.75 | Gadchandur |

## Migration Command

**Note:** SCHEDULE_TRIPS migration is currently done from the legacy project (SCH_ORDERS collection), not from Excel. However, if you need to create a script for Excel migration, you can use this template.

For legacy project migration:
```bash
cd migrations/firebase
npm run migrate-schedule-trips
```

## Environment Variables

```bash
export LEGACY_SERVICE_ACCOUNT=/path/to/legacy-service-account.json
export NEW_SERVICE_ACCOUNT=/path/to/new-service-account.json
export LEGACY_ORG_ID=K4Q6vPOuTcLPtlcEwdw0
export NEW_ORG_ID=NlQgs9kADbZr4ddBRkhS
```

## Date Range Filter

The migration script filters trips by date range:
- **Start Date:** April 1, 2025
- **End Date:** December 31, 2025
- Only trips with `deliveryStatus = true` are migrated



