#!/data/data/com.termux/files/usr/bin/bash
# Android Cluster Node Tool Installer
# This script installs kubectl and SLURM tools in Termux

set -e

echo "🚀 Android Cluster Node Tool Installer"
echo "======================================="

# Update package lists
echo "📦 Updating package lists..."
pkg update -y

# Install base dependencies
echo "🔧 Installing base dependencies..."
pkg install -y wget curl git python nodejs-lts

# Install kubectl
echo "☸️ Installing kubectl..."
if ! command -v kubectl &> /dev/null; then
    ARCH=$(uname -m)
    if [[ "$ARCH" == "aarch64" ]]; then
        KUBECTL_ARCH="arm64"
    elif [[ "$ARCH" == "armv7l" ]]; then
        KUBECTL_ARCH="arm"
    else
        KUBECTL_ARCH="amd64"
    fi
    
    wget "https://dl.k8s.io/release/v1.28.0/bin/linux/${KUBECTL_ARCH}/kubectl" -O $PREFIX/bin/kubectl
    chmod +x $PREFIX/bin/kubectl
    echo "✅ kubectl installed successfully"
else
    echo "✅ kubectl already installed"
fi

# Test kubectl
kubectl version --client

# Install SLURM build dependencies
echo "⚡ Installing SLURM build dependencies..."
pkg install -y make gcc clang autoconf automake libtool pkg-config

# Check if SLURM is already installed
if ! command -v sinfo &> /dev/null; then
    echo "🔨 Building SLURM from source..."
    cd $HOME
    
    # Clone SLURM if not already present
    if [ ! -d "slurm" ]; then
        git clone https://github.com/SchedMD/slurm.git
    fi
    
    cd slurm
    
    # Configure and build
    ./configure --prefix=$PREFIX --disable-dependency-tracking --without-mysql --without-gtk --disable-gtktest
    make -j$(nproc)
    make install
    
    echo "✅ SLURM installed successfully"
else
    echo "✅ SLURM already installed"
fi

# Test SLURM
sinfo --version

echo ""
echo "🎉 Installation complete!"
echo "✅ kubectl: $(kubectl version --client --short)"
echo "✅ SLURM: $(sinfo --version)"
echo ""
echo "🚀 Android cluster node is ready for Kubernetes and SLURM jobs!"
