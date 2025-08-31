# Kubernetes Cluster with SLURM and Jupyter

This project sets up a Kubernetes cluster on old laptops with:
- SLURM workload manager for job queuing
- JupyterHub for interactive computing
- Sphinx documentation with GitHub Pages
- Automated Docker container deployment
- Web interface for service discovery

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
