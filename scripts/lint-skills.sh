#!/usr/bin/env bash
# shellcheck disable=SC2016,SC1091
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/skill-lib.sh"

# Lint all skills in the collection for common issues.
# Runs in CI and locally. Exit 0 = clean, exit 1 = issues found.
# SC2016: grep patterns use single-quoted backticks intentionally.

SKILLS_DIR="${1:-skills}"
errors=0
warnings=0

error() { echo "  ERROR: $1"; (( errors++ )) || true; }
warn()  { echo "  WARN:  $1"; (( warnings++ )) || true; }

# Private skills: present locally (gitignored) but must not be referenced
# by public skills. They can reference public skills freely.
PRIVATE_SKILLS=()

# ── Private skill reference check ──────────────────────────────────────
check_private_refs() {
  local dir="$1" name="$2"
  for priv in "${PRIVATE_SKILLS[@]}"; do
    [[ "$name" == "$priv" ]] && continue  # private skill can reference itself
    for f in "$dir"/SKILL.md "$dir"/references/*.md; do
      [[ -f "$f" ]] || continue
      if grep -q "\\b${priv}\\b" "$f" 2>/dev/null; then
        error "$name: references private skill '$priv' in $(basename "$f") (public skills must not reference private skills)"
      fi
    done
  done
}

# ── Frontmatter checks ─────────────────────────────────────────────────
check_frontmatter() {
  local file="$1" name="$2"
  if ! frontmatter_valid "$file"; then
    error "$name: invalid YAML frontmatter"
    return
  fi

  # Required top-level fields (Agent Skills spec)
  for field in name description license; do
    if ! frontmatter_has "$file" "$field"; then
      error "$name: missing frontmatter field '$field'"
    fi
  done

  # Required metadata fields (custom, nested under metadata:)
  if ! frontmatter_has "$file" "metadata"; then
    error "$name: missing 'metadata:' block"
  fi
  for field in source date_added effort; do
    if ! frontmatter_has "$file" "metadata.$field"; then
      error "$name: missing metadata field '$field'"
    fi
  done

  local src
  src="$(frontmatter_get "$file" "metadata.source" 2>/dev/null || true)"
  if [[ -z "$src" ]]; then
    error "$name: metadata.source is empty"
  elif [[ "$src" != "custom" && ! "$src" =~ ^[a-zA-Z0-9._-]+/[a-zA-Z0-9._-]+$ ]]; then
    error "$name: metadata.source must be 'custom' or 'owner/repo' format, got '$src'"
  fi

  local eff
  eff="$(frontmatter_get "$file" "metadata.effort" 2>/dev/null || true)"
  if [[ "$eff" != "low" && "$eff" != "medium" && "$eff" != "high" ]]; then
    error "$name: metadata.effort must be low/medium/high, got '$eff'"
  fi

  # Optional: metadata.argument_hint (string, max 100 chars)
  local arg_hint
  arg_hint="$(frontmatter_get "$file" "metadata.argument_hint" 2>/dev/null || true)"
  if [[ -n "$arg_hint" && ${#arg_hint} -gt 100 ]]; then
    error "$name: metadata.argument_hint exceeds 100 characters"
  fi

  # Optional: metadata.internal ("true" or "false" string)
  local internal
  internal="$(frontmatter_get "$file" "metadata.internal" 2>/dev/null || true)"
  if [[ -n "$internal" && "$internal" != "true" && "$internal" != "false" ]]; then
    error "$name: metadata.internal must be true or false, got '$internal'"
  fi

  # Validate name matches directory (Agent Skills spec requirement)
  frontmatter_name_matches_dir "$file" "$name" error
}

# ── Section checks ──────────────────────────────────────────────────────
check_sections() {
  local file="$1" name="$2"
  for section in "When to use" "When NOT to use" "Workflow" "Rules"; do
    if ! grep -qi "^## .*${section}" "$file"; then
      error "$name: missing '## $section' section"
    fi
  done
}

# ── ASCII checks ────────────────────────────────────────────────────────
# Approved non-ASCII: middle dot and the emoji status indicators.
ASCII_ALLOWED='\x{00B7}\x{1F534}\x{1F7E0}\x{1F7E2}\x{1F7E1}\x{1F535}\x{26AA}\x{26A1}\x{1F3AF}\x{1F480}'

check_ascii() {
  local file="$1" name="$2"
  local bad_lines
  bad_lines=$(grep -Pn '[^\x00-\x7F]' "$file" 2>/dev/null || true)
  if [[ -n "$bad_lines" ]]; then
    while IFS= read -r line; do
      # Strip allowed emoji status indicators, then check for remaining non-ASCII
      local stripped
      stripped=$(echo "$line" | ALLOWED="$ASCII_ALLOWED" perl -CSD -pe 's/[$ENV{ALLOWED}]//g' 2>/dev/null || echo "$line")
      if echo "$stripped" | grep -Pq '[^\x00-\x7F]' 2>/dev/null; then
        error "$name: non-ASCII character at $line"
      fi
    done <<< "$bad_lines"
  fi
}

# References: same rule, but fenced blocks and inline code spans may show
# literal characters (e.g. locale examples).
check_ascii_refs() {
  local dir="$1" name="$2" refs=() f hit
  for f in "$dir"/references/*.md; do
    [[ -f "$f" ]] && refs+=("$f")
  done
  (( ${#refs[@]} )) || return 0
  while IFS= read -r hit; do
    [[ -n "$hit" ]] && error "$name: non-ASCII character at ${hit#"$dir"/}"
  done < <(ALLOWED="$ASCII_ALLOWED" perl -CSD -ne '
    if (/^\s*(```|~~~)/) { $fence = !$fence }
    elsif (!$fence) {
      (my $s = $_) =~ s/(`+).*?\1//g;
      $s =~ s/[$ENV{ALLOWED}]//g;
      if ($s =~ /[^\x00-\x7F]/) { chomp; print "$ARGV:$.:$_\n" }
    }
    if (eof) { $fence = 0; close ARGV }
  ' "${refs[@]}")
}

# ── Line count check ───────────────────────────────────────────────────
check_length() {
  local file="$1" name="$2"
  local lines
  lines=$(wc -l < "$file")
  local warn_msg="$name: SKILL.md is $lines lines (near the 500 hard max; extract to references/)"
  skill_length_check "$file" "$name" error warn "$warn_msg"

  # Activation size: spec guidance keeps the body under ~5000 tokens.
  # Estimate tokens as chars/4 of the body after frontmatter. Advisory only.
  local body_bytes body_tokens
  body_bytes=$(awk 'n>=2; /^---$/ && n<2 {n++}' "$file" | wc -c)
  body_tokens=$(( body_bytes / 4 ))
  if (( body_tokens > 5000 )); then
    warn "$name: SKILL.md body is ~$body_tokens tokens (spec guidance ~5000; move detail to references/)"
  fi
}

# ── Reference file checks ──────────────────────────────────────────────
check_references() {
  local file="$1" name="$2" dir="$3"
  # Check that referenced files exist (only in own references/ dir).
  # Scan SKILL.md and references/*.md, but ignore fenced examples.
  local source_files=("$file")
  for ref_file in "$dir"/references/*.md; do
    [[ -f "$ref_file" ]] && source_files+=("$ref_file")
  done

  local source line_no line refs ref rel_source
  for source in "${source_files[@]}"; do
    rel_source="${source#"$dir"/}"
    while IFS=$'\t' read -r line_no line; do
      # Most lines have no reference; skip them without forking grep and sed.
      [[ "$line" == *'`references/'* ]] || continue
      refs=$(grep -oP '`references/[^`]+`' <<< "$line" | sed "s/\`//g" || true)
      for ref in $refs; do
        # Skip template placeholders.
        [[ "$ref" == *"<"* ]] && continue
        if [[ ! -f "$dir/$ref" ]]; then
          # Cross-skill reference escape hatch: accept the missing path only if a
          # bolded token on this line names a sibling skill that DOES contain the
          # referenced file. A bare bold word no longer suppresses the error.
          local skills_root resolved=false bold
          skills_root="$(dirname "$dir")"
          while IFS= read -r bold; do
            [[ -z "$bold" ]] && continue
            if [[ -f "$skills_root/$bold/$ref" ]]; then
              resolved=true
              break
            fi
          done < <(grep -oP '\*\*\K[a-z][-a-z0-9]+(?=\*\*)' <<< "$line" || true)
          if [[ "$resolved" != true ]]; then
            error "$name: referenced file '$ref' does not exist in $rel_source:$line_no"
          fi
        fi
      done
    done < <(awk '/^```/{skip=!skip; next} !skip{print NR "\t" $0}' "$source")
  done
}

# ── Reference depth and contents lists ─────────────────────────────────
# Agents may read a reference reached through another reference only partially,
# so every reference file must be named directly in SKILL.md (one level deep).
check_reference_depth() {
  local file="$1" name="$2" dir="$3" ref_file base
  for ref_file in "$dir"/references/*.md; do
    [[ -f "$ref_file" ]] || continue
    base="$(basename "$ref_file")"
    if ! grep -qF "references/$base" "$file"; then
      error "$name: references/$base is not linked from SKILL.md (keep references one level deep)"
    fi
  done
}

# Long references need a contents list near the top so a partial read still sees
# their full scope. scripts/gen-ref-toc.py owns the generated lists.
check_reference_toc() {
  local name="$1" dir="$2" line out rc=0
  [[ -d "$dir/references" ]] || return 0
  out="$(python3 "$SCRIPT_DIR/gen-ref-toc.py" --check "${dir%/}")" || rc=$?
  if (( rc == 1 )) && [[ -n "$out" ]]; then
    while IFS= read -r line; do
      [[ -n "$line" ]] && error "$name: ${line#"$dir"/}"
    done <<< "$out"
  elif (( rc != 0 )); then
    error "$name: gen-ref-toc.py --check failed (rc=$rc)"
  fi
}

# ── Banned word check (warning only) ──────────────────────────────────
BANNED_WORDS=(delve tapestry nuanced multifaceted utilize commence facilitate synergy leverage holistic empower seamless innovative)

BANNED_WORDS_RE="\\b($(IFS='|'; echo "${BANNED_WORDS[*]}"))\\b"

check_banned_words() {
  local dir="$1" name="$2"
  # anti-ai-prose is the meta-reference for AI prose tells and must name them.
  [[ "$name" == "anti-ai-prose" ]] && return 0
  local f basename_f word hit
  local -A found
  for f in "$dir"/SKILL.md "$dir"/references/*.md; do
    [[ -f "$f" ]] || continue
    basename_f="${f##*/}"
    # skill-creator's conventions.md lists the banned vocabulary.
    [[ "$basename_f" == "conventions.md" ]] && continue
    # One grep per file finds every banned word outside fenced code blocks
    # (word-boundary, case-insensitive); warnings keep BANNED_WORDS order.
    found=()
    while IFS= read -r hit; do
      found["${hit,,}"]=1
    done < <(awk '/^```/{skip=!skip; next} !skip' "$f" | grep -oiE "$BANNED_WORDS_RE" || true)
    for word in "${BANNED_WORDS[@]}"; do
      [[ -n "${found[$word]:-}" ]] && warn "$name: banned word '$word' in $basename_f"
    done
  done
  return 0
}

# ── Prose double-dash check ────────────────────────────────────────────
# Enforces an existing convention (skill-creator Rules / conventions Section 4):
# ' -- ' must not be used as an em-dash substitute in prose. It IS allowed inside
# code - fenced blocks and inline-code spans (shell end-of-options separators like
# `git ls-files -- path` or `npm test -- --filter`). This rule had no automated
# guard, so the dash substitute kept slipping into prose across skills.
check_prose_double_dash() {
  local dir="$1" name="$2"
  local f basename_f matches m
  for f in "$dir"/SKILL.md "$dir"/references/*.md; do
    [[ -f "$f" ]] || continue
    basename_f=$(basename "$f")
    # Skip fenced code blocks; strip inline-code spans; then look for ' -- '.
    matches=$(awk '/^```/{skip=!skip; next} !skip{print NR": "$0}' "$f" \
      | sed 's/`[^`]*`//g' \
      | grep -E ' -- ' || true)
    if [[ -n "$matches" ]]; then
      while IFS= read -r m; do
        [[ -n "$m" ]] && error "$name: ' -- ' double-dash in prose in $basename_f (use '-' or rephrase): $m"
      done <<< "$matches"
    fi
  done
}

# ── ERE literal-pipe check ─────────────────────────────────────────────
# grep -E, egrep, rg, pgrep, and pkill use extended regular expressions,
# where '|' is alternation and '\|' inside a quoted pattern matches a literal
# pipe. A stray '\|' in one of those patterns silently matches nothing.
# Scan fenced command examples (indented fences included), split commands on
# unquoted '|', ';', and '&&', and ignore BRE grep and fixed-string modes.
# sed -E and awk are outside this check.
check_ere_literal_pipe() {
  local dir="$1" name="$2" f line_no
  for f in "$dir"/SKILL.md "$dir"/references/*.md; do
    [[ -f "$f" ]] || continue
    while IFS= read -r line_no; do
      [[ -n "$line_no" ]] || continue
      error "$name: '\\|' inside an ERE pattern in $(basename "$f"):$line_no (use '|' for alternation)"
    done < <(python3 - "$f" <<'PY'
import re
import shlex
import sys

ERE_COMMANDS = {"grep", "egrep", "rg", "pgrep", "pkill"}
SEPARATORS = {"|", ";", "&&", "||", "&"}
PREFIXES = {"sudo", "doas", "command", "time", "nohup", "nice"}
KEYWORDS = {"if", "then", "elif", "else", "while", "until", "do", "done", "fi", "esac", "!", "("}


def split_segments(tokens):
    segments = []
    current = []
    for token in tokens:
        if token in SEPARATORS:
            if current:
                segments.append(current)
            current = []
        else:
            current.append(token)
    if current:
        segments.append(current)
    return segments


def command_start(tokens):
    i = 0
    while i < len(tokens):
        token = tokens[i]
        if token in {"$", ">"}:
            i += 1
            continue
        if token == "#":
            return len(tokens)
        if token in KEYWORDS or re.match(r"^[A-Za-z_][A-Za-z0-9_]*=", token):
            i += 1
            continue
        if token in PREFIXES:
            i += 1
            while i < len(tokens) and tokens[i].startswith("-"):
                i += 1
            continue
        if token == "env":
            i += 1
            while i < len(tokens) and (
                tokens[i].startswith("-") or re.match(r"^[A-Za-z_][A-Za-z0-9_]*=", tokens[i])
            ):
                i += 1
            continue
        if token == "xargs":
            i += 1
            while i < len(tokens) and tokens[i].startswith("-"):
                i += 1
            continue
        break
    return i


def has_literal_pipe(pattern):
    i = 0
    while i < len(pattern):
        if pattern[i] != "\\":
            i += 1
            continue
        count = 0
        while i < len(pattern) and pattern[i] == "\\":
            count += 1
            i += 1
        if i < len(pattern) and pattern[i] == "|" and count % 2 == 1:
            return True
    return False


def find_patterns(command, args):
    extended = command in {"egrep", "rg", "pgrep", "pkill"}
    fixed = False
    regexp_patterns = []
    operands = []
    has_regexp = False
    has_pattern_file = False
    end_of_options = False
    i = 0
    while i < len(args):
        token = args[i]
        if not end_of_options and token == "--":
            end_of_options = True
            i += 1
            continue
        if not end_of_options and token.startswith("--"):
            name, eq, value = token.partition("=")
            if name == "--extended-regexp":
                extended, fixed = True, False
            elif name == "--perl-regexp":
                extended, fixed = True, False
            elif name == "--basic-regexp":
                extended, fixed = False, False
            elif name == "--fixed-strings":
                fixed, extended = True, False
            elif name == "--regexp":
                has_regexp = True
                if eq:
                    regexp_patterns.append(value)
                elif i + 1 < len(args):
                    regexp_patterns.append(args[i + 1])
                    i += 1
            elif name == "--file" and command in {"grep", "rg"}:
                has_pattern_file = True
                if not eq and i + 1 < len(args):
                    i += 1
            i += 1
            continue
        if not end_of_options and token.startswith("-") and token != "-":
            cluster = token[1:]
            j = 0
            while j < len(cluster):
                flag = cluster[j]
                if flag == "E" and command == "grep":
                    extended, fixed = True, False
                elif flag == "P" and command == "grep":
                    extended, fixed = True, False
                elif flag == "G" and command == "grep":
                    extended, fixed = False, False
                elif flag == "F" and command in {"grep", "rg"}:
                    fixed, extended = True, False
                elif flag == "e" and command in {"grep", "rg"}:
                    has_regexp = True
                    rest = cluster[j + 1 :]
                    if rest:
                        regexp_patterns.append(rest)
                    elif i + 1 < len(args):
                        regexp_patterns.append(args[i + 1])
                        i += 1
                    j = len(cluster)
                    break
                elif flag == "f" and command in {"grep", "rg"}:
                    has_pattern_file = True
                    j = len(cluster)
                    break
                j += 1
            i += 1
            continue
        operands.append(token)
        i += 1
    if fixed:
        return [], False
    if has_regexp:
        return regexp_patterns, extended
    if has_pattern_file and command in {"grep", "rg"}:
        return [], False
    return operands, extended


def scan_line(line):
    try:
        lexer = shlex.shlex(line, posix=True, punctuation_chars=True)
        lexer.whitespace_split = True
        tokens = list(lexer)
    except ValueError:
        return False
    for segment in split_segments(tokens):
        start = command_start(segment)
        if start >= len(segment):
            continue
        command = segment[start]
        if command not in ERE_COMMANDS:
            continue
        patterns, match_as_ere = find_patterns(command, segment[start + 1 :])
        if match_as_ere and any(has_literal_pipe(pattern) for pattern in patterns):
            return True
    return False


def main(path):
    fence = None
    buffer = ""
    start_line = 0
    with open(path, encoding="utf-8", errors="replace") as handle:
        for number, raw in enumerate(handle, 1):
            line = raw.rstrip("\n")
            if fence is None:
                match = re.match(r"^\s*(`{3,}|~{3,})", line)
                if match:
                    fence = match.group(1)
                continue
            closing = re.match(r"^\s*(`{3,}|~{3,})\s*$", line)
            if closing and closing.group(1)[0] == fence[0] and len(closing.group(1)) >= len(fence):
                if buffer and scan_line(buffer):
                    print(start_line)
                fence = None
                buffer = ""
                continue
            if buffer:
                buffer = (
                    (buffer[:-1] + " " + line.strip()).rstrip()
                    if buffer.endswith("\\")
                    else (buffer + " " + line.strip()).rstrip()
                )
                if not buffer.endswith("\\"):
                    if scan_line(buffer):
                        print(start_line)
                    buffer = ""
                continue
            if line.rstrip().endswith("\\"):
                buffer = line.rstrip()[:-1] + " "
                start_line = number
                continue
            if scan_line(line):
                print(number)
        if buffer and scan_line(buffer):
            print(start_line)


if __name__ == "__main__":
    main(sys.argv[1])
PY
)
  done
}

# Descriptions begin with useful task language, not collection decoration.
check_desc_prefix() {
  local file="$1" name="$2" desc
  desc="$(frontmatter_get "$file" "description" 2>/dev/null || true)"
  if [[ "$desc" == "· "* ]]; then
    error "$name: description must start with the task, without a decorative prefix"
  fi
}

# ── AI Self-Check section check ────────────────────────────────────────
check_ai_self_check() {
  local file="$1" name="$2"
  local effort
  effort="$(frontmatter_get "$file" "metadata.effort" 2>/dev/null || true)"
  if [[ "$effort" == "high" ]]; then
    if ! grep -qi '^## .*Self.Check' "$file"; then
      warn "$name: high-effort skill without 'AI Self-Check' section (recommended for skills that generate output)"
    fi
  fi
}

# ── Generic self-check ratio check ──────────────────────────────────────
# The five items below (full canonical text, not just the bold label) were
# bulk-injected by an automated skill-scoring pass into nearly every skill.
# They now live once, shared, at skills/_shared/agent-hygiene.md. A skill's
# own '## AI Self-Check' section should be dominated by hand-written,
# skill-specific checks; cap how much of it can still be this generic
# boilerplate.
#
# Match on the full item text, not the bold label: an item that reuses a
# label like "Routing overlap checked" with its own hand-written body (e.g.
# synology-dsm's DSM-specific checks) is authored content, not injected
# filler, and must not be flagged.
#
# skill-refiner and skill-creator are exempt only because verification is their domain; phase-1 changes to this list remain subject to scripts/check-refiner-phase1-guard.sh, not self-enforced.
GENERIC_SELF_CHECK_ITEMS=(
  '- [ ] **Current source checked**: dated versions, CLI flags, API names, and support windows are verified against primary docs before repeating them'
  '- [ ] **Hidden state identified**: local config, credentials, caches, contexts, branches, cluster targets, or previous runs are made explicit before acting'
  '- [ ] **Verification is real**: final checks exercise the actual runtime, parser, service, or integration point instead of only linting prose or happy paths'
  '- [ ] **Routing overlap checked**: overlapping skills, trigger terms, and "When NOT to use" boundaries are checked before returning guidance'
  '- [ ] **Spec claims verified**: claims about tool behavior, output contracts, or repo conventions are checked against current docs, scripts, or skill files'
)
GENERIC_SELF_CHECK_EXEMPT=("skill-refiner" "skill-creator")
GENERIC_SELF_CHECK_MAX_RATIO=10  # percent

check_generic_self_check_ratio() {
  local file="$1" name="$2"
  local exempt
  for exempt in "${GENERIC_SELF_CHECK_EXEMPT[@]}"; do
    [[ "$name" == "$exempt" ]] && return
  done

  local section
  section="$(awk '/^## AI Self-Check/{f=1; next} /^## /{f=0} f' "$file")"
  [[ -z "$section" ]] && return

  local total generic canonical_item line
  total=$(grep -c '^- \[ \]' <<< "$section" || true)
  (( total == 0 )) && return

  generic=0
  while IFS= read -r line; do
    # Normalize leading/trailing whitespace only - no other fuzzy matching.
    line="$(sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' <<< "$line")"
    for canonical_item in "${GENERIC_SELF_CHECK_ITEMS[@]}"; do
      if [[ "$line" == "$canonical_item" ]]; then
        (( generic++ )) || true
        break
      fi
    done
  done <<< "$(grep '^- \[ \]' <<< "$section")"

  local ratio=$(( generic * 100 / total ))
  if (( ratio > GENERIC_SELF_CHECK_MAX_RATIO )); then
    error "$name: AI Self-Check section is ${ratio}% generic boilerplate ($generic/$total items) - exceeds ${GENERIC_SELF_CHECK_MAX_RATIO}% cap, replace with skill-specific checks"
  fi
}

# ── Collection-wide symlink check ──────────────────────────────────────
# Reject committed symlinks under skills/. install.sh's skill_hash uses
# `find` without -L so symlinks are no longer followed, but a committed
# symlink would still confuse downstream tooling.
check_no_symlinks() {
  local dir="$1"
  local found
  found="$(find "$dir" -type l -print 2>/dev/null || true)"
  if [[ -n "$found" ]]; then
    while IFS= read -r link; do
      error "symlink committed under $dir: $link (skills must contain only regular files)"
    done <<< "$found"
  fi
}

# A collection that ships skill-refiner's canonical behavioral catalog must
# keep exactly one section for every public skill. Smaller or unrelated
# collections without that catalog are unaffected.
check_canonical_test_coverage() {
  local catalog="$SKILLS_DIR/skill-refiner/references/test-cases.md"
  [[ -f "$catalog" ]] || return 0

  local skill_dir name heading kind
  declare -A public_skills=()
  declare -A heading_counts=()
  declare -A test_counts=()
  declare -A prompt_counts=()

  for skill_dir in "$SKILLS_DIR"/*/; do
    name=$(basename "$skill_dir")
    [[ "$name" == ".backups" || "$name" == ".cook" ]] && continue
    [[ "$name" == _* ]] && continue
    git check-ignore -q "$skill_dir" 2>/dev/null && continue
    [[ -f "$skill_dir/SKILL.md" ]] || continue
    public_skills["$name"]=1
  done

  while IFS=$'\t' read -r kind heading; do
    case "$kind" in
      H)
        [[ "$heading" == "<skill-name>" ]] && continue
        (( heading_counts["$heading"]++ )) || true
        ;;
      T)
        [[ -n "$heading" ]] || continue
        (( test_counts["$heading"]++ )) || true
        ;;
      P)
        [[ -n "$heading" ]] || continue
        (( prompt_counts["$heading"]++ )) || true
        ;;
    esac
  done < <(
    awk '
      function marker_length(value, marker, count) {
        marker = substr(value, 1, 1)
        count = 0
        while (substr(value, count + 1, 1) == marker) count++
        return count
      }
      {
        line = $0
        sub(/^[[:space:]]*/, "", line)

        marker = substr(line, 1, 3)
        if (marker == "```" || marker == "~~~") {
          current_marker = substr(marker, 1, 1)
          current_length = marker_length(line)
          if (fence == "") {
            fence = current_marker
            fence_length = current_length
          } else if (fence == current_marker && current_length >= fence_length) {
            fence = ""
            fence_length = 0
          }
          next
        }
        if (fence != "") next

        if (line ~ /^## Test Cases[[:space:]]*$/) {
          in_cases = 1
          next
        }
        if (line ~ /^## [^#]/) {
          in_cases = 0
          next
        }
        if (in_cases && line ~ /^### /) {
          heading = substr(line, 5)
          sub(/[[:space:]]*$/, "", heading)
          print "H\t" heading
          next
        }
        if (in_cases) {
          if (line ~ /^\*\*Test /) { print "T\t" heading; next }
          if (line ~ /^Prompt:/) { print "P\t" heading; next }
        }
      }
    ' "$catalog"
  )

  for name in "${!public_skills[@]}"; do
    if [[ -z "${heading_counts[$name]:-}" ]]; then
      error "canonical test catalog missing section for '$name'"
    fi
  done

  for heading in "${!heading_counts[@]}"; do
    if (( heading_counts["$heading"] > 1 )); then
      error "canonical test catalog has duplicate section for '$heading'"
    fi
    if [[ -z "${public_skills[$heading]:-}" ]]; then
      error "canonical test catalog has orphan section for '$heading'"
    fi
    if (( ${test_counts[$heading]:-0} == 0 )) || (( ${prompt_counts[$heading]:-0} == 0 )); then
      error "canonical test catalog section for '$heading' has no test case"
    fi
  done
}

# ── Documentation drift checks ─────────────────────────────────────────
# Active = public skill dir (same rules as the main loop) whose frontmatter
# metadata.deprecated is not "true". Prints one name per line.
list_active_skills() {
  local skill_dir name visible_files
  for skill_dir in "$SKILLS_DIR"/*/; do
    name=$(basename "$skill_dir")
    [[ "$name" == ".backups" || "$name" == ".cook" ]] && continue
    [[ "$name" == _* ]] && continue
    git check-ignore -q "$skill_dir" 2>/dev/null && continue
    if visible_files="$(git ls-files --cached --others --exclude-standard -- "$skill_dir" 2>/dev/null)" \
      && [[ -z "$visible_files" ]]; then
      continue
    fi
    [[ -f "$skill_dir/SKILL.md" ]] || continue
    frontmatter_flag "$skill_dir/SKILL.md" metadata.deprecated && continue
    echo "$name"
  done
}

# Old skill names from migrations.json, one per line (empty when absent).
list_old_skill_names() {
  local manifest="$SKILLS_DIR/../migrations.json"
  [[ -f "$manifest" ]] || return 0
  python3 -c 'import json,sys; print("\n".join(json.load(open(sys.argv[1]))["skills"]))' "$manifest"
}

# Number of entries in install.sh's SUPPORTED_TOOLS array, names one per line.
list_supported_tools() {
  awk '
    /^SUPPORTED_TOOLS=\(/ {f=1; sub(/^SUPPORTED_TOOLS=\(/, "")}
    f {
      sub(/#.*/, "")
      closed = ($0 ~ /\)/)
      sub(/\).*/, "")
      n = split($0, t, /[[:space:]]+/)
      for (i = 1; i <= n; i++) if (t[i] != "") print t[i]
      if (closed) exit
    }
  ' "$1"
}

check_collection_docs() {
  local root="$SKILLS_DIR/.."
  local readme="$root/README.md" install="$root/install.sh" install_doc="$root/INSTALL.md" migration="$root/MIGRATION.md"
  [[ -f "$readme" && -f "$install" ]] || return 0

  local name file n
  declare -A active=() linked=()
  while IFS= read -r name; do
    [[ -n "$name" ]] && active["$name"]=1
  done < <(list_active_skills)
  local active_count=${#active[@]}

  for file in "$readme" "$migration"; do
    [[ -f "$file" ]] || continue
    while IFS= read -r n; do
      [[ -n "$n" ]] || continue
      (( n == active_count )) || error "$(basename "$file") says $n active skills but $active_count are active"
    done < <(grep -oE '[0-9]+ active skills' "$file" | grep -oE '^[0-9]+' || true)
  done

  while IFS= read -r name; do
    [[ -n "$name" ]] && linked["$name"]=1
  done < <(grep -oE 'skills/[A-Za-z0-9._-]+/SKILL\.md' "$readme" | sed -E 's#^skills/##; s#/SKILL\.md$##' || true)
  for name in "${!active[@]}"; do
    [[ -n "${linked[$name]:-}" ]] || error "README.md does not link active skill '$name' (skills/$name/SKILL.md)"
  done
  for name in "${!linked[@]}"; do
    [[ -n "${active[$name]:-}" ]] || error "README.md links unknown or inactive skill '$name'"
  done

  local -a tools=()
  while IFS= read -r name; do
    [[ -n "$name" ]] && tools+=("$name")
  done < <(list_supported_tools "$install")
  local tool_count=${#tools[@]}

  for file in "$readme" "$install_doc"; do
    [[ -f "$file" ]] || continue
    while IFS= read -r n; do
      [[ -n "$n" ]] || continue
      (( n == tool_count )) || error "$(basename "$file") says $n targets but install.sh supports $tool_count"
    done < <(grep -oE '[0-9]+ targets' "$file" | grep -oE '^[0-9]+' || true)
  done

  if [[ -f "$install_doc" ]]; then
    # Backticked tokens in the Flag column (2nd cell) of the table under "## Supported targets".
    local doc_tools tool
    doc_tools="$(awk -F'|' '
      /^## / {f = ($0 ~ /^## Supported targets/); next}
      f && /^\|/ {
        cell = $3
        while (match(cell, /`[^`]+`/)) {
          print substr(cell, RSTART + 1, RLENGTH - 2)
          cell = substr(cell, RSTART + RLENGTH)
        }
      }
    ' "$install_doc")"
    for tool in "${tools[@]}"; do
      grep -qxF -- "$tool" <<< "$doc_tools" || error "INSTALL.md supported-targets table is missing tool '$tool'"
    done
  fi
}

# Active skills must name current skills in bold, not retired old names.
check_old_name_mentions() {
  local file="$1" name="$2" old
  [[ ${#OLD_SKILL_NAMES[@]} -gt 0 ]] || return 0
  frontmatter_flag "$file" metadata.deprecated && return 0
  for old in "${OLD_SKILL_NAMES[@]}"; do
    if grep -qF -- "**$old**" "$file"; then
      error "$name: SKILL.md mentions retired skill name '**$old**' (see migrations.json)"
    fi
  done
}

# ── Main ────────────────────────────────────────────────────────────────
echo "Linting skills in $SKILLS_DIR..."
echo

if [[ -d "$SKILLS_DIR" ]]; then
  frontmatter_cache_load "$SKILLS_DIR" name description license metadata \
    metadata.source metadata.date_added metadata.effort metadata.argument_hint metadata.internal \
    metadata.deprecated
fi

check_no_symlinks "$SKILLS_DIR"
check_canonical_test_coverage
check_collection_docs

OLD_SKILL_NAMES=()
while IFS= read -r old_name; do
  [[ -n "$old_name" ]] && OLD_SKILL_NAMES+=("$old_name")
done < <(list_old_skill_names)

skill_count=0
for skill_dir in "$SKILLS_DIR"/*/; do
  name=$(basename "$skill_dir")
  [[ "$name" == ".backups" || "$name" == ".cook" ]] && continue
  [[ "$name" == _* ]] && continue
  git check-ignore -q "$skill_dir" 2>/dev/null && continue
  # A retired skill can leave only an ignored private overlay behind.
  if visible_files="$(git ls-files --cached --others --exclude-standard -- "$skill_dir" 2>/dev/null)" \
    && [[ -z "$visible_files" ]]; then
    continue
  fi

  skill_file="$skill_dir/SKILL.md"
  if [[ ! -f "$skill_file" ]]; then
    error "$name: no SKILL.md found"
    continue
  fi

  echo "[$name]"
  check_frontmatter "$skill_file" "$name"
  check_desc_prefix "$skill_file" "$name"
  check_sections "$skill_file" "$name"
  check_ascii "$skill_file" "$name"
  check_ascii_refs "$skill_dir" "$name"
  check_length "$skill_file" "$name"
  check_references "$skill_file" "$name" "$skill_dir"
  check_reference_depth "$skill_file" "$name" "$skill_dir"
  check_reference_toc "$name" "$skill_dir"
  check_private_refs "$skill_dir" "$name"
  check_ai_self_check "$skill_file" "$name"
  check_generic_self_check_ratio "$skill_file" "$name"
  check_banned_words "$skill_dir" "$name"
  check_prose_double_dash "$skill_dir" "$name"
  check_ere_literal_pipe "$skill_dir" "$name"
  check_old_name_mentions "$skill_file" "$name"
  (( skill_count++ )) || true
done

echo
echo "────────────────────────────────────────"
echo "Skills checked: $skill_count"
echo "Errors:         $errors"
echo "Warnings:       $warnings"
echo "────────────────────────────────────────"

if (( errors > 0 )); then
  echo "FAILED"
  exit 1
else
  echo "PASSED"
  exit 0
fi
