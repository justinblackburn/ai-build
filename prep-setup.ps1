# prep-setup.ps1 - AI Build Repository Setup Script (Windows PowerShell)
# This script prepares the ai-build repository for deployment by copying
# example files, prompting for configuration, and installing dependencies.

$ErrorActionPreference = "Stop"

function Write-Info {
    param([string]$Message)
    Write-Host "[INFO] " -ForegroundColor Blue -NoNewline
    Write-Host $Message
}

function Write-Success {
    param([string]$Message)
    Write-Host "[SUCCESS] " -ForegroundColor Green -NoNewline
    Write-Host $Message
}

function Write-Warning {
    param([string]$Message)
    Write-Host "[WARNING] " -ForegroundColor Yellow -NoNewline
    Write-Host $Message
}

function Write-Error {
    param([string]$Message)
    Write-Host "[ERROR] " -ForegroundColor Red -NoNewline
    Write-Host $Message
}

Write-Host ""
Write-Host "======================================================================"
Write-Host "  AI Build Repository Setup Script (Windows)"
Write-Host "======================================================================"
Write-Host ""

# Check if we're in the right directory
if (-not (Test-Path "README.md") -or -not (Test-Path "ansible" -PathType Container)) {
    Write-Error "This script must be run from the ai-build repository root!"
    Write-Info "Current directory: $PWD"
    exit 1
}

Write-Info "Repository root detected: $PWD"
Write-Host ""

# Step 1: Copy example configuration files
Write-Host "----------------------------------------------------------------------"
Write-Host "Step 1: Copying Example Configuration Files"
Write-Host "----------------------------------------------------------------------"

if (-not (Test-Path ".env")) {
    Write-Info "Copying .env.example to .env..."
    Copy-Item ".env.example" ".env"
    Write-Success ".env created"
} else {
    Write-Warning ".env already exists, skipping..."
}

if (-not (Test-Path "ansible\ansible.cfg")) {
    Write-Info "Copying ansible.conf.example to ansible.cfg..."
    Copy-Item "ansible\ansible.conf.example" "ansible\ansible.cfg"
    Write-Success "ansible.cfg created"
} else {
    Write-Warning "ansible\ansible.cfg already exists, skipping..."
}

if (-not (Test-Path "ansible\.vault_pass.txt")) {
    Write-Info "Copying .vault_pass.txt.example to .vault_pass.txt..."
    Copy-Item "ansible\.vault_pass.txt.example" "ansible\.vault_pass.txt"
    Write-Success ".vault_pass.txt created"
} else {
    Write-Warning "ansible\.vault_pass.txt already exists, skipping..."
}

if (-not (Test-Path "ansible\inventory" -PathType Container)) {
    Write-Info "Copying inventory.example to inventory..."
    Copy-Item "ansible\inventory.example" "ansible\inventory" -Recurse
    Write-Success "ansible\inventory created"
} else {
    Write-Warning "ansible\inventory already exists, skipping..."
}

Write-Host ""

# Step 2: Configure RHSM credentials
Write-Host "----------------------------------------------------------------------"
Write-Host "Step 2: Red Hat Subscription Manager Configuration"
Write-Host "----------------------------------------------------------------------"
Write-Info "You need your Red Hat Subscription Manager credentials."
Write-Info "Find them at: https://access.redhat.com/ > Subscription Management > Activation Keys"
Write-Host ""

$configureRhsm = Read-Host "Do you want to configure RHSM credentials now? [y/N]"
if ($configureRhsm -eq "y" -or $configureRhsm -eq "Y") {
    $rhsmOrg = Read-Host "Enter your RHSM Organization ID"
    $rhsmKey = Read-Host "Enter your RHSM Activation Key"

    if ($rhsmOrg -and $rhsmKey) {
        Write-Info "Updating ansible\inventory\group_vars\all.yml..."

        $inventoryPath = "ansible\inventory\group_vars\all.yml"
        $content = Get-Content $inventoryPath -Raw
        $content = $content -replace 'rhsm_org: .*', "rhsm_org: `"$rhsmOrg`""
        $content = $content -replace 'rhsm_key: .*', "rhsm_key: `"$rhsmKey`""
        Set-Content $inventoryPath $content

        Write-Success "RHSM credentials configured in inventory"
    } else {
        Write-Warning "Skipping RHSM configuration (empty values provided)"
        Write-Info "You can manually edit: ansible\inventory\group_vars\all.yml"
    }
} else {
    Write-Warning "Skipping RHSM configuration"
    Write-Info "Remember to edit: ansible\inventory\group_vars\all.yml"
}

Write-Host ""

# Step 3: Generate secure vault password
Write-Host "----------------------------------------------------------------------"
Write-Host "Step 3: Vault Password Configuration"
Write-Host "----------------------------------------------------------------------"

$vaultCurrent = Get-Content "ansible\.vault_pass.txt" -Raw
if ($vaultCurrent.Trim() -eq "your-vault-password-here") {
    Write-Warning "Vault password is still using the example value!"
    $generateVault = Read-Host "Generate a secure random vault password? [Y/n]"

    if ($generateVault -ne "n" -and $generateVault -ne "N") {
        # Generate random password using .NET
        $bytes = New-Object byte[] 32
        $rng = [System.Security.Cryptography.RandomNumberGenerator]::Create()
        $rng.GetBytes($bytes)
        $newVaultPass = [Convert]::ToBase64String($bytes)

        Set-Content "ansible\.vault_pass.txt" $newVaultPass
        Write-Success "Generated new vault password and saved to ansible\.vault_pass.txt"
        Write-Warning "IMPORTANT: Backup this password securely!"
    } else {
        Write-Warning "Remember to manually update: ansible\.vault_pass.txt"
    }
} else {
    Write-Success "Vault password appears to be configured"
}

Write-Host ""

# Step 4: Check for WSL/Linux environment
Write-Host "----------------------------------------------------------------------"
Write-Host "Step 4: System Dependencies"
Write-Host "----------------------------------------------------------------------"

Write-Info "Ansible requires a Linux environment to run."
Write-Host ""
Write-Host "Options for Windows users:"
Write-Host "  1. Use WSL2 (Windows Subsystem for Linux) - Recommended"
Write-Host "  2. Use a Linux VM (VirtualBox, VMware, Hyper-V)"
Write-Host "  3. Run Ansible from the target RHEL host directly"
Write-Host ""
Write-Info "To install WSL2:"
Write-Host "  wsl --install"
Write-Host "  Then run this script from within WSL2"
Write-Host ""

# Step 5: Ansible Galaxy collections note
Write-Host "----------------------------------------------------------------------"
Write-Host "Step 5: Ansible Galaxy Collections"
Write-Host "----------------------------------------------------------------------"

Write-Info "After installing Ansible (in WSL/Linux), run:"
Write-Host "  ansible-galaxy collection install -r ansible/requirements.yml"
Write-Host ""

# Step 6: VirtualBox Guest Additions ISO check
Write-Host "----------------------------------------------------------------------"
Write-Host "Step 6: VirtualBox Guest Additions ISO (for Vagrant)"
Write-Host "----------------------------------------------------------------------"

if (Test-Path "files\VBoxGuestAdditions_7.1.10.iso") {
    Write-Success "VBoxGuestAdditions ISO found at: files\VBoxGuestAdditions_7.1.10.iso"
} else {
    Write-Warning "VBoxGuestAdditions ISO not found!"
    Write-Info "If you plan to use Vagrant for testing, you can:"
    Write-Host ""
    Write-Host "  Option 1: Download from VirtualBox website"
    Write-Host "    URL: https://download.virtualbox.org/virtualbox/7.1.10/VBoxGuestAdditions_7.1.10.iso"
    Write-Host "    Save to: files\VBoxGuestAdditions_7.1.10.iso"
    Write-Host ""
    Write-Host "  Option 2: Copy from VirtualBox installation"

    $vboxPath = "C:\Program Files\Oracle\VirtualBox\VBoxGuestAdditions.iso"
    if (Test-Path $vboxPath) {
        Write-Info "Found VirtualBox Guest Additions at: $vboxPath"
        $copyIso = Read-Host "Copy this ISO to files\ directory? [Y/n]"
        if ($copyIso -ne "n" -and $copyIso -ne "N") {
            if (-not (Test-Path "files" -PathType Container)) {
                New-Item -ItemType Directory -Path "files" | Out-Null
            }
            Copy-Item $vboxPath "files\VBoxGuestAdditions_7.1.10.iso"
            Write-Success "Copied VBoxGuestAdditions.iso to files\ directory"
        }
    }
}

Write-Host ""

# Step 7: Vagrant setup
Write-Host "----------------------------------------------------------------------"
Write-Host "Step 7: Vagrant Configuration (Optional)"
Write-Host "----------------------------------------------------------------------"

if (Test-Path "vagrant\rhel9" -PathType Container) {
    if (-not (Test-Path "vagrant\rhel9\.env")) {
        $setupVagrant = Read-Host "Setup Vagrant test environment? [y/N]"
        if ($setupVagrant -eq "y" -or $setupVagrant -eq "Y") {
            Copy-Item "vagrant\rhel9\.env.example" "vagrant\rhel9\.env"
            Write-Success "Created vagrant\rhel9\.env"
            Write-Info "Edit vagrant\rhel9\.env with your RHSM credentials before running 'vagrant up'"
        }
    } else {
        Write-Success "Vagrant environment already configured"
    }
}

Write-Host ""

# Step 8: Summary and next steps
Write-Host "======================================================================"
Write-Host "  Setup Complete!"
Write-Host "======================================================================"
Write-Host ""
Write-Success "Configuration files have been created and initialized."
Write-Host ""
Write-Host "Next Steps:"
Write-Host ""
Write-Host "  FOR WINDOWS USERS (using WSL2):"
Write-Host "  1. Install WSL2 if not already installed:"
Write-Host "     wsl --install"
Write-Host ""
Write-Host "  2. Copy this repository to WSL2:"
Write-Host "     # From WSL2 terminal:"
Write-Host "     cp -r /mnt/c/Users/Justin/github/ai-build ~/"
Write-Host "     cd ~/ai-build"
Write-Host ""
Write-Host "  3. Run prep-setup.sh from WSL2:"
Write-Host "     bash prep-setup.sh"
Write-Host ""
Write-Host "  FOR LINUX USERS:"
Write-Host "  1. Review and customize configuration:"
Write-Host "     - ansible/inventory/group_vars/all.yml"
Write-Host "     - .env"
Write-Host ""
Write-Host "  2. Load the environment:"
Write-Host "     source .env"
Write-Host ""
Write-Host "  3. Run the installation:"
Write-Host "     ansible-playbook playbooks/install.yml --ask-become-pass"
Write-Host ""
Write-Host "  FOR VAGRANT TESTING:"
Write-Host "  1. Install VirtualBox and Vagrant"
Write-Host "  2. Configure vagrant/rhel9/.env with RHSM credentials"
Write-Host "  3. Run: vagrant up (from vagrant/rhel9 directory)"
Write-Host ""
Write-Host "Documentation:"
Write-Host "  - Main README:    README.md"
Write-Host "  - Vagrant Setup:  vagrant\rhel9\README.md"
Write-Host "  - RAG Stack:      ansible\playbooks\README.md"
Write-Host ""
Write-Host "======================================================================"
Write-Host ""

# Create a verification checklist
Write-Host "Verification Checklist:"
Write-Host ""
Write-Host "  [ ] .env configured"
Write-Host "  [ ] ansible\ansible.cfg exists"
Write-Host "  [ ] ansible\.vault_pass.txt secured (not using example password)"
Write-Host "  [ ] ansible\inventory configured with RHSM credentials"
Write-Host "  [ ] Ansible environment ready (WSL2/Linux/Target host)"
Write-Host "  [ ] Ansible Galaxy collections installed (containers.podman)"
Write-Host ""
Write-Host "======================================================================"
