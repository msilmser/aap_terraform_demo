#!/bin/bash

# Manual cleanup script for AAP environment
# Run this script when you need to clean up a failed deployment

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  AAP Environment Cleanup Script       ${NC}"
echo -e "${BLUE}========================================${NC}"
echo

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo -e "${YELLOW}Cleaning up AAP environment...${NC}"

# Clean up Terraform resources
echo "1. Destroying Terraform resources..."
cd "$SCRIPT_DIR/terraform"
if [ -f "terraform.tfstate" ]; then
    terraform destroy -auto-approve || echo -e "${RED}Some Terraform resources may need manual cleanup${NC}"
else
    echo "No Terraform state file found"
fi

# Clean up storage directory
echo "2. Cleaning up storage directory..."
if [ -d "/var/lib/libvirt/images/aap" ]; then
    sudo rm -rf /var/lib/libvirt/images/aap/* 2>/dev/null || echo -e "${RED}Storage directory cleanup may require manual intervention${NC}"
    echo -e "${GREEN}Storage directory cleaned${NC}"
else
    echo "Storage directory doesn't exist"
fi

# Clean up any running VMs
echo "3. Cleaning up any running VMs..."
for vm in aap-controller aap-hub aap-database; do
    if virsh list --all | grep -q "$vm"; then
        echo "  Cleaning up VM: $vm"
        virsh destroy "$vm" 2>/dev/null || true
        virsh undefine "$vm" --remove-all-storage 2>/dev/null || true
    fi
done

# Clean up network
echo "4. Cleaning up network..."
if virsh net-list --all | grep -q "aap-network"; then
    virsh net-destroy aap-network 2>/dev/null || true
    virsh net-undefine aap-network 2>/dev/null || true
    echo -e "${GREEN}Network cleaned up${NC}"
else
    echo "Network not found"
fi

# Clean up storage pool
echo "5. Cleaning up storage pool..."
if virsh pool-list --all | grep -q "aap-pool"; then
    virsh pool-destroy aap-pool 2>/dev/null || true
    virsh pool-undefine aap-pool 2>/dev/null || true
    echo -e "${GREEN}Storage pool cleaned up${NC}"
else
    echo "Storage pool not found"
fi

echo
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  Cleanup completed!                   ${NC}"
echo -e "${GREEN}========================================${NC}"
echo
echo -e "${YELLOW}You can now run ./deploy.sh again${NC}"