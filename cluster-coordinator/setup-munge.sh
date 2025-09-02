#!/bin/bash
# MUNGE Setup Script for SLURM Authentication

set -e

echo "🔐 Setting up MUNGE authentication service..."

# Install MUNGE if not present
if ! command -v munge &> /dev/null; then
    echo "📦 Installing MUNGE..."
    sudo apt-get update
    sudo apt-get install -y munge libmunge-dev
fi

# Create munge user if doesn't exist
if ! id munge &> /dev/null; then
    echo "👤 Creating munge user..."
    sudo useradd -r -s /bin/false munge
fi

# Create MUNGE directories
echo "📁 Creating MUNGE directories..."
sudo mkdir -p /etc/munge
sudo mkdir -p /var/lib/munge
sudo mkdir -p /var/log/munge
sudo mkdir -p /run/munge

# Set proper ownership
sudo chown munge:munge /var/lib/munge
sudo chown munge:munge /var/log/munge
sudo chown munge:munge /run/munge

# Generate MUNGE key if it doesn't exist
if [ ! -f /etc/munge/munge.key ]; then
    echo "🔑 Generating MUNGE key..."
    sudo dd if=/dev/urandom bs=1 count=1024 of=/etc/munge/munge.key
    sudo chmod 400 /etc/munge/munge.key
    sudo chown munge:munge /etc/munge/munge.key
fi

# Start MUNGE daemon
echo "🚀 Starting MUNGE daemon..."
sudo systemctl enable munge
sudo systemctl start munge

# Wait a moment for daemon to start
sleep 2

# Test MUNGE authentication
echo "🧪 Testing MUNGE authentication..."
if echo "test" | munge | unmunge | grep -q "test"; then
    echo "✅ MUNGE authentication working!"
    systemctl is-active munge
else
    echo "❌ MUNGE authentication test failed"
    sudo systemctl status munge
    exit 1
fi

echo "🎉 MUNGE setup complete!"
