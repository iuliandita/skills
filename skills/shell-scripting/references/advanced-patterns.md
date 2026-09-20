# Advanced Shell Patterns

Read this reference for portable syntax, cleanup or signal handling, interactive job/process
management, or a Zsh completion. Read the shell-specific reference first when a feature differs
between Bash, Zsh, POSIX sh, or Fish.

## Cross-shell comparison

| Feature | POSIX sh | Bash | Zsh | Fish |
|---|---|---|---|---|
| Arrays | no (use `$@`) | 0-indexed | 1-indexed | lists (1-indexed) |
| Associative arrays | no | `declare -A` (4.0+) | `typeset -A` | no |
| `**/` glob | no | `shopt -s globstar` | built-in | built-in |
| Failed glob | literal | literal | error | no match |
| `[[ ]]` | no | yes | yes | no (`test`) |
| Process substitution | no | `<()` | `<()` and `=()` | `(command | psub)` |
| Unquoted variable splitting | yes | yes | no | no |
| Arithmetic | `$(( ))` | `$(( ))`, `(( ))` | `$(( ))`, `(( ))` | `math` |
| Completion | none | bash-completion | compsys | built-in |
| Script safety | `set -eu` | `set -euo pipefail` | `set -euo pipefail` | explicit status checks |

Use `#!/bin/sh` for POSIX scripts, `#!/usr/bin/env bash` for Bash, and
`#!/usr/bin/env zsh` for Zsh. Fish syntax is not POSIX syntax.

## Portable syntax and safety

These examples work in sh, Bash, and Zsh unless marked otherwise. Fish requires its own syntax.

| Pattern | Effect |
|---|---|
| `cmd1 | cmd2` | Pipe stdout to stdin |
| `cmd > file`, `cmd >> file`, `cmd 2> file` | Overwrite, append, or redirect stderr |
| `cmd 2>&1` | Redirect stderr to stdout (POSIX) |
| `cmd <<'EOF'` | Literal here-document; no expansion |
| `cmd <<< "string"` | Here string (Bash/Zsh, not POSIX) |
| `cmd1 && cmd2` / `cmd1 || cmd2` | Conditional chaining |
| `cmd1 ; cmd2` | Sequential execution regardless of status |

Do not use `cmd1 && cmd2 || cmd3` as an if/else shortcut: `cmd3` also runs when `cmd2` fails.
Use `if` when the second command can fail. Quote variables by default: `"$var"`. Single quotes
make literal text; `$'...'` is Bash/Zsh-only. Prefer `printf` to `echo` for non-trivial output.

```sh
command -v git >/dev/null 2>&1 || { printf '%s\n' 'git required' >&2; exit 1; }

tmpfile=$(mktemp) || exit 1
cleanup() { rm -f "$tmpfile"; }
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

while IFS= read -r line; do
    printf '%s\n' "$line"
done < file.txt

for file in *.txt; do
    [ -e "$file" ] || continue  # POSIX sh: a failed glob remains literal
    printf '%s\n' "$file"
done
```

`local`, `[[ ]]`, arrays, `pipefail`, `ERR`, and `BASH_SOURCE` are not POSIX. A trap handler must
not accidentally hide the original failure. For Bash/Zsh process shutdown, send TERM, wait for a
bounded interval, then use KILL only if the process remains alive; do not suppress unexpected errors.

## Jobs and interactive process control

Use `jobs`, `bg`, `fg`, `wait`, and `disown` only in an interactive shell. A production script
should retain PIDs and `wait` on the exact processes it started. Before killing by name, display
the matching PID and command line, exclude the current shell, require confirmation, and prefer
TERM followed by a bounded wait over immediate KILL. `pgrep` flags differ on BSD; verify the target.

| Command | Effect |
|---|---|
| `Ctrl+Z` | Suspend the foreground job |
| `bg` / `bg %N` | Resume a job in the background |
| `fg` / `fg %N` | Resume a job in the foreground |
| `jobs` | List background jobs |
| `kill %N` | Signal a job by number |
| `wait` / `wait "$pid"` | Wait for all jobs or a tracked process |
| `disown %N` | Detach an interactive job from the shell |

```sh
# Bash/Zsh helper; do not use as strict POSIX sh.
kill_gracefully() {
    local pid=$1 timeout=${2:-5}
    kill -TERM "$pid" 2>/dev/null || return
    local i=0
    while kill -0 "$pid" 2>/dev/null && [ "$i" -lt "$timeout" ]; do
        sleep 1
        i=$((i + 1))
    done
    kill -0 "$pid" 2>/dev/null || return 0
    kill -KILL "$pid"
}
```

For an interactive Zsh helper, keep matching and confirmation separate from escalation:

```zsh
pk() {  # usage: pk <pattern>
    local pattern=$1 line self=$$
    local -a pids
    pids=(${${(f)"$(pgrep -af -- "$pattern")"}:#($self|$PPID) *})
    (( $#pids )) || { print -u2 "no match"; return 1 }
    printf '%s\n' "${pids[@]}"
    read -q "?kill these? [y/N] " || { print; return 1 }
    print
    for line in $pids; do kill_gracefully ${line%% *} 3; done
}
```

Use `trap '' HUP` only when intentionally ignoring a hangup. Common signal numbers are HUP 1, INT 2,
TERM 15, USR1 10, and USR2 12. Status `126` means found-but-not-executable, `127` means not found,
and `128 + N` means termination by signal `N` (`130` is normally Ctrl-C).

## Zsh completion skeleton

Read `zsh.md` for qualifiers, `_arguments`, asynchronous completion, or hooks. A compact
subcommand completion is:

```zsh
#compdef mycli
_mycli() {
  local context state line curcontext="$curcontext"
  local -a subcmds=(
    'init:Initialize a new project'
    'build:Build a project'
    'deploy:Deploy to an environment'
  )
  _arguments -C \
    '(-h --help)'{-h,--help}'[Show help]' \
    '1:command:->subcmd' \
    '*::arg:->args'
  case $state in
    subcmd) _describe 'command' subcmds ;;
    args)
      case $words[1] in
        deploy) _arguments '--env[Target environment]:env:(dev staging prod)' ;;
      esac ;;
  esac
}
```

Put `_mycli` on `fpath` before `compinit`:

```zsh
fpath=(~/.zsh/completions $fpath)
autoload -Uz compinit && compinit
```

`zsh -n` checks syntax only. Exercise a real Tab completion after `compinit` to verify discovery
and argument routing.
