#!/bin/bash

echo "=== NGINX DIAGNOSTICS ==="
echo ""

echo "1. Checking nginx container status:"
docker ps | grep nginx
echo ""

echo "2. Latest nginx logs:"
docker-compose -f docker-compose.production.yml logs nginx --tail=10
echo ""

echo "3. Testing nginx configuration:"
docker exec star_wars_nginx nginx -t 2>&1
echo ""

echo "4. Checking if frontend service is accessible:"
docker exec star_wars_frontend curl -I http://localhost:3000 2>&1
echo ""

echo "5. Checking network connectivity:"
docker network inspect star_wars_network --format='{{range .Containers}}{{.Name}}: {{.IPv4Address}}{{"\n"}}{{end}}'
echo ""

echo "6. Checking all running containers:"
docker ps --format="table {{.Names}}\t{{.Status}}\t{{.Ports}}"
echo ""

echo "7. Testing direct access to services:"
echo "Frontend (port 3000):"
docker exec star_wars_frontend curl -s -o /dev/null -w "%{http_code}" http://localhost:3000
echo ""

echo "LLM Service (port 5003):"
docker exec star_wars_llm_service curl -s -o /dev/null -w "%{http_code}" http://localhost:5003/health 2>/dev/null || echo "Failed"
echo ""

echo "=== DIAGNOSTIC COMPLETE ==="

