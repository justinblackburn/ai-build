#!/bin/bash
# prep-setup.sh - AI Build Repository Setup Script
# This script prepares the ai-build repository for deployment by copying
# example files, prompting for configuration, and installing dependencies.

set -euo pipefail

# Color output for better readability
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

echo_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

echo_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

echo_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

echo ""
echo "======================================================================"
echo "  AI Build Repository Setup Script"
echo "======================================================================"
echo ""

# Check if we're in the right directory
if [[ ! -f "README.md" ]] || [[ ! -d "ansible" ]]; then
    echo_error "This script must be run from the ai-build repository root!"
    echo_info "Current directory: $(pwd)"
    exit 1
fi

echo_info "Repository root detected: $(pwd)"
echo ""

# Step 1: Copy example configuration files
echo "----------------------------------------------------------------------"
echo "Step 1: Copying Example Configuration Files"
echo "----------------------------------------------------------------------"

if [[ ! -f ".env" ]]; then
    echo_info "Copying .env.example to .env..."
    cp .env.example .env
    echo_success ".env created"
else
    echo_warning ".env already exists, skipping..."
fi

if [[ ! -f "ansible/ansible.cfg" ]]; then
    echo_info "Copying ansible.conf.example to ansible.cfg..."
    cp ansible/ansible.conf.example ansible/ansible.cfg
    echo_success "ansible.cfg created"
else
    echo_warning "ansible/ansible.cfg already exists, skipping..."
fi

if [[ ! -f "ansible/.vault_pass.txt" ]]; then
    echo_info "Copying .vault_pass.txt.example to .vault_pass.txt..."
    cp ansible/.vault_pass.txt.example ansible/.vault_pass.txt
    echo_success ".vault_pass.txt created"
else
    echo_warning "ansible/.vault_pass.txt already exists, skipping..."
fi

if [[ ! -d "ansible/inventory" ]]; then
    echo_info "Copying inventory.example to inventory..."
    cp -R ansible/inventory.example ansible/inventory
    echo_success "ansible/inventory created"
else
    echo_warning "ansible/inventory already exists, skipping..."
fi

echo ""

# Step 2: Configure RHSM credentials
echo "----------------------------------------------------------------------"
echo "Step 2: Red Hat Subscription Manager Configuration"
echo "----------------------------------------------------------------------"
echo_info "You need your Red Hat Subscription Manager credentials."
echo_info "Find them at: https://access.redhat.com/ > Subscription Management > Activation Keys"
echo ""

read -p "Do you want to configure RHSM credentials now? [y/N]: " configure_rhsm
if [[ "${configure_rhsm,,}" == "y" ]]; then
    read -p "Enter your RHSM Organization ID: " rhsm_org
    read -p "Enter your RHSM Activation Key: " rhsm_key

    if [[ -n "${rhsm_org}" ]] && [[ -n "${rhsm_key}" ]]; then
        echo_info "Updating ansible/inventory/group_vars/all.yml..."

        # Update the inventory file
        sed -i "s/rhsm_org: .*/rhsm_org: \"${rhsm_org}\"/" ansible/inventory/group_vars/all.yml
        sed -i "s/rhsm_key: .*/rhsm_key: \"${rhsm_key}\"/" ansible/inventory/group_vars/all.yml

        echo_success "RHSM credentials configured in inventory"
    else
        echo_warning "Skipping RHSM configuration (empty values provided)"
        echo_info "You can manually edit: ansible/inventory/group_vars/all.yml"
    fi
else
    echo_warning "Skipping RHSM configuration"
    echo_info "Remember to edit: ansible/inventory/group_vars/all.yml"
fi

echo ""

# Step 3: Generate secure vault password
echo "----------------------------------------------------------------------"
echo "Step 3: Vault Password Configuration"
echo "----------------------------------------------------------------------"

vault_current=$(cat ansible/.vault_pass.txt)
if [[ "${vault_current}" == "your-vault-password-here" ]]; then
    echo_warning "Vault password is still using the example value!"
    read -p "Generate a secure random vault password? [Y/n]: " generate_vault

    if [[ "${generate_vault,,}" != "n" ]]; then
        new_vault_pass=$(openssl rand -base64 32)
        echo "${new_vault_pass}" > ansible/.vault_pass.txt
        chmod 600 ansible/.vault_pass.txt
        echo_success "Generated new vault password and saved to ansible/.vault_pass.txt"
        echo_warning "IMPORTANT: Backup this password securely!"
    else
        echo_warning "Remember to manually update: ansible/.vault_pass.txt"
    fi
else
    echo_success "Vault password appears to be configured"
fi

echo ""

# Step 4: Install system dependencies
echo "----------------------------------------------------------------------"
echo "Step 4: System Dependencies"
echo "----------------------------------------------------------------------"

read -p "Install Ansible and Git (requires sudo)? [y/N]: " install_deps
if [[ "${install_deps,,}" == "y" ]]; then
    echo_info "Detecting package manager..."

    if command -v dnf &> /dev/null; then
        echo_info "Using dnf package manager..."
        sudo dnf install -y ansible-core git
        echo_success "Installed ansible-core and git"
    elif command -v apt &> /dev/null; then
        echo_info "Using apt package manager..."
        sudo apt update
        sudo apt install -y ansible git
        echo_success "Installed ansible and git"
    else
        echo_error "Could not detect package manager (dnf/apt)"
        echo_info "Please install ansible-core and git manually"
    fi
else
    echo_warning "Skipping system dependencies installation"
    echo_info "Make sure ansible-core and git are installed"
fi

echo ""

# Step 5: Install Ansible Galaxy collections
echo "----------------------------------------------------------------------"
echo "Step 5: Ansible Galaxy Collections"
echo "----------------------------------------------------------------------"

if command -v ansible-galaxy &> /dev/null; then
    read -p "Install required Ansible Galaxy collections? [Y/n]: " install_galaxy

    if [[ "${install_galaxy,,}" != "n" ]]; then
        echo_info "Installing containers.podman collection..."
        ansible-galaxy collection install -r ansible/requirements.yml
        echo_success "Ansible Galaxy collections installed"
    else
        echo_warning "Skipping Galaxy collections installation"
        echo_info "Run manually: ansible-galaxy collection install -r ansible/requirements.yml"
    fi
else
    echo_warning "ansible-galaxy command not found, skipping collection installation"
    echo_info "Install Ansible first, then run: ansible-galaxy collection install -r ansible/requirements.yml"
fi

echo ""

# Step 6: VirtualBox Guest Additions ISO check
echo "----------------------------------------------------------------------"
echo "Step 6: VirtualBox Guest Additions ISO (for Vagrant)"
echo "----------------------------------------------------------------------"

if [[ -f "files/VBoxGuestAdditions_7.1.10.iso" ]]; then
    echo_success "VBoxGuestAdditions ISO found at: files/VBoxGuestAdditions_7.1.10.iso"
else
    echo_warning "VBoxGuestAdditions ISO not found!"
    echo_info "If you plan to use Vagrant for testing, download the ISO:"
    echo_info "  wget -O files/VBoxGuestAdditions_7.1.10.iso https://download.virtualbox.org/virtualbox/7.1.10/VBoxGuestAdditions_7.1.10.iso"
    echo_info "Or copy from your VirtualBox installation directory"
fi

echo ""

# Step 7: Environment setup
echo "----------------------------------------------------------------------"
echo "Step 7: Environment Variables"
echo "----------------------------------------------------------------------"

echo_info "To use Ansible with this repository, load the environment:"
echo ""
echo "    source .env"
echo ""
echo_info "This exports ANSIBLE_CONFIG, ANSIBLE_INVENTORY, and other variables."

echo ""

# Step 8: Summary and next steps
echo "======================================================================"
echo "  Setup Complete!"
echo "======================================================================"
echo ""
echo_success "Configuration files have been created and initialized."
echo ""
echo "Next Steps:"
echo ""
echo "  1. Review and customize your configuration:"
echo "     - ansible/inventory/group_vars/all.yml (RHSM, paths, users)"
echo "     - .env (environment variables)"
echo ""
echo "  2. Load the environment:"
echo "     source .env"
echo ""
echo "  3. Test the configuration:"
echo "     ansible all -m ping"
echo ""
echo "  4. Run the base playbook:"
echo "     ansible-playbook playbooks/base.yml --ask-become-pass"
echo ""
echo "  5. Or run the full installation:"
echo "     ansible-playbook playbooks/install.yml --ask-become-pass"
echo ""
echo "  6. For Vagrant testing:"
echo "     cd vagrant/rhel9"
echo "     cp .env.example .env"
echo "     # Edit .env with RHSM credentials"
echo "     vagrant up"
echo ""
echo "Documentation:"
echo "  - Main README:    README.md"
echo "  - Vagrant Setup:  vagrant/rhel9/README.md"
echo "  - RAG Stack:      ansible/playbooks/README.md"
echo ""
echo "======================================================================"
echo ""

# Create a verification checklist
echo "Verification Checklist:"
echo ""
echo "  [ ] .env configured"
echo "  [ ] ansible/ansible.cfg exists"
echo "  [ ] ansible/.vault_pass.txt secured (not using example password)"
echo "  [ ] ansible/inventory configured with RHSM credentials"
echo "  [ ] Ansible and Git installed"
echo "  [ ] Ansible Galaxy collections installed (containers.podman)"
echo "  [ ] Environment loaded (source .env)"
echo ""
echo "======================================================================"
