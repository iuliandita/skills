#!/usr/bin/env python3
"""Check a repository against the shared stack conventions in canon.json and repo.json.

Run from the repository root. Reads canon.json and repo.json from this file's directory,
uses only the Python standard library, and makes no network calls.
"""
from __future__ import annotations

import argparse
import ast
import codecs
import fnmatch
import hashlib
import json
import os
import re
import struct
import subprocess
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Callable

if sys.version_info < (3, 11):
    sys.exit("error: stack-check: Python 3.11 or newer is required; run it with python3.11+")

HERE = Path(__file__).resolve().parent
PROG = "stack-check"
FENCE_RE = re.compile(r"^\s*(?:```|~~~)")
BINARY_SUFFIXES = {".png", ".jpg", ".jpeg", ".gif", ".ico", ".pdf", ".zip", ".gz", ".woff", ".woff2"}
HELP_EPILOG = """\
Environment:
  None. The checker reads no environment variables.

Exit codes:
  0  no findings
  1  one or more findings
  2  usage error, or canon.json or repo.json is missing or invalid
  3  git is missing in a git checkout
"""


class UsageError(Exception):
    pass


class ToolMissing(Exception):
    pass


@dataclass
class Finding:
    check: str
    file: str
    message: str
    fix: str
    line: int | None = None

    def location(self) -> str:
        return f"{self.file}:{self.line}" if self.line else self.file

    def render(self) -> str:
        return f"error: {self.check}: {self.location()}: {self.message}; {self.fix}"

    def as_dict(self) -> dict:
        return {
            "check": self.check,
            "file": self.file,
            "line": self.line,
            "message": self.message,
            "fix": self.fix,
        }


class Ctx:
    def __init__(self, root: Path, canon: dict, repo: dict) -> None:
        self.root = root
        self.canon = canon
        self.repo = repo
        self.files = list_files(root)
        self._text: dict[str, str | None] = {}

    def text(self, rel: str) -> str | None:
        if rel not in self._text:
            try:
                self._text[rel] = (self.root / rel).read_text(encoding="utf-8", errors="replace")
            except OSError:
                self._text[rel] = None
        return self._text[rel]


def list_files(root: Path) -> list[str]:
    """Tracked plus untracked-but-not-ignored files, so a check also sees work before it is committed."""
    if (root / ".git").exists():
        try:
            proc = subprocess.run(
                ["git", "-C", str(root), "ls-files", "-z", "--cached", "--others", "--exclude-standard"],
                capture_output=True,
                check=True,
            )
        except FileNotFoundError as exc:
            raise ToolMissing("git") from exc
        except subprocess.CalledProcessError as exc:
            raise UsageError(f"git ls-files failed in {root}: {exc.stderr.decode(errors='replace').strip()}") from exc
        names = proc.stdout.decode("utf-8", errors="surrogateescape").split("\0")
        return sorted({n for n in names if n and os.path.lexists(root / n)})
    skip = {".git", "__pycache__", ".pytest_cache", ".venv", "node_modules"}
    found: list[str] = []
    for base, dirs, names in os.walk(root):
        dirs[:] = [d for d in dirs if d not in skip]
        for name in names:
            found.append(Path(base, name).relative_to(root).as_posix())
    return sorted(found)


def md_lines(text: str):
    """Yield (number, line, in_fence); fence delimiter lines count as fenced."""
    fenced = False
    for number, line in enumerate(text.splitlines(), start=1):
        if FENCE_RE.match(line):
            yield number, line, True
            fenced = not fenced
            continue
        yield number, line, fenced


def md_headings(text: str, level: int = 2) -> list[tuple[int, str]]:
    pattern = re.compile(rf"^#{{{level}}}\s+(.*?)\s*#*\s*$")
    out = []
    for number, line, fenced in md_lines(text):
        match = pattern.match(line) if not fenced else None
        if match:
            out.append((number, match.group(1)))
    return out


def md_section(text: str, heading: str) -> list[tuple[int, str]] | None:
    """Lines (number, text) under a `##` heading up to the next `##`; None when the heading is absent."""
    inside = found = False
    lines: list[tuple[int, str]] = []
    for number, line, fenced in md_lines(text):
        match = None if fenced else re.match(r"^##\s+(.*?)\s*#*\s*$", line)
        if match:
            if inside:
                break
            inside = match.group(1) == heading
            found = found or inside
            continue
        if inside:
            lines.append((number, line))
    return lines if found else None


def order_findings(check: str, rel: str, text: str, required: list[str], fix_word: str) -> list[Finding]:
    headings = md_headings(text)
    first: dict[str, int] = {}
    for number, title in headings:
        first.setdefault(title, number)
    findings = [
        Finding(check, rel, f'missing section "## {name}"', f'add "## {name}" ({fix_word})')
        for name in required
        if name not in first
    ]
    present = [name for name in required if name in first]
    for before, after in zip(present, present[1:]):
        if first[before] > first[after]:
            findings.append(
                Finding(
                    check,
                    rel,
                    f'"## {after}" comes before "## {before}"',
                    f'move "## {after}" below "## {before}"',
                    first[after],
                )
            )
    return findings


# ---------------------------------------------------------------- README

def readme(ctx: Ctx) -> tuple[str, str] | None:
    rel = ctx.canon["readme"]["file"]
    text = ctx.text(rel)
    return (rel, text) if text is not None else None


def heading_block(lines: list[str]) -> tuple[str | None, str | None, int, int]:
    """Return (kind, name, first_index, end_index_exclusive) for the first heading of the README."""
    i = 0
    while i < len(lines) and (not lines[i].strip() or lines[i].strip().startswith("<!--")):
        i += 1
    if i >= len(lines):
        return None, None, i, i
    first = lines[i]
    md = re.match(r"^#\s+(.*?)\s*#*\s*$", first)
    if md:
        return "markdown", md.group(1), i, i + 1
    if re.match(r"^\s*<h1\b", first, re.I):
        j = i
        while j < len(lines) and "</h1>" not in lines[j].lower():
            j += 1
        inner = "\n".join(lines[i : j + 1])
        alt = re.search(r'alt="([^"]*)"', inner)
        return "html", alt.group(1) if alt else "", i, min(j + 1, len(lines))
    return None, first.strip(), i, i


def check_readme_title(ctx: Ctx) -> list[Finding]:
    found = readme(ctx)
    rel = ctx.canon["readme"]["file"]
    if not found:
        return [Finding("readme-title", rel, "file is missing", f"create {rel}")]
    lines = found[1].splitlines()
    kind, name, start, _ = heading_block(lines)
    expected = ctx.repo["repo"]
    if kind is None:
        return [Finding("readme-title", rel, "first content is not a heading", f'start with "# {expected}" or an <h1> whose img alt is "{expected}"', start + 1)]
    if name != expected:
        return [Finding("readme-title", rel, f'first heading names "{name}", not the repo name', f'change it to "{expected}"', start + 1)]
    return []


def check_readme_wordmark(ctx: Ctx) -> list[Finding]:
    found = readme(ctx)
    if not found:
        return []
    cfg = ctx.canon["readme"]
    head = "\n".join(found[1].splitlines()[: cfg["wordmark_within_lines"]])
    if cfg["wordmark"] in head:
        return []
    return [
        Finding(
            "readme-wordmark",
            found[0],
            f'{cfg["wordmark"]} is not referenced in the first {cfg["wordmark_within_lines"]} lines',
            f'add <img src="{cfg["wordmark"]}" alt="{ctx.repo["repo"]}" width="360"> under the title',
        )
    ]


def intro_paragraph(lines: list[str], start: int) -> tuple[int, str] | None:
    skip = ("<", "![", "[![", "#", ">", "|", "```", "~~~")
    i = start
    while i < len(lines):
        s = lines[i].strip()
        if s.startswith("## "):
            return None
        if s and not s.startswith(skip) and not re.match(r"^[-*+]\s", s):
            break
        i += 1
    else:
        return None
    first = i
    parts = []
    while i < len(lines):
        s = lines[i].strip()
        if not s or s.startswith(skip):
            break
        parts.append(s)
        i += 1
    return first + 1, " ".join(parts)


def check_readme_intro(ctx: Ctx) -> list[Finding]:
    found = readme(ctx)
    if not found:
        return []
    rel, text = found
    cfg = ctx.canon["readme"]
    lines = text.splitlines()
    _, _, _, end = heading_block(lines)
    para = intro_paragraph(lines, end)
    if para is None:
        return [Finding("readme-intro", rel, "no opening paragraph before the first section", "add one sentence saying what the repo is and for whom")]
    number, body = para
    findings = []
    if not cfg["intro_min_chars"] <= len(body) <= cfg["intro_max_chars"]:
        findings.append(
            Finding(
                "readme-intro",
                rel,
                f'opening paragraph is {len(body)} characters, expected {cfg["intro_min_chars"]}-{cfg["intro_max_chars"]}',
                "rewrite it as one sentence of what the repo is and for whom",
                number,
            )
        )
    if re.search(r"\*\*|__|<b>|<strong>", body):
        findings.append(Finding("readme-intro", rel, "opening paragraph uses bold", "remove the bold markup", number))
    if re.search(cfg["intro_version_regex"], body):
        findings.append(Finding("readme-intro", rel, "opening paragraph contains a version number", "move the version to the Status line", number))
    return findings


def check_readme_status(ctx: Ctx) -> list[Finding]:
    found = readme(ctx)
    if not found:
        return []
    rel, text = found
    cfg = ctx.canon["readme"]
    for number, line, fenced in md_lines(text):
        if not fenced and re.match(r"^##\s", line):
            break
        if not fenced and line.startswith(cfg["status_prefix"]):
            missing = [m for m in cfg["status_mentions"] if m not in line]
            if missing:
                return [Finding("readme-status", rel, f'status line does not mention {", ".join(missing)}', "state that main is the stable channel and develop the nightly", number)]
            return []
    return [Finding("readme-status", rel, f'no line starting with "{cfg["status_prefix"]}" before the first section', "add a status line under the opening paragraphs")]


def check_readme_sections(ctx: Ctx) -> list[Finding]:
    found = readme(ctx)
    if not found:
        return []
    return order_findings("readme-sections", found[0], found[1], ctx.canon["readme"]["sections"], "rename a near-equivalent section if one exists")


def expected_stack(ctx: Ctx) -> list[str]:
    cfg = ctx.canon["readme"]
    out = []
    for item in cfg["stack_repos"]:
        name, desc = item["name"], item["description"]
        if name == ctx.repo["repo"]:
            out.append(f"- {name}: {desc}")
        else:
            out.append(f'- [{name}]({cfg["stack_url_prefix"]}{name}): {desc}')
    out.append(cfg["stack_closing"])
    return out


def check_readme_stack(ctx: Ctx) -> list[Finding]:
    found = readme(ctx)
    if not found:
        return []
    rel, text = found
    cfg = ctx.canon["readme"]
    if ctx.repo["repo"] not in [r["name"] for r in cfg["stack_repos"]]:
        return [Finding("readme-stack", "repo.json", f'repo "{ctx.repo["repo"]}" is not listed in canon.json', "fix repo.json or update canon.json")]
    section = md_section(text, cfg["stack_heading"])
    if section is None:
        return [Finding("readme-stack", rel, f'missing section "## {cfg["stack_heading"]}"', "add it with the canonical lines")]
    actual = [(n, line.rstrip()) for n, line in section if line.strip()]
    expected = expected_stack(ctx)
    findings = []
    for index, want in enumerate(expected):
        if index >= len(actual):
            findings.append(Finding("readme-stack", rel, f'missing line "{want}"', "add it to the section"))
        elif actual[index][1] != want:
            findings.append(Finding("readme-stack", rel, f'line is "{actual[index][1]}"', f'use "{want}"', actual[index][0]))
    for number, line in actual[len(expected) :]:
        findings.append(Finding("readme-stack", rel, f'unexpected line "{line}"', "remove it", number))
    return findings


def check_readme_project(ctx: Ctx) -> list[Finding]:
    found = readme(ctx)
    if not found:
        return []
    rel, text = found
    cfg = ctx.canon["readme"]
    section = md_section(text, cfg["project_heading"])
    if section is None:
        return [Finding("readme-project", rel, f'missing section "## {cfg["project_heading"]}"', "add it with the Made by line")]
    body = "\n".join(line for _, line in section)
    findings = []
    if cfg["project_line"] not in body:
        findings.append(Finding("readme-project", rel, "the Made by line is missing or changed", f'use "{cfg["project_line"]}"'))
    for item in cfg["stack_repos"]:
        link = f'{cfg["stack_url_prefix"]}{item["name"]}'
        for number, line in section:
            if re.search(re.escape(link) + r"(?![\w-])", line):
                findings.append(Finding("readme-project", rel, f"links the {item['name']} repo", "keep sibling links in Part of the stack", number))
    return findings


# ---------------------------------------------------------------- assets, CONTRIBUTING

def png_size(path: Path) -> tuple[int, int] | None:
    try:
        head = path.read_bytes()[:24]
    except OSError:
        return None
    if len(head) < 24 or head[:8] != b"\x89PNG\r\n\x1a\n" or head[12:16] != b"IHDR":
        return None
    return struct.unpack(">II", head[16:24])


def check_assets(ctx: Ctx) -> list[Finding]:
    cfg = ctx.canon["assets"]
    findings = []
    for rel in cfg["files"]:
        if rel not in ctx.files:
            findings.append(Finding("assets", rel, "file is missing", "copy the shared logo files into assets/"))
            continue
        if rel.endswith(".png"):
            size = png_size(ctx.root / rel)
            if size is None:
                findings.append(Finding("assets", rel, "not a valid PNG file", "replace it with the shared logo file"))
            elif rel in cfg["png_sizes"] and list(size) != cfg["png_sizes"][rel]:
                want = "x".join(map(str, cfg["png_sizes"][rel]))
                findings.append(Finding("assets", rel, f"size is {size[0]}x{size[1]}, expected {want}", "replace it with the shared logo file"))
    return findings


def check_contributing(ctx: Ctx) -> list[Finding]:
    cfg = ctx.canon["contributing"]
    rel = cfg["file"]
    text = ctx.text(rel)
    if text is None:
        return [Finding("contributing", rel, "file is missing", f"create {rel} from the shared outline")]
    lines = text.splitlines()
    findings = []
    start = next((i for i, line in enumerate(lines) if line.startswith("# ")), -1) + 1
    while start < len(lines) and not lines[start].strip():
        start += 1
    end = start
    while end < len(lines) and lines[end].strip():
        end += 1
    opening = " ".join(" ".join(lines[start:end]).split())
    if opening != " ".join(cfg["opening"].split()):
        findings.append(Finding("contributing", rel, "opening paragraph differs from the shared text", "copy the opening paragraph from canon.json", start + 1))
    findings += order_findings("contributing", rel, text, cfg["headings"], "see canon.json")
    section = md_section(text, cfg["checks_heading"])
    if section is not None:
        first = next(((n, line) for n, line in section if line.strip()), None)
        if first is None or not re.match(rf"^```\s*{re.escape(cfg['checks_fence_lang'])}\s*$", first[1]):
            findings.append(Finding("contributing", rel, f'"{cfg["checks_heading"]}" does not start with a ```{cfg["checks_fence_lang"]} block', "start with the exact local check commands", first[0] if first else None))
    releases = md_section(text, cfg["releases_heading"])
    if releases is not None:
        body = "\n".join(line for _, line in releases)
        for word in cfg["releases_mention"]:
            if word not in body:
                findings.append(Finding("contributing", rel, f'"{cfg["releases_heading"]}" does not mention {word}', "describe the branch and release flow"))
    return findings


# ---------------------------------------------------------------- workflows

def workflow_files(ctx: Ctx) -> list[str]:
    prefix = ctx.canon["workflows"]["dir"] + "/"
    return [f for f in ctx.files if f.startswith(prefix) and f.endswith((".yml", ".yaml"))]


def indent(line: str) -> int:
    return len(line) - len(line.lstrip(" "))


def meaningful(line: str) -> bool:
    return bool(line.strip()) and not line.lstrip().startswith("#")


def parse_jobs(lines: list[str]) -> list[tuple[str, int, int]]:
    """Return (job id, start index, end index exclusive) for each job under the top-level `jobs:` key."""
    jobs: list[tuple[str, int, int]] = []
    in_jobs = False
    current: tuple[str, int] | None = None
    for i, line in enumerate(lines):
        if re.match(r"^jobs:\s*(#.*)?$", line):
            in_jobs = True
            continue
        if not in_jobs or not meaningful(line):
            continue
        if not line.startswith(" "):
            if current:
                jobs.append((current[0], current[1], i))
                current = None
            in_jobs = False
            continue
        match = re.match(r"^  ([A-Za-z0-9_][\w-]*):\s*(#.*)?$", line)
        if match:
            if current:
                jobs.append((current[0], current[1], i))
            current = (match.group(1), i)
    if current:
        jobs.append((current[0], current[1], len(lines)))
    return jobs


def all_jobs(ctx: Ctx) -> list[tuple[str, str, list[str], int, int]]:
    out = []
    for rel in workflow_files(ctx):
        lines = (ctx.text(rel) or "").splitlines()
        for job, start, end in parse_jobs(lines):
            out.append((rel, job, lines, start, end))
    return out


def check_workflow_jobs(ctx: Ctx) -> list[Finding]:
    cfg = ctx.canon["workflows"]
    jobs = all_jobs(ctx)
    found: dict[str, tuple[str, list[str], int, int]] = {}
    for rel, job, lines, start, end in jobs:
        found.setdefault(job, (rel, lines, start, end))
    findings = []
    for job in ctx.repo.get("required_jobs", []):
        if job not in found:
            findings.append(Finding("workflow-jobs", cfg["dir"], f'required job id "{job}" is missing', f'add a job with id "{job}"'))
            continue
        rel, lines, start, end = found[job]
        if not cfg["job_name_equals_id"]:
            continue
        for i in range(start + 1, end):
            match = re.match(r"^    name:\s*(.+?)\s*(?:#.*)?$", lines[i])
            if match:
                name = match.group(1).strip("'\"")
                if name != job:
                    findings.append(Finding("workflow-jobs", rel, f'job "{job}" is named "{name}"', f'set name: {job}', i + 1))
                break
    return findings


USES_RE = re.compile(r"^(\s*)(- )?uses:\s*(?P<ref>[^\s#]+)\s*(?P<comment>#.*)?$")


def check_workflow_pins(ctx: Ctx) -> list[Finding]:
    cfg = ctx.canon["workflows"]
    findings = []
    for rel in workflow_files(ctx):
        for number, line in enumerate((ctx.text(rel) or "").splitlines(), start=1):
            match = USES_RE.match(line)
            if not match:
                continue
            ref = match.group("ref").strip("'\"")
            if ref.startswith("./"):
                continue
            _, _, version = ref.rpartition("@")
            if "@" not in ref or not re.match(cfg["sha_regex"], version):
                findings.append(Finding("workflow-pins", rel, f"{ref} is not pinned to a 40-hex commit SHA", "pin it to the full SHA", number))
            elif not re.match(cfg["version_comment_regex"], match.group("comment") or ""):
                findings.append(Finding("workflow-pins", rel, f"{ref} has no version comment", "add a trailing # vX.Y.Z comment", number))
    return findings


def check_workflow_timeouts(ctx: Ctx) -> list[Finding]:
    findings = []
    for rel, job, lines, start, end in all_jobs(ctx):
        block = lines[start + 1 : end]
        if any(re.match(r"^    uses:", line) for line in block):
            continue
        if not any(re.match(r"^    timeout-minutes:\s*\S", line) for line in block):
            findings.append(Finding("workflow-timeouts", rel, f'job "{job}" has no timeout-minutes', "set a timeout on the job", start + 1))
    return findings


def step_range(lines: list[str], i: int) -> tuple[int, int]:
    match = USES_RE.match(lines[i])
    assert match
    dash = indent(lines[i]) if match.group(2) else indent(lines[i]) - 2
    start = i
    if not match.group(2):
        for j in range(i - 1, -1, -1):
            if not meaningful(lines[j]):
                continue
            if indent(lines[j]) == dash and lines[j].lstrip().startswith("- "):
                start = j
                break
            if indent(lines[j]) < dash:
                break
    end = i + 1
    while end < len(lines) and not (meaningful(lines[end]) and indent(lines[end]) <= dash):
        end += 1
    return start, end


def check_workflow_checkout(ctx: Ctx) -> list[Finding]:
    cfg = ctx.canon["workflows"]
    want = re.escape(cfg["checkout_require"].split(":")[0]) + r":\s*['\"]?false['\"]?\s*(?:#.*)?$"
    findings = []
    for rel in workflow_files(ctx):
        lines = (ctx.text(rel) or "").splitlines()
        for i, line in enumerate(lines):
            match = USES_RE.match(line)
            if not match or not match.group("ref").strip("'\"").startswith(cfg["checkout_action"] + "@"):
                continue
            start, end = step_range(lines, i)
            if not any(re.match(rf"^\s*{want}", step) for step in lines[start:end]):
                findings.append(Finding("workflow-checkout", rel, "checkout step does not set persist-credentials: false", f"add {cfg['checkout_require']} under with:", i + 1))
    return findings


# ---------------------------------------------------------------- installer help

def check_installer_help(ctx: Ctx) -> list[Finding]:
    cfg = ctx.canon["installer_help"]
    findings = []
    for entry in ctx.repo.get("installers", []):
        argv = entry["argv"]
        label = " ".join(argv)
        try:
            proc = subprocess.run(
                argv,
                cwd=ctx.root,
                capture_output=True,
                text=True,
                errors="replace",
                timeout=cfg["timeout_seconds"],
                env={**os.environ, "NO_COLOR": "1", "PYTHONDONTWRITEBYTECODE": "1"},
            )
        except (OSError, subprocess.TimeoutExpired) as exc:
            findings.append(Finding("installer-help", label, f"could not run: {exc}", "fix the argv in repo.json or the command"))
            continue
        out = proc.stdout + "\n" + proc.stderr
        if proc.returncode != 0:
            findings.append(Finding("installer-help", label, f"exited {proc.returncode}", "make --help exit 0"))
            continue
        for flag in entry.get("flags", []):
            if not re.search(rf"(?<![\w-]){re.escape(flag)}(?![\w-])", out):
                findings.append(Finding("installer-help", label, f"--help does not list {flag}", f"add {flag} to the command and its help"))
        for section in cfg["sections"]:
            if not re.search(rf"^\s*{re.escape(section)}\b", out, re.M):
                findings.append(Finding("installer-help", label, f'--help has no "{section}" section', f'add an "{section}" section to the help text'))
    return findings


# ---------------------------------------------------------------- error strings, ASCII, private patterns

def under(rel: str, paths: list[str]) -> bool:
    return any(rel == p.rstrip("/") or rel.startswith(p.rstrip("/") + "/") for p in paths)


def literal_prefix(node: ast.AST) -> str | None:
    """Leading literal text of a string expression, or None when the argument is not a string literal."""
    if isinstance(node, ast.Constant):
        return node.value if isinstance(node.value, str) else None
    if isinstance(node, ast.JoinedStr):
        first = node.values[0] if node.values else None
        return first.value if isinstance(first, ast.Constant) and isinstance(first.value, str) else ""
    if isinstance(node, ast.BinOp) and isinstance(node.op, (ast.Add, ast.Mod)):
        return literal_prefix(node.left)
    if isinstance(node, ast.Call) and isinstance(node.func, ast.Attribute) and node.func.attr == "format":
        return literal_prefix(node.func.value)
    return None


def is_exit_call(node: ast.Call) -> bool:
    func = node.func
    if isinstance(func, ast.Name):
        return func.id == "SystemExit"
    return isinstance(func, ast.Attribute) and func.attr == "exit" and isinstance(func.value, ast.Name) and func.value.id == "sys"


def check_error_format(ctx: Ctx) -> list[Finding]:
    cfg = ctx.canon["errors"]
    forbidden = re.compile(cfg["forbidden_regex"])
    allowed = re.compile(cfg["allowed_prefix_regex"])
    findings = []
    for rel in ctx.files:
        if not under(rel, ctx.repo.get("error_scan", {}).get("paths", [])):
            continue
        if any(fnmatch.fnmatch(rel, pat) for pat in ctx.repo.get("error_scan", {}).get("exclude", [])):
            continue
        if Path(rel).suffix.lower() in BINARY_SUFFIXES | {".pyc"}:
            continue
        text = ctx.text(rel)
        if text is None or "\0" in text:
            continue
        for number, line in enumerate(text.splitlines(), start=1):
            if forbidden.search(line):
                findings.append(Finding("error-format", rel, "upper-case ERROR: prefix", "use a lower-case error: prefix on stderr", number))
        if rel.endswith(".py"):
            try:
                tree = ast.parse(text)
            except SyntaxError as exc:
                findings.append(Finding("error-format", rel, f"could not be parsed: {exc.msg}", "fix the syntax error", exc.lineno))
                continue
            for node in ast.walk(tree):
                if isinstance(node, ast.Call) and is_exit_call(node) and node.args:
                    prefix = literal_prefix(node.args[0])
                    if prefix is not None and not allowed.match(prefix):
                        findings.append(Finding("error-format", rel, "exit message has no error:, warning:, or note: prefix", 'start the text with "error: "', node.lineno))
    return findings


def check_ascii_markdown(ctx: Ctx) -> list[Finding]:
    suffixes = tuple(ctx.canon["ascii"]["suffixes"])
    findings = []
    for rel in ctx.files:
        if not rel.endswith(suffixes) or (ctx.root / rel).is_symlink():
            continue
        try:
            data = (ctx.root / rel).read_bytes()
        except OSError:
            continue
        text = data.decode("utf-8", errors="replace")
        bad_lines = [(n, line) for n, line in enumerate(text.splitlines(), start=1) if not line.isascii()]
        if not bad_lines:
            continue
        number, line = bad_lines[0]
        col, char = next((i, c) for i, c in enumerate(line, start=1) if ord(c) > 127)
        more = f" and {len(bad_lines) - 1} more lines" if len(bad_lines) > 1 else ""
        findings.append(Finding("ascii-markdown", rel, f"non-ASCII character U+{ord(char):04X} at column {col}{more}", "replace it with ASCII", number))
    return findings


def decode_variants(data: bytes) -> list[str]:
    if b"\0" not in data:
        return [data.decode("utf-8", errors="replace")]
    for bom, codec in (
        (codecs.BOM_UTF32_LE, "utf-32"),
        (codecs.BOM_UTF32_BE, "utf-32"),
        (codecs.BOM_UTF16_LE, "utf-16"),
        (codecs.BOM_UTF16_BE, "utf-16"),
    ):
        if data.startswith(bom):
            return [data.decode(codec, errors="replace")]
    texts = []
    for codec in ("utf-32-le", "utf-32-be", "utf-16-le", "utf-16-be"):
        try:
            texts.append(data.decode(codec))
        except UnicodeDecodeError:
            continue  # not this encoding; the other candidates and the latin-1 fallback still run
    return texts + [data.decode("latin-1")]


def check_private_patterns(ctx: Ctx) -> list[Finding]:
    cfg = ctx.canon["private_patterns"]
    patterns = [(p["id"], re.compile(p["regex"])) for p in cfg["patterns"]]
    allowed_emails = [re.compile(p) for p in cfg["allowed_emails"]]
    skip_dirs, skip_names = set(cfg["skip_dirs"]), set(cfg["skip_names"])
    findings = []
    for rel in ctx.files:
        parts = Path(rel).parts
        if parts[0] in skip_dirs or (len(parts) == 1 and parts[0] in skip_names):
            continue
        path = ctx.root / rel
        if Path(rel).suffix.lower() in BINARY_SUFFIXES:
            continue
        try:
            texts = [os.readlink(path)] if path.is_symlink() else decode_variants(path.read_bytes())
        except OSError:
            findings.append(Finding("private-patterns", rel, "could not be read", "check the file permissions"))
            continue
        seen: set[tuple[int, str]] = set()
        for text in texts:
            for number, line in enumerate(text.splitlines(), start=1):
                for pid, rx in patterns:
                    if (number, pid) in seen:
                        continue
                    if pid == "email":
                        hit = any(not any(a.fullmatch(m.group(0)) for a in allowed_emails) for m in rx.finditer(line))
                    else:
                        hit = bool(rx.search(line))
                    if hit:
                        seen.add((number, pid))
                        findings.append(Finding("private-patterns", rel, f"matches built-in pattern {pid}", "remove it or use a placeholder", number))
    return findings


# ---------------------------------------------------------------- vendoring

def sha256_file(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def source_text(commit: str) -> str:
    cfg = json.loads((HERE / "canon.json").read_text(encoding="utf-8"))["vendor"]
    lines = [f"repo: {cfg['source_repo']}", f"commit: {commit}"]
    lines += [f"{name}: sha256:{sha256_file(HERE / name)}" for name in cfg["files"]]
    return "\n".join(lines) + "\n"


def check_vendor(ctx: Ctx) -> list[Finding]:
    cfg = ctx.canon["vendor"]
    source = HERE / cfg["source_file"]
    rel = (HERE / cfg["source_file"]).relative_to(ctx.root).as_posix() if HERE.is_relative_to(ctx.root) else str(source)
    if not source.is_file():
        if ctx.repo.get("source_of_truth"):
            return []
        return [Finding("vendor", rel, "vendored files have no SOURCE record", f"create it with: python3 {cfg['dir']}/stack-check.py --print-source COMMIT")]
    values = {}
    for line in source.read_text(encoding="utf-8").splitlines():
        key, sep, value = line.partition(":")
        if sep:
            values[key.strip()] = value.strip()
    findings = []
    if values.get("repo") != cfg["source_repo"]:
        findings.append(Finding("vendor", rel, f'repo is "{values.get("repo", "")}", expected {cfg["source_repo"]}', "re-vendor from the source repo"))
    if not re.fullmatch(r"[0-9a-f]{40}", values.get("commit", "")):
        findings.append(Finding("vendor", rel, "commit is not a 40-hex SHA", "record the source commit SHA"))
    for name in cfg["files"]:
        recorded = values.get(name, "")
        actual = "sha256:" + sha256_file(HERE / name) if (HERE / name).is_file() else ""
        if not recorded.startswith("sha256:"):
            findings.append(Finding("vendor", rel, f"no sha256 recorded for {name}", "regenerate SOURCE with --print-source"))
        elif recorded != actual:
            findings.append(Finding("vendor", f"{cfg['dir']}/{name}", "differs from the sha256 in SOURCE", "do not edit vendored files; copy them again from the source repo"))
    return findings


# ---------------------------------------------------------------- driver

CHECKS: list[tuple[str, str, Callable[[Ctx], list[Finding]]]] = [
    ("readme-title", "README first heading is the repo name", check_readme_title),
    ("readme-wordmark", "README references the wordmark near the top", check_readme_wordmark),
    ("readme-intro", "README opening paragraph length, bold, and version rules", check_readme_intro),
    ("readme-status", "README has a Status line naming main and develop", check_readme_status),
    ("readme-sections", "README sections exist in the canonical order", check_readme_sections),
    ("readme-stack", "README Part of the stack lines match the canon", check_readme_stack),
    ("readme-project", "README Project and support section", check_readme_project),
    ("assets", "logo and wordmark files exist with the right size", check_assets),
    ("contributing", "CONTRIBUTING opening, headings, and release notes", check_contributing),
    ("workflow-jobs", "required CI job ids exist and are named after their id", check_workflow_jobs),
    ("workflow-pins", "every uses: is pinned to a 40-hex SHA with a version comment", check_workflow_pins),
    ("workflow-timeouts", "every job has timeout-minutes", check_workflow_timeouts),
    ("workflow-checkout", "every checkout sets persist-credentials: false", check_workflow_checkout),
    ("installer-help", "installer --help lists the declared flags and sections", check_installer_help),
    ("error-format", "no upper-case ERROR: and no unprefixed exit messages", check_error_format),
    ("ascii-markdown", "Markdown files are ASCII", check_ascii_markdown),
    ("private-patterns", "no home paths, private IPv4 addresses, or e-mail addresses", check_private_patterns),
    ("vendor", "vendored files match the sha256 in SOURCE", check_vendor),
]


def load_json(name: str) -> dict:
    path = HERE / name
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except OSError as exc:
        raise UsageError(f"{path} cannot be read: {exc.strerror}") from exc
    except json.JSONDecodeError as exc:
        raise UsageError(f"{path} is not valid JSON: {exc}") from exc
    if not isinstance(data, dict):
        raise UsageError(f"{path} must hold a JSON object")
    return data


def validate_repo(repo: dict) -> None:
    if not isinstance(repo.get("repo"), str) or not repo["repo"]:
        raise UsageError('repo.json needs a "repo" name')
    for index, entry in enumerate(repo.get("allow", [])):
        if not entry.get("check") or not str(entry.get("reason", "")).strip():
            raise UsageError(f"repo.json allow entry {index} needs a check id and a reason")


def apply_allow(findings: list[Finding], repo: dict, ran: set[str]) -> list[Finding]:
    entries = repo.get("allow", [])
    used = [False] * len(entries)
    kept = []
    for finding in findings:
        for index, entry in enumerate(entries):
            if (
                entry["check"] == finding.check
                and fnmatch.fnmatch(finding.file, entry.get("path", "*"))
                and entry.get("match", "") in finding.message
            ):
                used[index] = True
                break
        else:
            kept.append(finding)
    for index, entry in enumerate(entries):
        if not used[index] and entry["check"] in ran:
            kept.append(Finding("allowlist", "repo.json", f"allow entry {index} for {entry['check']} matched nothing", "remove the stale entry"))
    return kept


def emit(args: argparse.Namespace, payload: dict, lines: list[str], code: int, ok_line: str = "") -> int:
    if args.json:
        print(json.dumps(payload))
        return code
    for line in lines:
        print(line, file=sys.stderr)
    if ok_line:
        print(ok_line)
    return code


class Parser(argparse.ArgumentParser):
    def error(self, message: str):  # type: ignore[override]
        line = f"error: {PROG}: {message}; run with --help for usage"
        if "--json" in sys.argv[1:]:
            print(json.dumps({"ok": False, "errors": [line]}))
        else:
            print(line, file=sys.stderr)
        raise SystemExit(2)


def build_parser() -> argparse.ArgumentParser:
    parser = Parser(
        prog=PROG,
        description="Check this repository against the shared stack conventions.",
        epilog=HELP_EPILOG,
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    parser.add_argument("--json", action="store_true", help="Print one JSON object to stdout and nothing else.")
    parser.add_argument("--list-checks", action="store_true", help="List the check ids and exit.")
    parser.add_argument("--only", metavar="IDS", help="Run only these comma-separated check ids.")
    parser.add_argument("--root", metavar="DIR", default=".", help="Repository root (default: current directory).")
    parser.add_argument("--print-source", metavar="COMMIT", help="Print the SOURCE record for the files in this directory and exit.")
    return parser


def run(args: argparse.Namespace) -> int:
    ids = [c[0] for c in CHECKS]
    if args.list_checks:
        if args.json:
            print(json.dumps({"ok": True, "errors": [], "checks": [{"id": i, "description": d} for i, d, _ in CHECKS]}))
        else:
            print("\n".join(f"{i}  {d}" for i, d, _ in CHECKS))
        return 0
    if args.print_source:
        if not re.fullmatch(r"[0-9a-f]{40}", args.print_source):
            raise UsageError("--print-source needs a full 40-hex commit SHA")
        sys.stdout.write(source_text(args.print_source))
        return 0
    selected = ids
    if args.only:
        selected = [s.strip() for s in args.only.split(",") if s.strip()]
        unknown = [s for s in selected if s not in ids]
        if unknown:
            raise UsageError(f"unknown check id {', '.join(unknown)}; run --list-checks")
    canon, repo = load_json("canon.json"), load_json("repo.json")
    validate_repo(repo)
    root = Path(args.root).resolve()
    ctx = Ctx(root, canon, repo)
    findings: list[Finding] = []
    for check_id, _, fn in CHECKS:
        if check_id in selected:
            findings += fn(ctx)
    findings = apply_allow(findings, repo, set(selected))
    findings.sort(key=lambda f: (f.check, f.file, f.line or 0))
    lines = [f.render() for f in findings]
    payload = {
        "ok": not findings,
        "errors": lines,
        "findings": [f.as_dict() for f in findings],
        "checks": selected,
        "repo": repo["repo"],
    }
    if findings:
        summary = f"note: {PROG}: {len(findings)} findings in {len({f.check for f in findings})} checks"
        return emit(args, payload, lines + [summary], 1)
    return emit(args, payload, [], 0, f"{PROG}: ok ({len(selected)} checks)")


def main(argv: list[str] | None = None) -> int:
    args = build_parser().parse_args(argv)
    try:
        return run(args)
    except UsageError as exc:
        line = f"error: {PROG}: {exc}; fix the input and rerun"
        print(json.dumps({"ok": False, "errors": [line]}) if args.json else line, file=None if args.json else sys.stderr)
        return 2
    except ToolMissing as exc:
        line = f"error: {PROG}: {exc} is required in a git checkout; install it and rerun"
        print(json.dumps({"ok": False, "errors": [line]}) if args.json else line, file=None if args.json else sys.stderr)
        return 3


if __name__ == "__main__":
    sys.exit(main())
