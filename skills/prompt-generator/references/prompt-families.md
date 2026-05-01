# Prompt Families

## System Prompts

Use for durable behavior, role, boundaries, and output contracts. Keep task-specific data out of
the system prompt unless it is stable across runs.

## Task Prompts

Use for one-off work. Put source material in fenced blocks and state whether it is trusted or
untrusted.

## Reusable Templates

Use `{{VARIABLE_NAME}}` placeholders, define each variable once, and keep variable names stable.

## Code-Review Prompts

Lead with findings, require file and line references, and ask for severity ordering.

## Delegation Prompts

Include task ownership, files or modules in scope, files out of scope, expected final answer, and
whether edits are allowed.
