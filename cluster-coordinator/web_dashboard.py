#!/usr/bin/env python3
"""
Web Dashboard for Android Cluster Management
"""

from aiohttp import web, web_ws
import aiohttp_cors
import json
import asyncio
from server import coordinator

async def dashboard_handler(request):
    """Serve the web dashboard"""
    return web.Response(text="""
<!DOCTYPE html>
<html>
<head>
    <title>Android Cluster Dashboard</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; background: #f5f5f5; }
        .container { max-width: 1200px; margin: 0 auto; }
        .card { background: white; padding: 20px; margin: 10px 0; border-radius: 8px; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }
        .node { display: inline-block; margin: 10px; padding: 15px; border: 1px solid #ddd; border-radius: 5px; min-width: 200px; }
        .node.connected { border-color: #4CAF50; background: #f8fff8; }
        .node.disconnected { border-color: #f44336; background: #fff8f8; }
        .status { font-weight: bold; }
        .connected { color: #4CAF50; }
        .disconnected { color: #f44336; }
        button { padding: 10px 20px; margin: 5px; border: none; border-radius: 4px; cursor: pointer; }
        .btn-primary { background: #2196F3; color: white; }
        .btn-success { background: #4CAF50; color: white; }
        .btn-warning { background: #FF9800; color: white; }
        #log { height: 200px; overflow-y: scroll; border: 1px solid #ddd; padding: 10px; background: #f9f9f9; font-family: monospace; }
    </style>
</head>
<body>
    <div class="container">
        <h1>🤖 Android Cluster Dashboard</h1>
        
        <div class="card">
            <h2>Cluster Status</h2>
            <div id="cluster-stats">
                <p>Nodes: <span id="node-count">0</span> | Tasks: <span id="task-count">0</span> | Completed: <span id="completed-count">0</span></p>
            </div>
        </div>
        
        <div class="card">
            <h2>Connected Nodes</h2>
            <div id="nodes-container"></div>
        </div>
        
        <div class="card">
            <h2>Task Management</h2>
            <button class="btn-primary" onclick="addPrimeTask()">Add Prime Task</button>
            <button class="btn-primary" onclick="addMatrixTask()">Add Matrix Task</button>
            <button class="btn-primary" onclick="addHashTask()">Add Hash Task</button>
            <button class="btn-success" onclick="refreshStatus()">Refresh Status</button>
        </div>
        
        <div class="card">
            <h2>Activity Log</h2>
            <div id="log"></div>
        </div>
    </div>

    <script>
        function log(message) {
            const logDiv = document.getElementById('log');
            const time = new Date().toLocaleTimeString();
            logDiv.innerHTML += `[${time}] ${message}<br>`;
            logDiv.scrollTop = logDiv.scrollHeight;
        }
        
        async function refreshStatus() {
            try {
                const response = await fetch('/api/status');
                const status = await response.json();
                updateDashboard(status);
                log('Status refreshed');
            } catch (error) {
                log(`Error: ${error.message}`);
            }
        }
        
        function updateDashboard(status) {
            // Update stats
            document.getElementById('node-count').textContent = Object.keys(status.nodes).length;
            document.getElementById('task-count').textContent = status.tasks.total;
            document.getElementById('completed-count').textContent = status.tasks.completed;
            
            // Update nodes
            const nodesContainer = document.getElementById('nodes-container');
            nodesContainer.innerHTML = '';
            
            for (const [nodeId, node] of Object.entries(status.nodes)) {
                const nodeDiv = document.createElement('div');
                nodeDiv.className = `node ${node.status}`;
                nodeDiv.innerHTML = `
                    <h3>${nodeId}</h3>
                    <p><strong>IP:</strong> ${node.ip_address}</p>
                    <p><strong>Status:</strong> <span class="status ${node.status}">${node.status}</span></p>
                    <p><strong>Tasks Completed:</strong> ${node.tasks_completed}</p>
                    <p><strong>Performance:</strong> ${node.performance_score.toFixed(2)}</p>
                    <p><strong>Capabilities:</strong> ${node.capabilities.join(', ')}</p>
                `;
                nodesContainer.appendChild(nodeDiv);
            }
        }
        
        async function addTask(taskType, data) {
            try {
                const response = await fetch('/api/add_task', {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify({ task_type: taskType, data: data })
                });
                const result = await response.json();
                log(`Added task: ${result.task_id} (${taskType})`);
                refreshStatus();
            } catch (error) {
                log(`Error adding task: ${error.message}`);
            }
        }
        
        function addPrimeTask() {
            addTask('prime_calculation', { start: 1, end: 50000 });
        }
        
        function addMatrixTask() {
            addTask('matrix_multiplication', { size: 150 });
        }
        
        function addHashTask() {
            addTask('hash_computation', { iterations: 5000 });
        }
        
        // Auto-refresh every 5 seconds
        setInterval(refreshStatus, 5000);
        
        // Initial load
        refreshStatus();
        log('Dashboard initialized');
    </script>
</body>
</html>
    """, content_type='text/html')

async def api_status(request):
    """API endpoint for cluster status"""
    status = coordinator.get_cluster_status()
    return web.json_response(status)

async def api_add_task(request):
    """API endpoint to add tasks"""
    data = await request.json()
    task_type = data.get('task_type')
    task_data = data.get('data', {})
    priority = data.get('priority', 1)
    
    task_id = coordinator.add_task(task_type, task_data, priority)
    return web.json_response({'task_id': task_id, 'status': 'added'})

async def create_web_app():
    """Create the web application"""
    app = web.Application()
    
    # Add CORS support
    cors = aiohttp_cors.setup(app, defaults={
        "*": aiohttp_cors.ResourceOptions(
            allow_credentials=True,
            expose_headers="*",
            allow_headers="*",
            allow_methods="*"
        )
    })
    
    # Routes
    app.router.add_get('/', dashboard_handler)
    app.router.add_get('/api/status', api_status)
    app.router.add_post('/api/add_task', api_add_task)
    
    # Add CORS to all routes
    for route in list(app.router.routes()):
        cors.add(route)
    
    return app

async def start_web_server():
    """Start the web dashboard server"""
    app = await create_web_app()
    runner = web.AppRunner(app)
    await runner.setup()
    
    site = web.TCPSite(runner, '0.0.0.0', 8080)
    await site.start()
    
    print("Web dashboard available at http://localhost:8080")

if __name__ == "__main__":
    asyncio.run(start_web_server())
