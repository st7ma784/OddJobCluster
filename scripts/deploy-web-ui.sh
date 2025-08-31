#!/bin/bash

# Deploy Cluster Web UI Script
# Sets up lightweight web dashboard as default index page

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
WEB_ROOT="/var/www/html"
NGINX_AVAILABLE="/etc/nginx/sites-available"
NGINX_ENABLED="/etc/nginx/sites-enabled"

echo "🚀 Deploying Cluster Web UI Dashboard"
echo "======================================"

# Function to deploy on a node
deploy_to_node() {
    local node_ip=$1
    local node_name=$2
    
    echo "📡 Deploying to $node_name ($node_ip)..."
    
    # Install nginx if not present
    ssh -i ~/.ssh/cluster_key ansible@$node_ip "
        sudo apt update -qq
        sudo apt install -y nginx
        sudo systemctl enable nginx
    "
    
    # Create web directory and copy dashboard
    ssh -i ~/.ssh/cluster_key ansible@$node_ip "
        sudo mkdir -p $WEB_ROOT
        sudo chown -R www-data:www-data $WEB_ROOT
    "
    
    # Copy the dashboard HTML
    scp -i ~/.ssh/cluster_key "$PROJECT_DIR/cluster-dashboard.html" ansible@$node_ip:/tmp/
    ssh -i ~/.ssh/cluster_key ansible@$node_ip "
        sudo cp /tmp/cluster-dashboard.html $WEB_ROOT/index.html
        sudo chown www-data:www-data $WEB_ROOT/index.html
        sudo chmod 644 $WEB_ROOT/index.html
    "
    
    # Configure nginx
    ssh -i ~/.ssh/cluster_key ansible@$node_ip "
        sudo tee $NGINX_AVAILABLE/cluster-dashboard > /dev/null << 'EOF'
server {
    listen 80 default_server;
    listen [::]:80 default_server;
    
    root $WEB_ROOT;
    index index.html;
    server_name _;
    
    location / {
        try_files \$uri \$uri/ =404;
        add_header Cache-Control 'no-cache, no-store, must-revalidate';
        add_header Pragma 'no-cache';
        add_header Expires '0';
    }
    
    # API proxy endpoints for future use
    location /api/slurm/ {
        proxy_pass http://localhost:8080/;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
    }
    
    location /api/k8s/ {
        proxy_pass https://localhost:6443/;
        proxy_ssl_verify off;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
    }
}
EOF
    "
    
    # Enable the site
    ssh -i ~/.ssh/cluster_key ansible@$node_ip "
        sudo rm -f $NGINX_ENABLED/default
        sudo ln -sf $NGINX_AVAILABLE/cluster-dashboard $NGINX_ENABLED/
        sudo nginx -t
        sudo systemctl restart nginx
        sudo systemctl status nginx --no-pager -l
    "
    
    echo "✅ Web UI deployed to $node_name at http://$node_ip/"
}

# Deploy to control plane node
echo "🎯 Deploying to control plane node..."
deploy_to_node "192.168.5.57" "steve-thinkpad-l490"

# Deploy to worker node
echo "🎯 Deploying to worker node..."
deploy_to_node "192.168.4.157" "steve-ideapad-flex-5-15alc05"

# Test the deployments
echo ""
echo "🧪 Testing deployments..."
echo "Control plane: http://192.168.5.57/"
curl -s -o /dev/null -w "Status: %{http_code}\n" http://192.168.5.57/ || echo "❌ Control plane web UI not accessible"

echo "Worker node: http://192.168.4.157/"
curl -s -o /dev/null -w "Status: %{http_code}\n" http://192.168.4.157/ || echo "❌ Worker node web UI not accessible"

echo ""
echo "🎉 Cluster Web UI Deployment Complete!"
echo "======================================"
echo "📊 Access Points:"
echo "   • Control Plane: http://192.168.5.57/"
echo "   • Worker Node:   http://192.168.4.157/"
echo "   • JupyterHub:    http://192.168.5.57:8000/"
echo ""
echo "🔧 Management Features:"
echo "   • Real-time cluster monitoring"
echo "   • SLURM job queue management"
echo "   • Kubernetes pod monitoring"
echo "   • Node status and resource usage"
echo "   • One-click cluster repair tools"
echo ""
echo "📋 Next Steps:"
echo "   • Open http://192.168.5.57/ in your browser"
echo "   • Use the management console for cluster operations"
echo "   • Run health checks and monitor resources"
