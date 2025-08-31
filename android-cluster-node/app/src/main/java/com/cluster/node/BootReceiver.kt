package com.cluster.node

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log

class BootReceiver : BroadcastReceiver() {
    
    companion object {
        private const val TAG = "ClusterBootReceiver"
    }
    
    override fun onReceive(context: Context, intent: Intent) {
        Log.d(TAG, "Received broadcast: ${intent.action}")
        
        when (intent.action) {
            Intent.ACTION_BOOT_COMPLETED,
            Intent.ACTION_MY_PACKAGE_REPLACED,
            Intent.ACTION_PACKAGE_REPLACED -> {
                
                // Check if auto-start is enabled in preferences
                val preferences = context.getSharedPreferences("cluster_node_prefs", Context.MODE_PRIVATE)
                val autoStart = preferences.getBoolean("auto_start_service", true)
                
                if (autoStart) {
                    Log.i(TAG, "Auto-starting cluster node service")
                    
                    try {
                        val serviceIntent = Intent(context, ClusterNodeService::class.java)
                        
                        // Get saved cluster URL
                        val clusterUrl = preferences.getString("cluster_url", "ws://192.168.1.100:8080/android")
                        serviceIntent.putExtra("cluster_url", clusterUrl)
                        serviceIntent.putExtra("auto_started", true)
                        
                        // Start foreground service
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                            context.startForegroundService(serviceIntent)
                        } else {
                            context.startService(serviceIntent)
                        }
                        
                        Log.i(TAG, "Cluster node service started successfully")
                        
                    } catch (e: Exception) {
                        Log.e(TAG, "Failed to start cluster node service", e)
                    }
                } else {
                    Log.i(TAG, "Auto-start disabled, not starting service")
                }
            }
        }
    }
}
