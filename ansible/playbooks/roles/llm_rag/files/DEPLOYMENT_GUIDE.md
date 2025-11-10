# RAG+LLM Stack Deployment Guide

Complete guide for deploying the RAG (Retrieval Augmented Generation) + LLM stack.

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│                    Your Question                         │
└────────────────────┬────────────────────────────────────┘
                     │
                     ▼
         ┌───────────────────────┐
         │   rag-ask CLI Tool    │ (Port 8091)
         │  (RAG+LLM Service)    │
         └───────────┬───────────┘
                     │
        ┌────────────┴────────────┐
        │                         │
        ▼                         ▼
┌───────────────┐         ┌──────────────┐
│  RAG Service  │         │    Ollama    │
│  (Port 8090)  │         │ (Port 11434) │
└───────┬───────┘         └──────────────┘
        │
        ▼
┌───────────────┐
│  PostgreSQL   │
│  + pgvector   │
└───────────────┘
```

## Components

1. **PostgreSQL with pgvector** - Vector database for embeddings
2. **RAG Service** - Document retrieval via semantic search
3. **Ollama** - Local LLM inference (llama2, mistral, etc.)
4. **RAG+LLM Service** - Combines retrieval + generation
5. **CLI Tools** - `rag-ask`, `rag-ingest`, `rag-backup`

## Quick Start

### 1. Deploy Complete Stack

```bash
cd /run/media/justin/MEDIA/ai-build/ansible/playbooks

# Deploy everything: Ollama + RAG + LLM integration
ansible-playbook rag_llm_stack.yml
```

This will:
- Install Ollama and pull llama2 and mistral models
- Deploy PostgreSQL with pgvector
- Deploy RAG service (port 8090)
- Deploy RAG+LLM service (port 8091)
- Create CLI wrapper scripts

### 2. Ingest Documents

```bash
# Ingest all documents from /srv/docs
sudo rag-ingest --verbose

# Check stats
curl http://localhost:19090/stats
```

### 3. Ask Questions

```bash
# Ask with LLM generation (full answer)
rag-ask "How do I configure SELinux in RHEL?"

# RAG retrieval only (document chunks)
rag-ask --rag-only "RHCSA exam"

# Use specific backend
rag-ask --backend mistral "What is systemd?"
```

## Deployment Options

### Option 1: Full Stack (Recommended)

Deploy everything together:

```bash
ansible-playbook rag_llm_stack.yml
```

### Option 2: RAG Only (No LLM)

Deploy just the RAG service:

```bash
ansible-playbook llm_ingest.yml
```

Then query directly:

```bash
curl -X POST http://localhost:19090/query \
  -H "Content-Type: application/json" \
  -d '{"query": "SELinux", "limit": 5}'
```

### Option 3: Ollama Only

Deploy just Ollama:

```bash
ansible-playbook ollama_setup.yml
```

## CLI Tools

### rag-ask - Query with LLM Generation

```bash
# Basic usage
rag-ask "How do I create a systemd service?"

# Options
rag-ask --help
rag-ask --backend anthropic "Question?"     # Use Claude API
rag-ask --backend openai "Question?"        # Use GPT API
rag-ask --rag-only "Query"                  # Retrieval only
rag-ask --rag-limit 10 "Question?"          # More context chunks
rag-ask --json "Question?"                  # JSON output
```

### rag-ingest - Index Documents

```bash
# Ingest all documents
sudo rag-ingest

# Verbose output
sudo rag-ingest --verbose

# Custom doc path
sudo rag-ingest --doc-path /path/to/docs
```

### rag-backup - Backup Database

```bash
# Manual backup
sudo rag-backup

# Backups stored in /srv/rag-backups/
# Auto-backup runs daily via systemd timer
```

## Configuration

### LLM Backends

Configure in [defaults/main.yml](../defaults/main.yml):

```yaml
# Default backend
llm_rag_llm_backend: ollama  # or anthropic, openai

# Ollama settings
llm_rag_ollama_url: "http://localhost:11434"
llm_rag_ollama_model: llama2  # or mistral
```

### API Backends

For Anthropic Claude:

```bash
export ANTHROPIC_API_KEY="your-key"
```

For OpenAI:

```bash
export OPENAI_API_KEY="your-key"
```

### Ports

| Service | Port | Description |
|---------|------|-------------|
| RAG Service | 19090 | Document retrieval API |
| RAG+LLM Service | 8091 | Question answering API |
| Ollama | 11434 | LLM inference API |
| PostgreSQL | 5432 | Database (internal only) |

## Document Ingestion

### Supported Formats

- **PDF** - Extracted with PDFMiner
- **Text** - .txt, .md, .rst
- **Code** - .py, .js, .go, etc.
- **Documentation** - Markdown, reStructuredText

### Document Structure

Organize documents in `/srv/docs/`:

```
/srv/docs/
├── ansible/
│   ├── Ansible.Notes.txt
│   └── Ansible.Best.Practices.pdf
├── linux/
│   └── redhat/
│       ├── courses/
│       └── training/
├── databases/
│   └── mysql/
└── hardware_manuals/
```

### Ingestion Process

1. **Scan** - Find all supported files
2. **Extract** - Extract text content
3. **Chunk** - Split into 800-char chunks (200 overlap)
4. **Embed** - Generate vector embeddings
5. **Store** - Save to PostgreSQL with deduplication

### Deduplication

Content-based deduplication via SHA1 hashing:
- Same content = same hash
- Skip already-indexed chunks
- Safe to re-run ingestion

## Testing

### Test RAG Service

```bash
# Health check
curl http://localhost:19090/

# Stats
curl http://localhost:19090/stats

# Query
curl -X POST http://localhost:19090/query \
  -H "Content-Type: application/json" \
  -d '{"query": "systemd", "limit": 5}'
```

### Test Ollama

```bash
# List models
ollama list

# Test inference
ollama run llama2 "Why is the sky blue?"

# API test
curl http://localhost:11434/api/tags
```

### Test RAG+LLM Integration

```bash
# Health check
curl http://localhost:8091/

# Ask a question
curl -X POST http://localhost:8091/ask \
  -H "Content-Type: application/json" \
  -d '{
    "question": "How do I configure SELinux?",
    "backend": "ollama",
    "rag_limit": 5
  }'
```

## Backup and Restore

### Automatic Backups

Systemd timer runs daily:

```bash
# Check timer status
systemctl status rag-backup.timer

# View backup logs
journalctl -u rag-backup.service

# Manual trigger
sudo systemctl start rag-backup.service
```

### Manual Backup

```bash
# Create backup
sudo rag-backup

# Backups stored in /srv/rag-backups/
ls -lh /srv/rag-backups/
```

### Restore from Backup

```bash
# Restore latest backup
sudo podman exec postgres psql -U aiuser -d ai_context < /srv/rag-backups/rag_backup_YYYYMMDD_HHMMSS.sql.gz
```

## Performance Tuning

### Ollama Performance

```yaml
# Use better model for quality
llm_rag_ollama_model: mistral

# GPU settings (auto-detect by default)
ollama_num_gpu: -1  # Auto
ollama_num_gpu: 0   # CPU only
ollama_num_gpu: 1   # Use 1 GPU
```

### RAG Performance

```bash
# Increase context chunks for better answers
rag-ask --rag-limit 10 "Question?"

# Fewer chunks for faster responses
rag-ask --rag-limit 3 "Question?"
```

## Troubleshooting

### RAG Service Issues

```bash
# Check service status
sudo podman ps | grep rag_service

# View logs
sudo podman logs rag_service

# Restart service
sudo podman restart rag_service
```

### Ollama Issues

```bash
# Check service
systemctl status ollama

# View logs
journalctl -u ollama -f

# Test connectivity
curl http://localhost:11434/api/tags
```

### Database Issues

```bash
# Check Postgres
sudo podman ps | grep postgres

# Connect to database
sudo podman exec -it postgres psql -U aiuser -d ai_context

# Check table stats
SELECT COUNT(*) FROM docs;
SELECT COUNT(DISTINCT filename) FROM docs;
```

### Common Errors

**Error: Connection refused (RAG service)**
- Solution: Wait for ingestion to complete, or deploy with new architecture (separate ingestion)

**Error: Ollama model not found**
- Solution: `ollama pull llama2`

**Error: Out of memory**
- Solution: Use smaller model (llama2 instead of llama2:13b) or reduce `ollama_num_parallel`

**Error: Permission denied on /srv/docs**
- Solution: Check file ownership, run commands with sudo

## Example Queries

### System Administration

```bash
rag-ask "How do I create a systemd service?"
rag-ask "Configure NTP on RHEL"
rag-ask "What are the RHCSA exam objectives?"
rag-ask "How do I configure SELinux?"
```

### DevOps

```bash
rag-ask "How do I write an Ansible playbook?"
rag-ask "MySQL backup best practices"
rag-ask "How do I use podman containers?"
```

### Programming

```bash
rag-ask "Python best practices for error handling"
rag-ask "How do I use async/await in JavaScript?"
```

## Next Steps

1. **Add More Documents** - Copy docs to `/srv/docs/` and run `rag-ingest`
2. **Tune Models** - Try different Ollama models: `ollama pull codellama`
3. **API Integration** - Build apps using the REST APIs
4. **Web UI** - Create a web interface for easier querying
5. **Fine-tuning** - Adjust prompts in `rag_llm_service.py` for better responses

## Architecture Details

### Why Separate Services?

1. **RAG Service (Port 8090)** - Fast startup, pure retrieval
2. **RAG+LLM Service (Port 8091)** - Combines retrieval + generation
3. **Ollama (Port 11434)** - Dedicated LLM inference

Benefits:
- Non-blocking startup
- Can use RAG without LLM
- Can swap LLM backends without changing RAG
- Scale components independently

### Persistence Strategy

1. **Vector Database** - PostgreSQL with pgvector extension
2. **Daily Backups** - Automated via systemd timer
3. **Content Deduplication** - SHA1 hashing prevents duplicates
4. **Incremental Ingestion** - Re-running is safe and fast

## References

- [RAG Service README](RAG_README.md)
- [RAG+LLM README](RAG_LLM_README.md)
- [Ollama Role README](../../ollama/README.md)
- [pgvector Documentation](https://github.com/pgvector/pgvector)
