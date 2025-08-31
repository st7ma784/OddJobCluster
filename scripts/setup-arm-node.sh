#!/bin/bash

# ARM Node Setup Script
# Configures ARM-based devices (Raspberry Pi, Android, etc.) for cluster integration

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# Default values
NODE_IP=""
NODE_USER=""
NODE_TYPE=""
SSH_KEY="~/.ssh/cluster_key"

usage() {
    echo "Usage: $0 <node_ip> <username> [node_type]"
    echo ""
    echo "Examples:"
    echo "  $0 192.168.1.100 pi raspberry-pi"
    echo "  $0 192.168.1.102 u0_a123 android"
    echo "  $0 192.168.1.103 ubuntu jetson"
    echo ""
    echo "Supported node types:"
    echo "  - raspberry-pi (default for 'pi' user)"
    echo "  - android (for Termux/UserLAnd)"
    echo "  - jetson (NVIDIA Jetson devices)"
    echo "  - generic-arm (other ARM devices)"
    exit 1
}

detect_architecture() {
    local node_ip=$1
    local node_user=$2
    
    echo "🔍 Detecting architecture on $node_ip..."
    
    ARCH=$(ssh -i $SSH_KEY -o ConnectTimeout=10 $node_user@$node_ip "uname -m" 2>/dev/null || echo "unknown")
    OS=$(ssh -i $SSH_KEY -o ConnectTimeout=10 $node_user@$node_ip "uname -s" 2>/dev/null || echo "unknown")
    
    echo "   Architecture: $ARCH"
    echo "   OS: $OS"
    
    case $ARCH in
        "aarch64"|"arm64")
            ARM_ARCH="arm64"
            ;;
        "armv7l"|"armhf")
            ARM_ARCH="armhf"
            ;;
        *)
            echo "❌ Unsupported architecture: $ARCH"
            exit 1
            ;;
    esac
}

setup_raspberry_pi() {
    local node_ip=$1
    local node_user=$2
    
    echo "🍓 Setting up Raspberry Pi node..."
    
    # Update system and install dependencies
    ssh -i $SSH_KEY $node_user@$node_ip "
        sudo apt update -qq
        sudo apt upgrade -y
        sudo apt install -y curl wget git python3 python3-pip htop iotop
    "
    
    # Configure boot parameters for containers
    ssh -i $SSH_KEY $node_user@$node_ip "
        if ! grep -q 'cgroup_enable=cpuset' /boot/firmware/cmdline.txt; then
            sudo sed -i '\$ s/\$/ cgroup_enable=cpuset cgroup_enable=memory cgroup_memory=1/' /boot/firmware/cmdline.txt
            echo '⚠️  Reboot required for cgroup changes'
        fi
    "
    
    # Optimize GPU memory for headless operation
    ssh -i $SSH_KEY $node_user@$node_ip "
        if ! grep -q 'gpu_mem=16' /boot/firmware/config.txt; then
            echo 'gpu_mem=16' | sudo tee -a /boot/firmware/config.txt
        fi
    "
    
    # Install Docker/containerd
    ssh -i $SSH_KEY $node_user@$node_ip "
        if ! command -v docker &> /dev/null; then
            curl -fsSL https://get.docker.com | sh
            sudo usermod -aG docker $node_user
            sudo systemctl enable docker
            sudo systemctl start docker
        fi
    "
}

setup_android_device() {
    local node_ip=$1
    local node_user=$2
    
    echo "📱 Setting up Android device..."
    
    # Check if running in Termux or UserLAnd
    ssh -i $SSH_KEY $node_user@$node_ip "
        if [ -d '/data/data/com.termux' ]; then
            echo 'Detected Termux environment'
            # Install packages via pkg
            pkg update -y
            pkg install -y python nodejs git curl wget htop
            
            # Install proot-distro for containers
            pkg install -y proot-distro
            if ! proot-distro list | grep -q ubuntu; then
                proot-distro install ubuntu
            fi
        else
            echo 'Assuming UserLAnd or similar Linux environment'
            sudo apt update -qq
            sudo apt install -y python3 python3-pip git curl wget htop
        fi
    "
}

setup_jetson_device() {
    local node_ip=$1
    local node_user=$2
    
    echo "🚀 Setting up NVIDIA Jetson device..."
    
    # Install JetPack components if not present
    ssh -i $SSH_KEY $node_user@$node_ip "
        sudo apt update -qq
        sudo apt install -y nvidia-jetpack python3 python3-pip git curl wget htop
        
        # Install Docker with GPU support
        if ! command -v docker &> /dev/null; then
            curl -fsSL https://get.docker.com | sh
            sudo usermod -aG docker $node_user
            
            # Add NVIDIA container runtime
            distribution=\$(. /etc/os-release;echo \$ID\$VERSION_ID)
            curl -s -L https://nvidia.github.io/nvidia-docker/gpgkey | sudo apt-key add -
            curl -s -L https://nvidia.github.io/nvidia-docker/\$distribution/nvidia-docker.list | sudo tee /etc/apt/sources.list.d/nvidia-docker.list
            
            sudo apt update
            sudo apt install -y nvidia-docker2
            sudo systemctl restart docker
        fi
    "
}

setup_generic_arm() {
    local node_ip=$1
    local node_user=$2
    
    echo "🔧 Setting up generic ARM device..."
    
    ssh -i $SSH_KEY $node_user@$node_ip "
        sudo apt update -qq
        sudo apt install -y curl wget git python3 python3-pip htop iotop
        
        # Install Docker
        if ! command -v docker &> /dev/null; then
            curl -fsSL https://get.docker.com | sh
            sudo usermod -aG docker $node_user
            sudo systemctl enable docker
            sudo systemctl start docker
        fi
    "
}

install_kubernetes_components() {
    local node_ip=$1
    local node_user=$2
    
    echo "☸️ Installing Kubernetes components..."
    
    ssh -i $SSH_KEY $node_user@$node_ip "
        # Add Kubernetes repository
        curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.28/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
        echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.28/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list
        
        sudo apt update
        sudo apt install -y kubelet kubeadm kubectl
        sudo apt-mark hold kubelet kubeadm kubectl
        
        # Configure kubelet for ARM
        echo 'KUBELET_EXTRA_ARGS=\"--max-pods=20 --kube-reserved=cpu=100m,memory=200Mi\"' | sudo tee /etc/default/kubelet
    "
}

install_slurm_components() {
    local node_ip=$1
    local node_user=$2
    
    echo "⚡ Installing SLURM components..."
    
    ssh -i $SSH_KEY $node_user@$node_ip "
        sudo apt install -y slurmd slurm-client
        
        # Create SLURM user and directories
        sudo useradd -r -s /bin/false slurm || true
        sudo mkdir -p /var/spool/slurm /var/log/slurm
        sudo chown slurm:slurm /var/spool/slurm /var/log/slurm
    "
}

update_inventory() {
    local node_ip=$1
    local node_user=$2
    local node_type=$3
    
    echo "📝 Updating inventory..."
    
    # Detect hostname
    HOSTNAME=$(ssh -i $SSH_KEY $node_user@$node_ip "hostname")
    
    # Add to inventory if not already present
    INVENTORY_FILE="$PROJECT_DIR/ansible/inventory.ini"
    
    if ! grep -q "$node_ip" "$INVENTORY_FILE"; then
        # Add ARM nodes section if not exists
        if ! grep -q "\[arm_nodes\]" "$INVENTORY_FILE"; then
            echo "" >> "$INVENTORY_FILE"
            echo "[arm_nodes]" >> "$INVENTORY_FILE"
        fi
        
        # Add node entry
        echo "$HOSTNAME ansible_host=$node_ip ansible_user=$node_user arch=$ARM_ARCH node_type=$node_type" >> "$INVENTORY_FILE"
        
        # Add group vars if not exists
        if ! grep -q "\[arm_nodes:vars\]" "$INVENTORY_FILE"; then
            echo "" >> "$INVENTORY_FILE"
            echo "[arm_nodes:vars]" >> "$INVENTORY_FILE"
            echo "ansible_ssh_private_key_file=~/.ssh/cluster_key" >> "$INVENTORY_FILE"
            echo "ansible_python_interpreter=/usr/bin/python3" >> "$INVENTORY_FILE"
        fi
        
        echo "✅ Added $HOSTNAME to inventory"
    else
        echo "ℹ️  Node already in inventory"
    fi
}

run_performance_test() {
    local node_ip=$1
    local node_user=$2
    
    echo "🧪 Running performance test..."
    
    ssh -i $SSH_KEY $node_user@$node_ip "
        echo '=== System Information ==='
        uname -a
        echo ''
        echo '=== CPU Information ==='
        lscpu | head -20
        echo ''
        echo '=== Memory Information ==='
        free -h
        echo ''
        echo '=== Storage Information ==='
        df -h
        echo ''
        echo '=== Network Test ==='
        ping -c 3 8.8.8.8 || echo 'Network test failed'
        echo ''
        echo '=== Temperature (if available) ==='
        if command -v vcgencmd &> /dev/null; then
            vcgencmd measure_temp
        elif [ -f /sys/class/thermal/thermal_zone0/temp ]; then
            echo \"CPU Temp: \$(cat /sys/class/thermal/thermal_zone0/temp | awk '{print \$1/1000}')°C\"
        else
            echo 'Temperature monitoring not available'
        fi
    "
}

# Main execution
if [ $# -lt 2 ]; then
    usage
fi

NODE_IP=$1
NODE_USER=$2
NODE_TYPE=${3:-""}

# Auto-detect node type if not specified
if [ -z "$NODE_TYPE" ]; then
    case $NODE_USER in
        "pi")
            NODE_TYPE="raspberry-pi"
            ;;
        "u0_a"*)
            NODE_TYPE="android"
            ;;
        *)
            NODE_TYPE="generic-arm"
            ;;
    esac
fi

echo "🚀 ARM Node Setup Starting"
echo "=========================="
echo "Node IP: $NODE_IP"
echo "Username: $NODE_USER"
echo "Node Type: $NODE_TYPE"
echo ""

# Test SSH connectivity
echo "🔑 Testing SSH connectivity..."
if ! ssh -i $SSH_KEY -o ConnectTimeout=10 $NODE_USER@$NODE_IP "echo 'SSH connection successful'" 2>/dev/null; then
    echo "❌ SSH connection failed. Please check:"
    echo "   - Node IP address: $NODE_IP"
    echo "   - Username: $NODE_USER"
    echo "   - SSH key: $SSH_KEY"
    echo "   - Network connectivity"
    exit 1
fi

# Detect architecture
detect_architecture $NODE_IP $NODE_USER

# Setup based on node type
case $NODE_TYPE in
    "raspberry-pi")
        setup_raspberry_pi $NODE_IP $NODE_USER
        ;;
    "android")
        setup_android_device $NODE_IP $NODE_USER
        ;;
    "jetson")
        setup_jetson_device $NODE_IP $NODE_USER
        ;;
    "generic-arm")
        setup_generic_arm $NODE_IP $NODE_USER
        ;;
    *)
        echo "❌ Unknown node type: $NODE_TYPE"
        exit 1
        ;;
esac

# Install cluster components (skip for Android in Termux)
if [ "$NODE_TYPE" != "android" ]; then
    install_kubernetes_components $NODE_IP $NODE_USER
    install_slurm_components $NODE_IP $NODE_USER
fi

# Update inventory
update_inventory $NODE_IP $NODE_USER $NODE_TYPE

# Run performance test
run_performance_test $NODE_IP $NODE_USER

echo ""
echo "🎉 ARM Node Setup Complete!"
echo "=========================="
echo "Node: $HOSTNAME ($NODE_IP)"
echo "Type: $NODE_TYPE"
echo "Architecture: $ARM_ARCH"
echo ""
echo "📋 Next Steps:"
echo "1. Reboot the node if Raspberry Pi (for cgroup changes)"
echo "2. Run cluster deployment: ./scripts/auto-cluster-setup.sh"
echo "3. Join node to cluster: kubeadm join ..."
echo "4. Add to SLURM configuration"
echo ""
echo "🔍 Monitor with: ssh -i $SSH_KEY $NODE_USER@$NODE_IP"
