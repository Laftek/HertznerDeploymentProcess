#!/bin/bash
# Purpose: Replace placeholder variables in configuration files with actual values
# File path: /opt/myapp/scripts/replace_vars.sh

set -e

CONFIG_FILE=$1

if [ ! -f "$CONFIG_FILE" ]; then
    echo "ERROR: Configuration file not found: $CONFIG_FILE"
    exit 1
fi

# Load configuration
source "$CONFIG_FILE"

echo "Replacing variables in configuration files..."

# Required variables
if [ -z "$APP_NAME" ]; then
    echo "ERROR: APP_NAME not defined in $CONFIG_FILE"
    exit 1
fi

# Optional variables with defaults
DOMAIN=${DOMAIN:-"$APP_NAME.local"}
DB_NAME=${DB_NAME:-"${APP_NAME}_db"}
DB_USER=${DB_USER:-"${APP_NAME}_user"}
RCLONE_REMOTE=${RCLONE_REMOTE:-"mybackups"}

# Function to replace placeholders in a file
replace_in_file() {
    local file=$1
    
    if [ ! -f "$file" ]; then
        echo "WARNING: File not found for variable replacement: $file"
        return
    }
    
    echo "Updating $file..."
    
    # Replace placeholders
    sed -i "s/yourappname/$APP_NAME/gi" "$file"
    sed -i "s/YourAppName/$APP_NAME/g" "$file"
    sed -i "s/myapp/$APP_NAME/g" "$file"
    sed -i "s/yourdomain.com/$DOMAIN/g" "$file"
    sed -i "s/yourdbname/$DB_NAME/g" "$file"
    sed -i "s/youruser/$DB_USER/g" "$file"
    sed -i "s/gdrive/$RCLONE_REMOTE/g" "$file"
}

# Find and replace in all configuration files
find . -type f \( -name "*.yml" -o -name "*.conf" -o -name "*.sh" -o -name "*.service" -o -name "Dockerfile" \) -not -path "*/\.*" | while read file; do
    replace_in_file "$file"
done

# Special handling for Dockerfile to update the ENTRYPOINT
if [ -f "./Dockerfile" ]; then
    sed -i "s/ENTRYPOINT \[\"dotnet\", \"YourAppName.dll\"\]/ENTRYPOINT [\"dotnet\", \"$APP_NAME.dll\"]/" "./Dockerfile"
fi

echo "Variable replacement complete!"
