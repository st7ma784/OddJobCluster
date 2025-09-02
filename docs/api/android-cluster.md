# Android Cluster API Reference

## Overview

The Android Cluster API provides REST endpoints for managing tasks, monitoring cluster status, and integrating with the Android compute nodes.

## Base URL

```
http://<cluster-ip>:8766
```

For Kubernetes deployment:
```
http://<node-ip>:30766
```

## Authentication

Currently, the API operates without authentication. In production environments, implement proper authentication and authorization mechanisms.

## Endpoints

### Task Management

#### Submit Task
Submit a custom task to the Android cluster for execution.

**Endpoint:** `POST /submit_task`

**Request Body:**
```json
{
  "task_type": "string",
  "data": {},
  "priority": 1
}
```

**Parameters:**
- `task_type` (required): Type of task to execute
  - `prime_calculation` - Calculate prime numbers
  - `matrix_multiplication` - Matrix operations
  - `hash_computation` - Cryptographic hashing
  - `custom` - Custom task type
- `data` (optional): Task-specific data object
- `priority` (optional): Task priority (1=low, 2=medium, 3=high)

**Example Request:**
```bash
curl -X POST http://localhost:8766/submit_task \
  -H "Content-Type: application/json" \
  -d '{
    "task_type": "prime_calculation",
    "data": {"start": 1, "end": 10000},
    "priority": 2
  }'
```

**Response:**
```json
{
  "task_id": "uuid-string",
  "status": "submitted",
  "message": "Task uuid-string submitted successfully"
}
```

#### Get Task Status
Retrieve the status and result of a specific task.

**Endpoint:** `GET /task/{task_id}`

**Parameters:**
- `task_id` (required): UUID of the task

**Example Request:**
```bash
curl http://localhost:8766/task/12345678-1234-1234-1234-123456789abc
```

**Response:**
```json
{
  "task_id": "12345678-1234-1234-1234-123456789abc",
  "task_type": "prime_calculation",
  "data": {"start": 1, "end": 10000},
  "priority": 2,
  "created_at": 1693920000.0,
  "assigned_to": "android-192-168-1-100",
  "status": "completed",
  "result": {"count": 1229, "primes": [2, 3, 5, 7, ...]}
}
```

**Status Values:**
- `pending` - Task queued, waiting for assignment
- `assigned` - Task assigned to Android node
- `completed` - Task finished successfully
- `failed` - Task execution failed

#### List All Tasks
Get a list of all tasks in the system.

**Endpoint:** `GET /tasks`

**Example Request:**
```bash
curl http://localhost:8766/tasks
```

**Response:**
```json
{
  "tasks": {
    "task-id-1": {
      "task_id": "task-id-1",
      "task_type": "prime_calculation",
      "status": "completed",
      ...
    },
    "task-id-2": {
      "task_id": "task-id-2",
      "task_type": "matrix_multiplication",
      "status": "pending",
      ...
    }
  },
  "queue": ["task-id-2", "task-id-3"]
}
```

### Cluster Status

#### Get Cluster Status
Retrieve comprehensive cluster status including all nodes and their current state.

**Endpoint:** `GET /status`

**Example Request:**
```bash
curl http://localhost:8766/status
```

**Response:**
```json
{
  "android_nodes": {
    "android-192-168-1-100": {
      "node_id": "android-192-168-1-100",
      "ip_address": "192.168.1.100",
      "status": "connected",
      "last_seen": 1693920000.0,
      "tasks_completed": 15,
      "capabilities": ["cpu", "memory"],
      "performance_score": 85.5,
      "kubernetes_registered": true,
      "slurm_registered": true
    }
  },
  "kubernetes_nodes": [
    {
      "name": "master-node",
      "status": "Ready",
      "type": "kubernetes",
      "pods": 25,
      "capacity": {
        "cpu": "4",
        "memory": "8Gi"
      },
      "allocatable": {
        "cpu": "3800m",
        "memory": "7Gi"
      }
    }
  ],
  "slurm_nodes": [
    {
      "name": "compute-01",
      "status": "idle",
      "type": "slurm",
      "cpus": "8/8/0/8",
      "memory": "16384",
      "features": "cpu,gpu",
      "jobs": 0
    }
  ],
  "tasks": {
    "total": 50,
    "pending": 3,
    "completed": 47
  },
  "clusters": {
    "kubernetes": {
      "available": true,
      "registered_nodes": 5,
      "total_nodes": 3
    },
    "slurm": {
      "available": true,
      "munge_available": true,
      "registered_nodes": 5,
      "total_nodes": 2
    }
  },
  "timestamp": 1693920000.0
}
```

## Task Types

### Prime Calculation
Calculate prime numbers within a specified range.

**Data Format:**
```json
{
  "start": 1,
  "end": 10000
}
```

**Result Format:**
```json
{
  "count": 1229,
  "primes": [2, 3, 5, 7, 11, ...],
  "execution_time_ms": 1250
}
```

### Matrix Multiplication
Perform matrix multiplication operations.

**Data Format:**
```json
{
  "size": 100
}
```

**Result Format:**
```json
{
  "result_matrix": [[...], [...], ...],
  "execution_time_ms": 2500,
  "operations": 1000000
}
```

### Hash Computation
Perform cryptographic hash computations.

**Data Format:**
```json
{
  "iterations": 1000,
  "algorithm": "sha256"
}
```

**Result Format:**
```json
{
  "hashes": ["abc123...", "def456...", ...],
  "execution_time_ms": 800,
  "hash_rate": 1250
}
```

### Custom Tasks
Submit custom tasks with arbitrary data structures.

**Data Format:**
```json
{
  "custom_parameter": "value",
  "nested_data": {
    "key": "value"
  }
}
```

## Error Handling

### Error Response Format
```json
{
  "error": "Error description",
  "code": "ERROR_CODE",
  "details": {}
}
```

### Common Error Codes

| Code | Description |
|------|-------------|
| `INVALID_TASK_TYPE` | Unknown or unsupported task type |
| `MISSING_PARAMETERS` | Required parameters not provided |
| `TASK_NOT_FOUND` | Task ID does not exist |
| `CLUSTER_UNAVAILABLE` | Cluster services not available |
| `NODE_OFFLINE` | No Android nodes available |

## Rate Limiting

Currently, no rate limiting is implemented. In production:
- Implement per-client rate limiting
- Add task queue size limits
- Monitor resource usage

## WebSocket API

For real-time communication with Android nodes:

**Endpoint:** `ws://<cluster-ip>:8765`

**Message Format:**
```json
{
  "type": "message_type",
  "data": {}
}
```

**Message Types:**
- `task_assignment` - Assign task to node
- `task_result` - Task completion result
- `heartbeat` - Node health check
- `capabilities` - Node capability report

## SDK Examples

### Python SDK Example
```python
import requests
import json

class AndroidClusterClient:
    def __init__(self, base_url):
        self.base_url = base_url
    
    def submit_task(self, task_type, data, priority=1):
        response = requests.post(
            f"{self.base_url}/submit_task",
            json={
                "task_type": task_type,
                "data": data,
                "priority": priority
            }
        )
        return response.json()
    
    def get_task_status(self, task_id):
        response = requests.get(f"{self.base_url}/task/{task_id}")
        return response.json()
    
    def get_cluster_status(self):
        response = requests.get(f"{self.base_url}/status")
        return response.json()

# Usage
client = AndroidClusterClient("http://localhost:8766")
result = client.submit_task("prime_calculation", {"start": 1, "end": 1000})
print(f"Task submitted: {result['task_id']}")
```

### JavaScript SDK Example
```javascript
class AndroidClusterClient {
    constructor(baseUrl) {
        this.baseUrl = baseUrl;
    }
    
    async submitTask(taskType, data, priority = 1) {
        const response = await fetch(`${this.baseUrl}/submit_task`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json'
            },
            body: JSON.stringify({
                task_type: taskType,
                data: data,
                priority: priority
            })
        });
        return await response.json();
    }
    
    async getTaskStatus(taskId) {
        const response = await fetch(`${this.baseUrl}/task/${taskId}`);
        return await response.json();
    }
    
    async getClusterStatus() {
        const response = await fetch(`${this.baseUrl}/status`);
        return await response.json();
    }
}

// Usage
const client = new AndroidClusterClient('http://localhost:8766');
client.submitTask('matrix_multiplication', {size: 50})
    .then(result => console.log('Task submitted:', result.task_id));
```

## Monitoring and Metrics

The API provides built-in monitoring capabilities:

- **Task Metrics**: Completion rates, execution times, error rates
- **Node Metrics**: Connection status, performance scores, task counts
- **Cluster Metrics**: Resource utilization, queue lengths, throughput

Access metrics through the `/status` endpoint or integrate with monitoring systems like Prometheus.
