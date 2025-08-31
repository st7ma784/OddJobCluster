#!/bin/bash

# Cluster Health Check and Monitoring Script
# Verifies all cluster components are running correctly

set -euo pipefail

SSH_KEY="$HOME/.ssh/cluster_key"
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

check_node() {
    local node_ip="$1"
    echo -e "\n${GREEN}=== Checking Node: $node_ip ===${NC}"
    
    if ! ssh -i "$SSH_KEY" -o ConnectTimeout=5 "ansible@$node_ip" "echo 'Connection OK'" 2>/dev/null; then
        echo -e "${RED}❌ SSH connection failed${NC}"
        return 1
    fi
    
    ssh -i "$SSH_KEY" "ansible@$node_ip" << 'EOF'
        echo "🔍 System Status:"
        echo "  Uptime: $(uptime -p)"
        echo "  Load: $(cat /proc/loadavg | awk '{print $1, $2, $3}')"
        echo "  Memory: $(free -h | awk '/^Mem:/ {print $3"/"$2}')"
        echo "  Disk: $(df -h / | awk 'NR==2 {print $3"/"$2" ("$5" used)"}')"
        
        echo -e "\n🐳 Container Runtime:"
        if systemctl is-active containerd >/dev/null 2>&1; then
            echo "  ✅ containerd: active"
        else
            echo "  ❌ containerd: inactive"
        fi
        
        echo -e "\n☸️  Kubernetes:"
        if kubectl get nodes >/dev/null 2>&1; then
            echo "  ✅ kubectl: working"
            kubectl get nodes --no-headers | while read node status role age version; do
                echo "    Node: $node ($status)"
            done
        else
            echo "  ❌ kubectl: not working"
        fi
        
        echo -e "\n⚡ SLURM:"
        for service in slurmctld slurmd munge; do
            if systemctl is-active $service >/dev/null 2>&1; then
                echo "  ✅ $service: active"
            else
                echo "  ❌ $service: inactive"
            fi
        done
        
        if command -v sinfo >/dev/null 2>&1; then
            echo "  Partitions:"
            sinfo --noheader | while read partition avail timelimit nodes state nodelist; do
                echo "    $partition: $nodes nodes ($state)"
            done
        fi
        
        echo -e "\n📓 JupyterHub:"
        if systemctl is-active jupyterhub >/dev/null 2>&1; then
            echo "  ✅ jupyterhub: active"
            if ss -tlnp | grep :8000 >/dev/null 2>&1; then
                echo "  ✅ port 8000: listening"
            else
                echo "  ❌ port 8000: not listening"
            fi
        else
            echo "  ❌ jupyterhub: inactive"
        fi
        
        echo -e "\n🌐 Network Ports:"
        ss -tlnp | grep -E ':(6443|8000|6817)' | while read line; do
            port=$(echo "$line" | awk '{print $4}' | cut -d: -f2)
            echo "  Port $port: listening"
        done
EOF
}

# Main function
main() {
    echo "🏥 Cluster Health Check Starting..."
    
    # Read nodes from inventory
    if [[ -f "ansible/inventory.ini" ]]; then
        echo "📋 Reading nodes from inventory..."
        
        # Extract IPs from inventory - only check reachable nodes
        nodes=$(grep -E 'ansible_host=' ansible/inventory.ini | grep -v 'ansible_ssh_pass' | sed 's/.*ansible_host=\([0-9.]*\).*/\1/' | sort -u)
        
        if [[ -z "$nodes" ]]; then
            echo -e "${YELLOW}⚠️  No nodes found in inventory${NC}"
            exit 1
        fi
        
        # Check each node
        for node in $nodes; do
            check_node "$node"
        done
        
    else
        echo -e "${RED}❌ inventory.ini not found${NC}"
        exit 1
    fi
    
    echo -e "\n${GREEN}✅ Health check completed${NC}"
}

main "$@"
