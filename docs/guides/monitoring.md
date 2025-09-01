# Monitoring

## Overview
This guide covers monitoring setup for the Kubernetes cluster with SLURM and Jupyter.

## Cluster Monitoring
- **Kubernetes Dashboard**: Access via NodePort service
- **SLURM Monitoring**: Built-in `sinfo`, `squeue` commands
- **Resource Usage**: `kubectl top nodes` and `kubectl top pods`

## JupyterHub Monitoring
- User sessions and resource consumption
- Hub logs: `kubectl logs -l app=jupyterhub`

## Log Collection
```bash
# View cluster logs
kubectl logs -n kube-system -l component=kube-apiserver

# SLURM logs
sudo journalctl -u slurmd
sudo journalctl -u slurmctld
```

## Alerts
Basic monitoring is provided through Kubernetes events and SLURM job status.
