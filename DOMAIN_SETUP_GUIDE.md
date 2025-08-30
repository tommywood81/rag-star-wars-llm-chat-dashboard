# Domain Setup Guide for cinemavoices.com

This guide will help you set up your domain `cinemavoices.com` with nginx and SSL certificates.

## Prerequisites

1. ✅ Domain purchased and configured in Cloudflare Zero Trust
2. ✅ Server running your Star Wars RAG application
3. ✅ Docker and Docker Compose installed on server

## Step 1: DNS Configuration

Ensure your domain `cinemavoices.com` points to your server's public IP address:

1. Log into Cloudflare
2. Go to DNS settings for `cinemavoices.com`
3. Add an A record:
   - **Name**: `@` (or leave blank)
   - **IPv4 address**: Your server's public IP
   - **Proxy status**: DNS only (gray cloud)
4. Add a CNAME record for www:
   - **Name**: `www`
   - **Target**: `cinemavoices.com`
   - **Proxy status**: DNS only (gray cloud)

## Step 2: Deploy with Nginx

Run the domain deployment script:

```bash
python deploy_domain.py
```

This script will:
- Check DNS configuration
- Build the nginx Docker image
- Deploy all services with nginx reverse proxy
- Set up SSL certificates (if you provide an email)

## Step 3: Manual SSL Setup (if needed)

If the automatic SSL setup fails, you can set it up manually:

1. SSH into your server
2. Run the SSL setup script:

```bash
# Enter the nginx container
docker exec -it star_wars_nginx /bin/sh

# Run SSL setup
/usr/local/bin/setup-ssl.sh
```

3. Update the email address in the script first:

```bash
# Edit the script
sed -i 's/your-email@example.com/your-actual-email@domain.com/' /usr/local/bin/setup-ssl.sh

# Run the setup
/usr/local/bin/setup-ssl.sh
```

## Step 4: Verify Deployment

Check that everything is working:

```bash
# Check service status
docker-compose -f docker-compose.production.yml ps

# Check nginx logs
docker-compose -f docker-compose.production.yml logs nginx

# Test the domain
curl -I https://cinemavoices.com
```

## Step 5: Cloudflare Configuration

Configure Cloudflare for optimal performance:

1. **SSL/TLS Settings**:
   - Set SSL/TLS encryption mode to "Full (strict)"
   - Enable "Always Use HTTPS"

2. **Page Rules** (optional):
   - Create a rule: `cinemavoices.com/*`
   - Set "Always Use HTTPS"

3. **Security Settings**:
   - Enable "I'm Under Attack" mode temporarily if needed
   - Set security level to "Medium"

## Troubleshooting

### Nginx Error
If you see "nginx needs to be set up":
- The nginx container isn't running
- Check: `docker ps | grep nginx`
- Start it: `docker-compose -f docker-compose.production.yml up -d nginx`

### SSL Certificate Issues
If SSL setup fails:
- Ensure port 80 is open for Let's Encrypt verification
- Check DNS propagation: `nslookup cinemavoices.com`
- Try manual setup: `docker exec star_wars_nginx certbot certonly --standalone -d cinemavoices.com`

### Domain Not Resolving
If domain doesn't resolve:
- Check DNS settings in Cloudflare
- Wait for DNS propagation (can take up to 24 hours)
- Test with: `dig cinemavoices.com`

## Management Commands

```bash
# View all logs
docker-compose -f docker-compose.production.yml logs -f

# Restart nginx
docker restart star_wars_nginx

# Renew SSL certificates
docker exec star_wars_nginx certbot renew

# Update deployment
python deploy_domain.py --skip-dns --skip-ssl
```

## Security Notes

- SSL certificates auto-renew every 60 days
- Nginx includes rate limiting and security headers
- All traffic is redirected to HTTPS
- CORS is configured for API access

## Support

If you encounter issues:
1. Check the logs: `docker-compose -f docker-compose.production.yml logs`
2. Verify DNS: `nslookup cinemavoices.com`
3. Test connectivity: `curl -I https://cinemavoices.com`

Your domain should now be accessible at `https://cinemavoices.com`! 🚀
