# RAG Service Documentation

## Architecture

The RAG (Retrieval Augmented Generation) service consists of three main components:

1. **PostgreSQL with pgvector** - Vector database for storing document embeddings
2. **RAG Query Service** (`rag_service.py`) - Flask API for querying documents
3. **Document Ingestion** (`ingest_docs.py`) - Standalone script for indexing documents

## Quick Start

### Querying Documents

The RAG service runs on port 19090 (by default) and provides a REST API:

```bash
# Health check
curl http://127.0.0.1:19090/

# Query documents
curl -X POST http://127.0.0.1:19090/query \
  -H "Content-Type: application/json" \
  -d '{"query": "your question here"}'

# Get statistics
curl http://127.0.0.1:19090/stats
```

### Adding Documents

1. **Add files to `/srv/docs/`:**
   ```bash
   sudo cp /path/to/your/document.pdf /srv/docs/
   ```

2. **Run ingestion:**
   ```bash
   rag-ingest --verbose
   ```

The ingestion script will:
- Scan all PDF, TXT, and MD files in `/srv/docs/`
- Extract text and split into chunks
- Generate embeddings
- Store in PostgreSQL
- Skip already-indexed chunks (based on content hash)

## Supported Document Formats

- **PDF** (`.pdf`) - Extracted using pdfminer
- **Text** (`.txt`) - Plain text files
- **Markdown** (`.md`) - Markdown documents

## API Endpoints

### GET `/`
Health check and document count

**Response:**
```json
{
  "status": "healthy",
  "documents_indexed": 1234
}
```

### POST `/query`
Query documents using vector similarity search

**Request:**
```json
{
  "query": "your question here",
  "limit": 5  // optional, default 5
}
```

**Response:**
```json
[
  {
    "filename": "/srv/docs/document.pdf",
    "content": "relevant text chunk...",
    "score": 0.85
  }
]
```

### GET `/stats`
Get database statistics

**Response:**
```json
{
  "unique_files": 42,
  "total_chunks": 1234,
  "database_size": "123 MB"
}
```

## Management Commands

### Ingestion

```bash
# Run ingestion with progress output
rag-ingest --verbose

# Specify custom document path
rag-ingest --doc-path /path/to/docs
```

### Backup

```bash
# Manual backup
rag-backup

# Restore from backup
podman exec -e PG_CONN="postgresql://..." \
  rag_service bash /app/restore_rag.sh /srv/rag-backups/rag_backup_20231109_120000.sql.gz
```

Automatic daily backups are enabled by default and managed by systemd timer.

### Monitoring

```bash
# Check RAG service logs
podman logs rag_service

# Check PostgreSQL logs
podman logs postgres

# Check backup timer status
systemctl status rag-backup.timer
```

## Data Persistence

### Persistent Data Locations

- `/srv/docs/` - Source documents
- `/srv/pgvector-data/` - PostgreSQL database (all embeddings and indexed content)
- `/srv/rag-backups/` - Database backups

### Backup Strategy

**Automatic Backups:**
- Scheduled via systemd timer (daily by default)
- Retention: 30 days (configurable)
- Compressed SQL dumps

**Manual Backup:**
```bash
rag-backup
```

**Restore:**
```bash
# List available backups
ls -lh /srv/rag-backups/

# Restore (requires confirmation)
podman exec -e PG_CONN="postgresql://..." \
  rag_service bash /app/restore_rag.sh /srv/rag-backups/rag_backup_YYYYMMDD_HHMMSS.sql.gz
```

## Configuration

Edit Ansible variables in `playbooks/roles/llm_rag/defaults/main.yml`:

```yaml
# Base paths
llm_rag_service_dir: /srv/rag
llm_rag_doc_path: /srv/docs
llm_rag_pg_data_dir: /srv/pgvector-data
llm_rag_backup_dir: /srv/rag-backups

# Backup configuration
llm_rag_enable_auto_backup: true
llm_rag_backup_schedule: "daily"
llm_rag_backup_retention_days: 30

# Networking
llm_rag_api_host_port: 19090
llm_rag_api_bind_address: 127.0.0.1
```

## Troubleshooting

### Service won't start
```bash
# Check container status
podman ps -a

# View logs
podman logs rag_service
podman logs postgres
```

### Documents not appearing in queries
1. Ensure files are in `/srv/docs/`
2. Run ingestion: `rag-ingest --verbose`
3. Check stats: `curl http://127.0.0.1:19090/stats`

### Slow ingestion
Ingestion speed depends on:
- Number and size of documents
- PDF complexity
- System resources

Large document collections (100s of MB) can take 30-60+ minutes to ingest initially.

## Technical Details

### Embeddings
- Deterministic 768-dimensional vectors
- Generated using SHA256-seeded random embeddings
- Content-based hashing prevents duplicate chunks

### Database Schema
```sql
CREATE TABLE docs (
  id SERIAL PRIMARY KEY,
  doc_hash TEXT UNIQUE,
  filename TEXT,
  content TEXT,
  embedding vector(768)
);
```

### Chunking Strategy
- Chunk size: 800 characters
- Chunk overlap: 200 characters
- Uses RecursiveCharacterTextSplitter from langchain

## Future Enhancements

Potential improvements:
- Replace deterministic embeddings with real embedding models (e.g., sentence-transformers)
- Add web UI for querying
- Integrate with LLM for answer generation (true RAG)
- Add document deletion/update API
- Multi-user support with access control
