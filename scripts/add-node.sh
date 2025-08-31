#!/bin/bash

# Add Node Script - Automated node addition to the cluster
# Usage: ./scripts/add-node.sh <node-ip> <node-hostname>

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

show_usage() {
    echo "Usage: $0 <node-ip> <node-hostname>"
    echo ""
    echo "Example:"
    echo "  $0 192.168.1.13 worker3"
    echo ""
    echo "This script will:"
    echo "  1. Prepare the new node"
    echo "  2. Add it to the inventory"
    echo "  3. Deploy cluster components"
    echo "  4. Verify the node joined successfully"
}

# Check arguments
if [ $# -ne 2 ]; then
    print_error "Invalid number of arguments"
    show_usage
    exit 1
fi

NODE_IP=$1
NODE_HOSTNAME=$2

# Validate IP format
if ! [[ $NODE_IP =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
    print_error "Invalid IP address format: $NODE_IP"
    exit 1
fi

# Check if running from project root
if [ ! -f "ansible/inventory.ini" ]; then
    print_error "Please run this script from the project root directory"
    exit 1
fi

print_status "Adding node $NODE_HOSTNAME ($NODE_IP) to the cluster..."

# Step 1: Prepare the new node
print_status "Step 1: Preparing new node..."

# Test initial connectivity
if ! ping -c 1 -W 5 $NODE_IP > /dev/null 2>&1; then
    print_error "Cannot reach node at $NODE_IP"
    exit 1
fi

# Prepare node via SSH
print_status "Setting up ansible user on new node..."
ssh -o StrictHostKeyChecking=no root@$NODE_IP << 'EOF'
# Update system
apt update && apt upgrade -y

# Create ansible user
useradd -m -s /bin/bash ansible || true
usermod -aG sudo ansible
echo "ansible ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/ansible

# Set up SSH key access
mkdir -p /home/ansible/.ssh
cp ~/.ssh/authorized_keys /home/ansible/.ssh/ 2>/dev/null || cp /root/.ssh/authorized_keys /home/ansible/.ssh/
chown -R ansible:ansible /home/ansible/.ssh
chmod 700 /home/ansible/.ssh
chmod 600 /home/ansible/.ssh/authorized_keys

# Install required packages
apt install -y python3 python3-pip curl

echo "Node preparation completed"
EOF

if [ $? -ne 0 ]; then
    print_error "Failed to prepare node"
    exit 1
fi

print_success "Node preparation completed"

# Step 2: Add to inventory
print_status "Step 2: Adding node to inventory..."

# Backup inventory
cp ansible/inventory.ini ansible/inventory.ini.backup

# Check if node already exists
if grep -q "$NODE_HOSTNAME" ansible/inventory.ini; then
    print_warning "Node $NODE_HOSTNAME already exists in inventory"
else
    # Add to workers section
    sed -i "/^\[workers\]/a $NODE_HOSTNAME ansible_host=$NODE_IP" ansible/inventory.ini
    print_success "Node added to inventory"
fi

# Step 3: Test connectivity
print_status "Step 3: Testing connectivity..."
if ansible $NODE_HOSTNAME -i ansible/inventory.ini -m ping > /dev/null 2>&1; then
    print_success "Ansible connectivity verified"
else
    print_error "Ansible connectivity failed"
    # Restore backup
    mv ansible/inventory.ini.backup ansible/inventory.ini
    exit 1
fi

# Step 4: Deploy to new node
print_status "Step 4: Deploying cluster components to new node..."
if ansible-playbook -i ansible/inventory.ini ansible/site.yml --limit=$NODE_HOSTNAME; then
    print_success "Deployment completed successfully"
else
    print_error "Deployment failed"
    # Restore backup
    mv ansible/inventory.ini.backup ansible/inventory.ini
    exit 1
fi

# Step 5: Verify node joined cluster
print_status "Step 5: Verifying node joined cluster..."

# Wait for node to be ready
sleep 30

# Check Kubernetes
MASTER_HOST=$(ansible master -i ansible/inventory.ini --list-hosts | grep -v "hosts" | head -1 | xargs)
K8S_STATUS=$(ansible $MASTER_HOST -i ansible/inventory.ini -m shell -a "kubectl get nodes $NODE_HOSTNAME --no-headers | awk '{print \$2}'" 2>/dev/null | grep -v "SUCCESS" | tail -1)

if [ "$K8S_STATUS" = "Ready" ]; then
    print_success "Node successfully joined Kubernetes cluster"
else
    print_warning "Node may not be ready in Kubernetes yet (Status: $K8S_STATUS)"
fi

# Check SLURM
SLURM_STATUS=$(ansible $MASTER_HOST -i ansible/inventory.ini -m shell -a "sinfo -N -h -n $NODE_HOSTNAME | awk '{print \$4}'" 2>/dev/null | grep -v "SUCCESS" | tail -1)

if [ "$SLURM_STATUS" = "idle" ] || [ "$SLURM_STATUS" = "alloc" ]; then
    print_success "Node successfully joined SLURM cluster"
else
    print_warning "Node may not be ready in SLURM yet (Status: $SLURM_STATUS)"
fi

# Clean up backup
rm -f ansible/inventory.ini.backup

print_success "Node $NODE_HOSTNAME has been successfully added to the cluster!"
print_status "Node details:"
echo "  - IP Address: $NODE_IP"
echo "  - Hostname: $NODE_HOSTNAME"
echo "  - Kubernetes Status: $K8S_STATUS"
echo "  - SLURM Status: $SLURM_STATUS"

print_status "To verify the deployment, run:"
echo "  ./scripts/validate-cluster.sh"
echo "  kubectl get nodes"
echo "  sinfo"
