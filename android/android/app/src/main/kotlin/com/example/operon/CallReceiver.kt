package com.example.operon

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.telephony.TelephonyManager
import android.util.Log

class CallReceiver : BroadcastReceiver() {
    
    companion object {
        private const val TAG = "CallReceiver"
    }
    
    override fun onReceive(context: Context, intent: Intent) {
        try {
            val state = intent.getStringExtra(TelephonyManager.EXTRA_STATE)
            val phoneNumber = intent.getStringExtra(TelephonyManager.EXTRA_INCOMING_NUMBER)
            
            Log.d(TAG, "Call state: $state, Phone number: $phoneNumber")
            
            when (state) {
                TelephonyManager.EXTRA_STATE_RINGING -> {
                    // Incoming call is ringing
                    if (phoneNumber != null) {
                        Log.d(TAG, "Incoming call from: $phoneNumber")
                        CallDetectionService.handleIncomingCall(context, phoneNumber)
                    }
                }
                TelephonyManager.EXTRA_STATE_OFFHOOK -> {
                    // Call answered or outgoing call started
                    Log.d(TAG, "Call answered/offhook")
                    CallDetectionService.handleCallOffhook(context)
                }
                TelephonyManager.EXTRA_STATE_IDLE -> {
                    // Call ended
                    Log.d(TAG, "Call ended")
                    CallDetectionService.handleCallEnded(context)
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error in CallReceiver: ${e.message}", e)
        }
    }
}
