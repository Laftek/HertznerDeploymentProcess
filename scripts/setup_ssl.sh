#!/bin/bash
# Purpose: Automates the process of obtaining and configuring
# Let's Encrypt SSL certificates for secure HTTPS connections
set -e

# Error handling function
error_exit() {
    echo "ERROR: $1" >&2
    exit "${2:-1}"
}

# Check if domain is provided
if [ -z "$1" ]; then
  echo "Usage: $0 yourdomain.com"
  exit 1
fi

DOMAIN=$1

# Validate domain format
if ! echo "$DOMAIN" | grep -qP '(?=^.{4,253}$)(^((?!-)[a-zA-Z0-9-]{1,63}(?<!-)\.)+[a-zA-Z]{2,63}$)'; then
    error_exit "Invalid domain format: $DOMAIN"
fi

# Check if Nginx config exists
if [ ! -f /opt/myapp/nginx/conf.d/app.conf ]; then
    error_exit "Nginx configuration file not found at /opt/myapp/nginx/conf.d/app.conf"
fi

# Replace domain in Nginx config
echo "Updating Nginx configuration for domain: $DOMAIN"
sed -i "s/yourdomain.com/$DOMAIN/g" /opt/myapp/nginx/conf.d/app.conf

# Check if Docker is running
if ! docker info &>/dev/null; then
    error_exit "Docker is not running. Please start Docker service first."
fi

# Start Nginx
cd /opt/myapp || error_exit "Application directory not found"
echo "Starting Nginx..."
if ! docker-compose up -d nginx; then
    error_exit "Failed to start Nginx container"
fi

# Wait for Nginx to start
echo "Waiting for Nginx to start..."
sleep 5

# Get SSL certificate
echo "Requesting SSL certificate for $DOMAIN..."
if ! docker-compose run --rm certbot certonly --webroot -w /var/www/certbot -d "$DOMAIN" --email "admin@$DOMAIN" --agree-tos --no-eff-email; then
    error_exit "Failed to obtain SSL certificate. Check domain configuration and connectivity."
fi

# Verify certificate was created
if [ ! -d "/opt/myapp/certbot/conf/live/$DOMAIN" ]; then
    error_exit "Certificate directory not found after request."
fi

# Reload Nginx to apply SSL
echo "Reloading Nginx configuration..."
if ! docker-compose exec nginx nginx -s reload; then
    error_exit "Failed to reload Nginx configuration"
fi

echo "SSL certificate for $DOMAIN has been set up successfully!"
echo "Certificate will auto-renew via the certbot container."