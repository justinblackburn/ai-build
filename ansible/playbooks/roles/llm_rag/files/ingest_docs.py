#!/usr/bin/env python3
"""
Standalone document ingestion script for RAG system

Usage:
    python ingest_docs.py [--verbose] [--doc-path /path/to/docs]

Environment Variables:
    PG_CONN - PostgreSQL connection string (required)
    DOC_PATH - Path to documents directory (default: /srv/docs)
"""
import argparse
import os
import sys
import time

from rag_common import get_db_connection, ingest_documents


def main():
    parser = argparse.ArgumentParser(description="Ingest documents into RAG system")
    parser.add_argument(
        "--verbose", "-v",
        action="store_true",
        help="Print verbose progress information"
    )
    parser.add_argument(
        "--doc-path",
        default=os.getenv("DOC_PATH", "/srv/docs"),
        help="Path to documents directory (default: $DOC_PATH or /srv/docs)"
    )

    args = parser.parse_args()

    if not os.getenv("PG_CONN"):
        print("ERROR: PG_CONN environment variable must be set", file=sys.stderr)
        sys.exit(1)

    if not os.path.isdir(args.doc_path):
        print(f"ERROR: Document path does not exist: {args.doc_path}", file=sys.stderr)
        sys.exit(1)

    if args.verbose:
        print(f"Connecting to database...", flush=True)

    try:
        conn = get_db_connection()
    except Exception as e:
        print(f"ERROR: Failed to connect to database: {e}", file=sys.stderr)
        sys.exit(1)

    if args.verbose:
        print(f"Starting ingestion from: {args.doc_path}", flush=True)
        print(f"Supported formats: PDF, TXT, MD", flush=True)
        print("-" * 60, flush=True)

    start_time = time.time()

    try:
        stats = ingest_documents(conn, args.doc_path, verbose=args.verbose)
    except KeyboardInterrupt:
        print("\nIngestion interrupted by user", file=sys.stderr)
        conn.close()
        sys.exit(130)
    except Exception as e:
        print(f"\nERROR: Ingestion failed: {e}", file=sys.stderr)
        conn.close()
        sys.exit(1)

    conn.close()
    elapsed = time.time() - start_time

    # Print summary
    print("-" * 60)
    print("Ingestion complete!")
    print(f"  Files processed: {stats['files_processed']}")
    print(f"  Chunks added:    {stats['chunks_added']}")
    print(f"  Chunks skipped:  {stats['chunks_skipped']}")
    print(f"  Errors:          {stats['errors']}")
    print(f"  Time elapsed:    {elapsed:.2f} seconds")
    print("-" * 60)


if __name__ == "__main__":
    main()
