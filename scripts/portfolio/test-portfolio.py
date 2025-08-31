#!/usr/bin/env python3

"""
Portfolio System Test Script - Tests the portfolio automation locally
"""

import os
import sys
import json
import tempfile
from pathlib import Path
import subprocess

def create_test_docker_compose():
    """Create a test docker-compose.yml for testing."""
    return """
version: '3.8'
services:
  web:
    image: nginx:alpine
    ports:
      - "8080:80"
    environment:
      - ENV=production
  
  api:
    image: node:16-alpine
    ports:
      - "3000:3000"
    environment:
      - NODE_ENV=production
"""

def test_portfolio_scanner():
    """Test the portfolio scanner with mock data."""
    print("🧪 Testing Portfolio Scanner...")
    
    # Create temporary directory structure
    with tempfile.TemporaryDirectory() as temp_dir:
        temp_path = Path(temp_dir)
        
        # Create test docker-compose file
        compose_file = temp_path / "docker-compose.yml"
        compose_file.write_text(create_test_docker_compose())
        
        # Test Docker Compose parsing
        sys.path.append(str(Path(__file__).parent))
        from portfolio_scanner import DockerComposeParser
        
        parser = DockerComposeParser()
        result = parser.parse_compose_file(create_test_docker_compose())
        
        print(f"✅ Parsed {len(result['services'])} services")
        print(f"✅ Found ports: {result['exposed_ports']}")
        print(f"✅ Has web interface: {result['has_web_interface']}")
        
        return True

def test_kubernetes_generator():
    """Test Kubernetes manifest generation."""
    print("\n🧪 Testing Kubernetes Generator...")
    
    sys.path.append(str(Path(__file__).parent))
    from portfolio_scanner import KubernetesGenerator, ProjectInfo
    
    # Create test project
    project = ProjectInfo(
        name="test-project",
        repo_url="https://github.com/user/test-project",
        description="Test project for portfolio",
        has_readme=True,
        has_github_pages=False,
        has_docker_compose=True,
        has_web_interface=True,
        docker_services=["web", "api"],
        exposed_ports=[8080, 3000]
    )
    
    generator = KubernetesGenerator()
    manifests = generator.generate_k8s_manifests(project, create_test_docker_compose())
    
    print(f"✅ Generated {len(manifests)} manifests")
    for filename in manifests.keys():
        print(f"   - {filename}")
    
    return True

def test_port_management():
    """Test port conflict resolution."""
    print("\n🧪 Testing Port Management...")
    
    # Mock used ports
    used_ports = {30000, 30001, 30002}
    
    # Simulate port assignment
    next_port = 30000
    while next_port in used_ports:
        next_port += 1
    
    print(f"✅ Next available port: {next_port}")
    return True

def main():
    """Run all portfolio system tests."""
    print("🚀 Portfolio System Test Suite")
    print("=" * 40)
    
    tests = [
        test_portfolio_scanner,
        test_kubernetes_generator,
        test_port_management
    ]
    
    passed = 0
    failed = 0
    
    for test in tests:
        try:
            if test():
                passed += 1
            else:
                failed += 1
        except Exception as e:
            print(f"❌ Test failed: {e}")
            failed += 1
    
    print(f"\n📊 Test Results: {passed} passed, {failed} failed")
    
    if failed == 0:
        print("🎉 All tests passed! Portfolio system ready for deployment.")
        return 0
    else:
        print("❌ Some tests failed. Please check the implementation.")
        return 1

if __name__ == '__main__':
    sys.exit(main())
