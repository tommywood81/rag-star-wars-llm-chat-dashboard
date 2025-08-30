# PowerShell script to transfer files to server
# Replace YOUR_SERVER_IP and YOUR_USERNAME with your actual values

$serverIP = "209.38.89.159"  # Your Digital Ocean droplet IP
$username = "ubuntu"   # Ubuntu droplet username
$remotePath = "/home/$username/star-wars-chat-app"  # Adjust path as needed

Write-Host "Transferring files to server..." -ForegroundColor Green

# Files to transfer
$files = @(
    "deploy_domain.py",
    "docker-compose.production.yml", 
    "nginx.conf",
    "Dockerfile.nginx",
    "setup-ssl.sh",
    "DOMAIN_SETUP_GUIDE.md"
)

# Create remote directory
Write-Host "Creating remote directory..." -ForegroundColor Yellow
ssh $username@$serverIP "mkdir -p $remotePath"

# Transfer each file
foreach ($file in $files) {
    if (Test-Path $file) {
        Write-Host "Transferring $file..." -ForegroundColor Yellow
        scp $file $username@$serverIP`:$remotePath/
    } else {
        Write-Host "Warning: $file not found!" -ForegroundColor Red
    }
}

Write-Host "File transfer complete!" -ForegroundColor Green
Write-Host "Next steps:" -ForegroundColor Cyan
Write-Host "1. SSH into your server: ssh $username@$serverIP" -ForegroundColor White
Write-Host "2. Navigate to project: cd $remotePath" -ForegroundColor White
Write-Host "3. Run deployment: python3 deploy_domain.py" -ForegroundColor White
