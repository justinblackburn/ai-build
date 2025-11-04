# `stable_diffusion` Role

Deploys AUTOMATIC1111 Stable Diffusion WebUI and ComfyUI with GPU acceleration, Python virtual environments, and hardened launch scripts. All workloads run under the `sd-data` service account.

---

## Purpose

The `stable_diffusion` role provides a complete Stable Diffusion stack:

| Component | Description |
|-----------|-------------|
| **AUTOMATIC1111 WebUI** | Full installation of the popular Stable Diffusion web interface |
| **ComfyUI** | Node-based Stable Diffusion UI for advanced workflows |
| **Python Virtual Environment** | Isolated Python 3.x environment with PyTorch CUDA 12.1 |
| **xformers** | Memory-efficient attention mechanisms (built from source) |
| **Model Directories** | Organized structure for checkpoints, VAE, LoRA, embeddings |
| **Launch Scripts** | Hardened bash wrappers with environment variable support |
| **Air-Gap Support** | Optional wheel caching for offline installations |

---

## Variables

Defined in [defaults/main.yml](defaults/main.yml) and overrideable in inventory:

```yaml
# Installation paths
sd_webui_root: /opt/stable-diffusion-webui      # AUTOMATIC1111 git clone location
sd_webui_data_dir: /home/sd-data/data           # Shared data directory

# PyTorch versions (CUDA 12.1 wheels)
torch_version: "torch==2.3.0+cu121"
torchvision_version: "torchvision==0.18.0+cu121"
torch_extra_index: "https://download.pytorch.org/whl/cu121"

# Derived paths (auto-calculated, override if needed)
sd_webui_models_dir: "{{ sd_webui_data_dir }}/models"
sd_webui_venv: "{{ sd_webui_data_dir }}/venv"
sd_webui_ckpt_dir: "{{ sd_webui_models_dir }}/Stable-diffusion"
sd_webui_vae_dir: "{{ sd_webui_models_dir }}/VAE"
sd_webui_lora_dir: "{{ sd_webui_models_dir }}/Lora"
sd_webui_embeddings_dir: "{{ sd_webui_models_dir }}/embeddings"
```

---

## Role Workflow

### 1. Directory Structure Creation
Creates all required directories owned by `sd-data:sd-data`:
- `{{ sd_webui_root }}` - AUTOMATIC1111 repository
- `{{ sd_webui_data_dir }}` - Shared data root
- `{{ sd_webui_venv }}` - Python virtual environment
- `{{ sd_webui_ckpt_dir }}` - Stable Diffusion checkpoints
- `{{ sd_webui_vae_dir }}` - VAE models
- `{{ sd_webui_lora_dir }}` - LoRA models
- `{{ sd_webui_embeddings_dir }}` - Text embeddings

### 2. Dependency Installation
- Installs system packages: `git`, `python3`, `python3-pip`, `python3-virtualenv`
- Creates `/tmp/wheels` for optional wheel caching

### 3. Repository Cloning
- Clones AUTOMATIC1111/stable-diffusion-webui from GitHub to `{{ sd_webui_root }}`
- Uses `update: no` to preserve local changes on reruns

### 4. Python Virtual Environment
- Creates venv at `{{ sd_webui_venv }}`
- Installs requirements from `{{ sd_webui_root }}/requirements.txt`
- Uses cached wheels from `/tmp/wheels` if available (air-gap friendly)

### 5. PyTorch Installation
Installs CUDA-enabled PyTorch wheels:
```bash
pip install torch==2.3.0+cu121 torchvision==0.18.0+cu121 \
  --extra-index-url https://download.pytorch.org/whl/cu121
```

### 6. xformers Build
Compiles xformers from source for optimized memory usage:
```bash
TORCH_CUDA_ARCH_LIST="8.6" pip install xformers==0.0.26.post1 --no-build-isolation
```
(Build includes `setuptools`, `wheel`, `ninja` dependencies)

### 7. ComfyUI Installation
- Clones ComfyUI repository to `{{ sd_webui_data_dir }}/ComfyUI`
- Installs requirements in the same shared venv
- Creates launch wrapper at `{{ sd_webui_data_dir }}/ComfyUI/launch.sh`

### 8. Launch Script Creation
Drops hardened launch scripts for both UIs with features:
- Automatic venv activation
- Environment variable support for ports and paths
- GPU detection and CUDA availability checks
- Friendly URL output for `0.0.0.0` bindings

---

## Prerequisites

- **Service Account**: `users` role must run first to create `sd-data` user
- **GPU Drivers**: `nvidia` role should complete before this role for GPU acceleration
- **Python**: Python 3.9+ from `base` role
- **Network Access** (unless using air-gap mode):
  - `github.com` - Repository cloning
  - `download.pytorch.org` - PyTorch wheels
  - `pypi.org` - Python packages

---

## Usage

### Standalone Execution

```bash
ansible-playbook playbooks/stable_diffusion.yml --ask-become-pass
```

### Air-Gap Deployment

Pre-cache Python wheels before running the role:

```bash
# On a machine with internet access
git clone https://github.com/AUTOMATIC1111/stable-diffusion-webui.git
cd stable-diffusion-webui
mkdir /tmp/wheels
pip download -r requirements.txt -d /tmp/wheels
pip download torch==2.3.0+cu121 torchvision==0.18.0+cu121 \
  --extra-index-url https://download.pytorch.org/whl/cu121 -d /tmp/wheels

# Transfer /tmp/wheels to target host
scp -r /tmp/wheels target-host:/tmp/
```

The role automatically detects cached wheels via `--find-links /tmp/wheels`.

---

## Launching the Web UIs

### AUTOMATIC1111 WebUI

```bash
# As sd-data user directly
sudo -u sd-data -- /home/sd-data/data/stable-diffusion-webui/launch.sh

# Or from sd-data shell
sudo -i -u sd-data
cd ~/data/stable-diffusion-webui
./launch.sh
```

Default URL: `http://127.0.0.1:7860`

**Launch Script Features**:
- Activates venv automatically
- Passes all command-line arguments to `launch.py`
- Examples:
  ```bash
  ./launch.sh --listen --port 8080
  ./launch.sh --xformers --medvram
  ```

### ComfyUI

```bash
# Basic launch (127.0.0.1:8188)
sudo -u sd-data -- /home/sd-data/data/ComfyUI/launch.sh

# Custom host and port
COMFY_LISTEN_ADDR=0.0.0.0 COMFY_PORT=9000 \
  sudo -u sd-data -- /home/sd-data/data/ComfyUI/launch.sh
```

**Environment Variables**:
- `COMFY_LISTEN_ADDR` - Bind address (default: `127.0.0.1`)
- `COMFY_PORT` - Listen port (default: `8188`)
- `COMFY_OUTPUT_DIR` - Output directory override
- `COMFY_TEMP_DIR` - Temporary files directory
- `COMFY_INPUT_DIR` - Input directory override

When binding to `0.0.0.0`, the script displays both the network address and `http://127.0.0.1:PORT` for clarity.

---

## Post-Installation Verification

### Check Installation

```bash
# Verify directories
ls -la /home/sd-data/data/
ls -la /opt/stable-diffusion-webui/

# Check venv and PyTorch
sudo -u sd-data bash -c "source /home/sd-data/data/venv/bin/activate && python -c 'import torch; print(torch.cuda.is_available())'"

# Expected output: True (if GPU drivers installed)
```

### Test GPU Access

```bash
sudo -u sd-data bash -c "source /home/sd-data/data/venv/bin/activate && python -c 'import torch; print(torch.cuda.get_device_name(0))'"

# Expected: Your GPU name (e.g., "NVIDIA GeForce RTX 4090")
```

---

## Troubleshooting

### PyTorch CUDA Not Available

**Symptom**: `torch.cuda.is_available()` returns `False`.

**Debug**:
```bash
sudo -u sd-data bash
source ~/data/venv/bin/activate
python -c "import torch; print(torch.version.cuda); print(torch.cuda.is_available())"
nvidia-smi
```

**Solution**:
- Verify NVIDIA drivers are loaded (`nvidia-smi` works)
- Ensure PyTorch CUDA wheels installed (not CPU-only versions):
  ```bash
  pip list | grep torch
  # Should show: torch 2.3.0+cu121
  ```
- Reinstall PyTorch if needed:
  ```bash
  pip uninstall torch torchvision
  pip install torch==2.3.0+cu121 torchvision==0.18.0+cu121 \
    --extra-index-url https://download.pytorch.org/whl/cu121
  ```

### xformers Build Failures

**Symptom**: xformers installation fails during `pip install`.

**Debug**:
```bash
# Check CUDA version
nvcc --version

# Verify development tools
gcc --version
ninja --version
```

**Solution**:
- Ensure `nvidia` role completed (provides CUDA toolkit)
- Verify `@Development Tools` installed from `base` role
- Try building with verbose output:
  ```bash
  sudo -u sd-data bash
  source ~/data/venv/bin/activate
  TORCH_CUDA_ARCH_LIST="8.6" pip install xformers==0.0.26.post1 --no-build-isolation -v
  ```

### AUTOMATIC1111 Won't Start

**Symptom**: `launch.sh` exits with errors.

**Debug**:
```bash
sudo -u sd-data bash
cd /opt/stable-diffusion-webui
source /home/sd-data/data/venv/bin/activate
python launch.py --help
```

**Common Issues**:
- Missing Python dependencies: Run `pip install -r requirements.txt`
- Port already in use: Change port with `./launch.sh --port 7861`
- Permission errors: Ensure all files owned by `sd-data`:
  ```bash
  sudo chown -R sd-data:sd-data /opt/stable-diffusion-webui /home/sd-data/data
  ```

### ComfyUI Environment Variables Not Working

**Symptom**: Custom `COMFY_PORT` ignored.

**Solution**: Ensure variables are exported before the script:
```bash
# Correct
export COMFY_PORT=9000
sudo -u sd-data --preserve-env=COMFY_PORT -- /home/sd-data/data/ComfyUI/launch.sh

# Or inline
COMFY_PORT=9000 sudo -u sd-data -- /home/sd-data/data/ComfyUI/launch.sh
```

### Out of Memory (OOM) Errors

**Symptom**: Generation fails with CUDA OOM.

**Solution**: Use launch arguments to reduce memory usage:
```bash
# AUTOMATIC1111
./launch.sh --medvram          # For 6-8GB VRAM
./launch.sh --lowvram          # For 4GB VRAM
./launch.sh --xformers         # Enable xformers optimization

# ComfyUI (edit launch.sh to add args)
python main.py --lowvram
```

---

## Model Management

### Adding Checkpoints

```bash
# Copy .safetensors or .ckpt files to:
/home/sd-data/data/models/Stable-diffusion/

# Example
sudo cp my-model.safetensors /home/sd-data/data/models/Stable-diffusion/
sudo chown sd-data:sd-data /home/sd-data/data/models/Stable-diffusion/my-model.safetensors
```

Restart the WebUI to see new models.

### Adding VAE

```bash
sudo cp my-vae.safetensors /home/sd-data/data/models/VAE/
sudo chown sd-data:sd-data /home/sd-data/data/models/VAE/my-vae.safetensors
```

### Adding LoRA

```bash
sudo cp my-lora.safetensors /home/sd-data/data/models/Lora/
sudo chown sd-data:sd-data /home/sd-data/data/models/Lora/my-lora.safetensors
```

### Adding Embeddings

```bash
sudo cp my-embedding.pt /home/sd-data/data/models/embeddings/
sudo chown sd-data:sd-data /home/sd-data/data/models/embeddings/my-embedding.pt
```

---

## Directory Structure

After role execution:

```
/home/sd-data/data/
├── venv/                              # Shared Python virtual environment
├── models/
│   ├── Stable-diffusion/             # Checkpoint models (.safetensors, .ckpt)
│   ├── VAE/                          # VAE models
│   ├── Lora/                         # LoRA models
│   └── embeddings/                   # Text embeddings
├── stable-diffusion-webui/           # Symlink to /opt/stable-diffusion-webui
│   └── launch.sh                     # AUTOMATIC1111 launcher
└── ComfyUI/                          # ComfyUI installation
    ├── main.py
    └── launch.sh                     # ComfyUI launcher

/opt/stable-diffusion-webui/          # AUTOMATIC1111 repository
├── launch.py
├── webui.py
├── requirements.txt
└── ...
```

---

## Performance Tuning

### CUDA Architecture Optimization

The role sets `TORCH_CUDA_ARCH_LIST="8.6"` for xformers (RTX 30xx/40xx series). For older GPUs:

```yaml
# In inventory or playbook
xformers_cuda_arch: "7.5"  # RTX 20xx (Turing)
xformers_cuda_arch: "8.0"  # A100 (Ampere data center)
```

### PyTorch Version Pinning

Override PyTorch versions for specific CUDA compatibility:

```yaml
# For CUDA 11.8
torch_version: "torch==2.3.0+cu118"
torchvision_version: "torchvision==0.18.0+cu118"
torch_extra_index: "https://download.pytorch.org/whl/cu118"
```

---

## Related Roles

- **base**: Provides Python, Git, and development tools
- **nvidia**: Required for GPU acceleration
- **users**: Must create `sd-data` service account first
- **podman**: Not used by this role (runs native Python, not containers)

---

## Security Notes

- All workloads run as unprivileged `sd-data` user (no root access)
- Default bindings use `127.0.0.1` (localhost only)
- To expose over network, use `--listen` or `COMFY_LISTEN_ADDR=0.0.0.0`
- No authentication enabled by default - use reverse proxy with auth if exposing publicly
