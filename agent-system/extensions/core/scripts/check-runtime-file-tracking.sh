#!/usr/bin/env bash
# check-runtime-file-tracking.sh - Verify a repo's git-tracking of orchestrator runtime files
# matches the policy in context/standards/orchestrator-runtime-files.md.
#
# Runs three checks from the repo root of any consumer repo:
#   A - Ignore coverage: every ephemeral-class pattern actually ignores a representative path
#       (tested via `git check-ignore -q`, not by grepping .gitignore text, so inherited or
#       differently-worded patterns are still detected).
#   B - Tracked ephemeral files: no file of an ephemeral class is currently tracked by git. Any
#       hit prints the exact `git rm --cached` (or `git rm -r --cached`) remediation command and
#       notes that the file stays on disk.
#   C - Provenance not over-ignored: `.orchestrator-handoff.json` and `.return-meta.json` are
#       NOT ignored. A repo that ignores them fails this check with the offending .gitignore
#       line named via `git check-ignore -v`.
#
# Checks A and B both derive their probe/pattern lists from scripts/lib/runtime-file-patterns.sh
# -- the single canonical definition of the ephemeral-class membership, also consumed by
# tests/test-deploy-orphans.sh and tests/test-deploy-propagation.sh (their scratch-repo
# `.gitignore` seeding) and pinned to context/standards/orchestrator-runtime-files.md's "Consumer
# Repo Setup" block by tests/test-runtime-file-tracking.sh Case 3. Do not hand-add a class member
# to either list below -- add it to the lib instead, in exactly one place.
#
# Exit code: 0 if all checks pass, 1 if any check fails.
#
# Usage: bash agent-system/extensions/core/scripts/check-runtime-file-tracking.sh
#        (or the deployed copy: bash .claude/scripts/check-runtime-file-tracking.sh)

set -uo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

FAILURES=0
PROBE_DIR="specs/000_probe"

# --- Shared runtime-file-patterns library ---
# Deploy-tree-first / source-store-fallback resolution relative to THIS script's own directory,
# so the same lookup works whether this file is run from the source store
# (agent-system/extensions/core/scripts/) or the deployed, flattened tree (.claude/scripts/) --
# both trees keep the lib at the same "./lib/runtime-file-patterns.sh" relative position.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RUNTIME_LIB="${SCRIPT_DIR}/lib/runtime-file-patterns.sh"
if [[ ! -f "$RUNTIME_LIB" ]]; then
  echo "ERROR: shared library lib/runtime-file-patterns.sh not found at: $RUNTIME_LIB" >&2
  exit 5
fi
# shellcheck disable=SC1090
. "$RUNTIME_LIB"

# Ephemeral-class representative paths (Check A), derived from the lib. Directory classes
# (.lock/, .dispatch/, .deploy-lock/, .scope-lock/, .commit-lock/, .sessions/) are probed with a
# file inside them, since a git-ignore pattern for a directory only matches paths under it.
declare -a EPHEMERAL_PROBES=("${RUNTIME_FILE_PROBES[@]}")

# Durable-provenance paths (Check C) — MUST NOT be ignored. Not part of the ephemeral-class lib
# (they are the opposite disposition), so these stay locally defined.
declare -a DURABLE_PROBES=(
  "${PROBE_DIR}/.orchestrator-handoff.json"
  "${PROBE_DIR}/.return-meta.json"
)

echo "check-runtime-file-tracking: verifying against context/standards/orchestrator-runtime-files.md"
echo "================================================================================"

# ── Check A: ignore coverage ──────────────────────────────────────────────────
echo ""
echo "Check A - ephemeral-class ignore coverage:"
a_failed=0
for probe in "${EPHEMERAL_PROBES[@]}"; do
  if git check-ignore -q "$probe" 2>/dev/null; then
    echo -e "  ${GREEN}OK${NC}   $probe is ignored"
  else
    echo -e "  ${RED}FAIL${NC} $probe is NOT ignored (ephemeral class must be gitignored)"
    a_failed=1
  fi
done
if [ "$a_failed" -eq 1 ]; then
  FAILURES=1
  echo -e "${RED}Check A FAILED${NC} — run \`bash .claude/scripts/init-specs.sh\` to (re)write"
  echo "  specs/.gitignore's managed block, or add the missing pattern(s) to the repo root"
  echo "  .gitignore by hand. See context/standards/orchestrator-runtime-files.md 'Consumer Repo"
  echo "  Setup' for the exact block either way."
else
  echo -e "${GREEN}Check A passed${NC}"
fi

# ── Check B: tracked ephemeral files ──────────────────────────────────────────
echo ""
echo "Check B - no ephemeral-class file is currently tracked:"
b_failed=0
b_patterns=("${RUNTIME_FILE_B_REGEX[@]}")
tracked_files=$(git ls-files 2>/dev/null)
for pattern in "${b_patterns[@]}"; do
  hits=$(echo "$tracked_files" | grep -E "$pattern" || true)
  if [ -n "$hits" ]; then
    b_failed=1
    while IFS= read -r hit; do
      [ -z "$hit" ] && continue
      echo -e "  ${RED}FAIL${NC} tracked ephemeral file: $hit"
      dir_basename="$(runtime_file_dir_basename_for_hit "$hit" || true)"
      if [ -n "$dir_basename" ]; then
        dir_path="${hit%/"$dir_basename"/*}/${dir_basename}"
        echo "        remediation: git rm -r --cached \"$dir_path\"  (file stays on disk)"
      else
        echo "        remediation: git rm --cached \"$hit\"  (file stays on disk)"
      fi
    done <<< "$hits"
  fi
done
if [ "$b_failed" -eq 1 ]; then
  FAILURES=1
  echo -e "${RED}Check B FAILED${NC} — run the remediation command(s) above to untrack without deleting."
else
  echo -e "${GREEN}Check B passed${NC} — no ephemeral-class file is tracked"
fi

# ── Check C: provenance not over-ignored ──────────────────────────────────────
echo ""
echo "Check C - durable provenance (.orchestrator-handoff.json / .return-meta.json) is NOT ignored:"
c_failed=0
for probe in "${DURABLE_PROBES[@]}"; do
  if git check-ignore -q "$probe" 2>/dev/null; then
    c_failed=1
    offending_line=$(git check-ignore -v "$probe" 2>/dev/null)
    echo -e "  ${RED}FAIL${NC} $probe is ignored (must be tracked): $offending_line"
    echo "        remediation: remove the offending .gitignore line. Never run git rm --cached on this file."
  else
    echo -e "  ${GREEN}OK${NC}   $probe is not ignored"
  fi
done
if [ "$c_failed" -eq 1 ]; then
  FAILURES=1
  echo -e "${RED}Check C FAILED${NC} — durable provenance must never be gitignored or untracked."
else
  echo -e "${GREEN}Check C passed${NC}"
fi

# ── Summary ────────────────────────────────────────────────────────────────────
echo ""
echo "================================================================================"
if [ "$FAILURES" -eq 0 ]; then
  echo -e "${GREEN}PASS${NC} — all three checks passed."
  exit 0
else
  echo -e "${RED}FAIL${NC} — one or more checks failed. See context/standards/orchestrator-runtime-files.md."
  exit 1
fi
