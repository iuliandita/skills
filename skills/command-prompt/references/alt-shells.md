# Alternative Shells Reference

> Syntax overviews and gotchas for Fish, tcsh/csh, Nushell, and other non-mainstream shells.
> These are not daily drivers for most users, but you'll encounter them in specific contexts.

---

## Fish (4.6)

Fish is a modern, user-friendly shell that intentionally breaks POSIX compatibility for a
better interactive experience. You'll encounter it when users have it as their login shell or
when writing fish-specific config.

**When you'll see it**: user's `$SHELL` is `/usr/bin/fish`, files ending in `.fish`,
`~/.config/fish/config.fish`.

### Key differences from bash/zsh

| Concept | Bash/Zsh | Fish |
|---------|----------|------|
| Variables | `export VAR=value` | `set -gx VAR value` |
| Command sub | `$(cmd)` | `(cmd)` |
| Conditionals | `if [[ ... ]]; then ... fi` | `if test ...; ... end` |
| Loops | `for x in ...; do ... done` | `for x in ...; ... end` |
| Functions | `func() { ... }` | `function func; ... end` |
| Stderr redirect | `2>/dev/null` | `2>/dev/null` (same) |
| Logical AND | `cmd1 && cmd2` | `cmd1; and cmd2` or `&&` (3.0+) |
| Logical OR | `cmd1 \|\| cmd2` | `cmd1; or cmd2` or `\|\|` (3.0+) |
| Exit status | `$?` | `$status` |
| Last argument | `$_` or `!$` | `$argv[-1]` (in functions) |
| Array index | 0-based (bash) / 1-based (zsh) | **1-based** |
| String ops | `${var%%pattern}` | `string match`, `string replace` |
| Process sub | `<(cmd)` | `(cmd \| psub)` |
| Here docs | `<<EOF ... EOF` | **Not supported** - use `printf` or `echo` |
| History expansion | `!!`, `!$` | **Not supported** (use `Alt+.` for last arg) |

### Variables

```fish
# Local (current scope)
set name "world"

# Global (all functions in this session)
set -g name "world"

# Exported (visible to child processes, like export)
set -gx PATH $PATH /usr/local/bin

# Universal (persisted across sessions - fish-unique feature)
set -U fish_greeting ""        # disable greeting permanently

# Erase
set -e name

# Lists (fish's version of arrays, 1-indexed)
set colors red green blue
echo $colors[1]                # red
echo $colors[-1]               # blue
echo (count $colors)           # 3
set -a colors yellow           # append
```

### Conditionals and loops

```fish
# if/else
if test -f "$path"
    echo "file exists"
else if test -d "$path"
    echo "directory exists"
else
    echo "not found"
end

# test is the fish way (no [[ ]])
if test "$str" = "hello"
    echo "match"
end

# String matching
if string match -q "*.tar.gz" "$file"
    echo "tarball"
end

# Switch (like case)
switch $input
    case "*.tar.gz" "*.tgz"
        tar xzf $input
    case "*.zip"
        unzip $input
    case '*'
        echo "unknown format"
end

# For loop
for f in *.txt
    echo $f
end

# While
while read -l line
    echo $line
end < file.txt

# Count-based loop
for i in (seq 1 10)
    echo $i
end
```

### Functions

```fish
# Define
function greet
    echo "Hello, $argv[1]"
end

# With description (shows in `functions` and completions)
function greet -d "Greet someone by name"
    echo "Hello, $argv[1]"
end

# Event handlers
function on_exit --on-event fish_exit
    echo "Goodbye"
end

# $argv is the arguments list (like $@ in bash, but 1-indexed)
function example
    echo "Got $argv"
    echo "Count: "(count $argv)
    echo "First: $argv[1]"
end

# Save a function permanently
funcsave greet    # writes to ~/.config/fish/functions/greet.fish
```

### Completions

```fish
# Fish has the best completion system - mostly auto-generated from man pages
# Custom completions go in ~/.config/fish/completions/mytool.fish

complete -c mytool -s v -l verbose -d "Verbose output"
complete -c mytool -s f -l file -r -F -d "Input file"
complete -c mytool -l format -x -a "json yaml toml" -d "Output format"

# -s = short flag, -l = long flag
# -r = requires argument, -f = no argument
# -x = exclusive (don't complete files), -F = force file completion
# -a = list of possible arguments
```

### Config

```fish
# Config file: ~/.config/fish/config.fish
# NO .fishrc - don't create one

# Functions: ~/.config/fish/functions/*.fish (one file per function)
# Completions: ~/.config/fish/completions/*.fish

# Fish doesn't read .profile, .bashrc, etc. Environment variables from
# login must be set in config.fish or via `set -Ux` (universal export).
```

### Fish 4.6 additions (March 2026)

- **`|&` syntax** - bash-compat pipe-stderr shorthand now supported (in addition to `2>&1 |`)
- **systemd env vars** - `SHELL_PROMPT_PREFIX`, `SHELL_PROMPT_SUFFIX`, `SHELL_WELCOME` are
  automatically applied to prompts and greeting. Set by systemd's `run0`, for example.
- **Emoji width default changed** from 1 to 2. If terminal alignment breaks on older systems,
  set `$fish_emoji_width` to 1.
- `set_color` can now individually disable italics, reverse, strikethrough, and underline
- `fish_indent` preserves comments and newlines before brace blocks

### String command (replaces bash parameter expansion)

```fish
# The `string` builtin is fish's Swiss army knife for text manipulation
string length "hello"                        # 5
string sub -s 1 -l 3 "hello"               # hel (1-indexed, length 3)
string lower "HELLO"                         # hello
string upper "hello"                         # HELLO
string match "*.txt" file.txt               # file.txt (glob match)
string match -r '^v(\d+)' "v42"            # v42\n42 (regex with groups)
string replace "old" "new" "old text"       # new text
string replace -a "l" "L" "hello"           # heLLo (all matches)
string split ":" "a:b:c"                    # a\nb\nc
string join "," a b c                        # a,b,c
string trim "  hello  "                      # hello
```

---

## Tcsh / Csh (6.24)

The C shell and its descendant tcsh. You'll encounter these on FreeBSD systems, legacy Unix
servers, and some academic environments. **Never write new scripts in csh/tcsh** - use it only
for interactive commands on systems where it's the default.

**When you'll see it**: FreeBSD default shell (`/bin/csh` or `/bin/tcsh`), OPNsense/pfSense
SSH sessions, legacy Solaris/HP-UX systems.

### Key syntax differences

| Concept | Bash/Zsh | Tcsh/Csh |
|---------|----------|----------|
| Variables | `VAR=value` | `set var = value` (local) / `setenv VAR value` (env) |
| If | `if [[ ... ]]; then ... fi` | `if ( expr ) then ... endif` |
| For loop | `for x in ...; do ... done` | `foreach x ( ... ) ... end` |
| While | `while ...; do ... done` | `while ( expr ) ... end` |
| Exit status | `$?` | `$status` (same as fish) |
| Background | `cmd &` | `cmd &` (same) |
| Stderr redirect | `2>/dev/null` | **Cannot redirect stderr separately** in csh. Use: `(cmd > /dev/null) >& /dev/null` |
| Pipe stderr | `cmd 2>&1 \| ...` | `cmd \|& ...` |
| Command sub | `$(cmd)` | `` `cmd` `` (backticks only) |
| Alias | `alias name='cmd'` | `alias name 'cmd'` or `alias name cmd` |

### Quick survival guide

```tcsh
# Set a variable
set name = "world"
setenv PATH "${PATH}:/usr/local/bin"

# If/else
if ( -f /etc/rc.conf ) then
    echo "FreeBSD"
else
    echo "Not FreeBSD"
endif

# Foreach
foreach f ( *.conf )
    echo $f
end

# While
set i = 1
while ( $i <= 10 )
    echo $i
    @ i++
end

# Arithmetic (@ is csh's let)
@ result = 5 + 3
@ count++

# Alias
alias ll 'ls -la'
```

### Why not to script in csh

The paper "Csh Programming Considered Harmful" (Tom Christiansen, 1995) remains valid. Key issues:
- No functions (only aliases)
- No stderr redirect without workarounds
- Broken quoting (can't nest quotes properly)
- No `set -e` equivalent
- Variable expansion is inconsistent
- Error handling is nearly impossible

**Rule**: use tcsh interactively on FreeBSD when you must. For scripts on those systems, install
bash (`pkg install bash`) or write POSIX sh.

---

## Nushell (0.111)

Nushell is a modern shell that treats data as structured tables instead of text streams. It's
gaining traction among developers who work with JSON/YAML/CSV regularly.

**When you'll see it**: user mentions "nu", files ending in `.nu`, pipelines that manipulate
structured data.

### Core concept: structured pipelines

```nu
# Everything is a table or record, not text
ls | where size > 1mb | sort-by modified

# Commands return structured data
sys host | get hostname

# HTTP responses are parsed automatically
http get https://api.github.com/repos/nushell/nushell | get stargazers_count
```

### Syntax overview

```nu
# Variables (immutable by default)
let name = "world"
mut count = 0
$count += 1

# Strings
let greeting = $"Hello, ($name)"    # string interpolation uses ()
let raw = 'no $interpolation'       # single quotes are literal

# Conditionals
if $x > 10 {
    print "big"
} else {
    print "small"
}

# Loops
for x in [1 2 3] {
    print $x
}

# Functions (called "custom commands")
def greet [name: string] {
    $"Hello, ($name)"
}

# Types are first-class
let nums: list<int> = [1 2 3]
```

### Data manipulation (nushell's strength)

```nu
# Filter and transform
open data.csv | where age > 30 | select name age

# Group and aggregate
open sales.csv | group-by region | transpose key value | each { |row|
    {region: $row.key, total: ($row.value | math sum)}
}

# JSON manipulation
open config.json | update settings.debug true | save config.json

# Format conversion
open data.csv | to json
open data.json | to yaml
```

### Key gotchas

- **Not POSIX.** Can't run bash/sh scripts directly - use `^bash script.sh`.
- **Pipelines are typed.** `ls | grep pattern` doesn't work - use `ls | where name =~ pattern`.
- **External commands** need `^` prefix if they conflict with builtins: `^git status`.
- **Environment variables**: `$env.PATH` not `$PATH`. Set with `$env.VAR = "value"`.
- **No background jobs** in the traditional sense. Use `par-each` for parallelism.
- **Config**: `$nu.config-path` shows the config file location (usually `~/.config/nushell/config.nu`).

---

## Brief: Other Shells

### Elvish (0.22)

A shell with a real programming language built in. Typed values, namespaces, exception handling.

```elvish
# Variables
var name = "world"

# Functions
fn greet {|name| echo "Hello, "$name }

# Pipelines work with structured data (like nushell)
ls | each {|f| echo $f[name] }

# Exception handling
try {
    risky-command
} catch e {
    echo "Failed: "$e[msg]
}
```

**Status**: pre-1.0, small community, but stable enough for daily use. Good for people who want a
shell that's also a real programming language.

### Oils (OSH + YSH, 0.37)

OSH is a bash-compatible shell (runs bash scripts correctly). YSH is the "upgrade path" - a
new language that fixes bash's worst problems while keeping the shell paradigm. 8 releases
shipped in the 6 months before September 2025, so the project is moving fast.

```ysh
# YSH - bash-like but with real data types
var name = "world"
var items = ['one', 'two', 'three']

# JSON-aware
json read :data < file.json
echo $[data.key]

# Expression language
if (len(items) > 2) {
    echo "many items"
}
```

OSH can replace `/bin/sh`, `/bin/ash`, and `/bin/bash` on a system - tested via the Alpine
Linux package build system (`regtest/aports`). Useful for validating that "bash-compatible"
actually means compatible.

**Status**: pre-1.0, actively developed. OSH is usable as a bash replacement for testing
scripts. YSH is maturing but still experimental.

### Dash (0.5.13)

Not really an "alternative" shell - dash is the Debian Almquist Shell, the `/bin/sh` on Debian
and Ubuntu. It's intentionally minimal and POSIX-strict. You don't write "dash scripts" - you
write POSIX sh scripts and dash runs them.

**Use the POSIX sh reference for dash.**

---

> **Rule of thumb:** bash and zsh handle 99% of shell needs. Fish is for people who prioritize
> interactive UX over POSIX compatibility. Nushell is for data-oriented workflows. Tcsh is legacy.
> Everything else is niche.
