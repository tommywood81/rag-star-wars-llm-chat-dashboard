# PowerShell script to deploy Star Wars Chat App to cinemavoices.com
# This script handles file transfer and deployment

$serverIP = "209.38.89.159"
$username = "root"
$sshKey = "$env:USERPROFILE\.ssh\id_ed25519"
$remotePath = "~/star-wars-chat-app"

Write-Host "🚀 Starting Star Wars Chat App Deployment to cinemavoices.com" -ForegroundColor Green
Write-Host "Server: $serverIP" -ForegroundColor Cyan
Write-Host "User: $username" -ForegroundColor Cyan

# Step 1: Check if SSH key exists
if (-not (Test-Path $sshKey)) {
    Write-Host "❌ SSH key not found at: $sshKey" -ForegroundColor Red
    exit 1
}

Write-Host "✅ SSH key found" -ForegroundColor Green

# Step 2: Test SSH connection
Write-Host "🔌 Testing SSH connection..." -ForegroundColor Yellow
try {
    $testResult = ssh -i $sshKey -o ConnectTimeout=10 -o BatchMode=yes $username@$serverIP "echo 'SSH connection successful'"
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ SSH connection successful" -ForegroundColor Green
    } else {
        Write-Host "❌ SSH connection failed" -ForegroundColor Red
        exit 1
    }
} catch {
    Write-Host "❌ SSH connection failed: $_" -ForegroundColor Red
    exit 1
}

# Step 3: Create remote directory
Write-Host "📁 Creating remote directory..." -ForegroundColor Yellow
ssh -i $sshKey $username@$serverIP "mkdir -p $remotePath"

# Step 4: Transfer essential files
Write-Host "📤 Transferring files to server..." -ForegroundColor Yellow

$files = @(
    "cinemavoices.conf",
    "setup_system_nginx.py", 
    "docker-compose.production.yml"
)

foreach ($file in $files) {
    if (Test-Path $file) {
        Write-Host "📤 Transferring $file..." -ForegroundColor Yellow
        scp -i $sshKey $file $username@$serverIP`:$remotePath/
        if ($LASTEXITCODE -eq 0) {
            Write-Host "✅ $file transferred successfully" -ForegroundColor Green
        } else {
            Write-Host "❌ Failed to transfer $file" -ForegroundColor Red
        }
    } else {
        Write-Host "❌ File not found: $file" -ForegroundColor Red
    }
}

# Step 5: Execute deployment on server
Write-Host "🔧 Executing deployment on server..." -ForegroundColor Yellow
Write-Host "This will take a few minutes..." -ForegroundColor Cyan

$deployCommand = @"
cd $remotePath
echo 'Starting deployment...'
python3 setup_system_nginx.py
echo 'Deployment script completed'
docker ps
echo 'Checking nginx status...'
systemctl status nginx --no-pager -l
echo 'Testing health endpoints...'
curl -I http://localhost:3000 || echo 'Frontend not responding'
curl -I http://localhost:5001/health || echo 'STT service not responding'
curl -I http://localhost:5002/health || echo 'TTS service not responding'
curl -I http://localhost:5003/health || echo 'LLM service not responding'
echo 'Deployment verification complete'
"@

ssh -i $sshKey $username@$serverIP $deployCommand

Write-Host "🎉 Deployment process completed!" -ForegroundColor Green
Write-Host "🌐 Your Star Wars Chat App should now be available at: http://cinemavoices.com" -ForegroundColor Cyan
Write-Host "📋 If you encounter issues, check the logs above or run: ssh -i $sshKey $username@$serverIP" -ForegroundColor Yellow
