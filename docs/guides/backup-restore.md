# Backup & Restore

## Overview
Backup and restore procedures for the Kubernetes cluster with SLURM and Jupyter.

## Kubernetes Backup
```bash
# Backup cluster configuration
kubectl get all --all-namespaces -o yaml > cluster-backup.yaml

# Backup persistent volumes
kubectl get pv -o yaml > pv-backup.yaml
kubectl get pvc --all-namespaces -o yaml > pvc-backup.yaml
```

## SLURM Configuration Backup
```bash
# Backup SLURM configuration
sudo cp /etc/slurm/slurm.conf /backup/slurm.conf.backup
sudo cp -r /var/lib/slurm /backup/slurm-state-backup
```

## JupyterHub Data Backup
```bash
# Backup JupyterHub configuration
kubectl get configmap jupyterhub-config -o yaml > jupyterhub-config-backup.yaml

# Backup user data (if using persistent volumes)
kubectl exec -it jupyterhub-pod -- tar czf /tmp/user-data.tar.gz /home
```

## Restore Procedures
```bash
# Restore Kubernetes resources
kubectl apply -f cluster-backup.yaml

# Restore SLURM configuration
sudo cp /backup/slurm.conf.backup /etc/slurm/slurm.conf
sudo systemctl restart slurmctld slurmd
```

## Automated Backup Script
```bash
#!/bin/bash
# Daily backup script
DATE=$(date +%Y%m%d)
BACKUP_DIR="/backup/$DATE"
mkdir -p $BACKUP_DIR

kubectl get all --all-namespaces -o yaml > $BACKUP_DIR/cluster.yaml
sudo cp /etc/slurm/slurm.conf $BACKUP_DIR/
```
