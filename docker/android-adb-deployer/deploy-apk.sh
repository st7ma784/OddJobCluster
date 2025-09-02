#!/bin/bash
set -e

echo "🤖 Android APK Deployment Script"
echo "================================="

# Configuration
APK_PATH="/apk/app-debug.apk"
TIMEOUT=30

# Check if APK file exists
if [ ! -f "$APK_PATH" ]; then
    echo "❌ APK file not found at $APK_PATH"
    exit 1
fi

echo "📱 APK file found: $APK_PATH"

# Start ADB server
echo "🔧 Starting ADB server..."
adb start-server

# Wait for device connection
echo "⏳ Waiting for Android device connection (timeout: ${TIMEOUT}s)..."
timeout $TIMEOUT adb wait-for-device

# Check if device is connected
DEVICES=$(adb devices | grep -v "List of devices" | grep -c "device")
if [ "$DEVICES" -eq 0 ]; then
    echo "❌ No Android devices connected"
    echo "💡 Make sure:"
    echo "   1. USB debugging is enabled on the device"
    echo "   2. Device is connected via USB to the node"
    echo "   3. USB debugging permission is granted"
    exit 1
fi

echo "✅ Found $DEVICES Android device(s) connected"

# List connected devices
echo "📱 Connected devices:"
adb devices

# Install APK on all connected devices
for device in $(adb devices | grep "device$" | cut -f1); do
    echo "📦 Installing APK on device: $device"
    
    # Check if app is already installed
    if adb -s $device shell pm list packages | grep -q "com.cluster.node"; then
        echo "🔄 App already installed, updating..."
        adb -s $device install -r "$APK_PATH"
    else
        echo "📲 Installing new app..."
        adb -s $device install "$APK_PATH"
    fi
    
    if [ $? -eq 0 ]; then
        echo "✅ Successfully installed on device: $device"
        
        # Start the app
        echo "🚀 Starting Android Cluster app..."
        adb -s $device shell am start -n com.cluster.node/.MainActivity
        
        echo "📊 Device info:"
        adb -s $device shell getprop ro.product.model
        adb -s $device shell getprop ro.build.version.release
        
    else
        echo "❌ Failed to install on device: $device"
    fi
    
    echo "---"
done

echo "🎉 APK deployment completed!"
echo "💡 Next steps:"
echo "   1. Configure cluster URL in the app"
echo "   2. Enable cluster service"
echo "   3. Monitor connection in dashboard"
