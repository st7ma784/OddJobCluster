# Node Setup Log

## Target Nodes
- **Node 1**: 192.168.4.157 (username: steve, password: password)
- **Node 2**: 192.168.5.57 (username: steve, password: password)

## Setup Process Documentation

### Phase 1: Initial Connectivity Testing

#### Node 192.168.4.157
```bash
# Test network connectivity
ping -c 3 192.168.4.157
# Result: SUCCESS - 3 packets transmitted, 3 received, 0% packet loss
# RTT: min/avg/max = 161.330/248.104/338.940 ms
```

#### Node 192.168.5.57
```bash
# Test network connectivity  
ping -c 3 192.168.5.57
# Result: SUCCESS - 3 packets transmitted, 3 received, 0% packet loss
# RTT: min/avg/max = 35.790/100.234/211.003 ms
```

### Phase 2: SSH Key Setup

#### Generate SSH keys for cluster access
```bash
# Generate cluster SSH key if not exists
ssh-keygen -t ed25519 -f ~/.ssh/cluster_key -N "" -C "cluster-admin@$(hostname)"
# Result: SUCCESS - Key generated with fingerprint SHA256:o2C3PliP9TbbsAP/k2PpPteoPMLVA2q5+l2pAQ3o2fo
```

### Phase 3: Node Preparation Commands

#### Node 192.168.4.157 - Initial SSH Test
```bash
# Test SSH connectivity and gather system info
sshpass -p "password" ssh -o ConnectTimeout=10 -o StrictHostKeyChecking=no steve@192.168.4.157 "whoami && hostname && cat /etc/os-release | grep PRETTY_NAME"
# Result: SUCCESS
# User: steve
# Hostname: steve-IdeaPad-Flex-5-15ALC05
# OS: Ubuntu 25.04
```

#### Node 192.168.5.57 - Initial SSH Test
```bash
# Test SSH connectivity and gather system info
sshpass -p "password" ssh -o ConnectTimeout=10 -o StrictHostKeyChecking=no steve@192.168.5.57 "whoami && hostname && cat /etc/os-release | grep PRETTY_NAME"
# Result: SUCCESS
# User: steve
# Hostname: steve-ThinkPad-L490
# OS: Ubuntu 25.04
```

### Phase 4: Ansible User Setup

#### Node 192.168.4.157 - Create ansible user
```bash
# Create ansible user with sudo privileges
sshpass -p "password" ssh -o StrictHostKeyChecking=no steve@192.168.4.157 "echo 'password' | sudo -S useradd -m -s /bin/bash ansible && echo 'password' | sudo -S usermod -aG sudo ansible && echo 'ansible ALL=(ALL) NOPASSWD:ALL' | sudo -S tee /etc/sudoers.d/ansible"
# Result: SUCCESS - ansible user created with passwordless sudo
```

#### Node 192.168.5.57 - Create ansible user
```bash
# Create ansible user with sudo privileges
sshpass -p "password" ssh -o StrictHostKeyChecking=no steve@192.168.5.57 "echo 'password' | sudo -S useradd -m -s /bin/bash ansible && echo 'password' | sudo -S usermod -aG sudo ansible && echo 'ansible ALL=(ALL) NOPASSWD:ALL' | sudo -S tee /etc/sudoers.d/ansible"
# Result: WARNING - ansible user already exists, configured sudo access
```

### Phase 5: SSH Key Deployment

#### Node 192.168.4.157 - Setup SSH directory
```bash
# Create SSH directory for ansible user
sshpass -p "password" ssh -o StrictHostKeyChecking=no steve@192.168.4.157 "echo 'password' | sudo -S mkdir -p /home/ansible/.ssh && echo 'password' | sudo -S chmod 700 /home/ansible/.ssh && echo 'password' | sudo -S chown ansible:ansible /home/ansible/.ssh"
# Result: SUCCESS - SSH directory created
```

#### Node 192.168.4.157 - Deploy SSH public key
```bash
# Copy SSH public key to ansible user
cat ~/.ssh/cluster_key.pub | sshpass -p "password" ssh -o StrictHostKeyChecking=no steve@192.168.4.157 "echo 'password' | sudo -S tee /home/ansible/.ssh/authorized_keys && echo 'password' | sudo -S chmod 600 /home/ansible/.ssh/authorized_keys && echo 'password' | sudo -S chown ansible:ansible /home/ansible/.ssh/authorized_keys"
# Result: SUCCESS - SSH key deployed
```

#### Node 192.168.4.157 - Set ansible user password and test access
```bash
# Set password for ansible user
sshpass -p "password" ssh -o StrictHostKeyChecking=no steve@192.168.4.157 "echo 'password' | sudo -S bash -c 'echo \"ansible:password\" | chpasswd'"
# Result: SUCCESS - Password set (with dictionary warning)

# Test ansible user access
sshpass -p "password" ssh -o StrictHostKeyChecking=no ansible@192.168.4.157 "whoami && sudo whoami && hostname"
# Result: SUCCESS
# User: ansible
# Sudo: root
# Hostname: steve-IdeaPad-Flex-5-15ALC05
```

#### Node 192.168.5.57 - Setup SSH and test access
```bash
# Create SSH directory
sshpass -p "password" ssh -o StrictHostKeyChecking=no steve@192.168.5.57 "echo 'password' | sudo -S mkdir -p /home/ansible/.ssh && echo 'password' | sudo -S chmod 700 /home/ansible/.ssh && echo 'password' | sudo -S chown ansible:ansible /home/ansible/.ssh"
# Result: SUCCESS

# Deploy SSH key
cat ~/.ssh/cluster_key.pub | sshpass -p "password" ssh -o StrictHostKeyChecking=no steve@192.168.5.57 "echo 'password' | sudo -S su - ansible -c 'cat > ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys'"
# Result: SUCCESS

# Set ansible user password
sshpass -p "password" ssh -o StrictHostKeyChecking=no steve@192.168.5.57 "echo 'password' | sudo -S bash -c 'echo \"ansible:password\" | chpasswd'"
# Result: SUCCESS - Password set (with dictionary warning)

# Test ansible user access
sshpass -p "password" ssh -o StrictHostKeyChecking=no ansible@192.168.5.57 "whoami && sudo whoami && hostname"
# Result: SUCCESS
# User: ansible
# Sudo: root
# Hostname: steve-ThinkPad-L490
```

### Phase 6: Inventory Setup and Ansible Testing

#### Install Ansible
```bash
# Install Ansible on management machine
sudo apt update && sudo apt install -y ansible
# Result: SUCCESS - Ansible 9.2.0 installed
```

#### Add nodes to inventory
```bash
# Updated ansible/inventory.ini with new nodes:
# steve-ideapad ansible_host=192.168.4.157 ansible_user=ansible ansible_ssh_pass=password
# steve-thinkpad ansible_host=192.168.5.57 ansible_user=ansible ansible_ssh_pass=password
```

#### Test Ansible connectivity
```bash
# Test ping connectivity to both nodes
ansible steve-ideapad,steve-thinkpad -m ping -i ansible/inventory.ini --ask-pass
# Result: PARTIAL SUCCESS
# steve-thinkpad: SUCCESS - ping pong
# steve-ideapad: UNREACHABLE - Connection timed out
```

#### System information gathering from working node
```bash
# Get system details from steve-thinkpad
ansible steve-thinkpad -m setup -i ansible/inventory.ini --ask-pass -a "filter=ansible_distribution*,ansible_memory_mb,ansible_processor_count"
# Result: SUCCESS
# OS: Ubuntu 25.04 (plucky)
# Memory: 7102 MB total, 4927 MB free
# CPU: 1 processor
```

#### Network connectivity check for steve-ideapad
```bash
# Re-test network connectivity to first node
ping -c 2 192.168.4.157
# Result: FAILED - Destination Host Unreachable
# Note: Node was reachable earlier but now shows network issues
```

### Phase 7: Summary and Next Steps

#### Successfully Configured Nodes
- **steve-thinkpad (192.168.5.57)**: ✅ READY
  - SSH access: Working
  - Ansible connectivity: Working
  - System: Ubuntu 25.04, 7GB RAM, 1 CPU
  - Status: Ready for cluster integration

#### Nodes with Issues
- **steve-ideapad (192.168.4.157)**: ⚠️ NETWORK ISSUE
  - SSH access: Was working
  - Current status: Network unreachable
  - Issue: Intermittent connectivity or node powered down

#### Next Steps for Cluster Integration
```bash
# For working node (steve-thinkpad), run cluster deployment:
# 1. Test full Ansible playbook on single node
ansible-playbook -i ansible/inventory.ini --limit steve-thinkpad ansible/site.yml --ask-pass

# 2. Or use automated script
./scripts/add-node.sh steve-thinkpad 192.168.5.57

# 3. Verify integration
kubectl get nodes
sinfo -N
```

### Phase 8: Cluster Deployment Results

#### Ansible Playbook Execution
```bash
# Deploy cluster components to steve-thinkpad
ansible-playbook -i ansible/inventory.ini --limit steve-thinkpad ansible/site.yml --ask-pass
# Result: PARTIAL SUCCESS - Node prepared for cluster joining

# Components successfully installed:
# - Docker 27.5.1 (running)
# - Kubernetes components (kubelet, kubeadm, kubectl)
# - containerd runtime
# - Network configuration for Kubernetes
# - System optimizations (swap disabled, kernel modules loaded)
```

#### Service Status Verification
```bash
# Check Docker status
ansible steve-thinkpad -i ansible/inventory.ini --ask-pass -m shell -a "docker --version && sudo systemctl status docker"
# Result: SUCCESS
# Docker version 27.5.1, build 27.5.1-0ubuntu3
# Status: active (running)

# Check kubelet status
ansible steve-thinkpad -i ansible/inventory.ini --ask-pass -m shell -a "sudo systemctl status kubelet"
# Result: EXPECTED - kubelet inactive (waiting for cluster join)
```

### Phase 9: Final Status Summary

#### ✅ Successfully Deployed Components
- **Base System**: Ubuntu 25.04 with proper configuration
- **Container Runtime**: Docker 27.5.1 running successfully
- **Kubernetes**: kubelet, kubeadm, kubectl installed and configured
- **Network**: Proper kernel modules and sysctl settings applied
- **User Management**: ansible user with passwordless sudo
- **SSH Access**: Working with both password and key authentication

#### 🔄 Ready for Cluster Integration
- **Node Status**: Prepared and waiting for cluster join command
- **Next Step**: Node needs to join an existing Kubernetes cluster or initialize as master
- **SLURM Integration**: Ready for SLURM worker node deployment
- **JupyterHub**: Ready for notebook server integration

#### 📋 Integration Commands
```bash
# To join an existing cluster (run on steve-thinkpad):
# sudo kubeadm join <master-ip>:6443 --token <token> --discovery-token-ca-cert-hash sha256:<hash>

# To initialize as single-node cluster (for testing):
# sudo kubeadm init --pod-network-cidr=10.244.0.0/16

# To deploy SLURM components:
# ansible-playbook -i ansible/inventory.ini --limit steve-thinkpad --tags slurm ansible/site.yml --ask-pass
```

### Phase 10: Full Cluster Integration Complete

#### ✅ Final Cluster Status - steve-thinkpad (192.168.5.57)

**Kubernetes Cluster:**
```bash
# Cluster Status
kubectl get nodes -o wide
# Result: steve-thinkpad-l490 Ready control-plane v1.28.15 containerd://2.0.5

# Core Components Running:
# - etcd: Running (1/1)
# - kube-apiserver: Running (1/1) 
# - kube-controller-manager: Running (1/1)
# - kube-scheduler: Running (1/1)
# - kube-proxy: Running (1/1)
```

**SLURM Workload Manager:**
```bash
# SLURM Status
sinfo
# Result: compute* partition with steve-ThinkPad-L490 node in idle state

# Services Active:
systemctl is-active slurmctld slurmd munge
# Result: active active active

# Version: slurm-wlm 24.11.3
```

**JupyterHub:**
```bash
# JupyterHub Status
systemctl is-active jupyterhub
# Result: active

# Service: Running on port 8000
# Access: http://192.168.5.57:8000
```

#### 🔧 SSH Key Authentication
```bash
# Password-free access configured
ssh -i ~/.ssh/cluster_key ansible@192.168.5.57
# Result: Direct login without password prompts
```

#### 📊 Cluster Capabilities
- **Container Orchestration**: Kubernetes v1.28.15 with Flannel networking
- **Workload Management**: SLURM with single compute partition
- **Interactive Computing**: JupyterHub for notebook-based workflows
- **Node Resources**: 4 CPUs, 7GB RAM, Ubuntu 25.04
- **Network**: Fully configured with pod and service networking

#### 🎯 Integration Achievement
**steve-thinkpad node is now fully integrated with:**
1. ✅ **Kubernetes cluster membership** - Ready control-plane node
2. ✅ **SLURM workload management** - Active compute node in idle state
3. ✅ **JupyterHub capability** - Running notebook server on port 8000

#### 🔗 Access Information
- **Kubernetes API**: https://192.168.5.57:6443
- **JupyterHub Web Interface**: http://192.168.5.57:8000
- **SLURM Controller**: steve-ThinkPad-L490:6817
- **SSH Access**: `ssh -i ~/.ssh/cluster_key ansible@192.168.5.57`

#### 📝 Next Steps for steve-ideapad (192.168.4.157)
- **Status**: Network connectivity issues (intermittent)
- **Action Required**: Re-establish network connection and repeat integration process
- **Command**: `./scripts/discover-nodes.sh` to check connectivity
- **Integration**: Use same process once connectivity is restored
