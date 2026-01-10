# DELIVERY_MEMOS Excel Migration Template

## Required Columns

The following columns are **REQUIRED** for DELIVERY_MEMOS migration:

| Column Name | Description | Example | Notes |
|------------|-------------|---------|-------|
| **DATE** | Scheduled delivery date | `2025-04-15` or `15/04/2025` | Required - Used to determine financial year |
| **CLIENT** | Client name | `ABC Corporation` | Required - If contains "CANCAL D M", DM will be marked as cancelled |

## Optional Columns

| Column Name | Description | Example | Notes |
|------------|-------------|---------|-------|
| DM_NO | DM Number (if you want to specify) | `3442` | If not provided, will auto-generate |
| Trip ID | Link to trip document | `abc123` | Optional |
| Schedule Trip ID | Link to schedule trip | `xyz789` | Optional |
| Order ID | Link to order document | `order123` | Optional |
| Client ID | Client document ID | `client456` | Optional |
| Customer Number | Client phone number | `+919876543210` | Will be normalized to E.164 format |
| Vehicle ID | Vehicle document ID | `vehicle789` | Optional |
| Vehicle Number | Vehicle registration number | `MH34 AB8930` | Optional |
| VehicleNO | Alternative column name for vehicle number | `MH34 AB8930` | Alternative to "Vehicle Number" |
| Slot | Slot number (1, 2, 3...) | `1` | Optional - defaults to 0 |
| Slot Name | Slot name (Morning, Afternoon, Evening, Night) | `Morning` | Optional |
| Driver ID | Driver/Employee document ID | `driver123` | Optional |
| Driver Name | Driver name | `John Doe` | Optional |
| Driver Phone | Driver phone number | `+919876543210` | Will be normalized to E.164 format |
| Zone ID | Delivery zone ID | `zone123` | Optional |
| City | City name | `Mumbai` | Optional |
| Region | Region name | `Maharashtra` | Optional |
| Product | Product name | `BRICKS` or `TUKDA` | If contains "BRICKS", will map to productId `1765277893839` |
| Quantity | Product quantity per trip | `4000` | Required if Product is provided |
| Unit | Unit price | `5.75` | Required if Product is provided. If Unit = "1", DM will be marked as cancelled |
| Priority | Priority level | `normal` or `high` | Optional - defaults to `normal` |
| Payment Type | Payment type | `cash`, `pay_on_delivery`, `pay_later` | Optional |
| Trip Status | Trip status | `scheduled`, `returned`, `cancelled` | Optional - defaults based on status |
| Order Status | Order status | `pending`, `delivered`, `cancelled` | Optional - defaults to `pending` |
| Status | DM status | `active`, `cancelled` | Optional - defaults to `active` |

## Special Notes

### Cancelled DMs
A DM will be marked as cancelled if:
1. **CLIENT** column contains "CANCAL D M" (case-insensitive), OR
2. **Unit** column equals "1"

### Date Formats Supported
- Excel date format (serial number)
- ISO format: `2025-04-15` or `2025-04-15T00:00:00Z`
- DD/MM/YYYY: `15/04/2025`
- MM/DD/YYYY: `04/15/2025`
- DD-MM-YYYY: `15-04-2025`

### Phone Number Format
Phone numbers will be automatically normalized to E.164 format:
- `9876543210` → `+919876543210`
- `919876543210` → `+919876543210`
- `+919876543210` → `+919876543210` (unchanged)

### Product Mapping
- If **Product** contains "BRICKS" (case-insensitive), it will be mapped to:
  - `productName`: "Bricks"
  - `productId`: "1765277893839"

### Financial Year Calculation
Financial year is automatically calculated from the **DATE** column:
- FY starts in April (month 4)
- Example: Date `2025-04-15` → Financial Year `FY2425`

### DM Number Generation
- If **DM_NO** is provided, it will be used as-is
- If not provided, DM number will be auto-generated sequentially within the financial year
- DM numbers are unique per financial year

## Example Excel Row

| DATE | CLIENT | DM_NO | Vehicle Number | Product | Quantity | Unit | Customer Number | Driver Name | City | Region |
|------|--------|-------|----------------|---------|----------|------|-----------------|-------------|------|--------|
| 2025-04-15 | ABC Corporation | 3442 | MH34 AB8930 | BRICKS | 4000 | 5.75 | +919876543210 | John Doe | Mumbai | Maharashtra |

## Migration Command

```bash
cd migrations/firebase
npm run migrate-delivery-memos
```

## Environment Variables

```bash
export EXCEL_FILE_PATH=/path/to/your/delivery-memos.xlsx
export EXCEL_SHEET_NAME=Sheet1  # Optional: specify sheet name
export TARGET_ORG_ID=NlQgs9kADbZr4ddBRkhS
export OVERWRITE_EXISTING=false  # Set to true to overwrite existing DMs
export SKIP_INVALID_ROWS=true   # Set to false to stop on invalid rows
```



