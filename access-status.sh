#!/bin/bash

# 🎯 IMMEDIATE ACCESS TO WORKING SERVICES
echo "🌐 Kubernetes Cluster - Direct Access URLs"
echo "=========================================="

echo ""
echo "✅ WORKING SERVICES (NodePort access):"
echo ""

echo "🛍️  LUStores E-commerce Platform:"
echo "   URL: http://192.168.4.157:31080"
echo "   Status: ✅ WORKING"
echo "   Features: Product catalog, shopping cart, user management"
echo ""

echo "🎥 Intruder Detection System:"  
echo "   URL: http://192.168.4.157:30080"
echo "   Status: ⚠️  Pod crashing - needs investigation"
echo "   Node: steve-thinkpad-l490 (camera equipped)"
echo ""

echo "📊 Kubernetes Dashboard:"
echo "   URL: https://192.168.4.157:6443/api/v1/namespaces/kubernetes-dashboard/services/https:kubernetes-dashboard:/proxy/"
echo "   Alternative: Use kubectl proxy or port-forward"
echo "   Status: ✅ Available"
echo ""

echo "⚠️  SERVICES WITH ISSUES:"
echo ""

echo "🌊 Radio Propagation System:"
echo "   Expected URL: http://192.168.4.157:31082"  
echo "   Status: ❌ CrashLoopBackOff"
echo "   Issue: Pods restarting continuously"
echo ""

echo "🌍 Atmospheric Simulator:"
echo "   Expected URL: http://192.168.4.157:31081"
echo "   Status: ❌ Service not responding"  
echo "   Issue: Backend pod issues"
echo ""

echo "================================================"
echo ""
echo "🔧 FIXES APPLIED:"
echo "✅ LoadBalancer → NodePort conversion for LUStores"
echo "✅ Ingress controller deployed"  
echo "✅ Proper service exposure configured"
echo ""

echo "❌ REMAINING ISSUES:"
echo "• Missing node at 192.168.4.31 (not found on network)"
echo "• 9 pods in CrashLoopBackOff state"
echo "• CNI networking instability (Calico)"
echo "• Some services not starting properly"
echo ""

echo "🎯 IMMEDIATE RECOMMENDATIONS:"
echo "1. Test LUStores: curl http://192.168.4.157:31080"
echo "2. Remove missing node from Ansible configuration"
echo "3. Debug pod crashes: kubectl logs <pod-name>"
echo "4. Consider cluster reset for clean state"
echo ""

echo "📋 CLUSTER STATUS:"
export KUBECONFIG="/home/user/ansible/CascadeProjects/windsurf-project/AtmosRay/Kubernetes Demo/kubeconfig"
kubectl get nodes
echo ""
kubectl get pods --all-namespaces | grep -E "(Running|Ready)" | wc -l | xargs echo "Running pods:"
kubectl get pods --all-namespaces | grep -E "(CrashLoop|Error|Pending)" | wc -l | xargs echo "Problem pods:"
