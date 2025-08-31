#!/bin/bash

# Cluster restore script
# This script restores cluster components from a backup

set -e

# Colors for output
RED='\033[0;31m'
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

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check arguments
if [ $# -ne 1 ]; then
    print_error "Usage: $0 <backup_directory>"
    exit 1
fi

BACKUP_DIR=$1
MASTER_HOST=$(ansible master -i ansible/inventory.ini --list-hosts | grep -v "hosts" | head -1 | xargs)

# Verify backup directory exists
if ! ansible $MASTER_HOST -i ansible/inventory.ini -m stat -a "path=$BACKUP_DIR" --become | grep -q "exists.*true"; then
    print_error "Backup directory $BACKUP_DIR does not exist on master node"
    exit 1
fi

print_warning "This will restore cluster configuration from backup: $BACKUP_DIR"
read -p "Are you sure you want to continue? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    print_info "Restore cancelled"
    exit 0
fi

print_info "Starting cluster restore from $BACKUP_DIR"

# Stop cluster services
print_info "Stopping cluster services..."
ansible all -i ansible/inventory.ini -m systemd -a "name=kubelet state=stopped" --become || true
ansible all -i ansible/inventory.ini -m systemd -a "name=containerd state=stopped" --become || true

# Restore etcd
print_info "Restoring etcd..."
ansible $MASTER_HOST -i ansible/inventory.ini -m shell -a "
systemctl stop etcd
rm -rf /var/lib/etcd.bak
mv /var/lib/etcd /var/lib/etcd.bak || true
ETCDCTL_API=3 etcdctl snapshot restore $BACKUP_DIR/etcd-snapshot.db \
--data-dir=/var/lib/etcd \
--initial-cluster-token=etcd-cluster-1 \
--initial-advertise-peer-urls=https://$(hostname -i):2380
chown -R etcd:etcd /var/lib/etcd
" --become

# Restore Kubernetes certificates
print_info "Restoring Kubernetes certificates..."
ansible $MASTER_HOST -i ansible/inventory.ini -m shell -a "
cd /etc/kubernetes
tar -xzf $BACKUP_DIR/k8s-certs.tar.gz
" --become

# Restore SLURM configuration
print_info "Restoring SLURM configuration..."
ansible all -i ansible/inventory.ini -m shell -a "
cd /etc
tar -xzf $BACKUP_DIR/slurm-config.tar.gz
" --become

# Restore munge key
print_info "Restoring munge key..."
ansible all -i ansible/inventory.ini -m copy -a "
src=$BACKUP_DIR/munge.key
dest=/etc/munge/munge.key
owner=munge
group=munge
mode=0400
remote_src=yes
" --become

# Start services
print_info "Starting cluster services..."
ansible all -i ansible/inventory.ini -m systemd -a "name=containerd state=started enabled=yes" --become
ansible all -i ansible/inventory.ini -m systemd -a "name=kubelet state=started enabled=yes" --become
ansible all -i ansible/inventory.ini -m systemd -a "name=munge state=started enabled=yes" --become

# Wait for Kubernetes to be ready
print_info "Waiting for Kubernetes to be ready..."
sleep 30

# Restore JupyterHub configuration
print_info "Restoring JupyterHub configuration..."
ansible $MASTER_HOST -i ansible/inventory.ini -m shell -a "
kubectl apply -f $BACKUP_DIR/jupyterhub-config.yaml
kubectl apply -f $BACKUP_DIR/jupyterhub-secrets.yaml
" --become

print_success "Cluster restore completed successfully!"
print_info "Please run ./scripts/validate-cluster.sh to verify the restore"
