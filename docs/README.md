# Heterogeneous Kubernetes SLURM Cluster

A comprehensive cluster deployment supporting both x86 and ARM architectures, including Raspberry Pi, Android devices, and NVIDIA Jetson platforms.

## 🚀 Quick Start

### Complete Cluster Deployment
```bash
# Clone and deploy full heterogeneous cluster
git clone <repository>
cd windsurf-project

# Full deployment (x86 + ARM + Android)
./scripts/deploy-complete-cluster.sh --full

# Deployment options
./scripts/deploy-complete-cluster.sh --x86-only      # Traditional cluster
./scripts/deploy-complete-cluster.sh --android-only  # Android integration only
./scripts/deploy-complete-cluster.sh --validate     # Check existing deployment
```

### Cluster Validation
```bash
# Quick health check
./scripts/validate-cluster-deployment.sh --quick

# Comprehensive validation
./scripts/validate-cluster-deployment.sh --full

# Fix common issues
./scripts/validate-cluster-deployment.sh --fix-issues
```

### Add ARM Devices
```bash
# Raspberry Pi
./scripts/add-arm-node.sh raspberry_pi 192.168.1.100 pi

# NVIDIA Jetson
./scripts/add-arm-node.sh jetson 192.168.1.102 nvidia

# Generic ARM device
./scripts/add-arm-node.sh generic 192.168.1.103 ubuntu
```

### Android Device Integration
```bash
# Build Android APK
./scripts/android-cluster-manager.sh build-apk

# Add Android devices (multiple methods)
./scripts/android-cluster-manager.sh add apk 192.168.1.101        # Custom APK
./scripts/android-cluster-manager.sh add termux 192.168.1.104 u0_a123  # Termux
./scripts/android-cluster-manager.sh add webview 192.168.1.105    # WebView

# Discover and manage
./scripts/android-cluster-manager.sh discover
./scripts/android-cluster-manager.sh list
./scripts/android-cluster-manager.sh status 192.168.1.101
```

## 🏗️ Architecture

- **Control Plane**: Kubernetes + SLURM controller on x86 master
- **Worker Nodes**: Mixed x86 and ARM64 compute nodes
- **Web Interface**: Real-time cluster management dashboard
- **JupyterHub**: Multi-user notebook environment
- **ARM Support**: Raspberry Pi, Android, Jetson, generic ARM boards
- **Android Integration**: Custom APK, Termux, WebView, ADB methods
- **Monitoring**: Automated health checks and performance tracking

## 📱 Android Integration Methods

| Method | Setup | Performance | Compatibility | Security |
|--------|--------|-------------|---------------|----------|
| **Custom APK** | Medium | High | Excellent | High |
| **Termux** | Easy | Medium | Good | Medium |
| **WebView** | Easy | Low-Medium | Excellent | High |
| **ADB** | Hard | High | Limited | Low |

**Recommended**: Custom APK for production, Termux for development

## 🛠️ Cluster Management

### Status Monitoring
```bash
# Kubernetes cluster
kubectl get nodes -o wide

# SLURM cluster
sinfo
squeue

# ARM and Android nodes
./scripts/arm-node-discovery.sh
./scripts/android-cluster-manager.sh list

# Health dashboard
./scripts/cluster-health-dashboard.sh status
```

### Job Submission
```bash
# Submit to ARM partition
sbatch --partition=arm_compute ./examples/slurm-jobs/arm-workloads.sh

# Submit to mobile devices
sbatch --partition=mobile_compute ./examples/slurm-jobs/mobile-workloads.sh

# Mixed architecture job
sbatch --partition=mixed_compute ./examples/slurm-jobs/heterogeneous-job.sh
```

### Web Access
- **Cluster Dashboard**: `http://<master-ip>/`
- **JupyterHub**: `http://<master-ip>:8000/`
- **Monitoring**: Real-time status and metrics

## 📚 Documentation

### Quick Links

### Core Documentation
- [🏗️ Architecture Overview](ARCHITECTURE.md) - System design and tech stack
- [🚀 Deployment Guide](DEPLOYMENT.md) - Complete deployment instructions
- [📱 Android Deployment](guides/android-deployment.md) - Android-specific setup
- [📚 API Reference](api/android-cluster.md) - REST API documentation

### Setup Guides
- [⚡ Quick Install](QUICK_INSTALL.md) - Fast cluster setup
- [🔧 ARM Platform Setup](guides/arm-platform-setup.md) - ARM node configuration
- [📱 Android Integration](guides/android-integration-methods.md) - Mobile device integration
- [🔐 User Management](guides/user-management.md) - Access control setup

### Operations
- [📊 Monitoring](guides/monitoring.md) - Cluster monitoring setup
- [🔒 SSL Setup](guides/ssl-setup.md) - Security configuration
- [💾 Backup & Restore](guides/backup-restore.md) - Data protection
- [🔧 Troubleshooting](guides/troubleshooting-network.md) - Problem resolution

### Scripts Reference
- `scripts/deploy-complete-cluster.sh` - Full cluster deployment
- `scripts/validate-cluster-deployment.sh` - Comprehensive validation
- `scripts/android-cluster-manager.sh` - Android device management
- `scripts/add-arm-node.sh` - ARM device integration
- `scripts/cluster-health-dashboard.sh` - Health monitoring

### Examples
- `examples/slurm-jobs/` - SLURM job examples for different architectures
- `android-cluster-node/` - Android APK source code
- `kubernetes/manifests/` - Kubernetes deployment manifests

## 🔧 Troubleshooting

### Common Issues
```bash
# Fix permissions and missing files
./scripts/validate-cluster-deployment.sh --fix-issues

# Check network connectivity
./scripts/validate-cluster-deployment.sh --network

# Test Android integration
./scripts/validate-cluster-deployment.sh --android

# Performance testing
./scripts/validate-cluster-deployment.sh --performance
```

### Support
- Check validation reports in project root
- Review deployment logs
- Use `--help` flag on any script for detailed usage
- Refer to troubleshooting sections in documentation guides

## Prerequisites

- Multiple old laptops (minimum 2 recommended)
- Ubuntu 22.04 LTS installed on each node
- SSH access between nodes
- GitHub account for documentation hosting
- Docker Hub account for container registry

## Directory Structure

```
├── ansible/
│   ├── group_vars/         # Group variables
│   ├── host_vars/          # Host-specific variables
│   ├── roles/
│   │   ├── common/         # Common system setup
│   │   ├── kubernetes/     # Kubernetes installation
│   │   ├── slurm/          # SLURM configuration
│   │   ├── jupyter/        # JupyterHub setup
│   │   ├── nginx/          # Reverse proxy
│   │   └── monitoring/     # Monitoring stack
│   ├── inventory.ini       # Inventory file
│   ├── site.yml           # Main playbook
│   └── requirements.yml    # Role dependencies
├── kubernetes/
│   ├── manifests/         # Kubernetes manifests
│   └── helm/              # Helm charts
├── docs/                  # Sphinx documentation
└── scripts/               # Utility scripts
```

## Getting Started

### Prerequisites Setup
1. Install Python 3.8+ and pip on your control machine
2. Create a virtual environment:
   ```bash
   python3 -m venv venv
   source venv/bin/activate
   ```
3. Install dependencies:
   ```bash
   pip install -r requirements.txt
   ansible-galaxy install -r ansible/requirements.yml
   ```

### Cluster Deployment
1. Clone this repository
2. Configure your inventory in `ansible/inventory.ini`
3. Update variables in `ansible/group_vars/all.yml`
4. Test connectivity: `ansible all -i ansible/inventory.ini -m ping`
5. Deploy the cluster: `ansible-playbook -i ansible/inventory.ini ansible/site.yml`

### Quick Start Script
Use the provided deployment script for automated setup:
```bash
./scripts/deploy.sh
```

## Features

This cluster provides:
- **Kubernetes**: Container orchestration with automatic scaling
- **SLURM**: High-performance computing workload manager
- **JupyterHub**: Multi-user interactive computing environment
- **Monitoring**: Prometheus and Grafana for cluster monitoring
- **Container Registry**: Private Docker registry for custom images
- **SSL/TLS**: Automated certificate management with Let's Encrypt
- **Backup/Restore**: Automated cluster backup and recovery
- **User Management**: Integrated user management across all services

## Available Scripts

- `./scripts/deploy.sh` - Automated cluster deployment
- `./scripts/validate-cluster.sh` - Cluster health validation
- `./scripts/get-credentials.sh` - Retrieve service credentials
- `./scripts/backup-cluster.sh` - Create cluster backups
- `./scripts/restore-cluster.sh` - Restore from backups
- `./scripts/manage-users.sh` - User management across services
- `./scripts/setup-ssl.sh` - SSL certificate setup with Let's Encrypt

## Sample SLURM Jobs

Test your cluster with the provided sample jobs:
- `examples/slurm-jobs/hello-world.sh` - Basic job submission test
- `examples/slurm-jobs/parallel-computation.sh` - Multi-node parallel processing
- `examples/slurm-jobs/gpu-computation.sh` - GPU-accelerated computing

## Documentation

Documentation is built using Sphinx and published to GitHub Pages. The documentation includes:
- Cluster setup and configuration
- User guides for SLURM and Jupyter
- API documentation
- Troubleshooting guides
