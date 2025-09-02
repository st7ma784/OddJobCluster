#!/bin/bash
set -e

echo "🐳 Building Android ADB Deployer Docker Image"
echo "============================================="

# Navigate to docker directory
cd "$(dirname "$0")/../docker/android-adb-deployer"

# Build the Docker image
echo "📦 Building Docker image..."
docker build -t android-adb-deployer:latest .

# Tag for local registry if available
if docker info | grep -q "Registry Mirrors"; then
    echo "🏷️ Tagging for local registry..."
    docker tag android-adb-deployer:latest localhost:5000/android-adb-deployer:latest
    
    echo "📤 Pushing to local registry..."
    docker push localhost:5000/android-adb-deployer:latest
fi

echo "✅ Docker image built successfully!"
echo "📋 Image details:"
docker images | grep android-adb-deployer

echo ""
echo "💡 Next steps:"
echo "   1. Deploy using: kubectl apply -f kubernetes/manifests/android-apk-deployer.yaml"
echo "   2. Use dashboard button to deploy APK to connected devices"
echo "   3. Monitor deployment with: kubectl logs -f job/apk-deploy-<timestamp>"
