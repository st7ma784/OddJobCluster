#!/bin/bash

# 🎯 COMPREHENSIVE SERVICE ACCESS GUIDE
# =====================================
echo "🌐 Kubernetes Cluster - All Services Access Guide"
echo "=================================================="

echo ""
echo "✅ FIXES COMPLETED:"
echo "• AtmosRay deployment scaled down: 2 → 1 replica"
echo "• Ingress configurations deployed for all services"
echo "• NodePort services configured for direct access"
echo ""

echo "🔗 DIRECT ACCESS URLs (NodePort):"
echo "================================="

echo ""
echo "🛍️  LUStores E-commerce Platform:"
echo "   URL: http://192.168.4.157:31080"
echo "   Alternative: http://192.168.5.57:31080"
echo "   Features: Product catalog, shopping cart, user auth"
echo "   Status: ✅ WORKING"

echo ""
echo "🌊 Radio Propagation System:"
echo "   URL: http://192.168.4.157:31082"
echo "   Alternative: http://192.168.5.57:31082"
echo "   Features: Signal monitoring, TX/RX simulation"
echo "   Status: ⚠️  Needs service restart"

echo ""
echo "🌍 Atmospheric Simulator:"
echo "   URL: http://192.168.4.157:31081"
echo "   Alternative: http://192.168.5.57:31081"
echo "   Features: Weather modeling, solar flux data"
echo "   Status: ⚠️  Needs debugging"

echo ""
echo "🎥 Intruder Detection System:"
echo "   URL: http://192.168.4.157:30080"
echo "   Alternative: http://192.168.5.57:30080"
echo "   Features: Camera monitoring, motion detection"
echo "   Node: steve-thinkpad-l490 (camera equipped)"
echo "   Status: ⚠️  Pod crashing"

echo ""
echo "🌟 AtmosRay Legacy System:"
echo "   URL: http://192.168.4.157:30500"
echo "   Alternative: http://192.168.5.57:30500"
echo "   Features: Original radio propagation interface"
echo "   Replicas: ✅ Fixed (2 → 1)"

echo ""
echo "📊 Kubernetes Dashboard:"
echo "   Method 1: kubectl port-forward"
echo "   Method 2: https://192.168.4.157:6443/api/v1/namespaces/kubernetes-dashboard/services/https:kubernetes-dashboard:/proxy/"
echo "   Status: ✅ Available"

echo ""
echo "=================================================="
echo ""

echo "🌐 INGRESS ACCESS (when controller is ready):"
echo "=============================================="

echo ""
echo "Main Domain: cluster.local (add to /etc/hosts)"
echo "IP: 192.168.4.157  cluster.local"
echo "IP: 192.168.4.157  shop.cluster.local"

echo ""
echo "🔗 Ingress URLs:"
echo "• LUStores:     http://cluster.local:30880/lustores/"
echo "• Radio:        http://cluster.local:30880/radio/"
echo "• AtmosRay:     http://cluster.local:30880/atmosray/"
echo "• Security:     http://cluster.local:30880/security/"
echo "• Weather:      http://cluster.local:30880/weather/"
echo "• Shop Only:    http://shop.cluster.local:30880/"

echo ""
echo "=================================================="
echo ""

echo "🔧 CLUSTER STATUS CHECK:"
echo "========================"

export KUBECONFIG="/home/user/ansible/CascadeProjects/windsurf-project/AtmosRay/Kubernetes Demo/kubeconfig"

echo ""
echo "📋 Nodes:"
kubectl get nodes

echo ""
echo "📦 AtmosRay Status:"
kubectl get deployment atmosray-deployment -o wide

echo ""
echo "🌐 All Services:"
kubectl get services --all-namespaces | grep -E "(NodePort|LoadBalancer)"

echo ""
echo "🎯 Ingress Status:"
kubectl get ingress --all-namespaces

echo ""
echo "=================================================="
echo ""

echo "🚀 QUICK TESTS:"
echo "==============="

echo ""
echo "Test LUStores (should return HTTP 200):"
echo "curl -I http://192.168.4.157:31080"

echo ""
echo "Test AtmosRay Legacy:"
echo "curl -I http://192.168.4.157:30500"

echo ""
echo "Add to /etc/hosts for ingress:"
echo "echo '192.168.4.157 cluster.local shop.cluster.local' | sudo tee -a /etc/hosts"

echo ""
echo "=================================================="
echo ""

echo "✅ SUMMARY:"
echo "• AtmosRay: ✅ Scaled from 2 to 1 replica"
echo "• Ingress: ✅ Comprehensive rules deployed"  
echo "• NodePort: ✅ Direct access available"
echo "• LUStores: ✅ Working via NodePort"
echo "• Missing Node: ⚠️  Still investigating 192.168.4.31"

echo ""
echo "🎯 Next: Test the NodePort URLs above!"
