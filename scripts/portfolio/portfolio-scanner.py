#!/usr/bin/env python3

"""
Portfolio Scanner - Scans GitHub repositories for Docker Compose files
and generates Kubernetes deployments for cluster portfolio hosting.
"""

import os
import sys
import json
import yaml
import requests
import argparse
from pathlib import Path
from typing import Dict, List, Optional, Any
from dataclasses import dataclass, asdict
import re
import logging

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

@dataclass
class ProjectInfo:
    name: str
    repo_url: str
    description: str
    has_readme: bool
    has_github_pages: bool
    has_docker_compose: bool
    has_web_interface: bool
    docker_services: List[str]
    exposed_ports: List[int]
    github_pages_url: Optional[str] = None
    readme_quality: str = "unknown"  # basic, verbose, missing
    validation_flags: List[str] = None
    
    def __post_init__(self):
        if self.validation_flags is None:
            self.validation_flags = []

class GitHubScanner:
    def __init__(self, token: str, username: str = None):
        self.token = token
        self.username = username
        self.session = requests.Session()
        self.session.headers.update({
            'Authorization': f'token {token}',
            'Accept': 'application/vnd.github.v3+json'
        })
        
    def get_user_repos(self) -> List[Dict]:
        """Get all repositories for the authenticated user."""
        repos = []
        page = 1
        
        while True:
            url = f'https://api.github.com/user/repos?page={page}&per_page=100'
            response = self.session.get(url)
            response.raise_for_status()
            
            page_repos = response.json()
            if not page_repos:
                break
                
            repos.extend(page_repos)
            page += 1
            
        logger.info(f"Found {len(repos)} repositories")
        return repos
    
    def get_file_content(self, repo_name: str, file_path: str) -> Optional[str]:
        """Get content of a file from repository."""
        url = f'https://api.github.com/repos/{repo_name}/contents/{file_path}'
        response = self.session.get(url)
        
        if response.status_code == 404:
            return None
            
        response.raise_for_status()
        content = response.json()
        
        if content.get('encoding') == 'base64':
            import base64
            return base64.b64decode(content['content']).decode('utf-8')
        
        return content.get('content')
    
    def check_github_pages(self, repo_name: str) -> Optional[str]:
        """Check if repository has GitHub Pages enabled."""
        url = f'https://api.github.com/repos/{repo_name}/pages'
        response = self.session.get(url)
        
        if response.status_code == 200:
            pages_info = response.json()
            return pages_info.get('html_url')
        
        return None
    
    def analyze_readme(self, content: str) -> str:
        """Analyze README quality."""
        if not content:
            return "missing"
        
        lines = content.split('\n')
        non_empty_lines = [line.strip() for line in lines if line.strip()]
        
        # Basic quality checks
        has_description = any(len(line) > 50 for line in non_empty_lines[:5])
        has_installation = any('install' in line.lower() for line in non_empty_lines)
        has_usage = any('usage' in line.lower() or 'example' in line.lower() for line in non_empty_lines)
        has_sections = len([line for line in non_empty_lines if line.startswith('#')]) >= 3
        
        if len(non_empty_lines) > 20 and has_description and has_installation and has_usage and has_sections:
            return "verbose"
        elif len(non_empty_lines) > 5:
            return "basic"
        else:
            return "minimal"

class DockerComposeParser:
    @staticmethod
    def parse_compose_file(content: str) -> Dict[str, Any]:
        """Parse Docker Compose file and extract service information."""
        try:
            compose_data = yaml.safe_load(content)
            services = compose_data.get('services', {})
            
            parsed_services = []
            exposed_ports = []
            
            for service_name, service_config in services.items():
                service_info = {
                    'name': service_name,
                    'image': service_config.get('image'),
                    'build': service_config.get('build'),
                    'ports': service_config.get('ports', []),
                    'environment': service_config.get('environment', {}),
                    'volumes': service_config.get('volumes', []),
                    'depends_on': service_config.get('depends_on', [])
                }
                
                # Extract exposed ports
                for port_mapping in service_config.get('ports', []):
                    if isinstance(port_mapping, str):
                        # Format: "host:container" or "port"
                        if ':' in port_mapping:
                            host_port = port_mapping.split(':')[0]
                        else:
                            host_port = port_mapping
                        
                        try:
                            exposed_ports.append(int(host_port))
                        except ValueError:
                            pass
                    elif isinstance(port_mapping, int):
                        exposed_ports.append(port_mapping)
                
                parsed_services.append(service_info)
            
            return {
                'services': parsed_services,
                'exposed_ports': list(set(exposed_ports)),
                'has_web_interface': any(port in [80, 443, 3000, 8000, 8080, 5000, 4200] for port in exposed_ports)
            }
            
        except yaml.YAMLError as e:
            logger.error(f"Error parsing Docker Compose file: {e}")
            return {'services': [], 'exposed_ports': [], 'has_web_interface': False}

class KubernetesGenerator:
    def __init__(self, base_port: int = 30000):
        self.base_port = base_port
        self.used_ports = set()
    
    def generate_k8s_manifests(self, project: ProjectInfo, compose_content: str) -> Dict[str, str]:
        """Generate Kubernetes manifests from Docker Compose."""
        compose_data = DockerComposeParser.parse_compose_file(compose_content)
        manifests = {}
        
        for service in compose_data['services']:
            if not service['image'] and service['build']:
                # Skip services that need to be built - we only want pre-built images
                logger.warning(f"Skipping service {service['name']} - requires build, no image specified")
                continue
            
            # Generate Deployment
            deployment = self._generate_deployment(project.name, service)
            manifests[f"{project.name}-{service['name']}-deployment.yaml"] = yaml.dump(deployment)
            
            # Generate Service if ports are exposed
            if service['ports']:
                service_manifest = self._generate_service(project.name, service)
                manifests[f"{project.name}-{service['name']}-service.yaml"] = yaml.dump(service_manifest)
        
        return manifests
    
    def _generate_deployment(self, project_name: str, service: Dict) -> Dict:
        """Generate Kubernetes Deployment manifest."""
        return {
            'apiVersion': 'apps/v1',
            'kind': 'Deployment',
            'metadata': {
                'name': f"{project_name}-{service['name']}",
                'labels': {
                    'app': f"{project_name}-{service['name']}",
                    'project': project_name
                }
            },
            'spec': {
                'replicas': 1,
                'selector': {
                    'matchLabels': {
                        'app': f"{project_name}-{service['name']}"
                    }
                },
                'template': {
                    'metadata': {
                        'labels': {
                            'app': f"{project_name}-{service['name']}"
                        }
                    },
                    'spec': {
                        'containers': [{
                            'name': service['name'],
                            'image': service['image'],
                            'ports': [{'containerPort': self._extract_container_port(port)} 
                                     for port in service.get('ports', [])],
                            'env': [{'name': k, 'value': str(v)} 
                                   for k, v in service.get('environment', {}).items()]
                        }]
                    }
                }
            }
        }
    
    def _generate_service(self, project_name: str, service: Dict) -> Dict:
        """Generate Kubernetes Service manifest."""
        ports = []
        for port_mapping in service.get('ports', []):
            container_port = self._extract_container_port(port_mapping)
            node_port = self._get_available_port()
            
            ports.append({
                'port': container_port,
                'targetPort': container_port,
                'nodePort': node_port,
                'protocol': 'TCP'
            })
        
        return {
            'apiVersion': 'v1',
            'kind': 'Service',
            'metadata': {
                'name': f"{project_name}-{service['name']}-service",
                'labels': {
                    'app': f"{project_name}-{service['name']}",
                    'project': project_name
                }
            },
            'spec': {
                'type': 'NodePort',
                'selector': {
                    'app': f"{project_name}-{service['name']}"
                },
                'ports': ports
            }
        }
    
    def _extract_container_port(self, port_mapping) -> int:
        """Extract container port from port mapping."""
        if isinstance(port_mapping, int):
            return port_mapping
        elif isinstance(port_mapping, str):
            if ':' in port_mapping:
                return int(port_mapping.split(':')[1])
            else:
                return int(port_mapping)
        return 8080  # default
    
    def _get_available_port(self) -> int:
        """Get next available NodePort."""
        port = self.base_port
        while port in self.used_ports:
            port += 1
        self.used_ports.add(port)
        return port

def main():
    parser = argparse.ArgumentParser(description='Scan GitHub repositories for portfolio deployment')
    parser.add_argument('--github-token', required=True, help='GitHub API token')
    parser.add_argument('--cluster-host', required=True, help='Cluster host IP')
    parser.add_argument('--output-dir', default='./portfolio-output', help='Output directory')
    parser.add_argument('--username', help='GitHub username (optional)')
    
    args = parser.parse_args()
    
    # Create output directory
    output_dir = Path(args.output_dir)
    output_dir.mkdir(exist_ok=True)
    
    # Initialize scanner
    scanner = GitHubScanner(args.github_token, args.username)
    k8s_generator = KubernetesGenerator()
    
    # Scan repositories
    repos = scanner.get_user_repos()
    projects = []
    
    for repo in repos:
        if repo['fork']:  # Skip forked repositories
            continue
            
        logger.info(f"Analyzing repository: {repo['name']}")
        
        # Check for Docker Compose file
        compose_content = scanner.get_file_content(repo['full_name'], 'docker-compose.yml')
        if not compose_content:
            compose_content = scanner.get_file_content(repo['full_name'], 'docker-compose.yaml')
        
        # Check README
        readme_content = scanner.get_file_content(repo['full_name'], 'README.md')
        if not readme_content:
            readme_content = scanner.get_file_content(repo['full_name'], 'readme.md')
        
        # Check GitHub Pages
        github_pages_url = scanner.check_github_pages(repo['full_name'])
        
        # Parse Docker Compose if exists
        docker_info = {'services': [], 'exposed_ports': [], 'has_web_interface': False}
        if compose_content:
            docker_info = DockerComposeParser.parse_compose_file(compose_content)
        
        # Create project info
        project = ProjectInfo(
            name=repo['name'],
            repo_url=repo['html_url'],
            description=repo['description'] or '',
            has_readme=bool(readme_content),
            has_github_pages=bool(github_pages_url),
            has_docker_compose=bool(compose_content),
            has_web_interface=docker_info['has_web_interface'],
            docker_services=[s['name'] for s in docker_info['services']],
            exposed_ports=docker_info['exposed_ports'],
            github_pages_url=github_pages_url,
            readme_quality=scanner.analyze_readme(readme_content) if readme_content else "missing"
        )
        
        # Validation flags
        if not project.has_github_pages and project.readme_quality in ['missing', 'minimal'] and not project.has_web_interface:
            project.validation_flags.append('missing_presentation')
        
        if project.has_docker_compose and not project.has_web_interface:
            project.validation_flags.append('no_web_interface')
        
        if not project.has_readme:
            project.validation_flags.append('no_readme')
        
        projects.append(project)
        
        # Generate Kubernetes manifests if Docker Compose exists
        if compose_content and docker_info['services']:
            manifests = k8s_generator.generate_k8s_manifests(project, compose_content)
            
            # Save manifests
            project_dir = output_dir / project.name
            project_dir.mkdir(exist_ok=True)
            
            for filename, content in manifests.items():
                (project_dir / filename).write_text(content)
    
    # Save portfolio data
    portfolio_data = {
        'projects': [asdict(p) for p in projects],
        'scan_timestamp': str(pd.Timestamp.now()),
        'total_projects': len(projects),
        'projects_with_docker': len([p for p in projects if p.has_docker_compose]),
        'projects_with_web_interface': len([p for p in projects if p.has_web_interface]),
        'flagged_projects': len([p for p in projects if p.validation_flags])
    }
    
    (output_dir / 'portfolio.json').write_text(json.dumps(portfolio_data, indent=2))
    
    logger.info(f"Portfolio scan complete. Found {len(projects)} projects.")
    logger.info(f"Projects with Docker Compose: {portfolio_data['projects_with_docker']}")
    logger.info(f"Projects with web interface: {portfolio_data['projects_with_web_interface']}")
    logger.info(f"Flagged projects: {portfolio_data['flagged_projects']}")

if __name__ == '__main__':
    main()
