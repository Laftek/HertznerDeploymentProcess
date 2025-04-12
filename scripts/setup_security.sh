#!/bin/bash
# Purpose: Additional security hardening beyond the initial setup
set -e

echo "Starting security hardening..."

# Update permissions on systemd service
if [ -f /etc/systemd/system/docker-compose-app.service ]; then
    sudo chmod 640 /etc/systemd/system/docker-compose-app.service
    sudo systemctl daemon-reload
    echo "Systemd service hardened"
else
    echo "WARNING: Systemd service file not found. Skipping service hardening."
fi

# Set immutable flag on important files - with checks
if [ -f /opt/myapp/.env ]; then
    # Check if the immutable flag is already set
    if lsattr /opt/myapp/.env | grep -q "i"; then
        echo ".env file already has immutable flag set."
    else
        sudo chattr +i /opt/myapp/.env
        echo "Set immutable flag on .env file"
		
													  
    fi
else
    echo "WARNING: .env file not found. Skipping immutable flag setting."
fi

if [ -f /etc/ssh/sshd_config ]; then
    # Check if the immutable flag is already set
    if lsattr /etc/ssh/sshd_config | grep -q "i"; then
        echo "SSH config already has immutable flag set."
    else
        sudo chattr +i /etc/ssh/sshd_config
        echo "Set immutable flag on SSH config"
		
													   
    fi
else
    echo "WARNING: SSH config file not found. Skipping immutable flag setting."
fi

# Verify UFW is running
								  
if sudo ufw status | grep -q "Status: active"; then
    echo "Firewall is active and configured."
else
    echo "WARNING: Firewall appears to be inactive. Enabling..."
    sudo ufw --force enable
fi

# Removed redundant line for unattended-upgrades as it's already configured in initial_setup.sh

# Harden shared memory
if ! grep -q "/run/shm" /etc/fstab; then
    echo "Hardening shared memory..."
    echo "tmpfs /run/shm tmpfs defaults,noexec,nosuid 0 0" | sudo tee -a /etc/fstab
    echo "Shared memory hardened. This will take effect after reboot."
else
    echo "Shared memory already hardened."
fi

# Set proper permissions for application directories
echo "Setting secure permissions on application directories..."
sudo chmod 750 /opt/myapp
sudo chmod -R 700 /opt/myapp/certbot/conf

echo "Security hardening complete!"
