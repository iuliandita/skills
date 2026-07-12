# Code Slimming: Report Templates

Deliverable body templates for Workflow Step 7. Field semantics (behavior invariant, validation
evidence, action labels, `Risk`) are defined in `SKILL.md` Steps 5-6; the Output Contract wrapper
(boxed header, conclusion table) is defined in the `SKILL.md` Output Contract section.

## Audit with findings

```markdown
## Code Slimming Audit: [scope]

Context:
- Languages/frameworks: [detected]
- Baseline validation run: [commands and results; implementation validation not run because this audit is read-only]
- Validation gaps: [missing, noisy, skipped, or unavailable checks]

### High-Value Opportunities

**Do with tests** `services/*/list-items.*` - Centralize repeated pagination and filter parsing.
Affected files: `services/users/list-items.*`, `services/projects/list-items.*`
Evidence: `services/users/list-items.ts:24-58`, `services/projects/list-items.ts:19-55`
Current duplication: both modules parse the same page, limit, sort, and filter parameters.
Refactor shape: extract a shared parser with endpoint-specific allowlists.
Behavior invariant: page and limit defaults, max-limit handling, sort allowlists, and error messages stay identical.
Call-site impact: 2 endpoint handlers, no public import path changes.
Why better: one behavior path for defaults and validation, with fewer divergent call sites.
Tradeoffs: one shared helper couples list endpoints to a common pagination contract.
Risk: medium
Validation needed: add boundary tests for page and limit values, then run lint/type/build/test commands.

**Do now** `src/legacy/format.ts` - Delete unused module.
Evidence: `src/legacy/format.ts:1-120` defines `formatLegacy`; no imports of `legacy/format` or
references to `formatLegacy` in `src/`, `test/`, config, or route tables (`rg -n "legacy/format|formatLegacy"`).
No-reference proof: not exported from the package index, not referenced by string key, not a DI/CLI/route registration.
Behavior invariant: none; nothing reaches this code.
Why better: removes a whole dead module and its transitive imports.
Tradeoffs: none if the no-reference proof holds.
Risk: low
Validation needed: type and build pass after deletion; grep confirms zero references.

### Removed-Code Safety Review

Include this section only when reviewing a diff or PR that removed code.

**Needs evidence** `[area]`
Removed behavior: [code path, wrapper, branch, fallback, type, validation, or dependency removed]
Replacement path: [what now handles it]
Behavior invariant: [what must still happen]
Evidence checked: [diff lines, call sites, tests, type checks]
Risk: [low/medium/high]
Validation needed: [specific command/test/case]

### Low-Value Or Risky Opportunities

**Leave alone** `integrations/*` - Duplication is likely to diverge per provider.
Why not: each provider already has different retry, auth, pagination, and error semantics.

### Summary

- High-value opportunities: 1
- Low-value or risky opportunities: 1
- Merge blockers: none from this audit lens
- Residual risk / skipped areas: [large dirs, generated files, expensive checks, external services]
- Net recommendation: [slim / defer / leave mostly unchanged], based on risk-adjusted maintenance value, not LOC delta
```

## Zero findings

If no useful slimming opportunities are found, say so explicitly:

```markdown
### High-Value Opportunities
None found within scope.

### Search Coverage
- Scope inspected: [diff/path/repo areas]
- Patterns checked: [dead code/unused symbols, superseded code, leftover files, orphan files, clones, per-element copies, wrappers, inert try/catch, duplicate schemas, repeated parsers, adapters, utils, comment walls]
- Files/directories skipped: [generated/vendor/tests/etc.]
- Validation checked: [commands/tests found or unavailable]

### Why no action is recommended
- Existing duplication appears intentional because: [...]
- Thin wrappers are retained because: [...]
- Shared abstraction would likely worsen: [...]

### Low-Value Or Risky Opportunities
[optional leave-alone observations]

### Summary
- High-value opportunities: 0
- Low-value or risky opportunities: N
- Merge blockers: none from this audit lens
- Residual risk: [what was not inspected]
- Net recommendation: leave mostly unchanged
```
