#!/bin/bash

# Fix nginx configuration
echo "Fixing nginx configuration..."

# Update the nginx.conf file
sed -i 's/star-wars-rag:8002/star_wars_llm_service:5003/g' nginx.conf

# Restart nginx container
echo "Restarting nginx container..."
docker-compose -f docker-compose.production.yml restart nginx

# Check nginx status
echo "Checking nginx status..."
sleep 5
docker ps | grep nginx

echo "Nginx configuration fixed!"
echo "Your Star Wars app should now be accessible at:"
echo "HTTP: http://cinemavoices.com:8080"
echo "HTTPS: https://cinemavoices.com:8443"

