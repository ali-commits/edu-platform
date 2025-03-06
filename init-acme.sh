#!/bin/bash

# Create traefik directory if it doesn't exist
mkdir -p traefik

# Create or reset acme.json with proper permissions
touch traefik/acme.json
chmod 600 traefik/acme.json

echo "acme.json file initialized with proper permissions (600)"
echo "You can now start your containers with: docker-compose up -d"
