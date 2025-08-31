#!/bin/bash

# Quick One-Command Cluster Deployment
# Usage: ./quick-cluster-deploy.sh <master-ip> [worker-ip1] [worker-ip2] ...

set -euo pipefail

MASTER_IP="$1"
WORKER_IPS=("${@:2}")

echo "🚀 Starting quick cluster deployment..."
echo "Master: $MASTER_IP"
echo "Workers: ${WORKER_IPS[*]:-none}"

# Run the full automation script
exec "$(dirname "$0")/auto-cluster-setup.sh" --master "$MASTER_IP" $(printf -- "--node %s " "${WORKER_IPS[@]}")
