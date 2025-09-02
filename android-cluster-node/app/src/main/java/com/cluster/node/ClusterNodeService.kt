package com.cluster.node

import android.app.*
import android.content.Context
import android.content.Intent
import android.os.IBinder
import android.os.PowerManager
import androidx.core.app.NotificationCompat
import okhttp3.*
import okio.ByteString
import com.google.gson.Gson
import java.util.concurrent.Executors
import java.util.concurrent.ThreadPoolExecutor
import android.util.Log

class ClusterNodeService : Service() {
    private lateinit var webSocket: WebSocket
    private lateinit var client: OkHttpClient
    private lateinit var wakeLock: PowerManager.WakeLock
    private lateinit var computeEngine: ComputeEngine
    private val executor = Executors.newFixedThreadPool(4) as ThreadPoolExecutor
    
    companion object {
        const val CHANNEL_ID = "ClusterNodeService"
        const val NOTIFICATION_ID = 1
        private const val TAG = "ClusterNodeService"
        
        @JvmStatic
        var isServiceRunning = false
        
        @JvmStatic
        var connectionStatus = "Disconnected"
        
        @JvmStatic
        var tasksProcessed = 0
        
        private var startTime = 0L
        
        @JvmStatic
        fun getUptime(): Long {
            return if (startTime > 0) System.currentTimeMillis() - startTime else 0
        }
    }
    
    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
        
        // Acquire wake lock to keep service running
        val powerManager = getSystemService(Context.POWER_SERVICE) as PowerManager
        wakeLock = powerManager.newWakeLock(
            PowerManager.PARTIAL_WAKE_LOCK,
            "ClusterNode::ServiceWakeLock"
        )
        wakeLock.acquire()
        
        computeEngine = ComputeEngine(this)
        client = OkHttpClient()
        
        isServiceRunning = true
        startTime = System.currentTimeMillis()
        connectionStatus = "Connecting..."
        
        startForeground(NOTIFICATION_ID, createNotification("Connecting to cluster..."))
        connectToCluster()
    }
    
    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        return START_STICKY // Restart if killed
    }
    
    override fun onBind(intent: Intent?): IBinder? = null
    
    private fun createNotificationChannel() {
        val channel = NotificationChannel(
            CHANNEL_ID,
            "Cluster Node Service",
            NotificationManager.IMPORTANCE_LOW
        ).apply {
            description = "Background service for cluster compute tasks"
        }
        
        val notificationManager = getSystemService(NotificationManager::class.java)
        notificationManager.createNotificationChannel(channel)
    }
    
    private fun createNotification(status: String): Notification {
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("Cluster Node Active")
            .setContentText(status)
            .setSmallIcon(R.drawable.ic_cluster)
            .setOngoing(true)
            .build()
    }
    
    private fun updateNotification(status: String) {
        val notification = createNotification(status)
        val notificationManager = getSystemService(NotificationManager::class.java)
        notificationManager.notify(NOTIFICATION_ID, notification)
    }
    
    private fun connectToCluster() {
        val clusterUrl = getClusterUrl()
        Log.i(TAG, "Connecting to cluster at: $clusterUrl")
        val request = Request.Builder()
            .url(clusterUrl)
            .addHeader("Connection", "Upgrade")
            .addHeader("Upgrade", "websocket")
            .addHeader("Sec-WebSocket-Version", "13")
            .addHeader("Sec-WebSocket-Key", "dGhlIHNhbXBsZSBub25jZQ==")
            .build()
            
        webSocket = client.newWebSocket(request, object : WebSocketListener() {
            override fun onOpen(webSocket: WebSocket, response: Response) {
                Log.i(TAG, "Connected to cluster")
                connectionStatus = "Connected"
                updateNotification("Connected - Ready for tasks")
                
                // Send node registration
                val registration = mapOf(
                    "type" to "register",
                    "node_id" to android.os.Build.MODEL.replace(" ", "_").lowercase(),
                    "device_info" to getDeviceInfo(),
                    "capabilities" to getCapabilities()
                )
                webSocket.send(Gson().toJson(registration))
            }
            
            override fun onMessage(webSocket: WebSocket, text: String) {
                Log.d(TAG, "Received message: $text")
                handleClusterMessage(text)
            }
            
            override fun onFailure(webSocket: WebSocket, t: Throwable, response: Response?) {
                Log.e(TAG, "WebSocket failure: ${t.message}", t)
                connectionStatus = "Failed: ${t.message}"
                updateNotification("Connection failed - Retrying...")
                
                // Retry connection after delay
                android.os.Handler(mainLooper).postDelayed({
                    connectToCluster()
                }, 5000)
            }
            
            override fun onClosed(webSocket: WebSocket, code: Int, reason: String) {
                Log.i(TAG, "WebSocket closed: $reason")
                updateNotification("Disconnected - Reconnecting...")
                connectToCluster()
            }
        })
    }
    
    private fun handleClusterMessage(message: String) {
        try {
            val messageObj = Gson().fromJson(message, Map::class.java) as Map<String, Any>
            val messageType = messageObj["type"] as? String
            
            when (messageType) {
                "welcome" -> {
                    Log.i(TAG, "Received welcome message")
                    // Send capabilities and request tasks
                    sendCapabilities()
                    requestTask()
                }
                "task_assignment" -> {
                    val taskData = messageObj["data"] as? Map<String, Any> ?: emptyMap()
                    val task = ComputeTask(
                        id = messageObj["task_id"] as? String ?: "",
                        type = messageObj["task_type"] as? String ?: "",
                        data = taskData,
                        priority = when (val priority = messageObj["priority"]) {
                            is Number -> priority.toInt()
                            else -> 1
                        }
                    )
                    Log.d(TAG, "Received task assignment: ${task.type}")
                    processComputeTask(task)
                }
                "no_tasks" -> {
                    Log.i(TAG, "No tasks available")
                    connectionStatus = "Connected - No tasks"
                    // Request again after delay
                    android.os.Handler(mainLooper).postDelayed({
                        requestTask()
                    }, 10000)
                }
                "task_ack" -> {
                    Log.i(TAG, "Task acknowledgment received")
                    tasksProcessed++
                    requestTask() // Request next task
                }
                "heartbeat_ack" -> {
                    Log.d(TAG, "Heartbeat acknowledged")
                }
                else -> Log.w(TAG, "Unknown message type: $messageType")
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error handling message: $message", e)
            sendError("Failed to process message: ${e.message}")
        }
    }
    
    private fun sendCapabilities() {
        val capabilities = mapOf(
            "type" to "capabilities",
            "capabilities" to listOf(
                "shell_scripts",
                "python_scripts", 
                "arm_compute",
                "kubernetes_jobs",
                "slurm_jobs",
                "matrix_operations",
                "file_processing",
                "network_tasks"
            )
        )
        webSocket.send(Gson().toJson(capabilities))
    }
    
    private fun requestTask() {
        val request = mapOf("type" to "request_task")
        webSocket.send(Gson().toJson(request))
    }
    
    private fun processComputeTask(task: ComputeTask) {
        updateNotification("Processing task ${task.id}")
        Log.i(TAG, "🚀 Starting task ${task.id} (${task.type})")
        
        executor.submit {
            try {
                val startTime = System.currentTimeMillis()
                val result = computeEngine.processTask(task)
                val duration = System.currentTimeMillis() - startTime
                
                Log.i(TAG, "✅ Task ${task.id} (${task.type}) completed in ${duration}ms")
                sendTaskResult(task.id, result)
                updateNotification("Connected - Ready for tasks")
            } catch (e: Exception) {
                Log.e(TAG, "❌ Task ${task.id} (${task.type}) failed: ${e.message}", e)
                sendTaskError(task.id, e.message ?: "Unknown error")
            }
        }
    }
    
    private fun sendHealthStatus() {
        val health = HealthStatus(
            cpuUsage = computeEngine.getCpuUsage(),
            memoryUsage = computeEngine.getMemoryUsage(),
            batteryLevel = getBatteryLevel(),
            temperature = getDeviceTemperature(),
            activeThreads = executor.activeCount,
            queuedTasks = executor.queue.size
        )
        
        webSocket.send(Gson().toJson(health))
    }
    
    private fun runBenchmark(task: ComputeTask) {
        executor.submit {
            val benchmark = computeEngine.runBenchmark()
            sendTaskResult(task.id, benchmark)
        }
    }
    
    private fun sendTaskResult(taskId: String, result: Any) {
        Log.i(TAG, "✅ Task $taskId completed successfully")
        val response = mapOf(
            "type" to "task_result",
            "task_id" to taskId,
            "status" to "completed",
            "result" to result,
            "success" to true,
            "timestamp" to System.currentTimeMillis()
        )
        webSocket.send(Gson().toJson(response))
    }
    
    private fun sendTaskError(taskId: String, error: String) {
        val response = mapOf(
            "type" to "task_result",
            "task_id" to taskId,
            "status" to "error",
            "error" to error,
            "success" to false,
            "timestamp" to System.currentTimeMillis()
        )
        webSocket.send(Gson().toJson(response))
    }
    
    private fun sendError(message: String) {
        val error = ErrorMessage(
            message = message,
            timestamp = System.currentTimeMillis()
        )
        webSocket.send(Gson().toJson(error))
    }
    
    private fun getClusterUrl(): String {
        val prefs = getSharedPreferences("cluster_node_prefs", Context.MODE_PRIVATE)
        return prefs.getString("cluster_url", "ws://192.168.5.55:8765") ?: "ws://192.168.5.55:8765"
    }
    
    private fun getDeviceInfo(): DeviceInfo {
        return DeviceInfo(
            model = android.os.Build.MODEL,
            manufacturer = android.os.Build.MANUFACTURER,
            androidVersion = android.os.Build.VERSION.RELEASE,
            apiLevel = android.os.Build.VERSION.SDK_INT,
            architecture = System.getProperty("os.arch") ?: "unknown",
            cores = Runtime.getRuntime().availableProcessors(),
            totalMemory = Runtime.getRuntime().totalMemory(),
            maxMemory = Runtime.getRuntime().maxMemory()
        )
    }
    
    private fun getCapabilities(): List<String> {
        return listOf(
            "compute",
            "javascript",
            "json_processing",
            "image_processing",
            "machine_learning"
        )
    }
    
    private fun getBatteryLevel(): Int {
        val batteryManager = getSystemService(Context.BATTERY_SERVICE) as android.os.BatteryManager
        return batteryManager.getIntProperty(android.os.BatteryManager.BATTERY_PROPERTY_CAPACITY)
    }
    
    private fun getDeviceTemperature(): Float {
        // Android doesn't provide direct temperature access without root
        // Return estimated temperature based on CPU usage
        return 25.0f + (computeEngine.getCpuUsage() * 0.3f)
    }
    
    override fun onDestroy() {
        super.onDestroy()
        
        if (::wakeLock.isInitialized && wakeLock.isHeld) {
            wakeLock.release()
        }
        
        if (::webSocket.isInitialized) {
            webSocket.close(1000, "Service stopped")
        }
        
        executor.shutdown()
    }
}

// Data classes for communication
data class NodeRegistration(
    val deviceInfo: DeviceInfo,
    val capabilities: List<String>
)

data class DeviceInfo(
    val model: String,
    val manufacturer: String,
    val androidVersion: String,
    val apiLevel: Int,
    val architecture: String,
    val cores: Int,
    val totalMemory: Long,
    val maxMemory: Long
)

data class ComputeTask(
    val id: String,
    val type: String,
    val data: Map<String, Any>,
    val priority: Int = 0
)

data class TaskResponse(
    val taskId: String,
    val status: String,
    val result: Any? = null,
    val error: String? = null,
    val timestamp: Long
)

data class HealthStatus(
    val cpuUsage: Float,
    val memoryUsage: Float,
    val batteryLevel: Int,
    val temperature: Float,
    val activeThreads: Int,
    val queuedTasks: Int
)

data class ErrorMessage(
    val message: String,
    val timestamp: Long
)
