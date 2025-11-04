# `whisper` Role

Deploys OpenAI Whisper for automatic speech recognition with YouTube download support, model pre-caching, and helper scripts. Shares the Python virtual environment with Stable Diffusion under the `sd-data` service account.

---

## Purpose

The `whisper` role provides AI-powered transcription capabilities:

| Component | Description |
|-----------|-------------|
| **OpenAI Whisper** | State-of-the-art speech recognition model from OpenAI |
| **yt-dlp** | YouTube video/audio downloader for transcription |
| **Model Pre-Download** | Caches Whisper models to avoid runtime downloads |
| **Helper Scripts** | Bash wrappers for audio file and YouTube transcription |
| **Cookie Support** | Browser cookie extraction for age-restricted content |
| **Shared Environment** | Reuses `sd-data` venv to minimize disk usage |

---

## Variables

Defined in [defaults/main.yml](defaults/main.yml) and overrideable in inventory:

```yaml
# Service account
whisper_user: sd-data
whisper_group: sd-data

# Paths
whisper_data_dir: /home/sd-data/data
whisper_venv: "{{ whisper_data_dir }}/venv"         # Shared with stable_diffusion role
whisper_cache_home: "/home/{{ whisper_user }}/.cache"
whisper_cache_dir: "{{ whisper_cache_home }}/whisper"

# System packages
whisper_ffmpeg_package: ffmpeg                       # Media codec library

# Model pre-download
whisper_models:
  - tiny                                             # Default: only tiny model pre-cached

# Model URLs and checksums (full list in defaults/main.yml)
whisper_model_urls:
  tiny:
    url: "https://openaipublic.azureedge.net/main/whisper/models/65147644a518d12f04e32d6f3b26facc3f8dd46e5390956a9424a650c0ce22b9/tiny.pt"
    sha256: "65147644a518d12f04e32d6f3b26facc3f8dd46e5390956a9424a650c0ce22b9"
  # ... additional models: tiny.en, base, base.en, small, small.en, medium, medium.en,
  #     large-v1, large-v2, large-v3, large (alias for v3), large-v3-turbo, turbo
```

**Available Models** (smallest to largest):
- `tiny` / `tiny.en` - ~39M parameters, fastest, lowest accuracy
- `base` / `base.en` - ~74M parameters
- `small` / `small.en` - ~244M parameters
- `medium` / `medium.en` - ~769M parameters
- `large-v1` / `large-v2` / `large-v3` / `large` - ~1550M parameters, best accuracy
- `large-v3-turbo` / `turbo` - Optimized large model, faster inference

Models with `.en` suffix are English-only and slightly faster/more accurate for English content.

---

## Role Workflow

### 1. Virtual Environment Setup
- Ensures `{{ whisper_venv }}` exists (created by `stable_diffusion` role if present)
- Creates venv if not already available
- Owned by `{{ whisper_user }}:{{ whisper_group }}`

### 2. FFmpeg Installation
- Installs `ffmpeg` system package for audio/video processing
- Required for Whisper audio decoding and yt-dlp format conversion

### 3. Whisper Installation
- Installs `openai-whisper` package in the venv
- Installs `yt-dlp` for YouTube audio extraction

### 4. Cache Directory Creation
- Creates `{{ whisper_cache_home }}` (`/home/sd-data/.cache`)
- Creates `{{ whisper_cache_dir }}` (`/home/sd-data/.cache/whisper`)
- Proper ownership for model downloads

### 5. Model Pre-Download
For each model in `whisper_models` list:
- Downloads `.pt` file from Azure CDN to cache directory
- Verifies SHA-256 checksum to ensure integrity
- Skips if model already exists with correct checksum

### 6. Helper Script Deployment
Creates two bash scripts in `{{ whisper_data_dir }}`:

**whisper-transcribe.sh**:
```bash
#!/bin/bash
# Transcribes local audio/video files
# Usage: whisper-transcribe.sh FILE [--model medium] [--language en]
```

**youtube-transcribe.sh**:
```bash
#!/bin/bash
# Downloads and transcribes YouTube videos
# Usage: youtube-transcribe.sh URL [--model large] [--cookies-from-browser firefox]
```

Both scripts:
- Activate the venv automatically
- Pass all arguments to Whisper
- Support model selection via `--model` flag
- Output transcriptions to current working directory

---

## Prerequisites

- **Service Account**: `users` role must create `sd-data` user first
- **Python Environment**: `stable_diffusion` role should run first to create shared venv (or venv will be created automatically)
- **FFmpeg**: Role installs from EPEL (enabled by `base` role)
- **Network Access** (for model downloads):
  - `openaipublic.azureedge.net` - Whisper model files
  - `youtube.com` / `youtu.be` - YouTube transcription (optional)

---

## Usage

### Standalone Execution

```bash
ansible-playbook playbooks/whisper.yml --ask-become-pass
```

### Pre-Download Specific Models

Override the default model list in inventory:

```yaml
# In inventory/group_vars/all.yml
whisper_models:
  - tiny
  - base
  - medium
  - large-v3-turbo
```

Then run the playbook to cache all specified models.

---

## Transcribing Audio Files

### Basic Transcription

```bash
sudo -u sd-data -- /home/sd-data/data/whisper-transcribe.sh audio.mp3
```

Output: `audio.mp3.txt` in current directory

### Specify Model and Language

```bash
sudo -u sd-data -- /home/sd-data/data/whisper-transcribe.sh audio.wav \
  --model large-v3-turbo \
  --language en \
  --output_format srt
```

### Supported Formats
- Audio: MP3, WAV, FLAC, M4A, OGG, AAC
- Video: MP4, MKV, AVI, MOV, WEBM (audio track extracted)

### Whisper CLI Options

Pass any Whisper argument through the helper script:

```bash
--model MODEL           # Model size (tiny, base, small, medium, large, turbo)
--language LANG         # Source language (en, es, fr, etc.) or auto-detect
--task transcribe       # Transcribe to source language (default)
--task translate        # Translate to English
--output_format FORMAT  # txt, vtt, srt, tsv, json (default: all)
--output_dir DIR        # Output directory (default: current)
--verbose True          # Show detailed progress
--temperature 0.0       # Sampling temperature (0 = deterministic)
```

---

## Transcribing YouTube Videos

### Basic YouTube Transcription

```bash
sudo -u sd-data -- /home/sd-data/data/youtube-transcribe.sh "https://youtu.be/VIDEO_ID"
```

Output: `VIDEO_TITLE.txt`

### With Model Selection

```bash
sudo -u sd-data -- /home/sd-data/data/youtube-transcribe.sh \
  "https://www.youtube.com/watch?v=VIDEO_ID" \
  --model medium.en
```

### Age-Restricted Content

For age-gated videos, extract browser cookies:

```bash
# Firefox
sudo -u sd-data -- /home/sd-data/data/youtube-transcribe.sh \
  "https://youtu.be/VIDEO_ID" \
  --cookies-from-browser firefox

# Chrome
sudo -u sd-data -- /home/sd-data/data/youtube-transcribe.sh \
  "https://youtu.be/VIDEO_ID" \
  --cookies-from-browser chrome
```

**Note**: The browser must be running as the `sd-data` user for cookie extraction to work.

### Download Without Transcription

Use `yt-dlp` directly:

```bash
sudo -u sd-data bash
source /home/sd-data/data/venv/bin/activate
yt-dlp -x --audio-format mp3 "https://youtu.be/VIDEO_ID"
```

---

## Post-Installation Verification

### Check Installation

```bash
# Verify Whisper installed
sudo -u sd-data bash -c "source /home/sd-data/data/venv/bin/activate && whisper --help"

# Check yt-dlp
sudo -u sd-data bash -c "source /home/sd-data/data/venv/bin/activate && yt-dlp --version"

# Verify FFmpeg
ffmpeg -version
```

### List Cached Models

```bash
ls -lh /home/sd-data/.cache/whisper/
# Should show .pt files for each pre-downloaded model
```

### Test Transcription

```bash
# Create test audio (5 seconds of silence)
ffmpeg -f lavfi -i anullsrc=r=44100:cl=mono -t 5 -q:a 9 -acodec libmp3lame test.mp3

# Transcribe with tiny model (fast)
sudo -u sd-data -- /home/sd-data/data/whisper-transcribe.sh test.mp3 --model tiny
```

---

## Troubleshooting

### Model Download Failures

**Symptom**: Role fails during model pre-download tasks.

**Debug**:
```bash
# Test manual download
curl -I https://openaipublic.azureedge.net/main/whisper/models/65147644a518d12f04e32d6f3b26facc3f8dd46e5390956a9424a650c0ce22b9/tiny.pt

# Check cache permissions
ls -la /home/sd-data/.cache/whisper/
```

**Solution**:
- Verify network access to `openaipublic.azureedge.net`
- Ensure cache directory is writable by `sd-data`
- For air-gap: manually download `.pt` files to cache directory with correct ownership

### Whisper Command Not Found

**Symptom**: `whisper: command not found` when running helper scripts.

**Debug**:
```bash
sudo -u sd-data bash
source /home/sd-data/data/venv/bin/activate
which whisper
pip list | grep whisper
```

**Solution**:
```bash
# Reinstall Whisper
sudo -u sd-data bash
source /home/sd-data/data/venv/bin/activate
pip install --upgrade openai-whisper
```

### FFmpeg Missing or Incompatible

**Symptom**: `ffmpeg: command not found` or codec errors during transcription.

**Debug**:
```bash
ffmpeg -version
ffmpeg -codecs | grep mp3
```

**Solution**:
```bash
# Reinstall FFmpeg from EPEL
sudo dnf reinstall ffmpeg

# Verify EPEL enabled
sudo dnf repolist | grep epel
```

### YouTube Download Fails

**Symptom**: `yt-dlp` errors with "Video unavailable" or "Sign in to confirm your age".

**Debug**:
```bash
sudo -u sd-data bash
source /home/sd-data/data/venv/bin/activate
yt-dlp -F "https://youtu.be/VIDEO_ID"  # List available formats
```

**Solutions**:

**For age-restricted content**:
```bash
# Use browser cookies
--cookies-from-browser firefox
```

**For geo-blocked content**:
```bash
# Use proxy (requires network access)
yt-dlp --proxy socks5://127.0.0.1:1080 URL
```

**Update yt-dlp**:
```bash
sudo -u sd-data bash
source /home/sd-data/data/venv/bin/activate
pip install --upgrade yt-dlp
```

### Transcription Too Slow

**Symptom**: Large model takes hours to transcribe.

**Solution**: Use smaller/faster models:
- `tiny` - Fastest, least accurate (~5-10x real-time on CPU)
- `base` - Good balance (~2-3x real-time on CPU)
- `medium` - High accuracy, slower (~1x real-time on CPU)
- `large-v3-turbo` - Best accuracy, optimized speed (requires GPU for real-time)

**Enable GPU acceleration** (if `nvidia` role installed):
```bash
sudo -u sd-data bash
source /home/sd-data/data/venv/bin/activate
python -c "import torch; print(torch.cuda.is_available())"
# Should return True - Whisper automatically uses GPU if available
```

### Out of Memory Errors

**Symptom**: Transcription crashes with OOM on large files.

**Solution**: Process in smaller chunks:
```bash
# Split audio into 10-minute segments
ffmpeg -i long-audio.mp3 -f segment -segment_time 600 -c copy chunk_%03d.mp3

# Transcribe each chunk
for file in chunk_*.mp3; do
  whisper-transcribe.sh "$file" --model medium
done
```

---

## Model Selection Guide

| Model | Parameters | English-only | Multilingual | Relative Speed | Use Case |
|-------|-----------|--------------|--------------|----------------|----------|
| `tiny` | 39M | `tiny.en` | `tiny` | 32x | Quick drafts, real-time subtitles |
| `base` | 74M | `base.en` | `base` | 16x | Good balance for most content |
| `small` | 244M | `small.en` | `small` | 6x | High accuracy for podcasts |
| `medium` | 769M | `medium.en` | `medium` | 2x | Production transcription |
| `large-v3` | 1550M | - | `large` | 1x | Maximum accuracy |
| `turbo` | 809M | - | `turbo` | 8x | Fast large model (v3-turbo) |

**Speed is relative to real-time on CPU. GPU acceleration provides 5-10x speedup.**

---

## Air-Gap Deployment

### Pre-Download All Models

On a machine with internet access:

```bash
# Download all model files
mkdir -p whisper-models
cd whisper-models

# URLs from defaults/main.yml
wget https://openaipublic.azureedge.net/main/whisper/models/65147644a518d12f04e32d6f3b26facc3f8dd46e5390956a9424a650c0ce22b9/tiny.pt
wget https://openaipublic.azureedge.net/main/whisper/models/ed3a0b6b1c0edf879ad9b11b1af5a0e6ab5db9205f891f668f8b0e6c6326e34e/base.pt
# ... etc for other models

# Transfer to air-gapped host
scp *.pt target-host:/home/sd-data/.cache/whisper/
```

On air-gapped host:
```bash
sudo chown -R sd-data:sd-data /home/sd-data/.cache/whisper/
```

---

## Example Workflows

### Podcast Transcription

```bash
# Download podcast episode
wget https://example.com/podcast-episode.mp3

# Transcribe with timestamps
sudo -u sd-data -- /home/sd-data/data/whisper-transcribe.sh \
  podcast-episode.mp3 \
  --model medium.en \
  --output_format srt

# Output: podcast-episode.mp3.srt (with timestamps)
```

### Meeting Recording Transcription

```bash
# Record with ffmpeg or use existing file
sudo -u sd-data -- /home/sd-data/data/whisper-transcribe.sh \
  meeting-2024-01-15.m4a \
  --model base \
  --language en \
  --output_format txt \
  --output_dir /home/sd-data/transcripts/
```

### YouTube Lecture Series

```bash
# Create list of URLs
cat > lectures.txt <<EOF
https://youtu.be/VIDEO1
https://youtu.be/VIDEO2
https://youtu.be/VIDEO3
EOF

# Batch transcribe
while read url; do
  sudo -u sd-data -- /home/sd-data/data/youtube-transcribe.sh \
    "$url" --model medium --output_format srt
done < lectures.txt
```

---

## Related Roles

- **base**: Provides Python and enables EPEL for FFmpeg
- **users**: Creates `sd-data` service account
- **stable_diffusion**: Creates shared venv (optional, role will create venv if missing)
- **nvidia**: Enables GPU acceleration for faster transcription (optional)

---

## Security Notes

- All transcription runs as unprivileged `sd-data` user
- No network services exposed (CLI tools only)
- YouTube cookies stored in `sd-data` home directory (protected by file permissions)
- Model checksums verified via SHA-256 before use
