#!/bin/bash

# Prerequisites Check Script
# This script verifies all required dependencies are installed and configured

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Counters
PASSED=0
FAILED=0
WARNINGS=0

# Helper functions
print_header() {
    echo -e "${BLUE}================================${NC}"
    echo -e "${BLUE}  AAP Demo Prerequisites Check  ${NC}"
    echo -e "${BLUE}================================${NC}"
    echo
}

print_check() {
    echo -e "${BLUE}Checking: $1${NC}"
}

print_pass() {
    echo -e "${GREEN}✓ PASS:${NC} $1"
    ((PASSED++))
}

print_fail() {
    echo -e "${RED}✗ FAIL:${NC} $1"
    ((FAILED++))
}

print_warn() {
    echo -e "${YELLOW}⚠ WARN:${NC} $1"
    ((WARNINGS++))
}

print_info() {
    echo -e "  ℹ INFO: $1"
}

print_summary() {
    echo
    echo -e "${BLUE}================================${NC}"
    echo -e "${BLUE}         Summary Results         ${NC}"
    echo -e "${BLUE}================================${NC}"
    echo -e "${GREEN}Passed: $PASSED${NC}"
    echo -e "${RED}Failed: $FAILED${NC}"
    echo -e "${YELLOW}Warnings: $WARNINGS${NC}"
    echo
    
    if [ $FAILED -eq 0 ]; then
        echo -e "${GREEN}🎉 All prerequisites are satisfied!${NC}"
        echo -e "${GREEN}You can proceed with the AAP deployment.${NC}"
    else
        echo -e "${RED}❌ Some prerequisites are missing.${NC}"
        echo -e "${RED}Please install missing components before proceeding.${NC}"
        exit 1
    fi
}

# Check operating system
check_os() {
    print_check "Operating System"
    
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        print_pass "Linux system detected"
        
        # Check for specific distributions
        if [ -f /etc/redhat-release ]; then
            print_info "Red Hat/CentOS/Fedora detected"
        elif [ -f /etc/debian_version ]; then
            print_info "Debian/Ubuntu detected"
        else
            print_warn "Unknown Linux distribution"
        fi
    else
        print_fail "This script requires Linux"
    fi
}

# Check KVM/libvirt support
check_kvm() {
    print_check "KVM Virtualization Support"
    
    if [ -e /dev/kvm ]; then
        print_pass "KVM device available"
    else
        print_fail "KVM device not found - virtualization may not be enabled"
        print_info "Enable virtualization in BIOS/UEFI settings"
    fi
    
    # Check if user is in libvirt group
    if groups | grep -q libvirt; then
        print_pass "User is in libvirt group"
    else
        print_warn "User not in libvirt group - may need sudo for libvirt operations"
        print_info "Add user to libvirt group: sudo usermod -a -G libvirt \$USER"
    fi
}

# Check libvirt service
check_libvirt() {
    print_check "Libvirt Service"
    
    if systemctl is-active --quiet libvirtd; then
        print_pass "Libvirt service is running"
    else
        print_fail "Libvirt service is not running"
        print_info "Start libvirt: sudo systemctl start libvirtd"
        print_info "Enable libvirt: sudo systemctl enable libvirtd"
    fi
    
    # Check if we can connect to libvirt
    if virsh --connect qemu:///system list > /dev/null 2>&1; then
        print_pass "Can connect to libvirt system"
    else
        print_fail "Cannot connect to libvirt system"
        print_info "Check libvirt permissions and service status"
    fi
}

# Check Terraform
check_terraform() {
    print_check "Terraform"
    
    if command -v terraform &> /dev/null; then
        TERRAFORM_VERSION=$(terraform version | head -n1 | grep -o 'v[0-9]\+\.[0-9]\+\.[0-9]\+')
        print_pass "Terraform found - version $TERRAFORM_VERSION"
        
        # Check minimum version (1.0.0+)
        if [[ "$TERRAFORM_VERSION" < "v1.0.0" ]]; then
            print_warn "Terraform version is older than 1.0.0"
        fi
    else
        print_fail "Terraform not found"
        print_info "Install Terraform: https://www.terraform.io/downloads.html"
    fi
}

# Check Ansible
check_ansible() {
    print_check "Ansible"
    
    if command -v ansible &> /dev/null; then
        ANSIBLE_VERSION=$(ansible --version | head -n1 | grep -o '[0-9]\+\.[0-9]\+\.[0-9]\+')
        print_pass "Ansible found - version $ANSIBLE_VERSION"
        
        # Check ansible-playbook
        if command -v ansible-playbook &> /dev/null; then
            print_pass "ansible-playbook available"
        else
            print_fail "ansible-playbook not found"
        fi
    else
        print_fail "Ansible not found"
        print_info "Install Ansible: pip3 install ansible"
    fi
}

# Check Python dependencies
check_python() {
    print_check "Python Dependencies"
    
    if command -v python3 &> /dev/null; then
        PYTHON_VERSION=$(python3 --version | grep -o '[0-9]\+\.[0-9]\+\.[0-9]\+')
        print_pass "Python3 found - version $PYTHON_VERSION"
    else
        print_fail "Python3 not found"
        print_info "Install Python3: sudo apt install python3 (Ubuntu/Debian)"
    fi
    
    # Check pip3
    if command -v pip3 &> /dev/null; then
        print_pass "pip3 available"
    else
        print_fail "pip3 not found"
        print_info "Install pip3: sudo apt install python3-pip"
    fi
    
    # Check required Python packages
    for package in requests urllib3 psycopg2-binary; do
        if python3 -c "import ${package//-/_}" &> /dev/null; then
            print_pass "Python package '$package' available"
        else
            print_warn "Python package '$package' not found"
            print_info "Install with: pip3 install $package"
        fi
    done
}

# Check SSH key
check_ssh() {
    print_check "SSH Key Pair"
    
    if [ -f ~/.ssh/id_rsa ]; then
        print_pass "SSH private key found"
    else
        print_fail "SSH private key not found at ~/.ssh/id_rsa"
        print_info "Generate SSH key: ssh-keygen -t rsa -b 4096"
    fi
    
    if [ -f ~/.ssh/id_rsa.pub ]; then
        print_pass "SSH public key found"
    else
        print_fail "SSH public key not found at ~/.ssh/id_rsa.pub"
        print_info "Generate SSH key: ssh-keygen -t rsa -b 4096"
    fi
    
    # Check SSH key permissions
    if [ -f ~/.ssh/id_rsa ]; then
        PERMS=$(stat -c "%a" ~/.ssh/id_rsa)
        if [ "$PERMS" = "600" ]; then
            print_pass "SSH private key permissions correct (600)"
        else
            print_warn "SSH private key permissions should be 600"
            print_info "Fix permissions: chmod 600 ~/.ssh/id_rsa"
        fi
    fi
}

# Check available disk space
check_disk_space() {
    print_check "Disk Space"
    
    # Check /var/lib/libvirt/images (default libvirt storage)
    if [ -d /var/lib/libvirt/images ]; then
        AVAILABLE=$(df -BG /var/lib/libvirt/images | tail -n1 | awk '{print $4}' | sed 's/G//')
        if [ "$AVAILABLE" -ge 50 ]; then
            print_pass "Sufficient disk space available (${AVAILABLE}GB)"
        else
            print_warn "Low disk space in /var/lib/libvirt/images (${AVAILABLE}GB)"
            print_info "AAP deployment needs ~30GB for VM images"
        fi
    else
        print_warn "Libvirt images directory not found"
        print_info "Will be created during deployment"
    fi
}

# Check memory
check_memory() {
    print_check "System Memory"
    
    TOTAL_MEM=$(free -g | grep '^Mem:' | awk '{print $2}')
    if [ "$TOTAL_MEM" -ge 12 ]; then
        print_pass "Sufficient memory available (${TOTAL_MEM}GB)"
    else
        print_warn "Low system memory (${TOTAL_MEM}GB)"
        print_info "AAP deployment needs ~10GB RAM for all VMs"
    fi
}

# Check network connectivity
check_network() {
    print_check "Network Connectivity"
    
    if ping -c 1 8.8.8.8 &> /dev/null; then
        print_pass "Internet connectivity available"
    else
        print_fail "No internet connectivity"
        print_info "Internet required for downloading VM images and packages"
    fi
    
    # Check if 192.168.100.0/24 network is available
    if ip route | grep -q "192.168.100"; then
        print_warn "192.168.100.0/24 network already exists"
        print_info "May conflict with AAP network deployment"
    else
        print_pass "192.168.100.0/24 network available"
    fi
}

# Check Red Hat subscription
check_rh_subscription() {
    print_check "Red Hat Subscription"
    
    print_warn "Red Hat subscription check requires manual verification"
    print_info "You need a valid Red Hat subscription to download AAP installer"
    print_info "Check your subscription at: https://access.redhat.com/management"
    print_info "AAP installer download: https://access.redhat.com/downloads/content/480"
}

# Check Terraform provider
check_terraform_provider() {
    print_check "Terraform Libvirt Provider"
    
    if [ -f terraform/.terraform.lock.hcl ]; then
        print_pass "Terraform initialized"
    else
        print_warn "Terraform not initialized"
        print_info "Run 'terraform init' in the terraform directory"
    fi
}

# Main execution
main() {
    print_header
    
    check_os
    echo
    
    check_kvm
    echo
    
    check_libvirt
    echo
    
    check_terraform
    echo
    
    check_ansible
    echo
    
    check_python
    echo
    
    check_ssh
    echo
    
    check_disk_space
    echo
    
    check_memory
    echo
    
    check_network
    echo
    
    check_rh_subscription
    echo
    
    check_terraform_provider
    echo
    
    print_summary
}

# Run main function
main