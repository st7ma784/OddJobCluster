# New Node Setup Guide

Complete step-by-step guide for adding a new node to your Kubernetes cluster with SLURM and JupyterHub integration.

## Overview

This guide covers the entire process from OS installation to full cluster integration:

1. **Hardware Preparation** - Physical setup and BIOS configuration
2. **OS Installation** - Ubuntu 22.04 LTS installation and basic configuration
3. **Network Configuration** - Static IP, hostname, and DNS setup
4. **Security Setup** - SSH keys, firewall, and user accounts
5. **Cluster Integration** - Adding the node to Kubernetes and SLURM
6. **Verification** - Testing and validation

## Prerequisites

- Physical server or VM with minimum 4GB RAM, 2 CPU cores, 50GB storage
- Network access to existing cluster master node
- Ubuntu 22.04 LTS installation media
- SSH access to cluster master node

## Phase 1: Hardware Preparation

### BIOS Configuration

1. **Boot into BIOS/UEFI**
   - Enable virtualization (VT-x/AMD-V) for containerization
   - Set boot order: USB/Network first for installation
   - Enable IPMI/BMC if available for remote management

2. **Hardware Checks**
   ```bash
   # After OS boot, verify hardware
   lscpu                    # Check CPU info
   free -h                  # Check memory
   lsblk                    # Check storage
   lspci | grep -i network  # Check network cards
   ```

### Network Planning

Plan your network configuration:
- **IP Address**: Choose static IP in cluster subnet
- **Hostname**: Follow naming convention (e.g., `worker-03`)
- **DNS**: Use cluster DNS servers
- **Gateway**: Cluster network gateway

## Phase 2: OS Installation

### Ubuntu 22.04 LTS Installation

1. **Boot from Installation Media**
   - Create bootable USB with Ubuntu 22.04 LTS
   - Boot from USB and select "Install Ubuntu Server"

2. **Installation Configuration**
   ```
   Language: English
   Keyboard: Your layout
   Network: Configure static IP (recommended)
   Storage: Use entire disk with LVM
   Profile: Create admin user
   SSH: Install OpenSSH server
   Snaps: Skip for now
   ```

3. **Partitioning Scheme**
   ```
   /boot     - 1GB   (ext4)
   /         - 20GB  (ext4)
   /var      - 15GB  (ext4) - for logs and containers
   /tmp      - 2GB   (ext4)
   /home     - 10GB  (ext4)
   swap      - 2GB   (or equal to RAM if <8GB)
   remaining - unallocated (for future use)
   ```

### Post-Installation Setup

1. **First Boot Configuration**
   ```bash
   # Update system
   sudo apt update && sudo apt upgrade -y
   
   # Install essential packages
   sudo apt install -y curl wget vim htop net-tools
   
   # Set timezone
   sudo timedatectl set-timezone UTC
   
   # Configure hostname
   sudo hostnamectl set-hostname worker-03
   echo "127.0.1.1 worker-03" | sudo tee -a /etc/hosts
   ```

2. **Verify Installation**
   ```bash
   # Check system info
   hostnamectl
   ip addr show
   df -h
   free -h
   ```

## Phase 3: Network Configuration

### Static IP Configuration

1. **Configure Netplan** (Ubuntu 22.04 uses Netplan)
   ```bash
   sudo vim /etc/netplan/00-installer-config.yaml
   ```

   ```yaml
   network:
     version: 2
     renderer: networkd
     ethernets:
       ens18:  # Replace with your interface name
         dhcp4: false
         addresses:
           - 192.168.1.103/24  # Your chosen IP
         gateway4: 192.168.1.1
         nameservers:
           addresses:
             - 192.168.1.1      # Master node IP
             - 8.8.8.8          # Fallback DNS
           search:
             - cluster.local
   ```

2. **Apply Network Configuration**
   ```bash
   # Test configuration
   sudo netplan try
   
   # Apply permanently
   sudo netplan apply
   
   # Verify connectivity
   ping -c 3 192.168.1.100  # Master node IP
   ping -c 3 8.8.8.8        # Internet connectivity
   ```

### DNS and Hostname Resolution

1. **Update /etc/hosts**
   ```bash
   sudo vim /etc/hosts
   ```
   
   ```
   127.0.0.1       localhost
   127.0.1.1       worker-03
   192.168.1.100   master-01
   192.168.1.101   worker-01
   192.168.1.102   worker-02
   192.168.1.103   worker-03
   
   # Add other cluster nodes as needed
   ```

2. **Configure systemd-resolved**
   ```bash
   # Check DNS resolution
   systemd-resolve --status
   
   # Test hostname resolution
   nslookup master-01
   ```

## Phase 4: Security Setup

### SSH Key Configuration

1. **Generate SSH Keys** (if not already done)
   ```bash
   # On your management machine
   ssh-keygen -t ed25519 -C "cluster-admin@worker-03"
   
   # Copy public key to new node
   ssh-copy-id admin@192.168.1.103
   ```

2. **Configure SSH Security**
   ```bash
   sudo vim /etc/ssh/sshd_config
   ```
   
   ```
   # Recommended SSH security settings
   PermitRootLogin no
   PasswordAuthentication no
   PubkeyAuthentication yes
   AuthorizedKeysFile .ssh/authorized_keys
   Port 22
   Protocol 2
   MaxAuthTries 3
   ClientAliveInterval 300
   ClientAliveCountMax 2
   ```
   
   ```bash
   # Restart SSH service
   sudo systemctl restart sshd
   ```

### User Account Setup

1. **Create Ansible User**
   ```bash
   # Create ansible user for automation
   sudo useradd -m -s /bin/bash ansible
   sudo usermod -aG sudo ansible
   
   # Set up passwordless sudo
   echo "ansible ALL=(ALL) NOPASSWD:ALL" | sudo tee /etc/sudoers.d/ansible
   
   # Set up SSH key for ansible user
   sudo -u ansible mkdir -p /home/ansible/.ssh
   sudo -u ansible chmod 700 /home/ansible/.ssh
   
   # Copy your public key
   sudo -u ansible tee /home/ansible/.ssh/authorized_keys << 'EOF'
   ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAI... your-public-key-here
   EOF
   
   sudo -u ansible chmod 600 /home/ansible/.ssh/authorized_keys
   ```

2. **Test SSH Access**
   ```bash
   # From management machine
   ssh ansible@192.168.1.103
   sudo whoami  # Should work without password
   ```

### Firewall Configuration

1. **Configure UFW**
   ```bash
   # Enable firewall
   sudo ufw enable
   
   # Allow SSH
   sudo ufw allow ssh
   
   # Allow cluster communication
   sudo ufw allow from 192.168.1.0/24
   
   # Kubernetes ports
   sudo ufw allow 10250/tcp  # kubelet
   sudo ufw allow 30000:32767/tcp  # NodePort services
   
   # SLURM ports
   sudo ufw allow 6817/tcp   # slurmd
   sudo ufw allow 6818/tcp   # slurmd
   
   # Check status
   sudo ufw status verbose
   ```

## Phase 5: System Preparation

### Package Installation

1. **Install Required Packages**
   ```bash
   # Update package list
   sudo apt update
   
   # Install essential packages
   sudo apt install -y \
       apt-transport-https \
       ca-certificates \
       curl \
       gnupg \
       lsb-release \
       software-properties-common \
       python3 \
       python3-pip \
       git \
       htop \
       iotop \
       nfs-common \
       chrony
   ```

2. **Configure Time Synchronization**
   ```bash
   # Configure chrony for time sync
   sudo vim /etc/chrony/chrony.conf
   ```
   
   Add master node as time source:
   ```
   server 192.168.1.100 iburst  # Master node
   server pool.ntp.org iburst   # Fallback
   ```
   
   ```bash
   # Restart and verify
   sudo systemctl restart chrony
   chrony sources -v
   ```

### Storage Preparation

1. **Configure Additional Storage** (if available)
   ```bash
   # List available disks
   lsblk
   
   # Create partition for container storage (example)
   sudo fdisk /dev/sdb
   # Create new partition, write changes
   
   # Format and mount
   sudo mkfs.ext4 /dev/sdb1
   sudo mkdir -p /var/lib/containers
   echo "/dev/sdb1 /var/lib/containers ext4 defaults 0 2" | sudo tee -a /etc/fstab
   sudo mount -a
   ```

2. **Configure Swap** (if needed)
   ```bash
   # Check current swap
   swapon --show
   
   # Create swap file if needed
   sudo fallocate -l 2G /swapfile
   sudo chmod 600 /swapfile
   sudo mkswap /swapfile
   sudo swapon /swapfile
   echo "/swapfile none swap sw 0 0" | sudo tee -a /etc/fstab
   ```

## Phase 6: Cluster Integration

### Update Inventory

1. **Add Node to Ansible Inventory**
   ```bash
   # On management machine, edit inventory
   vim ansible/inventory.ini
   ```
   
   Add new node:
   ```ini
   [workers]
   worker-01 ansible_host=192.168.1.101
   worker-02 ansible_host=192.168.1.102
   worker-03 ansible_host=192.168.1.103  # New node
   
   [kubernetes_workers]
   worker-01
   worker-02
   worker-03  # Add here too
   
   [slurm_workers]
   worker-01
   worker-02
   worker-03  # And here
   ```

### Automated Deployment

1. **Test Connectivity**
   ```bash
   # Test Ansible connectivity
   ansible worker-03 -m ping -i ansible/inventory.ini
   
   # Test sudo access
   ansible worker-03 -m shell -a "sudo whoami" -i ansible/inventory.ini
   ```

2. **Deploy to New Node**
   ```bash
   # Run deployment for new node only
   ansible-playbook -i ansible/inventory.ini \
       --limit worker-03 \
       ansible/site.yml
   
   # Or use the automated script
   ./scripts/add-node.sh worker-03 192.168.1.103
   ```

### Manual Integration Steps

If you prefer manual setup:

1. **Install Docker**
   ```bash
   # Add Docker repository
   curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
   
   echo "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
   
   sudo apt update
   sudo apt install -y docker-ce docker-ce-cli containerd.io
   sudo usermod -aG docker ansible
   ```

2. **Install Kubernetes**
   ```bash
   # Add Kubernetes repository
   curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add -
   echo "deb https://apt.kubernetes.io/ kubernetes-xenial main" | sudo tee /etc/apt/sources.list.d/kubernetes.list
   
   sudo apt update
   sudo apt install -y kubelet kubeadm kubectl
   sudo apt-mark hold kubelet kubeadm kubectl
   ```

3. **Join Kubernetes Cluster**
   ```bash
   # Get join command from master
   ssh master-01 "sudo kubeadm token create --print-join-command"
   
   # Run the join command on new node
   sudo kubeadm join 192.168.1.100:6443 --token <token> --discovery-token-ca-cert-hash sha256:<hash>
   ```

4. **Install SLURM**
   ```bash
   # Install SLURM packages
   sudo apt install -y slurm-wlm slurm-wlm-doc
   
   # Copy configuration from master
   scp master-01:/etc/slurm/slurm.conf /tmp/
   sudo cp /tmp/slurm.conf /etc/slurm/
   
   # Copy munge key
   scp master-01:/etc/munge/munge.key /tmp/
   sudo cp /tmp/munge.key /etc/munge/
   sudo chown munge:munge /etc/munge/munge.key
   sudo chmod 400 /etc/munge/munge.key
   
   # Start services
   sudo systemctl enable --now munge slurmd
   ```

## Phase 7: Verification and Testing

### Kubernetes Verification

1. **Check Node Status**
   ```bash
   # From master node
   kubectl get nodes
   kubectl describe node worker-03
   
   # Check node resources
   kubectl top node worker-03
   ```

2. **Test Pod Scheduling**
   ```bash
   # Create test pod on new node
   kubectl run test-pod --image=nginx --overrides='{"spec":{"nodeName":"worker-03"}}'
   
   # Check pod status
   kubectl get pods -o wide
   
   # Clean up
   kubectl delete pod test-pod
   ```

### SLURM Verification

1. **Check SLURM Status**
   ```bash
   # Check node in SLURM
   sinfo -N
   scontrol show node worker-03
   
   # Test job submission
   srun -w worker-03 hostname
   ```

2. **Submit Test Job**
   ```bash
   # Create simple test job
   cat > test-job.sh << 'EOF'
   #!/bin/bash
   #SBATCH --job-name=node-test
   #SBATCH --output=test-%j.out
   #SBATCH --nodelist=worker-03
   #SBATCH --time=00:01:00
   
   echo "Testing new node: $(hostname)"
   echo "Date: $(date)"
   echo "CPU info: $(nproc) cores"
   echo "Memory: $(free -h | grep Mem)"
   EOF
   
   sbatch test-job.sh
   squeue
   ```

### System Health Checks

1. **Resource Monitoring**
   ```bash
   # Check system resources
   htop
   iotop
   df -h
   free -h
   
   # Check network connectivity
   ping -c 3 master-01
   curl -k https://master-01:6443/version
   ```

2. **Service Status**
   ```bash
   # Check all services
   sudo systemctl status docker
   sudo systemctl status kubelet
   sudo systemctl status munge
   sudo systemctl status slurmd
   
   # Check logs for errors
   sudo journalctl -u kubelet --since "1 hour ago"
   sudo journalctl -u slurmd --since "1 hour ago"
   ```

### Performance Testing

1. **CPU Benchmark**
   ```bash
   # Install and run stress test
   sudo apt install -y stress-ng
   stress-ng --cpu 0 --timeout 60s --metrics-brief
   ```

2. **Network Benchmark**
   ```bash
   # Test network performance to master
   sudo apt install -y iperf3
   
   # On master node
   iperf3 -s
   
   # On new node
   iperf3 -c master-01 -t 30
   ```

## Phase 8: Integration Validation

### Cluster-wide Tests

1. **Deploy Test Application**
   ```bash
   # Create test deployment
   kubectl create deployment nginx-test --image=nginx --replicas=3
   kubectl scale deployment nginx-test --replicas=6
   
   # Check pod distribution
   kubectl get pods -o wide | grep nginx-test
   
   # Clean up
   kubectl delete deployment nginx-test
   ```

2. **SLURM Cluster Test**
   ```bash
   # Submit multi-node job
   cat > cluster-test.sh << 'EOF'
   #!/bin/bash
   #SBATCH --job-name=cluster-test
   #SBATCH --nodes=2
   #SBATCH --ntasks=4
   #SBATCH --time=00:05:00
   
   srun hostname
   EOF
   
   sbatch cluster-test.sh
   ```

### Monitoring Integration

1. **Check Monitoring Stack**
   ```bash
   # Verify node appears in Prometheus
   kubectl port-forward -n monitoring svc/prometheus-server 9090:80
   # Open browser to localhost:9090, check targets
   
   # Check Grafana dashboards
   kubectl port-forward -n monitoring svc/grafana 3000:80
   # Open browser to localhost:3000, check node metrics
   ```

## Troubleshooting

### Common Issues

**Node Not Joining Kubernetes**
```bash
# Check kubelet logs
sudo journalctl -u kubelet -f

# Reset and rejoin
sudo kubeadm reset
# Get new join command and retry
```

**SLURM Node Down**
```bash
# Check munge authentication
sudo systemctl status munge
sudo munge -n | unmunge

# Check SLURM configuration
sudo scontrol update nodename=worker-03 state=resume
```

**Network Issues**
```bash
# Check network configuration
ip route show
systemd-resolve --status

# Test cluster connectivity
nc -zv master-01 6443
nc -zv master-01 6817
```

### Performance Issues

**High Load Average**
```bash
# Check running processes
top
ps aux --sort=-%cpu | head -20

# Check I/O wait
iostat -x 1 5
```

**Memory Issues**
```bash
# Check memory usage
free -h
cat /proc/meminfo

# Check for memory leaks
sudo dmesg | grep -i "killed process"
```

## Best Practices

### Security Hardening

1. **Regular Updates**
   ```bash
   # Set up automatic security updates
   sudo apt install -y unattended-upgrades
   sudo dpkg-reconfigure -plow unattended-upgrades
   ```

2. **Log Monitoring**
   ```bash
   # Configure log rotation
   sudo vim /etc/logrotate.d/cluster-logs
   
   # Monitor auth logs
   sudo tail -f /var/log/auth.log
   ```

### Maintenance

1. **Regular Health Checks**
   ```bash
   # Create health check script
   cat > /home/ansible/health-check.sh << 'EOF'
   #!/bin/bash
   echo "=== Node Health Check ==="
   echo "Date: $(date)"
   echo "Uptime: $(uptime)"
   echo "Load: $(cat /proc/loadavg)"
   echo "Memory: $(free -h | grep Mem)"
   echo "Disk: $(df -h / | tail -1)"
   echo "Docker: $(sudo systemctl is-active docker)"
   echo "Kubelet: $(sudo systemctl is-active kubelet)"
   echo "SLURM: $(sudo systemctl is-active slurmd)"
   EOF
   
   chmod +x /home/ansible/health-check.sh
   ```

2. **Backup Important Configs**
   ```bash
   # Create backup directory
   sudo mkdir -p /backup/configs
   
   # Backup key configurations
   sudo cp /etc/kubernetes/kubelet.conf /backup/configs/
   sudo cp /etc/slurm/slurm.conf /backup/configs/
   sudo cp /etc/munge/munge.key /backup/configs/
   ```

## Summary

You've successfully added a new node to your cluster! The node should now be:

- ✅ **Integrated** with Kubernetes cluster
- ✅ **Participating** in SLURM workload management  
- ✅ **Monitored** by Prometheus and Grafana
- ✅ **Secured** with proper SSH and firewall configuration
- ✅ **Ready** for production workloads

For ongoing maintenance, use the cluster management scripts in the `scripts/` directory and monitor the node through the web dashboards.

If you encounter any issues, refer to the troubleshooting section or check the cluster logs for detailed error information.
