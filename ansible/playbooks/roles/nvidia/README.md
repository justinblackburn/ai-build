# `nvidia` Role

Installs NVIDIA GPU drivers, container toolkit, and configures the system for GPU-accelerated workloads. The role handles nouveau driver removal, kernel module compilation via akmods, and Podman integration.

---

## Purpose

The `nvidia` role provides complete NVIDIA GPU support:

| Component | Description |
|-----------|-------------|
| **Driver Detection** | Automatically detects NVIDIA GPUs via `lspci` |
| **Nouveau Blacklist** | Disables the open-source nouveau driver that conflicts with NVIDIA |
| **Pinned driver** | Installs driver 615.71.09 from NVIDIA's RHEL repo (`nvidia_driver_version`), with the DKMS kernel module that rebuilds on kernel updates, and locks the packages |
| **Container Toolkit** | Enables GPU passthrough for Podman containers |
| **Clean Reinstall** | Automated cleanup mode for fixing driver issues |
| **Kernel Arguments** | Applies boot parameters for NVIDIA driver loading and modesetting |

---

## Variables

Defined in [defaults/main.yml](defaults/main.yml) and overrideable in inventory:

```yaml
# Repository configuration
nvidia_repo_el_version: "9"                    # Enterprise Linux major version

# Feature flags
nvidia_install_gpu_drivers: true               # Install GPU drivers
nvidia_install_container_toolkit: true         # Install NVIDIA Container Toolkit

# Paths
nvidia_container_runtime_path: /usr/bin/nvidia-container-runtime

# Repository URLs
nvidia_driver_version: "615.71.09"
nvidia_cuda_repo_url: "https://developer.download.nvidia.com/compute/cuda/repos/rhel9/x86_64/cuda-rhel9.repo"
nvidia_container_repo_url: "https://nvidia.github.io/libnvidia-container/stable/rpm/nvidia-container-toolkit.repo"

# Troubleshooting
nvidia_force_clean_reinstall: false            # Force driver cleanup and reinstall

# Kernel parameters
nvidia_kernel_args:
  - rd.driver.blacklist=nouveau                # Block nouveau in initramfs
  - modprobe.blacklist=nouveau                 # Block nouveau in running system
  - nvidia-drm.modeset=1                       # Enable NVIDIA DRM modesetting
```

---

## Role Workflow

### 1. GPU Detection
- Runs `lspci` to detect NVIDIA hardware
- Skips all tasks if no NVIDIA GPU found or `is_vagrant: true`

### 2. Driver State Analysis
Determines if a clean reinstall is needed by checking:
- `nvidia_force_clean_reinstall` variable (manual trigger)
- Presence of nouveau in initramfs (indicates incomplete cleanup)
- Missing NVIDIA kernel module (`modinfo nvidia` fails)

### 3. Clean Reinstall (if required)
When triggered, performs aggressive cleanup:
```bash
# Remove all NVIDIA packages
dnf remove nvidia-driver* akmod-nvidia* xorg-x11-drv-nvidia* nvidia-settings*

# Delete stale kernel modules and build artifacts
rm -rf /usr/lib/modules/$(uname -r)/extra/nvidia*
rm -rf /var/lib/dkms/nvidia*
rm -rf /var/cache/akmods/*
rm -rf /var/tmp/akmodsbuild*
rm -f /etc/modprobe.d/nvidia*.conf

# Rebuild initramfs
dracut --force
```

### 4. Nouveau Blacklist
- Writes `/etc/modprobe.d/blacklist-nouveau.conf`
- Triggers initramfs rebuild via handler
- Attempts to unload nouveau module from running system (best effort)

### 5. Driver Installation
- Installs kernel development packages (kernel-devel, kernel-headers, gcc, make)
- Adds NVIDIA's CUDA RHEL 9 repo (driver source)
- Installs `nvidia-driver-<version>` and `kmod-nvidia-open-dkms-<version>` at the pinned version, then locks them with versionlock
- The DKMS module builds during the install and rebuilds on kernel updates

### 6. Kernel Arguments
Applies NVIDIA-specific boot parameters via grubby:
- `rd.driver.blacklist=nouveau` - Prevents nouveau loading during boot
- `modprobe.blacklist=nouveau` - Ensures nouveau stays blacklisted
- `nvidia-drm.modeset=1` - Enables kernel modesetting for NVIDIA

### 7. Container Toolkit (optional)
If `nvidia_install_container_toolkit: true`:
- Adds NVIDIA container toolkit repository
- Installs `nvidia-container-toolkit` package
- Configures Podman to use NVIDIA runtime in `/etc/containers/containers.conf.d/nvidia.conf`

---

## Prerequisites

- RHEL 9.x with NVIDIA GPU hardware
- `base` role completed (provides EPEL and development tools)
- Network access to:
  - `developer.download.nvidia.com` (driver packages)
  - `nvidia.github.io` (container toolkit)
- Secure Boot **disabled** or NVIDIA modules signed (akmods require unsigned module loading by default)

---

## Usage

### Standalone Execution

```bash
ansible-playbook playbooks/nvidia.yml --ask-become-pass
```

**Important**: Reboot after first run to activate nouveau blacklist and load NVIDIA modules.

### Force Clean Reinstall

If drivers fail to load or nouveau persists, trigger cleanup mode:

```yaml
# In inventory/group_vars/all.yml
nvidia_force_clean_reinstall: true
```

Then rerun the playbook:
```bash
ansible-playbook playbooks/nvidia.yml --ask-become-pass
```

**Remember to set it back to `false` after cleanup completes.**

---

## Post-Installation Verification

### Check NVIDIA Driver

```bash
# Primary verification
nvidia-smi

# Expected output:
# +---------------------------------------------------------------------------------------+
# | NVIDIA-SMI 550.78                 Driver Version: 550.78       CUDA Version: 12.4     |
# +---------------------------------------------------------------------------------------+
```

### Verify Kernel Modules

```bash
# NVIDIA modules loaded
lsmod | grep nvidia

# Nouveau NOT loaded
lsmod | grep nouveau  # Should return nothing
```

### Check Kernel Arguments

```bash
grubby --info=ALL | grep args

# Should include:
# rd.driver.blacklist=nouveau modprobe.blacklist=nouveau nvidia-drm.modeset=1
```

### Test Container Toolkit

```bash
# Verify NVIDIA runtime configured
cat /etc/containers/containers.conf.d/nvidia.conf

# Test GPU access in container
podman run --rm --device nvidia.com/gpu=all docker.io/nvidia/cuda:12.1.0-base-ubuntu22.04 nvidia-smi
```

---

## Troubleshooting

### NVIDIA Driver Not Loading After Reboot

**Symptom**: `nvidia-smi` returns "No devices were found" or module not found.

**Debug Steps**:
```bash
# 1. Check if nouveau is still loaded
lsmod | grep nouveau

# 2. Verify nouveau is in initramfs
lsinitrd /boot/initramfs-$(uname -r).img | grep nouveau

# 3. Check if NVIDIA module exists
modinfo nvidia

# 4. Review akmod build logs
sudo journalctl -u akmods
ls -la /var/cache/akmods/
```

**Solution**: Set `nvidia_force_clean_reinstall: true` and rerun playbook, then reboot.

### akmod Build Failures

**Symptom**: NVIDIA module doesn't compile after kernel update.

**Debug**:
```bash
# Check akmod status
sudo akmods --kernels $(uname -r)

# Review build logs
tail -f /var/cache/akmods/akmods.log

# Verify kernel headers match running kernel
uname -r
rpm -q kernel-devel kernel-headers
```

**Solution**:
```bash
# Install matching kernel-devel
sudo dnf install "kernel-devel-$(uname -r)"

# Manually trigger akmod rebuild
sudo akmods --force --kernels $(uname -r)
```

### Container Toolkit Not Working

**Symptom**: Podman containers can't access GPU.

**Debug**:
```bash
# Verify toolkit installed
rpm -qa | grep nvidia-container

# Check runtime configuration
podman info | grep -i nvidia

# Test device detection
nvidia-container-cli info
```

**Solution**:
```bash
# Reinstall toolkit
sudo dnf reinstall nvidia-container-toolkit

# Regenerate Podman config
sudo nvidia-ctk runtime configure --runtime=podman
```

### Secure Boot Conflicts

**Symptom**: Kernel module loading fails with "Operation not permitted" in dmesg.

**Solution**: Either:
1. Disable Secure Boot in BIOS/UEFI
2. Sign the NVIDIA modules with a MOK (Machine Owner Key) - see [RHEL documentation](https://access.redhat.com/documentation/en-us/red_hat_enterprise_linux/9/html/managing_monitoring_and_updating_the_kernel/signing-a-kernel-and-modules-for-secure-boot_managing-monitoring-and-updating-the-kernel)

### Nouveau Persists After Blacklist

**Symptom**: `lsmod | grep nouveau` still shows nouveau loaded.

**Solution**:
```bash
# Force unload (may require stopping display manager)
sudo systemctl isolate multi-user.target
sudo modprobe -r nouveau

# Verify initramfs was rebuilt
ls -lht /boot/initramfs-* | head -5

# Manually rebuild if needed
sudo dracut --force

# Reboot
sudo reboot
```

---

## Handlers

The role includes two handlers triggered on configuration changes:

### `Rebuild initramfs after nouveau blacklist`
Runs `dracut --force` to regenerate initramfs when blacklist config changes.

---

## Architecture Notes

### Why NVIDIA's repo and DKMS?

The driver comes from NVIDIA's own repo so the version can be pinned to match the CUDA wheels. The DKMS module (`kmod-nvidia-open-dkms`) rebuilds on every kernel update, so no manual step is needed.

### Clean reinstall

A normal run never removes the driver. A clean reinstall (removing packages and artifacts first) runs only with `nvidia_force_clean_reinstall: true`.

### Why Two Blacklist Methods?

- `rd.driver.blacklist=nouveau` - Blocks loading during early boot (initramfs stage)
- `modprobe.blacklist=nouveau` - Ensures systemd and manual modprobe don't load nouveau
- `/etc/modprobe.d/blacklist-nouveau.conf` - Persistent module blacklist configuration

All three are necessary to prevent nouveau from interfering with NVIDIA drivers.

### Container Runtime Configuration

The role writes a separate config file at `/etc/containers/containers.conf.d/nvidia.conf` instead of modifying the main `containers.conf`. This follows the drop-in configuration pattern and survives package updates.

---

## Related Roles

- **base**: Must run first to provide EPEL and development tools
- **podman**: Benefits from container toolkit for GPU-enabled containers
- **stable_diffusion**: Requires NVIDIA drivers for GPU acceleration
