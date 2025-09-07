#!/bin/bash

# Cluster Web Services Access Script
# Run this script to access various web services in the cluster

KUBECONFIG_PATH="./AtmosRay/Kubernetes Demo/kubeconfig"
export KUBECONFIG=$KUBECONFIG_PATH

echo "🚀 Kubernetes Cluster Web Services Access"
echo "=========================================="
echo ""

# Check cluster connectivity
if ! kubectl cluster-info &> /dev/null; then
    echo "❌ Error: Cannot connect to Kubernetes cluster"
    exit 1
fi

echo "✅ Connected to cluster"
echo ""
echo "Available Services:"
echo ""

# Function to start port forwarding in background
start_port_forward() {
    local service=$1
    local namespace=$2
    local local_port=$3
    local remote_port=$4
    local description=$5
    
    echo "🌐 $description"
    echo "   Starting port forward: $service in $namespace"
    echo "   Access at: http://localhost:$local_port"
    
    # Kill any existing process on this port
    pkill -f "kubectl.*port-forward.*$local_port" 2>/dev/null
    
    # Start port forwarding in background
    kubectl port-forward svc/$service -n $namespace $local_port:$remote_port --address=0.0.0.0 &
    local pid=$!
    echo "   Process ID: $pid"
    echo ""
    
    # Give it a moment to start
    sleep 2
}

echo "1️⃣  KUBERNETES DASHBOARD"
echo "   📊 Complete cluster management interface"
start_port_forward "kubernetes-dashboard" "kubernetes-dashboard" "9443" "443" "Kubernetes Dashboard (HTTPS)"

echo "2️⃣  RADIO PROPAGATION SYSTEM (AtmosRay)"
echo "   🌊 Radio signal monitoring and visualization"
start_port_forward "radio-server-service" "radio-propagation" "9080" "8080" "Radio Propagation Server"

echo "3️⃣  LUSTORES SYSTEM"
echo "   🛍️  E-commerce platform"
start_port_forward "nginx" "lustores" "9081" "80" "LUStores Web Interface"

echo "4️⃣  INTRUDER DETECTION"
echo "   🎥 Security camera monitoring"
start_port_forward "intruder-detection-service" "default" "9082" "8080" "Intruder Detection System"

echo "5️⃣  ATMOSPHERIC SIMULATOR"
echo "   🌍 Weather and propagation simulation"
start_port_forward "simulator-service" "radio-propagation" "9083" "8081" "Atmospheric Simulator"

echo ""
echo "🔑 KUBERNETES DASHBOARD ACCESS TOKEN:"
echo "Copy this token to login to the dashboard:"
echo ""
kubectl -n kubernetes-dashboard create token admin-user 2>/dev/null || echo "Error generating token"
echo ""

echo "📋 ACCESS SUMMARY:"
echo "=================="
echo "🌐 Kubernetes Dashboard: https://localhost:9443 (use token above)"
echo "🌊 Radio Propagation:    http://localhost:9080"
echo "🛍️  LUStores Platform:    http://localhost:9081"
echo "🎥 Intruder Detection:   http://localhost:9082"
echo "🌍 Atmospheric Sim:      http://localhost:9083"
echo ""
echo "📊 CLUSTER STATUS:"
echo "=================="
kubectl get nodes
echo ""
kubectl get pods --all-namespaces | grep -E "(Running|Ready)" | wc -l | xargs echo "Running Pods:"
echo ""

echo "🎯 To stop all port forwarding:"
echo "   pkill -f 'kubectl.*port-forward'"
echo ""
echo "🔄 To check what's running:"
echo "   ps aux | grep kubectl"
echo ""

# Keep script running
echo "✨ All services started! Press Ctrl+C to stop all port forwarding..."
trap 'echo ""; echo "🛑 Stopping all port forwarding..."; pkill -f "kubectl.*port-forward"; exit 0' INT

# Wait for user interrupt
while true; do
    sleep 10
    # Check if any port-forward processes died and restart them
    if ! pgrep -f "kubectl.*port-forward.*9443" > /dev/null; then
        echo "⚠️  Restarting Kubernetes Dashboard port-forward..."
        kubectl port-forward svc/kubernetes-dashboard -n kubernetes-dashboard 9443:443 --address=0.0.0.0 &
    fi
done

echo "🚀 Setting up access to deployed services..."

# Check if kubectl is available
if ! command -v kubectl &> /dev/null; then
    echo "❌ kubectl not found. Run this script from the master node."
    exit 1
fi

export KUBECONFIG=/etc/kubernetes/admin.conf

echo "🔍 Checking service status..."

# Check LUStores
LUSTORES_READY=$(kubectl get pods -n lustores -l app=app --no-headers | grep Running | wc -l)
ATMOSRAY_READY=$(kubectl get pods -l app=atmosray --no-headers | grep Running | wc -l)

echo "📊 Service Status:"
echo "  - LUStores: $LUSTORES_READY/2 pods ready"
echo "  - AtmosRay: $ATMOSRAY_READY/2 pods ready"

echo ""
echo "🌐 Available Access Methods:"
echo ""

echo "1. 🏪 LUStores (University Inventory System):"
echo "   Internal: http://10.107.24.100:5000"
echo "   Port Forward: kubectl port-forward -n lustores service/app 8080:5000"
echo "   Then access: http://localhost:8080"
echo ""

echo "2. 🌤️  AtmosRay (Weather Data):"
echo "   Internal: http://10.96.46.126:5000"
echo "   Port Forward: kubectl port-forward service/atmosray-service 8081:5000"
echo "   Then access: http://localhost:8081"
echo ""

echo "3. 🔐 Replit Auth Service:"
echo "   Internal: http://10.99.124.136:3001"
echo "   Port Forward: kubectl port-forward -n lustores service/replit-auth 8082:3001"
echo "   Then access: http://localhost:8082"
echo ""

# Option to start port forwarding
if [ "$1" = "--start-forwarding" ]; then
    echo "🔗 Starting port forwarding (press Ctrl+C to stop)..."
    echo ""
    
    # Start LUStores port forwarding
    echo "Starting LUStores on http://localhost:8080"
    kubectl port-forward -n lustores service/app 8080:5000 --address=0.0.0.0 &
    LUSTORES_PID=$!
    
    # Start AtmosRay port forwarding  
    echo "Starting AtmosRay on http://localhost:8081"
    kubectl port-forward service/atmosray-service 8081:5000 --address=0.0.0.0 &
    ATMOSRAY_PID=$!
    
    echo ""
    echo "✅ Services accessible at:"
    echo "   🏪 LUStores: http://$(hostname -I | awk '{print $1}'):8080"
    echo "   🌤️  AtmosRay: http://$(hostname -I | awk '{print $1}'):8081"
    echo ""
    echo "Press Ctrl+C to stop all port forwarding..."
    
    # Wait for interrupt
    trap "echo ''; echo 'Stopping port forwarding...'; kill $LUSTORES_PID $ATMOSRAY_PID 2>/dev/null; exit 0" INT
    wait
else
    echo "💡 Run with --start-forwarding to automatically set up port forwarding"
    echo "   Example: $0 --start-forwarding"
fi

echo ""
echo "📋 Quick Status Check Commands:"
echo "   kubectl get pods -n lustores"
echo "   kubectl get pods -l app=atmosray"
echo "   kubectl get svc -n lustores"
echo "   kubectl get svc atmosray-service"
