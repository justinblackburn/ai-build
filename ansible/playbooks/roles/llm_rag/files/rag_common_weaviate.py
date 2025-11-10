"""
Common utilities for RAG service with Weaviate backend
"""
import glob
import hashlib
import os
import random
from typing import Iterable, Tuple, List, Dict, Any

try:
    from langchain_text_splitters import RecursiveCharacterTextSplitter
except ImportError:
    from langchain.text_splitter import RecursiveCharacterTextSplitter
from pdfminer.high_level import extract_text
import weaviate
from weaviate.classes.config import Configure, Property, DataType


WEAVIATE_URL = os.getenv("WEAVIATE_URL", "http://localhost:8080")
COLLECTION_NAME = "Documents"


def get_weaviate_client():
    """Create and return a Weaviate client"""
    client = weaviate.connect_to_local(host=WEAVIATE_URL.replace("http://", "").split(":")[0])

    # Create collection if it doesn't exist
    if not client.collections.exists(COLLECTION_NAME):
        client.collections.create(
            name=COLLECTION_NAME,
            properties=[
                Property(name="filename", data_type=DataType.TEXT),
                Property(name="content", data_type=DataType.TEXT),
                Property(name="doc_hash", data_type=DataType.TEXT),
            ],
            vectorizer_config=Configure.Vectorizer.none(),  # We provide our own vectors
        )

    return client


def embed_text(text: str) -> List[float]:
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
        if ext not in {".pdf", ".txt", ".md", ".rst", ".py", ".js", ".go", ".sh"}:
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


def ingest_documents(client, doc_path: str, verbose: bool = False) -> Dict[str, int]:
    """
    Ingest all documents from doc_path into Weaviate

    Args:
        client: Weaviate client
        doc_path: Path to documents directory
        verbose: Print progress information

    Returns:
        dict with stats about ingestion
    """
    collection = client.collections.get(COLLECTION_NAME)
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

                # Check if chunk already exists
                response = collection.query.fetch_objects(
                    filters=weaviate.classes.query.Filter.by_property("doc_hash").equal(digest),
                    limit=1
                )

                if len(response.objects) > 0:
                    stats["chunks_skipped"] += 1
                    continue

                # Add new chunk
                embedding = embed_text(chunk)
                collection.data.insert(
                    properties={
                        "filename": filename,
                        "content": chunk,
                        "doc_hash": digest
                    },
                    vector=embedding
                )
                stats["chunks_added"] += 1

            if verbose and stats["files_processed"] % 10 == 0:
                print(f"Progress: {stats['files_processed']} files, "
                      f"{stats['chunks_added']} chunks added, "
                      f"{stats['chunks_skipped']} skipped", flush=True)

        except Exception as e:
            stats["errors"] += 1
            if verbose:
                print(f"Error processing {filename}: {e}", flush=True)
            continue

    return stats


def query_documents(client, query: str, limit: int = 5) -> List[Dict[str, Any]]:
    """
    Query documents using vector similarity search

    Args:
        client: Weaviate client
        query: Search query
        limit: Maximum number of results

    Returns:
        List of matching documents with scores
    """
    collection = client.collections.get(COLLECTION_NAME)
    query_vector = embed_text(query)

    response = collection.query.near_vector(
        near_vector=query_vector,
        limit=limit,
        return_metadata=["distance"]
    )

    results = []
    for obj in response.objects:
        # Convert distance to similarity score (0-1, higher is better)
        distance = obj.metadata.distance if obj.metadata.distance else 1.0
        score = 1.0 / (1.0 + distance)

        results.append({
            "filename": obj.properties["filename"],
            "content": obj.properties["content"][:500],
            "score": score
        })

    return results


def get_stats(client) -> Dict[str, Any]:
    """Get statistics about indexed documents"""
    collection = client.collections.get(COLLECTION_NAME)

    # Get total chunk count
    agg = collection.aggregate.over_all(total_count=True)
    chunk_count = agg.total_count

    # Get unique files (need to query all and deduplicate)
    response = collection.query.fetch_objects(limit=10000)
    filenames = set(obj.properties["filename"] for obj in response.objects)
    file_count = len(filenames)

    return {
        "unique_files": file_count,
        "total_chunks": chunk_count,
        "backend": "weaviate"
    }
