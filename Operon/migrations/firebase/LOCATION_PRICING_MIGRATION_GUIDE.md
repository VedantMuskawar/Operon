# Location Pricing Migration Guide

## Overview

This script migrates location/zone pricing data from Excel to the Operon Firebase project. It creates or updates delivery zones and sets product prices for each zone.

## Excel Format

### Required Columns

| Column Name | Description | Example | Notes |
|------------|-------------|---------|-------|
| **City Name** | City name | `Mumbai` | Required - Creates/uses city in DELIVERY_CITIES |
| **Region** | Region/Area name | `Andheri East` | Required - Part of zone identifier |
| **Product ID** or **Product Name** | Product identifier | `1765277893839` or `BRICKS` | Required - At least one must be provided |
| **Unit Price** | Price per unit | `5.75` | Required - Must be > 0 |

### Optional Columns

| Column Name | Description | Example | Notes |
|------------|-------------|---------|-------|
| **Deliverable** | Can deliver this product | `true` or `false` | Optional - Defaults to `true` |
| **Round Trip Distance** | Round trip distance in kilometers | `25.5` | Optional - Distance for fuel calculations |

### Alternative Column Names

The script accepts multiple column name variations:
- **City Name**: `City Name`, `City`, `cityName`, `city`
- **Region**: `Region`, `region`, `Region Name`, `regionName`
- **Product ID**: `Product ID`, `productId`, `Product ID`
- **Product Name**: `Product Name`, `productName`, `Product`, `product`
- **Unit Price**: `Unit Price`, `unitPrice`, `Price`, `price`
- **Deliverable**: `Deliverable`, `deliverable`, `Can Deliver`, `canDeliver`
- **Round Trip Distance**: `Round Trip Distance`, `Round Trip KM`, `roundTripDistance`, `roundTripKm`, `roundtrip_km`, `Roundtrip KM`

## Example Excel Structure

| City Name | Region | Product ID | Product Name | Unit Price | Deliverable | Round Trip Distance |
|-----------|--------|------------|--------------|------------|-------------|---------------------|
| Mumbai | Andheri East | 1765277893839 | BRICKS | 5.75 | true | 25.5 |
| Mumbai | Andheri East | | TUKDA | 1500 | true | 25.5 |
| Chandrapur | Gadchandur | 1765277893839 | BRICKS | 5.50 | true | 30.0 |

## How It Works

1. **Reads Excel file** - Parses all rows
2. **Step 1: Migrate Cities** - Extracts unique city names and creates/updates `DELIVERY_CITIES` collection first
3. **Step 2: Resolves Product IDs** - If Product Name is provided, looks up Product ID from PRODUCTS collection
4. **Step 3: Creates/Updates Zones** - Creates zone documents in `ORGANIZATIONS/{orgId}/DELIVERY_ZONES` if they don't exist, including Round Trip Distance
5. **Step 4: Sets Prices** - Updates prices for each product in each zone

## Price Storage Options

The script supports two storage formats:

### Option 1: Flattened Prices (Recommended - Default)

Prices are stored as a map in the zone document:
```typescript
{
  organization_id: string,
  city_id: string,
  city_name: string,
  region: string,
  is_active: boolean,
  prices: {
    [productId]: {
      unit_price: number,
      deliverable: boolean,
      updated_at: Timestamp
    }
  }
}
```

**Benefits:**
- Single query to get zone + all prices
- Simpler data structure
- Better performance

### Option 2: Subcollection Structure

Prices are stored in a subcollection:
```
ORGANIZATIONS/{orgId}/DELIVERY_ZONES/{zoneId}/PRICES/{productId}
```

**Use this if:**
- You have many products per zone (to avoid document size limits)
- You need to query prices separately

## Running the Migration

### Basic Run

```bash
cd migrations/firebase
npm install
npm run migrate-location-pricing
```

### With Environment Variables

```bash
cd migrations/firebase
export EXCEL_FILE_PATH=/path/to/your/location-pricing.xlsx
export EXCEL_SHEET_NAME=Sheet1  # Optional: specify sheet name
export TARGET_ORG_ID=NlQgs9kADbZr4ddBRkhS
export USE_FLATTENED_PRICES=true  # true = flattened (default), false = subcollection
export OVERWRITE_EXISTING=false  # Set to true to overwrite existing prices
export SKIP_INVALID_ROWS=true   # Set to false to stop on invalid rows
npm run migrate-location-pricing
```

## Expected Output

```
=== Migrating Location Pricing from Excel ===
Excel file: /path/to/location-pricing.xlsx
Sheet: First sheet
Target Org ID: NlQgs9kADbZr4ddBRkhS
Use Flattened Prices: true
Overwrite existing: false
Skip invalid rows: true

Reading Excel file...
Found 150 rows in Excel file

Processing rows and resolving product IDs...
Processed 145 valid rows
Found 25 unique zones
Total price updates: 145

Updating zones with prices...
Updated 25/25 zones...

=== Migration Complete ===
Total rows processed: 145
Zones updated: 25
Prices updated: 145
Skipped 5 invalid rows
```

## Troubleshooting

### Error: Product not found

- Ensure Product Name matches exactly (case-sensitive) with product names in PRODUCTS collection
- Or provide Product ID directly in Excel
- Check that products exist in `ORGANIZATIONS/{orgId}/PRODUCTS`

### Error: Excel file not found

- Ensure Excel file is at `data/location-pricing.xlsx`
- Or set `EXCEL_FILE_PATH` environment variable with full path

### Warning: Skipping price update (already exists)

- Set `OVERWRITE_EXISTING=true` to overwrite existing prices
- Or manually delete existing prices before migration

### Zone not created

- Check that City Name and Region columns are filled
- Verify service account has write permissions

## Data Structure Created

### City Document
```
ORGANIZATIONS/{orgId}/DELIVERY_CITIES/{cityId}
{
  name: "Mumbai",
  created_at: Timestamp,
  updated_at: Timestamp
}
```

### Zone Document (Flattened Prices)
```
ORGANIZATIONS/{orgId}/DELIVERY_ZONES/{zoneId}
{
  organization_id: "NlQgs9kADbZr4ddBRkhS",
  city_id: "city123",
  city_name: "Mumbai",
  region: "Andheri East",
  is_active: true,
  roundtrip_km: 25.5,  // Round trip distance in kilometers
  roundtripKm: 25.5,   // Alternative field name (both supported)
  prices: {
    "1765277893839": {
      unit_price: 5.75,
      deliverable: true,
      updated_at: Timestamp
    },
    "prod456": {
      unit_price: 1500,
      deliverable: true,
      updated_at: Timestamp
    }
  },
  created_at: Timestamp,
  updated_at: Timestamp
}
```

### Price Document (Subcollection - if USE_FLATTENED_PRICES=false)
```
ORGANIZATIONS/{orgId}/DELIVERY_ZONES/{zoneId}/PRICES/{productId}
{
  product_id: "1765277893839",
  product_name: "BRICKS",
  unit_price: 5.75,
  deliverable: true,
  updated_at: Timestamp
}
```

## Notes

- **Duplicate Zones**: If a zone with the same city_name and region already exists, it will be reused
- **Product Lookup**: Product names are matched case-insensitively if Product ID is not provided
- **Price Updates**: By default, existing prices are not overwritten (set `OVERWRITE_EXISTING=true` to overwrite)
- **Invalid Rows**: Rows with missing required fields are skipped if `SKIP_INVALID_ROWS=true`

