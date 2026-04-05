# Bash Reference

> Patterns and features for Bash 5.3 on Linux and macOS. Covers what you need beyond the
> universal patterns in the main skill -- bash-specific features, gotchas, and idioms.

---

## Section Routing

| Task | What to read |
|------|-------------|
| Writing a new bash script | Section 1 (template) + section 9 (error handling) |
| Parameter expansion / string ops | Section 2 |
| Arrays (indexed or associative) | Section 3 |
| Conditionals and test expressions | Section 4 |
| Process substitution / subshells | Section 5 |
| Heredocs and here strings | Section 6 |
| Reading input / parsing files | Section 7 |
| Bash 5.x features | Section 10 |
| Porting bash to POSIX sh | Section 11 |
| Porting bash to zsh | Load the zsh reference instead -- it has the full compat matrix |
| Debugging a bash script | Section 12 |

---

## 1. Script Template

```bash
#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

log_info()  { printf '\033[0;32m[INFO]\033[0m %s\n' "$1"; }
log_warn()  { printf '\033[0;33m[WARN]\033[0m %s\n' "$1"; }
log_error() { printf '\033[0;31m[ERROR]\033[0m %s\n' "$1" >&2; }

cleanup() {
    # Cleanup logic here
    :
}
trap cleanup EXIT INT TERM

usage() {
    cat <<EOF
Usage: $(basename "$0") [options] <argument>

Options:
    -h, --help      Show this help
    -v, --verbose   Verbose output
    -f, --file      Input file
EOF
}

main() {
    local verbose=false
    local file=""

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)    usage; exit 0 ;;
            -v|--verbose) verbose=true; shift ;;
            -f|--file)    file="$2"; shift 2 ;;
            --)           shift; break ;;
            -*)           log_error "Unknown option: $1"; usage; exit 1 ;;
            *)            break ;;
        esac
    done

    log_info "Starting..."
    # Your logic here
    log_info "Done."
}

main "$@"
```

---

## 2. Parameter Expansion

### String operations

```bash
str="Hello World"

# Length
echo "${#str}"                 # 11

# Substring (0-indexed)
echo "${str:0:5}"              # Hello
echo "${str:6}"                # World
echo "${str: -5}"              # World (note the space before -)

# Case conversion (bash 4.0+)
echo "${str,,}"                # hello world (lowercase)
echo "${str^^}"                # HELLO WORLD (uppercase)
echo "${str,}"                 # hello World (first char lower)
echo "${str^}"                 # Hello World (first char upper)

# Pattern removal
path="/home/user/file.tar.gz"
echo "${path##*/}"             # file.tar.gz (basename -- remove longest prefix)
echo "${path%/*}"              # /home/user (dirname -- remove shortest suffix)
echo "${path%%.*}"             # /home/user/file (remove longest suffix)
echo "${path#*.}"              # tar.gz (remove shortest prefix through first .)

# Replacement
echo "${str/World/Bash}"       # Hello Bash (first match)
echo "${str//l/L}"             # HeLLo WorLd (all matches)
echo "${str/#Hello/Hi}"        # Hi World (anchor to start)
echo "${str/%World/Earth}"     # Hello Earth (anchor to end)
```

### Default / fallback values

```bash
# ${var:-default}  -- use default if var is unset or empty
name="${1:-anonymous}"

# ${var:=default}  -- assign default if var is unset or empty
: "${TMPDIR:=/tmp}"

# ${var:+value}    -- use value if var IS set and non-empty
extra="${DEBUG:+--verbose}"

# ${var:?message}  -- error if var is unset or empty
: "${API_KEY:?API_KEY must be set}"
```

### Indirect expansion

```bash
# ${!prefix*} -- list variable names starting with prefix
CONF_HOST="localhost"
CONF_PORT="8080"
echo "${!CONF_*}"              # CONF_HOST CONF_PORT

# ${!var} -- indirect reference (the value of var names another variable)
key="HOME"
echo "${!key}"                 # /home/user
```

---

## 3. Arrays

### Indexed arrays (0-based)

```bash
# Declaration
arr=(alpha bravo charlie)
declare -a arr                 # explicit declaration (optional)

# Access
echo "${arr[0]}"               # alpha (first element)
echo "${arr[-1]}"              # charlie (last element, bash 4.3+)
echo "${arr[@]}"               # all elements
echo "${#arr[@]}"              # 3 (length)

# Append
arr+=(delta)

# Slice
echo "${arr[@]:1:2}"           # bravo charlie (offset 1, count 2)

# Delete
unset 'arr[1]'                 # removes bravo (leaves gap -- indices don't shift)

# Iterate
for item in "${arr[@]}"; do
    echo "$item"
done

# Iterate with index
for i in "${!arr[@]}"; do
    echo "$i: ${arr[$i]}"
done

# Read lines into array
mapfile -t lines < file.txt            # bash 4.0+
readarray -t lines < file.txt          # alias for mapfile

# Read command output into array
mapfile -t files < <(find . -name "*.sh")
```

### Associative arrays (bash 4.0+)

```bash
declare -A config
config[host]="localhost"
config[port]="8080"
config[debug]="true"

# Or in one shot (bash 4.0+)
declare -A config=(
    [host]="localhost"
    [port]="8080"
    [debug]="true"
)

# Access
echo "${config[host]}"         # localhost

# All keys
echo "${!config[@]}"           # host port debug (unordered)

# All values
echo "${config[@]}"            # localhost 8080 true (unordered)

# Check if key exists
if [[ -v config[host] ]]; then echo "exists"; fi    # bash 4.2+

# Delete key
unset 'config[debug]'

# Iterate
for key in "${!config[@]}"; do
    echo "$key = ${config[$key]}"
done
```

### Array gotchas

- **Always quote `"${arr[@]}"`**. Unquoted `${arr[@]}` splits elements with spaces.
- `${arr[*]}` joins all elements into one string (IFS-separated). `${arr[@]}` keeps them separate. Use `[@]` in for loops, `[*]` in printf format strings.
- `unset 'arr[N]'` leaves a gap. Use `arr=("${arr[@]}")` to reindex if needed.
- Bash arrays are sparse. `${#arr[@]}` returns the count of assigned elements, not the highest index.

---

## 4. Conditionals

### `[[ ]]` vs `[ ]`

`[[ ]]` is bash-specific and preferred. `[ ]` is POSIX and runs `/usr/bin/[` (or the builtin).

```bash
# String comparison (use [[ ]] -- no word splitting or glob expansion)
[[ "$str" == "hello" ]]        # equality
[[ "$str" != "hello" ]]        # inequality
[[ "$str" == hello* ]]         # glob match (no quotes on pattern!)
[[ "$str" =~ ^[0-9]+$ ]]      # regex match
[[ -z "$str" ]]                # empty string
[[ -n "$str" ]]                # non-empty string

# Numeric comparison
(( a > b ))                    # arithmetic context (preferred for numbers)
[[ "$a" -gt "$b" ]]           # also works

# File tests
[[ -f "$path" ]]               # regular file exists
[[ -d "$path" ]]               # directory exists
[[ -e "$path" ]]               # any type exists
[[ -r "$path" ]]               # readable
[[ -w "$path" ]]               # writable
[[ -x "$path" ]]               # executable
[[ -s "$path" ]]               # non-empty file
[[ -L "$path" ]]               # symlink
[[ "$a" -nt "$b" ]]           # a is newer than b
[[ "$a" -ot "$b" ]]           # a is older than b

# Logical operators (inside [[ ]])
[[ -f "$f" && -r "$f" ]]      # AND
[[ -f "$f" || -d "$f" ]]      # OR
[[ ! -f "$f" ]]               # NOT
```

### Regex matching

```bash
if [[ "$input" =~ ^([a-z]+)-([0-9]+)$ ]]; then
    echo "Full match: ${BASH_REMATCH[0]}"   # e.g., "foo-123"
    echo "Group 1: ${BASH_REMATCH[1]}"      # e.g., "foo"
    echo "Group 2: ${BASH_REMATCH[2]}"      # e.g., "123"
fi

# Store regex in a variable to avoid quoting issues
pattern='^v[0-9]+\.[0-9]+\.[0-9]+$'
[[ "$tag" =~ $pattern ]]       # don't quote the variable!
```

### Arithmetic

```bash
# (( )) for arithmetic evaluation
(( count++ ))
(( total = a + b * c ))
(( remaining = total % batch_size ))

# $(( )) for arithmetic expansion (returns the value)
echo "Result: $(( a + b ))"
size=$(( width * height ))

# Integer comparison
if (( count > 10 )); then echo "big"; fi
```

---

## 5. Process Substitution and Subshells

### Process substitution

```bash
# <(cmd) -- treat command output as a file (FIFO)
diff <(sort file1.txt) <(sort file2.txt)
while IFS= read -r line; do echo "$line"; done < <(some_command)

# >(...) -- treat command input as a file (FIFO)
some_command | tee >(grep ERROR > errors.log) >(wc -l > count.txt) > /dev/null
```

### Subshell gotchas

```bash
# Variables set inside a pipe are in a subshell -- they don't persist
count=0
cat file.txt | while read -r line; do (( count++ )); done
echo "$count"   # still 0!

# Fix 1: process substitution instead of pipe
count=0
while read -r line; do (( count++ )); done < <(cat file.txt)
echo "$count"   # correct

# Fix 2: lastpipe (bash 4.2+) -- last pipe segment runs in current shell
shopt -s lastpipe
```

### Command grouping

```bash
# { } -- runs in current shell (preserves variables)
{ read -r first; read -r second; } < file.txt
echo "$first $second"    # both set

# ( ) -- runs in subshell (variables are lost)
( cd /tmp; do_something )
# cwd is unchanged here
```

---

## 6. Heredocs and Here Strings

```bash
# Heredoc (stdin from inline text)
cat <<EOF
Hello $USER, today is $(date).
EOF

# Heredoc with no expansion (single-quote the delimiter)
cat <<'EOF'
This $variable is literal.
No $(expansion) happens.
EOF

# Heredoc with indentation stripping (<<- with tabs)
if true; then
    cat <<-EOF
	This line can be indented with tabs.
	The tabs are stripped from the output.
	EOF
fi

# Here string (bash-specific, not POSIX)
grep "pattern" <<< "$variable"
read -r first rest <<< "hello world"
```

---

## 7. Reading Input and Parsing

### Reading files

```bash
# Line by line (preserving whitespace)
while IFS= read -r line; do
    printf '%s\n' "$line"
done < file.txt

# With a custom delimiter
while IFS=: read -r user _ uid gid _ home shell; do
    echo "$user -> $shell"
done < /etc/passwd

# Read into array by line
mapfile -t lines < file.txt

# Read specific fields from CSV
while IFS=, read -r name age city; do
    echo "$name is $age in $city"
done < data.csv
```

### Reading user input

```bash
# Basic prompt
read -rp "Enter name: " name

# With timeout
read -rt 10 -p "Enter name (10s): " name || echo "Timed out"

# Silent (passwords)
read -rs -p "Password: " pass; echo

# Single character
read -rn 1 -p "Continue? [y/N] " answer
```

### Parsing command output

```bash
# Read into variables
read -r total used free <<< "$(df -h / | awk 'NR==2 {print $2, $3, $4}')"

# Process substitution for while loop (avoids subshell)
while read -r pid cmd; do
    echo "PID $pid: $cmd"
done < <(ps -eo pid,comm --no-headers)
```

---

## 8. Functions

```bash
# Definition (two styles, both work)
my_func() {
    local name="$1"
    local count="${2:-1}"
    echo "$name: $count"
}
# or: function my_func { ... }  -- avoid this form for POSIX compat

# Local variables (always use local in functions)
process() {
    local -r input="$1"          # -r = readonly
    local -a items=()            # -a = indexed array
    local -A map=()              # -A = associative array
    local -i count=0             # -i = integer
}

# Return values
# Functions return an exit code (0-255). For data, use stdout or a global.
get_name() {
    echo "result"                 # captured via $(get_name)
}
result=$(get_name)

# Nameref (bash 4.3+) -- pass variable by reference
fill_array() {
    local -n arr_ref="$1"        # nameref to caller's variable
    arr_ref=(one two three)
}
declare -a my_arr
fill_array my_arr
echo "${my_arr[@]}"              # one two three
```

---

## 9. Error Handling

### set options

```bash
set -e          # Exit on error (any command returning non-zero)
set -u          # Exit on undefined variable
set -o pipefail # Exit on pipe failure (not just last command)
set -x          # Debug: print every command before execution

# Combined (always use this in scripts)
set -euo pipefail
```

### Traps

```bash
# Cleanup on exit (always runs, even on error)
cleanup() {
    rm -f "$tmpfile"
    [[ -n "${pid:-}" ]] && kill "$pid" 2>/dev/null
}
trap cleanup EXIT

# Trap specific signals
trap 'echo "Interrupted"; exit 130' INT
trap 'echo "Terminated"; exit 143' TERM

# ERR trap (runs on any command failure when set -e is active)
trap 'echo "Error on line $LINENO: $BASH_COMMAND" >&2' ERR

# DEBUG trap (runs before every command)
trap 'echo "+ $BASH_COMMAND"' DEBUG
```

### Error handling patterns

```bash
# Try/catch pattern
if ! output=$(some_command 2>&1); then
    log_error "Failed: $output"
    exit 1
fi

# Retry with backoff
retry() {
    local max_attempts="$1"; shift
    local delay=1
    local attempt=1
    while (( attempt <= max_attempts )); do
        if "$@"; then return 0; fi
        log_warn "Attempt $attempt/$max_attempts failed, retrying in ${delay}s..."
        sleep "$delay"
        (( delay *= 2 ))
        (( attempt++ ))
    done
    return 1
}
retry 3 curl -sf "https://example.com/health"

# Safe temporary files
tmpdir=$(mktemp -d) || exit 1
trap 'rm -rf "$tmpdir"' EXIT
```

---

## 10. Bash 5.x Features

### Bash 5.0 (2019)

```bash
# EPOCHSECONDS and EPOCHREALTIME
echo "$EPOCHSECONDS"          # Unix timestamp (seconds)
echo "$EPOCHREALTIME"         # Unix timestamp with microseconds

# Associative array assignment in declare
declare -A map=([key1]=val1 [key2]=val2)

# Negative subscripts for strings
str="hello"
echo "${str: -1}"              # o (already worked, but now consistent)
```

### Bash 5.1 (2020)

```bash
# SRANDOM -- cryptographic random (not based on PID like $RANDOM)
echo "$SRANDOM"                # 32-bit random from /dev/urandom

# ${var@U} / ${var@u} / ${var@L} -- case transformation operators
name="hello"
echo "${name@U}"               # HELLO (uppercase)
echo "${name@u}"               # Hello (capitalize first)
echo "${name@L}"               # hello (lowercase)

# BASH_REMATCH is now readonly inside [[ =~ ]]
# (prevents accidental modification)

# loadable builtins: sleep is now a builtin (faster in loops)
enable -f /usr/lib/bash/sleep sleep
```

### Bash 5.2 (2022)

```bash
# @a operator to get variable attributes
declare -i num=42
echo "${num@a}"                # i (integer attribute)
declare -A map=()
echo "${map@a}"                # A (associative array)
# Also: improved set -e in subshells, bracketed paste mode on by default
```

### Bash 5.3 (July 2025)

The biggest release since 5.0. Headline feature: non-forking command substitution.

```bash
# Non-forking command substitution -- runs in current shell, no fork+pipe
# Analogous to zsh's ${ } (see zsh reference Section 13)

# ${ cmd; } -- captures stdout without forking
result=${ printf '%s' "hello"; }    # note: space after { and ; before }
echo "$result"                       # hello

# ${| cmd; } -- command writes to REPLY instead of stdout
result=${| REPLY="computed-$(date +%s)"; }
echo "$result"                       # computed-1234567890

# Why it matters: variables modified inside ${ } persist in the caller
count=0
: ${ (( count++ )); }
echo "$count"                        # 1 (would be 0 with traditional $((...)))
```

Use `${ }` and `${| }` in: hot loops, prompt rendering, frequently-called functions,
startup scripts. The performance difference is significant when fork overhead matters
(embedded systems, tight loops, WSL where fork is expensive).

**Gotcha**: `${ cmd; }` requires the space after `{` and `;` before `}`. Without the
space, bash interprets it as parameter expansion.

Other additions:

```bash
# GLOBSORT -- control how pathname-completion results are sorted
GLOBSORT=size        # sort by size
GLOBSORT=name        # sort by name (default)
GLOBSORT=nosort      # no sorting (fastest for large directories)

# GLOBSORT also affects glob expansion in scripts:
GLOBSORT=size
files=(*.log)        # sorted by size, not name
```

- Improved `set -e` handling in compound commands
- `type -P` behavior refinements

---

## 11. Bash-isms to Avoid in POSIX sh

If you need to port a script to `#!/bin/sh`, these bash features are NOT available:

| Bash feature | POSIX alternative |
|-------------|-------------------|
| `[[ ]]` | `[ ]` (with more quoting) |
| `(( ))` arithmetic | `$(( ))` in test: `[ "$(( a > b ))" = 1 ]` |
| Arrays | Positional params (`set -- a b c; echo "$1"`) |
| `${var,,}` / `${var^^}` | `tr '[:upper:]' '[:lower:]'` via pipe or `$(...)` |
| `${var:offset:length}` | `expr substr` or `cut` |
| `<<<` here string | `echo "$var" \| cmd` or `printf '%s' "$var" \| cmd` |
| `<(cmd)` process sub | Temp files or named pipes |
| `mapfile` / `readarray` | `while read` loop |
| `local` (mostly works) | Technically not POSIX, but supported by dash/ash/all major sh |
| `function name { }` | `name() { }` (POSIX form) |
| `source file` | `. file` (POSIX form) |
| `BASH_SOURCE` | `$0` (different semantics in sourced files) |
| `declare -A` (assoc arrays) | No equivalent -- restructure the logic |
| `set -o pipefail` | Not POSIX -- check `${PIPESTATUS[@]}` equivalent doesn't exist either |
| `$RANDOM` | Read from `/dev/urandom`: `od -An -N2 -tu2 /dev/urandom` |
| `${ cmd; }` / `${| cmd; }` | `$(cmd)` (forks a subshell) |

See the full posix-sh reference for portable patterns.

---

## 12. Debugging

```bash
# Trace execution (shows every command)
bash -x script.sh
# Or inside the script:
set -x                         # enable
set +x                         # disable

# Print function call stack on error
trap 'echo "Error at ${FUNCNAME[0]}:${LINENO}" >&2' ERR

# Full stack trace
stacktrace() {
    local i
    for (( i=1; i < ${#FUNCNAME[@]}; i++ )); do
        printf '  %s() at %s:%d\n' \
            "${FUNCNAME[$i]}" "${BASH_SOURCE[$i]}" "${BASH_LINENO[$((i-1))]}" >&2
    done
}
trap stacktrace ERR

# Check for common issues
shellcheck script.sh           # static analysis (install: pacman -S shellcheck)

# Time a section
SECONDS=0
# ... expensive work ...
echo "Took ${SECONDS}s"
```

---

## 13. Coprocesses (bash 4.0+)

Coprocesses run a command in the background with two-way communication via file descriptors.

```bash
# Start a coprocess
coproc my_proc { while read -r line; do echo "processed: $line"; done; }

# Write to it
echo "hello" >&"${my_proc[1]}"

# Read from it
read -r result <&"${my_proc[0]}"
echo "$result"    # processed: hello

# Close and wait
exec {my_proc[1]}>&-
wait "$my_proc_PID"
```

**When to use**: interactive communication with a background process (e.g., a database CLI, a REPL). For simple background jobs, use `&` and `wait` instead.

---

> **Remember:** Bash is the lingua franca of Unix scripting. Write it with `set -euo pipefail`,
> quote your variables, and use shellcheck. When portability matters, see the POSIX sh reference.
