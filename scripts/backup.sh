#!/bin/bash
# Purpose: Creates database backups and uploads them to Google Drive
# using rclone, with local backup rotation to save space
set -e

# Error handling function
error_exit() {
    echo "ERROR: $1" >&2
    exit "${2:-1}"
}

# Install rclone if not installed
if ! command -v rclone &> /dev/null; then
    echo "Installing rclone..."
    if ! curl https://rclone.org/install.sh | sudo bash; then
        error_exit "Failed to install rclone. Check your internet connection."
    fi
    
    # Configure rclone (first time only)
    echo "Please configure rclone for Google Drive:"
    echo "Run 'rclone config' and follow the prompts to set up Google Drive"
    echo "Name your remote 'gdrive'"
    if ! rclone config; then
        error_exit "Failed to configure rclone."
    fi
fi

# Variables
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
BACKUP_DIR="/opt/backups"
REMOTE_DIR="backups"
DB_CONTAINER="myapp_db_1"
DB_USER="youruser"
DB_NAME="yourdbname"

# Create backup directory if it doesn't exist
mkdir -p $BACKUP_DIR

echo "Creating database backup..."

# Verify that Docker and the database container are running
if ! docker ps | grep -q $DB_CONTAINER; then
    error_exit "Database container $DB_CONTAINER not running. Check Docker status."
fi

# Run pg_dump inside the Docker container
if ! docker exec -t $DB_CONTAINER pg_dump -U $DB_USER $DB_NAME > "$BACKUP_DIR/backup_$TIMESTAMP.sql"; then
    error_exit "Database backup failed. Check container and database status."
fi

# Compress the backup
echo "Compressing backup..."
if ! gzip "$BACKUP_DIR/backup_$TIMESTAMP.sql"; then
    error_exit "Failed to compress backup file."
fi
BACKUP_FILE="$BACKUP_DIR/backup_$TIMESTAMP.sql.gz"

# Verify the backup file exists and has content
if [ ! -s "$BACKUP_FILE" ]; then
    error_exit "Backup file is empty or doesn't exist after compression."
fi

# Upload to Google Drive
echo "Uploading to Google Drive..."
if ! rclone copy "$BACKUP_FILE" "gdrive:$REMOTE_DIR"; then
    echo "WARNING: Failed to upload to Google Drive. Keeping local backup anyway."
else
    echo "Backup uploaded to Google Drive: $REMOTE_DIR"
fi

# Keep only the last 7 local backups
echo "Cleaning old local backups..."
find $BACKUP_DIR -name "backup_*.sql.gz" -type f -printf '%T@ %p\n' | sort -n | head -n -7 | awk '{print $2}' | xargs -r rm
if [ $? -ne 0 ]; then
    echo "WARNING: Error while cleaning up old backups."
fi

echo "Backup completed: $BACKUP_FILE"