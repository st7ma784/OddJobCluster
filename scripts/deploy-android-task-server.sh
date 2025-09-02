#!/bin/bash
# Deploy Android Task Server to Kubernetes

set -e

echo "🚀 Deploying Android Task Server to Kubernetes..."

# Apply the ConfigMap first
echo "📦 Creating ConfigMap with server code..."
kubectl apply -f /home/user/ansible/CascadeProjects/windsurf-project/kubernetes/manifests/android-task-server-config.yaml

# Apply the main deployment
echo "🚢 Deploying Android Task Server..."
kubectl apply -f /home/user/ansible/CascadeProjects/windsurf-project/kubernetes/manifests/android-task-server.yaml

# Wait for deployment to be ready
echo "⏳ Waiting for deployment to be ready..."
kubectl wait --for=condition=available --timeout=300s deployment/android-task-server -n android-cluster

# Get service information
echo "📊 Service information:"
kubectl get services -n android-cluster
echo ""
echo "🌐 Access points:"
echo "  WebSocket: ws://<node-ip>:30765"
echo "  HTTP API: http://<node-ip>:30766"
echo "  Dashboard: http://<node-ip>:30766"
echo ""
echo "📝 API Endpoints:"
echo "  POST /submit_task - Submit custom tasks"
echo "  GET /status - Get cluster status"
echo "  GET /tasks - List all tasks"
echo "  GET /task/{task_id} - Get specific task status"
echo ""
echo "✅ Android Task Server deployed successfully!"
