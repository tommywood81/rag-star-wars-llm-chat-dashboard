#!/usr/bin/env python3
"""
Database Authentication Diagnostic Script for Star Wars Chat App

This script helps diagnose and fix database authentication issues between
the LLM service and PostgreSQL database on your Digital Ocean droplet.
"""

import os
import sys
import subprocess
import json
import time
import requests
from typing import Dict, Any, Optional

class DatabaseDiagnostic:
    def __init__(self):
        self.docker_compose_file = "docker-compose.production.yml"
        self.expected_credentials = {
            "host": "star_wars_postgres",
            "port": "5432",
            "database": "star_wars_rag",
            "user": "starwars_admin",
            "password": "your_secure_password_123"
        }
    
    def run_command(self, command: str, capture_output: bool = True) -> Dict[str, Any]:
        """Run a shell command and return results."""
        try:
            if capture_output:
                result = subprocess.run(
                    command, 
                    shell=True, 
                    capture_output=True, 
                    text=True, 
                    timeout=30
                )
                return {
                    "success": result.returncode == 0,
                    "stdout": result.stdout,
                    "stderr": result.stderr,
                    "returncode": result.returncode
                }
            else:
                result = subprocess.run(command, shell=True, timeout=30)
                return {"success": result.returncode == 0, "returncode": result.returncode}
        except subprocess.TimeoutExpired:
            return {"success": False, "error": "Command timed out"}
        except Exception as e:
            return {"success": False, "error": str(e)}
    
    def check_docker_status(self) -> Dict[str, Any]:
        """Check the status of all Docker containers."""
        print("🔍 Checking Docker container status...")
        
        # Check if containers are running
        result = self.run_command("docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'")
        
        if not result["success"]:
            return {"status": "error", "message": "Failed to check Docker containers", "details": result}
        
        containers = {}
        for line in result["stdout"].strip().split('\n')[1:]:  # Skip header
            if line.strip():
                parts = line.split('\t')
                if len(parts) >= 2:
                    name = parts[0]
                    status = parts[1]
                    ports = parts[2] if len(parts) > 2 else ""
                    containers[name] = {"status": status, "ports": ports}
        
        # Check for specific Star Wars containers
        star_wars_containers = {
            "star_wars_postgres": "PostgreSQL Database",
            "star_wars_llm_service": "LLM Service (Phi-2)",
            "star_wars_llm_tinyllama_service": "LLM Service (TinyLlama)",
            "star_wars_frontend": "Frontend",
            "star_wars_stt_service": "Speech-to-Text",
            "star_wars_tts_service": "Text-to-Speech"
        }
        
        missing_containers = []
        running_containers = {}
        
        for container_name, description in star_wars_containers.items():
            if container_name in containers:
                running_containers[container_name] = {
                    "description": description,
                    "status": containers[container_name]["status"],
                    "ports": containers[container_name]["ports"]
                }
            else:
                missing_containers.append(container_name)
        
        return {
            "status": "success",
            "running_containers": running_containers,
            "missing_containers": missing_containers,
            "all_containers": containers
        }
    
    def check_postgres_credentials(self) -> Dict[str, Any]:
        """Check PostgreSQL container environment variables."""
        print("🔍 Checking PostgreSQL container credentials...")
        
        # Get PostgreSQL container environment variables
        result = self.run_command(
            "docker exec star_wars_postgres env | grep POSTGRES"
        )
        
        if not result["success"]:
            return {"status": "error", "message": "Failed to get PostgreSQL environment variables"}
        
        postgres_env = {}
        for line in result["stdout"].strip().split('\n'):
            if line.strip():
                key, value = line.split('=', 1)
                postgres_env[key] = value
        
        # Check if credentials match expected values
        mismatches = []
        for key, expected_value in self.expected_credentials.items():
            env_key = f"POSTGRES_{key.upper()}"
            if env_key in postgres_env:
                actual_value = postgres_env[env_key]
                if actual_value != expected_value:
                    mismatches.append({
                        "key": env_key,
                        "expected": expected_value,
                        "actual": actual_value
                    })
            else:
                mismatches.append({
                    "key": env_key,
                    "expected": expected_value,
                    "actual": "NOT_SET"
                })
        
        return {
            "status": "success",
            "postgres_env": postgres_env,
            "mismatches": mismatches,
            "expected_credentials": self.expected_credentials
        }
    
    def check_llm_service_credentials(self) -> Dict[str, Any]:
        """Check LLM service container environment variables."""
        print("🔍 Checking LLM service container credentials...")
        
        # Check both LLM services
        llm_services = ["star_wars_llm_service", "star_wars_llm_tinyllama_service"]
        results = {}
        
        for service in llm_services:
            result = self.run_command(f"docker exec {service} env | grep POSTGRES")
            
            if result["success"]:
                llm_env = {}
                for line in result["stdout"].strip().split('\n'):
                    if line.strip():
                        key, value = line.split('=', 1)
                        llm_env[key] = value
                
                # Check for mismatches
                mismatches = []
                for key, expected_value in self.expected_credentials.items():
                    env_key = f"POSTGRES_{key.upper()}"
                    if env_key in llm_env:
                        actual_value = llm_env[env_key]
                        if actual_value != expected_value:
                            mismatches.append({
                                "key": env_key,
                                "expected": expected_value,
                                "actual": actual_value
                            })
                    else:
                        mismatches.append({
                            "key": env_key,
                            "expected": expected_value,
                            "actual": "NOT_SET"
                        })
                
                results[service] = {
                    "status": "success",
                    "env": llm_env,
                    "mismatches": mismatches
                }
            else:
                results[service] = {
                    "status": "error",
                    "message": f"Failed to get environment variables for {service}",
                    "details": result
                }
        
        return results
    
    def test_database_connection(self) -> Dict[str, Any]:
        """Test database connection from LLM service."""
        print("🔍 Testing database connection from LLM service...")
        
        # Test connection from LLM service container
        test_script = """
import os
import asyncio
import asyncpg

async def test_db_connection():
    try:
        host = os.getenv("POSTGRES_HOST", "localhost")
        port = int(os.getenv("POSTGRES_PORT", "5432"))
        database = os.getenv("POSTGRES_DB", "star_wars_rag")
        user = os.getenv("POSTGRES_USER", "postgres")
        password = os.getenv("POSTGRES_PASSWORD", "password")
        
        print(f"Attempting connection with:")
        print(f"  Host: {host}")
        print(f"  Port: {port}")
        print(f"  Database: {database}")
        print(f"  User: {user}")
        print(f"  Password: {'*' * len(password) if password else 'NOT_SET'}")
        
        connection_string = f"postgresql://{user}:{password}@{host}:{port}/{database}"
        
        conn = await asyncpg.connect(connection_string)
        print("✅ Database connection successful!")
        
        # Test a simple query
        result = await conn.fetchval("SELECT COUNT(*) FROM information_schema.tables")
        print(f"✅ Database query successful! Found {result} tables")
        
        await conn.close()
        return True
        
    except Exception as e:
        print(f"❌ Database connection failed: {e}")
        return False

asyncio.run(test_db_connection())
"""
        
        # Write test script to temporary file
        with open("/tmp/test_db_connection.py", "w") as f:
            f.write(test_script)
        
        # Run test from LLM service container
        result = self.run_command(
            "docker exec star_wars_llm_service python /tmp/test_db_connection.py"
        )
        
        # Clean up
        self.run_command("rm -f /tmp/test_db_connection.py")
        
        return {
            "success": result["success"],
            "output": result["stdout"],
            "error": result["stderr"] if not result["success"] else None
        }
    
    def check_health_endpoints(self) -> Dict[str, Any]:
        """Check health endpoints of all services."""
        print("🔍 Checking service health endpoints...")
        
        health_endpoints = {
            "llm_service": "http://localhost:5003/health",
            "llm_tinyllama": "http://localhost:5004/health",
            "stt_service": "http://localhost:5001/health",
            "tts_service": "http://localhost:5002/health"
        }
        
        results = {}
        
        for service, url in health_endpoints.items():
            try:
                response = requests.get(url, timeout=10)
                if response.status_code == 200:
                    data = response.json()
                    results[service] = {
                        "status": "healthy",
                        "response": data
                    }
                else:
                    results[service] = {
                        "status": "unhealthy",
                        "status_code": response.status_code,
                        "response": response.text
                    }
            except requests.exceptions.RequestException as e:
                results[service] = {
                    "status": "error",
                    "error": str(e)
                }
        
        return results
    
    def generate_fix_commands(self, issues: Dict[str, Any]) -> str:
        """Generate commands to fix identified issues."""
        print("🔧 Generating fix commands...")
        
        fix_commands = []
        
        # Check if containers are missing
        if "missing_containers" in issues and issues["missing_containers"]:
            fix_commands.append("# Start missing containers:")
            fix_commands.append("docker-compose -f docker-compose.production.yml up -d")
            fix_commands.append("")
        
        # Check for credential mismatches
        if "credential_mismatches" in issues and issues["credential_mismatches"]:
            fix_commands.append("# Fix credential mismatches:")
            fix_commands.append("# Stop the LLM service containers:")
            fix_commands.append("docker stop star_wars_llm_service star_wars_llm_tinyllama_service")
            fix_commands.append("docker rm star_wars_llm_service star_wars_llm_tinyllama_service")
            fix_commands.append("")
            fix_commands.append("# Restart with correct credentials:")
            fix_commands.append("docker-compose -f docker-compose.production.yml up -d llm llm-tinyllama")
            fix_commands.append("")
        
        # Check for network issues
        if "network_issues" in issues and issues["network_issues"]:
            fix_commands.append("# Fix network issues:")
            fix_commands.append("docker network create star_wars_network")
            fix_commands.append("docker-compose -f docker-compose.production.yml up -d")
            fix_commands.append("")
        
        # General restart command
        fix_commands.append("# Complete restart (if needed):")
        fix_commands.append("docker-compose -f docker-compose.production.yml down")
        fix_commands.append("docker-compose -f docker-compose.production.yml up -d")
        fix_commands.append("")
        
        # Verification commands
        fix_commands.append("# Verify the fix:")
        fix_commands.append("docker ps")
        fix_commands.append("curl http://localhost:5003/health")
        fix_commands.append("")
        
        return "\n".join(fix_commands)
    
    def run_diagnostic(self) -> Dict[str, Any]:
        """Run the complete diagnostic."""
        print("🚀 Starting Star Wars Chat App Database Authentication Diagnostic")
        print("=" * 70)
        
        results = {}
        
        # Step 1: Check Docker container status
        print("\n📋 Step 1: Docker Container Status")
        print("-" * 40)
        docker_status = self.check_docker_status()
        results["docker_status"] = docker_status
        
        if docker_status["status"] == "success":
            print("✅ Docker containers checked successfully")
            for container, info in docker_status["running_containers"].items():
                print(f"  {container}: {info['status']}")
            
            if docker_status["missing_containers"]:
                print("❌ Missing containers:")
                for container in docker_status["missing_containers"]:
                    print(f"  - {container}")
        else:
            print(f"❌ Failed to check Docker status: {docker_status['message']}")
        
        # Step 2: Check PostgreSQL credentials
        print("\n📋 Step 2: PostgreSQL Credentials")
        print("-" * 40)
        postgres_creds = self.check_postgres_credentials()
        results["postgres_credentials"] = postgres_creds
        
        if postgres_creds["status"] == "success":
            print("✅ PostgreSQL credentials checked")
            if postgres_creds["mismatches"]:
                print("❌ Credential mismatches found:")
                for mismatch in postgres_creds["mismatches"]:
                    print(f"  {mismatch['key']}: expected '{mismatch['expected']}', got '{mismatch['actual']}'")
            else:
                print("✅ All PostgreSQL credentials match expected values")
        else:
            print(f"❌ Failed to check PostgreSQL credentials: {postgres_creds['message']}")
        
        # Step 3: Check LLM service credentials
        print("\n📋 Step 3: LLM Service Credentials")
        print("-" * 40)
        llm_creds = self.check_llm_service_credentials()
        results["llm_credentials"] = llm_creds
        
        for service, cred_info in llm_creds.items():
            if cred_info["status"] == "success":
                print(f"✅ {service} credentials checked")
                if cred_info["mismatches"]:
                    print(f"❌ {service} credential mismatches:")
                    for mismatch in cred_info["mismatches"]:
                        print(f"  {mismatch['key']}: expected '{mismatch['expected']}', got '{mismatch['actual']}'")
                else:
                    print(f"✅ {service} credentials match expected values")
            else:
                print(f"❌ Failed to check {service}: {cred_info['message']}")
        
        # Step 4: Test database connection
        print("\n📋 Step 4: Database Connection Test")
        print("-" * 40)
        db_test = self.test_database_connection()
        results["database_test"] = db_test
        
        if db_test["success"]:
            print("✅ Database connection test completed")
            print(db_test["output"])
        else:
            print("❌ Database connection test failed")
            print(db_test["error"])
        
        # Step 5: Check health endpoints
        print("\n📋 Step 5: Service Health Endpoints")
        print("-" * 40)
        health_status = self.check_health_endpoints()
        results["health_status"] = health_status
        
        for service, status in health_status.items():
            if status["status"] == "healthy":
                print(f"✅ {service}: Healthy")
                if "database" in status["response"]:
                    print(f"  Database: {status['response']['database']}")
            elif status["status"] == "unhealthy":
                print(f"❌ {service}: Unhealthy (Status: {status['status_code']})")
            else:
                print(f"❌ {service}: Error - {status['error']}")
        
        # Generate summary and fix commands
        print("\n📋 Summary and Fix Commands")
        print("-" * 40)
        
        issues = []
        
        # Check for missing containers
        if docker_status["status"] == "success" and docker_status["missing_containers"]:
            issues.append("missing_containers")
        
        # Check for credential mismatches
        if postgres_creds["status"] == "success" and postgres_creds["mismatches"]:
            issues.append("credential_mismatches")
        
        for service, cred_info in llm_creds.items():
            if cred_info["status"] == "success" and cred_info["mismatches"]:
                issues.append("credential_mismatches")
                break
        
        # Check for database connection issues
        if not db_test["success"]:
            issues.append("database_connection")
        
        # Check for health issues
        for service, status in health_status.items():
            if status["status"] != "healthy":
                issues.append("health_issues")
                break
        
        if issues:
            print("❌ Issues detected:")
            for issue in issues:
                print(f"  - {issue}")
            
            print("\n🔧 Fix Commands:")
            fix_commands = self.generate_fix_commands({"issues": issues})
            print(fix_commands)
        else:
            print("✅ No issues detected! All systems are healthy.")
        
        return results

def main():
    """Main function to run the diagnostic."""
    diagnostic = DatabaseDiagnostic()
    
    try:
        results = diagnostic.run_diagnostic()
        
        # Save results to file
        with open("database_diagnostic_results.json", "w") as f:
            json.dump(results, f, indent=2)
        
        print(f"\n📄 Detailed results saved to: database_diagnostic_results.json")
        
    except KeyboardInterrupt:
        print("\n\n⚠️ Diagnostic interrupted by user")
        sys.exit(1)
    except Exception as e:
        print(f"\n❌ Diagnostic failed with error: {e}")
        sys.exit(1)

if __name__ == "__main__":
    main()
