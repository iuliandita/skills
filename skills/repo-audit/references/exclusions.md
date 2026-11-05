# Excluded Lanes

| Skill | Reason for exclusion |
|---|---|
| **kubernetes-health** | Live cluster diagnostics require an explicit cluster context. |
| **debug-triage** | Requires a running failure and routes to a domain skill. |
| **dev-cycle** | Changes and ships a repository; it does not audit one. |
| **prompt-generator** | Authors prompts rather than reviewing repository content. |
| **skill-creator** | Reviews the skill collection itself, not application repositories. |
| **skill-refiner** | Improves skill collections through eval loops. |
| **plan-review** | Reviews decisions after evidence exists, rather than repository files. |
| **session-handoff** | Moves session context; it is not an audit lane. |
| **privilege-escalation** | Opt-in; if installed. Offensive work has a different threat model; use defensive security and vulnerability research. |
| **synology-dsm** | Live NAS administration and recovery require appliance state. |
| **repo-audit** | Self-invocation would loop. |

Quick mode is an alternate mode of this skill, not an exhaustive-wave lane.
