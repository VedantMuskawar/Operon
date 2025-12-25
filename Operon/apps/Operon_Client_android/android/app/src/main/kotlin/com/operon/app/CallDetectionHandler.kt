package com.operonclientandroid.app

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.CallLog
import android.telephony.PhoneStateListener
import android.telephony.TelephonyManager
import io.flutter.plugin.common.MethodChannel

class CallDetectionHandler(private val context: Context, private val channel: MethodChannel) {
    private var telephonyManager: TelephonyManager? = null
    private var phoneStateListener: PhoneStateListener? = null
    private var isListening = false

    fun startListening(): Boolean {
        android.util.Log.d("CallDetectionHandler", "startListening called, isListening: $isListening")
        if (isListening) {
            android.util.Log.d("CallDetectionHandler", "Already listening, returning true")
            return true
        }

        try {
            android.util.Log.d("CallDetectionHandler", "Getting TelephonyManager...")
            telephonyManager = context.getSystemService(Context.TELEPHONY_SERVICE) as TelephonyManager
            
            android.util.Log.d("CallDetectionHandler", "Creating PhoneStateListener...")
            
            // Use the appropriate PhoneStateListener based on Android version
            phoneStateListener = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                // Android 12+ uses TelephonyCallback
                object : PhoneStateListener() {
                    override fun onCallStateChanged(state: Int, phoneNumber: String?) {
                        handleCallStateChange(state, phoneNumber)
                    }
                }
            } else {
                // Older Android versions
                object : PhoneStateListener() {
                    override fun onCallStateChanged(state: Int, phoneNumber: String?) {
                        handleCallStateChange(state, phoneNumber)
                    }
                }
            }
            
            android.util.Log.d("CallDetectionHandler", "Registering PhoneStateListener...")
            telephonyManager?.listen(phoneStateListener, PhoneStateListener.LISTEN_CALL_STATE)
            isListening = true
            android.util.Log.d("CallDetectionHandler", "Call detection started successfully")
            return true
        } catch (e: Exception) {
            android.util.Log.e("CallDetectionHandler", "Error starting call detection", e)
            e.printStackTrace()
            return false
        }
    }

    fun stopListening() {
        android.util.Log.d("CallDetectionHandler", "stopListening called, isListening: $isListening")
        if (!isListening) {
            android.util.Log.d("CallDetectionHandler", "Not listening, returning")
            return
        }

        try {
            phoneStateListener?.let {
                android.util.Log.d("CallDetectionHandler", "Unregistering PhoneStateListener...")
                telephonyManager?.listen(it, PhoneStateListener.LISTEN_NONE)
            }
            phoneStateListener = null
            telephonyManager = null
            isListening = false
            android.util.Log.d("CallDetectionHandler", "Call detection stopped successfully")
        } catch (e: Exception) {
            android.util.Log.e("CallDetectionHandler", "Error stopping call detection", e)
            e.printStackTrace()
        }
    }
    
    private fun handleCallStateChange(state: Int, phoneNumber: String?) {
        android.util.Log.d("CallDetectionHandler", "Call state changed: $state, phoneNumber: $phoneNumber")
        when (state) {
            TelephonyManager.CALL_STATE_RINGING -> {
                // Incoming call detected
                var number = phoneNumber?.trim() ?: ""
                
                android.util.Log.d("CallDetectionHandler", "Initial phone number from listener: '$number'")
                
                // If phone number is empty, try to get it from CallLog with a small delay
                // This gives the system time to write the call to the log
                if (number.isEmpty()) {
                    android.util.Log.d("CallDetectionHandler", "Phone number is empty, waiting 200ms then checking call log...")
                    Handler(Looper.getMainLooper()).postDelayed({
                        val callLogNumber = getIncomingCallNumber()
                        android.util.Log.d("CallDetectionHandler", "Got number from call log: '$callLogNumber'")
                        number = callLogNumber ?: ""
                        
                        android.util.Log.d("CallDetectionHandler", "Final phone number: '$number'")
                        
                        if (number.isNotEmpty()) {
                            try {
                                channel.invokeMethod("onIncomingCall", number)
                                android.util.Log.d("CallDetectionHandler", "onIncomingCall method invoked with number: $number")
                            } catch (e: Exception) {
                                android.util.Log.e("CallDetectionHandler", "Error invoking onIncomingCall", e)
                                e.printStackTrace()
                            }
                        } else {
                            android.util.Log.w("CallDetectionHandler", "Phone number still empty after checking call log")
                            // Still notify Flutter with empty string - Flutter can handle this
                            try {
                                channel.invokeMethod("onIncomingCall", "")
                                android.util.Log.d("CallDetectionHandler", "onIncomingCall invoked with empty number")
                            } catch (e: Exception) {
                                android.util.Log.e("CallDetectionHandler", "Error invoking onIncomingCall with empty number", e)
                            }
                        }
                    }, 200) // 200ms delay
                } else {
                    // Phone number is available immediately
                    android.util.Log.d("CallDetectionHandler", "Incoming call detected with number: $number")
                    try {
                        channel.invokeMethod("onIncomingCall", number)
                        android.util.Log.d("CallDetectionHandler", "onIncomingCall method invoked with number: $number")
                    } catch (e: Exception) {
                        android.util.Log.e("CallDetectionHandler", "Error invoking onIncomingCall", e)
                        e.printStackTrace()
                    }
                }
            }
            TelephonyManager.CALL_STATE_IDLE -> {
                // Call ended
                android.util.Log.d("CallDetectionHandler", "Call ended (IDLE state)")
                try {
                    channel.invokeMethod("onCallEnd", null)
                    android.util.Log.d("CallDetectionHandler", "onCallEnd method invoked")
                } catch (e: Exception) {
                    android.util.Log.e("CallDetectionHandler", "Error invoking onCallEnd", e)
                    e.printStackTrace()
                }
            }
            TelephonyManager.CALL_STATE_OFFHOOK -> {
                android.util.Log.d("CallDetectionHandler", "Call state: OFFHOOK (call active)")
            }
        }
    }
    
    private fun getIncomingCallNumber(): String? {
        return try {
            // Check if we have READ_CALL_LOG permission
            val hasPermission = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                context.checkSelfPermission(Manifest.permission.READ_CALL_LOG) == PackageManager.PERMISSION_GRANTED
            } else {
                true // Permission granted by default on older Android versions
            }
            
            if (!hasPermission) {
                android.util.Log.w("CallDetectionHandler", "READ_CALL_LOG permission not granted")
                return null
            }
            
            // Try to get the most recent incoming call number from CallLog
            val cursor = context.contentResolver.query(
                CallLog.Calls.CONTENT_URI,
                arrayOf(CallLog.Calls.NUMBER, CallLog.Calls.DATE),
                "${CallLog.Calls.TYPE} = ?",
                arrayOf(CallLog.Calls.INCOMING_TYPE.toString()),
                "${CallLog.Calls.DATE} DESC LIMIT 1"
            )
            
            cursor?.use {
                if (it.moveToFirst()) {
                    val number = it.getString(0)?.trim() ?: ""
                    val callDate = it.getLong(1)
                    val currentTime = System.currentTimeMillis()
                    val timeDiff = currentTime - callDate
                    
                    android.util.Log.d("CallDetectionHandler", "Got number from call log: '$number', time diff: ${timeDiff}ms")
                    
                    // Only return the number if the call was logged very recently (within last 5 seconds)
                    if (timeDiff < 5000 && number.isNotEmpty()) {
                        number
                    } else {
                        android.util.Log.d("CallDetectionHandler", "Call log entry too old or empty, ignoring")
                        null
                    }
                } else {
                    android.util.Log.d("CallDetectionHandler", "No incoming calls found in call log")
                    null
                }
            } ?: null
        } catch (e: Exception) {
            android.util.Log.e("CallDetectionHandler", "Error getting call number from call log", e)
            e.printStackTrace()
            null
        }
    }
}

