#!/bin/bash

# Camera Device Verification Script for Kubernetes Nodes
# Checks camera availability, permissions, and container compatibility

echo "🎥 CAMERA DEVICE VERIFICATION FOR KUBERNETES CLUSTER"
echo "===================================================="
echo ""

# Set kubeconfig
export KUBECONFIG="./AtmosRay/Kubernetes Demo/kubeconfig"

# Check if kubectl is available
if ! command -v kubectl &> /dev/null; then
    echo "❌ kubectl not found"
    exit 1
fi

echo "📋 CLUSTER OVERVIEW:"
echo "==================="
kubectl get nodes -o wide
echo ""

# Define camera test function for each node
test_camera_on_node() {
    local node_name=$1
    local node_ip=$2
    
    echo "🎥 Testing camera capabilities on: $node_name ($node_ip)"
    echo "--------------------------------------------------------"
    
    # Create a debug pod to test camera access
    cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: camera-test-${node_name,,}
  namespace: default
spec:
  nodeSelector:
    kubernetes.io/hostname: $node_name
  containers:
  - name: camera-test
    image: ubuntu:22.04
    command: ["/bin/bash", "-c", "sleep 3600"]
    securityContext:
      privileged: true
    volumeMounts:
    - name: dev
      mountPath: /dev
    - name: sys
      mountPath: /sys
  volumes:
  - name: dev
    hostPath:
      path: /dev
  - name: sys
    hostPath:
      path: /sys
  restartPolicy: Never
  tolerations:
  - operator: Exists
EOF

    # Wait for pod to be ready
    echo "⏳ Waiting for camera test pod to start..."
    kubectl wait --for=condition=Ready pod/camera-test-${node_name,,} --timeout=60s
    
    if [ $? -eq 0 ]; then
        echo "✅ Pod started successfully on $node_name"
        
        # Test camera device detection
        echo "🔍 Checking for camera devices..."
        kubectl exec camera-test-${node_name,,} -- bash -c "apt-get update -qq && apt-get install -y v4l-utils > /dev/null 2>&1"
        
        # List video devices
        echo "📹 Video devices found:"
        kubectl exec camera-test-${node_name,,} -- ls -la /dev/video* 2>/dev/null || echo "❌ No video devices found"
        
        # Check v4l2 capabilities if devices exist
        kubectl exec camera-test-${node_name,,} -- bash -c "
            if ls /dev/video* >/dev/null 2>&1; then
                echo '📊 Camera capabilities:'
                for device in /dev/video*; do
                    echo '  Device: \$device'
                    v4l2-ctl --device=\$device --info 2>/dev/null || echo '    ❌ Cannot access device'
                    v4l2-ctl --device=\$device --list-formats 2>/dev/null || echo '    ❌ Cannot list formats'
                done
            else
                echo '❌ No video devices available for testing'
            fi
        "
        
        # Test basic permissions
        echo "🔐 Testing device permissions..."
        kubectl exec camera-test-${node_name,,} -- bash -c "
            if ls /dev/video* >/dev/null 2>&1; then
                for device in /dev/video*; do
                    echo '  Testing \$device:'
                    if [ -r \$device ]; then
                        echo '    ✅ Read permission OK'
                    else
                        echo '    ❌ No read permission'
                    fi
                    if [ -w \$device ]; then
                        echo '    ✅ Write permission OK'
                    else
                        echo '    ❌ No write permission'
                    fi
                done
            fi
        "
        
        # Check for USB cameras
        echo "🔌 USB camera detection:"
        kubectl exec camera-test-${node_name,,} -- lsusb | grep -i camera || echo "❌ No USB cameras detected"
        kubectl exec camera-test-${node_name,,} -- lsusb | grep -i video || echo "❌ No USB video devices detected"
        
        # Check kernel modules
        echo "🔧 Camera-related kernel modules:"
        kubectl exec camera-test-${node_name,,} -- bash -c "
            echo '  Video modules:'
            lsmod | grep -E 'uvcvideo|v4l2|videodev' || echo '    ❌ No video modules loaded'
            echo '  USB modules:'
            lsmod | grep -E 'usb.*video|uvc' || echo '    ❌ No USB video modules'
        "
        
    else
        echo "❌ Failed to start camera test pod on $node_name"
    fi
    
    # Cleanup
    kubectl delete pod camera-test-${node_name,,} --ignore-not-found=true
    echo ""
}

# Test each ready node
echo "🚀 STARTING CAMERA TESTS ON ALL READY NODES:"
echo "============================================="

# Get list of ready nodes
ready_nodes=$(kubectl get nodes --no-headers | grep " Ready " | awk '{print $1}')

for node in $ready_nodes; do
    node_ip=$(kubectl get node $node -o jsonpath='{.status.addresses[?(@.type=="InternalIP")].address}')
    test_camera_on_node "$node" "$node_ip"
done

echo "📊 CAMERA VERIFICATION SUMMARY:"
echo "==============================="
echo "Test completed for all ready nodes."
echo ""
echo "🎯 NEXT STEPS:"
echo "=============="
echo "1. Review camera device availability on each node"
echo "2. Install required camera drivers if missing"
echo "3. Configure proper device permissions"
echo "4. Update intruder detection deployment with correct node selectors"
echo ""
echo "💡 RECOMMENDATIONS:"
echo "==================="
echo "• For nodes with cameras: Use them for intruder detection"
echo "• For nodes without cameras: Use demo mode or webcam simulation"
echo "• Consider USB camera installation for nodes without built-in cameras"
echo ""
