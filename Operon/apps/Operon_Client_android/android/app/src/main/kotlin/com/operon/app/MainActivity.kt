package com.operonclientandroid.app

import android.content.Intent
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    companion object {
        private const val TAG = "CallerOverlay"
        private const val CHANNEL = "operon.app/caller_overlay"
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
    }
}
