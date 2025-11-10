# RAG+LLM Stack Playbooks

Complete retrieval-augmented generation (RAG) stack with LLM integration for local document Q&A.

## Available Deployments

### 1. **PostgreSQL + pgvector** (Recommended for getting started)
Simple, mature, lower resource requirements.

**Playbook**: [rag_llm_stack.yml](rag_llm_stack.yml)

**Components**:
- PostgreSQL 15 with pgvector extension
- RAG service (Flask API)
- RAG+LLM service (question answering)
- Ollama (local LLM inference)

### 2. **Weaviate** (Recommended for production/scale)
Purpose-built vector DB, better performance at scale, advanced features.

**Playbook**: [rag_llm_weaviate.yml](rag_llm_weaviate.yml)

**Components**:
- Weaviate vector database
- RAG service (Flask API)
- RAG+LLM service (question answering)
- Ollama (local LLM inference)

**See**: [VECTOR_BACKEND_COMPARISON.md](VECTOR_BACKEND_COMPARISON.md) for detailed comparison.

---

## Architecture

```
Question → rag-ask CLI → RAG+LLM Service → RAG Service + Ollama → Answer
                                               ↓
                                    PostgreSQL/Weaviate
```

---

## Prerequisites

- RHEL 9 / Rocky 9 host with Podman 5.x and Ansible 2.14+.
- Ansible control user with sudo privileges (the play escalates where required).
- Local document corpus available on the target host (PDF/TXT/MD).

SELinux is left enforcing; the role explicitly:

- Forces Podman to use `crun` (`/etc/containers/containers.conf.d/zz-llm-rag-runtime.conf`).
- Disables label relabeling per-container (`security_opt: label=disable`) because data volumes live under `/srv`.
- Runs both containers inside a shared pod to avoid exposing Postgres externally.

---

## Quick Start

### Option 1: PostgreSQL + pgvector (Simple)

```bash
# Deploy complete stack
cd /run/media/justin/MEDIA/ai-build/ansible/playbooks
ansible-playbook rag_llm_stack.yml

# Ingest documents
sudo rag-ingest --verbose

# Ask questions
rag-ask "How do I configure SELinux in RHEL?"
```

### Option 2: Weaviate (Advanced)

```bash
# Deploy complete stack
cd /run/media/justin/MEDIA/ai-build/ansible/playbooks
ansible-playbook rag_llm_weaviate.yml

# Ingest documents
sudo rag-ingest --verbose

# Ask questions
rag-ask "How do I configure SELinux in RHEL?"
```

### Verify Deployment

```bash
# Check containers
sudo podman ps --pod

# Test RAG service
curl http://localhost:19090/stats

# Test Ollama
ollama list

# Test end-to-end
rag-ask "What is systemd?"
```

---

## CLI Tools

### rag-ask - Question Answering

```bash
# Ask with LLM generation (full answer)
rag-ask "How do I create a systemd service?"

# RAG retrieval only (document chunks)
rag-ask --rag-only "RHCSA exam"

# Use specific LLM backend
rag-ask --backend mistral "What is SELinux?"
rag-ask --backend anthropic "Question?"  # Requires ANTHROPIC_API_KEY
rag-ask --backend openai "Question?"     # Requires OPENAI_API_KEY

# More options
rag-ask --rag-limit 10 "Question?"       # More context
rag-ask --json "Question?"               # JSON output
```

### rag-ingest - Document Indexing

```bash
# Ingest all documents
sudo rag-ingest

# Verbose progress
sudo rag-ingest --verbose

# Custom doc path
sudo rag-ingest --doc-path /path/to/docs
```

### rag-backup - Database Backup

```bash
# Manual backup
sudo rag-backup

# Backups stored in /srv/rag-backups/
# Auto-backup runs daily via systemd timer
```

---

## Day-2 Operations

### Adding New Documents

```bash
# 1. Copy documents to /srv/docs
sudo cp -r /path/to/new/docs /srv/docs/category/

# 2. Re-run ingestion (safe, deduplicates)
sudo rag-ingest --verbose

# 3. Verify
curl http://localhost:19090/stats
```

### Changing LLM Models

```bash
# Pull new model
ollama pull codellama

# Update service (edit defaults/main.yml or set env var)
podman exec rag_llm_service \
  bash -c "export OLLAMA_MODEL=codellama && python /app/rag_llm_service.py"
```

### Monitoring

```bash
# View logs
sudo podman logs -f rag_service
sudo podman logs -f rag_llm_service
sudo podman logs -f weaviate  # or postgres

# Check backup timer
systemctl status rag-backup.timer
journalctl -u rag-backup.service

# Resource usage
sudo podman stats
```

### Removing the Stack

```bash
# Remove containers
sudo podman pod rm -f rag-stack

# Clean data (optional)
sudo rm -rf /srv/weaviate-data  # or /srv/pgvector-data
sudo rm -rf /srv/rag-backups
```

---

## Documentation

- **[VECTOR_BACKEND_COMPARISON.md](VECTOR_BACKEND_COMPARISON.md)** - PostgreSQL vs Weaviate comparison
- **[roles/llm_rag/README.md](roles/llm_rag/README.md)** - PostgreSQL+pgvector role details
- **[roles/llm_rag_weaviate/README.md](roles/llm_rag_weaviate/README.md)** - Weaviate role details
- **[roles/ollama/README.md](roles/ollama/README.md)** - Ollama deployment
- **[roles/llm_rag/files/DEPLOYMENT_GUIDE.md](roles/llm_rag/files/DEPLOYMENT_GUIDE.md)** - Full deployment guide
- **[roles/llm_rag/files/RAG_LLM_README.md](roles/llm_rag/files/RAG_LLM_README.md)** - RAG+LLM integration

---

## Playbook Overview

| Playbook | Components | Use Case |
|----------|-----------|----------|
| [rag_llm_stack.yml](rag_llm_stack.yml) | PostgreSQL+pgvector + RAG + Ollama | Getting started, development |
| [rag_llm_weaviate.yml](rag_llm_weaviate.yml) | Weaviate + RAG + Ollama | Production, large scale |
| [ollama_setup.yml](ollama_setup.yml) | Ollama only | Just LLM inference |
| [llm_ingest.yml](llm_ingest.yml) | Legacy RAG only | Basic RAG (no LLM) |

---

## Architecture Details

### PostgreSQL Stack

```
rag-stack pod:
  ├── postgres (port 5432, internal)
  ├── rag_service (port 8090 → 19090)
  └── rag_llm_service (port 8091)

Ollama (systemd service, port 11434)
```

### Weaviate Stack

```
rag-stack pod:
  ├── weaviate (port 8080, internal)
  ├── rag_service (port 8090 → 19090)
  └── rag_llm_service (port 8091)

Ollama (systemd service, port 11434)
```

---

## Troubleshooting

### Common Issues

**Service won't start:**
```bash
# Check logs
sudo podman logs rag_service

# Verify pod network
sudo podman pod inspect rag-stack
```

**Ollama not responding:**
```bash
# Check service
systemctl status ollama

# Test API
curl http://localhost:11434/api/tags
```

**Permission denied on /srv/docs:**
```bash
# Fix ownership
sudo chown -R root:root /srv/docs
sudo chmod -R 755 /srv/docs
```

**Out of memory during ingestion:**
```bash
# Process in batches (already implemented via dedup)
# Or increase container memory limits
```

For detailed troubleshooting, see role-specific READMEs.

