# Rapid Node Deployment Guide

This guide provides step-by-step instructions for quickly adding new nodes to an existing Kubernetes cluster with SLURM and Jupyter.

## Prerequisites

- Existing cluster already deployed and operational
- New hardware with Ubuntu 22.04 LTS installed
- Network connectivity between new and existing nodes
- SSH access to new nodes

## Quick Node Addition (5 Minutes)

### Step 1: Prepare New Node (2 minutes)

On the new node, run:

```bash
# Update system
sudo apt update && sudo apt upgrade -y

# Create ansible user
sudo useradd -m -s /bin/bash ansible
sudo usermod -aG sudo ansible
echo "ansible ALL=(ALL) NOPASSWD:ALL" | sudo tee /etc/sudoers.d/ansible

# Set up SSH key access
sudo mkdir -p /home/ansible/.ssh
sudo cp ~/.ssh/authorized_keys /home/ansible/.ssh/
sudo chown -R ansible:ansible /home/ansible/.ssh
sudo chmod 700 /home/ansible/.ssh
sudo chmod 600 /home/ansible/.ssh/authorized_keys
```

### Step 2: Add Node to Inventory (1 minute)

On the control machine:

```bash
# Edit inventory file
nano ansible/inventory.ini

# Add new node to [workers] section:
worker3 ansible_host=192.168.1.13

# Also add to appropriate groups:
# [kube_node:children] - already includes workers
# [slurm_node:children] - already includes workers
```

### Step 3: Deploy to New Node (2 minutes)

```bash
# Test connectivity
ansible worker3 -i ansible/inventory.ini -m ping

# Deploy only to new node
ansible-playbook -i ansible/inventory.ini ansible/site.yml --limit=worker3

# Verify node joined cluster
kubectl get nodes
```

## Automated Node Scaling Script

Use the provided script for fully automated node addition:

```bash
./scripts/add-node.sh <node-ip> <node-hostname>
```

Example:
```bash
./scripts/add-node.sh 192.168.1.13 worker3
```

## Bulk Node Addition

For adding multiple nodes simultaneously:

### Step 1: Prepare Node List

Create a file `new-nodes.txt`:
```
192.168.1.13 worker3
192.168.1.14 worker4
192.168.1.15 worker5
```

### Step 2: Run Bulk Addition

```bash
./scripts/bulk-add-nodes.sh new-nodes.txt
```

## Node Preparation Automation

### Option 1: Cloud-Init (Recommended for VMs)

Create `cloud-init.yaml`:
```yaml
#cloud-config
users:
  - name: ansible
    sudo: ALL=(ALL) NOPASSWD:ALL
    shell: /bin/bash
    ssh_authorized_keys:
      - ssh-rsa AAAAB3NzaC1yc2E... # Your public key

packages:
  - python3
  - python3-pip
  - curl

runcmd:
  - apt update && apt upgrade -y
  - systemctl enable ssh
```

### Option 2: PXE Boot Setup

For bare metal rapid deployment, configure PXE boot with:
- Ubuntu 22.04 LTS netboot image
- Preseed configuration for automated installation
- Post-install script for ansible user setup

## Verification Steps

After adding nodes, verify the deployment:

```bash
# Check cluster status
./scripts/validate-cluster.sh

# Verify new nodes
kubectl get nodes -o wide
sinfo

# Test SLURM job on new node
sbatch --nodelist=worker3 examples/slurm-jobs/hello-world.sh
```

## Troubleshooting

### Node Not Joining Cluster

```bash
# Check kubelet logs on new node
ansible worker3 -i ansible/inventory.ini -m shell -a "journalctl -u kubelet -f" --become

# Regenerate join token if expired
ansible master -i ansible/inventory.ini -m shell -a "kubeadm token create --print-join-command" --become
```

### SLURM Node Not Responding

```bash
# Check SLURM daemon on new node
ansible worker3 -i ansible/inventory.ini -m shell -a "systemctl status slurmd" --become

# Restart SLURM services
ansible worker3 -i ansible/inventory.ini -m systemd -a "name=slurmd state=restarted" --become
```

### Network Issues

```bash
# Test network connectivity
ansible worker3 -i ansible/inventory.ini -m shell -a "ping -c 3 master"

# Check firewall rules
ansible worker3 -i ansible/inventory.ini -m shell -a "ufw status" --become
```

## Node Removal

To remove a node from the cluster:

```bash
./scripts/remove-node.sh worker3
```

This will:
1. Drain the node of workloads
2. Remove from Kubernetes cluster
3. Remove from SLURM configuration
4. Update inventory file

## Performance Optimization

### For High-Performance Workloads

Add these optimizations to new nodes:

```bash
# CPU performance mode
echo performance | sudo tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor

# Disable swap
sudo swapoff -a

# Optimize network settings
echo 'net.core.rmem_max = 134217728' | sudo tee -a /etc/sysctl.conf
echo 'net.core.wmem_max = 134217728' | sudo tee -a /etc/sysctl.conf
sudo sysctl -p
```

### For GPU Nodes

Additional steps for GPU-enabled nodes:

```bash
# Install NVIDIA drivers
sudo apt install nvidia-driver-525 nvidia-utils-525

# Install NVIDIA Container Toolkit
curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | sudo gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg
curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list | \
  sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' | \
  sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list

sudo apt update && sudo apt install nvidia-container-toolkit
sudo nvidia-ctk runtime configure --runtime=containerd
sudo systemctl restart containerd

# Install NVIDIA device plugin
kubectl apply -f https://raw.githubusercontent.com/NVIDIA/k8s-device-plugin/v0.14.0/nvidia-device-plugin.yml
```

## Security Considerations

### Hardening New Nodes

```bash
# Update SSH configuration
sudo sed -i 's/#PermitRootLogin yes/PermitRootLogin no/' /etc/ssh/sshd_config
sudo sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
sudo systemctl restart ssh

# Configure firewall
sudo ufw enable
sudo ufw allow from 192.168.1.0/24  # Adjust for your network
sudo ufw allow ssh
```

### Certificate Management

New nodes automatically receive:
- Kubernetes certificates via kubeadm join
- SLURM munge key from master node
- Container registry certificates

## Monitoring Integration

New nodes are automatically integrated with monitoring:
- Prometheus node exporter installed
- Grafana dashboards updated
- Alerting rules applied

Check monitoring status:
```bash
# Verify metrics collection
kubectl get pods -n monitoring -l app=prometheus-node-exporter
```

## Best Practices

1. **Always test connectivity** before running deployment
2. **Use consistent naming** for hostnames and inventory
3. **Document custom configurations** for each node type
4. **Backup cluster state** before major changes
5. **Monitor resource usage** after adding nodes
6. **Update documentation** with node-specific details

## Next Steps

After successful node addition:
1. Update monitoring dashboards with new nodes
2. Adjust SLURM partition configurations if needed
3. Test workload distribution across all nodes
4. Update backup procedures to include new nodes
5. Document any node-specific configurations
