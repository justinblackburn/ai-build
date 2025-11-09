# RHEL 9 Vagrant Test Environment

This directory contains a disposable RHEL 9 VM configuration for testing the ai-build playbooks without affecting production systems. The VM automatically registers with Red Hat Subscription Manager and provides a safe sandbox for iterative development.

---

## Prerequisites

### 1. Install VirtualBox

Download and install VirtualBox for your operating system:

**Windows:**
```powershell
# Download from: https://www.virtualbox.org/wiki/Downloads
# Run the installer: VirtualBox-7.1.x-Win.exe
```

**macOS:**
```bash
# Download from: https://www.virtualbox.org/wiki/Downloads
# Or install via Homebrew:
brew install --cask virtualbox
```

**Linux (Debian/Ubuntu):**
```bash
sudo apt update
sudo apt install -y virtualbox
```

**Linux (RHEL/Fedora):**
```bash
sudo dnf install -y VirtualBox
```

Verify installation:
```bash
VBoxManage --version
```

### 2. Install Vagrant

Download and install Vagrant for your operating system:

**Windows:**
```powershell
# Download from: https://www.vagrantup.com/downloads
# Run the installer: vagrant_x.x.x_windows_amd64.msi
# Restart your terminal after installation
```

**macOS:**
```bash
# Download from: https://www.vagrantup.com/downloads
# Or install via Homebrew:
brew install --cask vagrant
```

**Linux (Debian/Ubuntu):**
```bash
wget -O- https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt update
sudo apt install -y vagrant
```

**Linux (RHEL/Fedora):**
```bash
sudo dnf install -y dnf-plugins-core
sudo dnf config-manager --add-repo https://rpm.releases.hashicorp.com/fedora/hashicorp.repo
sudo dnf install -y vagrant
```

Verify installation:
```bash
vagrant --version
```

### 3. Download VirtualBox Guest Additions ISO

The Vagrantfile expects the VirtualBox Guest Additions ISO to be present at `../../files/VBoxGuestAdditions_7.1.10.iso`.

**Option A: Download Specific Version (7.1.10)**

```bash
# From the repository root
cd files/
wget https://download.virtualbox.org/virtualbox/7.1.10/VBoxGuestAdditions_7.1.10.iso

# Verify the download
ls -lh VBoxGuestAdditions_7.1.10.iso
```

**Option B: Use VirtualBox Installation Directory**

If you have VirtualBox installed, the Guest Additions ISO is typically included:

**Windows:**
```powershell
# Default location:
# C:\Program Files\Oracle\VirtualBox\VBoxGuestAdditions.iso

# Copy to project:
Copy-Item "C:\Program Files\Oracle\VirtualBox\VBoxGuestAdditions.iso" -Destination ..\..\files\VBoxGuestAdditions_7.1.10.iso
```

**macOS:**
```bash
# Default location:
# /Applications/VirtualBox.app/Contents/MacOS/VBoxGuestAdditions.iso

# Copy to project:
cp /Applications/VirtualBox.app/Contents/MacOS/VBoxGuestAdditions.iso ../../files/VBoxGuestAdditions_7.1.10.iso
```

**Linux:**
```bash
# Common locations:
# /usr/share/virtualbox/VBoxGuestAdditions.iso
# /usr/lib/virtualbox/additions/VBoxGuestAdditions.iso

# Copy to project (adjust path as needed):
cp /usr/share/virtualbox/VBoxGuestAdditions.iso ../../files/VBoxGuestAdditions_7.1.10.iso
```

**Option C: Download Latest Version**

Visit [VirtualBox Downloads](https://www.virtualbox.org/wiki/Downloads) and download the Guest Additions ISO matching your VirtualBox version. Place it in `../../files/` and update the Vagrantfile path if necessary.

---

## Configuration

### 1. Copy the Environment Template

```bash
cd vagrant/rhel9
cp .env.example .env
```

### 2. Edit the .env File

Open `.env` and configure your Red Hat Subscription Manager credentials:

```bash
RHSM_ORG=1234567
RHSM_KEY=Your_Activation_Key_Here
```

**Where to find these values:**

1. Log in to [Red Hat Customer Portal](https://access.redhat.com/)
2. Navigate to **Subscription Management** > **Activation Keys**
3. Create a new activation key or use an existing one
4. Note your **Organization ID** and **Activation Key**

**Security Note:** The `.env` file is gitignored to prevent accidental credential commits. Never commit real credentials to version control.

---

## Usage

### Starting the VM

From the `vagrant/rhel9` directory:

```bash
vagrant up
```

This will:
1. Download the RHEL 9 base box (first run only)
2. Create and configure the VM
3. Attach the VirtualBox Guest Additions ISO
4. Register with Red Hat Subscription Manager
5. Update packages
6. Install Ansible and Git
7. Mount shared folders

### SSH into the VM

```bash
vagrant ssh
```

### Running Playbooks Inside the VM

Once inside the VM, the Ansible playbooks are available at `/mnt/ansible`:

```bash
# Inside the VM
cd /mnt/ansible
ansible-playbook playbooks/base.yml --ask-become-pass
```

**Note:** GPU-related playbooks (`nvidia.yml`) automatically skip in Vagrant environments since the VM doesn't have GPU passthrough configured.

### Stopping the VM

```bash
vagrant halt
```

### Destroying the VM

To completely remove the VM and start fresh:

```bash
vagrant destroy -f
```

### Reloading After Configuration Changes

If you modify the Vagrantfile:

```bash
vagrant reload
```

To re-run provisioning scripts:

```bash
vagrant reload --provision
```

---

## VM Configuration

The Vagrantfile configures the following:

| Setting | Value | Description |
| --- | --- | --- |
| **Box** | `generic/rhel9` | Official RHEL 9 base image |
| **Hostname** | `rhel9-vagrant` | VM hostname |
| **Memory** | 4096 MB | RAM allocation |
| **CPUs** | 2 | Virtual CPU cores |
| **Port Forwarding** | 7860 (host) → 7860 (guest) | For Stable Diffusion WebUI access |

### Shared Folders

| Host Path | Guest Path | Purpose |
| --- | --- | --- |
| `vagrant/rhel9` | `/vagrant` | Vagrantfile directory (rsync) |
| `vagrant/shared` | `/mnt/shared` | Additional shared files |
| `ansible/` | `/mnt/ansible` | Playbook access |

---

## Troubleshooting

### Guest Additions ISO Not Found

**Error:**
```
The guest additions on this VM do not match the installed version of VirtualBox!
```

**Solution:**
1. Ensure the ISO exists at `../../files/VBoxGuestAdditions_7.1.10.iso`
2. Verify the version matches your VirtualBox installation
3. Update the Vagrantfile path if using a different version

### Subscription Registration Fails

**Error:**
```
Registration failed
```

**Solution:**
1. Verify your `.env` file contains correct RHSM credentials
2. Check your activation key has available subscriptions
3. Test credentials manually:
   ```bash
   vagrant ssh
   sudo subscription-manager register --org=YOUR_ORG --activationkey=YOUR_KEY
   ```

### Shared Folder Mount Errors

**Error:**
```
Failed to mount folders in Linux guest
```

**Solution:**
1. Ensure VirtualBox Guest Additions are properly installed
2. Manually install inside the VM:
   ```bash
   vagrant ssh
   sudo mount /dev/cdrom /mnt
   sudo /mnt/VBoxLinuxAdditions.run
   ```
3. Reload the VM:
   ```bash
   vagrant reload
   ```

### VM Won't Start

**Error:**
```
VBoxManage: error: Could not find a registered machine named 'rhel9-vagrant'
```

**Solution:**
1. Remove stale Vagrant state:
   ```bash
   rm -rf .vagrant/
   vagrant up
   ```
2. Check VirtualBox VM list:
   ```bash
   VBoxManage list vms
   ```

### Port Already in Use

**Error:**
```
Vagrant cannot forward the specified ports on this VM, since they would collide with some other application
```

**Solution:**
1. Stop any applications using port 7860
2. Or modify the Vagrantfile to use a different port:
   ```ruby
   config.vm.network "forwarded_port", guest: 7860, host: 7861
   ```

---

## Testing Workflow

Typical development cycle for testing playbooks:

1. **Make changes** to playbooks or roles in the main repository
2. **SSH into VM:**
   ```bash
   vagrant ssh
   ```
3. **Run specific playbook:**
   ```bash
   cd /mnt/ansible
   ansible-playbook playbooks/base.yml --ask-become-pass
   ```
4. **Verify results** and check for errors
5. **Iterate** on playbook changes
6. **Destroy and recreate** for clean-slate testing:
   ```bash
   exit
   vagrant destroy -f
   vagrant up
   ```

---

## Performance Tips

- **Increase Resources:** Edit the Vagrantfile to allocate more memory/CPUs if needed:
  ```ruby
  vb.memory = 8192
  vb.cpus = 4
  ```

- **Use rsync for Better Performance:** Already configured for the main synced folder to avoid VirtualBox shared folder overhead

- **Snapshot for Quick Recovery:**
  ```bash
  vagrant snapshot save clean-state
  vagrant snapshot restore clean-state
  ```

---

## Next Steps

After verifying playbooks work in the Vagrant environment:

1. Apply changes to production systems
2. Update documentation based on testing results
3. Commit tested playbook changes to the repository

For production deployment instructions, see the main [README.md](../../README.md) at the repository root.
