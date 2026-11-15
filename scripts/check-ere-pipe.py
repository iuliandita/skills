#!/usr/bin/env python3
"""Find '\\|' inside ERE patterns in fenced command examples.

grep -E, egrep, rg, pgrep, and pkill use extended regular expressions, where
'|' is alternation and '\\|' inside a quoted pattern matches a literal pipe. A
stray '\\|' in one of those patterns silently matches nothing.

Scans fenced blocks (indented fences included), splits commands on unquoted
'|', ';', and '&&', and ignores BRE grep and fixed-string modes. sed -E and awk
are outside this check.

Usage: check-ere-pipe.py <file>...
Prints one "<file>:<line>" per finding. Exits 0 when every file was scanned,
with or without findings, so scripts/lint-skills.sh can tell a scan that found
nothing from one that did not run.
"""

from __future__ import annotations

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
            if name in {"--extended-regexp", "--perl-regexp"}:
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
                if flag in {"E", "P"} and command == "grep":
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


def scan_file(path):
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
                    yield start_line
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
                        yield start_line
                    buffer = ""
                continue
            if line.rstrip().endswith("\\"):
                buffer = line.rstrip()[:-1] + " "
                start_line = number
                continue
            if scan_line(line):
                yield number
        if buffer and scan_line(buffer):
            yield start_line


def main(paths):
    for path in paths:
        for number in scan_file(path):
            print(f"{path}:{number}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
