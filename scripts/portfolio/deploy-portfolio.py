#!/usr/bin/env python3

"""
Portfolio Deployment Script - Deploys generated Kubernetes manifests to cluster
and manages portfolio web interface.
"""

import os
import sys
import json
import yaml
import subprocess
import argparse
from pathlib import Path
from typing import Dict, List, Optional
import logging

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

class ClusterDeployer:
    def __init__(self, cluster_host: str, ssh_key_path: str):
        self.cluster_host = cluster_host
        self.ssh_key_path = ssh_key_path
        self.ssh_user = "ansible"
        
    def execute_remote_command(self, command: str) -> tuple:
        """Execute command on remote cluster."""
        ssh_cmd = [
            'ssh', '-i', self.ssh_key_path, 
            '-o', 'StrictHostKeyChecking=no',
            f'{self.ssh_user}@{self.cluster_host}',
            command
        ]
        
        try:
            result = subprocess.run(ssh_cmd, capture_output=True, text=True, check=True)
            return result.returncode, result.stdout, result.stderr
        except subprocess.CalledProcessError as e:
            return e.returncode, e.stdout, e.stderr
    
    def copy_to_cluster(self, local_path: str, remote_path: str):
        """Copy file to cluster."""
        scp_cmd = [
            'scp', '-i', self.ssh_key_path,
            '-o', 'StrictHostKeyChecking=no',
            local_path,
            f'{self.ssh_user}@{self.cluster_host}:{remote_path}'
        ]
        
        subprocess.run(scp_cmd, check=True)
    
    def deploy_manifest(self, manifest_path: str) -> bool:
        """Deploy a Kubernetes manifest to the cluster."""
        # Copy manifest to cluster
        remote_path = f'/tmp/{Path(manifest_path).name}'
        self.copy_to_cluster(manifest_path, remote_path)
        
        # Apply manifest
        returncode, stdout, stderr = self.execute_remote_command(f'kubectl apply -f {remote_path}')
        
        if returncode == 0:
            logger.info(f"Successfully deployed {manifest_path}")
            return True
        else:
            logger.error(f"Failed to deploy {manifest_path}: {stderr}")
            return False
    
    def get_service_urls(self) -> Dict[str, str]:
        """Get URLs for all portfolio services."""
        returncode, stdout, stderr = self.execute_remote_command(
            "kubectl get services -o json | jq -r '.items[] | select(.metadata.labels.project) | \"\\(.metadata.labels.project):\\(.spec.ports[0].nodePort)\"'"
        )
        
        service_urls = {}
        if returncode == 0:
            for line in stdout.strip().split('\n'):
                if ':' in line:
                    project, port = line.split(':', 1)
                    service_urls[project] = f"http://{self.cluster_host}:{port}"
        
        return service_urls

class PortManager:
    def __init__(self, cluster_deployer: ClusterDeployer):
        self.deployer = cluster_deployer
        self.used_ports = set()
        self._load_used_ports()
    
    def _load_used_ports(self):
        """Load currently used NodePorts from cluster."""
        returncode, stdout, stderr = self.deployer.execute_remote_command(
            "kubectl get services -o json | jq -r '.items[].spec.ports[]?.nodePort // empty'"
        )
        
        if returncode == 0:
            for line in stdout.strip().split('\n'):
                if line.strip().isdigit():
                    self.used_ports.add(int(line.strip()))
    
    def get_available_port(self, start_port: int = 30000) -> int:
        """Get next available port starting from start_port."""
        port = start_port
        while port in self.used_ports or port > 32767:  # NodePort range limit
            port += 1
        
        self.used_ports.add(port)
        return port
    
    def resolve_port_conflicts(self, manifest_content: str, project_name: str) -> str:
        """Resolve port conflicts in manifest by assigning new ports."""
        manifest = yaml.safe_load(manifest_content)
        
        if manifest.get('kind') == 'Service' and manifest.get('spec', {}).get('type') == 'NodePort':
            ports = manifest['spec'].get('ports', [])
            
            for port_spec in ports:
                if 'nodePort' in port_spec:
                    old_port = port_spec['nodePort']
                    if old_port in self.used_ports:
                        new_port = self.get_available_port()
                        port_spec['nodePort'] = new_port
                        logger.info(f"Resolved port conflict for {project_name}: {old_port} -> {new_port}")
        
        return yaml.dump(manifest)

def create_portfolio_web_interface(portfolio_data: Dict, service_urls: Dict[str, str]) -> str:
    """Create HTML for portfolio web interface."""
    
    html_template = """
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Kubernetes Cluster Portfolio</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        
        body {
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            min-height: 100vh;
            padding: 20px;
        }
        
        .container {
            max-width: 1200px;
            margin: 0 auto;
            background: white;
            border-radius: 15px;
            box-shadow: 0 20px 40px rgba(0,0,0,0.1);
            overflow: hidden;
        }
        
        .header {
            background: linear-gradient(135deg, #2c3e50, #34495e);
            color: white;
            padding: 40px;
            text-align: center;
        }
        
        .header h1 {
            font-size: 2.5em;
            margin-bottom: 10px;
        }
        
        .stats {
            display: flex;
            justify-content: center;
            gap: 30px;
            margin-top: 20px;
        }
        
        .stat {
            text-align: center;
        }
        
        .stat-number {
            font-size: 2em;
            font-weight: bold;
            color: #3498db;
        }
        
        .projects {
            padding: 40px;
        }
        
        .project-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(350px, 1fr));
            gap: 25px;
        }
        
        .project-card {
            border: 1px solid #e0e0e0;
            border-radius: 10px;
            padding: 25px;
            transition: transform 0.3s, box-shadow 0.3s;
            position: relative;
        }
        
        .project-card:hover {
            transform: translateY(-5px);
            box-shadow: 0 10px 25px rgba(0,0,0,0.1);
        }
        
        .project-card.flagged {
            border-left: 5px solid #e74c3c;
        }
        
        .project-title {
            font-size: 1.3em;
            font-weight: bold;
            color: #2c3e50;
            margin-bottom: 10px;
        }
        
        .project-description {
            color: #666;
            margin-bottom: 15px;
            line-height: 1.5;
        }
        
        .project-links {
            display: flex;
            gap: 10px;
            flex-wrap: wrap;
        }
        
        .link-btn {
            padding: 8px 16px;
            border-radius: 20px;
            text-decoration: none;
            font-size: 0.9em;
            font-weight: 500;
            transition: all 0.3s;
        }
        
        .link-github {
            background: #333;
            color: white;
        }
        
        .link-pages {
            background: #3498db;
            color: white;
        }
        
        .link-app {
            background: #27ae60;
            color: white;
        }
        
        .link-btn:hover {
            transform: scale(1.05);
            opacity: 0.9;
        }
        
        .flags {
            margin-top: 15px;
        }
        
        .flag {
            display: inline-block;
            background: #e74c3c;
            color: white;
            padding: 4px 8px;
            border-radius: 12px;
            font-size: 0.8em;
            margin-right: 5px;
        }
        
        .services {
            margin-top: 15px;
            font-size: 0.9em;
            color: #666;
        }
        
        .filter-bar {
            margin-bottom: 30px;
            display: flex;
            gap: 15px;
            flex-wrap: wrap;
        }
        
        .filter-btn {
            padding: 10px 20px;
            border: 2px solid #3498db;
            background: white;
            color: #3498db;
            border-radius: 25px;
            cursor: pointer;
            transition: all 0.3s;
        }
        
        .filter-btn.active {
            background: #3498db;
            color: white;
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>🚀 Kubernetes Cluster Portfolio</h1>
            <p>Automated deployment and hosting of development projects</p>
            
            <div class="stats">
                <div class="stat">
                    <div class="stat-number">{{ total_projects }}</div>
                    <div>Total Projects</div>
                </div>
                <div class="stat">
                    <div class="stat-number">{{ projects_with_docker }}</div>
                    <div>Docker Projects</div>
                </div>
                <div class="stat">
                    <div class="stat-number">{{ projects_with_web }}</div>
                    <div>Web Apps</div>
                </div>
                <div class="stat">
                    <div class="stat-number">{{ flagged_projects }}</div>
                    <div>Need Attention</div>
                </div>
            </div>
        </div>
        
        <div class="projects">
            <div class="filter-bar">
                <button class="filter-btn active" onclick="filterProjects('all')">All Projects</button>
                <button class="filter-btn" onclick="filterProjects('web')">Web Apps</button>
                <button class="filter-btn" onclick="filterProjects('docker')">Docker Projects</button>
                <button class="filter-btn" onclick="filterProjects('flagged')">Flagged</button>
            </div>
            
            <div class="project-grid" id="projectGrid">
                {% for project in projects %}
                <div class="project-card {{ 'flagged' if project.validation_flags else '' }}" 
                     data-tags="{{ 'web' if project.has_web_interface else '' }} {{ 'docker' if project.has_docker_compose else '' }} {{ 'flagged' if project.validation_flags else '' }}">
                    
                    <div class="project-title">{{ project.name }}</div>
                    
                    <div class="project-description">
                        {{ project.description or 'No description available' }}
                    </div>
                    
                    <div class="project-links">
                        <a href="{{ project.repo_url }}" class="link-btn link-github" target="_blank">
                            📁 Repository
                        </a>
                        
                        {% if project.github_pages_url %}
                        <a href="{{ project.github_pages_url }}" class="link-btn link-pages" target="_blank">
                            📄 GitHub Pages
                        </a>
                        {% endif %}
                        
                        {% if project.name in service_urls %}
                        <a href="{{ service_urls[project.name] }}" class="link-btn link-app" target="_blank">
                            🌐 Live App
                        </a>
                        {% endif %}
                    </div>
                    
                    {% if project.validation_flags %}
                    <div class="flags">
                        {% for flag in project.validation_flags %}
                        <span class="flag">{{ flag.replace('_', ' ').title() }}</span>
                        {% endfor %}
                    </div>
                    {% endif %}
                    
                    {% if project.docker_services %}
                    <div class="services">
                        <strong>Services:</strong> {{ ', '.join(project.docker_services) }}
                    </div>
                    {% endif %}
                </div>
                {% endfor %}
            </div>
        </div>
    </div>
    
    <script>
        function filterProjects(filter) {
            const cards = document.querySelectorAll('.project-card');
            const buttons = document.querySelectorAll('.filter-btn');
            
            // Update button states
            buttons.forEach(btn => btn.classList.remove('active'));
            event.target.classList.add('active');
            
            // Filter cards
            cards.forEach(card => {
                const tags = card.dataset.tags;
                let show = false;
                
                if (filter === 'all') {
                    show = true;
                } else if (filter === 'web' && tags.includes('web')) {
                    show = true;
                } else if (filter === 'docker' && tags.includes('docker')) {
                    show = true;
                } else if (filter === 'flagged' && tags.includes('flagged')) {
                    show = true;
                }
                
                card.style.display = show ? 'block' : 'none';
            });
        }
    </script>
</body>
</html>
    """
    
    from jinja2 import Template
    template = Template(html_template)
    
    return template.render(
        projects=portfolio_data['projects'],
        service_urls=service_urls,
        total_projects=portfolio_data['total_projects'],
        projects_with_docker=portfolio_data['projects_with_docker'],
        projects_with_web=portfolio_data['projects_with_web_interface'],
        flagged_projects=portfolio_data['flagged_projects']
    )

def main():
    parser = argparse.ArgumentParser(description='Deploy portfolio to Kubernetes cluster')
    parser.add_argument('--cluster-host', required=True, help='Cluster host IP')
    parser.add_argument('--ssh-key', required=True, help='SSH private key path')
    parser.add_argument('--portfolio-dir', required=True, help='Portfolio directory')
    
    args = parser.parse_args()
    
    portfolio_dir = Path(args.portfolio_dir)
    portfolio_file = portfolio_dir / 'portfolio.json'
    
    if not portfolio_file.exists():
        logger.error(f"Portfolio file not found: {portfolio_file}")
        sys.exit(1)
    
    # Load portfolio data
    with open(portfolio_file) as f:
        portfolio_data = json.load(f)
    
    # Initialize deployer and port manager
    deployer = ClusterDeployer(args.cluster_host, args.ssh_key)
    port_manager = PortManager(deployer)
    
    # Deploy all project manifests
    deployed_projects = []
    
    for project_dir in portfolio_dir.iterdir():
        if not project_dir.is_dir() or project_dir.name == '__pycache__':
            continue
        
        project_name = project_dir.name
        logger.info(f"Deploying project: {project_name}")
        
        # Deploy all manifests in project directory
        success = True
        for manifest_file in project_dir.glob('*.yaml'):
            # Read and resolve port conflicts
            manifest_content = manifest_file.read_text()
            resolved_content = port_manager.resolve_port_conflicts(manifest_content, project_name)
            
            # Write resolved manifest
            resolved_file = project_dir / f"resolved_{manifest_file.name}"
            resolved_file.write_text(resolved_content)
            
            # Deploy resolved manifest
            if not deployer.deploy_manifest(str(resolved_file)):
                success = False
        
        if success:
            deployed_projects.append(project_name)
    
    # Get service URLs
    service_urls = deployer.get_service_urls()
    
    # Create and deploy portfolio web interface
    portfolio_html = create_portfolio_web_interface(portfolio_data, service_urls)
    
    # Save portfolio HTML
    portfolio_html_file = portfolio_dir / 'portfolio.html'
    portfolio_html_file.write_text(portfolio_html)
    
    # Deploy portfolio web interface as ConfigMap and Service
    portfolio_configmap = {
        'apiVersion': 'v1',
        'kind': 'ConfigMap',
        'metadata': {
            'name': 'portfolio-html',
            'labels': {'app': 'portfolio'}
        },
        'data': {
            'index.html': portfolio_html
        }
    }
    
    portfolio_deployment = {
        'apiVersion': 'apps/v1',
        'kind': 'Deployment',
        'metadata': {
            'name': 'portfolio',
            'labels': {'app': 'portfolio'}
        },
        'spec': {
            'replicas': 1,
            'selector': {'matchLabels': {'app': 'portfolio'}},
            'template': {
                'metadata': {'labels': {'app': 'portfolio'}},
                'spec': {
                    'containers': [{
                        'name': 'nginx',
                        'image': 'nginx:alpine',
                        'ports': [{'containerPort': 80}],
                        'volumeMounts': [{
                            'name': 'html',
                            'mountPath': '/usr/share/nginx/html'
                        }]
                    }],
                    'volumes': [{
                        'name': 'html',
                        'configMap': {'name': 'portfolio-html'}
                    }]
                }
            }
        }
    }
    
    portfolio_service = {
        'apiVersion': 'v1',
        'kind': 'Service',
        'metadata': {
            'name': 'portfolio-service',
            'labels': {'app': 'portfolio'}
        },
        'spec': {
            'type': 'NodePort',
            'selector': {'app': 'portfolio'},
            'ports': [{
                'port': 80,
                'targetPort': 80,
                'nodePort': 30080
            }]
        }
    }
    
    # Deploy portfolio components
    for manifest, name in [
        (portfolio_configmap, 'configmap'),
        (portfolio_deployment, 'deployment'), 
        (portfolio_service, 'service')
    ]:
        manifest_file = portfolio_dir / f'portfolio-{name}.yaml'
        manifest_file.write_text(yaml.dump(manifest))
        deployer.deploy_manifest(str(manifest_file))
    
    logger.info(f"Portfolio deployment complete!")
    logger.info(f"Deployed {len(deployed_projects)} projects")
    logger.info(f"Portfolio web interface: http://{args.cluster_host}:30080")

if __name__ == '__main__':
    main()
