# Kubernetes Cluster with SLURM and Jupyter

A complete, production-ready infrastructure automation solution for deploying high-performance computing clusters on repurposed hardware.

## 🚀 Quick Start

Get your cluster running in under 15 minutes:

```bash
curl -fsSL https://raw.githubusercontent.com/yourusername/kubernetes-slurm-cluster/main/scripts/quick-install.sh | bash
```

Or clone and deploy manually:

```bash
git clone https://github.com/yourusername/kubernetes-slurm-cluster.git
cd kubernetes-slurm-cluster
./scripts/deploy.sh
```

## 📚 Documentation

### Getting Started
- [Quick Install Guide](QUICK_INSTALL.md) - 15-minute setup
- [Deployment Guide](../DEPLOYMENT.md) - Complete deployment instructions
- [Rapid Node Deployment](RAPID_DEPLOYMENT.md) - Add nodes in 5 minutes

### User Guides
- [SLURM Job Submission](guides/slurm-jobs.md) - Submit and manage jobs
- [JupyterHub Usage](guides/jupyter.md) - Interactive computing
- [Monitoring](guides/monitoring.md) - Grafana dashboards and alerts

### Administration
- [User Management](guides/user-management.md) - Add and manage users
- [Backup and Restore](guides/backup-restore.md) - Data protection
- [SSL Configuration](guides/ssl-setup.md) - Security setup
- [Troubleshooting](guides/troubleshooting.md) - Common issues and solutions

### API Reference
- [SLURM REST API](api/slurm.md) - Job management API
- [Kubernetes API](api/kubernetes.md) - Container orchestration
- [Monitoring API](api/monitoring.md) - Metrics and alerts

## 🏗️ Architecture

### Core Components
- **Kubernetes**: Container orchestration with containerd runtime
- **SLURM**: High-performance computing workload manager
- **JupyterHub**: Multi-user interactive computing environment
- **Nginx**: Reverse proxy with SSL termination
- **Monitoring**: Prometheus and Grafana stack
- **Registry**: Private Docker registry

### Features
- ✅ One-command deployment
- ✅ Automated SSL/TLS with Let's Encrypt
- ✅ Integrated monitoring and alerting
- ✅ Backup and restore procedures
- ✅ Multi-user management
- ✅ GPU support
- ✅ Container registry
- ✅ Web-based interfaces

## 🎯 Service Access

After deployment, access your services:

- **Cluster Dashboard**: `https://<master-ip>/`
- **JupyterHub**: `https://<master-ip>/jupyter`
- **Grafana Monitoring**: `https://<master-ip>/grafana`
- **Docker Registry**: `https://<master-ip>/registry`

Default credentials: `admin/admin` (change after first login)

## 🛠️ Management Scripts

- `./scripts/deploy.sh` - Deploy complete cluster
- `./scripts/add-node.sh` - Add single node
- `./scripts/bulk-add-nodes.sh` - Add multiple nodes
- `./scripts/validate-cluster.sh` - Health validation
- `./scripts/backup-cluster.sh` - Create backups
- `./scripts/manage-users.sh` - User management
- `./scripts/setup-ssl.sh` - SSL configuration

## 📊 Sample Workloads

Test your cluster with included examples:

```bash
# Basic job
sbatch examples/slurm-jobs/hello-world.sh

# Parallel computation
sbatch examples/slurm-jobs/parallel-computation.sh

# GPU workload
sbatch examples/slurm-jobs/gpu-computation.sh
```

## 🔧 Requirements

### Minimum
- **Master**: 2 CPU, 4GB RAM, 50GB storage
- **Workers**: 2 CPU, 4GB RAM, 100GB storage
- **OS**: Ubuntu 22.04 LTS
- **Network**: Same subnet, SSH access

### Recommended
- **Master**: 4+ CPU, 8+ GB RAM, 100GB+ storage
- **Workers**: 4+ CPU, 8+ GB RAM, 200GB+ storage
- **Network**: Gigabit Ethernet
- **Storage**: SSD for better performance

## 🚨 Support

### Quick Help
- Run `./scripts/validate-cluster.sh` for health checks
- Check logs in `/var/log/` on each node
- Use `./scripts/get-credentials.sh` for service access

### Community
- [GitHub Issues](https://github.com/yourusername/kubernetes-slurm-cluster/issues)
- [Discussions](https://github.com/yourusername/kubernetes-slurm-cluster/discussions)
- [Wiki](https://github.com/yourusername/kubernetes-slurm-cluster/wiki)

## 📈 Scaling

### Add Nodes
```bash
# Single node
./scripts/add-node.sh 192.168.1.13 worker3

# Multiple nodes
echo "192.168.1.13 worker3" > new-nodes.txt
echo "192.168.1.14 worker4" >> new-nodes.txt
./scripts/bulk-add-nodes.sh new-nodes.txt
```

### Resource Management
- Monitor usage via Grafana dashboards
- Scale workloads with SLURM partitions
- Use Kubernetes HPA for auto-scaling

## 🔐 Security

### Built-in Security
- SSL/TLS encryption for all services
- Role-based access control
- Network policies and firewalls
- Secret management

### Hardening
```bash
# Change default passwords
./scripts/manage-users.sh reset-password admin

# Set up proper SSL
./scripts/setup-ssl.sh your-domain.com admin@your-domain.com

# Configure firewall
sudo ufw enable
sudo ufw allow from your-network/24
```

## 🎓 Learning Resources

### Tutorials
- [Your First SLURM Job](tutorials/first-slurm-job.md)
- [Jupyter Notebook Basics](tutorials/jupyter-basics.md)
- [Kubernetes Fundamentals](tutorials/k8s-basics.md)
- [Monitoring Setup](tutorials/monitoring.md)

### Examples
- [Data Science Workflows](examples/data-science/)
- [HPC Applications](examples/hpc/)
- [Container Builds](examples/containers/)

## 🤝 Contributing

We welcome contributions! See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

### Development Setup
```bash
git clone https://github.com/yourusername/kubernetes-slurm-cluster.git
cd kubernetes-slurm-cluster
python3 -m venv venv
source venv/bin/activate
pip install -r requirements-dev.txt
```

## 📄 License

This project is licensed under the MIT License - see [LICENSE](LICENSE) file for details.

---

**🎉 Ready to build your HPC cluster?** Start with the [Quick Install Guide](QUICK_INSTALL.md)!
