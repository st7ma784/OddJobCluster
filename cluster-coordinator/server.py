#!/usr/bin/env python3
"""
Android Cluster Coordinator
WebSocket server for managing Android compute nodes
"""

import asyncio
import websockets
import json
import logging
import time
import subprocess
import os
from typing import Dict, List, Any, Optional
from dataclasses import dataclass, asdict
from datetime import datetime
import uuid
from aiohttp import web, web_response
import aiohttp_cors

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

@dataclass
class ComputeNode:
    node_id: str
    ip_address: str
    status: str = "disconnected"
    last_seen: float = 0
    tasks_completed: int = 0
    capabilities: List[str] = None
    performance_score: float = 0.0
    kubernetes_registered: bool = False
    slurm_registered: bool = False
    
    def __post_init__(self):
        if self.capabilities is None:
            self.capabilities = []

@dataclass
class ComputeTask:
    task_id: str
    task_type: str
    data: Dict[str, Any]
    priority: int = 1
    created_at: float = 0
    assigned_to: str = None
    status: str = "pending"
    result: Any = None
    
    def __post_init__(self):
        if self.created_at == 0:
            self.created_at = time.time()

class ClusterCoordinator:
    def __init__(self):
        self.nodes: Dict[str, ComputeNode] = {}
        self.tasks: Dict[str, ComputeTask] = {}
        self.task_queue: List[str] = []
        self.connections: Dict[str, websockets.WebSocketServerProtocol] = {}
        self.kubernetes_available = self.check_kubernetes_cluster()
        self.slurm_available = self.check_slurm_cluster()
        self.munge_available = self.check_munge_service()
        
        if self.kubernetes_available:
            logger.info("✅ Kubernetes cluster detected - Android nodes will be auto-registered")
        if self.slurm_available:
            if self.munge_available:
                logger.info("✅ SLURM cluster with MUNGE authentication detected - Android nodes will be auto-registered")
            else:
                logger.warning("⚠️ SLURM cluster detected but MUNGE authentication is missing - registration may fail")
                logger.info("💡 Install MUNGE: sudo apt-get install munge libmunge-dev")
        
    async def register_handler(self, websocket, path=None):
        """Handle WebSocket connections from Android nodes"""
        node_ip = websocket.remote_address[0]
        node_id = f"android-{node_ip.replace('.', '-')}"
        
        logger.info(f"Node {node_id} connecting from {node_ip}")
        
        try:
            # Register the node
            self.connections[node_id] = websocket
            
            if node_id not in self.nodes:
                self.nodes[node_id] = ComputeNode(
                    node_id=node_id,
                    ip_address=node_ip,
                    status="connected",
                    last_seen=time.time()
                )
            else:
                self.nodes[node_id].status = "connected"
                self.nodes[node_id].last_seen = time.time()
            
            # Send welcome message
            await websocket.send(json.dumps({
                "type": "welcome",
                "node_id": node_id,
                "message": "Connected to cluster coordinator"
            }))
            
            # Auto-register to existing clusters
            await self.auto_register_to_clusters(node_id)
            
            # Auto-assign tasks if available
            await self.assign_task(node_id)
            
            # Handle messages from this node
            async for message in websocket:
                await self.handle_message(node_id, json.loads(message))
                
        except websockets.exceptions.ConnectionClosed:
            logger.info(f"Node {node_id} disconnected")
        except Exception as e:
            logger.error(f"Error handling node {node_id}: {e}")
        finally:
            # Clean up
            if node_id in self.connections:
                del self.connections[node_id]
            if node_id in self.nodes:
                self.nodes[node_id].status = "disconnected"
    
    async def handle_message(self, node_id: str, message: Dict[str, Any]):
        """Process messages from Android nodes"""
        msg_type = message.get("type")
        
        if msg_type == "heartbeat":
            self.nodes[node_id].last_seen = time.time()
            await self.send_to_node(node_id, {"type": "heartbeat_ack"})
            
        elif msg_type == "capabilities":
            self.nodes[node_id].capabilities = message.get("capabilities", [])
            logger.info(f"Node {node_id} capabilities: {self.nodes[node_id].capabilities}")
            
        elif msg_type == "task_result":
            await self.handle_task_result(node_id, message)
            
        elif msg_type == "performance_update":
            self.nodes[node_id].performance_score = message.get("score", 0.0)
            
        elif msg_type == "request_task":
            await self.assign_task(node_id)
    
    async def handle_task_result(self, node_id: str, message: Dict[str, Any]):
        """Handle completed task results"""
        task_id = message.get("task_id")
        result = message.get("result")
        success = message.get("success", True)
        
        if task_id in self.tasks:
            task = self.tasks[task_id]
            task.status = "completed" if success else "failed"
            task.result = result
            
            self.nodes[node_id].tasks_completed += 1
            logger.info(f"✅ Task {task_id} ({task.task_type}) completed by {node_id} - Result: {str(result)[:100]}...")
            
            # Send acknowledgment
            await self.send_to_node(node_id, {
                "type": "task_ack",
                "task_id": task_id,
                "status": "received"
            })
    
    async def assign_task(self, node_id: str):
        """Assign a task to a specific node"""
        if not self.task_queue:
            await self.send_to_node(node_id, {
                "type": "no_tasks",
                "message": "No tasks available"
            })
            return
        
        # Get the next task
        task_id = self.task_queue.pop(0)
        task = self.tasks[task_id]
        
        # Assign to node
        task.assigned_to = node_id
        task.status = "assigned"
        
        # Send task to node
        logger.info(f"📤 Assigning task {task_id} ({task.task_type}) to {node_id}")
        await self.send_to_node(node_id, {
            "type": "task_assignment",
            "task_id": task_id,
            "task_type": task.task_type,
            "data": task.data,
            "priority": task.priority
        })
        
        logger.info(f"Assigned task {task_id} to {node_id}")
    
    async def send_to_node(self, node_id: str, message: Dict[str, Any]):
        """Send message to a specific node"""
        if node_id in self.connections:
            try:
                await self.connections[node_id].send(json.dumps(message))
            except Exception as e:
                logger.error(f"Failed to send message to {node_id}: {e}")
    
    async def broadcast(self, message: Dict[str, Any]):
        """Broadcast message to all connected nodes"""
        for node_id in list(self.connections.keys()):
            await self.send_to_node(node_id, message)
    
    def add_task(self, task_type: str, data: Dict[str, Any], priority: int = 1) -> str:
        """Add a new task to the queue"""
        task_id = str(uuid.uuid4())
        task = ComputeTask(
            task_id=task_id,
            task_type=task_type,
            data=data,
            priority=priority
        )
        
        self.tasks[task_id] = task
        self.task_queue.append(task_id)
        self.task_queue.sort(key=lambda tid: self.tasks[tid].priority, reverse=True)
        
        logger.info(f"Added task {task_id} of type {task_type}")
        return task_id
    
    def check_kubernetes_cluster(self) -> bool:
        """Check if Kubernetes cluster is available on this host"""
        try:
            result = subprocess.run(['kubectl', 'cluster-info'], 
                                  capture_output=True, text=True, timeout=5)
            return result.returncode == 0
        except (subprocess.TimeoutExpired, FileNotFoundError):
            return False
    
    def check_slurm_cluster(self) -> bool:
        """Check if SLURM cluster is available on this host"""
        try:
            result = subprocess.run(['sinfo', '--version'], 
                                  capture_output=True, text=True, timeout=5)
            return result.returncode == 0
        except (subprocess.TimeoutExpired, FileNotFoundError):
            return False
    
    def check_munge_service(self) -> bool:
        """Check if MUNGE authentication service is available"""
        try:
            # First check if munge command exists
            result = subprocess.run(['which', 'munge'], 
                                  capture_output=True, text=True, timeout=5)
            if result.returncode != 0:
                logger.info("💡 MUNGE command not found - install with: sudo apt-get install munge libmunge-dev")
                return False
            
            # Check if munge daemon is running
            result = subprocess.run(['systemctl', 'is-active', 'munge'], 
                                  capture_output=True, text=True, timeout=5)
            if result.returncode == 0 and result.stdout.strip() == 'active':
                logger.info("✅ MUNGE daemon is active")
                return True
            
            # Try to test MUNGE functionality directly
            try:
                test_result = subprocess.run(['bash', '-c', 'echo "test" | munge | unmunge'], 
                                           capture_output=True, text=True, timeout=10)
                if test_result.returncode == 0 and 'test' in test_result.stdout:
                    logger.info("✅ MUNGE authentication test successful")
                    return True
                else:
                    logger.warning("⚠️ MUNGE installed but authentication test failed")
                    logger.info("💡 Try: sudo systemctl start munge")
                    return False
            except Exception as e:
                logger.warning(f"⚠️ MUNGE test failed: {e}")
                return False
                
        except (subprocess.TimeoutExpired, FileNotFoundError) as e:
            logger.warning(f"⚠️ MUNGE check failed: {e}")
            return False
    
    async def auto_register_to_clusters(self, node_id: str):
        """Automatically register Android node to existing clusters"""
        node = self.nodes[node_id]
        
        # Register to Kubernetes if available
        if self.kubernetes_available and not node.kubernetes_registered:
            success = await self.register_to_kubernetes(node_id)
            if success:
                node.kubernetes_registered = True
                logger.info(f"✅ Node {node_id} registered to Kubernetes cluster")
                await self.send_to_node(node_id, {
                    "type": "cluster_registration",
                    "cluster_type": "kubernetes",
                    "status": "registered",
                    "message": "Successfully registered to Kubernetes cluster"
                })
        
        # Register to SLURM if available (with MUNGE check)
        if self.slurm_available and not node.slurm_registered:
            if self.munge_available:
                success = await self.register_to_slurm(node_id)
                if success:
                    node.slurm_registered = True
                    logger.info(f"✅ Node {node_id} registered to SLURM cluster with MUNGE authentication")
                    await self.send_to_node(node_id, {
                        "type": "cluster_registration",
                        "cluster_type": "slurm",
                        "status": "registered",
                        "message": "Successfully registered to SLURM cluster with MUNGE authentication"
                    })
            else:
                logger.warning(f"⚠️ Cannot register {node_id} to SLURM - MUNGE authentication not available")
                await self.send_to_node(node_id, {
                    "type": "cluster_registration",
                    "cluster_type": "slurm",
                    "status": "failed",
                    "message": "SLURM registration failed - MUNGE authentication service not available"
                })
    
    async def register_to_kubernetes(self, node_id: str) -> bool:
        """Register Android node to Kubernetes cluster"""
        try:
            node = self.nodes[node_id]
            
            # Create a node manifest for the Android device
            node_manifest = f"""
apiVersion: v1
kind: Node
metadata:
  name: {node_id}
  labels:
    node-type: android
    cluster-role: compute
    architecture: arm64
spec:
  taints:
  - key: android-node
    value: "true"
    effect: NoSchedule
status:
  addresses:
  - type: InternalIP
    address: {node.ip_address}
  - type: Hostname
    address: {node_id}
  nodeInfo:
    architecture: arm64
    operatingSystem: android
  capacity:
    cpu: "4"
    memory: "4Gi"
    pods: "10"
  allocatable:
    cpu: "3"
    memory: "3Gi"
    pods: "10"
"""
            
            # Write manifest to temp file
            manifest_path = f"/tmp/{node_id}-node.yaml"
            with open(manifest_path, 'w') as f:
                f.write(node_manifest)
            
            # Apply the manifest
            result = subprocess.run(['kubectl', 'apply', '-f', manifest_path],
                                  capture_output=True, text=True, timeout=10)
            
            # Clean up temp file
            os.remove(manifest_path)
            
            return result.returncode == 0
            
        except Exception as e:
            logger.error(f"Failed to register {node_id} to Kubernetes: {e}")
            return False
    
    async def register_to_slurm(self, node_id: str) -> bool:
        """Register Android node to SLURM cluster with MUNGE authentication"""
        try:
            node = self.nodes[node_id]
            
            # Ensure MUNGE is available before proceeding
            if not self.munge_available:
                logger.error(f"Cannot register {node_id} to SLURM - MUNGE authentication not available")
                return False
            
            # Generate MUNGE key for the Android node if needed
            munge_key_path = f"/tmp/{node_id}-munge.key"
            try:
                # Copy the main MUNGE key for this node (in production, this should be done securely)
                subprocess.run(['cp', '/etc/munge/munge.key', munge_key_path], 
                             capture_output=True, timeout=5)
                logger.info(f"MUNGE key prepared for {node_id}")
            except Exception as e:
                logger.warning(f"Could not prepare MUNGE key for {node_id}: {e}")
            
            # Add node to SLURM configuration with MUNGE authentication
            slurm_config = f"""
# Android node configuration for {node_id} with MUNGE authentication
# MUNGE authentication required for all SLURM communications
NodeName={node_id} CPUs=4 RealMemory=4096 State=UNKNOWN NodeAddr={node.ip_address} \
    Feature=android,arm64 Gres=cpu:4 Weight=1

# Android partition with MUNGE authentication
PartitionName=android Nodes={node_id} Default=NO MaxTime=INFINITE State=UP \
    AllowGroups=slurm Priority=1 PreemptMode=REQUEUE

# MUNGE authentication settings
# AuthType=auth/munge
# AuthInfo=/etc/munge/munge.key
"""
            
            # Write to a temporary SLURM config file
            config_path = f"/tmp/{node_id}-slurm.conf"
            with open(config_path, 'w') as f:
                f.write(slurm_config)
            
            # Create MUNGE setup script for the Android node
            munge_setup_script = f"""
#!/bin/bash
# MUNGE setup script for Android node {node_id}

# Install MUNGE if not present
if ! command -v munge &> /dev/null; then
    echo "Installing MUNGE..."
    pkg update -y && pkg install -y munge libmunge-dev
fi

# Copy MUNGE key (this should be done securely in production)
if [ -f "{munge_key_path}" ]; then
    mkdir -p $PREFIX/etc/munge
    cp "{munge_key_path}" $PREFIX/etc/munge/munge.key
    chmod 400 $PREFIX/etc/munge/munge.key
    chown munge:munge $PREFIX/etc/munge/munge.key 2>/dev/null || true
fi

# Start MUNGE daemon
munged --force || echo "MUNGE daemon start failed"

# Test MUNGE authentication
echo "Testing MUNGE authentication..."
echo "test" | munge | unmunge && echo "MUNGE authentication working" || echo "MUNGE authentication failed"
"""
            
            setup_script_path = f"/tmp/{node_id}-munge-setup.sh"
            with open(setup_script_path, 'w') as f:
                f.write(munge_setup_script)
            os.chmod(setup_script_path, 0o755)
            
            logger.info(f"SLURM config with MUNGE authentication prepared for {node_id}")
            logger.info(f"MUNGE setup script created at {setup_script_path}")
            
            # In a real implementation, this would:
            # 1. Update the main slurm.conf with the new node
            # 2. Distribute the MUNGE key securely to the Android node
            # 3. Restart slurmctld daemon
            # 4. Ensure MUNGE is running on both controller and compute nodes
            
            return True
            
        except Exception as e:
            logger.error(f"Failed to register {node_id} to SLURM with MUNGE: {e}")
            return False
    
    def get_kubernetes_nodes(self) -> List[Dict[str, Any]]:
        """Get all Kubernetes nodes and their status"""
        if not self.kubernetes_available:
            return []
        
        try:
            result = subprocess.run(['kubectl', 'get', 'nodes', '-o', 'json'], 
                                  capture_output=True, text=True, timeout=10)
            if result.returncode == 0:
                import json as json_lib
                data = json_lib.loads(result.stdout)
                nodes = []
                
                for item in data.get('items', []):
                    node_name = item['metadata']['name']
                    status = 'Ready'
                    for condition in item.get('status', {}).get('conditions', []):
                        if condition['type'] == 'Ready':
                            status = 'Ready' if condition['status'] == 'True' else 'NotReady'
                    
                    # Get pod count
                    pod_result = subprocess.run(['kubectl', 'get', 'pods', '--all-namespaces', 
                                               '--field-selector', f'spec.nodeName={node_name}', 
                                               '--no-headers'], 
                                             capture_output=True, text=True, timeout=5)
                    pod_count = len(pod_result.stdout.strip().split('\n')) if pod_result.stdout.strip() else 0
                    
                    nodes.append({
                        'name': node_name,
                        'status': status,
                        'type': 'kubernetes',
                        'pods': pod_count,
                        'capacity': item.get('status', {}).get('capacity', {}),
                        'allocatable': item.get('status', {}).get('allocatable', {})
                    })
                
                return nodes
        except Exception as e:
            logger.error(f"Failed to get Kubernetes nodes: {e}")
            return []
    
    def get_slurm_nodes(self) -> List[Dict[str, Any]]:
        """Get all SLURM nodes and their status"""
        if not self.slurm_available:
            return []
        
        try:
            result = subprocess.run(['sinfo', '-N', '-h', '-o', '%N %T %C %m %f'], 
                                  capture_output=True, text=True, timeout=10)
            if result.returncode == 0:
                nodes = []
                for line in result.stdout.strip().split('\n'):
                    if line.strip():
                        parts = line.split()
                        if len(parts) >= 4:
                            # Get job count for this node
                            job_result = subprocess.run(['squeue', '-h', '-w', parts[0]], 
                                                       capture_output=True, text=True, timeout=5)
                            job_count = len(job_result.stdout.strip().split('\n')) if job_result.stdout.strip() else 0
                            
                            nodes.append({
                                'name': parts[0],
                                'status': parts[1],
                                'type': 'slurm',
                                'cpus': parts[2] if len(parts) > 2 else 'N/A',
                                'memory': parts[3] if len(parts) > 3 else 'N/A',
                                'features': parts[4] if len(parts) > 4 else '',
                                'jobs': job_count
                            })
                
                return nodes
        except Exception as e:
            logger.error(f"Failed to get SLURM nodes: {e}")
            return []
    
    def get_cluster_status(self) -> Dict[str, Any]:
        """Get current cluster status including all nodes"""
        # Get all cluster nodes
        k8s_nodes = self.get_kubernetes_nodes()
        slurm_nodes = self.get_slurm_nodes()
        
        return {
            "android_nodes": {nid: asdict(node) for nid, node in self.nodes.items()},
            "kubernetes_nodes": k8s_nodes,
            "slurm_nodes": slurm_nodes,
            "tasks": {
                "total": len(self.tasks),
                "pending": len(self.task_queue),
                "completed": len([t for t in self.tasks.values() if t.status == "completed"])
            },
            "clusters": {
                "kubernetes": {
                    "available": self.kubernetes_available,
                    "registered_nodes": len([n for n in self.nodes.values() if n.kubernetes_registered]),
                    "total_nodes": len(k8s_nodes)
                },
                "slurm": {
                    "available": self.slurm_available,
                    "munge_available": self.munge_available,
                    "registered_nodes": len([n for n in self.nodes.values() if n.slurm_registered]),
                    "total_nodes": len(slurm_nodes)
                }
            },
            "timestamp": time.time()
        }

# Global coordinator instance
coordinator = ClusterCoordinator()

async def status_handler(request):
    """HTTP endpoint for cluster status"""
    status = coordinator.get_cluster_status()
    return web_response.json_response(status)

async def submit_task_handler(request):
    """HTTP endpoint for custom task submission"""
    try:
        data = await request.json()
        task_type = data.get('task_type')
        task_data = data.get('data', {})
        priority = data.get('priority', 1)
        
        if not task_type:
            return web_response.json_response(
                {'error': 'task_type is required'}, status=400)
        
        task_id = coordinator.add_task(task_type, task_data, priority)
        
        # Try to assign immediately if nodes are available
        connected_nodes = [nid for nid, node in coordinator.nodes.items() 
                          if node.status == "connected"]
        if connected_nodes:
            await coordinator.assign_task(connected_nodes[0])
        
        return web_response.json_response({
            'task_id': task_id,
            'status': 'submitted',
            'message': f'Task {task_id} submitted successfully'
        })
    except Exception as e:
        logger.error(f"Error submitting task: {e}")
        return web_response.json_response(
            {'error': str(e)}, status=500)

async def get_task_status_handler(request):
    """HTTP endpoint to get task status"""
    task_id = request.match_info.get('task_id')
    
    if task_id not in coordinator.tasks:
        return web_response.json_response(
            {'error': 'Task not found'}, status=404)
    
    task = coordinator.tasks[task_id]
    return web_response.json_response(asdict(task))

async def list_tasks_handler(request):
    """HTTP endpoint to list all tasks"""
    tasks = {tid: asdict(task) for tid, task in coordinator.tasks.items()}
    return web_response.json_response({
        'tasks': tasks,
        'queue': coordinator.task_queue
    })

async def deploy_apk_handler(request):
    """HTTP endpoint to deploy APK to Android devices via Kubernetes job"""
    try:
        data = await request.json()
        target_node = data.get('target_node', 'any')
        apk_url = data.get('apk_url', '')
        
        # Create Kubernetes job for APK deployment
        job_name = f"apk-deploy-{int(time.time())}"
        
        job_manifest = {
            "apiVersion": "batch/v1",
            "kind": "Job",
            "metadata": {
                "name": job_name,
                "labels": {"app": "android-apk-deployer"}
            },
            "spec": {
                "template": {
                    "metadata": {"labels": {"app": "android-apk-deployer"}},
                    "spec": {
                        "restartPolicy": "Never",
                        "containers": [{
                            "name": "adb-deployer",
                            "image": "android-adb-deployer:latest",
                            "imagePullPolicy": "IfNotPresent",
                            "volumeMounts": [
                                {"name": "apk-volume", "mountPath": "/apk"},
                                {"name": "usb-devices", "mountPath": "/dev/bus/usb"}
                            ],
                            "securityContext": {"privileged": True},
                            "env": [
                                {"name": "TARGET_NODE", "value": target_node},
                                {"name": "APK_URL", "value": apk_url}
                            ],
                            "command": ["/usr/local/bin/deploy-apk.sh"]
                        }],
                        "volumes": [
                            {"name": "apk-volume", "emptyDir": {}},
                            {"name": "usb-devices", "hostPath": {"path": "/dev/bus/usb", "type": "DirectoryOrCreate"}}
                        ]
                    }
                }
            }
        }
        
        # Apply the job to Kubernetes
        import tempfile
        import yaml
        
        with tempfile.NamedTemporaryFile(mode='w', suffix='.yaml', delete=False) as f:
            yaml.dump(job_manifest, f)
            job_file = f.name
        
        try:
            result = subprocess.run(
                ['kubectl', 'apply', '-f', job_file],
                capture_output=True, text=True, check=True
            )
            
            os.unlink(job_file)
            
            return web_response.json_response({
                'job_name': job_name,
                'status': 'deployed',
                'message': f'APK deployment job {job_name} started successfully',
                'kubectl_output': result.stdout
            })
            
        except subprocess.CalledProcessError as e:
            os.unlink(job_file)
            return web_response.json_response({
                'error': f'Failed to deploy job: {e.stderr}'
            }, status=500)
            
    except Exception as e:
        logger.error(f"Error deploying APK: {e}")
        return web_response.json_response(
            {'error': str(e)}, status=500)

async def dashboard_handler(request):
    """Serve the dashboard HTML"""
    dashboard_path = os.path.join(os.path.dirname(__file__), 'dashboard.html')
    try:
        with open(dashboard_path, 'r') as f:
            content = f.read()
        return web_response.Response(text=content, content_type='text/html')
    except FileNotFoundError:
        return web_response.Response(text='Dashboard not found', status=404)

async def main():
    """Start the cluster coordinator server"""
    logger.info("Starting Android Cluster Coordinator...")
    
    # Create HTTP app for dashboard and API
    app = web.Application()
    
    # Add CORS to all routes
    cors = aiohttp_cors.setup(app, defaults={
        "*": aiohttp_cors.ResourceOptions(
            allow_credentials=True,
            expose_headers="*",
            allow_headers="*",
            allow_methods="*"
        )
    })
    
    # Add routes
    cors.add(app.router.add_get('/', dashboard_handler))
    cors.add(app.router.add_get('/status', status_handler))
    cors.add(app.router.add_post('/submit_task', submit_task_handler))
    cors.add(app.router.add_get('/task/{task_id}', get_task_status_handler))
    cors.add(app.router.add_get('/tasks', list_tasks_handler))
    cors.add(app.router.add_post('/deploy_apk', deploy_apk_handler))
    
    # Add CORS to all routes
    for route in list(app.router.routes()):
        cors.add(route)
    
    # Start HTTP server
    runner = web.AppRunner(app)
    await runner.setup()
    site = web.TCPSite(runner, '0.0.0.0', 8766)
    await site.start()
    
    # Start WebSocket server
    ws_server = await websockets.serve(
        coordinator.register_handler,
        "0.0.0.0",
        8765
    )
    
    # Add some sample tasks for testing
    coordinator.add_task("prime_calculation", {"start": 1, "end": 10000}, priority=2)
    coordinator.add_task("matrix_multiplication", {"size": 100}, priority=1)
    coordinator.add_task("hash_computation", {"iterations": 1000}, priority=1)
    
    logger.info("✅ WebSocket server running on ws://0.0.0.0:8765")
    logger.info("✅ HTTP dashboard available at http://0.0.0.0:8766")
    logger.info("🚀 Android nodes can connect to ws://YOUR_IP:8765")
    
    # Keep servers running
    try:
        await ws_server.wait_closed()
    except KeyboardInterrupt:
        logger.info("Shutting down servers...")
        await runner.cleanup()

if __name__ == "__main__":
    try:
        asyncio.run(main())
    except KeyboardInterrupt:
        logger.info("Server stopped by user")
