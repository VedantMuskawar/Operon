package com.operonclientandroid.app

import android.Manifest
import android.content.pm.PackageManager
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CALL_DETECTION_CHANNEL = "call_detection"
    private val CALL_OVERLAY_CHANNEL = "call_overlay"
    private var callDetectionHandler: CallDetectionHandler? = null
    private var overlayHandler: OverlayHandler? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Call Detection Channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CALL_DETECTION_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "startListening" -> {
                    if (checkPhonePermission()) {
                        callDetectionHandler = CallDetectionHandler(this, MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CALL_DETECTION_CHANNEL))
                        val success = callDetectionHandler?.startListening() ?: false
                        result.success(success)
                    } else {
                        requestPhonePermission()
                        result.success(false)
                    }
                }
                "stopListening" -> {
                    callDetectionHandler?.stopListening()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }

        // Call Overlay Channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CALL_OVERLAY_CHANNEL).setMethodCallHandler { call, result ->
            try {
                android.util.Log.d("CallOverlay", "Method called: ${call.method}")
                overlayHandler = overlayHandler ?: OverlayHandler(this)
                when (call.method) {
                    "showOverlay" -> {
                        android.util.Log.d("CallOverlay", "showOverlay called")
                        val args = call.arguments as? Map<*, *>
                        if (args != null) {
                            android.util.Log.d("CallOverlay", "Args received: clientName=${args["clientName"]}")
                            val success = overlayHandler?.showOverlay(
                                clientId = args["clientId"] as? String ?: "",
                                clientName = args["clientName"] as? String ?: "",
                                clientPhone = args["clientPhone"] as? String ?: "",
                                pendingOrders = args["pendingOrders"] as? List<*>,
                                completedOrders = args["completedOrders"] as? List<*>
                            ) ?: false
                            android.util.Log.d("CallOverlay", "showOverlay result: $success")
                            result.success(success)
                        } else {
                            android.util.Log.e("CallOverlay", "showOverlay: No arguments provided")
                            result.success(false)
                        }
                    }
                    "hideOverlay" -> {
                        android.util.Log.d("CallOverlay", "hideOverlay called")
                        overlayHandler?.hideOverlay()
                        result.success(true)
                    }
                    "isOverlayVisible" -> {
                        val visible = overlayHandler?.isOverlayVisible() ?: false
                        android.util.Log.d("CallOverlay", "isOverlayVisible: $visible")
                        result.success(visible)
                    }
                    else -> {
                        android.util.Log.w("CallOverlay", "Unknown method: ${call.method}")
                        result.notImplemented()
                    }
                }
            } catch (e: Exception) {
                android.util.Log.e("CallOverlay", "Error in method call handler", e)
                result.error("ERROR", e.message, e.stackTraceToString())
            }
        }
    }

    private fun checkPhonePermission(): Boolean {
        return ContextCompat.checkSelfPermission(
            this,
            Manifest.permission.READ_PHONE_STATE
        ) == PackageManager.PERMISSION_GRANTED
    }

    private fun requestPhonePermission() {
        ActivityCompat.requestPermissions(
            this,
            arrayOf(Manifest.permission.READ_PHONE_STATE),
            1001
        )
    }

    override fun onDestroy() {
        super.onDestroy()
        callDetectionHandler?.stopListening()
        overlayHandler?.hideOverlay()
    }
}
