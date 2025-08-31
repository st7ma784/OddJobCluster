# Kubernetes Cluster with SLURM and Jupyter - Deployment Guide

This guide covers the deployment process for the heterogeneous Kubernetes SLURM cluster supporting both x86 and ARM architectures.

## Table of Contents
1. [Prerequisites](#prerequisites)
2. [Hardware Requirements](#hardware-requirements)
3. [Network Setup](#network-setup)
4. [Initial Server Setup](#initial-server-setup)
5. [Ansible Setup](#ansible-setup)
6. [Deploying the Cluster](#deploying-the-cluster)
7. [Accessing Services](#accessing-services)
8. [Maintenance](#maintenance)
9. [Troubleshooting](#troubleshooting)

## Prerequisites

### **Base Requirements**
- Multiple nodes with Ubuntu 22.04+ LTS
- SSH access configured between nodes
- Ansible installed on control machine
- Internet access on all nodes

### **Supported Platforms**
- **x86_64**: Traditional servers, laptops, workstations (4GB+ RAM, 2+ cores)
- **ARM64**: Raspberry Pi 4/3, Android devices, NVIDIA Jetson (2GB+ RAM recommended)
- **Mixed architectures**: Seamless integration of both platforms

## Hardware Requirements

### **x86 Nodes**
#### Master Node
- 2+ CPU cores
- 4GB+ RAM
- 50GB+ storage

#### Worker Nodes
- 2+ CPU cores
- 4GB+ RAM
- 100GB+ storage

### **ARM Nodes**
#### Raspberry Pi 4
- 4 ARM cores
- 4GB+ RAM (8GB recommended)
- 32GB+ SD card (Class 10)

#### Android Devices
- 4+ ARM cores
- 3GB+ RAM
- Termux or UserLAnd app

#### NVIDIA Jetson
- 4-8 ARM cores
- 4GB+ RAM
- GPU acceleration support

## Network Setup

1. Connect all laptops to the same network (wired recommended)
2. Assign static IPs to each node or configure your router to provide consistent IPs
3. Ensure all nodes can ping each other
4. Configure hostnames on each node (e.g., `k8s-master`, `k8s-worker1`, etc.)

## Initial Server Setup

On each node:

```bash
# Update system
sudo apt update && sudo apt upgrade -y

# Install required packages
sudo apt install -y python3 python3-pip python3-venv git curl

# Create deployment user
sudo useradd -m -s /bin/bash ansible
sudo usermod -aG sudo ansible
sudo passwd ansible

# Enable passwordless sudo
echo "ansible ALL=(ALL) NOPASSWD:ALL" | sudo tee /etc/sudoers.d/ansible

# Configure SSH key-based authentication
sudo mkdir -p /home/ansible/.ssh
sudo chmod 700 /home/ansible/.ssh
sudo cp ~/.ssh/authorized_keys /home/ansible/.ssh/
sudo chown -R ansible:ansible /home/ansible/.ssh
```

## Ansible Setup

On your control machine (can be one of the cluster nodes):

```bash
# Install Ansible
sudo apt update
sudo apt install -y python3 python3-pip python3-venv

# Clone this repository
git clone https://github.com/yourusername/kubernetes-slurm-cluster.git
cd kubernetes-slurm-cluster

# Create Python virtual environment
python3 -m venv venv
source venv/bin/activate

# Install dependencies
pip install -r requirements.txt
ansible-galaxy install -r ansible/requirements.yml

# Configure inventory
nano ansible/inventory.ini  # Update with your node IPs/hostnames

# Configure variables
nano ansible/group_vars/all.yml  # Update passwords and settings
```

## Deploying the Cluster

### Option 1: Automated Deployment (Recommended)

Use the provided deployment script for a fully automated setup:

```bash
./scripts/deploy.sh
```

This script will:
- Check prerequisites
- Set up the Python environment
- Install dependencies
- Test connectivity
- Deploy the entire cluster
- Provide access URLs and credentials

### Option 2: Manual Deployment

1. Test Ansible connection:

```bash
ansible all -i ansible/inventory.ini -m ping
```

2. Run the playbook:

```bash
ansible-playbook -i ansible/inventory.ini ansible/site.yml
```

3. Monitor the deployment process. It may take 15-30 minutes to complete.

### Post-Deployment Validation

After deployment, validate your cluster:

```bash
./scripts/validate-cluster.sh
```

Get service credentials:

```bash
./scripts/get-credentials.sh
```

## Accessing Services

### JupyterHub
- URL: `https://<master-ip>/jupyter`
- Default admin user: `admin`
- To get the admin password:
  ```bash
  kubectl get secret --namespace jupyter hub -o jsonpath="{.data.values\.yaml}" | base64 --decode | grep -A 2 'admin:' | grep password
  ```

### SLURM Dashboard
- URL: `https://<master-ip>/slurm`
- Use your system credentials to log in

### Kubernetes Dashboard
- URL: `https://<master-ip>/kubernetes`
- To get the admin token:
  ```bash
  kubectl -n kubernetes-dashboard create token admin-user
  ```

## Maintenance

### Adding Nodes

#### **Adding x86 Nodes**
1. Set up the new node following the [Initial Server Setup](#initial-server-setup) steps
2. Add the node to `ansible/inventory.ini` under the appropriate groups
3. Run the playbook:
   ```bash
   ansible-playbook -i ansible/inventory.ini ansible/site.yml --limit=<new-node-hostname>
   ```

#### **Adding ARM Nodes**
1. **Raspberry Pi**:
   ```bash
   ./scripts/add-arm-node.sh rpi4-8gb 192.168.1.100
   ```

2. **Android Device**:
   ```bash
   ./scripts/add-arm-node.sh android 192.168.1.102 u0_a123
   ```

3. **NVIDIA Jetson**:
   ```bash
   ./scripts/add-arm-node.sh jetson 192.168.1.104 nvidia
   ```

#### **ARM Node Discovery**
```bash
# Discover ARM devices on network
./scripts/arm-node-discovery.sh discover

# Monitor ARM node health
./scripts/arm-node-discovery.sh monitor --continuous
```

### Updating the Cluster
1. Update the repository:
   ```bash
   git pull origin main
   ```
2. Run the playbook:
   ```bash
   ansible-playbook -i ansible/inventory.ini ansible/site.yml
   ```

### Backup and Restore
#### Backup
```bash
# Backup etcd
kubectl exec -n kube-system etcd-<node-name> -- etcdctl snapshot save /tmp/etcd-snapshot.db

# Backup persistent volumes
# (This depends on your storage solution)
```

#### Restore
```bash
# Restore etcd
kubectl exec -n kube-system etcd-<node-name> -- etcdctl snapshot restore /tmp/etcd-snapshot.db
```

## Troubleshooting

### Common Issues

#### Node Not Ready
```bash
# Check node status
kubectl get nodes

# Check kubelet logs
journalctl -u kubelet -f

# Check container runtime
sudo crictl ps -a
```

#### Network Issues
```bash
# Check pod network
kubectl get pods --all-namespaces -o wide

# Check network policies
kubectl get networkpolicies --all-namespaces
```

#### SLURM Issues
```bash
# Check SLURM daemon status
sudo systemctl status slurmd
sudo systemctl status slurmctld

# Check SLURM logs
sudo tail -f /var/log/slurm/*.log
```

## Advanced Configuration

### SSL Certificate Setup
To enable SSL/TLS with Let's Encrypt:
```bash
./scripts/setup-ssl.sh your-domain.com admin@your-domain.com
```

### User Management
Add users to the cluster:
```bash
./scripts/manage-users.sh add username
./scripts/manage-users.sh add admin-user --admin
```

List all users:
```bash
./scripts/manage-users.sh list
```

### Backup and Restore
Create a backup:
```bash
./scripts/backup-cluster.sh
```

Restore from backup:
```bash
./scripts/restore-cluster.sh /path/to/backup
```

### Container Registry
The cluster includes a private Docker registry accessible at:
- URL: `https://<master-ip>/registry`
- Push images: `docker push <master-ip>/registry/image:tag`

## Testing the Cluster

### Submit SLURM Jobs
Test with sample jobs:

#### **x86 Jobs**
```bash
# Copy job scripts to master node
scp examples/slurm-jobs/*.sh user@master-node:~/

# Submit jobs
sbatch hello-world.sh
sbatch parallel-computation.sh
sbatch gpu-computation.sh

# Monitor jobs
squeue
sinfo
```

#### **ARM Jobs**
```bash
# Generate ARM-optimized job examples
./examples/slurm-jobs/arm-workloads.sh

# Submit ARM-specific jobs
sbatch --partition=arm_compute arm-hello-world.sh
sbatch --partition=edge_compute rpi-temperature-monitor.sh
sbatch mobile-device-job.sh

# Monitor ARM partitions
sinfo -p arm_compute
sinfo -p edge_compute
```

#### **Mixed Architecture Jobs**
```bash
# Submit jobs that can run on any architecture
sbatch multi-arch-parallel.sh

# View all partitions
sinfo
```

### Access Services
- **JupyterHub**: `https://<master-ip>/jupyter` (admin/admin)
- **Grafana**: `https://<master-ip>/grafana` (admin/admin)
- **Docker Registry**: `https://<master-ip>/registry`

### Getting Help
For additional help, please open an issue on the GitHub repository or consult the documentation.

## License
This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
