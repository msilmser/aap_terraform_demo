# Ansible Automation Platform Demo Environment

This repository contains everything needed to deploy a complete Ansible Automation Platform (AAP) environment using Terraform and Ansible, including scripts to run demo job templates without UI interaction.

## Architecture

The deployment creates:
- **AAP Controller** (192.168.100.10) - Main automation controller
- **AAP Hub** (192.168.100.11) - Private automation hub
- **Database Server** (192.168.100.12) - PostgreSQL database

## Prerequisites

**NONE!** This project automatically installs everything you need.

### WSL2 Users

If running on WSL2, enable systemd support:

1. Create `/etc/wsl.conf`:
   ```bash
   sudo nano /etc/wsl.conf
   ```

2. Add this content:
   ```ini
   [boot]
   systemd=true
   ```

3. Restart WSL2 from Windows PowerShell/CMD:
   ```cmd
   wsl --shutdown
   wsl
   ```

4. Verify systemd is running:
   ```bash
   systemctl --version
   ```

## Quick Start

**For users with zero experience - just run these two commands:**

```bash
# 1. Run automated setup (installs all prerequisites)
sudo ./setup.sh

# 2. Deploy the entire environment
./deploy.sh
```

**That's it!** The setup script will automatically install:
- KVM/libvirt virtualization
- Terraform
- Ansible
- Python dependencies
- SSH keys
- Firewall configuration

## Manual Steps (Advanced Users)

### 1. Deploy Infrastructure

```bash
# Initialize Terraform
cd terraform
terraform init

# Deploy VMs
terraform plan
terraform apply
```

### 2. Configure Systems

```bash
# Run system configuration playbook
cd ../ansible
ansible-playbook -i inventory/hosts.yml playbooks/site.yml
```

### 3. Install AAP

```bash
# Download AAP installer bundle manually from Red Hat
# Place in /tmp/aap-installer/
cd ../installer
sudo ./setup.sh

# Follow instructions to download AAP bundle
# Then run the installer
```

### 4. Post-Installation Setup

```bash
# Configure AAP and create demo resources
./post-install.sh
```

### 5. Run Demo Job Template

```bash
# Launch demo job template via API
cd ../scripts
./run-demo.sh
```

## Directory Structure

```
├── terraform/           # VM deployment configuration
│   ├── main.tf         # Main Terraform configuration
│   ├── outputs.tf      # Output values
│   └── cloud-init/     # Cloud-init configuration files
├── ansible/            # Ansible playbooks and inventory
│   ├── inventory/      # Inventory files
│   └── playbooks/      # Configuration playbooks
├── installer/          # AAP installation scripts
│   ├── setup.sh        # AAP installer setup
│   └── post-install.sh # Post-installation configuration
├── scripts/            # API automation scripts
│   ├── aap-api.py      # Python API client
│   └── run-demo.sh     # Demo job launcher
└── README.md           # This file
```

## Usage Examples

### API Client Usage

```bash
# List all job templates
python3 scripts/aap-api.py --action list

# Launch a job template
python3 scripts/aap-api.py --action launch --template-id 1 --wait

# Check job status
python3 scripts/aap-api.py --action status --job-id 1

# Get job output
python3 scripts/aap-api.py --action output --job-id 1

# Launch with extra variables
python3 scripts/aap-api.py --action launch --template-id 1 --extra-vars '{"variable": "value"}'
```

### Manual Testing

```bash
# Test VM connectivity
ansible all -i ansible/inventory/hosts.yml -m ping

# Access AAP Controller UI
https://192.168.100.10
Username: admin
Password: admin123
```

## Network Configuration

- **Network**: 192.168.100.0/24
- **Gateway**: 192.168.100.1
- **DNS**: Configured for .aap.local domain
- **Firewall**: Configured for SSH, HTTP, HTTPS access

## Security Notes

- SSH keys are used for authentication
- Default passwords are set for demo purposes
- SSL certificates are self-signed
- Firewall rules allow necessary ports only

## Troubleshooting

### Common Issues

1. **VMs not starting**: Check libvirt service status
2. **SSH connection failed**: Verify SSH key permissions
3. **AAP installation failed**: Check Red Hat subscription status
4. **API calls failing**: Verify AAP controller is running

### Useful Commands

```bash
# Check VM status
virsh list --all

# Check network connectivity
ping 192.168.100.10

# Check AAP services
systemctl status automation-controller

# View logs
journalctl -u automation-controller
```

## Cleanup

```bash
# Destroy infrastructure
cd terraform
terraform destroy

# Remove libvirt storage
sudo virsh pool-destroy aap-pool
sudo virsh pool-undefine aap-pool
```

## Support

For issues with:
- **Terraform**: Check libvirt provider documentation
- **Ansible**: Refer to Ansible documentation
- **AAP**: Consult Red Hat AAP documentation

## License

This demo environment is provided as-is for educational purposes.