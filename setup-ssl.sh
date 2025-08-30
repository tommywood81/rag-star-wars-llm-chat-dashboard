#!/bin/sh

# SSL Setup Script for Star Wars RAG Dashboard
# This script sets up SSL certificates using Let's Encrypt

set -e

DOMAIN="cinemavoices.com"
EMAIL="your-email@example.com"  # Change this to your email

echo "🔒 Setting up SSL certificates for $DOMAIN..."

# Check if certificates already exist
if [ -d "/etc/letsencrypt/live/$DOMAIN" ]; then
    echo "✅ SSL certificates already exist for $DOMAIN"
    echo "🔄 Renewing certificates..."
    certbot renew --quiet
else
    echo "📝 Requesting new SSL certificates from Let's Encrypt..."
    
    # Stop nginx temporarily for certificate verification
    nginx -s stop || true
    
    # Request certificate
    certbot certonly \
        --standalone \
        --email $EMAIL \
        --agree-tos \
        --no-eff-email \
        --domains $DOMAIN,www.$DOMAIN \
        --non-interactive
    
    echo "✅ SSL certificates obtained successfully!"
fi

# Test nginx configuration
echo "🔍 Testing nginx configuration..."
nginx -t

# Start nginx
echo "🚀 Starting nginx..."
nginx -g "daemon off;"
