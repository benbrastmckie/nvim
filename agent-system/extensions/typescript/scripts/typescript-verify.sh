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
# hook: a missing jq interpreter, an unparseable package.json), never for a finding about the
# target project. The lifecycle-hook contract is unconditionally non-blocking (no opt-in
# blocking mode), so this script's STDOUT text is the only channel that carries the
# pass/fail/skip finding anywhere -- this is why every skip path below prints an explicit
# "SKIP: <reason>" and never a word a reader could mistake for a success finding.

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

# ── Package manager detection, by lockfile priority ─────────────────────────────────────────
pm=""
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
  echo "[typescript-verify] SKIP: no package.json found -- no Node/TypeScript project in scope, nothing to verify"
  skipped_no_command=$((skipped_no_command + 1))
  echo "[typescript-verify] summary: ran_pass=${ran_pass} ran_fail=${ran_fail} skipped_no_command=${skipped_no_command}"
  exit 0
fi

# package.json exists if $pm is set -- confirm it actually parses before trusting it further.
# A genuinely malformed package.json is a hook-input problem, not a project finding, so this is
# the one case besides a missing jq that exits non-zero.
if ! jq -e . package.json >/dev/null 2>&1; then
  echo "[typescript-verify] ERROR: package.json exists but is not valid JSON -- this hook cannot run" >&2
  exit 1
fi

# ── Typecheck sub-check ──────────────────────────────────────────────────────────────────────
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
  echo "[typescript-verify] SKIP: no tsconfig.json and no typecheck script found -- nothing to verify"
  skipped_no_command=$((skipped_no_command + 1))
else
  echo "[typescript-verify] running typecheck: ${typecheck_cmd}"
  if eval "$typecheck_cmd"; then
    echo "[typescript-verify] typecheck finding: ran_pass (${typecheck_cmd})"
    ran_pass=$((ran_pass + 1))
  else
    echo "[typescript-verify] typecheck finding: ran_fail (${typecheck_cmd})"
    ran_fail=$((ran_fail + 1))
  fi
fi

# ── Test sub-check ───────────────────────────────────────────────────────────────────────────
test_cmd="$(echo "$scripts_json" | jq -r '.test // empty')"
npm_placeholder='Error: no test specified'
if [ -z "$test_cmd" ] || [[ "$test_cmd" == *"$npm_placeholder"* ]]; then
  echo "[typescript-verify] SKIP: no test script configured -- test verification not attempted"
  skipped_no_command=$((skipped_no_command + 1))
else
  echo "[typescript-verify] running test: ${pm} run test"
  if "$pm" run test; then
    echo "[typescript-verify] test finding: ran_pass (${pm} run test)"
    ran_pass=$((ran_pass + 1))
  else
    echo "[typescript-verify] test finding: ran_fail (${pm} run test)"
    ran_fail=$((ran_fail + 1))
  fi
fi

echo "[typescript-verify] summary: ran_pass=${ran_pass} ran_fail=${ran_fail} skipped_no_command=${skipped_no_command}"
exit 0
