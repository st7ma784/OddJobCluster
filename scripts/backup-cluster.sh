#!/bin/bash

# Cluster backup script
# This script creates backups of critical cluster components

set -e

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Configuration
BACKUP_DIR="/opt/cluster-backups/$(date +%Y%m%d_%H%M%S)"
MASTER_HOST=$(ansible master -i ansible/inventory.ini --list-hosts | grep -v "hosts" | head -1 | xargs)

print_info "Starting cluster backup to $BACKUP_DIR"

# Create backup directory
ansible $MASTER_HOST -i ansible/inventory.ini -m file -a "path=$BACKUP_DIR state=directory mode=0755" --become

# Backup etcd
print_info "Backing up etcd..."
ansible $MASTER_HOST -i ansible/inventory.ini -m shell -a "
ETCDCTL_API=3 etcdctl snapshot save $BACKUP_DIR/etcd-snapshot.db \
--endpoints=https://127.0.0.1:2379 \
--cacert=/etc/kubernetes/pki/etcd/ca.crt \
--cert=/etc/kubernetes/pki/etcd/healthcheck-client.crt \
--key=/etc/kubernetes/pki/etcd/healthcheck-client.key
" --become

# Backup Kubernetes certificates
print_info "Backing up Kubernetes certificates..."
ansible $MASTER_HOST -i ansible/inventory.ini -m shell -a "
tar -czf $BACKUP_DIR/k8s-certs.tar.gz -C /etc/kubernetes pki/
" --become

# Backup SLURM configuration
print_info "Backing up SLURM configuration..."
ansible $MASTER_HOST -i ansible/inventory.ini -m shell -a "
tar -czf $BACKUP_DIR/slurm-config.tar.gz -C /etc slurm-llnl/
" --become

# Backup munge key
ansible $MASTER_HOST -i ansible/inventory.ini -m shell -a "
cp /etc/munge/munge.key $BACKUP_DIR/munge.key
" --become

# Backup JupyterHub configuration
print_info "Backing up JupyterHub configuration..."
ansible $MASTER_HOST -i ansible/inventory.ini -m shell -a "
kubectl get configmap -n jupyter -o yaml > $BACKUP_DIR/jupyterhub-config.yaml
kubectl get secret -n jupyter -o yaml > $BACKUP_DIR/jupyterhub-secrets.yaml
" --become

# Create backup manifest
ansible $MASTER_HOST -i ansible/inventory.ini -m shell -a "
cat > $BACKUP_DIR/backup-manifest.txt << EOF
Cluster Backup Created: $(date)
Kubernetes Version: $(kubectl version --short --client)
SLURM Version: $(sinfo --version)
Backup Contents:
- etcd-snapshot.db: etcd database snapshot
- k8s-certs.tar.gz: Kubernetes PKI certificates
- slurm-config.tar.gz: SLURM configuration files
- munge.key: Munge authentication key
- jupyterhub-config.yaml: JupyterHub configuration
- jupyterhub-secrets.yaml: JupyterHub secrets
EOF
" --become

print_success "Backup completed successfully at $BACKUP_DIR"
print_info "To restore from this backup, use: ./scripts/restore-cluster.sh $BACKUP_DIR"
