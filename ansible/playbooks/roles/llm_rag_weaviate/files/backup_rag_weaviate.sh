#!/bin/bash
set -euo pipefail

# Backup script for Weaviate RAG database
# Usage: backup_rag_weaviate.sh [backup_directory]

BACKUP_DIR="${1:-/srv/rag-backups}"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="${BACKUP_DIR}/weaviate_backup_${TIMESTAMP}.tar.gz"
RETENTION_DAYS="${BACKUP_RETENTION_DAYS:-30}"
WEAVIATE_URL="${WEAVIATE_URL:-http://localhost:8080}"

# Ensure backup directory exists
mkdir -p "$BACKUP_DIR"

echo "Starting Weaviate backup..."
echo "Backup directory: $BACKUP_DIR"
echo "Timestamp: $TIMESTAMP"

# Create backup using Weaviate's backup API
# Note: This requires Weaviate to have backup module configured
curl -X POST "${WEAVIATE_URL}/v1/backups/filesystem" \
  -H "Content-Type: application/json" \
  -d "{
    \"id\": \"backup_${TIMESTAMP}\",
    \"include\": [\"Documents\"]
  }"

echo "Backup created: backup_${TIMESTAMP}"

# Clean up old backups
if [ "$RETENTION_DAYS" -gt 0 ]; then
  echo "Cleaning up backups older than $RETENTION_DAYS days..."
  find "$BACKUP_DIR" -name "weaviate_backup_*.tar.gz" -type f -mtime +"$RETENTION_DAYS" -delete
  echo "Cleanup complete"
fi

echo "Backup complete: backup_${TIMESTAMP}"
