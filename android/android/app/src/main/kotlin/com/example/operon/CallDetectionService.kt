package com.example.operon

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.IBinder
import android.util.Log
import androidx.core.app.NotificationCompat
import io.flutter.plugin.common.MethodChannel
import org.json.JSONArray
import org.json.JSONObject

class CallDetectionService : Service() {
    
    companion object {
        private const val TAG = "CallDetectionService"
        private const val CHANNEL_ID = "call_detection_channel"
        private const val NOTIFICATION_ID = 1001
        private const val METHOD_CHANNEL_NAME = "com.example.operon/call_detection"
        private const val NATIVE_OVERLAY_CHANNEL_NAME = "com.example.operon/native_overlay"
        
        @Volatile
        private var methodChannel: MethodChannel? = null
        @Volatile
        private var nativeOverlayChannel: MethodChannel? = null
        private var currentPhoneNumber: String? = null
        
        fun setMethodChannel(channel: MethodChannel) {
            methodChannel = channel
        }
        
        fun setNativeOverlayChannel(channel: MethodChannel) {
            nativeOverlayChannel = channel
        }
        
        fun handleIncomingCall(context: Context, phoneNumber: String) {
            Log.d(TAG, "Handling incoming call: $phoneNumber")
            currentPhoneNumber = phoneNumber
            
            // Send phone number to Flutter (only if channel is available)
            // Don't start service here - it's already running if needed
            if (methodChannel == null) {
                Log.w(TAG, "Method channel is null! Cannot send call event to Flutter.")
                return
            }
            
            try {
                Log.d(TAG, "Invoking method channel with phone number: $phoneNumber")
                methodChannel?.invokeMethod("onIncomingCall", mapOf(
                    "phoneNumber" to phoneNumber
                ))
                Log.d(TAG, "Method channel invoked successfully")
            } catch (e: Exception) {
                Log.e(TAG, "Error invoking method channel: ${e.message}", e)
            }
        }
        
        fun handleCallOffhook(context: Context) {
            Log.d(TAG, "Call offhook")
            try {
                methodChannel?.invokeMethod("onCallOffhook", null)
            } catch (e: Exception) {
                Log.e(TAG, "Error invoking method channel: ${e.message}")
            }
        }
        
        fun handleCallEnded(context: Context) {
            Log.d(TAG, "Call ended")
            currentPhoneNumber = null
            try {
                methodChannel?.invokeMethod("onCallEnded", null)
            } catch (e: Exception) {
                Log.e(TAG, "Error invoking method channel: ${e.message}")
            }
            // Hide native overlay
            SystemOverlayManager.getInstance(context).hideOverlay()
        }
        
        fun showNativeOverlay(context: Context, phoneNumber: String, clientName: String?, ordersJson: String) {
            try {
                Log.d(TAG, "Showing native overlay for: $phoneNumber")
                
                // Parse orders from JSON
                val orders = mutableListOf<SystemOverlayManager.OrderInfo>()
                if (ordersJson.isNotEmpty()) {
                    val jsonArray = JSONArray(ordersJson)
                    for (i in 0 until jsonArray.length()) {
                        val orderObj = jsonArray.getJSONObject(i)
                        orders.add(
                            SystemOverlayManager.OrderInfo(
                                orderId = orderObj.getString("orderId"),
                                placedDate = orderObj.getString("placedDate"),
                                location = orderObj.getString("location"),
                                trips = orderObj.getInt("trips")
                            )
                        )
                    }
                }
                
                SystemOverlayManager.getInstance(context).showOverlay(phoneNumber, clientName, orders)
            } catch (e: Exception) {
                Log.e(TAG, "Error showing native overlay: ${e.message}", e)
            }
        }
        
        fun hideNativeOverlay(context: Context) {
            try {
                SystemOverlayManager.getInstance(context).hideOverlay()
            } catch (e: Exception) {
                Log.e(TAG, "Error hiding native overlay: ${e.message}", e)
            }
        }
    }
    
    override fun onCreate() {
        super.onCreate()
        Log.d(TAG, "Service created")
        
        createNotificationChannel()
        initializeFlutterEngine()
    }
    
    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        Log.d(TAG, "Service started")
        
        // Only start foreground if we successfully can
        // If not, run as regular service (works for call detection via BroadcastReceiver)
        try {
            val notification = createNotification()
            startForeground(NOTIFICATION_ID, notification)
        } catch (e: SecurityException) {
            Log.w(TAG, "Cannot start foreground service: ${e.message}. Running as regular service.")
            // BroadcastReceiver will still work without foreground service
            // The service is mainly for keeping method channel alive
            return START_STICKY
        } catch (e: Exception) {
            Log.e(TAG, "Error starting service: ${e.message}", e)
            return START_STICKY
        }
        
        return START_STICKY
    }
    
    override fun onBind(intent: Intent?): IBinder? {
        return null
    }
    
    override fun onDestroy() {
        super.onDestroy()
        Log.d(TAG, "Service destroyed")
    }
    
    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Call Detection Service",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Service for detecting incoming calls"
                setShowBadge(false)
            }
            
            val notificationManager = getSystemService(NotificationManager::class.java)
            notificationManager.createNotificationChannel(channel)
        }
    }
    
    private fun createNotification(): Notification {
        // Use app icon or a default system icon
        val iconId = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            android.R.drawable.ic_dialog_info
        } else {
            android.R.drawable.ic_menu_call
        }
        
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("Call Detection Active")
            .setContentText("Monitoring incoming calls for pending orders")
            .setSmallIcon(iconId)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setOngoing(true)
            .build()
    }
    
    private fun initializeFlutterEngine() {
        // Method channel is set by MainActivity
        // This method is kept for future use if needed
        Log.d(TAG, "Service initialized, method channel should be set by MainActivity")
    }
}
