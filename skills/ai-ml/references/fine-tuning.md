# Fine-Tuning Guide

When to fine-tune, data preparation, PEFT/LoRA patterns, full fine-tuning, and evaluation
during training.

---

## Table of Contents

1. Decision Framework
2. Data Preparation
3. PEFT / LoRA
4. Full Fine-Tuning
5. Evaluation During Training
6. Deployment
7. Common Mistakes

---

## 1. Decision Framework

### When to fine-tune

- Prompt engineering can't capture the desired behavior consistently
- Need a specific style, format, or tone across thousands of outputs
- Need lower latency than RAG provides (no retrieval step)
- Domain specialization where the base model lacks knowledge
- Classification or extraction tasks with well-defined categories
- Cost optimization -- a fine-tuned small model can match a large model's quality at lower
  inference cost for narrow tasks

### When NOT to fine-tune

- **Data changes frequently** -- use RAG instead. Fine-tuning bakes knowledge into weights;
  updating requires retraining.
- **Fewer than 100 high-quality examples** -- insufficient data produces overfitting, not
  specialization. Try few-shot prompting first.
- **Prompt engineering works** -- if a well-crafted prompt gets 90%+ accuracy, fine-tuning
  adds complexity without proportional benefit.
- **The task is general-purpose** -- fine-tuning narrows model capabilities. A fine-tuned
  model may be worse at tasks outside its training domain.
- **You don't have eval infrastructure** -- without structured evaluation, you can't measure
  if fine-tuning actually helped. Set up evals first.

### Decision tree

```
Does prompt engineering work well enough?
  YES -> Don't fine-tune
  NO -> Does the knowledge change frequently?
    YES -> Use RAG
    NO -> Do you have 100+ high-quality examples?
      NO -> Collect more data, use few-shot for now
      YES -> Do you need the model to behave differently (style/format)?
        YES -> Fine-tune
        NO -> Do you need domain-specific knowledge?
          YES -> RAG (or fine-tune if latency matters)
          NO -> Revisit prompt engineering
```

---

## 2. Data Preparation

### Data format

Most fine-tuning APIs expect conversation-format JSONL:

```jsonl
{"messages": [{"role": "system", "content": "You are a medical coding assistant."}, {"role": "user", "content": "Code this diagnosis: chest pain, non-cardiac"}, {"role": "assistant", "content": "R07.89 - Other chest pain"}]}
{"messages": [{"role": "system", "content": "You are a medical coding assistant."}, {"role": "user", "content": "Code this diagnosis: type 2 diabetes with neuropathy"}, {"role": "assistant", "content": "E11.40 - Type 2 diabetes mellitus with diabetic neuropathy, unspecified"}]}
```

### Data quality checklist

- [ ] Examples are diverse -- cover the full range of expected inputs
- [ ] Outputs follow a consistent format and style
- [ ] No contradictions between examples
- [ ] PII removed or anonymized
- [ ] Bad examples removed (wrong answers, off-topic, incomplete)
- [ ] Balanced across categories (for classification tasks)
- [ ] Train/validation/test split: 80/10/10 (minimum)
- [ ] At least 100 examples (500+ recommended for good results)

### Data quality over quantity

50 perfect examples beat 500 mediocre ones. Spend time on quality:

```python
# Validate training data
def validate_example(example: dict) -> list[str]:
    issues = []
    messages = example.get("messages", [])

    if not messages:
        issues.append("Empty messages")
    if messages[-1]["role"] != "assistant":
        issues.append("Last message must be assistant")
    if any(m["content"].strip() == "" for m in messages):
        issues.append("Empty content in messages")
    if len(messages[-1]["content"]) < 10:
        issues.append("Assistant response too short")

    return issues
```

### Data augmentation

When you need more examples but manual creation is slow:

1. **Paraphrase inputs** -- use an LLM to rephrase user queries while keeping the same
   expected output
2. **Edge case generation** -- ask an LLM to generate unusual inputs for your domain
3. **Difficulty variation** -- create easy, medium, and hard versions of each example
4. **Error injection** -- include examples with intentional user mistakes (typos, unclear
   phrasing) and correct outputs

---

## 3. PEFT / LoRA

Parameter-Efficient Fine-Tuning trains only a small subset of model parameters. LoRA (Low-Rank
Adaptation) is the most common approach.

### Why LoRA

- Trains 0.1-1% of parameters instead of all of them
- Requires far less GPU memory (a 7B model fits on a single 24GB GPU)
- Training is 2-10x faster than full fine-tuning
- LoRA adapters are small files (10-100MB) that can be swapped at inference time
- Multiple adapters can serve different tasks from the same base model

### Hugging Face PEFT + Transformers

```python
from transformers import AutoModelForCausalLM, AutoTokenizer, TrainingArguments
from peft import LoraConfig, get_peft_model
from trl import SFTTrainer

model_name = "meta-llama/Llama-3.1-8B-Instruct"
tokenizer = AutoTokenizer.from_pretrained(model_name)
model = AutoModelForCausalLM.from_pretrained(
    model_name,
    torch_dtype="auto",
    device_map="auto",
)

# LoRA config
lora_config = LoraConfig(
    r=16,                          # rank -- higher = more capacity, more memory
    lora_alpha=32,                 # scaling factor (usually 2x rank)
    target_modules=["q_proj", "v_proj", "k_proj", "o_proj"],
    lora_dropout=0.05,
    bias="none",
    task_type="CAUSAL_LM",
)

model = get_peft_model(model, lora_config)
model.print_trainable_parameters()  # ~0.5% of total

# Training
training_args = TrainingArguments(
    output_dir="./output",
    num_train_epochs=3,
    per_device_train_batch_size=4,
    gradient_accumulation_steps=4,
    learning_rate=2e-4,
    warmup_ratio=0.1,
    logging_steps=10,
    eval_strategy="steps",
    eval_steps=50,
    save_strategy="steps",
    save_steps=50,
    bf16=True,
)

trainer = SFTTrainer(
    model=model,
    args=training_args,
    train_dataset=train_dataset,
    eval_dataset=eval_dataset,
    processing_class=tokenizer,
)

trainer.train()
```

### LoRA hyperparameters

| Parameter | Default | Range | Notes |
|-----------|---------|-------|-------|
| `r` (rank) | 16 | 4-64 | Higher = more capacity, more memory. 16 is a good default |
| `lora_alpha` | 32 | 2x rank | Scaling factor. alpha/rank = effective learning rate multiplier |
| `target_modules` | varies | model-specific | At minimum: q_proj, v_proj. Add k_proj, o_proj for more capacity |
| `lora_dropout` | 0.05 | 0-0.1 | Regularization. Higher for small datasets |
| Learning rate | 2e-4 | 1e-5 to 5e-4 | LoRA tolerates higher LR than full fine-tuning |
| Epochs | 3 | 1-5 | Watch for overfitting after 3 epochs |

### QLoRA (quantized LoRA)

Fine-tune a 4-bit quantized model -- fits larger models on less hardware:

```python
from transformers import BitsAndBytesConfig

bnb_config = BitsAndBytesConfig(
    load_in_4bit=True,
    bnb_4bit_quant_type="nf4",
    bnb_4bit_compute_dtype="bfloat16",
    bnb_4bit_use_double_quant=True,
)

model = AutoModelForCausalLM.from_pretrained(
    model_name,
    quantization_config=bnb_config,
    device_map="auto",
)
```

QLoRA trades a small quality loss for significant memory savings. A 70B model can be
fine-tuned on a single 80GB A100.

---

## 4. Full Fine-Tuning

### Provider-hosted fine-tuning

The easiest path -- upload data, start training, no GPU management:

```bash
# OpenAI fine-tuning
openai api fine_tuning.jobs.create \
  --training-file file-abc123 \
  --model gpt-4o-mini-2024-07-18 \
  --hyperparameters '{"n_epochs": 3}'
```

### When full fine-tuning over LoRA

- Need maximum quality for a critical task
- Have significant compute budget (multiple GPUs)
- Training on a very large dataset (100k+ examples)
- Need to modify the model's core knowledge, not just behavior

For most use cases, LoRA produces comparable quality at a fraction of the cost.

---

## 5. Evaluation During Training

### Metrics to track

| Metric | What it means | Alert if |
|--------|--------------|----------|
| Training loss | How well the model fits training data | Stops decreasing (plateau) |
| Validation loss | How well the model generalizes | Increases (overfitting) |
| Eval accuracy | Task-specific performance | Below baseline |
| Token perplexity | How "surprised" the model is by validation data | Increases after initial decrease |

### Early stopping

Stop training when validation loss stops improving:

```python
training_args = TrainingArguments(
    # ...
    eval_strategy="steps",
    eval_steps=50,
    load_best_model_at_end=True,
    metric_for_best_model="eval_loss",
    greater_is_better=False,
    early_stopping_patience=3,  # stop after 3 evals without improvement
)
```

### Post-training evaluation

Run the full eval suite (from evaluation.md) on the fine-tuned model and compare against:
1. The base model with the best prompt
2. The base model with few-shot examples
3. A larger model (to check if fine-tuning closed the gap)

If the fine-tuned model doesn't clearly beat option 1 or 2, the fine-tuning wasn't worth it.

---

## 6. Deployment

### Merging LoRA weights

For production serving, merge the adapter into the base model:

```python
from peft import PeftModel

base_model = AutoModelForCausalLM.from_pretrained(model_name)
peft_model = PeftModel.from_pretrained(base_model, "path/to/adapter")
merged_model = peft_model.merge_and_unload()
merged_model.save_pretrained("merged-model")
```

### Serving fine-tuned models

- **Provider-hosted** (OpenAI, Anthropic): deploy via API, no infra management
- **vLLM**: `python -m vllm.entrypoints.openai.api_server --model merged-model`
- **Ollama**: create a Modelfile pointing to the merged weights
- **TGI**: `docker run ghcr.io/huggingface/text-generation-inference --model-id merged-model`

---

## 7. Common Mistakes

| Mistake | Impact | Fix |
|---------|--------|-----|
| Fine-tuning on bad data | Model learns wrong patterns | Audit data quality before training |
| Too many epochs | Overfitting, degraded generalization | Use early stopping, monitor val loss |
| No eval before and after | Can't measure if it helped | Set up evals before starting |
| Fine-tuning for retrieval tasks | Baked knowledge goes stale | Use RAG for dynamic knowledge |
| Tiny dataset (<50 examples) | Overfitting, not learning | Collect more data, use few-shot instead |
| No test set held out | Can't detect overfitting | Always hold out 10% for testing |
| Forgetting the base model comparison | Fine-tuned model might not actually be better | Always compare against prompted base model |
