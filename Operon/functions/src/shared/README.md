# Shared Modules

This directory contains shared utilities and services used across Cloud Functions.

## Modules

### `whatsapp-service.ts`
Centralized WhatsApp service for loading settings and sending messages.
- `loadWhatsappSettings()` - Loads organization-specific or global WhatsApp settings
- `sendWhatsappMessage()` - Sends WhatsApp messages via Meta Graph API

### `function-config.ts`
Standardized Cloud Function configuration presets.
- `LIGHT_TRIGGER_CONFIG` - For simple Firestore triggers
- `STANDARD_TRIGGER_CONFIG` - For most Firestore triggers
- `HEAVY_PROCESSING_CONFIG` - For complex operations
- `CALLABLE_FUNCTION_CONFIG` - For HTTP callable functions
- `SCHEDULED_FUNCTION_CONFIG` - For scheduled PubSub functions

### `date-helpers.ts`
Date and time utility functions.
- `getISOWeek()` - Get ISO week number
- `formatDate()` - Format date as YYYY-MM-DD
- `formatMonth()` - Format date as YYYY-MM
- `cleanDailyData()` - Clean up daily data older than specified days
- `getYearMonth()` - Get year-month string in YYYY-MM format
- `getYearMonthCompact()` - Get year-month string in YYYYMM format (for document IDs)
- `normalizeDate()` - Normalize date to start of day in UTC

### `transaction-helpers.ts`
Transaction-related utility functions.
- `removeUndefinedFields()` - Remove undefined values from objects recursively
- `getTransactionDate()` - Extract transaction date from Firestore snapshot
- `validateTransaction()` - Validate transaction has required fields

### `logger.ts`
Standardized logging helper.
- `logInfo()` - Log info messages with consistent format
- `logWarning()` - Log warning messages with consistent format
- `logError()` - Log error messages with consistent format

Format: `[Module/Function] Message` with context

### `financial-year.ts`
Financial year calculations.
- `getFinancialContext()` - Get financial year context for a date

### `firestore-helpers.ts`
Firestore utility functions.
- `getCreationDate()` - Get creation date from Firestore snapshot
- `seedAnalyticsDoc()` - Initialize analytics document
- `getFirestore()` - Get Firestore database instance
