#!/bin/bash

# Kubernetes Cluster with SLURM and Jupyter - Deployment Script
# This script automates the deployment of the entire cluster

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
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
if [ ! -f "ansible/site.yml" ]; then
    print_error "Please run this script from the project root directory"
    exit 1
fi

print_status "Starting Kubernetes cluster deployment..."

# Check prerequisites
print_status "Checking prerequisites..."

if ! command -v python3 &> /dev/null; then
    print_error "Python 3 is required but not installed"
    exit 1
fi

if ! command -v pip &> /dev/null; then
    print_error "pip is required but not installed"
    exit 1
fi

# Create virtual environment if it doesn't exist
if [ ! -d "venv" ]; then
    print_status "Creating Python virtual environment..."
    python3 -m venv venv
fi

# Activate virtual environment
print_status "Activating virtual environment..."
source venv/bin/activate

# Install Python dependencies
print_status "Installing Python dependencies..."
pip install -r requirements.txt

# Install Ansible collections
print_status "Installing Ansible collections..."
ansible-galaxy install -r ansible/requirements.yml

# Check if inventory file exists
if [ ! -f "ansible/inventory.ini" ]; then
    print_error "Inventory file ansible/inventory.ini not found"
    print_status "Please create and configure your inventory file"
    exit 1
fi

# Test connectivity
print_status "Testing connectivity to all hosts..."
if ansible all -i ansible/inventory.ini -m ping; then
    print_success "All hosts are reachable"
else
    print_error "Some hosts are not reachable. Please check your inventory and SSH configuration"
    exit 1
fi

# Run the playbook
print_status "Deploying the cluster (this may take 15-30 minutes)..."
if ansible-playbook -i ansible/inventory.ini ansible/site.yml; then
    print_success "Cluster deployment completed successfully!"
    
    # Get master node IP
    MASTER_IP=$(ansible master -i ansible/inventory.ini --list-hosts | grep -v "hosts" | xargs | cut -d' ' -f1)
    
    print_status "Cluster services are available at:"
    echo "  - JupyterHub: https://$MASTER_IP/jupyter"
    echo "  - SLURM Dashboard: https://$MASTER_IP/slurm"
    echo "  - Kubernetes Dashboard: https://$MASTER_IP/kubernetes"
    echo "  - Grafana Monitoring: https://$MASTER_IP/grafana"
    
    print_status "To get service credentials, run:"
    echo "  ./scripts/get-credentials.sh"
    
else
    print_error "Cluster deployment failed"
    exit 1
fi

print_success "Deployment script completed!"
