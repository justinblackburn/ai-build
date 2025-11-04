# `llm_rag` Role

Installs a fully local retrieval-augmented generation stack. The role targets a single host and deploys:

| Component   | Runtime | Description |
|-------------|---------|-------------|
| `rag-stack` | Podman pod | Keeps the Postgres and ingestion service on a shared network namespace. Only the HTTP API is published to the host. |
| `postgres`  | docker.io/ankane/pgvector | PostgreSQL 15 with the `pgvector` extension. Data is stored under `{{ llm_rag_pg_data_dir }}`. |
| `rag_service` | docker.io/python:3.11 | Flask API that chunks and indexes documents, stores vectors, and exposes a `/query` endpoint. |

The service uses deterministic, pseudo-random embeddings generated from the text SHA-256 hash so that everything runs offline. Embeddings are stored using the `pgvector` extension and cosine similarity operators.

---

## Variables

Defined in `defaults/main.yml` and overrideable via inventory:

```yaml
llm_rag_service_dir: /srv/rag
llm_rag_doc_path: /srv/docs
llm_rag_pg_data_dir: /srv/pgvector-data

llm_rag_pg_user: aiuser
llm_rag_pg_password: change_me   # override in inventory
llm_rag_pg_database: ai_context
llm_rag_pg_host: localhost
llm_rag_pg_port: 5432

llm_rag_pod_name: rag-stack
llm_rag_api_container_port: 8090
llm_rag_api_host_port: 19090
llm_rag_api_bind_address: 127.0.0.1

llm_rag_pg_conn_uri: >-
  postgresql://{{ llm_rag_pg_user }}:{{ llm_rag_pg_password }}@
  {{ llm_rag_pg_host }}:{{ llm_rag_pg_port }}/{{ llm_rag_pg_database }}
```

Key points:
- Change `llm_rag_pg_password` in inventory; the default is only a placeholder.
- `llm_rag_api_host_port` chooses the host port for the Flask API. Postgres is *not* published; it’s only reachable inside the pod.
- Existing playbooks that still reference `rag_docs` continue to work because it aliases `llm_rag_doc_path`.

---

## Role Workflow

1. Ensures `/srv/docs`, `/srv/rag`, and `/srv/pgvector-data` exist (override paths via variables).
2. Copies the service bundle (Python entrypoint, `requirements.txt`, etc.) into `llm_rag_service_dir` and makes the entrypoint executable.
3. Writes `/etc/containers/containers.conf.d/zz-llm-rag-runtime.conf` and `/usr/local/bin/podman-crun` to force `crun` usage. SELinux relabeling is disabled with `security_opt: label=disable` because volumes live under `/srv`.
4. Creates a Podman pod that only publishes the API port to `llm_rag_api_bind_address:llm_rag_api_host_port`.
5. Starts `postgres` with the supplied credentials and data directory.
6. Starts `rag_service`, which:
   - Installs pip 25.3 and all dependencies from `/srv/rag/wheels` (air-gapped-safe).
   - Waits for Postgres before ingestion.
   - Ingests documents under `llm_rag_doc_path` on startup and exposes `/query`.

---

## Manual Commands

```bash
# Restart containers inside the pod
podman restart postgres
podman restart rag_service

# Follow logs
podman logs -f postgres
podman logs -f rag_service

# Shell into the service container
podman exec -it rag_service bash
```

When updating the wheelhouse, rerun:

```bash
podman run --rm --security-opt label=disable \
  -v /srv/rag:/app -w /app docker.io/python:3.11 \
  bash -lc "pip download -r requirements.txt -d wheels"

podman run --rm --security-opt label=disable \
  -v /srv/rag:/app -w /app docker.io/python:3.11 \
  bash -lc 'pip download pip==25.3 -d wheels'
```

---

## Troubleshooting

- **Connection refused on `/query`**: Confirm both containers are up (`podman ps --pod`) and that the API port matches `llm_rag_api_host_port`.
- **Empty results**: Ensure supported files (PDF/TXT/MD) exist under `llm_rag_doc_path` and restart `rag_service` to re-ingest.
- **Permission denied on `/srv/pgvector-data`**: The play expects root-owned directories. Make sure `llm_rag_pg_data_dir` exists and is writable before running the playbook.
- **Need to expose the API on a different interface**: Override `llm_rag_api_bind_address` in inventory (e.g. `0.0.0.0`).

Postgres remains inside the pod. If external access is required, manually publish the port or use `podman port postgres` to view dynamic mappings—but the default configuration blocks it intentionally.

