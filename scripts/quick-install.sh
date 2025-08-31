#!/bin/bash

# Quick Install Script - One-line cluster deployment
# Usage: curl -fsSL https://raw.githubusercontent.com/yourusername/kubernetes-slurm-cluster/main/scripts/quick-install.sh | bash

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_banner() {
    echo -e "${BLUE}"
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║           Kubernetes Cluster with SLURM and Jupyter         ║"
    echo "║                     Quick Install Script                     ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

# Check if running as root
if [ "$EUID" -eq 0 ]; then
    print_error "Please do not run this script as root"
    exit 1
fi

print_banner
print_status "Starting quick installation..."

# Check prerequisites
print_status "Checking prerequisites..."

# Check OS
if ! grep -q "Ubuntu 22.04" /etc/os-release; then
    print_warning "This script is designed for Ubuntu 22.04 LTS"
    read -p "Continue anyway? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# Check required commands
REQUIRED_COMMANDS=("git" "python3" "pip3" "ssh")
for cmd in "${REQUIRED_COMMANDS[@]}"; do
    if ! command -v $cmd &> /dev/null; then
        print_status "Installing $cmd..."
        sudo apt update && sudo apt install -y $cmd
    fi
done

# Clone repository
REPO_DIR="kubernetes-slurm-cluster"
if [ -d "$REPO_DIR" ]; then
    print_status "Repository already exists, updating..."
    cd $REPO_DIR
    git pull origin main
else
    print_status "Cloning repository..."
    git clone https://github.com/yourusername/kubernetes-slurm-cluster.git
    cd $REPO_DIR
fi

# Set up Python environment
print_status "Setting up Python environment..."
if [ ! -d "venv" ]; then
    python3 -m venv venv
fi
source venv/bin/activate
pip install -r requirements.txt
ansible-galaxy install -r ansible/requirements.yml

# Interactive configuration
print_status "Starting interactive configuration..."

echo ""
echo "=== Cluster Configuration ==="
echo ""

# Get master node information
read -p "Master node IP address: " MASTER_IP
read -p "Master node hostname [master]: " MASTER_HOST
MASTER_HOST=${MASTER_HOST:-master}

# Validate master IP
if ! [[ $MASTER_IP =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
    print_error "Invalid IP address format"
    exit 1
fi

# Get worker nodes
echo ""
echo "Enter worker nodes (press Enter with empty IP when done):"
WORKERS=()
WORKER_COUNT=1
while true; do
    read -p "Worker $WORKER_COUNT IP (or Enter to finish): " WORKER_IP
    [ -z "$WORKER_IP" ] && break
    
    # Validate worker IP
    if ! [[ $WORKER_IP =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        print_error "Invalid IP address format"
        continue
    fi
    
    read -p "Worker $WORKER_COUNT hostname [worker$WORKER_COUNT]: " WORKER_HOST
    WORKER_HOST=${WORKER_HOST:-worker$WORKER_COUNT}
    
    WORKERS+=("$WORKER_HOST ansible_host=$WORKER_IP")
    ((WORKER_COUNT++))
done

if [ ${#WORKERS[@]} -eq 0 ]; then
    print_error "At least one worker node is required"
    exit 1
fi

# Generate inventory file
print_status "Generating inventory file..."
cat > ansible/inventory.ini << EOF
[all:vars]
ansible_python_interpreter=/usr/bin/python3
ansible_user=ubuntu
ansible_ssh_private_key_file=~/.ssh/id_rsa

[master]
$MASTER_HOST ansible_host=$MASTER_IP

[workers]
$(printf '%s\n' "${WORKERS[@]}")

[kube_control_plane:children]
master

[kube_node:children]
workers

[slurm_control:children]
master

[slurm_node:children]
workers

[jupyter:children]
master
EOF

print_success "Inventory file created"

# Test connectivity
print_status "Testing connectivity to all nodes..."
if ansible all -i ansible/inventory.ini -m ping; then
    print_success "All nodes are reachable"
else
    print_error "Some nodes are not reachable. Please check:"
    echo "  1. SSH key is properly configured"
    echo "  2. All nodes are running and accessible"
    echo "  3. Ubuntu user exists on all nodes"
    exit 1
fi

# Confirm deployment
echo ""
print_status "Ready to deploy cluster with:"
echo "  - Master: $MASTER_HOST ($MASTER_IP)"
echo "  - Workers: ${#WORKERS[@]} nodes"
echo ""
read -p "Proceed with deployment? (Y/n): " -n 1 -r
echo
if [[ $REPLY =~ ^[Nn]$ ]]; then
    print_status "Deployment cancelled"
    exit 0
fi

# Deploy cluster
print_status "Deploying cluster (this may take 15-30 minutes)..."
if ansible-playbook -i ansible/inventory.ini ansible/site.yml; then
    print_success "Cluster deployment completed successfully!"
else
    print_error "Cluster deployment failed"
    exit 1
fi

# Validation
print_status "Validating cluster deployment..."
./scripts/validate-cluster.sh

# Display access information
echo ""
print_success "🎉 Cluster is ready!"
echo ""
echo "Access your services at:"
echo "  - Landing Page: https://$MASTER_IP/"
echo "  - JupyterHub: https://$MASTER_IP/jupyter (admin/admin)"
echo "  - Grafana: https://$MASTER_IP/grafana (admin/admin)"
echo "  - Docker Registry: https://$MASTER_IP/registry"
echo ""
echo "Useful commands:"
echo "  - Get credentials: ./scripts/get-credentials.sh"
echo "  - Add nodes: ./scripts/add-node.sh <ip> <hostname>"
echo "  - Backup cluster: ./scripts/backup-cluster.sh"
echo "  - Manage users: ./scripts/manage-users.sh"
echo ""
echo "Test SLURM with:"
echo "  sbatch examples/slurm-jobs/hello-world.sh"
echo ""
print_success "Installation completed! Happy computing! 🚀"
