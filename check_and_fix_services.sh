#!/bin/bash

echo "🔍 Checking Star Wars Chat App Services..."
echo "=========================================="

ssh -i ~/.ssh/id_ed25519 root@209.38.89.159 << 'EOF'
cd ~/star-wars-chat-app

echo "📊 Current container status:"
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

echo ""
echo "🔧 Checking TinyLlama service..."
if docker ps | grep -q "star_wars_llm_tinyllama_service"; then
    echo "✅ TinyLlama service is running"
else
    echo "❌ TinyLlama service is not running"
    echo "🔄 Starting TinyLlama service..."
    docker-compose -f docker-compose.production.yml up -d llm-tinyllama
fi

echo ""
echo "🔧 Checking all services health..."
docker-compose -f docker-compose.production.yml ps

echo ""
echo "🌐 Testing endpoints:"
echo "Frontend: $(curl -s -o /dev/null -w "%{http_code}" http://localhost:3000)"
echo "Phi-2 API: $(curl -s -o /dev/null -w "%{http_code}" http://localhost:5003/health)"
echo "TinyLlama API: $(curl -s -o /dev/null -w "%{http_code}" http://localhost:5004/health)"
echo "STT Service: $(curl -s -o /dev/null -w "%{http_code}" http://localhost:5001/health)"
echo "TTS Service: $(curl -s -o /dev/null -w "%{http_code}" http://localhost:5002/health)"

echo ""
echo "🎉 Service check complete!"
echo "🌐 Your app is available at: http://cinemavoices.com"
EOF
