package com.cluster.node

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import android.util.Log

class NetworkChangeReceiver : BroadcastReceiver() {
    
    companion object {
        private const val TAG = "NetworkChangeReceiver"
    }
    
    override fun onReceive(context: Context, intent: Intent) {
        Log.d(TAG, "Network change detected: ${intent.action}")
        
        val connectivityManager = context.getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
        val isConnected = isNetworkAvailable(connectivityManager)
        
        Log.i(TAG, "Network status: ${if (isConnected) "Connected" else "Disconnected"}")
        
        // Notify the cluster service about network changes
        val serviceIntent = Intent(context, ClusterNodeService::class.java)
        serviceIntent.putExtra("network_change", true)
        serviceIntent.putExtra("network_available", isConnected)
        
        try {
            context.startService(serviceIntent)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to notify service about network change", e)
        }
    }
    
    private fun isNetworkAvailable(connectivityManager: ConnectivityManager): Boolean {
        val activeNetwork = connectivityManager.activeNetwork ?: return false
        val networkCapabilities = connectivityManager.getNetworkCapabilities(activeNetwork) ?: return false
        
        return networkCapabilities.hasCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET) &&
               networkCapabilities.hasCapability(NetworkCapabilities.NET_CAPABILITY_VALIDATED)
    }
}
