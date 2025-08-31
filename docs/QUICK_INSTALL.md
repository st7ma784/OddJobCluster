# Quick Install Guide

Get your Kubernetes cluster with SLURM and Jupyter running in under 15 minutes!

## 🚀 One-Line Install

```bash
curl -fsSL https://raw.githubusercontent.com/yourusername/kubernetes-slurm-cluster/main/scripts/quick-install.sh | bash
```

## 📋 Prerequisites Checklist

- [ ] 2+ Ubuntu 22.04 LTS machines
- [ ] 4GB+ RAM per machine
- [ ] Network connectivity between machines
- [ ] SSH access to all machines
- [ ] Internet access on all machines

## ⚡ 5-Minute Setup

### Step 1: Clone and Configure (2 minutes)

```bash
# Clone repository
git clone https://github.com/yourusername/kubernetes-slurm-cluster.git
cd kubernetes-slurm-cluster

# Quick configuration
./scripts/quick-config.sh
```

### Step 2: Deploy Cluster (3 minutes)

```bash
# Automated deployment
./scripts/deploy.sh
```

That's it! Your cluster is ready.

## 🎯 Access Your Services

After deployment, access your services at:

- **Cluster Dashboard**: `https://<master-ip>/`
- **JupyterHub**: `https://<master-ip>/jupyter` (admin/admin)
- **Grafana**: `https://<master-ip>/grafana` (admin/admin)
- **Docker Registry**: `https://<master-ip>/registry`

## 🔧 Manual Quick Setup

If you prefer manual control:

### 1. Environment Setup (1 minute)

```bash
# Install dependencies
sudo apt update && sudo apt install -y python3 python3-pip python3-venv git
python3 -m venv venv && source venv/bin/activate
pip install -r requirements.txt
ansible-galaxy install -r ansible/requirements.yml
```

### 2. Configure Inventory (1 minute)

```bash
# Copy and edit inventory
cp ansible/inventory.ini.example ansible/inventory.ini
nano ansible/inventory.ini  # Update IPs
```

### 3. Deploy (3 minutes)

```bash
# Test connectivity
ansible all -i ansible/inventory.ini -m ping

# Deploy cluster
ansible-playbook -i ansible/inventory.ini ansible/site.yml
```

## 🛠️ Quick Configuration Script

The `quick-config.sh` script automates initial setup:

```bash
#!/bin/bash
# Interactive configuration
echo "=== Quick Cluster Configuration ==="

# Get master node IP
read -p "Master node IP: " MASTER_IP
read -p "Master node hostname [master]: " MASTER_HOST
MASTER_HOST=${MASTER_HOST:-master}

# Get worker nodes
echo "Enter worker nodes (press Enter when done):"
WORKERS=()
while true; do
    read -p "Worker IP (or Enter to finish): " WORKER_IP
    [ -z "$WORKER_IP" ] && break
    read -p "Worker hostname: " WORKER_HOST
    WORKERS+=("$WORKER_HOST ansible_host=$WORKER_IP")
done

# Generate inventory
cat > ansible/inventory.ini << EOF
[all:vars]
ansible_python_interpreter=/usr/bin/python3
ansible_user=ubuntu
ansible_ssh_private_key_file=~/.ssh/id_rsa

[master]
$MASTER_HOST ansible_host=$MASTER_IP

[workers]
$(printf '%s\n' "${WORKERS[@]}")

[kube_control_plane:children]
master

[kube_node:children]
workers

[slurm_control:children]
master

[slurm_node:children]
workers

[jupyter:children]
master
EOF

echo "Configuration saved to ansible/inventory.ini"
```

## 🔍 Verification Commands

After deployment, verify everything works:

```bash
# Cluster status
./scripts/validate-cluster.sh

# Service credentials
./scripts/get-credentials.sh

# Test SLURM job
sbatch examples/slurm-jobs/hello-world.sh
squeue
```

## 🚨 Troubleshooting Quick Fixes

### Connection Issues
```bash
# Test SSH connectivity
ssh ubuntu@<node-ip>

# Check firewall
sudo ufw status
```

### Deployment Failures
```bash
# Check Ansible connectivity
ansible all -i ansible/inventory.ini -m ping

# View detailed logs
ansible-playbook -i ansible/inventory.ini ansible/site.yml -vvv
```

### Service Not Starting
```bash
# Check service status
systemctl status kubelet
systemctl status docker
systemctl status nginx
```

## 🎛️ Quick Customization

### Change Default Passwords
```bash
# Edit group variables
nano ansible/group_vars/all.yml

# Update these values:
mysql_root_password: "your-secure-password"
slurmdbd_password: "your-secure-password"
```

### Add More Workers
```bash
# Use the rapid deployment script
./scripts/add-node.sh <new-ip> <new-hostname>
```

### Enable SSL
```bash
# Set up Let's Encrypt SSL
./scripts/setup-ssl.sh your-domain.com admin@your-domain.com
```

## 📊 Resource Requirements

### Minimum Configuration
- **Master**: 2 CPU, 4GB RAM, 50GB storage
- **Worker**: 2 CPU, 4GB RAM, 100GB storage

### Recommended Configuration
- **Master**: 4 CPU, 8GB RAM, 100GB storage
- **Worker**: 4+ CPU, 8+ GB RAM, 200GB+ storage

### Network Requirements
- All nodes on same subnet
- Ports 22 (SSH), 80/443 (HTTP/HTTPS), 6443 (K8s API)
- Internal cluster communication on various ports

## 🔄 Quick Updates

### Update Cluster
```bash
git pull origin main
./scripts/deploy.sh
```

### Add New Features
```bash
# Enable monitoring
ansible-playbook -i ansible/inventory.ini ansible/site.yml --tags=monitoring

# Deploy container registry
kubectl apply -f kubernetes/manifests/docker-registry.yaml
```

## 📱 Mobile-Friendly Access

Access your cluster from mobile devices:
- JupyterHub works great on tablets
- Grafana dashboards are responsive
- SSH access via mobile apps (Termius, JuiceSSH)

## 🎓 Learning Resources

After your cluster is running:
- **SLURM Tutorial**: Submit your first job
- **Kubernetes Basics**: Explore pods and services  
- **Jupyter Notebooks**: Start with data science examples
- **Monitoring**: Set up custom alerts in Grafana

## 🔐 Security Quick Setup

### Basic Hardening
```bash
# Change default passwords
./scripts/manage-users.sh reset-password admin

# Set up firewall
sudo ufw enable
sudo ufw allow from <your-network>/24
```

### SSL Certificates
```bash
# Automated SSL setup
./scripts/setup-ssl.sh cluster.yourdomain.com admin@yourdomain.com
```

## 🎯 Next Steps

1. **Test the cluster** with sample jobs
2. **Add more nodes** as needed
3. **Set up SSL** for production use
4. **Configure backups** for data safety
5. **Monitor usage** and optimize resources

## 💡 Pro Tips

- Use `tmux` for long-running deployments
- Keep inventory file in version control
- Regular backups with `./scripts/backup-cluster.sh`
- Monitor resource usage via Grafana
- Use node labels for workload placement

## 🆘 Getting Help

- **Documentation**: Full guides in `/docs` folder
- **Validation**: Run `./scripts/validate-cluster.sh`
- **Logs**: Check `/var/log/` on each node
- **Community**: Open GitHub issues for support

---

**🎉 Congratulations!** You now have a production-ready HPC cluster running Kubernetes, SLURM, and Jupyter!
