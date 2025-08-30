# PowerShell script to rebuild Star Wars Chat App Frontend

Write-Host "🔧 Rebuilding Star Wars Chat App Frontend..." -ForegroundColor Green
Write-Host "==============================================" -ForegroundColor Cyan

# Build the frontend image
Write-Host "📦 Building frontend Docker image..." -ForegroundColor Yellow
docker build -t tommyboy777/star-wars-chat-app-frontend:latest ./frontend

if ($LASTEXITCODE -eq 0) {
    Write-Host "✅ Frontend image built successfully" -ForegroundColor Green
    
    # Push to Docker Hub
    Write-Host "📤 Pushing to Docker Hub..." -ForegroundColor Yellow
    docker push tommyboy777/star-wars-chat-app-frontend:latest
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ Frontend image pushed successfully" -ForegroundColor Green
        Write-Host ""
        Write-Host "🚀 Next steps:" -ForegroundColor Cyan
        Write-Host "1. SSH into your server: ssh -i ~/.ssh/id_ed25519 root@209.38.89.159" -ForegroundColor White
        Write-Host "2. Pull the new image: docker pull tommyboy777/star-wars-chat-app-frontend:latest" -ForegroundColor White
        Write-Host "3. Restart the frontend: docker-compose -f docker-compose.production.yml restart frontend" -ForegroundColor White
        Write-Host ""
        Write-Host "🌐 Your app will be available at: http://cinemavoices.com" -ForegroundColor Cyan
    } else {
        Write-Host "❌ Failed to push frontend image" -ForegroundColor Red
        exit 1
    }
} else {
    Write-Host "❌ Failed to build frontend image" -ForegroundColor Red
    exit 1
}
