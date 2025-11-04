# `base` Role

Bootstraps a RHEL 9 workstation with subscription management, package repositories, development tools, and NVIDIA audio support. This role prepares the foundation for all other AI workload roles.

---

## Purpose

The `base` role handles initial system configuration:

| Component | Description |
|-----------|-------------|
| **Subscription Management** | Registers the system with Red Hat Subscription Manager (RHSM) using organization ID and activation key |
| **Repository Enablement** | Activates CodeReady Builder and EPEL repositories for additional packages |
| **Development Tools** | Installs `@Development Tools` group (gcc, make, etc.) and essential utilities |
| **Kernel Components** | Ensures kernel headers, kernel-devel, and kernel-modules-extra are present |
| **NVIDIA Audio** | Loads and persists HDMI audio kernel modules (`snd_hda_intel`, `snd_hda_codec_hdmi`) |
| **Vagrant Detection** | Automatically detects Vagrant environments to skip GPU-related tasks |

---

## Variables

All variables are defined in inventory (`group_vars/all.yml`):

```yaml
# Subscription management
enable_subscription: true                    # Toggle RHSM registration
rhsm_org: "YOUR_RED_HAT_ORG_ID"             # RHSM organization ID
rhsm_key: "YOUR_REDHAT_ACTIVATION_KEY"      # RHSM activation key

# Environment detection
is_vagrant: false                            # Auto-detected by checking /vagrant path
```

**Important**: Encrypt `rhsm_org` and `rhsm_key` with Ansible Vault in production:

```bash
ansible-vault encrypt_string 'your-activation-key' --name 'rhsm_key'
```

---

## Role Workflow

1. **Environment Detection**
   - Checks for `/vagrant` directory to set `is_vagrant` fact
   - GPU and audio tasks are skipped when running in Vagrant

2. **Subscription Registration** (if `enable_subscription: true`)
   - Tests if system is already registered with `subscription-manager identity`
   - Registers with RHSM using org ID and activation key if not registered
   - Enables CodeReady Builder repository for architecture-specific packages

3. **Repository Configuration**
   - Imports EPEL GPG key from Fedora Project
   - Installs EPEL repository for RHEL 9

4. **Package Installation**
   - Installs `@Development Tools` group (gcc, make, autoconf, etc.)
   - Installs core utilities:
     - `kernel-headers`, `kernel-devel` (for driver compilation)
     - `python3-pip`, `git`, `wget`, `curl`
     - `zsh`, `ansible-core`

5. **NVIDIA Audio Configuration** (skipped in Vagrant)
   - Installs `kernel-modules-extra` for running kernel (falls back to generic if specific version unavailable)
   - Loads HDMI audio modules immediately with `modprobe` (best-effort)
   - Persists modules in `/etc/modules-load.d/nvidia-audio.conf` for boot-time loading

---

## Prerequisites

- RHEL 9.x host with network access to:
  - `subscription.rhsm.redhat.com` (subscription management)
  - `dl.fedoraproject.org` (EPEL repository)
- Valid Red Hat subscription with organization ID and activation key
- Ansible control node with SSH access and sudo privileges on target

---

## Usage

### Standalone Execution

```bash
ansible-playbook playbooks/base.yml --ask-become-pass
```

### As Part of Full Stack

The `base` role is automatically included in [playbooks/install.yml](../install.yml) as the first step.

---

## Post-Installation Verification

```bash
# Verify subscription status
sudo subscription-manager identity
sudo subscription-manager list --consumed

# Check enabled repositories
sudo subscription-manager repos --list-enabled

# Verify EPEL is available
sudo dnf repolist | grep epel

# Confirm development tools
gcc --version
make --version

# Check NVIDIA audio modules (physical hardware only)
lsmod | grep snd_hda_intel
lsmod | grep snd_hda_codec_hdmi
```

---

## Troubleshooting

### Subscription Registration Fails

**Symptom**: `subscription-manager register` returns authentication errors.

**Solution**:
- Verify org ID and activation key in inventory
- Ensure activation key is valid and not expired in Red Hat Customer Portal
- Check network connectivity to `subscription.rhsm.redhat.com`
- Run manually to see detailed errors:
  ```bash
  sudo subscription-manager register --org YOUR_ORG --activationkey YOUR_KEY
  ```

### CodeReady Builder Not Enabling

**Symptom**: CodeReady Builder repository enablement fails.

**Solution**: The role uses `ignore_errors: true` for repo enablement. Verify manually:
```bash
sudo subscription-manager repos --list | grep codeready
sudo subscription-manager repos --enable codeready-builder-for-rhel-9-x86_64-rpms
```

### NVIDIA Audio Modules Not Loading

**Symptom**: `lsmod | grep snd_hda` shows no results on physical hardware.

**Solution**:
- Verify you're not in Vagrant (role skips audio in VMs)
- Check if modules exist:
  ```bash
  modinfo snd_hda_intel
  modinfo snd_hda_codec_hdmi
  ```
- Load manually:
  ```bash
  sudo modprobe snd_hda_intel
  sudo modprobe snd_hda_codec_hdmi
  ```
- Ensure `/etc/modules-load.d/nvidia-audio.conf` exists and contains module names

### kernel-modules-extra Installation Fails

**Symptom**: Task fails to install `kernel-modules-extra` for running kernel.

**Solution**: The role includes a fallback to install the generic package. If both fail:
```bash
# Check running kernel version
uname -r

# Search for available packages
sudo dnf search kernel-modules-extra

# Install manually
sudo dnf install kernel-modules-extra
```

---

## Notes

- SELinux remains in enforcing mode (no disabled SELinux tasks)
- VirtualBox Guest Additions tasks are commented out (not in active use)
- The role is idempotent and safe to run multiple times
- RHSM registration is skipped if system is already registered
- All package installations use `state: present` (updates not forced)

---

## Related Roles

- **nvidia**: Installs NVIDIA drivers and container toolkit (depends on base repositories)
- **podman**: Requires development tools from this role for container builds
- **stable_diffusion**: Needs Python and Git packages installed by this role
