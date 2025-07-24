#!/bin/bash

# AAP Installation Script
# This script downloads and installs Ansible Automation Platform

set -e

AAP_VERSION="2.4"
INSTALLER_DIR="/tmp/aap-installer"
INSTALLER_URL="https://access.redhat.com/downloads/content/480/ver=2.4/rhel---8/2.4/x86_64/product-software"

echo "Starting AAP ${AAP_VERSION} Installation..."

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root"
   exit 1
fi

# Create installer directory
mkdir -p ${INSTALLER_DIR}
cd ${INSTALLER_DIR}

# Download AAP installer (requires Red Hat subscription)
echo "Please download the AAP installer manually from:"
echo "https://access.redhat.com/downloads/content/480"
echo "Place the installer bundle in: ${INSTALLER_DIR}"
echo ""
echo "Expected filename: ansible-automation-platform-setup-bundle-${AAP_VERSION}-*.tar.gz"
echo ""

# Wait for installer bundle
while true; do
    if ls ansible-automation-platform-setup-bundle-${AAP_VERSION}-*.tar.gz 1> /dev/null 2>&1; then
        INSTALLER_BUNDLE=$(ls ansible-automation-platform-setup-bundle-${AAP_VERSION}-*.tar.gz | head -1)
        echo "Found installer bundle: ${INSTALLER_BUNDLE}"
        break
    else
        echo "Waiting for installer bundle..."
        sleep 10
    fi
done

# Extract installer
echo "Extracting installer..."
tar -xzf ${INSTALLER_BUNDLE}

# Find extracted directory
EXTRACTED_DIR=$(find . -name "ansible-automation-platform-setup-bundle-${AAP_VERSION}*" -type d | head -1)
cd ${EXTRACTED_DIR}

# Generate inventory file
echo "Generating inventory file..."
cat > inventory << EOF
[automationcontroller]
aap-controller ansible_host=192.168.100.10

[automationhub]
aap-hub ansible_host=192.168.100.11

[database]
aap-database ansible_host=192.168.100.12

[all:vars]
ansible_user=ansible
ansible_ssh_private_key_file=~/.ssh/id_rsa

admin_password='admin123'
pg_host='192.168.100.12'
pg_port='5432'
pg_database='awx'
pg_username='awx'
pg_password='awxpass'
pg_sslmode='prefer'

automationhub_admin_password='admin123'
automationhub_pg_host='192.168.100.12'
automationhub_pg_port='5432'
automationhub_pg_database='pulp'
automationhub_pg_username='awx'
automationhub_pg_password='awxpass'
automationhub_pg_sslmode='prefer'

registry_url='registry.redhat.io'
registry_username='your-rh-username'
registry_password='your-rh-password'
EOF

echo "Inventory file created. Please update registry credentials in inventory file."
echo ""
echo "To install AAP, run:"
echo "cd ${EXTRACTED_DIR}"
echo "./setup.sh"
echo ""
echo "Installation will take 30-60 minutes to complete."