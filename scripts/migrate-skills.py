#!/usr/bin/env python3
"""Safely migrate installer-owned skill directories from migrations.json."""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import shutil
import sys
from datetime import datetime, timezone
from pathlib import Path
from typing import Any


NAME_RE = re.compile(r"^[a-z0-9](?:[a-z0-9-]*[a-z0-9])?$")
HASH_RE = re.compile(r"^[0-9a-f]{64}$")
PROVENANCE = "source-equal-v1"


class ValidationError(Exception):
    pass


def path_is_within(path: Path, parent: Path) -> bool:
    try:
        path.resolve(strict=False).relative_to(parent.resolve(strict=True))
    except ValueError:
        return False
    return True


def skill_hash(directory: Path) -> str:
    digest = hashlib.sha256()
    files: list[Path] = []
    for root, dirs, names in os.walk(directory, followlinks=False):
        dirs[:] = [name for name in dirs if not (Path(root) / name).is_symlink()]
        files.extend(Path(root) / name for name in names if not (Path(root) / name).is_symlink())
    for file_path in sorted(files, key=lambda item: str(item)):
        with file_path.open("rb") as file:
            shutil.copyfileobj(file, _HashWriter(digest))
    return digest.hexdigest()


def safe_skill_tree(directory: Path) -> str | None:
    protected = directory / "protected"
    if protected.exists() or protected.is_symlink():
        return "protected overlay exists"
    for root, dirs, names in os.walk(directory, followlinks=False):
        root_path = Path(root)
        for name in dirs:
            if (root_path / name).is_symlink():
                return "skill tree contains an interior symlink"
        for name in names:
            path = root_path / name
            if path.is_symlink():
                return "skill tree contains an interior symlink"
            if not path.is_file():
                return "skill tree contains a non-regular file"
    return None


class _HashWriter:
    def __init__(self, digest: Any) -> None:
        self.digest = digest

    def write(self, data: bytes) -> int:
        self.digest.update(data)
        return len(data)


def read_manifest(path: Path, source: Path) -> dict[str, dict[str, str | None]]:
    try:
        raw = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as error:
        raise ValidationError(f"invalid manifest: {error}") from error
    if not isinstance(raw, dict) or raw.get("version") != 1:
        raise ValidationError("manifest version must be 1")
    transition = raw.get("transition")
    if not isinstance(transition, dict):
        raise ValidationError("manifest transition must be an object")
    required_transition = {"release", "published_at", "minimum_days", "placeholder_releases"}
    if set(transition) != required_transition:
        raise ValidationError("manifest transition has unexpected fields")
    if transition["release"] is not None and not isinstance(transition["release"], str):
        raise ValidationError("transition release must be a string or null")
    if transition["published_at"] is not None and not isinstance(transition["published_at"], str):
        raise ValidationError("transition published_at must be a string or null")
    if not isinstance(transition["minimum_days"], int) or transition["minimum_days"] < 0:
        raise ValidationError("transition minimum_days must be a non-negative integer")
    if not isinstance(transition["placeholder_releases"], int) or transition["placeholder_releases"] < 0:
        raise ValidationError("transition placeholder_releases must be a non-negative integer")

    skills = raw.get("skills")
    if not isinstance(skills, dict) or not skills:
        raise ValidationError("manifest skills must be a non-empty object")
    parsed: dict[str, dict[str, str | None]] = {}
    for old_name, entry in skills.items():
        if not isinstance(old_name, str) or not NAME_RE.fullmatch(old_name):
            raise ValidationError(f"invalid old skill name: {old_name!r}")
        if not isinstance(entry, dict) or set(entry) != {"action", "replacement"}:
            raise ValidationError(f"{old_name}: expected action and replacement")
        action = entry["action"]
        replacement = entry["replacement"]
        if action not in {"rename", "merge", "remove"}:
            raise ValidationError(f"{old_name}: invalid action")
        if action == "remove":
            if replacement is not None:
                raise ValidationError(f"{old_name}: remove action cannot have a replacement")
        else:
            if not isinstance(replacement, str) or not NAME_RE.fullmatch(replacement):
                raise ValidationError(f"{old_name}: replacement must be a skill name")
        parsed[old_name] = {"action": action, "replacement": replacement}
    return parsed


def read_lock(path: Path, source: Path) -> tuple[dict[str, Any] | None, str | None]:
    try:
        raw = json.loads(path.read_text(encoding="utf-8"))
    except FileNotFoundError:
        return None, "missing lock file"
    except (OSError, json.JSONDecodeError) as error:
        return None, f"invalid lock file: {error}"
    if not isinstance(raw, dict) or raw.get("version") != 1:
        return None, "invalid lock version"
    lock_source = raw.get("source")
    skills = raw.get("skills")
    if not isinstance(lock_source, str) or not isinstance(skills, dict):
        return None, "invalid lock fields"
    try:
        if Path(lock_source).resolve(strict=True) != source.resolve(strict=True):
            return None, "lock source does not match requested source"
    except OSError:
        return None, "lock source cannot be resolved"
    for name, record in skills.items():
        if not isinstance(name, str) or not NAME_RE.fullmatch(name):
            return None, "invalid lock skill record"
        if isinstance(record, str):
            if not HASH_RE.fullmatch(record):
                return None, "invalid lock skill record"
        elif not isinstance(record, dict) or set(record) != {"hash", "provenance"} or not isinstance(record["hash"], str) or not HASH_RE.fullmatch(record["hash"]) or record["provenance"] != PROVENANCE:
            return None, "invalid lock skill record"
    return raw, None


def owned_target(
    old_path: Path, old_name: str, lock: dict[str, Any], link_root: Path | None
) -> tuple[Path | None, str | None]:
    if not old_path.exists() and not old_path.is_symlink():
        return None, "already absent"
    record = lock["skills"].get(old_name)
    if record is None:
        return None, "no lock record for skill"
    if not isinstance(record, dict) or record.get("provenance") != PROVENANCE:
        return None, "legacy lock record has no verified provenance; migrate manually"
    digest = record["hash"]
    target = old_path
    if old_path.is_symlink():
        if link_root is None:
            return None, "ambiguous symlink without --link-root"
        try:
            resolved = old_path.resolve(strict=True)
        except OSError:
            return None, "ambiguous broken symlink"
        expected = (link_root / old_name).resolve(strict=False)
        if resolved != expected:
            return None, "ambiguous symlink target"
        target = resolved
    if target.is_symlink() or not target.is_dir():
        return None, "target is not an owned skill directory"
    if reason := safe_skill_tree(target):
        return None, reason
    try:
        actual = skill_hash(target)
    except OSError as error:
        return None, f"could not hash target: {error}"
    if actual != digest:
        return None, "ownership hash differs"
    return target, None


def replacement_ready(
    destination: Path, replacement: str, source: Path, link_root: Path | None
) -> tuple[bool, str | None]:
    source_skill = source / replacement
    expected_hash = skill_hash(source_skill)
    current = destination / replacement
    if current.exists() or current.is_symlink():
        if link_root is not None:
            if not current.is_symlink():
                return False, "replacement collision with existing differing new target"
            try:
                canonical = (link_root / replacement).resolve(strict=True)
                if current.resolve(strict=True) != canonical or safe_skill_tree(canonical) or skill_hash(canonical) != expected_hash:
                    return False, "replacement collision with existing differing new target"
            except OSError:
                return False, "replacement collision with existing differing new target"
            return True, None
        if current.is_symlink() or not current.is_dir() or safe_skill_tree(current) or skill_hash(current) != expected_hash:
            return False, "replacement collision with existing differing new target"
        return True, None
    if link_root is not None:
        canonical = link_root / replacement
        if canonical.is_symlink() or not canonical.is_dir() or safe_skill_tree(canonical) or skill_hash(canonical) != expected_hash:
            return False, "replacement canonical target is missing or differs from source"
    return True, None


def install_replacement(destination: Path, replacement: str, source: Path, link_root: Path | None) -> None:
    target = destination / replacement
    if target.exists() or target.is_symlink():
        return
    if link_root is not None:
        target.symlink_to(link_root / replacement)
    else:
        shutil.copytree(source / replacement, target, symlinks=True)
    ready, reason = replacement_ready(destination, replacement, source, link_root)
    if not ready:
        raise OSError(f"replacement verification failed: {reason}")


def backup_and_remove(path: Path, destination: Path, name: str) -> None:
    backup_root = destination.parent / ".skills-backups" / destination.name / name
    stamp = datetime.now(timezone.utc).strftime("%Y%m%d-%H%M%S")
    backup = backup_root / stamp
    suffix = 1
    while backup.exists() or backup.is_symlink():
        suffix += 1
        backup = backup_root / f"{stamp}-{suffix}"
    backup.mkdir(parents=True)
    saved = backup / name
    if path.is_symlink():
        link_target = path.resolve(strict=True)
        saved.symlink_to(os.readlink(path))
        shutil.copytree(link_target, backup / f"{name}.target", symlinks=True)
        path.unlink()
    else:
        shutil.copytree(path, saved, symlinks=True)
        shutil.rmtree(path)


def write_lock(path: Path, lock: dict[str, Any], source: Path, updates: dict[str, dict[str, str] | None]) -> None:
    skills = dict(lock["skills"])
    for name, digest in updates.items():
        if digest is None:
            skills.pop(name, None)
        else:
            skills[name] = digest
    lock["skills"] = dict(sorted(skills.items()))
    lock["source"] = str(source)
    lock["updated_at"] = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    temp = path.with_name(f".{path.name}.tmp")
    temp.write_text(json.dumps(lock, indent=2, sort_keys=False) + "\n", encoding="utf-8")
    temp.replace(path)


def migrate(args: argparse.Namespace) -> int:
    source = args.source.resolve(strict=True)
    destination = args.dest.resolve(strict=False)
    if destination == source or path_is_within(destination, source):
        raise ValidationError("destination overlaps the source tree")
    link_root = args.link_root.resolve(strict=True) if args.link_root else None
    if link_root is not None:
        if link_root == destination or link_root == source or path_is_within(link_root, source):
            raise ValidationError("link root aliases a protected source or destination")
    manifest = read_manifest(args.manifest, source)
    lock_path = destination / ".skills-lock.json"
    lock, reason = read_lock(lock_path, source)
    if lock is None:
        print(f"SKIP all: {reason}")
        return 0
    updates: dict[str, dict[str, str] | None] = {}
    changed = False
    for old_name, entry in manifest.items():
        old_path = destination / old_name
        owned, reason = owned_target(old_path, old_name, lock, link_root)
        if owned is None:
            print(f"SKIP {old_name}: {reason}")
            continue
        action = str(entry["action"])
        replacement = entry["replacement"]
        if replacement is not None:
            source_skill = source / replacement
            if source_skill.is_symlink() or not source_skill.is_dir() or not (source_skill / "SKILL.md").is_file() or not path_is_within(source_skill, source):
                print(f"SKIP {old_name}: replacement source is unavailable")
                continue
            if source_reason := safe_skill_tree(source_skill):
                print(f"SKIP {old_name}: replacement {source_reason}")
                continue
            ready, ready_reason = replacement_ready(destination, replacement, source, link_root)
            if not ready:
                print(f"SKIP {old_name}: {ready_reason}")
                continue
        if args.preserve_shared_canonical:
            if replacement is None:
                print(f"SKIP {old_name}: shared canonical target retained; manual migration required")
                continue
            if args.apply:
                install_replacement(destination, replacement, source, link_root)
                updates[replacement] = {"hash": skill_hash(source / replacement), "provenance": PROVENANCE}
                changed = True
                print(f"APPLIED {action} {old_name} -> {replacement}: shared canonical target retained")
            else:
                print(f"DRY-RUN {action} {old_name} -> {replacement}: would install replacement; shared canonical target retained")
            continue
        if args.apply:
            if replacement is not None:
                install_replacement(destination, replacement, source, link_root)
                updates[replacement] = {"hash": skill_hash(source / replacement), "provenance": PROVENANCE}
            backup_and_remove(old_path, destination, old_name)
            updates[old_name] = None
            changed = True
            detail = f" -> {replacement}" if replacement else ""
            print(f"APPLIED {action} {old_name}{detail}")
        else:
            detail = f" -> {replacement}" if replacement else ""
            print(f"DRY-RUN {action} {old_name}{detail}: would install/verify replacement before backup and retire")
    if args.apply and changed:
        write_lock(lock_path, lock, source, updates)
    return 0


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--manifest", type=Path, required=True)
    parser.add_argument("--source", type=Path, required=True)
    parser.add_argument("--dest", type=Path, required=True)
    parser.add_argument("--link-root", type=Path)
    parser.add_argument("--preserve-shared-canonical", action="store_true")
    parser.add_argument("--apply", action="store_true")
    return parser.parse_args()


def main() -> int:
    try:
        return migrate(parse_args())
    except (ValidationError, OSError) as error:
        print(f"ERROR: {error}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
