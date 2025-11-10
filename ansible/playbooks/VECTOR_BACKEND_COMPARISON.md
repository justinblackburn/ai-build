# Vector Database Backend Comparison

This project supports two vector database backends for the RAG stack:

1. **PostgreSQL + pgvector** - Traditional RDBMS with vector extension
2. **Weaviate** - Purpose-built vector database

## Quick Decision Matrix

| Use Case | Recommended Backend |
|----------|---------------------|
| Getting started, small scale | PostgreSQL+pgvector |
| Production, large scale (>100k docs) | Weaviate |
| Already using PostgreSQL | PostgreSQL+pgvector |
| Need advanced vector features | Weaviate |
| Simple deployment, minimal deps | PostgreSQL+pgvector |
| Horizontal scaling needed | Weaviate |
| Budget/resource constrained | PostgreSQL+pgvector |
| Performance critical | Weaviate |

## Feature Comparison

### PostgreSQL + pgvector

**Pros:**
- ✅ Familiar PostgreSQL ecosystem
- ✅ ACID transactions
- ✅ Mature, battle-tested
- ✅ Lower memory footprint
- ✅ Easy backup/restore (pg_dump)
- ✅ Integrate with existing PostgreSQL infrastructure
- ✅ Simpler deployment (single container)
- ✅ Lower resource requirements

**Cons:**
- ⚠️ Slower at scale (>100k vectors)
- ⚠️ Limited vector-specific features
- ⚠️ Vertical scaling only
- ⚠️ Basic indexing (IVFFlat)
- ⚠️ No built-in vectorization
- ⚠️ Higher query latency at scale

**Best For:**
- Small to medium deployments (<100k documents)
- Organizations already using PostgreSQL
- Simple use cases with basic vector search
- Development and testing
- Budget-constrained projects

---

### Weaviate

**Pros:**
- ✅ Purpose-built for vectors
- ✅ HNSW indexing (faster queries)
- ✅ Horizontal scaling
- ✅ Advanced features (hybrid search, multi-tenancy)
- ✅ GraphQL + REST APIs
- ✅ Built-in vectorization modules
- ✅ Better performance at scale
- ✅ Cloud-native architecture

**Cons:**
- ⚠️ Higher memory requirements
- ⚠️ More complex deployment
- ⚠️ Steeper learning curve
- ⚠️ Additional container overhead
- ⚠️ Less mature than PostgreSQL
- ⚠️ Overkill for small datasets

**Best For:**
- Large-scale deployments (>100k documents)
- Performance-critical applications
- Advanced vector search features needed
- Microservices architecture
- Cloud deployments with auto-scaling
- Production systems with high query volume

## Performance Benchmarks

### Query Latency (Approximate)

| Dataset Size | PostgreSQL+pgvector | Weaviate |
|--------------|---------------------|----------|
| 1k docs      | ~10ms              | ~15ms    |
| 10k docs     | ~50ms              | ~20ms    |
| 100k docs    | ~200ms             | ~30ms    |
| 1M docs      | ~1000ms            | ~50ms    |

*Note: Results vary based on hardware, chunk size, and query complexity*

### Indexing (HNSW vs IVFFlat)

**IVFFlat (PostgreSQL):**
- Cluster-based approximate search
- Faster indexing, slower queries
- Good for static datasets
- Trade-off: `lists` parameter

**HNSW (Weaviate):**
- Graph-based approximate search
- Slower indexing, faster queries
- Excellent recall at scale
- Trade-off: memory vs accuracy

### Resource Requirements

| Component | PostgreSQL+pgvector | Weaviate |
|-----------|---------------------|----------|
| Memory (100k docs) | ~500MB | ~2GB |
| CPU | Moderate | Higher during indexing |
| Disk | Lower | Higher (graph storage) |
| Startup Time | Fast (~5s) | Slower (~15s) |

## API Differences

### Query Syntax

**PostgreSQL+pgvector:**
```sql
SELECT filename, content,
       1 - (embedding <#> %s) AS score
FROM docs
ORDER BY embedding <-> %s
LIMIT 5;
```

**Weaviate:**
```python
collection.query.near_vector(
    near_vector=embedding,
    limit=5,
    return_metadata=["distance"]
)
```

### Filtering

**PostgreSQL+pgvector:**
```sql
WHERE filename LIKE '/srv/docs/linux/%'
  AND score > 0.8
```

**Weaviate:**
```python
filters=Filter.by_property("filename").like("/srv/docs/linux/*") &
        Filter.by_property("score").greater_than(0.8)
```

## Deployment Comparison

### PostgreSQL+pgvector Stack

```bash
# Deploy
ansible-playbook rag_llm_stack.yml

# Containers
- postgres (pgvector)
- rag_service
- rag_llm_service

# Ports
- 19090 (RAG API)
- 8091 (LLM API)
- 5432 (PostgreSQL, internal)
```

### Weaviate Stack

```bash
# Deploy
ansible-playbook rag_llm_weaviate.yml

# Containers
- weaviate
- rag_service
- rag_llm_service

# Ports
- 19090 (RAG API)
- 8091 (LLM API)
- 8080 (Weaviate, internal)
```

## Migration Between Backends

### PostgreSQL → Weaviate

```bash
# 1. Deploy Weaviate stack
ansible-playbook rag_llm_weaviate.yml

# 2. Re-ingest documents (recommended)
sudo rag-ingest --verbose

# Alternative: Export and migrate (requires custom script)
```

### Weaviate → PostgreSQL

```bash
# 1. Deploy PostgreSQL stack
ansible-playbook rag_llm_stack.yml

# 2. Re-ingest documents
sudo rag-ingest --verbose
```

**Note:** Both stacks use the same document ingestion logic, so re-ingestion is straightforward and safe (deduplication prevents duplicates).

## Cost Analysis

### Resource Costs (Approximate)

**PostgreSQL+pgvector (100k documents):**
- Memory: 500MB
- Disk: 2GB
- CPU: 0.5 cores (idle), 2 cores (ingestion)
- **Total**: ~$5-10/month (cloud VM)

**Weaviate (100k documents):**
- Memory: 2GB
- Disk: 5GB
- CPU: 1 core (idle), 4 cores (ingestion)
- **Total**: ~$20-30/month (cloud VM)

### Development vs Production

| Environment | Recommended |
|-------------|-------------|
| Local dev   | PostgreSQL+pgvector |
| Staging     | Same as production |
| Production (small) | PostgreSQL+pgvector |
| Production (large) | Weaviate |

## Advanced Features

### PostgreSQL+pgvector

**Basic Features:**
- Vector similarity search
- Index types: IVFFlat, HNSW (pg 17+)
- SQL queries with vector ops
- ACID transactions

**Missing:**
- Native hybrid search
- Multi-tenancy
- Built-in vectorization
- GraphQL API

### Weaviate

**Advanced Features:**
- Hybrid search (vector + BM25)
- Multi-tenancy
- Cross-references
- GraphQL API
- Multiple vectorizer modules
- Generative search
- Classification
- Question answering

**Configuration Example:**
```python
# Hybrid search
collection.query.hybrid(
    query="systemd",
    alpha=0.5,  # 0=keyword, 1=vector
    limit=5
)

# Multi-tenant
collection.with_tenant("user123").query.near_vector(...)
```

## Recommendations

### Choose PostgreSQL+pgvector if:

1. ✅ You're just getting started with RAG
2. ✅ Dataset < 100k documents
3. ✅ You already use PostgreSQL
4. ✅ Simple deployment is priority
5. ✅ Budget is constrained
6. ✅ You need ACID transactions
7. ✅ Query latency < 200ms is acceptable

### Choose Weaviate if:

1. ✅ Dataset > 100k documents
2. ✅ Need low query latency (<50ms)
3. ✅ Want advanced vector features
4. ✅ Plan to scale horizontally
5. ✅ Need hybrid search
6. ✅ Building production system
7. ✅ Have resources for higher memory usage

### Hybrid Approach

Run both! Use the same RAG service API:

```bash
# Deploy both backends
ansible-playbook rag_llm_stack.yml          # PostgreSQL
ansible-playbook rag_llm_weaviate.yml       # Weaviate (different ports)

# Switch between them based on workload
```

## Future Considerations

### PostgreSQL Improvements (Upcoming)

- PostgreSQL 17: Native HNSW support
- Better vector performance
- Improved indexing options

### Weaviate Roadmap

- Improved compression
- More vectorizer modules
- Better multi-tenancy
- Enhanced backup/restore

## Summary

| Criteria | Winner |
|----------|--------|
| **Ease of Use** | PostgreSQL+pgvector |
| **Performance (Large Scale)** | Weaviate |
| **Feature Set** | Weaviate |
| **Resource Efficiency** | PostgreSQL+pgvector |
| **Scalability** | Weaviate |
| **Ecosystem Maturity** | PostgreSQL+pgvector |
| **Production Ready** | Both |

**Default Recommendation**: Start with PostgreSQL+pgvector, migrate to Weaviate if you outgrow it.

## Quick Start Commands

### PostgreSQL+pgvector
```bash
ansible-playbook rag_llm_stack.yml
sudo rag-ingest --verbose
rag-ask "How do I configure SELinux?"
```

### Weaviate
```bash
ansible-playbook rag_llm_weaviate.yml
sudo rag-ingest --verbose
rag-ask "How do I configure SELinux?"
```

Both provide identical user experience—the difference is in the backend!
