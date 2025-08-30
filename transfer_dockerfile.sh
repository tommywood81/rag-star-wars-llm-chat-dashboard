#!/bin/bash

echo "📤 Transferring frontend Dockerfile to server..."

# Transfer the Dockerfile
scp -i ~/.ssh/id_ed25519 ./frontend/Dockerfile root@209.38.89.159:~/star-wars-chat-app/frontend/

if [ $? -eq 0 ]; then
    echo "✅ Dockerfile transferred successfully"
    echo ""
    echo "🔧 Now run these commands on the server:"
    echo "cd ~/star-wars-chat-app"
    echo "docker build -t star-wars-chat-app-frontend:latest ./frontend"
    echo "sed -i 's|tommyboy777/star-wars-chat-app-frontend:latest|star-wars-chat-app-frontend:latest|g' docker-compose.production.yml"
    echo "docker-compose -f docker-compose.production.yml up -d frontend"
else
    echo "❌ Failed to transfer Dockerfile"
    exit 1
fi
