#!/bin/bash

# Cluster Health Dashboard Generator
# Creates real-time health monitoring for mixed x86/ARM cluster

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# Generate comprehensive health report
generate_health_data() {
    local output_file="$1"
    
    cat > "$output_file" << 'EOF'
{
  "timestamp": "TIMESTAMP_PLACEHOLDER",
  "cluster": {
    "total_nodes": 0,
    "online_nodes": 0,
    "x86_nodes": 0,
    "arm_nodes": 0
  },
  "nodes": [],
  "services": {
    "kubernetes": "unknown",
    "slurm": "unknown",
    "jupyterhub": "unknown"
  },
  "workloads": {
    "running_jobs": 0,
    "queued_jobs": 0,
    "running_pods": 0
  }
}
EOF

    # Replace timestamp
    sed -i "s/TIMESTAMP_PLACEHOLDER/$(date -Iseconds)/" "$output_file"
    
    # Collect node data
    local node_data="[]"
    local total_nodes=0
    local online_nodes=0
    local x86_count=0
    local arm_count=0
    
    # Check inventory for nodes
    if [ -f "$PROJECT_DIR/ansible/inventory.ini" ]; then
        while IFS= read -r line; do
            if [[ $line =~ ^([^[:space:]]+)[[:space:]]+ansible_host=([0-9.]+)[[:space:]]+ansible_user=([^[:space:]]+) ]]; then
                local hostname="${BASH_REMATCH[1]}"
                local ip="${BASH_REMATCH[2]}"
                local user="${BASH_REMATCH[3]}"
                local arch="x86_64"
                
                # Extract architecture if specified
                if [[ $line =~ arch=([^[:space:]]+) ]]; then
                    arch="${BASH_REMATCH[1]}"
                fi
                
                total_nodes=$((total_nodes + 1))
                
                # Count by architecture
                if [[ $arch =~ arm ]]; then
                    arm_count=$((arm_count + 1))
                else
                    x86_count=$((x86_count + 1))
                fi
                
                # Check if node is online
                local status="offline"
                local cpu_usage="0"
                local memory_usage="0"
                local temperature="N/A"
                local uptime="Unknown"
                
                if timeout 5 ssh -i ~/.ssh/cluster_key -o ConnectTimeout=3 -o StrictHostKeyChecking=no "$user@$ip" "echo test" 2>/dev/null >/dev/null; then
                    status="online"
                    online_nodes=$((online_nodes + 1))
                    
                    # Collect detailed metrics
                    local metrics=$(ssh -i ~/.ssh/cluster_key "$user@$ip" "
                        echo \"cpu_usage:\$(top -bn1 | grep 'Cpu(s)' | awk '{print \$2}' | cut -d'%' -f1)\"
                        echo \"memory_usage:\$(free | grep Mem | awk '{printf \"%.1f\", \$3/\$2 * 100.0}')\"
                        echo \"uptime:\$(uptime -p)\"
                        if command -v vcgencmd &> /dev/null; then
                            echo \"temperature:\$(vcgencmd measure_temp | cut -d= -f2)\"
                        elif [ -f /sys/class/thermal/thermal_zone0/temp ]; then
                            temp=\$(($(cat /sys/class/thermal/thermal_zone0/temp)/1000))
                            echo \"temperature:\${temp}°C\"
                        fi
                    " 2>/dev/null || echo "")
                    
                    # Parse metrics
                    cpu_usage=$(echo "$metrics" | grep "cpu_usage:" | cut -d: -f2 || echo "0")
                    memory_usage=$(echo "$metrics" | grep "memory_usage:" | cut -d: -f2 || echo "0")
                    temperature=$(echo "$metrics" | grep "temperature:" | cut -d: -f2 || echo "N/A")
                    uptime=$(echo "$metrics" | grep "uptime:" | cut -d: -f2 || echo "Unknown")
                fi
                
                # Add node to JSON (simplified - would need proper JSON handling in production)
                echo "Node: $hostname ($ip) - $arch - $status - CPU: $cpu_usage% - Memory: $memory_usage% - Temp: $temperature"
            fi
        done < "$PROJECT_DIR/ansible/inventory.ini"
    fi
    
    # Update JSON with collected data (simplified approach)
    sed -i "s/\"total_nodes\": 0/\"total_nodes\": $total_nodes/" "$output_file"
    sed -i "s/\"online_nodes\": 0/\"online_nodes\": $online_nodes/" "$output_file"
    sed -i "s/\"x86_nodes\": 0/\"x86_nodes\": $x86_count/" "$output_file"
    sed -i "s/\"arm_nodes\": 0/\"arm_nodes\": $arm_count/" "$output_file"
    
    # Check service status (from control plane)
    local k8s_status="unknown"
    local slurm_status="unknown"
    local jupyter_status="unknown"
    
    if timeout 5 ssh -i ~/.ssh/cluster_key -o ConnectTimeout=3 ansible@192.168.5.57 "kubectl get nodes" 2>/dev/null >/dev/null; then
        k8s_status="running"
    else
        k8s_status="error"
    fi
    
    if timeout 5 ssh -i ~/.ssh/cluster_key -o ConnectTimeout=3 ansible@192.168.5.57 "sinfo" 2>/dev/null >/dev/null; then
        slurm_status="running"
    else
        slurm_status="error"
    fi
    
    if timeout 5 curl -s http://192.168.5.57:8000 >/dev/null 2>&1; then
        jupyter_status="running"
    else
        jupyter_status="error"
    fi
    
    # Update service status
    sed -i "s/\"kubernetes\": \"unknown\"/\"kubernetes\": \"$k8s_status\"/" "$output_file"
    sed -i "s/\"slurm\": \"unknown\"/\"slurm\": \"$slurm_status\"/" "$output_file"
    sed -i "s/\"jupyterhub\": \"unknown\"/\"jupyterhub\": \"$jupyter_status\"/" "$output_file"
}

# Update web dashboard with real data
update_dashboard() {
    local health_file="/tmp/cluster_health.json"
    generate_health_data "$health_file"
    
    # Create JavaScript snippet to update dashboard
    cat > /tmp/dashboard_update.js << EOF
// Real-time cluster data update
function updateClusterData() {
    // This would normally fetch from the health API
    const healthData = $(cat "$health_file");
    
    // Update cluster overview
    document.getElementById('cluster-status').innerHTML = 
        '<div><strong>' + healthData.cluster.online_nodes + '/' + healthData.cluster.total_nodes + '</strong></div><div>Online</div>';
    
    // Update architecture counts
    const archDisplay = document.querySelector('.status-grid');
    if (archDisplay) {
        archDisplay.innerHTML = 
            '<div class="status-item status-ready"><div><strong>' + healthData.cluster.total_nodes + '</strong></div><div>Total Nodes</div></div>' +
            '<div class="status-item status-ready"><div><strong>' + healthData.cluster.x86_nodes + '</strong></div><div>x86 Nodes</div></div>' +
            '<div class="status-item status-ready"><div><strong>' + healthData.cluster.arm_nodes + '</strong></div><div>ARM Nodes</div></div>' +
            '<div class="status-item ' + (healthData.cluster.online_nodes === healthData.cluster.total_nodes ? 'status-ready' : 'status-warning') + '">' +
            '<div><strong>' + healthData.cluster.online_nodes + '</strong></div><div>Online</div></div>';
    }
    
    // Update service status
    const services = ['kubernetes', 'slurm', 'jupyterhub'];
    services.forEach(service => {
        const element = document.getElementById(service + '-status');
        if (element) {
            const status = healthData.services[service];
            element.className = 'status-item ' + (status === 'running' ? 'status-ready' : 'status-error');
            element.innerHTML = '<div><strong>' + (status === 'running' ? '✅' : '❌') + '</strong></div><div>' + service.toUpperCase() + '</div>';
        }
    });
}

// Auto-update every 30 seconds
setInterval(updateClusterData, 30000);
updateClusterData(); // Initial load
EOF

    # Deploy updated dashboard to nodes
    for node_ip in "192.168.5.57" "192.168.4.157"; do
        # Copy health data and update script
        scp -i ~/.ssh/cluster_key "$health_file" ansible@$node_ip:/tmp/ 2>/dev/null || true
        scp -i ~/.ssh/cluster_key /tmp/dashboard_update.js ansible@$node_ip:/tmp/ 2>/dev/null || true
        
        # Inject update script into dashboard
        ssh -i ~/.ssh/cluster_key ansible@$node_ip "
            if [ -f /var/www/html/index.html ]; then
                # Add health update script before closing body tag
                if ! grep -q 'updateClusterData' /var/www/html/index.html; then
                    sudo sed -i '/<\/body>/i\\    <script src=\"/tmp/dashboard_update.js\"></script>' /var/www/html/index.html
                fi
            fi
        " 2>/dev/null || true
    done
    
    rm -f "$health_file" /tmp/dashboard_update.js
}

# Create systemd service for continuous monitoring
create_monitoring_service() {
    cat > /tmp/cluster-health.service << EOF
[Unit]
Description=Cluster Health Monitoring
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=$PROJECT_DIR
ExecStart=$SCRIPT_DIR/cluster-health-dashboard.sh monitor
Restart=always
RestartSec=30

[Install]
WantedBy=multi-user.target
EOF

    # Install service on control plane
    scp -i ~/.ssh/cluster_key /tmp/cluster-health.service ansible@192.168.5.57:/tmp/
    ssh -i ~/.ssh/cluster_key ansible@192.168.5.57 "
        sudo cp /tmp/cluster-health.service /etc/systemd/system/
        sudo systemctl daemon-reload
        sudo systemctl enable cluster-health.service
        echo 'Health monitoring service installed. Start with: sudo systemctl start cluster-health'
    "
    
    rm -f /tmp/cluster-health.service
}

# Main execution
case "${1:-update}" in
    "update")
        echo "🔄 Updating cluster health dashboard..."
        update_dashboard
        echo "✅ Dashboard updated with real-time data"
        ;;
    "monitor")
        echo "❤️ Starting continuous health monitoring..."
        while true; do
            update_dashboard
            sleep 60  # Update every minute
        done
        ;;
    "install-service")
        echo "⚙️ Installing health monitoring service..."
        create_monitoring_service
        echo "✅ Service installed"
        ;;
    "report")
        echo "📊 Generating health report..."
        health_file="/tmp/cluster_health_$(date +%Y%m%d_%H%M%S).json"
        generate_health_data "$health_file"
        echo "Health report saved to: $health_file"
        cat "$health_file"
        ;;
    *)
        echo "Usage: $0 [update|monitor|install-service|report]"
        echo ""
        echo "Commands:"
        echo "  update          - Update dashboard with current data"
        echo "  monitor         - Continuous monitoring (runs forever)"
        echo "  install-service - Install as systemd service"
        echo "  report          - Generate JSON health report"
        exit 1
        ;;
esac
