package com.operonclientandroid.app

import android.content.Intent
import android.util.Log
import com.operon.updater.AppUpdater
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    companion object {
        private const val TAG = "CallerOverlay"
        private const val CHANNEL = "operon.app/caller_overlay"
        private const val UPDATE_CHANNEL = "operon.app/app_updater"
        private const val DEFAULT_UPDATE_URL = "https://api.operon.com/updates/{app_name}.json"
    }

    private var pendingIncomingPhone: String? = null

    override fun onCreate(savedInstanceState: android.os.Bundle?) {
        super.onCreate(savedInstanceState)
        pendingIncomingPhone = intent?.getStringExtra(CallDetectionReceiver.EXTRA_INCOMING_PHONE)
            ?: CallDetectionReceiver.pendingIncomingPhone
        Log.d(TAG, "onCreate pendingPhone=${pendingIncomingPhone?.take(6) ?: "null"}...")
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        val phone = intent.getStringExtra(CallDetectionReceiver.EXTRA_INCOMING_PHONE)
            ?: CallDetectionReceiver.pendingIncomingPhone
        if (!phone.isNullOrEmpty()) {
            pendingIncomingPhone = phone
            Log.d(TAG, "onNewIntent pendingPhone=$phone")
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            Log.d(TAG, "method=${call.method}")
            when (call.method) {
                "getPendingIncomingCall" -> {
                    val phone = pendingIncomingPhone
                        ?: CallDetectionReceiver.pendingIncomingPhone
                    pendingIncomingPhone = null
                    CallDetectionReceiver.clearPending()
                    Log.d(TAG, "getPendingIncomingCall return=${phone?.take(6) ?: "null"}...")
                    result.success(phone?.takeIf { it.isNotEmpty() })
                }
                "getPendingIncomingCallPeek" -> {
                    val phone = pendingIncomingPhone
                        ?: CallDetectionReceiver.pendingIncomingPhone
                    Log.d(TAG, "getPendingIncomingCallPeek return=${phone?.take(6) ?: "null"}...")
                    result.success(phone?.takeIf { it.isNotEmpty() })
                }
                "clearPendingIncomingCall" -> {
                    pendingIncomingPhone = null
                    CallDetectionReceiver.clearPending()
                    Log.d(TAG, "clearPendingIncomingCall")
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, UPDATE_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "checkUpdate" -> {
                        val url = call.arguments as? String ?: DEFAULT_UPDATE_URL
                        AppUpdater.with(this).check(url)
                        result.success(null)
                    }
                    "hasInstallPermission" -> {
                        val hasPermission = AppUpdater.with(this).hasInstallPermission(this)
                        result.success(hasPermission)
                    }
                    "requestInstallPermission" -> {
                        AppUpdater.with(this).requestInstallPermission(this)
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
