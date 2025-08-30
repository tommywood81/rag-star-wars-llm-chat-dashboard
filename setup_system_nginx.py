#!/usr/bin/env python3
"""
Star Wars RAG - System Nginx Deployment Script
Deploys the app using the existing system nginx instead of Docker nginx
"""

import subprocess
import sys
import time
import os
from pathlib import Path

def run_command(command, description):
    """Run a command and handle errors"""
    print(f"🔄 {description}...")
    print(f"   Executing: {command}")
    
    try:
        result = subprocess.run(command, shell=True, check=True, capture_output=True, text=True)
        print(f"   ✅ {description} completed successfully")
        return result.stdout
    except subprocess.CalledProcessError as e:
        print(f"   ❌ {description} failed")
        print(f"   Error: {e.stderr}")
        return None

def check_requirements():
    """Check if required tools are available"""
    print("🔍 Checking requirements...")
    
    # Check if we're on the server
    if not os.path.exists('/etc/nginx'):
        print("❌ This script must be run on the server with nginx installed")
        return False
    
    # Check if nginx is running
    result = run_command("systemctl is-active nginx", "Checking nginx status")
    if result is None or "active" not in result:
        print("❌ Nginx is not running. Please start nginx first.")
        return False
    
    return True

def backup_existing_config():
    """Backup existing nginx configuration"""
    print("📦 Backing up existing nginx configuration...")
    
    # Create backup directory
    run_command("mkdir -p /etc/nginx/backups", "Creating backup directory")
    
    # Backup existing sites
    if os.path.exists('/etc/nginx/sites-enabled'):
        run_command("cp -r /etc/nginx/sites-enabled/* /etc/nginx/backups/", "Backing up sites-enabled")
    
    print("✅ Backup completed")

def deploy_star_wars_services():
    """Deploy Star Wars services without nginx"""
    print("🚀 Deploying Star Wars services...")
    
    # Stop any existing containers
    run_command("docker-compose -f docker-compose.production.yml down", "Stopping existing containers")
    
    # Start services (without nginx)
    result = run_command("docker-compose -f docker-compose.production.yml up -d", "Starting Star Wars services")
    
    if result is None:
        print("❌ Failed to start services")
        return False
    
    return True

def setup_nginx_config():
    """Set up nginx configuration for cinemavoices.com"""
    print("⚙️ Setting up nginx configuration...")
    
    # Copy the configuration file
    if os.path.exists('cinemavoices.conf'):
        run_command("cp cinemavoices.conf /etc/nginx/sites-available/", "Copying nginx config")
        run_command("ln -sf /etc/nginx/sites-available/cinemavoices.conf /etc/nginx/sites-enabled/", "Enabling site")
    else:
        print("❌ cinemavoices.conf not found")
        return False
    
    # Test nginx configuration
    result = run_command("nginx -t", "Testing nginx configuration")
    if result is None:
        print("❌ Nginx configuration test failed")
        return False
    
    # Reload nginx
    result = run_command("systemctl reload nginx", "Reloading nginx")
    if result is None:
        print("❌ Failed to reload nginx")
        return False
    
    return True

def wait_for_services():
    """Wait for services to be healthy"""
    print("⏳ Waiting for services to be healthy...")
    
    services = [
        ("star_wars_stt_service", "http://localhost:5001/health"),
        ("star_wars_tts_service", "http://localhost:5002/health"),
        ("star_wars_llm_service", "http://localhost:5003/health"),
        ("star_wars_frontend", "http://localhost:3000")
    ]
    
    for service_name, health_url in services:
        print(f"   Checking {service_name}...")
        max_attempts = 30
        for attempt in range(max_attempts):
            try:
                result = subprocess.run(f"curl -f {health_url}", shell=True, capture_output=True, timeout=10)
                if result.returncode == 0:
                    print(f"   ✅ {service_name} is healthy")
                    break
            except:
                pass
            
            if attempt == max_attempts - 1:
                print(f"   ⚠️ {service_name} health check failed after {max_attempts} attempts")
            else:
                time.sleep(2)

def show_deployment_info():
    """Show deployment information"""
    print("\n" + "="*60)
    print("🌟 STAR WARS RAG - SYSTEM NGINX DEPLOYMENT")
    print("="*60)
    print("🎉 Deployment completed!")
    print("\n📊 Service Information:")
    print("   🌐 Domain: http://cinemavoices.com")
    print("   🎯 Frontend: http://localhost:3000")
    print("   🔧 API: http://localhost:5003")
    print("   🎤 STT: http://localhost:5001")
    print("   🔊 TTS: http://localhost:5002")
    print("\n🛠️ Management Commands:")
    print("   # View service logs")
    print("   docker-compose -f docker-compose.production.yml logs -f")
    print("\n   # Restart services")
    print("   docker-compose -f docker-compose.production.yml restart")
    print("\n   # Check nginx status")
    print("   systemctl status nginx")
    print("\n   # Test nginx config")
    print("   nginx -t")
    print("\n   # Reload nginx")
    print("   systemctl reload nginx")
    print("\n" + "="*60)
    print("May the Force be with your deployment! ⭐")
    print("="*60)

def main():
    """Main deployment function"""
    print("🌟 Star Wars RAG - System Nginx Deployment Script")
    print("="*60)
    
    # Check requirements
    if not check_requirements():
        sys.exit(1)
    
    # Backup existing config
    backup_existing_config()
    
    # Deploy services
    if not deploy_star_wars_services():
        sys.exit(1)
    
    # Setup nginx config
    if not setup_nginx_config():
        sys.exit(1)
    
    # Wait for services
    wait_for_services()
    
    # Show deployment info
    show_deployment_info()

if __name__ == "__main__":
    main()
