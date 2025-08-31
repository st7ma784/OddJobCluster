#!/bin/bash

# Bulk Add Nodes Script - Add multiple nodes to the cluster
# Usage: ./scripts/bulk-add-nodes.sh <nodes-file>

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
    echo "Usage: $0 <nodes-file>"
    echo ""
    echo "The nodes file should contain one node per line in format:"
    echo "  <ip-address> <hostname>"
    echo ""
    echo "Example nodes file:"
    echo "  192.168.1.13 worker3"
    echo "  192.168.1.14 worker4"
    echo "  192.168.1.15 worker5"
}

# Check arguments
if [ $# -ne 1 ]; then
    print_error "Invalid number of arguments"
    show_usage
    exit 1
fi

NODES_FILE=$1

# Check if file exists
if [ ! -f "$NODES_FILE" ]; then
    print_error "Nodes file not found: $NODES_FILE"
    exit 1
fi

# Check if running from project root
if [ ! -f "ansible/inventory.ini" ]; then
    print_error "Please run this script from the project root directory"
    exit 1
fi

print_status "Starting bulk node addition from file: $NODES_FILE"

# Read and validate nodes file
declare -a NODES_IP
declare -a NODES_HOSTNAME

while IFS=' ' read -r ip hostname; do
    # Skip empty lines and comments
    [[ -z "$ip" || "$ip" =~ ^#.*$ ]] && continue
    
    # Validate IP format
    if ! [[ $ip =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        print_error "Invalid IP address format: $ip"
        exit 1
    fi
    
    NODES_IP+=("$ip")
    NODES_HOSTNAME+=("$hostname")
done < "$NODES_FILE"

NODE_COUNT=${#NODES_IP[@]}
print_status "Found $NODE_COUNT nodes to add"

# Display nodes to be added
echo "Nodes to be added:"
for i in "${!NODES_IP[@]}"; do
    echo "  ${NODES_HOSTNAME[$i]} (${NODES_IP[$i]})"
done

# Confirm before proceeding
read -p "Continue with bulk node addition? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    print_status "Bulk node addition cancelled"
    exit 0
fi

# Backup inventory
cp ansible/inventory.ini ansible/inventory.ini.backup

# Phase 1: Prepare all nodes in parallel
print_status "Phase 1: Preparing all nodes..."

prepare_node() {
    local ip=$1
    local hostname=$2
    local logfile="/tmp/prepare_${hostname}.log"
    
    {
        echo "Preparing node $hostname ($ip)..."
        
        # Test connectivity
        if ! ping -c 1 -W 5 $ip > /dev/null 2>&1; then
            echo "ERROR: Cannot reach node at $ip"
            return 1
        fi
        
        # Prepare node via SSH
        ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 root@$ip << 'EOF'
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
        
        echo "SUCCESS: Node $hostname prepared"
    } > "$logfile" 2>&1 &
}

# Start preparation for all nodes
for i in "${!NODES_IP[@]}"; do
    prepare_node "${NODES_IP[$i]}" "${NODES_HOSTNAME[$i]}"
done

# Wait for all preparations to complete
wait

# Check preparation results
FAILED_NODES=()
for i in "${!NODES_HOSTNAME[@]}"; do
    hostname="${NODES_HOSTNAME[$i]}"
    logfile="/tmp/prepare_${hostname}.log"
    
    if grep -q "SUCCESS: Node $hostname prepared" "$logfile"; then
        print_success "Node $hostname prepared successfully"
    else
        print_error "Node $hostname preparation failed"
        FAILED_NODES+=("$hostname")
        cat "$logfile"
    fi
    rm -f "$logfile"
done

# Exit if any preparations failed
if [ ${#FAILED_NODES[@]} -gt 0 ]; then
    print_error "Failed to prepare ${#FAILED_NODES[@]} nodes. Aborting bulk addition."
    exit 1
fi

# Phase 2: Add all nodes to inventory
print_status "Phase 2: Adding nodes to inventory..."

for i in "${!NODES_IP[@]}"; do
    ip="${NODES_IP[$i]}"
    hostname="${NODES_HOSTNAME[$i]}"
    
    # Check if node already exists
    if grep -q "$hostname" ansible/inventory.ini; then
        print_warning "Node $hostname already exists in inventory"
    else
        # Add to workers section
        sed -i "/^\[workers\]/a $hostname ansible_host=$ip" ansible/inventory.ini
        print_success "Added $hostname to inventory"
    fi
done

# Phase 3: Test connectivity to all new nodes
print_status "Phase 3: Testing connectivity to all new nodes..."

NEW_NODES_LIST=$(printf "%s," "${NODES_HOSTNAME[@]}")
NEW_NODES_LIST=${NEW_NODES_LIST%,}  # Remove trailing comma

if ansible $NEW_NODES_LIST -i ansible/inventory.ini -m ping > /dev/null 2>&1; then
    print_success "Ansible connectivity verified for all nodes"
else
    print_error "Ansible connectivity failed for some nodes"
    # Restore backup
    mv ansible/inventory.ini.backup ansible/inventory.ini
    exit 1
fi

# Phase 4: Deploy to all new nodes
print_status "Phase 4: Deploying cluster components to all new nodes..."
if ansible-playbook -i ansible/inventory.ini ansible/site.yml --limit="$NEW_NODES_LIST"; then
    print_success "Deployment completed successfully for all nodes"
else
    print_error "Deployment failed for some nodes"
    # Restore backup
    mv ansible/inventory.ini.backup ansible/inventory.ini
    exit 1
fi

# Phase 5: Verify all nodes joined cluster
print_status "Phase 5: Verifying all nodes joined cluster..."

# Wait for nodes to be ready
sleep 60

MASTER_HOST=$(ansible master -i ansible/inventory.ini --list-hosts | grep -v "hosts" | head -1 | xargs)

print_status "Kubernetes cluster status:"
for hostname in "${NODES_HOSTNAME[@]}"; do
    K8S_STATUS=$(ansible $MASTER_HOST -i ansible/inventory.ini -m shell -a "kubectl get nodes $hostname --no-headers | awk '{print \$2}'" 2>/dev/null | grep -v "SUCCESS" | tail -1)
    echo "  $hostname: $K8S_STATUS"
done

print_status "SLURM cluster status:"
for hostname in "${NODES_HOSTNAME[@]}"; do
    SLURM_STATUS=$(ansible $MASTER_HOST -i ansible/inventory.ini -m shell -a "sinfo -N -h -n $hostname | awk '{print \$4}'" 2>/dev/null | grep -v "SUCCESS" | tail -1)
    echo "  $hostname: $SLURM_STATUS"
done

# Clean up backup
rm -f ansible/inventory.ini.backup

print_success "Bulk node addition completed!"
print_status "Added $NODE_COUNT nodes to the cluster:"
for i in "${!NODES_IP[@]}"; do
    echo "  - ${NODES_HOSTNAME[$i]} (${NODES_IP[$i]})"
done

print_status "To verify the deployment, run:"
echo "  ./scripts/validate-cluster.sh"
echo "  kubectl get nodes"
echo "  sinfo"
