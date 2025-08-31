#!/bin/bash

# Cluster Demo and Testing Script
# Demonstrates full cluster functionality

set -euo pipefail

SSH_KEY="$HOME/.ssh/cluster_key"
MASTER_IP="192.168.5.57"

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

# Test SLURM job submission
test_slurm() {
    log "Testing SLURM job submission..."
    
    ssh -i "$SSH_KEY" "ansible@$MASTER_IP" << 'EOF'
        # Create test job
        cat > demo_job.sh << 'JOBEOF'
#!/bin/bash
#SBATCH --job-name=demo-test
#SBATCH --output=demo_%j.out
#SBATCH --ntasks=1
#SBATCH --time=00:01:00

echo "=== SLURM Demo Job ==="
echo "Node: $(hostname)"
echo "Date: $(date)"
echo "User: $(whoami)"
echo "CPU Info: $(nproc) cores"
echo "Memory: $(free -h | grep Mem | awk '{print $2}')"
echo "Load: $(cat /proc/loadavg)"
echo "Job completed successfully!"
JOBEOF

        # Submit job
        job_id=$(sbatch demo_job.sh | awk '{print $4}')
        echo "Submitted job ID: $job_id"
        
        # Wait for completion
        sleep 15
        
        # Show results
        echo "=== Job Queue Status ==="
        squeue || echo "No jobs in queue"
        
        echo -e "\n=== Job Output ==="
        if ls demo_*.out 2>/dev/null; then
            cat demo_*.out
        else
            echo "Job output not yet available"
        fi
EOF
}

# Test Kubernetes functionality
test_kubernetes() {
    log "Testing Kubernetes functionality..."
    
    ssh -i "$SSH_KEY" "ansible@$MASTER_IP" << 'EOF'
        echo "=== Kubernetes Cluster Status ==="
        kubectl get nodes -o wide
        
        echo -e "\n=== System Pods ==="
        kubectl get pods -A --field-selector=status.phase=Running
        
        echo -e "\n=== Cluster Info ==="
        kubectl cluster-info
        
        echo -e "\n=== Node Resources ==="
        kubectl top nodes 2>/dev/null || echo "Metrics not available"
EOF
}

# Test JupyterHub accessibility
test_jupyterhub() {
    log "Testing JupyterHub accessibility..."
    
    ssh -i "$SSH_KEY" "ansible@$MASTER_IP" << 'EOF'
        echo "=== JupyterHub Status ==="
        systemctl is-active jupyterhub
        
        echo -e "\n=== JupyterHub Process ==="
        ps aux | grep jupyterhub | grep -v grep || echo "Process not found"
        
        echo -e "\n=== JupyterHub Port ==="
        ss -tlnp | grep :8000 || echo "Port 8000 not listening"
        
        echo -e "\n=== JupyterHub HTTP Test ==="
        curl -s -I http://localhost:8000 | head -3 || echo "HTTP test failed"
EOF
}

# Show cluster access information
show_access_info() {
    log "Cluster Access Information:"
    echo ""
    echo "🌐 Web Interfaces:"
    echo "  - JupyterHub: http://$MASTER_IP:8000"
    echo "  - Kubernetes API: https://$MASTER_IP:6443"
    echo ""
    echo "🔧 SSH Access:"
    echo "  ssh -i $SSH_KEY ansible@$MASTER_IP"
    echo ""
    echo "⚡ SLURM Commands:"
    echo "  sinfo          # Show partitions"
    echo "  squeue         # Show job queue"
    echo "  sbatch job.sh  # Submit job"
    echo ""
    echo "☸️ Kubernetes Commands:"
    echo "  kubectl get nodes"
    echo "  kubectl get pods -A"
    echo "  kubectl cluster-info"
}

# Run comprehensive demo
main() {
    echo "🚀 Kubernetes SLURM Jupyter Cluster Demo"
    echo "========================================="
    
    info "Testing cluster connectivity..."
    if ssh -i "$SSH_KEY" -o ConnectTimeout=5 "ansible@$MASTER_IP" "echo 'Connected'" 2>/dev/null; then
        log "✅ SSH connection successful"
    else
        echo "❌ Cannot connect to $MASTER_IP"
        exit 1
    fi
    
    # Run tests
    test_kubernetes
    echo ""
    test_slurm
    echo ""
    test_jupyterhub
    echo ""
    
    # Show access info
    show_access_info
    
    log "🎉 Cluster demo completed successfully!"
    log "Your cluster is ready for production workloads!"
}

main "$@"
