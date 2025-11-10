"""
Common utilities for RAG service and ingestion
"""
import glob
import hashlib
import os
import random
from typing import Iterable, Tuple

import psycopg2
try:
    from langchain_text_splitters import RecursiveCharacterTextSplitter
except ImportError:
    from langchain.text_splitter import RecursiveCharacterTextSplitter
from pdfminer.high_level import extract_text
from pgvector import Vector
from pgvector.psycopg2 import register_vector


def get_db_connection():
    """Create and return a database connection"""
    pg_conn = os.getenv("PG_CONN")
    conn = psycopg2.connect(pg_conn)
    cur = conn.cursor()
    cur.execute("CREATE EXTENSION IF NOT EXISTS vector;")
    conn.commit()
    register_vector(conn)
    cur.execute(
        """
        CREATE TABLE IF NOT EXISTS docs (
          id SERIAL PRIMARY KEY,
          doc_hash TEXT UNIQUE,
          filename TEXT,
          content TEXT,
          embedding vector(768)
        );
        """
    )
    conn.commit()
    return conn


def embed_text(text: str):
    """Generate deterministic embedding for text"""
    seed = int.from_bytes(hashlib.sha256(text.encode("utf-8")).digest()[:8], "big")
    rng = random.Random(seed)
    return [rng.uniform(-1.0, 1.0) for _ in range(768)]


def iter_documents(doc_path: str) -> Iterable[Tuple[str, str]]:
    """Iterate through all supported documents in doc_path"""
    for filepath in glob.glob(os.path.join(doc_path, "**"), recursive=True):
        if not os.path.isfile(filepath):
            continue
        ext = os.path.splitext(filepath)[1].lower()
        if ext not in {".pdf", ".txt", ".md"}:
            continue
        if ext == ".pdf":
            try:
                raw = extract_text(filepath)
            except Exception:
                continue
        else:
            try:
                with open(filepath, "r", encoding="utf-8", errors="ignore") as handle:
                    raw = handle.read()
            except OSError:
                continue
        yield filepath, raw


def ingest_documents(conn, doc_path: str, verbose: bool = False):
    """
    Ingest all documents from doc_path into the database

    Args:
        conn: Database connection
        doc_path: Path to documents directory
        verbose: Print progress information

    Returns:
        dict with stats about ingestion
    """
    cur = conn.cursor()
    splitter = RecursiveCharacterTextSplitter(chunk_size=800, chunk_overlap=200)

    stats = {
        "files_processed": 0,
        "chunks_added": 0,
        "chunks_skipped": 0,
        "errors": 0
    }

    for filename, raw in iter_documents(doc_path):
        try:
            stats["files_processed"] += 1
            if verbose:
                print(f"Processing: {filename}", flush=True)

            for chunk in splitter.split_text(raw):
                digest = hashlib.sha1(chunk.encode("utf-8")).hexdigest()
                cur.execute("SELECT 1 FROM docs WHERE doc_hash = %s;", (digest,))
                if cur.fetchone():
                    stats["chunks_skipped"] += 1
                    continue

                embedding = embed_text(chunk)
                cur.execute(
                    """
                    INSERT INTO docs (doc_hash, filename, content, embedding)
                    VALUES (%s, %s, %s, %s);
                    """,
                    (digest, filename, chunk, Vector(embedding)),
                )
                stats["chunks_added"] += 1

            # Commit after each file to avoid losing progress
            conn.commit()

            if verbose and stats["files_processed"] % 10 == 0:
                print(f"Progress: {stats['files_processed']} files, "
                      f"{stats['chunks_added']} chunks added, "
                      f"{stats['chunks_skipped']} skipped", flush=True)

        except Exception as e:
            stats["errors"] += 1
            if verbose:
                print(f"Error processing {filename}: {e}", flush=True)
            conn.rollback()
            continue

    conn.commit()
    return stats
