#!/bin/bash

# Camera Verification Deployment Script
# This script deploys and monitors camera capability testing across all cluster nodes

set -e

echo "🎥 Kubernetes Camera Verification System"
echo "========================================"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Check if cluster is accessible
echo -e "${BLUE}📋 Checking cluster connectivity...${NC}"
if ! kubectl cluster-info > /dev/null 2>&1; then
    echo -e "${RED}❌ Cannot connect to Kubernetes cluster${NC}"
    echo "Please ensure your kubeconfig is set correctly"
    exit 1
fi

echo -e "${GREEN}✅ Cluster accessible${NC}"

# Show cluster nodes
echo -e "\n${BLUE}🖥️  Cluster nodes:${NC}"
kubectl get nodes -o wide

# Deploy camera verification system
echo -e "\n${BLUE}🚀 Deploying camera verification system...${NC}"
kubectl apply -f kubernetes/manifests/camera-verification.yaml

echo -e "${GREEN}✅ Camera verification system deployed${NC}"

# Wait for DaemonSet to be ready
echo -e "\n${BLUE}⏳ Waiting for camera tests to deploy on all nodes...${NC}"
kubectl wait --for=condition=ready pod -l app=camera-test -n camera-testing --timeout=120s

# Show running pods
echo -e "\n${BLUE}📱 Camera test pods:${NC}"
kubectl get pods -n camera-testing -o wide

# Monitor test execution
echo -e "\n${BLUE}🔍 Monitoring camera capability tests (waiting 90 seconds)...${NC}"
echo "This will test camera access on each node and generate reports"

# Show logs from each pod
for i in {1..3}; do
    echo -e "\n${YELLOW}📊 Test progress check $i/3...${NC}"
    
    # Get pod names
    pods=$(kubectl get pods -n camera-testing -l app=camera-test --no-headers -o custom-columns=":metadata.name")
    
    for pod in $pods; do
        node=$(kubectl get pod $pod -n camera-testing -o jsonpath='{.spec.nodeName}')
        echo -e "\n${BLUE}Node: $node (Pod: $pod)${NC}"
        
        # Show recent logs
        kubectl logs $pod -n camera-testing --tail=10 2>/dev/null || echo "Logs not ready yet..."
    done
    
    if [ $i -lt 3 ]; then
        sleep 30
    fi
done

# Start the report collection job
echo -e "\n${BLUE}📊 Starting report collection...${NC}"
kubectl create job camera-report-run --from=job/camera-report-collector -n camera-testing

# Wait for report collection
echo -e "\n${BLUE}⏳ Waiting for report collection to complete...${NC}"
kubectl wait --for=condition=complete job/camera-report-run -n camera-testing --timeout=180s

# Show the collected reports
echo -e "\n${GREEN}📋 CAMERA CAPABILITY REPORT${NC}"
echo "==========================="

# Get the report collector pod logs
report_pod=$(kubectl get pods -n camera-testing -l job-name=camera-report-run --no-headers -o custom-columns=":metadata.name")
if [ ! -z "$report_pod" ]; then
    kubectl logs $report_pod -n camera-testing
else
    echo -e "${YELLOW}⚠️  Report collection pod not found, checking individual reports...${NC}"
    
    # Try to get reports directly from the shared volume
    pods=$(kubectl get pods -n camera-testing -l app=camera-test --no-headers -o custom-columns=":metadata.name")
    for pod in $pods; do
        echo -e "\n${BLUE}Report from $pod:${NC}"
        kubectl exec $pod -n camera-testing -- cat /shared/camera-report-$(kubectl get pod $pod -n camera-testing -o jsonpath='{.spec.nodeName}').txt 2>/dev/null || echo "Report not available"
    done
fi

# Provide next steps
echo -e "\n${BLUE}🎯 NEXT STEPS:${NC}"
echo "=============="
echo "1. Review the camera capability report above"
echo "2. Update intruder detection deployment to target camera-capable nodes"
echo "3. Use demo mode for nodes without cameras"

# Create node selector recommendations
echo -e "\n${BLUE}💡 Node Selector Recommendations:${NC}"
echo "================================="
echo "For nodes with cameras:"
echo "  nodeSelector:"
echo "    camera-capable: \"true\""
echo ""
echo "For demo mode (no cameras):"
echo "  nodeSelector:"
echo "    camera-capable: \"false\""

# Option to apply node labels based on results
echo -e "\n${YELLOW}📝 Would you like to automatically label nodes based on camera capabilities?${NC}"
echo "This will add 'camera-capable=true/false' labels to nodes for easy targeting"
echo ""
echo "To apply labels manually, run:"
echo "kubectl label node <node-name> camera-capable=true   # for nodes with cameras"
echo "kubectl label node <node-name> camera-capable=false  # for nodes without cameras"

# Cleanup option
echo -e "\n${BLUE}🧹 Cleanup:${NC}"
echo "=========="
echo "To remove the camera verification system:"
echo "kubectl delete namespace camera-testing"

echo -e "\n${GREEN}✅ Camera verification complete!${NC}"
