#!/bin/bash

# Enhanced Deployment script for Kubernetes SLURM Jupyter cluster
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
SSH_KEY="$HOME/.ssh/cluster_key"

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() {
    echo -e "${GREEN}[$(date +'%H:%M:%S')]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
    exit 1
}

warn() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

# Check prerequisites
check_prerequisites() {
    log "Checking prerequisites..."
    
    if ! command -v ansible-playbook &> /dev/null; then
        error "Ansible is not installed. Please install it first."
    fi
    
    if [[ ! -f "$PROJECT_ROOT/ansible/inventory.ini" ]]; then
        error "Inventory file not found: $PROJECT_ROOT/ansible/inventory.ini"
    fi
    
    if [[ ! -f "$SSH_KEY" ]]; then
        warn "SSH key not found at $SSH_KEY"
        warn "Run: ssh-keygen -t rsa -b 4096 -f $SSH_KEY -N ''"
    fi
}

# Deploy with options
deploy() {
    local target="${1:-all}"
    local tags="${2:-all}"
    
    log "Starting deployment to target: $target, tags: $tags"
    
    cd "$PROJECT_ROOT/ansible"
    
    # Choose authentication method
    if [[ -f "$SSH_KEY" ]]; then
        log "Using SSH key authentication"
        if [[ "$target" == "all" ]]; then
            ansible-playbook -i inventory.ini site.yml ${tags:+--tags $tags}
        else
            ansible-playbook -i inventory.ini --limit "$target" site.yml ${tags:+--tags $tags}
        fi
    else
        log "Using password authentication"
        if [[ "$target" == "all" ]]; then
            ansible-playbook -i inventory.ini site.yml --ask-pass ${tags:+--tags $tags}
        else
            ansible-playbook -i inventory.ini --limit "$target" site.yml --ask-pass ${tags:+--tags $tags}
        fi
    fi
    
    cd "$PROJECT_ROOT"
}

# Post-deployment fixes
post_deploy_fixes() {
    log "Running post-deployment fixes..."
    
    # Get master nodes from inventory
    masters=$(grep -A 10 '\[masters\]' "$PROJECT_ROOT/ansible/inventory.ini" | grep -E '^[0-9]+\.' | awk '{print $1}')
    
    for master in $masters; do
        log "Applying fixes to master: $master"
        
        if ssh -i "$SSH_KEY" -o ConnectTimeout=5 "ansible@$master" "echo 'Connected'" 2>/dev/null; then
            # Fix containerd and restart services
            ssh -i "$SSH_KEY" "ansible@$master" << 'EOF'
                # Fix containerd config
                sudo containerd config default | sudo tee /etc/containerd/config.toml
                sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml
                sudo systemctl restart containerd
                sleep 5
                
                # Restart kubelet
                sudo systemctl restart kubelet
                
                # Wait for services to stabilize
                sleep 10
EOF
            log "Fixes applied to $master"
        else
            warn "Cannot connect to $master, skipping fixes"
        fi
    done
}

# Verify deployment
verify_deployment() {
    log "Verifying deployment..."
    if [[ -f "$SCRIPT_DIR/health-check.sh" ]]; then
        "$SCRIPT_DIR/health-check.sh"
    else
        warn "Health check script not found, skipping verification"
    fi
}

# Main function
main() {
    echo "🚀 Enhanced Kubernetes SLURM Jupyter Cluster Deployment"
    
    # Parse arguments
    TARGET="all"
    TAGS=""
    SKIP_FIXES=false
    SKIP_VERIFY=false
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            --target)
                TARGET="$2"
                shift 2
                ;;
            --tags)
                TAGS="$2"
                shift 2
                ;;
            --skip-fixes)
                SKIP_FIXES=true
                shift
                ;;
            --skip-verify)
                SKIP_VERIFY=true
                shift
                ;;
            --help)
                echo "Usage: $0 [options]"
                echo "Options:"
                echo "  --target HOST    Deploy to specific host"
                echo "  --tags TAGS      Run specific Ansible tags"
                echo "  --skip-fixes     Skip post-deployment fixes"
                echo "  --skip-verify    Skip deployment verification"
                exit 0
                ;;
            *)
                error "Unknown option: $1"
                ;;
        esac
    done
    
    # Run deployment steps
    check_prerequisites
    deploy "$TARGET" "$TAGS"
    
    if [[ "$SKIP_FIXES" != true ]]; then
        post_deploy_fixes
    fi
    
    if [[ "$SKIP_VERIFY" != true ]]; then
        verify_deployment
    fi
    
    log "Deployment completed successfully!"
    log "Access your cluster:"
    
    # Show access information
    masters=$(grep -A 10 '\[masters\]' "$PROJECT_ROOT/ansible/inventory.ini" | grep -E '^[0-9]+\.' | awk '{print $1}' | head -1)
    if [[ -n "$masters" ]]; then
        log "  - JupyterHub: http://$masters:8000"
        log "  - Kubernetes API: https://$masters:6443"
        log "  - SSH: ssh -i $SSH_KEY ansible@$masters"
    fi
}

main "$@"
