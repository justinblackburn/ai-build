# RAG + LLM Integration

## Overview

The RAG+LLM service combines document retrieval with LLM generation to answer questions based on your document corpus.

**Architecture:**
```
Question → RAG Service → Relevant Docs → LLM → Generated Answer
```

## Quick Start

### 1. Choose Your LLM Backend

**Option A: Ollama (Local, Recommended)**
```bash
# Install Ollama
curl https://ollama.ai/install.sh | sh

# Pull a model
ollama pull llama2
# OR for better quality:
ollama pull mistral
```

**Option B: Anthropic Claude API**
```bash
export ANTHROPIC_API_KEY="your-key-here"
```

**Option C: OpenAI API**
```bash
export OPENAI_API_KEY="your-key-here"
```

### 2. Start RAG+LLM Service

The service runs alongside the existing RAG service:

```bash
# With Ollama (default)
python /srv/rag/rag_llm_service.py

# With Anthropic
LLM_BACKEND=anthropic python /srv/rag/rag_llm_service.py

# With OpenAI
LLM_BACKEND=openai python /srv/rag/rag_llm_service.py
```

### 3. Ask Questions

**Command Line:**
```bash
# Ask with generation
rag-ask "How do I configure SELinux in RHEL?"

# RAG retrieval only (no generation)
rag-ask --rag-only "SELinux configuration"

# Use specific backend
rag-ask --backend anthropic "What is systemd?"
```

**HTTP API:**
```bash
# Ask endpoint (RAG + Generation)
curl -X POST http://localhost:8091/ask \
  -H "Content-Type: application/json" \
  -d '{
    "question": "How do I configure SELinux?",
    "rag_limit": 5,
    "backend": "ollama"
  }'

# Query endpoint (RAG only)
curl -X POST http://localhost:8091/query \
  -H "Content-Type: application/json" \
  -d '{"query": "SELinux", "limit": 5}'
```

## Configuration

### Environment Variables

**RAG+LLM Service:**
- `LLM_BACKEND` - Backend to use: `ollama`, `anthropic`, `openai` (default: `ollama`)
- `LLM_PORT` - Port to run on (default: `8091`)
- `RAG_API_URL` - RAG service URL (default: `http://localhost:8090`)

**Ollama Backend:**
- `OLLAMA_URL` - Ollama server URL (default: `http://localhost:11434`)
- `OLLAMA_MODEL` - Model to use (default: `llama2`)

**API Backends:**
- `ANTHROPIC_API_KEY` - Claude API key
- `OPENAI_API_KEY` - OpenAI API key

## Example Queries

### System Administration
```bash
rag-ask "How do I create a systemd service?"
rag-ask "What are the steps for RHCSA exam?"
rag-ask "Configure NTP on RHEL"
```

### Programming
```bash
rag-ask "How do I use Ansible playbooks?"
rag-ask "MySQL backup best practices"
```

### Comparison

**RAG Only (Retrieval):**
- Returns raw document chunks
- Fast
- No API costs
- You read and interpret

**RAG + LLM (Generation):**
- Returns natural language answer
- Slower (depends on LLM)
- May have API costs (if using Claude/GPT)
- LLM interprets and synthesizes

## API Response Format

### `/ask` Endpoint

```json
{
  "question": "How do I configure SELinux?",
  "answer": "To configure SELinux in RHEL, you need to...",
  "sources": [
    {
      "filename": "/srv/docs/linux/redhat/...",
      "content": "relevant chunk...",
      "score": 0.85
    }
  ],
  "backend": "ollama"
}
```

### `/query` Endpoint

```json
[
  {
    "filename": "/srv/docs/...",
    "content": "relevant text...",
    "score": 0.85
  }
]
```

## Performance

**Ollama (Local):**
- ✅ No API costs
- ✅ Data stays local
- ⚠️ Slower (depends on hardware)
- ⚠️ Requires GPU for good performance

**API (Claude/GPT):**
- ✅ Fast
- ✅ High quality answers
- ⚠️ Costs per query
- ⚠️ Data sent to external service

## Troubleshooting

### Ollama Not Responding
```bash
# Check if Ollama is running
curl http://localhost:11434/api/tags

# Start Ollama
systemctl start ollama  # if installed as service
# OR
ollama serve
```

### RAG Service Not Found
```bash
# Check RAG service
curl http://localhost:8090/stats

# Check if running
podman ps | grep rag_service
```

### Model Not Found
```bash
# List available models
ollama list

# Pull a model
ollama pull llama2
```

## Next Steps

1. **Deploy Ollama** - For local LLM inference
2. **Optimize Prompts** - Tune the system prompt in `rag_llm_service.py`
3. **Add More Models** - Try mistral, codellama, etc.
4. **Web UI** - Build a web interface for easier querying
