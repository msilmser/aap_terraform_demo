#!/bin/bash

# Run Demo Job Template
# This script launches the demo job template without UI interaction

set -e

CONTROLLER_HOST="192.168.100.10"
ADMIN_USER="admin"
ADMIN_PASSWORD="admin123"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "Starting demo job template execution..."

# Check if AAP is ready
echo "Checking AAP Controller availability..."
if ! curl -s -k "https://${CONTROLLER_HOST}/api/v2/ping/" > /dev/null; then
    echo "AAP Controller is not accessible at https://${CONTROLLER_HOST}"
    echo "Please ensure AAP is installed and running."
    exit 1
fi

echo "AAP Controller is ready!"

# List available job templates
echo "Listing available job templates..."
python3 "${SCRIPT_DIR}/aap-api.py" \
    --host "${CONTROLLER_HOST}" \
    --username "${ADMIN_USER}" \
    --password "${ADMIN_PASSWORD}" \
    --action list

# Launch the demo job template (ID 1 is typically the first created template)
echo "Launching demo job template..."
python3 "${SCRIPT_DIR}/aap-api.py" \
    --host "${CONTROLLER_HOST}" \
    --username "${ADMIN_USER}" \
    --password "${ADMIN_PASSWORD}" \
    --action launch \
    --template-id 1 \
    --wait

echo "Demo job template execution completed!"
echo ""
echo "You can also run specific commands:"
echo "  List templates: python3 ${SCRIPT_DIR}/aap-api.py --action list"
echo "  Launch job: python3 ${SCRIPT_DIR}/aap-api.py --action launch --template-id 1"
echo "  Check status: python3 ${SCRIPT_DIR}/aap-api.py --action status --job-id <job-id>"
echo "  Get output: python3 ${SCRIPT_DIR}/aap-api.py --action output --job-id <job-id>"