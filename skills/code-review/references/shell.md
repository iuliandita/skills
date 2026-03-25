# Bash / Shell Bug Patterns

Bug patterns specific to Bash and POSIX shell scripts. Focused on correctness -- not style (see anti-slop) or security (see security-audit).

---

## Word Splitting & Globbing

The #1 source of shell bugs. Unquoted variables undergo word splitting and glob expansion.

### Unquoted Variables

**Detect:**
- `$var` instead of `"$var"` in any context except inside `[[ ]]`
- `for f in $files` instead of `for f in "${files[@]}"`
- `rm $file` where `$file` could contain spaces or glob characters
- `[ -f $path ]` instead of `[ -f "$path" ]`

**Example:**
```bash
# bug: breaks on filenames with spaces, and globs expand
file="my file*.txt"
rm $file  # runs: rm my file*.txt (3+ args, glob expanded)

# fix: always quote
rm "$file"  # runs: rm "my file*.txt" (1 arg, literal)
```

### Array Expansion

**Detect:**
- `${array[*]}` instead of `"${array[@]}"` (the former joins with IFS, the latter preserves elements)
- `"${array[*]}"` as a single string when separate elements are needed
- Assigning command output to a plain variable when an array is needed: `files=$(ls)` vs `files=($(ls))`

### Glob Expansion in Unexpected Places

**Detect:**
- `case $var in *) ...` without quoting (glob patterns in case are intentional, but the variable should still be quoted)
- Variables containing `*`, `?`, or `[` used without quoting
- `echo $var` where var could contain glob characters

---

## Exit Code Masking

### Pipes Hide Failures

By default, a pipeline's exit code is the exit code of the *last* command. Failures in earlier stages are silently lost.

**Detect:**
- `cmd1 | cmd2` where `cmd1` failing would be a problem
- Missing `set -o pipefail` (or `pipefail` not set)
- `curl ... | jq ...` -- if curl fails, jq gets empty input and may "succeed"

**Fix:** Use `set -o pipefail` or check `${PIPESTATUS[@]}` (bash) / `${pipestatus[@]}` (zsh).

### Command Substitution Masks Exit Codes

Assignment always succeeds, hiding the command's exit code.

**Detect:**
- `local var=$(cmd)` -- `local` always returns 0, masking cmd's exit code
- `export var=$(cmd)` -- same problem
- `readonly var=$(cmd)` -- same problem

**Example:**
```bash
# bug: even if cmd fails, local returns 0
local output=$(failing_command)
echo $?  # always 0!

# fix: separate declaration from assignment
local output
output=$(failing_command)
echo $?  # actual exit code
```

### Conditional Command Chains

**Detect:**
- `cmd1 && cmd2 || cmd3` used as if-then-else (cmd3 runs if cmd2 fails too!)
- Missing `set -e` and no explicit error checking
- `|| true` hiding real failures (legitimate in some cases, but verify intent)

---

## Variable Bugs

### Uninitialized Variables

Without `set -u` (nounset), uninitialized variables silently expand to empty string.

**Detect:**
- Missing `set -u` / `set -o nounset`
- Variables used before assignment (typos in variable names are silent bugs)
- `${var:-default}` used when `${var:?error}` would be more appropriate (fail instead of default)

### Subshell Variable Scope

Variables set inside a subshell don't affect the parent shell.

**Detect:**
- `cat file | while read line; do count=$((count+1)); done; echo $count` -- count is 0 (pipe creates subshell)
- `(cd /tmp && var=1)` followed by using `$var` in parent
- Process substitution gotchas: `while read line; do ...; done < <(cmd)` avoids the subshell problem but isn't POSIX

**Example:**
```bash
# bug: count is always 0 in parent shell
count=0
cat file.txt | while read -r line; do
  ((count++))
done
echo "$count"  # 0!

# fix: redirect instead of pipe
count=0
while read -r line; do
  ((count++))
done < file.txt
echo "$count"  # correct
```

### IFS Surprises

- `IFS=: read -ra parts <<< "$PATH"` -- IFS change persists if not localized
- `for word in $var` splits on IFS (default: space, tab, newline) -- might not be what you want
- Missing `-r` flag on `read` -- backslashes are interpreted as escapes

---

## Signal & Cleanup Bugs

### Missing Trap for Cleanup

Temporary files, lock files, and backgrounded processes not cleaned up on exit/error.

**Detect:**
- `mktemp` without a corresponding `trap` to clean up
- Lock files created without `trap` to remove on exit
- Background processes started without `trap` to kill them
- `set -e` without cleanup trap (script exits, temp files remain)

**Example:**
```bash
# bug: temp file left behind on error
tmpfile=$(mktemp)
process "$tmpfile"
rm "$tmpfile"  # never runs if process fails with set -e

# fix: trap for cleanup
tmpfile=$(mktemp)
trap 'rm -f "$tmpfile"' EXIT
process "$tmpfile"
```

### Background Process Management

**Detect:**
- `cmd &` without `wait` or `trap ... EXIT` to clean up
- Missing `wait` before script exit (orphaned background processes)
- No check if background process is still running before using its output

---

## Portability Bugs

### Bashisms in POSIX Scripts

Scripts with `#!/bin/sh` shebang using bash-only features.

**Detect:**
- `[[ ]]` (bash) in `#!/bin/sh` scripts (use `[ ]` or `test`)
- `source` (bash) instead of `.` (POSIX)
- `function name() {}` (bash) instead of `name() {}` (POSIX)
- Arrays (bash/zsh only, not POSIX)
- `$RANDOM`, `$BASHPID`, `${var,,}` (lowercase), `${var^^}` (uppercase)
- `echo -e` (non-portable, use `printf`)

### GNU vs BSD Tool Differences

**Detect:**
- `sed -i ''` (BSD) vs `sed -i` (GNU) -- different syntax for in-place editing
- `grep -P` (GNU only, PCRE) -- use `grep -E` for portability
- `date -d` (GNU) vs `date -j -f` (BSD) for date parsing
- `readlink -f` (GNU) not available on macOS without coreutils
- `stat` format strings differ between GNU and BSD

---

## Quoting & Escaping Edge Cases

### Here-docs and Here-strings

**Detect:**
- Unquoted here-doc delimiter: `<<EOF` (variables expand) vs `<<'EOF'` (literal)
- Variables in here-docs that should be literal but aren't quoted
- Here-string `<<<` not available in POSIX sh

### eval and Indirect Expansion

**Detect:**
- `eval` with user-controlled input (injection risk, but also correctness: double-expansion)
- `${!var}` (indirect expansion) used without verifying the variable name is valid
- Nested quoting in `eval` context

---

## Arithmetic Bugs

### Integer-Only Arithmetic

Bash arithmetic is integer-only. Floating-point silently truncates or errors.

**Detect:**
- `$((10 / 3))` expecting 3.33 (gives 3)
- Floating-point comparisons with `-gt` / `-lt` (these are integer operators)
- `bc` or `awk` needed for float math but not used

### Leading Zeros

- `$((08))` and `$((09))` fail (bash interprets leading zero as octal, 8 and 9 aren't valid octal digits)
- `printf "%02d"` is fine for formatting, but be careful with arithmetic on zero-padded strings

---

## Test/Conditional Bugs

### `[` vs `[[`

- `[` is a command -- needs quoting, can't use `&&`/`||` inside, no pattern matching
- `[[` is bash syntax -- supports `&&`, `||`, `=~` regex, glob patterns, no word splitting
- Mixing the two styles inconsistently in the same script

### Common Test Mistakes

- `-a` / `-o` (ambiguous in `[`; deprecated; use `&&` / `||` between separate `[` commands)
- `[ $var = "value" ]` without quoting `$var` (breaks if var is empty or contains spaces)
- `[ -z $var ]` succeeds when `$var` is unset (correct but misleading -- use `[[ -z ${var+x} ]]` to check if set)
