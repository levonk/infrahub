#!/usr/bin/env bash
#
# Claude Code PostToolUse hook: run magic-number lint on edited YAML/Jinja files.
#
# Reads the PostToolUse event JSON from stdin, extracts the edited file path,
# and runs project-lint's magic_numbers scanner on it if it's a
# .yml/.yaml/.j2/.jinja2 file.  Violations are printed to stderr as feedback
# to Claude; the hook does NOT block (exit 0) so Claude can continue working
# and fix the violations.
#
# This complements the git pre-commit hook (which blocks commits with
# violations) by giving Claude immediate feedback after each edit.

set -euo pipefail

# Read the event JSON from stdin.
event_json="$(cat)"

# Extract the file path from the tool input.
file_path="$(echo "$event_json" | jq -r '.tool_input.file_path // empty' 2>/dev/null || true)"

if [[ -z "$file_path" ]]; then
    exit 0
fi

# Check if the file has a scannable extension.
case "$file_path" in
    *.yml|*.yaml|*.j2|*.jinja2) ;;
    *) exit 0 ;;
esac

# Check if the file exists.
if [[ ! -f "$file_path" ]]; then
    exit 0
fi

# Find the project-lint binary.
repo_root="${CLAUDE_PROJECT_DIR:-$(git rev-parse --show-toplevel 2>/dev/null || echo .)}"
project_lint_bin="${PROJECT_LINT_BIN:-$HOME/p/gh/levonk/project-lint/target/release/project-lint}"

if [[ ! -x "$project_lint_bin" ]]; then
    exit 0
fi

# Run project-lint on the project root and filter for the edited file.
# Exit 0 always — this hook is advisory, not blocking.
output="$("$project_lint_bin" lint --path "$repo_root" 2>&1)" || true

# Extract violations for the edited file (relative path).
rel_path="${file_path#$repo_root/}"
file_violations="$(echo "$output" | grep "MagicNum" | grep "$rel_path" || true)"

if [[ -n "$file_violations" ]]; then
    echo "magic-number lint found violations in $rel_path:" >&2
    echo "$file_violations" >&2
    echo "" >&2
    echo "Fix by replacing hardcoded values with {{ variable }} references." >&2
    echo "For exceptions, add: # lint-magic-numbers: disable=<rule>  <reason>" >&2
fi

exit 0
