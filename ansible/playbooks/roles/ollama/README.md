# Ollama Ansible Role

Deploys and configures Ollama for local LLM inference.

## Features

- Installs Ollama via official install script
- Configures systemd service with environment variables
- Automatically pulls specified models
- GPU/CPU configuration support
- Health check verification

## Requirements

- RHEL/Rocky Linux 9+
- Systemd
- Internet connectivity for model downloads
- (Optional) NVIDIA GPU for accelerated inference

## Role Variables

See [defaults/main.yml](defaults/main.yml) for all variables.

### Key Variables

```yaml
# Models to install
ollama_models:
  - llama2      # Fast, good for testing
  - mistral     # Higher quality responses

# Network binding
ollama_host: "0.0.0.0"
ollama_port: 11434

# GPU settings
ollama_num_gpu: -1  # -1 = auto-detect
```

## Example Playbook

```yaml
- hosts: localhost
  become: true
  roles:
    - ollama
  vars:
    ollama_models:
      - llama2
      - mistral
      - codellama
```

## Usage

### Deploy Ollama

```bash
cd /run/media/justin/MEDIA/ai-build/ansible/playbooks
ansible-playbook ollama_setup.yml
```

### Test Installation

```bash
# List installed models
ollama list

# Test inference
ollama run llama2 "Why is the sky blue?"

# API test
curl http://localhost:11434/api/tags
```

### Use with RAG+LLM

After deploying Ollama, the RAG+LLM service can use it:

```bash
# Start RAG+LLM service with Ollama backend
python /srv/rag/rag_llm_service.py

# Ask a question
rag-ask "How do I configure SELinux in RHEL?"
```

## Model Recommendations

| Model | Size | Speed | Quality | Use Case |
|-------|------|-------|---------|----------|
| llama2 | 3.8GB | Fast | Good | General Q&A, testing |
| mistral | 4.1GB | Fast | Better | Production Q&A |
| codellama | 3.8GB | Fast | Good | Code generation |
| llama2:13b | 7.4GB | Medium | Excellent | High-quality responses |
| mixtral | 26GB | Slow | Excellent | Best quality (requires GPU) |

## GPU Support

### Check GPU Detection

```bash
# Verify GPU is detected
ollama run llama2 "test" --verbose

# Should show GPU offloading in logs
```

### CPU-Only Mode

If no GPU is available, set:

```yaml
ollama_num_gpu: 0
```

Performance will be slower but functional.

## Troubleshooting

### Service Not Starting

```bash
# Check service status
systemctl status ollama

# View logs
journalctl -u ollama -f
```

### Model Download Fails

```bash
# Check internet connectivity
curl -I https://ollama.ai

# Manually pull model
ollama pull llama2
```

### Out of Memory

- Use smaller models (llama2 instead of llama2:13b)
- Reduce `ollama_num_parallel` to 1
- Enable GPU offloading if available

## Integration with RAG Stack

This role works alongside the `llm_rag` role:

```bash
# Deploy full stack
ansible-playbook llm_ingest.yml    # RAG service
ansible-playbook ollama_setup.yml   # Ollama

# Test integration
rag-ask "How do I create a systemd service?"
```

## License

MIT

## Author

Created for AI-Build project
