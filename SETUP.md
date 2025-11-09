# Quick Setup Guide

This guide provides a streamlined setup process for the ai-build repository.

---

## TL;DR - Copy & Paste Commands

### Linux/macOS/WSL

```bash
# Clone and setup
git clone https://github.com/justinblackburn/ai-build.git
cd ai-build
bash prep-setup.sh

# After setup completes, load environment
source .env

# Verify connectivity
ansible all -m ping

# Run installation
ansible-playbook playbooks/install.yml --ask-become-pass
```

### Windows (PowerShell)

```powershell
# Clone repository
git clone https://github.com/justinblackburn/ai-build.git
cd ai-build

# Run setup script
.\prep-setup.ps1

# Note: Ansible requires WSL2/Linux. Follow instructions in script output.
```

---

## Setup Scripts

Two automated setup scripts are provided:

| Script | Platform | Purpose |
|--------|----------|---------|
| `prep-setup.sh` | Linux, macOS, WSL | Full automated setup with dependency installation |
| `prep-setup.ps1` | Windows PowerShell | Configuration setup + WSL2 guidance |

Both scripts perform the following:
1. ✅ Copy example configuration files
2. ✅ Prompt for RHSM credentials (optional)
3. ✅ Generate secure vault password
4. ✅ Install system dependencies (Linux/macOS only)
5. ✅ Install Ansible Galaxy collections
6. ✅ Verify VirtualBox Guest Additions ISO
7. ✅ Provide next steps checklist

---

## Prerequisites

### For Production Deployment

- **Target System**: RHEL 9.x or compatible (Rocky Linux, AlmaLinux)
- **Control Node**: Any system with Ansible 2.14+ (can be the target itself)
- **Red Hat Subscription**: Organization ID and Activation Key
- **Network**: Internet access (or pre-staged wheels for air-gap)

### For Vagrant Testing

- **VirtualBox**: Latest version (7.1.x recommended)
- **Vagrant**: Latest version (2.3.x or newer)
- **VirtualBox Guest Additions ISO**: See [vagrant/rhel9/README.md](vagrant/rhel9/README.md)
- **System Resources**: 4GB RAM, 2 CPU cores minimum for VM

---

## Configuration Files

After running `prep-setup.sh` or `prep-setup.ps1`, edit these files:

### Required Configuration

| File | Purpose | What to Edit |
|------|---------|--------------|
| `ansible/inventory/group_vars/all.yml` | Main inventory variables | `rhsm_org`, `rhsm_key`, paths, users |
| `ansible/.vault_pass.txt` | Vault password (auto-generated) | Backup this file securely |

### Optional Configuration

| File | Purpose | What to Edit |
|------|---------|--------------|
| `.env` | Environment variables | Usually fine as-is |
| `ansible/ansible.cfg` | Ansible configuration | Advanced users only |

---

## Installation Workflow

### 1. Setup Phase (One-time)

```bash
# Run automated setup
bash prep-setup.sh

# OR manually:
cp .env.example .env
cp ansible/ansible.conf.example ansible/ansible.cfg
cp ansible/.vault_pass.txt.example ansible/.vault_pass.txt
cp -R ansible/inventory.example ansible/inventory

# Edit configuration
vim ansible/inventory/group_vars/all.yml  # Set RHSM credentials

# Install Galaxy collections
ansible-galaxy collection install -r ansible/requirements.yml
```

### 2. Deployment Phase

```bash
# Load environment
source .env

# Test connectivity
ansible all -m ping

# Run base configuration
ansible-playbook playbooks/base.yml --ask-become-pass

# Run full installation
ansible-playbook playbooks/install.yml --ask-become-pass

# (Optional) Deploy RAG stack
ansible-playbook playbooks/llm_ingest.yml --ask-become-pass
```

### 3. Vagrant Testing (Optional)

```bash
cd vagrant/rhel9

# Setup Vagrant environment
cp .env.example .env
vim .env  # Add RHSM credentials

# Start VM
vagrant up

# SSH into VM
vagrant ssh

# Run playbooks from VM
cd /mnt/ansible
ansible-playbook playbooks/base.yml --ask-become-pass
```

---

## Common Issues & Solutions

### Issue: "ansible: command not found"

**Solution:**
```bash
# RHEL/Fedora/Rocky
sudo dnf install -y ansible-core

# Debian/Ubuntu
sudo apt install -y ansible

# macOS
brew install ansible
```

### Issue: "containers.podman collection not found"

**Solution:**
```bash
ansible-galaxy collection install -r ansible/requirements.yml
```

### Issue: "pip 25.3 dependency error"

**Solution:** This is now fixed in the base role. Ensure you're using the latest version:
```bash
git pull origin main
```

The `base` role automatically upgrades pip system-wide, and each role upgrades pip in its virtual environment before installing packages.

### Issue: "RHSM registration failed"

**Solution:**
1. Verify credentials at https://access.redhat.com/
2. Check organization ID and activation key in `ansible/inventory/group_vars/all.yml`
3. Ensure activation key has available subscriptions

### Issue: "VirtualBox Guest Additions not found"

**Solution:**
```bash
# Download ISO
wget -O files/VBoxGuestAdditions_7.1.10.iso \
  https://download.virtualbox.org/virtualbox/7.1.10/VBoxGuestAdditions_7.1.10.iso

# OR copy from VirtualBox installation
# Linux:
cp /usr/share/virtualbox/VBoxGuestAdditions.iso files/VBoxGuestAdditions_7.1.10.iso

# macOS:
cp /Applications/VirtualBox.app/Contents/MacOS/VBoxGuestAdditions.iso files/VBoxGuestAdditions_7.1.10.iso

# Windows:
Copy-Item "C:\Program Files\Oracle\VirtualBox\VBoxGuestAdditions.iso" files\VBoxGuestAdditions_7.1.10.iso
```

---

## Air-Gap Deployment

For systems without internet access, pre-download artifacts:

### 1. Download Python Wheels

```bash
# On internet-connected system
mkdir -p /tmp/wheels

# Download pip first (critical!)
pip download pip -d /tmp/wheels

# Download Stable Diffusion dependencies
cd /path/to/stable-diffusion-webui
pip download -r requirements.txt -d /tmp/wheels

# Download RAG stack dependencies
podman run --rm --security-opt label=disable \
  -v /srv/rag:/app -w /app docker.io/python:3.11 \
  bash -lc "mkdir -p wheels && pip download pip -d wheels && pip download -r requirements.txt -d wheels"

# Transfer to air-gapped system
rsync -avz /tmp/wheels/ target-host:/tmp/wheels/
```

### 2. Download Container Images

```bash
# Pull images
podman pull docker.io/ankane/pgvector:latest
podman pull docker.io/python:3.11

# Save to tar
podman save -o rag-images.tar docker.io/ankane/pgvector docker.io/python:3.11

# Transfer and load on air-gapped host
scp rag-images.tar target-host:/tmp/
ssh target-host 'podman load -i /tmp/rag-images.tar'
```

### 3. Download Whisper Models

```bash
# Pre-download models (on internet-connected system)
python -c "import whisper; whisper.load_model('tiny')"
python -c "import whisper; whisper.load_model('base')"

# Copy cache to target
rsync -avz ~/.cache/whisper/ target-host:/home/sd-data/.cache/whisper/
```

---

## Verification Checklist

Before running playbooks, verify:

- [ ] Configuration files created (`.env`, `ansible.cfg`, `inventory/`)
- [ ] RHSM credentials configured in `inventory/group_vars/all.yml`
- [ ] Vault password secured (not using example value)
- [ ] Ansible installed (`ansible --version`)
- [ ] Galaxy collections installed (`ansible-galaxy collection list | grep containers.podman`)
- [ ] Environment loaded (`echo $ANSIBLE_CONFIG`)
- [ ] Target host accessible (`ansible all -m ping`)

---

## Next Steps

After successful installation:

1. **Verify Services**
   ```bash
   # Check Stable Diffusion
   sudo -u sd-data /home/sd-data/data/stable-diffusion-webui/launch.sh
   # Access: http://localhost:7860

   # Check RAG stack
   curl http://localhost:19090/query -H 'Content-Type: application/json' \
     -d '{"query":"test"}' | jq
   ```

2. **Configure Systemd Services** (optional)
   - Create systemd user services for Stable Diffusion
   - Enable lingering for `sd-data` user

3. **Add Models and Data**
   - Download Stable Diffusion checkpoints to `/home/sd-data/data/models/Stable-diffusion/`
   - Add documents to `/srv/docs/` for RAG ingestion

4. **Review Documentation**
   - [Main README](README.md) - Complete feature documentation
   - [Vagrant Setup](vagrant/rhel9/README.md) - Testing environment
   - [RAG Stack](ansible/playbooks/README.md) - RAG deployment details

---

## Support

For issues or questions:

1. Check [Troubleshooting](README.md#troubleshooting) section in main README
2. Review role-specific READMEs in `ansible/playbooks/roles/*/README.md`
3. Open an issue at https://github.com/justinblackburn/ai-build/issues

---

**Happy Building!** 🚀
