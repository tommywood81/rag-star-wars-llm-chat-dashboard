# Star Wars Chat App Database Authentication Fix Guide

## 🎯 Problem Overview

Your Star Wars chat app is experiencing a database authentication failure. The LLM service cannot connect to the PostgreSQL database due to incorrect credentials, causing the "password authentication failed for user" error.

## 🔍 Root Cause Analysis

The issue occurs when:
1. **Credential Mismatch**: LLM service uses different database credentials than PostgreSQL expects
2. **Network Issues**: Containers are not on the same Docker network
3. **Container Configuration**: Environment variables are not set correctly
4. **Service Startup Order**: Services start before database is ready

## 🛠️ Automatic Fix (Recommended)

### Option 1: Use the Diagnostic Script
```bash
# Run the diagnostic script to identify issues
python3 diagnose_database_auth.py

# Run the automatic fix script
chmod +x fix_database_auth.sh
./fix_database_auth.sh
```

### Option 2: Use the Fix Script Directly
```bash
# Make the script executable and run it
chmod +x fix_database_auth.sh
./fix_database_auth.sh
```

## 📋 Manual Step-by-Step Fix Process

### Step 1: Access Your Droplet

1. **Log into Digital Ocean**
   - Go to your Digital Ocean account
   - Navigate to your droplet (cinemavoices.com)
   - Click "Console" or use SSH

2. **Verify Access**
   ```bash
   whoami  # Should show root or your user
   pwd     # Check current directory
   ```

### Step 2: Check Current Container Status

```bash
# Check all running containers
docker ps

# Check specifically for Star Wars containers
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | grep star_wars
```

**Expected Output:**
```
star_wars_postgres           Up 2 hours    0.0.0.0:5432->5432/tcp
star_wars_llm_service        Up 2 hours    0.0.0.0:5003->5003/tcp
star_wars_frontend           Up 2 hours    0.0.0.0:3000->3000/tcp
star_wars_stt_service        Up 2 hours    0.0.0.0:5001->5001/tcp
star_wars_tts_service        Up 2 hours    0.0.0.0:5002->5002/tcp
```

### Step 3: Identify Database Credentials

```bash
# Check PostgreSQL container environment variables
docker exec star_wars_postgres env | grep POSTGRES
```

**Expected Output:**
```
POSTGRES_DB=star_wars_rag
POSTGRES_USER=starwars_admin
POSTGRES_PASSWORD=your_secure_password_123
POSTGRES_HOST_AUTH_METHOD=scram-sha-256
```

### Step 4: Check LLM Service Credentials

```bash
# Check LLM service environment variables
docker exec star_wars_llm_service env | grep POSTGRES
```

**Expected Output:**
```
POSTGRES_HOST=star_wars_postgres
POSTGRES_PORT=5432
POSTGRES_DB=star_wars_rag
POSTGRES_USER=starwars_admin
POSTGRES_PASSWORD=your_secure_password_123
```

### Step 5: Compare Credentials

If the credentials don't match, you'll see differences like:
- Different passwords
- Wrong host names
- Incorrect database names
- Wrong usernames

### Step 6: Fix Credential Mismatches

#### Option A: Quick Fix (Stop and Restart LLM Services)

```bash
# Stop LLM service containers
docker stop star_wars_llm_service star_wars_llm_tinyllama_service

# Remove containers to force recreation
docker rm star_wars_llm_service star_wars_llm_tinyllama_service

# Restart with correct credentials
docker-compose -f docker-compose.production.yml up -d llm llm-tinyllama
```

#### Option B: Complete Restart

```bash
# Stop all services
docker-compose -f docker-compose.production.yml down

# Start all services
docker-compose -f docker-compose.production.yml up -d
```

### Step 7: Verify Database Connection

```bash
# Test database connection from LLM service
docker exec star_wars_llm_service python -c "
import os
import asyncio
import asyncpg

async def test_connection():
    try:
        host = os.getenv('POSTGRES_HOST', 'localhost')
        port = int(os.getenv('POSTGRES_PORT', '5432'))
        database = os.getenv('POSTGRES_DB', 'star_wars_rag')
        user = os.getenv('POSTGRES_USER', 'postgres')
        password = os.getenv('POSTGRES_PASSWORD', 'password')
        
        conn = await asyncpg.connect(f'postgresql://{user}:{password}@{host}:{port}/{database}')
        print('✅ Database connection successful!')
        await conn.close()
    except Exception as e:
        print(f'❌ Connection failed: {e}')

asyncio.run(test_connection())
"
```

### Step 8: Check Health Endpoints

```bash
# Check LLM service health
curl http://localhost:5003/health

# Check other services
curl http://localhost:5001/health  # STT
curl http://localhost:5002/health  # TTS
curl http://localhost:5004/health  # TinyLlama
```

**Expected Health Response:**
```json
{
  "status": "healthy",
  "service": "llm",
  "model": "phi-2",
  "database": "connected",
  "characters": ["Luke Skywalker", "Darth Vader", "Han Solo", ...],
  "available_models": {...}
}
```

### Step 9: Test the Chat Functionality

```bash
# Test a simple chat request
curl -X POST http://localhost:5003/chat \
  -H "Content-Type: application/json" \
  -d '{
    "message": "Hello, who are you?",
    "character": "Luke Skywalker",
    "max_tokens": 100
  }'
```

## 🔧 Common Issues and Solutions

### Issue 1: Wrong Password
**Symptoms:** `password authentication failed for user "starwars_admin"`

**Solution:**
```bash
# Check current password in PostgreSQL
docker exec star_wars_postgres env | grep POSTGRES_PASSWORD

# Check password in LLM service
docker exec star_wars_llm_service env | grep POSTGRES_PASSWORD

# If they don't match, restart LLM services
docker stop star_wars_llm_service star_wars_llm_tinyllama_service
docker rm star_wars_llm_service star_wars_llm_tinyllama_service
docker-compose -f docker-compose.production.yml up -d llm llm-tinyllama
```

### Issue 2: Wrong Host
**Symptoms:** `could not connect to server: Connection refused`

**Solution:**
```bash
# Check if LLM service is trying to connect to localhost instead of container name
docker exec star_wars_llm_service env | grep POSTGRES_HOST

# Should show: POSTGRES_HOST=star_wars_postgres
# If not, restart the service
docker restart star_wars_llm_service
```

### Issue 3: Network Issues
**Symptoms:** `could not connect to server: No route to host`

**Solution:**
```bash
# Check if containers are on the same network
docker network ls
docker network inspect star_wars_network

# Recreate network if needed
docker network create star_wars_network
docker-compose -f docker-compose.production.yml up -d
```

### Issue 4: Database Not Ready
**Symptoms:** `the database system is starting up`

**Solution:**
```bash
# Wait for database to be ready
docker logs star_wars_postgres | tail -20

# Check database health
docker exec star_wars_postgres pg_isready -U starwars_admin -d star_wars_rag
```

## ✅ Success Indicators

After the fix, you should see:

1. **Health Check Success:**
   ```json
   {
     "status": "healthy",
     "database": "connected"
   }
   ```

2. **Chat Response Success:**
   ```json
   {
     "response": "Hello! I'm Luke Skywalker...",
     "character": "Luke Skywalker",
     "rag_context": [...],
     "metadata": {...}
   }
   ```

3. **No Error Logs:**
   ```bash
   docker logs star_wars_llm_service | grep -i error
   # Should return no results
   ```

## 🔍 Troubleshooting Commands

### Check Container Logs
```bash
# LLM service logs
docker logs star_wars_llm_service

# PostgreSQL logs
docker logs star_wars_postgres

# Follow logs in real-time
docker logs -f star_wars_llm_service
```

### Check Container Status
```bash
# Detailed container info
docker inspect star_wars_llm_service

# Check container environment
docker exec star_wars_llm_service env

# Check container network
docker exec star_wars_llm_service ip route
```

### Test Network Connectivity
```bash
# Test connection from LLM to PostgreSQL
docker exec star_wars_llm_service ping star_wars_postgres

# Test database port
docker exec star_wars_llm_service nc -zv star_wars_postgres 5432
```

## 🚨 Emergency Recovery

If the automatic fix doesn't work:

```bash
# Complete reset
docker-compose -f docker-compose.production.yml down
docker system prune -f
docker volume prune -f
docker-compose -f docker-compose.production.yml up -d

# Wait for services to start
sleep 120

# Verify
curl http://localhost:5003/health
```

## 📞 Getting Help

If you're still experiencing issues:

1. **Run the diagnostic script** and share the output
2. **Check the logs** for specific error messages
3. **Verify your docker-compose.production.yml** file matches the expected configuration
4. **Ensure all containers are on the same network**

## 🎉 Expected Outcome

After completing these steps, your Star Wars chat app should work perfectly:
- Characters respond with authentic Star Wars dialogue
- RAG system provides relevant context from the movies
- No more database connection errors
- Smooth, responsive chat experience

The fix addresses the core authentication issue that prevents the LLM service from accessing the database, which is essential for the RAG functionality that makes character responses accurate and contextual.
