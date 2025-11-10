#!/bin/bash
#
# Backup script for RAG PostgreSQL database
#
# Usage: backup_rag.sh [backup_dir]
#
# Environment variables:
#   PG_CONN - PostgreSQL connection string
#   BACKUP_RETENTION_DAYS - Number of days to keep backups (default: 30)
#

set -euo pipefail

BACKUP_DIR="${1:-/srv/rag-backups}"
RETENTION_DAYS="${BACKUP_RETENTION_DAYS:-30}"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="${BACKUP_DIR}/rag_backup_${TIMESTAMP}.sql.gz"

# Extract connection details from PG_CONN
if [ -z "${PG_CONN:-}" ]; then
    echo "ERROR: PG_CONN environment variable must be set" >&2
    exit 1
fi

# Parse PG_CONN (postgresql://user:pass@host:port/database)
if [[ $PG_CONN =~ postgresql://([^:]+):([^@]+)@([^:]+):([0-9]+)/(.+) ]]; then
    PGUSER="${BASH_REMATCH[1]}"
    PGPASSWORD="${BASH_REMATCH[2]}"
    PGHOST="${BASH_REMATCH[3]}"
    PGPORT="${BASH_REMATCH[4]}"
    PGDATABASE="${BASH_REMATCH[5]}"
else
    echo "ERROR: Unable to parse PG_CONN" >&2
    exit 1
fi

# Create backup directory if it doesn't exist
mkdir -p "$BACKUP_DIR"

echo "Starting RAG database backup..."
echo "  Database: $PGDATABASE"
echo "  Host: $PGHOST:$PGPORT"
echo "  Backup file: $BACKUP_FILE"

# Perform backup
export PGPASSWORD
if pg_dump -h "$PGHOST" -p "$PGPORT" -U "$PGUSER" -d "$PGDATABASE" \
    --format=plain --no-owner --no-acl | gzip > "$BACKUP_FILE"; then
    echo "Backup completed successfully"
    ls -lh "$BACKUP_FILE"
else
    echo "ERROR: Backup failed" >&2
    rm -f "$BACKUP_FILE"
    exit 1
fi

# Clean up old backups
echo "Cleaning up backups older than $RETENTION_DAYS days..."
find "$BACKUP_DIR" -name "rag_backup_*.sql.gz" -type f -mtime +$RETENTION_DAYS -delete
REMAINING=$(find "$BACKUP_DIR" -name "rag_backup_*.sql.gz" -type f | wc -l)
echo "  $REMAINING backup(s) remaining"

echo "Backup complete!"
