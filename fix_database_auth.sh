#!/bin/bash

# Star Wars Chat App Database Authentication Fix Script
# This script automatically fixes database authentication issues between
# the LLM service and PostgreSQL database on your Digital Ocean droplet.

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
DOCKER_COMPOSE_FILE="docker-compose.production.yml"
EXPECTED_CREDENTIALS=(
    "POSTGRES_HOST=star_wars_postgres"
    "POSTGRES_PORT=5432"
    "POSTGRES_DB=star_wars_rag"
    "POSTGRES_USER=starwars_admin"
    "POSTGRES_PASSWORD=your_secure_password_123"
)

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to check if Docker is running
check_docker() {
    if ! command_exists docker; then
        print_error "Docker is not installed or not in PATH"
        exit 1
    fi
    
    if ! docker info >/dev/null 2>&1; then
        print_error "Docker is not running or you don't have permission to access it"
        exit 1
    fi
    
    print_success "Docker is available and running"
}

# Function to check if docker-compose is available
check_docker_compose() {
    if ! command_exists docker-compose && ! docker compose version >/dev/null 2>&1; then
        print_error "docker-compose is not available"
        exit 1
    fi
    
    print_success "docker-compose is available"
}

# Function to check current container status
check_container_status() {
    print_status "Checking current container status..."
    
    # Get running containers
    RUNNING_CONTAINERS=$(docker ps --format "{{.Names}}" 2>/dev/null || true)
    
    # Check for Star Wars containers
    STAR_WARS_CONTAINERS=(
        "star_wars_postgres"
        "star_wars_llm_service"
        "star_wars_llm_tinyllama_service"
        "star_wars_frontend"
        "star_wars_stt_service"
        "star_wars_tts_service"
    )
    
    RUNNING_STAR_WARS=()
    MISSING_STAR_WARS=()
    
    for container in "${STAR_WARS_CONTAINERS[@]}"; do
        if echo "$RUNNING_CONTAINERS" | grep -q "^${container}$"; then
            RUNNING_STAR_WARS+=("$container")
        else
            MISSING_STAR_WARS+=("$container")
        fi
    done
    
    print_status "Running Star Wars containers:"
    for container in "${RUNNING_STAR_WARS[@]}"; do
        print_success "  ✓ $container"
    done
    
    if [ ${#MISSING_STAR_WARS[@]} -gt 0 ]; then
        print_warning "Missing Star Wars containers:"
        for container in "${MISSING_STAR_WARS[@]}"; do
            print_warning "  ✗ $container"
        done
    fi
    
    return ${#MISSING_STAR_WARS[@]}
}

# Function to check PostgreSQL credentials
check_postgres_credentials() {
    print_status "Checking PostgreSQL container credentials..."
    
    if ! docker ps --format "{{.Names}}" | grep -q "^star_wars_postgres$"; then
        print_error "PostgreSQL container is not running"
        return 1
    fi
    
    # Get PostgreSQL environment variables
    POSTGRES_ENV=$(docker exec star_wars_postgres env 2>/dev/null | grep "^POSTGRES_" || true)
    
    if [ -z "$POSTGRES_ENV" ]; then
        print_error "Could not retrieve PostgreSQL environment variables"
        return 1
    fi
    
    print_success "PostgreSQL environment variables retrieved"
    
    # Check each expected credential
    CREDENTIAL_ISSUES=0
    for expected_cred in "${EXPECTED_CREDENTIALS[@]}"; do
        key=$(echo "$expected_cred" | cut -d'=' -f1)
        expected_value=$(echo "$expected_cred" | cut -d'=' -f2)
        
        actual_value=$(echo "$POSTGRES_ENV" | grep "^${key}=" | cut -d'=' -f2 || echo "NOT_SET")
        
        if [ "$actual_value" != "$expected_value" ]; then
            print_warning "Credential mismatch: $key"
            print_warning "  Expected: $expected_value"
            print_warning "  Actual:   $actual_value"
            CREDENTIAL_ISSUES=$((CREDENTIAL_ISSUES + 1))
        fi
    done
    
    if [ $CREDENTIAL_ISSUES -eq 0 ]; then
        print_success "All PostgreSQL credentials match expected values"
    fi
    
    return $CREDENTIAL_ISSUES
}

# Function to check LLM service credentials
check_llm_credentials() {
    print_status "Checking LLM service credentials..."
    
    LLM_SERVICES=("star_wars_llm_service" "star_wars_llm_tinyllama_service")
    CREDENTIAL_ISSUES=0
    
    for service in "${LLM_SERVICES[@]}"; do
        if ! docker ps --format "{{.Names}}" | grep -q "^${service}$"; then
            print_warning "LLM service $service is not running"
            continue
        fi
        
        print_status "Checking $service..."
        
        # Get LLM service environment variables
        LLM_ENV=$(docker exec "$service" env 2>/dev/null | grep "^POSTGRES_" || true)
        
        if [ -z "$LLM_ENV" ]; then
            print_warning "Could not retrieve environment variables for $service"
            CREDENTIAL_ISSUES=$((CREDENTIAL_ISSUES + 1))
            continue
        fi
        
        # Check each expected credential
        for expected_cred in "${EXPECTED_CREDENTIALS[@]}"; do
            key=$(echo "$expected_cred" | cut -d'=' -f1)
            expected_value=$(echo "$expected_cred" | cut -d'=' -f2)
            
            actual_value=$(echo "$LLM_ENV" | grep "^${key}=" | cut -d'=' -f2 || echo "NOT_SET")
            
            if [ "$actual_value" != "$expected_value" ]; then
                print_warning "Credential mismatch in $service: $key"
                print_warning "  Expected: $expected_value"
                print_warning "  Actual:   $actual_value"
                CREDENTIAL_ISSUES=$((CREDENTIAL_ISSUES + 1))
            fi
        done
    done
    
    if [ $CREDENTIAL_ISSUES -eq 0 ]; then
        print_success "All LLM service credentials match expected values"
    fi
    
    return $CREDENTIAL_ISSUES
}

# Function to test database connection
test_database_connection() {
    print_status "Testing database connection from LLM service..."
    
    if ! docker ps --format "{{.Names}}" | grep -q "^star_wars_llm_service$"; then
        print_error "LLM service container is not running"
        return 1
    fi
    
    # Create a test script
    cat > /tmp/test_db_connection.py << 'EOF'
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
EOF
    
    # Copy test script to container and run it
    docker cp /tmp/test_db_connection.py star_wars_llm_service:/tmp/
    TEST_RESULT=$(docker exec star_wars_llm_service python /tmp/test_db_connection.py 2>&1)
    
    # Clean up
    rm -f /tmp/test_db_connection.py
    docker exec star_wars_llm_service rm -f /tmp/test_db_connection.py
    
    # Check result
    if echo "$TEST_RESULT" | grep -q "✅ Database connection successful"; then
        print_success "Database connection test passed"
        echo "$TEST_RESULT"
        return 0
    else
        print_error "Database connection test failed"
        echo "$TEST_RESULT"
        return 1
    fi
}

# Function to check health endpoints
check_health_endpoints() {
    print_status "Checking service health endpoints..."
    
    HEALTH_ENDPOINTS=(
        "http://localhost:5003/health:LLM Service (Phi-2)"
        "http://localhost:5004/health:LLM Service (TinyLlama)"
        "http://localhost:5001/health:Speech-to-Text"
        "http://localhost:5002/health:Text-to-Speech"
    )
    
    HEALTH_ISSUES=0
    
    for endpoint_info in "${HEALTH_ENDPOINTS[@]}"; do
        url=$(echo "$endpoint_info" | cut -d':' -f1)
        service_name=$(echo "$endpoint_info" | cut -d':' -f2)
        
        if command_exists curl; then
            response=$(curl -s -w "%{http_code}" "$url" 2>/dev/null || echo "000")
            status_code=$(echo "$response" | tail -c 4)
            body=$(echo "$response" | head -c -4)
            
            if [ "$status_code" = "200" ]; then
                print_success "$service_name: Healthy"
                if echo "$body" | grep -q '"database"'; then
                    db_status=$(echo "$body" | grep -o '"database":"[^"]*"' | cut -d'"' -f4)
                    print_status "  Database status: $db_status"
                fi
            else
                print_warning "$service_name: Unhealthy (Status: $status_code)"
                HEALTH_ISSUES=$((HEALTH_ISSUES + 1))
            fi
        else
            print_warning "curl not available, skipping health check for $service_name"
        fi
    done
    
    return $HEALTH_ISSUES
}

# Function to fix credential mismatches
fix_credential_mismatches() {
    print_status "Fixing credential mismatches..."
    
    # Stop LLM service containers
    print_status "Stopping LLM service containers..."
    docker stop star_wars_llm_service star_wars_llm_tinyllama_service 2>/dev/null || true
    docker rm star_wars_llm_service star_wars_llm_tinyllama_service 2>/dev/null || true
    
    # Restart with correct credentials
    print_status "Restarting LLM services with correct credentials..."
    if command_exists docker-compose; then
        docker-compose -f "$DOCKER_COMPOSE_FILE" up -d llm llm-tinyllama
    else
        docker compose -f "$DOCKER_COMPOSE_FILE" up -d llm llm-tinyllama
    fi
    
    # Wait for services to start
    print_status "Waiting for LLM services to start..."
    sleep 30
    
    print_success "LLM services restarted with correct credentials"
}

# Function to restart all services
restart_all_services() {
    print_status "Restarting all Star Wars services..."
    
    # Stop all services
    print_status "Stopping all services..."
    if command_exists docker-compose; then
        docker-compose -f "$DOCKER_COMPOSE_FILE" down
    else
        docker compose -f "$DOCKER_COMPOSE_FILE" down
    fi
    
    # Start all services
    print_status "Starting all services..."
    if command_exists docker-compose; then
        docker-compose -f "$DOCKER_COMPOSE_FILE" up -d
    else
        docker compose -f "$DOCKER_COMPOSE_FILE" up -d
    fi
    
    # Wait for services to start
    print_status "Waiting for services to start..."
    sleep 60
    
    print_success "All services restarted"
}

# Function to verify the fix
verify_fix() {
    print_status "Verifying the fix..."
    
    # Wait a bit more for services to fully initialize
    sleep 30
    
    # Check container status
    print_status "Final container status check..."
    check_container_status
    
    # Test database connection
    print_status "Final database connection test..."
    if test_database_connection; then
        print_success "Database connection verified"
    else
        print_error "Database connection still failing"
        return 1
    fi
    
    # Check health endpoints
    print_status "Final health endpoint check..."
    if check_health_endpoints; then
        print_success "All health endpoints are healthy"
    else
        print_warning "Some health endpoints are still unhealthy"
    fi
    
    print_success "Fix verification completed"
}

# Main function
main() {
    echo "🚀 Star Wars Chat App Database Authentication Fix Script"
    echo "========================================================"
    echo
    
    # Check prerequisites
    print_status "Checking prerequisites..."
    check_docker
    check_docker_compose
    
    # Check if docker-compose file exists
    if [ ! -f "$DOCKER_COMPOSE_FILE" ]; then
        print_error "Docker Compose file not found: $DOCKER_COMPOSE_FILE"
        exit 1
    fi
    
    print_success "Prerequisites check passed"
    echo
    
    # Initial status check
    print_status "Performing initial status check..."
    check_container_status
    postgres_issues=$?
    
    check_postgres_credentials
    postgres_cred_issues=$?
    
    check_llm_credentials
    llm_cred_issues=$?
    
    test_database_connection
    db_connection_issues=$?
    
    check_health_endpoints
    health_issues=$?
    
    echo
    
    # Determine if fixes are needed
    total_issues=$((postgres_issues + postgres_cred_issues + llm_cred_issues + db_connection_issues + health_issues))
    
    if [ $total_issues -eq 0 ]; then
        print_success "No issues detected! All systems are healthy."
        exit 0
    fi
    
    print_warning "Issues detected. Starting automatic fix process..."
    echo
    
    # Apply fixes
    if [ $llm_cred_issues -gt 0 ] || [ $db_connection_issues -gt 0 ]; then
        print_status "Fixing credential and connection issues..."
        fix_credential_mismatches
        echo
    fi
    
    if [ $postgres_issues -gt 0 ] || [ $health_issues -gt 0 ]; then
        print_status "Restarting all services to ensure consistency..."
        restart_all_services
        echo
    fi
    
    # Verify the fix
    print_status "Verifying the fix..."
    if verify_fix; then
        print_success "✅ Database authentication issues have been resolved!"
        echo
        print_success "Your Star Wars chat app should now be working correctly."
        print_success "You can test it by visiting your domain or localhost:3000"
    else
        print_error "❌ Some issues may still persist. Please check the logs manually."
        echo
        print_status "Useful commands for further debugging:"
        echo "  docker logs star_wars_llm_service"
        echo "  docker logs star_wars_postgres"
        echo "  curl http://localhost:5003/health"
        exit 1
    fi
}

# Run main function
main "$@"
