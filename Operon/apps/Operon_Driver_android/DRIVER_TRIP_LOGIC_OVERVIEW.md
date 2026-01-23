# Driver App - Trip Logic Process Overview (UI Side)

## Table of Contents
1. [App Structure](#app-structure)
2. [Trip Lifecycle States](#trip-lifecycle-states)
3. [UI Screens & Navigation](#ui-screens--navigation)
4. [Trip Flow by Status](#trip-flow-by-status)
5. [Key Components](#key-components)
6. [Data Flow](#data-flow)
7. [Location Tracking Integration](#location-tracking-integration)

---

## App Structure

### Main Entry Point
- **File**: `lib/presentation/app.dart`
- **Widget**: `OperonDriverApp`
- **Key Providers**:
  - `ScheduledTripsRepository` - Trip data access
  - `LocationService` - GPS tracking
  - `TripBloc` - Trip state management
  - `BackgroundSyncService` - Background location sync

### Navigation Structure
- **File**: `lib/presentation/views/driver_home_page.dart`
- **Bottom Navigation**: 3 tabs
  1. **Home Tab** - Minimal placeholder
  2. **Schedule Tab** - List of scheduled trips (`DriverScheduleTripsPage`)
  3. **Map Tab** - Active trip tracking (`DriverHomeScreen`)

---

## Trip Lifecycle States

### Status Flow
```
scheduled → dispatched → delivered → returned
```

### Status Definitions

1. **`scheduled`** / **`pending`**
   - Trip is created and assigned to driver
   - Driver can see it in Schedule tab
   - Ready to be dispatched

2. **`dispatched`**
   - Driver has started the trip
   - Initial odometer reading captured
   - Location tracking active
   - HUD overlay visible
   - Path visualization active (orange line)

3. **`delivered`**
   - Driver marked delivery complete
   - Delivery photo uploaded
   - Delivery odometer reading captured
   - Path shows: orange (to delivery) + blue (after delivery)

4. **`returned`**
   - Driver marked return complete
   - Final odometer reading captured
   - Location tracking stopped
   - Historical path loaded from Firestore

---

## UI Screens & Navigation

### 1. Schedule Trips Page
**File**: `lib/presentation/views/driver_schedule_trips_page.dart`

**Purpose**: View all scheduled trips for selected date

**Features**:
- Date selector (Yesterday, Today, Tomorrow)
- Stream of trips via `watchDriverScheduledTripsForDate()`
- Displays trips as `DriverMissionCard` widgets
- Tap on trip → Navigate to Map screen

**Data Source**:
```dart
scheduledTripsRepo.watchDriverScheduledTripsForDate(
  organizationId: organization.id.toString(),
  driverPhone: user.phoneNumber.toString(),
  scheduledDate: _selectedDate,
)
```

**Filtering**:
- Filters by `organizationId` + `driverPhone` + `scheduledDate`
- Only shows active trips (`isActive != false`)
- Sorted by `slot` number

---

### 2. Map Screen (Driver Home Screen)
**File**: `lib/presentation/screens/home/driver_home_screen.dart`

**Purpose**: Main trip execution interface with map, controls, and tracking

**Components**:

#### A. DriverMap Widget
- Full-screen Google Maps
- Shows current location (if permissions granted)
- Path visualization:
  - **Orange polyline**: Path to delivery point
  - **Blue polyline**: Path after delivery (return journey)
- Historical path for returned trips

#### B. HUD Overlay
- **Visible**: Only when `tripStatus == 'dispatched'`
- **Displays**:
  - Current speed (km/h)
  - ETA (if available)
  - Distance remaining (if available)
- **Data Source**: `LocationService.currentLocationStream`

#### C. Control Panel (`_ControlPanel`)
- **Trip Picker**: Dropdown to select from today's trips
- **Status Indicator**: Shows tracking state (🟢 ONLINE / 🔴 OFFLINE)
- **Action Button**: Changes based on trip status
  - `scheduled` → "Start Trip" (requires DM number)
  - `dispatched` → "Mark Delivered"
  - `delivered` → "Mark Returned"
  - `returned` → "Trip Completed" message

#### D. Top Status Bar
- Shows permission status
- "READY" (green) or "PERMISSIONS NEEDED" (yellow)

---

## Trip Flow by Status

### Status: `scheduled` / `pending`

**UI State**:
- Button: "Start Trip" (disabled if no DM number)
- Trip visible in dropdown

**User Action**: Tap "Start Trip" button

**Flow**:
1. `TripExecutionSheet.show()` opens bottom sheet
2. Sheet shows: "Start Trip" form
3. User enters **Initial Reading** (odometer)
4. User slides "Slide to Start Trip" button

**Backend Actions**:
```dart
// 1. Update trip status
scheduledTripsRepo.updateTripStatus(
  tripId: tripId,
  tripStatus: 'dispatched',
  initialReading: reading,
  deliveredByRole: 'driver',
  source: 'driver',
)

// 2. Start location tracking
TripBloc.add(StartTrip(tripId: tripId, clientId: clientId))
```

**TripBloc Actions**:
- Validates permissions (notification, location always)
- Runs Firestore transaction to update trip status
- Starts `LocationService.startTracking()`
- Starts background foreground service
- Enables wakelock (keep screen on)

**UI Updates**:
- Status changes to `dispatched`
- HUD overlay appears
- Path visualization starts (orange line)
- Button changes to "Mark Delivered"

---

### Status: `dispatched`

**UI State**:
- HUD overlay visible (speed, ETA, distance)
- Path visualization active (orange line)
- Button: "Mark Delivered"

**User Action**: Tap "Mark Delivered" button

**Flow**:
1. `TripExecutionSheet.show()` opens bottom sheet
2. Sheet shows: "Mark Delivered" form
3. User enters **Delivery Reading** (odometer)
4. User takes delivery photo (camera)
5. User slides "Slide to Mark Delivered" button

**Backend Actions**:
```dart
// 1. Upload photo to Firebase Storage
storageService.uploadDeliveryPhoto(
  imageFile: photoFile,
  organizationId: organizationId,
  orderId: orderId,
  tripId: tripId,
)

// 2. Update trip status
scheduledTripsRepo.updateTripStatus(
  tripId: tripId,
  tripStatus: 'delivered',
  deliveryPhotoUrl: photoUrl,
  deliveredBy: user.id,
  deliveredByRole: 'driver',
  source: 'driver',
)
```

**UI Updates**:
- Status changes to `delivered`
- HUD overlay disappears
- Path visualization continues:
  - Orange line: up to delivery point
  - Blue line: after delivery point
- Button changes to "Mark Returned"
- Delivery point index captured for path splitting

---

### Status: `delivered`

**UI State**:
- Path visualization: Orange (to delivery) + Blue (after delivery)
- Button: "Mark Returned"

**User Action**: Tap "Mark Returned" button

**Flow**:
1. `TripExecutionSheet.show()` opens bottom sheet
2. Sheet shows: "Mark Returned" form
3. User enters **Final Reading** (odometer)
4. User slides "Slide to Mark Returned" button

**Backend Actions**:
```dart
// Calculate distance
final initialReading = trip['initialReading'] as double?;
final distance = (initialReading != null && reading >= initialReading)
    ? (reading - initialReading)
    : null;

// Get GPS-based distance
final computedDistance = locationService.totalDistance;

// Update trip status
scheduledTripsRepo.updateTripStatus(
  tripId: tripId,
  tripStatus: 'returned',
  finalReading: reading,
  distanceTravelled: distance,
  computedTravelledDistance: computedDistance,
  returnedBy: user.id,
  returnedByRole: 'driver',
  source: 'driver',
)

// Stop location tracking
TripBloc.add(EndTrip())
```

**TripBloc Actions**:
- Stops `LocationService.stopTracking()`
- Stops background service
- Disables wakelock
- Saves final location batch to Firestore

**UI Updates**:
- Status changes to `returned`
- Path visualization: Historical path loaded from Firestore
- Button shows: "Trip Completed" message
- Historical path shows delivery point marker

---

### Status: `returned`

**UI State**:
- Historical path displayed (from Firestore)
- Delivery point marked on path
- Button: "Trip Completed" (info only)

**User Action**: Tap button to view details

**Flow**:
1. `TripExecutionSheet.show()` opens bottom sheet
2. Sheet shows: "Trip Completed" summary
3. Displays:
   - Initial Reading
   - Delivery Reading
   - Final Reading
   - Distance Travelled

**No Backend Actions**: Read-only view

---

## Key Components

### 1. TripExecutionSheet
**File**: `lib/presentation/widgets/trip_execution_sheet.dart`

**Purpose**: Morphing bottom sheet that adapts to trip status

**States**:
- **Scheduled**: Initial reading input + Start action
- **Dispatched**: Delivery reading input + Photo upload + Deliver action
- **Delivered**: Final reading input + Return action
- **Returned**: Completion details (read-only)

**Features**:
- Form validation
- Reading validation (delivery >= initial, final >= initial)
- Photo picker integration
- Slide-to-confirm action buttons
- Rescue banner for client-dispatched trips

---

### 2. TripBloc
**File**: `lib/presentation/blocs/trip/trip_bloc.dart`

**Purpose**: Manages trip tracking state and location service coordination

**Events**:
- `StartTrip(tripId, clientId)` - Begin tracking
- `EndTrip()` - Stop tracking

**State**:
- `isTracking`: Boolean tracking status
- `activeTrip`: Currently tracked trip
- `status`: ViewStatus (loading, success, failure)
- `message`: Error/info messages

**Responsibilities**:
- Permission validation
- Firestore transaction management
- LocationService coordination
- Background service management
- Wakelock management

---

### 3. LocationService
**Purpose**: GPS location tracking and path recording

**Features**:
- Real-time location streaming
- Path point accumulation
- Distance calculation
- Background location updates
- Firebase RTDB updates (active_drivers)
- Firestore history storage

---

### 4. DriverMap Widget
**File**: `lib/presentation/widgets/driver_map.dart`

**Purpose**: Map visualization with path rendering

**Features**:
- Google Maps integration
- Live location marker
- Path polyline rendering:
  - Orange: To delivery point
  - Blue: After delivery point
- Historical path loading
- Delivery point marker

---

## Data Flow

### Trip Data Source
```
Firestore: SCHEDULE_TRIPS collection
  ↓
ScheduledTripsDataSource.watchDriverScheduledTripsForDate()
  ↓
Stream<List<Map<String, dynamic>>>
  ↓
UI Components (StreamBuilder)
```

### Trip Status Updates
```
User Action (UI)
  ↓
TripExecutionSheet callbacks
  ↓
ScheduledTripsRepository.updateTripStatus()
  ↓
ScheduledTripsDataSource.updateTripStatus()
  ↓
Firestore: SCHEDULE_TRIPS/{tripId}.update()
  ↓
Stream emits new data
  ↓
UI rebuilds with new status
```

### Location Tracking Flow
```
User dispatches trip
  ↓
TripBloc.add(StartTrip())
  ↓
LocationService.startTracking()
  ↓
GPS updates → LocationService.currentLocationStream
  ↓
UI: HUD Overlay (speed, ETA, distance)
UI: DriverMap (path visualization)
  ↓
Background: Firebase RTDB (active_drivers/{uid})
Background: Firestore (SCHEDULE_TRIPS/{tripId}/history)
```

---

## Location Tracking Integration

### When Tracking Starts
1. **Permissions Check**:
   - Notification permission (required for foreground service)
   - Location "Always" permission (required for background tracking)

2. **Firestore Transaction**:
   - Updates trip status to `dispatched`
   - Creates/updates `trips` document
   - Sets `source: 'driver'`

3. **Location Service**:
   - Starts GPS tracking
   - Begins streaming locations
   - Starts foreground service
   - Enables wakelock

4. **UI Updates**:
   - HUD overlay appears
   - Path visualization starts
   - Tracking indicator shows "🟢 ONLINE"

### During Tracking
- **Location Stream**: `LocationService.currentLocationStream`
- **Path Points**: Accumulated in `DriverMap._pathPoints`
- **RTDB Updates**: Real-time location in `active_drivers/{uid}`
- **History Storage**: Batched writes to `SCHEDULE_TRIPS/{tripId}/history`

### When Tracking Stops
1. **User marks returned**
2. **TripBloc.add(EndTrip())**
3. **LocationService.stopTracking()**
4. **Final batch saved to Firestore**
5. **Background service stopped**
6. **Wakelock disabled**
7. **UI shows historical path**

---

## Special Cases

### Client-Dispatched Trips
- **Detection**: `source == 'client'` and `tripStatus == 'dispatched'`
- **Behavior**: 
  - Shows warning banner: "Trip Dispatched by HQ (No Tracking)"
  - Tracking cannot be started (TripBloc prevents it)
  - Driver can still mark as delivered/returned

### Missing DM Number
- **Check**: `dmNumber == null`
- **Behavior**: 
  - "Start Trip" button disabled
  - Shows warning: "DM must be generated before dispatch"

### Historical Path Loading
- **Trigger**: When `returned` trip is selected
- **Source**: `SCHEDULE_TRIPS/{tripId}/history` collection
- **Process**:
  1. Query all history documents (ordered by `createdAt`)
  2. Extract location arrays from each document
  3. Convert to `LatLng` list
  4. Find delivery point index (by `deliveredAt` timestamp)
  5. Render on map with delivery marker

---

## Summary

The Driver App's trip logic follows a clear progression:

1. **View Trips** → Schedule tab shows all scheduled trips
2. **Select Trip** → Map screen with trip picker dropdown
3. **Dispatch** → Enter initial reading → Start tracking
4. **Deliver** → Enter delivery reading + photo → Update status
5. **Return** → Enter final reading → Stop tracking
6. **View History** → Historical path visualization

All status changes are reactive via Firestore streams, ensuring UI stays in sync with backend state. Location tracking is tightly integrated with trip status, starting on dispatch and stopping on return.
