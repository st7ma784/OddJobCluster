#!/bin/bash

# Node Investigation and Addition Script
echo "🔍 Investigating Missing Node at 192.168.4.31"
echo "=============================================="

echo "📡 Current network interfaces:"
ip addr show | grep -E "inet.*192\.168\."

echo ""
echo "🗺️  Network topology scan:"
echo "Scanning 192.168.4.0/24 subnet:"
nmap -sn 192.168.4.0/24 | grep -E "(Nmap|Host)"

echo ""
echo "Scanning 192.168.5.0/24 subnet:"  
nmap -sn 192.168.5.0/24 | grep -E "(Nmap|Host)"

echo ""
echo "🔍 Current Kubernetes nodes:"
export KUBECONFIG="/home/user/ansible/CascadeProjects/windsurf-project/AtmosRay/Kubernetes Demo/kubeconfig"
kubectl get nodes -o wide

echo ""
echo "📋 Expected nodes from Ansible configuration:"
echo "1. steve-IdeaPad-Flex-5-15ALC05 - 192.168.4.157 (master)"
echo "2. steve-ThinkPad-L490 - 192.168.5.57 (worker)"  
echo "3. steve-thinkpad-l490-node1 - 192.168.4.31 (worker) ❌ MISSING"

echo ""
echo "🔧 Checking if node is SSH accessible:"
ssh -o ConnectTimeout=5 -o BatchMode=yes user@192.168.4.31 "hostname && kubectl version --client" 2>/dev/null && echo "✅ SSH accessible" || echo "❌ SSH not accessible"

echo ""
echo "🏥 Cluster health check:"
kubectl get pods --all-namespaces | grep -E "(NotReady|CrashLoop|Error|Pending)"

echo ""
echo "📊 Services that need external access:"
kubectl get services --all-namespaces -o wide | grep -E "(LoadBalancer|NodePort)"

echo ""
echo "🎯 Recommendations:"
echo "1. If 192.168.4.31 is a physical machine, ensure it's powered on and network connected"
echo "2. If it's a VM, check hypervisor network configuration"  
echo "3. Verify firewall settings on all subnets"
echo "4. Use NodePort services for external access instead of LoadBalancer"
echo "5. Set up ingress controller for unified web access"
