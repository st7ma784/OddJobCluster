#!/bin/bash

PI_IP="${1:-192.168.4.186}"
PI_USER="${2:-pi}"

echo "🔧 Raspberry Pi Cluster Setup Script"
echo "===================================="
echo "Target: $PI_USER@$PI_IP"
echo ""

# Test connectivity first
echo "1. Testing connectivity..."
if ping -c 2 "$PI_IP" > /dev/null 2>&1; then
    echo "✅ Pi is reachable at $PI_IP"
else
    echo "❌ Pi not reachable at $PI_IP"
    echo "Please check:"
    echo "  - Pi is powered on"
    echo "  - Network connection is active"
    echo "  - IP address is correct"
    exit 1
fi

# Test SSH
echo "2. Testing SSH connection..."
if timeout 5 ssh -o ConnectTimeout=5 -o BatchMode=yes "$PI_USER@$PI_IP" exit 2>/dev/null; then
    echo "✅ SSH connection successful"
else
    echo "❌ SSH connection failed"
    echo "Please ensure:"
    echo "  - SSH is enabled on Pi"
    echo "  - Correct username ($PI_USER)"
    echo "  - SSH keys are set up or password authentication is enabled"
    exit 1
fi

echo ""
echo "3. Ready to add Pi to cluster! Run these commands:"
echo ""
echo "# Update inventory with correct Pi IP:"
echo "sed -i 's/192.168.4.186/$PI_IP/g' ansible/inventory.ini"
echo ""
echo "# Run the Pi setup playbook:"
echo "ansible-playbook -i ansible/inventory.ini ansible/setup-rpi-worker.yml"
echo ""
echo "# Join Pi to cluster (get join command from master):"
echo "ansible master -i ansible/inventory_working.ini -m shell -a 'export KUBECONFIG=/etc/kubernetes/admin.conf && kubeadm token create --print-join-command' --become"
