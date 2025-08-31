#!/bin/bash

# SSL Certificate Setup Script
# This script sets up Let's Encrypt SSL certificates for the cluster

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

show_usage() {
    echo "Usage: $0 <domain> <email>"
    echo ""
    echo "Arguments:"
    echo "  domain    Your cluster's domain name (e.g., cluster.example.com)"
    echo "  email     Email address for Let's Encrypt registration"
    echo ""
    echo "Example:"
    echo "  $0 cluster.example.com admin@example.com"
}

setup_certbot() {
    local domain=$1
    local email=$2
    
    print_info "Installing certbot on master node..."
    ansible master -i ansible/inventory.ini -m apt -a "
        name=certbot,python3-certbot-nginx
        state=present
        update_cache=yes
    " --become
    
    print_info "Obtaining SSL certificate for $domain..."
    ansible master -i ansible/inventory.ini -m shell -a "
        certbot --nginx -d $domain --email $email --agree-tos --non-interactive
    " --become
    
    print_info "Setting up automatic renewal..."
    ansible master -i ansible/inventory.ini -m cron -a "
        name='Certbot renewal'
        minute='0'
        hour='12'
        job='/usr/bin/certbot renew --quiet'
    " --become
}

setup_cert_manager() {
    local domain=$1
    local email=$2
    
    print_info "Installing cert-manager in Kubernetes..."
    ansible master -i ansible/inventory.ini -m shell -a "
        kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.0/cert-manager.yaml
    " --become
    
    print_info "Waiting for cert-manager to be ready..."
    ansible master -i ansible/inventory.ini -m shell -a "
        kubectl wait --for=condition=ready pod -l app=cert-manager -n cert-manager --timeout=300s
    " --become
    
    # Create ClusterIssuer for Let's Encrypt
    print_info "Creating Let's Encrypt ClusterIssuer..."
    ansible master -i ansible/inventory.ini -m shell -a "
        cat <<EOF | kubectl apply -f -
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: $email
    privateKeySecretRef:
      name: letsencrypt-prod
    solvers:
    - http01:
        ingress:
          class: nginx
EOF
    " --become
    
    print_success "cert-manager configured successfully"
}

update_ingress_ssl() {
    local domain=$1
    
    print_info "Updating ingress configurations for SSL..."
    
    # Update JupyterHub ingress
    ansible master -i ansible/inventory.ini -m shell -a "
        cat <<EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: jupyterhub-ingress
  namespace: jupyter
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt-prod
    nginx.ingress.kubernetes.io/ssl-redirect: 'true'
spec:
  tls:
  - hosts:
    - $domain
    secretName: jupyterhub-tls
  rules:
  - host: $domain
    http:
      paths:
      - path: /jupyter
        pathType: Prefix
        backend:
          service:
            name: proxy-public
            port:
              number: 80
EOF
    " --become
    
    # Update Grafana ingress
    ansible master -i ansible/inventory.ini -m shell -a "
        cat <<EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: grafana-ingress
  namespace: monitoring
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt-prod
    nginx.ingress.kubernetes.io/ssl-redirect: 'true'
spec:
  tls:
  - hosts:
    - $domain
    secretName: grafana-tls
  rules:
  - host: $domain
    http:
      paths:
      - path: /grafana
        pathType: Prefix
        backend:
          service:
            name: prometheus-grafana
            port:
              number: 80
EOF
    " --become
    
    print_success "Ingress configurations updated for SSL"
}

# Check arguments
if [ $# -ne 2 ]; then
    print_error "Invalid number of arguments"
    show_usage
    exit 1
fi

DOMAIN=$1
EMAIL=$2

# Validate email format
if [[ ! "$EMAIL" =~ ^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$ ]]; then
    print_error "Invalid email format"
    exit 1
fi

print_info "Setting up SSL certificates for domain: $DOMAIN"
print_info "Using email: $EMAIL"

# Check if domain resolves to master node
MASTER_IP=$(ansible master -i ansible/inventory.ini -m shell -a "hostname -I | awk '{print \$1}'" | grep -v "SUCCESS" | tail -1)
DOMAIN_IP=$(dig +short $DOMAIN | tail -1)

if [ "$MASTER_IP" != "$DOMAIN_IP" ]; then
    print_warning "Domain $DOMAIN does not resolve to master node IP $MASTER_IP"
    print_warning "Current resolution: $DOMAIN -> $DOMAIN_IP"
    print_warning "Please ensure DNS is configured correctly before proceeding"
    read -p "Continue anyway? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_info "SSL setup cancelled"
        exit 0
    fi
fi

# Setup cert-manager for Kubernetes services
setup_cert_manager "$DOMAIN" "$EMAIL"

# Update ingress configurations
update_ingress_ssl "$DOMAIN"

# Setup certbot for nginx (optional, for non-Kubernetes services)
print_info "Setting up certbot for nginx..."
setup_certbot "$DOMAIN" "$EMAIL"

print_success "SSL setup completed successfully!"
print_info "Your cluster is now accessible at: https://$DOMAIN"
print_info "Services:"
print_info "  - JupyterHub: https://$DOMAIN/jupyter"
print_info "  - Grafana: https://$DOMAIN/grafana"
print_info "  - Docker Registry: https://$DOMAIN/registry"
