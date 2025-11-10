#!/usr/bin/env python3
"""
Document Ingestion Script for Weaviate

Ingests documents from DOC_PATH into Weaviate vector database.
Run this separately from the API service to avoid blocking startup.

Usage:
    python ingest_docs_weaviate.py [--verbose] [--doc-path /path/to/docs]
"""
import argparse
import os
import sys

from rag_common_weaviate import get_weaviate_client, ingest_documents


def main():
    parser = argparse.ArgumentParser(description="Ingest documents into Weaviate")
    parser.add_argument(
        "--verbose", "-v",
        action="store_true",
        help="Print verbose progress information"
    )
    parser.add_argument(
        "--doc-path",
        default=os.getenv("DOC_PATH", "/srv/docs"),
        help="Path to documents directory (default: /srv/docs)"
    )

    args = parser.parse_args()

    if not os.path.isdir(args.doc_path):
        print(f"Error: Document path '{args.doc_path}' does not exist", file=sys.stderr)
        sys.exit(1)

    print(f"Starting document ingestion from: {args.doc_path}", flush=True)
    print(f"Connecting to Weaviate...", flush=True)

    try:
        client = get_weaviate_client()
    except Exception as e:
        print(f"Error connecting to Weaviate: {e}", file=sys.stderr)
        sys.exit(1)

    print("Running ingestion...", flush=True)
    stats = ingest_documents(client, args.doc_path, verbose=args.verbose)

    print("\n" + "=" * 60, flush=True)
    print("Ingestion Complete", flush=True)
    print("=" * 60, flush=True)
    print(f"Files processed: {stats['files_processed']}", flush=True)
    print(f"Chunks added: {stats['chunks_added']}", flush=True)
    print(f"Chunks skipped (duplicates): {stats['chunks_skipped']}", flush=True)
    print(f"Errors: {stats['errors']}", flush=True)
    print("=" * 60, flush=True)

    client.close()


if __name__ == "__main__":
    main()
