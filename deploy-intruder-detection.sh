#!/bin/bash

# Intruder Detection Deployment and Test Script
# This script deploys and verifies the st7ma784/intruder-detection service

echo "🔒 INTRUDER DETECTION DEPLOYMENT"
echo "================================"
echo ""

# Check if kubectl is configured
if ! kubectl cluster-info &>/dev/null; then
    echo "❌ kubectl not configured or cluster not accessible"
    echo "Please ensure KUBECONFIG is set and cluster is running"
    exit 1
fi

echo "✅ Kubernetes cluster accessible"
echo ""

# Deploy the intruder detection system
echo "🚀 Deploying Intruder Detection System..."
kubectl apply -f kubernetes/manifests/intruder-detection.yaml

if [ $? -eq 0 ]; then
    echo "✅ Intruder detection manifests applied successfully"
else
    echo "❌ Failed to apply intruder detection manifests"
    exit 1
fi

echo ""
echo "⏳ Waiting for deployment to be ready..."

# Wait for namespace to be created
kubectl wait --for=condition=Ready namespace/security --timeout=60s

# Wait for deployment to be available
kubectl wait --for=condition=available --timeout=300s deployment/intruder-detection -n security

if [ $? -eq 0 ]; then
    echo "✅ Intruder detection deployment is ready"
else
    echo "⚠️  Deployment may still be starting up"
fi

echo ""
echo "📊 DEPLOYMENT STATUS:"
echo "===================="

# Check namespace
echo "Namespace:"
kubectl get namespace security

echo ""
echo "Pods:"
kubectl get pods -n security

echo ""
echo "Services:"
kubectl get svc -n security

echo ""
echo "Ingress:"
kubectl get ingress -n security

echo ""
echo "🔗 ACCESS INFORMATION:"
echo "====================="

# Get node IPs for access
NODE_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}')

echo "NodePort Access:"
echo "  🖥️  Security Dashboard: http://$NODE_IP:30085"
echo "  📹 Camera Stream: http://$NODE_IP:30086"
echo "  📊 Metrics: http://$NODE_IP:30087"
echo ""

echo "Ingress Access (if configured):"
echo "  🖥️  Security Dashboard: http://cluster.local/security"
echo "  📹 Camera Stream: http://cluster.local/camera-stream"
echo ""

# Check if ingress controller is running
INGRESS_RUNNING=$(kubectl get pods -n ingress-nginx -l app.kubernetes.io/component=controller -o jsonpath='{.items[*].status.phase}' | grep -o Running | wc -l)

if [ "$INGRESS_RUNNING" -gt 0 ]; then
    echo "✅ NGINX Ingress Controller is running"
    echo "Add to /etc/hosts: $NODE_IP cluster.local"
else
    echo "⚠️  NGINX Ingress Controller not found - using NodePort access only"
fi

echo ""
echo "🔧 MANAGEMENT COMMANDS:"
echo "======================"
echo "Check pod logs:"
echo "  kubectl logs -f deployment/intruder-detection -n security"
echo ""
echo "Scale deployment:"
echo "  kubectl scale deployment intruder-detection --replicas=2 -n security"
echo ""
echo "View configuration:"
echo "  kubectl get configmap intruder-detection-config -n security -o yaml"
echo ""
echo "Port forward for local testing:"
echo "  kubectl port-forward svc/intruder-detection-service 8080:8080 -n security"
echo "  kubectl port-forward svc/intruder-detection-service 8090:8090 -n security"
echo ""

# Test connectivity if possible
echo "🧪 CONNECTIVITY TEST:"
echo "====================="

POD_COUNT=$(kubectl get pods -n security -l app=intruder-detection -o jsonpath='{.items[*].status.phase}' | grep -o Running | wc -l)

if [ "$POD_COUNT" -gt 0 ]; then
    echo "✅ $POD_COUNT intruder detection pod(s) running"
    
    # Test internal connectivity
    echo "Testing internal service connectivity..."
    kubectl run test-pod --image=busybox --rm -i --restart=Never -- wget -qO- --timeout=5 http://intruder-detection-service.security.svc.cluster.local:8080/health 2>/dev/null
    
    if [ $? -eq 0 ]; then
        echo "✅ Internal service connectivity test passed"
    else
        echo "⚠️  Internal service connectivity test failed (service may still be starting)"
    fi
else
    echo "❌ No running intruder detection pods found"
fi

echo ""
echo "🎯 NEXT STEPS:"
echo "============="
echo "1. Access the security dashboard at http://$NODE_IP:30085"
echo "2. Check camera connectivity and permissions"
echo "3. Configure detection sensitivity and alerts"
echo "4. Set up webhook notifications for security events"
echo "5. Monitor system logs for detection events"
echo ""

# Check for camera devices on target node
echo "📹 CAMERA DEVICE CHECK:"
echo "======================"
TARGET_NODE="steve-thinkpad-l490"

echo "Checking for camera devices on $TARGET_NODE..."
kubectl debug node/$TARGET_NODE -it --image=busybox -- ls -la /host/dev/video* 2>/dev/null || echo "⚠️  No camera devices found or node not accessible"

echo ""
echo "✨ INTRUDER DETECTION DEPLOYMENT COMPLETE!"
echo ""
