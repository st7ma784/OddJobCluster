#!/bin/bash

# Android Cluster Manager
# Manages Android devices as cluster nodes using multiple integration methods

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
ANDROID_NODES_FILE="$PROJECT_DIR/android_nodes.json"
APK_PATH="$PROJECT_DIR/android-cluster-node/app/build/outputs/apk/release/app-release.apk"

usage() {
    echo "Android Cluster Manager"
    echo "======================"
    echo "Usage: $0 <command> [options]"
    echo ""
    echo "Commands:"
    echo "  add <method> <ip> [user]     - Add Android device to cluster"
    echo "  remove <ip>                  - Remove Android device from cluster"
    echo "  list                         - List all Android nodes"
    echo "  status <ip>                  - Check status of Android node"
    echo "  build-apk                    - Build cluster node APK"
    echo "  install-apk <ip>             - Install APK via ADB"
    echo "  discover                     - Discover Android devices on network"
    echo ""
    echo "Integration Methods:"
    echo "  apk        - Custom cluster node APK (recommended)"
    echo "  termux     - Termux with custom setup"
    echo "  webview    - WebView-based compute node"
    echo "  adb        - ADB-based integration"
    echo ""
    echo "Examples:"
    echo "  $0 add apk 192.168.1.100"
    echo "  $0 add termux 192.168.1.101 u0_a123"
    echo "  $0 build-apk"
    echo "  $0 install-apk 192.168.1.100"
    exit 1
}

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

# Initialize Android nodes file
init_android_nodes() {
    if [ ! -f "$ANDROID_NODES_FILE" ]; then
        echo "[]" > "$ANDROID_NODES_FILE"
    fi
}

# Add Android node to registry
add_android_node() {
    local method=$1
    local ip=$2
    local user=${3:-""}
    
    log "Adding Android node: $ip (method: $method)"
    
    case $method in
        "apk")
            setup_apk_node "$ip"
            ;;
        "termux")
            setup_termux_node "$ip" "$user"
            ;;
        "webview")
            setup_webview_node "$ip"
            ;;
        "adb")
            setup_adb_node "$ip"
            ;;
        *)
            echo "❌ Unknown method: $method"
            usage
            ;;
    esac
}

# Setup APK-based node
setup_apk_node() {
    local ip=$1
    
    log "Setting up APK-based Android node at $ip"
    
    # Check if APK is running
    if curl -s --connect-timeout 5 "http://$ip:8080/health" >/dev/null 2>&1; then
        log "✅ Android cluster node APK is running"
        register_android_node "$ip" "apk" ""
        
        # Get device info
        local device_info=$(curl -s "http://$ip:8080/device-info" 2>/dev/null || echo "{}")
        log "Device info: $device_info"
    else
        log "❌ APK not running on device"
        log "📱 Please install ClusterNode.apk on the device"
        log "📋 APK location: $APK_PATH"
        log "📋 Or build with: $0 build-apk"
        
        # Provide installation instructions
        cat << EOF

📱 APK Installation Instructions:
================================

Method 1: Direct Install (if APK is available)
1. Transfer APK to device: adb push $APK_PATH /sdcard/
2. Install on device: Settings > Security > Install from Unknown Sources
3. Open file manager and install ClusterNode.apk

Method 2: Build and Install
1. Build APK: $0 build-apk
2. Install via ADB: $0 install-apk $ip

Method 3: Sideload via ADB
1. Enable Developer Options and USB Debugging
2. Connect device via USB
3. Run: adb install $APK_PATH

EOF
        return 1
    fi
}

# Setup Termux-based node
setup_termux_node() {
    local ip=$1
    local user=$2
    
    log "Setting up Termux-based Android node at $ip"
    
    if [ -z "$user" ]; then
        log "❌ Username required for Termux setup"
        log "📋 Find username with: pkg install openssh && whoami"
        return 1
    fi
    
    # Test SSH connection
    if timeout 5 ssh -o ConnectTimeout=3 -o StrictHostKeyChecking=no "$user@$ip" "echo 'SSH OK'" 2>/dev/null; then
        log "✅ SSH connection successful"
        
        # Install cluster components
        ssh "$user@$ip" "
            pkg update -y
            pkg install -y python nodejs git curl wget htop
            
            # Install Python dependencies
            pip install flask websockets psutil requests
            
            # Create cluster node script
            cat > cluster_node.py << 'PYTHON_EOF'
import flask, json, psutil, threading, time, requests
from flask import Flask, request, jsonify
import subprocess
import os

app = Flask(__name__)

@app.route('/health')
def health():
    return jsonify({
        'status': 'online',
        'method': 'termux',
        'cpu_percent': psutil.cpu_percent(),
        'memory_percent': psutil.virtual_memory().percent,
        'disk_usage': psutil.disk_usage('/').percent,
        'uptime': time.time() - psutil.boot_time()
    })

@app.route('/device-info')
def device_info():
    return jsonify({
        'hostname': os.uname().nodename,
        'architecture': os.uname().machine,
        'system': os.uname().sysname,
        'python_version': os.sys.version,
        'termux_version': subprocess.getoutput('pkg list-installed | grep termux')
    })

@app.route('/execute', methods=['POST'])
def execute_task():
    task = request.json
    try:
        # Process compute task
        result = process_compute_task(task)
        return jsonify({'status': 'success', 'result': result})
    except Exception as e:
        return jsonify({'status': 'error', 'error': str(e)})

def process_compute_task(task):
    task_type = task.get('type', 'unknown')
    
    if task_type == 'prime_calculation':
        start = task.get('start', 1)
        end = task.get('end', 1000)
        primes = [i for i in range(start, end+1) if is_prime(i)]
        return {'primes': primes, 'count': len(primes)}
    
    elif task_type == 'system_info':
        return {
            'cpu_count': psutil.cpu_count(),
            'memory_total': psutil.virtual_memory().total,
            'disk_total': psutil.disk_usage('/').total,
            'load_average': os.getloadavg() if hasattr(os, 'getloadavg') else [0,0,0]
        }
    
    return {'message': 'Task processed', 'type': task_type}

def is_prime(n):
    if n < 2: return False
    for i in range(2, int(n**0.5) + 1):
        if n % i == 0: return False
    return True

if __name__ == '__main__':
    print('Starting Termux cluster node on port 8080...')
    app.run(host='0.0.0.0', port=8080, debug=False)
PYTHON_EOF
            
            # Start cluster service in background
            nohup python cluster_node.py > cluster_node.log 2>&1 &
            echo \$! > cluster_node.pid
            
            echo 'Termux cluster node started'
        "
        
        # Wait for service to start
        sleep 3
        
        # Test the service
        if curl -s "http://$ip:8080/health" >/dev/null; then
            log "✅ Termux cluster node is running"
            register_android_node "$ip" "termux" "$user"
        else
            log "❌ Failed to start Termux cluster node"
            return 1
        fi
    else
        log "❌ SSH connection failed"
        log "📋 Termux SSH setup required:"
        cat << EOF

📱 Termux SSH Setup Instructions:
=================================

1. Install Termux from F-Droid (recommended) or Google Play
2. Update packages: pkg update && pkg upgrade
3. Install SSH: pkg install openssh
4. Set password: passwd
5. Start SSH server: sshd
6. Find IP address: ip addr show wlan0
7. Find username: whoami
8. Test connection: ssh username@device_ip

EOF
        return 1
    fi
}

# Setup WebView-based node
setup_webview_node() {
    local ip=$1
    
    log "Setting up WebView-based Android node at $ip"
    
    # Create WebView cluster node HTML
    cat > /tmp/android-webview-node.html << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>Android Cluster Node</title>
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; background: #f0f0f0; }
        .container { background: white; padding: 20px; border-radius: 8px; }
        .status { padding: 10px; margin: 10px 0; border-radius: 4px; }
        .online { background: #d4edda; color: #155724; }
        .offline { background: #f8d7da; color: #721c24; }
        .log { background: #f8f9fa; padding: 10px; border-radius: 4px; font-family: monospace; height: 200px; overflow-y: auto; }
        button { padding: 10px 20px; margin: 5px; border: none; border-radius: 4px; background: #007bff; color: white; }
    </style>
</head>
<body>
    <div class="container">
        <h1>🤖 Android Cluster Node</h1>
        <div id="status" class="status offline">Connecting...</div>
        
        <h3>Device Information</h3>
        <div id="device-info">Loading...</div>
        
        <h3>Controls</h3>
        <button onclick="connectToCluster()">Connect to Cluster</button>
        <button onclick="runBenchmark()">Run Benchmark</button>
        <button onclick="clearLog()">Clear Log</button>
        
        <h3>Activity Log</h3>
        <div id="log" class="log"></div>
    </div>

    <script>
        let websocket = null;
        let isConnected = false;
        
        function log(message) {
            const logDiv = document.getElementById('log');
            const timestamp = new Date().toLocaleTimeString();
            logDiv.innerHTML += `[${timestamp}] ${message}\n`;
            logDiv.scrollTop = logDiv.scrollHeight;
        }
        
        function updateStatus(status, message) {
            const statusDiv = document.getElementById('status');
            statusDiv.className = `status ${status}`;
            statusDiv.textContent = message;
        }
        
        function connectToCluster() {
            const clusterUrl = 'ws://192.168.5.57:8080/android-webview';
            
            try {
                websocket = new WebSocket(clusterUrl);
                
                websocket.onopen = function(event) {
                    isConnected = true;
                    updateStatus('online', 'Connected to cluster');
                    log('✅ Connected to cluster');
                    
                    // Send device registration
                    const deviceInfo = getDeviceInfo();
                    websocket.send(JSON.stringify({
                        type: 'register',
                        data: deviceInfo
                    }));
                };
                
                websocket.onmessage = function(event) {
                    const message = JSON.parse(event.data);
                    log(`📨 Received task: ${message.type}`);
                    
                    // Process the task
                    processTask(message).then(result => {
                        websocket.send(JSON.stringify({
                            type: 'task_result',
                            taskId: message.id,
                            result: result
                        }));
                    });
                };
                
                websocket.onclose = function(event) {
                    isConnected = false;
                    updateStatus('offline', 'Disconnected from cluster');
                    log('❌ Disconnected from cluster');
                };
                
                websocket.onerror = function(error) {
                    log(`❌ WebSocket error: ${error}`);
                    updateStatus('offline', 'Connection error');
                };
                
            } catch (error) {
                log(`❌ Failed to connect: ${error}`);
                updateStatus('offline', 'Connection failed');
            }
        }
        
        async function processTask(task) {
            log(`⚙️ Processing task: ${task.type}`);
            
            switch (task.type) {
                case 'prime_calculation':
                    return calculatePrimes(task.data.start || 1, task.data.end || 1000);
                case 'benchmark':
                    return runBenchmarkTask();
                case 'system_info':
                    return getDeviceInfo();
                default:
                    return { error: 'Unknown task type' };
            }
        }
        
        function calculatePrimes(start, end) {
            const primes = [];
            for (let i = start; i <= end; i++) {
                if (isPrime(i)) primes.push(i);
            }
            return { primes: primes, count: primes.length };
        }
        
        function isPrime(n) {
            if (n < 2) return false;
            for (let i = 2; i <= Math.sqrt(n); i++) {
                if (n % i === 0) return false;
            }
            return true;
        }
        
        function runBenchmarkTask() {
            const start = performance.now();
            
            // CPU benchmark
            let result = 0;
            for (let i = 0; i < 1000000; i++) {
                result += Math.sqrt(i);
            }
            
            const duration = performance.now() - start;
            return {
                duration_ms: duration,
                operations_per_second: 1000000 / duration * 1000,
                result: result
            };
        }
        
        function getDeviceInfo() {
            return {
                userAgent: navigator.userAgent,
                platform: navigator.platform,
                cores: navigator.hardwareConcurrency || 'unknown',
                memory: navigator.deviceMemory || 'unknown',
                connection: navigator.connection ? navigator.connection.effectiveType : 'unknown',
                screen: `${screen.width}x${screen.height}`,
                method: 'webview'
            };
        }
        
        function runBenchmark() {
            log('🏃 Running local benchmark...');
            const result = runBenchmarkTask();
            log(`📊 Benchmark result: ${result.operations_per_second.toFixed(0)} ops/sec`);
        }
        
        function clearLog() {
            document.getElementById('log').innerHTML = '';
        }
        
        // Initialize
        document.addEventListener('DOMContentLoaded', function() {
            const deviceInfo = getDeviceInfo();
            document.getElementById('device-info').innerHTML = 
                `Platform: ${deviceInfo.platform}<br>` +
                `Cores: ${deviceInfo.cores}<br>` +
                `Memory: ${deviceInfo.memory}GB<br>` +
                `Screen: ${deviceInfo.screen}`;
            
            log('📱 Android WebView cluster node initialized');
            log('👆 Tap "Connect to Cluster" to join');
        });
    </script>
</body>
</html>
EOF

    log "📱 WebView cluster node HTML created"
    log "📋 To use WebView method:"
    log "   1. Transfer /tmp/android-webview-node.html to device"
    log "   2. Open in Chrome/WebView app"
    log "   3. Tap 'Connect to Cluster'"
    log "   4. Keep browser open for cluster participation"
    
    # For now, register as potential node
    register_android_node "$ip" "webview" ""
}

# Setup ADB-based node
setup_adb_node() {
    local ip=$1
    
    log "Setting up ADB-based Android node at $ip"
    
    # Check if ADB can connect
    if adb connect "$ip:5555" 2>/dev/null | grep -q "connected"; then
        log "✅ ADB connected to $ip"
        
        # Install cluster components via ADB
        adb -s "$ip:5555" shell "
            # Create cluster directory
            mkdir -p /sdcard/cluster
            
            # Create simple cluster script
            cat > /sdcard/cluster/node.sh << 'SHELL_EOF'
#!/system/bin/sh
echo 'Android ADB cluster node starting...'
while true; do
    echo '{\"status\":\"online\",\"method\":\"adb\",\"timestamp\":\"'$(date)'\"}' > /sdcard/cluster/status.json
    sleep 30
done
SHELL_EOF
            
            chmod +x /sdcard/cluster/node.sh
            nohup /sdcard/cluster/node.sh > /sdcard/cluster/node.log 2>&1 &
        "
        
        register_android_node "$ip" "adb" ""
        log "✅ ADB cluster node setup complete"
    else
        log "❌ ADB connection failed"
        log "📋 ADB setup required:"
        cat << EOF

📱 ADB Setup Instructions:
=========================

1. Enable Developer Options:
   - Go to Settings > About Phone
   - Tap Build Number 7 times
   
2. Enable USB Debugging:
   - Go to Settings > Developer Options
   - Enable USB Debugging
   
3. Enable ADB over Network:
   - Connect via USB first
   - Run: adb tcpip 5555
   - Disconnect USB
   - Run: adb connect $ip:5555

EOF
        return 1
    fi
}

# Register Android node in cluster
register_android_node() {
    local ip=$1
    local method=$2
    local user=$3
    
    init_android_nodes
    
    # Create node entry
    local node_entry=$(cat << EOF
{
  "ip": "$ip",
  "method": "$method",
  "user": "$user",
  "added": "$(date -Iseconds)",
  "status": "active",
  "last_seen": "$(date -Iseconds)"
}
EOF
    )
    
    # Add to nodes file (simple append for now)
    local temp_file=$(mktemp)
    jq ". += [$node_entry]" "$ANDROID_NODES_FILE" > "$temp_file" 2>/dev/null || {
        # If jq fails, create new file
        echo "[$node_entry]" > "$temp_file"
    }
    mv "$temp_file" "$ANDROID_NODES_FILE"
    
    log "✅ Android node registered: $ip ($method)"
    
    # Update cluster inventory
    update_cluster_inventory "$ip" "$method" "$user"
}

# Update main cluster inventory
update_cluster_inventory() {
    local ip=$1
    local method=$2
    local user=$3
    
    local inventory_file="$PROJECT_DIR/ansible/inventory.ini"
    local hostname="android-${method}-$(echo $ip | tr '.' '-')"
    
    # Add to ARM nodes section
    if ! grep -q "\[arm_nodes\]" "$inventory_file" 2>/dev/null; then
        echo "" >> "$inventory_file"
        echo "[arm_nodes]" >> "$inventory_file"
    fi
    
    # Add node entry if not exists
    if ! grep -q "$ip" "$inventory_file"; then
        echo "$hostname ansible_host=$ip ansible_user=$user arch=arm64 node_type=android method=$method" >> "$inventory_file"
        log "✅ Added to cluster inventory: $hostname"
    fi
}

# Build APK
build_apk() {
    log "🔨 Building Android cluster node APK..."
    
    local android_project="$PROJECT_DIR/android-cluster-node"
    
    if [ ! -d "$android_project" ]; then
        log "❌ Android project directory not found: $android_project"
        return 1
    fi
    
    cd "$android_project"
    
    # Build APK using Gradle
    if command -v ./gradlew >/dev/null 2>&1; then
        ./gradlew assembleRelease
    elif command -v gradle >/dev/null 2>&1; then
        gradle assembleRelease
    else
        log "❌ Gradle not found. Please install Android Studio or Gradle"
        return 1
    fi
    
    if [ -f "$APK_PATH" ]; then
        log "✅ APK built successfully: $APK_PATH"
        log "📱 Install with: $0 install-apk <device_ip>"
    else
        log "❌ APK build failed"
        return 1
    fi
}

# Install APK via ADB
install_apk() {
    local ip=$1
    
    if [ ! -f "$APK_PATH" ]; then
        log "❌ APK not found: $APK_PATH"
        log "📋 Build APK first: $0 build-apk"
        return 1
    fi
    
    log "📱 Installing APK on device $ip..."
    
    # Try ADB over network
    if adb connect "$ip:5555" 2>/dev/null | grep -q "connected"; then
        adb -s "$ip:5555" install "$APK_PATH"
        log "✅ APK installed via ADB"
        
        # Start the app
        adb -s "$ip:5555" shell am start -n com.cluster.node/.MainActivity
        log "✅ Cluster node app started"
    else
        log "❌ ADB connection failed"
        log "📋 Manual installation required:"
        log "   1. Transfer APK to device"
        log "   2. Enable 'Install from Unknown Sources'"
        log "   3. Install APK manually"
    fi
}

# List Android nodes
list_android_nodes() {
    init_android_nodes
    
    log "📱 Android Cluster Nodes:"
    log "========================"
    
    if [ -s "$ANDROID_NODES_FILE" ]; then
        jq -r '.[] | "IP: \(.ip) | Method: \(.method) | Status: \(.status) | Added: \(.added)"' "$ANDROID_NODES_FILE" 2>/dev/null || {
            log "❌ Error reading nodes file"
        }
    else
        log "No Android nodes registered"
    fi
}

# Check node status
check_node_status() {
    local ip=$1
    
    log "🔍 Checking status of Android node: $ip"
    
    # Try different endpoints based on method
    local methods=("8080/health" "8080/device-info")
    local found=false
    
    for endpoint in "${methods[@]}"; do
        if curl -s --connect-timeout 5 "http://$ip:$endpoint" >/dev/null 2>&1; then
            local response=$(curl -s "http://$ip:$endpoint")
            log "✅ Node is online: $ip"
            log "Response: $response"
            found=true
            break
        fi
    done
    
    if [ "$found" = false ]; then
        log "❌ Node is offline or unreachable: $ip"
    fi
}

# Discover Android devices
discover_android_devices() {
    log "🔍 Discovering Android devices on network..."
    
    # Use nmap to find devices with common Android ports
    local network="192.168.0.0/16"
    
    log "Scanning for devices with Android services..."
    
    # Scan for ADB port (5555)
    nmap -p 5555 --open "$network" 2>/dev/null | grep -B 2 "5555/tcp open" | grep "Nmap scan report" | awk '{print $5}' | while read ip; do
        log "Found potential ADB device: $ip"
    done
    
    # Scan for common HTTP ports that might be cluster nodes
    nmap -p 8080 --open "$network" 2>/dev/null | grep -B 2 "8080/tcp open" | grep "Nmap scan report" | awk '{print $5}' | while read ip; do
        if curl -s --connect-timeout 2 "http://$ip:8080/health" | grep -q "android\|termux"; then
            log "Found Android cluster node: $ip"
        fi
    done
}

# Main execution
case "${1:-help}" in
    "add")
        if [ $# -lt 3 ]; then
            echo "Usage: $0 add <method> <ip> [user]"
            exit 1
        fi
        add_android_node "$2" "$3" "$4"
        ;;
    "remove")
        # TODO: Implement remove functionality
        log "Remove functionality not yet implemented"
        ;;
    "list")
        list_android_nodes
        ;;
    "status")
        if [ $# -lt 2 ]; then
            echo "Usage: $0 status <ip>"
            exit 1
        fi
        check_node_status "$2"
        ;;
    "build-apk")
        build_apk
        ;;
    "install-apk")
        if [ $# -lt 2 ]; then
            echo "Usage: $0 install-apk <ip>"
            exit 1
        fi
        install_apk "$2"
        ;;
    "discover")
        discover_android_devices
        ;;
    *)
        usage
        ;;
esac
