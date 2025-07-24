#!/bin/bash

# Post-installation configuration script
# This script configures AAP after installation

set -e

CONTROLLER_HOST="192.168.100.10"
ADMIN_PASSWORD="admin123"

echo "Starting post-installation configuration..."

# Wait for controller to be ready
echo "Waiting for AAP Controller to be ready..."
while ! curl -s -k "https://${CONTROLLER_HOST}/api/v2/ping/" > /dev/null; do
    echo "Waiting for controller..."
    sleep 10
done

echo "Controller is ready!"

# Run post-install playbook
echo "Running post-installation playbook..."
ansible-playbook -i ../ansible/inventory/hosts.yml ../ansible/playbooks/post-install.yml

echo "Post-installation configuration completed!"
echo ""
echo "AAP Controller URL: https://${CONTROLLER_HOST}"
echo "Username: admin"
echo "Password: ${ADMIN_PASSWORD}"
echo ""
echo "Token and job template ID saved to /tmp/ on controller host"