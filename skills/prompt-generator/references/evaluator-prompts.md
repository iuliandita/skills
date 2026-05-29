# Evaluator Prompts

An evaluator prompt asks a model to judge an artifact (an answer, a generated output, another
model's response) against fixed criteria. The output is a verdict and evidence, not a rewrite.

## Structure

An evaluator prompt needs: an input boundary (what is being judged vs. the reference), scoring
dimensions, a pass/fail threshold, failure examples, and required evidence for each judgment.

## Rubric Shape

Use 3-5 dimensions. Each dimension gets an explicit score range and observable criteria. More than
five dimensions and the scores stop meaning anything; fewer than three and the verdict is too
coarse to act on.

## Annotated Example

```
You evaluate a model answer against the reference answer. Score four dimensions, each 0-2:

- Correctness: 0 contradicts the reference, 1 partially right, 2 matches.
- Completeness: 0 misses the main point, 1 partial, 2 covers all required points.
- Grounding: 0 makes unsupported claims, 1 mostly grounded, 2 every claim traceable to the source.
- Format: 0 ignores the requested format, 1 minor deviation, 2 exact.

For each dimension, quote the span of the answer that justifies the score. Pass requires total >= 6
AND Correctness = 2. Output JSON: {"scores": {...}, "evidence": {...}, "verdict": "pass|fail"}.

<reference>{{REFERENCE}}</reference>
<answer>{{ANSWER}}</answer>
```

What makes it work: fixed dimensions with observable anchors per score, a hard gate on correctness,
required quoted evidence, a machine-readable verdict, and clearly delimited reference vs. answer.

## Counter-Example

```
Rate this answer from 1 to 10 on how good it is.
```

A single opaque scale with no criteria. Two runs disagree, no evidence is required, and "good"
silently rewards length and confident tone over correctness. Unusable for gating.

## Failure Modes

- Rewarding verbosity instead of correctness.
- Accepting unsupported claims as if they were grounded.
- Letting style preferences override stated requirements.
- Scoring without citing evidence from the evaluated artifact.
- One vague scale instead of named dimensions with anchors.
- Soft threshold ("around 7") that cannot gate a pipeline.
- No input boundary, so the evaluator grades the reference instead of the answer.

## Common Mistakes

- Asking the evaluator to fix the artifact instead of judging it. Keep evaluation and revision
  separate; mixing them hides which dimension failed.
- Omitting a tie-break or hard gate, so a verbose answer passes on volume.
- Letting the evaluated answer contain instructions the evaluator then follows. Fence the answer as
  untrusted data, the same as any other source text.
