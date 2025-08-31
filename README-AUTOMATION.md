# 🚀 Automated Cluster Setup Guide

This project now includes comprehensive automation scripts for deploying and managing your Kubernetes SLURM Jupyter cluster.

## 🎯 Quick Start - One Command Deployment

Deploy a complete cluster with a single command:

```bash
# Deploy to a single master node
./scripts/quick-cluster-deploy.sh 192.168.5.57

# Deploy with additional worker nodes
./scripts/quick-cluster-deploy.sh 192.168.5.57 192.168.4.157 192.168.1.100
```

## 📋 Available Automation Scripts

### 1. **Full Cluster Setup** - `auto-cluster-setup.sh`
Complete automated deployment with all components:

```bash
# Deploy to specific master
./scripts/auto-cluster-setup.sh --master 192.168.5.57

# Add worker nodes
./scripts/auto-cluster-setup.sh --master 192.168.5.57 --node 192.168.4.157 --node 192.168.1.100

# Auto-discover nodes on network
./scripts/auto-cluster-setup.sh --discover --master 192.168.5.57
```

**Features:**
- ✅ SSH key generation and deployment
- ✅ Ansible inventory management
- ✅ Complete cluster deployment
- ✅ Kubernetes initialization
- ✅ SLURM configuration
- ✅ JupyterHub setup
- ✅ Automatic containerd fixes
- ✅ Health verification

### 2. **Enhanced Deployment** - `deploy-enhanced.sh`
Advanced deployment with options:

```bash
# Full deployment
./scripts/deploy-enhanced.sh

# Deploy to specific target
./scripts/deploy-enhanced.sh --target 192.168.5.57

# Deploy specific components
./scripts/deploy-enhanced.sh --tags kubernetes,slurm

# Skip post-deployment fixes
./scripts/deploy-enhanced.sh --skip-fixes --skip-verify
```

### 3. **Health Monitoring** - `health-check.sh`
Comprehensive cluster health verification:

```bash
./scripts/health-check.sh
```

**Checks:**
- 🔍 System resources (CPU, memory, disk)
- 🐳 Container runtime status
- ☸️ Kubernetes cluster health
- ⚡ SLURM services and partitions
- 📓 JupyterHub availability
- 🌐 Network port status

### 4. **Node Repair** - `node-repair.sh`
Automatic issue resolution:

```bash
./scripts/node-repair.sh 192.168.5.57
```

**Fixes:**
- 🔧 Containerd configuration issues
- ☸️ Kubernetes node problems
- ⚡ SLURM service failures
- 📓 JupyterHub restart issues

## 🛠️ Setup Process

### Prerequisites
```bash
# Install required tools
sudo apt update
sudo apt install -y ansible ssh-client

# Generate SSH key (if not exists)
ssh-keygen -t rsa -b 4096 -f ~/.ssh/cluster_key -N ""
```

### Step-by-Step Automation

1. **Prepare your nodes** with Ubuntu 25.04
2. **Run discovery** to find available nodes:
   ```bash
   ./scripts/discover-nodes.sh
   ```

3. **Deploy the cluster**:
   ```bash
   ./scripts/quick-cluster-deploy.sh <master-ip> [worker-ips...]
   ```

4. **Verify deployment**:
   ```bash
   ./scripts/health-check.sh
   ```

## 🔧 Troubleshooting

### Common Issues and Automated Fixes

| Issue | Solution | Command |
|-------|----------|---------|
| Containerd not starting | Auto-fix config | `./scripts/node-repair.sh <ip>` |
| Kubernetes API unreachable | Restart services | `./scripts/node-repair.sh <ip>` |
| SLURM services down | Restart in order | `./scripts/node-repair.sh <ip>` |
| JupyterHub not accessible | Service restart | `./scripts/node-repair.sh <ip>` |

### Manual Troubleshooting
```bash
# Check specific node
ssh -i ~/.ssh/cluster_key ansible@<node-ip>

# View logs
journalctl -u kubelet -f
journalctl -u containerd -f
journalctl -u slurmctld -f
```

## 📊 Monitoring and Maintenance

### Regular Health Checks
```bash
# Run daily health check
./scripts/health-check.sh | tee health-$(date +%Y%m%d).log

# Monitor specific services
watch -n 30 './scripts/health-check.sh'
```

### Automated Recovery
```bash
# Set up cron job for automatic repairs
echo "0 */6 * * * /path/to/scripts/health-check.sh && /path/to/scripts/node-repair.sh \$(grep masters -A1 ansible/inventory.ini | tail -1 | awk '{print \$1}')" | crontab -
```

## 🎯 Access Your Cluster

After successful deployment:

- **JupyterHub**: `http://<master-ip>:8000`
- **Kubernetes API**: `https://<master-ip>:6443`
- **SSH Access**: `ssh -i ~/.ssh/cluster_key ansible@<master-ip>`
- **SLURM Commands**: `sinfo`, `squeue`, `sbatch`

## 🚀 Advanced Usage

### Scaling the Cluster
```bash
# Add new worker node
./scripts/auto-cluster-setup.sh --node 192.168.1.200

# Remove node (manual)
kubectl drain <node-name> --delete-emptydir-data --force --ignore-daemonsets
kubectl delete node <node-name>
```

### Custom Deployments
```bash
# Deploy only Kubernetes
./scripts/deploy-enhanced.sh --tags kubernetes

# Deploy only SLURM
./scripts/deploy-enhanced.sh --tags slurm

# Deploy to specific nodes
./scripts/deploy-enhanced.sh --target "192.168.5.57,192.168.4.157"
```

## 📝 Logging and Debugging

All automation scripts create detailed logs:
- **Setup logs**: `auto-setup-YYYYMMDD_HHMMSS.log`
- **Health logs**: Console output with timestamps
- **Repair logs**: Real-time status updates

Enable debug mode:
```bash
export ANSIBLE_DEBUG=1
./scripts/deploy-enhanced.sh
```

---

**🎉 Your cluster is now fully automated! The entire deployment process that previously took hours of manual work now completes in minutes with a single command.**
