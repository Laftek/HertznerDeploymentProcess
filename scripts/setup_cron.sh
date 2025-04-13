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

# Check if email alert script exists
if [ ! -f /opt/myapp/scripts/check_backup.sh ]; then
    echo "ERROR: Email alert script not found at /opt/myapp/scripts/check_backup.sh"
    echo "Make sure your repository is properly cloned and structured."
    exit 1
fi

# Make scripts executable if they aren't already
chmod +x /opt/myapp/scripts/backup.sh
chmod +x /opt/myapp/scripts/check_backup.sh

# Setup backup cron job
EXISTING_CRON=$(crontab -l 2>/dev/null || echo "")
if ! echo "$EXISTING_CRON" | grep -q "/opt/myapp/scripts/backup.sh"; then
    (echo "$EXISTING_CRON"; echo "0 2 * * * /opt/myapp/scripts/backup.sh >> /var/log/backup.log 2>&1") | crontab -
    echo "Backup cron job added"
else
    echo "Backup cron job already exists"
fi

# Setup email alert cron job
if ! echo "$EXISTING_CRON" | grep -q "/opt/myapp/scripts/check_backup.sh"; then
    (crontab -l 2>/dev/null || echo "") | \
    { cat; echo "30 2 * * * /opt/myapp/scripts/check_backup.sh >> /var/log/email_alerts.log 2>&1"; } | \
    crontab -
    echo "Email alert cron job added"
else
    echo "Email alert cron job already exists"
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

# Setup monitoring check cron job
if ! echo "$EXISTING_CRON" | grep -q "docker-compose.*monitoring"; then
    (crontab -l 2>/dev/null || echo "") | \
    { cat; echo "0 * * * * cd /opt/monitoring && docker-compose ps | grep -q 'prometheus.*Up' || docker-compose up -d >> /var/log/monitoring_watch.log 2>&1"; } | \
    crontab -
    echo "Monitoring watchdog cron job added"
else
    echo "Monitoring watchdog cron job already exists"
fi

# Create log files with proper permissions if they don't exist
for log_file in /var/log/backup.log /var/log/disk_space.log /var/log/email_alerts.log /var/log/monitoring_watch.log; do
    if [ ! -f "$log_file" ]; then
        touch "$log_file"
        chmod 640 "$log_file"
    fi
done

# View created cron jobs
echo "Current cron jobs:"
crontab -l

echo "Cron jobs setup complete!"
