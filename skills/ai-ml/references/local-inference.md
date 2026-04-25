# Local Inference

Running models locally with Ollama, vLLM, llama.cpp, and HF Text Generation Inference.
Covers model selection, quantization, GPU memory estimation, CPU-only deployments, and
production serving.

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
9. llama.cpp from source (CPU-only)
10. Benchmarking methodology
11. NUMA, threading, mlock

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

---

## 9. llama.cpp from source (CPU-only)

When `pip install llama-cpp-python` or `ollama` prebuilts crash with SIGILL, you're hitting
the AVX2 cliff. Build from source with the right cmake flags for your CPU generation.

### Detect ISA support

```bash
grep -o 'avx[2]*\|fma\|bmi2\|f16c' /proc/cpuinfo | sort -u
```

### Build flags by CPU generation

| Generation | AVX | AVX2 | FMA | BMI2 | F16C | AVX-512 |
|---|---|---|---|---|---|---|
| Sandy/Ivy Bridge (2011-2013) | yes | NO | NO | NO | yes (Ivy+) | NO |
| Haswell/Broadwell (2013-2015) | yes | yes | yes | yes | yes | NO |
| Skylake-X / Cascade Lake (2017+) | yes | yes | yes | yes | yes | yes |
| Zen 1/2 (2017-2019) | yes | yes | yes | yes | yes | NO |
| Zen 3+ (2020+) | yes | yes | yes | yes | yes | yes (Zen 4+) |

Set `-DGGML_<feature>=OFF` for any feature your CPU lacks. Setting one wrong produces a
binary that links cleanly and SIGILLs on the first matrix multiply.

### Full build for pre-Haswell

```bash
sudo apt install -y build-essential cmake git ccache libcurl4-openssl-dev

git clone https://github.com/ggml-org/llama.cpp.git /opt/llama.cpp
cd /opt/llama.cpp
git checkout b8920  # pin a known-good tag

cmake -B build \
  -DGGML_NATIVE=OFF \
  -DGGML_AVX=ON -DGGML_AVX2=OFF -DGGML_FMA=OFF \
  -DGGML_F16C=ON -DGGML_BMI2=OFF \
  -DGGML_AVX512=OFF -DGGML_AVX512_VBMI=OFF -DGGML_AVX512_VNNI=OFF \
  -DGGML_AVX_VNNI=OFF -DGGML_CUDA=OFF \
  -DLLAMA_CURL=ON -DCMAKE_BUILD_TYPE=Release

cmake --build build --config Release -j"$(nproc)"
sudo cmake --install build --prefix /usr/local
```

### Pin model files reproducibly

```bash
# Pin both file and revision (HF commit SHA)
huggingface-cli download \
  unsloth/Qwen3-30B-A3B-GGUF Qwen3-30B-A3B-Q4_K_M.gguf \
  --revision d5b1d57bd0b504ac62ae6c725904e96ef228dc74 \
  --local-dir /var/lib/llama/models
```

A bare repo+filename pulls "whatever the author serves now". Author rebases silently change
runtime behavior.

### Run as a server

```bash
llama-server \
  --model /var/lib/llama/models/Qwen3-30B-A3B-Q4_K_M.gguf \
  --host 0.0.0.0 --port 8080 \
  --ctx-size 32768 --cache-reuse 256 \
  --threads 28 --threads-batch 32 \
  --temp 0.7 --top-k 20 --top-p 0.8 \
  --mlock --api-key-file /etc/llama/api-key.txt
```

Endpoint is OpenAI-compatible at `/v1/chat/completions`. Point any OpenAI client at it.

### One systemd unit per model

For multi-model deployment, create one `llama-server-<alias>.service` per model on its own
port. Independent unit files mean independent restarts, separate logs, and no shared crash
blast radius. Don't try to multiplex multiple models behind a single llama-server process.

---

## 10. Benchmarking methodology

Establish baseline numbers before tuning anything. Re-bench after every model swap,
llama.cpp version bump, or cmake flag change.

### Fixed prompt suite

A reusable benchmark needs five prompts at minimum:

| Class | Prompt shape | Why |
|---|---|---|
| chat-short | "What is X?" (1 sentence answer) | Pure decode latency, low prefill cost |
| chat-long | Multi-turn context (~32 tokens prompt) | KV cache reuse behavior |
| code-simple | "Write a Python function that..." | Short prefill, long decode |
| code-complex | Diff-style refactor with 50+ tokens of context | Realistic prefill |
| reasoning | Math word problem requiring chain-of-thought | Tests sustained decode |

For each: warm up once (discard), then record `latency`, `prompt_tokens`, `completion_tokens`,
and `decode_tok_per_sec` over a fixed `max_tokens` cap (e.g., 400) at fixed temperature
(e.g., 0.3 - low for reproducibility).

### Output format

Versioned markdown table per run. The header captures host, started-at, max_tokens,
temperature, and warmup. Diffs across runs become readable.

```markdown
# AI VM Model Benchmark
- Host: http://192.168.x.x
- Started: 2026-04-25T01:19:12+02:00
- max_tokens: 400, temperature: 0.3, warmup: yes

| model | test | latency (s) | prompt_tok | completion_tok | decode t/s |
|---|---|---:|---:|---:|---:|
| qwen3-30b-a3b-q4 | chat-short | 24.37 | 19 | 327 | 13.42 |
```

### What to actually compare

- **decode t/s** (not latency) - latency conflates prefill cost with decode speed
- **decode t/s at fixed completion_tokens** - short outputs misleadingly look fast
- **across model classes**, not just within one - MoE vs dense at the same parameter count is
  the most informative comparison

### Pitfalls

- Cold cache vs warm cache: always include a discarded warmup
- Background load: bench on an otherwise-idle host
- mlock at first run: model paging in inflates the first measurement

---

## 11. NUMA, threading, mlock

### NUMA on multi-socket hosts

Multi-socket servers expose two memory controllers. Inference threads ping-ponging across
sockets pay a cross-socket latency penalty. Three options:

- **distribute** (default): kernel spreads pages across nodes. Simple, often fine.
- **isolate** with `numactl --cpunodebind=0 --membind=0`: pin one model to one socket.
  Better for single-model serving on a dual-socket box where the model fits in one node's RAM.
- **interleave** with `numactl --interleave=all`: stripe pages across nodes. Helps when the
  model is bigger than one node's RAM.

Per-model override is the right granularity. Some models prefer isolation, others don't care.

### Thread tuning

```
total_threads = physical_cores            # don't include SMT siblings for decode
threads (-t)  = physical_cores - 4        # leave 4 cores for OS, llama-server overhead, OWUI
threads_batch (-tb) = logical_cores       # prefill scales with all logical cores
```

Going past `physical_cores` for decode hurts: cache thrashing dominates. Going under
`logical_cores` for prefill leaves throughput on the table during prompt processing.

### mlock implications

`--mlock` (or `LimitMEMLOCK=infinity` in systemd) page-faults the entire GGUF into RAM at
service start. Three consequences:

1. **Eager memory accounting.** Sum the GGUF sizes of all `llama-server-*` units running on
   the host. That's your committed RAM, before KV cache.
2. **Slow first-request penalty disappears.** Without mlock, the first inference request
   triggers page-ins that look like a 30-60 second hang on big models.
3. **OOM killer is the failure mode.** Run `free -h` and verify `available` exceeds the sum
   of GGUF sizes plus headroom (~10% per model for KV cache at advertised ctx).

Disable mlock on memory-constrained hosts where you're willing to trade first-request
latency for safer overcommit behavior.
