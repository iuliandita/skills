# RAG Patterns

Detailed patterns for building retrieval-augmented generation pipelines. Covers chunking,
embedding, indexing, retrieval, hybrid search, reranking, and production architecture.

---

## Table of Contents

1. Pipeline Overview
2. Document Processing
3. Chunking Strategies
4. Embedding Pipelines
5. Vector Store Setup
6. Retrieval Strategies
7. Generation with Context
8. Production Architecture
9. Common Failures

---

## 1. Pipeline Overview

```
Documents -> Chunking -> Embedding -> Vector Store (indexing)
                                         |
User Query -> Embedding -> Vector Search -> Reranking -> Context Assembly -> LLM -> Response
```

Two separate flows: **indexing** (offline/batch) and **retrieval** (online/per-request).
Optimize them independently.

---

## 2. Document Processing

### Supported sources

Use document loaders to normalize content before chunking:

| Source | Tool | Notes |
|--------|------|-------|
| PDF | `pymupdf`, `pdfplumber` | pymupdf is faster, pdfplumber better for tables |
| HTML | `beautifulsoup4`, `trafilatura` | trafilatura extracts main content, strips boilerplate |
| Markdown | Direct parsing | Preserve headers for section-aware chunking |
| Code | Tree-sitter, language-specific parsers | Chunk by function/class, not arbitrary lines |
| Word/PPTX | `python-docx`, `python-pptx` | Extract text + structure |
| CSV/structured | `pandas` | Convert rows to text with column context |

### Preprocessing checklist

- [ ] Remove boilerplate (headers, footers, navigation, ads)
- [ ] Normalize whitespace and encoding (UTF-8)
- [ ] Extract and preserve metadata (title, date, author, URL)
- [ ] Handle tables - convert to text with column headers or extract separately
- [ ] Detect and handle code blocks differently from prose
- [ ] Remove or replace images with alt text / captions

---

## 3. Chunking Strategies

### Fixed-size with overlap (default starting point)

```python
def chunk_fixed(text: str, chunk_size: int = 1000, overlap: int = 200) -> list[str]:
    chunks = []
    start = 0
    while start < len(text):
        end = start + chunk_size
        chunks.append(text[start:end])
        start = end - overlap
    return chunks
```

Good enough for most use cases. Start here, optimize later.

### Recursive character splitting (LangChain default)

Splits on paragraph breaks first, then sentences, then words. Respects natural boundaries:

```python
from langchain_text_splitters import RecursiveCharacterTextSplitter

splitter = RecursiveCharacterTextSplitter(
    chunk_size=1000,
    chunk_overlap=200,
    separators=["\n\n", "\n", ". ", " ", ""],
)
chunks = splitter.split_text(document_text)
```

### Semantic chunking

Group sentences by embedding similarity. Produces variable-size chunks that respect
topic boundaries:

```python
from langchain_experimental.text_splitter import SemanticChunker
from langchain_openai import OpenAIEmbeddings

chunker = SemanticChunker(
    OpenAIEmbeddings(),
    breakpoint_threshold_type="percentile",
    breakpoint_threshold_amount=90,
)
chunks = chunker.split_text(document_text)
```

Higher quality but slower and more expensive (requires embedding calls during chunking).

### Parent-child chunking

Index small chunks for precision, but retrieve parent (larger) chunks for context:

```python
# Small chunks for retrieval (256 tokens)
# When a small chunk matches, return the parent section (2048 tokens)
# This gives precise matching with sufficient context for the LLM

parent_chunks = split_by_section(document)  # large, ~2048 tokens
for parent in parent_chunks:
    children = split_fixed(parent.text, chunk_size=256, overlap=50)
    for child in children:
        store(child, metadata={"parent_id": parent.id})

# At query time: retrieve child, fetch parent for context
```

### Choosing chunk size

| Chunk size | Tradeoff |
|-----------|----------|
| Small (128-256 tokens) | More precise retrieval, less context per chunk, needs more chunks |
| Medium (512-1024 tokens) | Good balance for most use cases |
| Large (1024-2048 tokens) | More context per chunk, less precise matching, fewer chunks needed |

Start with 512-1024 tokens. Adjust based on eval results, not intuition.

---

## 4. Embedding Pipelines

### Batch embedding

Always batch embedding calls. Single-document embedding is wasteful:

```python
from openai import OpenAI

client = OpenAI()

def embed_batch(texts: list[str], model: str = "text-embedding-3-large") -> list[list[float]]:
    # API accepts up to 2048 texts per batch (OpenAI)
    response = client.embeddings.create(input=texts, model=model)
    return [item.embedding for item in response.data]
```

### Dimension reduction

OpenAI's `text-embedding-3-large` supports a `dimensions` parameter to reduce vector size
without re-training. Lower dimensions = less storage, faster search, slightly lower quality:

```python
response = client.embeddings.create(
    input=texts,
    model="text-embedding-3-large",
    dimensions=1024,  # default 3072, reduce for cost/speed tradeoff
)
```

### Metadata enrichment

Attach metadata to chunks for filtering at query time:

```python
{
    "text": "chunk content here",
    "embedding": [0.1, 0.2, ...],
    "metadata": {
        "source": "docs/api-reference.md",
        "section": "Authentication",
        "date_modified": "2026-03-15",
        "doc_type": "api_docs",
    }
}
```

Filter on metadata before vector search to reduce search space and improve relevance.

---

## 5. Vector Store Setup

### pgvector (PostgreSQL)

```sql
-- Enable the extension
CREATE EXTENSION IF NOT EXISTS vector;

-- Create table with vector column
CREATE TABLE documents (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    content TEXT NOT NULL,
    embedding vector(1024) NOT NULL,  - match your model's dimensions
    metadata JSONB DEFAULT '{}',
    created_at TIMESTAMPTZ DEFAULT now()
);

-- HNSW index (recommended for most use cases)
CREATE INDEX ON documents
    USING hnsw (embedding vector_cosine_ops)
    WITH (m = 16, ef_construction = 64);

-- Query
SELECT id, content, 1 - (embedding <=> $1::vector) AS similarity
FROM documents
WHERE metadata->>'doc_type' = 'api_docs'
ORDER BY embedding <=> $1::vector
LIMIT 10;
```

### Qdrant

```python
from qdrant_client import QdrantClient
from qdrant_client.models import Distance, VectorParams, PointStruct

client = QdrantClient(url="http://localhost:6333")

client.create_collection(
    collection_name="documents",
    vectors_config=VectorParams(size=1024, distance=Distance.COSINE),
)

# Upsert with metadata
client.upsert(
    collection_name="documents",
    points=[
        PointStruct(
            id=i,
            vector=embedding,
            payload={"content": text, "source": source, "doc_type": "api_docs"},
        )
        for i, (embedding, text, source) in enumerate(data)
    ],
)

# Query with metadata filter
results = client.query_points(
    collection_name="documents",
    query=query_embedding,
    query_filter={"must": [{"key": "doc_type", "match": {"value": "api_docs"}}]},
    limit=10,
)
```

### ChromaDB (local development)

```python
import chromadb

client = chromadb.Client()  # in-memory, or PersistentClient("./chroma_data")

collection = client.create_collection("documents")

collection.add(
    ids=["doc1", "doc2"],
    documents=["first document text", "second document text"],
    metadatas=[{"source": "file1.md"}, {"source": "file2.md"}],
    # ChromaDB can auto-embed if you configure an embedding function
)

results = collection.query(query_texts=["search query"], n_results=5)
```

### Pinecone

```python
from pinecone import Pinecone

pc = Pinecone()  # reads PINECONE_API_KEY
index = pc.Index("documents")

# Upsert
index.upsert(
    vectors=[
        {"id": "doc1", "values": embedding, "metadata": {"source": "file1.md"}},
    ],
    namespace="production",
)

# Query with metadata filter
results = index.query(
    vector=query_embedding,
    top_k=10,
    filter={"source": {"$eq": "file1.md"}},
    include_metadata=True,
    namespace="production",
)
```

---

## 6. Retrieval Strategies

### Hybrid search (recommended default)

Combine vector similarity with keyword matching (BM25) for best results:

```python
# Qdrant hybrid search example
from qdrant_client.models import SparseVector

results = client.query_points(
    collection_name="documents",
    prefetch=[
        # Dense vector search
        {"query": dense_embedding, "using": "dense", "limit": 50},
        # Sparse (BM25) search
        {"query": SparseVector(indices=sparse_indices, values=sparse_values),
         "using": "sparse", "limit": 50},
    ],
    query={"fusion": "rrf"},  # Reciprocal Rank Fusion to merge results
    limit=10,
)
```

### Reranking

Retrieve more candidates with fast vector search, then rerank with a more accurate
cross-encoder model:

```python
import cohere

co = cohere.Client()

# Step 1: retrieve top 50 with vector search (fast, approximate)
candidates = vector_store.query(query_embedding, limit=50)

# Step 2: rerank with cross-encoder (slow, accurate)
reranked = co.rerank(
    model="rerank-v3.5",
    query=user_query,
    documents=[c.text for c in candidates],
    top_n=5,
)
```

### Query expansion

Rephrase the user query to improve retrieval coverage:

```python
def expand_query(original_query: str) -> list[str]:
    """Generate alternative phrasings for better retrieval coverage."""
    response = client.messages.create(
        model="claude-haiku-4-5-20251001",
        max_tokens=256,
        messages=[{
            "role": "user",
            "content": (
                f"Generate 3 alternative phrasings of this search query. "
                f"Return only the queries, one per line.\n\nQuery: {original_query}"
            ),
        }],
    )
    alternatives = response.content[0].text.strip().split("\n")
    return [original_query] + alternatives
```

### Multi-index retrieval

For different document types (code, docs, issues), maintain separate indexes and merge results:

```python
results = []
for index_name in ["code", "documentation", "issues"]:
    hits = vector_store.query(
        collection=index_name, query=query_embedding, limit=5
    )
    results.extend(hits)

# Sort by relevance score across all indexes
results.sort(key=lambda x: x.score, reverse=True)
context_chunks = results[:10]
```

---

## 7. Generation with Context

### Context assembly

```python
def build_prompt(query: str, chunks: list[dict]) -> str:
    context = "\n\n---\n\n".join(
        f"Source: {c['metadata']['source']}\n{c['content']}"
        for c in chunks
    )
    return f"""Answer the question based on the provided context. If the context doesn't
contain enough information, say so - don't make up an answer.

Context:
{context}

Question: {query}"""
```

### Source attribution

Include source references in the prompt instructions so the model can cite them:

```python
system = """You are a technical assistant. When answering, cite your sources using
[Source: filename] notation. Only use information from the provided context."""
```

### Relevance thresholds

Don't pass low-similarity chunks to the model. They add noise and increase cost:

```python
SIMILARITY_THRESHOLD = 0.7  # adjust based on eval results

filtered_chunks = [c for c in results if c.score >= SIMILARITY_THRESHOLD]

if not filtered_chunks:
    return "I don't have enough relevant information to answer that question."
```

---

## 8. Production Architecture

### Indexing pipeline

```
Source docs -> Change detection -> Document loader -> Preprocessor
    -> Chunker -> Embedder (batch) -> Vector store upsert
```

- Run indexing as a batch job (cron, CI trigger, webhook on doc changes)
- Track document versions to avoid re-indexing unchanged content
- Store raw documents alongside vectors for debugging and re-indexing
- Monitor embedding API costs per indexing run

### Query pipeline

```
User query -> Input validation -> Query embedding -> Vector search
    -> Metadata filter -> Reranking (optional) -> Context assembly
    -> LLM generation -> Output validation -> Response
```

- Cache embedding calls for repeated queries
- Cache LLM responses for identical (query, context) pairs
- Set timeout on vector search (500ms max for user-facing)
- Log retrieval scores for quality monitoring

### Monitoring

Track these metrics continuously:

| Metric | What it tells you | Alert threshold |
|--------|------------------|-----------------|
| Retrieval recall@k | Are relevant docs being found? | <0.8 for k=10 |
| Avg similarity score | Is retrieval quality degrading? | Drop >10% week-over-week |
| No-result rate | How often does retrieval find nothing? | >15% of queries |
| Latency p95 | Is the pipeline fast enough? | >2s for user-facing |
| Token cost per query | Is context too large? | Track trend, alert on spikes |

---

## 9. Common Failures

| Failure | Symptom | Fix |
|---------|---------|-----|
| Wrong embedding model at query time | Retrieval returns irrelevant results | Ensure same model for index and query |
| Chunks too large | Model ignores relevant details | Reduce chunk size, try parent-child |
| Chunks too small | Retrieved chunks lack context | Increase size, add overlap, use parent-child |
| No metadata filtering | Irrelevant docs from other domains | Add metadata at indexing, filter at query |
| Missing overlap | Information at chunk boundaries lost | Add 10-20% overlap between chunks |
| Stale index | Answers are outdated | Automate re-indexing on content changes |
| Low similarity threshold | Noise in context | Raise threshold, add reranking |
| No relevance check | Model hallucinates from bad context | Add similarity threshold, handle no-results |
