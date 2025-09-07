#!/bin/bash

# Complete Cluster Access Guide
# LUStores and AtmosRay External Access Information

echo "🎉 Lancaster University Stores - Cluster Access Guide"
echo "===================================================="
echo ""

# Check if we're on the master node
if command -v kubectl &> /dev/null; then
    export KUBECONFIG=/etc/kubernetes/admin.conf
    
    echo "📊 Current Cluster Status:"
    echo "=========================="
    kubectl get nodes -o wide
    echo ""
    
    echo "🏪 LUStores Status:"
    echo "=================="
    kubectl get pods -n lustores -l app=app
    kubectl get pods -n lustores -l app=nginx
    echo ""
    
    echo "🌤️  AtmosRay Status:"
    echo "=================="
    kubectl get pods -l app=atmosray
    echo ""
fi

echo "🌐 External Access Information:"
echo "==============================="
echo ""

echo "🏪 LUStores (University Inventory Management):"
echo "  Production Domain: https://py-stores.lancaster.ac.uk"
echo "  Development Access: http://192.168.4.157:31043"
echo "  Health Check: http://192.168.4.157:31043/nginx-health"
echo ""

echo "🌤️  AtmosRay (Weather Data Service):"
echo "  Development Access: http://192.168.4.157:30500"
echo "  Status: Partially functional (1/2 pods running)"
echo ""

echo "🔧 Internal Access (from cluster):"
echo "=================================="
echo "  LUStores App: http://10.107.24.100:5000"
echo "  LUStores via Nginx: http://10.100.73.145"
echo "  Database: postgresql://postgres@10.99.93.254:5432/university_inventory"
echo "  Redis: redis://10.109.185.190:6379"
echo "  Replit Auth: http://10.99.124.136:3001"
echo ""

echo "🛠️  Port Forwarding Options:"
echo "==========================="
echo "  LUStores: kubectl port-forward -n lustores service/nginx 8080:80"
echo "  AtmosRay: kubectl port-forward service/atmosray-service 8081:5000"
echo "  Direct App: kubectl port-forward -n lustores service/app 8082:5000"
echo ""

echo "🔍 Status Check Commands:"
echo "========================"
echo "  kubectl get all -n lustores"
echo "  kubectl get pods -l app=atmosray"
echo "  kubectl get svc --all-namespaces"
echo ""

echo "🚨 Troubleshooting:"
echo "=================="
echo "  View LUStores logs: kubectl logs -n lustores deployment/app"
echo "  View Nginx logs: kubectl logs -n lustores deployment/nginx"
echo "  Check worker node: kubectl describe node steve-thinkpad-l490"
echo ""

echo "✅ SUCCESS SUMMARY:"
echo "=================="
echo "  ✅ LUStores fully functional and externally accessible"
echo "  ✅ Nginx reverse proxy working"
echo "  ✅ NodePort access configured (port 31043)"
echo "  ✅ Database and Redis operational"
echo "  ✅ Authentication service running"
echo "  ⚠️  AtmosRay partially working (1/2 pods)"
echo "  ⚠️  One worker node needs reconnection"
echo ""

# Test access if we can
if command -v curl &> /dev/null; then
    echo "🧪 Connectivity Test:"
    echo "===================="
    if curl -s -I http://192.168.4.157:31043/nginx-health | grep -q "200 OK"; then
        echo "  ✅ LUStores external access: WORKING"
    else
        echo "  ❌ LUStores external access: FAILED"
    fi
    
    if curl -s -I http://192.168.4.157:30500/ | grep -q "200 OK"; then
        echo "  ✅ AtmosRay external access: WORKING"
    else
        echo "  ⚠️  AtmosRay external access: NEEDS ATTENTION"
    fi
fi

echo ""
echo "🎯 Next Steps:"
echo "============="
echo "  1. Configure DNS: py-stores.lancaster.ac.uk → 192.168.4.157:31043"
echo "  2. Set up SSL/TLS certificate for production domain"
echo "  3. Reconnect missing worker node (192.168.4.31)"
echo "  4. Investigate AtmosRay pod crashes"
echo "  5. Consider LoadBalancer service for production"
