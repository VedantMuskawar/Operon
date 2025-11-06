# Testing Guide: Call Overlay for Pending Orders

## Prerequisites

1. **Build and install the app** on a physical Android device (call detection requires a real device, not an emulator)
2. **Grant necessary permissions**:
   - Phone/Read Phone State permission
   - Display over other apps (SYSTEM_ALERT_WINDOW)
   - Background permissions (if prompted)

## Step 1: Initial Setup

### 1.1 Grant Permissions

1. **Phone Permission**:
   - When the app first launches, Android will prompt for phone permission
   - Accept it when prompted
   - If denied, go to: Settings → Apps → OPERON → Permissions → Phone → Allow

2. **Display Over Other Apps** (SYSTEM_ALERT_WINDOW):
   - Android doesn't automatically prompt for this
   - Go to: Settings → Apps → OPERON → Advanced → Display over other apps → Allow
   - OR: Settings → Apps → Special app access → Display over other apps → OPERON → Allow

3. **Battery Optimization** (Optional but recommended):
   - Go to: Settings → Apps → OPERON → Battery → Unrestricted
   - This ensures the service keeps running in the background

### 1.2 Set Up Test Data

1. **Login to the app** with your Firebase account
2. **Select an organization** (or create one)
3. **Create a test client**:
   - Go to Clients section
   - Add a new client with a phone number (use a real phone number you can call from)
   - Save the client

4. **Create test pending orders**:
   - Go to Orders section
   - Create a new order for the test client
   - Set status to "Pending"
   - Add order details (date, location, trips)
   - Save the order

## Step 2: Testing Scenarios

### Test Case 1: Call from Client with Pending Orders

**Steps:**
1. Ensure the app is running (can be in background)
2. Call the test client's phone number from another phone
3. **Expected Result:**
   - When the call starts ringing, an overlay should appear showing:
     - Phone number
     - Client name
     - List of pending orders with:
       - Placed date
       - Location
       - Trip count
   - Overlay stays visible during the entire call
   - Overlay disappears when call ends

**Verification:**
- ✅ Overlay appears within 1-2 seconds of call ringing
- ✅ All order details are displayed correctly
- ✅ Overlay remains visible during call
- ✅ Overlay disappears when call ends

### Test Case 2: Call from Client with No Pending Orders

**Steps:**
1. Create a client with a phone number but no pending orders
2. Call that phone number
3. **Expected Result:**
   - Overlay appears showing:
     - Phone number
     - Client name
     - "No pending orders" message
   - Overlay stays visible during call
   - Overlay disappears when call ends

**Verification:**
- ✅ Overlay still appears (shows for all calls)
- ✅ "No pending orders" message is displayed
- ✅ Overlay disappears when call ends

### Test Case 3: Call from Unknown Number (Not a Client)

**Steps:**
1. Call from a phone number that's not in your clients list
2. **Expected Result:**
   - Overlay appears showing:
     - Phone number
     - "No pending orders" message
   - No client name shown

**Verification:**
- ✅ Overlay appears
- ✅ Shows phone number
- ✅ Shows "No pending orders"
- ✅ No client name displayed

### Test Case 4: Multiple Pending Orders

**Steps:**
1. Create multiple pending orders for the same client
2. Call that client's number
3. **Expected Result:**
   - Overlay shows all pending orders in a scrollable list
   - Each order shows date, location, and trip count

**Verification:**
- ✅ All orders are displayed
- ✅ Orders are scrollable if there are many
- ✅ Each order shows correct information

### Test Case 5: Background Service (App Closed)

**Steps:**
1. Open the app and select an organization
2. Close the app completely (swipe away from recent apps)
3. Call the test client's number
4. **Expected Result:**
   - Overlay should still appear (if service is running)
   - Order information should be displayed

**Verification:**
- ✅ Service notification is visible in status bar
- ✅ Overlay appears even when app is closed
- ✅ Order lookup works in background

## Step 3: Quick Testing Methods

### Method 1: Using Another Phone
- Use a second phone to call your test device
- This is the most realistic test

### Method 2: Using Android Debug Bridge (ADB)
If you have ADB installed, you can simulate incoming calls:

```bash
# Make your device ring (use a test number)
adb shell am start -a android.intent.action.CALL -d tel:+1234567890
```

### Method 3: Using Android Studio Logcat
Monitor logs to see if call detection is working:

```bash
adb logcat | grep -E "CallReceiver|CallDetectionService|OverlayManager"
```

Look for log messages like:
- "Call state: RINGING"
- "Incoming call from: [number]"
- "Handling incoming call: [number]"
- "OverlayManager: Showing overlay"

## Step 4: Troubleshooting

### Issue: Overlay doesn't appear

**Check:**
1. ✅ Permissions granted (especially "Display over other apps")
2. ✅ Organization is selected in the app
3. ✅ Service is running (check notification bar)
4. ✅ Check logs for errors:
   ```bash
   adb logcat | grep -E "CallReceiver|CallDetectionService|OverlayManager|Error"
   ```

**Common Causes:**
- Permission not granted
- Navigator context not ready
- Service not started
- Organization ID not set

### Issue: Overlay shows but no order data

**Check:**
1. ✅ Client exists with correct phone number
2. ✅ Phone number format matches (check normalization)
3. ✅ Orders exist with status "pending"
4. ✅ Organization ID is set correctly

**Debug:**
- Check logs for "CallOrderLookupService" messages
- Verify phone number normalization in logs

### Issue: Service not starting

**Check:**
1. ✅ Check notification bar for service notification
2. ✅ Check logs: `adb logcat | grep CallDetectionService`
3. ✅ Verify AndroidManifest.xml has service declaration
4. ✅ Check if foreground service permission is granted

### Issue: App crashes on startup

**Check:**
1. ✅ Check logs for crash details
2. ✅ Verify all imports are correct
3. ✅ Ensure Firebase is initialized before service starts
4. ✅ Check if method channel is initialized properly

## Step 5: Performance Testing

### Test Response Time
- Call should be detected within 1-2 seconds
- Overlay should appear within 2-3 seconds total
- Order lookup should complete quickly (cached results)

### Test Battery Impact
- Monitor battery usage over 24 hours
- Service should use minimal battery
- Check background activity in Settings

## Step 6: Edge Cases

### Test These Scenarios:
1. **Very long phone numbers** (international formats)
2. **Multiple rapid calls** (one after another)
3. **Call rejected** before answering
4. **Call missed** (not answered)
5. **Organization switching** during service runtime
6. **App killed** by system (low memory)

## Expected Behavior Summary

| Scenario | Overlay Appears | Shows Orders | Shows Client Name |
|----------|----------------|--------------|-------------------|
| Call from client with pending orders | ✅ Yes | ✅ Yes | ✅ Yes |
| Call from client with no orders | ✅ Yes | ❌ No (shows "No pending orders") | ✅ Yes |
| Call from unknown number | ✅ Yes | ❌ No (shows "No pending orders") | ❌ No |
| App closed | ✅ Yes | ✅ Yes (if service running) | ✅ Yes (if client found) |

## Verification Checklist

- [ ] Phone permission granted
- [ ] Display over other apps permission granted
- [ ] Battery optimization disabled (if needed)
- [ ] Test client created with phone number
- [ ] Test pending orders created
- [ ] Service notification visible
- [ ] Overlay appears on incoming call
- [ ] Order details displayed correctly
- [ ] Overlay stays visible during call
- [ ] Overlay disappears when call ends
- [ ] Works when app is in background
- [ ] Works when app is closed (service running)

## Notes

- The overlay only works when the app has been opened at least once and an organization is selected
- The service needs to be running for call detection to work
- Phone number matching uses normalization (removes spaces, dashes, country codes)
- Orders are fetched in real-time (not cached) for accuracy
- The overlay uses Flutter's overlay system, so it requires the app process to be running




