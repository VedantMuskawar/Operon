package com.example.operon

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Context
import android.content.Intent
import android.location.Location
import android.os.Build
import android.os.IBinder
import android.os.Looper
import android.util.Log
import androidx.core.app.NotificationCompat
import androidx.core.content.ContextCompat
import com.google.android.gms.location.LocationCallback
import com.google.android.gms.location.LocationRequest
import com.google.android.gms.location.LocationResult
import com.google.android.gms.location.LocationServices
import com.google.android.gms.location.Priority
import com.google.firebase.FirebaseApp
import com.google.firebase.Timestamp
import com.google.firebase.firestore.ktx.firestore
import com.google.firebase.ktx.Firebase
import java.util.Date

class TripTrackingService : Service() {

    companion object {
        private const val TAG = "TripTrackingService"
        private const val CHANNEL_ID = "trip_tracking_channel"
        private const val CHANNEL_NAME = "Trip Tracking"
        private const val NOTIFICATION_ID = 7042

        private const val ACTION_START = "com.example.operon.action.START_TRIP_TRACKING"
        private const val ACTION_STOP = "com.example.operon.action.STOP_TRIP_TRACKING"

        private const val EXTRA_SCHEDULE_ID = "extra_schedule_id"
        private const val EXTRA_VEHICLE_LABEL = "extra_vehicle_label"

        private const val MIN_UPLOAD_INTERVAL_MS = 30_000L

        fun start(
            context: Context,
            scheduleId: String,
            vehicleLabel: String?
        ) {
            val intent = Intent(context, TripTrackingService::class.java).apply {
                action = ACTION_START
                putExtra(EXTRA_SCHEDULE_ID, scheduleId)
                putExtra(EXTRA_VEHICLE_LABEL, vehicleLabel)
            }

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                ContextCompat.startForegroundService(context, intent)
            } else {
                context.startService(intent)
            }
        }

        fun stop(
            context: Context,
            scheduleId: String?
        ) {
            val intent = Intent(context, TripTrackingService::class.java).apply {
                action = ACTION_STOP
                scheduleId?.let { putExtra(EXTRA_SCHEDULE_ID, it) }
            }

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                ContextCompat.startForegroundService(context, intent)
            } else {
                context.startService(intent)
            }
        }
    }

    private val firestore by lazy { Firebase.firestore }
    private val fusedClient by lazy { LocationServices.getFusedLocationProviderClient(this) }

    private var scheduleId: String? = null
    private var vehicleLabel: String? = null
    private var lastLoggedAt: Long = 0L

    private val locationCallback = object : LocationCallback() {
        override fun onLocationResult(result: LocationResult) {
            val schedule = scheduleId ?: return
            val now = System.currentTimeMillis()

            if (now - lastLoggedAt < MIN_UPLOAD_INTERVAL_MS) {
                return
            }

            val location = result.lastLocation ?: return
            lastLoggedAt = now
            persistLocation(schedule, location)
        }
    }

    override fun onCreate() {
        super.onCreate()
        if (FirebaseApp.getApps(this).isEmpty()) {
            FirebaseApp.initializeApp(this)
        }
        createNotificationChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_START -> handleStart(intent)
            ACTION_STOP -> handleStop(intent)
            else -> Log.w(TAG, "Received unknown intent action: ${intent?.action}")
        }
        return START_STICKY
    }

    private fun handleStart(intent: Intent) {
        val requestedScheduleId = intent.getStringExtra(EXTRA_SCHEDULE_ID)
        if (requestedScheduleId.isNullOrBlank()) {
            Log.e(TAG, "Cannot start tracking without schedule ID")
            stopSelf()
            return
        }

        if (!hasLocationPermission()) {
            Log.w(TAG, "Location permission missing. Stopping service.")
            stopSelf()
            return
        }

        val requestedVehicleLabel = intent.getStringExtra(EXTRA_VEHICLE_LABEL)

        if (requestedScheduleId != scheduleId) {
            stopLocationUpdates()
            scheduleId = requestedScheduleId
            lastLoggedAt = 0L
        }

        vehicleLabel = requestedVehicleLabel

        val notification = buildNotification()
        try {
            startForeground(NOTIFICATION_ID, notification)
        } catch (error: SecurityException) {
            Log.e(TAG, "Unable to start foreground service: ${error.message}", error)
            stopSelf()
            return
        }

        requestLocationUpdates()
    }

    private fun handleStop(intent: Intent) {
        val stopForSchedule = intent.getStringExtra(EXTRA_SCHEDULE_ID)
        if (stopForSchedule != null && stopForSchedule != scheduleId) {
            Log.d(TAG, "Stop ignored. Current schedule $scheduleId does not match $stopForSchedule")
            return
        }

        stopLocationUpdates()
        stopForeground(STOP_FOREGROUND_DETACH)
        stopSelf()
    }

    private fun requestLocationUpdates() {
        if (!hasLocationPermission()) {
            Log.w(TAG, "Location permission missing when requesting updates.")
            stopForeground(STOP_FOREGROUND_REMOVE)
            stopSelf()
            return
        }

        val locationRequest = LocationRequest.Builder(
            Priority.PRIORITY_HIGH_ACCURACY,
            MIN_UPLOAD_INTERVAL_MS
        ).apply {
            setMinUpdateIntervalMillis(MIN_UPLOAD_INTERVAL_MS)
            setMinUpdateDistanceMeters(0f)
        }.build()

        try {
            fusedClient.requestLocationUpdates(
                locationRequest,
                locationCallback,
                Looper.getMainLooper()
            )
            Log.d(TAG, "Location updates requested for schedule $scheduleId")
        } catch (error: SecurityException) {
            Log.e(TAG, "Permission error requesting updates: ${error.message}", error)
            stopForeground(STOP_FOREGROUND_REMOVE)
            stopSelf()
        } catch (error: Exception) {
            Log.e(TAG, "Unexpected error requesting updates: ${error.message}", error)
            stopForeground(STOP_FOREGROUND_REMOVE)
            stopSelf()
        }
    }

    private fun stopLocationUpdates() {
        fusedClient.removeLocationUpdates(locationCallback)
        Log.d(TAG, "Location updates stopped")
    }

    private fun persistLocation(scheduleId: String, location: Location) {
        val data = mutableMapOf<String, Any>(
            "latitude" to location.latitude,
            "longitude" to location.longitude,
            "recordedAt" to Timestamp(Date()),
            "source" to "android"
        )
        if (location.hasAccuracy()) {
            data["accuracy"] = location.accuracy.toDouble()
        }
        if (location.hasSpeed()) {
            data["speed"] = location.speed.toDouble()
        }
        if (location.hasBearing()) {
            data["heading"] = location.bearing.toDouble()
        }
        if (location.hasAltitude()) {
            data["altitude"] = location.altitude
        }

        firestore.collection("SCH_ORDERS")
            .document(scheduleId)
            .collection("TRIP_LOCATIONS")
            .add(data)
            .addOnSuccessListener {
                Log.d(TAG, "Location logged for schedule $scheduleId")
            }
            .addOnFailureListener { error ->
                Log.e(TAG, "Failed to log location: ${error.message}", error)
            }
    }

    private fun hasLocationPermission(): Boolean {
        val fineGranted = ContextCompat.checkSelfPermission(
            this,
            android.Manifest.permission.ACCESS_FINE_LOCATION
        ) == android.content.pm.PackageManager.PERMISSION_GRANTED

        val coarseGranted = ContextCompat.checkSelfPermission(
            this,
            android.Manifest.permission.ACCESS_COARSE_LOCATION
        ) == android.content.pm.PackageManager.PERMISSION_GRANTED

        return fineGranted || coarseGranted
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
            return
        }

        val manager = getSystemService(NotificationManager::class.java)
        val channel = NotificationChannel(
            CHANNEL_ID,
            CHANNEL_NAME,
            NotificationManager.IMPORTANCE_LOW
        ).apply {
            description = "Foreground service channel for trip GPS tracking"
            setShowBadge(false)
        }

        manager.createNotificationChannel(channel)
    }

    private fun buildNotification(): Notification {
        val label = vehicleLabel ?: scheduleId ?: "Trip"
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("Tracking active")
            .setContentText("Sharing GPS updates for $label every 30 seconds")
            .setSmallIcon(android.R.drawable.ic_menu_mylocation)
            .setOngoing(true)
            .setCategory(NotificationCompat.CATEGORY_SERVICE)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .build()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onDestroy() {
        super.onDestroy()
        stopLocationUpdates()
        Log.d(TAG, "Trip tracking service destroyed")
    }
}

