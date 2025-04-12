#!/bin/bash
# Purpose: Set up scheduled tasks for backups and maintenance
set -e

echo "Setting up cron jobs..."

# Check if backup script exists
if [ ! -f /opt/myapp/scripts/backup.sh ]; then
    echo "ERROR: Backup script not found at /opt/myapp/scripts/backup.sh"
    echo "Make sure your repository is properly cloned and structured."
    exit 1
fi

# Make backup script executable if it isn't already
if [ ! -x /opt/myapp/scripts/backup.sh ]; then
    chmod +x /opt/myapp/scripts/backup.sh
    echo "Made backup script executable"
fi

# Setup backup cron job
EXISTING_CRON=$(crontab -l 2>/dev/null || echo "")
if ! echo "$EXISTING_CRON" | grep -q "/opt/myapp/scripts/backup.sh"; then
    (echo "$EXISTING_CRON"; echo "0 2 * * * /opt/myapp/scripts/backup.sh >> /var/log/backup.log 2>&1") | crontab -
    echo "Backup cron job added"
else
    echo "Backup cron job already exists"
fi

# Setup disk space check cron job
if ! echo "$EXISTING_CRON" | grep -q "df -h.*disk_space.log"; then
    (crontab -l 2>/dev/null || echo "") | grep -v "df -h" | \
    { cat; echo "0 8 * * * df -h > /var/log/disk_space.log 2>&1"; } | \
    crontab -
    echo "Disk space check cron job added"
else
    echo "Disk space check cron job already exists"
fi

# Create log files with proper permissions if they don't exist
if [ ! -f /var/log/backup.log ]; then
    touch /var/log/backup.log
    chmod 640 /var/log/backup.log
fi

if [ ! -f /var/log/disk_space.log ]; then
    touch /var/log/disk_space.log
    chmod 640 /var/log/disk_space.log
fi

# View created cron jobs
echo "Current cron jobs:"
crontab -l

echo "Cron jobs setup complete!"