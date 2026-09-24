#!/usr/bin/env bash
# Tests for install.sh --detect and the saved install config (--save).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Git hooks export GIT_DIR and friends; fixture repos must not inherit them.
while IFS= read -r var; do unset "$var"; done < <(git rev-parse --local-env-vars)

SAFE_PATH="$(for cmd in python3 git sha256sum flock; do dirname "$(command -v "$cmd")"; done | awk '!seen[$0]++' | paste -sd:):/usr/bin:/bin"
REAL_GIT="$(command -v git)"
OVERRIDES=(CLAUDE_SKILLS_DIR CODEX_SKILLS_DIR SKILLS_CANONICAL_DIR SKILLS_BACKUP_DIR OPENCODE_CONFIG_FILE SKILLS_TOOL)

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  exit 1
}

isolated() {
  local home="$1"
  shift
  env -i HOME="$home" PATH="$SAFE_PATH" LANG=C "$@"
}

isolated_path() {
  local home="$1" path="$2"
  shift 2
  env -i HOME="$home" PATH="$path" LANG=C "$@"
}

# Names, types, modes, link targets, and contents of everything under $1.
tree_hash() {
  python3 - "$1" <<'PY'
import hashlib
import os
import sys

root = sys.argv[1]
digest = hashlib.sha256()
for directory, dirs, files in os.walk(root, followlinks=False):
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

mode_of() {
  python3 -c 'import os, sys; print(oct(os.lstat(sys.argv[1]).st_mode & 0o777))' "$1"
}

# A minimal checkout of the installer with two skills. $2=true adds a bare
# origin and makes main track it.
make_fixture() {
  local dir="$1" upstream="$2" home="$3"
  mkdir -p "$dir/scripts" "$dir/skills"
  cp "$ROOT/install.sh" "$ROOT/migrations.json" "$dir/"
  cp "$ROOT/scripts/skill-lib.sh" "$ROOT/scripts/skill-frontmatter.py" "$ROOT/scripts/migrate-skills.py" "$dir/scripts/"
  cp -R "$ROOT/skills/docker" "$ROOT/skills/git" "$dir/skills/"
  isolated "$home" git -C "$dir" init -q -b main
  isolated "$home" git -C "$dir" add -A
  isolated "$home" git -C "$dir" -c user.name=t -c user.email=t@example.invalid -c commit.gpgsign=false \
    commit -q -m fixture
  if [[ "$upstream" == "true" ]]; then
    isolated "$home" git init -q --bare "$dir.origin.git"
    isolated "$home" git -C "$dir" remote add origin "$dir.origin.git"
    isolated "$home" git -C "$dir" push -q -u origin main
  fi
}

conf_dir() {
  printf '%s/.config/iuliandita-skills\n' "$1"
}

write_conf() {
  local dir
  dir="$(conf_dir "$1")"
  mkdir -p "$dir"
  chmod 700 "$dir"
  printf '%s' "$2" > "$dir/install.conf"
  chmod 600 "$dir/install.conf"
}

# $1 tools, $2 skills, $3 source_repo
conf_text() {
  printf 'version=1\ntools=%s\nlink=false\ninclude_internal=false\nskills=%s\nsource_repo=%s\nsource_branch=main\nsource_remote=\nsource_remote_url=\nsource_upstream=\n' \
    "$1" "$2" "$3"
}

# ── --detect ──────────────────────────────────────────────────────────

# Only the commands install.sh needs before --detect exits, so no real
# harness binary on the host can leak into the result.
make_sys_path() {
  local cmd
  mkdir -p "$1"
  for cmd in bash dirname python3; do
    ln -s "$(command -v "$cmd")" "$1/$cmd"
  done
}

test_detect_reports_candidates_without_running_anything() {
  local tmp home bin bin2 sys out err before line expected
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' RETURN
  home="$tmp/home"
  bin="$tmp/b"$'\t'"in;x"
  bin2="$tmp/bin2"
  sys="$tmp/sys"
  make_sys_path "$sys"
  mkdir -p "$bin" "$bin2" "$home/.codex" "$home/.claude" "$home/.hermes" "$home/.config/opencode/skills" "$home/.agents/skills/docker"
  : > "$home/.codex/config.toml"
  : > "$home/.claude/settings.json"
  : > "$home/.hermes/config.yaml"
  printf '#!/bin/sh\ntouch "%s/ran"\n' "$tmp" > "$bin/claude"
  cp "$bin/claude" "$bin/agy"
  cp "$bin/claude" "$bin/cmd"
  cp "$bin/claude" "$bin2/claude"
  cp "$bin/claude" "$bin/kimi"
  chmod +x "$bin/claude" "$bin/agy" "$bin/cmd" "$bin2/claude"
  before="$(tree_hash "$tmp")"

  out="$(isolated_path "$home" "$bin:$bin2::relative/dir:$sys" "$ROOT/install.sh" --detect 2>"$tmp/err")" \
    || fail "--detect exited non-zero"
  err="$(cat "$tmp/err")"
  [[ ! -e "$tmp/ran" ]] || fail "--detect executed a harness binary"
  rm -f "$tmp/err"
  [[ "$(tree_hash "$tmp")" == "$before" ]] || fail "--detect changed files"

  expected="candidate"$'\t'"claude"$'\t'"binary:$tmp/b\\tin\\x3bx/claude;config:$home/.claude/settings.json"
  grep -qFx -- "$expected" <<< "$out" || fail "claude evidence missing or unescaped: $out"
  grep -qFx -- "candidate"$'\t'"codex"$'\t'"config:$home/.codex/config.toml" <<< "$out" || fail "codex config marker missing: $out"
  grep -qFx -- "candidate"$'\t'"hermes"$'\t'"config:$home/.hermes/config.yaml" <<< "$out" || fail "hermes config marker missing: $out"
  grep -qFx -- "candidate"$'\t'"antigravity"$'\t'"binary:$tmp/b\\tin\\x3bx/agy" <<< "$out" || fail "agy binary marker missing: $out"
  grep -qFx -- "nomarker"$'\t'"cursor" <<< "$out" || fail "cursor should have no marker: $out"
  grep -qFx -- "nomarker"$'\t'"portable" <<< "$out" || fail "portable should have no marker: $out"
  ! grep -q $'^candidate\t\\(opencode\\|commandcode\\|kimi\\)' <<< "$out" \
    || fail "skill dirs, bare cmd, or a non-executable file counted as evidence: $out"
  [[ "$(tail -n 1 <<< "$out")" == "suggested: claude,codex,hermes,antigravity" ]] || fail "wrong suggestion: $out"
  while IFS= read -r line; do
    [[ "$line" =~ ^(candidate$'\t'[a-z]+$'\t'[^$'\t']+|nomarker$'\t'[a-z]+|suggested:\ .+)$ ]] || fail "unexpected output line: $line"
  done <<< "$out"
  grep -q 'skipped PATH entry that is not absolute: (empty)' <<< "$err" || fail "empty PATH entry not reported on stderr: $err"
  grep -q 'skipped PATH entry that is not absolute: relative/dir' <<< "$err" || fail "relative PATH entry not reported: $err"
  rm -rf "$tmp"
  trap - RETURN
}

test_detect_suggests_none() {
  local tmp out
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' RETURN
  make_sys_path "$tmp/sys"
  mkdir -p "$tmp/home/.claude/skills" "$tmp/home/.agents/skills"
  out="$(isolated_path "$tmp/home" "$tmp/sys" "$ROOT/install.sh" --detect)" || fail "--detect with no markers failed"
  ! grep -q '^candidate' <<< "$out" || fail "candidates reported without markers: $out"
  [[ "$(tail -n 1 <<< "$out")" == "suggested: none" ]] || fail "expected 'suggested: none': $out"
  rm -rf "$tmp"
  trap - RETURN
}

test_detect_rejects_other_options_and_ignores_config() {
  local tmp flag out status
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' RETURN
  for flag in "--tool claude" "--dest $tmp/d" --link --list --check --migrate --apply --force --no-backup \
    --include-internal --doctor --verbose --save docker; do
    status=0
    # shellcheck disable=SC2086
    out="$(isolated "$tmp" "$ROOT/install.sh" --detect $flag 2>&1)" || status=$?
    (( status == 1 )) || fail "--detect $flag exited $status, want 1"
    grep -q -- '--detect is read-only' <<< "$out" || fail "--detect $flag refusal unclear: $out"
  done
  [[ ! -e "$tmp/d" && ! -e "$tmp/.claude" && ! -e "$tmp/.local" ]] || fail "rejected --detect changed files"

  # shellcheck disable=SC2016
  write_conf "$tmp" 'tools=$(touch pwned)'
  out="$(isolated "$tmp" CLAUDE_SKILLS_DIR="$tmp/x" "$ROOT/install.sh" --detect 2>&1)" \
    || fail "--detect read the saved config or override: $out"
  ! grep -q 'Saved install config' <<< "$out" || fail "--detect mentioned the saved config: $out"
  rm -rf "$tmp"
  trap - RETURN
}

# ── --save ────────────────────────────────────────────────────────────

test_save_round_trip_records_source() {
  local tmp home repo conf out
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' RETURN
  home="$tmp/home"
  repo="$tmp/repo"
  mkdir -p "$home/.config"
  make_fixture "$repo" true "$home"
  mkdir -m 755 "$(conf_dir "$home")"
  out="$(isolated "$home" "$repo/install.sh" --save --tool codex,claude-code,codex --link docker 2>&1)" \
    || fail "--save install failed: $out"
  conf="$(conf_dir "$home")/install.conf"
  [[ "$(mode_of "$(conf_dir "$home")")" == 0o700 && "$(mode_of "$conf")" == 0o600 ]] \
    || fail "config perms are $(mode_of "$(conf_dir "$home")")/$(mode_of "$conf"), want 0o700/0o600"
  grep -qFx "Saved install config: $conf" <<< "$out" || fail "save did not print its path: $out"
  ! grep -q 'no upstream' <<< "$out" || fail "upstream note printed for a tracking branch: $out"
  diff <(grep -v '^#' "$conf") <(printf '%s\n' version=1 tools=codex,claude link=true include_internal=false \
    skills=docker "source_repo=$repo" source_branch=main source_remote=origin "source_remote_url=$repo.origin.git" \
    source_upstream=refs/heads/main) >/dev/null || fail "unexpected config: $(cat "$conf")"
  ls "$(conf_dir "$home")"/.install.conf.* >/dev/null 2>&1 && fail "temporary config file left behind"

  rm -rf "$home/.agents" "$home/.claude"
  out="$(isolated "$home" "$repo/install.sh" 2>&1)" || fail "bare install with saved config failed: $out"
  [[ "$(head -n 1 <<< "$out")" == "Using saved install config: $conf" ]] || fail "saved config path not printed first: $out"
  [[ -d "$home/.agents/skills/docker" && -L "$home/.claude/skills/docker" && ! -e "$home/.agents/skills/git" ]] \
    || fail "bare install did not reproduce the saved link selection"
  ! grep -q 'saved from' <<< "$out" || fail "same checkout reported as different: $out"

  out="$(isolated "$home" "$repo/install.sh" --save --tool codex --include-internal 2>&1)" || fail "--save all failed: $out"
  { grep -qFx skills=all "$conf" && grep -qFx include_internal=true "$conf" \
    && grep -qFx link=false "$conf"; } || fail "all-skills save wrong: $(cat "$conf")"
  rm -rf "$tmp"
  trap - RETURN
}

test_save_without_upstream_records_empty() {
  local tmp out conf
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' RETURN
  make_fixture "$tmp/repo" false "$tmp"
  out="$(isolated "$tmp" "$tmp/repo/install.sh" --save git 2>&1)" || fail "--save without upstream failed: $out"
  conf="$(conf_dir "$tmp")/install.conf"
  { grep -qFx source_upstream= "$conf" && grep -qFx source_remote= "$conf" \
    && grep -qFx source_branch=main "$conf"; } || fail "missing upstream not recorded as empty: $(cat "$conf")"
  grep -q 'has no upstream branch; .* a later --update will refuse' <<< "$out" || fail "no upstream note: $out"
  rm -rf "$tmp"
  trap - RETURN
}

test_save_only_after_successful_install() {
  local tmp conf before
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' RETURN
  make_fixture "$tmp/repo" false "$tmp"
  conf="$(conf_dir "$tmp")/install.conf"
  if isolated "$tmp" "$tmp/repo/install.sh" --save nosuch >/dev/null 2>&1; then
    fail "--save with an unknown skill succeeded"
  fi
  [[ ! -e "$conf" ]] || fail "config written after a failed install"
  write_conf "$tmp" "$(conf_text claude docker "$tmp/repo")"
  before="$(cat "$conf")"
  isolated "$tmp" "$tmp/repo/install.sh" --save --tool codex nosuch >/dev/null 2>&1 && fail "failed install saved"
  [[ "$(cat "$conf")" == "$before" ]] || fail "failed --save replaced the existing config"
  rm -rf "$tmp"
  trap - RETURN
}

test_save_holds_lock_through_save() {
  local tmp shim saver status=0 out lock_dir holder
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' RETURN
  make_fixture "$tmp/repo" false "$tmp"
  shim="$tmp/shim"
  mkdir "$shim"
  # Source identity is read with symbolic-ref only while saving; pause there.
  printf '#!/bin/bash\nif [[ " $* " == *" symbolic-ref "* ]]; then : > "%s/saving"; sleep 3; fi\nexec "%s" "$@"\n' \
    "$tmp" "$REAL_GIT" > "$shim/git"
  chmod +x "$shim/git"
  isolated_path "$tmp" "$shim:$SAFE_PATH" "$tmp/repo/install.sh" --save docker >"$tmp/saver.log" 2>&1 &
  saver=$!
  for _ in $(seq 100); do [[ -e "$tmp/saving" ]] && break; sleep 0.1; done
  [[ -e "$tmp/saving" ]] || { wait "$saver" || true; fail "save never reached source capture: $(cat "$tmp/saver.log")"; }
  [[ ! -e "$(conf_dir "$tmp")/install.conf" ]] || fail "config written before source capture"
  out="$(isolated "$tmp" SKILLS_LOCK_WAIT=0 "$tmp/repo/install.sh" --tool portable --dest "$tmp/other" docker 2>&1)" || status=$?
  wait "$saver" || fail "--save failed: $(cat "$tmp/saver.log")"
  (( status == 3 )) || fail "contender during save exited $status, want 3: $out"
  [[ ! -e "$tmp/other" ]] || fail "contender installed while --save held the lock"
  [[ -f "$(conf_dir "$tmp")/install.conf" ]] || fail "--save did not write the config"

  lock_dir="$tmp/.local/state/iuliandita-skills"
  ( exec 8>>"$lock_dir/install.lock"; flock 8; touch "$tmp/held"; exec sleep 30 ) &
  holder=$!
  for _ in $(seq 100); do [[ -e "$tmp/held" ]] && break; sleep 0.1; done
  rm -rf "$tmp/.claude" "$(conf_dir "$tmp")"
  status=0
  out="$(isolated "$tmp" SKILLS_LOCK_WAIT=1 "$tmp/repo/install.sh" --save docker 2>&1)" || status=$?
  kill "$holder"
  wait "$holder" 2>/dev/null || true
  (( status == 3 )) || fail "--save under a held lock exited $status, want 3: $out"
  [[ ! -e "$tmp/.claude" && ! -e "$(conf_dir "$tmp")/install.conf" ]] || fail "--save acted without the lock"
  rm -rf "$tmp"
  trap - RETURN
}

test_save_refusals() {
  local tmp out status var dir file
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' RETURN
  make_fixture "$tmp/repo" false "$tmp"
  status=0
  out="$(isolated "$tmp" "$tmp/repo/install.sh" --save --tool portable --dest "$tmp/d" docker 2>&1)" || status=$?
  { (( status == 1 )) && grep -q -- '--save cannot be used with --dest' <<< "$out"; } || fail "--save --dest: $status $out"
  for flag in --check --list --migrate --doctor; do
    status=0
    out="$(isolated "$tmp" "$tmp/repo/install.sh" --save "$flag" 2>&1)" || status=$?
    { (( status == 1 )) && grep -q -- '--save applies only to installs' <<< "$out"; } || fail "--save $flag: $status $out"
  done
  for var in "${OVERRIDES[@]}"; do
    status=0
    out="$(isolated "$tmp" "$var=$tmp/o" "$tmp/repo/install.sh" --save docker 2>&1)" || status=$?
    { (( status == 2 )) && grep -q -- "--save: $var is set" <<< "$out"; } || fail "--save with $var: $status $out"
  done
  [[ ! -e "$tmp/d" && ! -e "$tmp/o" && ! -e "$tmp/.claude" && ! -e "$(conf_dir "$tmp")" ]] \
    || fail "a refused --save changed files"

  mkdir "$tmp/no-flock"
  for dir in ${SAFE_PATH//:/ }; do
    for file in "$dir"/*; do
      [[ "${file##*/}" == flock || -e "$tmp/no-flock/${file##*/}" || -L "$tmp/no-flock/${file##*/}" ]] \
        || ln -s "$file" "$tmp/no-flock/${file##*/}"
    done
  done
  status=0
  out="$(isolated_path "$tmp" "$tmp/no-flock" "$tmp/repo/install.sh" --save docker 2>&1)" || status=$?
  { (( status == 10 )) && grep -q 'flock (util-linux) is required' <<< "$out"; } || fail "--save without flock: $status $out"
  [[ ! -e "$tmp/.claude" && ! -e "$(conf_dir "$tmp")" ]] || fail "--save without flock changed files"

  if (( $(id -u) != 0 )); then
    mkdir -m 555 "$tmp/ro"
    status=0
    out="$(isolated "$tmp" XDG_CONFIG_HOME="$tmp/ro/cfg" "$tmp/repo/install.sh" --save docker 2>&1)" || status=$?
    chmod 755 "$tmp/ro"
    { (( status == 7 )) && grep -q 'cannot create' <<< "$out"; } || fail "unwritable config dir: $status $out"
    [[ ! -e "$tmp/.claude" ]] || fail "--save installed although the config dir cannot be created"
  fi
  rm -rf "$tmp"
  trap - RETURN
}

# ── Loading ───────────────────────────────────────────────────────────

# Run a bare install against a config and expect exit 2 with $3 in stderr.
expect_rejected() {
  local tmp="$1" label="$2" pattern="$3" status=0 out
  out="$(isolated "$tmp" "$tmp/repo/install.sh" 2>&1)" || status=$?
  (( status == 2 )) || fail "$label: exited $status, want 2: $out"
  grep -q -- "$pattern" <<< "$out" || fail "$label: message lacks '$pattern': $out"
  [[ ! -e "$tmp/pwned" ]] || fail "$label: config content was executed"
  [[ ! -e "$tmp/.claude/skills" && ! -e "$tmp/.agents" ]] || fail "$label: rejected config still installed"
}

test_invalid_configs_are_rejected_unexecuted() {
  local tmp good dir
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' RETURN
  make_fixture "$tmp/repo" false "$tmp"
  good="$(conf_text claude docker "$tmp/repo")"$'\n'
  dir="$(conf_dir "$tmp")"

  write_conf "$tmp" "${good/tools=claude/tools=\$(touch $tmp/pwned)}"
  expect_rejected "$tmp" "command substitution in tools" "invalid tool name"
  write_conf "$tmp" "${good/skills=docker/skills=\`touch $tmp/pwned\`}"
  expect_rejected "$tmp" "backticks in skills" "invalid skill name"
  write_conf "$tmp" "$good"$'tools=codex\n'
  expect_rejected "$tmp" "duplicate key" "repeats key 'tools'"
  write_conf "$tmp" "${good/link=false$'\n'/}"
  expect_rejected "$tmp" "missing key" "missing key(s): link"
  write_conf "$tmp" "$good"$'dest=/tmp/x\n'
  expect_rejected "$tmp" "unknown key" "unknown key 'dest'"
  write_conf "$tmp" "${good/source_branch=main/source_branch=main$'\x1b'[31m}"
  expect_rejected "$tmp" "escape character" "contains a control character"
  write_conf "$tmp" "${good/tools=claude/tools=claude$'\r'}"
  expect_rejected "$tmp" "carriage return" "contains a control character"
  write_conf "$tmp" "${good/link=false/link=yes}"
  expect_rejected "$tmp" "bad boolean" "link must be true or false"
  write_conf "$tmp" "${good/include_internal=false/include_internal=True}"
  expect_rejected "$tmp" "capitalized boolean" "include_internal must be true or false"
  write_conf "$tmp" "${good/tools=claude/tools=notatool}"
  expect_rejected "$tmp" "unknown tool" "unknown tool 'notatool'"
  write_conf "$tmp" "${good/version=1/version=2}"
  expect_rejected "$tmp" "version" "unsupported version"
  write_conf "$tmp" "${good/tools=claude/tools claude}"
  expect_rejected "$tmp" "no equals sign" "is not key=value"

  write_conf "$tmp" "$good"
  mv "$dir/install.conf" "$tmp/real.conf"
  ln -s "$tmp/real.conf" "$dir/install.conf"
  expect_rejected "$tmp" "symlinked file" "is a symlink"
  rm "$dir/install.conf"

  write_conf "$tmp" "$good"
  chmod 620 "$dir/install.conf"
  expect_rejected "$tmp" "group-writable file" "the file is group- or world-writable"
  chmod 600 "$dir/install.conf"
  chmod 770 "$dir"
  expect_rejected "$tmp" "group-writable dir" "$dir is group- or world-writable"
  chmod 700 "$dir"

  mv "$dir" "$tmp/real-dir"
  ln -s "$tmp/real-dir" "$dir"
  expect_rejected "$tmp" "symlinked dir" "is a symlink or not a directory"
  rm "$dir"
  mv "$tmp/real-dir" "$dir"

  rm "$dir/install.conf"
  mkfifo "$dir/install.conf"
  expect_rejected "$tmp" "fifo" "is not a regular file"
  rm "$dir/install.conf"

  if (( $(id -u) != 0 )); then
    write_conf "$tmp" "$good"
    chmod 000 "$dir"
    local status=0 out
    out="$(isolated "$tmp" "$tmp/repo/install.sh" 2>&1)" || status=$?
    chmod 700 "$dir"
    { (( status == 7 )) && grep -q 'cannot open' <<< "$out"; } || fail "unreadable config dir: $status $out"
  fi

  # Accepted values are data too: a path holding shell syntax is never run.
  write_conf "$tmp" "$(conf_text claude docker "/x\$(touch $tmp/pwned);touch $tmp/pwned")"
  isolated "$tmp" "$tmp/repo/install.sh" >/dev/null 2>&1 || fail "config with a shell-looking source_repo was refused"
  [[ ! -e "$tmp/pwned" && -d "$tmp/.claude/skills/docker" ]] || fail "shell-looking value ran or install skipped"
  rm -rf "$tmp"
  trap - RETURN
}

test_saved_config_rejects_override_env() {
  local tmp var status out
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' RETURN
  make_fixture "$tmp/repo" false "$tmp"
  write_conf "$tmp" "$(conf_text claude docker "$tmp/repo")"
  for var in "${OVERRIDES[@]}"; do
    status=0
    out="$(isolated "$tmp" "$var=$tmp/o" "$tmp/repo/install.sh" 2>&1)" || status=$?
    { (( status == 2 )) && grep -q "$var is set" <<< "$out"; } || fail "saved config with $var: $status $out"
    [[ ! -e "$tmp/o" && ! -e "$tmp/.claude" ]] || fail "saved config with $var installed"
  done
  rm "$(conf_dir "$tmp")/install.conf"
  isolated "$tmp" CLAUDE_SKILLS_DIR="$tmp/o" "$tmp/repo/install.sh" docker >/dev/null \
    || fail "override without a saved config was refused"
  [[ -d "$tmp/o/docker" ]] || fail "override without a saved config was not honored"
  rm -rf "$tmp"
  trap - RETURN
}

test_explicit_options_ignore_saved_config() {
  local tmp args out
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' RETURN
  make_fixture "$tmp/repo" false "$tmp"
  # Unparseable on purpose: any read of it would fail the run.
  # shellcheck disable=SC2016
  write_conf "$tmp" 'tools=$(touch pwned)'
  for args in "--tool claude git" "git" "--force" "--no-backup" "--include-internal" "--link" \
    "--tool portable --dest $tmp/dest docker"; do
    # shellcheck disable=SC2086
    out="$(isolated "$tmp" "$tmp/repo/install.sh" $args 2>&1)" || fail "install.sh $args read the saved config: $out"
    ! grep -q 'install config' <<< "$out" || fail "install.sh $args mentioned the saved config: $out"
  done
  isolated "$tmp" "$tmp/repo/install.sh" --tool claude --force >/dev/null || fail "install before --check failed"
  for args in --check --list --doctor --migrate "--migrate --apply" --detect; do
    # shellcheck disable=SC2086
    out="$(isolated "$tmp" "$tmp/repo/install.sh" $args 2>&1)" || fail "install.sh $args failed with a saved config: $out"
    ! grep -q 'install config' <<< "$out" || fail "install.sh $args read the saved config: $out"
  done
  [[ ! -e "$tmp/pwned" ]] || fail "saved config was executed"

  rm -rf "$tmp/.claude" "$tmp/.agents"
  write_conf "$tmp" "$(conf_text codex docker "$tmp/repo")"
  isolated "$tmp" "$tmp/repo/install.sh" --tool claude git >/dev/null || fail "explicit install failed"
  [[ -d "$tmp/.claude/skills/git" && ! -e "$tmp/.agents" ]] || fail "explicit --tool merged with the saved config"
  isolated "$tmp" "$tmp/repo/install.sh" >/dev/null || fail "bare install failed"
  [[ -d "$tmp/.agents/skills/docker" && ! -e "$tmp/.agents/skills/git" ]] || fail "bare install ignored the saved config"
  rm -rf "$tmp"
  trap - RETURN
}

test_saved_config_from_other_checkout_is_noted() {
  local tmp out
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' RETURN
  make_fixture "$tmp/repo" false "$tmp"
  write_conf "$tmp" "$(conf_text claude docker /elsewhere)"
  out="$(isolated "$tmp" "$tmp/repo/install.sh" 2>&1)" || fail "bare install failed: $out"
  grep -q 'the config was saved from /elsewhere; installing from' <<< "$out" || fail "checkout mismatch not noted: $out"
  rm -rf "$tmp"
  trap - RETURN
}

test_detect_reports_candidates_without_running_anything
test_detect_suggests_none
test_detect_rejects_other_options_and_ignores_config
test_save_round_trip_records_source
test_save_without_upstream_records_empty
test_save_only_after_successful_install
test_save_holds_lock_through_save
test_save_refusals
test_invalid_configs_are_rejected_unexecuted
test_saved_config_rejects_override_env
test_explicit_options_ignore_saved_config
test_saved_config_from_other_checkout_is_noted

printf 'setup tests passed\n'
