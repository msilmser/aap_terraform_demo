#!/bin/bash

# Automated AAP Demo Environment Setup
# This script installs all prerequisites and sets up the environment
# Run with: sudo ./setup.sh

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Get the actual user (not root) if running with sudo
if [ "$SUDO_USER" ]; then
    ACTUAL_USER="$SUDO_USER"
    USER_HOME="/home/$SUDO_USER"
else
    ACTUAL_USER="$USER"
    USER_HOME="$HOME"
fi

# Store the initial working directory
INITIAL_DIR="$(pwd)"

print_header() {
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}  AAP Demo Environment Setup Script    ${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo
}

print_step() {
    echo -e "${BLUE}[STEP] $1${NC}"
}

print_success() {
    echo -e "${GREEN}✓ SUCCESS: $1${NC}"
}

print_error() {
    echo -e "${RED}✗ ERROR: $1${NC}"
}

print_info() {
    echo -e "${YELLOW}ℹ INFO: $1${NC}"
}

# Check if running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        print_error "This script must be run as root (use sudo)"
        exit 1
    fi
}

# Detect OS and set package manager
detect_os() {
    print_step "Detecting operating system"
    
    if [ -f /etc/redhat-release ]; then
        OS="redhat"
        PKG_MANAGER="yum"
        print_success "Red Hat/CentOS/Fedora detected"
    elif [ -f /etc/debian_version ]; then
        OS="debian"
        PKG_MANAGER="apt"
        print_success "Debian/Ubuntu detected"
    else
        print_error "Unsupported operating system"
        exit 1
    fi
}

# Update system packages
update_system() {
    print_step "Updating system packages"
    
    if [ "$OS" = "redhat" ]; then
        yum update -y
        # Try different methods to install EPEL based on system version
        if ! yum install -y epel-release; then
            # For RHEL/Rocky/AlmaLinux 9+
            yum install -y https://dl.fedoraproject.org/pub/epel/epel-release-latest-9.noarch.rpm 2>/dev/null || \
            yum install -y https://dl.fedoraproject.org/pub/epel/epel-release-latest-8.noarch.rpm 2>/dev/null || \
            dnf install -y epel-release 2>/dev/null || true
        fi
    elif [ "$OS" = "debian" ]; then
        apt update -y
        apt upgrade -y
    fi
    
    print_success "System packages updated"
}

# Install base packages
install_base_packages() {
    print_step "Installing base packages"
    
    if [ "$OS" = "redhat" ]; then
        yum install -y \
            curl \
            wget \
            git \
            vim \
            python3 \
            python3-pip \
            unzip \
            tar \
            gzip \
            net-tools \
            firewalld
    elif [ "$OS" = "debian" ]; then
        apt install -y \
            curl \
            wget \
            git \
            vim \
            python3 \
            python3-pip \
            unzip \
            tar \
            gzip \
            net-tools \
            ufw
    fi
    
    print_success "Base packages installed"
}

# Install KVM/libvirt
install_kvm_libvirt() {
    print_step "Installing KVM and libvirt"
    
    if [ "$OS" = "redhat" ]; then
        yum install -y \
            qemu-kvm \
            libvirt \
            libvirt-daemon \
            libvirt-daemon-driver-qemu \
            libvirt-daemon-kvm \
            bridge-utils \
            virt-manager \
            virt-install
            
        systemctl enable --now libvirtd 2>/dev/null || echo "Systemd not available (WSL2 environment)"
        
    elif [ "$OS" = "debian" ]; then
        apt install -y \
            qemu-kvm \
            libvirt-daemon-system \
            libvirt-daemon-kvm \
            bridge-utils \
            virt-manager \
            virt-install
            
        systemctl enable --now libvirtd 2>/dev/null || echo "Systemd not available (WSL2 environment)"
    fi
    
    # Add user to libvirt group
    usermod -a -G libvirt "$ACTUAL_USER"
    
    print_success "KVM and libvirt installed"
}

# Install Terraform
install_terraform() {
    print_step "Installing Terraform"
    
    # Download and install Terraform
    TERRAFORM_VERSION="1.6.6"
    cd /tmp
    
    if [ ! -f "/usr/local/bin/terraform" ]; then
        wget "https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_linux_amd64.zip"
        unzip "terraform_${TERRAFORM_VERSION}_linux_amd64.zip"
        mv terraform /usr/local/bin/
        chmod +x /usr/local/bin/terraform
        rm -f "terraform_${TERRAFORM_VERSION}_linux_amd64.zip"
    fi
    
    print_success "Terraform installed"
}

# Install Ansible
install_ansible() {
    print_step "Installing Ansible"
    
    # Install Ansible via pip3
    pip3 install ansible
    
    # Create symlinks for global access
    ln -sf /usr/local/bin/ansible /usr/bin/ansible 2>/dev/null || true
    ln -sf /usr/local/bin/ansible-playbook /usr/bin/ansible-playbook 2>/dev/null || true
    
    print_success "Ansible installed"
}

# Install Python dependencies
install_python_deps() {
    print_step "Installing Python dependencies"
    
    pip3 install \
        requests \
        urllib3 \
        psycopg2-binary \
        libvirt-python
    
    print_success "Python dependencies installed"
}

# Generate SSH key
generate_ssh_key() {
    print_step "Generating SSH key"
    
    if [ ! -f "$USER_HOME/.ssh/id_rsa" ]; then
        sudo -u "$ACTUAL_USER" ssh-keygen -t rsa -b 4096 -f "$USER_HOME/.ssh/id_rsa" -N ""
        chmod 600 "$USER_HOME/.ssh/id_rsa"
        chmod 644 "$USER_HOME/.ssh/id_rsa.pub"
        chown "$ACTUAL_USER:$ACTUAL_USER" "$USER_HOME/.ssh/id_rsa" "$USER_HOME/.ssh/id_rsa.pub"
        print_success "SSH key generated"
    else
        print_info "SSH key already exists"
    fi
}

# Configure firewall
configure_firewall() {
    print_step "Configuring firewall"
    
    # Check if we're in WSL2 environment
    if grep -qi microsoft /proc/version 2>/dev/null; then
        print_info "WSL2 environment detected - skipping firewall configuration"
        return 0
    fi
    
    if [ "$OS" = "redhat" ]; then
        if systemctl enable --now firewalld 2>/dev/null; then
            firewall-cmd --permanent --add-service=ssh
            firewall-cmd --permanent --add-service=http
            firewall-cmd --permanent --add-service=https
            firewall-cmd --permanent --add-port=5432/tcp
            firewall-cmd --reload
        else
            print_info "Firewalld not available - skipping firewall configuration"
            return 0
        fi
    elif [ "$OS" = "debian" ]; then
        ufw --force enable
        ufw allow ssh
        ufw allow http
        ufw allow https
        ufw allow 5432/tcp
    fi
    
    print_success "Firewall configured"
}

# Create libvirt storage directory and pool
create_storage() {
    print_step "Creating libvirt storage directory and pool"
    
    mkdir -p /var/lib/libvirt/images/aap
    chown -R qemu:qemu /var/lib/libvirt/images/aap
    
    # Create the storage pool if it doesn't exist
    if ! virsh pool-info aap-pool >/dev/null 2>&1; then
        virsh pool-define-as aap-pool dir --target /var/lib/libvirt/images/aap
        virsh pool-start aap-pool
        virsh pool-autostart aap-pool
        print_success "Storage pool 'aap-pool' created and started"
    else
        print_info "Storage pool 'aap-pool' already exists"
    fi
    
    print_success "Storage directory and pool configured"
}

# Initialize Terraform
init_terraform() {
    print_step "Initializing Terraform"
    
    if [ -d "$INITIAL_DIR/terraform" ]; then
        cd "$INITIAL_DIR/terraform"
        sudo -u "$ACTUAL_USER" terraform init
        print_success "Terraform initialized"
    else
        print_error "Terraform directory not found at $INITIAL_DIR/terraform"
        exit 1
    fi
}

# Update cloud-init with actual SSH key
update_cloud_init() {
    print_step "Updating cloud-init configuration with SSH key"
    
    if [ -f "$USER_HOME/.ssh/id_rsa.pub" ]; then
        SSH_KEY=$(cat "$USER_HOME/.ssh/id_rsa.pub")
        
        # Update all cloud-init files
        for file in "$INITIAL_DIR"/terraform/cloud-init/*-user-data.yaml; do
            if [ -f "$file" ]; then
                sed -i "s|ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQC7.*|$SSH_KEY|g" "$file"
            fi
        done
        
        print_success "Cloud-init configuration updated"
    else
        print_error "SSH key not found"
        exit 1
    fi
}

# Create deployment script
create_deploy_script() {
    print_step "Creating deployment script"
    
    cat > "$INITIAL_DIR/deploy.sh" << 'EOF'
#!/bin/bash

# One-click deployment script
# This script deploys the entire AAP environment

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "Starting AAP deployment..."

# Deploy infrastructure
echo "Deploying VMs with Terraform..."
cd terraform
terraform plan
terraform apply -auto-approve
cd ..

# Wait for VMs to be ready
echo "Waiting for VMs to be ready..."
sleep 60

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
EOF

    chmod +x "$INITIAL_DIR/deploy.sh"
    chown "$ACTUAL_USER:$ACTUAL_USER" "$INITIAL_DIR/deploy.sh"
    
    print_success "Deployment script created"
}

# Main execution
main() {
    print_header
    
    check_root
    detect_os
    update_system
    install_base_packages
    install_kvm_libvirt
    install_terraform
    install_ansible
    install_python_deps
    generate_ssh_key
    configure_firewall
    create_storage
    init_terraform
    update_cloud_init
    create_deploy_script
    
    echo
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}  Setup Complete!                      ${NC}"
    echo -e "${GREEN}========================================${NC}"
    echo
    echo -e "${YELLOW}IMPORTANT: Please log out and log back in to apply group changes${NC}"
    echo
    echo -e "${GREEN}To deploy AAP environment:${NC}"
    echo -e "${GREEN}  ./deploy.sh${NC}"
    echo
    echo -e "${GREEN}To check system status:${NC}"
    echo -e "${GREEN}  sudo systemctl status libvirtd${NC}"
    echo -e "${GREEN}  virsh list --all${NC}"
    echo
}

main "$@"