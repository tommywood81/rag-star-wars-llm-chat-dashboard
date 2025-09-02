# Star Wars Chat App Database Authentication Fix Script (PowerShell)
# This script automatically fixes database authentication issues between
# the LLM service and PostgreSQL database on your Digital Ocean droplet.

param(
    [switch]$DiagnosticOnly,
    [switch]$Verbose
)

# Configuration
$DockerComposeFile = "docker-compose.production.yml"
$ExpectedCredentials = @{
    "POSTGRES_HOST" = "star_wars_postgres"
    "POSTGRES_PORT" = "5432"
    "POSTGRES_DB" = "star_wars_rag"
    "POSTGRES_USER" = "starwars_admin"
    "POSTGRES_PASSWORD" = "your_secure_password_123"
}

# Function to write colored output
function Write-Status {
    param([string]$Message)
    Write-Host "[INFO] $Message" -ForegroundColor Blue
}

function Write-Success {
    param([string]$Message)
    Write-Host "[SUCCESS] $Message" -ForegroundColor Green
}

function Write-Warning {
    param([string]$Message)
    Write-Host "[WARNING] $Message" -ForegroundColor Yellow
}

function Write-Error {
    param([string]$Message)
    Write-Host "[ERROR] $Message" -ForegroundColor Red
}

# Function to run Docker command
function Invoke-DockerCommand {
    param(
        [string]$Command,
        [switch]$CaptureOutput
    )
    
    try {
        if ($CaptureOutput) {
            $result = Invoke-Expression "docker $Command" 2>&1
            return @{
                Success = $LASTEXITCODE -eq 0
                Output = $result
                ExitCode = $LASTEXITCODE
            }
        } else {
            Invoke-Expression "docker $Command"
            return @{
                Success = $LASTEXITCODE -eq 0
                ExitCode = $LASTEXITCODE
            }
        }
    }
    catch {
        return @{
            Success = $false
            Error = $_.Exception.Message
        }
    }
}

# Function to check Docker status
function Test-DockerStatus {
    Write-Status "Checking Docker status..."
    
    $result = Invoke-DockerCommand "info" -CaptureOutput
    if (-not $result.Success) {
        Write-Error "Docker is not running or not accessible"
        return $false
    }
    
    Write-Success "Docker is available and running"
    return $true
}

# Function to check container status
function Get-ContainerStatus {
    Write-Status "Checking container status..."
    
    $result = Invoke-DockerCommand "ps --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'" -CaptureOutput
    
    if (-not $result.Success) {
        Write-Error "Failed to get container status"
        return $null
    }
    
    $containers = @{}
    $lines = $result.Output -split "`n"
    
    # Skip header line
    for ($i = 1; $i -lt $lines.Count; $i++) {
        $line = $lines[$i].Trim()
        if ($line) {
            $parts = $line -split "`t"
            if ($parts.Count -ge 2) {
                $name = $parts[0]
                $status = $parts[1]
                $ports = if ($parts.Count -gt 2) { $parts[2] } else { "" }
                $containers[$name] = @{
                    Status = $status
                    Ports = $ports
                }
            }
        }
    }
    
    # Check for Star Wars containers
    $starWarsContainers = @(
        "star_wars_postgres",
        "star_wars_llm_service",
        "star_wars_llm_tinyllama_service",
        "star_wars_frontend",
        "star_wars_stt_service",
        "star_wars_tts_service"
    )
    
    $runningContainers = @()
    $missingContainers = @()
    
    foreach ($container in $starWarsContainers) {
        if ($containers.ContainsKey($container)) {
            $runningContainers += $container
            Write-Success "  ✓ $container : $($containers[$container].Status)"
        } else {
            $missingContainers += $container
            Write-Warning "  ✗ $container : Not running"
        }
    }
    
    return @{
        RunningContainers = $runningContainers
        MissingContainers = $missingContainers
        AllContainers = $containers
    }
}

# Function to check PostgreSQL credentials
function Test-PostgresCredentials {
    Write-Status "Checking PostgreSQL credentials..."
    
    if (-not (Invoke-DockerCommand "ps --format '{{.Names}}'" -CaptureOutput).Output.Contains("star_wars_postgres")) {
        Write-Error "PostgreSQL container is not running"
        return $null
    }
    
    $result = Invoke-DockerCommand "exec star_wars_postgres env" -CaptureOutput
    
    if (-not $result.Success) {
        Write-Error "Failed to get PostgreSQL environment variables"
        return $null
    }
    
    $postgresEnv = @{}
    $lines = $result.Output -split "`n"
    
    foreach ($line in $lines) {
        if ($line -match "^POSTGRES_") {
            $parts = $line -split "=", 2
            if ($parts.Count -eq 2) {
                $postgresEnv[$parts[0]] = $parts[1]
            }
        }
    }
    
    Write-Success "PostgreSQL environment variables retrieved"
    
    # Check for mismatches
    $mismatches = @()
    foreach ($key in $ExpectedCredentials.Keys) {
        $expected = $ExpectedCredentials[$key]
        $actual = if ($postgresEnv.ContainsKey($key)) { $postgresEnv[$key] } else { "NOT_SET" }
        
        if ($actual -ne $expected) {
            $mismatches += @{
                Key = $key
                Expected = $expected
                Actual = $actual
            }
            Write-Warning "Credential mismatch: $key"
            Write-Warning "  Expected: $expected"
            Write-Warning "  Actual:   $actual"
        }
    }
    
    if ($mismatches.Count -eq 0) {
        Write-Success "All PostgreSQL credentials match expected values"
    }
    
    return @{
        Environment = $postgresEnv
        Mismatches = $mismatches
    }
}

# Function to check LLM service credentials
function Test-LLMCredentials {
    Write-Status "Checking LLM service credentials..."
    
    $llmServices = @("star_wars_llm_service", "star_wars_llm_tinyllama_service")
    $allMismatches = @()
    
    foreach ($service in $llmServices) {
        if (-not (Invoke-DockerCommand "ps --format '{{.Names}}'" -CaptureOutput).Output.Contains($service)) {
            Write-Warning "LLM service $service is not running"
            continue
        }
        
        Write-Status "Checking $service..."
        
        $result = Invoke-DockerCommand "exec $service env" -CaptureOutput
        
        if (-not $result.Success) {
            Write-Warning "Failed to get environment variables for $service"
            continue
        }
        
        $llmEnv = @{}
        $lines = $result.Output -split "`n"
        
        foreach ($line in $lines) {
            if ($line -match "^POSTGRES_") {
                $parts = $line -split "=", 2
                if ($parts.Count -eq 2) {
                    $llmEnv[$parts[0]] = $parts[1]
                }
            }
        }
        
        # Check for mismatches
        foreach ($key in $ExpectedCredentials.Keys) {
            $expected = $ExpectedCredentials[$key]
            $actual = if ($llmEnv.ContainsKey($key)) { $llmEnv[$key] } else { "NOT_SET" }
            
            if ($actual -ne $expected) {
                $allMismatches += @{
                    Service = $service
                    Key = $key
                    Expected = $expected
                    Actual = $actual
                }
                Write-Warning "Credential mismatch in $service : $key"
                Write-Warning "  Expected: $expected"
                Write-Warning "  Actual:   $actual"
            }
        }
    }
    
    if ($allMismatches.Count -eq 0) {
        Write-Success "All LLM service credentials match expected values"
    }
    
    return $allMismatches
}

# Function to test database connection
function Test-DatabaseConnection {
    Write-Status "Testing database connection from LLM service..."
    
    if (-not (Invoke-DockerCommand "ps --format '{{.Names}}'" -CaptureOutput).Output.Contains("star_wars_llm_service")) {
        Write-Error "LLM service container is not running"
        return $false
    }
    
    # Create test script
    $testScript = @"
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
"@
    
    # Write test script to temporary file
    $testScript | Out-File -FilePath "test_db_connection.py" -Encoding UTF8
    
    # Copy to container and run
    Invoke-DockerCommand "cp test_db_connection.py star_wars_llm_service:/tmp/"
    $result = Invoke-DockerCommand "exec star_wars_llm_service python /tmp/test_db_connection.py" -CaptureOutput
    
    # Clean up
    Remove-Item "test_db_connection.py" -ErrorAction SilentlyContinue
    Invoke-DockerCommand "exec star_wars_llm_service rm -f /tmp/test_db_connection.py" | Out-Null
    
    if ($result.Output -match "✅ Database connection successful") {
        Write-Success "Database connection test passed"
        Write-Host $result.Output
        return $true
    } else {
        Write-Error "Database connection test failed"
        Write-Host $result.Output
        return $false
    }
}

# Function to check health endpoints
function Test-HealthEndpoints {
    Write-Status "Checking service health endpoints..."
    
    $healthEndpoints = @{
        "http://localhost:5003/health" = "LLM Service (Phi-2)"
        "http://localhost:5004/health" = "LLM Service (TinyLlama)"
        "http://localhost:5001/health" = "Speech-to-Text"
        "http://localhost:5002/health" = "Text-to-Speech"
    }
    
    $healthIssues = 0
    
    foreach ($url in $healthEndpoints.Keys) {
        $serviceName = $healthEndpoints[$url]
        
        try {
            $response = Invoke-WebRequest -Uri $url -TimeoutSec 10 -ErrorAction Stop
            if ($response.StatusCode -eq 200) {
                Write-Success "$serviceName : Healthy"
                $content = $response.Content | ConvertFrom-Json
                if ($content.database) {
                    Write-Status "  Database status: $($content.database)"
                }
            } else {
                Write-Warning "$serviceName : Unhealthy (Status: $($response.StatusCode))"
                $healthIssues++
            }
        }
        catch {
            Write-Warning "$serviceName : Error - $($_.Exception.Message)"
            $healthIssues++
        }
    }
    
    return $healthIssues
}

# Function to fix credential mismatches
function Repair-CredentialMismatches {
    Write-Status "Fixing credential mismatches..."
    
    # Stop LLM service containers
    Write-Status "Stopping LLM service containers..."
    Invoke-DockerCommand "stop star_wars_llm_service star_wars_llm_tinyllama_service" | Out-Null
    Invoke-DockerCommand "rm star_wars_llm_service star_wars_llm_tinyllama_service" | Out-Null
    
    # Restart with correct credentials
    Write-Status "Restarting LLM services with correct credentials..."
    Invoke-DockerCommand "compose -f $DockerComposeFile up -d llm llm-tinyllama"
    
    # Wait for services to start
    Write-Status "Waiting for LLM services to start..."
    Start-Sleep -Seconds 30
    
    Write-Success "LLM services restarted with correct credentials"
}

# Function to restart all services
function Restart-AllServices {
    Write-Status "Restarting all Star Wars services..."
    
    # Stop all services
    Write-Status "Stopping all services..."
    Invoke-DockerCommand "compose -f $DockerComposeFile down"
    
    # Start all services
    Write-Status "Starting all services..."
    Invoke-DockerCommand "compose -f $DockerComposeFile up -d"
    
    # Wait for services to start
    Write-Status "Waiting for services to start..."
    Start-Sleep -Seconds 60
    
    Write-Success "All services restarted"
}

# Function to verify the fix
function Test-Fix {
    Write-Status "Verifying the fix..."
    
    # Wait a bit more for services to fully initialize
    Start-Sleep -Seconds 30
    
    # Check container status
    Write-Status "Final container status check..."
    $containerStatus = Get-ContainerStatus
    
    # Test database connection
    Write-Status "Final database connection test..."
    if (Test-DatabaseConnection) {
        Write-Success "Database connection verified"
    } else {
        Write-Error "Database connection still failing"
        return $false
    }
    
    # Check health endpoints
    Write-Status "Final health endpoint check..."
    $healthIssues = Test-HealthEndpoints
    
    if ($healthIssues -eq 0) {
        Write-Success "All health endpoints are healthy"
    } else {
        Write-Warning "Some health endpoints are still unhealthy"
    }
    
    Write-Success "Fix verification completed"
    return $true
}

# Main function
function Main {
    Write-Host "🚀 Star Wars Chat App Database Authentication Fix Script (PowerShell)" -ForegroundColor Cyan
    Write-Host "=====================================================================" -ForegroundColor Cyan
    Write-Host ""
    
    # Check prerequisites
    Write-Status "Checking prerequisites..."
    if (-not (Test-DockerStatus)) {
        exit 1
    }
    
    # Check if docker-compose file exists
    if (-not (Test-Path $DockerComposeFile)) {
        Write-Error "Docker Compose file not found: $DockerComposeFile"
        exit 1
    }
    
    Write-Success "Prerequisites check passed"
    Write-Host ""
    
    # Initial status check
    Write-Status "Performing initial status check..."
    $containerStatus = Get-ContainerStatus
    $postgresIssues = if ($containerStatus.MissingContainers.Contains("star_wars_postgres")) { 1 } else { 0 }
    
    $postgresCreds = Test-PostgresCredentials
    $postgresCredIssues = if ($postgresCreds -and $postgresCreds.Mismatches.Count -gt 0) { 1 } else { 0 }
    
    $llmCredIssues = Test-LLMCredentials
    $llmCredIssuesCount = if ($llmCredIssues) { $llmCredIssues.Count } else { 0 }
    
    $dbConnectionIssues = if (-not (Test-DatabaseConnection)) { 1 } else { 0 }
    
    $healthIssues = Test-HealthEndpoints
    
    Write-Host ""
    
    # Determine if fixes are needed
    $totalIssues = $postgresIssues + $postgresCredIssues + $llmCredIssuesCount + $dbConnectionIssues + $healthIssues
    
    if ($totalIssues -eq 0) {
        Write-Success "No issues detected! All systems are healthy."
        exit 0
    }
    
    if ($DiagnosticOnly) {
        Write-Warning "Issues detected. Run without -DiagnosticOnly to apply fixes."
        exit 0
    }
    
    Write-Warning "Issues detected. Starting automatic fix process..."
    Write-Host ""
    
    # Apply fixes
    if ($llmCredIssuesCount -gt 0 -or $dbConnectionIssues -gt 0) {
        Write-Status "Fixing credential and connection issues..."
        Repair-CredentialMismatches
        Write-Host ""
    }
    
    if ($postgresIssues -gt 0 -or $healthIssues -gt 0) {
        Write-Status "Restarting all services to ensure consistency..."
        Restart-AllServices
        Write-Host ""
    }
    
    # Verify the fix
    Write-Status "Verifying the fix..."
    if (Test-Fix) {
        Write-Success "✅ Database authentication issues have been resolved!"
        Write-Host ""
        Write-Success "Your Star Wars chat app should now be working correctly."
        Write-Success "You can test it by visiting your domain or localhost:3000"
    } else {
        Write-Error "❌ Some issues may still persist. Please check the logs manually."
        Write-Host ""
        Write-Status "Useful commands for further debugging:"
        Write-Host "  docker logs star_wars_llm_service"
        Write-Host "  docker logs star_wars_postgres"
        Write-Host "  curl http://localhost:5003/health"
        exit 1
    }
}

# Run main function
Main
