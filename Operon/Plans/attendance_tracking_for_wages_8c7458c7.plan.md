---
name: Attendance Tracking for Wages
overview: Add attendance tracking that automatically records employee work participation when wages are processed. This will mark employees as present on work dates based on production batches and trip wages. Includes UI design for Home page on both Android and Web apps.
todos:
  - id: create-attendance-schema
    content: Define TypeScript interfaces for nested ATTENDANCE subcollection in functions/src/shared/types.ts
    status: pending
  - id: create-attendance-functions
    content: Create functions/src/orders/wage-attendance.ts with onWageTransactionCreated and onWageTransactionCancelled handlers
    status: pending
    dependencies:
      - create-attendance-schema
  - id: register-functions
    content: Export new attendance functions in functions/src/index.ts
    status: pending
    dependencies:
      - create-attendance-functions
  - id: add-firestore-indexes
    content: Verify no Firestore indexes needed for nested ATTENDANCE subcollection (document ID queries are auto-indexed)
    status: pending
    dependencies:
      - create-attendance-schema
  - id: test-attendance-creation
    content: Test attendance record creation when production batch wages are processed
    status: pending
    dependencies:
      - register-functions
      - add-firestore-indexes
  - id: test-trip-attendance
    content: Test attendance record creation for trip wages (loading and unloading)
    status: pending
    dependencies:
      - register-functions
      - add-firestore-indexes
  - id: test-cancellation
    content: Test attendance cancellation when wage transactions are reversed
    status: pending
    dependencies:
      - register-functions
  - id: create-attendance-models
    content: Create shared data models (AttendanceSummary, DailyAttendanceEntry, WageProcessingActivity) in packages/core_models
    status: pending
  - id: create-attendance-datasource
    content: Create AttendanceDataSource in packages/core_datasources to query Firestore attendance subcollections
    status: pending
    dependencies:
      - create-attendance-models
  - id: create-attendance-repository
    content: Create AttendanceRepository interface in packages/core_services and implementations for Android/Web
    status: pending
    dependencies:
      - create-attendance-models
      - create-attendance-datasource
  - id: create-android-attendance-ui
    content: Create Android attendance overview view with metric cards and today's attendance list
    status: pending
    dependencies:
      - create-attendance-repository
  - id: create-web-attendance-ui
    content: Create Web attendance overview view with metrics grid and activity feed
    status: pending
    dependencies:
      - create-attendance-repository
  - id: integrate-attendance-home
    content: Integrate attendance overview into Home page navigation for both Android and Web apps
    status: pending
    dependencies:
      - create-android-attendance-ui
      - create-web-attendance-ui
---

# Attendance Tracking Integration with Wages Calculation

## Overview

When wages are processed (transactions created), automatically record attendance for all employees who worked. This creates a work participation record linking employees to specific work dates and wage sources (production batches or trips).

## Data Model

### Nested Attendance Collection

**Collection Path:** `EMPLOYEES/{employeeId}/ATTENDANCE/{monthId}`Where `monthId` is in format `"YYYY-MM"` (e.g., `"2024-01"`)**Month Document Structure:**

```typescript
{
  monthId: string;                        // "YYYY-MM" format (same as document ID)
  organizationId: string;                 // Required: For filtering by organization
  employeeId: string;                     // Employee ID (same as parent document)
  employeeName?: string;                  // Denormalized for display
  
  // Daily attendance array
  dailyAttendance: Array<{
    date: Timestamp;                      // Date when work was performed
    dateString: string;                   // "YYYY-MM-DD" for easy querying
  
  // Work source
  sourceType: 'productionBatch' | 'tripWage';
    sourceId: string;                     // batchId or tripWageId
  
  // Source details (denormalized for easy access)
    batchId?: string;                     // If sourceType === 'productionBatch'
    tripId?: string;                      // If sourceType === 'tripWage'
    tripWageId?: string;                   // If sourceType === 'tripWage'
  
  // Work details
  taskType?: 'production' | 'loading' | 'unloading';  // For trip wages
    wageAmount: number;                    // Wage earned for this work
  
  // Links to transactions
    transactionId: string;                 // Link to TRANSACTIONS collection
  
  // Status
    status: 'recorded' | 'cancelled';     // cancelled if transaction reversed
  
  // Metadata
    createdAt: Timestamp;
    createdBy?: string;                    // User who processed wages
  }>;
  
  // Month metadata
  createdAt: Timestamp;
  updatedAt: Timestamp;
}
```

**Indexes Required:**

- No composite indexes needed for subcollections (Firestore automatically indexes document IDs)
- For querying across employees by date, we'll need to query each employee's attendance subcollection separately

## Integration Points

### 1. Production Batch Wage Processing

**Location:** Wage processing function (to be created in `functions/src/orders/` or similar)When processing production batch wages:

1. For each employee in `batch.employeeIds`:

                                                                                                                                                                                                                                                                                                                                                                                                - Create wage transaction
                                                                                                                                                                                                                                                                                                                                                                                                - Get or create month document: `EMPLOYEES/{employeeId}/ATTENDANCE/{monthId}`
                                                                                                                                                                                                                                                                                                                                                                                                - Add attendance entry to `dailyAttendance` array:
     ```typescript
                    {
                      date: batch.batchDate,
                      dateString: formatDate(batch.batchDate), // "YYYY-MM-DD"
                      sourceType: 'productionBatch',
                      sourceId: batch.batchId,
                      batchId: batch.batchId,
                      taskType: 'production',
                      wageAmount: batch.wagePerEmployee,
                      transactionId: transactionId,
                      status: 'recorded',
                      createdAt: Timestamp.now(),
                      // ... other fields
                    }
     ```




                                                                                                                                                                                                                                                                                                                                                                                                - Use Firestore arrayUnion or transaction to append to array atomically

### 2. Trip Wage Processing

**Location:** Same wage processing functionWhen processing trip wages:

1. For each employee in `tripWage.loadingEmployeeIds`:

                                                                                                                                                                                                                                                                                                                                                                                                - Create loading wage transaction
                                                                                                                                                                                                                                                                                                                                                                                                - Get or create month document: `EMPLOYEES/{employeeId}/ATTENDANCE/{monthId}`
                                                                                                                                                                                                                                                                                                                                                                                                - Add attendance entry to `dailyAttendance` array with `taskType: 'loading'`

2. For each employee in `tripWage.unloadingEmployeeIds`:

                                                                                                                                                                                                                                                                                                                                                                                                - Create unloading wage transaction
                                                                                                                                                                                                                                                                                                                                                                                                - Get or create month document: `EMPLOYEES/{employeeId}/ATTENDANCE/{monthId}`
                                                                                                                                                                                                                                                                                                                                                                                                - Add attendance entry to `dailyAttendance` array with `taskType: 'unloading'`

Note: Same employee can have two entries in the same day's attendance if they did both loading and unloading

### 3. Transaction Cancellation Handling

**Location:** `functions/src/transactions/transaction-handlers.ts`When a wage transaction is cancelled:

- Find the month document and locate the attendance entry by `transactionId` in `dailyAttendance` array
- Update the entry's `status` to `'cancelled'` in the array
- Use Firestore transaction to update the specific array element atomically
- This prevents double-counting attendance

## Workflow Updates

### Updated Production Wages Workflow

**Step 4: Process Wages** (enhanced)

- System creates individual credit transactions for each employee
- **NEW:** For each transaction, create attendance record
- Each transaction links to batch via metadata
- Batch status → `processed`
- Updates employee ledgers automatically

### Updated Loading/Unloading Wages Workflow

**Step 4: Process Wages** (enhanced)

- System creates credit transactions for each employee
- **NEW:** For each transaction, create attendance record with appropriate `taskType`
- Separate transactions for loading vs unloading
- Updates employee ledgers

## Cloud Functions

### New Function: `onWageTransactionCreated`

**Location:** `functions/src/orders/wage-attendance.ts` (new file)**Trigger:** `TRANSACTIONS` document created with `category === 'wageCredit'`**Logic:**

```typescript
export const onWageTransactionCreated = onDocumentCreated(
  `${TRANSACTIONS_COLLECTION}/{transactionId}`,
  async (event) => {
    const transaction = event.data?.data();
    
    // Only process wage credits
    if (transaction?.category !== 'wageCredit' || 
        transaction?.ledgerType !== 'employeeLedger') {
      return;
    }
    
    const employeeId = transaction.employeeId;
    const metadata = transaction.metadata || {};
    const sourceType = metadata.sourceType; // 'productionBatch' | 'tripWage'
    
    // Get work date from metadata or transaction
    const workDate = getWorkDateFromTransaction(transaction, metadata);
    const monthId = formatMonthId(workDate); // "YYYY-MM"
    
    if (sourceType === 'productionBatch') {
      await addProductionBatchAttendance(employeeId, monthId, transaction, metadata, workDate);
    } else if (sourceType === 'tripWage') {
      await addTripWageAttendance(employeeId, monthId, transaction, metadata, workDate);
    }
  }
);

async function addProductionBatchAttendance(
  employeeId: string,
  monthId: string,
  transaction: any,
  metadata: any,
  workDate: Date
) {
  const attendanceRef = db
    .collection('EMPLOYEES')
    .doc(employeeId)
    .collection('ATTENDANCE')
    .doc(monthId);
  
  const attendanceEntry = {
    date: admin.firestore.Timestamp.fromDate(workDate),
    dateString: formatDateString(workDate), // "YYYY-MM-DD"
    sourceType: 'productionBatch',
    sourceId: metadata.batchId,
    batchId: metadata.batchId,
    taskType: 'production',
    wageAmount: transaction.amount,
    transactionId: transaction.transactionId,
    status: 'recorded',
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    createdBy: transaction.createdBy,
  };
  
  await db.runTransaction(async (tx) => {
    const monthDoc = await tx.get(attendanceRef);
    
    if (!monthDoc.exists) {
      // Create new month document
      tx.set(attendanceRef, {
        monthId,
        organizationId: transaction.organizationId,
        employeeId,
        employeeName: transaction.employeeName, // if available
        dailyAttendance: [attendanceEntry],
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    } else {
      // Append to existing array
      const data = monthDoc.data()!;
      const dailyAttendance = (data.dailyAttendance as any[]) || [];
      
      // Check if entry already exists (prevent duplicates)
      const exists = dailyAttendance.some(
        (entry) => entry.transactionId === transaction.transactionId
      );
      
      if (!exists) {
        dailyAttendance.push(attendanceEntry);
        tx.update(attendanceRef, {
          dailyAttendance,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
      }
    }
  });
}
```



### New Function: `onWageTransactionCancelled`

**Location:** Same file**Trigger:** `TRANSACTIONS` document updated (check if cancelled/deleted) or deleted**Logic:**

- Extract `employeeId` and work date from transaction
- Determine `monthId` from work date
- Find month document: `EMPLOYEES/{employeeId}/ATTENDANCE/{monthId}`
- Locate entry in `dailyAttendance` array by `transactionId`
- Update entry's `status` to `'cancelled'` using array update

## Query Patterns

### Get Employee Attendance for a Month

```typescript
const monthId = '2024-01';
const attendanceRef = db
  .collection('EMPLOYEES')
  .doc(employeeId)
  .collection('ATTENDANCE')
  .doc(monthId);

const monthDoc = await attendanceRef.get();
if (monthDoc.exists) {
  const dailyAttendance = monthDoc.data()?.dailyAttendance || [];
  // Filter by status, date range, etc. in application code
  const recorded = dailyAttendance.filter(
    (entry) => entry.status === 'recorded'
  );
}
```



### Get Employee Attendance for Date Range

```typescript
// Get all month documents in range
const startMonth = '2024-01';
const endMonth = '2024-03';

// Query each month in range
const months = ['2024-01', '2024-02', '2024-03'];
const attendanceRefs = months.map(monthId => 
  db.collection('EMPLOYEES')
    .doc(employeeId)
    .collection('ATTENDANCE')
    .doc(monthId)
);

const monthDocs = await Promise.all(
  attendanceRefs.map(ref => ref.get())
);

// Combine and filter dailyAttendance arrays
const allAttendance = monthDocs
  .filter(doc => doc.exists)
  .flatMap(doc => doc.data()?.dailyAttendance || [])
  .filter(entry => {
    const entryDate = entry.date.toDate();
    return entryDate >= startDate && 
           entryDate <= endDate && 
           entry.status === 'recorded';
  });
```



### Get All Attendance for a Specific Date

```typescript
// Query all employees' attendance for a specific date
// Note: This requires querying each employee's attendance subcollection
// For better performance, consider a separate index collection if needed

const targetDate = '2024-01-15';
const employees = await db.collection('EMPLOYEES')
  .where('organizationId', '==', orgId)
  .get();

const monthId = '2024-01'; // Extract from targetDate

const attendancePromises = employees.docs.map(async (empDoc) => {
  const attendanceRef = empDoc.ref
    .collection('ATTENDANCE')
    .doc(monthId);
  const monthDoc = await attendanceRef.get();
  
  if (monthDoc.exists) {
    const dailyAttendance = monthDoc.data()?.dailyAttendance || [];
    return dailyAttendance.filter(
      entry => entry.dateString === targetDate && entry.status === 'recorded'
    );
  }
  return [];
});

const allAttendanceForDate = (await Promise.all(attendancePromises)).flat();
```



### Get Attendance by Source (Production Batch)

```typescript
// To find all employees who worked on a specific batch:
// Query is more complex - need to check each employee's attendance
// Alternative: Store batchId in batch document and query from there

const batchId = 'batch123';
// Implementation depends on whether we need to query from batch or employee side
```



## Database Schema Updates

### Modified Collections

1. **TRANSACTIONS**

                                                                                                                                                                                                                                                                                                                                                                                                - No schema changes needed
                                                                                                                                                                                                                                                                                                                                                                                                - Metadata already includes `sourceType`, `sourceId`, etc.

2. **PRODUCTION_BATCHES**

                                                                                                                                                                                                                                                                                                                                                                                                - No schema changes needed
                                                                                                                                                                                                                                                                                                                                                                                                - Attendance records reference batch via `batchId`

3. **TRIP_WAGES**

                                                                                                                                                                                                                                                                                                                                                                                                - No schema changes needed
                                                                                                                                                                                                                                                                                                                                                                                                - Attendance records reference trip via `tripId` and `tripWageId`

### New Collection

1. **EMPLOYEE_ATTENDANCE**

                                                                                                                                                                                                                                                                                                                                                                                                - See schema above
                                                                                                                                                                                                                                                                                                                                                                                                - Indexed for common query patterns

## Implementation Steps

1. **Create Attendance Schema**

                                                                                                                                                                                                                                                                                                                                                                                                - Define TypeScript interfaces in `functions/src/shared/types.ts`
                                                                                                                                                                                                                                                                                                                                                                                                - Define `EmployeeAttendanceMonth` and `DailyAttendanceEntry` types
                                                                                                                                                                                                                                                                                                                                                                                                - No Firestore indexes needed (subcollection structure)

2. **Create Cloud Functions**

                                                                                                                                                                                                                                                                                                                                                                                                - `functions/src/orders/wage-attendance.ts`
                                                                                                                                                                                                                                                                                                                                                                                                - Implement `onWageTransactionCreated`
                                                                                                                                                                                                                                                                                                                                                                                                - Implement `onWageTransactionCancelled`
                                                                                                                                                                                                                                                                                                                                                                                                - Export functions in `functions/src/index.ts`

3. **Update Wage Processing Logic**

                                                                                                                                                                                                                                                                                                                                                                                                - Ensure wage processing creates transactions with proper metadata
                                                                                                                                                                                                                                                                                                                                                                                                - Cloud function will automatically create attendance records

4. **Firestore Indexes**

                                                                                                                                                                                                                                                                                                                                                                                                - No composite indexes needed for subcollections
                                                                                                                                                                                                                                                                                                                                                                                                - Document ID queries are automatically indexed

5. **Testing**

                                                                                                                                                                                                                                                                                                                                                                                                - Test attendance creation for production batches
                                                                                                                                                                                                                                                                                                                                                                                                - Test attendance creation for trip wages (loading/unloading)
                                                                                                                                                                                                                                                                                                                                                                                                - Test attendance cancellation when transactions are reversed
                                                                                                                                                                                                                                                                                                                                                                                                - Test query patterns

## UI Considerations (Future)

While not in scope for this plan, future UI enhancements could include:

- Attendance calendar view showing present/absent employees
- Monthly attendance reports
- Attendance summary by employee
- Integration with wage processing UI to show attendance status

## Edge Cases

1. **Same Employee, Multiple Tasks Same Day**

                                                                                                                                                                                                                                                                                                                                                                                                - If employee does both loading and unloading, create two entries in `dailyAttendance` array
                                                                                                                                                                                                                                                                                                                                                                                                - Both entries link to same `date` and `dateString` but have separate `transactionId`s
                                                                                                                                                                                                                                                                                                                                                                                                - Both entries stored in the same month document

2. **Transaction Cancellation**

                                                                                                                                                                                                                                                                                                                                                                                                - Mark attendance entry's `status` as `'cancelled'` in the array rather than deleting
                                                                                                                                                                                                                                                                                                                                                                                                - Allows audit trail while preventing double-counting

3. **Duplicate Processing Prevention**

                                                                                                                                                                                                                                                                                                                                                                                                - Check if attendance entry already exists for `transactionId` in `dailyAttendance` array before adding
                                                                                                                                                                                                                                                                                                                                                                                                - Use Firestore transactions to ensure atomic updates
                                                                                                                                                                                                                                                                                                                                                                                                - Transaction ID serves as unique constraint within the array

4. **Date Handling**

                                                                                                                                                                                                                                                                                                                                                                                                - Use `dateString` ("YYYY-MM-DD") for filtering within arrays
                                                                                                                                                                                                                                                                                                                                                                                                - Store both `date` (Timestamp) and `dateString` (string) for flexibility
                                                                                                                                                                                                                                                                                                                                                                                                - `monthId` ("YYYY-MM") determines which month document to use

5. **Array Size Considerations**

                                                                                                                                                                                                                                                                                                                                                                                                - Each month document contains an array of daily attendance entries
                                                                                                                                                                                                                                                                                                                                                                                                - Firestore document size limit is 1MB
                                                                                                                                                                                                                                                                                                                                                                                                - For months with many work days, consider splitting if array grows too large
                                                                                                                                                                                                                                                                                                                                                                                                - Typical month: ~30 days × ~2 entries/day (loading/unloading) = ~60 entries (well within limits)

---

## UI Design: Home Page Attendance Dashboard

### Overview

Add attendance tracking widgets to the Home page for both Android and Web apps. The attendance section should display:

- Today's attendance summary
- This week's attendance statistics
- This month's attendance overview
- Recent wage processing activities
- Quick access to attendance details

### Android App Design

**Location:** `apps/Operon_Client_android/lib/presentation/views/home_sections/attendance_overview_view.dart`**Design Pattern:** Follow existing `HomeOverviewView` structure with metric cards and grid layout**Components:**

1. **Attendance Summary Cards** (Top Section)
   ```dart
                                                                                                                                                                                                                                                            - Today's Present Count Card
                                                                                                                                                                                                                                                                                                                            * Icon: Icons.check_circle_outline
                                                                                                                                                                                                                                                                                                                            * Value: Number of employees present today
                                                                                                                                                                                                                                                                                                                            * Color: Green (#4CAF50)
                                                                                                                                                                                                                                                                                                                            * Subtitle: "Employees working today"
            
                                                                                                                                                                                                                                                            - This Week's Total Card
                                                                                                                                                                                                                                                                                                                            * Icon: Icons.calendar_today_outlined
                                                                                                                                                                                                                                                                                                                            * Value: Total work days this week
                                                                                                                                                                                                                                                                                                                            * Color: Blue (#2196F3)
                                                                                                                                                                                                                                                                                                                            * Subtitle: "Work days this week"
            
                                                                                                                                                                                                                                                            - This Month's Attendance Card
                                                                                                                                                                                                                                                                                                                            * Icon: Icons.event_note_outlined
                                                                                                                                                                                                                                                                                                                            * Value: Total attendance entries this month
                                                                                                                                                                                                                                                                                                                            * Color: Orange (#FF9800)
                                                                                                                                                                                                                                                                                                                            * Subtitle: "Attendance records"
   ```




2. **Today's Attendance List** (Middle Section)

                                                                                                                                                                                                                                                                                                                                                                                                - Scrollable list of employees who worked today
                                                                                                                                                                                                                                                                                                                                                                                                - Each item shows:
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                - Employee name
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                - Work type (Production / Loading / Unloading)
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                - Wage amount earned
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                - Time/date of work
                                                                                                                                                                                                                                                                                                                                                                                                - Tap to view full attendance details

3. **Recent Wage Processing** (Bottom Section)

                                                                                                                                                                                                                                                                                                                                                                                                - List of recent wage transactions that created attendance records
                                                                                                                                                                                                                                                                                                                                                                                                - Shows: Batch/Trip ID, Date, Number of employees, Total wages

**Layout Structure:**

```dart
Column(
  children: [
    // Summary Cards Row
    Row(
      children: [
        Expanded(child: _AttendanceMetricCard(...)),
        SizedBox(width: 16),
        Expanded(child: _AttendanceMetricCard(...)),
        SizedBox(width: 16),
        Expanded(child: _AttendanceMetricCard(...)),
      ],
    ),
    SizedBox(height: 24),
    // Today's Attendance Section
    _TodaysAttendanceSection(),
    SizedBox(height: 24),
    // Recent Wage Processing Section
    _RecentWageProcessingSection(),
  ],
)
```

**Styling:**

- Use existing dark theme colors (#13131E background)
- Glassmorphism cards with gradient borders
- Animated entrance effects (similar to existing tiles)
- Category-based color coding (green for present, blue for stats, orange for wages)

### Web App Design

**Location:** `apps/Operon_Client_web/lib/presentation/views/home_sections/attendance_overview_view.dart`**Design Pattern:** Follow existing `_HomeOverviewView` structure with section groups and responsive layout**Components:**

1. **Attendance Dashboard Section** (Left Side - 2/3 width)

                                                                                                                                                                                                                                                                                                                                                                                                - **Header:** "Attendance & Wages" with icon
                                                                                                                                                                                                                                                                                                                                                                                                - **Metric Cards Grid** (3 columns):
     ```dart
                                                                                                                                                                                                                                                                                                                                                                                                                                    - Today's Present Employees
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                    * Large number display
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                    * Trend indicator (vs yesterday)
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                    * Color: Green gradient
                    
                                                                                                                                                                                                                                                                                                                                                                                                                                    - This Week's Work Days
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                    * Total work days
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                    * Average per day
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                    * Color: Blue gradient
                    
                                                                                                                                                                                                                                                                                                                                                                                                                                    - This Month's Total Wages
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                    * Total wages processed
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                    * Number of transactions
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                    * Color: Orange gradient
     ```




2. **Today's Activity Feed** (Right Side - 1/3 width)

                                                                                                                                                                                                                                                                                                                                                                                                - Real-time list of today's attendance entries
                                                                                                                                                                                                                                                                                                                                                                                                - Each entry shows:
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                - Employee name with avatar
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                - Work type badge
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                - Wage amount
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                - Time stamp
                                                                                                                                                                                                                                                                                                                                                                                                - Auto-refreshes when new wages processed

3. **Quick Actions Panel** (Below metrics)

                                                                                                                                                                                                                                                                                                                                                                                                - "View Full Attendance" button → Navigate to attendance calendar
                                                                                                                                                                                                                                                                                                                                                                                                - "Process Wages" button → Navigate to wage processing page
                                                                                                                                                                                                                                                                                                                                                                                                - "Monthly Report" button → Generate attendance report

**Layout Structure:**

```dart
Row(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [
    // Left: Dashboard (2/3)
    Expanded(
      flex: 2,
      child: Column(
        children: [
          _AttendanceMetricsGrid(),
          SizedBox(height: 32),
          _QuickActionsPanel(),
        ],
      ),
    ),
    SizedBox(width: 24),
    // Right: Activity Feed (1/3)
    Expanded(
      flex: 1,
      child: _TodaysActivityFeed(),
    ),
  ],
)
```

**Styling:**

- Match existing web app design language
- Use `DashCard` components from `core_ui` package
- Hover effects on interactive elements
- Responsive breakpoints for mobile/tablet/desktop

### Data Fetching

**Repository Pattern:**

- Create `AttendanceRepository` in `packages/core_services/lib/attendance/`
- Methods:
  ```dart
        Future<AttendanceSummary> getTodaySummary(String organizationId);
        Future<AttendanceSummary> getWeekSummary(String organizationId, DateTime weekStart);
        Future<AttendanceSummary> getMonthSummary(String organizationId, String monthId);
        Future<List<DailyAttendanceEntry>> getTodaysAttendance(String organizationId);
        Future<List<WageProcessingActivity>> getRecentWageProcessing(String organizationId, {int limit = 10});
  ```


**Data Models:**

```dart
class AttendanceSummary {
  final int presentCount;
  final int totalWorkDays;
  final double totalWages;
  final int totalTransactions;
  final DateTime date;
}

class DailyAttendanceEntry {
  final String employeeId;
  final String employeeName;
  final DateTime workDate;
  final String sourceType; // 'productionBatch' | 'tripWage'
  final String? taskType; // 'production' | 'loading' | 'unloading'
  final double wageAmount;
  final String transactionId;
}

class WageProcessingActivity {
  final String sourceId;
  final String sourceType;
  final DateTime processedAt;
  final int employeeCount;
  final double totalWages;
  final String processedBy;
}
```



### Implementation Files

**Android:**

1. `apps/Operon_Client_android/lib/presentation/views/home_sections/attendance_overview_view.dart`
2. `apps/Operon_Client_android/lib/presentation/widgets/attendance_metric_card.dart`
3. `apps/Operon_Client_android/lib/presentation/widgets/todays_attendance_list.dart`
4. `apps/Operon_Client_android/lib/data/repositories/attendance_repository_impl.dart`
5. `apps/Operon_Client_android/lib/presentation/blocs/attendance/attendance_cubit.dart`

**Web:**

1. `apps/Operon_Client_web/lib/presentation/views/home_sections/attendance_overview_view.dart`
2. `apps/Operon_Client_web/lib/presentation/widgets/attendance_metrics_grid.dart`
3. `apps/Operon_Client_web/lib/presentation/widgets/todays_activity_feed.dart`
4. `apps/Operon_Client_web/lib/data/repositories/attendance_repository_impl.dart`
5. `apps/Operon_Client_web/lib/presentation/blocs/attendance/attendance_cubit.dart`

**Shared:**

1. `packages/core_services/lib/attendance/attendance_repository.dart`
2. `packages/core_models/lib/attendance/attendance_summary.dart`
3. `packages/core_models/lib/attendance/daily_attendance_entry.dart`
4. `packages/core_datasources/lib/attendance/attendance_data_source.dart`

### Integration with Existing Home Page

**Android:**

- Add attendance section as a new tab in `HomePage._sections` array
- Add to navigation in `HomeWorkspaceLayout`
- Update `computeHomeSections()` to include attendance section based on role permissions

**Web:**

- Add attendance section as a new tab in `HomePage._sections` array
- Add to navigation in `SectionWorkspaceLayout`
- Update `computeHomeSections()` to include attendance section

### Permissions

- Users with access to employee wages should see attendance overview
- Check: `role?.canAccessPage('employees') == true` or wage-related permissions
- Admin users see full attendance dashboard
- Regular users see only their own attendance (if applicable)

### Real-time Updates

- Use Firestore streams to listen for new attendance records
- Update UI automatically when wages are processed
- Show loading states while fetching data
- Handle offline scenarios gracefully

### Future Enhancements

- Attendance calendar view (monthly grid showing present/absent)
- Attendance reports (PDF export)