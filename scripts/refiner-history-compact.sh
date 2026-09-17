#!/usr/bin/env bash
set -euo pipefail

# Compact .refiner-runs.json once it grows past a retention window.
#
# This is a manual, periodic maintenance tool, not part of the per-run
# workflow: skill-refiner appends one entry per run and never compacts. Run it
# by hand, or from a scheduled job, when the history gets large.
#
# It keeps the newest N runs byte-for-byte and moves every older entry, in
# full, into an archive file. The summaries left in the history keep only the
# fields Phase 0 and check-refiner-state.sh read; per-skill score and file
# detail lives in the archive. Nothing is deleted: the archive is written
# before the history is rewritten, and the original history is restored if the
# post-write validation fails.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
CHECK="$SCRIPT_DIR/check-refiner-state.sh"

keep=20
history="$ROOT/.refiner-runs.json"
archive="$ROOT/.refiner-runs-archive.json"
dry_run=0

usage() {
  cat <<'EOF'
Usage: refiner-history-compact.sh [options]

  --keep N        Keep the N most recent runs intact (default: 20)
  --history PATH  Run history to compact (default: <repo>/.refiner-runs.json)
  --archive PATH  Archive for the full entries (default: <repo>/.refiner-runs-archive.json)
  --dry-run       Print what would change and write nothing
  -h, --help      Show this help
EOF
}

while (( $# > 0 )); do
  case "$1" in
    --keep)
      [[ $# -ge 2 ]] || { echo "ERROR: --keep requires a value" >&2; exit 2; }
      keep="$2"; shift 2 ;;
    --keep=*) keep="${1#*=}"; shift ;;
    --history)
      [[ $# -ge 2 ]] || { echo "ERROR: --history requires a value" >&2; exit 2; }
      history="$2"; shift 2 ;;
    --history=*) history="${1#*=}"; shift ;;
    --archive)
      [[ $# -ge 2 ]] || { echo "ERROR: --archive requires a value" >&2; exit 2; }
      archive="$2"; shift 2 ;;
    --archive=*) archive="${1#*=}"; shift ;;
    --dry-run) dry_run=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "ERROR: unknown option: $1" >&2; usage >&2; exit 2 ;;
  esac
done

if [[ ! "$keep" =~ ^[0-9]+$ ]]; then
  echo "ERROR: --keep must be a non-negative integer, got '$keep'" >&2
  exit 2
fi

if [[ ! -f "$history" ]]; then
  echo "ERROR: history file not found: $history" >&2
  exit 1
fi

if [[ "$history" == "$archive" ]]; then
  echo "ERROR: --history and --archive must differ" >&2
  exit 2
fi

if [[ ! -f "$CHECK" ]]; then
  echo "ERROR: validation script not found: $CHECK" >&2
  exit 1
fi

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

python3 - "$history" "$archive" "$keep" "$work" <<'PY'
import json
import os
import sys

history_path, archive_path, keep_s, work = sys.argv[1:5]
keep = int(keep_s)


def die(message):
    print(f"ERROR: {message}", file=sys.stderr)
    raise SystemExit(1)


with open(history_path, encoding="utf-8") as handle:
    raw = handle.read()

decoder = json.JSONDecoder()
start = raw.find("[")
if start < 0:
    die(f"{history_path} is not a JSON array")

# Record each top-level array element's byte range so the newest runs can be
# spliced back unchanged instead of being reserialized.
index = start + 1
length = len(raw)
elements = []
while True:
    while index < length and raw[index] in " \t\r\n,":
        index += 1
    if index >= length:
        die(f"{history_path} is an unterminated JSON array")
    if raw[index] == "]":
        break
    value, end = decoder.raw_decode(raw, index)
    elements.append((index, end, value))
    index = end

total = len(elements)
boundary = total - keep
if boundary < 0:
    boundary = 0


def is_compacted(entry):
    return isinstance(entry, dict) and entry.get("compacted") is True


# Only full entries need moving. Already-compacted summaries in the older
# region are left untouched, which keeps repeated runs idempotent.
compacted = [entry for entry in elements[:boundary] if not is_compacted(entry[2])]
if not compacted:
    with open(os.path.join(work, "state"), "w", encoding="utf-8") as handle:
        handle.write("nothing\n")
    print(f"Nothing to compact: no full entry older than the newest {keep} run(s).")
    raise SystemExit(0)

SUMMARY_KEYS = (
    "run_id",
    "date",
    "schema",
    "rubric_hash",
    "primary",
    "secondary",
    "review_weight",
    "cap",
    "control_failures",
    "terminated",
    "aggregate",
    "branch",
    "changes_summary",
)


def summarize(entry):
    if not isinstance(entry, dict):
        die(f"{history_path} contains a non-object entry")
    summary = {}
    for key in SUMMARY_KEYS:
        if key in entry:
            summary[key] = entry[key]
    summary["compacted"] = True
    return summary


def render(value):
    return json.dumps(value, indent=2, ensure_ascii=True).replace("\n", "\n  ")


# Rebuild the older region: newly compacted full entries become summaries,
# already-compacted ones keep their exact bytes, and the newest runs are
# spliced back from the original text unchanged.
prefix = raw[:elements[0][0]]
region = ",\n  ".join(
    raw[entry[0]:entry[1]] if is_compacted(entry[2]) else render(summarize(entry[2]))
    for entry in elements[:boundary]
)
last_end = elements[-1][1]
if boundary < total:
    new_text = prefix + region + ",\n  " + raw[elements[boundary][0]:last_end] + raw[last_end:]
else:
    new_text = prefix + region + raw[last_end:]

archive_entries = []
created = False
if os.path.exists(archive_path):
    with open(archive_path, encoding="utf-8") as handle:
        archive_entries = json.load(handle)
    if not isinstance(archive_entries, list):
        die(f"{archive_path} is not a JSON array")
else:
    created = True
archive_entries.extend(entry[2] for entry in compacted)
archive_text = json.dumps(archive_entries, indent=2, ensure_ascii=True) + "\n"

# Re-parse the spliced history and confirm the kept runs are unchanged in
# value and every entry in the older region carries its marker.
reparsed = json.loads(new_text)
if len(reparsed) != total:
    die("spliced history has the wrong number of entries")
for original, result in zip((entry[2] for entry in elements[boundary:]), reparsed[boundary:]):
    if result != original:
        die("spliced history changed a kept entry")
for summary in reparsed[:boundary]:
    if summary.get("compacted") is not True:
        die("spliced history is missing a compacted marker")

with open(os.path.join(work, "new-history.json"), "w", encoding="utf-8") as handle:
    handle.write(new_text)
with open(os.path.join(work, "new-archive.json"), "w", encoding="utf-8") as handle:
    handle.write(archive_text)
with open(os.path.join(work, "state"), "w", encoding="utf-8") as handle:
    handle.write("compact\n")

print(f"Compacting {len(compacted)} run(s), keeping {keep}.")
for entry in compacted:
    item = entry[2]
    print(f"  archive: {item.get('run_id', 'unknown run')} ({item.get('date', 'unknown date')})")
print(f"Archive: {archive_path} ({'created' if created else 'appended'})")
print(f"History: {len(raw)} -> {len(new_text)} bytes")
PY

state="$(cat "$work/state" 2>/dev/null || true)"
if [[ "$state" == "nothing" ]]; then
  exit 0
fi
if [[ "$state" != "compact" ]]; then
  echo "ERROR: compaction planner did not produce output" >&2
  exit 1
fi

if (( dry_run )); then
  echo "Dry run: nothing written."
  exit 0
fi

backup_history="$work/history.bak"
backup_archive="$work/archive.bak"
cp -p "$history" "$backup_history"
archive_existed=0
if [[ -f "$archive" ]]; then
  cp -p "$archive" "$backup_archive"
  archive_existed=1
fi

cp "$work/new-archive.json" "$archive"
cp "$work/new-history.json" "$history"

if ! "$CHECK" "$history"; then
  echo "ERROR: validation failed after compaction; restoring original files." >&2
  cp -p "$backup_history" "$history"
  if (( archive_existed )); then
    cp -p "$backup_archive" "$archive"
  else
    rm -f "$archive"
  fi
  exit 1
fi

echo "Compaction complete."
