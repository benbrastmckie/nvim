#!/usr/bin/env bash
# init-specs.sh - Idempotent bootstrap for a consumer repo's specs/ task-management state.
#
# A repo that has never run the task system has neither specs/ state (specs/state.json,
# specs/archive/state.json, specs/TODO.md) nor any gitignore coverage for the system's own
# runtime scratch files (see context/standards/orchestrator-runtime-files.md). This script closes
# both gaps in one idempotent pass:
#
#   1. Creates specs/ and specs/archive/ if absent.
#   2. Creates specs/state.json if absent: a schema-valid, empty state store
#      ({"next_project_number": 1, "active_projects": [], "active_topics": []}), written
#      DIRECTLY via mktemp + atomic mv -- never through state-write.sh, whose --init mode
#      unconditionally refuses the default live state path by design (a safety guard against a
#      filter typo destroying live task state; see state-write.sh's own header).
#   3. Creates specs/archive/state.json if absent: the minimal live shape
#      ({"archived_projects": [], "completed_projects": []}), same direct mktemp + mv idiom (a
#      non-default target that state-write.sh --init COULD reach, but the existence guard stays
#      here either way, so the direct write keeps both state files on one code path).
#   4. Creates specs/TODO.md if absent, by calling generate-todo.sh rather than hand-writing the
#      format.
#   5. Writes or refreshes specs/.gitignore's MANAGED BLOCK (sentinel-delimited) from
#      scripts/lib/runtime-file-patterns.sh's runtime_specs_ignore_block(), so the ephemeral
#      runtime-file class is always ignored relative to specs/ -- never the consumer's own
#      repo-root .gitignore (writing or modifying that file is explicitly out of scope; see
#      context/standards/orchestrator-runtime-files.md's "Consumer Repo Setup" for why a
#      specs/-relative file can be delivered directly where a repo-root one cannot). Content
#      outside the sentinels is preserved byte-for-byte, so a consumer's own hand-added ignore
#      lines survive a refresh.
#   6. Untracks (git rm --cached / git rm -r --cached, NEVER plain rm) any already-tracked file
#      under specs/ matching the ephemeral runtime-file class, leaving the change staged for the
#      caller's own scoped commit. Never touches .orchestrator-handoff.json or bare
#      .return-meta.json -- those are durable provenance and MUST stay tracked (belt-and-braces
#      skip in addition to the class regex already excluding them by construction).
#
# Non-destructive by construction: steps 2-5 each check existence/sentinel-presence before
# writing, and NEVER overwrite anything that already exists (specs/.gitignore's managed block is
# the one exception to "never touch an existing file", and even there only the sentinel-delimited
# region is rewritten -- everything outside it is preserved verbatim). Step 6 only ever stages
# `git rm --cached` deletions; it never deletes a working-tree copy and never commits.
#
# Idempotent: a second run against an already-bootstrapped repo makes no filesystem changes and
# stages no further git changes.
#
# Usage:
#   init-specs.sh [--help]
#
# Exit codes:
#   0 - success (including the true no-op case: everything already present, nothing to do)
#   1 - a write step failed (e.g. mktemp/mv failure)
#
# Called from every command/skill/agent that can be the first thing to touch specs/ in a fresh
# consumer repo (see context/standards/orchestrator-runtime-files.md's "Consumer Repo Setup" for
# the full call-site list and the deploy/gate-in decision record). Never called from deploy.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
  sed -n '2,/^set -euo pipefail/p' "${BASH_SOURCE[0]}" | sed '$d' | sed 's/^# \{0,1\}//'
  exit 0
fi

# --- Shared runtime-file-patterns library ---
# Deploy-tree-first / source-store-fallback resolution relative to THIS script's own directory,
# matching check-runtime-file-tracking.sh's own lookup -- both trees keep the lib at the same
# "./lib/runtime-file-patterns.sh" relative position.
RUNTIME_LIB="${SCRIPT_DIR}/lib/runtime-file-patterns.sh"
if [[ ! -f "$RUNTIME_LIB" ]]; then
  echo "ERROR: shared library lib/runtime-file-patterns.sh not found at: $RUNTIME_LIB" >&2
  exit 1
fi
# shellcheck disable=SC1090
. "$RUNTIME_LIB"

GITIGNORE_BEGIN="# BEGIN managed block: runtime-file-patterns.sh"
GITIGNORE_END="# END managed block: runtime-file-patterns.sh"

# atomic_write <target-path> <content-on-stdin>
# mktemp in the SAME directory as the target (so the final `mv` is a same-filesystem rename, not
# a cross-filesystem copy) + atomic mv. Never writes the target path directly.
atomic_write() {
  local target="$1" dir tmp
  dir="$(dirname "$target")"
  tmp="$(mktemp "${dir}/.init-specs.XXXXXX")" || {
    echo "ERROR: failed to create a private staging file under $dir" >&2
    return 1
  }
  cat > "$tmp"
  mv "$tmp" "$target"
}

echo "init-specs: bootstrapping specs/ task-management state"
echo "========================================================"

# ── Step 1: directories ────────────────────────────────────────────────────
mkdir -p specs specs/archive
echo "OK   specs/, specs/archive/ present"

# ── Step 2: specs/state.json ───────────────────────────────────────────────
if [[ -f specs/state.json ]]; then
  echo "SKIP specs/state.json already exists"
else
  printf '{\n  "next_project_number": 1,\n  "active_projects": [],\n  "active_topics": []\n}\n' \
    | atomic_write specs/state.json
  echo "CREATED specs/state.json"
fi

# ── Step 3: specs/archive/state.json ───────────────────────────────────────
if [[ -f specs/archive/state.json ]]; then
  echo "SKIP specs/archive/state.json already exists"
else
  printf '{\n  "archived_projects": [],\n  "completed_projects": []\n}\n' \
    | atomic_write specs/archive/state.json
  echo "CREATED specs/archive/state.json"
fi

# ── Step 4: specs/TODO.md ──────────────────────────────────────────────────
if [[ -f specs/TODO.md ]]; then
  echo "SKIP specs/TODO.md already exists"
else
  TODO_GENERATOR="${SCRIPT_DIR}/generate-todo.sh"
  if [[ -f "$TODO_GENERATOR" ]]; then
    bash "$TODO_GENERATOR"
    echo "CREATED specs/TODO.md (via generate-todo.sh)"
  else
    echo "WARN specs/TODO.md not created: generate-todo.sh not found at $TODO_GENERATOR" >&2
  fi
fi

# ── Step 5: specs/.gitignore managed block ─────────────────────────────────
GITIGNORE_TARGET="specs/.gitignore"
NEW_BLOCK="$(runtime_specs_ignore_block)"
if [[ ! -f "$GITIGNORE_TARGET" ]]; then
  { echo "$GITIGNORE_BEGIN"; echo "$NEW_BLOCK"; echo "$GITIGNORE_END"; } | atomic_write "$GITIGNORE_TARGET"
  echo "CREATED specs/.gitignore (managed block)"
elif grep -qF "$GITIGNORE_BEGIN" "$GITIGNORE_TARGET" && grep -qF "$GITIGNORE_END" "$GITIGNORE_TARGET"; then
  # Replace only the region between the sentinels; preserve everything outside byte-for-byte.
  existing_region="$(awk -v b="$GITIGNORE_BEGIN" -v e="$GITIGNORE_END" '
    $0==b {flag=1; next}
    $0==e {flag=0; next}
    flag {print}
  ' "$GITIGNORE_TARGET")"
  if [[ "$existing_region" == "$NEW_BLOCK" ]]; then
    echo "SKIP specs/.gitignore managed block already current"
  else
    awk -v b="$GITIGNORE_BEGIN" -v e="$GITIGNORE_END" -v newblock="$NEW_BLOCK" '
      $0==b {print; print newblock; flag=1; next}
      $0==e {print; flag=0; next}
      flag {next}
      {print}
    ' "$GITIGNORE_TARGET" | atomic_write "$GITIGNORE_TARGET"
    echo "REFRESHED specs/.gitignore managed block"
  fi
else
  # No sentinels present: append the managed block, preserving all existing content verbatim.
  { cat "$GITIGNORE_TARGET"; echo ""; echo "$GITIGNORE_BEGIN"; echo "$NEW_BLOCK"; echo "$GITIGNORE_END"; } \
    | atomic_write "$GITIGNORE_TARGET"
  echo "APPENDED managed block to existing specs/.gitignore"
fi


# ── Step 6: untrack already-tracked runtime-class files ────────────────────
# Finds any file under specs/ that git already tracks and that matches the ephemeral
# runtime-file class (RUNTIME_FILE_B_REGEX, the same regex list check-runtime-file-tracking.sh's
# Check B scans with), and untracks it with `git rm --cached` / `git rm -r --cached` -- NEVER a
# plain `rm`, and NEVER deleting the working-tree copy. Only ever STAGES the removal; it is left
# for the caller's own scoped commit, exactly like every other write this script makes. Skips
# gracefully (named notice, no error) when the working directory is not inside a git repository.
if ! git rev-parse --is-inside-work-tree > /dev/null 2>&1; then
  echo "SKIP untrack sweep: not inside a git repository"
else
  untracked_any=0
  tracked_files="$(git ls-files -- specs/ 2> /dev/null || true)"
  for pattern in "${RUNTIME_FILE_B_REGEX[@]}"; do
    hits="$(printf '%s\n' "$tracked_files" | grep -E "$pattern" || true)"
    [[ -z "$hits" ]] && continue
    while IFS= read -r hit; do
      [[ -z "$hit" ]] && continue
      hit_base="$(basename "$hit")"
      # Belt-and-braces skip: durable provenance must never be untracked. Neither name can
      # actually match any RUNTIME_FILE_B_REGEX entry by construction (see the class definitions
      # in lib/runtime-file-patterns.sh), but this guard stays as a second, independent check.
      if [[ "$hit_base" == ".orchestrator-handoff.json" || "$hit_base" == ".return-meta.json" ]]; then
        continue
      fi
      dir_basename="$(runtime_file_dir_basename_for_hit "$hit" || true)"
      if [[ -n "$dir_basename" ]]; then
        dir_path="${hit%/"$dir_basename"/*}/${dir_basename}"
        if git rm -r --cached "$dir_path" > /dev/null 2>&1; then
          if [[ ! -d "$dir_path" ]]; then
            echo "ERROR: $dir_path vanished from disk after git rm -r --cached -- must never happen" >&2
            exit 1
          fi
          echo "UNTRACKED (dir) $dir_path"
          untracked_any=1
        fi
      else
        if git rm --cached "$hit" > /dev/null 2>&1; then
          if [[ ! -e "$hit" ]]; then
            echo "ERROR: $hit vanished from disk after git rm --cached -- must never happen" >&2
            exit 1
          fi
          echo "UNTRACKED $hit"
          untracked_any=1
        fi
      fi
    done <<< "$hits"
  done
  if [[ "$untracked_any" -eq 1 ]]; then
    echo "NOTE: the untrack(s) above are staged (index only, working-tree copies untouched)."
    echo "      init-specs.sh never commits -- fold this into your own scoped commit."
  else
    echo "SKIP untrack sweep: no already-tracked runtime-class file found under specs/"
  fi
fi

echo ""
echo "init-specs: bootstrap complete"
