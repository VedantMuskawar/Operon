package com.example.operon

import android.content.Intent
import android.os.Bundle
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    
    private val METHOD_CHANNEL_NAME = "com.example.operon/call_detection"
    private val NATIVE_OVERLAY_CHANNEL_NAME = "com.example.operon/native_overlay"
    private val TRIP_TRACKING_CHANNEL_NAME = "com.example.operon/trip_tracking"
    private var methodChannel: MethodChannel? = null
    private var nativeOverlayChannel: MethodChannel? = null
    private var tripTrackingChannel: MethodChannel? = null
    
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        methodChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            METHOD_CHANNEL_NAME
        )
        
        // Native overlay channel - receives order data from Flutter
        nativeOverlayChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            NATIVE_OVERLAY_CHANNEL_NAME
        )
        
        nativeOverlayChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "showOverlay" -> {
                    val phoneNumber = call.argument<String>("phoneNumber") ?: ""
                    val clientName = call.argument<String>("clientName")
                    val ordersJson = call.argument<String>("ordersJson") ?: "[]"
                    
                    CallDetectionService.showNativeOverlay(
                        this,
                        phoneNumber,
                        clientName,
                        ordersJson
                    )
                    result.success(null)
                }
                "hideOverlay" -> {
                    CallDetectionService.hideNativeOverlay(this)
                    result.success(null)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
        
        // Store method channel reference in CallDetectionService
        CallDetectionService.setMethodChannel(methodChannel!!)
        
        // Start the call detection service after Flutter engine is ready
        startCallDetectionService()

        tripTrackingChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            TRIP_TRACKING_CHANNEL_NAME
        )

        tripTrackingChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "startTripTracking" -> {
                    val scheduleId = call.argument<String>("scheduleId")
                    if (scheduleId.isNullOrBlank()) {
                        result.error("invalid_args", "scheduleId is required", null)
                        return@setMethodCallHandler
                    }
                    val vehicleLabel = call.argument<String>("vehicleLabel")
                    TripTrackingService.start(
                        this,
                        scheduleId,
                        vehicleLabel
                    )
                    result.success(null)
                }

                "stopTripTracking" -> {
                    val scheduleId = call.argument<String>("scheduleId")
                    TripTrackingService.stop(this, scheduleId)
                    result.success(null)
                }

                else -> result.notImplemented()
            }
        }
    }
    
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // Don't start service here - wait for Flutter engine to be ready
    }
    
    private fun startCallDetectionService() {
        try {
            val intent = Intent(this, CallDetectionService::class.java)
            if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
                try {
                    startForegroundService(intent)
                } catch (e: SecurityException) {
                    // If foreground service fails, try regular service
                    Log.w("MainActivity", "Cannot start foreground service: ${e.message}. Starting regular service.")
                    startService(intent)
                }
            } else {
                startService(intent)
            }
        } catch (e: Exception) {
            Log.e("MainActivity", "Error starting call detection service: ${e.message}", e)
        }
    }
}
