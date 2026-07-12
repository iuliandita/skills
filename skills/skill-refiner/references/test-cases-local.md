# Local Behavioral Test Cases

Generated during skill-refiner runs for skills without hand-written cases in
`test-cases.md`. These are lower-confidence than curated tests and should be promoted
or revised during phase 2 before becoming canonical.

## Test Cases

### cluster-health

**Test 1: Post-maintenance cluster sweep**
Prompt: "Check cluster health after a node reboot. Context is prod-us-east, look back 2h. Do not make changes."
Quality signals:
- Requires or confirms the kube context before running commands
- Uses read-only `kubectl --context` and `helm --kube-context` commands
- Checks nodes, pods, events, storage, ingress, and recent errors with bounded output
- Reports GREEN/YELLOW/RED status with evidence and next actions
- Does not restart, delete, patch, drain, cordon, or exec into workloads

**Test 2: Vague cluster request**
Prompt: "Can you check whether the cluster is healthy?"
Quality signals:
- Does not guess the target cluster or use the current context silently
- Asks for an explicit context or protected-overlay alias
- States that checks are read-only and need a bounded time window

### code-slimming

**Test 1: Safe deletion audit**
Prompt: "Audit this repository for safe LOC reduction and duplicate wrappers. Report only; do not edit files."
Quality signals:
- Keeps the audit read-only
- Separates behavior-preserving slimming from bugs, security, tests, and slop cleanup
- Names validation needed for each proposed deletion or centralization
- Avoids recommending abstraction where duplication may intentionally diverge

**Test 2: Generic cleanup request**
Prompt: "This code feels overengineered and AI-written. Clean it up."
Quality signals:
- Routes generic AI-code-quality cleanup to anti-slop instead of code-slimming
- Explains that code-slimming requires an explicit smaller-code or safe-deletion goal
- Does not produce slimming findings outside its lane

**Test 3: Zero-findings clean repo**
Prompt: "Slim the codebase at <path-to-small-clean-fixture-repo> - find dead code, duplicates,
and anything safe to delete in that repository. Report only, do not edit files."
Fixture: a tiny lean repo (2-3 files, no dead code, no comments, a passing test) with one
exported-but-unimported constant on the package entry module (public-API trap).
Quality signals:
- Audits the named path, not the session cwd
- Reports zero high-value opportunities without manufacturing findings
- Includes an explicit search-coverage section
- Classifies the entry-module export as Leave alone (public-API path not ruled out)
- Writes the deliverable under the audited repo's root, not the session cwd
Prompt-authoring note: name the path immediately after "the codebase at". A trailing
": <path>" after an unrelated clause ("do not edit files: <path>") reliably misbinds and
the agent audits the session cwd - that variant tests prompt parsing, not the skill.

### skill-router

**Test 1: Multi-skill routing**
Prompt: "Which skill should handle auditing a Dockerized API for security and CI issues?"
Quality signals:
- Identifies independent domains and returns parallel skills rather than one broad skill
- Selects security-audit, docker, and ci-cd or explains any local availability differences
- Keeps the explanation brief and action-oriented

**Test 2: Process-before-domain routing**
Prompt: "I want to design and build a new SaaS dashboard. Which skill order should I use?"
Quality signals:
- Returns an ordered route with a process/design skill before frontend-design when available
- Avoids loading every frontend reference just to make the routing decision
- Mentions near misses only if they prevent confusion
