#!/bin/bash

echo "🔄 Updating Frontend on Server..."
echo "=================================="

# Transfer the updated frontend files
echo "📤 Transferring updated frontend files..."
scp -i $env:USERPROFILE/.ssh/id_ed25519 -r ./frontend root@209.38.89.159:~/star-wars-chat-app/

if [ $? -eq 0 ]; then
    echo "✅ Frontend files transferred successfully"
    
    echo "🔧 Rebuilding frontend on server..."
    ssh -i $env:USERPROFILE/.ssh/id_ed25519 root@209.38.89.159 << 'EOF'
        cd ~/star-wars-chat-app
        
        # Stop the frontend container
        docker-compose -f docker-compose.production.yml stop frontend
        
        # Remove the old frontend container
        docker-compose -f docker-compose.production.yml rm -f frontend
        
        # Build the new frontend image locally on the server
        docker build -t star-wars-chat-app-frontend:latest ./frontend
        
        # Update the docker-compose file to use the local image
        sed -i 's|tommyboy777/star-wars-chat-app-frontend:latest|star-wars-chat-app-frontend:latest|g' docker-compose.production.yml
        
        # Start the frontend container
        docker-compose -f docker-compose.production.yml up -d frontend
        
        echo "✅ Frontend updated and restarted"
        echo "🌐 Check http://cinemavoices.com"
EOF
    
    echo "🎉 Frontend update completed!"
else
    echo "❌ Failed to transfer frontend files"
    exit 1
fi
