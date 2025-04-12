#!/bin/bash
# Purpose: EXACT replacement of ACTUAL placeholders found in files
set -eo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

CONFIG_FILE="${1:-deployment.conf}"

declare -A REPLACEMENTS=(
    # From docker-compose.yml
    ["yourdbname"]="$DB_NAME"
    ["youruser"]="$DB_USER"
    
    # From nginx configs
    ["yourdomain.com"]="$DOMAIN"
    
    # From backup.sh
    ["myapp_db_1"]="${APP_NAME}_db_1"
    ["backups"]="$RCLONE_REMOTE"
    
    # From Dockerfile
    ["YourAppName"]="$APP_NAME"
    
    # From systemd service
    ["myapp"]="${APP_NAME}"
)

FILE_LIST=(
    "docker-compose.yml"
    "nginx/conf.d/app.conf"
    "scripts/backup.sh"
    "systemd/docker-compose-app.service"
    "Dockerfile"
)

validate_config() {
    [[ -z "$DOMAIN" ]] && { echo -e "${RED}DOMAIN is required${NC}"; exit 1; }
    [[ -z "$DB_NAME" ]] && { echo -e "${RED}DB_NAME is required${NC}"; exit 1; }
    [[ -z "$DB_USER" ]] && { echo -e "${RED}DB_USER is required${NC}"; exit 1; }
    [[ -z "$APP_NAME" ]] && { echo -e "${RED}APP_NAME is required${NC}"; exit 1; }
}

verify_placeholders() {
    echo -e "${YELLOW}Checking placeholders exist before replacement:${NC}"
    
    declare -A REQUIRED_PATTERNS=(
        ["yourdbname"]="docker-compose.yml"
        ["youruser"]="docker-compose.yml"
        ["yourdomain.com"]="nginx/conf.d/app.conf"
        ["myapp_db_1"]="scripts/backup.sh"
        ["backups"]="scripts/backup.sh"
        ["YourAppName"]="Dockerfile"
        ["myapp"]="systemd/docker-compose-app.service"
    )

    local errors=0
    for pattern in "${!REQUIRED_PATTERNS[@]}"; do
        file="${REQUIRED_PATTERNS[$pattern]}"
        if ! grep -q "$pattern" "$file" 2>/dev/null; then
            echo -e "${RED}ERROR: Pattern '$pattern' not found in $file${NC}"
            ((errors++))
        fi
    done

    return $errors
}

replace_placeholders() {
    for file in "${FILE_LIST[@]}"; do
        [[ ! -f "$file" ]] && continue
        
        # Create backup
        cp "$file" "$file.bak"
        
        # Perform replacements
        for pattern in "${!REPLACEMENTS[@]}"; do
            replacement="${REPLACEMENTS[$pattern]}"
            sed -i "s/$pattern/$replacement/g" "$file"
        done
        
        # Special case for Dockerfile DLL
        if [[ "$file" == "Dockerfile" ]]; then
            sed -i "s/YourAppName\.dll/${APP_NAME}.dll/g" "$file"
        fi
    done
}

# Main execution
source "$CONFIG_FILE"
validate_config

if ! verify_placeholders; then
    echo -e "${RED}Aborting due to missing placeholders${NC}"
    exit 1
fi

replace_placeholders

echo -e "${GREEN}Configuration completed successfully!${NC}"
echo -e "${YELLOW}Backups created with .bak extension${NC}"