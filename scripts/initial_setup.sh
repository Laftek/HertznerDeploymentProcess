#!/bin/bash
# Purpose: Initial server setup script that configures security, installs required packages,
# and sets up the environment for running a Docker-based C# application.
set -e

echo "Starting server setup..."

# Update system packages
if ! apt update && apt upgrade -y; then
    echo "ERROR: Failed to update system packages. Please check your internet connection."
    exit 1
fi

# Install necessary packages
echo "Installing required packages..."
if ! apt install -y ufw docker.io docker-compose git fail2ban unattended-upgrades curl python3-pip logrotate; then
    echo "ERROR: Failed to install required packages."
    exit 1
fi

# Configure firewall
echo "Configuring firewall..."
ufw default deny incoming
ufw default allow outgoing
ufw allow ssh
ufw allow http
ufw allow https
ufw allow 8080
if ! ufw --force enable; then
    echo "WARNING: Failed to enable UFW firewall."
fi

echo "Firewall configured and enabled"

# Setup Docker
echo "Configuring Docker..."
if ! systemctl enable docker; then
    echo "WARNING: Failed to enable Docker service."
fi
if ! systemctl start docker; then
    echo "WARNING: Failed to start Docker service."
fi

# NOTE: usermod -aG docker $USER is removed as it might not work correctly in the script context.
# User addition to the docker group will be done in the deployment instructions

echo "Docker setup completed"

# Configure automatic updates
echo "Setting up automatic updates..."
cat > /etc/apt/apt.conf.d/20auto-upgrades << EOF
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Download-Upgradeable-Packages "1";
APT::Periodic::AutocleanInterval "7";
APT::Periodic::Unattended-Upgrade "1";
EOF

echo "Automatic updates configured"

# Configure fail2ban
echo "Configuring fail2ban..."
if [ -f /etc/fail2ban/jail.conf ]; then
    cp /etc/fail2ban/jail.conf /etc/fail2ban/jail.local
    systemctl enable fail2ban
    systemctl start fail2ban

    echo "Fail2ban configured"
else
    echo "WARNING: fail2ban configuration file not found."
fi

# Create required directories
echo "Creating application directories..."
mkdir -p /opt/myapp/logs
mkdir -p /opt/myapp/nginx/conf.d
mkdir -p /opt/myapp/certbot/conf
mkdir -p /opt/myapp/certbot/www
mkdir -p /opt/backups

# Set proper permissions for all directories
chmod 750 /opt/myapp
chmod 750 /opt/myapp/logs
chmod 750 /opt/myapp/nginx
chmod 750 /opt/myapp/nginx/conf.d
chmod 700 /opt/myapp/certbot
chmod 700 /opt/myapp/certbot/conf
chmod 750 /opt/myapp/certbot/www
chmod 750 /opt/backups

# Clone repository (if provided)
# Note: We check if the directory is empty to avoid duplication
if [ ! -z "$1" ] && [ ! "$(ls -A /opt/myapp)" ]; then
    echo "Cloning repository from $1..."
    if ! cd /opt/myapp && git clone "$1" .; then
        echo "ERROR: Failed to clone repository from $1"
    else
        echo "Repository cloned from $1"
    fi
elif [ ! -z "$1" ]; then
    echo "Destination directory is not empty. Skipping repository cloning."
fi

# Generate a secure .env file template
if [ ! -f /opt/myapp/.env ]; then
    echo "Creating .env file..."
    cat > /opt/myapp/.env << EOF
# Database credentials
DB_PASSWORD=$(openssl rand -base64 16)

# Binance API credentials
BINANCE_API_KEY=your_binance_api_key
BINANCE_API_SECRET=your_binance_api_secret

# Gotty credentials
GOTTY_USER=admin
GOTTY_PASSWORD=$(openssl rand -base64 8)
EOF

    chmod 600 /opt/myapp/.env
    echo "Created .env file with secure password"
else
    echo "NOTE: .env file already exists. Keeping existing file."
fi

# Setup email configuration if not exists
if [ ! -f /opt/myapp/config/email.json ]; then
    echo "Creating email configuration..."
    cat > /opt/myapp/config/email.json << EOF
{
  "SmtpHost": "smtp.gmail.com",
  "SmtpPort": 587,
  "EmailUsername": "your_email@gmail.com",
  "EmailPassword": "your_app_password",
  "EmailFrom": "your_email@gmail.com",
  "EmailTo": "recipient@email.com"
}
EOF
    chmod 600 /opt/myapp/config/email.json
    echo "Created email configuration file"
else
    echo "NOTE: Email configuration already exists. Keeping existing file."
fi
# Configure log rotation for application logs
if [ ! -f /etc/logrotate.d/myapp ]; then
    echo "Configuring log rotation..."
    cat > /etc/logrotate.d/myapp << EOF
/opt/myapp/logs/*.log {
    daily
    missingok
    rotate 14
    compress
    delaycompress
    notifempty
    create 0640 root root
}
EOF
    chmod 644 /etc/logrotate.d/myapp
    echo "Log rotation configured"
else
    echo "Log rotation config already exists."
fi

# Configure SSH hardening
echo "Hardening SSH configuration..."
if grep -q "^#PermitRootLogin" /etc/ssh/sshd_config; then
    sed -i 's/#PermitRootLogin yes/PermitRootLogin no/' /etc/ssh/sshd_config
fi
if grep -q "^#PasswordAuthentication" /etc/ssh/sshd_config; then
    sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
fi
systemctl restart ssh

echo "SSH hardened"
echo "Initial server setup complete!"

# Show disk space
echo "Current disk space usage:"
df -h
