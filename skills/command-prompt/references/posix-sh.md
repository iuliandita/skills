# POSIX sh Reference

> Portable shell patterns for `#!/bin/sh` scripts. Everything here works on dash, ash, busybox
> sh, bash in POSIX mode, and zsh in sh-emulation mode. When you need a script that runs
> everywhere - Alpine containers, Debian, macOS, BSDs, embedded systems - this is the reference.

---

## 1. What IS and ISN'T POSIX

### POSIX-guaranteed features

- Variables, parameter expansion (`${var:-default}`, `${var%pattern}`, `${#var}`)
- `[ ]` test command (not `[[ ]]`)
- `$(command)` substitution (backticks work too but nest poorly)
- `$(( arithmetic ))` expansion
- Functions: `name() { body; }`
- Here documents (`<<EOF`)
- Pipes, redirects, `&&`, `||`, `;`
- `for`, `while`, `until`, `case`, `if`
- `trap`, `wait`, `kill`, `exec`
- `set -eu` (but NOT `set -o pipefail`)
- `local` - technically NOT in POSIX, but supported by every modern sh (dash, ash, busybox, mksh). Safe to use.
- `printf` - POSIX-specified and much more predictable than `echo`

### NOT POSIX (bash/zsh-isms to avoid)

| Feature | Why it fails | Portable alternative |
|---------|-------------|---------------------|
| `[[ ]]` | Bash/zsh built-in, not a POSIX command | `[ ]` with proper quoting |
| `(( ))` arithmetic | Bash/zsh extension | `[ "$(( expr ))" -ne 0 ]` or `test` |
| Arrays | Bash 2.0+ / zsh | Positional params (`set - a b c`) or IFS tricks |
| `${var,,}` / `${var^^}` | Bash 4.0+ case conversion | `printf '%s' "$var" \| tr '[:upper:]' '[:lower:]'` |
| `${var:offset:length}` | Bash substring | `expr substr "$var" start length` or `cut` |
| `<<<` here string | Bash/zsh | `printf '%s\n' "$var" \| cmd` |
| `<(cmd)` process sub | Bash/zsh (uses /dev/fd) | Temp files or named pipes |
| `mapfile` / `readarray` | Bash 4.0+ | `while read` loop |
| `source file` | Bash alias for `.` | `. file` |
| `function name { }` | Bash/ksh form | `name() { }` |
| `set -o pipefail` | Bash/zsh | No equivalent - check each stage manually |
| `$RANDOM` | Bash/zsh/ksh | `awk 'BEGIN{srand(); print int(rand()*32768)}'` |
| `BASH_SOURCE` | Bash-only | `$0` (different in sourced files) |
| `declare` / `typeset` | Bash/ksh/zsh | Plain assignment; `local` for function scope |
| `select` | Bash/ksh/zsh | Write a manual menu with `while`/`case` |
| `echo -e` / `echo -n` | Behavior varies by shell and platform | `printf` always |

---

## 2. Script Template

```sh
#!/bin/sh
set -eu

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

log_info()  { printf '[INFO] %s\n' "$1"; }
log_warn()  { printf '[WARN] %s\n' "$1"; }
log_error() { printf '[ERROR] %s\n' "$1" >&2; }

cleanup() {
    rm -f "${tmpfile:-}"
}
trap cleanup EXIT INT TERM

main() {
    log_info "Starting..."
    # Your logic here
    log_info "Done."
}

main "$@"
```

**Differences from the bash template:**
- `#!/bin/sh` not `#!/usr/bin/env bash`
- `set -eu` only (no `pipefail`)
- `$0` instead of `${BASH_SOURCE[0]}`
- `printf` instead of `echo -e` with ANSI colors
- No arrays, no `[[ ]]`, no `local -r`

---

## 3. Parameter Expansion (POSIX Subset)

All of these work in every POSIX sh:

```sh
# Default values
${var:-default}        # use default if var is unset or empty
${var:=default}        # assign default if var is unset or empty
${var:+value}          # use value if var IS set and non-empty
${var:?message}        # error if var is unset or empty

# String length
${#var}                # length of var

# Pattern removal (globs, not regex)
${var#pattern}         # remove shortest prefix match
${var##pattern}        # remove longest prefix match
${var%pattern}         # remove shortest suffix match
${var%%pattern}        # remove longest suffix match
```

### Common uses

```sh
# Basename and dirname
path="/home/user/file.tar.gz"
basename="${path##*/}"         # file.tar.gz
dirname="${path%/*}"           # /home/user
extension="${path##*.}"        # gz
name="${basename%%.*}"         # file

# Strip trailing slash
dir="${dir%/}"

# Check if var is set (POSIX way)
if [ -n "${var+x}" ]; then echo "var is set"; fi
# Note: ${var+x} expands to "x" if var is set (even if empty), nothing if unset
```

### What you CAN'T do in POSIX

```sh
# NO substring extraction - these are bash-isms:
# ${var:0:5}           # use: printf '%.5s' "$var"   or   expr substr "$var" 1 5
# ${var:(-3)}          # use: printf '%s' "$var" | tail -c 3

# NO case conversion - these are bash-isms:
# ${var,,}   ${var^^}  # use: printf '%s' "$var" | tr '[:upper:]' '[:lower:]'

# NO pattern replacement - these are bash-isms:
# ${var/old/new}       # use: printf '%s' "$var" | sed 's/old/new/'
# ${var//old/new}      # use: printf '%s' "$var" | sed 's/old/new/g'
```

---

## 4. Conditionals

### `[ ]` test (POSIX)

```sh
# String comparison
[ "$str" = "hello" ]           # equality (single =, not ==)
[ "$str" != "hello" ]          # inequality
[ -z "$str" ]                  # empty
[ -n "$str" ]                  # non-empty

# Numeric comparison
[ "$a" -eq "$b" ]              # equal
[ "$a" -ne "$b" ]              # not equal
[ "$a" -gt "$b" ]              # greater than
[ "$a" -lt "$b" ]              # less than
[ "$a" -ge "$b" ]              # greater or equal
[ "$a" -le "$b" ]              # less or equal

# File tests
[ -f "$path" ]                 # regular file
[ -d "$path" ]                 # directory
[ -e "$path" ]                 # exists (any type)
[ -r "$path" ]                 # readable
[ -w "$path" ]                 # writable
[ -x "$path" ]                 # executable
[ -s "$path" ]                 # non-empty file
[ -L "$path" ]                 # symlink
[ "$a" -nt "$b" ]             # a newer than b
[ "$a" -ot "$b" ]             # a older than b

# Logical operators (OUTSIDE the brackets)
[ -f "$f" ] && [ -r "$f" ]    # AND
[ -f "$f" ] || [ -d "$f" ]    # OR
[ ! -f "$f" ]                 # NOT (inside is OK)
```

### Critical `[ ]` gotchas

```sh
# ALWAYS quote variables inside [ ]
[ "$var" = "hello" ]           # correct
[ $var = "hello" ]             # BROKEN if var is empty or has spaces

# Use = not == for POSIX
[ "$a" = "$b" ]                # POSIX
[ "$a" == "$b" ]               # bash-ism (works in bash, not in dash)

# -a and -o inside [ ] are deprecated - use && and ||
[ -f "$f" ] && [ -r "$f" ]    # correct
[ -f "$f" -a -r "$f" ]        # deprecated, broken with some values
```

### case statement (powerful and portable)

```sh
case "$input" in
    *.tar.gz|*.tgz)
        tar xzf "$input"
        ;;
    *.zip)
        unzip "$input"
        ;;
    -h|--help)
        usage
        exit 0
        ;;
    -*)
        printf 'Unknown option: %s\n' "$input" >&2
        exit 1
        ;;
    *)
        printf 'Processing: %s\n' "$input"
        ;;
esac
```

---

## 5. Arithmetic

```sh
# $(( )) is the only POSIX arithmetic
result=$(( a + b ))
result=$(( a * b + c ))
result=$(( total / count ))
result=$(( total % batch ))

# Increment
count=$(( count + 1 ))

# Comparison in conditionals
if [ "$(( a > b ))" = 1 ]; then
    printf '%s is greater\n' "$a"
fi

# Or use test with -gt
if [ "$a" -gt "$b" ]; then
    printf '%s is greater\n' "$a"
fi
```

**Not POSIX**: `(( count++ ))`, `let`, `declare -i`. Use `$(( ))` for everything.

---

## 6. No Arrays - Workarounds

POSIX sh has no arrays. Here's how to work around it:

### Positional parameters as a single array

```sh
# Set positional params
set - alpha bravo charlie

# Access
printf 'First: %s\n' "$1"     # alpha
printf 'All: %s\n' "$@"       # alpha bravo charlie (properly quoted)
printf 'Count: %d\n' "$#"     # 3

# Iterate
for item in "$@"; do
    printf '%s\n' "$item"
done

# Shift (removes first element)
shift
printf 'Now first: %s\n' "$1" # bravo

# Append (rebuilds the list)
set - "$@" delta
```

### IFS splitting for simple lists

```sh
# Split a colon-separated string
old_ifs="$IFS"
IFS=:
set - $PATH                   # splits PATH into positional params
IFS="$old_ifs"

for dir in "$@"; do
    printf '%s\n' "$dir"
done
```

### Newline-separated data

```sh
# Store multiline data in a variable
items="alpha
bravo
charlie"

# Iterate (IFS must include newline - it does by default)
printf '%s\n' "$items" | while IFS= read -r item; do
    printf 'Item: %s\n' "$item"
done

# WARNING: the while loop runs in a subshell (pipe). Variables set inside
# won't be visible outside. Use a temp file if you need to collect results.
```

---

## 7. Portable Idioms

### Check if command exists

```sh
# POSIX way (command -v is specified in POSIX.1-2008)
if command -v git >/dev/null 2>&1; then
    printf 'git is available\n'
else
    printf 'git is required\n' >&2
    exit 1
fi

# NOT portable: which, type -P, hash
```

### Temporary files

```sh
# mktemp is not strictly POSIX but is available everywhere that matters
tmpfile=$(mktemp) || exit 1
trap 'rm -f "$tmpfile"' EXIT

# mktemp -d for directories
tmpdir=$(mktemp -d) || exit 1
trap 'rm -rf "$tmpdir"' EXIT
```

### Read a file line by line

```sh
# Preserves leading/trailing whitespace, handles files without trailing newline
while IFS= read -r line || [ -n "$line" ]; do
    printf '%s\n' "$line"
done < file.txt

# The || [ -n "$line" ] handles the last line if it lacks a trailing newline
```

### Safe glob iteration

```sh
# No nullglob in POSIX - must guard against no-match
for f in *.txt; do
    [ -e "$f" ] || continue    # skip if glob didn't match anything
    printf 'Processing: %s\n' "$f"
done
```

### Portable printf (prefer over echo)

```sh
# echo behavior varies: -n, -e, backslash handling all differ by platform
# printf is consistent everywhere
printf '%s\n' "hello"             # with newline
printf '%s' "no newline"          # without newline
printf 'Name: %s, Age: %d\n' "$name" "$age"
printf '%05d\n' 42                # 00042
```

### Boolean checks

```sh
# POSIX has no true booleans - use string comparison
enabled="true"
if [ "$enabled" = "true" ]; then
    printf 'Enabled\n'
fi

# Or use exit codes
is_root() { [ "$(id -u)" = 0 ]; }
if is_root; then printf 'Running as root\n'; fi
```

---

## 8. Which "sh" Am I?

When you write `#!/bin/sh`, the actual shell that runs depends on the OS:

| OS / Distro | `/bin/sh` is | Notes |
|-------------|-------------|-------|
| Debian/Ubuntu | **dash** | Fast, strict POSIX. Catches bash-isms immediately. |
| Alpine/BusyBox | **ash** | Minimal. Missing some features even dash has. |
| Arch Linux | **bash** | `#!/bin/sh` runs bash in POSIX mode. Bash-isms "work" but shouldn't be relied on. |
| macOS | **zsh** (since Catalina) | Runs in sh-emulation mode. Most POSIX scripts work. |
| FreeBSD | **ash** (FreeBSD variant) | Strict POSIX. |
| OpenBSD | **ksh** (pdksh derivative) | Has some ksh extensions. |

**Implication**: if you write `#!/bin/sh` and test on Arch (where sh = bash), your bash-isms
will work locally but break on Debian/Alpine. Always test POSIX scripts with `dash` if available:

```sh
dash ./script.sh    # strict POSIX check
```

---

## 9. Signal Handling

```sh
# Trap syntax (POSIX)
trap 'cleanup' EXIT           # runs on normal exit and errexit
trap 'printf "Interrupted\n" >&2; exit 130' INT
trap 'printf "Terminated\n" >&2; exit 143' TERM
trap '' HUP                    # ignore SIGHUP

# Reset a trap
trap - INT                     # restore default INT handling

# List current traps
trap                           # prints all active traps
```

### Cleanup pattern

```sh
cleanup() {
    # Guard against double-cleanup
    trap - EXIT INT TERM
    rm -f "${tmpfile:-}"
    rm -rf "${tmpdir:-}"
    # Kill background jobs if any
    kill 0 2>/dev/null || true
}
trap cleanup EXIT INT TERM
```

---

## 10. Common Mistakes

### Using echo instead of printf

```sh
# BAD: echo behavior varies by platform
echo -n "no newline"           # -n not POSIX (dash: works, some sh: prints "-n")
echo -e "tab\there"            # -e not POSIX (some sh: prints "-e")
echo "user input: $var"        # if var starts with -n or -e, behavior is undefined

# GOOD: printf is consistent
printf '%s' "no newline"
printf 'tab\there\n'
printf 'user input: %s\n' "$var"
```

### Unquoted variables

```sh
# BAD: breaks on filenames with spaces, or empty variables
for f in $files; do ...        # word splitting
[ -f $path ]                   # breaks if path is empty or has spaces

# GOOD: always quote
for f in $files; do ...        # still bad - $files isn't an array
[ -f "$path" ]                 # safe
```

### Using == in [ ]

```sh
# BAD: == is not POSIX
[ "$a" == "$b" ]               # works in bash, fails in dash

# GOOD: use single =
[ "$a" = "$b" ]
```

### Relying on pipefail

```sh
# BAD: pipefail doesn't exist in POSIX
set -o pipefail                # syntax error in dash

# GOOD: check exit status of pipe stages manually, or restructure
# Instead of:  cmd1 | cmd2 | cmd3
# Use temp files if you need to check each stage:
cmd1 > "$tmpfile" || exit 1
cmd2 < "$tmpfile" | cmd3
```

---

> **Remember:** POSIX sh is the lowest common denominator. It's not pleasant, but it runs
> everywhere. When in doubt: quote variables, use printf, avoid bash-isms, test with dash.
