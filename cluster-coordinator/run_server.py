#!/usr/bin/env python3
"""
Simple startup script for the Android Cluster Coordinator
"""

import asyncio
import logging
from server import coordinator
from web_dashboard import create_web_app
import websockets
from aiohttp import web

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

async def main():
    """Start both WebSocket server and web dashboard"""
    
    # Start WebSocket server
    ws_server = await websockets.serve(
        coordinator.register_handler,
        '0.0.0.0',
        8765
    )
    logger.info('✅ WebSocket server started on ws://0.0.0.0:8765')
    
    # Add sample tasks for testing
    coordinator.add_task('prime_calculation', {'start': 1, 'end': 10000}, priority=2)
    coordinator.add_task('matrix_multiplication', {'size': 100}, priority=1)
    coordinator.add_task('hash_computation', {'iterations': 1000}, priority=1)
    logger.info('📋 Added sample tasks to queue')
    
    # Start web dashboard
    app = await create_web_app()
    runner = web.AppRunner(app)
    await runner.setup()
    site = web.TCPSite(runner, '0.0.0.0', 8080)
    await site.start()
    logger.info('✅ Web dashboard started on http://0.0.0.0:8080')
    
    logger.info('🚀 Android Cluster Coordinator is ready!')
    logger.info('📱 Connect your Android device to ws://YOUR_IP:8765')
    
    # Keep running forever
    try:
        await asyncio.Future()  # run forever
    except KeyboardInterrupt:
        logger.info('🛑 Shutting down cluster coordinator...')
        ws_server.close()
        await ws_server.wait_closed()
        await runner.cleanup()

if __name__ == "__main__":
    asyncio.run(main())
