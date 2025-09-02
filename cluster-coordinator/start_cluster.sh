#!/bin/bash

# Android Cluster Coordinator Startup Script

echo "🚀 Starting Android Cluster Coordinator..."

# Check if Python 3 is available
if ! command -v python3 &> /dev/null; then
    echo "❌ Python 3 is required but not installed"
    exit 1
fi

echo "📦 Installing dependencies..."
pip install -r requirements.txt

# Get local IP address
LOCAL_IP=$(hostname -I | awk '{print $1}')
echo "🌐 Cluster coordinator will be available at:"
echo "   WebSocket: ws://$LOCAL_IP:8765"
echo "   Dashboard: http://$LOCAL_IP:8080"

# Update Android APK with coordinator IP
echo "📱 To connect your Android device:"
echo "   1. Open the ClusterNode app"
echo "   2. Enter server: $LOCAL_IP:8765"
echo "   3. Tap 'Start Service'"

# Start both servers
echo "🎯 Starting cluster coordinator and web dashboard..."

# Start the combined server
python -c "
import asyncio
import sys
sys.path.append('.')
from server import coordinator
from web_dashboard import create_web_app
import websockets
from aiohttp import web
import logging

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

async def run_both():
    # Start WebSocket server
    ws_server = await websockets.serve(
        coordinator.register_handler,
        '0.0.0.0',
        8764
    )
    logger.info('WebSocket server started on ws://0.0.0.0:8764')
    
    # Add sample tasks
    coordinator.add_task('prime_calculation', {'start': 1, 'end': 10000}, priority=2)
    coordinator.add_task('matrix_multiplication', {'size': 100}, priority=1)
    coordinator.add_task('hash_computation', {'iterations': 1000}, priority=1)
    
    # Start web dashboard
    app = await create_web_app()
    runner = web.AppRunner(app)
    await runner.setup()
    site = web.TCPSite(runner, '0.0.0.0', 8082)
    await site.start()
    logger.info('Web dashboard started on http://0.0.0.0:8082')
    
    # Keep running
    await asyncio.Future()  # run forever

asyncio.run(run_both())
"

echo "✅ Cluster coordinator started!"
echo "   WebSocket PID: $WS_PID"
echo "   Web Dashboard PID: $WEB_PID"

# Wait for interrupt
trap 'kill $WS_PID $WEB_PID; exit' INT
wait
