#!/bin/bash
# Purpose: Configures the Gotty terminal interface for web-based access to
# the application console, generating credentials if not already defined
set -e

# Error handling function
error_exit() {
    echo "ERROR: $1" >&2
    exit "${2:-1}"
}

echo "Setting up Gotty..."

# Check if Docker is installed
if ! command -v docker &> /dev/null; then
    error_exit "Docker is not installed. Please run initial_setup.sh first."
fi

# Check if docker-compose is installed
if ! command -v docker-compose &> /dev/null; then
    error_exit "Docker Compose is not installed. Please run initial_setup.sh first."
fi

# Set variables from .env file or use defaults
if [ -f /opt/myapp/.env ]; then
    source /opt/myapp/.env
else
    echo "WARNING: .env file not found. Creating a new one."
    GOTTY_USER=${GOTTY_USER:-admin}
    GOTTY_PASSWORD=${GOTTY_PASSWORD:-$(openssl rand -base64 8)}
    
    # Create .env file with minimal settings
    cat > /opt/myapp/.env << EOF
GOTTY_USER=$GOTTY_USER
GOTTY_PASSWORD=$GOTTY_PASSWORD
EOF
    
    chmod 600 /opt/myapp/.env
fi

# Check if .env contains required variables
if [ -z "$GOTTY_USER" ] || [ -z "$GOTTY_PASSWORD" ]; then
    echo "GOTTY_USER or GOTTY_PASSWORD not set in .env. Adding them now."
    GOTTY_USER=${GOTTY_USER:-admin}
    GOTTY_PASSWORD=${GOTTY_PASSWORD:-$(openssl rand -base64 8)}
    
    echo "GOTTY_USER=$GOTTY_USER" >> /opt/myapp/.env
    echo "GOTTY_PASSWORD=$GOTTY_PASSWORD" >> /opt/myapp/.env
    
    # If we had to modify the .env file, set proper permissions
    chmod 600 /opt/myapp/.env
fi

# Update docker-compose configuration if necessary
cd /opt/myapp

# Start the services
echo "Starting Docker services..."
if ! docker-compose up -d; then
    error_exit "Failed to start Docker services. Check docker-compose.yml for errors."
fi

echo "Gotty setup complete!"
echo "You can access your console at: https://yourdomain.com/console/"
echo "Username: $GOTTY_USER"
echo "Password: $GOTTY_PASSWORD"