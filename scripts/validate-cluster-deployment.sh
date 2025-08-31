#!/bin/bash

# Cluster Deployment Validation Script
# Comprehensive testing and validation of heterogeneous cluster deployment

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

usage() {
    echo "Cluster Deployment Validation Script"
    echo "===================================="
    echo "Usage: $0 [options]"
    echo ""
    echo "Options:"
    echo "  --quick             Quick validation (basic checks only)"
    echo "  --full              Full validation including performance tests"
    echo "  --android           Test Android integration specifically"
    echo "  --arm               Test ARM node integration"
    echo "  --network           Test network connectivity"
    echo "  --performance       Run performance benchmarks"
    echo "  --fix-issues        Attempt to fix common issues"
    echo "  --report            Generate detailed validation report"
    echo ""
    echo "Examples:"
    echo "  $0 --quick          # Basic cluster health check"
    echo "  $0 --full           # Comprehensive validation"
    echo "  $0 --android        # Test Android device integration"
    exit 1
}

log() {
    local level=$1
    shift
    local message="$*"
    
    case $level in
        "PASS")
            echo -e "${GREEN}[✅ PASS]${NC} $message"
            ;;
        "FAIL")
            echo -e "${RED}[❌ FAIL]${NC} $message"
            ;;
        "WARN")
            echo -e "${YELLOW}[⚠️ WARN]${NC} $message"
            ;;
        "INFO")
            echo -e "${BLUE}[ℹ️ INFO]${NC} $message"
            ;;
        *)
            echo "$message"
            ;;
    esac
}

# Test results tracking
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_WARNED=0

test_result() {
    local result=$1
    local message=$2
    
    case $result in
        "PASS")
            log "PASS" "$message"
            ((TESTS_PASSED++))
            ;;
        "FAIL")
            log "FAIL" "$message"
            ((TESTS_FAILED++))
            ;;
        "WARN")
            log "WARN" "$message"
            ((TESTS_WARNED++))
            ;;
    esac
}

validate_prerequisites() {
    log "INFO" "🔍 Validating prerequisites..."
    
    # Check required commands
    local required_commands=("kubectl" "ansible" "curl" "jq" "ssh")
    for cmd in "${required_commands[@]}"; do
        if command -v "$cmd" >/dev/null 2>&1; then
            test_result "PASS" "Command available: $cmd"
        else
            test_result "FAIL" "Command missing: $cmd"
        fi
    done
    
    # Check project structure
    local required_files=(
        "$PROJECT_DIR/ansible/inventory.ini"
        "$PROJECT_DIR/scripts/android-cluster-manager.sh"
        "$PROJECT_DIR/scripts/add-arm-node.sh"
    )
    
    for file in "${required_files[@]}"; do
        if [ -f "$file" ]; then
            test_result "PASS" "Required file exists: $(basename "$file")"
        else
            test_result "FAIL" "Required file missing: $file"
        fi
    done
}

validate_kubernetes_cluster() {
    log "INFO" "☸️ Validating Kubernetes cluster..."
    
    # Check cluster connectivity
    if kubectl cluster-info >/dev/null 2>&1; then
        test_result "PASS" "Kubernetes cluster is accessible"
        
        # Check node status
        local total_nodes=$(kubectl get nodes --no-headers | wc -l)
        local ready_nodes=$(kubectl get nodes --no-headers | grep -c " Ready " || echo "0")
        
        if [ "$ready_nodes" -gt 0 ]; then
            test_result "PASS" "Kubernetes nodes ready: $ready_nodes/$total_nodes"
        else
            test_result "FAIL" "No Kubernetes nodes in Ready state"
        fi
        
        # Check system pods
        local system_pods=$(kubectl get pods -n kube-system --no-headers | grep -c " Running " || echo "0")
        if [ "$system_pods" -gt 5 ]; then
            test_result "PASS" "Kubernetes system pods running: $system_pods"
        else
            test_result "WARN" "Few system pods running: $system_pods"
        fi
        
    else
        test_result "FAIL" "Cannot connect to Kubernetes cluster"
    fi
}

validate_slurm_cluster() {
    log "INFO" "🖥️ Validating SLURM cluster..."
    
    # Check SLURM controller
    if sinfo >/dev/null 2>&1; then
        test_result "PASS" "SLURM controller is accessible"
        
        # Check partitions
        local partitions=$(sinfo --noheader | wc -l)
        if [ "$partitions" -gt 0 ]; then
            test_result "PASS" "SLURM partitions configured: $partitions"
        else
            test_result "FAIL" "No SLURM partitions found"
        fi
        
        # Check nodes
        local slurm_nodes=$(sinfo --Node --noheader | wc -l)
        local idle_nodes=$(sinfo --Node --noheader | grep -c "idle" || echo "0")
        
        test_result "PASS" "SLURM nodes total: $slurm_nodes (idle: $idle_nodes)"
        
    else
        test_result "WARN" "SLURM controller not accessible from this node"
    fi
}

validate_web_services() {
    log "INFO" "🌐 Validating web services..."
    
    # Get master node IP
    local master_ip=$(grep "steve-thinkpad" "$PROJECT_DIR/ansible/inventory.ini" | grep -o "ansible_host=[0-9.]*" | cut -d= -f2)
    
    if [ -z "$master_ip" ]; then
        test_result "FAIL" "Cannot determine master node IP"
        return
    fi
    
    # Check cluster dashboard
    if curl -s --connect-timeout 5 "http://$master_ip" >/dev/null 2>&1; then
        test_result "PASS" "Cluster dashboard accessible at http://$master_ip"
    else
        test_result "FAIL" "Cluster dashboard not accessible"
    fi
    
    # Check JupyterHub
    if curl -s --connect-timeout 5 "http://$master_ip:8000" >/dev/null 2>&1; then
        test_result "PASS" "JupyterHub accessible at http://$master_ip:8000"
    else
        test_result "WARN" "JupyterHub not accessible"
    fi
}

validate_android_integration() {
    log "INFO" "📱 Validating Android integration..."
    
    # Check Android management script
    if [ -x "$PROJECT_DIR/scripts/android-cluster-manager.sh" ]; then
        test_result "PASS" "Android cluster manager script is executable"
    else
        test_result "FAIL" "Android cluster manager script not executable"
    fi
    
    # Check Android nodes registry
    if [ -f "$PROJECT_DIR/android_nodes.json" ]; then
        local android_nodes=$(jq length "$PROJECT_DIR/android_nodes.json" 2>/dev/null || echo "0")
        if [ "$android_nodes" -gt 0 ]; then
            test_result "PASS" "Android nodes registered: $android_nodes"
        else
            test_result "INFO" "No Android nodes registered yet"
        fi
    else
        test_result "WARN" "Android nodes registry file not found"
    fi
    
    # Check APK availability
    if [ -f "$PROJECT_DIR/ClusterNode.apk" ] || [ -f "$PROJECT_DIR/android-cluster-node/app/build/outputs/apk/release/app-release.apk" ]; then
        test_result "PASS" "Android APK is available"
    else
        test_result "WARN" "Android APK not built yet"
    fi
}

validate_arm_integration() {
    log "INFO" "🦾 Validating ARM integration..."
    
    # Check ARM management scripts
    local arm_scripts=(
        "$PROJECT_DIR/scripts/add-arm-node.sh"
        "$PROJECT_DIR/scripts/setup-arm-node.sh"
        "$PROJECT_DIR/scripts/arm-node-discovery.sh"
    )
    
    for script in "${arm_scripts[@]}"; do
        if [ -x "$script" ]; then
            test_result "PASS" "ARM script executable: $(basename "$script")"
        else
            test_result "FAIL" "ARM script not executable: $(basename "$script")"
        fi
    done
    
    # Check ARM Ansible configuration
    if [ -f "$PROJECT_DIR/ansible/group_vars/arm_nodes.yml" ]; then
        test_result "PASS" "ARM nodes group variables configured"
    else
        test_result "WARN" "ARM nodes group variables not found"
    fi
    
    # Check for ARM nodes in inventory
    local arm_nodes=$(grep -c "arch=arm64" "$PROJECT_DIR/ansible/inventory.ini" || echo "0")
    if [ "$arm_nodes" -gt 0 ]; then
        test_result "PASS" "ARM nodes configured in inventory: $arm_nodes"
    else
        test_result "INFO" "No ARM nodes in inventory yet"
    fi
}

test_network_connectivity() {
    log "INFO" "🌐 Testing network connectivity..."
    
    # Test connectivity to configured nodes
    while IFS= read -r line; do
        if [[ $line =~ ansible_host=([0-9.]+) ]]; then
            local host_ip="${BASH_REMATCH[1]}"
            local hostname=$(echo "$line" | awk '{print $1}')
            
            if ping -c 1 -W 2 "$host_ip" >/dev/null 2>&1; then
                test_result "PASS" "Network connectivity to $hostname ($host_ip)"
            else
                test_result "FAIL" "No network connectivity to $hostname ($host_ip)"
            fi
        fi
    done < <(grep "ansible_host=" "$PROJECT_DIR/ansible/inventory.ini")
}

run_performance_tests() {
    log "INFO" "🏃 Running performance tests..."
    
    # Test Kubernetes pod scheduling
    log "INFO" "Testing Kubernetes pod scheduling..."
    kubectl run test-pod --image=busybox --restart=Never --rm -i --tty -- echo "Pod scheduling test" >/dev/null 2>&1
    if [ $? -eq 0 ]; then
        test_result "PASS" "Kubernetes pod scheduling works"
    else
        test_result "FAIL" "Kubernetes pod scheduling failed"
    fi
    
    # Test SLURM job submission
    if command -v sbatch >/dev/null 2>&1; then
        log "INFO" "Testing SLURM job submission..."
        local job_script="/tmp/test_job.sh"
        cat > "$job_script" << 'EOF'
#!/bin/bash
#SBATCH --job-name=validation_test
#SBATCH --output=/tmp/slurm_test_%j.out
#SBATCH --time=00:01:00
#SBATCH --nodes=1

echo "SLURM validation test completed successfully"
date
EOF
        
        if sbatch "$job_script" >/dev/null 2>&1; then
            test_result "PASS" "SLURM job submission works"
        else
            test_result "FAIL" "SLURM job submission failed"
        fi
        
        rm -f "$job_script"
    else
        test_result "WARN" "SLURM not available for testing on this node"
    fi
}

fix_common_issues() {
    log "INFO" "🔧 Attempting to fix common issues..."
    
    # Fix script permissions
    find "$PROJECT_DIR/scripts" -name "*.sh" -exec chmod +x {} \;
    test_result "PASS" "Fixed script permissions"
    
    # Create missing directories
    mkdir -p "$PROJECT_DIR/logs"
    mkdir -p "$PROJECT_DIR/tmp"
    test_result "PASS" "Created missing directories"
    
    # Initialize Android nodes registry if missing
    if [ ! -f "$PROJECT_DIR/android_nodes.json" ]; then
        echo "[]" > "$PROJECT_DIR/android_nodes.json"
        test_result "PASS" "Initialized Android nodes registry"
    fi
    
    # Check and fix Kubernetes context
    if ! kubectl cluster-info >/dev/null 2>&1; then
        log "INFO" "Attempting to set Kubernetes context..."
        if kubectl config use-context kubernetes-admin@kubernetes >/dev/null 2>&1; then
            test_result "PASS" "Fixed Kubernetes context"
        else
            test_result "WARN" "Could not fix Kubernetes context automatically"
        fi
    fi
}

generate_validation_report() {
    log "INFO" "📄 Generating validation report..."
    
    local report_file="$PROJECT_DIR/validation-report-$(date +%Y%m%d_%H%M%S).md"
    
    cat > "$report_file" << EOF
# Cluster Validation Report

**Validation Date:** $(date)
**Validation Type:** $VALIDATION_TYPE

## 📊 Test Results Summary

- **Tests Passed:** $TESTS_PASSED ✅
- **Tests Failed:** $TESTS_FAILED ❌
- **Warnings:** $TESTS_WARNED ⚠️
- **Total Tests:** $((TESTS_PASSED + TESTS_FAILED + TESTS_WARNED))

## 🏥 Overall Health Status

$(if [ $TESTS_FAILED -eq 0 ]; then
    echo "🟢 **HEALTHY** - All critical tests passed"
elif [ $TESTS_FAILED -le 2 ]; then
    echo "🟡 **DEGRADED** - Some issues detected but cluster is functional"
else
    echo "🔴 **UNHEALTHY** - Multiple critical issues detected"
fi)

## 🔍 Detailed Results

### Kubernetes Cluster
$(kubectl get nodes 2>/dev/null | head -10 || echo "Not accessible")

### SLURM Cluster
$(sinfo 2>/dev/null || echo "Not accessible")

### Web Services
- Cluster Dashboard: http://$(grep "steve-thinkpad" "$PROJECT_DIR/ansible/inventory.ini" | grep -o "ansible_host=[0-9.]*" | cut -d= -f2 || echo "unknown")
- JupyterHub: http://$(grep "steve-thinkpad" "$PROJECT_DIR/ansible/inventory.ini" | grep -o "ansible_host=[0-9.]*" | cut -d= -f2 || echo "unknown"):8000

### Android Integration
- Registry: $PROJECT_DIR/android_nodes.json
- Registered Devices: $(jq length "$PROJECT_DIR/android_nodes.json" 2>/dev/null || echo "0")

## 🛠️ Recommended Actions

$(if [ $TESTS_FAILED -gt 0 ]; then
    echo "1. Review failed tests and address issues"
    echo "2. Run validation again after fixes"
    echo "3. Check logs for detailed error information"
else
    echo "✅ No immediate actions required - cluster is healthy"
fi)

## 📋 Next Steps

- Monitor cluster performance over time
- Add ARM and Android devices as needed
- Regular validation runs recommended
- Keep documentation updated

---
Generated by validate-cluster-deployment.sh
EOF

    log "INFO" "📄 Validation report saved: $report_file"
}

# Parse command line arguments
VALIDATION_TYPE="quick"
RUN_ANDROID_TESTS="false"
RUN_ARM_TESTS="false"
RUN_NETWORK_TESTS="false"
RUN_PERFORMANCE_TESTS="false"
FIX_ISSUES="false"
GENERATE_REPORT="false"

while [[ $# -gt 0 ]]; do
    case $1 in
        --quick)
            VALIDATION_TYPE="quick"
            shift
            ;;
        --full)
            VALIDATION_TYPE="full"
            RUN_ANDROID_TESTS="true"
            RUN_ARM_TESTS="true"
            RUN_NETWORK_TESTS="true"
            RUN_PERFORMANCE_TESTS="true"
            GENERATE_REPORT="true"
            shift
            ;;
        --android)
            RUN_ANDROID_TESTS="true"
            shift
            ;;
        --arm)
            RUN_ARM_TESTS="true"
            shift
            ;;
        --network)
            RUN_NETWORK_TESTS="true"
            shift
            ;;
        --performance)
            RUN_PERFORMANCE_TESTS="true"
            shift
            ;;
        --fix-issues)
            FIX_ISSUES="true"
            shift
            ;;
        --report)
            GENERATE_REPORT="true"
            shift
            ;;
        --help)
            usage
            ;;
        *)
            log "FAIL" "Unknown option: $1"
            usage
            ;;
    esac
done

# Main execution
main() {
    log "INFO" "🚀 Starting cluster validation (type: $VALIDATION_TYPE)"
    
    # Fix issues if requested
    if [ "$FIX_ISSUES" = "true" ]; then
        fix_common_issues
    fi
    
    # Core validation tests
    validate_prerequisites
    validate_kubernetes_cluster
    validate_slurm_cluster
    validate_web_services
    
    # Optional validation tests
    if [ "$RUN_ANDROID_TESTS" = "true" ]; then
        validate_android_integration
    fi
    
    if [ "$RUN_ARM_TESTS" = "true" ]; then
        validate_arm_integration
    fi
    
    if [ "$RUN_NETWORK_TESTS" = "true" ]; then
        test_network_connectivity
    fi
    
    if [ "$RUN_PERFORMANCE_TESTS" = "true" ]; then
        run_performance_tests
    fi
    
    # Generate report if requested
    if [ "$GENERATE_REPORT" = "true" ]; then
        generate_validation_report
    fi
    
    # Final summary
    log "INFO" "🏁 Validation completed"
    log "INFO" "📊 Results: $TESTS_PASSED passed, $TESTS_FAILED failed, $TESTS_WARNED warnings"
    
    if [ $TESTS_FAILED -eq 0 ]; then
        log "PASS" "🎉 Cluster validation successful!"
        exit 0
    else
        log "FAIL" "❌ Cluster validation failed - please review issues"
        exit 1
    fi
}

# Execute main function
main "$@"
