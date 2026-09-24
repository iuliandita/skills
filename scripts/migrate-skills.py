#!/usr/bin/env python3
"""Safely migrate installer-owned skill directories from migrations.json."""

from __future__ import annotations

import argparse
import ctypes
import errno
import fcntl
import hashlib
import json
import os
import re
import shutil
import stat
import sys
import tempfile
import time
from datetime import datetime, timezone
from pathlib import Path
from typing import Any


NAME_RE = re.compile(r"^[a-z0-9](?:[a-z0-9-]*[a-z0-9])?$")
HASH_RE = re.compile(r"^[0-9a-f]{64}$")
PROVENANCE = "source-equal-v1"
STAGING_NAMESPACE = ".skills-migrate-staging"
INHERITED_LOCK_FD = 9
LOCK_BUSY_EXIT = 3
# Test hooks only: comma-separated fault names, see scripts/test-migrate-skills.sh.
FAULTS = frozenset(filter(None, os.environ.get("SKILLS_MIGRATE_FAULT", "").split(",")))
NO_REPLACE_UNSUPPORTED = {errno.ENOSYS, errno.EINVAL, errno.ENOTSUP, errno.EOPNOTSUPP}


class ValidationError(Exception):
    pass


class LockBusy(Exception):
    pass


class NoReplaceUnavailable(Exception):
    pass


def crash(name: str) -> None:
    if name in FAULTS:
        sys.stdout.flush()
        print(f"FAULT {name}", file=sys.stderr, flush=True)
        os._exit(99)


def overlaps(first: Path, second: Path) -> bool:
    return first == second or path_is_within(first, second) or path_is_within(second, first)


def installer_lock_path() -> Path:
    state = os.environ.get("XDG_STATE_HOME") or os.path.join(os.environ.get("HOME") or str(Path.home()), ".local", "state")
    return Path(state) / "iuliandita-skills" / "install.lock"


def hold_installer_lock() -> None:
    """Hold install.sh's lock before any change; flock(1) and fcntl.flock are both flock(2)."""
    path = installer_lock_path()
    try:
        inherited = os.fstat(INHERITED_LOCK_FD)
        current = os.stat(path)
    except OSError:
        inherited = current = None
    if inherited is not None and current is not None and (inherited.st_dev, inherited.st_ino) == (current.st_dev, current.st_ino):
        try:
            # Succeeds without waiting only on the open file description our parent locked.
            fcntl.flock(INHERITED_LOCK_FD, fcntl.LOCK_EX | fcntl.LOCK_NB)
            return
        except BlockingIOError:
            pass
    wait = os.environ.get("SKILLS_LOCK_WAIT", "30")
    if not re.fullmatch(r"[0-9]+", wait):
        raise ValidationError(f"SKILLS_LOCK_WAIT must be a whole number of seconds: {wait}")
    path.parent.mkdir(parents=True, exist_ok=True)
    os.chmod(path.parent, 0o700)
    fd = os.open(path, os.O_WRONLY | os.O_APPEND | os.O_CREAT | os.O_CLOEXEC, 0o600)
    deadline = time.monotonic() + int(wait)
    while True:
        try:
            fcntl.flock(fd, fcntl.LOCK_EX | fcntl.LOCK_NB)
            break
        except BlockingIOError:
            if time.monotonic() >= deadline:
                os.close(fd)
                raise LockBusy(f"another install.sh run holds {path}; gave up after {wait}s (set SKILLS_LOCK_WAIT to wait longer)") from None
            time.sleep(0.1)
    # The descriptor stays open, and the lock held, until this process exits.
    if "sleep-after-lock" in FAULTS:
        print("FAULT sleep-after-lock", file=sys.stderr, flush=True)
        time.sleep(2)


def rename_noreplace(source: Path, target: Path) -> None:
    """Rename that fails with EEXIST instead of replacing an existing target."""
    if "force-enosys" in FAULTS:
        raise OSError(errno.ENOSYS, "forced by SKILLS_MIGRATE_FAULT", str(target))
    libc = ctypes.CDLL(None, use_errno=True)
    if sys.platform.startswith("linux"):
        func = getattr(libc, "renameat2", None)
        if func is None:
            raise OSError(errno.ENOSYS, "renameat2 is unavailable in this C library", str(target))
        func.argtypes = [ctypes.c_int, ctypes.c_char_p, ctypes.c_int, ctypes.c_char_p, ctypes.c_uint]
        func.restype = ctypes.c_int
        at_fdcwd, rename_noreplace_flag = -100, 1
        result = func(at_fdcwd, os.fsencode(source), at_fdcwd, os.fsencode(target), rename_noreplace_flag)
    elif sys.platform == "darwin":
        func = getattr(libc, "renamex_np", None)
        if func is None:
            raise OSError(errno.ENOSYS, "renamex_np is unavailable", str(target))
        func.argtypes = [ctypes.c_char_p, ctypes.c_char_p, ctypes.c_uint]
        func.restype = ctypes.c_int
        rename_excl = 0x4
        result = func(os.fsencode(source), os.fsencode(target), rename_excl)
    else:
        raise OSError(errno.ENOSYS, f"no atomic no-replace rename on {sys.platform}", str(target))
    if result != 0:
        error = ctypes.get_errno()
        raise OSError(error, os.strerror(error), str(target))


def _raise(error: OSError) -> None:
    raise error


def remove_tree(root: Path, fault: str | None = None) -> None:
    for current, dirs, names in os.walk(root, topdown=False, onerror=_raise, followlinks=False):
        for name in names:
            os.unlink(os.path.join(current, name))
            if fault:
                crash(fault)
        for name in dirs:
            path = os.path.join(current, name)
            if os.path.islink(path):
                os.unlink(path)
            else:
                os.rmdir(path)
    os.rmdir(root)


def remove_entry(path: Path) -> None:
    if path.is_symlink() or not path.is_dir():
        path.unlink()
    else:
        shutil.rmtree(path)


def fsync_dir(directory: Path) -> None:
    fd = os.open(directory, os.O_RDONLY | os.O_DIRECTORY)
    try:
        os.fsync(fd)
    finally:
        os.close(fd)


def check_namespace(root: Path, area: Path) -> None:
    for path in (root, area):
        if path.is_symlink():
            raise ValidationError(f"migration staging path is a symlink: {path}")


def clear_namespace(root: Path, area: Path) -> None:
    """Everything under the destination's staging area is migrator debris from an earlier run."""
    check_namespace(root, area)
    if area.exists():
        shutil.rmtree(area)


def ensure_namespace(root: Path, area: Path, destination: Path) -> Path:
    check_namespace(root, area)
    area.mkdir(parents=True, exist_ok=True)
    check_namespace(root, area)
    if os.stat(area).st_dev != os.stat(destination).st_dev:
        raise ValidationError(f"migration staging area {area} is on a different filesystem than {destination}")
    return area


def tidy_namespace(root: Path, area: Path) -> None:
    for path in (area, root):
        try:
            path.rmdir()
        except FileNotFoundError:
            continue
        except OSError:
            return


def path_is_within(path: Path, parent: Path) -> bool:
    try:
        path.resolve(strict=False).relative_to(parent.resolve(strict=False))
    except ValueError:
        return False
    return True


def skill_hash(directory: Path) -> str:
    digest = hashlib.sha256()
    files: list[Path] = []
    for root, dirs, names in os.walk(directory, followlinks=False):
        dirs[:] = [name for name in dirs if not (Path(root) / name).is_symlink()]
        files.extend(Path(root) / name for name in names if not (Path(root) / name).is_symlink())
    for file_path in sorted(files, key=lambda item: os.fsencode(str(item))):
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


def promote_replacement(
    destination: Path, replacement: str, source: Path, link_root: Path | None, staging_area: Any
) -> str | None:
    """Install an absent replacement by staging it and renaming it into place without replacing.

    Returns a skip reason, or None once the replacement is present and verified.
    """
    target = destination / replacement
    if target.exists() or target.is_symlink():
        return None
    staged = staging_area() / replacement
    try:
        if link_root is not None:
            staged.symlink_to(link_root / replacement)
            if staged.resolve(strict=True) != (link_root / replacement).resolve(strict=True):
                raise OSError(f"staged replacement link does not resolve to {link_root / replacement}")
        else:
            shutil.copytree(source / replacement, staged, symlinks=True)
            if safe_skill_tree(staged) or skill_hash(staged) != skill_hash(source / replacement):
                raise OSError("staged replacement differs from source")
        if "insert-target-dir" in FAULTS:
            target.mkdir()
            (target / "SKILL.md").write_text("inserted\n", encoding="utf-8")
        if "insert-target-symlink" in FAULTS:
            target.symlink_to("/nonexistent-inserted-target")
        try:
            rename_noreplace(staged, target)
        except OSError as error:
            if error.errno == errno.EEXIST:
                return "replacement collision with existing differing new target"
            if error.errno in NO_REPLACE_UNSUPPORTED:
                raise NoReplaceUnavailable(
                    f"atomic no-replace rename is unavailable ({error.strerror}); replacement {replacement} not installed"
                ) from error
            raise
    finally:
        if staged.exists() or staged.is_symlink():
            remove_entry(staged)
    crash("after-promote")
    ready, reason = replacement_ready(destination, replacement, source, link_root)
    if not ready:
        raise OSError(f"replacement verification failed: {reason}")
    return None


def retire(path: Path, backup_base: Path, name: str, staging_area: Any) -> None:
    """Move a legacy entry into its backup; its working path is intact or absent, never partial."""
    backup_root = backup_base / name
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
        shutil.copytree(link_target, backup / f"{name}.target", symlinks=True)
        saved.symlink_to(os.readlink(path))
        path.unlink()
        return
    try:
        if "force-exdev" in FAULTS:
            raise OSError(errno.EXDEV, "forced by SKILLS_MIGRATE_FAULT", str(saved))
        os.rename(path, saved)
        return
    except OSError as error:
        if error.errno != errno.EXDEV:
            raise
    # Backup on another filesystem: copy it, then delete only from the staging area.
    shutil.copytree(path, saved, symlinks=True)
    retiring = staging_area() / f".retiring-{name}"
    os.rename(path, retiring)
    remove_tree(retiring, "mid-retirement")


def write_lock(path: Path, lock: dict[str, Any], source: Path, updates: dict[str, dict[str, str] | None]) -> None:
    skills = dict(lock["skills"])
    trees = lock.get("trees")
    for name, digest in updates.items():
        if digest is None:
            skills.pop(name, None)
        else:
            skills[name] = digest
        # install.sh's v2 tree digest; this helper writes v1 records only.
        if isinstance(trees, dict):
            trees.pop(name, None)
    lock["skills"] = dict(sorted(skills.items()))
    lock["source"] = str(source)
    lock["updated_at"] = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    data = json.dumps(lock, indent=2, sort_keys=False) + "\n"
    fd, temp_name = tempfile.mkstemp(prefix=f".{path.name}.", suffix=".tmp", dir=path.parent)
    temp = Path(temp_name)
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as file:
            if "fail-lock-write" in FAULTS:
                raise OSError(errno.EIO, "forced by SKILLS_MIGRATE_FAULT", str(temp))
            file.write(data)
            file.flush()
            os.fsync(file.fileno())
        try:
            mode = stat.S_IMODE(os.stat(path).st_mode)
        except FileNotFoundError:
            mode = 0o644
        os.chmod(temp, mode)
        os.replace(temp, path)
    except BaseException:
        try:
            temp.unlink()
        except FileNotFoundError:
            pass
        raise
    fsync_dir(path.parent)


def migrate(args: argparse.Namespace) -> int:
    source = args.source.resolve(strict=True)
    destination = args.dest.resolve(strict=False)
    if destination == source or path_is_within(destination, source):
        raise ValidationError("destination overlaps the source tree")
    link_root = args.link_root.resolve(strict=True) if args.link_root else None
    if link_root is not None:
        if link_root == destination or link_root == source or path_is_within(link_root, source):
            raise ValidationError("link root aliases a protected source or destination")
    protected_root = args.protected_root.resolve(strict=False) if args.protected_root else None
    backup_base = args.backup_dir.resolve(strict=False) if args.backup_dir else destination.parent / ".skills-backups" / destination.name
    if backup_base == destination or path_is_within(backup_base, destination):
        raise ValidationError("backup directory must be outside the destination")
    if backup_base == source or path_is_within(backup_base, source):
        raise ValidationError("backup directory must be outside the source")
    if link_root is not None and (backup_base == link_root or path_is_within(backup_base, link_root)):
        raise ValidationError("backup directory must be outside the canonical link root")
    if protected_root is not None and (backup_base == protected_root or path_is_within(backup_base, protected_root)):
        raise ValidationError("backup directory must be outside the protected root")
    namespace_root = destination.parent / STAGING_NAMESPACE
    namespace = namespace_root / destination.name
    check_namespace(namespace_root, namespace)
    if overlaps(backup_base, namespace_root):
        raise ValidationError(f"backup directory must be outside the migration staging area {namespace_root}")
    for other, label in ((destination, "destination"), (source, "source")):
        if path_is_within(other, backup_base):
            raise ValidationError(f"backup directory must not contain the {label}")
    if overlaps(namespace_root, source) or (link_root is not None and overlaps(namespace_root, link_root)):
        raise ValidationError(f"migration staging area {namespace_root} overlaps the source or canonical link root")
    manifest = read_manifest(args.manifest, source)
    lock_path = destination / ".skills-lock.json"
    if args.apply:
        hold_installer_lock()
        clear_namespace(namespace_root, namespace)
    try:
        return migrate_locked(args, source, destination, link_root, backup_base, manifest, lock_path, namespace_root, namespace)
    finally:
        if args.apply:
            tidy_namespace(namespace_root, namespace)


def migrate_locked(
    args: argparse.Namespace,
    source: Path,
    destination: Path,
    link_root: Path | None,
    backup_base: Path,
    manifest: dict[str, dict[str, str | None]],
    lock_path: Path,
    namespace_root: Path,
    namespace: Path,
) -> int:
    lock, reason = read_lock(lock_path, source)
    if lock is None:
        print(f"SKIP all: {reason}")
        return 0

    def staging_area() -> Path:
        return ensure_namespace(namespace_root, namespace, destination)

    added: dict[str, dict[str, str] | None] = {}
    retiring: list[tuple[str, str, str | None, Path]] = []
    pruned: list[str] = []
    failed = False
    for old_name, entry in manifest.items():
        old_path = destination / old_name
        owned, reason = owned_target(old_path, old_name, lock, link_root)
        if owned is None:
            # A retirement that stopped before its lock update leaves a record for an absent path.
            if reason == "already absent" and old_name in lock["skills"] and not args.preserve_shared_canonical:
                if args.apply:
                    pruned.append(old_name)
                else:
                    print(f"DRY-RUN prune lock record {old_name}: path already absent")
                continue
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
        if args.preserve_shared_canonical and replacement is None:
            print(f"SKIP {old_name}: shared canonical target retained; manual migration required")
            continue
        detail = f" -> {replacement}" if replacement else ""
        if not args.apply:
            if args.preserve_shared_canonical:
                print(f"DRY-RUN {action} {old_name}{detail}: would install replacement; shared canonical target retained")
            else:
                print(f"DRY-RUN {action} {old_name}{detail}: would install/verify replacement before backup and retire")
            continue
        if replacement is not None:
            try:
                skip_reason = promote_replacement(destination, replacement, source, link_root, staging_area)
            except NoReplaceUnavailable as error:
                print(f"SKIP {old_name}: {error}")
                failed = True
                continue
            if skip_reason:
                print(f"SKIP {old_name}: {skip_reason}")
                continue
            added[replacement] = {"hash": skill_hash(source / replacement), "provenance": PROVENANCE}
        if args.preserve_shared_canonical:
            print(f"APPLIED {action} {old_name}{detail}: shared canonical target retained")
            continue
        retiring.append((old_name, action, replacement, old_path))

    # Publish replacements before retiring anything, then drop retired and stale legacy records.
    if added:
        write_lock(lock_path, lock, source, added)
    removed: dict[str, dict[str, str] | None] = {}
    for old_name, action, replacement, old_path in retiring:
        retire(old_path, backup_base, old_name, staging_area)
        removed[old_name] = None
        detail = f" -> {replacement}" if replacement else ""
        print(f"APPLIED {action} {old_name}{detail}")
    if retiring:
        crash("after-retirement")
    for old_name in pruned:
        removed[old_name] = None
        print(f"APPLIED prune lock record {old_name}: path already absent")
    if removed:
        write_lock(lock_path, lock, source, removed)
    if args.apply and args.applied_file:
        replacements = sorted(added)
        args.applied_file.write_text("\n".join(replacements) + ("\n" if replacements else ""), encoding="utf-8")
    return 1 if failed else 0


def cleanup_legacy_dir(args: argparse.Namespace) -> int:
    """Unlink installer-owned links in a dropped tool dir once the new dir serves the same skill."""
    source = args.source.resolve(strict=True)
    legacy = args.legacy_dir
    if not legacy.is_dir():
        return 0
    legacy_real = legacy.resolve(strict=True)
    new_real = args.new_dir.resolve(strict=False)
    canonical = args.link_root.resolve(strict=False)
    for other, label in ((new_real, "new directory"), (canonical, "canonical directory"), (source, "source")):
        if legacy_real == other or path_is_within(legacy_real, other) or path_is_within(other, legacy_real):
            print(f"SKIP all: legacy directory aliases the {label}")
            return 0
    backup_base = args.backup_dir.resolve(strict=False)
    for other in (legacy_real, new_real, canonical, source):
        if backup_base == other or path_is_within(backup_base, other):
            raise ValidationError("backup directory must be outside the legacy, new, canonical, and source directories")
    if args.apply:
        hold_installer_lock()
    lock_path = legacy / ".skills-lock.json"
    lock, reason = read_lock(lock_path, source)
    if lock is None:
        if reason in {"missing lock file", "lock source does not match requested source"}:
            print(f"SKIP all: {reason}")
            return 0
        raise ValidationError(f"{lock_path}: {reason}")

    removable: list[str] = []
    stale: list[str] = []
    for name in sorted(lock["skills"]):
        path = legacy / name
        if not path.exists() and not path.is_symlink():
            stale.append(name)
            continue
        if not path.is_symlink():
            print(f"SKIP {name}: not a symlink; left in place")
            continue
        try:
            target = path.resolve(strict=True)
        except OSError:
            print(f"SKIP {name}: broken symlink; left in place")
            continue
        try:
            expected = (canonical / name).resolve(strict=True)
        except OSError:
            expected = None
        if expected is None or target != expected:
            print(f"SKIP {name}: symlink does not point at the canonical skill; left in place")
            continue
        replacement = args.new_dir / name
        try:
            replaced = (replacement / "SKILL.md").is_file() and replacement.resolve(strict=True) == expected
        except OSError:
            replaced = False
        if not replaced:
            print(f"SKIP {name}: no verified replacement in {args.new_dir}")
            continue
        removable.append(name)
    listed = set(lock["skills"])
    for entry in sorted(legacy.iterdir()):
        if not entry.name.startswith(".") and entry.name not in listed:
            print(f"SKIP {entry.name}: not recorded in the lock; left in place")

    if not removable and not stale:
        print("NOOP: nothing to clean up")
        return 0
    if not args.apply:
        for name in removable:
            print(f"DRY-RUN unlink {name}: replacement verified in {args.new_dir}")
        for name in stale:
            print(f"DRY-RUN prune lock record {name}: path already absent")
        return 0

    stamp = datetime.now(timezone.utc).strftime("%Y%m%d-%H%M%S")
    backup = backup_base / ".legacy-dir-cleanup" / stamp
    suffix = 1
    while backup.exists() or backup.is_symlink():
        suffix += 1
        backup = backup_base / ".legacy-dir-cleanup" / f"{stamp}-{suffix}"
    try:
        backup.mkdir(parents=True)
        shutil.copy2(lock_path, backup / ".skills-lock.json")
        rows = []
        for name in removable:
            link_target = os.readlink(legacy / name)
            (backup / name).symlink_to(link_target)
            rows.append(f"{name}\t{legacy / name}\t{link_target}\n")
        (backup / "links.tsv").write_text("".join(rows), encoding="utf-8")
    except OSError as error:
        raise ValidationError(f"backup failed, nothing removed: {error}") from error
    print(f"BACKUP {backup}")

    updates: dict[str, dict[str, str] | None] = {}
    for name in removable:
        (legacy / name).unlink()
        updates[name] = None
        print(f"APPLIED unlink {name}")
    for name in stale:
        updates[name] = None
        print(f"APPLIED prune lock record {name}")
    if all(name in updates for name in lock["skills"]):
        lock_path.unlink()
        print(f"APPLIED remove lock {lock_path}")
    else:
        write_lock(lock_path, lock, source, updates)
    return 0


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--manifest", type=Path)
    parser.add_argument("--source", type=Path, required=True)
    parser.add_argument("--dest", type=Path)
    parser.add_argument("--legacy-dir", type=Path)
    parser.add_argument("--new-dir", type=Path)
    parser.add_argument("--link-root", type=Path)
    parser.add_argument("--protected-root", type=Path)
    parser.add_argument("--backup-dir", type=Path)
    parser.add_argument("--applied-file", type=Path)
    parser.add_argument("--preserve-shared-canonical", action="store_true")
    parser.add_argument("--apply", action="store_true")
    args = parser.parse_args()
    if args.legacy_dir is not None:
        if args.new_dir is None or args.link_root is None or args.backup_dir is None:
            parser.error("--legacy-dir requires --new-dir, --link-root, and --backup-dir")
    elif args.manifest is None or args.dest is None:
        parser.error("--manifest and --dest are required")
    return args


def main() -> int:
    try:
        args = parse_args()
        if args.legacy_dir is not None:
            return cleanup_legacy_dir(args)
        return migrate(args)
    except LockBusy as error:
        print(f"ERROR: {error}", file=sys.stderr)
        return LOCK_BUSY_EXIT
    except (ValidationError, OSError) as error:
        print(f"ERROR: {error}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
