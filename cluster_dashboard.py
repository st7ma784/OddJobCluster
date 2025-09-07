#!/usr/bin/env python3
"""
OddJobCluster Dashboard
A simple web dashboard to monitor the SLURM and Kubernetes cluster
"""

from flask import Flask, render_template_string, jsonify
import subprocess
import json
import datetime

app = Flask(__name__)

HTML_TEMPLATE = """
<!DOCTYPE html>
<html>
<head>
    <title>OddJobCluster Dashboard</title>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; background-color: #f5f5f5; }
        .container { max-width: 1200px; margin: 0 auto; }
        .header { background-color: #2c3e50; color: white; padding: 20px; border-radius: 5px; margin-bottom: 20px; }
        .section { background-color: white; padding: 20px; margin-bottom: 20px; border-radius: 5px; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }
        .status-good { color: #27ae60; font-weight: bold; }
        .status-bad { color: #e74c3c; font-weight: bold; }
        .status-warning { color: #f39c12; font-weight: bold; }
        pre { background-color: #ecf0f1; padding: 10px; border-radius: 3px; overflow-x: auto; }
        .refresh-btn { background-color: #3498db; color: white; padding: 10px 20px; border: none; border-radius: 3px; cursor: pointer; }
        .refresh-btn:hover { background-color: #2980b9; }
        .grid { display: grid; grid-template-columns: 1fr 1fr; gap: 20px; }
        @media (max-width: 768px) { .grid { grid-template-columns: 1fr; } }
    </style>
    <script>
        function refreshData() {
            fetch('/api/status')
                .then(response => response.json())
                .then(data => {
                    document.getElementById('slurm-info').innerHTML = data.slurm_info;
                    document.getElementById('k8s-nodes').innerHTML = data.k8s_nodes;
                    document.getElementById('k8s-pods').innerHTML = data.k8s_pods;
                    document.getElementById('last-update').innerHTML = 'Last updated: ' + new Date().toLocaleString();
                });
        }
        setInterval(refreshData, 30000); // Refresh every 30 seconds
    </script>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>🖥️ OddJobCluster Dashboard</h1>
            <p>Heterogeneous SLURM + Kubernetes Cluster Monitor</p>
            <button class="refresh-btn" onclick="refreshData()">🔄 Refresh</button>
            <span id="last-update" style="float: right; opacity: 0.8;">{{ timestamp }}</span>
        </div>
        
        <div class="grid">
            <div class="section">
                <h2>🔧 SLURM Cluster Status</h2>
                <pre id="slurm-info">{{ slurm_info }}</pre>
            </div>
            
            <div class="section">
                <h2>☸️ Kubernetes Nodes</h2>
                <pre id="k8s-nodes">{{ k8s_nodes }}</pre>
            </div>
        </div>
        
        <div class="section">
            <h2>🐳 Kubernetes Pods</h2>
            <pre id="k8s-pods">{{ k8s_pods }}</pre>
        </div>
        
        <div class="section">
            <h2>📊 Cluster Information</h2>
            <p><strong>Master Node:</strong> 192.168.4.157 (steve-IdeaPad-Flex-5-15ALC05)</p>
            <p><strong>Worker Node:</strong> 192.168.5.57 (steve-ThinkPad-L490)</p>
            <p><strong>SLURM Version:</strong> 24.11.3</p>
            <p><strong>Kubernetes Version:</strong> v1.28.15</p>
        </div>
    </div>
</body>
</html>
"""

def run_command(cmd):
    """Run a shell command and return output"""
    try:
        result = subprocess.run(cmd, shell=True, capture_output=True, text=True, timeout=10)
        return result.stdout if result.returncode == 0 else f"Error: {result.stderr}"
    except subprocess.TimeoutExpired:
        return "Error: Command timed out"
    except Exception as e:
        return f"Error: {str(e)}"

@app.route('/')
def dashboard():
    slurm_info = run_command('sinfo && echo && squeue')
    k8s_nodes = run_command('kubectl get nodes')
    k8s_pods = run_command('kubectl get pods --all-namespaces')
    timestamp = datetime.datetime.now().strftime('%Y-%m-%d %H:%M:%S')
    
    return render_template_string(HTML_TEMPLATE, 
                                slurm_info=slurm_info,
                                k8s_nodes=k8s_nodes, 
                                k8s_pods=k8s_pods,
                                timestamp=timestamp)

@app.route('/api/status')
def api_status():
    """API endpoint for AJAX updates"""
    return jsonify({
        'slurm_info': run_command('sinfo && echo && squeue'),
        'k8s_nodes': run_command('kubectl get nodes'),
        'k8s_pods': run_command('kubectl get pods --all-namespaces'),
        'timestamp': datetime.datetime.now().strftime('%Y-%m-%d %H:%M:%S')
    })

if __name__ == '__main__':
    print("Starting OddJobCluster Dashboard...")
    print("Access the dashboard at: http://localhost:8080")
    app.run(host='0.0.0.0', port=8080, debug=False)
