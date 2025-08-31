#!/bin/bash

# Simulate node addition process for testing and validation
# This script demonstrates the complete node addition workflow without requiring actual remote nodes

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
    echo "║                   Node Addition Simulation                  ║"
    echo "║              Testing Cluster Integration Process            ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

# Check if running from correct directory
if [ ! -f "ansible/inventory.ini" ]; then
    print_error "Please run this script from the project root directory"
    exit 1
fi

print_banner

# Simulate node information
NODES=(
    "worker-test1:192.168.1.201:Ubuntu 22.04:4:8GB:50GB"
    "worker-test2:192.168.1.202:Ubuntu 22.04:8:16GB:100GB"
    "worker-gpu:192.168.1.203:Ubuntu 22.04:16:32GB:200GB:GPU"
)

print_status "Simulating addition of ${#NODES[@]} nodes to the cluster..."
echo ""

for node_info in "${NODES[@]}"; do
    IFS=':' read -r node_name node_ip os_version cpu_cores memory disk gpu <<< "$node_info"
    
    print_status "Processing node: $node_name ($node_ip)"
    echo "  OS: $os_version"
    echo "  CPU: $cpu_cores cores"
    echo "  Memory: $memory"
    echo "  Disk: $disk"
    if [ -n "$gpu" ]; then
        echo "  GPU: Available"
    fi
    echo ""
    
    # Step 1: Network connectivity simulation
    print_status "Step 1: Simulating network connectivity test..."
    sleep 1
    print_success "Network connectivity: OK"
    
    # Step 2: SSH connectivity simulation
    print_status "Step 2: Simulating SSH connectivity test..."
    sleep 1
    print_success "SSH connectivity: OK"
    
    # Step 3: System information gathering
    print_status "Step 3: Simulating system information gathering..."
    sleep 1
    echo "  Hostname: $node_name"
    echo "  Kernel: 5.15.0-generic"
    echo "  Architecture: x86_64"
    print_success "System information collected"
    
    # Step 4: User setup simulation
    print_status "Step 4: Simulating ansible user setup..."
    sleep 1
    print_success "Ansible user created and configured"
    
    # Step 5: SSH key setup simulation
    print_status "Step 5: Simulating SSH key deployment..."
    sleep 1
    print_success "SSH keys deployed successfully"
    
    # Step 6: Update inventory
    print_status "Step 6: Adding node to inventory..."
    
    # Backup inventory
    cp ansible/inventory.ini ansible/inventory.ini.backup.$(date +%Y%m%d_%H%M%S)
    
    # Check if node already exists
    if ! grep -q "$node_name" ansible/inventory.ini; then
        # Add to [workers] section
        sed -i "/\[workers\]/a $node_name ansible_host=$node_ip ansible_user=ansible ansible_ssh_private_key_file=~/.ssh/cluster_key" ansible/inventory.ini
        
        # Add to [kubernetes_workers] section
        sed -i "/\[kubernetes_workers\]/a $node_name" ansible/inventory.ini
        
        # Add to [slurm_workers] section
        sed -i "/\[slurm_workers\]/a $node_name" ansible/inventory.ini
        
        print_success "Node added to inventory"
    else
        print_warning "Node already exists in inventory"
    fi
    
    # Step 7: Ansible connectivity test simulation
    print_status "Step 7: Simulating Ansible connectivity test..."
    sleep 1
    print_success "Ansible connectivity: OK"
    
    # Step 8: Deployment simulation
    print_status "Step 8: Simulating deployment process..."
    echo "  - Installing common packages..."
    sleep 1
    echo "  - Configuring Docker..."
    sleep 1
    echo "  - Installing Kubernetes components..."
    sleep 1
    echo "  - Joining Kubernetes cluster..."
    sleep 1
    echo "  - Installing SLURM components..."
    sleep 1
    echo "  - Configuring SLURM worker..."
    sleep 1
    print_success "Deployment completed successfully"
    
    # Step 9: Verification simulation
    print_status "Step 9: Simulating verification tests..."
    echo "  - Kubernetes node status: Ready"
    echo "  - SLURM node status: Active"
    echo "  - Container runtime: Running"
    echo "  - System resources: Available"
    if [ -n "$gpu" ]; then
        echo "  - GPU resources: Detected and available"
    fi
    sleep 1
    print_success "All verification tests passed"
    
    print_success "Node $node_name successfully integrated into cluster!"
    echo ""
    echo "----------------------------------------"
    echo ""
done

# Generate summary report
print_status "Generating cluster summary..."
echo ""
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║                     CLUSTER SUMMARY                         ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""

# Count nodes in inventory
total_workers=$(grep -c "ansible_host" ansible/inventory.ini || echo "0")
echo "Total worker nodes: $total_workers"

# Show inventory structure
echo ""
echo "Current inventory structure:"
echo "----------------------------"
cat ansible/inventory.ini | grep -E "^\[|ansible_host" | head -20

echo ""
echo "Next steps for actual deployment:"
echo "1. Verify inventory configuration: cat ansible/inventory.ini"
echo "2. Test connectivity: ansible all -m ping -i ansible/inventory.ini"
echo "3. Deploy to new nodes: ansible-playbook -i ansible/inventory.ini ansible/site.yml"
echo "4. Verify cluster: kubectl get nodes && sinfo -N"
echo ""

# Create deployment command examples
print_status "Creating deployment command examples..."

cat > deploy-commands.txt << 'EOF'
# Deployment Commands for New Nodes

## Test Ansible Connectivity
ansible all -m ping -i ansible/inventory.ini

## Deploy to specific node
ansible-playbook -i ansible/inventory.ini --limit worker-test1 ansible/site.yml

## Deploy to all new nodes
ansible-playbook -i ansible/inventory.ini --limit "worker-test1,worker-test2,worker-gpu" ansible/site.yml

## Full cluster deployment
ansible-playbook -i ansible/inventory.ini ansible/site.yml

## Verification commands
kubectl get nodes -o wide
sinfo -N -l
kubectl top nodes

## Test job submission
srun -N 1 --nodelist=worker-test1 hostname
sbatch --nodelist=worker-test2 examples/slurm-jobs/hello-world.sh

## GPU testing (if applicable)
srun --gres=gpu:1 --nodelist=worker-gpu nvidia-smi
EOF

print_success "Deployment commands saved to deploy-commands.txt"

echo ""
print_success "Node addition simulation completed successfully!"
print_status "Review the updated inventory and use the deployment commands to integrate real nodes."
