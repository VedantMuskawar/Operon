# Trip Logic and Location Tracking - Comprehensive Overview

## Table of Contents
1. [Trip Logic Architecture](#trip-logic-architecture)
2. [Location Tracking - Driver Map](#location-tracking---driver-map)
3. [Location Tracking - Fleet Map](#location-tracking---fleet-map)
4. [Client Schedule Detail Trip Page](#client-schedule-detail-trip-page)
5. [Modals and Dialogs](#modals-and-dialogs)
6. [Helpers and Utilities](#helpers-and-utilities)
7. [Scenarios and Edge Cases](#scenarios-and-edge-cases)

---

## Trip Logic Architecture

### Core Components

#### 1. TripBloc (`apps/Operon_Driver_android/lib/presentation/blocs/trip/trip_bloc.dart`)

**Purpose**: Manages trip lifecycle and coordinates location tracking with Firestore updates.

**Key Responsibilities**:
- Start/End trip tracking
- Monitor external trip status changes
- Coordinate with LocationService and BackgroundSyncService
- Handle trip state transitions atomically

**State Management**:
```dart
class TripState {
  ViewStatus status;
  Trip? activeTrip;
  bool isTracking;
  String? message;
}
```

**Events**:
- `StartTrip(tripId, clientId)`: Initiates trip tracking
- `EndTrip()`: Stops trip tracking and saves polyline

#### 2. Trip Lifecycle Flow

**Starting a Trip** (`_onStartTrip`):

1. **Permission Checks**:
   - Notification permission (required for foreground service)
   - Location "Always" permission (required for background tracking)

2. **Transaction-Based Status Update**:
   ```dart
   await _firestore.runTransaction((transaction) async {
     // Read SCHEDULE_TRIPS document
     // Validate trip availability (not cancelled, not already completed)
     // Check if already dispatched (prevent duplicate tracking)
     // Update status to 'dispatched' (if not already)
     // Create/update trips document
   });
   ```

3. **Start Location Tracking**:
   - `LocationService.startTracking(uid, tripId, status)`
   - Start foreground service
   - Enable wakelock

4. **Monitor Trip Status**:
   - Subscribe to `SCHEDULE_TRIPS/{tripId}` document
   - Auto-stop tracking if status reverts externally

**Ending a Trip** (`_onEndTrip`):

1. **Stop Location Tracking**:
   - `LocationService.stopTracking(flush: true)`

2. **Compress and Save Polyline**:
   - Fetch all location points from Hive
   - Convert to DriverLocation list
   - Encode using PolylineEncoder
   - Save to `SCHEDULE_TRIPS/{tripId}.routePolyline`

3. **Update Trips Collection**:
   - Set status to 'completed'
   - Set endTime

4. **Cleanup**:
   - Disable wakelock
   - Stop foreground service
   - Stop trip status monitoring

#### 3. External Status Monitoring

**Problem Solved**: When Client App undoes dispatch, Driver App must stop tracking automatically.

**Solution**: `_watchActiveTripStatus()` method:
- Listens to `SCHEDULE_TRIPS/{tripId}` document changes
- Detects when status changes from tracking state (`dispatched`, `delivered`, `returned`) to non-tracking state (`scheduled`)
- Automatically calls `EndTrip()` to stop tracking

**Tracking States**:
- `dispatched`: Active tracking
- `delivered`: Still tracking (return journey)
- `returned`: Still tracking (final leg)
- `scheduled`: Not tracking
- `cancelled`: Not tracking

---

## Location Tracking - Driver Map

### Architecture

#### 1. LocationService (`apps/Operon_Driver_android/lib/core/services/location_service.dart`)

**Purpose**: Core location tracking service with offline-first pattern.

**Key Features**:
- Real-time GPS position stream (Geolocator)
- Dual storage: RTDB (live) + Hive (offline backup)
- Distance calculation with noise filtering (10m threshold)
- Presence service for heartbeat

**Storage Strategy**:

1. **RTDB (Real-time Database)**:
   - Path: `active_drivers/{uid}`
   - Purpose: Live location for fleet map
   - Updates: Every GPS position update

2. **Hive (Local Storage)**:
   - Box: `locationPoints`
   - Purpose: Offline-first backup
   - Sync: BackgroundSyncService handles batch upload

**Location Processing** (`_onPosition`):

```dart
1. Calculate incremental distance (filter GPS jitter > 10m)
2. Emit to currentLocationStream (for UI)
3. Write to RTDB (active_drivers/{uid})
4. Write to Hive (LocationPoint with synced=false)
```

**Distance Tracking**:
- Filters movements < 10 meters (GPS jitter while parked)
- Incremental calculation: `_totalDistanceMeters += distanceMeters`
- Used for trip distance reporting

#### 2. BackgroundSyncService (`apps/Operon_Driver_android/lib/core/services/background_sync_service.dart`)

**Purpose**: Syncs unsynced location points from Hive to RTDB.

**Sync Strategy**:
- Periodic sync: Every 60 seconds
- Network restoration: Triggers sync when connectivity restored
- Batch upload: Groups points by (uid, tripId)
- Cleanup: Deletes synced points from Hive

**Sync Flow**:
```dart
1. Get all unsynced points from Hive
2. Group by (uid, tripId)
3. For each group:
   - Update active_drivers/{uid} (latest point)
   - Batch write to trips/{tripId}/locations/{timestamp}
   - Delete synced points from Hive
```

#### 3. DriverMap Widget (`apps/Operon_Driver_android/lib/presentation/widgets/driver_map.dart`)

**Purpose**: Displays map with live location and path visualization.

**Features**:
- Live location stream subscription
- Path building (adds points when movement > 3m)
- Path simplification (when > 1500 points)
- Camera following (throttled to 1 update/second)
- Historical path support (for returned trips)

**Path Visualization**:
- **Pre-delivery**: Orange polyline
- **Post-delivery**: Blue polyline (after delivery point)
- **Delivery point**: Split point between orange and blue

**Path Management**:
- Resets when trip changes
- Simplifies path when > 1500 points (preserves start/end)
- Tracks delivery point index for color split

#### 4. Driver Home Screen (`apps/Operon_Driver_android/lib/presentation/screens/home/driver_home_screen.dart`)

**Purpose**: Main screen coordinating map, HUD, and trip controls.

**Components**:
- **DriverMap**: Full-screen map with path visualization
- **HudOverlay**: Speed, ETA, distance display (only when dispatched)
- **ControlPanel**: Trip selection, dispatch/delivery/return buttons
- **TopStatusBar**: Permission status indicator

**Trip Status Handling**:
- `scheduled`: Can dispatch (requires DM)
- `dispatched`: Can deliver, shows HUD, shows path
- `delivered`: Can return, shows path (orange + blue)
- `returned`: View history only, shows historical path

**Historical Path Loading**:
- For returned trips, fetches from `SCHEDULE_TRIPS/{tripId}/history`
- Converts to LatLng list
- Finds delivery point index based on `deliveredAt` timestamp

#### 5. HUD Overlay (`apps/Operon_Driver_android/lib/presentation/widgets/hud_overlay.dart`)

**Purpose**: Heads-up display showing real-time trip metrics.

**Displayed Metrics**:
- **Speed**: Current speed in km/h (from GPS)
- **ETA**: Estimated time to arrival (if available)
- **Distance**: Remaining distance (if available)

**Visibility**:
- Only shown when `tripStatus == 'dispatched'`
- Streams from `LocationService.currentLocationStream`
- Monospace font (Roboto Mono) to prevent jitter

---

## Location Tracking - Fleet Map

### Architecture

#### 1. FleetBloc (`apps/Operon_Client_web/lib/logic/fleet/fleet_bloc.dart`)

**Purpose**: Manages fleet-wide location tracking and visualization.

**Modes**:
- **Live Mode**: Real-time RTDB listener
- **History Mode**: Firestore query for historical locations

**State**:
```dart
class FleetState {
  List<FleetDriver> drivers;
  Set<Marker> markers;
  DateTime? selectedDateTime;
  bool isLiveMode;
  FleetStatusFilter selectedFilter;
  List<DriverLocation>? selectedVehicleHistory;
}
```

#### 2. Live Mode (Real-time Tracking)

**Data Source**: Firebase Realtime Database
- Path: `active_drivers/{uid}`
- Listener: `db.ref('active_drivers').onValue`

**Processing Flow** (`_onSnapshotUpdated`):

1. **Parse RTDB Snapshot**:
   - Extract driver UIDs and location data
   - Convert to `DriverLocation` objects

2. **Calculate Staleness**:
   - Compare location timestamp with current time
   - Mark as offline if > 10 minutes old

3. **Generate Vehicle Badges**:
   - Extract vehicle number from location data
   - Generate pin marker with vehicle number (last 4 digits)
   - Cache badges for performance

4. **Animated Marker Management**:
   - Update `AnimatedMarkerManager` with new positions
   - Smooth interpolation between RTDB updates (5-second animation)

5. **Apply Filters**:
   - Filter by status: All, Moving, Idling, Offline
   - Apply ghost mode (alpha 0.2 for non-matching)

**Animated Markers**:
- AnimationController runs continuously (5-second duration)
- Interpolates between last known position and new RTDB update
- Prevents marker "jumping" between updates

#### 3. History Mode (Historical Tracking)

**Data Source**: Firestore
- Collection: `SCHEDULE_TRIPS`
- Subcollection: `history` (contains location batches)

**Query Strategy** (`_loadHistoricalLocations`):

1. **Query Trips for Date**:
   ```dart
   SCHEDULE_TRIPS
     .where('organizationId', == organizationId)
     .where('scheduledDate', >= startOfDay)
     .where('scheduledDate', < endOfDay)
   ```

2. **Load History for Each Trip**:
   ```dart
   SCHEDULE_TRIPS/{tripId}/history
     .orderBy('createdAt', ascending: true)
   ```

3. **Extract Locations**:
   - Each history document contains `locations` array
   - Convert JSON to `DriverLocation` objects
   - Sort by timestamp

4. **Find Location at Target Time**:
   - Binary search for location with timestamp <= target time
   - Use closest location if exact match not found

5. **Generate Markers**:
   - Create marker with historical badge
   - Show time difference in info window
   - Apply offline status if location is stale

#### 4. Vehicle History Playback

**Purpose**: Playback full history for a single vehicle.

**Flow**:
1. User selects vehicle from dropdown
2. Load all history points for that vehicle on selected date
3. Create `HistoryPlayerController` with all points
4. Display playback sheet with controls
5. Animate marker through historical path

**HistoryPlayerController**:
- Manages playback state (play, pause, seek)
- Interpolates between history points
- Updates marker position smoothly

#### 5. FleetMapScreen (`apps/Operon_Client_web/lib/presentation/views/fleet_map_screen.dart`)

**UI Components**:
- **GoogleMap**: Full-screen map with markers
- **SearchPill**: Search functionality (top center)
- **FleetStatusFilterBar**: Filter by status (Moving, Idling, Offline)
- **FleetLegend**: Online/Offline count (top left)
- **ModeToggleButton**: Switch Live/History (top right)
- **HistoryPlaybackSheet**: Playback controls (bottom, history mode only)

**Marker Generation**:
- Uses `MarkerGenerator.createPinMarker()` for vehicle badges
- Badges show last 4 digits of vehicle number
- Color coding: Available (green), Offline (gray), Alert (red)

**Filtering**:
- **All**: Show all vehicles
- **Moving**: Speed > 1.0 m/s, not offline
- **Idling**: Speed <= 1.0 m/s, not offline
- **Offline**: Last update > 10 minutes ago
- Ghost mode: Non-matching markers at 20% opacity

---

## Client Schedule Detail Trip Page

### Overview

**File**: `apps/Operon_Client_android/lib/presentation/views/orders/schedule_trip_detail_page.dart`

**Purpose**: Comprehensive trip management interface for client app.

### UI Structure

#### 1. Header Section
- Trip status badge (color-coded)
- Close button
- Status colors:
  - `delivered`: Green (#4CAF50)
  - `dispatched`: Purple (#6F4BFF)
  - `returned`: Orange
  - Default: Blue-gray

#### 2. Top Action Section
- **Call Driver**: Launches phone dialer
- **Call Customer**: Launches phone dialer

#### 3. Information Cards

**Trip Information**:
- Date and Slot
- Vehicle Number
- Address and City

**Order Summary**:
- Product list with quantities and unit prices
- Subtotal
- GST (included/excluded indicator)
- Total

**Payment Summary**:
- Payment Type (pay_on_delivery, pay_later)
- Payment Status (full, partial, pending)
- Total Amount
- Paid Amount
- Remaining Amount
- Payment Entries (if any)

**Trip Status** (Interactive):
- **Dispatch Toggle**: Switch to dispatch trip
- **Delivery Toggle**: Switch to mark as delivered
- **Return Toggle**: Switch to mark as returned

### Trip Status Management

#### Dispatch Flow

1. **Validation**:
   - Check if DM is generated (required)
   - Verify trip is in `scheduled` or `pending` status

2. **Initial Reading Dialog**:
   - Modal: `_showInitialReadingDialog()`
   - Input: Odometer reading
   - Validation: Must be valid number >= 0

3. **Dispatch Action**:
   ```dart
   await repository.updateTripStatus(
     tripId: tripId,
     tripStatus: 'dispatched',
     initialReading: reading,
   );
   ```

4. **Local State Update**:
   - Set `orderStatus` and `tripStatus` to 'dispatched'
   - Store `initialReading`, `dispatchedAt`, `dispatchedBy`

#### Delivery Flow

1. **Validation**:
   - Trip must be `dispatched`
   - Cannot be `returned`

2. **Photo Dialog**:
   - Modal: `DeliveryPhotoDialog`
   - Capture/select delivery photo
   - Upload to Firebase Storage

3. **Delivery Action**:
   ```dart
   await repository.updateTripStatus(
     tripId: tripId,
     tripStatus: 'delivered',
     deliveryPhotoUrl: photoUrl,
     deliveredBy: userId,
     deliveredByRole: userRole,
   );
   ```

4. **Local State Update**:
   - Set status to 'delivered'
   - Store `deliveryPhotoUrl`, `deliveredAt`, `deliveredBy`

#### Return Flow

1. **Validation**:
   - Trip must be `delivered`
   - Must have `initialReading`

2. **Final Reading Dialog**:
   - Modal: `_showFinalReadingDialog()`
   - Input: Final odometer reading
   - Calculate distance: `finalReading - initialReading`

3. **Payment Collection** (if `pay_on_delivery`):
   - Modal: `ReturnPaymentDialog`
   - Select payment accounts
   - Enter payment amounts
   - Create debit transactions

4. **Return Action**:
   ```dart
   await repository.updateTripStatus(
     tripId: tripId,
     tripStatus: 'returned',
     finalReading: reading,
     distanceTravelled: distance,
     paymentDetails: payments,
     totalPaidOnReturn: totalPaid,
     paymentStatus: status,
   );
   ```

5. **Transaction Creation**:
   - For `pay_on_delivery`: Create debit transactions (client paid)
   - Note: Credit transaction was created at DM generation (dispatch)

### Revert Operations

#### Revert Dispatch
- Confirmation dialog
- Reverts status to `scheduled`
- Removes dispatch fields (`initialReading`, `dispatchedAt`, etc.)
- **Note**: Driver App automatically stops tracking via `TripBloc._watchActiveTripStatus()`

#### Revert Delivery
- Confirmation dialog
- Reverts status to `dispatched`
- Removes delivery fields (keeps dispatch fields)

#### Revert Return
- Confirmation dialog
- Cancels return transactions
- Reverts status to `delivered`
- Removes return fields (keeps delivery and dispatch fields)

---

## Modals and Dialogs

### Driver App

#### 1. DeliveryPhotoDialog
**File**: `apps/Operon_Driver_android/lib/presentation/widgets/delivery_photo_dialog.dart`

**Purpose**: Capture or select delivery photo.

**Features**:
- Camera capture
- Gallery selection
- Image preview
- Returns `File` object

#### 2. Reading Input Dialogs
**Location**: `driver_home_screen.dart` and `driver_trip_detail_page.dart`

**Purpose**: Collect odometer readings.

**Types**:
- Initial Reading (dispatch)
- Final Reading (return)

**Validation**:
- Must be valid number
- Must be >= 0

### Client App

#### 1. Initial Reading Dialog
**Location**: `schedule_trip_detail_page.dart` → `_showInitialReadingDialog()`

**Purpose**: Collect initial odometer reading before dispatch.

**Validation**:
- Required field
- Must be valid number >= 0

#### 2. Delivery Photo Dialog
**Location**: `schedule_trip_detail_page.dart` → `_showDeliveryPhotoDialog()`

**Purpose**: Capture delivery photo.

**Flow**:
1. Show `DeliveryPhotoDialog`
2. Upload photo to Firebase Storage
3. Get photo URL
4. Update trip with `deliveryPhotoUrl`

#### 3. Final Reading Dialog
**Location**: `schedule_trip_detail_page.dart` → `_showFinalReadingDialog()`

**Purpose**: Collect final odometer reading for return.

**Validation**:
- Required field
- Must be valid number >= 0
- Must be >= initial reading

#### 4. Return Payment Dialog
**File**: `apps/Operon_Client_android/lib/presentation/widgets/return_payment_dialog.dart`

**Purpose**: Collect payment entries for `pay_on_delivery` trips.

**Features**:
- Select payment accounts
- Enter payment amounts
- Validate total doesn't exceed trip total
- Returns list of payment entries

#### 5. Revert Confirmation Dialogs
**Location**: `schedule_trip_detail_page.dart`

**Types**:
- `_revertDispatch()`: Revert dispatch to scheduled
- `_revertDelivery()`: Revert delivery to dispatched
- `_revertReturn()`: Revert return to delivered

**All include**:
- Confirmation message
- Cancel/Confirm buttons
- Transaction cleanup (for return revert)

---

## Helpers and Utilities

### 1. Trip Status Utils
**File**: `apps/Operon_Driver_android/lib/core/utils/trip_status_utils.dart`

**Function**: `getTripStatus(Map<String, dynamic> trip)`

**Purpose**: Standardize trip status reading.

**Behavior**:
- Only reads `tripStatus` field (not `orderStatus`)
- Returns `'scheduled'` as default
- Converts to lowercase

**Usage**: All UI components should use this helper for consistency.

### 2. Polyline Encoder
**File**: `apps/Operon_Driver_android/lib/core/utils/polyline_encoder.dart`

**Purpose**: Compress location paths for storage efficiency.

**Algorithm**: Google Polyline Algorithm

**Methods**:
- `encodePath(List<DriverLocation>)`: Returns polyline string + metadata
- `decodePath(String polyline)`: Returns list of [lat, lng] pairs
- `decodeToDriverLocations()`: Converts to DriverLocation objects

**Storage Strategy**:
- Raw locations: ~24 bytes per point
- Polyline: ~1-2 bytes per point (90%+ reduction)
- Stored in `SCHEDULE_TRIPS/{tripId}.routePolyline`

### 3. Path Simplifier
**File**: `apps/Operon_Driver_android/lib/core/utils/path_simplifier.dart`

**Purpose**: Reduce path complexity for long trips.

**Usage**: When path > 1500 points, simplify to preserve memory.

**Algorithm**: Douglas-Peucker simplification with 5m tolerance.

### 4. Permission Utils
**File**: `apps/Operon_Driver_android/lib/core/utils/permission_utils.dart`

**Function**: `requestDriverPermissions(BuildContext)`

**Required Permissions**:
- Location (Always)
- Notification
- Camera (for delivery photo)

### 5. Message Utils
**File**: `apps/Operon_Driver_android/lib/core/utils/message_utils.dart`

**Functions**:
- `showErrorSnackBar()`: Display error messages
- `showSuccessSnackBar()`: Display success messages

---

## Scenarios and Edge Cases

### 1. Dispatch Undo Scenario

**Scenario**: Client App undoes dispatch while Driver App is tracking.

**Flow**:
1. Driver dispatches trip → Tracking starts
2. Client reverts dispatch → Status changes to `scheduled`
3. `TripBloc._watchActiveTripStatus()` detects change
4. Automatically calls `EndTrip()`
5. Tracking stops, UI updates

**Implementation**:
- `TripBloc` subscribes to trip document on `StartTrip`
- Monitors for status changes
- Stops tracking if status is no longer in tracking state

### 2. Network Offline Scenario

**Scenario**: Driver loses network during trip.

**Flow**:
1. Location points stored in Hive (offline-first)
2. RTDB writes fail (expected)
3. BackgroundSyncService detects network restoration
4. Batch uploads all unsynced points
5. Points deleted from Hive after successful sync

**Implementation**:
- `LocationService` writes to Hive immediately
- `BackgroundSyncService` handles sync when network available
- Connectivity listener triggers sync on restoration

### 3. App Restart During Trip

**Scenario**: Driver app is killed/restarted while trip is active.

**Current Behavior**:
- Trip state is lost (not persisted)
- Driver must manually restart trip
- Historical locations are preserved in Hive

**Potential Improvement**:
- Persist active trip ID
- Restore trip state on app start
- Resume tracking automatically

### 4. Multiple Trips Scenario

**Scenario**: Driver has multiple trips scheduled for the day.

**Flow**:
1. Driver selects trip from dropdown
2. Only selected trip is tracked
3. Switching trips stops current tracking
4. New trip must be dispatched separately

**Implementation**:
- `DriverHomeScreen` manages `_selectedTrip`
- `TripBloc` handles one active trip at a time
- Trip picker updates selection

### 5. Historical Path Loading

**Scenario**: Viewing returned trip with historical path.

**Flow**:
1. User selects returned trip
2. `_ensureHistoryLoaded()` fetches from Firestore
3. Loads `SCHEDULE_TRIPS/{tripId}/history` subcollection
4. Extracts all locations, sorts by timestamp
5. Finds delivery point index based on `deliveredAt`
6. Displays path with orange (pre-delivery) and blue (post-delivery)

**Implementation**:
- Lazy loading: Only loads when returned trip selected
- Caching: Stores in `_historicalPath` to avoid re-fetching
- Delivery point: Binary search for timestamp >= `deliveredAt`

### 6. Fleet Map Staleness

**Scenario**: Vehicle hasn't updated location in > 10 minutes.

**Flow**:
1. `FleetBloc` calculates location age
2. Marks as offline if > 10 minutes
3. Badge changes to offline style (gray)
4. Marker alpha reduced to 0.35

**Implementation**:
- `_staleThreshold = Duration(minutes: 10)`
- Calculated in `_onSnapshotUpdated()` for live mode
- Calculated in `_loadHistoricalLocations()` for history mode

### 7. Payment Collection on Return

**Scenario**: `pay_on_delivery` trip requires payment on return.

**Flow**:
1. User marks trip as returned
2. Enters final reading
3. `ReturnPaymentDialog` shows payment accounts
4. User enters payment amounts
5. Debit transactions created (client paid)
6. Trip updated with payment details

**Transaction Logic**:
- **Credit Transaction**: Created at DM generation (dispatch)
- **Debit Transactions**: Created on return (payments received)
- **Balance**: Credit - Debits = Remaining receivable

### 8. Path Simplification

**Scenario**: Long trip generates > 1500 location points.

**Flow**:
1. `DriverMap` tracks path length
2. When > 1500 points, triggers simplification
3. Uses Douglas-Peucker algorithm (5m tolerance)
4. Preserves start and end points
5. Reduces memory usage

**Implementation**:
- `PathSimplifier.simplifyPath()` called in `DriverMap`
- Simplification preserves visual path shape
- Delivery point index adjusted relative to simplified path

---

## Data Flow Diagrams

### Trip Dispatch Flow

```
Driver App:
  User selects trip
    ↓
  User slides "Dispatch"
    ↓
  Initial reading dialog
    ↓
  scheduledTripsRepo.updateTripStatus('dispatched', initialReading)
    ↓
  TripBloc.add(StartTrip)
    ↓
  TripBloc._onStartTrip():
    - Transaction: Update SCHEDULE_TRIPS status
    - Create trips document
    - Start LocationService tracking
    - Start foreground service
    - Monitor trip status
    ↓
  LocationService.startTracking():
    - Open Hive box
    - Start Geolocator stream
    - Start PresenceService
    ↓
  Location updates flow:
    - Calculate distance
    - Write to RTDB (active_drivers/{uid})
    - Write to Hive (locationPoints)
    - Emit to currentLocationStream
    ↓
  DriverMap:
    - Receives location updates
    - Builds path (adds points when > 3m movement)
    - Updates camera (throttled to 1/sec)
    - Displays orange polyline
```

### Location Sync Flow

```
LocationService._onPosition():
  - Calculate distance
  - Write to RTDB (active_drivers/{uid}) [may fail if offline]
  - Write to Hive (locationPoints, synced=false) [always succeeds]
    ↓
BackgroundSyncService (runs every 60s or on network restore):
  - Get all unsynced points from Hive
  - Group by (uid, tripId)
  - For each group:
    - Update RTDB (active_drivers/{uid}) with latest
    - Batch write to RTDB (trips/{tripId}/locations/{timestamp})
    - Delete synced points from Hive
```

### Fleet Map Live Mode Flow

```
FleetBloc:
  - Listen to RTDB (active_drivers)
    ↓
  RTDB snapshot update:
    - Parse driver locations
    - Calculate staleness
    - Generate vehicle badges
    - Update AnimatedMarkerManager
    ↓
FleetMapScreen:
  - AnimationController (5s loop)
  - On each frame:
    - Get animated markers from AnimatedMarkerManager
    - Apply filters
    - Update map markers
    ↓
  Smooth marker interpolation between RTDB updates
```

### Trip End Flow

```
Driver App:
  User slides "Return"
    ↓
  Final reading dialog
    ↓
  scheduledTripsRepo.updateTripStatus('returned', finalReading)
    ↓
  TripBloc.add(EndTrip)
    ↓
  TripBloc._onEndTrip():
    - Stop LocationService tracking
    - Get location points from BackgroundSyncService
    - Encode to polyline
    - Save to SCHEDULE_TRIPS/{tripId}.routePolyline
    - Update trips collection
    - Stop foreground service
    - Stop monitoring
```

---

## Key Design Decisions

### 1. Offline-First Location Storage
**Decision**: Write to Hive first, sync to RTDB later.

**Rationale**:
- Prevents data loss during network outages
- Reduces battery drain (batch uploads)
- Improves reliability

### 2. Polyline Compression
**Decision**: Compress location paths to polyline strings.

**Rationale**:
- Reduces Firestore storage costs by 90%+
- Maintains path visualization capability
- Trade-off: Loses bearing/speed data (acceptable)

### 3. Transaction-Based Status Updates
**Decision**: Use Firestore transactions for trip status changes.

**Rationale**:
- Prevents race conditions
- Ensures atomicity
- Single source of truth

### 4. External Status Monitoring
**Decision**: TripBloc monitors trip document for external changes.

**Rationale**:
- Handles dispatch undo scenario
- Prevents orphaned tracking
- Automatic cleanup

### 5. Animated Markers in Fleet Map
**Decision**: Interpolate marker positions between RTDB updates.

**Rationale**:
- Smooth visual experience
- Prevents marker "jumping"
- 5-second animation matches RTDB update frequency

### 6. Dual Status Fields
**Decision**: Support both `tripStatus` and `orderStatus` for compatibility.

**Rationale**:
- Legacy support
- Gradual migration
- `tripStatus` is primary, `orderStatus` is fallback

---

## Performance Optimizations

### 1. Path Simplification
- Reduces memory usage for long trips
- Preserves visual path shape
- Threshold: 1500 points

### 2. Camera Update Throttling
- Limits updates to 1 per second
- Prevents rendering overload
- Reduces BLASTBufferQueue warnings

### 3. Badge Caching
- Caches vehicle badge icons
- Prevents regeneration on every update
- Key: `{status}|{vehicleNumber}`

### 4. Batch Location Sync
- Groups points by (uid, tripId)
- Single RTDB update per group
- Reduces network calls

### 5. Lazy History Loading
- Only loads historical path when needed
- Caches loaded path
- Avoids unnecessary Firestore reads

---

## Testing Considerations

### 1. Trip Lifecycle
- Test dispatch → delivery → return flow
- Test dispatch undo scenario
- Test app restart during trip

### 2. Location Tracking
- Test offline scenario
- Test network restoration
- Test long trip (> 1500 points)

### 3. Fleet Map
- Test live mode updates
- Test history mode queries
- Test filter application
- Test vehicle history playback

### 4. Payment Collection
- Test pay_on_delivery flow
- Test pay_later flow
- Test partial payment
- Test transaction creation

### 5. Edge Cases
- Test cancelled trip
- Test deleted trip
- Test multiple trips
- Test stale location handling

---

## Future Improvements

### 1. Trip State Persistence
- Persist active trip ID
- Restore on app restart
- Resume tracking automatically

### 2. Enhanced HUD
- Real-time ETA calculation
- Distance to destination
- Turn-by-turn navigation

### 3. Fleet Map Enhancements
- Route visualization
- Geofencing alerts
- Speed limit warnings

### 4. Analytics
- Trip duration tracking
- Distance accuracy metrics
- Battery usage optimization

### 5. Offline Mode
- Full offline trip management
- Queue status updates
- Sync when online

---

## Conclusion

This system provides a comprehensive trip management and location tracking solution with:

- **Robust offline support**: Hive-based storage with background sync
- **Real-time tracking**: RTDB for live fleet visibility
- **Cost optimization**: Polyline compression for historical paths
- **Automatic cleanup**: External status monitoring prevents orphaned tracking
- **Smooth UX**: Animated markers, path visualization, HUD overlay
- **Comprehensive management**: Full trip lifecycle from dispatch to return

The architecture balances performance, reliability, and user experience while maintaining data integrity and cost efficiency.
