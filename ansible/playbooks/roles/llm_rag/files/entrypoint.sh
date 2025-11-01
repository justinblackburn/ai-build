#!/bin/bash
set -euo pipefail

echo "Installing pip 25.3 from local wheelhouse..." >&2
python -m pip install --no-index --find-links /app/wheels pip==25.3

echo "Installing application requirements from local wheelhouse..." >&2
python -m pip install --no-index --find-links /app/wheels -r /app/requirements.txt

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
