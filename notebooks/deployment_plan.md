# 🚀 **Star Wars Chat App Deployment Plan**

## **🎯 Goal**
Deploy your Star Wars RAG chat application to `cinemavoices.com` without any port numbers, using the existing system nginx on your Digital Ocean droplet.

## **📋 Current Situation**
- **Server:** Digital Ocean droplet (IP: 209.38.89.159)
- **Domain:** cinemavoices.com (DNS configured correctly)
- **Problem:** Port 80 is occupied by system nginx for other projects
- **Solution:** Configure system nginx to proxy cinemavoices.com to Star Wars Docker containers

## **🔑 Essential Information**
- **SSH User:** `root` (not ubuntu)
- **SSH Key:** `id_ed25519` (located at `$env:USERPROFILE\.ssh\id_ed25519`)
- **Server IP:** `209.38.89.159`
- **Project Directory:** `~/star-wars-chat-app`

## **📁 Files Created**
1. **`cinemavoices.conf`** - Nginx configuration for cinemavoices.com
2. **`setup_system_nginx.py`** - Automated deployment script
3. **`docker-compose.production.yml`** - Updated (removed nginx service, added port 3000)

## **🔄 Step-by-Step Deployment Plan**

### **Step 1: Test SSH Connection**
```powershell
ssh -i $env:USERPROFILE\.ssh\id_ed25519 root@209.38.89.159
```
**Expected:** Server prompt `root@ubuntu-s-2vcpu-4gb-syd1-01:~#`

### **Step 2: Transfer Files to Server**
```powershell
# Transfer nginx configuration
scp -i $env:USERPROFILE\.ssh\id_ed25519 cinemavoices.conf root@209.38.89.159:~/star-wars-chat-app/

# Transfer deployment script
scp -i $env:USERPROFILE\.ssh\id_ed25519 setup_system_nginx.py root@209.38.89.159:~/star-wars-chat-app/

# Transfer updated docker-compose file
scp -i $env:USERPROFILE\.ssh\id_ed25519 docker-compose.production.yml root@209.38.89.159:~/star-wars-chat-app/
```

### **Step 3: SSH into Server and Deploy**
```powershell
ssh -i $env:USERPROFILE\.ssh\id_ed25519 root@209.38.89.159
```

Then on the server:
```bash
cd ~/star-wars-chat-app
python3 setup_system_nginx.py
```

### **Step 4: Manual Deployment (if script fails)**
```bash
# Stop existing containers
docker-compose -f docker-compose.production.yml down

# Start services (without nginx)
docker-compose -f docker-compose.production.yml up -d

# Backup existing nginx config
mkdir -p /etc/nginx/backups
cp -r /etc/nginx/sites-enabled/* /etc/nginx/backups/

# Copy the new config
cp cinemavoices.conf /etc/nginx/sites-available/
ln -sf /etc/nginx/sites-available/cinemavoices.conf /etc/nginx/sites-enabled/

# Test and reload nginx
nginx -t
systemctl reload nginx
```

### **Step 5: Verify Deployment**
```bash
# Check if services are running
docker ps

# Test health endpoints
curl -I http://localhost:3000
curl -I http://localhost:5001/health
curl -I http://localhost:5002/health
curl -I http://localhost:5003/health

# Test nginx proxy
curl -I http://localhost/health
```

### **Step 6: Test Domain**
- Open browser and go to: `http://cinemavoices.com`
- Should show your Star Wars chat application

## **🔧 Troubleshooting Commands**

### **If SSH fails:**
```powershell
# Check if SSH key exists
ls $env:USERPROFILE\.ssh\id_ed25519

# Check key permissions
icacls $env:USERPROFILE\.ssh\id_ed25519
```

### **If nginx fails:**
```bash
# Check nginx status
systemctl status nginx

# Check nginx config
nginx -t

# View nginx error logs
tail -f /var/log/nginx/error.log
```

### **If Docker services fail:**
```bash
# Check container logs
docker-compose -f docker-compose.production.yml logs -f

# Restart services
docker-compose -f docker-compose.production.yml restart
```

## **🎯 Expected Result**
- `http://cinemavoices.com` → Star Wars chat application
- `http://cinemavoices.com/api/` → API endpoints
- `http://cinemavoices.com/stt/` → Speech-to-text service
- `http://cinemavoices.com/tts/` → Text-to-speech service
- `http://cinemavoices.com/llm/` → LLM service

## **✅ Success Criteria**
1. ✅ SSH connection works
2. ✅ Files transfer successfully
3. ✅ Docker containers start without errors
4. ✅ Nginx configuration loads without errors
5. ✅ `cinemavoices.com` shows Star Wars app
6. ✅ No port numbers in URL

## **⚠️ Important Notes**
- This approach uses the existing system nginx (port 80)
- Your other projects will continue running
- The Star Wars app will be accessible via cinemavoices.com
- No SSL initially (HTTP only) - we can add HTTPS later

## **📝 File Locations**
- **Local files:** `C:\Users\tommy\projects\star-wars-chat-app\`
- **Server files:** `~/star-wars-chat-app/`
- **Nginx config:** `/etc/nginx/sites-available/cinemavoices.conf`
- **Nginx enabled:** `/etc/nginx/sites-enabled/cinemavoices.conf`

## **🔄 Rollback Plan**
If something goes wrong:
```bash
# Remove the new nginx config
rm /etc/nginx/sites-enabled/cinemavoices.conf
rm /etc/nginx/sites-available/cinemavoices.conf

# Restore from backup
cp -r /etc/nginx/backups/* /etc/nginx/sites-enabled/

# Reload nginx
systemctl reload nginx

# Stop Star Wars containers
docker-compose -f docker-compose.production.yml down
```

**Good luck with the restart! May the Force be with your deployment! ⭐**
