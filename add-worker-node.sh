#!/bin/bash

# Script to add additional worker nodes to the Kubernetes cluster
# This script handles the common kubelet configuration issues

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}=== Kubernetes Worker Node Addition Script ===${NC}"

# Function to print status
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if running as root
if [ "$EUID" -eq 0 ]; then
    print_error "Please do not run this script as root. It will use sudo when needed."
    exit 1
fi

# Get join command from master
print_status "Getting join command from master node..."
JOIN_COMMAND=$(ansible master -i ansible/inventory_working.ini -m shell -a "export KUBECONFIG=/etc/kubernetes/admin.conf && kubeadm token create --print-join-command" --become | grep "kubeadm join" | tail -1)

if [ -z "$JOIN_COMMAND" ]; then
    print_error "Failed to get join command from master"
    exit 1
fi

print_status "Join command obtained: $JOIN_COMMAND"

# Function to setup a worker node
setup_worker_node() {
    local node_name=$1
    local node_host=$2
    
    print_status "Setting up worker node: $node_name ($node_host)"
    
    # Reset any existing cluster configuration
    print_status "Resetting existing Kubernetes configuration on $node_name..."
    if [ "$node_name" == "scc-ws-01" ]; then
        # Local node
        sudo kubeadm reset -f 2>/dev/null || true
        sudo rm -rf /etc/kubernetes/pki /var/lib/etcd 2>/dev/null || true
        
        # Ensure containerd is properly configured
        print_status "Configuring containerd..."
        sudo containerd config default | sudo tee /etc/containerd/config.toml > /dev/null
        sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml
        sudo systemctl restart containerd
        
        # Load bridge module
        sudo modprobe br_netfilter
        
        # Apply kernel parameters
        sudo sysctl --system > /dev/null
        
        # Join the cluster
        print_status "Joining cluster..."
        sudo $JOIN_COMMAND --ignore-preflight-errors=Swap
        
    else
        # Remote node
        ansible $node_name -i ansible/inventory_working.ini -m shell -a "sudo kubeadm reset -f" --become 2>/dev/null || true
        ansible $node_name -i ansible/inventory_working.ini -m shell -a "sudo rm -rf /etc/kubernetes/pki /var/lib/etcd" --become 2>/dev/null || true
        
        # Ensure Docker/containerd is running
        print_status "Ensuring container runtime is running on $node_name..."
        ansible $node_name -i ansible/inventory_working.ini -m shell -a "sudo systemctl restart containerd && sudo systemctl restart docker" --become
        
        # Load bridge module and apply sysctl
        ansible $node_name -i ansible/inventory_working.ini -m shell -a "sudo modprobe br_netfilter && sudo sysctl --system" --become
        
        # Join the cluster
        print_status "Joining cluster..."
        ansible $node_name -i ansible/inventory_working.ini -m shell -a "sudo $JOIN_COMMAND --ignore-preflight-errors=Swap" --become
    fi
}

# Menu for node selection
echo
echo "Available nodes to add:"
echo "1) cluster-node-1 (192.168.4.31) - Third node that came back online"
echo "2) scc-ws-01 (10.48.240.32) - Current local system"
echo "3) All pending nodes"
echo "4) Exit"
echo

read -p "Select option (1-4): " choice

case $choice in
    1)
        setup_worker_node "cluster-node-1" "192.168.4.31"
        ;;
    2)
        setup_worker_node "scc-ws-01" "10.48.240.32"
        ;;
    3)
        setup_worker_node "cluster-node-1" "192.168.4.31"
        sleep 5
        setup_worker_node "scc-ws-01" "10.48.240.32"
        ;;
    4)
        print_status "Exiting..."
        exit 0
        ;;
    *)
        print_error "Invalid option"
        exit 1
        ;;
esac

# Verify the node joined successfully
print_status "Waiting for node to be ready..."
sleep 10

print_status "Checking cluster status..."
ansible master -i ansible/inventory_working.ini -m shell -a "export KUBECONFIG=/etc/kubernetes/admin.conf && kubectl get nodes -o wide" --become

print_status "Worker node addition process completed!"
print_status "Check the output above to verify the node status."
