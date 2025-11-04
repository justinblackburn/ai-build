# ai-build

Automation for a reproducible AI workstation on **RHEL 9**. The playbooks in this repo configure the base OS, GPU drivers, container tooling, Stable Diffusion, Whisper transcription, and local RAG infrastructure so you can rebuild the stack from bare metal in a few commands.

---

## Highlights
- Opinionated RHEL 9 workstation bootstrap (subscription, build tools, EPEL)
- NVIDIA driver/toolkit provisioning with nouveau cleanup and HDMI audio support
- Stable Diffusion (AUTOMATIC1111) + ComfyUI in a dedicated service account
- Whisper CLI with optional YouTube audio helper script
- Local RAG stack with PostgreSQL + pgvector for air-gapped document retrieval
- Podman-based container workflow and user provisioning
- All configuration captured in inventory/`group_vars` and example environment files

---

## Repository Layout
```
ai-build/
├── .env.example
├── .gitignore
├── README.md
├── ansible/
│   ├── .vault_pass.txt.example
│   ├── ansible.conf.example
│   ├── inventory/              # active inventory (gitignored)
│   ├── inventory.example/      # template inventory
│   │   ├── group_vars/
│   │   │   └── all.yml
│   │   └── hosts.yml
│   └── playbooks/
│       ├── README.md           # RAG stack deployment guide
│       ├── base.yml
│       ├── install.yml
│       ├── llm_ingest.yml      # RAG stack provisioning
│       ├── nvidia.yml
│       ├── podman.yml
│       ├── stable_diffusion.yml
│       ├── users.yml
│       ├── whisper.yml
│       └── roles/
│           ├── base/
│           ├── llm_rag/        # Local RAG stack
│           │   ├── README.md
│           │   ├── defaults/
│           │   ├── files/
│           │   └── tasks/
│           ├── nvidia/
│           ├── podman/
│           ├── stable_diffusion/
│           ├── users/
│           └── whisper/
├── files/
│   └── VBoxGuestAdditions_7.1.10.iso
└── vagrant/
    └── rhel9/                  # disposable test VM definition
```

---

## Platform Compatibility

| Component | Version | Status |
| --- | --- | --- |
| RHEL | 9.x | Tested |
| Rocky Linux | 9.x | Compatible |
| Python | 3.9+ | Required |
| Podman | 5.x | Recommended |
| Ansible | 2.14+ | Required |

The playbooks target RHEL 9 and derivatives with the latest stable Ansible release. GPU features require NVIDIA hardware and are automatically skipped in Vagrant environments.

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
   - Set your Red Hat subscription org/key in [ansible/inventory/group_vars/all.yml](ansible/inventory/group_vars/all.yml).
   - Adjust paths (e.g. `sd_webui_root`, `sd_webui_data_dir`) or add additional users if needed.
   - For RAG stack deployment, configure `llm_rag_*` variables (see [Variable Reference](#variable-reference)).

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

8. **(Optional) Deploy the local RAG stack**
   ```bash
   ansible-playbook playbooks/llm_ingest.yml --ask-become-pass
   ```
   See [ansible/playbooks/README.md](ansible/playbooks/README.md) for detailed RAG stack documentation including prerequisites, configuration, and day-2 operations.

---

## Role Overview

| Role | Playbook | Purpose |
| --- | --- | --- |
| `base` | [playbooks/base.yml](ansible/playbooks/base.yml) | Registers the host, enables CodeReady & EPEL, installs development toolchain and core utilities. |
| `users` | [playbooks/users.yml](ansible/playbooks/users.yml) | Provisions service and interactive accounts, home directories, lingering, and sudo policy. |
| `podman` | [playbooks/podman.yml](ansible/playbooks/podman.yml) | Installs Podman + podman-compose, enables the rootless socket, and writes user-level container configs. |
| `nvidia` | [playbooks/nvidia.yml](ansible/playbooks/nvidia.yml) | Blacklists nouveau, rebuilds initramfs, installs RPMFusion/NVIDIA drivers, container toolkit, and configures HDMI audio. |
| `stable_diffusion` | [playbooks/stable_diffusion.yml](ansible/playbooks/stable_diffusion.yml) | Clones AUTOMATIC1111 and ComfyUI, prepares the Python venv, installs xformers from source, and drops hardened launch scripts. |
| `whisper` | [playbooks/whisper.yml](ansible/playbooks/whisper.yml) | Creates or reuses the service venv, installs `openai-whisper` + `yt-dlp`, and supplies helper scripts for audio and YouTube transcription. |
| `llm_rag` | [playbooks/llm_ingest.yml](ansible/playbooks/llm_ingest.yml) | Deploys a local RAG stack using Podman (PostgreSQL + pgvector + Flask ingestion service) for air-gapped document retrieval. See [roles/llm_rag/README.md](ansible/playbooks/roles/llm_rag/README.md). |

The composite [playbooks/install.yml](ansible/playbooks/install.yml) runs the core roles in order for a turnkey deployment. The RAG stack is deployed separately via `llm_ingest.yml` to allow independent provisioning and updates.

---

## Architecture

### System Components
```
┌─────────────────────────────────────────────────────────────┐
│ RHEL 9 Host                                                 │
│                                                             │
│  ┌─────────────────┐  ┌──────────────────────────────┐    │
│  │ Base OS         │  │ NVIDIA Stack                  │    │
│  │ - RHEL Sub Mgr  │  │ - RPMFusion akmod-nvidia      │    │
│  │ - EPEL          │  │ - Container Toolkit           │    │
│  │ - Dev Tools     │  │ - HDMI Audio (snd_hda_intel)  │    │
│  └─────────────────┘  └──────────────────────────────┘    │
│                                                             │
│  ┌─────────────────────────────────────────────────────┐   │
│  │ Service Account: sd-data                            │   │
│  │                                                     │   │
│  │  ┌──────────────────┐  ┌──────────────────┐        │   │
│  │  │ Stable Diffusion │  │ Whisper          │        │   │
│  │  │ - AUTOMATIC1111  │  │ - openai-whisper │        │   │
│  │  │ - ComfyUI        │  │ - yt-dlp         │        │   │
│  │  │ - xformers       │  │ - helper scripts │        │   │
│  │  └──────────────────┘  └──────────────────┘        │   │
│  └─────────────────────────────────────────────────────┘   │
│                                                             │
│  ┌─────────────────────────────────────────────────────┐   │
│  │ Podman Pod: rag-stack                               │   │
│  │                                                     │   │
│  │  ┌─────────────┐  ┌──────────────────────┐         │   │
│  │  │ postgres    │  │ rag_service          │         │   │
│  │  │ (pgvector)  │◄─│ Flask API            │         │   │
│  │  │ :5432       │  │ :8090 → :19090       │         │   │
│  │  │ (internal)  │  │ (exposed to host)    │         │   │
│  │  └─────────────┘  └──────────────────────┘         │   │
│  └─────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
```

All AI workloads run under the `sd-data` service account with rootless Podman for isolation. The RAG stack exposes only a query API (`127.0.0.1:19090`) while keeping PostgreSQL internal to the pod.

---

## Air-Gap Deployment

The repository supports air-gapped environments through pre-staged artifacts:

### Python Wheels
Cache dependencies before deployment:

```bash
# For Stable Diffusion
mkdir -p /tmp/wheels
cd /path/to/stable-diffusion-webui
pip download -r requirements.txt -d /tmp/wheels

# For RAG stack
podman run --rm --security-opt label=disable \
  -v /srv/rag:/app -w /app docker.io/python:3.11 \
  bash -lc "mkdir -p wheels && pip download -r requirements.txt -d wheels"
```

The playbooks detect cached wheels in `/tmp/wheels` (Stable Diffusion) or `/srv/rag/wheels` (RAG stack) and use them automatically via `pip install --find-links`.

### Container Images
Pull images ahead of time:

```bash
# RAG stack
podman pull docker.io/ankane/pgvector:latest
podman pull docker.io/python:3.11

# Save for transfer
podman save -o rag-images.tar docker.io/ankane/pgvector docker.io/python:3.11

# Load on air-gapped host
podman load -i rag-images.tar
```

### Whisper Models
Pre-download models to skip runtime fetches:

```bash
# Models are cached in ~/.cache/whisper by default
# Copy the cache directory to the target host before running the whisper playbook
```

---

## Using the Helper Scripts

After provisioning, switch to the service account or run with sudo:

```bash
# Whisper transcription
sudo -u sd-data -- /home/sd-data/data/whisper-transcribe.sh /path/to/audio.wav --model large
sudo -u sd-data -- /home/sd-data/data/youtube-transcribe.sh "https://youtu.be/clip" --model medium.en

# Stable Diffusion
sudo -u sd-data -- /home/sd-data/data/stable-diffusion-webui/launch.sh
COMFY_LISTEN_ADDR=127.0.0.1 COMFY_PORT=8188 sudo -u sd-data -- /home/sd-data/data/ComfyUI/launch.sh

# RAG queries
curl -X POST http://localhost:19090/query \
  -H 'Content-Type: application/json' \
  -d '{"query":"your search terms"}' | jq
```

The scripts activate the Python virtual environment and call the venv-local executables (`whisper`, `yt-dlp`, `launch.py`).

> **Tip**: The ComfyUI launcher accepts environment overrides such as `COMFY_LISTEN_ADDR`, `COMFY_PORT`, and directory variables (`COMFY_OUTPUT_DIR`, `COMFY_TEMP_DIR`, etc.). When binding to `0.0.0.0`, the wrapper now echoes a friendly `http://127.0.0.1:PORT` URL so it's clear which address to open locally.

---

## Troubleshooting

### GPU Drivers
**Symptom**: NVIDIA module fails to load or nouveau keeps resurfacing.

**Solution**: After installing the `nvidia` role, reboot so the nouveau blacklist takes effect, then verify with `nvidia-smi`. If nouveau persists, set `nvidia_force_clean_reinstall: true` in inventory to trigger the automated cleanup/rebuild sequence (removes stale drivers, rebuilds `initramfs`, reapplies kernel args, and reruns `akmods`).

**Debug Commands**:
```bash
# Check if nouveau is in initramfs
lsinitrd /boot/initramfs-$(uname -r).img | grep nouveau

# Verify NVIDIA module is available
modinfo nvidia

# Check loaded modules
lsmod | grep -E 'nouveau|nvidia'

# Review kernel arguments
grubby --info=ALL | grep args
```

### HDMI Audio
**Symptom**: No audio over HDMI despite NVIDIA drivers installed.

**Solution**: The `base` role now automatically installs `kernel-modules-extra` and loads `snd_hda_intel` + `snd_hda_codec_hdmi`. Verify modules are loaded:
```bash
lsmod | grep snd_hda
aplay -l  # List audio devices
```

### Stable Diffusion Performance
**Symptom**: Slow generation or CUDA errors.

**Solution**: Verify GPU is accessible inside the Python venv:
```bash
sudo -u sd-data bash
source /home/sd-data/data/venv/bin/activate
python -c "import torch; print(torch.cuda.is_available())"
```

If False, check that `nvidia-container-toolkit` is installed and Podman configuration includes the NVIDIA runtime.

### Whisper Transcription
**Symptom**: Model download fails or transcription errors.

**Solution**: Pre-download models to the cache directory:
```bash
mkdir -p /home/sd-data/.cache/whisper
# Manually download .pt files to this directory
```

Models are defined in [roles/whisper/defaults/main.yml](ansible/playbooks/roles/whisper/defaults/main.yml) with SHA-256 checksums.

### RAG Stack
**Symptom**: Connection refused on `/query` endpoint.

**Solution**: Confirm both containers are running:
```bash
podman ps --pod
podman logs -f rag_service
podman logs -f postgres
```

Ensure `llm_rag_api_host_port` matches your curl command (default: `19090`) and that documents exist in `llm_rag_doc_path` (default: `/srv/docs`).

**Re-ingest documents**:
```bash
# Add files to /srv/docs then restart
podman restart rag_service
```

### Ansible Vault
**Symptom**: Vault password errors during playbook runs.

**Solution**: Use `ansible-vault encrypt` on secrets (e.g., RHSM keys). The vault password file path matches the sample Ansible config. Verify the path in [ansible/ansible.cfg](ansible/ansible.cfg):
```ini
vault_password_file = .vault_pass.txt
```

### Vagrant Testing
**Symptom**: Need to test playbooks without affecting production.

**Solution**: Use the disposable VM at [vagrant/rhel9/](vagrant/rhel9/):
```bash
cd vagrant/rhel9
vagrant up
vagrant ssh
```

GPU roles automatically skip when `is_vagrant: true` is detected.

### Temp Directories
**Symptom**: Ansible errors about restricted temp paths.

**Solution**: Set `ANSIBLE_LOCAL_TEMP`/`ANSIBLE_REMOTE_TEMP` to a writable path (see [.env.example](.env.example) for inspiration).

---

## Next Steps

- **Enhance RAG capabilities**: Integrate actual embedding models (e.g., sentence-transformers) to replace deterministic pseudo-embeddings
- **Multi-node support**: Extend inventory groups for distributed inference workers or shared storage backends
- **CI/CD integration**: Add GitHub Actions or Jenkins pipelines to lint and test playbooks automatically
- **Additional model formats**: Extend Stable Diffusion role to support GGUF, ONNX, or other formats
- **Monitoring stack**: Layer in Prometheus + Grafana for GPU metrics and service health

Contributions and refinements are always welcome—open an issue or PR with ideas for improving the automation. Happy building!

---

## Variable Reference

### Global

| Variable | Default | Description |
| --- | --- | --- |
| `enable_subscription` | `true` | Toggle Red Hat subscription registration tasks in the `base` role. |
| `is_vagrant` | `false` | Flags when playbooks run inside Vagrant; used to skip GPU work. |
| `rhsm_org` | `"YOUR_RED_HAT_ORG_ID"` | Red Hat Subscription Manager organization ID. |
| `rhsm_key` | `"YOUR_REDHAT_ACTIVATION_KEY"` | Activation key for RHSM registration. |
| `sd_webui_root` | `"/opt/stable-diffusion-webui"` | Checkout location for the AUTOMATIC1111 repository. |
| `sd_webui_data_dir` | `"/home/sd-data/data"` | Shared data tree for Stable Diffusion and Whisper assets. |
| `users` | See inventory example | List of user/service-account dictionaries consumed by the `users` role. |
| `users[].enable_podman` | `true`/`false` | Enables per-user Podman configuration. |
| `users[].directories` | `[]` | Directories created and owned by each user entry. |

### NVIDIA

| Variable | Default | Description |
| --- | --- | --- |
| `nvidia_repo_el_version` | `"9"` | Enterprise Linux major version used for RPM repository URLs. |
| `nvidia_install_gpu_drivers` | `true` | Feature flag for installing akmod-based GPU drivers. |
| `nvidia_install_container_toolkit` | `true` | Feature flag for installing the NVIDIA container runtime/toolkit. |
| `nvidia_container_runtime_path` | `"/usr/bin/nvidia-container-runtime"` | Expected runtime path injected into Podman configuration. |
| `nvidia_rpmfusion_repo_url` | rpmfusion nonfree URL | Override to supply a custom RPMFusion repository. |
| `nvidia_container_repo_url` | NVIDIA toolkit repo | Location of the libnvidia-container repository definition. |
| `nvidia_force_clean_reinstall` | `false` | Forces cleanup and reinstall of NVIDIA drivers when set to `true`. |
| `nvidia_kernel_args` | See defaults | List of kernel arguments applied via grubby (nouveau blacklist, modesetting). |

### Stable Diffusion

| Variable | Default | Description |
| --- | --- | --- |
| `sd_webui_models_dir` | `"{{ sd_webui_data_dir + '/models' }}"` | Root directory for Stable Diffusion model assets. |
| `sd_webui_venv` | `"{{ sd_webui_data_dir + '/venv' }}"` | Python virtual environment used by Stable Diffusion roles/scripts. |
| `sd_webui_ckpt_dir` | `"{{ sd_webui_models_dir + '/Stable-diffusion' }}"` | Checkpoint directory path passed to `launch.py`. |
| `sd_webui_vae_dir` | `"{{ sd_webui_models_dir + '/VAE' }}"` | VAE model location passed to `launch.py`. |
| `sd_webui_lora_dir` | `"{{ sd_webui_models_dir + '/Lora' }}"` | LoRA model directory used during launches. |
| `sd_webui_embeddings_dir` | `"{{ sd_webui_models_dir + '/embeddings' }}"` | Text embedding directory injected into launch options. |
| `torch_version` | `"torch==2.3.0+cu121"` | Override value for PyTorch version (available for customization). |
| `torchvision_version` | `"torchvision==0.18.0+cu121"` | Override value for torchvision version. |
| `torch_extra_index` | CUDA 12.1 wheel index | Extra pip index for CUDA-enabled PyTorch wheels. |

### Whisper

| Variable | Default | Description |
| --- | --- | --- |
| `whisper_user` | `"sd-data"` | Account used to own Whisper helper scripts and venv. |
| `whisper_group` | `"sd-data"` | Primary group for Whisper assets. |
| `whisper_data_dir` | `"/home/sd-data/data"` | Base directory for Whisper downloads and helper scripts. |
| `whisper_venv` | `"{{ whisper_data_dir }}/venv"` | Python virtual environment path for Whisper tooling. |
| `whisper_ffmpeg_package` | `"ffmpeg"` | System package installed to provide media codecs for Whisper. |
| `whisper_cache_home` | `"/home/{{ whisper_user }}/.cache"` | Base cache directory for Whisper user. |
| `whisper_cache_dir` | `"{{ whisper_cache_home }}/whisper"` | Model cache directory for pre-downloaded Whisper models. |
| `whisper_models` | `["tiny"]` | List of models to pre-download during provisioning. |

### LLM RAG

| Variable | Default | Description |
| --- | --- | --- |
| `llm_rag_service_dir` | `"/srv/rag"` | Service bundle directory containing Flask app and requirements. |
| `llm_rag_doc_path` | `"/srv/docs"` | Document corpus path for ingestion (PDF/TXT/MD files). |
| `llm_rag_pg_data_dir` | `"/srv/pgvector-data"` | PostgreSQL data directory for persistent storage. |
| `llm_rag_pg_user` | `"aiuser"` | PostgreSQL username for the RAG database. |
| `llm_rag_pg_password` | `"change_me"` | PostgreSQL password (override in inventory, consider vaulting). |
| `llm_rag_pg_database` | `"ai_context"` | Database name for storing embeddings and chunks. |
| `llm_rag_pg_host` | `"localhost"` | Postgres hostname (internal to pod, use localhost). |
| `llm_rag_pg_port` | `5432` | Postgres port (internal to pod, not exposed to host). |
| `llm_rag_pod_name` | `"rag-stack"` | Podman pod name for the RAG stack containers. |
| `llm_rag_api_container_port` | `8090` | Flask API port inside the container. |
| `llm_rag_api_host_port` | `19090` | Host port mapped to the Flask API (accessible at `127.0.0.1:19090`). |
| `llm_rag_api_bind_address` | `"127.0.0.1"` | Host address to bind the API port (use `0.0.0.0` for network access). |
| `llm_rag_pg_conn_uri` | Derived | Full PostgreSQL connection URI (auto-generated from above vars). |

All variable names follow lower_snake_case and are prefixed per role (`sd_webui_*`, `whisper_*`, `nvidia_*`, `llm_rag_*`) to avoid collisions, aligning with Ansible best practices. The few global values intentionally remain concise for readability in inventory files.
