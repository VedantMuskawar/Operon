package com.operonclientandroid.app

import android.app.Service
import android.content.Context
import android.content.Intent
import android.graphics.PixelFormat
import android.os.Build
import android.os.IBinder
import android.view.Gravity
import android.view.LayoutInflater
import android.view.View
import android.view.ViewTreeObserver
import android.view.WindowManager
import android.widget.FrameLayout
import android.widget.TextView
import androidx.core.view.ViewCompat
import androidx.core.view.WindowInsetsCompat
import io.flutter.embedding.android.FlutterView
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.dart.DartExecutor

class OverlayHandler(private val context: Context) {
    private var overlayView: View? = null
    private var windowManager: WindowManager? = null
    private var isOverlayVisible = false

    fun showOverlay(
        clientId: String,
        clientName: String,
        clientPhone: String,
        pendingOrders: List<*>?,
        completedOrders: List<*>?
    ): Boolean {
        android.util.Log.d("OverlayHandler", "showOverlay called")
        android.util.Log.d("OverlayHandler", "Client: $clientName, Phone: $clientPhone")
        android.util.Log.d("OverlayHandler", "Pending orders: ${pendingOrders?.size ?: 0}")
        android.util.Log.d("OverlayHandler", "Completed orders: ${completedOrders?.size ?: 0}")

        if (isOverlayVisible) {
            android.util.Log.d("OverlayHandler", "Overlay already visible, hiding first")
            hideOverlay()
        }

        try {
            windowManager = context.getSystemService(Context.WINDOW_SERVICE) as WindowManager
            android.util.Log.d("OverlayHandler", "WindowManager obtained")

            val windowType = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                android.util.Log.d("OverlayHandler", "Using TYPE_APPLICATION_OVERLAY (API >= 26)")
                WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
            } else {
                android.util.Log.d("OverlayHandler", "Using TYPE_PHONE (API < 26)")
                WindowManager.LayoutParams.TYPE_PHONE
            }

            val screenWidth = context.resources.displayMetrics.widthPixels
            val overlayWidth = (screenWidth * 0.85).toInt().coerceAtMost(400)
            
            val params = WindowManager.LayoutParams(
                overlayWidth,
                WindowManager.LayoutParams.WRAP_CONTENT,
                windowType,
                WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                        WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN or
                        WindowManager.LayoutParams.FLAG_HARDWARE_ACCELERATED,
                PixelFormat.TRANSLUCENT
            )

            params.gravity = Gravity.TOP or Gravity.END
            params.x = 16 // Add some margin from edge
            params.y = 100
            params.alpha = 1.0f
            params.format = PixelFormat.TRANSLUCENT

            android.util.Log.d("OverlayHandler", "Creating overlay view...")
            overlayView = createOverlayView(clientName, clientPhone, pendingOrders, completedOrders)
            
            // Measure and layout the view before adding
            val widthSpec = View.MeasureSpec.makeMeasureSpec(params.width, View.MeasureSpec.EXACTLY)
            val heightSpec = View.MeasureSpec.makeMeasureSpec(0, View.MeasureSpec.UNSPECIFIED)
            overlayView?.measure(widthSpec, heightSpec)
            overlayView?.layout(0, 0, overlayView?.measuredWidth ?: params.width, overlayView?.measuredHeight ?: 0)
            
            android.util.Log.d("OverlayHandler", "View measured: ${overlayView?.measuredWidth}x${overlayView?.measuredHeight}")
            android.util.Log.d("OverlayHandler", "Adding view to WindowManager with params: width=${params.width}, type=${params.type}, flags=${params.flags}")

            try {
                windowManager?.addView(overlayView, params)
                isOverlayVisible = true
                android.util.Log.d("OverlayHandler", "Overlay shown successfully")
                
                // Post a check to verify the view is still attached
                overlayView?.postDelayed({
                    val isAttached = overlayView?.isAttachedToWindow == true
                    android.util.Log.d("OverlayHandler", "Overlay attachment check (1s): $isAttached")
                    if (!isAttached) {
                        android.util.Log.e("OverlayHandler", "Overlay view was detached! Checking WindowManager...")
                        // Try to re-add if it was detached
                        try {
                            if (overlayView != null && windowManager != null) {
                                windowManager?.addView(overlayView, params)
                                android.util.Log.d("OverlayHandler", "Re-added overlay view")
                            }
                        } catch (e: Exception) {
                            android.util.Log.e("OverlayHandler", "Failed to re-add overlay", e)
                        }
                    }
                }, 1000)
                
                return true
            } catch (e: Exception) {
                android.util.Log.e("OverlayHandler", "Exception while adding view to WindowManager", e)
                android.util.Log.e("OverlayHandler", "Exception type: ${e.javaClass.simpleName}")
                android.util.Log.e("OverlayHandler", "Exception message: ${e.message}")
                e.printStackTrace()
                return false
            }
        } catch (e: Exception) {
            android.util.Log.e("OverlayHandler", "Error showing overlay", e)
            e.printStackTrace()
            return false
        }
    }

    private fun createOverlayView(
        clientName: String,
        clientPhone: String,
        pendingOrders: List<*>?,
        completedOrders: List<*>?
    ): View {
        android.util.Log.d("OverlayHandler", "Creating overlay view...")
        
        val frameLayout = FrameLayout(context)
        val frameParams = FrameLayout.LayoutParams(
            FrameLayout.LayoutParams.MATCH_PARENT,
            FrameLayout.LayoutParams.WRAP_CONTENT
        )
        frameLayout.layoutParams = frameParams
        frameLayout.setBackgroundColor(0xFF1B1B2C.toInt()) // Dark background
        frameLayout.setPadding(16, 16, 16, 16)
        frameLayout.elevation = 10f
        
        // Create a LinearLayout for better structure
        val linearLayout = android.widget.LinearLayout(context)
        linearLayout.orientation = android.widget.LinearLayout.VERTICAL
        val linearParams = FrameLayout.LayoutParams(
            FrameLayout.LayoutParams.MATCH_PARENT,
            FrameLayout.LayoutParams.WRAP_CONTENT
        )
        linearLayout.layoutParams = linearParams
        
        // Client name
        val nameTextView = TextView(context)
        nameTextView.text = clientName
        nameTextView.setTextColor(0xFFFFFFFF.toInt())
        nameTextView.textSize = 18f
        nameTextView.setTypeface(null, android.graphics.Typeface.BOLD)
        nameTextView.setPadding(0, 0, 0, 8)
        linearLayout.addView(nameTextView)
        
        // Phone number
        val phoneTextView = TextView(context)
        phoneTextView.text = clientPhone
        phoneTextView.setTextColor(0xFFFFFFFF.toInt())
        phoneTextView.textSize = 14f
        phoneTextView.setPadding(0, 0, 0, 16)
        linearLayout.addView(phoneTextView)
        
        // Pending orders
        if (pendingOrders != null && pendingOrders.isNotEmpty()) {
            val pendingTextView = TextView(context)
            pendingTextView.text = "Pending Orders: ${pendingOrders.size}"
            pendingTextView.setTextColor(0xFFFF9800.toInt())
            pendingTextView.textSize = 12f
            pendingTextView.setPadding(0, 0, 0, 8)
            linearLayout.addView(pendingTextView)
        }
        
        // Completed orders
        if (completedOrders != null && completedOrders.isNotEmpty()) {
            val completedTextView = TextView(context)
            completedTextView.text = "Completed Orders: ${completedOrders.size}"
            completedTextView.setTextColor(0xFF4CAF50.toInt())
            completedTextView.textSize = 12f
            linearLayout.addView(completedTextView)
        }
        
        frameLayout.addView(linearLayout)
        
        // Add close button
        val closeButton = TextView(context)
        closeButton.text = "✕"
        closeButton.setTextColor(0xFFFFFFFF.toInt())
        closeButton.textSize = 20f
        closeButton.setPadding(8, 8, 8, 8)
        closeButton.gravity = android.view.Gravity.END
        closeButton.setOnClickListener {
            android.util.Log.d("OverlayHandler", "Close button clicked")
            hideOverlay()
        }
        
        val closeButtonParams = FrameLayout.LayoutParams(
            FrameLayout.LayoutParams.WRAP_CONTENT,
            FrameLayout.LayoutParams.WRAP_CONTENT
        )
        closeButtonParams.gravity = android.view.Gravity.END or android.view.Gravity.TOP
        frameLayout.addView(closeButton, closeButtonParams)
        
        // Make the view clickable but not focusable to prevent issues
        frameLayout.isClickable = true
        frameLayout.isFocusable = false
        frameLayout.isFocusableInTouchMode = false
        
        // Add a ViewTreeObserver to ensure proper layout
        frameLayout.viewTreeObserver.addOnGlobalLayoutListener(object : ViewTreeObserver.OnGlobalLayoutListener {
            override fun onGlobalLayout() {
                android.util.Log.d("OverlayHandler", "Overlay view laid out: ${frameLayout.width}x${frameLayout.height}")
                frameLayout.viewTreeObserver.removeOnGlobalLayoutListener(this)
            }
        })
        
        android.util.Log.d("OverlayHandler", "Overlay view created successfully")
        return frameLayout
    }

    fun hideOverlay() {
        android.util.Log.d("OverlayHandler", "hideOverlay called")
        try {
            overlayView?.let { view ->
                android.util.Log.d("OverlayHandler", "Removing overlay view")
                windowManager?.removeView(view)
                overlayView = null
            }
            isOverlayVisible = false
            android.util.Log.d("OverlayHandler", "Overlay hidden successfully")
        } catch (e: Exception) {
            android.util.Log.e("OverlayHandler", "Error hiding overlay", e)
            e.printStackTrace()
        }
    }

    fun isOverlayVisible(): Boolean {
        android.util.Log.d("OverlayHandler", "isOverlayVisible: $isOverlayVisible")
        return isOverlayVisible
    }
}
