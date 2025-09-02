package com.cluster.node

import android.content.Intent
import android.os.Bundle
import android.widget.Button
import android.widget.TextView
import com.google.android.material.switchmaterial.SwitchMaterial
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
    private lateinit var serviceSwitch: SwitchMaterial
    private lateinit var clusterUrlEdit: EditText
    private lateinit var connectButton: Button
    private lateinit var benchmarkButton: Button
    private lateinit var dashboardButton: Button
    private lateinit var kubernetesButton: Button
    private lateinit var slurmButton: Button
    private lateinit var clearLogButton: Button
    
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
        dashboardButton = findViewById(R.id.dashboardButton)
        kubernetesButton = findViewById(R.id.kubernetesButton)
        slurmButton = findViewById(R.id.slurmButton)
        clearLogButton = findViewById(R.id.clearLogButton)
    }
    
    private fun setupPreferences() {
        preferences = getSharedPreferences("cluster_node_prefs", Context.MODE_PRIVATE)
        
        // Load saved cluster URL
        val savedUrl = preferences.getString("cluster_url", "ws://192.168.5.55:8765")
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
        
        dashboardButton.setOnClickListener {
            openClusterDashboard()
        }
        
        kubernetesButton.setOnClickListener {
            testKubernetesIntegration()
        }
        
        slurmButton.setOnClickListener {
            testSlurmIntegration()
        }
        
        clearLogButton.setOnClickListener {
            clearLogs()
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
            val computeEngine = ComputeEngine(this@MainActivity)
            
            try {
                // CPU benchmark
                val cpuStart = System.currentTimeMillis()
                val primeResult = computeEngine.calculatePrimes(mapOf("start" to 1, "end" to 10000))
                val cpuDuration = System.currentTimeMillis() - cpuStart
                
                addLog("🔢 Prime calculation: ${primeResult["count"]} primes in ${cpuDuration}ms")
                
                // Memory benchmark
                val memStart = System.currentTimeMillis()
                val matrixResult = computeEngine.multiplyMatrices(mapOf("size" to 50))
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
    
    private fun openClusterDashboard() {
        val clusterUrl = clusterUrlEdit.text.toString()
        val dashboardUrl = clusterUrl.replace("ws://", "http://").replace(":8765", ":8080")
        
        try {
            val intent = Intent(Intent.ACTION_VIEW, android.net.Uri.parse(dashboardUrl))
            startActivity(intent)
            addLog("🌐 Opening cluster dashboard: $dashboardUrl")
        } catch (e: Exception) {
            addLog("❌ Failed to open dashboard: ${e.message}")
        }
    }
    
    private fun testKubernetesIntegration() {
        addLog("🚀 Testing Kubernetes integration...")
        
        lifecycleScope.launch {
            // First check if Termux is installed, install if needed
            if (!isTermuxInstalled()) {
                addLog("📦 Termux not found - installing automatically...")
                if (installTermux()) {
                    addLog("✅ Termux installation initiated")
                    addLog("⏱️ Please wait for installation to complete, then try again")
                } else {
                    addLog("❌ Failed to install Termux automatically")
                    addLog("💡 Please install Termux manually from F-Droid or GitHub")
                }
                return@launch
            }
            
            try {
                // Check if kubectl is already available and run test command
                val testCommand = "if command -v kubectl >/dev/null 2>&1; then " +
                        "echo '✅ kubectl found - running test...' && " +
                        "kubectl version --client && " +
                        "echo '🔧 Testing cluster connection...' && " +
                        "kubectl cluster-info --request-timeout=5s 2>/dev/null || echo '⚠️ No cluster configured (this is normal)' && " +
                        "echo '✅ kubectl test complete'; " +
                        "else " +
                        "echo '📦 kubectl not found - installing...' && " +
                        "pkg update -y && pkg install -y wget curl && " +
                        "wget https://dl.k8s.io/release/v1.28.0/bin/linux/arm64/kubectl -O \$PREFIX/bin/kubectl && " +
                        "chmod +x \$PREFIX/bin/kubectl && kubectl version --client && echo '✅ kubectl installation complete'; " +
                        "fi"
                
                // Copy command to clipboard and open Termux
                try {
                    val clipboard = getSystemService(Context.CLIPBOARD_SERVICE) as android.content.ClipboardManager
                    val clip = android.content.ClipData.newPlainText("kubectl_test", testCommand)
                    clipboard.setPrimaryClip(clip)
                    
                    val intent = Intent()
                    intent.setClassName("com.termux", "com.termux.app.TermuxActivity")
                    intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
                    startActivity(intent)
                    
                    addLog("✅ kubectl test command copied to clipboard")
                    addLog("📱 Termux opened - paste and run the command")
                    addLog("💡 Long press in Termux terminal and select 'Paste'")
                } catch (e: Exception) {
                    val intent = Intent()
                    intent.setClassName("com.termux", "com.termux.app.TermuxActivity")
                    intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
                    startActivity(intent)
                    
                    addLog("✅ Termux opened")
                    addLog("📝 Run this command manually:")
                    addLog("   $testCommand")
                }
                
            } catch (e: Exception) {
                addLog("❌ Kubernetes test failed: ${e.message}")
                addLog("💡 Make sure Termux is installed and accessible")
            }
        }
    }
    
    private fun copyInstallScriptToStorage() {
        try {
            val inputStream = assets.open("install_tools.sh")
            val externalDir = getExternalFilesDir(null)
            val scriptFile = java.io.File(externalDir, "install_tools.sh")
            
            scriptFile.outputStream().use { output ->
                inputStream.copyTo(output)
            }
            
            addLog("📄 Installation script copied to ${scriptFile.absolutePath}")
        } catch (e: Exception) {
            addLog("⚠️ Could not copy installation script: ${e.message}")
        }
    }
    
    private fun testSlurmIntegration() {
        addLog("⚡ Testing SLURM integration...")
        
        lifecycleScope.launch {
            // First check if Termux is installed, install if needed
            if (!isTermuxInstalled()) {
                addLog("📦 Termux not found - installing automatically...")
                if (installTermux()) {
                    addLog("✅ Termux installation initiated")
                    addLog("⏱️ Please wait for installation to complete, then try again")
                } else {
                    addLog("❌ Failed to install Termux automatically")
                    addLog("💡 Please install Termux manually from F-Droid or GitHub")
                }
                return@launch
            }
            
            try {
                // Check if SLURM is already available and run test command
                val testCommand = "if command -v sinfo >/dev/null 2>&1; then " +
                    "echo '✅ SLURM found - running test...' && " +
                    "sinfo --version && " +
                    "echo '🔧 Testing SLURM commands...' && " +
                    "sinfo -s 2>/dev/null || echo '⚠️ No SLURM cluster configured (this is normal)' && " +
                    "echo '📊 SLURM partitions:' && " +
                    "scontrol show partition 2>/dev/null || echo '⚠️ No partitions configured' && " +
                    "echo '🔐 Testing MUNGE authentication...' && " +
                    "if command -v munge >/dev/null 2>&1; then " +
                    "echo 'test' | munge | unmunge && echo '✅ MUNGE working' || echo '❌ MUNGE failed'; " +
                    "else echo '⚠️ MUNGE not installed'; fi && " +
                    "echo '✅ SLURM test complete'; " +
                    "else " +
                    "echo '📦 SLURM not found - installing with MUNGE (15-20 minutes)...' && " +
                    "pkg update -y && pkg install -y make clang binutils autoconf automake libtool git wget curl openssl-tool && " +
                    "echo '🔐 Installing and setting up MUNGE...' && " +
                    "pkg install -y munge || (echo '📦 Building MUNGE from source...' && " +
                    "cd \$HOME && git clone https://github.com/dun/munge.git && cd munge && " +
                    "./bootstrap && ./configure --prefix=\$PREFIX --sysconfdir=\$PREFIX/etc && " +
                    "make && make install) && " +
                    "echo '🔑 Setting up MUNGE key and daemon...' && " +
                    "mkdir -p \$PREFIX/etc/munge \$PREFIX/var/lib/munge \$PREFIX/var/log/munge \$PREFIX/var/run/munge && " +
                    "dd if=/dev/urandom bs=1 count=1024 > \$PREFIX/etc/munge/munge.key 2>/dev/null && " +
                    "chmod 400 \$PREFIX/etc/munge/munge.key && " +
                    "chmod 700 \$PREFIX/etc/munge \$PREFIX/var/lib/munge \$PREFIX/var/log/munge \$PREFIX/var/run/munge && " +
                    "export MUNGE_SOCKETDIR=\$PREFIX/var/run/munge && " +
                    "munged --foreground --syslog &" +
                    "sleep 3 && " +
                    "echo 'test' | munge | unmunge && echo '✅ MUNGE authentication working' || echo '❌ MUNGE test failed' && " +
                    "echo '📦 Installing SLURM with MUNGE support...' && " +
                    "export CC=clang && export CXX=clang++ && " +
                    "cd \$HOME && " +
                    "if [ ! -d slurm ]; then git clone https://github.com/SchedMD/slurm.git; fi && " +
                    "cd slurm && " +
                    "./configure --prefix=\$PREFIX --disable-dependency-tracking --without-mysql --with-munge=\$PREFIX --sysconfdir=\$PREFIX/etc/slurm CC=clang CXX=clang++ && " +
                    "make -j\$(nproc) && make install && " +
                    "mkdir -p \$PREFIX/etc/slurm && " +
                    "echo 'ClusterName=android-cluster' > \$PREFIX/etc/slurm/slurm.conf && " +
                    "echo 'ControlMachine=localhost' >> \$PREFIX/etc/slurm/slurm.conf && " +
                    "echo 'AuthType=auth/munge' >> \$PREFIX/etc/slurm/slurm.conf && " +
                    "echo 'NodeName=android-node CPUs=4 RealMemory=4096 State=UNKNOWN' >> \$PREFIX/etc/slurm/slurm.conf && " +
                    "echo 'PartitionName=android Nodes=android-node Default=YES MaxTime=INFINITE State=UP' >> \$PREFIX/etc/slurm/slurm.conf && " +
                    "sinfo --version && echo '✅ SLURM with MUNGE installation complete'; " +
                    "fi"
                
                // Copy command to clipboard and open Termux
                try {
                    val clipboard = getSystemService(Context.CLIPBOARD_SERVICE) as android.content.ClipboardManager
                    val clip = android.content.ClipData.newPlainText("slurm_test", testCommand)
                    clipboard.setPrimaryClip(clip)
                    
                    val intent = Intent()
                    intent.setClassName("com.termux", "com.termux.app.TermuxActivity")
                    intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
                    startActivity(intent)
                    
                    addLog("✅ SLURM test command copied to clipboard")
                    addLog("📱 Termux opened - paste and run the command")
                    addLog("💡 Long press in Termux terminal and select 'Paste'")
                    addLog("⏱️ Note: Installation may take 10-15 minutes if not installed")
                } catch (e: Exception) {
                    val intent = Intent()
                    intent.setClassName("com.termux", "com.termux.app.TermuxActivity")
                    intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
                    startActivity(intent)
                    
                    addLog("✅ Termux opened")
                    addLog("📝 Run this command manually:")
                    addLog("   $testCommand")
                    addLog("⏱️ Note: Installation may take 10-15 minutes if not installed")
                }
                
            } catch (e: Exception) {
                addLog("❌ SLURM test failed: ${e.message}")
                addLog("💡 Make sure Termux is installed and accessible")
            }
        }
    }

    private fun isTermuxInstalled(): Boolean {
        return try {
            val pm = packageManager
            pm.getPackageInfo("com.termux", 0)
            true
        } catch (e: Exception) {
            false
        }
    }
    
    private fun installTermux(): Boolean {
        return try {
            // Create a more comprehensive Termux installation approach
            addLog("📦 Attempting to install Termux...")
            
            // First try F-Droid if available
            val fdroidIntent = Intent(Intent.ACTION_VIEW, android.net.Uri.parse("https://f-droid.org/packages/com.termux/"))
            fdroidIntent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
            
            try {
                startActivity(fdroidIntent)
                addLog("🔗 Opening F-Droid Termux page (recommended)")
                addLog("📱 Install Termux from F-Droid for best compatibility")
                return true
            } catch (e: Exception) {
                addLog("⚠️ F-Droid not available, trying GitHub...")
            }
            
            // Fallback to GitHub releases
            val termuxUrl = "https://github.com/termux/termux-app/releases/download/v0.118.0/termux-app_v0.118.0+github-debug_arm64-v8a.apk"
            val intent = Intent(Intent.ACTION_VIEW, android.net.Uri.parse(termuxUrl))
            intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
            startActivity(intent)
            
            addLog("🔗 Opening Termux GitHub download...")
            addLog("📱 Please install the APK when download completes")
            addLog("⚠️ Note: You may need to enable 'Install from unknown sources'")
            true
        } catch (e: Exception) {
            addLog("❌ Failed to open Termux installation: ${e.message}")
            addLog("💡 Manual installation required:")
            addLog("   1. Install F-Droid from f-droid.org")
            addLog("   2. Install Termux from F-Droid")
            addLog("   3. Or download APK from GitHub termux/termux-app")
            false
        }
    }
    
    private fun clearLogs() {
        runOnUiThread {
            logText.text = "[${java.text.SimpleDateFormat("HH:mm:ss", java.util.Locale.getDefault()).format(java.util.Date())}] 📱 Logs cleared\n"
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
