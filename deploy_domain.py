#!/usr/bin/env python3
"""
Domain Deployment Script for Star Wars RAG Dashboard

This script sets up the domain cinemavoices.com with nginx and SSL certificates.
"""

import subprocess
import sys
import time
import requests
import argparse
from pathlib import Path
import logging

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

def run_command(command, check=True, capture_output=False):
    """Run shell command with error handling."""
    logger.info(f"Executing: {command}")
    try:
        result = subprocess.run(
            command, 
            shell=True, 
            check=check,
            capture_output=capture_output,
            text=True
        )
        if capture_output:
            return result.stdout.strip()
        return result.returncode == 0
    except subprocess.CalledProcessError as e:
        logger.error(f"Command failed: {e}")
        return None if capture_output else False

def check_domain_dns():
    """Check if domain DNS is properly configured."""
    logger.info("Checking DNS configuration for cinemavoices.com...")
    
    # Get server IP (you'll need to replace this with your actual server IP)
    server_ip = input("Enter your server's public IP address: ").strip()
    
    if not server_ip:
        logger.error("❌ Server IP is required")
        return False
    
    # Check if domain resolves to server IP
    try:
        import socket
        resolved_ip = socket.gethostbyname('cinemavoices.com')
        if resolved_ip == server_ip:
            logger.info("✅ Domain DNS is correctly configured")
            return True
        else:
            logger.warning(f"⚠️ Domain resolves to {resolved_ip}, expected {server_ip}")
            logger.info("Please ensure your domain points to the correct server IP")
            return False
    except Exception as e:
        logger.error(f"❌ DNS resolution failed: {e}")
        return False

def build_nginx_image():
    """Build the nginx Docker image."""
    logger.info("Building nginx Docker image...")
    
    success = run_command("docker build -f Dockerfile.nginx -t star-wars-nginx .")
    
    if not success:
        logger.error("❌ Failed to build nginx image")
        return False
    
    logger.info("✅ Nginx image built successfully")
    return True

def deploy_with_nginx():
    """Deploy the application with nginx reverse proxy."""
    logger.info("Deploying application with nginx...")
    
    # Stop any existing services
    run_command(
        "docker-compose -f docker-compose.production.yml down",
        check=False
    )
    
    # Start services with nginx
    success = run_command(
        "docker-compose -f docker-compose.production.yml up -d"
    )
    
    if not success:
        logger.error("❌ Failed to deploy services")
        return False
    
    logger.info("✅ Services deployed successfully")
    return True

def setup_ssl_certificates():
    """Set up SSL certificates using Let's Encrypt."""
    logger.info("Setting up SSL certificates...")
    
    # Get email for SSL certificates
    email = input("Enter your email address for SSL certificates: ").strip()
    
    if not email:
        logger.error("❌ Email is required for SSL certificates")
        return False
    
    # Update the setup-ssl.sh script with the correct email
    with open('setup-ssl.sh', 'r') as f:
        content = f.read()
    
    content = content.replace('your-email@example.com', email)
    
    with open('setup-ssl.sh', 'w') as f:
        f.write(content)
    
    logger.info("✅ SSL setup script updated with your email")
    
    # Run SSL setup in nginx container
    logger.info("Running SSL certificate setup...")
    success = run_command(
        "docker exec star_wars_nginx /usr/local/bin/setup-ssl.sh"
    )
    
    if not success:
        logger.warning("⚠️ SSL setup may need manual intervention")
        logger.info("You can run SSL setup manually later")
        return False
    
    logger.info("✅ SSL certificates set up successfully")
    return True

def wait_for_services():
    """Wait for all services to be healthy."""
    logger.info("Waiting for services to be healthy...")
    
    services = [
        {"name": "Nginx", "url": "http://localhost/health", "timeout": 60},
        {"name": "Frontend", "url": "http://localhost", "timeout": 30},
        {"name": "API", "url": "http://localhost:8002/health", "timeout": 30}
    ]
    
    for service in services:
        logger.info(f"Checking {service['name']} health...")
        
        for attempt in range(service['timeout']):
            try:
                response = requests.get(service['url'], timeout=5)
                if response.status_code == 200:
                    logger.info(f"✅ {service['name']} is healthy")
                    break
            except requests.exceptions.RequestException:
                pass
            
            if attempt < service['timeout'] - 1:
                time.sleep(1)
        else:
            logger.warning(f"⚠️ {service['name']} health check failed")
    
    return True

def show_deployment_info():
    """Display deployment information."""
    logger.info("🎉 Domain deployment completed!")
    
    print("\n" + "="*60)
    print("🌟 STAR WARS RAG DASHBOARD - DOMAIN DEPLOYMENT")
    print("="*60)
    print("🌐 Domain:         https://cinemavoices.com")
    print("🔒 SSL:            Let's Encrypt (auto-renewal)")
    print("📊 Dashboard:      https://cinemavoices.com")
    print("🚀 API Backend:    https://cinemavoices.com/api/")
    print("🔍 Health Check:   https://cinemavoices.com/health")
    print()
    print("🛠️ Management Commands:")
    print("   # View logs")
    print("   docker-compose -f docker-compose.production.yml logs -f nginx")
    print()
    print("   # Renew SSL certificates")
    print("   docker exec star_wars_nginx certbot renew")
    print()
    print("   # Test nginx configuration")
    print("   docker exec star_wars_nginx nginx -t")
    print()
    print("   # Restart nginx")
    print("   docker restart star_wars_nginx")
    print("="*60)
    print("May the Force be with your domain! ⭐")

def main():
    """Main deployment function."""
    parser = argparse.ArgumentParser(description="Deploy Star Wars RAG domain")
    parser.add_argument("--skip-dns", action="store_true", help="Skip DNS check")
    parser.add_argument("--skip-ssl", action="store_true", help="Skip SSL setup")
    args = parser.parse_args()
    
    print("🌟 Star Wars RAG - Domain Deployment Script")
    print("="*50)
    
    # Check DNS configuration
    if not args.skip_dns:
        if not check_domain_dns():
            logger.error("❌ DNS configuration check failed")
            sys.exit(1)
    
    # Build nginx image
    if not build_nginx_image():
        sys.exit(1)
    
    # Deploy with nginx
    if not deploy_with_nginx():
        sys.exit(1)
    
    # Wait for services
    if not wait_for_services():
        logger.warning("⚠️ Some services may not be fully ready")
    
    # Set up SSL certificates
    if not args.skip_ssl:
        setup_ssl_certificates()
    
    show_deployment_info()

if __name__ == "__main__":
    main()
