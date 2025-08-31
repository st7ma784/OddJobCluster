#!/bin/bash

# Node Repair and Recovery Script
# Automatically fixes common cluster node issues

set -euo pipefail

SSH_KEY="$HOME/.ssh/cluster_key"
NODE_IP="$1"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log() {
    echo -e "${GREEN}[$(date +'%H:%M:%S')]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Fix containerd issues
fix_containerd() {
    log "Fixing containerd configuration..."
    
    ssh -i "$SSH_KEY" "ansible@$NODE_IP" << 'EOF'
        # Stop services
        sudo systemctl stop kubelet containerd
        
        # Generate fresh containerd config
        sudo containerd config default | sudo tee /etc/containerd/config.toml
        sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml
        
        # Clean up containers and restart
        sudo systemctl start containerd
        sleep 5
        sudo systemctl start kubelet
        
        echo "Containerd fixed and restarted"
EOF
}

# Fix Kubernetes node issues
fix_kubernetes() {
    log "Fixing Kubernetes node issues..."
    
    ssh -i "$SSH_KEY" "ansible@$NODE_IP" << 'EOF'
        # Reset and rejoin if needed
        if ! kubectl get nodes 2>/dev/null; then
            echo "Kubernetes not accessible, attempting reset..."
            sudo kubeadm reset -f
            
            # Reinitialize as single node cluster
            sudo kubeadm init --pod-network-cidr=10.244.0.0/16 --apiserver-advertise-address=$(hostname -I | awk '{print $1}')
            
            # Setup kubectl
            mkdir -p $HOME/.kube
            sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
            sudo chown $(id -u):$(id -g) $HOME/.kube/config
            
            # Install network plugin
            kubectl apply -f https://raw.githubusercontent.com/flannel-io/flannel/master/Documentation/kube-flannel.yml
            kubectl taint nodes --all node-role.kubernetes.io/control-plane-
        fi
EOF
}

# Fix SLURM services
fix_slurm() {
    log "Fixing SLURM services..."
    
    ssh -i "$SSH_KEY" "ansible@$NODE_IP" << 'EOF'
        # Restart SLURM services
        sudo systemctl restart munge
        sleep 2
        sudo systemctl restart slurmctld
        sleep 2
        sudo systemctl restart slurmd
        
        echo "SLURM services restarted"
EOF
}

# Fix JupyterHub
fix_jupyterhub() {
    log "Fixing JupyterHub service..."
    
    ssh -i "$SSH_KEY" "ansible@$NODE_IP" << 'EOF'
        # Restart JupyterHub
        sudo systemctl restart jupyterhub
        
        echo "JupyterHub restarted"
EOF
}

# Main repair function
main() {
    log "Starting node repair for $NODE_IP..."
    
    # Check connectivity
    if ! ssh -i "$SSH_KEY" -o ConnectTimeout=5 "ansible@$NODE_IP" "echo 'Connected'" 2>/dev/null; then
        error "Cannot connect to $NODE_IP"
        exit 1
    fi
    
    # Run repairs
    fix_containerd
    sleep 10
    fix_kubernetes
    sleep 10
    fix_slurm
    sleep 5
    fix_jupyterhub
    
    log "Node repair completed for $NODE_IP"
    log "Running health check..."
    
    # Quick health check
    ssh -i "$SSH_KEY" "ansible@$NODE_IP" << 'EOF'
        echo "=== Service Status ==="
        systemctl is-active containerd kubelet slurmctld slurmd jupyterhub | paste <(echo -e "containerd\nkubelet\nslurmctld\nslurmd\njupyterhub") -
        
        echo -e "\n=== Kubernetes Nodes ==="
        kubectl get nodes 2>/dev/null || echo "Kubernetes not ready"
        
        echo -e "\n=== SLURM Status ==="
        sinfo 2>/dev/null || echo "SLURM not ready"
EOF
    
    log "Repair and verification completed!"
}

if [[ $# -eq 0 ]]; then
    echo "Usage: $0 <node-ip>"
    exit 1
fi

main
