#!/usr/bin/env bash
# typescript-verify.sh — TypeScript extension verification-stage lifecycle hook
#
# Called by skill_run_extension_hook "verification" (skill-base.sh), from command-gate-out.sh,
# immediately after skill_validate_task_artifacts -- i.e. AFTER the agent has returned and its
# artifacts have been validated. Fires only when the declaring manifest's task_type matches.
#
# Positional args (5, the fixed contract every lifecycle hook receives):
#   $1 = task_number   $2 = task_type   $3 = task_dir   $4 = session_id   $5 = operation
#
# Three-state outcome vocabulary per sub-check, never collapsed: ran_pass, ran_fail,
# skipped_no_command. Exit code is unconditionally 0 whenever this script itself ran to
# completion and printed its findings -- regardless of whether the typecheck/test it ran was
# green, red, or skipped. A non-zero exit is reserved for THIS SCRIPT failing (a bug in the
# hook: a missing jq interpreter, an unparseable package.json AT CWD), never for a finding about
# the target project. The lifecycle-hook contract is unconditionally non-blocking (no opt-in
# blocking mode), so this script's STDOUT text is the only channel that carries the
# pass/fail/skip finding anywhere -- this is why every skip path below prints an explicit
# "SKIP: <reason>" and never a word a reader could mistake for a success finding.
#
# ── Two-tier project detection ───────────────────────────────────────────────────────────────
# Tier 1 (fast path): if "package.json" exists directly at cwd, verify that one project with an
#   empty output prefix. No `find` is ever invoked in this case -- output is byte-identical to
#   the single-root behavior this hook has always had.
# Tier 2 (bounded fallback): reached ONLY when no "package.json" exists at cwd (this hook is
#   invoked with cwd fixed at the task's repo root by its caller, which may not be where the
#   Node/TypeScript project actually lives). Searches below cwd with:
#     find . -maxdepth 4 -name package.json \
#       -not -path '*/node_modules/*' -not -path '*/.git/*' -not -path '*/dist/*' \
#       -not -path '*/build/*' -not -path '*/.next/*' -not -path '*/out/*' \
#       -not -path '*/vendor/*' -not -path '*/.venv/*'
#   Results are sorted for determinism and iterated via `while IFS= read -r ... done < <(find
#   ... | sort)` -- process substitution, never a trailing pipe on the while itself, so the
#   while loop runs in THIS shell and the ran_pass/ran_fail/skipped_no_command counters it
#   increments are not silently discarded in a subshell.
#   At most 10 discovered projects are verified (the cap). If more than 10 are found, a loud
#   stderr NOTICE names the true count and states the run is INCOMPLETE -- a truncated run must
#   never look like a complete one. Every output line for a discovered (non-cwd) project is
#   prefixed with that project's relative directory, extending (never replacing) the existing
#   "[typescript-verify]" prefix, e.g. "[typescript-verify][a/b] running test: ...".
#   If the fallback also finds nothing, the terminal "SKIP: no package.json found ..." line
#   below is printed verbatim, exactly as it always has been for the single-root case.
#
# ── Malformed package.json policy ───────────────────────────────────────────────────────────
# A malformed package.json AT CWD (tier 1) keeps the pre-existing hook-input-error contract:
#   this script exits 1, exactly as it always has. A malformed package.json at a DISCOVERED
#   NESTED project (tier 2) does NOT exit non-zero -- it prints an "ERROR: ... -- skipping" line
#   on stderr, counts one skipped_no_command, and the loop continues to the next discovered
#   project. One bad nested manifest must never blank out findings for every sibling project.
#
# ── set -euo pipefail audit (new paths only) ────────────────────────────────────────────────
# - `find ... | sort` with zero matches: both commands exit 0 on an empty result; the process
#   substitution produces no lines and the while loop simply never executes its body. No error.
# - `ls tsconfig*.json >/dev/null 2>&1` inside verify_project(): used only as an `if` condition,
#   which is exempt from errexit (pre-existing pattern, unchanged by this refactor).
# - Arithmetic increments at value 0 (`skipped_no_command=$((skipped_no_command + 1))` etc.):
#   these use arithmetic EXPANSION `$(( ))` inside a plain assignment, not the arithmetic
#   COMMAND `(( ))` -- the assignment's own exit status is that of the assignment itself (always
#   0 for a syntactically valid expression), never the truth value of the computed number. A
#   result of 0 therefore never trips `set -e` here, unlike a bare `((var++))` would.

set -euo pipefail

# shellcheck disable=SC2034  # Positional args kept for interface parity with sibling hooks
# (skill_run_extension_hook's documented, stable 5-argument calling contract); this hook's own
# detection logic needs none of them directly.
TASK_NUMBER="${1:-}"
# shellcheck disable=SC2034
TASK_TYPE="${2:-}"
# shellcheck disable=SC2034
TASK_DIR="${3:-}"
# shellcheck disable=SC2034
SESSION_ID="${4:-}"
# shellcheck disable=SC2034
OPERATION="${5:-}"

ran_pass=0
ran_fail=0
skipped_no_command=0

if ! command -v jq &>/dev/null; then
  echo "[typescript-verify] ERROR: 'jq' command not found -- this hook cannot run" >&2
  exit 1
fi

# verify_project DIR PREFIX
#
# Runs the full per-directory detection (lockfile-priority package-manager resolution,
# package.json parse check, typecheck sub-check, test sub-check) against DIR, with every output
# line carrying PREFIX appended directly after the "[typescript-verify]" tag (empty string for
# the tier-1 fast path, so output there is byte-identical to the pre-refactor script).
# ran_pass/ran_fail/skipped_no_command are parent-shell globals incremented here directly --
# this function is never invoked inside a subshell, so the increments are never lost.
verify_project() {
  local dir="$1"
  local prefix="$2"
  local orig_pwd
  orig_pwd="$(pwd)"

  if ! cd "$dir" 2>/dev/null; then
    echo "[typescript-verify]${prefix} ERROR: cannot cd into '${dir}' -- skipping" >&2
    skipped_no_command=$((skipped_no_command + 1))
    return 0
  fi

  local pm=""
  if [ -f "pnpm-lock.yaml" ]; then
    pm="pnpm"
  elif [ -f "yarn.lock" ]; then
    pm="yarn"
  elif [ -f "package-lock.json" ]; then
    pm="npm"
  elif [ -f "bun.lockb" ]; then
    pm="bun"
  elif [ -f "package.json" ]; then
    pm="npm" # no committed lockfile, but npm run still works without one
  fi

  if [ -z "$pm" ]; then
    # Caller only invokes verify_project on a directory already confirmed to hold
    # package.json; this guard is defensive only and should be unreachable.
    cd "$orig_pwd"
    return 0
  fi

  # package.json exists if $pm is set -- confirm it actually parses before trusting it further.
  if ! jq -e . package.json >/dev/null 2>&1; then
    if [ -z "$prefix" ]; then
      # Tier-1 (cwd-local) malformed manifest: unchanged hook-input-error contract.
      echo "[typescript-verify] ERROR: package.json exists but is not valid JSON -- this hook cannot run" >&2
      exit 1
    fi
    # Tier-2 (discovered nested) malformed manifest: warn, skip, continue -- never fatal.
    echo "[typescript-verify]${prefix} ERROR: package.json exists but is not valid JSON -- skipping" >&2
    skipped_no_command=$((skipped_no_command + 1))
    cd "$orig_pwd"
    return 0
  fi

  # ── Typecheck sub-check ────────────────────────────────────────────────────────────────────
  local scripts_json typecheck_cmd
  scripts_json="$(jq -r '.scripts // {}' package.json)"
  typecheck_cmd=""
  for name in typecheck type-check tsc check; do
    if [ "$(echo "$scripts_json" | jq -r --arg n "$name" 'has($n)')" = "true" ]; then
      typecheck_cmd="${pm} run ${name}"
      break
    fi
  done

  if [ -z "$typecheck_cmd" ]; then
    # Config-driven fallback: no declared script, but a tsconfig*.json variant exists.
    if ls tsconfig*.json >/dev/null 2>&1; then
      case "$pm" in
        pnpm) typecheck_cmd="pnpm exec tsc --noEmit" ;;
        yarn) typecheck_cmd="yarn exec tsc --noEmit" ;;
        bun)  typecheck_cmd="bunx tsc --noEmit" ;;
        *)    typecheck_cmd="npx tsc --noEmit" ;;
      esac
    fi
  fi

  if [ -z "$typecheck_cmd" ]; then
    echo "[typescript-verify]${prefix} SKIP: no tsconfig.json and no typecheck script found -- nothing to verify"
    skipped_no_command=$((skipped_no_command + 1))
  else
    echo "[typescript-verify]${prefix} running typecheck: ${typecheck_cmd}"
    if eval "$typecheck_cmd"; then
      echo "[typescript-verify]${prefix} typecheck finding: ran_pass (${typecheck_cmd})"
      ran_pass=$((ran_pass + 1))
    else
      echo "[typescript-verify]${prefix} typecheck finding: ran_fail (${typecheck_cmd})"
      ran_fail=$((ran_fail + 1))
    fi
  fi

  # ── Test sub-check ─────────────────────────────────────────────────────────────────────────
  local test_cmd npm_placeholder
  test_cmd="$(echo "$scripts_json" | jq -r '.test // empty')"
  npm_placeholder='Error: no test specified'
  if [ -z "$test_cmd" ] || [[ "$test_cmd" == *"$npm_placeholder"* ]]; then
    echo "[typescript-verify]${prefix} SKIP: no test script configured -- test verification not attempted"
    skipped_no_command=$((skipped_no_command + 1))
  else
    echo "[typescript-verify]${prefix} running test: ${pm} run test"
    if "$pm" run test; then
      echo "[typescript-verify]${prefix} test finding: ran_pass (${pm} run test)"
      ran_pass=$((ran_pass + 1))
    else
      echo "[typescript-verify]${prefix} test finding: ran_fail (${pm} run test)"
      ran_fail=$((ran_fail + 1))
    fi
  fi

  cd "$orig_pwd"
  return 0
}

if [ -f "package.json" ]; then
  # ── Tier 1: fast path, no find invoked, output byte-identical to single-root behavior ──────
  verify_project "." ""
else
  # ── Tier 2: bounded, vendor-excluded fallback search below cwd ─────────────────────────────
  found_count=0
  verified_count=0
  cap=10
  while IFS= read -r pkg_path; do
    found_count=$((found_count + 1))
    if [ "$verified_count" -ge "$cap" ]; then
      continue
    fi
    dir="$(dirname "$pkg_path")"
    relpath="${dir#./}"
    verify_project "$dir" "[${relpath}]"
    verified_count=$((verified_count + 1))
  done < <(find . -maxdepth 4 -name package.json \
             -not -path '*/node_modules/*' -not -path '*/.git/*' -not -path '*/dist/*' \
             -not -path '*/build/*' -not -path '*/.next/*' -not -path '*/out/*' \
             -not -path '*/vendor/*' -not -path '*/.venv/*' | sort)

  if [ "$found_count" -eq 0 ]; then
    echo "[typescript-verify] SKIP: no package.json found -- no Node/TypeScript project in scope, nothing to verify"
    skipped_no_command=$((skipped_no_command + 1))
  elif [ "$found_count" -gt "$cap" ]; then
    echo "[typescript-verify] NOTICE: found ${found_count} candidate projects below cwd, verified only the first ${cap} (cap=${cap}) -- this run is INCOMPLETE, the remaining $((found_count - cap)) project(s) were NOT verified" >&2
  fi
fi

echo "[typescript-verify] summary: ran_pass=${ran_pass} ran_fail=${ran_fail} skipped_no_command=${skipped_no_command}"
exit 0
