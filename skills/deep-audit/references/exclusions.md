# Deep Audit Exclusions

These published skills are intentionally not dispatched by deep-audit. Keep this list current
so future contributors do not re-add them by reflex.

| Skill | Reason for exclusion |
|---|---|
| **browse** | Operational tool (fetch a page, fill a form). Not an audit lens. |
| **dev-cycle** | Workflow orchestrator (start-to-finish dev: branch -> ship). Acts on the repo; does not audit it. |
| **prompt-generator** | Creative authoring of LLM prompts. Produces content; does not evaluate code. |
| **routine-writer** | Creative authoring of cloud-routine prompts. Same shape as prompt-generator. |
| **skill-creator** | Audits the skill collection itself, not application code. Use Mode 3 of skill-creator separately. |
| **skill-refiner** | Batch-improves skill collections via eval loops. Same domain as skill-creator. |
| **lockpick** | Offensive security / CTF / privesc. Different threat model from defensive audit; security-audit + zero-day cover the defensive side. |
| **kali-linux** | Live-system administration of Kali. Kali is Debian-based, so repo-side packaging concerns are caught by debian-ubuntu in Wave 3. The skill itself is for running Kali, not auditing repos. |
| **full-review** | Alternate orchestrator (the smaller 4-skill version). Mutually exclusive with deep-audit by design. |
| **deep-audit** | This skill. Self-invocation would loop. |
