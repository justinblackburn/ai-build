# ai-build

Automation for a reproducible AI workstation on **RHEL 9**. The playbooks in this repo configure the base OS, GPU drivers, container tooling, Stable Diffusion, and Whisper transcription so you can rebuild the stack from bare metal in a few commands.

---

## Highlights
- Opinionated RHEL 9 workstation bootstrap (subscription, build tools, EPEL)
- NVIDIA driver/toolkit provisioning with nouveau cleanup
- Stable Diffusion (AUTOMATIC1111) + ComfyUI in a dedicated service account
- Whisper CLI with optional YouTube audio helper script
- Podman-based container workflow and user provisioning
- All configuration captured in inventory/`group_vars` and example environment files

---

## Repository Layout
```
ai-build/
├── .env.example
├── README.md
├── ansible/
│   ├── ansible.conf.example
│   ├── inventory.example/
│   │   ├── group_vars/
│   │   │   └── all.yml
│   │   └── hosts.yml
│   ├── playbooks/
│   │   ├── base.yml
│   │   ├── install.yml
│   │   ├── nvidia.yml
│   │   ├── podman.yml
│   │   ├── stable_diffusion.yml
│   │   ├── users.yml
│   │   └── whisper.yml
│   └── roles/
│       ├── base/
│       ├── nvidia/
│       ├── podman/
│       ├── stable_diffusion/
│       ├── users/
│       └── whisper/
└── vagrant/
    └── rhel9/        # disposable test VM definition
```

---

## Quick Start
1. **Clone the repo**
   ```bash
   git clone https://github.com/justinblackburn/ai-build.git
   cd ai-build
   ```

2. **Copy the example configuration**
   ```bash
   cp .env.example .env
   cp ansible/ansible.conf.example ansible/ansible.cfg
   cp ansible/.vault_pass.txt.example ansible/.vault_pass.txt
   cp -R ansible/inventory.example ansible/inventory
   ```

3. **Edit the inventory**
   - Set your Red Hat subscription org/key in `ansible/inventory/group_vars/all.yml`.
   - Adjust paths (e.g. `sd_webui_root`, `sd_webui_data_dir`) or add additional users if needed.

4. **Secure the vault password**
   - Replace the placeholder in `ansible/.vault_pass.txt` with a unique value.
   - Keep the real file out of source control.

5. **Load the environment**
   ```bash
   source .env
   ```
   This exports `ANSIBLE_CONFIG`, `ANSIBLE_INVENTORY`, and related variables for convenience.

6. **Install Ansible and dependencies on the controller**
   ```bash
   sudo dnf install -y ansible-core git
   ```

7. **Run the full workstation build (become password required)**
   ```bash
   ansible-playbook playbooks/install.yml --ask-become-pass
   ```
   Feel free to run individual playbooks (`base.yml`, `nvidia.yml`, `stable_diffusion.yml`, `whisper.yml`) as you iterate.

---

## Role Overview

| Role | Playbook | Purpose |
| --- | --- | --- |
| `base` | `playbooks/base.yml` | Registers the host, enables CodeReady & EPEL, installs development toolchain and core utilities. |
| `users` | `playbooks/users.yml` | Provisions service and interactive accounts, home directories, lingering, and sudo policy. |
| `podman` | `playbooks/podman.yml` | Installs Podman + podman-compose, enables the rootless socket, and writes user-level container configs. |
| `nvidia` | `playbooks/nvidia.yml` | Blacklists nouveau, rebuilds initramfs, installs RPMFusion/NVIDIA drivers, and the container toolkit. |
| `stable_diffusion` | `playbooks/stable_diffusion.yml` | Clones AUTOMATIC1111, prepares the Python venv, installs xformers from source, and drops a hardened `launch.sh`. |
| `whisper` | `playbooks/whisper.yml` | Creates or reuses the service venv, installs `openai-whisper` + `yt-dlp`, and supplies helper scripts for audio and YouTube transcription. |

The composite `playbooks/install.yml` runs these roles in order for a turnkey deployment.

---

## Using the Helper Scripts

After provisioning, switch to the service account or run with sudo:
```bash
sudo -u sd-data -- /home/sd-data/data/whisper-transcribe.sh /path/to/audio.wav --model large
sudo -u sd-data -- /home/sd-data/data/youtube-transcribe.sh "https://youtu.be/clip" --model medium.en
sudo -u sd-data -- /home/sd-data/data/stable-diffusion-webui/launch.sh
COMFY_LISTEN_ADDR=127.0.0.1 COMFY_PORT=8188 sudo -u sd-data -- /home/sd-data/data/ComfyUI/launch.sh
```

The scripts activate the Python virtual environment and call the venv-local executables (`whisper`, `yt-dlp`, `launch.py`).

> Tip: The ComfyUI launcher accepts environment overrides such as `COMFY_LISTEN_ADDR`, `COMFY_PORT`, and directory variables (`COMFY_OUTPUT_DIR`, `COMFY_TEMP_DIR`, etc.). When binding to `0.0.0.0`, the wrapper now echoes a friendly `http://127.0.0.1:PORT` URL so it’s clear which address to open locally.

---

## Tips & Troubleshooting
- **GPU Drivers:** After installing the `nvidia` role, reboot so the nouveau blacklist takes effect, then verify with `nvidia-smi`. If nouveau keeps resurfacing or the NVIDIA module fails to load, set `nvidia_force_clean_reinstall: true` in inventory to trigger the automated cleanup/rebuild sequence (removes stale drivers, rebuilds `initramfs`, reapplies kernel args, and reruns `akmods`).
- **Ansible Vault:** Use `ansible-vault encrypt` on secrets (e.g., RHSM keys). The vault password file path matches the sample Ansible config.
- **Vagrant Testing:** `vagrant/rhel9/` contains a disposable VM definition for validating playbooks without touching production gear.
- **Temp Directories:** If you run Ansible inside a restricted environment, set `ANSIBLE_LOCAL_TEMP`/`ANSIBLE_REMOTE_TEMP` to a writable path (see `.env.example` for inspiration).

---

## Next Steps
- Layer in additional roles for LLM tooling or RAG indexing.
- Integrate CI (GitHub Actions, Jenkins) to lint and execute playbooks automatically.
- Extend inventory groups for multi-node clusters (workers, storage, inference).

Contributions and refinements are always welcome—open an issue or PR with ideas for improving the automation. Happy building!

---

## Variable Reference

| Category | Variable | Default | Description |
| --- | --- | --- | --- |
| Global | `enable_subscription` | `true` | Toggle Red Hat subscription registration tasks in the `base` role. |
| Global | `is_vagrant` | `false` | Flags when playbooks run inside Vagrant; used to skip GPU work. |
| Global | `rhsm_org` | `"YOUR_RED_HAT_ORG_ID"` | Red Hat Subscription Manager organization ID. |
| Global | `rhsm_key` | `"YOUR_REDHAT_ACTIVATION_KEY"` | Activation key for RHSM registration. |
| Global | `sd_webui_root` | `"/opt/stable-diffusion-webui"` | Checkout location for the AUTOMATIC1111 repository. |
| Global | `sd_webui_data_dir` | `"/home/sd-data/data"` | Shared data tree for Stable Diffusion and Whisper assets. |
| Global | `nvidia_driver_url` | NVIDIA 550.78 URL | Remote installer used when the proprietary driver is required. |
| Global | `nvidia_driver_file` | `"{{ nvidia_driver_url | basename }}"` | Filename portion of the NVIDIA driver URL (derived automatically). |
| Global | `users` | See inventory example | List of user/service-account dictionaries consumed by the `users` role. |
| Global | `users[].enable_podman` | `true`/`false` | Enables per-user Podman configuration. |
| Global | `users[].directories` | `[]` | Directories created and owned by each user entry. |
| NVIDIA | `nvidia_repo_el_version` | `"9"` | Enterprise Linux major version used for RPM repository URLs. |
| NVIDIA | `nvidia_install_gpu_drivers` | `true` | Feature flag for installing akmod-based GPU drivers. |
| NVIDIA | `nvidia_install_container_toolkit` | `true` | Feature flag for installing the NVIDIA container runtime/toolkit. |
| NVIDIA | `nvidia_container_runtime_path` | `"/usr/bin/nvidia-container-runtime"` | Expected runtime path injected into Podman configuration. |
| NVIDIA | `nvidia_rpmfusion_repo_url` | rpmfusion nonfree URL | Override to supply a custom RPMFusion repository. |
| NVIDIA | `nvidia_container_repo_url` | NVIDIA toolkit repo | Location of the libnvidia-container repository definition. |
| Stable Diffusion | `sd_webui_models_dir` | `"{{ sd_webui_data_dir + '/models' }}"` | Root directory for Stable Diffusion model assets. |
| Stable Diffusion | `sd_webui_venv` | `"{{ sd_webui_data_dir + '/venv' }}"` | Python virtual environment used by Stable Diffusion roles/scripts. |
| Stable Diffusion | `sd_webui_ckpt_dir` | `"{{ sd_webui_models_dir + '/Stable-diffusion' }}"` | Checkpoint directory path passed to `launch.py`. |
| Stable Diffusion | `sd_webui_vae_dir` | `"{{ sd_webui_models_dir + '/VAE' }}"` | VAE model location passed to `launch.py`. |
| Stable Diffusion | `sd_webui_lora_dir` | `"{{ sd_webui_models_dir + '/Lora' }}"` | LoRA model directory used during launches. |
| Stable Diffusion | `sd_webui_embeddings_dir` | `"{{ sd_webui_models_dir + '/embeddings' }}"` | Text embedding directory injected into launch options. |
| Stable Diffusion | `torch_version` | `"torch==2.3.0+cu121"` | Override value for PyTorch version (available for customization). |
| Stable Diffusion | `torchvision_version` | `"torchvision==0.18.0+cu121"` | Override value for torchvision version. |
| Stable Diffusion | `torch_extra_index` | CUDA 12.1 wheel index | Extra pip index for CUDA-enabled PyTorch wheels. |
| Whisper | `whisper_user` | `"sd-data"` | Account used to own Whisper helper scripts and venv. |
| Whisper | `whisper_group` | `"sd-data"` | Primary group for Whisper assets. |
| Whisper | `whisper_data_dir` | `"/home/sd-data/data"` | Base directory for Whisper downloads and helper scripts. |
| Whisper | `whisper_venv` | `"{{ whisper_data_dir }}/venv"` | Python virtual environment path for Whisper tooling. |
| Whisper | `whisper_ffmpeg_package` | `"ffmpeg"` | System package installed to provide media codecs for Whisper. |

All variable names follow lower_snake_case and are prefixed per role (`sd_webui_*`, `whisper_*`, `nvidia_*`) to avoid collisions, aligning with Ansible best practices. The few global values intentionally remain concise for readability in inventory files.
