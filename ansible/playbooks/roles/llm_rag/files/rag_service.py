import glob
import hashlib
import os
import random
from typing import Iterable, Tuple

import psycopg2
from flask import Flask, jsonify, request
try:
    from langchain_text_splitters import RecursiveCharacterTextSplitter
except ImportError:
    from langchain.text_splitter import RecursiveCharacterTextSplitter
from pdfminer.high_level import extract_text
from pgvector import Vector
from pgvector.psycopg2 import register_vector

PG_CONN = os.getenv("PG_CONN")
DOC_PATH = os.getenv("DOC_PATH", "/srv/docs")
API_PORT = int(os.getenv("API_PORT", "8090"))

app = Flask(__name__)
conn = psycopg2.connect(PG_CONN)
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


def embed_text(text: str):
    seed = int.from_bytes(hashlib.sha256(text.encode("utf-8")).digest()[:8], "big")
    rng = random.Random(seed)
    return [rng.uniform(-1.0, 1.0) for _ in range(768)]


def iter_documents() -> Iterable[Tuple[str, str]]:
    for filepath in glob.glob(os.path.join(DOC_PATH, "**"), recursive=True):
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


def ingest():
    splitter = RecursiveCharacterTextSplitter(chunk_size=800, chunk_overlap=200)
    for filename, raw in iter_documents():
        for chunk in splitter.split_text(raw):
            digest = hashlib.sha1(chunk.encode("utf-8")).hexdigest()
            cur.execute("SELECT 1 FROM docs WHERE doc_hash = %s;", (digest,))
            if cur.fetchone():
                continue
            embedding = embed_text(chunk)
            cur.execute(
                """
                INSERT INTO docs (doc_hash, filename, content, embedding)
                VALUES (%s, %s, %s, %s);
                """,
                (digest, filename, chunk, Vector(embedding)),
            )
    conn.commit()


@app.route("/query", methods=["POST"])
def query():
    payload = request.get_json(force=True) or {}
    question = payload.get("query", "")
    if not question:
        return jsonify([])
    embedding = Vector(embed_text(question))
    cur.execute(
        """
        SELECT filename,
               content,
               1 - (embedding <#> %s) AS score
        FROM docs
        ORDER BY embedding <-> %s
        LIMIT 5;
        """,
        (embedding, embedding),
    )
    rows = cur.fetchall()
    return jsonify(
        [{"filename": name, "score": float(score), "content": content[:500]} for name, content, score in rows]
    )


if __name__ == "__main__":
    ingest()
    app.run(host="0.0.0.0", port=API_PORT)
