#!/bin/bash

# ARM Node Discovery and Health Monitoring Script
# Automatically discovers ARM devices on the network and monitors their health

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# Configuration
NETWORK_RANGE="192.168.0.0/16"
DISCOVERY_TIMEOUT=5
SSH_KEY="~/.ssh/cluster_key"
HEALTH_CHECK_INTERVAL=300  # 5 minutes

# Common ARM device patterns
declare -A ARM_PATTERNS=(
    ["raspberry"]="Raspberry Pi"
    ["rpi"]="Raspberry Pi"
    ["android"]="Android Device"
    ["jetson"]="NVIDIA Jetson"
    ["orangepi"]="Orange Pi"
    ["rockpi"]="Rock Pi"
    ["pine64"]="Pine64"
)

usage() {
    echo "Usage: $0 [command] [options]"
    echo ""
    echo "Commands:"
    echo "  discover    - Scan network for ARM devices"
    echo "  monitor     - Monitor health of known ARM nodes"
    echo "  benchmark   - Run performance benchmarks on ARM nodes"
    echo "  report      - Generate ARM cluster report"
    echo ""
    echo "Options:"
    echo "  --network RANGE    - Network range to scan (default: $NETWORK_RANGE)"
    echo "  --timeout SECONDS  - Discovery timeout (default: $DISCOVERY_TIMEOUT)"
    echo "  --continuous       - Run continuous monitoring"
    exit 1
}

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

# Network discovery function
discover_arm_devices() {
    local network_range=${1:-$NETWORK_RANGE}
    
    log "🔍 Discovering ARM devices on network: $network_range"
    
    # Create temporary results file
    local results_file="/tmp/arm_discovery_$(date +%s).txt"
    
    # Use nmap to discover live hosts
    log "Scanning for live hosts..."
    nmap -sn "$network_range" 2>/dev/null | grep -E "Nmap scan report|MAC Address" > "$results_file" || true
    
    # Extract IP addresses
    local discovered_ips=()
    while read -r line; do
        if [[ $line =~ "Nmap scan report for" ]]; then
            ip=$(echo "$line" | grep -oE '([0-9]{1,3}\.){3}[0-9]{1,3}')
            if [ -n "$ip" ]; then
                discovered_ips+=("$ip")
            fi
        fi
    done < "$results_file"
    
    log "Found ${#discovered_ips[@]} live hosts, checking for ARM devices..."
    
    # Check each IP for ARM characteristics
    local arm_devices=()
    for ip in "${discovered_ips[@]}"; do
        check_arm_device "$ip" && arm_devices+=("$ip")
    done
    
    # Generate discovery report
    if [ ${#arm_devices[@]} -gt 0 ]; then
        log "✅ Discovered ${#arm_devices[@]} potential ARM devices:"
        for device in "${arm_devices[@]}"; do
            get_device_info "$device"
        done
        
        # Save to discovery file
        printf '%s\n' "${arm_devices[@]}" > "$PROJECT_DIR/discovered_arm_devices.txt"
    else
        log "❌ No ARM devices discovered on network"
    fi
    
    rm -f "$results_file"
}

# Check if device is ARM-based
check_arm_device() {
    local ip=$1
    
    # Try common ARM device detection methods
    local is_arm=false
    
    # Method 1: SSH architecture check
    for user in pi ubuntu nvidia android; do
        if timeout $DISCOVERY_TIMEOUT ssh -i $SSH_KEY -o ConnectTimeout=3 -o StrictHostKeyChecking=no "$user@$ip" "uname -m" 2>/dev/null | grep -qE "(aarch64|arm64|armv7l)"; then
            is_arm=true
            break
        fi
    done
    
    # Method 2: Check for Raspberry Pi specific services
    if ! $is_arm; then
        if timeout $DISCOVERY_TIMEOUT nc -z "$ip" 22 2>/dev/null; then
            # Try to detect Pi-specific patterns
            if timeout $DISCOVERY_TIMEOUT ssh -i $SSH_KEY -o ConnectTimeout=3 -o StrictHostKeyChecking=no "pi@$ip" "test -f /proc/device-tree/model" 2>/dev/null; then
                is_arm=true
            fi
        fi
    fi
    
    $is_arm
}

# Get detailed device information
get_device_info() {
    local ip=$1
    
    log "📋 Device: $ip"
    
    # Try different users to get device info
    for user in pi ubuntu nvidia android; do
        if timeout $DISCOVERY_TIMEOUT ssh -i $SSH_KEY -o ConnectTimeout=3 -o StrictHostKeyChecking=no "$user@$ip" "echo 'Connected'" 2>/dev/null >/dev/null; then
            local info=$(ssh -i $SSH_KEY "$user@$ip" "
                echo 'Hostname: '$(hostname)
                echo 'Architecture: '$(uname -m)
                echo 'OS: '$(lsb_release -d 2>/dev/null | cut -f2 || cat /etc/os-release | grep PRETTY_NAME | cut -d'\"' -f2)
                echo 'CPUs: '$(nproc)
                echo 'Memory: '$(free -h | grep '^Mem:' | awk '{print \$2}')
                if command -v vcgencmd &> /dev/null; then
                    echo 'Device: Raspberry Pi ('$(cat /proc/device-tree/model 2>/dev/null || echo 'Unknown model')')'
                    echo 'Temperature: '$(vcgencmd measure_temp 2>/dev/null || echo 'N/A')
                fi
                if [ -f /proc/version ] && grep -q Android /proc/version; then
                    echo 'Device: Android Device'
                fi
            " 2>/dev/null)
            
            echo "$info" | sed 's/^/   /'
            break
        fi
    done
}

# Monitor ARM node health
monitor_arm_nodes() {
    local continuous=${1:-false}
    
    log "❤️ Starting ARM node health monitoring"
    
    # Get list of ARM nodes from inventory
    local arm_nodes=()
    if [ -f "$PROJECT_DIR/ansible/inventory.ini" ]; then
        while IFS= read -r line; do
            if [[ $line =~ ansible_host=([0-9.]+) ]]; then
                local ip="${BASH_REMATCH[1]}"
                if [[ $line =~ arch=(arm64|armhf) ]]; then
                    arm_nodes+=("$ip")
                fi
            fi
        done < "$PROJECT_DIR/ansible/inventory.ini"
    fi
    
    # Add discovered devices
    if [ -f "$PROJECT_DIR/discovered_arm_devices.txt" ]; then
        while IFS= read -r ip; do
            arm_nodes+=("$ip")
        done < "$PROJECT_DIR/discovered_arm_devices.txt"
    fi
    
    if [ ${#arm_nodes[@]} -eq 0 ]; then
        log "⚠️ No ARM nodes found to monitor"
        return
    fi
    
    log "Monitoring ${#arm_nodes[@]} ARM nodes: ${arm_nodes[*]}"
    
    do_health_check() {
        local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
        echo "=== ARM Node Health Check - $timestamp ===" >> "$PROJECT_DIR/arm_health.log"
        
        for ip in "${arm_nodes[@]}"; do
            log "Checking $ip..."
            
            # Determine user for this IP
            local user="pi"
            for test_user in pi ubuntu nvidia android; do
                if timeout 3 ssh -i $SSH_KEY -o ConnectTimeout=2 -o StrictHostKeyChecking=no "$test_user@$ip" "echo test" 2>/dev/null >/dev/null; then
                    user="$test_user"
                    break
                fi
            done
            
            # Collect health metrics
            local health_data=$(ssh -i $SSH_KEY "$user@$ip" "
                echo 'Node: $ip ($(hostname))'
                echo 'Status: Online'
                echo 'Uptime: '$(uptime -p)
                echo 'Load: '$(uptime | awk -F'load average:' '{print \$2}' | xargs)
                echo 'Memory: '$(free | grep Mem | awk '{printf \"%.1f%%\", \$3/\$2 * 100.0}')
                echo 'Disk: '$(df / | tail -1 | awk '{print \$5}')
                
                # Temperature monitoring
                if command -v vcgencmd &> /dev/null; then
                    echo 'Temperature: '$(vcgencmd measure_temp 2>/dev/null || echo 'N/A')
                    echo 'Throttling: '$(vcgencmd get_throttled 2>/dev/null || echo 'N/A')
                elif [ -f /sys/class/thermal/thermal_zone0/temp ]; then
                    temp=\$(($(cat /sys/class/thermal/thermal_zone0/temp)/1000))
                    echo \"Temperature: \${temp}°C\"
                fi
                
                # Service status
                echo 'Docker: '$(systemctl is-active docker 2>/dev/null || echo 'inactive')
                echo 'Kubelet: '$(systemctl is-active kubelet 2>/dev/null || echo 'inactive')
                echo 'SLURM: '$(systemctl is-active slurmd 2>/dev/null || echo 'inactive')
                echo '---'
            " 2>/dev/null || echo "Node: $ip - Status: Offline")
            
            echo "$health_data" | tee -a "$PROJECT_DIR/arm_health.log"
        done
        
        echo "" >> "$PROJECT_DIR/arm_health.log"
    }
    
    # Run initial health check
    do_health_check
    
    # Continuous monitoring if requested
    if [ "$continuous" = true ]; then
        log "Starting continuous monitoring (interval: ${HEALTH_CHECK_INTERVAL}s)"
        while true; do
            sleep $HEALTH_CHECK_INTERVAL
            do_health_check
        done
    fi
}

# Run performance benchmarks
benchmark_arm_nodes() {
    log "🏃 Running ARM node performance benchmarks"
    
    # Create benchmark script
    cat > /tmp/arm_benchmark.sh << 'EOF'
#!/bin/bash
echo "=== ARM Performance Benchmark ==="
echo "Node: $(hostname)"
echo "Architecture: $(uname -m)"
echo "CPUs: $(nproc)"
echo "Memory: $(free -h | grep '^Mem:' | awk '{print $2}')"
echo ""

# CPU benchmark
echo "CPU Benchmark (computing primes):"
time python3 -c "
import time
start = time.time()
primes = [i for i in range(2, 10000) if all(i % j != 0 for j in range(2, int(i**0.5) + 1))]
end = time.time()
print(f'Found {len(primes)} primes in {end-start:.2f} seconds')
"

# Memory benchmark
echo ""
echo "Memory Benchmark:"
python3 -c "
import time
start = time.time()
data = [i**2 for i in range(100000)]
end = time.time()
print(f'Processed {len(data)} integers in {end-start:.2f} seconds')
"

# Disk I/O benchmark
echo ""
echo "Disk I/O Benchmark:"
time dd if=/dev/zero of=/tmp/benchmark_test bs=1M count=100 2>&1 | grep -E "(copied|MB/s)"
rm -f /tmp/benchmark_test

echo "=== Benchmark Complete ==="
EOF

    chmod +x /tmp/arm_benchmark.sh
    
    # Run on all ARM nodes
    local inventory_file="$PROJECT_DIR/ansible/inventory.ini"
    if [ -f "$inventory_file" ]; then
        grep -A 100 "\[arm_nodes\]" "$inventory_file" | grep "ansible_host" | while read -r line; do
            if [[ $line =~ ansible_host=([0-9.]+) ]] && [[ $line =~ ansible_user=([^ ]+) ]]; then
                local ip="${BASH_REMATCH[1]}"
                local user="${BASH_REMATCH[2]}"
                
                log "Running benchmark on $ip..."
                scp -i $SSH_KEY /tmp/arm_benchmark.sh "$user@$ip:/tmp/"
                ssh -i $SSH_KEY "$user@$ip" "bash /tmp/arm_benchmark.sh" | tee -a "$PROJECT_DIR/arm_benchmarks.log"
                echo "" >> "$PROJECT_DIR/arm_benchmarks.log"
            fi
        done
    fi
    
    rm -f /tmp/arm_benchmark.sh
    log "✅ Benchmarks complete. Results saved to arm_benchmarks.log"
}

# Generate comprehensive report
generate_report() {
    log "📊 Generating ARM cluster report"
    
    local report_file="$PROJECT_DIR/arm_cluster_report_$(date +%Y%m%d_%H%M%S).md"
    
    cat > "$report_file" << EOF
# ARM Cluster Report
Generated: $(date)

## Cluster Overview
EOF

    # Count nodes by architecture
    if [ -f "$PROJECT_DIR/ansible/inventory.ini" ]; then
        local x86_count=$(grep -c "arch=x86_64" "$PROJECT_DIR/ansible/inventory.ini" 2>/dev/null || echo "0")
        local arm64_count=$(grep -c "arch=arm64" "$PROJECT_DIR/ansible/inventory.ini" 2>/dev/null || echo "0")
        local armhf_count=$(grep -c "arch=armhf" "$PROJECT_DIR/ansible/inventory.ini" 2>/dev/null || echo "0")
        
        cat >> "$report_file" << EOF

- **Total Nodes**: $((x86_count + arm64_count + armhf_count))
- **x86_64 Nodes**: $x86_count
- **ARM64 Nodes**: $arm64_count
- **ARMHF Nodes**: $armhf_count

## ARM Node Details
EOF

        # List ARM nodes
        grep -A 100 "\[arm_nodes\]" "$PROJECT_DIR/ansible/inventory.ini" 2>/dev/null | grep "ansible_host" | while read -r line; do
            if [[ $line =~ ^([^ ]+).*ansible_host=([0-9.]+).*ansible_user=([^ ]+) ]]; then
                echo "- **${BASH_REMATCH[1]}**: ${BASH_REMATCH[2]} (user: ${BASH_REMATCH[3]})" >> "$report_file"
            fi
        done
    fi
    
    # Add health status if available
    if [ -f "$PROJECT_DIR/arm_health.log" ]; then
        cat >> "$report_file" << EOF

## Recent Health Status
\`\`\`
$(tail -50 "$PROJECT_DIR/arm_health.log")
\`\`\`
EOF
    fi
    
    # Add benchmark results if available
    if [ -f "$PROJECT_DIR/arm_benchmarks.log" ]; then
        cat >> "$report_file" << EOF

## Performance Benchmarks
\`\`\`
$(tail -100 "$PROJECT_DIR/arm_benchmarks.log")
\`\`\`
EOF
    fi
    
    log "✅ Report generated: $report_file"
}

# Main execution
case "${1:-discover}" in
    "discover")
        discover_arm_devices "${2:-$NETWORK_RANGE}"
        ;;
    "monitor")
        if [[ "$2" == "--continuous" ]]; then
            monitor_arm_nodes true
        else
            monitor_arm_nodes false
        fi
        ;;
    "benchmark")
        benchmark_arm_nodes
        ;;
    "report")
        generate_report
        ;;
    *)
        usage
        ;;
esac
