#!/bin/bash
set -e

echo "Setting up monitoring stack..."

# Create directories
mkdir -p /opt/monitoring/{prometheus,grafana/data,configs}

# Generate Grafana password
GRAFANA_PASSWORD=$(openssl rand -base64 12 | tr -dc 'a-zA-Z0-9!@#$%^&*()_+-=' | head -c 16)
GRAFANA_PASSWORD_FILE="/opt/monitoring/grafana_password.txt"
echo "$GRAFANA_PASSWORD" > "$GRAFANA_PASSWORD_FILE"
chmod 600 "$GRAFANA_PASSWORD_FILE"

# Create .env file for Docker Compose
echo "GF_SECURITY_ADMIN_PASSWORD=$GRAFANA_PASSWORD" > /opt/monitoring/.env
chmod 600 /opt/monitoring/.env

# Create Nginx basic auth
if ! command -v htpasswd &> /dev/null; then
    apt-get update && apt-get install -y apache2-utils
fi

if [ ! -f /opt/myapp/nginx/.htpasswd ]; then
    mkdir -p /opt/myapp/nginx
    NGINX_PASSWORD=$(openssl rand -base64 12)
    htpasswd -bc /opt/myapp/nginx/.htpasswd admin "$NGINX_PASSWORD"
    chmod 600 /opt/myapp/nginx/.htpasswd
fi

# Configure firewall
ufw allow 9090/tcp comment "Prometheus"
ufw allow 3000/tcp comment "Grafana"

# Deploy stack
cd /opt/monitoring
docker-compose --env-file .env up -d

echo "Setup complete!"
echo "Grafana URL: https://yourdomain.com/grafana/"
echo "Admin credentials:"
echo "Username: admin"
echo "Password: $GRAFANA_PASSWORD (stored in $GRAFANA_PASSWORD_FILE)"