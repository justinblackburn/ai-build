# Local RAG Stack Playbook

This playbook provisions an air-gapped retrieval-augmented generation stack on a single host using Podman containers. It creates a Podman pod with two containers:

1. `postgres` – PostgreSQL 15 with the `pgvector` extension for embeddings.
2. `rag_service` – A Flask ingestion/query service that chunk-splits local documents, generates deterministic embeddings, and writes them into Postgres.

The pod is locked down so that only the HTTP API is forwarded to the host (default `127.0.0.1:19090`). Postgres stays completely inside the pod network.

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

All commands run from the repository root unless noted.

1. **Create inventory**
   ```bash
   cp -r ansible/inventory.example ansible/inventory
   ```

2. **Set variables**  
   Edit `ansible/inventory/group_vars/all.yml` and review the `llm_rag_*` section. At a minimum set:
   - `llm_rag_pg_password`
   - (optional) `llm_rag_doc_path`, `llm_rag_pg_data_dir`, `llm_rag_api_host_port`

3. **Pre-stage Python wheels (air-gapped friendly)**
   ```bash
   podman run --rm --security-opt label=disable \
     -v /srv/rag:/app -w /app docker.io/python:3.11 \
     bash -lc "mkdir -p wheels && pip download -r requirements.txt -d wheels"

   podman run --rm --security-opt label=disable \
     -v /srv/rag:/app -w /app docker.io/python:3.11 \
     bash -lc 'pip download pip==25.3 -d wheels'
   ```

4. **Run the playbook**
   ```bash
   ansible-playbook \
     -i ansible/inventory/hosts.yml \
     ansible/playbooks/llm_ingest.yml \
     --ask-become-pass \
     --vault-password-file ~/.ansible/.vault_pass.txt
   ```

5. **Verify**
   ```bash
   podman ps --pod
   curl -s -X POST http://localhost:19090/query \
     -H 'Content-Type: application/json' \
     -d '{"query":"test"}' | jq
   ```

---

## Day-2 Operations

- **Ingest new documents**: copy PDF/TXT/MD into `{{ llm_rag_doc_path }}` and restart the app container:
  ```bash
  podman restart rag_service
  ```

- **Upgrade wheel cache** after modifying `requirements.txt`:
  rerun the wheel download commands from step 3.

- **Inspect logs**:
  ```bash
  podman logs -f rag_service
  podman logs -f postgres
  ```

- **Remove the stack**:
  ```bash
  podman pod rm -f rag-stack
  ```

See `roles/llm_rag/README.md` for a deeper dive into variables, architecture, and troubleshooting.

