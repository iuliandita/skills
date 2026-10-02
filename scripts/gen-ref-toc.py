#!/usr/bin/env python3
"""Add or refresh a `## Contents` list at the top of long reference files.

Agents often preview a long reference with a partial read (roughly the first
100 lines) to decide whether it is worth loading. A contents list near the top
keeps the whole file's scope visible even then.

Usage:
  scripts/gen-ref-toc.py [PATH ...]          write missing or stale lists
  scripts/gen-ref-toc.py --check [PATH ...]  report only; exit 1 on drift

PATH is a skills root, a skill directory, or a reference file. Defaults to
`skills`. Only `<skill>/references/*.md` files are considered.

A file needs a list when its body (excluding a generated list) exceeds
TOC_MIN_LINES. A hand-written `## Table of Contents` is accepted as-is; a
`## Contents` section is owned by this script and must match the headings.
"""

from __future__ import annotations

import argparse
import re
import subprocess
import sys
from pathlib import Path

# Matches Anthropic's guidance: reference files over 100 lines get a contents list.
TOC_MIN_LINES = 100
# How far from the top a hand-written table of contents may start and still count
# as visible to a partial read.
TOC_SEARCH_LINES = 40
# Generated per-skill copies of skills/_shared/*; their source owns their shape.
SHARED_COPIES = {"output-contract.md", "agent-hygiene.md"}

GENERATED_HEADING = "## Contents"
MANUAL_TOC = re.compile(r"^#{2,3}\s+(table of contents|contents)\s*$", re.I)
FENCE = re.compile(r"^\s*(```|~~~)")


def headings(lines: list[str], level: str) -> list[str]:
    out, in_fence = [], False
    for line in lines:
        if FENCE.match(line):
            in_fence = not in_fence
            continue
        if in_fence or not line.startswith(level + " "):
            continue
        text = line[len(level) + 1 :].strip().rstrip("#").strip()
        if MANUAL_TOC.match(f"## {text}"):
            continue
        out.append(text)
    return out


def generated_start(lines: list[str]) -> int:
    """Index of a generated block: `## Contents`, a blank line, then `- ` bullets."""
    for i, ln in enumerate(lines[: len(lines) - 2]):
        if ln.rstrip() == GENERATED_HEADING and not lines[i + 1].strip() and lines[i + 2].startswith("- "):
            return i
    return -1


def strip_generated(lines: list[str]) -> list[str]:
    """Return lines with an existing generated `## Contents` section removed."""
    start = generated_start(lines)
    if start < 0:
        return lines
    # The generated block is exactly: heading, one blank, consecutive bullets. Anything
    # after it, including a separate bullet list, belongs to the author.
    end = start + 1
    if end < len(lines) and not lines[end].strip():
        end += 1
    while end < len(lines) and lines[end].startswith("- "):
        end += 1
    head, tail = lines[:start], lines[end:]
    while head and not head[-1].strip() and tail and not tail[0].strip():
        head = head[:-1]
    return head + tail


def has_manual_toc(lines: list[str]) -> bool:
    """A contents heading near the top that this script did not write (e.g. numbered)."""
    gen = generated_start(lines)
    return any(
        MANUAL_TOC.match(ln) and i != gen for i, ln in enumerate(lines[:TOC_SEARCH_LINES])
    )


# Keep the list inside what a partial read sees: after a short intro, never deep in it.
MAX_INTRO_LINES = 25


def insert_at(lines: list[str]) -> int:
    """Index of the first `##` heading or `---` rule after a short intro, else after the H1."""
    h1 = next((i for i, ln in enumerate(lines[:5]) if ln.startswith("# ")), -1)
    in_fence = False
    for i in range(h1 + 1, min(len(lines), h1 + 1 + MAX_INTRO_LINES)):
        if FENCE.match(lines[i]):
            in_fence = not in_fence
        elif not in_fence and (lines[i].startswith("## ") or lines[i].rstrip() == "---"):
            return i
    return h1 + 1


def render(lines: list[str]) -> list[str] | None:
    """Return the file with a fresh generated list, or None when none applies."""
    body = strip_generated(lines)
    if len(body) <= TOC_MIN_LINES or has_manual_toc(body):
        return None if body == lines else body
    items = headings(body, "##")
    if len(items) < 2:
        items = headings(body, "###")
    if len(items) < 2:
        return None if body == lines else body
    block = [GENERATED_HEADING, ""] + [f"- {h}" for h in items] + [""]
    at = insert_at(body)
    head = body[:at]
    if head and head[-1].strip():
        head = head + [""]
    tail = body[at:]
    while tail and not tail[0].strip():
        tail = tail[1:]
    return head + block + tail


def is_ignored(path: Path) -> bool:
    try:
        return subprocess.run(
            ["git", "check-ignore", "-q", str(path)], capture_output=True
        ).returncode == 0
    except FileNotFoundError:
        return False


def collect(paths: list[Path]) -> list[Path]:
    files: list[Path] = []
    for p in paths:
        if p.is_file():
            files.append(p)
        elif (p / "references").is_dir():
            files.extend(sorted((p / "references").glob("*.md")))
        elif p.is_dir():
            for skill in sorted(p.iterdir()):
                if skill.is_dir() and not skill.name.startswith(("_", ".")) and (skill / "references").is_dir():
                    files.extend(sorted((skill / "references").glob("*.md")))
        else:
            sys.exit(f"gen-ref-toc: no such path: {p}")
    return [f for f in files if f.name not in SHARED_COPIES and not is_ignored(f)]


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--check", action="store_true", help="report drift without writing")
    ap.add_argument("paths", nargs="*", type=Path, default=[Path("skills")])
    args = ap.parse_args()

    drift = 0
    for f in collect(args.paths):
        text = f.read_text(encoding="utf-8")
        lines = text.split("\n")
        trailing = lines[-1] == ""
        if trailing:
            lines = lines[:-1]
        new = render(lines)
        if new is None or new == lines:
            continue
        drift += 1
        if args.check:
            print(f"{f}: missing or stale '## Contents' list (run scripts/gen-ref-toc.py)")
        else:
            f.write_text("\n".join(new) + ("\n" if trailing else ""), encoding="utf-8")
            print(f"updated {f}")
    return 1 if args.check and drift else 0


if __name__ == "__main__":
    sys.exit(main())
