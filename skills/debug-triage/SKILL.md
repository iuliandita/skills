---
name: debug-triage
description: >
  · Triage a live incident to localize an unknown failing layer, then route. Triggers:
  incident, outage, triage, production down, crashloop, 502. Not for known-component debugging
  (systematic-debugging) or repo audits (deep-audit).
license: MIT
compatibility: "Optional, stack-dependent: kubectl, dig, curl, openssl, ss, journalctl, pg_isready, jq"
metadata:
  source: iuliandita/skills
  date_added: "2026-06-14"
  effort: high
  argument_hint: "[symptom-or-service]"
---

# Debug Triage

A live system is broken and you do not yet know which layer is at fault. This skill localizes the
failure - narrows an unknown-layer outage to one layer with evidence - and then hands off to the
skill that owns that layer. It does not fix; it finds where to look.

It layers on top of the host harness's `systematic-debugging` skill: that skill is the root-cause
method for one *known* component. Use this skill *first*, when the component is unknown, to decide
which component `systematic-debugging` (or a domain skill) should then investigate. Triage
localizes; the domain skill diagnoses; neither guesses a fix before the cause is found.

## When to use

- A live service is down or degraded and the failing layer is not yet known ("it's broken", "502s
  started", "pods CrashLooping", "users report timeouts")
- An outage spans multiple layers (DNS, network, ingress, app, data, secrets) and you need to find
  which one before going deep
- Post-deploy or post-change breakage where the blast radius is unclear
- You are about to start guessing fixes - stop and localize first

## When NOT to use

- The failing component is already known and you need the root-cause method - use the host
  `systematic-debugging` skill, then the matching domain skill
- Auditing repo files for problems that are not a live incident - use **deep-audit** or **code-review**
- Running the standing Kubernetes health checklist when you already know it is a cluster question -
  use **cluster-health**
- Building the signals you wish you had mid-incident - use **observability** (do that before the
  next incident, not during this one)
- A security incident with a suspected intrusion - triage the layer, then escalate to
  **security-audit** and your incident-response process; this skill localizes, it does not contain

---

## AI Self-Check

Diagnostic work fails in specific ways. Before reporting a localization or running checks, verify:

- [ ] **No fix before localization.** The cause is identified with evidence before any change is
  proposed. A guessed fix on an unknown layer is the failure mode this skill exists to prevent.
- [ ] **Failure modes differentiated.** "Unreachable", "permission denied", and "not present" are
  distinct findings with distinct next steps - never collapse them into "missing".
- [ ] **No silent masking.** Diagnostic commands do not hide errors behind `2>/dev/null`. A failed
  check surfaces its reason; an empty result is not read as "all clear".
- [ ] **Cheapest discriminating check first.** Each step is chosen to *exclude* the most layers per
  command, not to confirm a hunch. State what a pass and a fail each rule out.
- [ ] **Evidence, not inference.** Each layer is excluded or implicated by an observed signal
  (command output, metric, log line), not by assumption.
- [ ] **Read-only by default.** Triage observes. Any state-changing command (restart, failover,
  scale, flush) is called out as an action requiring explicit confirmation, not run silently.
- [ ] **Handoff is explicit.** The output names the implicated layer, the evidence, and the exact
  skill to route to next.

---

## Workflow

Run the checks listed for the candidate layers. Do not improvise checks with assumed service names
or paths; if a layer needs coverage not listed here, note it as a gap and ask, do not invent it.

### Step 1: Scope the symptom

Pin the observable failure before touching anything. Capture: what is failing (endpoint, job,
user action), since when, what changed near that time (deploy, config, cert rotation, infra
change), and the blast radius (one service, one node, one region, everything). A recent change is
the strongest prior - check it first.

### Step 2: Form layer hypotheses

Map the symptom to candidate layers (see the layer map). A symptom usually implicates 2-4 layers,
not one. List them; do not commit to a favorite.

### Step 3: Run the cheapest discriminating check

For the candidate layers, run the check that excludes the most layers per command (see the
discriminating-signal table). After each result, drop the layers it rules out. Repeat until one
layer remains. Report *why* each layer was excluded, with the evidence.

### Step 4: Localize and hand off

State the implicated layer, the evidence that localized it, and the skill that owns the next step.
Do not cross into fixing - that is the domain skill's job, or `systematic-debugging`'s once the
component is known.

---

## Layer map

Work outside-in along the request path. Each layer is owned by a domain skill for the deep dive.

| Layer | Typical symptom | Owner skill for the deep dive |
|---|---|---|
| DNS resolution | NXDOMAIN, wrong IP, intermittent name failures | **networking** |
| Network / routing (L3-L4) | timeouts, no route, connection refused | **networking** |
| TLS / certificates | cert expired, SAN mismatch, handshake failure | **networking** (or the distro/appliance skill) |
| Load balancer / ingress | 502 (upstream sent an invalid/no reply), 503 (no healthy backend), 504 (upstream timed out) | **kubernetes** (ingress/Gateway) or **firewall-appliance** |
| Service / pod | CrashLoopBackOff, OOMKilled, readiness failing | **kubernetes**, then **cluster-health** for the broad sweep |
| App runtime | 500s, exceptions, deadlocks in one component | host `systematic-debugging`, then the language/domain skill |
| Dependency (DB/cache/queue) | slow queries, connection pool exhaustion, broker lag | **databases** |
| Secrets / auth chain | 401/403, token expired, Vault path unreachable | **security-audit**; trace the Vault->IaC->runtime chain |
| Host / node | disk full, memory pressure, kernel/systemd unit down | the distro skill (**debian-ubuntu**, **rhel-fedora**, **arch-btw**, **nixos-btw**) |
| Config / deploy (GitOps) | broke right after a sync; drift from desired state | **kubernetes** / **terraform**, check the last change |

## Discriminating-signal table

Pick the check that splits the candidate set fastest. These are starting points - adapt the
service names and paths to the actual stack, and surface errors rather than masking them. Run
reachability checks from the right network vantage point - inside the cluster or namespace for
ClusterIP services and split-horizon DNS, not from a laptop - or a wrong exclusion follows. For a
*degraded* symptom (slow, no errors) the discriminators shift from up/down to fast/slow and
which-fraction; see the last row - read its percentiles first (uniform vs tail vs one slow
replica), then chase only the resource that split implicates.

| Question | Check (adapt to stack) | A pass rules out | A fail implicates |
|---|---|---|---|
| Does the name resolve? | `dig +short <host>` (or `getent hosts <host>`) | DNS | DNS / upstream resolver |
| Is the port reachable? | `curl -sS -o /dev/null -w '%{http_code}' <url>`; `ss -tnp` | network/routing | network, LB, or the listener |
| Is TLS valid? | `openssl s_client -connect <host:port> -servername <host> </dev/null` | TLS/cert | cert expiry / SAN / chain |
| Is the pod actually up? | `kubectl get pods -o wide`; `kubectl describe pod` | service/pod | scheduling, image, probes, OOM |
| Does the ingress have backends? | `kubectl get endpoints <svc>` (empty = nothing to route to) | ingress wiring | empty endpoints (selector mismatch or all pods unready) -> 502 |
| Is the dependency answering? | dependency ping/health (e.g. `pg_isready`, broker health) | data layer | DB/cache/queue or its credentials |
| Did something just change? | `kubectl rollout history` / git log of the manifests / deploy log | config/deploy | the last change (roll back to test) |
| Is the host healthy? | `df -h`, `journalctl -p err -b`, unit status (surface errors) | host/node | disk, memory, a failed unit |
| Slow, not down (no errors)? | latency percentiles per endpoint/pod (p50 vs p99); CPU throttle ratio; pool-wait (`pg_stat_activity`); cache hit/miss ratio | a flat, healthy distribution rules out saturation | tail latency or one slow replica: CPU throttle, pool exhaustion, slow query, cache-miss shift |

Read metrics for what they measure, not what they seem to say (e.g. K8s HPA `targetCPU` is a
percentage of the CPU *request*, not raw CPU; `df` is allocation, not live content). When a
resource is on a schedule (backups, rotations), judge freshness against that schedule.

## What NOT to do

- Do not propose a fix before a layer is localized with evidence.
- Do not run state-changing commands (restart, failover, scale, flush, apply) as part of triage;
  name them as actions and get explicit confirmation.
- Do not mask command failures with `2>/dev/null`; a failed check is a finding.
- Do not invent service names, namespaces, or paths; if coverage is missing, ask.

## Output Contract

See `references/output-contract.md` for the full contract.

- **Skill name:** DEBUG-TRIAGE
- **Deliverable bucket:** `audits`
- **Mode:** conditional. Live triage is conversational - walk the layers, localize, and route inline without the contract. When invoked to **write up a triage or post-incident summary** as a durable artifact, emit the full contract - boxed inline header, per-layer detail in the deliverable file, boxed conclusion, conclusion table - and write it to `docs/local/audits/debug-triage/<YYYY-MM-DD>-<slug>.md`.
- **Severity scale:** `P0 | P1 | P2 | P3 | info` (see shared contract; used only in the written-summary mode).

## Related Skills

- **observability** - produces the metrics, traces, and logs triage reads. This skill consumes
  those signals to localize; observability builds them. If a layer is dark mid-incident, that is an
  observability gap to fix afterward.
- **cluster-health** - the broad read-only Kubernetes checklist. Triage routes to it once the
  symptom is localized to the cluster; cluster-health then sweeps node/workload/event/storage state.
- **networking** - owns DNS, routing, TLS, and proxy deep dives once triage points there.
- **databases** - owns the data-layer deep dive (slow queries, pools, replication) once implicated.
- **security-audit** - owns the auth/secrets deep dive and exploitability; triage localizes a
  401/403 or a broken Vault chain, security-audit investigates it.
- **deep-audit** / **code-review** - operate on repo files, not a live incident. Triage is for a
  running system that is currently broken.

## Rules

1. **Localize before fixing.** Identify the failing layer with evidence before proposing any
   change. No guessed fixes on unknown layers.
2. **One layer at a time, cheapest check first.** Choose each check to exclude the most layers per
   command; drop ruled-out layers and state why.
3. **Differentiate failure modes.** Unreachable, denied, and absent are different findings - never
   collapse them.
4. **Surface errors.** No `2>/dev/null` on diagnostic commands; an empty or failed result is
   reported, not assumed benign.
5. **Read-only by default.** Triage observes; any state-changing action is flagged for explicit
   confirmation, never run silently.
6. **Run listed checks, do not improvise.** Adapt names and paths to the stack; if a needed check
   is not covered, note the gap and ask rather than inventing one.
7. **Hand off explicitly.** Output the implicated layer, the evidence, and the exact skill (or
   `systematic-debugging`) to continue with.
8. **Run the AI Self-Check** before reporting a localization.
