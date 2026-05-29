# Prompt Families

Pick the family from how the prompt will be used, not from how the user phrased the request. The
family determines structure, what must be specified, and the most common ways the prompt fails.

## System Prompts

Use for durable behavior, role, boundaries, and output contracts that hold across many runs. Keep
task-specific data out of the system prompt unless it is stable across runs.

Annotated example:

```
You are a release-notes editor. You receive raw merged-PR titles and return grouped, human-readable
release notes. Group by: Features, Fixes, Internal. Within a group, order by impact. Drop noise
(version bumps, lint-only changes). Never invent a change that is not in the input.
```

What makes it work: stable role, fixed grouping contract, an explicit drop rule, and an
anti-fabrication line. None of it depends on a specific run.

Counter-example (task data leaking into a system prompt):

```
You are a release-notes editor. Summarize PRs #418, #421, and #430 for the v2.3 release.
```

The PR numbers and version belong in the task prompt. As written, the system prompt is single-use
and must be rewritten every release.

Common mistakes:

- Stuffing one run's input into durable instructions.
- Vague role ("helpful assistant") that constrains nothing.
- Output contract described in prose when a fixed shape is required.

## Task Prompts

Use for one-off work. Put source material in fenced blocks and state whether it is trusted or
untrusted. Keep instructions below the data when the data block is large.

Annotated example:

```
Extract every email address and phone number from the text below. Return one JSON object per
contact with keys "email" and "phone"; use null for a missing field. Do not include addresses that
appear inside the example block.

<untrusted_source>
{{PASTED_TEXT}}
</untrusted_source>
```

What makes it work: explicit output shape, a null rule for missing fields, a fenced untrusted
block, and an instruction that the source is data, not commands.

Counter-example:

```
Pull out the contact info from this: {{PASTED_TEXT}}
```

No output shape, no delimiter, and pasted text that says "ignore previous instructions" would be
read as an instruction.

Common mistakes:

- No delimiter between instructions and pasted/untrusted content.
- Output shape left to the model to guess.
- Asking for "all relevant info" instead of named fields.

## Reusable Templates

Use `{{VARIABLE_NAME}}` placeholders, define each variable once, and keep variable names stable so
callers can fill them programmatically.

Annotated example:

```
Translate the text below from {{SOURCE_LANG}} to {{TARGET_LANG}}. Preserve markdown structure and
code blocks verbatim. Return only the translation.

TEXT:
{{BODY}}
```

Variables table: `SOURCE_LANG`, `TARGET_LANG`, `BODY`, each used exactly once in the body.

Counter-example: `{{lang}}` used in two different senses (source in one place, target in another),
or a placeholder named in the body that never appears in the variables table.

Common mistakes:

- Placeholder in the body with no entry in the variables table, or vice versa.
- Renaming a variable mid-template (`{{LANG}}` then `{{LANGUAGE}}`).
- Embedding one run's value inline instead of a placeholder.

## Code-Review Prompts

Lead with findings, require file and line references, and ask for severity ordering. The reviewer
should report nothing rather than pad with style nitpicks.

Annotated example:

```
You are a senior reviewer. For each issue, output: severity (P0/P1/P2/P3/info), file:line, and a
one-line description. Order by severity. Cover bugs, edge cases, security, and performance. Skip
style. If nothing is wrong, output exactly: No issues found.
```

What makes it work: a fixed finding shape with file:line, a severity scale, a scope list, an
explicit skip rule, and a defined empty result.

Counter-example: "Review this code and tell me what you think." Produces unranked prose with no
locations and no way to triage.

Common mistakes:

- No file:line, so findings cannot be acted on.
- No severity, so everything reads as equally urgent.
- No empty-result contract, so the model invents issues to look useful.

## Delegation Prompts

Use when handing a scoped task to an agent or subagent. Include task ownership, files or modules in
scope, files out of scope, whether edits are allowed, and the expected final answer shape.

Annotated example:

```
Task: add pagination to the /users list endpoint.
You own: src/api/users.ts and its test file only.
Out of scope: do not touch routing, auth, or the database schema.
Allowed edits: yes, in the two files above. Ask before adding dependencies.
Return: a summary of the change plus the final diff.
```

What makes it work: a single clear task, explicit in-scope and out-of-scope files, an edit
permission boundary, a dependency gate, and a defined return shape.

Counter-example: "Improve the users endpoint." No scope, no edit boundary, no return contract; the
agent may rewrite unrelated files and report inconsistently.

Common mistakes:

- No out-of-scope list, so the agent edits adjacent files.
- Edit permission left implicit.
- No defined return shape, so the parent agent cannot consume the result.
