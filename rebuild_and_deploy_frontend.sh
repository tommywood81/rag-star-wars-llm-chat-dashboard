#!/bin/bash

echo "🚀 Rebuilding and Deploying Updated Frontend..."
echo "================================================"

# Transfer the updated frontend files
echo "📤 Transferring updated frontend files..."
scp -i ~/.ssh/id_ed25519 -r ./frontend root@209.38.89.159:~/star-wars-chat-app/

if [ $? -eq 0 ]; then
    echo "✅ Frontend files transferred successfully"
    
    echo "🔧 Rebuilding frontend on server..."
    ssh -i ~/.ssh/id_ed25519 root@209.38.89.159 << 'EOF'
        cd ~/star-wars-chat-app
        
        # Stop the frontend container
        docker-compose -f docker-compose.production.yml stop frontend
        
        # Remove the old frontend container
        docker-compose -f docker-compose.production.yml rm -f frontend
        
        # Build the new frontend image
        docker build -t star-wars-chat-app-frontend:latest ./frontend
        
        # Start the frontend container
        docker-compose -f docker-compose.production.yml up -d frontend
        
        # Check if TinyLlama service is running
        if ! docker ps | grep -q "star_wars_llm_tinyllama_service"; then
            echo "🔄 Starting TinyLlama service..."
            docker-compose -f docker-compose.production.yml up -d llm-tinyllama
        fi
        
        echo "✅ Frontend updated and all services started"
        echo "🌐 Check http://cinemavoices.com"
        
        # Show container status
        echo ""
        echo "📊 Container Status:"
        docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
EOF
    
    echo "🎉 Frontend deployment completed!"
else
    echo "❌ Failed to transfer frontend files"
    exit 1
fi
