#!/bin/bash
# Install kubectl and SLURM tools on Android device via Termux

set -e

echo "🔧 Installing Android cluster tools..."

# Check if device is connected
if ! adb devices | grep -q "device$"; then
    echo "❌ No Android device connected via ADB"
    exit 1
fi

DEVICE=$(adb devices | grep "device$" | head -1 | cut -f1)
echo "📱 Using device: $DEVICE"

# Install Termux if not present
echo "📦 Installing Termux..."
adb -s $DEVICE install -r https://github.com/termux/termux-app/releases/download/v0.118.0/termux-app_v0.118.0+github-debug_arm64-v8a.apk 2>/dev/null || echo "Termux already installed or failed to install"

# Start Termux and setup environment
echo "🚀 Setting up Termux environment..."
adb -s $DEVICE shell am start -n com.termux/.app.TermuxActivity
sleep 3

# Update packages and install dependencies
echo "📦 Installing base packages..."
adb -s $DEVICE shell input text "pkg update -y && pkg upgrade -y"
adb -s $DEVICE shell input keyevent 66
sleep 10

adb -s $DEVICE shell input text "pkg install -y wget curl python nodejs-lts git openssh"
adb -s $DEVICE shell input keyevent 66
sleep 15

# Install kubectl
echo "☸️ Installing kubectl..."
adb -s $DEVICE shell input text "wget https://dl.k8s.io/release/v1.28.0/bin/linux/arm64/kubectl -O \$PREFIX/bin/kubectl"
adb -s $DEVICE shell input keyevent 66
sleep 10

adb -s $DEVICE shell input text "chmod +x \$PREFIX/bin/kubectl"
adb -s $DEVICE shell input keyevent 66
sleep 2

# Install SLURM client tools (compile from source for ARM)
echo "⚡ Setting up SLURM client..."
adb -s $DEVICE shell input text "pkg install -y make gcc clang autoconf automake libtool"
adb -s $DEVICE shell input keyevent 66
sleep 15

adb -s $DEVICE shell input text "cd \$HOME && git clone https://github.com/SchedMD/slurm.git"
adb -s $DEVICE shell input keyevent 66
sleep 10

adb -s $DEVICE shell input text "cd slurm && ./configure --prefix=\$PREFIX --disable-dependency-tracking"
adb -s $DEVICE shell input keyevent 66
sleep 20

adb -s $DEVICE shell input text "make -j4 && make install"
adb -s $DEVICE shell input keyevent 66

echo "✅ Android cluster tools installation initiated"
echo "📱 Check Termux on your device to monitor installation progress"
echo "🔧 Once complete, kubectl and SLURM commands will be available in Termux"
