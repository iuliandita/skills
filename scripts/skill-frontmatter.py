#!/usr/bin/env python3
"""Parse and query skill frontmatter without external dependencies."""

from __future__ import annotations

import json
import pathlib
import sys
from typing import Any


def load_frontmatter(path_str: str) -> dict[str, Any]:
    text = pathlib.Path(path_str).read_text(encoding="utf-8")
    lines = text.splitlines()
    if not lines or lines[0] != "---":
        raise ValueError("missing frontmatter start")

    try:
        end_index = lines[1:].index("---") + 1
    except ValueError as exc:
        raise ValueError("missing frontmatter end") from exc

    data, next_index = parse_mapping(lines[1:end_index])
    if next_index != end_index - 1:
        raise ValueError("unexpected trailing content in frontmatter")

    return data


def get_value(data: dict[str, Any], path: str) -> Any:
    current: Any = data
    for segment in path.split("."):
        if not isinstance(current, dict) or segment not in current:
            raise KeyError(path)
        current = current[segment]

    if current is None:
        raise KeyError(path)

    return current


def print_value(value: Any) -> None:
    print(format_value(value))


def parse_mapping(lines: list[str], start: int = 0, indent: int = 0) -> tuple[dict[str, Any], int]:
    data: dict[str, Any] = {}
    index = start

    while index < len(lines):
        line = lines[index]
        if not line.strip():
            index += 1
            continue

        current_indent = len(line) - len(line.lstrip(" "))
        if current_indent < indent:
            break
        if current_indent > indent:
            raise ValueError(f"unexpected indentation: {line!r}")

        stripped = line.strip()
        if ":" not in stripped:
            raise ValueError(f"expected key/value pair: {line!r}")

        key, raw_value = stripped.split(":", 1)
        raw_value = raw_value.lstrip()

        if not raw_value:
            value, index = parse_nested(lines, index + 1, indent + 2)
            data[key] = value
            continue

        if raw_value in {">", "|"}:
            value, index = parse_block(lines, index + 1, indent + 2, raw_value)
            data[key] = value
            continue

        data[key] = parse_scalar(raw_value)
        index += 1

    return data, index


def parse_nested(lines: list[str], start: int, indent: int) -> tuple[Any, int]:
    index = start
    while index < len(lines) and not lines[index].strip():
        index += 1

    if index >= len(lines):
        raise ValueError("expected nested value")

    current_indent = len(lines[index]) - len(lines[index].lstrip(" "))
    if current_indent < indent:
        raise ValueError("expected nested value")

    if lines[index].strip().startswith("- "):
        return parse_sequence(lines, index, indent)
    return parse_mapping(lines, index, indent)


def parse_sequence(lines: list[str], start: int, indent: int) -> tuple[list[Any], int]:
    items: list[Any] = []
    index = start

    while index < len(lines):
        line = lines[index]
        if not line.strip():
            index += 1
            continue

        current_indent = len(line) - len(line.lstrip(" "))
        if current_indent < indent:
            break
        if current_indent != indent:
            raise ValueError(f"unexpected indentation in sequence: {line!r}")

        stripped = line.strip()
        if not stripped.startswith("- "):
            break

        item = stripped[2:].lstrip()
        if not item:
            raise ValueError(f"empty sequence item: {line!r}")

        items.append(parse_scalar(item))
        index += 1

    return items, index


def parse_block(lines: list[str], start: int, indent: int, style: str) -> tuple[str, int]:
    block_lines: list[str] = []
    index = start

    while index < len(lines):
        line = lines[index]
        if not line.strip():
            block_lines.append("")
            index += 1
            continue

        current_indent = len(line) - len(line.lstrip(" "))
        if current_indent < indent:
            break

        block_lines.append(line[indent:])
        index += 1

    if style == "|":
        return "\n".join(block_lines).rstrip(), index

    paragraphs: list[str] = []
    current: list[str] = []
    for line in block_lines:
        if line == "":
            if current:
                paragraphs.append(" ".join(current))
                current = []
            if not paragraphs or paragraphs[-1] != "":
                paragraphs.append("")
            continue
        current.append(line.strip())

    if current:
        paragraphs.append(" ".join(current))

    return "\n".join(part for part in paragraphs if part != "" or len(paragraphs) == 1).rstrip(), index


def parse_scalar(raw_value: str) -> Any:
    if len(raw_value) >= 2 and raw_value[0] == raw_value[-1] and raw_value[0] in {"'", '"'}:
        return raw_value[1:-1]

    lowered = raw_value.lower()
    if lowered in {"true", "yes"}:
        return True
    if lowered in {"false", "no"}:
        return False

    return raw_value


def format_value(value: Any) -> str:
    if isinstance(value, bool):
        return "true" if value else "false"
    if isinstance(value, (dict, list)):
        return json.dumps(value, sort_keys=True)
    return str(value)


def flag(data: dict[str, Any], path: str) -> str:
    try:
        return "true" if format_value(get_value(data, path)) == "true" else "false"
    except KeyError:
        return "false"


def batch(skills_dir: str) -> int:
    """Print dir, name, internal, deprecated as TSV for every skill dir."""
    root = pathlib.Path(skills_dir)
    if not root.is_dir():
        print(f"batch: not a directory: {skills_dir}", file=sys.stderr)
        return 2

    rows: list[str] = []
    for entry in sorted(root.iterdir(), key=lambda item: item.name):
        skill_md = entry / "SKILL.md"
        if entry.name.startswith(".") or not entry.is_dir() or not skill_md.is_file():
            continue
        try:
            data = load_frontmatter(str(skill_md))
            name = data.get("name")
            name = "" if name is None else format_value(name)
            if any(char in name for char in "\t\n\r"):
                raise ValueError("name contains a tab or newline")
        except (OSError, ValueError) as exc:
            print(f"invalid frontmatter in {skill_md}: {exc}", file=sys.stderr)
            return 1
        rows.append("\t".join((entry.name, name, flag(data, "metadata.internal"), flag(data, "metadata.deprecated"))))

    for row in rows:
        print(row)
    return 0


def fields(skills_dir: str, paths: list[str]) -> int:
    """Emit NUL-separated records: dir, valid, then has and value per path.

    Mirrors the valid, has and get subcommands for every skill dir at once, so
    shell callers can answer per-field lookups without a python fork each.
    """
    root = pathlib.Path(skills_dir)
    if not root.is_dir():
        print(f"fields: not a directory: {skills_dir}", file=sys.stderr)
        return 2

    out = sys.stdout.buffer
    for entry in sorted(root.iterdir(), key=lambda item: item.name):
        skill_md = entry / "SKILL.md"
        if not entry.is_dir() or not skill_md.is_file():
            continue
        try:
            data = load_frontmatter(str(skill_md))
            record = [entry.name, "1"]
        except (OSError, ValueError):
            data = {}
            record = [entry.name, "0"]
        for path in paths:
            try:
                record += ["1", format_value(get_value(data, path))]
            except KeyError:
                record += ["0", ""]
        out.write(b"".join(field.encode("utf-8", "surrogateescape") + b"\0" for field in record))
    return 0


def main(argv: list[str]) -> int:
    if len(argv) < 3:
        print(
            "usage: skill-frontmatter.py {valid|get|has} <file> [path] | batch <skills-dir>"
            " | fields <skills-dir> <path>...",
            file=sys.stderr,
        )
        return 2

    command = argv[1]
    if command == "batch":
        return batch(argv[2])
    if command == "fields":
        return fields(argv[2], argv[3:])

    file_path = argv[2]

    try:
        data = load_frontmatter(file_path)
        if command == "valid":
            return 0
        if len(argv) < 4:
            print(f"{command}: missing path", file=sys.stderr)
            return 2
        value = get_value(data, argv[3])
    except (OSError, ValueError, KeyError):
        return 1

    if command == "get":
        print_value(value)
        return 0
    if command == "has":
        return 0

    print(f"unknown command: {command}", file=sys.stderr)
    return 2


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
