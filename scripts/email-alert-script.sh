#!/bin/bash
# Purpose: Check backup status and send email alert if backup failed
# File path: /opt/myapp/scripts/check_backup.sh

set -e

# Error handling function
error_exit() {
    echo "ERROR: $1" >&2
    exit "${2:-1}"
}

# Load email configuration from json file
CONFIG_FILE="/opt/myapp/config/email.json"

if [ ! -f "$CONFIG_FILE" ]; then
    error_exit "Email configuration file not found at $CONFIG_FILE"
fi

# Extract values using jq for more robust JSON parsing
if ! command -v jq &> /dev/null; then
    echo "Installing jq for JSON parsing..."
    apt-get update && apt-get install -y jq || error_exit "Failed to install jq"
fi

SMTP_HOST=$(jq -r '.SmtpHost' "$CONFIG_FILE")
SMTP_PORT=$(jq -r '.SmtpPort' "$CONFIG_FILE")
EMAIL_USERNAME=$(jq -r '.EmailUsername' "$CONFIG_FILE")
EMAIL_PASSWORD=$(jq -r '.EmailPassword' "$CONFIG_FILE")
EMAIL_FROM=$(jq -r '.EmailFrom' "$CONFIG_FILE")
EMAIL_TO=$(jq -r '.EmailTo' "$CONFIG_FILE")

# Validate required configuration
if [ -z "$SMTP_HOST" ] || [ -z "$EMAIL_USERNAME" ] || [ -z "$EMAIL_PASSWORD" ]; then
    error_exit "Missing required email configuration in $CONFIG_FILE"
fi

# Application info
APP_NAME=$(basename $(dirname $(dirname "$PWD")))
HOSTNAME=$(hostname)
BACKUP_LOG="/var/log/backup.log"

# Check if backup log exists
if [ ! -f "$BACKUP_LOG" ]; then
    error_exit "Backup log file not found at $BACKUP_LOG"
fi

# Check for backup failures
if grep -i "error\|fail\|exception" "$BACKUP_LOG" | grep -q "$(date +%Y-%m-%d)"; then
    # Get the error message
    ERROR_MSG=$(grep -i "error\|fail\|exception" "$BACKUP_LOG" | grep "$(date +%Y-%m-%d)" | tail -10)
    
    # Create email content
    SUBJECT="[$APP_NAME] Backup FAILED on $HOSTNAME"
    BODY="Backup job failed on $HOSTNAME at $(date).
Error details:
$ERROR_MSG

Please check the backup log at $BACKUP_LOG for more information.
Server: $HOSTNAME
Time: $(date)"
    
    # Send email using Python (more reliable than mail command)
    python3 -c "
import smtplib
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart

# Email details
sender = '$EMAIL_FROM'
recipient = '$EMAIL_TO'
password = '$EMAIL_PASSWORD'
subject = '$SUBJECT'
body = '''$BODY'''

# Create message
message = MIMEMultipart()
message['From'] = sender
message['To'] = recipient
message['Subject'] = subject
message.attach(MIMEText(body, 'plain'))

# Send email
try:
    server = smtplib.SMTP('$SMTP_HOST', $SMTP_PORT)
    server.starttls()
    server.login('$EMAIL_USERNAME', password)
    server.send_message(message)
    server.quit()
    print('Email sent successfully')
except Exception as e:
    print(f'Error sending email: {e}')
"
    
    echo "Backup failure detected, email alert sent to $EMAIL_TO"
else
    echo "Backup seems to be working fine."
fi
