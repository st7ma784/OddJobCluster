package com.cluster.node

import android.content.Intent
import android.os.Bundle
import android.widget.Button
import android.widget.TextView
import android.widget.Switch
import android.widget.EditText
import androidx.appcompat.app.AppCompatActivity
import androidx.lifecycle.lifecycleScope
import kotlinx.coroutines.launch
import kotlinx.coroutines.delay
import android.content.Context
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import android.os.PowerManager
import android.provider.Settings
import android.content.SharedPreferences

class MainActivity : AppCompatActivity() {
    
    private lateinit var statusText: TextView
    private lateinit var deviceInfoText: TextView
    private lateinit var logText: TextView
    private lateinit var serviceSwitch: Switch
    private lateinit var clusterUrlEdit: EditText
    private lateinit var connectButton: Button
    private lateinit var benchmarkButton: Button
    
    private lateinit var preferences: SharedPreferences
    private var clusterNodeService: Intent? = null
    
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_main)
        
        initializeViews()
        setupPreferences()
        setupEventListeners()
        updateDeviceInfo()
        startStatusUpdates()
        
        // Check battery optimization
        checkBatteryOptimization()
    }
    
    private fun initializeViews() {
        statusText = findViewById(R.id.statusText)
        deviceInfoText = findViewById(R.id.deviceInfoText)
        logText = findViewById(R.id.logText)
        serviceSwitch = findViewById(R.id.serviceSwitch)
        clusterUrlEdit = findViewById(R.id.clusterUrlEdit)
        connectButton = findViewById(R.id.connectButton)
        benchmarkButton = findViewById(R.id.benchmarkButton)
    }
    
    private fun setupPreferences() {
        preferences = getSharedPreferences("cluster_node_prefs", Context.MODE_PRIVATE)
        
        // Load saved cluster URL
        val savedUrl = preferences.getString("cluster_url", "ws://192.168.1.100:8080/android")
        clusterUrlEdit.setText(savedUrl)
    }
    
    private fun setupEventListeners() {
        serviceSwitch.setOnCheckedChangeListener { _, isChecked ->
            if (isChecked) {
                startClusterService()
            } else {
                stopClusterService()
            }
        }
        
        connectButton.setOnClickListener {
            val clusterUrl = clusterUrlEdit.text.toString()
            if (clusterUrl.isNotEmpty()) {
                // Save URL to preferences
                preferences.edit().putString("cluster_url", clusterUrl).apply()
                
                // Start service with new URL
                if (serviceSwitch.isChecked) {
                    stopClusterService()
                    startClusterService()
                } else {
                    serviceSwitch.isChecked = true
                }
            }
        }
        
        benchmarkButton.setOnClickListener {
            runLocalBenchmark()
        }
    }
    
    private fun startClusterService() {
        val clusterUrl = clusterUrlEdit.text.toString()
        
        clusterNodeService = Intent(this, ClusterNodeService::class.java).apply {
            putExtra("cluster_url", clusterUrl)
        }
        
        startForegroundService(clusterNodeService)
        addLog("🚀 Starting cluster node service...")
        addLog("🔗 Cluster URL: $clusterUrl")
    }
    
    private fun stopClusterService() {
        clusterNodeService?.let {
            stopService(it)
            addLog("⏹️ Stopping cluster node service...")
        }
    }
    
    private fun updateDeviceInfo() {
        val deviceInfo = StringBuilder()
        
        // Basic device information
        deviceInfo.append("📱 Device: ${android.os.Build.MODEL}\n")
        deviceInfo.append("🏗️ Manufacturer: ${android.os.Build.MANUFACTURER}\n")
        deviceInfo.append("📋 Android: ${android.os.Build.VERSION.RELEASE}\n")
        deviceInfo.append("🏛️ Architecture: ${System.getProperty("os.arch")}\n")
        
        // CPU information
        val cores = Runtime.getRuntime().availableProcessors()
        deviceInfo.append("⚙️ CPU Cores: $cores\n")
        
        // Memory information
        val activityManager = getSystemService(Context.ACTIVITY_SERVICE) as android.app.ActivityManager
        val memInfo = android.app.ActivityManager.MemoryInfo()
        activityManager.getMemoryInfo(memInfo)
        val totalMemMB = memInfo.totalMem / (1024 * 1024)
        deviceInfo.append("💾 RAM: ${totalMemMB}MB\n")
        
        // Network information
        val networkInfo = getNetworkInfo()
        deviceInfo.append("🌐 Network: $networkInfo\n")
        
        deviceInfoText.text = deviceInfo.toString()
    }
    
    private fun getNetworkInfo(): String {
        val connectivityManager = getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
        val activeNetwork = connectivityManager.activeNetwork
        val networkCapabilities = connectivityManager.getNetworkCapabilities(activeNetwork)
        
        return when {
            networkCapabilities?.hasTransport(NetworkCapabilities.TRANSPORT_WIFI) == true -> "WiFi"
            networkCapabilities?.hasTransport(NetworkCapabilities.TRANSPORT_CELLULAR) == true -> "Mobile"
            networkCapabilities?.hasTransport(NetworkCapabilities.TRANSPORT_ETHERNET) == true -> "Ethernet"
            else -> "Unknown"
        }
    }
    
    private fun startStatusUpdates() {
        lifecycleScope.launch {
            while (true) {
                updateStatus()
                delay(2000) // Update every 2 seconds
            }
        }
    }
    
    private fun updateStatus() {
        val isServiceRunning = ClusterNodeService.isServiceRunning
        val connectionStatus = ClusterNodeService.connectionStatus
        
        val statusBuilder = StringBuilder()
        statusBuilder.append("🤖 Service: ${if (isServiceRunning) "Running" else "Stopped"}\n")
        statusBuilder.append("🔗 Connection: $connectionStatus\n")
        
        if (isServiceRunning) {
            statusBuilder.append("📊 Tasks Processed: ${ClusterNodeService.tasksProcessed}\n")
            statusBuilder.append("⏱️ Uptime: ${formatUptime(ClusterNodeService.getUptime())}\n")
        }
        
        statusText.text = statusBuilder.toString()
        
        // Update service switch state
        serviceSwitch.isChecked = isServiceRunning
    }
    
    private fun formatUptime(uptimeMs: Long): String {
        val seconds = uptimeMs / 1000
        val minutes = seconds / 60
        val hours = minutes / 60
        
        return when {
            hours > 0 -> "${hours}h ${minutes % 60}m"
            minutes > 0 -> "${minutes}m ${seconds % 60}s"
            else -> "${seconds}s"
        }
    }
    
    private fun runLocalBenchmark() {
        addLog("🏃 Running local benchmark...")
        
        lifecycleScope.launch {
            val computeEngine = ComputeEngine()
            
            try {
                // CPU benchmark
                val cpuStart = System.currentTimeMillis()
                val primeResult = computeEngine.calculatePrimes(1, 10000)
                val cpuDuration = System.currentTimeMillis() - cpuStart
                
                addLog("🔢 Prime calculation: ${primeResult.count} primes in ${cpuDuration}ms")
                
                // Memory benchmark
                val memStart = System.currentTimeMillis()
                val matrixResult = computeEngine.multiplyMatrices(
                    arrayOf(arrayOf(1.0, 2.0), arrayOf(3.0, 4.0)),
                    arrayOf(arrayOf(5.0, 6.0), arrayOf(7.0, 8.0))
                )
                val memDuration = System.currentTimeMillis() - memStart
                
                addLog("🧮 Matrix multiplication in ${memDuration}ms")
                
                // Overall score
                val score = (10000.0 / cpuDuration) * 1000
                addLog("📊 Benchmark score: ${score.toInt()} points")
                
            } catch (e: Exception) {
                addLog("❌ Benchmark error: ${e.message}")
            }
        }
    }
    
    private fun checkBatteryOptimization() {
        val powerManager = getSystemService(Context.POWER_SERVICE) as PowerManager
        val packageName = packageName
        
        if (!powerManager.isIgnoringBatteryOptimizations(packageName)) {
            addLog("⚠️ Battery optimization enabled - may affect background operation")
            addLog("💡 Disable in Settings > Battery > Battery Optimization")
        } else {
            addLog("✅ Battery optimization disabled - background operation optimized")
        }
    }
    
    private fun addLog(message: String) {
        runOnUiThread {
            val timestamp = java.text.SimpleDateFormat("HH:mm:ss", java.util.Locale.getDefault())
                .format(java.util.Date())
            val logMessage = "[$timestamp] $message\n"
            
            logText.append(logMessage)
            
            // Scroll to bottom
            val scrollAmount = logText.layout?.getLineTop(logText.lineCount) ?: 0
            if (scrollAmount > logText.height) {
                logText.scrollTo(0, scrollAmount - logText.height)
            }
        }
    }
    
    override fun onDestroy() {
        super.onDestroy()
        if (serviceSwitch.isChecked) {
            // Keep service running even if activity is destroyed
            addLog("📱 App closed - service continues in background")
        }
    }
}
