# Android Cluster Deployment Guide

## Overview

This guide covers the complete deployment process for integrating Android devices into your Kubernetes and SLURM clusters, creating a unified heterogeneous compute environment.

## Prerequisites

### Infrastructure Requirements
- Kubernetes cluster (v1.28+) with at least one node
- SLURM workload manager with MUNGE authentication
- Network connectivity between all components
- Docker registry access (optional but recommended)

### Android Device Requirements
- Android 7.0+ (API level 24+)
- ARM64 architecture (recommended)
- 2GB+ RAM available
- WiFi connectivity to cluster network
- Developer options enabled (for APK installation)

## Deployment Steps

### 1. Deploy Android Task Server to Kubernetes

#### Quick Deployment
```bash
# Navigate to project directory
cd /home/user/ansible/CascadeProjects/windsurf-project

# Deploy using the automated script
./scripts/deploy-android-task-server.sh
```

#### Manual Deployment
```bash
# Create the namespace and ConfigMap
kubectl apply -f kubernetes/manifests/android-task-server-config.yaml

# Deploy the task server
kubectl apply -f kubernetes/manifests/android-task-server.yaml

# Verify deployment
kubectl get pods -n android-cluster
kubectl get services -n android-cluster
```

### 2. Install Android Cluster App

#### Build from Source
```bash
# Navigate to Android project
cd android-cluster-node

# Build the APK
./gradlew assembleDebug

# Install on device via ADB
adb install app/build/outputs/apk/debug/app-debug.apk
```

#### Direct Installation
1. Transfer the APK to your Android device
2. Enable "Install from unknown sources" in device settings
3. Install the APK file

### 3. Configure Android Devices

#### Initial Setup
1. Open the Android Cluster app
2. Configure cluster URL: `ws://<your-cluster-ip>:8765`
3. Enable the cluster service toggle
4. Wait for connection confirmation

#### Install Prerequisites (Automatic)
The app will automatically:
1. Check for Termux installation
2. Install Termux if not present
3. Configure the Linux environment
4. Install required tools (kubectl, SLURM clients)

### 4. Verify Integration

#### Check Cluster Status
```bash
# View cluster status via API
curl http://<cluster-ip>:8766/status

# Check Kubernetes nodes
kubectl get nodes

# Check SLURM nodes
sinfo -N
```

#### Test Task Submission
```bash
# Submit a test task via API
curl -X POST http://<cluster-ip>:8766/submit_task \
  -H "Content-Type: application/json" \
  -d '{
    "task_type": "prime_calculation",
    "data": {"start": 1, "end": 1000},
    "priority": 2
  }'
```

## Configuration Options

### Cluster Coordinator Settings
Edit `cluster-coordinator/server.py` to customize:

```python
# WebSocket server port
WS_PORT = 8765

# HTTP API port
HTTP_PORT = 8766

# Task queue settings
MAX_QUEUE_SIZE = 1000
DEFAULT_PRIORITY = 1

# Auto-registration settings
AUTO_REGISTER_KUBERNETES = True
AUTO_REGISTER_SLURM = True
```

### Android App Configuration
Modify `android-cluster-node/app/src/main/java/com/cluster/node/MainActivity.kt`:

```kotlin
// Default cluster URL
private val DEFAULT_CLUSTER_URL = "ws://192.168.1.100:8765"

// Connection timeout
private val CONNECTION_TIMEOUT = 30000

// Heartbeat interval
private val HEARTBEAT_INTERVAL = 5000
```

### Kubernetes Deployment Configuration
Customize `kubernetes/manifests/android-task-server.yaml`:

```yaml
# Resource limits
resources:
  requests:
    cpu: 100m
    memory: 256Mi
  limits:
    cpu: 500m
    memory: 512Mi

# Replica count
replicas: 1

# NodePort configuration
nodePort: 30766
```

## Network Configuration

### Firewall Rules
Ensure these ports are accessible:

```bash
# WebSocket connections (Android devices)
sudo ufw allow 8765/tcp

# HTTP API and dashboard
sudo ufw allow 8766/tcp

# Kubernetes NodePorts
sudo ufw allow 30765/tcp
sudo ufw allow 30766/tcp

# SLURM communication
sudo ufw allow 6817/tcp  # slurmctld
sudo ufw allow 6818/tcp  # slurmd
```

### DNS Configuration
For easier access, configure DNS entries:

```bash
# Add to /etc/hosts or DNS server
192.168.1.100  android-cluster.local
192.168.1.100  k8s-cluster.local
```

## Monitoring and Troubleshooting

### Access Web Dashboard
Navigate to: `http://<cluster-ip>:8766`

The dashboard provides:
- Real-time cluster status
- Node connectivity monitoring
- Task queue visualization
- Performance metrics
- Custom task submission interface

### Log Monitoring
```bash
# Kubernetes logs
kubectl logs -f deployment/android-task-server -n android-cluster

# SLURM logs
sudo journalctl -u slurmctld -f
sudo journalctl -u slurmd -f

# System logs
sudo journalctl -u kubelet -f
```

### Common Issues

#### Android Connection Problems
```bash
# Check network connectivity
ping <cluster-ip>

# Verify WebSocket port
telnet <cluster-ip> 8765

# Check firewall rules
sudo ufw status
```

#### Kubernetes Registration Issues
```bash
# Check node status
kubectl get nodes -o wide

# Verify RBAC permissions
kubectl auth can-i create nodes

# Check cluster connectivity
kubectl cluster-info
```

#### SLURM Integration Problems
```bash
# Test MUNGE authentication
echo "test" | munge | unmunge

# Check SLURM daemon status
systemctl status slurmctld
systemctl status slurmd

# Verify node registration
scontrol show nodes
```

## Performance Optimization

### Android Device Optimization
1. **Disable battery optimization** for the cluster app
2. **Keep WiFi always on** during sleep
3. **Close unnecessary apps** to free resources
4. **Enable developer options** for better performance monitoring

### Cluster Optimization
```bash
# Increase task queue size
# Edit server.py
MAX_QUEUE_SIZE = 5000

# Optimize WebSocket connections
# Increase connection limits
ulimit -n 65536

# Tune Kubernetes scheduler
# Add Android node preferences
kubectl patch deployment android-task-server -p '
{
  "spec": {
    "template": {
      "spec": {
        "affinity": {
          "nodeAffinity": {
            "preferredDuringSchedulingIgnoredDuringExecution": [
              {
                "weight": 100,
                "preference": {
                  "matchExpressions": [
                    {
                      "key": "node-type",
                      "operator": "In",
                      "values": ["android"]
                    }
                  ]
                }
              }
            ]
          }
        }
      }
    }
  }
}'
```

## Security Considerations

### Network Security
- Use VPN for remote Android device connections
- Implement TLS/SSL for production deployments
- Configure network policies for pod isolation

### Authentication
```bash
# Enable RBAC for Kubernetes
kubectl create clusterrolebinding android-cluster-admin \
  --clusterrole=cluster-admin \
  --serviceaccount=android-cluster:default

# Configure MUNGE keys securely
sudo chmod 400 /etc/munge/munge.key
sudo chown munge:munge /etc/munge/munge.key
```

### Access Control
- Implement API authentication for production
- Use service accounts for Kubernetes access
- Configure SLURM user permissions appropriately

## Scaling Considerations

### Horizontal Scaling
- **Android devices**: Add unlimited devices by installing the app
- **Kubernetes workers**: Standard cluster expansion procedures
- **SLURM compute nodes**: Traditional HPC scaling methods

### Load Balancing
```bash
# Deploy multiple task server replicas
kubectl scale deployment android-task-server --replicas=3 -n android-cluster

# Configure load balancer service
kubectl expose deployment android-task-server \
  --type=LoadBalancer \
  --port=8766 \
  --target-port=8766 \
  -n android-cluster
```

## Backup and Recovery

### Configuration Backup
```bash
# Backup Kubernetes manifests
kubectl get all -n android-cluster -o yaml > android-cluster-backup.yaml

# Backup SLURM configuration
sudo cp -r /etc/slurm /backup/slurm-config-$(date +%Y%m%d)

# Backup MUNGE keys
sudo cp /etc/munge/munge.key /backup/munge-key-$(date +%Y%m%d)
```

### Disaster Recovery
```bash
# Restore from backup
kubectl apply -f android-cluster-backup.yaml

# Restore SLURM configuration
sudo cp -r /backup/slurm-config-latest/* /etc/slurm/
sudo systemctl restart slurmctld slurmd

# Restore MUNGE keys
sudo cp /backup/munge-key-latest /etc/munge/munge.key
sudo systemctl restart munge
```

## Next Steps

After successful deployment:

1. **Monitor performance** using the web dashboard
2. **Submit test workloads** to verify functionality
3. **Scale the cluster** by adding more Android devices
4. **Implement monitoring** with Prometheus/Grafana
5. **Set up automated backups** for critical configurations
6. **Configure alerting** for cluster health monitoring

For advanced configuration and troubleshooting, refer to:
- [Architecture Documentation](../ARCHITECTURE.md)
- [API Reference](../api/android-cluster.md)
- [Troubleshooting Guide](troubleshooting-network.md)
