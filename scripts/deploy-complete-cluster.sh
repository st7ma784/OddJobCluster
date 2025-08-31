#!/bin/bash

# Complete Cluster Deployment Script
# Deploys heterogeneous Kubernetes SLURM cluster with ARM and Android support

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
LOG_FILE="$PROJECT_DIR/cluster-deployment-$(date +%Y%m%d_%H%M%S).log"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

usage() {
    echo "Complete Cluster Deployment Script"
    echo "================================="
    echo "Usage: $0 [options]"
    echo ""
    echo "Options:"
    echo "  --full              Full deployment (x86 + ARM + Android)"
    echo "  --x86-only          Deploy only x86 nodes"
    echo "  --arm-only          Deploy only ARM nodes"
    echo "  --android-only      Deploy only Android integration"
    echo "  --skip-android      Skip Android APK building"
    echo "  --validate          Validate existing deployment"
    echo "  --help              Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 --full           # Complete heterogeneous cluster"
    echo "  $0 --x86-only       # Traditional x86 cluster only"
    echo "  $0 --validate       # Check cluster health"
    exit 1
}

log() {
    local level=$1
    shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    case $level in
        "INFO")
            echo -e "${GREEN}[INFO]${NC} $message" | tee -a "$LOG_FILE"
            ;;
        "WARN")
            echo -e "${YELLOW}[WARN]${NC} $message" | tee -a "$LOG_FILE"
            ;;
        "ERROR")
            echo -e "${RED}[ERROR]${NC} $message" | tee -a "$LOG_FILE"
            ;;
        "DEBUG")
            echo -e "${BLUE}[DEBUG]${NC} $message" | tee -a "$LOG_FILE"
            ;;
        *)
            echo "[$timestamp] $message" | tee -a "$LOG_FILE"
            ;;
    esac
}

check_prerequisites() {
    log "INFO" "🔍 Checking prerequisites..."
    
    # Check required tools
    local required_tools=("ansible" "kubectl" "docker" "curl" "jq")
    for tool in "${required_tools[@]}"; do
        if ! command -v "$tool" >/dev/null 2>&1; then
            log "ERROR" "Required tool not found: $tool"
            return 1
        fi
    done
    
    # Check Ansible inventory
    if [ ! -f "$PROJECT_DIR/ansible/inventory.ini" ]; then
        log "ERROR" "Ansible inventory not found: $PROJECT_DIR/ansible/inventory.ini"
        return 1
    fi
    
    # Check SSH keys
    if [ ! -f ~/.ssh/cluster_key ]; then
        log "WARN" "Cluster SSH key not found, using default key"
    fi
    
    log "INFO" "✅ Prerequisites check passed"
}

deploy_x86_cluster() {
    log "INFO" "🖥️ Deploying x86 cluster nodes..."
    
    cd "$PROJECT_DIR/ansible"
    
    # Deploy common components
    log "INFO" "Installing common components..."
    ansible-playbook -i inventory.ini site.yml --limit x86_nodes --tags common
    
    # Deploy Kubernetes
    log "INFO" "Setting up Kubernetes cluster..."
    ansible-playbook -i inventory.ini site.yml --limit x86_nodes --tags kubernetes
    
    # Deploy SLURM
    log "INFO" "Setting up SLURM cluster..."
    ansible-playbook -i inventory.ini site.yml --limit x86_nodes --tags slurm
    
    # Deploy JupyterHub
    log "INFO" "Setting up JupyterHub..."
    ansible-playbook -i inventory.ini site.yml --limit master --tags jupyter
    
    log "INFO" "✅ x86 cluster deployment completed"
}

deploy_arm_support() {
    log "INFO" "🦾 Deploying ARM node support..."
    
    cd "$PROJECT_DIR/ansible"
    
    # Deploy ARM-specific configurations
    if ansible-playbook -i inventory.ini site.yml --limit arm_nodes --tags arm-support 2>/dev/null; then
        log "INFO" "✅ ARM support deployed to existing nodes"
    else
        log "WARN" "No ARM nodes found in inventory, skipping ARM deployment"
    fi
    
    # Make ARM scripts executable
    chmod +x "$PROJECT_DIR/scripts/setup-arm-node.sh"
    chmod +x "$PROJECT_DIR/scripts/add-arm-node.sh"
    chmod +x "$PROJECT_DIR/scripts/arm-node-discovery.sh"
    
    log "INFO" "✅ ARM support configuration completed"
}

build_android_apk() {
    log "INFO" "📱 Building Android cluster node APK..."
    
    local android_project="$PROJECT_DIR/android-cluster-node"
    
    if [ ! -d "$android_project" ]; then
        log "ERROR" "Android project directory not found: $android_project"
        return 1
    fi
    
    cd "$android_project"
    
    # Check for Gradle wrapper
    if [ -f "./gradlew" ]; then
        log "INFO" "Building APK with Gradle wrapper..."
        ./gradlew assembleRelease
    elif command -v gradle >/dev/null 2>&1; then
        log "INFO" "Building APK with system Gradle..."
        gradle assembleRelease
    else
        log "ERROR" "Gradle not found. Please install Android Studio or Gradle"
        return 1
    fi
    
    local apk_path="$android_project/app/build/outputs/apk/release/app-release.apk"
    if [ -f "$apk_path" ]; then
        log "INFO" "✅ APK built successfully: $apk_path"
        
        # Create symlink for easy access
        ln -sf "$apk_path" "$PROJECT_DIR/ClusterNode.apk"
        log "INFO" "📱 APK available at: $PROJECT_DIR/ClusterNode.apk"
    else
        log "ERROR" "APK build failed - output not found"
        return 1
    fi
}

deploy_android_integration() {
    log "INFO" "🤖 Setting up Android integration..."
    
    # Make Android management script executable
    chmod +x "$PROJECT_DIR/scripts/android-cluster-manager.sh"
    
    # Initialize Android nodes registry
    echo "[]" > "$PROJECT_DIR/android_nodes.json"
    
    # Build APK if not skipped
    if [ "$SKIP_ANDROID_BUILD" != "true" ]; then
        if ! build_android_apk; then
            log "WARN" "APK build failed, but continuing with other Android methods"
        fi
    fi
    
    log "INFO" "✅ Android integration setup completed"
    log "INFO" "📋 Use ./scripts/android-cluster-manager.sh to manage Android devices"
}

deploy_web_ui() {
    log "INFO" "🌐 Deploying cluster web UI..."
    
    # Deploy web UI to master node
    if [ -f "$PROJECT_DIR/scripts/deploy-web-ui.sh" ]; then
        chmod +x "$PROJECT_DIR/scripts/deploy-web-ui.sh"
        "$PROJECT_DIR/scripts/deploy-web-ui.sh"
    else
        log "WARN" "Web UI deployment script not found"
    fi
    
    log "INFO" "✅ Web UI deployment completed"
}

setup_monitoring() {
    log "INFO" "📊 Setting up cluster monitoring..."
    
    # Make monitoring scripts executable
    chmod +x "$PROJECT_DIR/scripts/cluster-health-dashboard.sh"
    
    # Start health monitoring service
    if "$PROJECT_DIR/scripts/cluster-health-dashboard.sh" setup-service; then
        log "INFO" "✅ Health monitoring service configured"
    else
        log "WARN" "Failed to setup health monitoring service"
    fi
}

validate_deployment() {
    log "INFO" "🔍 Validating cluster deployment..."
    
    local validation_passed=true
    
    # Check Kubernetes cluster
    log "INFO" "Checking Kubernetes cluster status..."
    if kubectl cluster-info >/dev/null 2>&1; then
        local ready_nodes=$(kubectl get nodes --no-headers | grep -c " Ready ")
        log "INFO" "✅ Kubernetes cluster active with $ready_nodes ready nodes"
    else
        log "ERROR" "❌ Kubernetes cluster not accessible"
        validation_passed=false
    fi
    
    # Check SLURM cluster
    log "INFO" "Checking SLURM cluster status..."
    if sinfo >/dev/null 2>&1; then
        local slurm_nodes=$(sinfo --noheader | wc -l)
        log "INFO" "✅ SLURM cluster active with $slurm_nodes partitions"
    else
        log "WARN" "⚠️ SLURM cluster not accessible from this node"
    fi
    
    # Check web UI
    log "INFO" "Checking web UI accessibility..."
    local master_ip=$(grep "steve-thinkpad" "$PROJECT_DIR/ansible/inventory.ini" | grep -o "ansible_host=[0-9.]*" | cut -d= -f2)
    if curl -s "http://$master_ip" >/dev/null 2>&1; then
        log "INFO" "✅ Web UI accessible at http://$master_ip"
    else
        log "WARN" "⚠️ Web UI not accessible"
    fi
    
    # Check JupyterHub
    log "INFO" "Checking JupyterHub status..."
    if curl -s "http://$master_ip:8000" >/dev/null 2>&1; then
        log "INFO" "✅ JupyterHub accessible at http://$master_ip:8000"
    else
        log "WARN" "⚠️ JupyterHub not accessible"
    fi
    
    if [ "$validation_passed" = true ]; then
        log "INFO" "✅ Cluster validation completed successfully"
        return 0
    else
        log "ERROR" "❌ Cluster validation failed"
        return 1
    fi
}

generate_deployment_summary() {
    log "INFO" "📋 Generating deployment summary..."
    
    local summary_file="$PROJECT_DIR/deployment-summary-$(date +%Y%m%d_%H%M%S).md"
    
    cat > "$summary_file" << EOF
# Cluster Deployment Summary

**Deployment Date:** $(date)
**Deployment Type:** $DEPLOYMENT_TYPE
**Log File:** $LOG_FILE

## 🖥️ Cluster Nodes

### x86 Nodes
$(kubectl get nodes -o wide 2>/dev/null | grep -v "arm64" || echo "Not available")

### ARM Nodes
$(kubectl get nodes -o wide 2>/dev/null | grep "arm64" || echo "No ARM nodes found")

## 🔗 Access URLs

- **Cluster Dashboard:** http://$(grep "steve-thinkpad" "$PROJECT_DIR/ansible/inventory.ini" | grep -o "ansible_host=[0-9.]*" | cut -d= -f2)
- **JupyterHub:** http://$(grep "steve-thinkpad" "$PROJECT_DIR/ansible/inventory.ini" | grep -o "ansible_host=[0-9.]*" | cut -d= -f2):8000

## 📱 Android Integration

- **APK Location:** $PROJECT_DIR/ClusterNode.apk
- **Management Script:** ./scripts/android-cluster-manager.sh
- **Registry File:** $PROJECT_DIR/android_nodes.json

## 🛠️ Management Commands

### Add ARM Devices
\`\`\`bash
# Raspberry Pi
./scripts/add-arm-node.sh raspberry_pi 192.168.1.100 pi

# NVIDIA Jetson
./scripts/add-arm-node.sh jetson 192.168.1.101 nvidia

# Generic ARM
./scripts/add-arm-node.sh generic 192.168.1.102 ubuntu
\`\`\`

### Add Android Devices
\`\`\`bash
# Custom APK method
./scripts/android-cluster-manager.sh add apk 192.168.1.103

# Termux method
./scripts/android-cluster-manager.sh add termux 192.168.1.104 u0_a123
\`\`\`

### Monitor Cluster
\`\`\`bash
# Check cluster health
kubectl get nodes
sinfo
./scripts/cluster-health-dashboard.sh status

# Discover ARM devices
./scripts/arm-node-discovery.sh
./scripts/android-cluster-manager.sh discover
\`\`\`

## 📊 SLURM Job Examples

### Submit ARM Job
\`\`\`bash
sbatch --partition=arm_compute ./examples/slurm-jobs/arm-workloads.sh
\`\`\`

### Submit Android Job
\`\`\`bash
# Jobs will be automatically routed to Android devices via HTTP API
sbatch --partition=mobile_compute ./examples/slurm-jobs/mobile-workloads.sh
\`\`\`

---
Generated by deploy-complete-cluster.sh
EOF

    log "INFO" "📄 Deployment summary saved: $summary_file"
}

# Parse command line arguments
DEPLOYMENT_TYPE="full"
SKIP_ANDROID_BUILD="false"
VALIDATE_ONLY="false"

while [[ $# -gt 0 ]]; do
    case $1 in
        --full)
            DEPLOYMENT_TYPE="full"
            shift
            ;;
        --x86-only)
            DEPLOYMENT_TYPE="x86_only"
            shift
            ;;
        --arm-only)
            DEPLOYMENT_TYPE="arm_only"
            shift
            ;;
        --android-only)
            DEPLOYMENT_TYPE="android_only"
            shift
            ;;
        --skip-android)
            SKIP_ANDROID_BUILD="true"
            shift
            ;;
        --validate)
            VALIDATE_ONLY="true"
            shift
            ;;
        --help)
            usage
            ;;
        *)
            log "ERROR" "Unknown option: $1"
            usage
            ;;
    esac
done

# Main execution
main() {
    log "INFO" "🚀 Starting cluster deployment (type: $DEPLOYMENT_TYPE)"
    
    # Check prerequisites
    if ! check_prerequisites; then
        log "ERROR" "Prerequisites check failed"
        exit 1
    fi
    
    # Validation-only mode
    if [ "$VALIDATE_ONLY" = "true" ]; then
        validate_deployment
        exit $?
    fi
    
    # Execute deployment based on type
    case $DEPLOYMENT_TYPE in
        "full")
            deploy_x86_cluster
            deploy_arm_support
            deploy_android_integration
            deploy_web_ui
            setup_monitoring
            ;;
        "x86_only")
            deploy_x86_cluster
            deploy_web_ui
            setup_monitoring
            ;;
        "arm_only")
            deploy_arm_support
            ;;
        "android_only")
            deploy_android_integration
            ;;
    esac
    
    # Validate deployment
    if ! validate_deployment; then
        log "WARN" "Deployment validation failed, but continuing..."
    fi
    
    # Generate summary
    generate_deployment_summary
    
    log "INFO" "🎉 Cluster deployment completed successfully!"
    log "INFO" "📋 Check deployment summary and logs for details"
    log "INFO" "🌐 Access your cluster dashboard to get started"
}

# Execute main function
main "$@"
