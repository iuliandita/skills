# Harness Detection

How skill-refiner detects and validates AI CLI harnesses for cross-model peer review.

---

## Detection Table

| Harness | Binary | Config Paths | Env Vars | Smoke Test |
|---------|--------|-------------|----------|------------|
| Claude Code | `claude` | `~/.claude/settings.json` | `ANTHROPIC_API_KEY` | `claude -p "respond with PONG"` |
| Codex | `codex` | `~/.codex/config.toml` | `OPENAI_API_KEY` | `codex exec "respond with PONG"` |
| OpenCode | `opencode` | project-level `.opencode/` (verify) | varies by provider | check `opencode --help` |
| Aider | `aider` | `~/.aider.conf.yml` | `OPENAI_API_KEY` or `ANTHROPIC_API_KEY` | `aider --message "respond with PONG" --no-git --yes` |
| Goose | `goose` | `~/.config/goose/config.yaml` | varies by provider | check `goose --help` |

**Important:** Smoke test commands are approximate. Verify against current CLI versions
before relying on them. Check `<harness> --help` for the correct non-interactive flag.
Harness CLIs evolve rapidly - these should be verified on each run.

---

## Three-Step Probe

Run for each harness in priority order. Stop at the first that passes all three steps.

### Step 1: PATH Check

```bash
command -v <binary> >/dev/null 2>&1
```

If binary not found on PATH, skip to next harness.

### Step 2: Config Check

Verify credentials exist (file OR env var):

```bash
[[ -f <config_path> ]] || [[ -n "${ENV_VAR:-}" ]]
```

If neither config file nor env var exists, skip to next harness.

### Step 3: Smoke Test

Send a trivial prompt with a distinct canary word, verify it appears in the output:

```bash
output=$(timeout 60 <smoke_test_command> 2>&1)
echo "$output" | grep -qi "pong"
```

Use "respond with PONG" as the prompt (not "OK" - too likely to match banner text).
60-second timeout - some harnesses (Codex) run MCP startup and emit verbose banners
(10+ lines of config metadata) before the model response. Never truncate output with
`head` or assume the response appears in the first N lines. Grep the full output.

If no match, error, or timeout, skip to next harness.

---

## Auto-Detection Priority

```
1. claude
2. codex
3. opencode
4. aider
5. goose
```

The primary harness (the one running the current session) is always excluded from
secondary selection.

### Detecting the Primary Harness

Check in order (env var names are approximate - verify against current CLI versions):
1. Claude Code env var (e.g., `CLAUDE_CODE` or similar) - primary is claude
2. Parent process name contains `codex` - primary is codex
3. OpenCode env var (e.g., `OPENCODE_SESSION` or similar) - primary is opencode
4. If ambiguous, prompt user once at run start

### Multi-Model Harnesses

When the detected secondary harness supports multiple models (OpenCode, Aider):
1. Prompt user once: "Which model should be the secondary reviewer?"
2. Store selection for the run duration
3. Pass model selection via the harness's native flag (e.g., `--model <model>`)

---

## Config Override

**Environment variable:**
```bash
export SKILL_REFINER_SECONDARY=codex
```

**CLI flag:**
```bash
skill-refiner --secondary codex
```

CLI flag takes precedence over env var. Both skip auto-detection entirely.
Setting `--secondary none` explicitly disables cross-model review.

---

## Review Prompt Template

What gets sent to the secondary harness (non-interactive).

**Known issue**: Codex in `exec` mode may run tools (lint, validate) instead of producing
text-only review output. If the secondary returns tool output instead of a
NO_FLAGS/MINOR_FLAG/MAJOR_FLAG response, fall back to self-review: spawn a fresh agent
on the primary harness with the review prompt template (see Phase 0, Step 6 in SKILL.md).
Weight self-review at 3% instead of 5% (composite becomes gate/40/55/3, renormalize the
missing 2% proportionally across AI Self-Check and Behavioral).

**Peer review is mandatory.** Always attempt the secondary harness first (three-step probe).
If no secondary is available or the secondary fails to produce a valid response, self-review
on a fresh context of the primary harness is the required fallback. Skipping review entirely
is never acceptable - even same-model fresh-context review catches issues the working context
is blind to.

```
You are reviewing a skill improvement diff. Be specific and cite exact lines.

## Original Skill (before)
<full SKILL.md content before the change>

## Diff
<git diff output of the change>

## Scoring Breakdown
Structural: <score>/100
AI Self-Check: <score>/100
Behavioral: <score>/100
Overall: <score>/100

## Your Task
1. Does this change genuinely improve the skill?
2. Does it introduce regressions, remove useful content, or add fluff?
3. Are there issues the primary model might have missed?

Respond with exactly one of:
- NO_FLAGS - improvement is good, no concerns
- MINOR_FLAG: <specific description citing lines> - suboptimal but not harmful
- MAJOR_FLAG: <specific description citing lines> - harmful, regression, or removes critical content
```

---

## Flag Verification Protocol

Flags from the secondary model are verified before action:

### Minor Flag
1. Present the flag + diff to the primary model (fresh context, no leading)
2. Ask: "Do you agree this is a valid concern? Why or why not?"
3. If primary agrees: deduct 20 points from cross-model component, log flag
4. If primary disagrees: discard flag, log disagreement with reasoning

### Major Flag
1. Present the flag + diff + secondary's full reasoning to primary
2. Ask: "Is this change genuinely harmful? Analyze independently."
3. If primary agrees: hard revert the change, log reason
4. If primary disagrees: **escalate to circuit breaker** - pause for human review
5. Human decides: keep, revert, or modify

The contested-major-flag-to-human escalation is non-configurable even in `--mode auto`.
