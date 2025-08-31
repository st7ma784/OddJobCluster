#!/bin/bash

# Get service credentials script
# This script retrieves credentials for various cluster services

set -e

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_info "Retrieving service credentials..."

echo "=========================================="
echo "JUPYTERHUB CREDENTIALS"
echo "=========================================="
echo "URL: https://$(ansible master -i ansible/inventory.ini --list-hosts | grep -v hosts | head -1)/jupyter"
echo "Default Admin User: admin"
echo "Admin Password: admin (using dummy auth)"
echo ""

echo "=========================================="
echo "KUBERNETES DASHBOARD"
echo "=========================================="
echo "URL: https://$(ansible master -i ansible/inventory.ini --list-hosts | grep -v hosts | head -1)/kubernetes"
print_info "To get admin token, run on master node:"
echo "kubectl -n kubernetes-dashboard create token admin-user"
echo ""

echo "=========================================="
echo "GRAFANA MONITORING"
echo "=========================================="
echo "URL: https://$(ansible master -i ansible/inventory.ini --list-hosts | grep -v hosts | head -1)/grafana"
echo "Username: admin"
echo "Password: admin"
echo ""

echo "=========================================="
echo "SLURM CLUSTER INFO"
echo "=========================================="
print_info "To check SLURM status, run on master node:"
echo "sinfo"
echo "squeue"
echo "sacctmgr show cluster"
echo ""

print_success "Credentials retrieved successfully!"
