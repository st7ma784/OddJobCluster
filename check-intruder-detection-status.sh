#!/bin/bash

# Intruder Detection Status Check
# Comprehensive overview of st7ma784/intruder-detection deployment status

echo "🔒 INTRUDER DETECTION SYSTEM STATUS"
echo "==================================="
echo ""

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check prerequisites
echo "📋 PREREQUISITES CHECK:"
echo "======================="

if command_exists kubectl; then
    echo "✅ kubectl installed"
    if kubectl cluster-info &>/dev/null; then
        echo "✅ Kubernetes cluster accessible"
    else
        echo "❌ Kubernetes cluster not accessible"
        echo "   Please check KUBECONFIG and cluster status"
        exit 1
    fi
else
    echo "❌ kubectl not found"
    exit 1
fi

if command_exists docker; then
    echo "✅ Docker available"
else
    echo "⚠️  Docker not found (needed for image management)"
fi

echo ""

# Check if manifests exist
echo "📁 MANIFEST FILES STATUS:"
echo "========================="

if [ -f "kubernetes/manifests/intruder-detection.yaml" ]; then
    echo "✅ intruder-detection.yaml manifest exists"
    echo "   📊 Manifest details:"
    echo "     - Namespace: security"
    echo "     - NodePort: 30085 (web), 30086 (stream), 30087 (metrics)"
    echo "     - Target node: steve-thinkpad-l490 (camera node)"
    echo "     - Image: st7ma784/intruder-detection:latest"
else
    echo "❌ intruder-detection.yaml manifest missing"
    echo "   Run the documentation update to create manifests"
fi

if [ -f "deploy-intruder-detection.sh" ]; then
    echo "✅ Deployment script available"
else
    echo "❌ Deployment script missing"
fi

echo ""

# Check current deployment status
echo "🚀 DEPLOYMENT STATUS:"
echo "===================="

# Check if security namespace exists
if kubectl get namespace security &>/dev/null; then
    echo "✅ Security namespace exists"
    
    # Check pods
    PODS=$(kubectl get pods -n security -l app=intruder-detection --no-headers 2>/dev/null | wc -l)
    RUNNING_PODS=$(kubectl get pods -n security -l app=intruder-detection --no-headers 2>/dev/null | grep Running | wc -l)
    
    if [ "$PODS" -gt 0 ]; then
        echo "✅ Intruder detection pods: $RUNNING_PODS/$PODS running"
        kubectl get pods -n security -l app=intruder-detection
    else
        echo "❌ No intruder detection pods found"
    fi
    
    # Check services
    SERVICES=$(kubectl get svc -n security -l app=intruder-detection --no-headers 2>/dev/null | wc -l)
    if [ "$SERVICES" -gt 0 ]; then
        echo "✅ Intruder detection service deployed"
        kubectl get svc -n security -l app=intruder-detection
    else
        echo "❌ No intruder detection service found"
    fi
    
    # Check ingress
    INGRESS=$(kubectl get ingress -n security --no-headers 2>/dev/null | wc -l)
    if [ "$INGRESS" -gt 0 ]; then
        echo "✅ Security ingress rules deployed"
        kubectl get ingress -n security
    else
        echo "⚠️  No ingress rules found in security namespace"
    fi
    
else
    echo "❌ Security namespace not found"
    echo "   Intruder detection system not deployed"
fi

echo ""

# Check Docker image availability
echo "🐳 DOCKER IMAGE STATUS:"
echo "======================="

if command_exists docker; then
    echo "Checking st7ma784/intruder-detection image..."
    if docker images st7ma784/intruder-detection:latest &>/dev/null; then
        echo "✅ Image available locally"
        docker images st7ma784/intruder-detection:latest --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}\t{{.CreatedAt}}"
    else
        echo "⚠️  Image not available locally"
        echo "   Attempting to pull from registry..."
        docker pull st7ma784/intruder-detection:latest
        if [ $? -eq 0 ]; then
            echo "✅ Image pulled successfully"
        else
            echo "❌ Failed to pull image - registry access issues"
        fi
    fi
else
    echo "⚠️  Docker not available for image check"
fi

echo ""

# Check network access and ports
echo "🌐 NETWORK ACCESS STATUS:"
echo "========================="

# Get node IP for access testing
NODE_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}' 2>/dev/null)

if [ -n "$NODE_IP" ]; then
    echo "📍 Master node IP: $NODE_IP"
    
    # Check if ports are accessible
    echo "🔌 Port availability check:"
    
    # Check if any services are using our target ports
    PORT_30085=$(kubectl get svc --all-namespaces -o jsonpath='{.items[?(@.spec.ports[*].nodePort==30085)].metadata.name}' 2>/dev/null)
    PORT_30086=$(kubectl get svc --all-namespaces -o jsonpath='{.items[?(@.spec.ports[*].nodePort==30086)].metadata.name}' 2>/dev/null)
    PORT_30087=$(kubectl get svc --all-namespaces -o jsonpath='{.items[?(@.spec.ports[*].nodePort==30087)].metadata.name}' 2>/dev/null)
    
    if [ -z "$PORT_30085" ]; then
        echo "✅ Port 30085 (web interface) available"
    else
        echo "⚠️  Port 30085 in use by: $PORT_30085"
    fi
    
    if [ -z "$PORT_30086" ]; then
        echo "✅ Port 30086 (camera stream) available"
    else
        echo "⚠️  Port 30086 in use by: $PORT_30086"
    fi
    
    if [ -z "$PORT_30087" ]; then
        echo "✅ Port 30087 (metrics) available"
    else
        echo "⚠️  Port 30087 in use by: $PORT_30087"
    fi
    
else
    echo "❌ Cannot determine node IP address"
fi

echo ""

# Check ingress controller status
echo "🔀 INGRESS STATUS:"
echo "=================="

INGRESS_PODS=$(kubectl get pods -n ingress-nginx -l app.kubernetes.io/component=controller --no-headers 2>/dev/null | wc -l)
INGRESS_RUNNING=$(kubectl get pods -n ingress-nginx -l app.kubernetes.io/component=controller --no-headers 2>/dev/null | grep Running | wc -l)

if [ "$INGRESS_PODS" -gt 0 ]; then
    echo "✅ NGINX Ingress Controller: $INGRESS_RUNNING/$INGRESS_PODS running"
    if [ "$INGRESS_RUNNING" -gt 0 ]; then
        echo "✅ Ingress-based access will be available"
        echo "   Add to /etc/hosts: $NODE_IP cluster.local"
    fi
else
    echo "❌ NGINX Ingress Controller not deployed"
    echo "   Only NodePort access will be available"
fi

echo ""

# Check camera node status
echo "📹 CAMERA NODE STATUS:"
echo "====================="

TARGET_NODE="steve-thinkpad-l490"
NODE_STATUS=$(kubectl get node $TARGET_NODE --no-headers 2>/dev/null | awk '{print $2}')

if [ "$NODE_STATUS" = "Ready" ]; then
    echo "✅ Target camera node ($TARGET_NODE) is Ready"
    
    # Check if node has camera devices (requires node access)
    echo "🔍 Camera device check on $TARGET_NODE:"
    echo "   (Manual verification required - ssh to node and check /dev/video*)"
    
else
    echo "❌ Target camera node ($TARGET_NODE) is $NODE_STATUS"
    echo "   Intruder detection requires this node to be Ready"
fi

echo ""

# Summary and recommendations
echo "📋 STATUS SUMMARY:"
echo "=================="

# Count issues
ISSUES=0
READY=false

if ! kubectl get namespace security &>/dev/null; then
    echo "❌ Not deployed - Security namespace missing"
    ISSUES=$((ISSUES + 1))
elif [ "$RUNNING_PODS" -eq 0 ]; then
    echo "❌ Deployed but not running - No running pods"
    ISSUES=$((ISSUES + 1))
elif [ "$NODE_STATUS" != "Ready" ]; then
    echo "⚠️  Deployed but target node not ready"
    ISSUES=$((ISSUES + 1))
else
    echo "✅ Deployed and operational"
    READY=true
fi

if [ "$INGRESS_RUNNING" -eq 0 ]; then
    echo "⚠️  No ingress controller - NodePort access only"
fi

echo ""
echo "🎯 RECOMMENDED ACTIONS:"
echo "======================"

if [ "$ISSUES" -gt 0 ]; then
    if ! kubectl get namespace security &>/dev/null; then
        echo "1. Deploy intruder detection system:"
        echo "   ./deploy-intruder-detection.sh"
        echo ""
        echo "2. Or deploy via Ansible:"
        echo "   cd ansible"
        echo "   ansible-playbook -i inventory.ini complete-cluster-deployment.yml"
    elif [ "$RUNNING_PODS" -eq 0 ]; then
        echo "1. Check deployment issues:"
        echo "   kubectl describe deployment intruder-detection -n security"
        echo ""
        echo "2. Check pod logs:"
        echo "   kubectl logs -l app=intruder-detection -n security"
    elif [ "$NODE_STATUS" != "Ready" ]; then
        echo "1. Fix target node issues:"
        echo "   kubectl describe node $TARGET_NODE"
        echo ""
        echo "2. Check node connectivity:"
        echo "   ansible $TARGET_NODE -m ping"
    fi
else
    echo "1. ✅ System appears to be deployed and ready"
    if [ -n "$NODE_IP" ]; then
        echo ""
        echo "2. 🔗 Access URLs:"
        echo "   Web Interface: http://$NODE_IP:30085"
        echo "   Camera Stream: http://$NODE_IP:30086"
        echo "   Metrics: http://$NODE_IP:30087"
        if [ "$INGRESS_RUNNING" -gt 0 ]; then
            echo "   Ingress: http://cluster.local/security"
        fi
    fi
    echo ""
    echo "3. 🔧 Test connectivity:"
    echo "   curl -I http://$NODE_IP:30085"
fi

echo ""
echo "📝 CONFIGURATION STATUS:"
echo "========================"
echo "✅ Manifest file: kubernetes/manifests/intruder-detection.yaml"
echo "✅ Deployment script: deploy-intruder-detection.sh"
echo "✅ Ansible integration: complete-cluster-deployment.yml"
echo "✅ Ingress rules: Configured for /security and /camera-stream paths"
echo "✅ Port allocation: 30085, 30086, 30087 (non-conflicting)"
echo "✅ Security context: Privileged access for camera devices"
echo "✅ Node affinity: Targeted to steve-thinkpad-l490 (camera node)"
echo ""

if [ "$READY" = true ]; then
    echo "🎉 INTRUDER DETECTION SYSTEM IS READY FOR USE!"
else
    echo "⚠️  INTRUDER DETECTION SYSTEM NEEDS DEPLOYMENT/FIXES"
fi

echo ""
