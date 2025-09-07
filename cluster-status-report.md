# Cluster Status Report

## Current Configuration

### Cluster Nodes
- **Master Node (cluster-head)**: 192.168.4.157 - Ready ✅
  - Role: control-plane
  - Version: v1.28.15
  - OS: Ubuntu 25.04
  - Runtime: containerd://1.7.27

- **Worker Node 1 (steve-thinkpad-l490)**: 192.168.5.57 - Ready ✅
  - Role: worker
  - Version: v1.28.15
  - OS: Ubuntu 25.04
  - Runtime: containerd://1.7.27

- **Worker Node 2 (cluster-node-1)**: 192.168.4.31 - Offline ❌
  - Status: Recently came back online but failed to rejoin
  - Issue: kubelet configuration problems

- **Potential Worker Node 3 (scc-ws-01)**: 10.48.240.32 - Pending ⏳
  - Status: Kubernetes components installed, ready for join process
  - Issue: Similar kubelet configuration problems

## Services Status

### LUStores System (Lancaster University Inventory) - Production Ready ✅
- **Database**: PostgreSQL 15 - Running (1/1)
- **Cache**: Redis 7 - Running (1/1)
- **Application**: Node.js LUStores - Running (2/2)
- **Authentication**: Replit Auth - Running (1/1)
- **Reverse Proxy**: Nginx - Running (1/1)
- **GitHub Runner**: CrashLoopBackOff (0/1) - Non-critical ⚠️

**External Access**: http://192.168.4.157:31043 - Working ✅

### AtmosRay System - Partially Working ⚠️
- **Pod 1**: Running (1/1) ✅
- **Pod 2**: CrashLoopBackOff (0/1) ❌

## Network Configuration
- **NodePort Range**: 30000-32767 (UFW firewall opened)
- **Primary Service Port**: 31043 (LUStores)
- **AtmosRay Service Port**: 5000

## Action Items

### Immediate (Working)
1. ✅ LUStores system is production-ready and externally accessible
2. ✅ 2-node cluster is stable and functional
3. ⚠️ GitHub runner needs investigation (non-critical)
4. ⚠️ AtmosRay pod crash needs debugging

### Future Improvements
1. 🔄 Add cluster-node-1 (192.168.4.31) back to cluster
2. 🔄 Add scc-ws-01 (10.48.240.32) as additional worker node
3. 🔄 Implement SSL/TLS certificates for py-stores.lancaster.ac.uk
4. 🔄 Set up DNS pointing to cluster for production domain

## Commands for Cluster Management

### Check cluster status:
```bash
kubectl get nodes -o wide
kubectl get pods -A
```

### Access services:
```bash
# External access to LUStores
curl http://192.168.4.157:31043

# Port forward for development
kubectl port-forward -n lustores service/app-service 5000:5000
```

### Add new worker nodes:
```bash
# Generate new join token
kubeadm token create --print-join-command

# Join node (run on worker)
sudo kubeadm join 192.168.4.157:6443 --token <token> --discovery-token-ca-cert-hash <hash>
```

## Updated Inventory

The cluster now includes the local system (scc-ws-01) in the inventory for future expansion:

```ini
[workers]
cluster-node-1 ansible_host=192.168.4.31 ansible_user=steve ansible_ssh_pass=password ansible_become_pass=password
cluster-node-2 ansible_host=192.168.5.57 ansible_user=ansible ansible_ssh_private_key_file=~/.ssh/cluster_key
scc-ws-01 ansible_host=10.48.240.32 ansible_connection=local ansible_user=user ansible_become=yes ansible_become_method=sudo
```

Date: September 6, 2025
Status: Cluster operational with 2/4 nodes, primary services running
