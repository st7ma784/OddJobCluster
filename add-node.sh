#!/bin/bash

# Script to add steve-thinkpad-l490-node1 to the cluster
echo "🔧 Adding node steve-thinkpad-l490-node1 (192.168.4.31) to Kubernetes cluster"

# SSH and run the join command
sshpass -p 'password' ssh -o StrictHostKeyChecking=no steve@192.168.4.31 << 'EOF'
# Join the cluster
echo 'password' | sudo -S kubeadm join 192.168.4.157:6443 --token m0cr3w.hlozv7nuhb3ufxcl --discovery-token-ca-cert-hash sha256:b07498d5977e3d91474bf2c717780f8491a242d3aa8f26a80bfda85a296d4a8b

# Verify kubelet is running
echo 'password' | sudo -S systemctl enable kubelet
echo 'password' | sudo -S systemctl start kubelet
echo 'password' | sudo -S systemctl status kubelet
EOF

echo "✅ Node addition attempt completed"
