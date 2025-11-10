#!/bin/bash
#
# Restore script for RAG PostgreSQL database
#
# Usage: restore_rag.sh <backup_file>
#
# Environment variables:
#   PG_CONN - PostgreSQL connection string
#

set -euo pipefail

if [ $# -ne 1 ]; then
    echo "Usage: $0 <backup_file>" >&2
    exit 1
fi

BACKUP_FILE="$1"

if [ ! -f "$BACKUP_FILE" ]; then
    echo "ERROR: Backup file not found: $BACKUP_FILE" >&2
    exit 1
fi

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

echo "WARNING: This will replace all data in database: $PGDATABASE"
read -p "Are you sure you want to continue? (yes/no): " CONFIRM

if [ "$CONFIRM" != "yes" ]; then
    echo "Restore cancelled"
    exit 0
fi

echo "Starting RAG database restore..."
echo "  Database: $PGDATABASE"
echo "  Host: $PGHOST:$PGPORT"
echo "  Backup file: $BACKUP_FILE"

# Restore backup
export PGPASSWORD
if zcat "$BACKUP_FILE" | psql -h "$PGHOST" -p "$PGPORT" -U "$PGUSER" -d "$PGDATABASE"; then
    echo "Restore completed successfully"
else
    echo "ERROR: Restore failed" >&2
    exit 1
fi

echo "Restore complete!"
