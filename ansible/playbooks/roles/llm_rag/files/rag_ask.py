#!/usr/bin/env python3
"""
CLI tool for querying RAG+LLM service

Usage:
    rag-ask "How do I configure SELinux?"
    rag-ask --backend anthropic "What is systemd?"
    rag-ask --rag-only "RHCSA exam"
"""
import argparse
import json
import os
import sys

import requests


def main():
    parser = argparse.ArgumentParser(description="Query RAG+LLM service")
    parser.add_argument("question", help="Question to ask")
    parser.add_argument(
        "--url",
        default=os.getenv("RAG_LLM_URL", "http://localhost:8091"),
        help="RAG+LLM service URL"
    )
    parser.add_argument(
        "--backend",
        choices=["ollama", "anthropic", "openai"],
        help="LLM backend to use"
    )
    parser.add_argument(
        "--rag-only",
        action="store_true",
        help="Only retrieve context, don't generate answer"
    )
    parser.add_argument(
        "--rag-limit",
        type=int,
        default=5,
        help="Number of context chunks to retrieve"
    )
    parser.add_argument(
        "--json",
        action="store_true",
        help="Output raw JSON"
    )

    args = parser.parse_args()

    if args.rag_only:
        # Query RAG only
        endpoint = f"{args.url}/query"
        payload = {"query": args.question, "limit": args.rag_limit}
    else:
        # Query RAG+LLM
        endpoint = f"{args.url}/ask"
        payload = {"question": args.question, "rag_limit": args.rag_limit}
        if args.backend:
            payload["backend"] = args.backend

    try:
        response = requests.post(endpoint, json=payload, timeout=120)
        response.raise_for_status()
        data = response.json()

        if args.json:
            print(json.dumps(data, indent=2))
        elif args.rag_only:
            # Display RAG results
            if not data:
                print("No results found.")
                return

            for i, chunk in enumerate(data, 1):
                print(f"\n{'='*80}")
                print(f"[{i}] {chunk['filename']}")
                print(f"Score: {chunk['score']:.2f}")
                print(f"{'-'*80}")
                print(chunk['content'])
        else:
            # Display generated answer
            print(f"\nQuestion: {data['question']}")
            print(f"Backend: {data['backend']}")
            print(f"\n{'='*80}")
            print("Answer:")
            print(f"{'='*80}")
            print(data['answer'])
            print(f"\n{'='*80}")
            print(f"Sources ({len(data['sources'])} found):")
            print(f"{'='*80}")
            for i, source in enumerate(data['sources'], 1):
                print(f"[{i}] {source['filename']} (score: {source['score']:.2f})")

    except requests.exceptions.RequestException as e:
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(1)
    except KeyError as e:
        print(f"Error: Unexpected response format - {e}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
