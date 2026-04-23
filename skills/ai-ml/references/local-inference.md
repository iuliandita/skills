# Local Inference

Running models locally with Ollama, vLLM, llama.cpp, and HF Text Generation Inference.
Covers model selection, quantization, GPU memory estimation, and production serving.

---

## Table of Contents

1. When to Run Locally
2. Tool Selection
3. Ollama
4. vLLM
5. Quantization
6. Model Selection
7. GPU Memory Estimation
8. Production Serving

---

## 1. When to Run Locally

### Good reasons

- **Data privacy** - can't send data to external APIs (regulatory, compliance, air-gapped)
- **Cost at scale** - high-volume inference is cheaper self-hosted above ~1M tokens/day
- **Latency** - local inference can be faster than API round-trips for small models
- **Offline / air-gapped** - no internet connectivity available
- **Development** - iterate on prompts without API costs during development
- **Fine-tuned models** - serving custom models not available via APIs

### Bad reasons

- "I want to avoid API costs" (with low volume - self-hosting has significant TCO)
- "I want the best quality" (frontier API models still beat self-hosted open models)
- "It's more secure" (mismanaged self-hosted infra can be less secure than API providers)

---

## 2. Tool Selection

| Tool | Best for | GPU required | OpenAI-compatible API | Production-ready |
|------|----------|-------------|----------------------|-----------------|
| **Ollama** | Dev, prototyping, Mac | No (CPU/MLX) | Yes | Basic |
| **vLLM** | Production serving | Yes | Yes | Yes |
| **llama.cpp** | Minimal deps, CPU | No | Via server mode | Basic |
| **TGI** | HF model hub | Yes | No (custom API) | Yes |

---

## 3. Ollama

### Setup

```bash
# Install
curl -fsSL https://ollama.com/install.sh | sh

# Pull a model
ollama pull llama3.1:8b
ollama pull llama3.1:70b-instruct-q4_K_M  # quantized 70B
ollama pull codellama:13b                   # code-specialized
ollama pull nomic-embed-text                # embeddings

# Run interactive
ollama run llama3.1:8b

# Start server (default port 11434)
ollama serve
```

### API usage (OpenAI-compatible)

```python
from openai import OpenAI

# Point OpenAI client at Ollama
client = OpenAI(base_url="http://localhost:11434/v1", api_key="unused")

response = client.chat.completions.create(
    model="llama3.1:8b",
    messages=[{"role": "user", "content": "Explain TCP handshake"}],
    temperature=0.7,
    max_tokens=512,
)
print(response.choices[0].message.content)
```

```bash
curl http://localhost:11434/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{"model": "llama3.1:8b", "messages": [{"role": "user", "content": "hello"}]}'
```

### Embeddings

```python
response = client.embeddings.create(
    model="nomic-embed-text",
    input=["text to embed"],
)
embedding = response.data[0].embedding
```

### Custom models (Modelfile)

```dockerfile
FROM llama3.1:8b

SYSTEM """You are a DevOps assistant specializing in Kubernetes and Terraform.
Answer concisely with code examples."""

PARAMETER temperature 0.3
PARAMETER num_ctx 8192
```

```bash
ollama create devops-assistant -f Modelfile
ollama run devops-assistant
```

### Ollama 0.19 features

- MLX backend for Apple Silicon (1.6x prefill, ~2x decode speed improvement)
- ROCm 7 support for AMD GPUs (requires updated drivers)
- Remote model registry: `ollama pull` can stream from cloud registries without full local download first
- `--yes` flag for non-interactive environments

---

## 4. vLLM

### Setup

```bash
pip install vllm
```

### Serving

```bash
# Basic serving (OpenAI-compatible API)
python -m vllm.entrypoints.openai.api_server \
  --model meta-llama/Llama-3.1-8B-Instruct \
  --dtype auto \
  --max-model-len 8192 \
  --gpu-memory-utilization 0.9 \
  --port 8000

# Multi-GPU (tensor parallelism)
python -m vllm.entrypoints.openai.api_server \
  --model meta-llama/Llama-3.1-70B-Instruct \
  --tensor-parallel-size 4 \
  --dtype auto \
  --max-model-len 8192
```

### Key features

- **Continuous batching** - serves multiple requests simultaneously, maximizing GPU utilization
- **PagedAttention** - efficient memory management for KV cache, supports more concurrent requests
- **Tensor parallelism** - split a model across multiple GPUs
- **Speculative decoding** - use a smaller draft model to accelerate generation
- **Quantization support** - GPTQ, AWQ, FP8 out of the box

### vLLM vs Ollama

| Feature | Ollama | vLLM |
|---------|--------|------|
| Setup difficulty | Trivial | Moderate |
| CPU inference | Yes | No |
| Apple Silicon (MLX) | Yes | No |
| Throughput (GPU) | Low-medium | High |
| Continuous batching | No | Yes |
| Multi-GPU | Limited | Full support |
| Concurrent users | Few | Many |
| Best for | Dev/single user | Production/multi-user |

---

## 5. Quantization

Reduce model size and memory usage by lowering numerical precision.

### Quantization levels

| Method | Bits | Quality loss | Memory reduction | Speed impact |
|--------|------|-------------|-----------------|-------------|
| FP16/BF16 | 16 | None | 2x vs FP32 | Faster |
| INT8 | 8 | Minimal | 4x vs FP32 | Faster |
| INT4 (GPTQ/AWQ) | 4 | Small | 8x vs FP32 | Depends |
| GGUF Q4_K_M | ~4.8 | Small | ~7x vs FP32 | Good for CPU |
| GGUF Q2_K | ~2.5 | Noticeable | ~12x vs FP32 | Fast but degraded |

### Recommendations

- **Production serving (GPU)**: FP16/BF16 if it fits, INT8 or AWQ/GPTQ if it doesn't
- **Development (GPU)**: INT4 (AWQ or GPTQ) for faster iteration
- **CPU / Apple Silicon**: GGUF Q4_K_M (best quality-to-size ratio for CPU inference)
- **Edge / constrained**: GGUF Q3_K_M or Q2_K (accept quality loss for fit)

### GGUF quantization naming

```
Q4_K_M = 4-bit, K-quants, medium quality (recommended default)
Q5_K_M = 5-bit, better quality, more memory
Q3_K_S = 3-bit, small, noticeable quality loss
Q2_K   = 2-bit, significant quality loss, smallest
```

---

## 6. Model Selection

### By task and resource

| Task | Model | Min VRAM | Notes |
|------|-------|----------|-------|
| General chat (budget) | Llama 3.1 8B | 6 GB (Q4) / 16 GB (FP16) | Good baseline |
| General chat (quality) | Llama 3.1 70B | 40 GB (Q4) / 140 GB (FP16) | Multi-GPU needed |
| Code generation | CodeLlama 34B, DeepSeek-Coder-V2 | 20 GB (Q4) | Code-specialized |
| Embeddings | nomic-embed-text, gte-Qwen2 | 2 GB | Lightweight |
| Vision | Llava, LLaMA 3.2 Vision | 8-16 GB | Multimodal |
| Small / edge | Phi-3 mini (3.8B), Gemma 2 2B | 3-4 GB | Fits on consumer hardware |

### Choosing model size

```
Available VRAM -> max model size at chosen quantization
  6 GB  -> 7-8B at Q4
  12 GB -> 13B at Q4, or 7-8B at FP16
  24 GB -> 34B at Q4, or 13B at FP16
  48 GB -> 70B at Q4
  80 GB -> 70B at FP16
```

---

## 7. GPU Memory Estimation

### Rule of thumb

```
Memory (GB) = Parameters (B) * Bytes per parameter / 1024^3

FP16: 7B model = ~14 GB
INT8: 7B model = ~7 GB
INT4: 7B model = ~3.5 GB
```

Add overhead for KV cache, activations, and the framework itself:

```
Total memory = model weights + KV cache + framework overhead
             = model_size + (2 * num_layers * hidden_dim * seq_len * batch_size * bytes) + ~1-2 GB
```

### Practical memory requirements

| Model | FP16 | INT8 | INT4 (GPTQ/AWQ) |
|-------|------|------|-----------------|
| 7B | 14 GB | 7 GB | 4 GB |
| 13B | 26 GB | 13 GB | 7 GB |
| 34B | 68 GB | 34 GB | 18 GB |
| 70B | 140 GB | 70 GB | 38 GB |

These are minimums. Add 20-30% for KV cache and operational headroom.

---

## 8. Production Serving

### Architecture

```
Load Balancer -> [vLLM instance 1 (GPU 0-1)]
              -> [vLLM instance 2 (GPU 2-3)]
              -> [vLLM instance 3 (GPU 4-5)]
```

### Health checks

```bash
# vLLM health check endpoint
curl http://localhost:8000/health

# Check model loaded
curl http://localhost:8000/v1/models
```

### Monitoring

| Metric | What to track | Alert threshold |
|--------|--------------|-----------------|
| GPU utilization | % GPU compute used | <20% (underutilized) or >95% (saturated) |
| GPU memory | % VRAM used | >90% |
| Request queue depth | Pending requests | >100 (add capacity) |
| Token throughput | Tokens/second generated | Baseline - 20% |
| Latency p99 | 99th percentile response time | >10s for small models |
| Error rate | Failed requests | >1% |

### Scaling considerations

- **Horizontal scaling**: multiple vLLM instances behind a load balancer
- **GPU type**: A100 80GB (best value), H100 (highest performance), L40S (cost-efficient)
- **Batching**: vLLM continuous batching handles this automatically. Don't implement
  your own batching on top.
- **Model caching**: keep models loaded in memory. Cold starts take minutes for large models.
- **Request routing**: route requests by model to dedicated instances. Don't serve multiple
  models on the same GPU unless they're small.
