# Bash / Shell Slop Patterns

## Missing Safety (Lies)

The #1 shell slop tell: no error handling discipline.

**Detect:**
- Unhandled command failures; strict-mode options must fit the declared shell and its calling contexts
- Unquoted variables: `$var` instead of `"$var"` (word splitting + globbing)
- No `shellcheck` compliance (if shellcheck is available, run it)
- A shebang whose interpreter path is unavailable on the target; fixed paths and PATH lookup have different deployment tradeoffs
- Missing `trap` for cleanup on exit/error

**Fix:** Choose supported strict-mode options and explicit error handling for the script. Quote expansions unless splitting or globbing is intentional. ShellCheck catches many defects but does not prove behavior correct.

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

- Wrappers that add no diagnostics or recovery; an explicit failure branch remains useful with `set -e`
- Manual `$?` checks after every command
- `|| true` on commands that should fail loudly
- Wrapping every command in a function just for error handling

**Exception:** Distinguish expected statuses from errors: grep/diff status1 can be informational, while higher statuses indicate failure. Collect each parallel command's status instead of turning all failures into success. `set -e` is suppressed in several conditional and function contexts; verify the actual call site.

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

- A literal substring search may use shell pattern matching; a grep regular expression is not equivalent to a literal substring test
- Shell substitution can replace a simple literal transform; preserve regex, escaping, and replacement semantics when sed uses them
- `echo "$var" | cut -d'/' -f1` -> `"${var%%/*}"`
- Distinguish byte counts from character counts and any newline added by the producer; `${#var}` does not generally equal `echo "$var" | wc -c`
- Spawning subshells for simple variable manipulation
- `for f in $(find ...)` -> `find ... -exec` or `while IFS= read -r -d ''` in Bash with `-print0`

## Script Structure (Soul)

**Detect:**
- No `main()` function pattern (all code at top level in non-trivial scripts)
- Functions defined after they're called
- No usage/help message for scripts that take arguments
- Hardcoded paths that should be variables or arguments
- Missing `readonly` on constants

**Fix:** Use a `main()` function when it clarifies control flow; line count alone is not a defect. Define functions before use and parameterize environment-dependent paths.

## AI-Native Tells (Lies + Soul)

**Detect:**
- Hallucinated flags or subcommands copied from adjacent CLIs (`--json`, `--force`, `--yes`, `config get`) without checking `--help`
- `2>/dev/null || true` glued onto uncertain commands to make the script "robust"
- Large inline heredocs used to generate YAML/JSON/config in automation when the repo already has templates or source files
- Retry loops and sleeps around local deterministic commands instead of fixing ordering or preconditions
- `command -v tool >/dev/null || install_tool` inside project scripts where tool installation should be explicit

**Fix:** Check the real CLI help text before keeping a flag. Let failures surface unless the non-zero is expected and documented. Prefer checked-in files or templates over opaque heredocs for non-trivial config. Keep installation/bootstrap separate from normal task scripts.
