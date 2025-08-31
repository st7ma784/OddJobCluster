#!/bin/bash

# Add ARM Node to Existing Cluster
# Integrates new ARM devices into running cluster

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

usage() {
    echo "Usage: $0 <device_type> <ip_address> [username]"
    echo ""
    echo "Device types:"
    echo "  rpi4-8gb    - Raspberry Pi 4 (8GB RAM)"
    echo "  rpi4-4gb    - Raspberry Pi 4 (4GB RAM)" 
    echo "  rpi3        - Raspberry Pi 3 Model B+"
    echo "  android     - Android device (Termux/UserLAnd)"
    echo "  jetson      - NVIDIA Jetson series"
    echo "  custom      - Custom ARM device"
    echo ""
    echo "Examples:"
    echo "  $0 rpi4-8gb 192.168.1.100"
    echo "  $0 android 192.168.1.102 u0_a123"
    echo "  $0 jetson 192.168.1.104 nvidia"
    exit 1
}

if [ $# -lt 2 ]; then
    usage
fi

DEVICE_TYPE=$1
NODE_IP=$2
USERNAME=${3:-"pi"}

# Device configurations
case $DEVICE_TYPE in
    "rpi4-8gb")
        NODE_NAME="rpi4-node-$(echo $NODE_IP | cut -d. -f4)"
        EXPECTED_ARCH="arm64"
        EXPECTED_CPUS=4
        EXPECTED_MEMORY="8GB"
        SETUP_TYPE="raspberry-pi"
        ;;
    "rpi4-4gb")
        NODE_NAME="rpi4-node-$(echo $NODE_IP | cut -d. -f4)"
        EXPECTED_ARCH="arm64"
        EXPECTED_CPUS=4
        EXPECTED_MEMORY="4GB"
        SETUP_TYPE="raspberry-pi"
        ;;
    "rpi3")
        NODE_NAME="rpi3-node-$(echo $NODE_IP | cut -d. -f4)"
        EXPECTED_ARCH="arm64"
        EXPECTED_CPUS=4
        EXPECTED_MEMORY="1GB"
        SETUP_TYPE="raspberry-pi"
        ;;
    "android")
        NODE_NAME="android-node-$(echo $NODE_IP | cut -d. -f4)"
        EXPECTED_ARCH="arm64"
        EXPECTED_CPUS="4-8"
        EXPECTED_MEMORY="3-12GB"
        SETUP_TYPE="android"
        USERNAME=${USERNAME:-"u0_a123"}
        ;;
    "jetson")
        NODE_NAME="jetson-node-$(echo $NODE_IP | cut -d. -f4)"
        EXPECTED_ARCH="arm64"
        EXPECTED_CPUS="4-8"
        EXPECTED_MEMORY="4-32GB"
        SETUP_TYPE="jetson"
        USERNAME=${USERNAME:-"nvidia"}
        ;;
    "custom")
        NODE_NAME="arm-node-$(echo $NODE_IP | cut -d. -f4)"
        EXPECTED_ARCH="arm64"
        SETUP_TYPE="generic-arm"
        ;;
    *)
        echo "❌ Unknown device type: $DEVICE_TYPE"
        usage
        ;;
esac

echo "🚀 Adding ARM Node to Cluster"
echo "============================="
echo "Device Type: $DEVICE_TYPE"
echo "Node IP: $NODE_IP"
echo "Username: $USERNAME"
echo "Expected Architecture: $EXPECTED_ARCH"
echo ""

# Step 1: Setup the ARM node
echo "📋 Step 1: Setting up ARM node..."
if ! "$SCRIPT_DIR/setup-arm-node.sh" "$NODE_IP" "$USERNAME" "$SETUP_TYPE"; then
    echo "❌ ARM node setup failed"
    exit 1
fi

# Step 2: Get cluster join token
echo "📋 Step 2: Getting cluster join token..."
CONTROL_PLANE_IP="192.168.5.57"
JOIN_TOKEN=$(ssh -i ~/.ssh/cluster_key ansible@$CONTROL_PLANE_IP "sudo kubeadm token create --print-join-command" 2>/dev/null)

if [ -z "$JOIN_TOKEN" ]; then
    echo "❌ Failed to get join token from control plane"
    exit 1
fi

echo "✅ Got join token"

# Step 3: Join node to Kubernetes cluster (skip for Android)
if [ "$SETUP_TYPE" != "android" ]; then
    echo "📋 Step 3: Joining Kubernetes cluster..."
    ssh -i ~/.ssh/cluster_key $USERNAME@$NODE_IP "sudo $JOIN_TOKEN"
    
    # Wait for node to be ready
    echo "⏳ Waiting for node to be ready..."
    for i in {1..30}; do
        if ssh -i ~/.ssh/cluster_key ansible@$CONTROL_PLANE_IP "kubectl get node $NODE_NAME" 2>/dev/null | grep -q "Ready"; then
            echo "✅ Node joined cluster successfully"
            break
        fi
        sleep 10
    done
else
    echo "ℹ️  Skipping Kubernetes join for Android device"
fi

# Step 4: Configure SLURM
echo "📋 Step 4: Configuring SLURM..."

# Get node specs
NODE_SPECS=$(ssh -i ~/.ssh/cluster_key $USERNAME@$NODE_IP "
    CPUS=\$(nproc)
    MEMORY=\$(free -m | grep '^Mem:' | awk '{print \$2}')
    echo \"CPUs=\$CPUS RealMemory=\$MEMORY\"
")

# Add to SLURM configuration
ssh -i ~/.ssh/cluster_key ansible@$CONTROL_PLANE_IP "
    # Backup current config
    sudo cp /etc/slurm/slurm.conf /etc/slurm/slurm.conf.backup.\$(date +%Y%m%d_%H%M%S)
    
    # Add node to configuration
    echo 'NodeName=$NODE_NAME $NODE_SPECS Arch=arm64 State=UNKNOWN' | sudo tee -a /etc/slurm/slurm.conf
    
    # Update partition to include ARM node
    if ! grep -q 'PartitionName=arm_compute' /etc/slurm/slurm.conf; then
        echo 'PartitionName=arm_compute Nodes=$NODE_NAME Default=NO MaxTime=INFINITE State=UP' | sudo tee -a /etc/slurm/slurm.conf
    else
        sudo sed -i 's/PartitionName=arm_compute Nodes=/&$NODE_NAME,/' /etc/slurm/slurm.conf
    fi
    
    # Restart SLURM services
    sudo systemctl restart slurmctld
    sudo systemctl restart slurmd
"

# Configure SLURM on the new node
ssh -i ~/.ssh/cluster_key $USERNAME@$NODE_IP "
    # Copy SLURM configuration from control plane
    sudo mkdir -p /etc/slurm
    sudo systemctl stop slurmd || true
"

scp -i ~/.ssh/cluster_key ansible@$CONTROL_PLANE_IP:/etc/slurm/slurm.conf /tmp/slurm.conf
scp -i ~/.ssh/cluster_key /tmp/slurm.conf $USERNAME@$NODE_IP:/tmp/
ssh -i ~/.ssh/cluster_key $USERNAME@$NODE_IP "
    sudo cp /tmp/slurm.conf /etc/slurm/
    sudo chown slurm:slurm /etc/slurm/slurm.conf
    sudo systemctl start slurmd
    sudo systemctl enable slurmd
"

# Step 5: Update web dashboard
echo "📋 Step 5: Updating web dashboard..."

# Create ARM node entry for dashboard
ARM_NODE_ENTRY="{
    name: '$NODE_NAME',
    ip: '$NODE_IP', 
    arch: '$EXPECTED_ARCH',
    type: '$(echo $DEVICE_TYPE | tr '[:lower:]' '[:upper:]')',
    cpus: $(ssh -i ~/.ssh/cluster_key $USERNAME@$NODE_IP "nproc"),
    memory: '$(ssh -i ~/.ssh/cluster_key $USERNAME@$NODE_IP "free -h | grep '^Mem:' | awk '{print \$2}'")',
    status: 'online'
}"

# Update dashboard on both nodes
for dashboard_ip in "192.168.5.57" "192.168.4.157"; do
    ssh -i ~/.ssh/cluster_key ansible@$dashboard_ip "
        sudo sed -i '/\/\/ Example ARM nodes/a\\        $ARM_NODE_ENTRY,' /var/www/html/index.html
    " 2>/dev/null || true
done

# Step 6: Verify integration
echo "📋 Step 6: Verifying integration..."

echo "🔍 Kubernetes status:"
ssh -i ~/.ssh/cluster_key ansible@$CONTROL_PLANE_IP "kubectl get nodes | grep $NODE_NAME" || echo "Node not in Kubernetes (expected for Android)"

echo "🔍 SLURM status:"
ssh -i ~/.ssh/cluster_key ansible@$CONTROL_PLANE_IP "sinfo -N | grep $NODE_NAME" || echo "Node not visible in SLURM yet"

echo "🔍 Node connectivity:"
ssh -i ~/.ssh/cluster_key $USERNAME@$NODE_IP "hostname && uptime"

echo ""
echo "🎉 ARM Node Integration Complete!"
echo "================================="
echo "Node Name: $NODE_NAME"
echo "IP Address: $NODE_IP"
echo "Device Type: $DEVICE_TYPE"
echo "Architecture: $EXPECTED_ARCH"
echo ""
echo "📊 Access Points:"
echo "   • Web Dashboard: http://192.168.5.57/"
echo "   • SSH Access: ssh -i ~/.ssh/cluster_key $USERNAME@$NODE_IP"
echo ""
echo "🧪 Test Commands:"
echo "   • Check node: kubectl get node $NODE_NAME"
echo "   • SLURM info: sinfo -N -n $NODE_NAME"
echo "   • Submit job: sbatch --partition=arm_compute job_script.sh"
echo ""
echo "📋 Next Steps:"
echo "   1. Monitor node status in web dashboard"
echo "   2. Submit test workloads to ARM partition"
echo "   3. Add more ARM nodes using this script"
