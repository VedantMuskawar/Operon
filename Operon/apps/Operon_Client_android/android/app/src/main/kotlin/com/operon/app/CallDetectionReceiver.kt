package com.operonclientandroid.app

import android.content.BroadcastReceiver
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.os.Build
import android.telephony.TelephonyManager
import android.util.Log
import java.io.File

/**
 * Listens for PHONE_STATE. On RINGING, stores incoming number (SharedPreferences + static)
 * and starts OverlayService directly so the Caller ID overlay is shown without launching
 * MainActivity (Android 14/15 compatibility).
 */
class CallDetectionReceiver : BroadcastReceiver() {

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != TelephonyManager.ACTION_PHONE_STATE_CHANGED) return
        val state = intent.getStringExtra(TelephonyManager.EXTRA_STATE) ?: return
        if (state != TelephonyManager.EXTRA_STATE_RINGING) return

        val number = intent.getStringExtra(TelephonyManager.EXTRA_INCOMING_NUMBER)
        val phone = number?.takeIf { it.isNotBlank() } ?: ""

        Log.d(TAG, "Incoming call: ${if (phone.isEmpty()) "(no number)" else phone}")

        pendingIncomingPhone = phone
        if (phone.isNotEmpty()) {
            storePhoneForOverlay(context, phone)
            storePhoneForOverlayFile(context, phone)
        }

        val serviceIntent = Intent().apply {
            component = ComponentName(context.packageName, OVERLAY_SERVICE_CLASS)
            putExtra(EXTRA_INCOMING_PHONE, phone)
        }
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(serviceIntent)
            } else {
                context.startService(serviceIntent)
            }
            Log.d(TAG, "Receiver: stored phone, started OverlayService")
        } catch (e: Exception) {
            Log.w(TAG, "Failed to start OverlayService", e)
        }

        // Avoid launching MainActivity on incoming calls to reduce startup overhead.
    }

    private fun storePhoneForOverlay(context: Context, phone: String) {
        try {
            val prefs = context.applicationContext.getSharedPreferences(PREFS_OVERLAY, Context.MODE_PRIVATE)
            prefs.edit().putString(KEY_PENDING_PHONE, phone).commit()
            Log.d(TAG, "Stored phone for overlay")
        } catch (e: Exception) {
            Log.w(TAG, "Failed to store phone for overlay", e)
        }
    }

    private fun storePhoneForOverlayFile(context: Context, phone: String) {
        try {
            val file = File(context.cacheDir, OVERLAY_PHONE_FILE)
            file.writeText(phone, Charsets.UTF_8)
            Log.d(TAG, "Stored phone for overlay file")
        } catch (e: Exception) {
            Log.w(TAG, "Failed to store phone for overlay file", e)
        }
    }

    companion object {
        private const val TAG = "CallDetectionReceiver"
        const val EXTRA_INCOMING_PHONE = "incoming_phone"
        /** Same store/key as Dart CallerOverlayService uses for overlay. */
        private const val PREFS_OVERLAY = "FlutterSharedPreferences"
        private const val KEY_PENDING_PHONE = "flutter.caller_overlay_pending_phone"
        const val OVERLAY_PHONE_FILE = "caller_overlay_phone.txt"
        private const val OVERLAY_SERVICE_CLASS = "flutter.overlay.window.flutter_overlay_window.OverlayService"

        @Volatile
        var pendingIncomingPhone: String? = null
            private set

        fun clearPending() {
            pendingIncomingPhone = null
        }
    }
}
