#!/usr/bin/env bash
# runtime-file-patterns.sh - Single source of truth for the "ephemeral orchestrator runtime
# state" file class: which small scratch files/directories under specs/ are gitignored and
# untracked, as distinct from the durable-provenance files (.orchestrator-handoff.json, the
# bare .return-meta.json) that MUST stay tracked and are deliberately NOT part of this class.
#
# Exports one canonical record per class member (20 total) consumed by BOTH mechanical
# consumers: the repo-wide lint (scripts/check-runtime-file-tracking.sh, Checks A and B) and the
# two deploy-harness test fixtures that seed a scratch repo's .gitignore
# (scripts/tests/test-deploy-orphans.sh, scripts/tests/test-deploy-propagation.sh). Neither
# consumer defines its own probe list, tracked-file regex list, or gitignore pattern list --
# this is the ONLY place any of them is defined. Modeled directly on the precedent already
# established in this repo for a lint/hook pattern pair: scripts/lib/task-reference-patterns.sh.
#
# The markdown policy document (context/standards/orchestrator-runtime-files.md's "Consumer
# Repo Setup" fenced block) cannot `source` a bash lib, so it is instead PINNED to this lib by a
# machine assertion in scripts/tests/test-runtime-file-tracking.sh (Case 3): that test extracts
# the fenced block from the markdown file and asserts it is byte-identical to this file's
# runtime_ignore_block() output. Editing the block in the markdown without updating this lib (or
# vice versa) fails that test. See that standards file's "Single source of truth" subsection for
# the full decision record.
#
# Usage: `source` this file, then read the parallel arrays directly (all indexed in lockstep by
# RUNTIME_FILE_IDS -- index i's id, pattern, probe, regex, and dir flag/basename all describe the
# SAME class member) or call the three accessor functions below.

# ─── Canonical class membership (18 members) ───────────────────────────────────────────────────
# One entry per array, per member, in the exact order the "Consumer Repo Setup" gitignore block
# emits them: the 11 members already covered before this lib existed, then `.dispatch/` (already
# gitignored and already probed by the pre-existing Check A, but missing from the pre-existing
# Check B list and the standards block -- a live divergence this lib closes), then the four
# further gaps found by this task's sweep (`.deploy-lock/`, `.scope-lock/`, `.commit-lock/`,
# `.errors.lock`), then `tmp` (specs/init-consumer-specs task): the TTS/lifecycle notify hooks'
# log directory, and also where state-write.sh stages its own mktemp write-ahead files. Then
# `deploy-ledger` (the durable redeploy ledger task, `lib/deploy-ledger-lib.sh`'s
# `deploy_ledger_path` default `specs/.orchestrator-deploy-ledger.json`): unlike every other
# member here, this one is DURABLE, MACHINE-LOCAL cross-invocation state, not per-cycle scratch
# -- it is gitignored not because it is disposable, but because it describes THIS machine's own
# `.claude/` deploy state and would mislead on another clone; every read is hash-gated so a
# stale or git-restored copy can only ever cause an extra redeploy, never a wrong skip. See
# context/standards/orchestrator-runtime-files.md's Class Table for the full disposition note.
# Do not reorder without also re-checking runtime_ignore_block() callers that assume this is the
# documented block's order.
#
# `tmp` is deliberately ROOT-SCOPED (`/specs/tmp/`), not the `**/`-prefixed form every other
# member uses: its only writers (`hooks/tts-notify.sh`, `scripts/lifecycle-notify.sh`, and
# `scripts/state-write.sh`'s own staging/spill files) always write to the `specs/` top level,
# never to a per-task directory, so a `**/tmp/` pattern would be strictly wider than needed and
# would silently swallow a legitimate per-task `tmp/` some consumer repo might create for its
# own purposes. This repo's own root `.gitignore` already carries the root-relative `/specs/tmp`
# form as precedent.
#
# `decisions-lock` (20th member) is the lock file for `scripts/orchestrate-record-decision.sh`,
# the sanctioned writer for `specs/{NNN}_{slug}/.decisions.json`. Declared as a dedicated
# `**/.decisions.lock` file-class member -- mirroring `.errors.lock` exactly, never placed inside
# the task's existing `.lock/` directory, whose `rmdir`-based mutex release would fail permanently
# if a stray file were left inside it.
#
# `orchestration` (19th member, added by the specs/-root relocation task) is a DIRECTORY-class
# member covering `specs/.orchestration/` — the relocation target for the two repo-level
# session-scoped singletons (`.orchestrator-multi-state-{session_id}.json`,
# `.return-meta-multi-{session_id}.json`) that used to sit directly at the `specs/` root. Its
# `**/.orchestration/` pattern is additive alongside (never a replacement for) the pre-existing
# `orchestrator-multi-state`/`return-meta-suffixed` file-class patterns above, which already
# match at any depth via their own `**/` prefix and therefore already cover files inside the new
# directory without modification. The directory-class pattern exists so `specs/.orchestration/`
# itself is never reported as an untracked directory in `git status`, mirroring the
# `.sessions/`/`.dispatch/`/`.deploy-lock/` precedent above.

declare -a RUNTIME_FILE_IDS=(
  "lock"
  "orchestrator-loop-guard"
  "continuation-loop-guard"
  "orchestrator-churn-state"
  "postflight-loop-guard"
  "orchestrator-multi-state"
  "drift-inspection"
  "return-meta-suffixed"
  "events-lock"
  "sessions"
  "freshness-warn-streak"
  "dispatch"
  "deploy-lock"
  "scope-lock"
  "commit-lock"
  "errors-lock"
  "decisions-lock"
  "tmp"
  "deploy-ledger"
  "orchestration"
)

# Exact gitignore pattern line for each member, as emitted by runtime_ignore_block().
declare -a RUNTIME_FILE_PATTERNS=(
  "**/.lock/"
  "**/.orchestrator-loop-guard"
  "**/.continuation-loop-guard"
  "**/.orchestrator-churn-state.json"
  "**/.postflight-loop-guard"
  "**/.orchestrator-multi-state*.json"
  "**/.drift-inspection.json"
  "**/.return-meta-*.json"
  "**/.events.lock"
  "**/.sessions/"
  "**/.freshness-warn-streak.json"
  "**/.dispatch/"
  "**/.deploy-lock/"
  "**/.scope-lock/"
  "**/.commit-lock/"
  "**/.errors.lock"
  "**/.decisions.lock"
  "/specs/tmp/"
  "**/.orchestrator-deploy-ledger.json"
  "**/.orchestration/"
)

# Check A representative probe path: a concrete file this pattern must `git check-ignore -q`.
# Directory-class members are probed with a file inside the directory, since a gitignore
# pattern for a directory only matches paths under it, not the bare directory name in isolation.
declare -a RUNTIME_FILE_PROBES=(
  "specs/000_probe/.lock/holder.json"
  "specs/000_probe/.orchestrator-loop-guard"
  "specs/000_probe/.continuation-loop-guard"
  "specs/000_probe/.orchestrator-churn-state.json"
  "specs/000_probe/.postflight-loop-guard"
  "specs/.orchestration/.orchestrator-multi-state-sess_0000000000_probe.json"
  "specs/000_probe/.drift-inspection.json"
  "specs/000_probe/.return-meta-orchestrate.json"
  "specs/.events.lock"
  "specs/.sessions/sess_0000000000_probe.json"
  "specs/.freshness-warn-streak.json"
  "specs/000_probe/.dispatch/1.md"
  "specs/.deploy-lock/owner"
  "specs/.scope-lock/owner"
  "specs/.commit-lock/owner"
  "specs/.errors.lock"
  "specs/000_probe/.decisions.lock"
  "specs/tmp/claude-tts-notify.log"
  "specs/.orchestrator-deploy-ledger.json"
  "specs/.orchestration/.orchestrator-multi-state-sess_0000000000_probe.json"
)

# Check B tracked-file regex: `grep -E` pattern matched against `git ls-files` output. Any hit
# means an ephemeral-class file is tracked and must be untracked (never deleted).
declare -a RUNTIME_FILE_B_REGEX=(
  '/\.lock/'
  '\.orchestrator-loop-guard$'
  '\.continuation-loop-guard$'
  '\.orchestrator-churn-state\.json$'
  '\.postflight-loop-guard$'
  '\.orchestrator-multi-state(-[^/]+)?\.json$'
  '\.drift-inspection\.json$'
  '\.return-meta-[^/]*\.json$'
  '\.events\.lock$'
  '/\.sessions/[^/]+\.json$'
  '\.freshness-warn-streak\.json$'
  '/\.dispatch/'
  '/\.deploy-lock/'
  '/\.scope-lock/'
  '/\.commit-lock/'
  '\.errors\.lock$'
  '\.decisions\.lock$'
  '^specs/tmp/'
  '\.orchestrator-deploy-ledger\.json$'
  '/\.orchestration/'
)

# Directory-class flag ("1" or "0"): governs which `git rm` remediation form Check B prints for
# a hit at this index. A "1" member's bare directory basename is given in
# RUNTIME_FILE_DIR_BASENAME at the same index (empty string for "0" members, where it is unused).
declare -a RUNTIME_FILE_IS_DIR=(
  "1" "0" "0" "0" "0" "0" "0" "0" "0" "1" "0" "1" "1" "1" "1" "0" "0" "1" "0" "1"
)
declare -a RUNTIME_FILE_DIR_BASENAME=(
  ".lock" "" "" "" "" "" "" "" "" ".sessions" "" ".dispatch" ".deploy-lock" ".scope-lock" ".commit-lock" "" "" "tmp" "" ".orchestration"
)

# ─── Accessors ──────────────────────────────────────────────────────────────────────────────────

# runtime_ignore_block
# Emits the exact fenced gitignore body (comment header + all 20 patterns, in the order above)
# that context/standards/orchestrator-runtime-files.md's "Consumer Repo Setup" block and both
# deploy-harness test fixtures (test-deploy-orphans.sh, test-deploy-propagation.sh) must carry
# verbatim. Callers write this to a `.gitignore` file or embed it in a fenced markdown block --
# never hand-copy it; a hand-copy is exactly the drift this lib exists to prevent.
runtime_ignore_block() {
  cat <<'BLOCK_EOF'
# Ephemeral orchestrator runtime state: per-dispatch scratch, mutex directories, and loop
# guards. Ignored because these have no freshness gate on read — a git-restored copy would
# silently corrupt in-flight cycle/churn state. See
# agent-system/extensions/core/context/standards/orchestrator-runtime-files.md for the full
# two-class policy and rationale. Deliberately does NOT include .orchestrator-handoff.json or
# .return-meta.json — those are durable, freshness-gated provenance and MUST stay tracked.
# Canonical source: agent-system/extensions/core/scripts/lib/runtime-file-patterns.sh
# (runtime_ignore_block()) -- this block is generated from that lib and pinned to it by
# tests/test-runtime-file-tracking.sh Case 3; do not hand-edit the pattern list here.
**/.lock/
**/.orchestrator-loop-guard
**/.continuation-loop-guard
**/.orchestrator-churn-state.json
**/.postflight-loop-guard
**/.orchestrator-multi-state*.json
**/.drift-inspection.json
**/.return-meta-*.json
**/.events.lock
**/.sessions/
**/.freshness-warn-streak.json
**/.dispatch/
**/.deploy-lock/
**/.scope-lock/
**/.commit-lock/
**/.errors.lock
**/.decisions.lock
/specs/tmp/
**/.orchestrator-deploy-ledger.json
**/.orchestration/
BLOCK_EOF
}

# runtime_specs_ignore_block
# Emits the same 20-member class as runtime_ignore_block() above, but with every pattern
# rewritten relative to `specs/` instead of the repo root, for a `specs/.gitignore` file (whose
# patterns are matched relative to the directory the .gitignore file lives in, not the repo
# root). MECHANICALLY DERIVED from RUNTIME_FILE_PATTERNS -- never a second hand-written literal
# list. The `**/`-prefixed members pass through unchanged (a `**/` pattern matches at any depth
# regardless of which directory its .gitignore lives in); the one root-scoped member
# (`/specs/tmp/`) has its leading `specs/` path segment dropped, becoming `/tmp/`. Canonical
# writer: scripts/init-specs.sh, which writes this block into a managed section of
# `specs/.gitignore`.
runtime_specs_ignore_block() {
  cat <<'HEADER_EOF'
# Ephemeral orchestrator runtime state: per-dispatch scratch, mutex directories, and loop
# guards. Ignored because these have no freshness gate on read — a git-restored copy would
# silently corrupt in-flight cycle/churn state. See
# agent-system/extensions/core/context/standards/orchestrator-runtime-files.md for the full
# two-class policy and rationale. Deliberately does NOT include .orchestrator-handoff.json or
# .return-meta.json — those are durable, freshness-gated provenance and MUST stay tracked.
# Canonical source: agent-system/extensions/core/scripts/lib/runtime-file-patterns.sh
# (runtime_specs_ignore_block()) -- this block is generated by scripts/init-specs.sh from that
# lib; do not hand-edit the pattern list here.
HEADER_EOF
  local pattern
  for pattern in "${RUNTIME_FILE_PATTERNS[@]}"; do
    case "$pattern" in
      /specs/*)
        echo "/${pattern#/specs/}"
        ;;
      *)
        echo "$pattern"
        ;;
    esac
  done
}

# runtime_file_dir_basename_for_hit <tracked-file-path>
# Prints (on stdout) the directory-class basename (e.g. ".lock") whose pattern matches the given
# tracked-file hit, and returns 0. Returns 1 and prints nothing if the hit belongs to a
# file-class member (or no member at all). Used by check-runtime-file-tracking.sh's Check B to
# print the correct `git rm -r --cached <dir>` remediation for ANY directory-class member, not
# just `.lock/` (the pre-existing, narrower hardcoded form this generalizes).
runtime_file_dir_basename_for_hit() {
  local hit="$1"
  local i basename
  for i in "${!RUNTIME_FILE_IDS[@]}"; do
    if [ "${RUNTIME_FILE_IS_DIR[$i]}" = "1" ]; then
      basename="${RUNTIME_FILE_DIR_BASENAME[$i]}"
      case "$hit" in
        */"$basename"/*)
          echo "$basename"
          return 0
          ;;
      esac
    fi
  done
  return 1
}

# runtime_mt_state_path <specs_dir> <session_id>
# Single shared resolver for the session-scoped multi-task batch-orchestration state file's
# path, so a future rename of its location touches this one site rather than every writer/reader
# independently re-deriving the same string. `<specs_dir>` is the caller's own resolved `specs/`
# directory (e.g. `"$(dirname "$STATE_FILE")"` or a literal `specs`); the file lives under
# `<specs_dir>/.orchestration/`, created on demand by the caller before first write — this
# function only computes the path, it never creates the directory itself.
runtime_mt_state_path() {
  local specs_dir="$1" session_id="$2"
  echo "${specs_dir}/.orchestration/.orchestrator-multi-state-${session_id}.json"
}

# runtime_return_meta_multi_path <specs_dir> <session_id>
# Sibling resolver for the session-scoped multi-task batch return-metadata file's path. Same
# contract as runtime_mt_state_path() above: caller supplies its own resolved `specs/` directory
# and ensures `.orchestration/` exists before writing; this function only computes the path.
runtime_return_meta_multi_path() {
  local specs_dir="$1" session_id="$2"
  echo "${specs_dir}/.orchestration/.return-meta-multi-${session_id}.json"
}
