#!/bin/bash

echo "🔧 Rebuilding Star Wars Chat App Frontend..."
echo "=============================================="

# Build the frontend image
echo "📦 Building frontend Docker image..."
docker build -t tommyboy777/star-wars-chat-app-frontend:latest ./frontend

if [ $? -eq 0 ]; then
    echo "✅ Frontend image built successfully"
    
    # Push to Docker Hub
    echo "📤 Pushing to Docker Hub..."
    docker push tommyboy777/star-wars-chat-app-frontend:latest
    
    if [ $? -eq 0 ]; then
        echo "✅ Frontend image pushed successfully"
        echo ""
        echo "🚀 Next steps:"
        echo "1. SSH into your server: ssh -i ~/.ssh/id_ed25519 root@209.38.89.159"
        echo "2. Pull the new image: docker pull tommyboy777/star-wars-chat-app-frontend:latest"
        echo "3. Restart the frontend: docker-compose -f docker-compose.production.yml restart frontend"
        echo ""
        echo "🌐 Your app will be available at: http://cinemavoices.com"
    else
        echo "❌ Failed to push frontend image"
        exit 1
    fi
else
    echo "❌ Failed to build frontend image"
    exit 1
fi
