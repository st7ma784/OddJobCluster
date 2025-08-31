#!/bin/bash

# Cluster validation script
# This script validates the health and status of all cluster components

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_status() {
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

# Check if running from project root
if [ ! -f "ansible/inventory.ini" ]; then
    print_error "Please run this script from the project root directory"
    exit 1
fi

print_status "Starting cluster validation..."

# Test connectivity
print_status "Testing connectivity to all hosts..."
if ansible all -i ansible/inventory.ini -m ping > /dev/null 2>&1; then
    print_success "All hosts are reachable"
else
    print_error "Some hosts are not reachable"
    exit 1
fi

# Check Kubernetes cluster status
print_status "Checking Kubernetes cluster status..."
MASTER_HOST=$(ansible master -i ansible/inventory.ini --list-hosts | grep -v "hosts" | head -1 | xargs)

if ansible $MASTER_HOST -i ansible/inventory.ini -m shell -a "kubectl get nodes" > /dev/null 2>&1; then
    print_success "Kubernetes cluster is running"
    ansible $MASTER_HOST -i ansible/inventory.ini -m shell -a "kubectl get nodes"
else
    print_error "Kubernetes cluster is not accessible"
fi

# Check SLURM status
print_status "Checking SLURM status..."
if ansible $MASTER_HOST -i ansible/inventory.ini -m shell -a "sinfo" > /dev/null 2>&1; then
    print_success "SLURM is running"
    ansible $MASTER_HOST -i ansible/inventory.ini -m shell -a "sinfo"
else
    print_warning "SLURM may not be fully configured"
fi

# Check JupyterHub status
print_status "Checking JupyterHub status..."
if ansible $MASTER_HOST -i ansible/inventory.ini -m shell -a "kubectl get pods -n jupyter" > /dev/null 2>&1; then
    print_success "JupyterHub namespace exists"
    ansible $MASTER_HOST -i ansible/inventory.ini -m shell -a "kubectl get pods -n jupyter"
else
    print_warning "JupyterHub may not be deployed"
fi

# Check monitoring stack
print_status "Checking monitoring stack..."
if ansible $MASTER_HOST -i ansible/inventory.ini -m shell -a "kubectl get pods -n monitoring" > /dev/null 2>&1; then
    print_success "Monitoring stack is deployed"
    ansible $MASTER_HOST -i ansible/inventory.ini -m shell -a "kubectl get pods -n monitoring"
else
    print_warning "Monitoring stack may not be deployed"
fi

print_success "Cluster validation completed!"
