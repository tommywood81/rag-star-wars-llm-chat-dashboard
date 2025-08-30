# PowerShell script to transfer and force rebuild Star Wars Chat App Frontend

Write-Host "🚀 Transfer and Force Rebuild Star Wars Chat App Frontend" -ForegroundColor Cyan
Write-Host "=========================================================" -ForegroundColor Cyan
Write-Host ""

# Get the SSH key path
$sshKeyPath = "$env:USERPROFILE\.ssh\id_ed25519"
$serverAddress = "root@209.38.89.159"
$projectPath = "~/star-wars-chat-app"

# Check if SSH key exists
if (-not (Test-Path $sshKeyPath)) {
    Write-Host "❌ SSH key not found at: $sshKeyPath" -ForegroundColor Red
    exit 1
}

Write-Host "✅ SSH key found at: $sshKeyPath" -ForegroundColor Green

# Step 1: Transfer the updated frontend files to server
Write-Host "📤 Transferring updated frontend files to server..." -ForegroundColor Blue
$scpResult = scp -i $sshKeyPath -r ./frontend $serverAddress`:$projectPath 2>&1
if ($LASTEXITCODE -eq 0) {
    Write-Host "✅ Frontend files transferred successfully" -ForegroundColor Green
} else {
    Write-Host "❌ Failed to transfer frontend files" -ForegroundColor Red
    Write-Host $scpResult -ForegroundColor Red
    exit 1
}

# Step 2: Transfer the rebuild script
Write-Host "📤 Transferring rebuild script to server..." -ForegroundColor Blue
$scpResult = scp -i $sshKeyPath force_rebuild_frontend.sh $serverAddress`:$projectPath 2>&1
if ($LASTEXITCODE -eq 0) {
    Write-Host "✅ Rebuild script transferred successfully" -ForegroundColor Green
} else {
    Write-Host "❌ Failed to transfer rebuild script" -ForegroundColor Red
    Write-Host $scpResult -ForegroundColor Red
    exit 1
}

# Step 3: Execute the rebuild on the server
Write-Host "🔄 Executing force rebuild on server..." -ForegroundColor Blue

$sshCommands = @"
cd $projectPath

echo "🔄 Starting FORCE rebuild process on server..."

# Stop the frontend container
echo "Stopping frontend container..."
docker-compose -f docker-compose.production.yml stop frontend

# Remove the old frontend container
echo "Removing old frontend container..."
docker-compose -f docker-compose.production.yml rm -f frontend

# Remove the old image to force rebuild
echo "Removing old frontend image..."
docker rmi star-wars-chat-app-frontend:latest 2>/dev/null

# Build the new frontend image WITHOUT CACHE
echo "Building new frontend image WITHOUT CACHE (this will take longer)..."
docker build --no-cache -t star-wars-chat-app-frontend:latest ./frontend

if [ `$? -eq 0 ]; then
    echo "✅ Frontend image built successfully (no cache)"
else
    echo "❌ Failed to build frontend image"
    exit 1
fi

# Start the frontend container
echo "Starting frontend container..."
docker-compose -f docker-compose.production.yml up -d frontend

if [ `$? -eq 0 ]; then
    echo "✅ Frontend container started"
else
    echo "❌ Failed to start frontend container"
    exit 1
fi

# Wait for services to fully start
echo "Waiting for services to fully start..."
sleep 15

# Show container status
echo ""
echo "📊 Container Status:"
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

# Test frontend
echo ""
echo "🧪 Testing frontend..."
FRONTEND_STATUS=`curl -s -o /dev/null -w "%{http_code}" http://localhost:3000`
echo "Frontend: HTTP `$FRONTEND_STATUS"

echo ""
echo "🎉 FORCE rebuild completed on server!"
echo "🌐 Your Star Wars Chat App is now available at: http://cinemavoices.com"
"@

$sshResult = ssh -i $sshKeyPath $serverAddress $sshCommands 2>&1
if ($LASTEXITCODE -eq 0) {
    Write-Host "🎉 Transfer and rebuild completed successfully!" -ForegroundColor Green
    Write-Host ""
    Write-Host "🌐 Your Star Wars Chat App is now available at:" -ForegroundColor Cyan
    Write-Host "   http://cinemavoices.com" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "✨ Features restored:" -ForegroundColor Cyan
    Write-Host "   ✅ Dark Star Wars theme with blue accents" -ForegroundColor Green
    Write-Host "   ✅ Model selection (Phi-2 & TinyLlama)" -ForegroundColor Green
    Write-Host "   ✅ Explain button for RAG transparency" -ForegroundColor Green
    Write-Host "   ✅ README button for documentation" -ForegroundColor Green
    Write-Host "   ✅ Microphone support for speech-to-text" -ForegroundColor Green
    Write-Host "   ✅ All 6 Star Wars characters" -ForegroundColor Green
    Write-Host "   ✅ Responsive design for mobile/desktop" -ForegroundColor Green
    Write-Host ""
    Write-Host "💡 The rebuild was done WITHOUT cache and with fresh files!" -ForegroundColor Yellow
} else {
    Write-Host "❌ Transfer and rebuild failed" -ForegroundColor Red
    Write-Host $sshResult -ForegroundColor Red
    exit 1
}
