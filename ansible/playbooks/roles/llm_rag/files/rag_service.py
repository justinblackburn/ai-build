"""
RAG Query Service - Flask API for querying document embeddings

This service provides a REST API for querying documents using vector similarity search.
Ingestion is handled separately by ingest_docs.py to avoid blocking the API server.
"""
import os

from flask import Flask, jsonify, request
from pgvector import Vector

from rag_common import get_db_connection, embed_text


PG_CONN = os.getenv("PG_CONN")
API_PORT = int(os.getenv("API_PORT", "8090"))

app = Flask(__name__)

# Initialize database connection
print("Connecting to database...", flush=True)
conn = get_db_connection()
cur = conn.cursor()
print("Database connection established", flush=True)


@app.route("/", methods=["GET"])
def health():
    """Health check endpoint"""
    try:
        cur.execute("SELECT COUNT(*) FROM docs;")
        count = cur.fetchone()[0]
        return jsonify({
            "status": "healthy",
            "documents_indexed": count
        })
    except Exception as e:
        return jsonify({
            "status": "error",
            "error": str(e)
        }), 500


@app.route("/query", methods=["POST"])
def query():
    """
    Query documents using vector similarity search

    Request body:
        {
            "query": "your question here",
            "limit": 5  # optional, default 5
        }

    Response:
        [
            {
                "filename": "/path/to/document.pdf",
                "content": "relevant chunk of text...",
                "score": 0.85
            },
            ...
        ]
    """
    payload = request.get_json(force=True) or {}
    question = payload.get("query", "")
    limit = payload.get("limit", 5)

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
        LIMIT %s;
        """,
        (embedding, embedding, limit),
    )
    rows = cur.fetchall()
    return jsonify(
        [{"filename": name, "score": float(score), "content": content[:500]} for name, content, score in rows]
    )


@app.route("/stats", methods=["GET"])
def stats():
    """Get statistics about the indexed documents"""
    try:
        cur.execute("SELECT COUNT(DISTINCT filename) FROM docs;")
        file_count = cur.fetchone()[0]

        cur.execute("SELECT COUNT(*) FROM docs;")
        chunk_count = cur.fetchone()[0]

        cur.execute("SELECT pg_size_pretty(pg_total_relation_size('docs'));")
        table_size = cur.fetchone()[0]

        return jsonify({
            "unique_files": file_count,
            "total_chunks": chunk_count,
            "database_size": table_size
        })
    except Exception as e:
        return jsonify({"error": str(e)}), 500


if __name__ == "__main__":
    print(f"Starting RAG query service on port {API_PORT}...", flush=True)
    print("Note: Ingestion is handled separately via ingest_docs.py", flush=True)
    app.run(host="0.0.0.0", port=API_PORT)
