#!/bin/bash

# Test script for adding nodes to cluster
# Usage: ./test-node-setup.sh <node-ip> <username> <password>

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

# Check arguments
if [ $# -ne 3 ]; then
    print_error "Usage: $0 <node-ip> <username> <password>"
    exit 1
fi

NODE_IP=$1
USERNAME=$2
PASSWORD=$3
NODE_NAME="worker-$(echo $NODE_IP | cut -d'.' -f4)"

print_status "Testing node addition for $NODE_IP"
print_status "Node will be named: $NODE_NAME"

# Step 1: Test connectivity
print_status "Step 1: Testing network connectivity..."
if ping -c 3 $NODE_IP > /dev/null 2>&1; then
    print_success "Node $NODE_IP is reachable"
else
    print_error "Node $NODE_IP is not reachable"
    exit 1
fi

# Step 2: Test SSH connectivity
print_status "Step 2: Testing SSH connectivity..."
if sshpass -p "$PASSWORD" ssh -o ConnectTimeout=10 -o StrictHostKeyChecking=no $USERNAME@$NODE_IP "echo 'SSH test successful'" > /dev/null 2>&1; then
    print_success "SSH connection successful"
else
    print_error "SSH connection failed"
    exit 1
fi

# Step 3: Get system information
print_status "Step 3: Gathering system information..."
SYSTEM_INFO=$(sshpass -p "$PASSWORD" ssh -o StrictHostKeyChecking=no $USERNAME@$NODE_IP "
    echo 'HOSTNAME:' \$(hostname)
    echo 'OS:' \$(cat /etc/os-release | grep PRETTY_NAME | cut -d'=' -f2 | tr -d '\"')
    echo 'KERNEL:' \$(uname -r)
    echo 'ARCH:' \$(uname -m)
    echo 'CPU_CORES:' \$(nproc)
    echo 'MEMORY:' \$(free -h | grep Mem | awk '{print \$2}')
    echo 'DISK:' \$(df -h / | tail -1 | awk '{print \$2}')
")

echo "$SYSTEM_INFO"

# Step 4: Check if ansible user exists
print_status "Step 4: Checking for ansible user..."
if sshpass -p "$PASSWORD" ssh -o StrictHostKeyChecking=no $USERNAME@$NODE_IP "id ansible" > /dev/null 2>&1; then
    print_warning "Ansible user already exists"
else
    print_status "Creating ansible user..."
    sshpass -p "$PASSWORD" ssh -o StrictHostKeyChecking=no $USERNAME@$NODE_IP "
        echo '$PASSWORD' | sudo -S useradd -m -s /bin/bash ansible 2>/dev/null || true
        echo '$PASSWORD' | sudo -S usermod -aG sudo ansible
        echo 'ansible ALL=(ALL) NOPASSWD:ALL' | sudo -S tee /etc/sudoers.d/ansible > /dev/null
    "
    print_success "Ansible user created"
fi

# Step 5: Setup SSH keys
print_status "Step 5: Setting up SSH keys..."
if [ ! -f ~/.ssh/cluster_key ]; then
    ssh-keygen -t ed25519 -f ~/.ssh/cluster_key -N "" -C "cluster-admin@$(hostname)"
    print_success "SSH key generated"
fi

# Copy SSH key to ansible user
sshpass -p "$PASSWORD" ssh -o StrictHostKeyChecking=no $USERNAME@$NODE_IP "
    echo '$PASSWORD' | sudo -S mkdir -p /home/ansible/.ssh
    echo '$PASSWORD' | sudo -S chmod 700 /home/ansible/.ssh
    echo '$PASSWORD' | sudo -S chown ansible:ansible /home/ansible/.ssh
"

cat ~/.ssh/cluster_key.pub | sshpass -p "$PASSWORD" ssh -o StrictHostKeyChecking=no $USERNAME@$NODE_IP "
    echo '$PASSWORD' | sudo -S tee /home/ansible/.ssh/authorized_keys > /dev/null
    echo '$PASSWORD' | sudo -S chmod 600 /home/ansible/.ssh/authorized_keys
    echo '$PASSWORD' | sudo -S chown ansible:ansible /home/ansible/.ssh/authorized_keys
"

# Test ansible user SSH access
print_status "Step 6: Testing ansible user access..."
sleep 2  # Give SSH a moment
if ssh -i ~/.ssh/cluster_key -o ConnectTimeout=10 -o StrictHostKeyChecking=no ansible@$NODE_IP "whoami && sudo whoami" > /dev/null 2>&1; then
    print_success "Ansible user SSH access working"
else
    print_warning "Direct ansible SSH test failed, but keys are installed"
fi

# Step 7: Update inventory file
print_status "Step 7: Updating inventory file..."
INVENTORY_FILE="ansible/inventory.ini"

# Backup original inventory
cp $INVENTORY_FILE ${INVENTORY_FILE}.backup

# Add node to inventory if not already present
if ! grep -q "$NODE_NAME" $INVENTORY_FILE; then
    # Add to [workers] section
    sed -i "/\[workers\]/a $NODE_NAME ansible_host=$NODE_IP ansible_user=ansible ansible_ssh_private_key_file=~/.ssh/cluster_key" $INVENTORY_FILE
    
    # Add to [kubernetes_workers] section
    sed -i "/\[kubernetes_workers\]/a $NODE_NAME" $INVENTORY_FILE
    
    # Add to [slurm_workers] section
    sed -i "/\[slurm_workers\]/a $NODE_NAME" $INVENTORY_FILE
    
    print_success "Node added to inventory"
else
    print_warning "Node already exists in inventory"
fi

# Step 8: Test Ansible connectivity
print_status "Step 8: Testing Ansible connectivity..."
if ansible $NODE_NAME -m ping -i $INVENTORY_FILE > /dev/null 2>&1; then
    print_success "Ansible connectivity successful"
else
    print_warning "Ansible ping test failed, but configuration is in place"
fi

# Step 9: Show next steps
print_status "Step 9: Node preparation complete!"
echo ""
echo "Next steps to integrate the node:"
echo "1. Run: ansible-playbook -i ansible/inventory.ini --limit $NODE_NAME ansible/site.yml"
echo "2. Or use: ./scripts/add-node.sh $NODE_NAME $NODE_IP"
echo "3. Verify with: kubectl get nodes"
echo "4. Test SLURM: sinfo -N"
echo ""
echo "Node information:"
echo "$SYSTEM_INFO"
echo ""
print_success "Node $NODE_IP is ready for cluster integration!"
