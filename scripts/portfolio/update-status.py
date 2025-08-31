#!/usr/bin/env python3

"""
Portfolio Status Updater - Updates portfolio status and monitors deployments
"""

import os
import sys
import json
import subprocess
import argparse
from pathlib import Path
import logging

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

class StatusUpdater:
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
    
    def get_deployment_status(self) -> dict:
        """Get status of all portfolio deployments."""
        # Get deployments
        returncode, stdout, stderr = self.execute_remote_command(
            "kubectl get deployments -o json"
        )
        
        status = {
            'deployments': {},
            'services': {},
            'pods': {},
            'portfolio_url': f"http://{self.cluster_host}:30080"
        }
        
        if returncode == 0:
            import json
            deployments = json.loads(stdout)
            
            for deployment in deployments.get('items', []):
                name = deployment['metadata']['name']
                spec_replicas = deployment['spec']['replicas']
                ready_replicas = deployment['status'].get('readyReplicas', 0)
                
                status['deployments'][name] = {
                    'ready': ready_replicas == spec_replicas,
                    'replicas': f"{ready_replicas}/{spec_replicas}"
                }
        
        # Get services
        returncode, stdout, stderr = self.execute_remote_command(
            "kubectl get services -o json"
        )
        
        if returncode == 0:
            services = json.loads(stdout)
            
            for service in services.get('items', []):
                name = service['metadata']['name']
                service_type = service['spec'].get('type', 'ClusterIP')
                
                if service_type == 'NodePort':
                    ports = service['spec'].get('ports', [])
                    node_ports = [p.get('nodePort') for p in ports if p.get('nodePort')]
                    
                    status['services'][name] = {
                        'type': service_type,
                        'ports': node_ports,
                        'urls': [f"http://{self.cluster_host}:{port}" for port in node_ports]
                    }
        
        return status
    
    def check_portfolio_health(self) -> dict:
        """Check health of portfolio system."""
        health = {
            'portfolio_accessible': False,
            'kubernetes_healthy': False,
            'total_projects': 0,
            'running_projects': 0
        }
        
        # Check if portfolio is accessible
        returncode, stdout, stderr = self.execute_remote_command(
            f"curl -s -o /dev/null -w '%{{http_code}}' http://localhost:30080"
        )
        
        if returncode == 0 and stdout.strip() == '200':
            health['portfolio_accessible'] = True
        
        # Check Kubernetes health
        returncode, stdout, stderr = self.execute_remote_command("kubectl get nodes")
        health['kubernetes_healthy'] = returncode == 0
        
        # Count deployments
        status = self.get_deployment_status()
        health['total_projects'] = len(status['deployments'])
        health['running_projects'] = sum(1 for d in status['deployments'].values() if d['ready'])
        
        return health

def main():
    parser = argparse.ArgumentParser(description='Update portfolio status')
    parser.add_argument('--cluster-host', required=True, help='Cluster host IP')
    parser.add_argument('--ssh-key', required=True, help='SSH private key path')
    
    args = parser.parse_args()
    
    updater = StatusUpdater(args.cluster_host, args.ssh_key)
    
    # Get deployment status
    status = updater.get_deployment_status()
    health = updater.check_portfolio_health()
    
    # Log status
    logger.info("=== Portfolio Status ===")
    logger.info(f"Portfolio URL: {status['portfolio_url']}")
    logger.info(f"Portfolio accessible: {health['portfolio_accessible']}")
    logger.info(f"Kubernetes healthy: {health['kubernetes_healthy']}")
    logger.info(f"Projects: {health['running_projects']}/{health['total_projects']} running")
    
    logger.info("\n=== Deployment Status ===")
    for name, deploy_status in status['deployments'].items():
        status_icon = "✅" if deploy_status['ready'] else "❌"
        logger.info(f"{status_icon} {name}: {deploy_status['replicas']}")
    
    logger.info("\n=== Service URLs ===")
    for name, service in status['services'].items():
        for url in service['urls']:
            logger.info(f"🌐 {name}: {url}")
    
    # Save status to file for GitHub Actions
    status_data = {
        'status': status,
        'health': health,
        'timestamp': str(__import__('datetime').datetime.now())
    }
    
    with open('portfolio-status.json', 'w') as f:
        json.dump(status_data, f, indent=2)
    
    # Exit with error code if not healthy
    if not health['kubernetes_healthy'] or not health['portfolio_accessible']:
        sys.exit(1)

if __name__ == '__main__':
    main()
