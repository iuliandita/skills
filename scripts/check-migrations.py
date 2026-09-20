#!/usr/bin/env python3
"""Validate transition notices and prevent retiring them before the grace period."""

from __future__ import annotations

import argparse
from datetime import datetime, timedelta, timezone
import importlib.util
import json
from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parent.parent
spec = importlib.util.spec_from_file_location("frontmatter", ROOT / "scripts/skill-frontmatter.py")
assert spec and spec.loader
frontmatter = importlib.util.module_from_spec(spec)
spec.loader.exec_module(frontmatter)
NAME = re.compile(r"[a-z0-9]+(?:-[a-z0-9]+)*")


def validate(root: Path, retire: bool = False) -> None:
    manifest = json.loads((root / "migrations.json").read_text())
    if manifest.get("version") != 1:
        raise ValueError("unsupported migration manifest version")
    transition = manifest["transition"]
    if transition["minimum_days"] != 7 or transition["placeholder_releases"] != 1:
        raise ValueError("transition policy must be one release and seven days")
    release, published = transition["release"], transition["published_at"]
    if (release is None) != (published is None):
        raise ValueError("release and published_at must both be set or both null")
    eligible = False
    if release is not None:
        if not isinstance(release, str) or not release.strip():
            raise ValueError("release must identify the published transition tag")
        timestamp = datetime.fromisoformat(published.replace("Z", "+00:00"))
        if timestamp.tzinfo is None:
            raise ValueError("published_at must include a timezone")
        eligible = datetime.now(timezone.utc) >= timestamp + timedelta(days=7)
    if retire and not eligible:
        raise ValueError("retirement requires a recorded published release and seven elapsed days")

    mappings = manifest["skills"]
    if not isinstance(mappings, dict) or not mappings:
        raise ValueError("migration mapping must be nonempty")
    for old, item in mappings.items():
        if not NAME.fullmatch(old):
            raise ValueError(f"invalid old skill name: {old!r}")
        action, replacement = item["action"], item["replacement"]
        if action not in {"rename", "merge", "remove"}:
            raise ValueError(f"{old}: invalid action")
        if action == "remove":
            if replacement is not None:
                raise ValueError(f"{old}: removed skill must not have a replacement")
        else:
            if not isinstance(replacement, str) or not NAME.fullmatch(replacement):
                raise ValueError(f"{old}: invalid replacement name")
            if replacement in mappings:
                raise ValueError(f"{old}: replacement cannot be another deprecated name")
            target = root / "skills" / replacement / "SKILL.md"
            data = frontmatter.load_frontmatter(str(target))
            if data["name"] != replacement or str(data["metadata"].get("deprecated", "")).lower() == "true":
                raise ValueError(f"{old}: replacement must be an active skill")
        notice = root / "skills" / old / "SKILL.md"
        if notice.exists():
            data = frontmatter.load_frontmatter(str(notice))
            if data["name"] != old or str(data["metadata"].get("deprecated", "")).lower() != "true":
                raise ValueError(f"{old}: old name must be a deprecated notice")
            if not data["description"].startswith("Deprecated"):
                raise ValueError(f"{old}: description must lead with Deprecated")
            if replacement and f"**{replacement}**" not in notice.read_text():
                raise ValueError(f"{old}: notice must name its replacement")
        elif not eligible:
            raise ValueError(f"{old}: notice removed before published grace period elapsed")
    for notice in (root / "skills").glob("*/SKILL.md"):
        data = frontmatter.load_frontmatter(str(notice))
        if str(data.get("metadata", {}).get("deprecated", "")).lower() == "true" and notice.parent.name not in mappings:
            raise ValueError(f"{notice.parent.name}: deprecated skill missing from manifest")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=ROOT)
    parser.add_argument("--retire-check", action="store_true")
    args = parser.parse_args()
    try:
        validate(args.root, args.retire_check)
    except (OSError, ValueError, KeyError, TypeError) as error:
        print(f"Migration check failed: {error}", file=sys.stderr)
        return 1
    print("Migration manifest and transition notices are valid.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
