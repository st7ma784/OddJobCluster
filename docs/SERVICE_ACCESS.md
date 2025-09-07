# Service Access Guide

## 🌐 Web Services Access

### Kubernetes Dashboard
**Comprehensive cluster management interface**

```bash
# NodePort Access (Recommended)
https://<node-ip>:30443

# Port Forwarding Alternative
kubectl port-forward svc/kubernetes-dashboard 8080:443 -n kubernetes-dashboard
# Access: https://localhost:8080

# Get admin token
kubectl get secret admin-user-token -n kubernetes-dashboard -o jsonpath='{.data.token}' | base64 -d
```

### AtmosRay Radio Propagation System
**Advanced RF modeling and simulation platform**

```bash
# Radio Server - Main Interface
http://<node-ip>:30080

# TX Simulator - Transmitter Array
http://<node-ip>:30081

# RX Simulator - Receiver Network  
http://<node-ip>:30082

# Database Access (Internal)
# MySQL service available to other pods on port 3306
```

### LUStores E-commerce Platform
**Microservices-based shopping platform**

```bash
# Frontend - Customer Interface
http://<node-ip>:30083

# API Gateway - Backend Services
http://<node-ip>:30084

# Admin Panel
http://<node-ip>:30083/admin
```

### Intruder Detection System
**AI-powered security monitoring**

```bash
# Security Dashboard
http://<node-ip>:30085

# Camera Feed Access
http://<node-ip>:30085/stream

# Alert Management
http://<node-ip>:30085/alerts
```

## 🔗 Ingress-Based Access

### Via Cluster Domain (cluster.local)
**When DNS is configured or using /etc/hosts entries**

```bash
# Add to /etc/hosts for local access
echo "<master-node-ip> cluster.local" >> /etc/hosts

# Service Access URLs
https://cluster.local/dashboard        # Kubernetes Dashboard
https://cluster.local/atmosray        # AtmosRay Radio Server
https://cluster.local/lustores        # LUStores Frontend
https://cluster.local/security        # Intruder Detection
https://cluster.local/tx-simulator    # TX Simulator
https://cluster.local/rx-simulator    # RX Simulator
```

### Load Balancer Configuration
**For cloud deployments with external load balancers**

```bash
# Get external IP (if available)
kubectl get svc -n ingress-nginx

# Access via external IP
https://<external-ip>/dashboard
https://<external-ip>/atmosray
```

## 🔧 Port Forwarding for Development

### AtmosRay Services
```bash
# Radio Server
kubectl port-forward svc/radio-server-service 9080:8080 -n radio-propagation

# TX Simulator
kubectl port-forward svc/tx-simulator-service 9081:8080 -n radio-propagation

# RX Simulator  
kubectl port-forward svc/rx-simulator-service 9082:8080 -n radio-propagation

# MySQL Database
kubectl port-forward svc/mysql-service 3306:3306 -n radio-propagation
```

### LUStores Services
```bash
# Frontend
kubectl port-forward svc/lustores-frontend 3000:3000 -n ecommerce

# API Gateway
kubectl port-forward svc/lustores-api 8080:8080 -n ecommerce

# Database
kubectl port-forward svc/lustores-postgres 5432:5432 -n ecommerce
```

### Security Services
```bash
# Intruder Detection
kubectl port-forward svc/intruder-detection-service 8080:8080 -n security

# Camera Service
kubectl port-forward svc/camera-service 8090:8090 -n security
```

## 📊 Monitoring and Management

### Prometheus Metrics
```bash
# Prometheus Server
http://<node-ip>:30090

# Individual service metrics
http://<node-ip>:30080/metrics    # AtmosRay
http://<node-ip>:30083/metrics    # LUStores
http://<node-ip>:30085/metrics    # Security
```

### Grafana Dashboards
```bash
# Grafana Interface
http://<node-ip>:30091

# Default credentials: admin/admin
# Dashboards available:
# - Cluster Overview
# - Service Performance
# - Resource Utilization
# - Security Monitoring
```

## 🛠️ Service Management Commands

### Check Service Status
```bash
# All services across namespaces
kubectl get svc --all-namespaces

# Specific namespace
kubectl get svc -n radio-propagation
kubectl get svc -n ecommerce
kubectl get svc -n security
kubectl get svc -n kubernetes-dashboard
```

### View Service Logs
```bash
# AtmosRay Radio Server
kubectl logs -f deployment/radio-server -n radio-propagation

# LUStores Frontend
kubectl logs -f deployment/lustores-frontend -n ecommerce

# Intruder Detection
kubectl logs -f deployment/intruder-detection -n security

# Dashboard
kubectl logs -f deployment/kubernetes-dashboard -n kubernetes-dashboard
```

### Scale Services
```bash
# Scale AtmosRay components
kubectl scale deployment radio-server --replicas=2 -n radio-propagation
kubectl scale deployment tx-simulator --replicas=1 -n radio-propagation

# Scale LUStores frontend
kubectl scale deployment lustores-frontend --replicas=3 -n ecommerce

# Scale security monitoring
kubectl scale deployment intruder-detection --replicas=2 -n security
```

### Service Health Checks
```bash
# Check endpoint status
kubectl get endpoints --all-namespaces

# Test service connectivity
kubectl run test-pod --image=busybox -it --rm -- \
  wget -qO- http://radio-server-service.radio-propagation.svc.cluster.local:8080/health

# Check ingress status
kubectl get ingress --all-namespaces
```

## 🔐 Security and Authentication

### Dashboard Authentication
```bash
# Create admin user (if not exists)
kubectl apply -f kubernetes/manifests/dashboard-admin.yaml

# Get authentication token
kubectl get secret admin-user-token -n kubernetes-dashboard \
  -o jsonpath='{.data.token}' | base64 -d

# Token expires in 24 hours - regenerate as needed
kubectl delete secret admin-user-token -n kubernetes-dashboard
kubectl apply -f kubernetes/manifests/dashboard-admin.yaml
```

### Service-to-Service Authentication
```bash
# Check service accounts
kubectl get serviceaccounts --all-namespaces

# View RBAC policies
kubectl get clusterrolebindings
kubectl get rolebindings --all-namespaces
```

### TLS Certificate Management
```bash
# Check certificate status
kubectl get certificates --all-namespaces

# View TLS secrets
kubectl get secrets --field-selector type=kubernetes.io/tls --all-namespaces

# Renew certificates (if using cert-manager)
kubectl delete certificate <certificate-name> -n <namespace>
```

## 🚨 Troubleshooting Access Issues

### Common Problems and Solutions

#### Service Not Accessible
```bash
# Check service status
kubectl describe svc <service-name> -n <namespace>

# Verify pod health
kubectl get pods -n <namespace>
kubectl describe pod <pod-name> -n <namespace>

# Check endpoint connectivity
kubectl get endpoints <service-name> -n <namespace>
```

#### Ingress Not Working
```bash
# Check ingress controller
kubectl get pods -n ingress-nginx
kubectl logs deployment/ingress-nginx-controller -n ingress-nginx

# Verify ingress rules
kubectl describe ingress <ingress-name> -n <namespace>

# Test ingress connectivity
curl -v http://cluster.local/<path>
```

#### Port Forwarding Issues
```bash
# Check kubectl config
kubectl config current-context
kubectl cluster-info

# Verify service exists
kubectl get svc <service-name> -n <namespace>

# Use different local port
kubectl port-forward svc/<service-name> 8080:80 -n <namespace>
```

#### Dashboard Authentication Problems
```bash
# Recreate admin user
kubectl delete -f kubernetes/manifests/dashboard-admin.yaml
kubectl apply -f kubernetes/manifests/dashboard-admin.yaml

# Check token validity
kubectl get secret admin-user-token -n kubernetes-dashboard

# Use skip login (development only)
kubectl patch deployment kubernetes-dashboard -n kubernetes-dashboard \
  -p '{"spec":{"template":{"spec":{"containers":[{"name":"kubernetes-dashboard","args":["--auto-generate-certificates","--namespace=kubernetes-dashboard","--enable-skip-login"]}]}}}}'
```

## 📱 Mobile and API Access

### REST API Endpoints
```bash
# AtmosRay API
GET  http://<node-ip>:30080/api/v1/propagation
POST http://<node-ip>:30080/api/v1/simulate
GET  http://<node-ip>:30080/api/v1/status

# LUStores API
GET  http://<node-ip>:30084/api/v1/products
POST http://<node-ip>:30084/api/v1/orders
GET  http://<node-ip>:30084/api/v1/users

# Security API
GET  http://<node-ip>:30085/api/v1/alerts
POST http://<node-ip>:30085/api/v1/detection
GET  http://<node-ip>:30085/api/v1/cameras
```

### WebSocket Connections
```bash
# Real-time AtmosRay data
ws://<node-ip>:30080/ws/propagation

# Live security feeds
ws://<node-ip>:30085/ws/camera

# LUStores notifications
ws://<node-ip>:30084/ws/notifications
```

### Mobile App Integration
```bash
# Android APK endpoints
GET  http://<node-ip>:30766/api/android/tasks
POST http://<node-ip>:30766/api/android/submit
WS   ws://<node-ip>:30765/android/connect
```
