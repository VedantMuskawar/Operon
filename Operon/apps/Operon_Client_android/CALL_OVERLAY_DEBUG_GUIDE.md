# Call Overlay Debug Logging Guide

## Overview
Added comprehensive debug logging for the Android Call Overlay feature. Logs are emitted with distinct tags for easy filtering in logcat.

## Log Tags & Filters

### Main Tags
- `CallerOverlay` - Bootstrap initialization and lifecycle
- `CallerOverlay.Bootstrap` - App lifecycle events and pending call checks
- `CallOverlayBloc` - BLoC events, state transitions, and data fetching

## Logging Categories

### 1. Bootstrap Initialization (`CallerOverlay.Bootstrap`)
```
🚀 Bootstrap initialized
📱 Android detected. Checking for pending calls...
⚠️  Non-Android platform detected.
```

### 2. App Lifecycle (`CallerOverlay.Bootstrap`)
```
♻️  App lifecycle changed: {state}
⏸️  App resumed. Checking for pending calls...
🛑 Bootstrap disposed
```

### 3. Pending Call Detection
```
🔍 Checking for pending calls...
✅ Pending call check result: {result}
❌ Bootstrap error: {error}
```

### 4. Phone Number Processing (`CallOverlayBloc`)
```
📞 PhoneNumberReceived event: {phone}
📞 Normalized phone: {normalized}
⚠️  Empty phone number. Showing Unknown.
```

### 5. Client Data Fetching (`CallOverlayBloc`)
```
🔄 Loading client data...
🔍 Fetching client by phone: {phone}
✅ Client found: {name} (ID: {id})
❌ Client not found for phone: {phone}
📱 Display number: {number}
```

### 6. Organization & Details Fetch (`CallOverlayBloc`)
```
🏢 Org ID: {orgId}
⚠️  No organization ID found. Skipping details fetch.
🔄 Loading order and transaction details...
```

### 7. Order & Transaction Data (`CallOverlayBloc`)
```
Fetching pending orders for org: {orgId}, client: {clientId}
Pending order result: Found (ID: {orderId}) | None
Fetching last transaction for org: {orgId}, client: {clientId}
Last transaction result: Found | None
Fetching active trip for order: {orderId}
Active trip result: Found (ID: {tripId}) | None
```

### 8. State Update & Errors (`CallOverlayBloc`)
```
✅ Overlay state updated with client details
❌ Error fetching client details: {error}
Stack: {stackTrace}
```

### 9. Permission Checks (`CallerOverlayService`)
```
🔍 Checking if overlay can run...
📋 Overlay permission: {true|false}
📋 Phone permission: {true|false}
✅ Can run overlay: {true|false}
```

### 10. Overlay Trigger (`CallerOverlayService`)
```
🎬 Triggering overlay for phone: {phone}
📞 Normalized phone: {normalized}
⚠️  Empty phone after normalize, skipping overlay trigger
📋 Overlay permission granted: {true|false}
❌ Overlay permission not granted. Enable in Profile → Caller ID.
📡 Sharing data with overlay window...
✅ Data shared successfully
📋 Final overlay permission check: {true|false}
🖼️  Showing overlay window...
✅ Overlay displayed successfully for {phone}
❌ showOverlay error: {error}
```

### 11. Overlay Management
```
🔴 Closing overlay...
✅ Overlay closed
```

### 12. Enable/Disable Status
```
🔧 Setting Caller ID enabled: {true|false}
✅ Caller ID enabled state saved: {true|false}
🔍 Caller ID enabled: {true|false}
```

### 13. Pending Call & File Operations
```
📂 Reading phone from cache file...
📁 Cache file exists: {true|false}
⚠️  No cached phone file found
✅ Read phone from file: {phone|empty}
```

### 14. Data Sharing
```
📡 Sharing data only (overlay already shown): {phone}
😊 Fetching pending incoming call...
👀 Peeking pending incoming call (non-destructive)...
📞 Pending call result: {phone|null}
👀 Peek result: {phone|null}
🗑️  Clearing pending incoming call...
✅ Pending call cleared
```

## How to View Logs

### Using Android Studio
1. Open the Logcat panel (View → Tool Windows → Logcat)
2. Filter by tag: Type in the filter field:
   - `CallerOverlay` (for all overlay logs)
   - `CallOverlayBloc` (for BLoC-specific logs)
   - `CallerOverlay.Bootstrap` (for bootstrap logs)

### Using Command Line (adb logcat)
```bash
# View all Call Overlay logs
adb logcat | grep "CallerOverlay"

# View only BLoC logs
adb logcat | grep "CallOverlayBloc"

# View with timestamps
adb logcat -v threadtime | grep "CallerOverlay"

# Pipe to file for analysis
adb logcat > overlay_logs.txt &
# ... trigger incoming call ...
# Ctrl+C to stop
```

### Filter by Log Level
```bash
# Info and above (default)
adb logcat "*:E" | grep "CallerOverlay"

# Errors only
adb logcat "*:E" | grep "CallerOverlay"

# Warnings and errors
adb logcat "*:W" | grep "CallerOverlay"
```

## Emoji Legend
- 🚀 - Initialization
- 📱 - Android/Platform
- ⚠️ - Warning
- 🛑 - Cleanup/Stop
- ♻️ - Lifecycle
- ⏸️ - Resume
- 🔍 - Searching
- ✅ - Success
- ❌ - Error
- 🔄 - Loading
- 📞 - Phone number
- 🏢 - Organization
- 📋 - Permissions/Status
- 📡 - Data sharing
- 🖼️ - Overlay UI
- 🔴 - Closing
- 🔧 - Configuration
- 📂 - File operations
- 👀 - Peeking
- 🗑️ - Clearing
- 🎬 - Trigger action

## Debugging Flow

### Incoming Call Triggered
1. ✅ Check bootstrap initialization: `🚀 Bootstrap initialized`
2. ✅ Verify Android platform: `📱 Android detected`
3. ✅ Check pending call: `🔍 Checking for pending calls...`
4. ✅ Phone received: `📞 PhoneNumberReceived event: {phone}`
5. ✅ Normalization: `📞 Normalized phone: {normalized}`
6. ✅ Client fetch: `🔍 Fetching client by phone:` + Result
7. ✅ Data loading: `🔄 Loading order and transaction details...`
8. ✅ Overlay shown: `✅ Overlay displayed successfully`

### Permission Issues
1. Check overlay permission: `📋 Overlay permission granted:`
2. Check phone permission: `📋 Phone permission:`
3. If denied: `❌ Overlay permission not granted`

### Data Fetch Failures
1. Look for: `❌ Error fetching client details:`
2. Check stack trace: `Stack: {stackTrace}`
3. Verify network/Firestore access

## Performance Monitoring
- Track `🔄 Loading client data...` to `✅ Client found:` duration
- Monitor BLoC event processing time
- Check for repeated permission checks
- Watch for multiple overlay triggers

## Testing Scenarios

### Scenario 1: Normal Incoming Call
Expected logs:
```
📱 Android detected. Checking for pending calls...
📞 PhoneNumberReceived event: +919876543210
📞 Normalized phone: 919876543210
🔍 Fetching client by phone: 919876543210
✅ Client found: ABC Company (ID: cust_123)
🔄 Loading order and transaction details...
✅ Overlay state updated with client details
✅ Overlay displayed successfully for 919876543210
```

### Scenario 2: Unknown Caller
Expected logs:
```
📞 PhoneNumberReceived event: +1234567890
📞 Normalized phone: 1234567890
🔍 Fetching client by phone: 1234567890
❌ Client not found for phone: 1234567890
```

### Scenario 3: Permission Denied
Expected logs:
```
🎬 Triggering overlay for phone: +919876543210
📋 Overlay permission granted: false
❌ Overlay permission not granted. Enable in Profile → Caller ID.
```

### Scenario 4: App Resumed
Expected logs:
```
♻️  App lifecycle changed: resumed
⏸️  App resumed. Checking for pending calls...
🔍 Checking for pending calls...
✅ Pending call check result: true
```

## Troubleshooting

### Overlay not showing
- ✅ Check: `📋 Overlay permission granted: true`
- ✅ Check: `🎬 Triggering overlay for phone: {phone}`
- ✅ Check: `✅ Overlay displayed successfully`
- ❌ If missing, check permission error logs

### Wrong caller name displayed
- ✅ Check: `📞 Normalized phone: {normalized}`
- ✅ Check: `🔍 Fetching client by phone: {normalized}`
- ✅ Verify client ID in result logs

### Slow response time
- ✅ Time between `🔄 Loading client data...` and `✅ Client found:`
- ✅ Time between `🔄 Loading order and transaction details...` and `✅ Overlay state updated`
- ✅ Look for network/Firestore errors

### Empty overlay content
- ✅ Check if client was found: `❌ Client not found`
- ✅ Check if details failed to load: `❌ Error fetching client details: {error}`
- ✅ Review error logs with stack traces
