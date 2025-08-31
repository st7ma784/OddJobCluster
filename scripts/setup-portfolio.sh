#!/bin/bash

# Portfolio System Setup Script
# Sets up the automated portfolio system on the cluster

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
SSH_KEY="$HOME/.ssh/cluster_key"
CLUSTER_HOST="192.168.5.57"

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

log() {
    echo -e "${GREEN}[$(date +'%H:%M:%S')]${NC} $1"
}

info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Install Python dependencies
install_dependencies() {
    log "Installing Python dependencies..."
    
    if command -v pip3 &> /dev/null; then
        pip3 install -r "$SCRIPT_DIR/portfolio/requirements.txt"
    else
        warn "pip3 not found, please install dependencies manually"
        cat "$SCRIPT_DIR/portfolio/requirements.txt"
    fi
}

# Test portfolio system
test_portfolio() {
    log "Testing portfolio system..."
    
    cd "$SCRIPT_DIR/portfolio"
    python3 test-portfolio.py
}

# Setup GitHub secrets (instructions)
show_github_setup() {
    log "GitHub Secrets Setup Required:"
    echo ""
    echo "Please add the following secrets to your GitHub repository:"
    echo ""
    echo "1. CLUSTER_HOST: $CLUSTER_HOST"
    echo "2. CLUSTER_SSH_KEY: (contents of $SSH_KEY)"
    echo "3. GITHUB_TOKEN: (your GitHub personal access token)"
    echo ""
    echo "To add secrets:"
    echo "1. Go to your repository on GitHub"
    echo "2. Settings → Secrets and variables → Actions"
    echo "3. Click 'New repository secret'"
    echo "4. Add each secret with the exact names above"
    echo ""
}

# Deploy portfolio namespace
setup_cluster_namespace() {
    log "Setting up portfolio namespace on cluster..."
    
    ssh -i "$SSH_KEY" "ansible@$CLUSTER_HOST" << 'EOF'
        # Create portfolio namespace
        kubectl create namespace portfolio --dry-run=client -o yaml | kubectl apply -f -
        
        # Label namespace
        kubectl label namespace portfolio app=portfolio --overwrite
        
        echo "Portfolio namespace ready"
EOF
}

# Test cluster connectivity
test_cluster() {
    log "Testing cluster connectivity..."
    
    if ssh -i "$SSH_KEY" -o ConnectTimeout=5 "ansible@$CLUSTER_HOST" "kubectl get nodes" 2>/dev/null; then
        log "✅ Cluster connectivity verified"
        return 0
    else
        warn "❌ Cannot connect to cluster"
        return 1
    fi
}

# Manual portfolio deployment test
test_manual_deployment() {
    log "Testing manual portfolio deployment..."
    
    # Create test output directory
    mkdir -p /tmp/portfolio-test
    
    # Create mock portfolio data
    cat > /tmp/portfolio-test/portfolio.json << 'EOF'
{
  "projects": [
    {
      "name": "test-project",
      "repo_url": "https://github.com/user/test-project",
      "description": "Test project for portfolio system",
      "has_readme": true,
      "has_github_pages": false,
      "has_docker_compose": true,
      "has_web_interface": true,
      "docker_services": ["web"],
      "exposed_ports": [8080],
      "readme_quality": "verbose",
      "validation_flags": []
    }
  ],
  "total_projects": 1,
  "projects_with_docker": 1,
  "projects_with_web_interface": 1,
  "flagged_projects": 0
}
EOF
    
    # Test deployment script
    if test_cluster; then
        log "Running deployment test..."
        python3 "$SCRIPT_DIR/portfolio/deploy-portfolio.py" \
            --cluster-host "$CLUSTER_HOST" \
            --ssh-key "$SSH_KEY" \
            --portfolio-dir "/tmp/portfolio-test"
        
        log "✅ Manual deployment test completed"
        log "Portfolio should be available at: http://$CLUSTER_HOST:30080"
    else
        warn "Skipping deployment test - cluster not accessible"
    fi
}

# Main setup function
main() {
    echo "🚀 Portfolio System Setup"
    echo "========================="
    
    # Check prerequisites
    if [[ ! -f "$SSH_KEY" ]]; then
        warn "SSH key not found: $SSH_KEY"
        warn "Please run cluster setup first"
        exit 1
    fi
    
    # Install dependencies
    install_dependencies
    
    # Test system
    test_portfolio
    
    # Setup cluster
    if test_cluster; then
        setup_cluster_namespace
        
        # Ask if user wants to test deployment
        echo ""
        read -p "Test manual portfolio deployment? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            test_manual_deployment
        fi
    fi
    
    # Show GitHub setup instructions
    echo ""
    show_github_setup
    
    log "Portfolio system setup completed!"
    log "Next steps:"
    log "1. Add GitHub secrets as shown above"
    log "2. Push changes to trigger GitHub Actions workflow"
    log "3. Monitor workflow execution in GitHub Actions tab"
    log "4. Access portfolio at: http://$CLUSTER_HOST:30080"
}

main "$@"
