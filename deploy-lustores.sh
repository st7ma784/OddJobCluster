#!/bin/bash

# LUStores Deployment Script for Kubernetes
# This script will deploy the LUStores system with proper secret management

set -e

NAMESPACE="lustores"
CONFIG_DIR="/tmp/lustores-config"

echo "🚀 Starting LUStores deployment..."

# Create config directory
mkdir -p $CONFIG_DIR

# Function to generate random secrets
generate_secret() {
    openssl rand -base64 32
}

# Function to base64 encode
b64encode() {
    echo -n "$1" | base64 -w 0
}

# Check if we should generate secrets or use provided ones
if [ "$1" = "--generate-secrets" ]; then
    echo "📝 Generating secure random secrets..."
    
    DB_PASSWORD=$(generate_secret)
    SESSION_SECRET=$(generate_secret)
    JWT_SECRET=$(generate_secret)
    DATABASE_URL="postgresql://postgres:${DB_PASSWORD}@db:5432/university_inventory"
    GITHUB_RUNNER_TOKEN="your-runner-token-here"  # This needs to be provided manually
    
    echo "Generated secrets:"
    echo "DB_PASSWORD: $DB_PASSWORD"
    echo "SESSION_SECRET: $SESSION_SECRET"
    echo "JWT_SECRET: $JWT_SECRET"
    echo "DATABASE_URL: $DATABASE_URL"
    echo "⚠️  GITHUB_RUNNER_TOKEN needs to be set manually"
    
elif [ -f ".env" ]; then
    echo "📄 Loading secrets from .env file..."
    source .env
else
    echo "❌ No secrets provided. Options:"
    echo "  1. Run with --generate-secrets to generate random secrets"
    echo "  2. Create a .env file with the required variables"
    echo "  3. Set environment variables manually"
    echo ""
    echo "Required environment variables:"
    echo "  DB_PASSWORD"
    echo "  SESSION_SECRET" 
    echo "  JWT_SECRET"
    echo "  DATABASE_URL"
    echo "  GITHUB_RUNNER_TOKEN"
    exit 1
fi

# Create namespace
echo "🏗️  Creating namespace..."
kubectl create namespace $NAMESPACE --dry-run=client -o yaml | kubectl apply -f -

# Create temporary manifest with secrets
echo "🔐 Creating secrets..."
cat > $CONFIG_DIR/lustores-secrets.yaml << EOF
apiVersion: v1
kind: Secret
metadata:
  name: db-secret
  namespace: $NAMESPACE
type: Opaque
data:
  password: $(b64encode "$DB_PASSWORD")

---

apiVersion: v1
kind: Secret
metadata:
  name: app-secret
  namespace: $NAMESPACE
type: Opaque
data:
  session-secret: $(b64encode "$SESSION_SECRET")
  jwt-secret: $(b64encode "$JWT_SECRET")
  database-url: $(b64encode "$DATABASE_URL")

---

apiVersion: v1
kind: Secret
metadata:
  name: github-runner-secret
  namespace: $NAMESPACE
type: Opaque
data:
  token: $(b64encode "$GITHUB_RUNNER_TOKEN")
EOF

# Apply secrets
kubectl apply -f $CONFIG_DIR/lustores-secrets.yaml

# Create storage directories on nodes
echo "💾 Creating storage directories..."
kubectl get nodes -o jsonpath='{.items[*].status.addresses[?(@.type=="InternalIP")].address}' | xargs -I {} ssh {} "sudo mkdir -p /db /mnt/data/redis && sudo chown -R 999:999 /db && sudo chown -R 999:999 /mnt/data/redis" 2>/dev/null || echo "⚠️  Could not create storage directories remotely, ensure they exist on nodes"

# Process and apply the main manifest
echo "🏗️  Processing main manifest..."
sed 's/<BASE64_ENCODED_PASSWORD>/# Replaced by secret/g; s/<BASE64_ENCODED_SESSION_SECRET>/# Replaced by secret/g; s/<BASE64_ENCODED_JWT_SECRET>/# Replaced by secret/g; s/<BASE64_ENCODED_DATABASE_URL>/# Replaced by secret/g; s/<BASE64_ENCODED_RUNNER_TOKEN>/# Replaced by secret/g' LUSTORE\$.yml > $CONFIG_DIR/lustores-manifest.yaml

# Apply the main manifest
echo "🚀 Deploying LUStores components..."
kubectl apply -f $CONFIG_DIR/lustores-manifest.yaml

# Wait for deployments to be ready
echo "⏳ Waiting for deployments to be ready..."
echo "Waiting for Redis..."
kubectl rollout status deployment/redis -n $NAMESPACE --timeout=300s

echo "Waiting for Database..."
kubectl rollout status deployment/db -n $NAMESPACE --timeout=300s

echo "Waiting for App..."
kubectl rollout status deployment/app -n $NAMESPACE --timeout=300s

echo "Waiting for Replit Auth..."
kubectl rollout status deployment/replit-auth -n $NAMESPACE --timeout=300s

echo "Waiting for Nginx..."
kubectl rollout status deployment/nginx -n $NAMESPACE --timeout=300s

# Get service information
echo "📊 Getting service information..."
kubectl get services -n $NAMESPACE

# Get external access information
NGINX_EXTERNAL_IP=$(kubectl get service nginx -n $NAMESPACE -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "Pending")
NGINX_NODE_PORT=$(kubectl get service nginx -n $NAMESPACE -o jsonpath='{.spec.ports[?(@.name=="http")].nodePort}' 2>/dev/null || echo "None")

echo ""
echo "✅ LUStores deployment completed!"
echo ""
echo "📊 Access Information:"
if [ "$NGINX_EXTERNAL_IP" != "Pending" ] && [ "$NGINX_EXTERNAL_IP" != "" ]; then
    echo "🌐 External Access: http://$NGINX_EXTERNAL_IP"
else
    if [ "$NGINX_NODE_PORT" != "None" ]; then
        NODE_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}')
        echo "🌐 NodePort Access: http://$NODE_IP:$NGINX_NODE_PORT"
    else
        echo "🌐 Use port-forward: kubectl port-forward -n $NAMESPACE service/nginx 8080:80"
        echo "   Then access: http://localhost:8080"
    fi
fi

echo ""
echo "🔧 Useful commands:"
echo "kubectl get pods -n $NAMESPACE"
echo "kubectl logs -f -n $NAMESPACE deployment/app"
echo "kubectl port-forward -n $NAMESPACE service/nginx 8080:80"

# Clean up temporary files
rm -rf $CONFIG_DIR

echo ""
echo "🎉 LUStores is now running!"
