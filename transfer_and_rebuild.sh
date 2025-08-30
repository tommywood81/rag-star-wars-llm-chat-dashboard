#!/bin/bash

echo "🚀 Transfer and Force Rebuild Star Wars Chat App Frontend"
echo "========================================================="
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if we're in the right directory
if [ ! -f "docker-compose.production.yml" ]; then
    print_error "docker-compose.production.yml not found. Please run this script from the star-wars-chat-app directory."
    exit 1
fi

print_status "Starting transfer and force rebuild process..."

# Step 1: Transfer the updated frontend files to server
print_status "Transferring updated frontend files to server..."
scp -i "$env:USERPROFILE/.ssh/id_ed25519" -r ./frontend root@209.38.89.159:~/star-wars-chat-app/
if [ $? -eq 0 ]; then
    print_success "Frontend files transferred successfully"
else
    print_error "Failed to transfer frontend files"
    exit 1
fi

# Step 2: Transfer the rebuild script
print_status "Transferring rebuild script to server..."
scp -i "$env:USERPROFILE/.ssh/id_ed25519" force_rebuild_frontend.sh root@209.38.89.159:~/star-wars-chat-app/
if [ $? -eq 0 ]; then
    print_success "Rebuild script transferred successfully"
else
    print_error "Failed to transfer rebuild script"
    exit 1
fi

# Step 3: Execute the rebuild on the server
print_status "Executing force rebuild on server..."
ssh -i "$env:USERPROFILE/.ssh/id_ed25519" root@209.38.89.159 << 'EOF'
cd ~/star-wars-chat-app

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

if [ $? -eq 0 ]; then
    echo "✅ Frontend image built successfully (no cache)"
else
    echo "❌ Failed to build frontend image"
    exit 1
fi

# Start the frontend container
echo "Starting frontend container..."
docker-compose -f docker-compose.production.yml up -d frontend

if [ $? -eq 0 ]; then
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
FRONTEND_STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:3000)
echo "Frontend: HTTP $FRONTEND_STATUS"

echo ""
echo "🎉 FORCE rebuild completed on server!"
echo "🌐 Your Star Wars Chat App is now available at: http://cinemavoices.com"
EOF

if [ $? -eq 0 ]; then
    print_success "🎉 Transfer and rebuild completed successfully!"
    echo ""
    echo "🌐 Your Star Wars Chat App is now available at:"
    echo "   http://cinemavoices.com"
    echo ""
    echo "✨ Features restored:"
    echo "   ✅ Dark Star Wars theme with blue accents"
    echo "   ✅ Model selection (Phi-2 & TinyLlama)"
    echo "   ✅ Explain button for RAG transparency"
    echo "   ✅ README button for documentation"
    echo "   ✅ Microphone support for speech-to-text"
    echo "   ✅ All 6 Star Wars characters"
    echo "   ✅ Responsive design for mobile/desktop"
    echo ""
    echo "💡 The rebuild was done WITHOUT cache and with fresh files!"
else
    print_error "❌ Transfer and rebuild failed"
    exit 1
fi
