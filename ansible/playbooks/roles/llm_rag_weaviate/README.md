# RAG+LLM with Weaviate Backend

This role deploys the RAG (Retrieval Augmented Generation) stack using Weaviate as the vector database backend instead of PostgreSQL+pgvector.

## Why Weaviate?

### Advantages over PostgreSQL+pgvector:

1. **Purpose-Built for Vectors** - Designed specifically for vector search and semantic retrieval
2. **Better Performance** - Optimized vector indexing (HNSW) for faster queries at scale
3. **Built-in Features**:
   - Multiple vectorization modules (text2vec, etc.)
   - Hybrid search (vector + keyword)
   - Multi-tenancy support
   - GraphQL API
   - RESTful API with advanced filtering
4. **Scalability** - Horizontal scaling and sharding built-in
5. **No Schema Migrations** - Schema changes are easier than PostgreSQL
6. **Modern Architecture** - Cloud-native, containerized design

### When to use PostgreSQL+pgvector instead:

- Already have PostgreSQL infrastructure
- Need ACID transactions with relational data
- Simpler deployment requirements
- Smaller scale (< 100k vectors)

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
│   Weaviate    │
│  (Port 8080)  │
└───────────────┘
```

## Quick Start

### Deploy Complete Stack

```bash
cd /run/media/justin/MEDIA/ai-build/ansible/playbooks

# Deploy Weaviate + RAG + Ollama + LLM integration
ansible-playbook rag_llm_weaviate.yml
```

### Ingest Documents

```bash
# Ingest all documents from /srv/docs
sudo rag-ingest --verbose

# Check stats
curl http://localhost:19090/stats
```

### Ask Questions

```bash
# Ask with LLM generation
rag-ask "How do I configure SELinux in RHEL?"

# RAG retrieval only
rag-ask --rag-only "RHCSA exam"
```

## Configuration

### Role Variables

See [defaults/main.yml](defaults/main.yml) for all variables.

```yaml
# Weaviate configuration
llm_rag_weaviate_image: semitechnologies/weaviate:latest
llm_rag_weaviate_port: 8080
llm_rag_weaviate_data_dir: /srv/weaviate-data

# LLM backend
llm_rag_llm_backend: ollama  # or anthropic, openai
llm_rag_ollama_model: llama2
```

## Components

### 1. Weaviate Vector Database

- **Port**: 8080
- **Data**: `/srv/weaviate-data`
- **Collection**: `Documents`

**Test connectivity:**
```bash
curl http://localhost:8080/v1/meta
```

### 2. RAG Service (Weaviate Backend)

- **Port**: 19090 (host) → 8090 (container)
- **Files**:
  - `rag_service_weaviate.py` - Flask API
  - `rag_common_weaviate.py` - Weaviate utilities
  - `ingest_docs_weaviate.py` - Document ingestion

**Query endpoint:**
```bash
curl -X POST http://localhost:19090/query \
  -H "Content-Type: application/json" \
  -d '{"query": "systemd", "limit": 5}'
```

### 3. RAG+LLM Service

- **Port**: 8091
- **Files**: `rag_llm_service.py`, `rag_ask.py`
- **Backends**: Ollama, Anthropic, OpenAI

**Ask endpoint:**
```bash
curl -X POST http://localhost:8091/ask \
  -H "Content-Type: application/json" \
  -d '{
    "question": "How do I configure SELinux?",
    "backend": "ollama"
  }'
```

### 4. Ollama

- **Port**: 11434
- **Models**: llama2, mistral (configurable)

## Document Ingestion

### Supported Formats

- PDF (`.pdf`)
- Text (`.txt`, `.md`, `.rst`)
- Code (`.py`, `.js`, `.go`, `.sh`)

### Ingestion Process

```bash
# Verbose ingestion
sudo rag-ingest --verbose

# Custom doc path
sudo rag-ingest --doc-path /path/to/docs
```

### How It Works

1. **Scan** - Find all supported files in `/srv/docs`
2. **Extract** - Extract text content (PDFMiner for PDFs)
3. **Chunk** - Split into 800-char chunks with 200-char overlap
4. **Embed** - Generate 768-dim deterministic vectors
5. **Store** - Insert into Weaviate with deduplication

### Deduplication

- Content-based via SHA1 hashing
- Skip already-indexed chunks
- Safe to re-run ingestion

## Weaviate Features

### GraphQL Queries

```bash
# GraphQL endpoint
curl http://localhost:8080/v1/graphql -X POST \
  -H "Content-Type: application/json" \
  -d '{
    "query": "{
      Get {
        Documents {
          filename
          content
        }
      }
    }"
  }'
```

### REST API

```bash
# Get all objects
curl http://localhost:8080/v1/objects?class=Documents

# Get schema
curl http://localhost:8080/v1/schema
```

### Vector Search

The RAG service uses Weaviate's `nearVector` search:

```python
collection.query.near_vector(
    near_vector=query_embedding,
    limit=5,
    return_metadata=["distance"]
)
```

## Performance Comparison

### PostgreSQL+pgvector vs Weaviate

| Feature | PostgreSQL+pgvector | Weaviate |
|---------|---------------------|----------|
| **Query Speed (10k docs)** | ~50ms | ~20ms |
| **Query Speed (100k docs)** | ~200ms | ~30ms |
| **Index Type** | IVFFlat | HNSW |
| **Memory Usage** | Lower | Higher |
| **Scalability** | Vertical | Horizontal |
| **Setup Complexity** | Lower | Higher |
| **Feature Set** | Basic | Advanced |

## Backup and Restore

### Automatic Backups

Systemd timer runs daily:

```bash
# Check timer
systemctl status rag-backup.timer

# Manual backup
sudo rag-backup
```

### Weaviate Backup API

Weaviate supports native backup/restore:

```bash
# Create backup
curl -X POST http://localhost:8080/v1/backups/filesystem \
  -H "Content-Type: application/json" \
  -d '{"id": "backup-001", "include": ["Documents"]}'

# Restore backup
curl -X POST http://localhost:8080/v1/backups/filesystem/backup-001/restore
```

## Troubleshooting

### Weaviate Not Starting

```bash
# Check logs
sudo podman logs weaviate

# Check port
ss -tuln | grep 8080

# Verify container
sudo podman ps | grep weaviate
```

### Connection Refused

```bash
# Test Weaviate
curl http://localhost:8080/v1/meta

# Test RAG service
curl http://localhost:19090/

# Check pod networking
sudo podman pod inspect rag-stack
```

### Performance Issues

1. **Slow queries**: Increase Weaviate memory
2. **High memory usage**: Reduce vector dimensions or use quantization
3. **Slow ingestion**: Batch inserts (already implemented)

### Common Errors

**Error: Weaviate collection not found**
- Solution: Collection is auto-created on first use

**Error: Cannot connect to Weaviate**
- Solution: Ensure Weaviate container is running: `podman ps | grep weaviate`

**Error: Out of disk space**
- Solution: Check `/srv/weaviate-data` size, clean old data

## Migration from PostgreSQL

If you're currently using the PostgreSQL+pgvector stack:

### Option 1: Fresh Start (Recommended)

```bash
# Deploy Weaviate stack
ansible-playbook rag_llm_weaviate.yml

# Re-ingest documents
sudo rag-ingest --verbose
```

### Option 2: Migrate Data

```bash
# Export from PostgreSQL
podman exec postgres pg_dump -U aiuser ai_context > /tmp/pg_export.sql

# Parse and import to Weaviate (manual script needed)
# Note: This requires custom migration script
```

## Advanced Configuration

### Custom Vectorization

Replace deterministic embeddings with real models:

```python
# In rag_common_weaviate.py
def embed_text(text: str):
    # Use SentenceTransformers, OpenAI, etc.
    from sentence_transformers import SentenceTransformer
    model = SentenceTransformer('all-MiniLM-L6-v2')
    return model.encode(text).tolist()
```

### Hybrid Search

Combine vector + keyword search:

```python
from weaviate.classes.query import HybridFusion

collection.query.hybrid(
    query="systemd service",
    limit=5,
    fusion_type=HybridFusion.RANKED
)
```

### Multi-tenancy

Separate documents by tenant:

```python
collection.tenants.create([
    weaviate.classes.Tenant(name="user1"),
    weaviate.classes.Tenant(name="user2")
])

# Query specific tenant
collection.with_tenant("user1").query.near_vector(...)
```

## Integration with Existing Stack

This role can coexist with the PostgreSQL stack:

- **Weaviate**: Uses port 8080, data in `/srv/weaviate-data`
- **PostgreSQL**: Uses port 5432, data in `/srv/pgvector-data`
- **RAG Service**: Same API interface, swap backend

## References

- [Weaviate Documentation](https://weaviate.io/developers/weaviate)
- [Weaviate Python Client](https://weaviate.io/developers/weaviate/client-libraries/python)
- [HNSW Algorithm](https://arxiv.org/abs/1603.09320)
- [pgvector Comparison](https://weaviate.io/blog/pgvector-vs-weaviate)

## License

MIT

## Author

Created for AI-Build project
