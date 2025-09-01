# Kubernetes API Reference

## Overview
Kubernetes API reference for cluster management and application deployment.

## Core Resources

### Pods
```bash
# List pods
kubectl get pods --all-namespaces

# Pod details
kubectl describe pod pod-name

# Pod logs
kubectl logs pod-name -c container-name
```

### Services
```bash
# List services
kubectl get services

# Expose deployment
kubectl expose deployment app-name --port=80 --type=NodePort

# Service details
kubectl describe service service-name
```

### Deployments
```bash
# Create deployment
kubectl create deployment app-name --image=nginx

# Scale deployment
kubectl scale deployment app-name --replicas=3

# Update deployment
kubectl set image deployment/app-name container=new-image:tag
```

## Cluster Management

### Nodes
```bash
# List nodes
kubectl get nodes

# Node details
kubectl describe node node-name

# Drain node
kubectl drain node-name --ignore-daemonsets
```

### Namespaces
```bash
# List namespaces
kubectl get namespaces

# Create namespace
kubectl create namespace my-namespace

# Set default namespace
kubectl config set-context --current --namespace=my-namespace
```

## Configuration

### ConfigMaps
```bash
# Create configmap
kubectl create configmap app-config --from-file=config.properties

# View configmap
kubectl get configmap app-config -o yaml
```

### Secrets
```bash
# Create secret
kubectl create secret generic app-secret --from-literal=password=secret123

# View secret
kubectl get secret app-secret -o yaml
```

## Monitoring

### Resource Usage
```bash
# Node resource usage
kubectl top nodes

# Pod resource usage
kubectl top pods

# Events
kubectl get events --sort-by=.metadata.creationTimestamp
```
