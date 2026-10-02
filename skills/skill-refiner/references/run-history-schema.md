# Run History Schema

Schema for one run object appended to `$SKILL_REFINER_HISTORY` (default `.refiner-runs.json`)
in Phase 3. `scripts/check-refiner-state.sh` validates it when the collection ships that script.

```jsonc
{
  "schema": 2,                           // int, required
  "rubric_hash": "<hex>",                // 64-char lowercase sha256 from refiner-rubric-hash.sh
  "run_id": "<string>",                  // unique; date-based or issue-prefixed
  "branch": "<string>",
  "date": "<YYYY-MM-DD>",
  "primary": {                           // required; identity key is "resolved_model"
    "provider": "<string|null>",
    "resolved_model": "<string|null>",   // legacy alias "model" is accepted on read
    "effective_effort": "<string|null>",
    "harness": "<string|null>",
    "version": "<string|null>",
    "evidence": "<string|null>"
  },
  "secondary": { /* same shape as primary */ },     // or null
  "reviewer_classification": "cross-model|same-model|unknown-model|none",
  "cap": 5,                              // or 3; legacy alias "review_weight" is 0.03 or 0.05
  "config": { "iterations": <int>, "threshold": <int>, "mode": "<string>", "plateau": <int> },
  "pool_size": <int>,
  "termination": "<string>",
  "review_flags": { "minor": <int>, "major": <int> },
  "control_failures": [ "<string>" ],    // required array; empty when none
  "skills": {
    "<skill-name>": {
      "before": { "structural": "pass|fail", "ai": <number>, "behavioral": <number>,
                  "penalty": <number>, "composite": <number> },
      "after":  { /* same shape */ },
      "test_source": "<string>",
      "changed": <bool>
    }
  },
  "changes": "<string>"
}
```

Optional per-skill fields: `executor_tiers` (array of `small|balanced|flagship` that ran its
behavioral cases) and `baseline_lift` (`true` when the with-skill output beat the no-skill run on
every case, `false` when any case showed no lift, omitted when not measured).
