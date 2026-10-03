# Report Format

Use these templates for the code-review report. Severity markers and the 80% threshold come from SKILL.md.

### When issues are found:

````markdown
## Code Review: [scope]

### Findings

#### P0 - Must Fix ([count] issues)

🔴 **[confidence]%** `path/to/file:line` - [description]

[Why this is wrong and what will happen if it isn't fixed]
**Triggers when:** [specific input, sequence, or condition that causes the bug]

```[language]
// before
[code snippet]

// after
[fixed code snippet]
```

#### P1 - Should Fix ([count] issues)

🟠 **[confidence]%** `path/to/file:line` - [description]

[Explanation]

```[language]
// before
[code snippet]

// after
[fixed code snippet]
```

#### P2 - Nice to Fix ([count] issues)
🟡 **[confidence]%** `path/to/file:line` - [description]

[Explanation]

#### P3 - Backlog ([count] issues)
🔵 **[confidence]%** `path/to/file:line` - [description]

[Explanation]

#### Info ([count] notes)
⚪ **[confidence]%** `path/to/file:line` - [description]

[Non-actionable observation]

### Observations

[Patterns noticed below the 80% threshold but worth mentioning as a group. This is where higher-level insights go - "error handling is inconsistent across the API handlers", "no input validation on any of the CLI commands", "the test suite mocks the database everywhere so nothing tests actual queries." These aggregate observations are often more valuable than individual findings.]

### Summary
- X findings across Y files (P0: Z, P1: W, P2: V, P3: U, info: T)
- [1-2 sentences on overall code health as it relates to correctness]
````

### When no issues are found:

````markdown
## Code Review: [scope]

No issues found above the confidence threshold.

**Checked:** [list what was reviewed - e.g., "14 files, focused on API handlers and auth middleware"]
**Linters:** [what ran, what was missing - e.g., "eslint clean, shellcheck not installed (`pacman -S shellcheck`)"]

[Optional: 1-2 sentences noting anything positive - well-structured error handling, good test coverage, etc.]
````

Keep it tight. Show the bug, show the fix, move on. Long explanations only when the bug is subtle and the reader needs to understand *why* it's wrong.
