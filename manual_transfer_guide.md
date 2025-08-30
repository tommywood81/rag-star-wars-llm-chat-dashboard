# Manual File Transfer Guide

Since SSH key authentication isn't set up yet, here's how to manually transfer files:

## Option 1: Digital Ocean Console (Easiest)

1. **Open Digital Ocean Console:**
   - Go to your droplet: ubuntu-s-2vcpu-4gb-syd1-01
   - Click "Console" button
   - Log in with your credentials

2. **Create project directory:**
   ```bash
   mkdir -p ~/star-wars-chat-app
   cd ~/star-wars-chat-app
   ```

3. **Copy and paste each file content:**
   - Copy the content of each file from your local machine
   - Use `nano filename` to create and paste content
   - Or use `cat > filename << 'EOF'` method

## Option 2: Set up SSH Keys First

1. **Add your public key to Digital Ocean:**
   ```
   ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGp0UGDa6Q1/ZyKmivIj1Wa77lZrMyU29x+k031SL2Sf tommy@LAPTOP-U7F1NDJK
   ```

2. **Then run the transfer script:**
   ```powershell
   .\transfer_to_server.ps1
   ```

## Files to Transfer:

1. `deploy_domain.py`
2. `docker-compose.production.yml`
3. `nginx.conf`
4. `Dockerfile.nginx`
5. `setup-ssl.sh`
6. `DOMAIN_SETUP_GUIDE.md`

## After Transfer:

1. **SSH into server:**
   ```bash
   ssh ubuntu@209.38.89.159
   ```

2. **Navigate to project:**
   ```bash
   cd ~/star-wars-chat-app
   ```

3. **Run deployment:**
   ```bash
   python3 deploy_domain.py
   ```

## Quick Test:

Once you have access, test with:
```bash
echo "Server access successful!"
```
