# ARM Platform Integration Guide

This guide covers adding ARM-based devices to your Kubernetes SLURM cluster, including Raspberry Pi computers, Android devices, and other ARM platforms.

## 🏗️ Supported ARM Platforms

### **Raspberry Pi (Recommended)**
- **Pi 4 Model B (4GB/8GB)** - Excellent performance
- **Pi 4 Model B (2GB)** - Good for light workloads
- **Pi 3 Model B+** - Basic compute node
- **Pi Zero 2 W** - Minimal edge compute

### **Mobile Devices**
- **Android phones/tablets** (Android 7+)
- **iOS devices** (via iSH or similar)
- **Old smartphones** repurposed as compute nodes

### **Other ARM Devices**
- **NVIDIA Jetson** series
- **Orange Pi / Banana Pi**
- **Rock Pi / Pine64**
- **ARM-based mini PCs**

## 🚀 Quick Setup for Raspberry Pi

### Prerequisites
```bash
# Flash Raspberry Pi OS Lite (64-bit) to SD card
# Enable SSH and set up user account
# Connect to network and get IP address
```

### 1. Prepare Raspberry Pi
```bash
# Update system
sudo apt update && sudo apt upgrade -y

# Enable container features
echo 'cgroup_enable=cpuset cgroup_enable=memory cgroup_memory=1' | sudo tee -a /boot/firmware/cmdline.txt

# Install required packages
sudo apt install -y curl wget git python3 python3-pip

# Reboot to apply cgroup changes
sudo reboot
```

### 2. Add to Cluster Inventory
```ini
[arm_nodes]
rpi-node-01 ansible_host=192.168.1.100 ansible_user=pi arch=arm64
rpi-node-02 ansible_host=192.168.1.101 ansible_user=pi arch=arm64
android-node-01 ansible_host=192.168.1.102 ansible_user=u0_a123 arch=arm64

[arm_nodes:vars]
ansible_ssh_private_key_file=~/.ssh/cluster_key
ansible_python_interpreter=/usr/bin/python3
```

### 3. Run ARM Setup Script
```bash
./scripts/setup-arm-node.sh 192.168.1.100 pi
```

## 📱 Android Device Setup

### Using Termux
1. **Install Termux** from F-Droid or Google Play
2. **Setup SSH server**:
```bash
pkg update && pkg upgrade
pkg install openssh python nodejs
passwd  # Set password
sshd    # Start SSH daemon
```

3. **Install container runtime**:
```bash
pkg install proot-distro
proot-distro install ubuntu
proot-distro login ubuntu
```

### Using UserLAnd
1. **Install UserLAnd** app
2. **Setup Ubuntu environment**
3. **Enable SSH access**
4. **Install required packages**

## 🔧 Architecture-Specific Configurations

### Container Images
```yaml
# ARM64 images for Kubernetes components
kubeadm_image_repository: "registry.k8s.io"
kubernetes_images:
  arm64:
    - "registry.k8s.io/kube-apiserver:v1.28.15"
    - "registry.k8s.io/kube-controller-manager:v1.28.15"
    - "registry.k8s.io/kube-scheduler:v1.28.15"
    - "registry.k8s.io/kube-proxy:v1.28.15"
    - "registry.k8s.io/pause:3.9"
    - "registry.k8s.io/etcd:3.5.12-0"
```

### SLURM Configuration
```bash
# ARM-specific SLURM node configuration
NodeName=rpi-node-[01-04] CPUs=4 RealMemory=3800 Arch=arm64 State=UNKNOWN
NodeName=android-node-[01-02] CPUs=8 RealMemory=6000 Arch=arm64 State=UNKNOWN

PartitionName=arm_compute Nodes=rpi-node-[01-04],android-node-[01-02] Default=NO MaxTime=INFINITE State=UP
PartitionName=edge_compute Nodes=rpi-node-[01-04] Default=NO MaxTime=INFINITE State=UP
```

## ⚡ Performance Considerations

### **Raspberry Pi Optimization**
```bash
# GPU memory split (reduce for headless)
echo "gpu_mem=16" | sudo tee -a /boot/firmware/config.txt

# CPU governor for performance
echo 'performance' | sudo tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor

# Increase swap for compilation
sudo dphys-swapfile swapoff
sudo sed -i 's/#CONF_SWAPSIZE=/CONF_SWAPSIZE=2048/' /etc/dphys-swapfile
sudo dphys-swapfile setup
sudo dphys-swapfile swapon
```

### **Mobile Device Optimization**
```bash
# Reduce resource usage
export KUBELET_EXTRA_ARGS="--max-pods=10 --kube-reserved=cpu=100m,memory=200Mi"

# Use lightweight container runtime
apt install -y containerd.io
systemctl enable containerd
```

## 🌐 Network Configuration

### **Mixed Architecture Networking**
```yaml
# Flannel configuration for ARM
apiVersion: v1
kind: ConfigMap
metadata:
  name: kube-flannel-cfg
data:
  cni-conf.json: |
    {
      "name": "cbr0",
      "cniVersion": "0.3.1",
      "plugins": [
        {
          "type": "flannel",
          "delegate": {
            "hairpinMode": true,
            "isDefaultGateway": true
          }
        }
      ]
    }
```

## 🔍 Troubleshooting ARM Nodes

### **Common Issues**
```bash
# Check architecture
uname -m  # Should show aarch64 for ARM64

# Verify cgroup support
cat /proc/cgroups

# Check container runtime
sudo systemctl status containerd

# Test Kubernetes node
kubectl get nodes -o wide
```

### **Performance Monitoring**
```bash
# ARM-specific monitoring
vcgencmd measure_temp    # Raspberry Pi temperature
cat /sys/class/thermal/thermal_zone0/temp  # Generic ARM temp

# Resource usage
htop
iostat -x 1
```

## 📊 Expected Performance

| Device Type | CPUs | Memory | Network | Use Case |
|-------------|------|--------|---------|----------|
| Pi 4 (8GB) | 4 cores | 8GB | 1Gbps | Primary ARM compute |
| Pi 4 (4GB) | 4 cores | 4GB | 1Gbps | Secondary compute |
| Pi 3 B+ | 4 cores | 1GB | 100Mbps | Edge/IoT tasks |
| Android (High-end) | 8 cores | 6-12GB | WiFi | Mobile compute |
| Android (Mid-range) | 4-6 cores | 3-6GB | WiFi | Light tasks |

## 🚀 Advanced ARM Features

### **GPU Acceleration** (Raspberry Pi)
```bash
# Enable GPU for ML workloads
echo "dtoverlay=vc4-kms-v3d" | sudo tee -a /boot/firmware/config.txt
echo "gpu_mem=128" | sudo tee -a /boot/firmware/config.txt
```

### **Edge Computing Jobs**
```bash
# SLURM job for ARM-specific tasks
#!/bin/bash
#SBATCH --partition=arm_compute
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=4
#SBATCH --constraint=arm64

# Run ARM-optimized workload
./arm_optimized_binary
```

## 📋 Next Steps

1. **Add ARM nodes** to inventory
2. **Run setup scripts** for each device type
3. **Deploy ARM-specific workloads**
4. **Monitor performance** and optimize
5. **Scale horizontally** with more ARM devices

The cluster will automatically detect ARM architecture and deploy appropriate configurations for optimal performance across mixed x86/ARM environments.
