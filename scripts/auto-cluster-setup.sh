#!/bin/bash

# Automated Kubernetes SLURM Jupyter Cluster Setup
# This script automates the complete cluster integration process

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
ANSIBLE_DIR="$PROJECT_ROOT/ansible"
SSH_KEY="$HOME/.ssh/cluster_key"
LOG_FILE="$PROJECT_ROOT/auto-setup-$(date +%Y%m%d_%H%M%S).log"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging function
log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1" | tee -a "$LOG_FILE"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1" | tee -a "$LOG_FILE"
    exit 1
}

warn() {
    echo -e "${YELLOW}[WARNING]${NC} $1" | tee -a "$LOG_FILE"
}

info() {
    echo -e "${BLUE}[INFO]${NC} $1" | tee -a "$LOG_FILE"
}

# Check prerequisites
check_prerequisites() {
    log "Checking prerequisites..."
    
    # Check if running from correct directory
    if [[ ! -f "$ANSIBLE_DIR/site.yml" ]]; then
        error "Must run from project root directory"
    fi
    
    # Check required tools
    for tool in ansible-playbook ssh-keygen kubectl; do
        if ! command -v "$tool" &> /dev/null; then
            error "$tool is not installed"
        fi
    done
    
    # Check SSH key exists
    if [[ ! -f "$SSH_KEY" ]]; then
        warn "SSH key not found, will generate new one"
        generate_ssh_key
    fi
    
    log "Prerequisites check completed"
}

# Generate SSH key for cluster access
generate_ssh_key() {
    log "Generating SSH key for cluster access..."
    ssh-keygen -t rsa -b 4096 -f "$SSH_KEY" -N "" -C "ansible@cluster"
    chmod 600 "$SSH_KEY"
    chmod 644 "$SSH_KEY.pub"
    log "SSH key generated: $SSH_KEY"
}

# Discover available nodes
discover_nodes() {
    log "Discovering available nodes..."
    
    if [[ -f "$PROJECT_ROOT/scripts/discover-nodes.sh" ]]; then
        bash "$PROJECT_ROOT/scripts/discover-nodes.sh" | tee -a "$LOG_FILE"
    else
        info "Running basic network scan..."
        # Basic network discovery
        for ip in 192.168.{4,5}.{50..200}; do
            if ping -c 1 -W 1 "$ip" &>/dev/null; then
                echo "Found active node: $ip"
            fi
        done
    fi
}

# Setup SSH access to a node
setup_ssh_access() {
    local node_ip="$1"
    local username="${2:-ansible}"
    
    log "Setting up SSH access to $node_ip..."
    
    # Check if SSH key is already deployed
    if ssh -i "$SSH_KEY" -o ConnectTimeout=5 -o StrictHostKeyChecking=no "$username@$node_ip" "echo 'SSH key access verified'" 2>/dev/null; then
        log "SSH key access already configured for $node_ip"
        return 0
    fi
    
    # Try to copy SSH key (will prompt for password)
    info "Copying SSH key to $node_ip (password required)..."
    if ssh-copy-id -i "$SSH_KEY.pub" "$username@$node_ip" 2>/dev/null; then
        log "SSH key deployed successfully to $node_ip"
        return 0
    else
        warn "Failed to deploy SSH key to $node_ip"
        return 1
    fi
}

# Deploy cluster components to a node
deploy_to_node() {
    local node_ip="$1"
    local node_role="${2:-worker}"
    
    log "Deploying cluster components to $node_ip (role: $node_role)..."
    
    # Update inventory for this node
    update_inventory "$node_ip" "$node_role"
    
    # Run Ansible playbook
    cd "$ANSIBLE_DIR"
    
    if ansible-playbook -i inventory.ini --limit "$node_ip" site.yml; then
        log "Successfully deployed to $node_ip"
    else
        error "Failed to deploy to $node_ip"
    fi
    
    cd "$PROJECT_ROOT"
}

# Update Ansible inventory
update_inventory() {
    local node_ip="$1"
    local role="$2"
    
    log "Updating inventory for $node_ip..."
    
    # Backup current inventory
    cp "$ANSIBLE_DIR/inventory.ini" "$ANSIBLE_DIR/inventory.ini.backup.$(date +%Y%m%d_%H%M%S)"
    
    # Add node to inventory if not already present
    if ! grep -q "$node_ip" "$ANSIBLE_DIR/inventory.ini"; then
        case "$role" in
            "master"|"control-plane")
                sed -i "/\[masters\]/a $node_ip ansible_user=ansible ansible_ssh_private_key_file=$SSH_KEY" "$ANSIBLE_DIR/inventory.ini"
                ;;
            "worker")
                sed -i "/\[workers\]/a $node_ip ansible_user=ansible ansible_ssh_private_key_file=$SSH_KEY" "$ANSIBLE_DIR/inventory.ini"
                ;;
        esac
        log "Added $node_ip to inventory as $role"
    fi
}

# Initialize Kubernetes cluster
init_kubernetes_cluster() {
    local master_ip="$1"
    
    log "Initializing Kubernetes cluster on $master_ip..."
    
    ssh -i "$SSH_KEY" "ansible@$master_ip" << 'EOF'
        # Initialize cluster if not already done
        if ! kubectl get nodes 2>/dev/null; then
            sudo kubeadm init --pod-network-cidr=10.244.0.0/16 --apiserver-advertise-address=$(hostname -I | awk '{print $1}')
            
            # Setup kubectl for ansible user
            mkdir -p $HOME/.kube
            sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
            sudo chown $(id -u):$(id -g) $HOME/.kube/config
            
            # Install Flannel network plugin
            kubectl apply -f https://raw.githubusercontent.com/flannel-io/flannel/master/Documentation/kube-flannel.yml
            
            # Remove taint from master to allow scheduling
            kubectl taint nodes --all node-role.kubernetes.io/control-plane-
        fi
EOF
    
    log "Kubernetes cluster initialized on $master_ip"
}

# Fix containerd configuration
fix_containerd() {
    local node_ip="$1"
    
    log "Fixing containerd configuration on $node_ip..."
    
    ssh -i "$SSH_KEY" "ansible@$node_ip" << 'EOF'
        # Generate default containerd config
        sudo containerd config default | sudo tee /etc/containerd/config.toml
        
        # Enable SystemdCgroup
        sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml
        
        # Restart containerd and kubelet
        sudo systemctl restart containerd
        sudo systemctl restart kubelet
EOF
    
    log "Containerd configuration fixed on $node_ip"
}

# Verify cluster health
verify_cluster_health() {
    local master_ip="$1"
    
    log "Verifying cluster health on $master_ip..."
    
    ssh -i "$SSH_KEY" "ansible@$master_ip" << 'EOF'
        echo "=== Kubernetes Nodes ==="
        kubectl get nodes -o wide
        
        echo -e "\n=== Kubernetes Pods ==="
        kubectl get pods -A
        
        echo -e "\n=== SLURM Status ==="
        sinfo
        
        echo -e "\n=== SLURM Services ==="
        systemctl is-active slurmctld slurmd munge
        
        echo -e "\n=== JupyterHub Status ==="
        systemctl is-active jupyterhub
        
        echo -e "\n=== Service Ports ==="
        ss -tlnp | grep -E ':(6443|8000|6817)'
EOF
    
    log "Cluster health verification completed"
}

# Main automation workflow
main() {
    log "Starting automated Kubernetes SLURM Jupyter cluster setup..."
    log "Log file: $LOG_FILE"
    
    # Parse command line arguments
    NODES=()
    MASTER_NODE=""
    AUTO_DISCOVER=false
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            --master)
                MASTER_NODE="$2"
                shift 2
                ;;
            --node)
                NODES+=("$2")
                shift 2
                ;;
            --discover)
                AUTO_DISCOVER=true
                shift
                ;;
            --help)
                echo "Usage: $0 [--master IP] [--node IP] [--discover]"
                echo "  --master IP    : Specify master node IP"
                echo "  --node IP      : Add worker node IP (can be used multiple times)"
                echo "  --discover     : Auto-discover nodes on network"
                exit 0
                ;;
            *)
                error "Unknown option: $1"
                ;;
        esac
    done
    
    # Step 1: Prerequisites
    check_prerequisites
    
    # Step 2: Node discovery
    if [[ "$AUTO_DISCOVER" == true ]]; then
        discover_nodes
    fi
    
    # Step 3: Setup master node
    if [[ -n "$MASTER_NODE" ]]; then
        log "Processing master node: $MASTER_NODE"
        
        # Setup SSH access
        setup_ssh_access "$MASTER_NODE"
        
        # Deploy components
        deploy_to_node "$MASTER_NODE" "master"
        
        # Fix containerd
        fix_containerd "$MASTER_NODE"
        
        # Initialize Kubernetes
        init_kubernetes_cluster "$MASTER_NODE"
        
        # Verify health
        verify_cluster_health "$MASTER_NODE"
        
    else
        warn "No master node specified, skipping cluster initialization"
    fi
    
    # Step 4: Setup worker nodes
    for node in "${NODES[@]}"; do
        log "Processing worker node: $node"
        
        # Setup SSH access
        setup_ssh_access "$node"
        
        # Deploy components
        deploy_to_node "$node" "worker"
        
        # Fix containerd
        fix_containerd "$node"
    done
    
    log "Automated cluster setup completed successfully!"
    log "Access your cluster:"
    log "  - JupyterHub: http://$MASTER_NODE:8000"
    log "  - Kubernetes API: https://$MASTER_NODE:6443"
    log "  - SSH: ssh -i $SSH_KEY ansible@$MASTER_NODE"
}

# Run main function with all arguments
main "$@"
