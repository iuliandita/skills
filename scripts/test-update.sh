#!/usr/bin/env bash
# Tests for install.sh --update against fixture checkouts and a fixture HOME.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Git hooks export GIT_DIR and friends; fixture repos must not inherit them.
while IFS= read -r var; do unset "$var"; done < <(git rev-parse --local-env-vars)

SAFE_PATH="$(for cmd in bash python3 git sha256sum flock timeout; do dirname "$(command -v "$cmd")"; done | awk '!seen[$0]++' | paste -sd:):/usr/bin:/bin"
REAL_GIT="$(command -v git)"
GIT_ID=(-c user.name=t -c user.email=t@example.invalid -c commit.gpgsign=false)
F=""
H=""
RC=0
OUT=""
ERR=""

cleanup() {
  [[ -z "$F" ]] || rm -rf "$F"
}
trap cleanup EXIT

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  exit 1
}

isolated() {
  local home="$1"
  shift
  env -i HOME="$home" PATH="$SAFE_PATH" LANG=C "$@"
}

g() {
  isolated "$H" git "$@"
}

# Names, types, modes, link targets, and contents under $1, skipping a
# top-level .git.
tree_hash() {
  python3 - "$1" <<'PY'
import hashlib
import os
import sys

root = sys.argv[1]
digest = hashlib.sha256()
for directory, dirs, files in os.walk(root, followlinks=False):
    if directory == root and ".git" in dirs:
        dirs.remove(".git")
    dirs.sort()
    for name in sorted(dirs + files):
        path = os.path.join(directory, name)
        info = os.lstat(path)
        digest.update(f"{os.path.relpath(path, root)}\0{info.st_mode:o}\0".encode())
        if os.path.islink(path):
            digest.update(os.readlink(path).encode())
        elif os.path.isfile(path):
            with open(path, "rb") as handle:
                digest.update(handle.read())
print(digest.hexdigest())
PY
}

# A publisher clone ($F/dev), its bare origin, and the user's clone ($F/repo)
# with two skills; the user installs and saves with the given options.
new_fixture() {
  cleanup
  F="$(mktemp -d)"
  H="$F/home"
  mkdir -p "$H" "$F/dev/scripts" "$F/dev/skills"
  cp "$ROOT/install.sh" "$ROOT/migrations.json" "$F/dev/"
  cp "$ROOT/scripts/skill-lib.sh" "$ROOT/scripts/skill-frontmatter.py" "$ROOT/scripts/migrate-skills.py" "$F/dev/scripts/"
  cp -R "$ROOT/skills/docker" "$ROOT/skills/git" "$F/dev/skills/"
  printf 'notes\n' > "$F/dev/skills/git/notes-a.md"
  ln -s SKILL.md "$F/dev/skills/git/alias.md"
  g init -q -b main "$F/dev"
  g -C "$F/dev" add -A
  g -C "$F/dev" "${GIT_ID[@]}" commit -q -m fixture
  g init -q --bare -b main "$F/origin.git"
  g -C "$F/dev" remote add origin "$F/origin.git"
  g -C "$F/dev" push -q -u origin main
  g clone -q "$F/origin.git" "$F/repo"
  isolated "$H" "$F/repo/install.sh" --save "$@" >/dev/null || fail "fixture install --save $* failed"
}

publish() {
  g -C "$F/dev" add -A
  g -C "$F/dev" "${GIT_ID[@]}" commit -q -m "${1:-change}"
  g -C "$F/dev" push -q origin main
}

# run_update [VAR=value...]: sets RC, OUT, ERR.
run_update() {
  RC=0
  isolated "$H" "$@" "$F/repo/install.sh" --update >"$F/out" 2>"$F/err" || RC=$?
  OUT="$(cat "$F/out")"
  ERR="$(cat "$F/err")"
}

expect_rc() {
  (( RC == $1 )) || fail "$2: exit $RC, want $1
--- stdout
$OUT
--- stderr
$ERR"
}

last_line() {
  tail -n 1 <<< "$OUT"
}

repo_head() {
  g -C "$F/repo" rev-parse HEAD
}

dev_head() {
  g -C "$F/dev" rev-parse HEAD
}

conf_set() {
  python3 - "$H/.config/iuliandita-skills/install.conf" "$1" "$2" <<'PY'
import sys

path, key, value = sys.argv[1:]
lines = open(path, encoding="utf-8").read().splitlines()
lines = [f"{key}={value}" if line.startswith(f"{key}=") else line for line in lines]
open(path, "w", encoding="utf-8").write("\n".join(lines) + "\n")
PY
}

# PATH holding everything in SAFE_PATH except $2.
path_without() {
  local dir="$1" skip="$2" d file
  mkdir -p "$dir"
  for d in ${SAFE_PATH//:/ }; do
    for file in "$d"/*; do
      [[ "${file##*/}" == "$skip" || -e "$dir/${file##*/}" || -L "$dir/${file##*/}" ]] \
        || ln -s "$file" "$dir/${file##*/}"
    done
  done
}

lock_tree() {
  python3 - "$1" "$2" <<'PY'
import json
import sys

entry = json.load(open(sys.argv[1], encoding="utf-8")).get("trees", {}).get(sys.argv[2])
print(f"{entry['hash_version']} {entry['digest']}" if entry else "-")
PY
}

OK_RANGE='^update: ok [0-9a-f]{12}\.\.[0-9a-f]{12} changed=1 skipped=0$'

test_current_is_a_noop() {
  local before
  new_fixture --tool claude
  before="$(tree_hash "$H/.claude")"
  run_update
  expect_rc 0 "current checkout"
  [[ "$(last_line)" == "update: ok current" ]] || fail "current: last line: $OUT"
  [[ ! -e "$H/.claude/.skills-backups" ]] || fail "current: backups were made"
  [[ "$(tree_hash "$H/.claude")" == "$before" ]] || fail "current: destination changed"
  grep -Eq '^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z update: fetching ' <<< "$OUT" \
    || fail "current: no timestamped phase line: $OUT"
  [[ -z "$ERR" ]] || fail "current: unexpected stderr: $ERR"
}

test_changed_skill_is_replaced_and_backed_up() {
  local git_before
  new_fixture --tool claude
  printf 'upstream change\n' >> "$F/dev/skills/docker/SKILL.md"
  publish
  git_before="$(tree_hash "$H/.claude/skills/git")"
  run_update
  expect_rc 0 "one changed skill"
  [[ "$(last_line)" =~ $OK_RANGE ]] || fail "one changed skill: last line: $OUT"
  cmp -s "$F/dev/skills/docker/SKILL.md" "$H/.claude/skills/docker/SKILL.md" || fail "docker not updated"
  [[ -d "$H/.claude/.skills-backups/skills/docker" && ! -e "$H/.claude/.skills-backups/skills/git" ]] \
    || fail "backups not limited to docker: $(ls "$H/.claude/.skills-backups/skills" 2>&1)"
  [[ "$(tree_hash "$H/.claude/skills/git")" == "$git_before" ]] || fail "unchanged skill git was touched"
  [[ "$(repo_head)" == "$(dev_head)" ]] || fail "checkout not fast-forwarded"
  [[ ! -e "$H/.claude/.skills-txn" ]] || fail "install records left behind"
  [[ "$(lock_tree "$H/.claude/skills/.skills-lock.json" docker)" == 2\ * ]] || fail "lock has no v2 tree for docker"
}

test_rename_and_symlink_target_changes_are_detected() {
  new_fixture --tool claude
  g -C "$F/dev" mv skills/git/notes-a.md skills/git/notes-b.md
  publish rename
  run_update
  expect_rc 0 "rename-only change"
  [[ "$(last_line)" =~ $OK_RANGE ]] || fail "rename-only: last line: $OUT"
  [[ -f "$H/.claude/skills/git/notes-b.md" && ! -e "$H/.claude/skills/git/notes-a.md" ]] || fail "rename not applied"

  ln -sfn notes-b.md "$F/dev/skills/git/alias.md"
  publish relink
  run_update
  expect_rc 0 "symlink-target-only change"
  [[ "$(last_line)" =~ $OK_RANGE ]] || fail "symlink-only: last line: $OUT"
  [[ "$(readlink "$H/.claude/skills/git/alias.md")" == notes-b.md ]] || fail "symlink target not updated"
}

test_new_skill_is_installed() {
  new_fixture --tool claude
  cp -R "$F/dev/skills/docker" "$F/dev/skills/extra"
  sed -i 's/^name: docker$/name: extra/' "$F/dev/skills/extra/SKILL.md"
  publish
  run_update
  expect_rc 0 "new skill"
  [[ "$(last_line)" =~ $OK_RANGE ]] || fail "new skill: last line: $OUT"
  [[ -f "$H/.claude/skills/extra/SKILL.md" ]] || fail "new skill not installed"
  [[ ! -e "$H/.claude/.skills-backups" ]] || fail "new skill made a backup"
}

test_saved_duplicates_and_kept_renames() {
  local lock
  new_fixture --tool claude docker git
  lock="$H/.claude/skills/.skills-lock.json"
  conf_set skills docker,git,docker
  printf 'upstream\n' >> "$F/dev/skills/docker/SKILL.md"
  publish
  run_update
  expect_rc 0 "duplicate saved skill"
  [[ "$(last_line)" =~ $OK_RANGE ]] || fail "duplicate saved skill processed twice: $OUT"

  # Same content under another name: the v1 record is still published, the
  # tree entry is dropped, and --update will not claim the copy.
  mv "$H/.claude/skills/git/notes-a.md" "$H/.claude/skills/git/notes-z.md"
  isolated "$H" "$F/repo/install.sh" --tool claude git >/dev/null || fail "plain reinstall failed"
  python3 - "$lock" <<'PY' || fail "v1 record not published for a kept skill"
import json
import sys

assert "git" in json.load(open(sys.argv[1], encoding="utf-8"))["skills"]
PY
  [[ "$(lock_tree "$lock" git)" == "-" ]] || fail "tree entry kept for a renamed copy"
  printf 'upstream\n' >> "$F/dev/skills/git/SKILL.md"
  publish
  run_update
  expect_rc 6 "renamed copy"
  [[ -f "$H/.claude/skills/git/notes-z.md" ]] || fail "renamed copy was replaced"
}

test_local_modification_is_kept() {
  local mine
  new_fixture --tool claude
  printf 'my edit\n' >> "$H/.claude/skills/docker/SKILL.md"
  mine="$(tree_hash "$H/.claude/skills/docker")"
  printf 'upstream\n' >> "$F/dev/skills/docker/SKILL.md"
  printf 'upstream\n' >> "$F/dev/skills/git/SKILL.md"
  publish
  run_update
  expect_rc 6 "local modification"
  [[ "$(last_line)" =~ ^update:\ partial\ [0-9a-f]{12}\.\.[0-9a-f]{12}\ changed=1\ skipped=1$ ]] \
    || fail "local modification: last line: $OUT"
  grep -q 'docker skipped: local changes in' <<< "$OUT" || fail "skip not explained: $OUT"
  [[ "$(tree_hash "$H/.claude/skills/docker")" == "$mine" ]] || fail "local modification was overwritten"
  cmp -s "$F/dev/skills/git/SKILL.md" "$H/.claude/skills/git/SKILL.md" || fail "git not updated next to a skip"
  [[ "$(repo_head)" == "$(dev_head)" ]] || fail "checkout not fast-forwarded on partial"
}

test_legacy_v1_records() {
  local lock git_before
  new_fixture --tool claude
  lock="$H/.claude/skills/.skills-lock.json"
  python3 - "$lock" <<'PY'
import json
import sys

lock = json.load(open(sys.argv[1], encoding="utf-8"))
del lock["trees"]
json.dump(lock, open(sys.argv[1], "w", encoding="utf-8"))
PY
  printf 'upstream\n' >> "$F/dev/skills/git/SKILL.md"
  publish
  git_before="$(tree_hash "$H/.claude/skills/git")"
  run_update
  expect_rc 6 "legacy v1 records"
  grep -q 'git skipped: installed before tree digests.*install.sh --tool claude --force git' <<< "$OUT" \
    || fail "legacy-unresolved not explained: $OUT"
  [[ "$(tree_hash "$H/.claude/skills/git")" == "$git_before" ]] || fail "legacy-unresolved skill was replaced"
  [[ "$(lock_tree "$lock" docker)" == 2\ * ]] || fail "equal v1 record not upgraded"
  [[ "$(lock_tree "$lock" git)" == "-" ]] || fail "unequal v1 record upgraded"

  isolated "$H" "$F/repo/install.sh" --tool claude --force git >/dev/null || fail "force reinstall failed"
  run_update
  expect_rc 0 "after legacy reconcile"
  [[ "$(last_line)" == "update: ok current" ]] || fail "after legacy reconcile: $OUT"
}

# Each case must leave HEAD and the installed skills unchanged.
expect_refused() {
  local code="$1" label="$2" pattern="$3" head dest
  head="$(repo_head)"
  dest="$(tree_hash "$H/.claude")"
  shift 3
  run_update "$@"
  expect_rc "$code" "$label"
  grep -q -- "$pattern" <<< "$ERR" || fail "$label: stderr lacks '$pattern': $ERR"
  [[ "$(repo_head)" == "$head" ]] || fail "$label: HEAD moved"
  [[ "$(tree_hash "$H/.claude")" == "$dest" ]] || fail "$label: installed skills changed"
}

test_source_checks() {
  new_fixture --tool claude
  printf 'x\n' >> "$F/repo/migrations.json"
  expect_refused 4 "dirty tracked file" "uncommitted or untracked changes"
  g -C "$F/repo" checkout -q -- migrations.json
  : > "$F/repo/stray"
  expect_refused 4 "untracked file" "uncommitted or untracked changes"
  rm "$F/repo/stray"
  g -C "$F/repo" checkout -q -b other
  expect_refused 4 "wrong branch" "on branch other"
  g -C "$F/repo" checkout -q main
  g -C "$F/repo" checkout -q --detach
  expect_refused 4 "detached HEAD" "HEAD is detached"
  g -C "$F/repo" checkout -q main
  g -C "$F/repo" remote set-url origin "$F/elsewhere.git"
  expect_refused 4 "remote URL changed" "the remote URL is"
  g -C "$F/repo" remote set-url origin "$F/origin.git"
  g -C "$F/repo" config branch.main.remote upstream
  expect_refused 4 "upstream remote changed" "the upstream remote is 'upstream'"
  g -C "$F/repo" config branch.main.remote origin
  g -C "$F/repo" config branch.main.merge refs/heads/other
  expect_refused 4 "upstream ref changed" "the upstream branch is"
  g -C "$F/repo" config branch.main.merge refs/heads/main
  conf_set source_repo /elsewhere
  expect_refused 4 "other checkout" "the config was saved from /elsewhere"
  conf_set source_repo "$F/repo"
  conf_set source_upstream ""
  expect_refused 4 "no saved upstream" "has no upstream branch"
  conf_set source_upstream refs/heads/main

  g -C "$F/repo" "${GIT_ID[@]}" commit -q --allow-empty -m local
  expect_refused 4 "ahead of upstream" "is not an ancestor of upstream"
  printf 'upstream\n' >> "$F/dev/skills/docker/SKILL.md"
  publish
  expect_refused 4 "diverged" "is not an ancestor of upstream"
  g -C "$F/repo" reset -q --hard HEAD~1
  run_update
  expect_rc 0 "after the checks"
}

test_fast_forward_failure_changes_nothing() {
  local head index work
  new_fixture --tool claude
  printf 'upstream\n' >> "$F/dev/skills/docker/SKILL.md"
  publish
  head="$(repo_head)"
  index="$(sha256sum < "$F/repo/.git/index")"
  work="$(tree_hash "$F/repo")"
  : > "$F/repo/.git/index.lock"
  expect_refused 5 "ff-only merge failure" "fast-forward to [0-9a-f]* failed; HEAD is still"
  [[ "$(repo_head)" == "$head" ]] || fail "ff failure moved HEAD"
  [[ "$(sha256sum < "$F/repo/.git/index")" == "$index" ]] || fail "ff failure changed the index"
  [[ "$(tree_hash "$F/repo")" == "$work" ]] || fail "ff failure changed the working tree"
  rm "$F/repo/.git/index.lock"

  # A fast-forward that fails partway changes the tree: that is not exit 5.
  printf 'new\n' > "$F/dev/skills/git/zz-new.md"
  publish
  chmod 555 "$F/repo/skills/git"
  run_update
  chmod 755 "$F/repo/skills/git"
  expect_rc 1 "partial fast-forward"
  grep -q 'failed partway' <<< "$ERR" || fail "partial fast-forward not reported: $ERR"
  [[ "$(repo_head)" == "$head" ]] || fail "partial fast-forward moved HEAD"
  g -C "$F/repo" checkout -q -- .
  run_update
  expect_rc 0 "after restoring the checkout"
  [[ "$(last_line)" =~ ^update:\ ok\ [0-9a-f]{12}\.\.[0-9a-f]{12}\ changed=2\ skipped=0$ ]] \
    || fail "after restoring the checkout: $OUT"
}

test_config_and_invocation_errors() {
  local conf head
  new_fixture --tool claude
  conf="$H/.config/iuliandita-skills/install.conf"
  mv "$conf" "$F/saved.conf"
  expect_refused 2 "missing config" "no saved install config"
  mv "$F/saved.conf" "$conf"
  expect_refused 2 "override env" "CLAUDE_SKILLS_DIR is set" CLAUDE_SKILLS_DIR="$F/o"
  expect_refused 2 "canonical override" "SKILLS_CANONICAL_DIR is set" SKILLS_CANONICAL_DIR="$F/o"
  expect_refused 2 "bad timeout" "SKILLS_UPDATE_TIMEOUT must be" SKILLS_UPDATE_TIMEOUT=soon
  conf_set tools 'claude;touch pwned'
  expect_refused 2 "invalid config" "invalid tool name"
  conf_set tools claude
  [[ ! -e "$F/o" ]] || fail "an override path was created"

  head="$(repo_head)"
  RC=0
  OUT="$(isolated "$H" "$F/repo/install.sh" --update --tool claude 2>&1)" || RC=$?
  expect_rc 2 "--update with options"
  RC=0
  OUT="$(isolated "$H" "$F/repo/install.sh" --tool claude --update 2>&1)" || RC=$?
  expect_rc 2 "--update after options"
  RC=0
  OUT="$(isolated "$H" "$F/repo/install.sh" --apply-update "$head" "$head" 2>&1)" || RC=$?
  expect_rc 1 "direct --apply-update"
  grep -q 'lock was not handed over' <<< "$OUT" || fail "direct --apply-update refusal unclear: $OUT"
  ( exec 8>>"$H/.local/state/iuliandita-skills/install.lock"; flock 8; : > "$F/held"; exec sleep 30 ) &
  local holder=$!
  for _ in $(seq 100); do [[ -e "$F/held" ]] && break; sleep 0.1; done
  RC=0
  # shellcheck disable=SC2016
  OUT="$(isolated "$H" bash -c 'exec 9>>"$1"; exec "$2" --apply-update "$3" "$3"' _ \
    "$H/.local/state/iuliandita-skills/install.lock" "$F/repo/install.sh" "$head" 2>&1)" || RC=$?
  kill "$holder"
  wait "$holder" 2>/dev/null || true
  expect_rc 1 "--apply-update with an unheld lock descriptor"
  grep -q 'lock was not handed over' <<< "$OUT" || fail "unheld lock descriptor accepted: $OUT"
  [[ "$(repo_head)" == "$head" ]] || fail "invocation errors moved HEAD"
}

test_every_override_variable_is_refused() {
  local var
  local -a vars=()
  new_fixture --tool claude
  mapfile -t vars < <(grep -oE '[A-Z_]+_SKILLS_DIR:-' "$ROOT/install.sh" | cut -d: -f1 | sort -u)
  (( ${#vars[@]} > 20 )) || fail "override matrix found only ${#vars[@]} *_SKILLS_DIR variables"
  vars+=(SOMETOOL_SKILLS_DIR SKILLS_CANONICAL_DIR SKILLS_BACKUP_DIR OPENCODE_CONFIG_FILE SKILLS_TOOL)
  for var in "${vars[@]}"; do
    expect_refused 2 "$var" "$var is set" "$var=$F/o"
  done
  [[ ! -e "$F/o" ]] || fail "an override path was created"
}

test_held_lock_exits_3() {
  local holder
  new_fixture --tool claude
  printf 'upstream\n' >> "$F/dev/skills/docker/SKILL.md"
  publish
  ( exec 8>>"$H/.local/state/iuliandita-skills/install.lock"; flock 8; : > "$F/held"; exec sleep 30 ) &
  holder=$!
  for _ in $(seq 100); do [[ -e "$F/held" ]] && break; sleep 0.1; done
  expect_refused 3 "held lock" "Another install.sh run holds"
  kill "$holder"
  wait "$holder" 2>/dev/null || true
  [[ ! -e "$F/repo/.git/FETCH_HEAD" ]] || fail "fetched without the lock"
}

test_concurrent_updates_one_proceeds() {
  local first
  new_fixture --tool claude
  printf 'upstream\n' >> "$F/dev/skills/docker/SKILL.md"
  publish
  mkdir "$F/shim"
  printf '#!/bin/bash\nif [[ " $* " == *" fetch "* ]]; then : > "%s/fetching"; sleep 2; fi\nexec "%s" "$@"\n' \
    "$F" "$REAL_GIT" > "$F/shim/git"
  chmod +x "$F/shim/git"
  isolated "$H" PATH="$F/shim:$SAFE_PATH" "$F/repo/install.sh" --update >"$F/first.out" 2>&1 &
  first=$!
  for _ in $(seq 100); do [[ -e "$F/fetching" ]] && break; sleep 0.1; done
  [[ -e "$F/fetching" ]] || fail "first update never fetched: $(cat "$F/first.out")"
  run_update PATH="$F/shim:$SAFE_PATH"
  expect_rc 3 "second concurrent update"
  wait "$first" || fail "first concurrent update failed: $(cat "$F/first.out")"
  [[ "$(cat "$F/first.out" "$F/out" | grep -c '^update: ok')" == 1 ]] || fail "not exactly one update proceeded"
}

test_fetch_timeout_and_signal() {
  local start pid sig rc
  new_fixture --tool claude
  mkdir "$F/helpers"
  printf '#!/bin/sh\nexec sleep 60\n' > "$F/helpers/git-remote-slow"
  chmod +x "$F/helpers/git-remote-slow"
  g -C "$F/repo" remote set-url origin slow::nowhere
  isolated "$H" "$F/repo/install.sh" --save --tool claude >/dev/null || fail "re-save failed"
  start=$SECONDS
  expect_refused 5 "fetch timeout" "fetch timed out after 2s" PATH="$F/helpers:$SAFE_PATH" SKILLS_UPDATE_TIMEOUT=2
  (( SECONDS - start < 15 )) || fail "fetch timeout took $(( SECONDS - start ))s"

  for sig in INT:130 TERM:143; do
    rc=0
    # Background jobs start with SIGINT ignored, which bash cannot trap;
    # restore the default so the installer sees what a terminal would send.
    isolated "$H" PATH="$F/helpers:$SAFE_PATH" SKILLS_UPDATE_TIMEOUT=60 python3 -c \
      'import os, signal, sys; signal.signal(signal.SIGINT, signal.SIG_DFL); os.execv(sys.argv[1], sys.argv[1:])' \
      "$F/repo/install.sh" --update >"$F/sig.out" 2>&1 &
    pid=$!
    sleep 1
    start=$SECONDS
    kill "-${sig%%:*}" "$pid"
    wait "$pid" || rc=$?
    (( rc == ${sig##*:} )) || fail "SIG${sig%%:*} during fetch exited $rc, want ${sig##*:}: $(cat "$F/sig.out")"
    (( SECONDS - start < 5 )) || fail "SIG${sig%%:*} during fetch took $(( SECONDS - start ))s to take effect"
  done
}

test_prompts_fail_instead_of_hanging() {
  local start
  new_fixture --tool claude
  mkdir "$F/fake"
  cat > "$F/fake/ssh" <<EOF
#!/bin/sh
printf '%s\n' "args=\$*" "SSH_ASKPASS=\$SSH_ASKPASS" "SSH_ASKPASS_REQUIRE=\$SSH_ASKPASS_REQUIRE" \
  "GIT_TERMINAL_PROMPT=\$GIT_TERMINAL_PROMPT" >> "$F/ssh.log"
case "\$*" in *BatchMode=yes*) echo 'Permission denied (publickey).' >&2; exit 255 ;; esac
exec sleep 60
EOF
  cat > "$F/fake/git-remote-cred" <<EOF
#!/bin/sh
printf 'GIT_ASKPASS=%s GIT_TERMINAL_PROMPT=%s\n' "\$GIT_ASKPASS" "\$GIT_TERMINAL_PROMPT" > "$F/cred.log"
printf 'protocol=https\nhost=example.invalid\n\n' | git credential fill >/dev/null 2>&1 && : > "$F/got-credential"
exit 1
EOF
  chmod +x "$F/fake/ssh" "$F/fake/git-remote-cred"

  g -C "$F/repo" remote set-url origin ssh://git.example.invalid/skills.git
  isolated "$H" "$F/repo/install.sh" --save --tool claude >/dev/null || fail "re-save failed"
  start=$SECONDS
  expect_refused 5 "ssh prompt" "fetch failed" PATH="$F/fake:$SAFE_PATH" SKILLS_UPDATE_TIMEOUT=30
  (( SECONDS - start < 10 )) || fail "ssh auth failure took $(( SECONDS - start ))s"
  grep -q 'BatchMode=yes' "$F/ssh.log" || fail "ssh ran without BatchMode: $(cat "$F/ssh.log")"
  grep -qx 'SSH_ASKPASS_REQUIRE=never' "$F/ssh.log" || fail "SSH_ASKPASS_REQUIRE not never: $(cat "$F/ssh.log")"

  g -C "$F/repo" remote set-url origin cred::https://example.invalid/skills.git
  isolated "$H" "$F/repo/install.sh" --save --tool claude >/dev/null || fail "re-save failed"
  start=$SECONDS
  expect_refused 5 "credential prompt" "fetch failed" PATH="$F/fake:$SAFE_PATH" SKILLS_UPDATE_TIMEOUT=30
  (( SECONDS - start < 10 )) || fail "credential failure took $(( SECONDS - start ))s"
  grep -qx 'GIT_ASKPASS=false GIT_TERMINAL_PROMPT=0' "$F/cred.log" || fail "prompts not disabled: $(cat "$F/cred.log")"
  [[ ! -e "$F/got-credential" ]] || fail "a credential was obtained"
}

test_updated_installer_runs_once_holding_the_lock() {
  local pid status=0 out
  new_fixture --tool claude
  python3 - "$F/dev/install.sh" <<'PY'
import sys

path = sys.argv[1]
text = open(path, encoding="utf-8").read()
hook = ('if [[ "${1:-}" == --apply-update ]]; then printf \'ran\\n\' >> "$HOME/marker"; '
        ': > "$HOME/applying"; sleep 3; fi\n')
text = text.replace("set -euo pipefail\n", "set -euo pipefail\n" + hook, 1)
open(path, "w", encoding="utf-8").write(text)
PY
  publish installer
  isolated "$H" "$F/repo/install.sh" --update >"$F/first.out" 2>&1 &
  pid=$!
  for _ in $(seq 100); do [[ -e "$H/applying" ]] && break; sleep 0.1; done
  [[ -e "$H/applying" ]] || fail "new installer never ran: $(cat "$F/first.out")"
  out="$(isolated "$H" SKILLS_LOCK_WAIT=0 "$F/repo/install.sh" --tool portable --dest "$F/other" docker 2>&1)" || status=$?
  (( status == 3 )) || fail "contender during apply exited $status, want 3: $out"
  [[ ! -e "$F/other" ]] || fail "contender installed during apply"
  wait "$pid" || fail "update with a new installer failed: $(cat "$F/first.out")"
  [[ "$(wc -l < "$H/marker")" -eq 1 ]] || fail "new installer ran $(wc -l < "$H/marker") times"
}

test_apply_faults_then_rerun() {
  local before
  new_fixture --tool claude
  printf 'upstream\n' >> "$F/dev/skills/docker/SKILL.md"
  publish
  before="$(tree_hash "$H/.claude/skills/docker")"
  run_update SKILLS_INSTALL_FAULT=stage:docker
  expect_rc 1 "copy fault"
  grep -q "HEAD is at $(dev_head); rerun install.sh --update" <<< "$ERR" || fail "copy fault message: $ERR"
  [[ "$(repo_head)" == "$(dev_head)" ]] || fail "copy fault: HEAD not at the new commit"
  [[ "$(tree_hash "$H/.claude/skills/docker")" == "$before" ]] || fail "copy fault changed docker"
  run_update
  expect_rc 0 "rerun after copy fault"
  [[ "$(last_line)" =~ $OK_RANGE ]] || fail "rerun after copy fault: $OUT"

  # Interrupted right after the new copy landed: the next run confirms it.
  printf 'again\n' >> "$F/dev/skills/docker/SKILL.md"
  publish
  run_update SKILLS_INSTALL_FAULT=record:docker
  expect_rc 1 "interrupted apply"
  cmp -s "$F/dev/skills/docker/SKILL.md" "$H/.claude/skills/docker/SKILL.md" || fail "interrupted apply: new copy missing"
  run_update
  expect_rc 0 "rerun after interrupted apply"
  [[ "$(last_line)" == "update: ok current" ]] || fail "rerun after interrupted apply: $OUT"
  [[ ! -e "$H/.claude/.skills-txn" ]] || fail "interrupted apply: records left after rerun"
}

test_edit_after_interrupted_update_is_kept() {
  local txn edited evidence
  new_fixture --tool claude
  txn="$H/.claude/.skills-txn/skills/docker"
  printf 'upstream\n' >> "$F/dev/skills/docker/SKILL.md"
  publish
  run_update SKILLS_INSTALL_FAULT=record:docker
  expect_rc 1 "record fault during update"
  printf 'my edit\n' >> "$H/.claude/skills/docker/SKILL.md"
  edited="$(tree_hash "$H/.claude/skills/docker")"
  evidence="$(tree_hash "$txn")"
  [[ -e "$txn/prev" && -f "$txn/record" ]] || fail "record fault left no evidence"
  printf 'more\n' >> "$F/dev/skills/git/SKILL.md"
  publish
  for _ in 1 2; do
    run_update
    expect_rc 6 "edit after an interrupted update"
    [[ "$(last_line)" =~ ^update:\ partial\ .*skipped=1$ ]] || fail "edit after interruption: last line: $OUT"
    grep -q 'kept it as a local modification' <<< "$OUT" || fail "edit not reported: $OUT"
    grep -q 'docker skipped: local changes made after an interrupted install' <<< "$OUT" || fail "docker not skipped: $OUT"
    [[ "$(tree_hash "$H/.claude/skills/docker")" == "$edited" ]] || fail "the edit was not preserved"
    [[ "$(tree_hash "$txn")" == "$evidence" ]] || fail "the evidence was not kept"
  done
  cmp -s "$F/dev/skills/git/SKILL.md" "$H/.claude/skills/git/SKILL.md" || fail "other skills were not updated"
}

test_lock_publication_fault_keeps_ownership() {
  local record mine
  new_fixture --tool claude
  record="$H/.claude/.skills-txn/skills/docker/record"
  printf 'one\n' >> "$F/dev/skills/docker/SKILL.md"
  publish
  run_update SKILLS_INSTALL_FAULT=lock
  expect_rc 1 "lock fault"
  cmp -s "$F/dev/skills/docker/SKILL.md" "$H/.claude/skills/docker/SKILL.md" || fail "lock fault: copy not in place"
  grep -q '^pending=[0-9a-f]\{64\}$' "$record" || fail "lock fault: no pending digest in the record"
  run_update
  expect_rc 0 "retry with the same upstream"
  [[ "$(last_line)" == "update: ok current" ]] || fail "retry with the same upstream: $OUT"
  [[ ! -e "$record" ]] || fail "record kept after the lock was published"

  printf 'two\n' >> "$F/dev/skills/docker/SKILL.md"
  publish
  run_update SKILLS_INSTALL_FAULT=lock
  expect_rc 1 "second lock fault"
  printf 'three\n' >> "$F/dev/skills/docker/SKILL.md"
  publish
  run_update
  expect_rc 0 "upstream moved after a lock fault"
  [[ "$(last_line)" =~ $OK_RANGE ]] || fail "upstream moved after a lock fault: $OUT"
  grep -q 'docker: install record kept until its lock entry is published' <<< "$OUT" \
    || fail "record did not survive startup recovery: $OUT"
  cmp -s "$F/dev/skills/docker/SKILL.md" "$H/.claude/skills/docker/SKILL.md" || fail "docker not replaced"

  printf 'mine\n' >> "$H/.claude/skills/docker/SKILL.md"
  mine="$(tree_hash "$H/.claude/skills/docker")"
  printf 'four\n' >> "$F/dev/skills/docker/SKILL.md"
  publish
  run_update
  expect_rc 6 "local edit after recovery"
  [[ "$(tree_hash "$H/.claude/skills/docker")" == "$mine" ]] || fail "local edit overwritten"
}

test_missing_dependencies_exit_10() {
  new_fixture --tool claude
  path_without "$F/no-flock" flock
  path_without "$F/no-timeout" timeout
  expect_refused 10 "missing flock" "flock (util-linux) is required" PATH="$F/no-flock"
  expect_refused 10 "missing timeout" "timeout is required" PATH="$F/no-timeout"
}

test_link_mode() {
  new_fixture --tool claude,cursor --link
  printf 'upstream\n' >> "$F/dev/skills/docker/SKILL.md"
  publish
  run_update
  expect_rc 0 "link mode update"
  [[ "$(last_line)" =~ $OK_RANGE ]] || fail "link mode update: $OUT"
  cmp -s "$F/dev/skills/docker/SKILL.md" "$H/.agents/skills/docker/SKILL.md" || fail "canonical copy not updated"
  [[ "$(readlink "$H/.claude/skills/docker")" == "$H/.agents/skills/docker" ]] || fail "claude link changed"

  rm "$H/.claude/skills/git"
  run_update
  expect_rc 0 "missing link"
  [[ "$(readlink "$H/.claude/skills/git")" == "$H/.agents/skills/git" ]] || fail "missing link not recreated"

  rm "$H/.cursor/skills/git"
  cp -R "$H/.agents/skills/git" "$H/.cursor/skills/git"
  run_update
  expect_rc 6 "copy where a link belongs"
  grep -q "is not a link to $H/.agents/skills/git" <<< "$OUT" || fail "link skip not explained: $OUT"
  [[ -d "$H/.cursor/skills/git" && ! -L "$H/.cursor/skills/git" ]] || fail "user copy replaced"
}

test_opencode_new_skill_is_allowed() {
  new_fixture --tool opencode
  cp -R "$F/dev/skills/docker" "$F/dev/skills/extra"
  sed -i 's/^name: docker$/name: extra/' "$F/dev/skills/extra/SKILL.md"
  publish
  run_update
  expect_rc 0 "opencode update"
  python3 - "$H/.config/opencode/opencode.json" <<'PY' || fail "new skill not allowed in opencode.json"
import json
import sys

assert json.load(open(sys.argv[1], encoding="utf-8"))["permission"]["skill"]["extra"] == "allow"
PY
}

test_current_is_a_noop
test_changed_skill_is_replaced_and_backed_up
test_rename_and_symlink_target_changes_are_detected
test_new_skill_is_installed
test_saved_duplicates_and_kept_renames
test_local_modification_is_kept
test_legacy_v1_records
test_source_checks
test_fast_forward_failure_changes_nothing
test_config_and_invocation_errors
test_every_override_variable_is_refused
test_held_lock_exits_3
test_concurrent_updates_one_proceeds
test_fetch_timeout_and_signal
test_prompts_fail_instead_of_hanging
test_updated_installer_runs_once_holding_the_lock
test_apply_faults_then_rerun
test_edit_after_interrupted_update_is_kept
test_lock_publication_fault_keeps_ownership
test_missing_dependencies_exit_10
test_link_mode
test_opencode_new_skill_is_allowed

printf 'update tests passed\n'
