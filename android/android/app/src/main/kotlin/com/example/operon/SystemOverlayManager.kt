package com.example.operon

import android.content.Context
import android.graphics.PixelFormat
import android.view.Gravity
import android.view.View
import android.view.WindowManager
import android.widget.LinearLayout
import android.widget.ScrollView
import android.widget.TextView
import android.util.Log
import android.os.Build
import android.provider.Settings
import java.text.SimpleDateFormat
import java.util.Locale

class SystemOverlayManager private constructor(private val context: Context) {
    
    companion object {
        private const val TAG = "SystemOverlayManager"
        private var instance: SystemOverlayManager? = null
        
        fun getInstance(context: Context): SystemOverlayManager {
            if (instance == null) {
                instance = SystemOverlayManager(context.applicationContext)
            }
            return instance!!
        }
    }
    
    private var windowManager: WindowManager? = null
    private var overlayView: View? = null
    private var params: WindowManager.LayoutParams? = null
    
    init {
        windowManager = context.getSystemService(Context.WINDOW_SERVICE) as? WindowManager
    }
    
    fun showOverlay(phoneNumber: String, clientName: String?, orders: List<OrderInfo>) {
        try {
            // Check if overlay permission is granted
            if (!canDrawOverlays()) {
                Log.w(TAG, "SYSTEM_ALERT_WINDOW permission not granted. Cannot show native overlay.")
                return
            }
            
            hideOverlay() // Remove existing overlay if any
            
            Log.d(TAG, "Showing system overlay for: $phoneNumber")
            
            // Create overlay layout
            overlayView = createOverlayView(phoneNumber, clientName, orders)
            
            // Set up window parameters for system overlay
            params = WindowManager.LayoutParams().apply {
                type = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
                } else {
                    @Suppress("DEPRECATION")
                    WindowManager.LayoutParams.TYPE_PHONE
                }
                
                format = PixelFormat.TRANSLUCENT
                flags = WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                        WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN or
                        WindowManager.LayoutParams.FLAG_LAYOUT_INSET_DECOR
                
                width = WindowManager.LayoutParams.MATCH_PARENT
                height = WindowManager.LayoutParams.WRAP_CONTENT
                gravity = Gravity.CENTER // Center the overlay
                x = 0
                y = 0
                
                // Set margins for better positioning (centered horizontally, slightly above center vertically)
                val screenHeight = context.resources.displayMetrics.heightPixels
                val screenWidth = context.resources.displayMetrics.widthPixels
                val overlayHeight = dpToPx(400) // Approximate height
                y = -(screenHeight / 4) // Position slightly above center
            }
            
            windowManager?.addView(overlayView, params)
            Log.d(TAG, "System overlay added successfully")
            
        } catch (e: Exception) {
            Log.e(TAG, "Error showing system overlay: ${e.message}", e)
        }
    }
    
    private fun canDrawOverlays(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            Settings.canDrawOverlays(context)
        } else {
            true // Pre-Marshmallow, permission is granted at install time
        }
    }
    
    fun hideOverlay() {
        try {
            overlayView?.let { view ->
                windowManager?.removeView(view)
                overlayView = null
                params = null
                Log.d(TAG, "System overlay removed")
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error hiding overlay: ${e.message}", e)
        }
    }
    
    private fun createOverlayView(phoneNumber: String, clientName: String?, orders: List<OrderInfo>): View {
        // Create scrollable container
        val scrollView = ScrollView(context).apply {
            val padding = dpToPx(20)
            setPadding(padding, padding, padding, padding)
        }
        
        // Create main container with card-like appearance
        val mainContainer = LinearLayout(context).apply {
            orientation = LinearLayout.VERTICAL
            val padding = dpToPx(20)
            setPadding(padding, padding, padding, padding)
            setBackgroundColor(0xFF161817.toInt()) // Dark background
        }
        
        // Header with phone icon and number
        val headerLayout = LinearLayout(context).apply {
            orientation = LinearLayout.HORIZONTAL
            val padding = dpToPx(8)
            setPadding(0, 0, 0, padding)
        }
        
        // Phone icon (using text emoji as fallback)
        val phoneIcon = TextView(context).apply {
            text = "📞"
            textSize = 24f
            val padding = dpToPx(8)
            setPadding(0, 0, padding, 0)
        }
        headerLayout.addView(phoneIcon)
        
        // Phone number and name container
        val infoContainer = LinearLayout(context).apply {
            orientation = LinearLayout.VERTICAL
        }
        
        // Phone number
        val phoneText = TextView(context).apply {
            text = phoneNumber
            textSize = 20f
            setTextColor(0xFFFFFFFF.toInt())
            setTypeface(null, android.graphics.Typeface.BOLD)
        }
        infoContainer.addView(phoneText)
        
        // Client name (if available)
        clientName?.let { name ->
            val nameText = TextView(context).apply {
                text = name
                textSize = 14f
                setTextColor(0xB3FFFFFF.toInt())
                val padding = dpToPx(4)
                setPadding(0, padding, 0, 0)
            }
            infoContainer.addView(nameText)
        }
        
        headerLayout.addView(infoContainer)
        mainContainer.addView(headerLayout)
        
        // Divider
        val divider = View(context).apply {
            setBackgroundColor(0x33FFFFFF.toInt())
            val height = dpToPx(1)
            val margin = dpToPx(16)
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                height
            ).apply {
                setMargins(0, margin, 0, margin)
            }
        }
        mainContainer.addView(divider)
        
        // Orders section
        if (orders.isEmpty()) {
            val noOrdersText = TextView(context).apply {
                text = "No pending orders"
                textSize = 14f
                setTextColor(0xB3FFFFFF.toInt())
                val padding = dpToPx(8)
                setPadding(0, padding, 0, 0)
            }
            mainContainer.addView(noOrdersText)
        } else {
            val ordersHeader = TextView(context).apply {
                text = "${orders.size} Pending Order${if (orders.size > 1) "s" else ""}"
                textSize = 16f
                setTextColor(0xFF667EEA.toInt()) // Primary color
                setTypeface(null, android.graphics.Typeface.BOLD)
                val padding = dpToPx(8)
                setPadding(0, 0, 0, padding)
            }
            mainContainer.addView(ordersHeader)
            
            orders.forEachIndexed { index, order ->
                val orderView = LinearLayout(context).apply {
                    orientation = LinearLayout.VERTICAL
                    val padding = dpToPx(12)
                    val margin = dpToPx(8)
                    setPadding(padding, padding, padding, padding)
                    setBackgroundColor(0xFF0A0A0A.toInt()) // Darker background for order items
                    layoutParams = LinearLayout.LayoutParams(
                        LinearLayout.LayoutParams.MATCH_PARENT,
                        LinearLayout.LayoutParams.WRAP_CONTENT
                    ).apply {
                        setMargins(0, 0, 0, margin)
                    }
                }
                
                // Date
                val dateText = TextView(context).apply {
                    text = "📅 Placed: ${formatDate(order.placedDate)}"
                    textSize = 13f
                    setTextColor(0xB3FFFFFF.toInt())
                    val padding = dpToPx(4)
                    setPadding(0, 0, 0, padding)
                }
                orderView.addView(dateText)
                
                // Location
                val locationText = TextView(context).apply {
                    text = "📍 Location: ${order.location}"
                    textSize = 13f
                    setTextColor(0xB3FFFFFF.toInt())
                    val padding = dpToPx(4)
                    setPadding(0, 0, 0, padding)
                }
                orderView.addView(locationText)
                
                // Trips
                val tripsText = TextView(context).apply {
                    text = "🚚 Trips: ${order.trips}"
                    textSize = 13f
                    setTextColor(0xB3FFFFFF.toInt())
                }
                orderView.addView(tripsText)
                
                mainContainer.addView(orderView)
            }
        }
        
        scrollView.addView(mainContainer)
        
        return scrollView
    }
    
    private fun formatDate(dateString: String): String {
        return try {
            // Date format from Flutter: ISO 8601 format (e.g., "2025-11-04T18:07:10.858Z")
            // Try multiple formats to handle different cases
            val formats = listOf(
                "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'",
                "yyyy-MM-dd'T'HH:mm:ss.SSS",
                "yyyy-MM-dd'T'HH:mm:ss'Z'",
                "yyyy-MM-dd'T'HH:mm:ss"
            )
            
            var date: java.util.Date? = null
            for (format in formats) {
                try {
                    val inputFormat = SimpleDateFormat(format, Locale.getDefault())
                    date = inputFormat.parse(dateString)
                    if (date != null) break
                } catch (e: Exception) {
                    // Try next format
                }
            }
            
            if (date != null) {
                val outputFormat = SimpleDateFormat("MMM dd, yyyy 'at' hh:mm a", Locale.getDefault())
                outputFormat.format(date)
            } else {
                // If parsing fails, return a cleaned version
                dateString.replace("T", " ").substringBefore(".")
            }
        } catch (e: Exception) {
            // Return original if parsing fails
            dateString.replace("T", " ").substringBefore(".")
        }
    }
    
    private fun dpToPx(dp: Int): Int {
        val density = context.resources.displayMetrics.density
        return (dp * density).toInt()
    }
    
    data class OrderInfo(
        val orderId: String,
        val placedDate: String,
        val location: String,
        val trips: Int
    )
}

