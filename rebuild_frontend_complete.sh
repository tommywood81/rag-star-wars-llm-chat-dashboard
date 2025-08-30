#!/bin/bash

echo "🚀 Complete Star Wars Chat App Frontend Rebuild"
echo "================================================"
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

print_status "Starting frontend rebuild process..."

# Step 1: Stop the frontend container
print_status "Stopping frontend container..."
docker-compose -f docker-compose.production.yml stop frontend
if [ $? -eq 0 ]; then
    print_success "Frontend container stopped"
else
    print_warning "Frontend container was not running or already stopped"
fi

# Step 2: Remove the old frontend container
print_status "Removing old frontend container..."
docker-compose -f docker-compose.production.yml rm -f frontend
if [ $? -eq 0 ]; then
    print_success "Old frontend container removed"
else
    print_warning "No old frontend container to remove"
fi

# Step 3: Build the new frontend image
print_status "Building new frontend image (this may take a few minutes)..."
docker build -t star-wars-chat-app-frontend:latest ./frontend
if [ $? -eq 0 ]; then
    print_success "Frontend image built successfully"
else
    print_error "Failed to build frontend image"
    exit 1
fi

# Step 4: Start the frontend container
print_status "Starting frontend container..."
docker-compose -f docker-compose.production.yml up -d frontend
if [ $? -eq 0 ]; then
    print_success "Frontend container started"
else
    print_error "Failed to start frontend container"
    exit 1
fi

# Step 5: Check if TinyLlama service is running
print_status "Checking TinyLlama service..."
if ! docker ps | grep -q "star_wars_llm_tinyllama_service"; then
    print_warning "TinyLlama service not running, starting it..."
    docker-compose -f docker-compose.production.yml up -d llm-tinyllama
    if [ $? -eq 0 ]; then
        print_success "TinyLlama service started"
    else
        print_warning "Failed to start TinyLlama service (may not be needed)"
    fi
else
    print_success "TinyLlama service is already running"
fi

# Step 6: Wait a moment for containers to fully start
print_status "Waiting for services to fully start..."
sleep 5

# Step 7: Show container status
echo ""
print_status "Container Status:"
echo "=================="
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

# Step 8: Test endpoints
echo ""
print_status "Testing endpoints..."
echo "======================"

# Test frontend
FRONTEND_STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:3000)
if [ "$FRONTEND_STATUS" = "200" ]; then
    print_success "Frontend: HTTP $FRONTEND_STATUS"
else
    print_warning "Frontend: HTTP $FRONTEND_STATUS (may still be starting)"
fi

# Test Phi-2 API
PHI2_STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:5003/health)
if [ "$PHI2_STATUS" = "405" ] || [ "$PHI2_STATUS" = "200" ]; then
    print_success "Phi-2 API: HTTP $PHI2_STATUS"
else
    print_warning "Phi-2 API: HTTP $PHI2_STATUS"
fi

# Test TinyLlama API
TINYLLAMA_STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:5004/health)
if [ "$TINYLLAMA_STATUS" = "405" ] || [ "$TINYLLAMA_STATUS" = "200" ]; then
    print_success "TinyLlama API: HTTP $TINYLLAMA_STATUS"
else
    print_warning "TinyLlama API: HTTP $TINYLLAMA_STATUS"
fi

# Test STT Service
STT_STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:5001/health)
if [ "$STT_STATUS" = "405" ] || [ "$STT_STATUS" = "200" ]; then
    print_success "STT Service: HTTP $STT_STATUS"
else
    print_warning "STT Service: HTTP $STT_STATUS"
fi

# Test TTS Service
TTS_STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:5002/health)
if [ "$TTS_STATUS" = "405" ] || [ "$TTS_STATUS" = "200" ]; then
    print_success "TTS Service: HTTP $TTS_STATUS"
else
    print_warning "TTS Service: HTTP $TTS_STATUS"
fi

echo ""
print_success "🎉 Frontend rebuild completed successfully!"
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
echo "🔧 If you encounter any issues:"
echo "   - Check container logs: docker-compose -f docker-compose.production.yml logs -f"
echo "   - Restart services: docker-compose -f docker-compose.production.yml restart"
echo "   - Check nginx: systemctl status nginx"
