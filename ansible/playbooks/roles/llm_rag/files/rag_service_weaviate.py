"""
RAG Query Service with Weaviate - Flask API for querying document embeddings

This service provides a REST API for querying documents using Weaviate vector database.
Ingestion is handled separately by ingest_docs_weaviate.py to avoid blocking the API server.
"""
import os

from flask import Flask, jsonify, request

from rag_common_weaviate import get_weaviate_client, query_documents, get_stats


API_PORT = int(os.getenv("API_PORT", "8090"))

app = Flask(__name__)

# Initialize Weaviate client
print("Connecting to Weaviate...", flush=True)
client = get_weaviate_client()
print("Weaviate connection established", flush=True)


@app.route("/", methods=["GET"])
def health():
    """Health check endpoint"""
    try:
        stats = get_stats(client)
        return jsonify({
            "status": "healthy",
            "documents_indexed": stats["total_chunks"],
            "backend": "weaviate"
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

    try:
        results = query_documents(client, question, limit=limit)
        return jsonify(results)
    except Exception as e:
        return jsonify({"error": str(e)}), 500


@app.route("/stats", methods=["GET"])
def stats():
    """Get statistics about the indexed documents"""
    try:
        return jsonify(get_stats(client))
    except Exception as e:
        return jsonify({"error": str(e)}), 500


if __name__ == "__main__":
    print(f"Starting RAG query service (Weaviate backend) on port {API_PORT}...", flush=True)
    print("Note: Ingestion is handled separately via ingest_docs_weaviate.py", flush=True)
    app.run(host="0.0.0.0", port=API_PORT)
