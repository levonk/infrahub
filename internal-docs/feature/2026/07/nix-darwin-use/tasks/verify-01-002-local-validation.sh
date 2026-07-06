#!/usr/bin/env bash
# verify-01-002-local-validation.sh
#
# Verification script for story 01-002 (darwin flake authoring) — Task 10 + Acceptance Criteria.
# Run this ON lzkmbp2016 (the Mac being configured). It performs:
#   1. Static checks (flake check, flake show, no home-manager, apps.yml cask→nix)
#   2. Destructive apply: `nix run nix-darwin -- switch --flake ...#lzkmbp2016`
#   3. Idempotency re-run
#   4. Post-apply `defaults read` spot-checks + `brew list --cask`
#   5. Rollback test: `darwin-rebuild rollback` (restores prior generation)
#
# The destructive steps (apply, idempotency, rollback) prompt for confirmation.
# Safe static checks run first so you can bail before anything touches the system.
#
# Usage:
#   ./verify-01-002-local-validation.sh            # prompt before each destructive step
#   ./verify-01-002-local-validation.sh --yes      # skip confirmation prompts (CI / confident run)
#   ./verify-01-002-local-validation.sh --skip-apply  # static checks only, no darwin-rebuild
#
# Exit codes:
#   0  all enabled checks passed
#   1  one or more checks failed (see summary table)
#   2  bad usage / prereq missing

set -euo pipefail

# --- config -----------------------------------------------------------------
REPO_ROOT="${REPO_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)}"
FLAKE_DIR="$REPO_ROOT/shared/active/02-config/nix/darwin"
HOST="lzkmbp2016"
APPS_YML="$REPO_ROOT/shared/active/02-config/ansible/infrastructure/apps.yml"

# Fleet casks that MUST NOT appear in `brew list --cask` after apply.
FLEET_CASKS=("orbstack" "rustdesk")

# --- helpers ----------------------------------------------------------------
PASS=0
FAIL=0
FAILED_CHECKS=()

# Colors (disabled if not a TTY)
if [ -t 1 ]; then
  C_GREEN=$'\033[32m'; C_RED=$'\033[31m'; C_YELLOW=$'\033[33m'; C_BOLD=$'\033[1m'; C_RESET=$'\033[0m'
else
  C_GREEN=""; C_RED=""; C_YELLOW=""; C_BOLD=""; C_RESET=""
fi

log() { printf '%s\n' "$*"; }
ok()   { printf '%sPASS%s  %s\n' "$C_GREEN"  "$C_RESET" "$1"; PASS=$((PASS+1)); }
bad()  { printf '%sFAIL%s  %s\n' "$C_RED"    "$C_RESET" "$1"; FAIL=$((FAIL+1)); FAILED_CHECKS+=("$1"); }
warn() { printf '%sWARN%s  %s\n' "$C_YELLOW" "$C_RESET" "$1"; }

check_eq() { # check_eq <label> <actual> <expected>
  local label="$1" actual="$2" expected="$3"
  if [ "$actual" = "$expected" ]; then ok "$label (got: $actual)"; else bad "$label (expected: $expected, got: $actual)"; fi
}

confirm() { # confirm <prompt>  → returns 0 on yes, 1 on no
  if [ "${YES:-0}" = "1" ]; then log "$C_YELLOW[auto-yes] $1$C_RESET"; return 0; fi
  printf '%s%s (y/N)? %s' "$C_YELLOW" "$1" "$C_RESET"
  local reply; read -r reply
  case "$reply" in y|Y|yes|YES) return 0 ;; *) return 1 ;; esac
}

run_quiet() { # run_quiet <label> <cmd...>  → prints output only on failure
  local label="$1"; shift
  local out rc
  if out=$("$@" 2>&1); then ok "$label"; log "$out" | sed 's/^/      /' >&2; return 0
  else rc=$?; bad "$label (exit $rc)"; log "$out" | sed 's/^/      /' >&2; return $rc; fi
}

# --- arg parsing ------------------------------------------------------------
YES=0
SKIP_APPLY=0
for arg in "$@"; do
  case "$arg" in
    --yes|-y) YES=1 ;;
    --skip-apply) SKIP_APPLY=1 ;;
    -h|--help)
      sed -n '2,20p' "$0"; exit 0 ;;
    *) log "Unknown arg: $arg" >&2; exit 2 ;;
  esac
done

# --- prereqs ----------------------------------------------------------------
log "${C_BOLD}=== nix-darwin 01-002 local validation ===${C_RESET}"
log "Repo:  $REPO_ROOT"
log "Flake: $FLAKE_DIR"
log "Host:  $HOST"
log ""

if [ "$(uname -s)" != "Darwin" ]; then
  warn "Not running on Darwin (uname -s = $(uname -s)). Static checks will run; apply steps will be skipped."
  SKIP_APPLY=1
fi

if ! command -v nix >/dev/null 2>&1; then
  bad "nix not found in PATH — source /etc/profile.d/nix.sh or fix PATH first"
  exit 2
fi

if [ ! -f "$FLAKE_DIR/flake.nix" ]; then
  bad "flake.nix not found at $FLAKE_DIR/flake.nix — check REPO_ROOT / branch checkout"
  exit 2
fi

# Make sure we're on the right branch
BRANCH=$(git -C "$REPO_ROOT" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "detached")
log "On branch: $BRANCH"
case "$BRANCH" in
  *01-002-darwin-flake-authoring*) ;;
  *) warn "Not on the 01-002 story branch (current: $BRANCH). Static checks may use stale files." ;;
esac
log ""

# --- 1. static checks -------------------------------------------------------
log "${C_BOLD}--- Phase 1: static checks ---${C_RESET}"

# 1a. nix flake check
if nix flake check "$FLAKE_DIR" >/tmp/nix-flake-check.log 2>&1; then
  ok "nix flake check (exit 0)"
else
  rc=$?
  bad "nix flake check (exit $rc)"
  tail -n 20 /tmp/nix-flake-check.log | sed 's/^/      /' >&2
fi

# 1b. nix flake show lists both configs
SHOW_OUT=$(nix flake show "$FLAKE_DIR" --json 2>/dev/null || echo "")
if echo "$SHOW_OUT" | /usr/bin/python3 -c 'import json,sys
d=json.load(sys.stdin)
cfgs=d.get("darwinConfigurations",{})
sys.exit(0 if "lzkmbp2016" in cfgs and "lzkmbp2018" in cfgs else 1)' 2>/dev/null; then
  ok "nix flake show lists darwinConfigurations.lzkmbp2016 + lzkmbp2018"
else
  bad "nix flake show missing one or both darwinConfigurations"
  echo "$SHOW_OUT" | sed 's/^/      /' >&2
fi

# 1c. no home-manager references
if ! rg -q "home-manager" "$FLAKE_DIR/" 2>/dev/null; then
  ok "no home-manager references in $FLAKE_DIR/"
else
  bad "home-manager reference found in $FLAKE_DIR/"
  rg -n "home-manager" "$FLAKE_DIR/" | sed 's/^/      /' >&2
fi

# 1d. orbstack in apps.yml under nix packages, not casks
if [ -f "$APPS_YML" ]; then
  # orbstack should appear in the nix_gui_packages block, not the brew_casks block
  if rg -q "orbstack" "$APPS_YML" 2>/dev/null; then
    # crude block check: is it under infra_app_brew_casks?
    if awk '/^infra_app_brew_casks:/{f=1} /^[a-z]/{if($0 !~ /^infra_app_brew_casks:/) f=0} f && /orbstack/{found=1} END{exit found?0:1}' "$APPS_YML"; then
      bad "orbstack still listed under infra_app_brew_casks in $APPS_YML"
    else
      ok "orbstack not under infra_app_brew_casks (moved to nix packages)"
    fi
  else
    bad "orbstack not found in $APPS_YML at all"
  fi
else
  warn "apps.yml not found at $APPS_YML — skipping cask/nix check"
fi

log ""
log "Static checks: $PASS passed, $FAIL failed."
log ""

if [ "$SKIP_APPLY" = "1" ]; then
  log "${C_YELLOW}--skip-apply set (or non-Darwin). Stopping after static checks.${C_RESET}"
  log ""
  log "${C_BOLD}=== Summary ===${C_RESET}"
  log "  Passed: $PASS"
  log "  Failed: $FAIL"
  if [ "$FAIL" -gt 0 ]; then
    log "${C_RED}Failed checks:${C_RESET}"
    for c in "${FAILED_CHECKS[@]}"; do log "  - $c"; done
    exit 1
  fi
  exit 0
fi

# --- 2. destructive: darwin-rebuild switch ----------------------------------
log "${C_BOLD}--- Phase 2: darwin-rebuild switch (DESTRUCTIVE) ---${C_RESET}"
log "This will apply the nix-darwin configuration to THIS Mac ($HOST)."
log "It modifies system settings, homebrew, and may restart services."
log "If it goes wrong, run: darwin-rebuild rollback"
log ""

if ! confirm "Run 'nix run nix-darwin -- switch --flake $FLAKE_DIR#$HOST' now?"; then
  warn "Apply skipped by user. Post-apply checks will be skipped too."
  log ""
  log "${C_BOLD}=== Summary (partial) ===${C_RESET}"
  log "  Passed: $PASS"
  log "  Failed: $FAIL"
  exit $([ "$FAIL" -gt 0 ] && echo 1 || echo 0)
fi

APPLY_LOG=/tmp/darwin-rebuild-switch-01-002.log
log "Running darwin-rebuild switch (logging to $APPLY_LOG)..."
if nix run nix-darwin -- switch --flake "$FLAKE_DIR#$HOST" >"$APPLY_LOG" 2>&1; then
  ok "darwin-rebuild switch succeeded (exit 0)"
  # show the diff-style changes
  rg -n "activating|reloading|building" "$APPLY_LOG" | head -n 10 | sed 's/^/      /' >&2
else
  rc=$?
  bad "darwin-rebuild switch failed (exit $rc)"
  tail -n 40 "$APPLY_LOG" | sed 's/^/      /' >&2
  warn "If the system is in a bad state, run: darwin-rebuild rollback"
  log ""
  log "${C_BOLD}=== Summary (apply failed) ===${C_RESET}"
  log "  Passed: $PASS"
  log "  Failed: $FAIL"
  for c in "${FAILED_CHECKS[@]}"; do log "  - $c"; done
  exit 1
fi
log ""

# --- 3. idempotency ---------------------------------------------------------
log "${C_BOLD}--- Phase 3: idempotency re-run ---${C_RESET}"
IDEM_LOG=/tmp/darwin-rebuild-idempotency-01-002.log
log "Re-running darwin-rebuild switch (logging to $IDEM_LOG)..."
if nix run nix-darwin -- switch --flake "$FLAKE_DIR#$HOST" >"$IDEM_LOG" 2>&1; then
  # Idempotent if the second run reports no changes. nix-darwin prints
  # "activating the configuration..." even on no-op, but the diff section
  # should be empty. Heuristic: no "created" / "removed" / "changed" lines.
  if rg -q "created|removed|changed" "$IDEM_LOG" 2>/dev/null; then
    warn "Second run reported changes — not fully idempotent (review $IDEM_LOG)"
    rg -n "created|removed|changed" "$IDEM_LOG" | head -n 10 | sed 's/^/      /' >&2
    bad "idempotency (second run reported changes)"
  else
    ok "idempotency (second run reported no changes)"
  fi
else
  rc=$?
  bad "idempotency re-run failed (exit $rc)"
  tail -n 20 "$IDEM_LOG" | sed 's/^/      /' >&2
fi
log ""

# --- 4. post-apply defaults read spot-checks --------------------------------
log "${C_BOLD}--- Phase 4: post-apply defaults read spot-checks ---${C_RESET}"

# FR-6: OS auto-install OFF
SU_VAL=$(defaults read /Library/Preferences/com.apple.SoftwareUpdate AutomaticallyInstallMacOSUpdates 2>/dev/null || echo "MISSING")
check_eq "SoftwareUpdate.AutomaticallyInstallMacOSUpdates == 0" "$SU_VAL" "0"

# FR-6: ConfigDataInstall OFF
CD_VAL=$(defaults read /Library/Preferences/com.apple.SoftwareUpdate ConfigDataInstall 2>/dev/null || echo "MISSING")
check_eq "SoftwareUpdate.ConfigDataInstall == 0" "$CD_VAL" "0"

# FR-6: CriticalUpdateInstall OFF
CU_VAL=$(defaults read /Library/Preferences/com.apple.SoftwareUpdate CriticalUpdateInstall 2>/dev/null || echo "MISSING")
check_eq "SoftwareUpdate.CriticalUpdateInstall == 0" "$CU_VAL" "0"

# FR-6: AutoUpdate (apps) ON
AU_VAL=$(defaults read /Library/Preferences/com.apple.commerce AutoUpdate 2>/dev/null || echo "MISSING")
check_eq "commerce.AutoUpdate == 1" "$AU_VAL" "1"

# FR-7: SubmitDiagInfo OFF
SD_VAL=$(defaults read com.apple.SubmitDiagInfo AutoSubmit 2>/dev/null || echo "MISSING")
check_eq "SubmitDiagInfo.AutoSubmit == 0" "$SD_VAL" "0"

# FR-6: dock autohide (sanity that defaults applied at all)
DH_VAL=$(defaults read com.apple.dock autohide 2>/dev/null || echo "MISSING")
check_eq "dock.autohide == 1" "$DH_VAL" "1"
log ""

# --- 5. brew list --cask: no fleet casks ------------------------------------
log "${C_BOLD}--- Phase 5: brew cask check ---${C_RESET}"
if command -v brew >/dev/null 2>&1; then
  BREW_CASKS=$(brew list --cask 2>/dev/null || echo "")
  FOUND_FLEET=()
  for c in "${FLEET_CASKS[@]}"; do
    if echo "$BREW_CASKS" | rg -q "^${c}\$"; then
      FOUND_FLEET+=("$c")
    fi
  done
  if [ "${#FOUND_FLEET[@]}" -eq 0 ]; then
    ok "no fleet casks in 'brew list --cask' (orbstack, rustdesk absent)"
  else
    bad "fleet casks still installed: ${FOUND_FLEET[*]}"
    echo "$BREW_CASKS" | sed 's/^/      /' >&2
  fi
else
  warn "brew not found — skipping cask check"
fi
log ""

# --- 6. rollback test -------------------------------------------------------
log "${C_BOLD}--- Phase 6: rollback test (DESTRUCTIVE) ---${C_RESET}"
log "This will roll back to the previous system generation."
log "You can re-apply with: nix run nix-darwin -- switch --flake $FLAKE_DIR#$HOST"
log ""

if ! confirm "Run 'darwin-rebuild rollback' now?"; then
  warn "Rollback skipped by user."
  log ""
  log "${C_BOLD}=== Summary ===${C_RESET}"
  log "  Passed: $PASS"
  log "  Failed: $FAIL"
  if [ "$FAIL" -gt 0 ]; then
    log "${C_RED}Failed checks:${C_RESET}"
    for c in "${FAILED_CHECKS[@]}"; do log "  - $c"; done
    exit 1
  fi
  exit 0
fi

ROLLBACK_LOG=/tmp/darwin-rebuild-rollback-01-002.log
log "Running darwin-rebuild rollback (logging to $ROLLBACK_LOG)..."
if darwin-rebuild rollback >"$ROLLBACK_LOG" 2>&1; then
  ok "darwin-rebuild rollback succeeded (exit 0)"
else
  rc=$?
  bad "darwin-rebuild rollback failed (exit $rc)"
  tail -n 20 "$ROLLBACK_LOG" | sed 's/^/      /' >&2
fi

# Show available generations for the record
log ""
log "Available generations:"
darwin-rebuild generations 2>/dev/null | head -n 10 | sed 's/^/      /' || true
log ""

# --- summary ----------------------------------------------------------------
log "${C_BOLD}=== Summary ===${C_RESET}"
log "  Passed: $PASS"
log "  Failed: $FAIL"
if [ "$FAIL" -gt 0 ]; then
  log "${C_RED}Failed checks:${C_RESET}"
  for c in "${FAILED_CHECKS[@]}"; do log "  - $c"; done
  log ""
  log "${C_YELLOW}If the system is in a bad state:${C_RESET} darwin-rebuild rollback"
  log "${C_YELLOW}To re-apply the config:${C_RESET} nix run nix-darwin -- switch --flake $FLAKE_DIR#$HOST"
  exit 1
fi
log ""
log "${C_GREEN}All checks passed. Story 01-002 Task 10 + acceptance criteria verified.${C_RESET}"
log "Next: mark Task 10 and the remaining acceptance criteria [x] in the story file,"
log "set status: \"done\", set the 01-002-done git tag, and update the index file."
exit 0
