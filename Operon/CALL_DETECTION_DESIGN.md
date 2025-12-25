# Call Detection & Caller ID Feature Design

## Overview
A Truecaller-like feature that detects incoming calls, identifies if the caller is a client, and displays an overlay with pending orders and recent completed orders.

## Requirements

### Functional Requirements
1. **Call Detection**: Detect incoming calls whether app is open or closed
2. **Client Identification**: Check if caller's phone number matches a client in the system
3. **Overlay Display**: Show overlay UI with:
   - Client name and info
   - Pending orders count and list
   - Recent completed orders (last 5)
4. **Background Operation**: Work when app is in background or closed

### Technical Requirements
1. **Platform Support**: Android (primary), iOS (secondary - more restricted)
2. **Permissions**: 
   - Phone state permission (Android)
   - Overlay permission (Android)
   - Background execution permission
3. **Performance**: Fast client lookup (< 1 second)
4. **UI/UX**: Non-intrusive overlay that doesn't block call controls

## Architecture

### Components

#### 1. Call Detection Service
- **Purpose**: Monitor incoming calls
- **Implementation**: 
  - Use `telephony` package for Android call state detection
  - Use platform channels for iOS (CallKit integration)
- **Location**: `lib/data/services/call_detection_service.dart`

#### 2. Call Overlay Manager
- **Purpose**: Manage overlay display and lifecycle
- **Implementation**:
  - Use `overlay_support` or `flutter_overlay_window` package
  - Handle overlay permissions
  - Manage overlay visibility
- **Location**: `lib/data/services/call_overlay_manager.dart`

#### 3. Caller ID Service
- **Purpose**: Identify caller and fetch related data
- **Implementation**:
  - Use existing `ClientService.findClientByPhone()`
  - Fetch pending orders for client
  - Fetch recent completed orders
- **Location**: `lib/data/services/caller_id_service.dart`

#### 4. Call Overlay Widget
- **Purpose**: UI component displayed during call
- **Implementation**:
  - Compact, non-intrusive design
  - Shows client info, pending orders, completed orders
  - Dismissible overlay
- **Location**: `lib/presentation/widgets/call_overlay_widget.dart`

#### 5. Call Detection Bloc/Cubit
- **Purpose**: State management for call detection
- **Implementation**:
  - Listen to call events
  - Trigger client lookup
  - Manage overlay state
- **Location**: `lib/presentation/blocs/call_detection/call_detection_cubit.dart`

## Implementation Plan

### Phase 1: Call Detection Setup
1. Add required packages:
   - `telephony` - Android call detection
   - `flutter_overlay_window` or `overlay_support` - Overlay display
   - `permission_handler` - Already available

2. Create call detection service
   - Listen to phone state changes
   - Detect incoming calls
   - Extract caller phone number

### Phase 2: Client Lookup Integration
1. Create caller ID service
   - Use `ClientService.findClientByPhone()`
   - Fetch pending orders (using `PendingOrdersRepository`)
   - Fetch completed orders (using `TransactionsRepository` or similar)
   - Cache results for performance

### Phase 3: Overlay UI
1. Create overlay widget
   - Client header (name, phone)
   - Pending orders section (count + list)
   - Recent completed orders (last 5)
   - Dismiss button

2. Create overlay manager
   - Request overlay permissions
   - Show/hide overlay
   - Handle overlay lifecycle

### Phase 4: Integration
1. Create call detection cubit
   - Listen to call events
   - Trigger client lookup on incoming call
   - Show overlay if client found
   - Hide overlay when call ends

2. Initialize in app
   - Start call detection on app launch
   - Request necessary permissions
   - Handle background execution

## Data Flow

```
Incoming Call Detected
    ↓
Extract Phone Number
    ↓
Caller ID Service: findClientByPhone()
    ↓
Client Found?
    ├─ No → Do nothing
    └─ Yes → Fetch Orders
            ├─ Pending Orders (from PENDING_ORDERS collection)
            └─ Completed Orders (from TRANSACTIONS subcollection in CLIENT_LEDGERS)
        ↓
Show Overlay with Data
    ↓
Call Ends → Hide Overlay
```

## Package Dependencies

```yaml
dependencies:
  telephony: ^0.2.0  # Android call detection
  flutter_overlay_window: ^0.4.0  # Overlay display
  # OR
  overlay_support: ^1.2.0  # Alternative overlay solution
  permission_handler: ^11.3.1  # Already available
```

## Android Configuration

### AndroidManifest.xml
```xml
<uses-permission android:name="android.permission.READ_PHONE_STATE" />
<uses-permission android:name="android.permission.SYSTEM_ALERT_WINDOW" />
<uses-permission android:name="android.permission.FOREGROUND_SERVICE" />

<service
    android:name="com.example.overlay.OverlayService"
    android:enabled="true"
    android:exported="false"
    android:foregroundServiceType="phoneCall" />
```

### MainActivity.kt
```kotlin
// Handle overlay permissions
// Initialize overlay service
```

## iOS Configuration

### Info.plist
```xml
<key>NSPhoneCallUsageDescription</key>
<string>We need access to detect incoming calls to show client information</string>
```

**Note**: iOS has strict limitations on call detection. CallKit integration may be required, which is more complex.

## UI Design

### Overlay Widget Structure
```
┌─────────────────────────────┐
│  [X] Close                   │
├─────────────────────────────┤
│  👤 Client Name              │
│  📞 +91 98765 43210          │
├─────────────────────────────┤
│  📋 Pending Orders (3)      │
│  ┌─────────────────────────┐ │
│  │ Order #123 - 500 units   │ │
│  │ Order #124 - 1000 units │ │
│  └─────────────────────────┘ │
├─────────────────────────────┤
│  ✅ Recent Completed (2)     │
│  ┌─────────────────────────┐ │
│  │ Order #120 - ₹50,000     │ │
│  │ Order #119 - ₹30,000     │ │
│  └─────────────────────────┘ │
└─────────────────────────────┘
```

## Performance Considerations

1. **Caching**: Cache client data and recent orders to avoid repeated queries
2. **Async Loading**: Load orders asynchronously after showing client info
3. **Debouncing**: Avoid multiple lookups for the same call
4. **Background Limits**: Be mindful of background execution limits

## Security & Privacy

1. **Data Access**: Only access client data for authenticated users
2. **Phone Number Normalization**: Normalize phone numbers consistently
3. **Permission Handling**: Request permissions gracefully with explanations
4. **Data Caching**: Clear sensitive data when appropriate

## Testing Strategy

1. **Unit Tests**: Test client lookup logic
2. **Integration Tests**: Test call detection flow
3. **Manual Testing**: Test overlay display during actual calls
4. **Permission Testing**: Test permission request flows

## Limitations & Considerations

1. **Android Focus**: Primary implementation for Android
2. **iOS Restrictions**: iOS has stricter limitations on call detection
3. **Battery Impact**: Background monitoring may impact battery
4. **Privacy Concerns**: Users may be concerned about call monitoring
5. **Overlay Permissions**: Users must grant overlay permissions manually

## Future Enhancements

1. **Call Recording**: Option to record call notes
2. **Quick Actions**: Quick actions from overlay (create order, view client)
3. **Call History**: Track call history per client
4. **Smart Notifications**: Push notifications for important clients
5. **Multi-Organization**: Support for multiple organizations

## Questions for Discussion

1. **Overlay Position**: Where should overlay appear? (Top, bottom, floating?)
2. **Auto-Dismiss**: Should overlay auto-dismiss after X seconds?
3. **Order Limit**: How many pending/completed orders to show?
4. **Background Behavior**: Should it work when app is completely closed?
5. **iOS Support**: Is iOS support required initially or can we focus on Android?
6. **Permissions UX**: How to guide users through permission setup?
7. **Performance**: Acceptable delay for showing overlay? (< 1s, < 2s?)

