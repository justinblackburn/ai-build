#!/usr/bin/env python3
"""
RAG + LLM Service - Combines retrieval with generation

Supports multiple LLM backends:
- Ollama (local)
- Anthropic Claude API
- OpenAI API

Environment Variables:
    LLM_BACKEND - Backend to use: ollama, anthropic, openai (default: ollama)
    OLLAMA_URL - Ollama server URL (default: http://localhost:11434)
    OLLAMA_MODEL - Model to use (default: llama2)
    ANTHROPIC_API_KEY - Claude API key
    OPENAI_API_KEY - OpenAI API key
    RAG_API_URL - RAG service URL (default: http://localhost:8090)
    LLM_PORT - Port to run on (default: 8091)
"""
import os
import sys
import json
from typing import List, Dict, Any

import requests
from flask import Flask, jsonify, request

app = Flask(__name__)

# Configuration
LLM_BACKEND = os.getenv("LLM_BACKEND", "ollama")
OLLAMA_URL = os.getenv("OLLAMA_URL", "http://localhost:11434")
OLLAMA_MODEL = os.getenv("OLLAMA_MODEL", "llama2")
RAG_API_URL = os.getenv("RAG_API_URL", "http://localhost:8090")
LLM_PORT = int(os.getenv("LLM_PORT", "8091"))


def query_rag(question: str, limit: int = 5) -> List[Dict[str, Any]]:
    """Query the RAG service for relevant context"""
    try:
        response = requests.post(
            f"{RAG_API_URL}/query",
            json={"query": question, "limit": limit},
            timeout=30
        )
        response.raise_for_status()
        return response.json()
    except Exception as e:
        print(f"Error querying RAG: {e}", file=sys.stderr)
        return []


def query_ollama(prompt: str, model: str = None) -> str:
    """Query Ollama for generation"""
    model = model or OLLAMA_MODEL
    try:
        response = requests.post(
            f"{OLLAMA_URL}/api/generate",
            json={
                "model": model,
                "prompt": prompt,
                "stream": False
            },
            timeout=120
        )
        response.raise_for_status()
        return response.json().get("response", "")
    except Exception as e:
        return f"Error querying Ollama: {e}"


def query_anthropic(prompt: str, model: str = "claude-3-haiku-20240307") -> str:
    """Query Anthropic Claude API"""
    api_key = os.getenv("ANTHROPIC_API_KEY")
    if not api_key:
        return "Error: ANTHROPIC_API_KEY not set"

    try:
        import anthropic
        client = anthropic.Anthropic(api_key=api_key)
        message = client.messages.create(
            model=model,
            max_tokens=1024,
            messages=[{"role": "user", "content": prompt}]
        )
        return message.content[0].text
    except ImportError:
        return "Error: anthropic package not installed"
    except Exception as e:
        return f"Error querying Anthropic: {e}"


def query_openai(prompt: str, model: str = "gpt-3.5-turbo") -> str:
    """Query OpenAI API"""
    api_key = os.getenv("OPENAI_API_KEY")
    if not api_key:
        return "Error: OPENAI_API_KEY not set"

    try:
        import openai
        client = openai.OpenAI(api_key=api_key)
        response = client.chat.completions.create(
            model=model,
            messages=[{"role": "user", "content": prompt}],
            max_tokens=1024
        )
        return response.choices[0].message.content
    except ImportError:
        return "Error: openai package not installed"
    except Exception as e:
        return f"Error querying OpenAI: {e}"


def generate_response(question: str, context_chunks: List[Dict], backend: str = None) -> str:
    """Generate a response using the specified LLM backend"""
    backend = backend or LLM_BACKEND

    # Build context from chunks
    if not context_chunks:
        context = "No relevant context found in the knowledge base."
    else:
        context_parts = []
        for i, chunk in enumerate(context_chunks, 1):
            filename = chunk.get('filename', 'Unknown')
            content = chunk.get('content', '')
            score = chunk.get('score', 0)
            context_parts.append(f"[Source {i}] {filename} (relevance: {score:.2f})\n{content}")
        context = "\n\n".join(context_parts)

    # Build prompt
    prompt = f"""Based on the following context from documentation, answer the user's question.

Context:
{context}

Question: {question}

Answer the question based on the provided context. If the context doesn't contain enough information, say so. Cite sources by referring to [Source N] numbers."""

    # Query appropriate backend
    if backend == "ollama":
        return query_ollama(prompt)
    elif backend == "anthropic":
        return query_anthropic(prompt)
    elif backend == "openai":
        return query_openai(prompt)
    else:
        return f"Error: Unknown backend '{backend}'"


@app.route("/", methods=["GET"])
def health():
    """Health check"""
    return jsonify({
        "status": "healthy",
        "backend": LLM_BACKEND,
        "rag_url": RAG_API_URL
    })


@app.route("/ask", methods=["POST"])
def ask():
    """
    Ask a question and get a generated answer with RAG context

    Request:
        {
            "question": "How do I configure SELinux?",
            "rag_limit": 5,  // optional, default 5
            "backend": "ollama"  // optional, override default
        }

    Response:
        {
            "question": "...",
            "answer": "...",
            "sources": [{"filename": "...", "score": 0.85, "content": "..."}],
            "backend": "ollama"
        }
    """
    payload = request.get_json(force=True) or {}
    question = payload.get("question", "")
    rag_limit = payload.get("rag_limit", 5)
    backend = payload.get("backend", LLM_BACKEND)

    if not question:
        return jsonify({"error": "No question provided"}), 400

    # Get context from RAG
    context_chunks = query_rag(question, limit=rag_limit)

    # Generate answer
    answer = generate_response(question, context_chunks, backend=backend)

    return jsonify({
        "question": question,
        "answer": answer,
        "sources": context_chunks,
        "backend": backend
    })


@app.route("/query", methods=["POST"])
def query_only():
    """
    RAG-only endpoint (no generation) - passes through to RAG service
    """
    payload = request.get_json(force=True) or {}
    question = payload.get("query", "")
    limit = payload.get("limit", 5)

    if not question:
        return jsonify([])

    chunks = query_rag(question, limit=limit)
    return jsonify(chunks)


if __name__ == "__main__":
    print(f"Starting RAG+LLM service on port {LLM_PORT}...", flush=True)
    print(f"  LLM Backend: {LLM_BACKEND}", flush=True)
    print(f"  RAG API: {RAG_API_URL}", flush=True)
    if LLM_BACKEND == "ollama":
        print(f"  Ollama URL: {OLLAMA_URL}", flush=True)
        print(f"  Ollama Model: {OLLAMA_MODEL}", flush=True)
    app.run(host="0.0.0.0", port=LLM_PORT)
