# Android Cluster Documentation

Welcome to the comprehensive documentation for the Android Cluster system - a revolutionary heterogeneous compute environment that seamlessly integrates Android devices with Kubernetes and SLURM clusters.

## What is Android Cluster?

Android Cluster transforms mobile devices into first-class compute nodes, creating a unified environment where smartphones and tablets work alongside traditional servers to process computational workloads.

### Key Features

- **🚀 Seamless Integration**: Android devices automatically register with existing Kubernetes and SLURM clusters
- **📱 Native Mobile App**: Purpose-built Android application for cluster participation
- **🔄 Real-time Management**: Web dashboard for monitoring and task submission
- **🔐 Enterprise Security**: MUNGE authentication and Kubernetes RBAC
- **⚡ High Performance**: Optimized for ARM64 mobile processors
- **🌐 REST API**: Programmatic access for custom integrations

### Architecture Overview

The system consists of several key components:

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Web Dashboard │    │ Android Devices │    │ Traditional HPC │
│                 │    │                 │    │                 │
│ • Task Submit   │◄──►│ • Native App    │◄──►│ • Kubernetes    │
│ • Monitoring    │    │ • Termux Env    │    │ • SLURM         │
│ • Status View   │    │ • Auto-register │    │ • x86/ARM Nodes │
└─────────────────┘    └─────────────────┘    └─────────────────┘
```

## 🚀 Quick Start

Get your cluster running in under 15 minutes:

### 1. Deploy the Android Task Server
```bash
# Deploy to Kubernetes
./scripts/deploy-android-task-server.sh
```

### 2. Install Android App
```bash
# Build and install on devices
cd android-cluster-node
./gradlew assembleDebug
adb install app/build/outputs/apk/debug/app-debug.apk
```

### 3. Configure Devices
1. Open the Android Cluster app
2. Set cluster URL: `ws://<your-cluster-ip>:8765`
3. Enable cluster service
4. Wait for automatic registration

### 4. Access Dashboard
Navigate to: `http://<cluster-ip>:8766`

### 5. Submit Tasks
```bash
# Via API
curl -X POST http://<cluster-ip>:8766/submit_task \
  -H "Content-Type: application/json" \
  -d '{"task_type": "prime_calculation", "data": {"start": 1, "end": 1000}}'
```

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
