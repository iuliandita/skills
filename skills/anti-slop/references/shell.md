# Bash / Shell Slop Patterns

## Missing Safety (Lies)

The #1 shell slop tell: no error handling discipline.

**Detect:**
- Missing `set -euo pipefail` (or equivalent) at the top of scripts
- Unquoted variables: `$var` instead of `"$var"` (word splitting + globbing)
- No `shellcheck` compliance (if shellcheck is available, run it)
- Using `#!/bin/bash` instead of `#!/usr/bin/env bash` (portability)
- Missing `trap` for cleanup on exit/error

**Fix:** Add `set -euo pipefail` to every script. Quote all variables. Use `shellcheck` as the authority on shell correctness.

**Exception:** Interactive one-liners and `.bashrc`/`.zshrc` functions don't need `set -euo pipefail`.

## Useless Use of Cat (Noise)

The classic. Using `cat` to feed data into a command that can read files directly.

```bash
# slop
cat file.txt | grep "pattern"
cat file.txt | wc -l
cat file.txt | head -5

# better
grep "pattern" file.txt
wc -l < file.txt
head -5 file.txt
```

Also: `echo "$var" | command` when a here-string works: `command <<< "$var"`

## Stale Patterns (Lies)

- Backticks `` `command` `` -> `$(command)` (nestable, clearer)
- `expr 1 + 1` -> `$((1 + 1))` (arithmetic expansion)
- `[ ]` (test) -> `[[ ]]` in bash/zsh (no word splitting, regex support, safer)
- Parsing `ls` output -> `for f in *.txt` or `find ... -print0 | xargs -0`
- `seq 1 10` -> `{1..10}` (brace expansion)
- `echo -e` for escape sequences -> `printf` (portable)
- `which command` -> `command -v command` (POSIX)
- `grep ... | awk '{print $2}'` -> `awk '/pattern/ {print $2}'` (awk can grep)
- `cat <<EOF > file` for simple content -> `printf` or direct redirect

## Over-Defensive Patterns (Soul)

```bash
# slop: manual error checking with set -e already active
set -euo pipefail
result=$(some_command)
if [ $? -ne 0 ]; then  # redundant - set -e already handles this
    echo "Failed"
    exit 1
fi

# better: let set -e do its job
set -euo pipefail
result=$(some_command)
```

- `if command; then true; else echo "failed"; exit 1; fi` when `set -e` is active
- Manual `$?` checks after every command
- `|| true` on commands that should fail loudly
- Wrapping every command in a function just for error handling

**Exception:** `|| true` is correct when a command legitimately returns non-zero for informational reasons (e.g., `grep` no match, `diff` finding differences). Also fine in parallel Bash calls where one non-zero would cancel siblings.

## Verbose Patterns (Noise)

```bash
# slop: external tool for built-in operation
result=$(echo "$string" | tr '[:upper:]' '[:lower:]')

# better (bash 4+)
result="${string,,}"
```

```bash
# slop: subshell for variable assignment
DIR=$(dirname "$0")
cd "$DIR"

# better
cd "$(dirname "$0")"
```

- `echo "$var" | grep -q pattern` -> `[[ "$var" == *pattern* ]]`
- `echo "$var" | sed 's/old/new/'` -> `"${var/old/new}"`
- `echo "$var" | cut -d'/' -f1` -> `"${var%%/*}"`
- `echo "$var" | wc -c` -> `${#var}`
- Spawning subshells for simple variable manipulation
- `for f in $(find ...)` -> `find ... -exec` or `while IFS= read -r` with `-print0`

## Script Structure (Soul)

**Detect:**
- No `main()` function pattern (all code at top level in non-trivial scripts)
- Functions defined after they're called
- No usage/help message for scripts that take arguments
- Hardcoded paths that should be variables or arguments
- Missing `readonly` on constants

**Fix:** Use `main()` pattern for scripts >50 lines. Define functions before use. Use `readonly` for constants. Accept paths as arguments with sensible defaults.

## AI-Native Tells (Lies + Soul)

**Detect:**
- Hallucinated flags or subcommands copied from adjacent CLIs (`--json`, `--force`, `--yes`, `config get`) without checking `--help`
- `2>/dev/null || true` glued onto uncertain commands to make the script "robust"
- Large inline heredocs used to generate YAML/JSON/config in automation when the repo already has templates or source files
- Retry loops and sleeps around local deterministic commands instead of fixing ordering or preconditions
- `command -v tool >/dev/null || install_tool` inside project scripts where tool installation should be explicit

**Fix:** Check the real CLI help text before keeping a flag. Let failures surface unless the non-zero is expected and documented. Prefer checked-in files or templates over opaque heredocs for non-trivial config. Keep installation/bootstrap separate from normal task scripts.
