# Zsh Reference

> Patterns and gotchas for Zsh 5.9/5.10 on Linux and macOS. Focuses on where Zsh diverges
> from Bash -- the stuff that silently breaks.

---

## Section Routing

Not every task needs all 685 lines. Use this routing:

| Task | What to read |
|------|-------------|
| Simple one-liner (no glob qualifiers, no arrays) | Section 11 gotchas table only |
| Writing a new zsh script | Section 11 gotchas + section 1 (globbing) + section 10 (template) |
| Porting bash to zsh | Section 11 gotchas + full compat matrix |
| Glob qualifiers (file age, size, type, sorting) | Section 1 -- qualifier cheat sheet is essential |
| Debugging a zsh issue | Section 11 gotchas, then: globbing=1, arrays=2, expansion=3, quoting=4, portability=5 |
| Editing .zshrc / startup | Section 6 (load order) + 7 (prompt, options, hooks) |
| Completion issues | Section 8 + 9. Check: (1) `compinit` called? (2) after `fpath` mods? (3) file named `_commandname`? (4) stale cache? (`rm ~/.zcompdump*`) |
| Zsh-only features | Section 12 (named dirs, assoc arrays, suffix aliases) |
| Zsh 5.10 features | Section 13 (non-forking `${ }`, namerefs, SRANDOM) |

---

## Verification Checklist

Before returning any zsh script or .zshrc edit:

- [ ] Shebang is `#!/usr/bin/env zsh` (not `#!/bin/bash`, not `#!/bin/sh`)
- [ ] `set -euo pipefail` present for scripts (or `setopt ERR_EXIT NO_UNSET PIPE_FAIL`)
- [ ] Arrays are 1-indexed (not 0-indexed) -- every loop, slice, index
- [ ] Globs use `(N)` qualifier where empty results are acceptable
- [ ] File-filtering globs use type qualifiers: `(.)` files, `(/)` dirs, `(@)` symlinks
- [ ] No bash-isms: `${!var}` -> `${(P)var}`, `read -a` -> `read -A`, `BASH_SOURCE` -> `${0:A:h}`
- [ ] No `mapfile`/`readarray` -- use `arr=("${(@f)$(command)}")` to read lines into array
- [ ] `!` in double-quoted strings is escaped (`\!`) or `NO_BANG_HIST` is set
- [ ] Word splitting: `for f in $var` iterates ONCE in zsh. Use `${=var}` to force split, or use an array
- [ ] `print` used instead of `echo -e` for escape sequences (`print -P` for prompt escapes)
- [ ] If porting `BASH_REMATCH`: even with `setopt BASH_REMATCH`, the array is **1-indexed** in zsh

---

## 1. Globbing Differences (The Big One)

Zsh globbing is stricter and more powerful than bash. **A failed glob is a fatal error by default.**

### No match = error

```zsh
# Bash: passes the literal '*.foo' if nothing matches
# Zsh: throws "no matches found: *.foo" and ABORTS

ls *.nonexistent    # zsh: no matches found

# Fix: use (N) null glob qualifier
ls *.nonexistent(N)    # returns nothing silently

# Or set globally (often in .zshrc)
setopt NULL_GLOB
```

### Extended globbing is built-in (no `shopt -s extglob`)

```zsh
# Recursive glob (bash needs shopt -s globstar)
ls **/*.js              # just works in zsh

# Qualifiers -- zsh-only power
ls *(.)                 # files only
ls *(/)                 # directories only
ls *(.m-1)              # files modified in last day
ls *(.L+1M)             # files larger than 1MB
ls *(.om[1,5])          # 5 most recently modified files
ls **/*(.D)             # include dotfiles in recursive glob
```

### Glob qualifiers cheat sheet

| Qualifier | Meaning |
|-----------|---------|
| `(.)` | Regular files only |
| `(/)` | Directories only |
| `(@)` | Symlinks only |
| `(*)` | Executable files only |
| `(N)` | Null glob (no error if empty) |
| `(D)` | Include dotfiles |
| `(om)` | Order by modification time |
| `(oL)` | Order by size |
| `(OL)` | Reverse order by size |
| `(m-N)` | Modified in last N days |
| `(L+NK)` | Larger than N kilobytes |
| `([1,N])` | First N results |

---

## 2. Array Handling (Silently Different)

**Zsh arrays are 1-indexed. Bash arrays are 0-indexed.** This will bite you.

```zsh
arr=(one two three)

# Zsh
echo $arr[1]        # "one"
echo $arr[3]        # "three"
echo ${#arr}        # 3 (length)

# Bash equivalent would be ${arr[0]} for "one"
```

### Array operations

```zsh
arr=(alpha bravo charlie)

# Append
arr+=(delta)

# Slice (1-indexed, inclusive)
echo ${arr[2,3]}       # bravo charlie

# Iterate
for item in "${arr[@]}"; do echo "$item"; done

# Contains check
if (( ${arr[(Ie)bravo]} )); then echo "found"; fi

# Remove by value
arr=("${(@)arr:#bravo}")    # removes "bravo"

# Split string to array
str="a:b:c"
arr=("${(@s/:/)str}")       # splits on ":"
```

### Word splitting gotcha

```zsh
# Bash: unquoted $var splits on whitespace
# Zsh: unquoted $var does NOT split by default

files="one two three"

# Bash: for f in $files  -> iterates 3 times
# Zsh:  for f in $files  -> iterates 1 time (whole string)

# Zsh fix: use parameter expansion flag
for f in ${=files}; do echo "$f"; done    # (=) forces splitting

# Or use an actual array (preferred)
files=(one two three)
```

---

## 3. Parameter Expansion Differences

### String operations

```zsh
str="Hello World"

# Length
echo ${#str}               # 11

# Substring (1-indexed!)
echo ${str[1,5]}           # Hello
echo ${str[7,-1]}          # World

# Replacement
echo ${str/World/Zsh}      # Hello Zsh
echo ${str:l}              # hello world (lowercase -- zsh-only)
echo ${str:u}              # HELLO WORLD (uppercase -- zsh-only)
```

### Bash vs Zsh expansion

| Operation | Bash | Zsh |
|-----------|------|-----|
| Lowercase | `${var,,}` | `${var:l}` |
| Uppercase | `${var^^}` | `${var:u}` |
| Substring | `${var:offset:length}` | `${var[start,end]}` (1-indexed) |
| Split to array | `IFS=: read -ra arr <<< "$var"` | `arr=("${(@s/:/)var}")` |
| Array length | `${#arr[@]}` | `${#arr}` |
| First element | `${arr[0]}` | `${arr[1]}` |

> **Tip:** Bash-style `${var,,}` and `${var^^}` also work in modern zsh (5.9+), but `${var:l}` and `${var:u}` are idiomatic.

---

## 4. Escape / Quoting Issues

### History expansion in double quotes

```zsh
# The ! character is special inside double quotes in zsh (history expansion)
echo "Hello!"        # zsh: event not found (or unexpected expansion)

# Fixes:
echo "Hello\!"       # escape it
echo 'Hello!'        # single quotes
setopt NO_BANG_HIST  # disable globally
```

### Curly braces in commands

```zsh
# Brace expansion happens even when you don't want it
echo {foo}           # foo (fine)
echo {1..5}          # 1 2 3 4 5 (expansion!)

# When passing literal braces to commands (e.g., curl, jq):
curl -d '{"key":"val"}' URL      # single-quote the JSON
# Or escape:
echo \{not,expanded\}
```

### The `#` comment gotcha

```zsh
# In interactive zsh, # is NOT a comment by default
echo foo # bar       # prints "foo # bar" in interactive mode

# Fix (usually in .zshrc):
setopt INTERACTIVE_COMMENTS
```

### ANSI-C quoting ($'...')

```zsh
# Neither bash nor zsh allow escaping inside single quotes
# Both support $'...' (ANSI-C quoting) for escape sequences
echo $'it\'s working'        # it's working
echo $'line1\nline2'         # actual newline
echo $'tab\there'            # actual tab
```

---

## 5. Script Portability

### Shebang matters

```zsh
#!/usr/bin/env zsh
# Don't use #!/bin/bash for zsh scripts (obvious but common)
# Don't use #!/bin/sh -- zsh in sh-emulation mode loses features

set -euo pipefail    # works in zsh too, use it
```

### Zsh-specific `set` options

```zsh
setopt ERR_EXIT          # same as set -e
setopt NO_UNSET          # same as set -u
setopt PIPE_FAIL         # same as set -o pipefail
setopt WARN_CREATE_GLOBAL  # warn when function creates global var (use typeset -g for intentional globals)
setopt LOCAL_OPTIONS     # options in function are local to it
```

### Script directory (different from bash)

```zsh
# Bash:
# SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Zsh:
SCRIPT_DIR="${0:A:h}"
# :A = absolute path (resolves symlinks)
# :h = head (dirname)
```

### BASH_SOURCE equivalent

```zsh
# Zsh has no BASH_SOURCE -- use these instead:
echo ${(%):-%x}          # current script path
echo ${(%):-%N}          # current function/script name
echo $0                  # in scripts: script path; in functions: function name
echo ${funcstack[@]}     # full function call stack
```

### Process substitution difference

```zsh
# Bash has <(...) which creates a FIFO (named pipe)
# Zsh has BOTH <(...) AND =(...) which creates a temp file

# =(...) is unique to zsh -- creates an actual temp file, not a FIFO
# Useful when the command needs to seek (read the input more than once)
diff =(curl -s url1) =(curl -s url2)    # compare two URLs
wc -l =(grep pattern file)              # wc can't seek on a FIFO in some cases

# <(...) still works for streaming (same as bash)
while read -r line; do echo "$line"; done < <(some_command)
```

---

## 6. Startup File Load Order

The order matters. Putting things in the wrong file causes subtle issues.

```
# Login shell (SSH, initial terminal):
.zshenv -> .zprofile -> .zshrc -> .zlogin

# Interactive non-login (new tab, subshell):
.zshenv -> .zshrc

# Script (non-interactive):
.zshenv only

# Logout:
.zlogout
```

| File | Use for | Runs when |
|------|---------|-----------|
| `.zshenv` | PATH, EDITOR, LANG, env vars that scripts need | Always -- every zsh invocation |
| `.zprofile` | Login-only setup (rarely needed, use `.zshrc` instead) | Login shells only |
| `.zshrc` | Aliases, functions, completions, prompt, history, setopt | Interactive shells |
| `.zlogin` | Commands after `.zshrc` in login shells (rare) | Login shells, after .zshrc |
| `.zlogout` | Cleanup on logout | Login shell exit |

**Common mistakes:**
- Putting PATH in `.zshrc` instead of `.zshenv` -- scripts and non-interactive shells won't see it
- Putting interactive stuff (aliases, prompt) in `.zshenv` -- runs in every subshell and script, causing noise
- Using both `.zprofile` and `.zshrc` for the same thing -- pick one

---

## 7. Prompt / .zshrc Patterns

### Prompt variables

```zsh
# Zsh uses %codes, not \codes like bash
# Set in .zshrc:
PROMPT='%F{green}%n@%m%f:%F{blue}%~%f$ '

# Right-side prompt (zsh-only -- disappears when typing reaches it)
RPROMPT='%F{242}%T%f'          # gray timestamp on the right
RPROMPT='%(?.%F{green}ok%f.%F{red}%?%f)'  # green "ok" or red exit code

# Common codes:
# %n = username
# %m = hostname
# %~ = cwd with ~ abbreviation
# %F{color}...%f = foreground color
# %B...%b = bold
# %T = time (HH:MM)
# %? = last exit code
```

### precmd / preexec hooks

```zsh
# precmd: runs before each prompt (like bash PROMPT_COMMAND)
precmd() {
    # Update terminal title with current directory
    print -Pn "\e]0;%~\a"
}

# preexec: runs before each command (receives the command as $1)
preexec() {
    # Update terminal title with running command
    print -Pn "\e]0;$1\a"
}

# Multiple hooks (array form -- won't clobber existing hooks)
autoload -Uz add-zsh-hook
add-zsh-hook precmd my_precmd_function
add-zsh-hook preexec my_preexec_function
```

### Useful .zshrc options

```zsh
# History
HISTFILE=~/.zsh_history
HISTSIZE=100000
SAVEHIST=100000
setopt SHARE_HISTORY          # share across sessions
setopt HIST_IGNORE_ALL_DUPS   # no duplicate entries
setopt HIST_IGNORE_SPACE      # commands starting with space are private

# Directory navigation
setopt AUTO_CD                # type dir name to cd into it
setopt AUTO_PUSHD             # cd pushes onto dir stack
setopt PUSHD_IGNORE_DUPS      # no dupes on dir stack
setopt CDABLE_VARS            # cd into named variables

# Correction
setopt CORRECT                # suggest corrections for commands
setopt CORRECT_ALL            # suggest corrections for arguments too

# Completion
autoload -Uz compinit && compinit
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Z}'   # case-insensitive
zstyle ':completion:*' menu select                      # arrow-key menu
```

---

## 8. Completion System

Zsh's completion is its single biggest advantage over bash. Beyond basic `compinit`:

### Custom completion with `_arguments`

```zsh
# Completion for a custom script/command
_my_tool() {
    _arguments \
        '-v[verbose output]' \
        '-o[output file]:filename:_files' \
        '--format[output format]:format:(json yaml toml)' \
        '*:input file:_files -g "*.txt"'
}
compdef _my_tool my_tool
```

### Useful zstyle patterns

```zsh
# Group completions by type
zstyle ':completion:*' group-name ''
zstyle ':completion:*:descriptions' format '%F{yellow}-- %d --%f'

# Complete . and .. directories
zstyle ':completion:*' special-dirs true

# Cache completions for speed (important for large projects)
zstyle ':completion:*' use-cache on
zstyle ':completion:*' cache-path ~/.zsh/cache

# Kill menu with process names
zstyle ':completion:*:*:kill:*:processes' list-colors '=(#b) #([0-9]#)*=0=01;31'

# SSH hostname completion from config
zstyle ':completion:*:ssh:*' hosts $(awk '/^Host / && !/\*/{print $2}' ~/.ssh/config 2>/dev/null)
```

### Debugging completions

```zsh
# _complete_help: on a partial command, press Ctrl+x then h
# Shows which completer is active and what tags are being tried

# Verbose completion debugging
zstyle ':completion:*' verbose yes
```

### Autoloading completions

```zsh
# Add custom completion directory to fpath
fpath=(~/.zsh/completions $fpath)

# Write a completion file: ~/.zsh/completions/_mytool
# The filename MUST start with _ and match the command name

# Then re-run compinit or start a new shell
```

---

## 9. Autoloading Functions and FPATH

Zsh's idiomatic way to organize functions. Functions are loaded on first call, not at shell startup.

```zsh
# Add function directory to fpath
fpath=(~/.zsh/functions $fpath)

# Create a function file: ~/.zsh/functions/greet
# File contents (NO function wrapper needed):
#   echo "Hello, $1!"

# Declare it as autoloaded
autoload -Uz greet

# Now `greet World` works -- file is loaded on first call
```

**Key points:**
- The file name IS the function name (no `function greet() { ... }` wrapper in the file)
- `-U` suppresses alias expansion during loading
- `-z` forces zsh-style autoloading (not ksh-style)
- Functions aren't loaded until first call -- no startup cost
- `$fpath` is the search path for autoloaded functions (like `$PATH` for commands)

```zsh
# Check if a function is autoloaded
whence -v greet         # "greet is a shell function from /path/to/greet"

# Force reload after editing
unfunction greet && autoload -Uz greet
```

---

## 10. Zsh Script Template

```zsh
#!/usr/bin/env zsh
set -euo pipefail

SCRIPT_DIR="${0:A:h}"

log_info()  { print -P "%F{green}[INFO]%f $1" }
log_warn()  { print -P "%F{yellow}[WARN]%f $1" }
log_error() { print -P "%F{red}[ERROR]%f $1" >&2 }

cleanup() {
    # Cleanup logic here
}
trap cleanup EXIT INT TERM

main() {
    log_info "Starting..."
    # Your logic here
    log_info "Done!"
}

main "$@"
```

---

## 11. Key Gotchas Summary (Bash -> Zsh)

| Gotcha | Bash | Zsh | Fix |
|--------|------|-----|-----|
| Failed glob | passes literal | **error** | `(N)` qualifier or `setopt NULL_GLOB` |
| Array index | 0-based | **1-based** | adjust indices |
| Word splitting | splits unquoted `$var` | **no split** | use `${=var}` to force split |
| `!` in double quotes | literal | **history expansion** | `\!` or `setopt NO_BANG_HIST` |
| `#` in interactive | comment | **literal** | `setopt INTERACTIVE_COMMENTS` |
| `BASH_SOURCE[0]` | works | **undefined** | use `${0:A:h}` or `${(%):-%x}` |
| `read -a` | splits to array | **syntax error** | use `read -A` in zsh |
| `echo -e` | interprets escapes | **may not** | use `print` or `print -P` |
| `select` builtin | menu from list | works but prompts differ | test interactively |
| `[[ =~ ]]` regex | `BASH_REMATCH` | `MATCH` / `match` | or `setopt BASH_REMATCH` |
| `local -a arr` | works | works | same syntax |
| `${!var}` indirect | works | **error** | use `${(P)var}` |
| `<(...)` process sub | FIFO only | FIFO + `=(...)` temp file | use `=(...)` when seeking needed |

---

## 12. Zsh-Only Power Features

### Named directories

```zsh
hash -d proj=~/projects
cd ~proj                    # jumps to ~/projects
```

### Associative arrays

```zsh
typeset -A config
config=(
    host   "localhost"
    port   "8080"
    debug  "true"
)
echo ${config[host]}        # localhost
echo ${(k)config}           # keys: host port debug
echo ${(v)config}           # values: localhost 8080 true
```

### Anonymous functions

```zsh
() {
    local tmp="scoped"
    echo "this runs immediately, $tmp"
}
# $tmp is not leaked
```

### Suffix aliases

```zsh
alias -s log='tail -f'
alias -s json='jq .'
alias -s md='bat'

# Now just type the filename:
# ./app.log     -> tail -f ./app.log
# data.json     -> jq . data.json
```

### Global aliases

```zsh
alias -g G='| grep'
alias -g L='| less'
alias -g H='| head -20'
alias -g C='| wc -l'

ls -la G ".js"      # expands to: ls -la | grep ".js"
```

---

## 13. Zsh 5.10 Features

> **Note**: macOS Tahoe still ships zsh 5.9. These features are only available if you install
> zsh via Homebrew or are on Linux with zsh 5.10+.

### Non-forking command substitution

The biggest performance win in zsh 5.10. Runs in-process instead of spawning a subshell:

```zsh
# Old (forks a subshell):
result=$(some_function)

# New (runs in-process, much faster):
result=${ some_function }       # note the spaces inside braces
result=${| REPLY=value }        # assign to REPLY for return value
```

Use for: hot loops, frequently-called functions, startup scripts. Especially impactful in prompt rendering and completion functions.

**Gotcha**: `${ }` (non-forking) vs `$()` (forking) -- the space after `{` is required.

### Named references (nameref)

Similar to Bash 4.3+ namerefs. Requires `zsh/ksh93` module:

```zsh
zmodload zsh/ksh93
typeset -n ref=myvar
myvar="hello"
echo $ref  # prints "hello"
```

### SRANDOM

Cryptographic random number via `zsh/random` module:

```zsh
zmodload zsh/random
echo $SRANDOM  # 32-bit random from OS entropy
```

### ERR_EXIT / ERR_RETURN refinements

Functions or anonymous functions prefixed with `!` never trigger ERR_EXIT/ERR_RETURN:

```zsh
set -e
! { false; echo "this still runs" }  # ! prefix bypasses ERR_EXIT
```

**Gotcha for existing scripts**: behavior change from 5.9. Scripts relying on `set -e` catching errors inside `!`-prefixed blocks will silently stop catching.

### Other notable additions

- `time` keyword now works on builtins and assignments
- Array syntax `array=([index]=value)` for cross-shell compatibility
- `zparseopts` learned `-v` (verbose) and `-G` (gnu-style) options
- pcre2 support in `zsh/pcre` module
- Monotonic time used internally (immune to clock adjustments)

---

## 14. macOS-Specific Notes

- macOS Tahoe (26.x) still ships zsh 5.9. Zsh 5.10 features (non-forking `${ }`, namerefs) are not available unless you install zsh via Homebrew.
- `/etc/zshrc` runs `path_helper` which reorders `$PATH` -- putting `/usr/bin` before Homebrew paths. Fix: set PATH in `.zshenv` (runs before `/etc/zshrc` in non-login shells) or `.zprofile` (runs after, overrides it for login shells).
- BSD coreutils differ from GNU: `sed -i ''` (not `sed -i`), `stat -f %m` (not `stat -c %Y`), `date` flags differ. When writing portable scripts, check which `coreutils` variant is available.

---

> **Remember:** Zsh is almost-but-not-quite bash. The silent differences (globbing, arrays, word
> splitting) are the dangerous ones. When in doubt, test interactively before scripting.
