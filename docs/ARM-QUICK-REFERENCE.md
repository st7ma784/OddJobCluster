# ARM Platform Quick Reference

Quick commands and setup guide for integrating ARM devices into your Kubernetes SLURM cluster.

## 🚀 Quick Setup Commands

### **Raspberry Pi 4/3**
```bash
# Add Raspberry Pi 4 (8GB)
./scripts/add-arm-node.sh rpi4-8gb 192.168.1.100

# Add Raspberry Pi 4 (4GB)
./scripts/add-arm-node.sh rpi4-4gb 192.168.1.101

# Add Raspberry Pi 3
./scripts/add-arm-node.sh rpi3 192.168.1.102
```

### **Android Devices**
```bash
# Add Android device (Termux/UserLAnd)
./scripts/add-arm-node.sh android 192.168.1.103 u0_a123
```

### **NVIDIA Jetson**
```bash
# Add Jetson device
./scripts/add-arm-node.sh jetson 192.168.1.104 nvidia
```

### **Generic ARM Devices**
```bash
# Add custom ARM device
./scripts/add-arm-node.sh custom 192.168.1.105 ubuntu
```

## 🔍 Discovery & Monitoring

### **Network Discovery**
```bash
# Discover ARM devices on network
./scripts/arm-node-discovery.sh discover

# Discover with custom network range
./scripts/arm-node-discovery.sh discover --network 192.168.0.0/24
```

### **Health Monitoring**
```bash
# One-time health check
./scripts/arm-node-discovery.sh monitor

# Continuous monitoring
./scripts/arm-node-discovery.sh monitor --continuous

# Generate performance benchmarks
./scripts/arm-node-discovery.sh benchmark

# Generate comprehensive report
./scripts/arm-node-discovery.sh report
```

## ⚡ SLURM Job Submission

### **ARM-Specific Partitions**
```bash
# Submit to ARM compute partition
sbatch --partition=arm_compute job_script.sh

# Submit to edge compute (Raspberry Pi only)
sbatch --partition=edge_compute edge_job.sh

# Submit with ARM constraint
sbatch --constraint=arm64 job_script.sh
```

### **ARM Job Examples**
```bash
# Generate ARM job templates
./examples/slurm-jobs/arm-workloads.sh

# Submit basic ARM test
sbatch arm-hello-world.sh

# Submit Raspberry Pi monitoring job
sbatch rpi-temperature-monitor.sh

# Submit mobile device job
sbatch mobile-device-job.sh

# Submit multi-architecture parallel job
sbatch multi-arch-parallel.sh
```

## 📊 Monitoring Commands

### **Node Status**
```bash
# Check all nodes
kubectl get nodes -o wide

# Check ARM nodes only
kubectl get nodes -l kubernetes.io/arch=arm64

# SLURM node info
sinfo -N
sinfo -p arm_compute
sinfo -p edge_compute
```

### **Job Monitoring**
```bash
# View job queue
squeue

# View ARM partition jobs
squeue -p arm_compute

# Job details
scontrol show job <job_id>
```

## 🛠️ Troubleshooting

### **Common ARM Issues**
```bash
# Check architecture
ssh pi@192.168.1.100 "uname -m"

# Check cgroup support (Raspberry Pi)
ssh pi@192.168.1.100 "cat /proc/cgroups"

# Check temperature (Raspberry Pi)
ssh pi@192.168.1.100 "vcgencmd measure_temp"

# Check container runtime
ssh pi@192.168.1.100 "sudo systemctl status containerd"

# Check Kubernetes node
kubectl describe node <arm-node-name>
```

### **Service Status**
```bash
# Check SLURM on ARM node
ssh pi@192.168.1.100 "sudo systemctl status slurmd"

# Check kubelet on ARM node
ssh pi@192.168.1.100 "sudo systemctl status kubelet"

# Restart services if needed
ssh pi@192.168.1.100 "sudo systemctl restart containerd kubelet"
```

## 📱 Android Device Setup

### **Termux Setup**
```bash
# On Android device in Termux:
pkg update && pkg upgrade
pkg install openssh python nodejs
passwd  # Set password
sshd    # Start SSH daemon

# Install container support
pkg install proot-distro
proot-distro install ubuntu
```

### **UserLAnd Setup**
1. Install UserLAnd app
2. Setup Ubuntu environment
3. Enable SSH access
4. Install required packages

## 🍓 Raspberry Pi Optimization

### **Boot Configuration**
```bash
# Enable cgroups (required for Kubernetes)
echo 'cgroup_enable=cpuset cgroup_enable=memory cgroup_memory=1' | sudo tee -a /boot/firmware/cmdline.txt

# Optimize GPU memory for headless
echo 'gpu_mem=16' | sudo tee -a /boot/firmware/config.txt

# Reboot to apply changes
sudo reboot
```

### **Performance Tuning**
```bash
# Set CPU governor to performance
echo 'performance' | sudo tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor

# Increase swap for compilation
sudo dphys-swapfile swapoff
sudo sed -i 's/#CONF_SWAPSIZE=/CONF_SWAPSIZE=2048/' /etc/dphys-swapfile
sudo dphys-swapfile setup
sudo dphys-swapfile swapon
```

## 🌐 Web Dashboard Access

### **Cluster Dashboard**
- **URL**: http://192.168.5.57/
- **Features**: ARM node status, architecture display, mixed cluster monitoring

### **JupyterHub**
- **URL**: http://192.168.5.57:8000/
- **ARM Support**: Notebooks can run on ARM nodes via Kubernetes scheduling

## 📋 Architecture Information

### **Supported ARM Architectures**
- **ARM64 (aarch64)**: Raspberry Pi 4/3, modern Android devices, Jetson
- **ARMHF (armv7l)**: Older ARM devices, some Raspberry Pi models

### **Container Images**
ARM nodes automatically use ARM64-compatible images:
- `registry.k8s.io/kube-apiserver:v1.28.15`
- `registry.k8s.io/kube-proxy:v1.28.15`
- `docker.io/flannel/flannel:v0.22.3`

### **Performance Expectations**

| Device Type | CPUs | Memory | Use Case | Performance |
|-------------|------|--------|----------|-------------|
| Pi 4 (8GB) | 4 cores | 8GB | Primary ARM compute | Excellent |
| Pi 4 (4GB) | 4 cores | 4GB | Secondary compute | Good |
| Pi 3 B+ | 4 cores | 1GB | Edge/IoT tasks | Basic |
| Android (High-end) | 8 cores | 6-12GB | Mobile compute | Very Good |
| Android (Mid-range) | 4-6 cores | 3-6GB | Light tasks | Good |
| Jetson Nano | 4 cores | 4GB | GPU acceleration | Excellent |

## 🔧 Advanced Configuration

### **Custom ARM Node Types**
Edit `scripts/add-arm-node.sh` to add support for new ARM device types.

### **ARM-Specific Ansible Variables**
Configure in `ansible/group_vars/arm_nodes.yml`:
- `arm_max_pods`: Maximum pods per ARM node
- `arm_kube_reserved_cpu`: CPU reserved for Kubernetes
- `temperature_monitoring`: Temperature thresholds

### **Mixed Architecture Scheduling**
Use node selectors and affinity rules:
```yaml
nodeSelector:
  kubernetes.io/arch: arm64
```

This reference provides all essential commands for ARM platform integration and management.
