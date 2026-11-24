#!/usr/bin/env bash
# execution-gate.sh — Pre-flight gate for execute-upsert subagent dispatch
#
# Creates a per-story git worktree + checkpoint commit BEFORE dispatching a subagent.
# Writes a gate-pass file that the PreToolUse hook on run_subagent checks.
# If this script does not exit 0, the dispatch MUST NOT proceed.
#
# This is the machine-enforced gate. The PreToolUse hook (check-subagent-gate.sh)
# blocks every run_subagent call until this script has run and written a gate-pass
# file. The agent cannot rationalize past it — it is a turnstile, not a sign.
#
# Gate-pass files are PER-STORY: /tmp/devin-execution-gates/gate-pass-<slug>.
# Running the gate for a second story acquires a SECOND worktree — it never
# resumes the first story's lease. This is what makes parallel dispatch safe:
# one gate run per story, one worktree per story. Re-running the gate for the
# SAME slug resumes that story's existing worktree (RESUME path); pass --new
# to discard the recorded lease and force a fresh acquisition.
#
# --allow-dirty bypasses the uncommitted-changes-on-main precondition: the
# gate proceeds while leaving the dirty files untouched on the default
# branch. Use it when the dirty files are unrelated to the story — e.g.
# acquiring a worktree for new work while prior WIP stays on main. The
# bypass is explicit (a flag, not a heuristic) so the intent is recorded
# and the check remains the default.
#
# The legacy /tmp/devin-execution-gates/current-gate-pass file is still
# written (pointing at the most recent worktree) as a compat pointer for
# older hook versions that check only that file.
#
# Worktree acquisition uses treehouse (https://github.com/kunchenguid/treehouse)
# — a pool manager that reuses worktrees with dependencies and build cache
# intact; the gate BLOCKS when treehouse is not installed. After acquiring a
# worktree, a named story branch is created inside it with `git checkout -b`
# and `worktree_prime` runs (submodule init, devbox env health check + repair,
# nix tarball-cache validation) — best-effort, warns but never blocks.
#
# Usage:
#   bash .devin/scripts/execution-gate.sh <story-id-slug> [base-sha] [--story-type <trivial|standard|research>] [--new] [--allow-dirty]
#
# Outputs (stdout): the worktree path (for the orchestrator to pass to the subagent)
# Outputs (stderr): progress/diagnostic messages
# Exit codes:
#   0 = gate passed, worktree ready (fresh acquisition or RESUME of an
#       existing lease for the same slug)
#   1 = usage error
#   2 = pre-condition failure (uncommitted changes on main, missing base SHA, etc.)
set -euo pipefail

PROJECT_DIR="${DEVIN_PROJECT_DIR:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
PROJECT_NAME="$(basename "$PROJECT_DIR")"
GATE_DIR="/tmp/devin-execution-gates"
# GATE_PASS is set after arg parsing — it is per-story:
#   $GATE_DIR/gate-pass-<story-slug>
# CURRENT_GATE_PASS is a compat pointer to the most recent live worktree,
# kept for older hook versions that check only that file.
CURRENT_GATE_PASS="$GATE_DIR/current-gate-pass"

# Canonicalize a path (resolve symlinks — e.g. /tmp → /private/tmp on macOS).
# `git worktree list` reports canonical paths, so comparisons must normalize
# both sides. Falls back to the input when the path does not exist.
canon_path() { (cd "$1" 2>/dev/null && pwd -P) || printf '%s' "$1"; }

# /tmp always exists, so canon_path resolves the base to its real location.
WORKTREE_BASE="$(canon_path /tmp)/${PROJECT_NAME}-worktrees"

# Include shared helpers — inlined at build time so the rendered script is
# self-contained (install-hooks.sh copies only this file into .devin/scripts/).
# treehouse helpers: treehouse_available, treehouse_acquire, treehouse_return,
#   treehouse_is_managed
# arg-parse helpers: reject_unknown_flag, parse_value_flag, parse_bool_flag
# worktree-prime helpers: worktree_prime, nix_tarball_cache_check
# treehouse-helpers.sh — shared helpers for treehouse worktree pool management
#
# Treehouse (https://github.com/kunchenguid/treehouse) manages a pool of
# reusable, isolated git worktrees so each agent gets its own environment
# instantly — no cloning, no conflicts, no coordination overhead.
#
# This include provides thin wrappers around the treehouse CLI for use by
# execution-gate.sh and other scripts that need to acquire or release
# worktrees. When treehouse is not available, callers fall back to manual
# `git worktree add` commands.
#
# Functions provided:
#   treehouse_available       — check if treehouse is on PATH (echoes 1/0)
#   treehouse_acquire         — lease a worktree, echo its path (sets TREEHOUSE_LEASE_ID)
#   treehouse_acquire_json    — lease a worktree, echo JSON {path, lease_id, lease_holder, leased_at}
#   treehouse_return          — release a lease and return worktree to pool
#   treehouse_status          — print pool status (JSON or text)
#   treehouse_is_managed      — check if a path is inside a treehouse-managed worktree
#
# Environment variables:
#   TREEHOUSE_LEASE_HOLDER   — label recorded as the lease holder (default: $USER or "agent")
#   TREEHOUSE_NO_FETCH       — if set to 1, pass --no-fetch to treehouse get
#
# Materialization: each consuming skill has a
# `scripts/treehouse-helpers.sh.tmpl` file containing a single include
# directive that pulls in this file. The templater inlines this file at build
# time. Scripts then `source` the materialized copy from the same `scripts/`
# directory.
#
# Consumers:
#   - execution/execute-upsert/scripts/execution-gate.sh.tmpl
#   - execution/execute-upsert/scripts/land-on-env-dev.sh.tmpl
#   - execution/execute-upsert/scripts/ship-pr.sh.tmpl

# Guard against double-sourcing
_TREEHOUSE_HELPERS_SOURCED="${_TREEHOUSE_HELPERS_SOURCED:-}"

# treehouse_available — check if treehouse CLI is available.
# Echoes 1 if available, 0 if not. Does not use `return` so it works both
# when sourced and when inlined.
treehouse_available() {
	if command -v treehouse >/dev/null 2>&1; then
		echo 1
	else
		echo 0
	fi
}

# treehouse_acquire — lease a worktree from the pool.
# Echoes the absolute path of the leased worktree to stdout.
# Sets TREEHOUSE_LEASE_ID and TREEHOUSE_LEASE_PATH in the environment.
# Returns 0 on success, 1 on failure.
#
# Optional args:
#   $1 — lease holder label (defaults to $TREEHOUSE_LEASE_HOLDER or $USER or "agent")
treehouse_acquire() {
	local holder="${1:-${TREEHOUSE_LEASE_HOLDER:-${USER:-agent}}}"
	local extra_args=()
	if [[ "${TREEHOUSE_NO_FETCH:-0}" == "1" ]]; then
		extra_args+=(--no-fetch)
	fi

	# treehouse get --lease prints the path to stdout, banners to stderr.
	# --json gives us path + lease_id for programmatic use.
	local json_out
	json_out="$(treehouse get --lease --lease-holder "$holder" --json "${extra_args[@]}" 2>/dev/null)" || {
		echo "TREEHOUSE: failed to acquire worktree" >&2
		return 1
	}

	# Parse JSON output (path, lease_id, lease_holder, leased_at)
	# Use jq if available, otherwise fall back to grep/sed
	if command -v jq >/dev/null 2>&1; then
		TREEHOUSE_LEASE_PATH="$(printf '%s' "$json_out" | jq -r '.path // empty')"
		TREEHOUSE_LEASE_ID="$(printf '%s' "$json_out" | jq -r '.lease_id // empty')"
		TREEHOUSE_LEASE_HOLDER="$(printf '%s' "$json_out" | jq -r '.lease_holder // empty')"
	else
		TREEHOUSE_LEASE_PATH="$(printf '%s' "$json_out" | grep -o '"path":"[^"]*"' | head -1 | sed 's/"path":"//;s/"//')"
		TREEHOUSE_LEASE_ID="$(printf '%s' "$json_out" | grep -o '"lease_id":"[^"]*"' | head -1 | sed 's/"lease_id":"//;s/"//')"
		TREEHOUSE_LEASE_HOLDER="$(printf '%s' "$json_out" | grep -o '"lease_holder":"[^"]*"' | head -1 | sed 's/"lease_holder":"//;s/"//')"
	fi

	if [[ -z "$TREEHOUSE_LEASE_PATH" ]]; then
		echo "TREEHOUSE: no path in lease output" >&2
		return 1
	fi

	export TREEHOUSE_LEASE_PATH
	export TREEHOUSE_LEASE_ID
	export TREEHOUSE_LEASE_HOLDER
	echo "$TREEHOUSE_LEASE_PATH"
}

# treehouse_return — release a lease and return a worktree to the pool.
# Terminates lingering processes, verifies no foreign process remains,
# resets the worktree, and clears the lease.
#
# Args:
#   $1 — worktree path (required)
#   $2 — lease ID (optional, for ABA-safe return via --if-lease-id)
#   $3 — lease holder (optional, for --if-lease-holder)
# Returns 0 on success, 1 on failure.
treehouse_return() {
	local path="$1"
	local lease_id="${2:-}"
	local holder="${3:-}"

	if [[ -z "$path" ]]; then
		echo "TREEHOUSE: return requires a worktree path" >&2
		return 1
	fi

	local args=(--force)
	if [[ -n "$lease_id" ]]; then
		args+=(--if-lease-id "$lease_id")
	fi
	if [[ -n "$holder" ]]; then
		args+=(--if-lease-holder "$holder")
	fi

	treehouse return "${args[@]}" "$path" 2>&1 || {
		echo "TREEHOUSE: failed to return worktree at $path" >&2
		return 1
	}
}

# treehouse_status — print pool status.
# Args:
#   --json — print JSON status (default is human-readable text)
treehouse_status() {
	if [[ "${1:-}" == "--json" ]]; then
		treehouse status --json 2>/dev/null
	else
		treehouse status 2>&1
	fi
}

# treehouse_is_managed — check if a path is a treehouse-managed worktree.
#
# This is the authoritative check: it asks treehouse itself via
# `treehouse status --json`, which lists all worktrees in the pool with their
# paths. This works regardless of where the treehouse root is configured
# (default ~/.treehouse, repo-level treehouse.toml, user-level
# ~/.config/treehouse/config.toml, --root flag, or environment variables).
#
# Echoes 1 if the path matches a treehouse-managed worktree, 0 if not.
treehouse_is_managed() {
	local path="${1:-$PWD}"
	local abs_path
	abs_path="$(cd "$path" 2>/dev/null && pwd)" || { echo 0; return 0; }

	# If treehouse is not available, the path cannot be treehouse-managed.
	if ! command -v treehouse >/dev/null 2>&1; then
		echo 0
		return 0
	fi

	# Ask treehouse for all managed worktree paths.
	# `treehouse status --json` returns a JSON array with objects containing
	# "path" fields. We extract the paths and check if ours is among them.
	# This is authoritative — no hard-coded root paths, no config file parsing.
	local status_json
	status_json="$(treehouse status --json 2>/dev/null)" || { echo 0; return 0; }

	if [[ -z "$status_json" ]] || [[ "$status_json" == "null" ]]; then
		echo 0
		return 0
	fi

	# Extract paths from JSON. Use jq when available, otherwise grep/sed.
	local managed_paths
	if command -v jq >/dev/null 2>&1; then
		managed_paths="$(printf '%s' "$status_json" | jq -r '.[].path // empty' 2>/dev/null)"
	else
		# Fallback: extract "path":"..." values from the JSON array
		managed_paths="$(printf '%s' "$status_json" | grep -o '"path":"[^"]*"' | sed 's/"path":"//;s/"//')"
	fi

	if [[ -z "$managed_paths" ]]; then
		echo 0
		return 0
	fi

	# Check if abs_path matches or is inside any managed worktree path.
	# We check both exact match and prefix (in case the caller is in a
	# subdirectory of the worktree).
	local mp
	while IFS= read -r mp; do
		[[ -z "$mp" ]] && continue
		if [[ "$abs_path" == "$mp" ]] || [[ "$abs_path" == "$mp"/* ]]; then
			echo 1
			return 0
		fi
	done <<< "$managed_paths"

	echo 0
}

# arg-parse-helpers.sh — shared helpers for shell argument parsers
#
# Provides:
#   reject_unknown_flag "$1"
#     Exit 1 with "Unknown option: $1" on stderr if $1 starts with `-`.
#     Call this as the first line of a `*)` default branch in a while/case
#     arg parser. Prevents unknown flags (--foo) from being silently
#     captured as positional arguments.
#
#   parse_value_flag "$1" "$2" out_var
#     Normalize a value-taking flag into out_var. Handles all three forms:
#       --flag value       (consumes 2 args)
#       --flag=value       (consumes 1 arg)
#       -f value           (consumes 2 args)
#       -f=value           (consumes 1 arg)
#     Sets out_var to the value and the global SHIFT_COUNT to 1 or 2.
#     Returns 0 on success, 1 if the flag does not match any recognized
#     form (caller should fall through to the next case).
#
#   parse_bool_flag "$1" var_name
#     Normalize a boolean flag into var_name. Handles:
#       --flag             (sets var_name=true, consumes 1 arg)
#       --flag=true        (sets var_name=true, consumes 1 arg)
#       --flag=false       (sets var_name=false, consumes 1 arg)
#       --flag=bogus       (exits 1 with error on stderr)
#     Returns 0 if the flag matched (var_name set), 1 if not (caller
#     falls through). SHIFT_COUNT is set to 1.
#
#   parse_format_flag "$1" "$2" out_var
#     Specialization of parse_value_flag for --format/-f/--json. Sets
#     out_var to the format value and SHIFT_COUNT to the shift count.
#     Recognizes:
#       --format value | --format=value | -f value | -f=value | --json
#     Returns 0 on match, 1 otherwise.
#
# Globals set by the parse_* helpers:
#   SHIFT_COUNT — number of args to shift after a successful parse
#
# Usage pattern in a script's main() arg parser:
#
#   source "$SCRIPT_DIR/arg-parse-helpers.sh"
#
#   while [[ $# -gt 0 ]]; do
#       case "$1" in
#       -v|--verbose)
#           parse_bool_flag "$1" VERBOSE; shift "$SHIFT_COUNT" ;;
#       -f|--format|--format=*|-f=*|--json)
#           if parse_format_flag "$1" "$2" format; then
#               shift "$SHIFT_COUNT"
#           else
#               reject_unknown_flag "$1"; shift
#           fi
#           ;;
#       -p|--path)
#           parse_value_flag "$1" "$2" repo_path; shift "$SHIFT_COUNT" ;;
#       --output|--output=*)
#           parse_value_flag "$1" "$2" output_path; shift "$SHIFT_COUNT" ;;
#       -h|--help)
#           usage; exit 0 ;;
#       *)
#           reject_unknown_flag "$1"
#           # ... positional assignment ...
#           shift
#           ;;
#       esac
#   done
#
# Materialization: each consuming skill has a
# `scripts/arg-parse-helpers.sh.tmpl` file containing a single include
# directive that pulls in this file. The templater inlines this file at
# build time. Scripts then `source` the materialized copy from the same
# `scripts/` directory.
#
# Consumers:
#   - project-detection/scripts/detect-all-systems.sh
#   - project-detection/scripts/detect-build-systems.sh
#   - project-detection/scripts/detect-ci-cd-systems.sh
#   - monorepo-extractor/scripts/detect-build-systems.sh
#   - monorepo-extractor/scripts/detect-ci-cd-systems.sh
#   - git-repository-management/scripts/git-tag.sh
#   - nixify/scripts/detect-garnix-scope.sh
#   - nixify/scripts/test-with-act.sh
#   - code-quality-validation/scripts/quality-validator.sh

# Guard against double-sourcing
if [[ -n "${_ARG_PARSE_HELPERS_SOURCED:-}" ]]; then
	return 0 2>/dev/null || exit 0
fi
_ARG_PARSE_HELPERS_SOURCED=1

# Global shift count set by parse_* helpers
SHIFT_COUNT=0

reject_unknown_flag() {
	if [[ "$1" == -* ]]; then
		echo "Unknown option: $1" >&2
		exit 1
	fi
}

# parse_value_flag "$1" "$2" out_var
# Returns 0 on match (out_var set, SHIFT_COUNT set), 1 on no match.
parse_value_flag() {
	local flag="$1"
	local next="$2"
	local out_var="$3"

	case "$flag" in
	--*=*)
		# --flag=value form
		printf -v "$out_var" '%s' "${flag#*=}"
		SHIFT_COUNT=1
		return 0
		;;
	-*=*)
		# -f=value form
		printf -v "$out_var" '%s' "${flag#*=}"
		SHIFT_COUNT=1
		return 0
		;;
	--*)
		# --flag value form (long flag, value is next arg)
		if [[ -z "$next" ]]; then
			echo "Option requires a value: $flag" >&2
			exit 1
		fi
		printf -v "$out_var" '%s' "$next"
		SHIFT_COUNT=2
		return 0
		;;
	-*)
		# -f value form (short flag, value is next arg)
		if [[ -z "$next" ]]; then
			echo "Option requires a value: $flag" >&2
			exit 1
		fi
		printf -v "$out_var" '%s' "$next"
		SHIFT_COUNT=2
		return 0
		;;
	*)
		# Not a value flag — caller should fall through
		return 1
		;;
	esac
}

# parse_bool_flag "$1" var_name
# Returns 0 on match (var_name set, SHIFT_COUNT=1), 1 on no match.
parse_bool_flag() {
	local flag="$1"
	local var_name="$2"

	case "$flag" in
	--*=*)
		# --flag=value form — validate the value
		local value="${flag#*=}"
		if [[ "$value" != "true" && "$value" != "false" ]]; then
			echo "Invalid boolean value for $flag: $value (expected true|false)" >&2
			exit 1
		fi
		printf -v "$var_name" '%s' "$value"
		SHIFT_COUNT=1
		return 0
		;;
	--*)
		# --flag form — implicit true
		printf -v "$var_name" '%s' "true"
		SHIFT_COUNT=1
		return 0
		;;
	*)
		# Not a boolean flag — caller should fall through
		return 1
		;;
	esac
}

# parse_format_flag "$1" "$2" out_var
# Specialization of parse_value_flag that also handles --json shorthand.
# Returns 0 on match (out_var set, SHIFT_COUNT set), 1 on no match.
parse_format_flag() {
	local flag="$1"
	local next="$2"
	local out_var="$3"

	# --json shorthand — always maps to "json"
	if [[ "$flag" == "--json" ]]; then
		printf -v "$out_var" '%s' "json"
		SHIFT_COUNT=1
		return 0
	fi

	# Delegate to parse_value_flag for --format/-f forms
	case "$flag" in
	--format | --format=* | -f | -f=*)
		parse_value_flag "$flag" "$next" "$out_var"
		return $?
		;;
	*)
		return 1
		;;
	esac
}

# worktree-prime.sh — shared helpers for preparing a leased/reused worktree
#
# A treehouse worktree is a warm, reusable checkout: gitignored state like
# `.devbox/`, `vendor/` submodule contents, and package caches persist across
# leases. That warmth is the point of the pool — but it means a slot can carry
# stale environment state (month-old devbox virtenvs, uninitialized submodules,
# a corrupted global nix cache). Priming at lease time surfaces those problems
# early instead of mid-commit inside a pre-commit hook.
#
# Functions provided:
#   nix_tarball_cache_check — validate the shared nix flake tarball cache;
#                             move it aside when corrupt (it is pure cache —
#                             nix rebuilds it on next resolve)
#   worktree_prime <path>   — prime a worktree: submodule init, devbox env
#                             health check + repair, nix cache validation,
#                             optional stamp file
#
# Tool-availability contract: every step checks for the tool it needs
# (`command -v git`, `devbox`, `nix`) and for repo opt-in signals
# (`.gitmodules`, `devbox.json`) before doing anything. In a repo or
# environment where a tool is not part of the dev process, the step is
# skipped with a [prime] SKIP/WARN line — never an error. Priming is
# best-effort by design: it must never block worktree acquisition, so all
# functions return 0 even when they warn.
#
# Output contract: all diagnostics go to stderr prefixed with `[prime]`.
# These helpers are inlined into execution-gate.sh, whose stdout is the
# worktree path the orchestrator consumes — nothing may write to stdout.
#
# Environment variables:
#   WORKTREE_PRIME=0        — skip priming entirely
#   WORKTREE_PRIME_STAMP    — when set, write a stamp file (JSON) at this path
#                             recording primed_at / path / devbox.json hash
#   NIX_TARBALL_CACHE_DIR   — override the tarball-cache location
#                             (default: $XDG_CACHE_HOME/nix/tarball-cache or
#                             ~/.cache/nix/tarball-cache)
#
# Materialization: inlined into consumer scripts via the include directive
# (`include "includes/worktree-prime.sh"`). The file is pure bash with no
# template directives, so repo-local tooling may also `source` it directly.
#
# Consumers:
#   - execution/execute-upsert/scripts/execution-gate.sh.tmpl
#   - skills-src: scripts/treehouse-pool-warm.sh (sourced directly)

# nix_tarball_cache_check — validate the nix flake tarball cache.
#
# The tarball cache ($XDG_CACHE_HOME/nix/tarball-cache or
# ~/.cache/nix/tarball-cache) is a bare git repo nix uses for
# github:NixOS/nixpkgs/... flake refs. When it is corrupted (e.g. only an
# objects/ dir with no repo metadata), EVERY cold package resolve fails with
# "could not find repository" — but warm .devbox caches never re-resolve, so
# the corruption hides until a fresh/stale worktree triggers a cold resolve.
#
# The cache is regenerable, so a corrupt copy is moved aside (not deleted —
# keeps a forensic copy) and nix rebuilds it on the next fetch.
nix_tarball_cache_check() {
	# Needs git to validate the cache repo; without git there is nothing
	# we can verify or the caller could not have cloned anyway.
	command -v git >/dev/null 2>&1 || return 0

	local cache_dir="${NIX_TARBALL_CACHE_DIR:-${XDG_CACHE_HOME:-${HOME:-}/.cache}/nix/tarball-cache}"
	[[ -n "$cache_dir" && -d "$cache_dir" ]] || return 0

	if git -C "$cache_dir" rev-parse --git-dir >/dev/null 2>&1; then
		return 0
	fi

	local backup="${cache_dir}.corrupt-$(date +%Y%m%d-%H%M%S 2>/dev/null || echo unknown)"
	if mv "$cache_dir" "$backup" 2>/dev/null; then
		echo "[prime] WARN: nix tarball-cache was corrupt — moved aside to $backup (nix will rebuild it)" >&2
	else
		echo "[prime] WARN: nix tarball-cache at $cache_dir looks corrupt but could not be moved aside" >&2
	fi
	return 0
}

# _worktree_prime_devbox_ok — health check: can devbox resolve the env?
# `devbox run -- true` forces env resolution without doing real work. No
# timeout wrapper: macOS lacks GNU `timeout` by default, and a cold nix
# fetch legitimately takes minutes — at lease time slowness is acceptable
# (it is exactly the work pool-warm/front-loading exists to absorb).
_worktree_prime_devbox_ok() {
	(cd "$1" && devbox run -- true >/dev/null 2>&1)
}

# worktree_prime <path> — prime a worktree for development.
#
# Steps, each independently guarded:
#   1. git submodule update --init   (only when .gitmodules exists)
#   2. nix tarball-cache validation  (only when devbox.json exists —
#      devbox is the nix consumer here; the check itself only needs git)
#   3. devbox env health check       (only when devbox.json exists AND
#      devbox is installed) — on failure, remove the stale .devbox and retry
#      once; a second failure warns but does not block.
#   4. stamp file                    (only when WORKTREE_PRIME_STAMP is set)
worktree_prime() {
	local path="${1:-}"

	if [[ "${WORKTREE_PRIME:-1}" == "0" ]]; then
		echo "[prime] SKIP: WORKTREE_PRIME=0 — skipping $path" >&2
		return 0
	fi

	if [[ -z "$path" || ! -d "$path" ]]; then
		echo "[prime] WARN: worktree_prime called with missing/invalid path '${path:-<empty>}'" >&2
		return 0
	fi

	if ! command -v git >/dev/null 2>&1; then
		echo "[prime] SKIP: git not on PATH — cannot prime $path" >&2
		return 0
	fi

	# --- Submodules: only when the repo declares them ---
	if [[ -f "$path/.gitmodules" ]]; then
		if git -C "$path" submodule update --init >/dev/null 2>&1; then
			echo "[prime] submodules initialized: $path" >&2
		else
			echo "[prime] WARN: 'git submodule update --init' failed in $path — anything reading vendored dirs may fail later" >&2
		fi
	fi

	# --- Devbox env: only when the repo opts in via devbox.json ---
	if [[ -f "$path/devbox.json" ]]; then
		if ! command -v devbox >/dev/null 2>&1; then
			echo "[prime] SKIP: $path has devbox.json but devbox is not installed — env check skipped" >&2
		else
			# Pre-validate the shared nix cache so a corrupt global cache
			# is repaired before devbox trips over it on a cold resolve.
			nix_tarball_cache_check

			if _worktree_prime_devbox_ok "$path"; then
				echo "[prime] devbox env healthy: $path" >&2
			else
				echo "[prime] WARN: devbox env check failed in $path — removing stale .devbox and retrying" >&2
				if [[ -d "$path/.devbox" ]]; then
					rm -rf "$path/.devbox" 2>/dev/null || \
						echo "[prime] WARN: could not remove $path/.devbox" >&2
				fi
				# The stale env is gone; a corrupt shared cache may have
				# been the real culprit — re-check before the retry.
				nix_tarball_cache_check
				if _worktree_prime_devbox_ok "$path"; then
					echo "[prime] devbox env repaired and healthy: $path" >&2
				else
					echo "[prime] WARN: devbox env still failing in $path after repair — devbox commands in this worktree may fail" >&2
				fi
			fi
		fi
	fi

	# --- Stamp: record that priming ran (for gate-pass observability) ---
	if [[ -n "${WORKTREE_PRIME_STAMP:-}" ]]; then
		local stamp_dir stamp_sha="none"
		stamp_dir="$(dirname "$WORKTREE_PRIME_STAMP")"
		[[ -f "$path/devbox.json" ]] && stamp_sha="$(git hash-object "$path/devbox.json" 2>/dev/null || echo unknown)"
		mkdir -p "$stamp_dir" 2>/dev/null || true
		{
			printf '{'
			printf '"primed_at":"%s",' "$(date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || echo unknown)"
			printf '"path":"%s",' "$path"
			printf '"devbox_json_sha":"%s"' "$stamp_sha"
			printf '}\n'
		} >"$WORKTREE_PRIME_STAMP" 2>/dev/null || \
			echo "[prime] WARN: could not write prime stamp to $WORKTREE_PRIME_STAMP" >&2
	fi

	return 0
}


# --- Args ---
# Parse positional args + optional --story-type, --new, and --allow-dirty flags.
# Usage: execution-gate.sh <story-id-slug> [base-sha] [--story-type <type>] [--new] [--allow-dirty]
# The --story-type flag is a forward-compatible metadata tag (trivial|standard|research).
# Today all types are treated identically — the value is stored in the gate-pass
# file for future divergence. If divergence is needed, the behavior change is a
# single case statement here, not a handoff document re-edit.
# The --new flag skips the resume path and forces a fresh worktree acquisition
# for this slug (best-effort release of any recorded prior lease first).
# The --allow-dirty flag bypasses the dirty-default-branch precondition
# (Check 1) without touching the working tree — for callers that knowingly
# leave unrelated uncommitted files on main/master while the story runs in
# its worktree.
STORY_TYPE="standard"
FORCE_NEW=0
NEW_FLAG="false"
ALLOW_DIRTY=0
ALLOW_DIRTY_FLAG="false"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --story-type|--story-type=*)
      parse_value_flag "$1" "${2:-}" STORY_TYPE
      shift "$SHIFT_COUNT"
      ;;
    --new|--new=*)
      parse_bool_flag "$1" NEW_FLAG
      shift "$SHIFT_COUNT"
      ;;
    --allow-dirty|--allow-dirty=*)
      parse_bool_flag "$1" ALLOW_DIRTY_FLAG
      shift "$SHIFT_COUNT"
      ;;
    *)
      reject_unknown_flag "$1"
      if [[ -z "${STORY_SLUG:-}" ]]; then
        STORY_SLUG="$1"
      elif [[ -z "${BASE_SHA:-}" ]]; then
        BASE_SHA="$1"
      else
        echo "Unexpected argument: $1" >&2
        echo "Usage: execution-gate.sh <story-id-slug> [base-sha] [--story-type <trivial|standard|research>] [--new] [--allow-dirty]" >&2
        exit 1
      fi
      shift
      ;;
  esac
done
if [[ "$NEW_FLAG" == "true" ]]; then FORCE_NEW=1; fi
if [[ "$ALLOW_DIRTY_FLAG" == "true" ]]; then ALLOW_DIRTY=1; fi

if [[ -z "${STORY_SLUG:-}" ]]; then
  echo "Usage: execution-gate.sh <story-id-slug> [base-sha] [--story-type <trivial|standard|research>] [--new] [--allow-dirty]" >&2
  exit 1
fi

# Validate story type
case "$STORY_TYPE" in
  trivial|standard|research) ;;
  *)
    echo "BLOCK: Invalid story type '$STORY_TYPE'. Must be one of: trivial, standard, research" >&2
    exit 1
    ;;
esac

BASE_SHA="${BASE_SHA:-HEAD}"
WORKTREE_PATH="$WORKTREE_BASE/$STORY_SLUG"
STORY_BRANCH="feature/current/execute-upsert/$STORY_SLUG"
# Per-story gate-pass file — resume is keyed to THIS story's slug only.
GATE_PASS="$GATE_DIR/gate-pass-${STORY_SLUG}"
# Where worktree_prime records that it ran for this story (observability only).
export WORKTREE_PRIME_STAMP="$GATE_DIR/prime-${STORY_SLUG}"

mkdir -p "$GATE_DIR"

# --- Check 1: not on main with uncommitted changes ---
CURRENT_BRANCH=$(git -C "$PROJECT_DIR" rev-parse --abbrev-ref HEAD)
if [[ "$CURRENT_BRANCH" == "main" || "$CURRENT_BRANCH" == "master" ]]; then
  DIRTY=$(git -C "$PROJECT_DIR" status --porcelain | wc -l | tr -d ' ')
  if [[ "$DIRTY" -gt 0 ]]; then
    if [[ "$ALLOW_DIRTY" -eq 1 ]]; then
      echo "[gate] --allow-dirty: proceeding with $DIRTY uncommitted change(s) on $CURRENT_BRANCH — they are out of scope for this story and stay untouched on the default branch." >&2
    else
      echo "BLOCK: You are on $CURRENT_BRANCH with $DIRTY uncommitted changes." >&2
      echo "Create a checkpoint commit or stash before dispatching subagents." >&2
      echo "Run: git -C \"$PROJECT_DIR\" stash or commit your changes first." >&2
      echo "If the dirty files are unrelated to this story and should stay on $CURRENT_BRANCH, re-run with --allow-dirty." >&2
      exit 2
    fi
  fi
fi

# --- Check 2: base SHA exists ---
if ! git -C "$PROJECT_DIR" rev-parse --verify "$BASE_SHA" >/dev/null 2>&1; then
  echo "BLOCK: Base SHA '$BASE_SHA' does not exist." >&2
  exit 2
fi

# --- --new: discard a recorded prior lease for this slug ---
# A per-story gate-pass normally triggers RESUME below. --new bypasses that and
# forces a fresh acquisition. If a prior treehouse lease is recorded for this
# slug, return it first so it does not leak a pool slot (best-effort — a failed
# return warns but does not block the new acquisition).
if [[ "$FORCE_NEW" -eq 1 ]] && [[ -f "$GATE_PASS" ]]; then
  OLD_PATH="$(canon_path "$(cat "$GATE_PASS")")"
  echo "[gate] --new: discarding prior gate-pass for $STORY_SLUG (was: $OLD_PATH)" >&2
  if [[ "$(treehouse_available)" == "1" ]] && [[ -f "$GATE_DIR/lease-${STORY_SLUG}" ]] && [[ -d "$OLD_PATH" ]]; then
    OLD_LEASE_ID=""
    OLD_LEASE_HOLDER=""
    { IFS= read -r OLD_LEASE_ID; IFS= read -r OLD_LEASE_HOLDER; } < "$GATE_DIR/lease-${STORY_SLUG}" || true
    treehouse_return "$OLD_PATH" "$OLD_LEASE_ID" "$OLD_LEASE_HOLDER" 2>&1 | sed 's/^/[gate] /' >&2 || \
      echo "[gate] WARNING: could not return prior lease at $OLD_PATH — continuing" >&2
  elif [[ -d "$OLD_PATH" ]] && git -C "$PROJECT_DIR" worktree list --porcelain 2>/dev/null | grep -qxF "worktree $OLD_PATH"; then
    # Non-treehouse worktree — the gate cannot safely remove it (it may hold
    # uncommitted work). Warn so the operator can clean it up manually.
    echo "[gate] WARNING: prior worktree at $OLD_PATH is not treehouse-managed." >&2
    echo "[gate]   It is now untracked by the gate — inspect and remove manually:" >&2
    echo "[gate]   git -C \"$PROJECT_DIR\" worktree remove \"$OLD_PATH\"" >&2
  elif [[ -d "$OLD_PATH" ]]; then
    echo "[gate] WARNING: prior path $OLD_PATH exists but is not a registered worktree — inspect and remove manually." >&2
  fi
  # Clear the compat pointer if it still references the discarded worktree —
  # otherwise a failed acquisition below would leave it pointing at a stale
  # path the hook could mistake for a live gate-pass.
  if [[ "$(canon_path "$(cat "$CURRENT_GATE_PASS" 2>/dev/null || true)")" == "$OLD_PATH" ]]; then
    rm -f "$CURRENT_GATE_PASS"
  fi
  rm -f "$GATE_PASS" "$GATE_DIR/lease-${STORY_SLUG}"
fi

# --- Check 3: worktree already exists (resume case) ---
# Keyed to THIS story's per-story gate-pass file — a different story's lease
# never satisfies this check, so a second story's gate run acquires its own
# worktree instead of resuming the first story's.
# For treehouse-managed worktrees, we check the gate-pass file for a lease path.
# For manual worktrees, we check git worktree list.
if [[ "$FORCE_NEW" -eq 0 ]] && [[ -f "$GATE_PASS" ]]; then
  # Canonicalize — gate-pass files written before canonicalization (or with
  # a symlinked /tmp prefix) must still match `git worktree list` output.
  EXISTING_PATH="$(canon_path "$(cat "$GATE_PASS")")"
  if [[ -d "$EXISTING_PATH" ]]; then
    # Verify it's still a valid worktree — anchored porcelain match, not a
    # substring grep (a slug like "foo" must not match "foo-bar"'s worktree).
    if git -C "$PROJECT_DIR" worktree list --porcelain 2>/dev/null | grep -qxF "worktree $EXISTING_PATH"; then
      echo "RESUME: Worktree already exists at $EXISTING_PATH" >&2
      # Re-prime on resume: the env may have gone stale since the lease began.
      worktree_prime "$EXISTING_PATH" || \
        echo "[gate] WARNING: worktree_prime reported problems — see [prime] lines above" >&2
      echo "$EXISTING_PATH" > "$CURRENT_GATE_PASS"
      echo "$EXISTING_PATH"
      exit 0
    fi
    # Treehouse worktree — check if lease is still active
    if [[ "$(treehouse_available)" == "1" ]] && [[ "$(treehouse_is_managed "$EXISTING_PATH")" == "1" ]]; then
      echo "RESUME: Treehouse worktree still leased at $EXISTING_PATH" >&2
      worktree_prime "$EXISTING_PATH" || \
        echo "[gate] WARNING: worktree_prime reported problems — see [prime] lines above" >&2
      echo "$EXISTING_PATH" > "$CURRENT_GATE_PASS"
      echo "$EXISTING_PATH"
      exit 0
    fi
  fi
fi

# Also check legacy manual worktree path (anchored porcelain match — see above)
if [[ "$FORCE_NEW" -eq 0 ]] && git -C "$PROJECT_DIR" worktree list --porcelain | grep -qxF "worktree $WORKTREE_PATH"; then
  echo "RESUME: Worktree already exists at $WORKTREE_PATH" >&2
  worktree_prime "$WORKTREE_PATH" || \
    echo "[gate] WARNING: worktree_prime reported problems — see [prime] lines above" >&2
  echo "$WORKTREE_PATH" > "$GATE_PASS"
  echo "$WORKTREE_PATH" > "$CURRENT_GATE_PASS"
  echo "$WORKTREE_PATH"
  exit 0
fi

# --- Acquire worktree ---
# Treehouse is required (not optional). Treehouse makes worktrees cheap —
# reusable, cache-warmed, pool-managed. The manual `git worktree add`
# fallback was removed because it created a two-path maintenance burden and
# the manual path lacked lease tracking, cache warming, and pool reuse.
# If treehouse is not installed, the gate fails with a clear install
# instruction rather than silently degrading.
TREEHOUSE_USED=0

if [[ "$(treehouse_available)" != "1" ]]; then
  echo "BLOCK: treehouse is not installed but is required for worktree isolation." >&2
  echo "Treehouse makes worktrees cheap (reusable, cache-warmed, pool-managed)." >&2
  echo "Install: https://github.com/kunchenguid/treehouse" >&2
  echo "Or: brew install treehouse (if available on tap)" >&2
  echo "Or: cargo install treehouse (if Rust toolchain is available)" >&2
  exit 2
fi

echo "[gate] Acquiring worktree via treehouse pool..." >&2
TREEHOUSE_LEASE_HOLDER="execute-upsert/${STORY_SLUG}"
# Invoke directly (no command substitution) — the helper exports
# TREEHOUSE_LEASE_ID for the lease-<slug> record, and a subshell would
# discard it. Stderr goes to a file so diagnostics never corrupt the path.
ACQUIRE_OUT="$(mktemp "${TMPDIR:-/tmp}/exec-gate-acquire.XXXXXX")"
ACQUIRE_ERR="$(mktemp "${TMPDIR:-/tmp}/exec-gate-acquire-err.XXXXXX")"
if treehouse_acquire "execute-upsert/${STORY_SLUG}" >"$ACQUIRE_OUT" 2>"$ACQUIRE_ERR"; then
  ACQUIRED_PATH="$(cat "$ACQUIRE_OUT")"
else
  echo "[gate] Treehouse acquire failed" >&2
  cat "$ACQUIRE_ERR" >&2
  rm -f "$ACQUIRE_OUT" "$ACQUIRE_ERR"
  exit 2
fi
rm -f "$ACQUIRE_OUT" "$ACQUIRE_ERR"

if [[ -n "$ACQUIRED_PATH" ]]; then
  WORKTREE_PATH="$(canon_path "$ACQUIRED_PATH")"
  TREEHOUSE_USED=1
  echo "[gate] Treehouse worktree leased: $WORKTREE_PATH" >&2
  echo "[gate] Lease ID: ${TREEHOUSE_LEASE_ID:-unknown}" >&2

  # Record the lease info for later return
  cat > "$GATE_DIR/lease-${STORY_SLUG}" <<EOF
${TREEHOUSE_LEASE_ID:-}
${TREEHOUSE_LEASE_HOLDER:-}
${WORKTREE_PATH}
EOF
else
  echo "BLOCK: treehouse acquire returned empty path" >&2
  exit 2
fi

# --- Create named story branch inside the worktree ---
# Treehouse worktrees start in detached HEAD at the default branch tip.
# We need a named branch for the story so pushes, PRs, and land-on-env-dev work.
if [[ "$TREEHOUSE_USED" -eq 1 ]]; then
  # The worktree is at detached HEAD at the default branch tip.
  # Check out the base SHA, then create the story branch.
  git -C "$WORKTREE_PATH" checkout "$BASE_SHA" 2>&1 | sed 's/^/[gate] /' >&2 || {
    echo "[gate] WARNING: could not checkout $BASE_SHA, staying at default branch tip" >&2
  }
  git -C "$WORKTREE_PATH" checkout -b "$STORY_BRANCH" 2>&1 | sed 's/^/[gate] /' >&2 || {
    # Branch may already exist if this is a re-acquired worktree
    echo "[gate] Branch $STORY_BRANCH may already exist, switching to it" >&2
    git -C "$WORKTREE_PATH" checkout "$STORY_BRANCH" 2>&1 | sed 's/^/[gate] /' >&2 || true
  }
fi

# --- Symlink node_modules if it exists (so the worktree can build/test) ---
# Treehouse worktrees may already have this from pool reuse, but symlink if missing.
if [[ -d "$PROJECT_DIR/node_modules" ]] && [[ ! -e "$WORKTREE_PATH/node_modules" ]]; then
  ln -sfn "$PROJECT_DIR/node_modules" "$WORKTREE_PATH/node_modules" 2>/dev/null || true
fi

# --- Prime the worktree environment ---
# Submodule init, devbox env health check (+ stale .devbox repair), and shared
# nix tarball-cache validation run at lease time so environment problems
# surface here — not mid-commit inside a pre-commit hook. Best-effort:
# worktree_prime warns via [prime] stderr lines but never blocks the gate —
# the story may not need every tool it checks.
worktree_prime "$WORKTREE_PATH" || \
  echo "[gate] WARNING: worktree_prime reported problems — see [prime] lines above" >&2

# --- Create checkpoint commit in the worktree ---
# (The worktree starts clean from BASE_SHA, so the checkpoint is implicit.
#  But we record the checkpoint SHA for rollback.)
CHECKPOINT_SHA=$(git -C "$WORKTREE_PATH" rev-parse HEAD)
echo "$CHECKPOINT_SHA" > "$GATE_DIR/checkpoint-$STORY_SLUG"

# --- Write gate pass files ---
# Per-story file (authoritative — drives resume for this slug) and the legacy
# current-gate-pass compat pointer (most recent live worktree — keeps older
# check-subagent-gate.sh hook versions working).
echo "$WORKTREE_PATH" > "$GATE_PASS"
echo "$WORKTREE_PATH" > "$CURRENT_GATE_PASS"

# Record whether treehouse was used (for land-on-env-dev to know whether to return the lease)
echo "$TREEHOUSE_USED" > "$GATE_DIR/treehouse-used-${STORY_SLUG}"

# Record story type as metadata (forward-compatible tag — currently unused behaviorally)
echo "$STORY_TYPE" > "$GATE_DIR/story-type-${STORY_SLUG}"

echo "GATE PASSED: worktree=$WORKTREE_PATH branch=$STORY_BRANCH checkpoint=$CHECKPOINT_SHA treehouse=$TREEHOUSE_USED story-type=$STORY_TYPE" >&2
echo "$WORKTREE_PATH"
