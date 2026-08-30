#!/usr/bin/env python3
"""
lint-magic-numbers.py — detect hardcoded IPs, ports, and magic numbers
that should be named variables.

Rationale: AGENTS.md states hardcoded IPs and ports are "ABSOLUTELY
FORBIDDEN" in configuration files. This script enforces that rule
statically by scanning YAML/Jinja files for numeric literals and IP
addresses that appear outside designated variable-definition locations.

Rule summary
------------
A "magic literal" is any of:
  - IPv4 address           (e.g. 100.90.22.85, 127.0.0.1, 0.0.0.0)
  - IPv4 CIDR              (e.g. 172.26.0.0/16)
  - IPv4:port              (e.g. 100.90.22.85:5000)
  - Dotted-decimal version (e.g. 0.9.25, 1.2.3)  — treated as one token
  - Bare integer           (e.g. 30, 1000, 755, 100000)
  - Integer + unit suffix  (e.g. 10m, 30s, 5M, 1h, 200ms)

A magic literal is a VIOLATION unless ALL of:
  1. The file is inside an allowlisted definition directory, AND
  2. The line is a direct variable assignment (``key: value``), AND
  3. The literal is NOT inside a ``{{ ... }}`` Jinja2 expression.

In non-allowlisted directories (tasks/, playbooks/, templates/, etc.)
ANY magic literal is a violation — it must be a ``{{ var }}`` reference.

Inline overrides
----------------
Suppress specific rules on a line with a tool-identifiable, rule-specific
comment:

  # lint-magic-numbers: disable=ipv4,ipport

The syntax is ``# lint-magic-numbers: disable=<rules>`` where ``<rules>``
is a comma-separated list of rule names matching the violation ``kind``:
  cidr, ipport, ipv4, dotted, unitnum, int

To suppress ALL rules on a line, use either:
  # lint-magic-numbers: disable=all
  # lint-magic-numbers: disable

Overrides are for exceptional cases only (e.g. protocol version strings
like ``HTTP/1.1``, compose schema versions like ``3.8``).  They should
not be used to paper over real violations.

Usage
-----
  scripts/lint-magic-numbers.py [options] [path ...]

  --mode {default,strict}   default: exempt variable definitions in
                            allowlisted dirs.  strict: flag everywhere.
  --json                    Emit JSON output for programmatic consumption.
  --quiet                   Suppress per-violation output; exit code only.
  --ignore-overrides        Flag violations even on lines with
                            ``# lint-magic-numbers: disable=...`` overrides.
  path ...                  Files or directories to scan.  Defaults to
                            the git repository root.

Exit status: 0 if no violations, 1 if violations found, 2 on usage error.
"""

from __future__ import annotations

import argparse
import json
import os
import re
import sys
from dataclasses import dataclass, field
from pathlib import Path
from typing import Iterable

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------

# File extensions to scan.
SCAN_EXTENSIONS = {".yml", ".yaml", ".j2", ".jinja2"}

# Directories (relative to repo root, path-prefix matched) where variable
# *definitions* are expected.  A ``key: <literal>`` line here is exempt;
# a literal inside ``{{ }}`` here is still a violation.
DEFINITION_DIRS: tuple[str, ...] = (
    "defaults",
    "vars",
    "group_vars",
    "host_vars",
    "infrastructure",
)

# Directories that are fully exempt from scanning (docs, agent skills,
# tests, vendored collections, etc.).  Contents are never flagged.
EXEMPT_DIRS: tuple[str, ...] = (
    "internal-docs",
    ".agents",
    ".claude",
    ".devin",
    ".git",
    ".molecule",
    "collections",          # ansible Galaxy collections (vendored)
    "node_modules",
    ".venv",
    ".cache",
    "08-docs",              # ADRs / research / requirements docs
    "docs",
    "tests",
    "test",
    "__pycache__",
)

# File names that are always exempt (regardless of directory).
EXEMPT_FILENAMES: frozenset[str] = frozenset({
    "lint-magic-numbers.py",   # this file
    "lint.log",
})

# Filename substrings that mark generated/lock files (always exempt).
EXEMPT_NAME_SUBSTRINGS: tuple[str, ...] = (
    "lock",          # pnpm-lock.yaml, package-lock.json, flake.lock, etc.
    ".vault",        # ansible-vault encrypted files (*.vault.yml, *.vault)
)

# Root-level dotfiles (tool configs, not infrastructure): .ansible-lint.yml,
# .gitignore, .gitmodules, .editorconfig, etc.  These are exempt only when
# they sit directly in the repository root.
_EXEMPT_ROOT_DOTFILES: bool = True

# Directories whose names match EXEMPT_DIRS anywhere in the path are
# skipped.  We also skip any path component starting with '.' except
# the ones we explicitly scan (none currently).

# ---------------------------------------------------------------------------
# Numeric-literal detection
# ---------------------------------------------------------------------------

# Ordered alternation: the first alternative that matches at a given
# position wins (Python re alternation is ordered).  This prevents
# ``100.90.22.85:5000`` from being reported as an IP + a bare port.
_NUMERIC_RE = re.compile(
    r"""
    (?P<cidr>      (?<![\w.])(?<![A-Za-z]/)\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}/\d{1,2}\b    )
  | (?P<ipport>    (?<![\w.])(?<![A-Za-z]/)\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}:\d{1,5}\b    )
  | (?P<ipv4>      (?<![\w.])(?<![A-Za-z]/)\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}\b            )
  | (?P<dotted>    (?<![\w.])(?<![A-Za-z]/)\d+\.\d+(?:\.\d+)*(?![\w.])                     )
  | (?P<unitnum>   (?<![\w.])\d+(?:ms|s|m|h|k|M|G|T|B)\b                                  )
  | (?P<int>       (?<![\w.\[])(?<![A-Za-z]\-)\d+(?![\w.\]>])(?!\-[A-Za-z])                )
    """,
    re.VERBOSE,
)

# Regex quantifier patterns inside shell commands (e.g. ``{1,3}`` in
# ``grep -rE '...{1,3}...'``).  These are regex syntax, not magic numbers,
# and are stripped from the line before scanning.
_REGEX_QUANTIFIER_RE = re.compile(r"\{\d+(?:,\d*)?\}")

# Patterns that are not magic numbers and are stripped before scanning:
#   - MAC addresses: 52:54:00:00:00:01
#   - YAML block scalar indentation indicators: |2, |-2
#   - Sed/regex backreferences: \1, \2
#   - Crypto hash parameter strings: $argon2id$v=19$m=65536,t=3,p=4$...
#   - Shell exit codes: exit 0, exit 1
#   - Comparisons against 0/1: == 0, != 0, > 0, < 0, >= 1, <= 1
_MAC_RE = re.compile(r"\b[0-9a-fA-F]{2}(?::[0-9a-fA-F]{2}){5}\b")
_YAML_BLOCK_SCALAR_RE = re.compile(r"(?<=: )\|[-+]?\d")
_SED_BACKREF_RE = re.compile(r"\\\d+")
_CRYPTO_HASH_RE = re.compile(r"\$(?:argon2[idid]|2[aby])\$[^'\"\s]*")
_EXIT_CODE_RE = re.compile(r"\bexit\s+\d+")
_CMP_ZERO_ONE_RE = re.compile(r"(?:==|!=|>=|<=|>|<|-eq|-ne|-gt|-lt|-ge|-le)\s*[01]\b")
_SHELL_REDIRECT_RE = re.compile(r"\d+>&\d+|\d+>\d+")
_SHELL_FOR_RE = re.compile(r"\bfor\s+\w+\s+in\s+[\d\s]+;")
_SHELL_SEQ_RE = re.compile(r"\bseq\s+\d+(?:\s+\d+)*")

# Jinja2 expression span finder: ``{{ ... }}``.
_JINJA_RE = re.compile(r"{{.*?}}", re.DOTALL)

# A YAML "direct variable assignment" line: ``key: value`` (mapping).
# List items (``- value``) and bare values are NOT definitions.
_DEFINITION_LINE_RE = re.compile(r"^\s*[A-Za-z_][\w.-]*\s*:\s+\S")

# Inline override: ``# lint-magic-numbers: disable=rule1,rule2``
# Suppresses specific rules (or all rules with ``disable=all`` or bare
# ``disable``) on that line.  Rule names match the ``kind`` field:
#   cidr, ipport, ipv4, dotted, unitnum, int
# Multiple rules are comma-separated.  Examples:
#   # lint-magic-numbers: disable=ipv4,ipport
#   # lint-magic-numbers: disable=all
#   # lint-magic-numbers: disable
_OVERRIDE_RE = re.compile(
    r"#\s*lint-magic-numbers\s*:\s*disable\s*(?:=\s*([A-Za-z,]+))?",
    re.IGNORECASE,
)
_OVERRIDE_ALL = {"all", ""}  # bare "disable" or "disable=all" → suppress all


@dataclass(frozen=True)
class Violation:
    """A single magic-literal violation."""

    file: str
    line: int          # 1-based
    column: int        # 1-based
    token: str         # the matched literal text
    kind: str          # cidr | ipport | ipv4 | dotted | unitnum | int
    context: str       # the full line (trimmed) for human review

    def as_dict(self) -> dict:
        return {
            "file": self.file,
            "line": self.line,
            "column": self.column,
            "token": self.token,
            "kind": self.kind,
            "context": self.context,
        }

    def format(self) -> str:
        return (
            f"{self.file}:{self.line}:{self.column}: "
            f"magic {self.kind} '{self.token}' should be a named variable"
        )


@dataclass
class ScanResult:
    """Aggregate scan output."""

    violations: list[Violation] = field(default_factory=list)
    files_scanned: int = 0
    files_with_violations: int = 0


# ---------------------------------------------------------------------------
# Path classification
# ---------------------------------------------------------------------------

def _is_exempt(rel_path: str) -> bool:
    """True if the path is fully exempt from scanning."""
    p = Path(rel_path)
    parts = p.parts

    # Exempt directory components anywhere in the path.
    for part in parts:
        if part in EXEMPT_DIRS:
            return True

    # Exact filename exemptions.
    if p.name in EXEMPT_FILENAMES:
        return True

    # Generated / lock / vault files by name substring.
    name_lower = p.name.lower()
    for sub in EXEMPT_NAME_SUBSTRINGS:
        if sub in name_lower:
            return True

    # Root-level dotfiles (tool configs like .ansible-lint.yml).
    # ``parts`` for a root-level file is ``("filename",)`` — no directory
    # components.  For nested files it's ``("dir", ..., "filename")``.
    if _EXEMPT_ROOT_DOTFILES and len(parts) == 1 and p.name.startswith("."):
        return True

    return False


def _is_definition_dir(rel_path: str) -> bool:
    """True if the path is inside a variable-definition directory."""
    parts = Path(rel_path).parts
    for part in parts:
        if part in DEFINITION_DIRS:
            return True
    return False


# ---------------------------------------------------------------------------
# Line-level scanning
# ---------------------------------------------------------------------------

def _strip_comment(line: str) -> str:
    """Remove a trailing YAML comment, respecting quotes.

    A ``#`` inside single or double quotes is not a comment.  We do a
    simple state-machine scan rather than a full YAML parse — sufficient
    for line-level comment stripping.
    """
    in_single = False
    in_double = False
    for i, ch in enumerate(line):
        if ch == "'" and not in_double:
            in_single = not in_single
        elif ch == '"' and not in_single:
            in_double = not in_double
        elif ch == "#" and not in_single and not in_double:
            # Comment starts here — but only if preceded by whitespace or
            # start of line (a '#' glued to a word is not a YAML comment).
            if i == 0 or line[i - 1] in (" ", "\t"):
                return line[:i]
    return line


def _jinja_spans(line: str) -> list[tuple[int, int]]:
    """Return (start, end) spans of all ``{{ ... }}`` on the line."""
    return [(m.start(), m.end()) for m in _JINJA_RE.finditer(line)]


def _is_inside_jinja(pos: int, spans: list[tuple[int, int]]) -> bool:
    """True if ``pos`` falls within any Jinja2 expression span."""
    for start, end in spans:
        if start <= pos < end:
            return True
    return False


def _is_definition_line(line: str) -> bool:
    """True if the line is a ``key: value`` mapping assignment."""
    return bool(_DEFINITION_LINE_RE.match(line))


def _parse_override(line: str) -> set[str] | None:
    """Parse an inline override from a line.

    Returns:
      - ``None`` if no override present on the line.
      - A set of rule names to suppress (may contain ``"all"``).
    """
    m = _OVERRIDE_RE.search(line)
    if not m:
        return None
    rules_str = m.group(1)
    if rules_str is None:
        # Bare ``disable`` or ``disable=all`` (the ``=all`` case is captured
        # by group 1 as the string "all"; bare ``disable`` has group 1 = None).
        return {"all"}
    rules = {r.strip().lower() for r in rules_str.split(",") if r.strip()}
    return rules


def _is_suppressed(kind: str, override: set[str] | None) -> bool:
    """True if ``kind`` is suppressed by the override set."""
    if override is None:
        return False
    if "all" in override:
        return True
    return kind in override


def _scan_line(
    line: str,
    line_no: int,
    rel_path: str,
    is_definition_dir: bool,
    strict: bool,
    ignore_overrides: bool = False,
) -> list[Violation]:
    """Find all magic-literal violations on a single line."""
    # Parse inline override (unless --ignore-overrides is set).
    override = None if ignore_overrides else _parse_override(line)

    code = _strip_comment(line)
    # Strip patterns that contain numbers but are not magic numbers.
    code = _REGEX_QUANTIFIER_RE.sub("", code)   # {1,3} regex quantifiers
    code = _MAC_RE.sub("", code)                # MAC addresses
    code = _YAML_BLOCK_SCALAR_RE.sub("", code)  # |2 YAML block scalar indent
    code = _SED_BACKREF_RE.sub("", code)        # \1 sed backreferences
    code = _CRYPTO_HASH_RE.sub("", code)        # $argon2id$v=19$... hashes
    code = _EXIT_CODE_RE.sub("exit", code)      # exit 0, exit 1
    code = _CMP_ZERO_ONE_RE.sub("CMP", code)    # == 0, != 0, > 0, -eq 0
    code = _SHELL_REDIRECT_RE.sub("", code)     # 2>&1, 2>1 shell redirects
    code = _SHELL_FOR_RE.sub("", code)          # for _ in 1 2 3 4; do
    code = _SHELL_SEQ_RE.sub("", code)          # seq 1 10
    spans = _jinja_spans(code)
    violations: list[Violation] = []

    for m in _NUMERIC_RE.finditer(code):
        kind = m.lastgroup
        token = m.group()
        col = m.start() + 1  # 1-based column

        inside_jinja = _is_inside_jinja(m.start(), spans)

        if strict:
            # Strict mode: flag every literal everywhere.
            is_exempt = False
        elif is_definition_dir and _is_definition_line(code) and not inside_jinja:
            # Allowlisted dir + direct ``key: value`` assignment + literal
            # is the value (not inlined in {{ }}) → this is a definition.
            is_exempt = True
        else:
            # Non-allowlisted dir, or inlined in {{ }}, or not a definition
            # line → the literal must be a variable reference.
            is_exempt = False

        if is_exempt:
            continue

        # Check inline override (rule-specific suppression).
        if _is_suppressed(kind, override):
            continue

        violations.append(
            Violation(
                file=rel_path,
                line=line_no,
                column=col,
                token=token,
                kind=kind,
                context=code.strip(),
            )
        )

    return violations


def _scan_file(
    path: Path,
    repo_root: Path,
    strict: bool,
    ignore_overrides: bool = False,
) -> list[Violation]:
    """Scan a single file for magic-literal violations."""
    try:
        rel_path = str(path.relative_to(repo_root))
    except ValueError:
        # File is outside the repo root (e.g. a temp test file).
        rel_path = str(path)
    if _is_exempt(rel_path):
        return []

    is_def_dir = _is_definition_dir(rel_path)
    violations: list[Violation] = []

    try:
        text = path.read_text(encoding="utf-8", errors="replace")
    except OSError:
        return []

    for line_no, line in enumerate(text.splitlines(), start=1):
        violations.extend(
            _scan_line(
                line, line_no, rel_path, is_def_dir, strict, ignore_overrides
            )
        )

    return violations


# ---------------------------------------------------------------------------
# File discovery
# ---------------------------------------------------------------------------

def _iter_scan_files(root: Path) -> Iterable[Path]:
    """Yield all scannable files under ``root``."""
    for dirpath, dirnames, filenames in os.walk(root):
        # Prune exempt directories in-place (os.walk allows mutation).
        dirnames[:] = [
            d for d in dirnames
            if d not in EXEMPT_DIRS and not d.startswith(".git")
        ]
        for fname in filenames:
            if Path(fname).suffix in SCAN_EXTENSIONS:
                if fname not in EXEMPT_FILENAMES:
                    yield Path(dirpath) / fname


def _resolve_paths(paths: list[str], repo_root: Path) -> list[Path]:
    """Resolve CLI path arguments into a list of files to scan."""
    if not paths:
        return list(_iter_scan_files(repo_root))

    files: list[Path] = []
    for p in paths:
        pp = Path(p)
        if not pp.is_absolute():
            pp = repo_root / pp
        if pp.is_file():
            files.append(pp)
        elif pp.is_dir():
            files.extend(_iter_scan_files(pp))
        else:
            print(f"warning: {p}: no such file or directory", file=sys.stderr)
    return files


def _find_repo_root(start: Path) -> Path:
    """Find the git repository root by walking up for a .git entry."""
    cur = start.resolve()
    while cur != cur.parent:
        if (cur / ".git").exists():
            return cur
        cur = cur.parent
    return start.resolve()


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        description="Detect hardcoded IPs, ports, and magic numbers "
                    "that should be named variables.",
    )
    parser.add_argument(
        "paths", nargs="*",
        help="Files or directories to scan (default: repo root).",
    )
    parser.add_argument(
        "--mode", choices=["default", "strict"], default="default",
        help="default: exempt variable definitions in allowlisted dirs; "
             "strict: flag every literal everywhere.",
    )
    parser.add_argument("--json", action="store_true", dest="as_json",
                        help="Emit JSON output.")
    parser.add_argument("--quiet", action="store_true",
                        help="Suppress per-violation output.")
    parser.add_argument(
        "--ignore-overrides", action="store_true",
        help="Ignore inline '# lint-magic-numbers: disable=...' overrides. "
             "Flag violations even on lines with exceptions.",
    )
    args = parser.parse_args(argv)

    repo_root = _find_repo_root(Path.cwd())
    files = _resolve_paths(args.paths, repo_root)
    strict = args.mode == "strict"

    result = ScanResult()
    files_with: set[str] = set()

    for f in files:
        result.files_scanned += 1
        vlist = _scan_file(f, repo_root, strict, args.ignore_overrides)
        if vlist:
            result.violations.extend(vlist)
            files_with.add(vlist[0].file)

    result.files_with_violations = len(files_with)

    if args.as_json:
        print(json.dumps({
            "files_scanned": result.files_scanned,
            "files_with_violations": result.files_with_violations,
            "violation_count": len(result.violations),
            "violations": [v.as_dict() for v in result.violations],
        }, indent=2))
    elif not args.quiet:
        for v in result.violations:
            print(v.format())
        if result.violations:
            print(
                f"\n{len(result.violations)} violation(s) in "
                f"{result.files_with_violations} file(s) "
                f"(scanned {result.files_scanned} file(s))",
                file=sys.stderr,
            )
        else:
            print(
                f"OK: no magic-number violations "
                f"(scanned {result.files_scanned} file(s))",
                file=sys.stderr,
            )

    return 1 if result.violations else 0


if __name__ == "__main__":
    sys.exit(main())
