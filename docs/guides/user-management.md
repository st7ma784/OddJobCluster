# User Management

## Overview
Managing users in the Kubernetes cluster with SLURM and JupyterHub integration.

## SLURM User Management
```bash
# Add user to SLURM
sudo useradd -m username
sudo scontrol update NodeName=ALL State=RESUME

# Set user limits
sudo sacctmgr add user username account=default
```

## JupyterHub Users
Users are managed through JupyterHub's admin interface:
- Access admin panel at `/hub/admin`
- Add/remove users
- Monitor active sessions

## Kubernetes RBAC
```yaml
# Example user role
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: user-role
rules:
- apiGroups: [""]
  resources: ["pods"]
  verbs: ["get", "list"]
```

## SSH Access
```bash
# Add SSH key for user
sudo mkdir -p /home/username/.ssh
sudo cp authorized_keys /home/username/.ssh/
sudo chown -R username:username /home/username/.ssh
```
