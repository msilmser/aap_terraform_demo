#!/bin/bash

# One-click deployment script
# This script deploys the entire AAP environment

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Cleanup function
cleanup_on_failure() {
    echo -e "${RED}Deployment failed! Cleaning up resources...${NC}"
    
    # Clean up Terraform resources
    cd "$SCRIPT_DIR/terraform"
    if [ -f "terraform.tfstate" ]; then
        echo "Destroying Terraform resources..."
        terraform destroy -auto-approve || echo "Some Terraform resources may need manual cleanup"
    fi
    
    # Clean up storage directory
    echo "Cleaning up storage directory..."
    sudo rm -rf /var/lib/libvirt/images/aap/* 2>/dev/null || echo "Storage directory cleanup may require manual intervention"
    
    # Clean up any running VMs
    echo "Cleaning up any running VMs..."
    for vm in aap-controller aap-hub aap-database; do
        virsh destroy "$vm" 2>/dev/null || true
        virsh undefine "$vm" --remove-all-storage 2>/dev/null || true
    done
    
    # Clean up network
    virsh net-destroy aap-network 2>/dev/null || true
    virsh net-undefine aap-network 2>/dev/null || true
    
    echo -e "${YELLOW}Cleanup completed. You can now retry the deployment.${NC}"
}

# Set trap to call cleanup on script failure
trap cleanup_on_failure ERR

echo "Starting AAP deployment..."

# Deploy infrastructure
echo "Deploying VMs with Terraform..."
cd terraform
terraform plan
terraform apply -auto-approve
cd ..

# Wait for VMs to be ready
echo "Waiting for VMs to be ready..."
echo "VMs are booting and cloud-init is configuring them..."

# Wait for cloud-init to complete (this can take several minutes)
echo "Waiting 3 minutes for cloud-init to complete..."
for i in {1..18}; do
    echo -n "."
    sleep 10
done
echo

# Test connectivity before proceeding
echo "Testing VM connectivity..."
CONTROLLER_READY=false
HUB_READY=false
DATABASE_READY=false

for attempt in {1..12}; do
    echo "Connectivity test attempt $attempt/12..."
    
    if ping -c 1 -W 2 192.168.100.10 >/dev/null 2>&1; then
        echo "  ✓ Controller VM (192.168.100.10) is reachable"
        CONTROLLER_READY=true
    else
        echo "  ✗ Controller VM (192.168.100.10) not reachable"
    fi
    
    if ping -c 1 -W 2 192.168.100.11 >/dev/null 2>&1; then
        echo "  ✓ Hub VM (192.168.100.11) is reachable"  
        HUB_READY=true
    else
        echo "  ✗ Hub VM (192.168.100.11) not reachable"
    fi
    
    if ping -c 1 -W 2 192.168.100.12 >/dev/null 2>&1; then
        echo "  ✓ Database VM (192.168.100.12) is reachable"
        DATABASE_READY=true
    else
        echo "  ✗ Database VM (192.168.100.12) not reachable"
    fi
    
    if $CONTROLLER_READY && $HUB_READY && $DATABASE_READY; then
        echo "All VMs are reachable!"
        break
    fi
    
    if [ $attempt -lt 12 ]; then
        echo "Waiting 30 seconds before next test..."
        sleep 30
    fi
done

if ! ($CONTROLLER_READY && $HUB_READY && $DATABASE_READY); then
    echo -e "${RED}ERROR: Not all VMs are reachable after waiting.${NC}"
    echo "This may be due to WSL2 limitations with nested virtualization."
    echo
    echo "VM Status:"
    virsh -c qemu:///system list --all
    echo
    echo "Network Status:"
    virsh -c qemu:///system net-list --all
    echo
    echo -e "${YELLOW}You may need to:"
    echo "1. Run this on a native Linux system instead of WSL2"
    echo "2. Check if the VMs have console access via 'virsh console <vm-name>'"
    echo "3. Manually verify VM network configuration${NC}"
    exit 1
fi

# Test SSH connectivity
echo "Testing SSH connectivity..."
for vm_ip in 192.168.100.10 192.168.100.11 192.168.100.12; do
    if nc -z -w5 $vm_ip 22 2>/dev/null; then
        echo "  ✓ SSH port open on $vm_ip"
    else
        echo "  ✗ SSH port not open on $vm_ip - waiting longer..."
        sleep 30
        if nc -z -w5 $vm_ip 22 2>/dev/null; then
            echo "  ✓ SSH port now open on $vm_ip"
        else
            echo -e "${YELLOW}  ! SSH port still not open on $vm_ip - continuing anyway${NC}"
        fi
    fi
done

# Configure systems
echo "Configuring systems with Ansible..."
cd ansible
ansible-playbook -i inventory/hosts.yml playbooks/site.yml
cd ..

echo "Infrastructure deployment completed!"
echo ""
echo "Next steps:"
echo "1. Download AAP installer from Red Hat and run: sudo installer/setup.sh"
echo "2. After AAP installation, run: installer/post-install.sh"
echo "3. Run demo job template: scripts/run-demo.sh"
echo ""
echo "AAP Controller will be available at: https://192.168.100.10"
echo "Username: admin"
echo "Password: admin123"
