---
name: anti-slop
description: "Use when auditing code for machine-generated patterns, over-abstraction, redundant comments, defensive overkill, verbose code, generic naming, stale idioms, or dependency creep. Triggers: 'slop', 'code quality', 'simplify', 'modernize', 'code smell', 'clean up'."
source: custom
date_added: "2026-03-25"
effort: medium
---

# Anti-Slop: Polyglot Code Quality Audit

Detect and fix patterns that make code look machine-generated, over-abstracted, or unnecessarily verbose. The goal is code that reads like a competent human wrote it -- minimal, intentional, and clear.

This skill covers: **TypeScript/JavaScript**, **Python**, **Bash/Shell**, and **Infrastructure as Code** (Terraform, Ansible, Helm, Kubernetes manifests). The universal patterns apply everywhere; language-specific sections add targeted checks.

## When to use

- Reviewing code that feels machine-generated, bloated, or oddly generic
- Simplifying code after an AI-heavy implementation pass
- Auditing comment noise, naming quality, over-abstraction, and dependency creep
- Looking for "ugly but technically works" code that still hurts readability or maintainability

## The Three Axes of Slop

Every finding falls into one of three categories:

1. **Noise** -- bulk without value (redundant comments, boilerplate, unnecessary types/annotations)
2. **Lies** -- subtly wrong or outdated (hallucinated APIs, deprecated patterns, stale deps)
3. **Soul** -- lacks taste (over-abstraction, generic names, defensive overkill)

## When NOT to use

- Correctness, logic, or race-condition bugs -- use code-review
- Security vulnerabilities, secret scanning, or auth review -- use security-audit
- One-off prompt authoring or prompt templates -- use prompt-generator
- Session-end documentation maintenance -- use update-docs

## Workflow

### Step 1: Scope the audit

Default scope based on context:
- If invoked right after writing code in this session -> **self-check** (review what you just wrote)
- If there are uncommitted changes (`git diff --name-only`) -> **recent changes**
- Otherwise -> ask the user

Available scopes:
- **Full codebase audit** -- scan everything, report by category
- **Recent changes** -- check git diff or recent commits
- **Specific files/dirs** -- targeted review
- **Self-check** -- review code you just wrote in this session

### Step 2: Detect languages

Scan the project to determine which languages are present. Apply the universal patterns to everything, then layer on language-specific checks. Don't apply TS checks to Python code or vice versa.

### Step 3: Run mechanical linters first (if available)

Before scanning for slop, run standard linters to clear the low-hanging fruit:
- **Shell**: `shellcheck`
- **Python**: `ruff check` / `mypy`
- **TypeScript**: `eslint` / `tsc --noEmit`
- **Terraform**: `terraform validate` / `tflint`
- **Structural patterns**: `ast-grep` (tree-sitter powered AST search -- write rules to catch restating comments, dead code, hallucinated imports across languages. Install: `npm i -g @ast-grep/cli`. If your tool ecosystem provides `ast-grep` helper skills or templates, use them.)

Linters handle syntax issues, unused imports, and known anti-patterns mechanically. This skill focuses on what linters can't catch: taste, over-abstraction, naming quality, unnecessary complexity, and stale idioms. Don't duplicate what a linter already covers.

**Per-project tools** (eslint, tsc, vitest, prettier) are project devDeps, not system tools. If they're not in the project's `package.json`/`devDependencies`, mention to the user what's missing and let them decide whether to install. Don't run linters that aren't set up.

### Step 4: Scan for patterns

Use Grep, Glob, and Read. Read files before flagging -- context matters. A pattern that looks like slop in isolation might be justified.

Classify each finding by action and severity:

**Action:**
- **Fix** -- clearly wrong or wasteful, should change
- **Consider** -- judgment call, present it and let the user decide
- **Fine** -- looks like slop but is justified (note why and move on)

**Severity** (determines report ordering -- high first):
- **High** -- security risk (silent error swallowing, `any` casts bypassing type safety, missing input validation at boundaries), correctness (stale/deprecated APIs, hallucinated patterns)
- **Medium** -- maintainability (over-abstraction, generic naming, missing error context, logic duplication)
- **Low** -- style (verbose patterns, comment noise, redundant annotations, barrel files)

### Step 5: Report and fix

Present findings grouped by category. For each Fix-level item, show the concrete replacement. Don't just point at problems -- show the better version.

---

## Universal Patterns (All Languages)

### 1. Comment Slop (Noise)

The single biggest tell. Comments that narrate what code does instead of why.

**Detect:**
- Comments restating the next line ("Initialize array", "Loop through items", "Return result", "Set variable")
- Hedging ("This should work", "This might need updating", "TODO: review this")
- Overconfident assertions ("This is the most efficient approach", "This handles all edge cases")
- Section dividers adding no information (`# --- Helper Functions ---` above obvious helpers)
- Docstrings/JSDoc on every function when signatures are self-documenting
- Inline comments on every block in a shell script or Terraform file

**AI agent tells** (these almost never appear in human code):
- Docstrings on every function regardless of complexity ("Returns the sum of two numbers" on `add(a, b)`)
- Comments restating what the next line does in plain English on every block
- Comments like "Error handling", "Configuration", "Main logic" as section headers in short functions
- JSDoc/docstrings with `@param` descriptions that just repeat the parameter name ("@param name - the name")
- Comments on obvious operations: `// increment counter`, `# check if file exists`, `// return the result`
- Convention blindness: ignoring the repo's existing patterns to produce "generic good code" (e.g., using camelCase in a snake_case codebase, adding JSDoc when the project uses no JSDoc)

**Fix:** Delete obvious comments. Keep only *why* comments -- business logic, workarounds, gotchas, non-obvious decisions. If code needs a *what* comment, rewrite the code. A 20-line function needs zero comments if the names are good. A 200-line module might need 3-4.

**Exception:** Comments explaining workarounds for bugs, API quirks, or platform limitations are valuable. Also: shell scripts benefit from more comments than typical code because the syntax is less self-documenting.

### 2. Defensive Overkill (Soul)

Error handling or validation that protects against impossible scenarios.

**Detect:**
- Try/catch (or try/except) that catches, logs, and re-raises without adding context
- Null/nil/None checks after the type system or prior logic already guarantees non-null
- Input validation deep inside internal functions (validate at boundaries, trust internally)
- Fallback values for things that can't be missing
- Shell scripts wrapping every command in `if ... then ... fi` instead of using `set -e`
- Terraform `try()` / `can()` wrapping expressions that can't fail

**AI agent tells** (overkill guardrails humans would never write):
- Try/catch wrapping every single function body, catching `Error` and logging a generic message
- Null checks on values returned from functions you control that never return null
- Input validation on internal helper functions that only receive pre-validated data
- `typeof x !== 'undefined'` checks when the variable was just assigned 3 lines up
- Fallback defaults for required config that should crash loudly if missing
- `if (!response.ok)` after every internal function call (not just HTTP boundaries)
- Wrapping pure functions in error handlers "just in case"

**Fix:** Remove pointless error handling. Validate at system boundaries (user input, API responses, env vars, external data), not on every internal call. If a catch block doesn't add context, retry, or recover -- delete it.

**Exception:** Defensive checks on external data (network responses, deserialized JSON, user input, third-party libraries) are correct. Security patterns (auth, CORS, SSRF protection, input sanitization) should never be flagged.

### 3. Over-Abstraction (Soul)

Creating abstraction layers for problems that need 10 lines of direct code.

**Detect:**
- Wrappers that just forward to one thing with no added logic
- Abstract/base classes with a single concrete implementation
- Factory functions that always produce the same type
- Separate files for types/interfaces only used in one place
- "Service" or "Manager" classes wrapping a single operation
- Terraform modules wrapping a single resource with no added logic
- Ansible roles with one task file
- Shell functions called exactly once

**Fix:** Inline small abstractions. Delete wrappers that add no logic. A little repetition beats a premature abstraction.

**Exception:** Abstractions for testing (dependency injection), multiple implementations, or isolating external deps are fine even with one current impl.

### 4. Verbose Patterns (Noise)

Using 10 lines where 3 would do.

**Detect (language-agnostic):**
- Unnecessary intermediate variables: `result = foo(); return result`
- Ternaries wrapping boolean returns: `return x ? true : false`
- Manual iteration that the language has built-ins for
- Copy-pasting code blocks with tiny variations instead of parameterizing

**Fix:** Use the idiomatic short form for the language. See language-specific sections for details.

### 5. Generic Naming (Soul)

Names that could mean anything: `data`, `result`, `response`, `item`, `temp`, `value`, `info`, `handler`, `manager`, `utils`, `helpers`, `common`, `misc`.

**Detect:**
- Variables with generic names outside tiny scopes (2-3 line lambdas are fine)
- Files named `utils.*`, `helpers.*`, `common.*`, `misc.*` (junk drawers)
- Functions named `handle_x`, `process_x`, `manage_x` without domain specificity
- Terraform resources named `this` or `main` when there are multiple of the same type
- Ansible variables named `item` or `result` in complex plays

**Fix:** Use domain-specific names. `data` -> `active_subscriptions`. `utils.sh` -> split by concern or inline.

**Exception:** Generic names in genuinely generic code (a `map()` callback, a type parameter `T`, a Terraform module's `this` when it's the only resource of that type).

### 6. Logic Duplication (Lies)

Same logic written slightly differently in multiple places -- a telltale sign of context-free generation.

**Detect:**
- Near-identical helper functions in different files
- Same validation logic in multiple handlers/routes
- Repeated inline formatting/parsing across modules
- Terraform `locals` blocks computing the same thing in different modules
- Ansible tasks doing the same thing with different variable names

**Fix:** Consolidate into a single well-named function/local/variable. But only if truly the same -- slight variations might be intentional.

### 7. Stale Patterns (Lies)

Code that was fine 5 years ago but has better alternatives now.

**Fix:** Use the modern equivalent. Check compatibility (language version, runtime, provider versions) before changing. See language-specific sections for concrete examples.

### 8. Error Handling Anti-Patterns (Noise + Lies)

**Detect:**
- Catch/except blocks that log a generic message and continue (error is lost)
- Every function wrapped in its own error handler (handle at boundaries instead)
- Errors caught and re-raised as new exceptions, losing the original stack
- Silent swallowing: `.catch(() => {})`, `except: pass`, `2>/dev/null` on critical commands
- Shell scripts without `set -e` that check `$?` after every command manually

**Fix:** Handle errors at boundaries. Let errors propagate through internal code. When catching, either recover or add context and re-raise.

**Exception:** Fire-and-forget operations legitimately swallow errors. Comment why.

### 9. Cross-Language Leakage (Lies)

AI models trained on multiple languages bleed idioms across boundaries. A reliable tell for AI-generated code.

**Detect:**
- JavaScript patterns in Python: `.push()`, `.length`, `.forEach()`, `===`, `console.log()`
- Java patterns in non-Java: `.equals()`, `.toString()`, `System.out.println()`, `public static void`
- Python patterns in JavaScript: `len()`, `print()`, `elif`, `def `, using `#` comments in JS
- Shell patterns in Python: backtick usage, `$VARIABLE` syntax
- Go patterns elsewhere: `fmt.Println()`, `:=` assignment, `func ` in non-Go

**Fix:** Replace with the target language's idiom. This is almost always an AI generation artifact -- humans don't accidentally write `.push()` in Python.

---

## Language: TypeScript / JavaScript

Read `references/typescript.md` for the full TS/JS pattern catalog. Key highlights:

- **Type abuse**: redundant annotations where inference works, `any` instead of `unknown`, enums instead of const objects/unions, missing `satisfies` / `as const`
- **Stale patterns**: `require()` in ESM, `var`, `React.FC`, class components, `PropTypes` alongside TS, `.then()` chains, `namespace`
- **Verbose**: `for` loops that should be `.filter().map()`, `Object.keys().forEach()` instead of `for...of`, classes for stateless logic
- **Dependency creep**: `node-fetch` when `fetch` is global, `uuid` when `crypto.randomUUID()` exists, two libs for the same concern
- **Barrel files**: `index.ts` re-exporting everything in small directories

## Language: Python

Read `references/python.md` for the full Python pattern catalog. Key highlights:

- **Class-for-everything disease**: stateless classes that should be plain functions/modules
- **Stale patterns**: `os.path` instead of `pathlib`, `.format()` instead of f-strings, `%` formatting, `if/elif` chains instead of `match` (3.10+), `typing.Optional[X]` instead of `X | None` (3.10+)
- **Type hints**: `Any` used to bypass type errors, redundant hints on obvious assignments, overly complex `TypeVar` gymnastics
- **Verbose**: manual dict/list building instead of comprehensions, nested `if` instead of early returns, `lambda` assigned to a variable (just use `def`)
- **Dependency creep**: `requests` for a single GET when `urllib` works, `python-dotenv` when `os.environ` is fine

## Language: Bash / Shell

Read `references/shell.md` for the full Shell pattern catalog. Key highlights:

- **Missing safety**: no `set -euo pipefail`, unquoted variables, no `shellcheck` compliance
- **Useless use of cat**: `cat file | grep` instead of `grep file`
- **Stale patterns**: backticks instead of `$()`, `expr` instead of `$(())`, `[ ]` instead of `[[ ]]` in bash/zsh, parsing `ls` output
- **Over-defensive**: `if command; then ... fi` on every line instead of `set -e`, manual `$?` checks
- **Verbose**: `echo "$var" | grep` instead of `[[ "$var" == *pattern* ]]`, external tools for built-in operations

## Language: Infrastructure as Code

Read `references/iac.md` for the full IaC pattern catalog covering Terraform, Ansible, Helm, and Kubernetes manifests. Key highlights:

- **Terraform**: over-modularizing (module for a single resource), redundant `depends_on` when implicit deps exist, not using `locals` for repeated expressions, unpinned provider versions, `provisioner` blocks instead of proper config management
- **Ansible**: `command`/`shell` when a module exists, `ignore_errors: true` everywhere, registering variables never used, not using handlers for service restarts, no YAML anchors for DRY
- **Helm**: hardcoded values in templates, `tpl` for static strings, `.Values` spaghetti without defaults, chart version not pinned
- **Kubernetes**: no resource requests/limits, `latest` tags, no namespace, imperative `kubectl run/create` in automation, no readiness/liveness probes

## Language: Rust

Read `references/rust.md` for the Rust pattern catalog. Key highlights:

- **Clone abuse**: `.clone()` to dodge the borrow checker -- the #1 AI-Rust tell
- **Error type proliferation**: custom error enums for every module instead of `anyhow`/`thiserror`
- **Overly generic trait bounds**: `T: Display + Debug + Clone + Send + Sync` when only `Display` is used
- **Verbose**: `match` with two arms instead of `if let`, explicit `return` at function end, manual Option/Result matching instead of combinators
- **Unsafe overuse**: `unsafe` blocks without `// SAFETY:` comments, `transmute` when `as` works
- **Stale**: `extern crate`, `#[macro_use]`, `try!()`, `lazy_static` instead of `std::sync::LazyLock` (1.80+)

## Language: Docker / Containers

Read `references/docker.md` for Dockerfile and Compose pattern catalog. Key highlights:

- **Fat images**: no multi-stage build, build tools in final stage, `COPY . .` before dep install (cache busting)
- **Layer waste**: separate `RUN` per package, `ADD` for local files, `RUN cd` instead of `WORKDIR`
- **Security**: running as root, `chmod 777`, secrets in build args/env, missing `.dockerignore`
- **Compose bloat**: `container_name` everywhere, `restart: always` without healthchecks, `depends_on` without conditions, hardcoded ports
- **Stale**: old base image versions, `MAINTAINER` directive, ENTRYPOINT+CMD confusion

## Other Languages

For Go and other languages without dedicated reference files: apply the universal patterns (sections 1-9) only. Note in the report that language-specific checks were skipped. Common cross-language tells still apply -- over-abstraction, comment noise, cross-language leakage, and error handling anti-patterns look similar everywhere.

## Research & Citations

Read `references/research-sources.md` for statistics, source citations, and deeper context on the "no soul" problem. Use when the user wants data to back up findings.

---

## What NOT to Flag

These look like slop but aren't:

- **Security patterns**: auth, CORS, SSRF protection, input validation at boundaries, rate limiting, TLS configuration, RBAC policies. Correct even if "defensive".
- **Explicit types/annotations on public interfaces**: function signatures, exported types, API contracts benefit from explicitness.
- **Abstractions that enable testing**: interfaces with one implementation for dependency injection.
- **Workaround comments**: "works around X bug", "API requires this", "platform-specific" -- institutional knowledge.
- **Defensive checks on external data**: network responses, user input, deserialized data, third-party library output.
- **Shell verbosity for clarity**: complex pipelines benefit from intermediate variables and comments.
- **Terraform `count`/`for_each` on single resources**: might be conditional (`count = var.enabled ? 1 : 0`).
- **Ansible `when` conditions that seem obvious**: often guarding against cross-platform differences.

---

## Related Skills

- **code-review** -- finds bugs and correctness issues. Anti-slop finds quality and style issues.
  If it would cause incorrect behavior, it's a code-review finding. If it's ugly but correct,
  it's anti-slop.
- **security-audit** -- finds vulnerabilities. Defensive code that looks like "overkill" may be
  correct security practice. Check the "What NOT to Flag" list before flagging security patterns.
- **full-review** -- orchestrates code-review, anti-slop, security-audit, and update-docs in
  parallel. Anti-slop is one of the four passes.

---

## Reference Files

- `references/typescript.md` -- TypeScript and JavaScript anti-slop patterns
- `references/python.md` -- Python anti-slop patterns
- `references/shell.md` -- shell and script anti-slop patterns
- `references/iac.md` -- Terraform, Ansible, Helm, and Kubernetes anti-slop patterns
- `references/rust.md` -- Rust anti-slop patterns
- `references/docker.md` -- Dockerfile and Compose anti-slop patterns
- `references/research-sources.md` -- supporting research, citations, and external context

---

## Output Format

````markdown
## Anti-Slop Audit: [scope]

### Findings

#### [Category Name] ([count] items)

**[action]** ([severity]) `path/to/file:line` -- [description]
```[language]
// before
[code snippet]

// after
[improved code snippet]
```

### Summary
- X findings across Y files
- [top-level observations about codebase health]
````

Keep it concise. Show the diff, not a paragraph explaining it.

---

## Rules

- **Keep correctness out of scope.** If it would actually break behavior, route it to code-review instead of padding this report.
- **Keep security out of scope.** Defensive code often looks verbose on purpose. Do not flag it casually.
- **Read before judging.** A pattern that looks generic in isolation may be justified by framework or project constraints.
- **Prefer concrete rewrites.** If you flag a pattern, show the simpler version.
