# SSH tmux Autostart Patterns

Use this when configuring shell startup so SSH logins land in a persistent tmux
session without breaking automation.

## Goal

Interactive SSH sessions should attach to an existing session or create one.
Non-interactive SSH commands, `scp`, `rsync`, automation, and already-nested tmux
sessions must not be hijacked.

## Bash `.bashrc` Pattern

Put this in `.bashrc` after normal PATH setup and after the standard interactive
shell guard.

```bash
# Auto-start tmux for interactive SSH sessions.
# Safe guards:
# - only over SSH
# - only when not already inside tmux
# - only with a real TTY, so scp/rsync/remote commands do not get hijacked
if [ -n "${SSH_CONNECTION:-}" ] && [ -z "${TMUX:-}" ] && [ -t 0 ] && [ -t 1 ] && command -v tmux >/dev/null 2>&1; then
    case "${TERM:-}" in
        dumb|unknown) ;;
        *) exec tmux new-session -A -s main ;;
    esac
fi
```

## Why These Guards Matter

- `SSH_CONNECTION` limits behavior to SSH logins.
- `TMUX` prevents nested tmux sessions.
- `[ -t 0 ] && [ -t 1 ]` preserves non-interactive SSH commands and file-copy workflows.
- `TERM=dumb|unknown` avoids launching tmux in unsuitable terminals.
- `command -v tmux` avoids breaking login if tmux is missing.
- `exec` replaces the login shell; exiting tmux exits the SSH session cleanly.
- `tmux new-session -A -s main` attaches to `main` if present or creates it if absent.

## Verification Commands

```bash
bash -n ~/.bashrc
command -v tmux && tmux -V

# Non-TTY SSH simulation should not exec tmux. Expect warnings from bash -i
# without a TTY, then `non-tty-ok`.
env SSH_CONNECTION='1 2 3 4' TERM=xterm-256color bash -ic 'echo non-tty-ok' 2>&1

# tmux smoke test
tmux new-session -d -s tmux-autostart-check 'sleep 10'
tmux has-session -t tmux-autostart-check
tmux kill-session -t tmux-autostart-check
```

## Editing Safety

- Read the target dotfile before editing.
- Make a timestamped backup before changing login startup files.
- Verify syntax before closing the session.
- Keep the existing non-interactive guard in `.bashrc` intact.
- If a protected-file editor refuses direct patching, use a small script that
  backs up, edits, and runs `bash -n`.

## Pitfalls

- Do not use only `SSH_CONNECTION`; that can still catch `ssh host command` cases.
- Do not omit the `TMUX` guard; nested sessions confuse users fast.
- Do not put this before PATH setup if tmux may be in a user-local path.
- Do not put it in `.profile` blindly; first check whether `.profile` sources
  `.bashrc` and what shell the account uses.
- Do not use `set -e` discovery blocks that hide useful diagnostics. Use
  `2>&1 || true` for probes where failure is informative.
