# Cached Files for Vagrant Testing

This directory contains large binary files and git repositories that are cached locally to speed up Vagrant deployments and enable offline testing.

## Contents

### VirtualBox Guest Additions ISO
- **File**: `VBoxGuestAdditions_7.1.10.iso`
- **Purpose**: Required for shared folder functionality in Vagrant
- **Size**: ~60 MB
- **See**: [vagrant/rhel9/README.md](../vagrant/rhel9/README.md) for download instructions

### Git Repository Caches (Optional)
These are cloned automatically by the `populate-git-cache.sh` script and used by Vagrant VMs to avoid re-downloading large repos:

- **stable-diffusion-webui/** - AUTOMATIC1111 Stable Diffusion WebUI (~42 MB)
- **ComfyUI/** - ComfyUI alternative interface (~15 MB)
- **xformers/** - Facebook Research xformers library (~50 MB)

## How It Works

### Vagrant Environment
When running in Vagrant, this directory is mounted at `/mnt/files` inside the VM. The Ansible playbooks check for cached repos and use them if available, otherwise they clone from GitHub.

### Production Environment
On non-Vagrant systems, the Ansible playbooks skip the cache checks and clone directly from GitHub as normal.

## Populating the Git Cache

To cache git repositories locally for faster Vagrant deployments:

```bash
cd files/
bash populate-git-cache.sh
```

The script will prompt you to select which repositories to cache:
1. All components (Stable Diffusion + ComfyUI + xformers)
2. Stable Diffusion only
3. ComfyUI only
4. xformers only
5. Custom selection

### After Caching

Once cached, reload your Vagrant VM to use the local repos:

```bash
cd vagrant/rhel9
vagrant reload
```

The next time you run Ansible playbooks, they will use the cached repos from `/mnt/files` instead of cloning from GitHub.

## Benefits

✅ **Faster Vagrant deployments** - No need to re-clone large repos
✅ **Offline testing** - Test deployments without internet access
✅ **Bandwidth savings** - Download repos once, use many times
✅ **Consistent versions** - Same repos used across VM rebuilds

## Clearing the Cache

To remove cached repositories and start fresh:

```bash
cd files/
rm -rf stable-diffusion-webui/ ComfyUI/ xformers/
```

The ISO file will not be affected and will remain in place.

## Disk Space Requirements

- **VBoxGuestAdditions ISO**: ~60 MB
- **stable-diffusion-webui**: ~42 MB
- **ComfyUI**: ~15 MB
- **xformers**: ~50 MB
- **Total (all cached)**: ~170 MB

## .gitignore

The cached git repositories are excluded from version control via `.gitignore` to prevent accidentally committing large binary data to the repository.

Only the following files are tracked:
- `VBoxGuestAdditions_7.1.10.iso` (explicitly tracked)
- `populate-git-cache.sh` (helper script)
- `README.md` (this file)

## Troubleshooting

### Cached repos not being used

**Symptom**: Ansible still clones from GitHub despite cached repos existing.

**Solution**: Check that `/mnt/files` is mounted in the Vagrant VM:
```bash
vagrant ssh
ls -la /mnt/files
# Should show: stable-diffusion-webui/, ComfyUI/, xformers/
```

### Permission issues

**Symptom**: Cannot access cached repos from Vagrant VM.

**Solution**: Check Vagrantfile mount configuration and file ownership on host.

### Outdated cached repos

**Symptom**: Using old versions of repos.

**Solution**: Re-run `populate-git-cache.sh` to update cached repos:
```bash
cd files/
bash populate-git-cache.sh
```

The script will detect existing repos and pull the latest changes.

---

**Note**: This caching mechanism is specifically designed for Vagrant testing. Production deployments always clone from GitHub to ensure they get the latest code.
