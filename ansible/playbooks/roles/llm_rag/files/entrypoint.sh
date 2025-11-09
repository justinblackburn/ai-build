#!/bin/bash
set -euo pipefail

# Upgrade pip first (try with internet, fallback to local wheels if available)
echo "Upgrading pip..." >&2
if ! python -m pip install --upgrade pip; then
  echo "Internet upgrade failed, trying local wheelhouse..." >&2
  if [ -d /app/wheels ] && [ -n "$(ls -A /app/wheels 2>/dev/null)" ]; then
    python -m pip install --no-index --find-links /app/wheels pip || echo "Warning: pip upgrade from wheels failed, continuing with existing pip version" >&2
  else
    echo "Warning: No wheels directory found, continuing with existing pip version" >&2
  fi
fi

# Install application requirements
echo "Installing application requirements..." >&2
if [ -d /app/wheels ] && [ -n "$(ls -A /app/wheels 2>/dev/null)" ]; then
  echo "Using local wheelhouse for air-gapped installation..." >&2
  python -m pip install --no-index --find-links /app/wheels -r /app/requirements.txt
else
  echo "Installing from PyPI..." >&2
  python -m pip install -r /app/requirements.txt
fi

echo "Waiting for Postgres at ${PG_CONN}..." >&2
ready=0
for attempt in $(seq 1 30); do
  if python - <<'PY'
import os
import psycopg2

conn = psycopg2.connect(os.environ["PG_CONN"])
conn.close()
PY
  then
    ready=1
    break
  fi
  sleep 2
done

if [[ "${ready}" -ne 1 ]]; then
  echo "Postgres did not become ready after waiting." >&2
  exit 1
fi

echo "Starting rag_service..." >&2
exec python /app/rag_service.py
