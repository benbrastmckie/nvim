#!/usr/bin/env bash
# verify-deploy.sh - Check that a deployed .claude/ tree actually reflects its source store.
#
# This is the first of the two gates that any claim about deployed behavior has to clear. It
# answers "is the deploy tree current and are its hooks registered?" -- it does NOT answer "have
# events actually flowed?", which requires real command invocations over time. Do not report a
# passing run here as end-to-end verification.
#
# Restated precisely for this script's one automated consumer: this script's PASS claims only
# that the deploy tree matches its source store and that hooks are registered. It does NOT claim
# the redeployed machinery has been exercised -- that would require the second gate (real command
# invocations) described above, which this script cannot and does not perform.
#
# Callers: the inter-cycle redeploy checkpoint (`skill-orchestrate` Stage MT-3 step 7) is an
# automated consumer of this script's exit code AND, via --findings below, of its findings set.
# See context/patterns/batch-orchestration-guardrails.md's `### The Inter-Cycle Redeploy
# Checkpoint` subsection for the full contract this script is one half of (the other half being
# scripts/deploy-headless.sh).
#
# The checks are deliberately mechanical and independently reproducible; each prints the command
# it stands for, so a reader can re-run any single line by hand rather than trusting this script.
#
# Usage:
#   verify-deploy.sh [--quiet] [--findings] [--skip-slow] [--minimal-init DIR] [TARGET_REPO]
#
# Minimal-init hatch (--minimal-init DIR, additive-only):
#   Opt-in escape hatch for CI/container environments with no user nvim config: this script's two
#   nvim-backed gates (gate5 verify_all, gate13 find_orphans) run under `nvim --headless --clean
#   --cmd "set rtp+=DIR"` instead of the default plain `nvim --headless` (which loads init.lua and
#   pays the full lazy.nvim plugin bootstrap). DIR is the nvim CONFIG directory, not necessarily
#   $TARGET (they coincide in CI, where the checkout IS the nvim config repo, but differ for a
#   consumer repo) -- always explicit, never derived. Default OFF: absent this flag, both gates'
#   behavior is byte-for-byte unchanged (plain `nvim --headless`, same as before this flag
#   existed). Confirmed safe by a direct probe (manager.load/resync_all/verify_all/find_orphans
#   all succeed under --clean with only rtp set) before this flag was added -- the extension
#   manager has no plugin dependency. See deploy-headless.sh's header for its own matching flag,
#   which this script's flag is designed to be threaded through from.
#
# Exit codes:
#   0  all checks passed
#   1  one or more checks failed
#   2  cannot run (target missing, or no deploy tree to inspect) -- an automated gate MUST treat
#      this the same as exit 1 (failure), never as a pass: a checkpoint that cannot establish the
#      redeploy landed is in the same position as one that established it did not.
#
# Slow-gate selection (--skip-slow):
#   Skips gate 8 (the shell test suite runner, tests/run-all.sh) ONLY. Gate 8 was measured at
#   117.9s of the ~2.8min total run, so --skip-slow drops the inline cost to roughly 50-70s while
#   every other gate still runs. This is purely additive: with --skip-slow absent, default-mode
#   behavior, findings, and exit codes are byte-for-byte unchanged. A skipped gate 8 never
#   increments CHECKS or FAILURES and never contributes a finding line. This is the flag
#   scripts/deploy-headless.sh now passes on its own inline, non-optional invocation of this
#   script -- see context/patterns/regeneration-is-manual-only.md's
#   `### deploy-headless.sh's Inline Verification and Exit Code 3` subsection for the full
#   fast/full split and exit-code contract.
#
# Gate 8 concurrency (VERIFY_DEPLOY_GATE8_JOBS, additive-only):
#   When gate 8 runs (--skip-slow absent), it requests run-all.sh's opt-in --jobs parallelism
#   instead of the sequential default. VERIFY_DEPLOY_GATE8_JOBS defaults to 'auto' (nproc capped
#   at run-all.sh's JOBS_CAP of 4); set it to '1' to force fully sequential Gate 8 on a nproc=1,
#   memory-pressured, or heavily-loaded CI/interactive host -- that override, with no code
#   change, IS the rollback for this feature. An invalid value surfaces through run-all.sh's own
#   exit-2 validation; Gate 8's remedy text names the variable when that happens. run-all.sh's
#   nested-invocation guard (RUN_ALL_NESTED) still forces sequential execution when this script
#   is itself reached from inside another run-all.sh suite, regardless of this setting.
#
# Findings mode (--findings, additive-only):
#   Emits a normalized, one-per-line, machine-diffable findings set across all eighteen gates
#   (gate0 through gate17) plus a gate0 "could not run" sentinel, printed to stdout after the
#   final narrative PASS/FAIL line (including on a passing run, where an empty set is a valid,
#   meaningful result). Every finding line begins with the literal token `FINDING ` followed by a
#   gate label (`gate0`..`gate17`); the automated consumer is expected to invoke
#   `verify-deploy.sh --findings --quiet`, filter with `grep '^FINDING ' | sort -u`, and diff two
#   such captures rather than compare exit codes alone -- see the Checkpoint subsection above for
#   why exit-code-only comparison masks a newly-introduced finding hiding inside an
#   already-failing gate. This mode is purely additive: with --findings absent, default-mode
#   narrative output and exit codes are byte-for-byte unchanged.
#
# Gate selection (--only-gate N[,M,...], additive-only):
#   Runs only the named gate(s) (1-20) instead of the full battery. Absent this flag, GATES_FILTER
#   is empty and every gate runs -- byte-for-byte the same as before this flag existed. A caller
#   that only needs to exercise one gate (e.g. a test suite targeting gate 20) can pay for that one
#   gate instead of all twenty; see context/standards/shell-script-testing.md for the intended
#   test-fast-path use and the standing rule that at least one full-battery invocation must remain
#   somewhere in the suite. gate0 (argument/target validation, before any gate runs) is never
#   filterable -- it always runs. An invalid gate id (non-numeric or outside 1-20) exits 2 and,
#   under --findings, emits a `FINDING gate0` line.

set -uo pipefail

QUIET=false
FINDINGS=false
SKIP_SLOW=false
TARGET=""
MINIMAL_INIT_DIR=""
FINDINGS_LIST=()
# GATES_FILTER: empty = all gates (today's default behavior). Populated by --only-gate below with
# a comma-separated list of gate ids; gate_selected() (defined further down, alongside pass()/
# fail()/warn()) is the single predicate every gate's guard consults.
GATES_FILTER=""

while [ $# -gt 0 ]; do
  case "$1" in
    --quiet) QUIET=true; shift ;;
    --findings) FINDINGS=true; shift ;;
    --skip-slow) SKIP_SLOW=true; shift ;;
    --only-gate)
      if [ $# -lt 2 ] || [ -z "$2" ]; then
        echo "ERROR: --only-gate requires a gate id (or comma-separated ids), e.g. --only-gate 20" >&2
        [ "$FINDINGS" = "true" ] && echo "FINDING gate0 verify-deploy could not run: --only-gate requires a gate id"
        exit 2
      fi
      # Validate every comma-separated token is a plain integer in 1..20 before accepting any of
      # them -- a partially-valid list must refuse loudly, not silently run a subset.
      IFS=',' read -r -a _only_gate_tokens <<< "$2"
      for _only_gate_tok in "${_only_gate_tokens[@]}"; do
        case "$_only_gate_tok" in
          ''|*[!0-9]*)
            echo "ERROR: --only-gate: invalid gate id '$_only_gate_tok' (must be a number 1-20)" >&2
            [ "$FINDINGS" = "true" ] && echo "FINDING gate0 verify-deploy could not run: --only-gate invalid gate id '$_only_gate_tok'"
            exit 2
            ;;
        esac
        if [ "$_only_gate_tok" -lt 1 ] || [ "$_only_gate_tok" -gt 20 ]; then
          echo "ERROR: --only-gate: gate id '$_only_gate_tok' is out of range (must be 1-20)" >&2
          [ "$FINDINGS" = "true" ] && echo "FINDING gate0 verify-deploy could not run: --only-gate gate id '$_only_gate_tok' out of range"
          exit 2
        fi
      done
      unset _only_gate_tok
      GATES_FILTER="$2"; shift 2
      ;;
    --minimal-init)
      if [ $# -lt 2 ] || [ -z "$2" ]; then
        echo "ERROR: --minimal-init requires a DIR argument (the nvim config directory)" >&2
        [ "$FINDINGS" = "true" ] && echo "FINDING gate0 verify-deploy could not run: --minimal-init requires a DIR argument"
        exit 2
      fi
      MINIMAL_INIT_DIR="$2"; shift 2
      ;;
    -h|--help)
      sed -n '2,77p' "$0" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    -*)
      echo "ERROR: unknown flag: $1" >&2
      [ "$FINDINGS" = "true" ] && echo "FINDING gate0 verify-deploy could not run: unknown flag: $1"
      exit 2
      ;;
    *)
      TARGET="$1"; shift ;;
  esac
done

# NVIM_ARGS: base nvim invocation for this script's two headless call sites (gate5 verify_all,
# gate13 find_orphans). Extended by --minimal-init to `--clean --cmd "set rtp+=DIR"` instead of
# the default plain `nvim --headless` (which loads init.lua and pays the full lazy.nvim plugin
# bootstrap). Absent --minimal-init this array is unchanged from before the flag existed, so
# default-mode behavior stays byte-for-byte identical. See deploy-headless.sh's header for the
# fuller rationale (DIR is the nvim config directory, not always $TARGET, always explicit).
declare -a NVIM_ARGS=(nvim --headless)
if [ -n "$MINIMAL_INIT_DIR" ]; then
  NVIM_ARGS+=(--clean --cmd "set rtp+=${MINIMAL_INIT_DIR}")
fi

TARGET="${TARGET:-$(pwd)}"

if [ ! -d "$TARGET" ]; then
  echo "ERROR: target is not a directory: $TARGET" >&2
  [ "$FINDINGS" = "true" ] && echo "FINDING gate0 verify-deploy could not run: target is not a directory: $TARGET"
  exit 2
fi
TARGET="$(cd "$TARGET" && pwd)"

CLAUDE_DIR="$TARGET/.claude"
if [ ! -d "$CLAUDE_DIR" ]; then
  echo "ERROR: no deploy tree at $CLAUDE_DIR -- nothing to verify." >&2
  echo "Run: bash deploy-headless.sh $TARGET" >&2
  [ "$FINDINGS" = "true" ] && echo "FINDING gate0 verify-deploy could not run: no deploy tree at $CLAUDE_DIR"
  exit 2
fi

if [ -n "$MINIMAL_INIT_DIR" ] && [ ! -d "$MINIMAL_INIT_DIR" ]; then
  echo "ERROR: --minimal-init directory does not exist: $MINIMAL_INIT_DIR" >&2
  [ "$FINDINGS" = "true" ] && echo "FINDING gate0 verify-deploy could not run: --minimal-init directory does not exist: $MINIMAL_INIT_DIR"
  exit 2
fi

# ORCHESTRATOR_BUDGET_GATE_MODE controls severity for gate20's two per-file ceiling sub-check
# (commands/orchestrate.md, skills/skill-orchestrate/SKILL.md against
# context/config/orchestrator-context-budget.json). Mirrors the SCHEMA_CONFORMANCE_GATE_MODE /
# STRICT_CORE_DEPLOY precedent (check-extension-docs.sh): one env-var default a maintainer flips
# in a follow-up commit, not a persisted auto-promotion counter. A first promotion attempt on
# 2026-10-01 was reverted same-day: a sibling commit (the `[HOLD]` status-marker change) grew
# commands/orchestrate.md to 21,328 B, 328 B over its own 21,000 B ceiling, just as
# skills/skill-orchestrate/SKILL.md and the eager-load total were brought under their ceilings by
# a deliberate duplication trim. Promotion to "hard" landed successfully later the same day
# (2026-10-01), once a restatement trim of commands/orchestrate.md's Options table rows
# (`--fast`/`--research`/`--plan`/`--implement`) and forced-phase Constraints bullet -- relocating
# duplicated detail behind pointers into docs/architecture/orchestrate-state-machine.md, the
# single authoritative long-form source -- brought the file to 19,024 B. Both per-file ceilings
# were clear at promotion time (commands/orchestrate.md 19,024 B / 21,000 B;
# skills/skill-orchestrate/SKILL.md 19,993 B / 20,000 B); neither ceiling_bytes nor
# eager_load.baseline_bytes in orchestrator-context-budget.json was moved to effect this
# promotion. Does NOT gate the eager-load regression check or the volatile-file check, both of
# which have their own fixed severity (see gate20 below).
ORCHESTRATOR_BUDGET_GATE_MODE="${ORCHESTRATOR_BUDGET_GATE_MODE:-hard}"

# VERIFY_DEPLOY_GATE8_JOBS controls Gate 8's concurrency request to run-all.sh's opt-in --jobs
# flag. Default 'auto' resolves to nproc capped at run-all.sh's own JOBS_CAP (4); see gate 8's
# call site below for the full precedence/rejected-alternatives record.
GATE8_JOBS="${VERIFY_DEPLOY_GATE8_JOBS:-auto}"

FAILURES=0
CHECKS=0
CURRENT_GATE="gate0"

say() { [ "$QUIET" = "true" ] || echo "$@"; }

pass() {
  CHECKS=$((CHECKS + 1))
  say "  [PASS] $1"
}

# fail(): records a narrative failure (stderr, unchanged) AND, as a second consumer of the same
# single source, a findings-mode entry. The optional third argument overrides the finding text
# recorded for --findings (used where the narrative message embeds a numeric count that must not
# leak into the normalized finding, or where a caller extracts its own per-underlying-finding
# lines separately and passes "" here to suppress the default aggregate finding).
fail() {
  CHECKS=$((CHECKS + 1))
  FAILURES=$((FAILURES + 1))
  echo "  [FAIL] $1" >&2
  [ -n "${2:-}" ] && echo "         $2" >&2
  if [ $# -ge 3 ]; then
    [ -n "$3" ] && FINDINGS_LIST+=("FINDING $CURRENT_GATE $3")
  else
    FINDINGS_LIST+=("FINDING $CURRENT_GATE $1")
  fi
  return 0
}

# warn(): a WARN-level cousin of fail() for gate16's non-blocking migration notice. Increments
# CHECKS but NEVER FAILURES -- a warning must never flip the verifier's exit code. Echoes to
# stderr the same way fail() does, and appends to FINDINGS_LIST when FINDINGS mode is on.
warn() {
  CHECKS=$((CHECKS + 1))
  echo "  [WARN] $1" >&2
  [ -n "${2:-}" ] && echo "         $2" >&2
  if [ "$FINDINGS" = "true" ]; then
    if [ $# -ge 3 ]; then
      [ -n "$3" ] && FINDINGS_LIST+=("FINDING $CURRENT_GATE $3")
    else
      FINDINGS_LIST+=("FINDING $CURRENT_GATE $1")
    fi
  fi
  return 0
}

# gate_selected N: returns 0 (selected) when GATES_FILTER is empty (default: all gates) or
# contains N as one of its comma-separated tokens; returns 1 otherwise. Every one of the 20
# guarded gate blocks below consults this single predicate -- gate0 itself is never guarded by it
# (see the --only-gate header doc above).
gate_selected() {
  local n="$1"
  [ -z "$GATES_FILTER" ] && return 0
  case ",${GATES_FILTER}," in
    *",${n},"*) return 0 ;;
    *) return 1 ;;
  esac
}

say "[verify-deploy] Target: $TARGET"
say ""

# ── 1. Core event-store and error-store files present ─────────────────────────
# Covers two store families: the passive-signal-capture stack (events.jsonl: append-only script,
# query script, both hooks, schema, format doc) and the error-tracking stack (errors.json:
# validated append/update writer, schema, format doc). A missing entry means the deploy predates
# that store's work or was a partial sync.
if gate_selected 1; then
say "1. Event-store and error-store files (ls .claude/{scripts,hooks,context}/...)"
CURRENT_GATE="gate1"
for rel in \
  scripts/events-append.sh \
  scripts/events-query.sh \
  hooks/events-log-artifact.sh \
  hooks/events-log-lifecycle.sh \
  context/schemas/events-schema.json \
  context/formats/events-format.md \
  scripts/errors-append.sh \
  context/schemas/errors-schema.json \
  context/formats/errors-format.md
do
  if [ -e "$CLAUDE_DIR/$rel" ]; then
    pass "$rel"
  else
    fail "$rel is missing" "run deploy-headless.sh to regenerate"
  fi
done
say ""

fi
# ── 2. Hook registrations in the deployed settings.json ──────────────────────
# The single most failure-prone part of a deploy: settings.json is install-once, so additions
# reach an existing repo only through merge-sources/settings-hooks.json. A tree can have every
# hook SCRIPT present and still register none of them.
if gate_selected 2; then
say "2. Hook registrations (jq '.hooks' .claude/settings.json)"
CURRENT_GATE="gate2"
SETTINGS="$CLAUDE_DIR/settings.json"
if [ ! -f "$SETTINGS" ]; then
  fail "settings.json is missing"
elif ! command -v jq >/dev/null 2>&1; then
  fail "jq unavailable; cannot inspect hook registrations"
elif ! jq empty "$SETTINGS" 2>/dev/null; then
  fail "settings.json is not valid JSON"
else
  for pair in "PostToolUse:events-log-artifact.sh" \
              "Stop:events-log-lifecycle.sh" \
              "SubagentStop:events-log-lifecycle.sh"
  do
    event="${pair%%:*}"
    script="${pair##*:}"
    n=$(jq --arg e "$event" --arg s "$script" \
      '[.hooks[$e][]?.hooks[]? | select(.command | test($s))] | length' "$SETTINGS" 2>/dev/null)
    n="${n:-0}"
    if [ "$n" -ge 1 ]; then
      pass "$event -> $script registered"
    else
      fail "$event -> $script NOT registered" \
           "add it to merge-sources/settings-hooks.json, not root-files/settings.json"
    fi
  done

  # Duplicate detection. Reported as a warning, never a failure: the merge is add-only and
  # cannot remove a pre-existing entry, so a duplicate is a manual-cleanup item rather than
  # something a regeneration could ever fix. Failing on it would make this script permanently
  # red on any tree that has ever accumulated one.
  dupes=$(jq -r '
    [.hooks | to_entries[] | .key as $e | .value[]?.hooks[]?.command
     | select(. != null) | "\($e)\t\(.)"]
    | group_by(.) | map(select(length > 1) | {cmd: .[0], n: length}) | .[]
    | "\(.cmd) x\(.n)"' "$SETTINGS" 2>/dev/null)
  if [ -n "$dupes" ]; then
    say ""
    say "  [WARN] duplicate hook command registrations (manual cleanup; no merge can remove these):"
    while IFS= read -r line; do
      [ -n "$line" ] && say "         $line"
    done <<< "$dupes"
  fi
fi
say ""

fi
# ── 3. Doc-lint gate ─────────────────────────────────────────────────────────
# Only meaningful in the source-store repo. A deploy consumer has no agent-system/extensions
# directory, and the gate correctly errors there -- that is not a deploy failure.
if gate_selected 3; then
say "3. Doc-lint (check-extension-docs.sh --quiet)"
CURRENT_GATE="gate3"
if [ ! -d "$TARGET/agent-system/extensions" ]; then
  say "  [SKIP] $TARGET is a deploy consumer, not the source store -- doc-lint does not apply"
elif [ ! -x "$CLAUDE_DIR/scripts/check-extension-docs.sh" ] && [ ! -f "$CLAUDE_DIR/scripts/check-extension-docs.sh" ]; then
  fail "check-extension-docs.sh not deployed"
else
  # Capture rather than discard: check-extension-docs.sh's `[ext_name]`/`[project-wide]` headers
  # and its `FAIL:` lines are unconditional echo (they survive that script's own --quiet), so a
  # single --quiet capture is enough to extract per-finding detail below. This generalizes the
  # STRICT_CORE_DEPLOY re-invocation precedent already used later in this same gate, rather than
  # introducing a new mechanism.
  doc_lint_output=$(cd "$TARGET" && bash "$CLAUDE_DIR/scripts/check-extension-docs.sh" --quiet 2>&1)
  doc_lint_exit=$?
  if [ "$doc_lint_exit" -eq 0 ]; then
    pass "doc-lint reports no failures"
  else
    # Third arg "" suppresses the default aggregate finding -- the per-underlying-FAIL: lines
    # extracted below are the findings-mode representation of this failure, not this message.
    fail "doc-lint reported failures" \
         "re-run without --quiet for detail: bash .claude/scripts/check-extension-docs.sh" ""
    if [ "$FINDINGS" = "true" ]; then
      current_header="[unknown]"
      while IFS= read -r doc_lint_line; do
        case "$doc_lint_line" in
          "["*"]")
            current_header="$doc_lint_line"
            ;;
          "  FAIL: "*)
            # ADVISORY: lines are deliberately excluded (Decision 3) -- only this FAIL: case
            # matches; check-extension-docs.sh exits non-zero on FAIL only, never on ADVISORY.
            FINDINGS_LIST+=("FINDING gate3 ${current_header} ${doc_lint_line#  }")
            ;;
        esac
      done <<< "$doc_lint_output"
    fi
  fi

  strict_output=$(cd "$TARGET" && STRICT_CORE_DEPLOY=1 bash "$CLAUDE_DIR/scripts/check-extension-docs.sh" --quiet 2>&1)
  strict_hits=$(printf '%s\n' "$strict_output" | grep -c 'events-')
  if [ "${strict_hits:-0}" -eq 0 ]; then
    pass "STRICT_CORE_DEPLOY reports no undeployed event files"
  else
    # Finding text (3rd arg) omits the numeric count (Decision 4) -- the condition is boolean
    # ("the deploy tree is behind the source store"); magnitude drift inside an already-failing
    # check must not manufacture a spurious "new" finding for the pre/post comparison.
    fail "STRICT_CORE_DEPLOY still reports $strict_hits event-file line(s)" \
         "the deploy tree is behind the source store" \
         "STRICT_CORE_DEPLOY reports undeployed event file(s): the deploy tree is behind the source store"
  fi
fi

say ""

fi
# ── 4. Task-reference lint gate ───────────────────────────────────────────────
# Only meaningful in the source-store repo, mirroring the Doc-lint gate above -- a deploy
# consumer has no agent-system/extensions directory and the gate correctly skips there.
if gate_selected 4; then
say "4. Task-reference lint (check-task-references.sh --quiet)"
CURRENT_GATE="gate4"
if [ ! -d "$TARGET/agent-system/extensions" ]; then
  say "  [SKIP] $TARGET is a deploy consumer, not the source store -- task-reference lint does not apply"
elif [ ! -x "$CLAUDE_DIR/scripts/check-task-references.sh" ] && [ ! -f "$CLAUDE_DIR/scripts/check-task-references.sh" ]; then
  fail "check-task-references.sh not deployed"
else
  # Leave this --quiet invocation verbatim (unlike gate 3, its per-finding `path:line:content`
  # detail is gated by that script's own info() and does NOT survive --quiet -- only the summary
  # counts and the final FAIL:/PASS: line do). Detail requires the WITHOUT-quiet re-invocation
  # below, done only when a finding-mode caller needs it and the gate already failed.
  if (cd "$TARGET" && bash "$CLAUDE_DIR/scripts/check-task-references.sh" --quiet >/dev/null 2>&1); then
    pass "task-reference lint reports no findings"
  else
    fail "task-reference lint reported findings" \
         "re-run without --quiet for detail: bash .claude/scripts/check-task-references.sh" ""
    if [ "$FINDINGS" = "true" ]; then
      task_ref_output=$(cd "$TARGET" && bash "$CLAUDE_DIR/scripts/check-task-references.sh" 2>&1)
      while IFS= read -r task_ref_line; do
        FINDINGS_LIST+=("FINDING gate4 ${task_ref_line#  }")
      done < <(printf '%s\n' "$task_ref_output" | grep -E '^  [^:]+:[0-9]+:')
    fi
  fi
fi

fi
# ── 5. Manifest-driven category parity + content-hash equality (verify.lua) ──────
# Extends gates 1-4 (which check specific known files/registrations) to full declared-vs-
# deployed parity plus content-hash equality across every provides.* category the manifest
# declares, driven by neotex.plugins.ai.shared.extensions.verify's manager.verify_all -- the
# same check the extension loader itself runs after a load. Only meaningful in the source-store
# repo (a deploy consumer has no agent-system/extensions/core/ source directory to diff against),
# mirroring gates 3-4's SKIP-if-not-source-store precedent.
if gate_selected 5; then
say "5. Manifest-driven category parity + content-hash equality (verify.lua)"
CURRENT_GATE="gate5"
if [ ! -d "$TARGET/agent-system/extensions" ]; then
  say "  [SKIP] $TARGET is a deploy consumer, not the source store -- this gate compares against"
  say "         the source store and does not apply here"
elif ! command -v nvim >/dev/null 2>&1; then
  fail "nvim not found on PATH; cannot run the manifest-driven verification"
else
  verify_output=$(cd "$TARGET" && "${NVIM_ARGS[@]}" \
    -c "lua local ok1, ext_config = pcall(require, 'neotex.plugins.ai.shared.extensions.config'); local ok2, ext_init = pcall(require, 'neotex.plugins.ai.shared.extensions.init'); if not (ok1 and ok2) then print('VERIFY_ERROR require: ' .. tostring(ok1 and ext_init or ext_config)) else local manager = ext_init.create(ext_config.claude()); local pok, results = pcall(manager.verify_all, '${TARGET}'); if not pok then print('VERIFY_ERROR call: ' .. tostring(results)) else for _, v in ipairs(results) do if v.status ~= 'passed' then for _, err in ipairs(v.errors or {}) do print('VERIFY_FINDING ' .. v.extension .. ': ' .. err) end end end print('VERIFY_DONE count=' .. tostring(#results)) end end" \
    -c "qa!" 2>&1)

  if echo "$verify_output" | grep -q 'VERIFY_ERROR'; then
    verify_error_line=$(echo "$verify_output" | grep 'VERIFY_ERROR' | head -1)
    fail "manifest-driven verification could not run" "$verify_error_line" \
         "manifest-driven verification could not run: $verify_error_line"
  elif ! echo "$verify_output" | grep -q 'VERIFY_DONE'; then
    fail "manifest-driven verification produced no result" \
         "re-run: nvim --headless -c \"lua ...manager.verify_all(...)\"" \
         "manifest-driven verification produced no result"
  else
    # Unanchored (not '^VERIFY_FINDING '): nvim can prepend a terminal OSC7 cwd-reporting escape
    # sequence to its first stdout line with no newline separator, which would otherwise defeat a
    # start-of-line anchor. Mirrors deploy-headless.sh's own unanchored 'grep -o DEPLOY_COUNT=...'
    # extraction of the same headless-nvim-output family, for the same reason.
    verify_finding_count=$(echo "$verify_output" | grep -c 'VERIFY_FINDING ')
    if [ "$verify_finding_count" -eq 0 ]; then
      pass "declared-vs-deployed parity and content-hash equality (all loaded extensions)"
    else
      # Third arg "" suppresses the default aggregate finding -- the per-underlying-VERIFY_FINDING
      # lines extracted below are the findings-mode representation of this failure, mirroring
      # gate 3's doc-lint per-FAIL: line extraction. The loop below ALSO prints each finding to
      # the operator-visible stderr stream unconditionally (fail()'s own [FAIL]/hint lines are
      # not gated by --quiet either, so this is consistent with the rest of the gate's output),
      # independent of --findings -- see context/patterns/deploy-orphan-detection.md's fail-time
      # detail subsection for why: without this, "re-run for detail" was a false promise, since
      # the per-finding lines were previously appended to FINDINGS_LIST only.
      fail "manifest-driven verification reported $verify_finding_count finding(s)" \
           "see findings below" ""
      while IFS= read -r verify_finding_line; do
        # -o 'VERIFY_FINDING .*' extracts from the token onward regardless of what (if anything)
        # precedes it on the line -- same OSC7 robustness rationale as verify_finding_count above.
        # '#*VERIFY_FINDING ' (not '#VERIFY_FINDING ') strips everything up to and including the
        # token wherever it falls, not only at position 0.
        verify_finding_detail="${verify_finding_line#*VERIFY_FINDING }"
        echo "         - $verify_finding_detail" >&2
        if [ "$FINDINGS" = "true" ]; then
          FINDINGS_LIST+=("FINDING gate5 $verify_finding_detail")
        fi
      done < <(echo "$verify_output" | grep -o 'VERIFY_FINDING .*')
    fi
  fi
fi

say ""

fi
# ── 6. Agent contracts lint gate ──────────────────────────────────────────────
# Only meaningful in the source-store repo, mirroring gates 3-4's SKIP-if-not-source-store
# precedent -- a deploy consumer has no agent-system/extensions directory and the gate correctly
# skips there.
if gate_selected 6; then
say "6. Agent contracts lint (lint-agent-contracts.sh --verbose)"
CURRENT_GATE="gate6"
if [ ! -d "$TARGET/agent-system/extensions" ]; then
  say "  [SKIP] $TARGET is a deploy consumer, not the source store -- agent contracts lint does not apply"
elif [ ! -f "$TARGET/agent-system/extensions/core/scripts/lint/lint-agent-contracts.sh" ]; then
  fail "lint-agent-contracts.sh not found in source store"
else
  agent_lint_output=$(cd "$TARGET" && REPO_ROOT="$TARGET" bash "$TARGET/agent-system/extensions/core/scripts/lint/lint-agent-contracts.sh" --verbose 2>&1)
  agent_lint_status=$?
  if [ "$agent_lint_status" -eq 0 ]; then
    pass "agent contracts lint reports no failures"
  else
    fail "agent contracts lint reported failures" \
         "re-run for detail: bash agent-system/extensions/core/scripts/lint/lint-agent-contracts.sh --verbose" ""
    if [ "$FINDINGS" = "true" ]; then
      while IFS= read -r agent_lint_line; do
        FINDINGS_LIST+=("FINDING gate6 ${agent_lint_line#*FAIL\] }")
      done < <(printf '%s\n' "$agent_lint_output" | grep -F '[FAIL]')
    fi
  fi
fi

fi
# ── 7. Routing wiring lint gate ───────────────────────────────────────────────
# Only meaningful in the source-store repo, mirroring gates 3-4/6's SKIP-if-not-source-store
# precedent -- a deploy consumer has no agent-system/extensions directory and the gate correctly
# skips there.
if gate_selected 7; then
say "7. Routing wiring lint (lint-routing-wiring.sh --verbose)"
CURRENT_GATE="gate7"
if [ ! -d "$TARGET/agent-system/extensions" ]; then
  say "  [SKIP] $TARGET is a deploy consumer, not the source store -- routing wiring lint does not apply"
elif [ ! -f "$TARGET/agent-system/extensions/core/scripts/lint/lint-routing-wiring.sh" ]; then
  fail "lint-routing-wiring.sh not found in source store"
else
  routing_lint_output=$(cd "$TARGET" && REPO_ROOT="$TARGET" bash "$TARGET/agent-system/extensions/core/scripts/lint/lint-routing-wiring.sh" --verbose 2>&1)
  routing_lint_status=$?
  if [ "$routing_lint_status" -eq 0 ]; then
    pass "routing wiring lint reports no failures"
  else
    fail "routing wiring lint reported failures" \
         "re-run for detail: bash agent-system/extensions/core/scripts/lint/lint-routing-wiring.sh --verbose" ""
    if [ "$FINDINGS" = "true" ]; then
      while IFS= read -r routing_lint_line; do
        FINDINGS_LIST+=("FINDING gate7 ${routing_lint_line#*FAIL\] }")
      done < <(printf '%s\n' "$routing_lint_output" | grep -F '[FAIL]')
    fi
  fi
fi

fi
# ── 8. Shell test suite runner (run-all.sh) ───────────────────────────────────
# Only meaningful in the source-store repo, mirroring gates 3-4/6-7's SKIP-if-not-source-store
# precedent -- a deploy consumer has no agent-system/extensions directory and the gate correctly
# skips there.
if gate_selected 8; then
say "8. Shell test suite runner (tests/run-all.sh)"
CURRENT_GATE="gate8"
if [ "$SKIP_SLOW" = "true" ]; then
  say "  [SKIP] --skip-slow: shell test suite deferred (run without --skip-slow for the full gate)"
elif [ ! -d "$TARGET/agent-system/extensions" ]; then
  say "  [SKIP] $TARGET is a deploy consumer, not the source store -- run-all.sh does not apply"
elif [ ! -f "$TARGET/agent-system/extensions/core/scripts/tests/run-all.sh" ]; then
  fail "tests/run-all.sh not found in source store"
else
  # Request run-all.sh's opt-in parallelism (default 'auto'; override via
  # VERIFY_DEPLOY_GATE8_JOBS, e.g. '1' on a nproc=1 or memory-pressured/heavily-loaded host).
  # VERIFY_DEPLOY_GATE8_JOBS always wins when set; the value is passed through verbatim and
  # validated by run-all.sh alone (single source of validation truth) -- no silent fallback here.
  # Rejected alternatives (do not re-propose): a bare hardcoded `4` (not host-adaptive; identical
  # to `auto` only on hosts with nproc >= 4); a conservative fixed `2` (leaves measured headroom
  # unused and still needs the same override); reusing a generic `JOBS` env name (too broad,
  # collides with unrelated tooling); gating on TTY-ness (implicit, untestable, surprising).
  # run-all.sh's own nested-invocation guard (RUN_ALL_NESTED) still forces JOBS=1 when this
  # verify-deploy.sh invocation is itself reached from inside another run-all.sh's suite,
  # regardless of what --jobs requests here -- unaffected by this change.
  run_all_output=$(cd "$TARGET" && bash "$TARGET/agent-system/extensions/core/scripts/tests/run-all.sh" --quiet --jobs "$GATE8_JOBS" 2>&1)
  run_all_status=$?
  if [ "$run_all_status" -eq 0 ]; then
    pass "run-all.sh: all discovered suites passed"
  else
    run_all_remedy="re-run for detail: bash agent-system/extensions/core/scripts/tests/run-all.sh"
    [ "$run_all_status" -eq 2 ] && run_all_remedy="$run_all_remedy (exit 2 may indicate an invalid VERIFY_DEPLOY_GATE8_JOBS value: '$GATE8_JOBS')"
    fail "run-all.sh reported failing or undiscoverable suites (exit $run_all_status)" \
         "$run_all_remedy" ""
    if [ "$FINDINGS" = "true" ]; then
      while IFS= read -r run_all_line; do
        FINDINGS_LIST+=("FINDING gate8 ${run_all_line#\[FAIL\] }")
      done < <(printf '%s\n' "$run_all_output" | grep -F '[FAIL]')
    fi
  fi
fi

say ""

fi
# ── 9. Postflight boundary lint gate ──────────────────────────────────────────
# Only meaningful in the source-store repo, mirroring gate 6's SKIP-if-not-source-store
# precedent -- a deploy consumer has no agent-system/extensions directory and the gate correctly
# skips there. UNLIKE gates 6-7, this gate invokes the DEPLOYED copy of the script
# ($TARGET/.claude/scripts/lint/lint-postflight-boundary.sh), not the source-store one: the
# script's own PROJECT_ROOT resolution (common_repo_root "$SCRIPT_DIR" 3) assumes a 3-levels-up
# depth that only lands on the repo root from the deployed path
# (.claude/scripts/lint -> .claude/scripts -> .claude -> repo root); invoking the source-store
# copy would resolve PROJECT_ROOT to agent-system/extensions instead and silently scan nothing.
# This also matches the script's own default scan targets ($PROJECT_ROOT/.claude/skills,
# $PROJECT_ROOT/.claude/extensions) -- it is designed to audit deployed content, not source.
if gate_selected 9; then
say "9. Postflight boundary lint (lint-postflight-boundary.sh, full corpus)"
CURRENT_GATE="gate9"
if [ ! -d "$TARGET/agent-system/extensions" ]; then
  say "  [SKIP] $TARGET is a deploy consumer, not the source store -- postflight boundary lint does not apply"
elif [ ! -f "$TARGET/agent-system/extensions/core/scripts/lint/lint-postflight-boundary.sh" ]; then
  fail "lint-postflight-boundary.sh not found in source store"
elif [ ! -f "$TARGET/.claude/scripts/lint/lint-postflight-boundary.sh" ]; then
  fail "lint-postflight-boundary.sh not found in deployed tree (run deploy-headless.sh first)"
else
  postflight_lint_output=$(cd "$TARGET" && bash "$TARGET/.claude/scripts/lint/lint-postflight-boundary.sh" --verbose 2>&1)
  postflight_lint_status=$?
  if [ "$postflight_lint_status" -eq 0 ]; then
    pass "postflight boundary lint reports no failures (full corpus)"
  else
    fail "postflight boundary lint reported failures" \
         "re-run for detail: bash .claude/scripts/lint/lint-postflight-boundary.sh --verbose" ""
    if [ "$FINDINGS" = "true" ]; then
      while IFS= read -r postflight_lint_line; do
        FINDINGS_LIST+=("FINDING gate9 ${postflight_lint_line#*VIOLATION\] }")
      done < <(printf '%s\n' "$postflight_lint_output" | grep -F '[VIOLATION]')
    fi
  fi
fi

say ""

fi
# ── 10. specs/state.json schema validation (validate-state.sh --deep) ─────────
# Only meaningful in the source-store repo, mirroring gates 3-4/6-7/9's SKIP-if-not-source-store
# precedent -- a deploy consumer has no agent-system/extensions directory and the gate correctly
# skips there. Invokes the DEPLOYED copy (like gate 9), not the source-store one: validate-state.sh
# itself is argument-relative (no PROJECT_ROOT/deploy-root-guard.sh dependency), but its --deep
# TODO.md-sync check shells out to generate-todo.sh, which DOES require the deployed tree via
# deploy-root-guard.sh -- so running the source-store copy here would spuriously fail that one
# sub-check. Targets $TARGET/specs/state.json, the live state store, not a fixture.
if gate_selected 10; then
say "10. specs/state.json schema validation (validate-state.sh --deep)"
CURRENT_GATE="gate10"
if [ ! -d "$TARGET/agent-system/extensions" ]; then
  say "  [SKIP] $TARGET is a deploy consumer, not the source store -- state schema validation does not apply"
elif [ ! -f "$TARGET/.claude/scripts/validate-state.sh" ]; then
  fail "validate-state.sh not found in deployed tree (run deploy-headless.sh first)"
elif [ ! -f "$TARGET/specs/state.json" ]; then
  say "  [SKIP] no specs/state.json in $TARGET -- state schema validation does not apply"
else
  state_validate_output=$(cd "$TARGET" && bash "$TARGET/.claude/scripts/validate-state.sh" --deep "$TARGET/specs/state.json" 2>&1)
  state_validate_status=$?
  if [ "$state_validate_status" -eq 0 ]; then
    pass "validate-state.sh --deep: specs/state.json passes (no FAIL-level finding)"
  else
    fail "validate-state.sh --deep reported FAIL-level finding(s) against specs/state.json" \
         "re-run for detail: bash .claude/scripts/validate-state.sh --deep specs/state.json" ""
    if [ "$FINDINGS" = "true" ]; then
      while IFS= read -r state_validate_line; do
        FINDINGS_LIST+=("FINDING gate10 ${state_validate_line#*\[FAIL\] }")
      done < <(printf '%s\n' "$state_validate_output" | grep -F '[FAIL]')
    fi
  fi
fi

say ""

fi
# ── 11. Contract compliance lint (lint-contract-compliance.sh --verbose) ──────
# Only meaningful in the source-store repo, mirroring gates 6-7's SKIP-if-not-source-store
# precedent -- a deploy consumer has no agent-system/extensions directory and the gate correctly
# skips there. Invokes the source-store copy directly (like gates 6-7): the script resolves its
# own REPO_ROOT via `git rev-parse --show-toplevel`, falling back to the `REPO_ROOT` env override
# set here, and always validates the source store (agent-system/extensions/core/**) regardless of
# which copy is invoked.
if gate_selected 11; then
say "11. Contract compliance lint (lint-contract-compliance.sh --verbose)"
CURRENT_GATE="gate11"
if [ ! -d "$TARGET/agent-system/extensions" ]; then
  say "  [SKIP] $TARGET is a deploy consumer, not the source store -- contract compliance lint does not apply"
elif [ ! -f "$TARGET/agent-system/extensions/core/scripts/lint/lint-contract-compliance.sh" ]; then
  fail "lint-contract-compliance.sh not found in source store"
else
  contract_lint_output=$(cd "$TARGET" && REPO_ROOT="$TARGET" bash "$TARGET/agent-system/extensions/core/scripts/lint/lint-contract-compliance.sh" --verbose 2>&1)
  contract_lint_status=$?
  if [ "$contract_lint_status" -eq 0 ]; then
    pass "contract compliance lint reports no failures"
  else
    fail "contract compliance lint reported failures" \
         "re-run for detail: bash agent-system/extensions/core/scripts/lint/lint-contract-compliance.sh --verbose" ""
    if [ "$FINDINGS" = "true" ]; then
      while IFS= read -r contract_lint_line; do
        FINDINGS_LIST+=("FINDING gate11 ${contract_lint_line#*FAIL\] }")
      done < <(printf '%s\n' "$contract_lint_output" | grep -F '[FAIL]')
    fi
  fi
fi

say ""

fi
# Gate 12: state-writer boundary lint (lint-state-writer-boundary.sh --verbose)
#
# Same source-store-vs-deploy-consumer [SKIP] posture as the sibling lint gates (6, 7, 9, 11):
# only the source store (agent-system/extensions/core/**) is validated, regardless of which copy
# (source store or deployed .claude/) invoked this script. Invokes the source-store copy
# directly, resolving REPO_ROOT the same way gate 11 does.
if gate_selected 12; then
say "12. State-writer boundary lint (lint-state-writer-boundary.sh --verbose)"
CURRENT_GATE="gate12"
if [ ! -d "$TARGET/agent-system/extensions" ]; then
  say "  [SKIP] $TARGET is a deploy consumer, not the source store -- state-writer boundary lint does not apply"
elif [ ! -f "$TARGET/agent-system/extensions/core/scripts/lint/lint-state-writer-boundary.sh" ]; then
  fail "lint-state-writer-boundary.sh not found in source store"
else
  state_writer_lint_output=$(cd "$TARGET" && REPO_ROOT="$TARGET" bash "$TARGET/agent-system/extensions/core/scripts/lint/lint-state-writer-boundary.sh" --verbose 2>&1)
  state_writer_lint_status=$?
  if [ "$state_writer_lint_status" -eq 0 ]; then
    pass "state-writer boundary lint reports no hand-rolled writes"
  else
    fail "state-writer boundary lint reported hand-rolled state.json writes" \
         "re-run for detail: bash agent-system/extensions/core/scripts/lint/lint-state-writer-boundary.sh --verbose" ""
    if [ "$FINDINGS" = "true" ]; then
      while IFS= read -r state_writer_lint_line; do
        FINDINGS_LIST+=("FINDING gate12 ${state_writer_lint_line#*VIOLATION\] }")
      done < <(printf '%s\n' "$state_writer_lint_output" | grep -F '[VIOLATION]')
    fi
  fi
fi

say ""

fi
# Gate 13: whole-tree orphan detection (find_orphans).
#
# The reverse direction from gate 5: gate 5 verifies declared -> deployed (is every declared
# entry present and hash-identical?); this gate verifies deployed -> declared (is every deployed
# file still declared by SOME active extension?). A file that loses its source-store owner is
# invisible to gate 5 forever, because the copy engine is additive-only by design and never
# deletes on its own. Modeled line-for-line on gate 5: same CURRENT_GATE assignment, same [SKIP]
# posture when the target is a deploy consumer rather than the source store, same headless-nvim
# invocation shape, same unanchored grep for the emitted token (OSC7 robustness). Detection only
# -- see context/patterns/deploy-orphan-detection.md for the full exclusion contract this gate
# enforces and the detect-never-delete decision it implements.
if gate_selected 13; then
say "13. Whole-tree orphan detection (find_orphans: deployed-but-undeclared files, ghost index rows)"
CURRENT_GATE="gate13"
if [ ! -d "$TARGET/agent-system/extensions" ]; then
  say "  [SKIP] $TARGET is a deploy consumer, not the source store -- this gate compares against"
  say "         the source store and does not apply here"
elif ! command -v nvim >/dev/null 2>&1; then
  fail "nvim not found on PATH; cannot run whole-tree orphan detection"
else
  orphan_output=$(cd "$TARGET" && "${NVIM_ARGS[@]}" \
    -c "lua local ok1, ext_config = pcall(require, 'neotex.plugins.ai.shared.extensions.config'); local ok2, ext_init = pcall(require, 'neotex.plugins.ai.shared.extensions.init'); if not (ok1 and ok2) then print('ORPHAN_ERROR require: ' .. tostring(ok1 and ext_init or ext_config)) else local manager = ext_init.create(ext_config.claude()); local pok, result = pcall(manager.find_orphans, '${TARGET}'); if not pok then print('ORPHAN_ERROR call: ' .. tostring(result)) else for _, rel in ipairs(result.orphans) do print('ORPHAN_FINDING orphan file: ' .. rel) end for _, path in ipairs(result.ghost_index_entries) do print('ORPHAN_FINDING ghost index row: ' .. path) end print('ORPHAN_DONE checked=' .. tostring(result.checked)) end end" \
    -c "qa!" 2>&1)

  if echo "$orphan_output" | grep -q 'ORPHAN_ERROR'; then
    orphan_error_line=$(echo "$orphan_output" | grep 'ORPHAN_ERROR' | head -1)
    fail "whole-tree orphan detection could not run" "$orphan_error_line" \
         "whole-tree orphan detection could not run: $orphan_error_line"
  elif ! echo "$orphan_output" | grep -q 'ORPHAN_DONE'; then
    fail "whole-tree orphan detection produced no result" \
         "re-run: nvim --headless -c \"lua ...manager.find_orphans(...)\"" \
         "whole-tree orphan detection produced no result"
  else
    # Unanchored, same OSC7 rationale as gate 5's verify_finding_count above.
    orphan_finding_count=$(echo "$orphan_output" | grep -c 'ORPHAN_FINDING ')
    if [ "$orphan_finding_count" -eq 0 ]; then
      pass "no deployed-but-undeclared files or ghost context/index.json rows"
    else
      # Third arg "" suppresses the default aggregate finding -- the per-underlying-
      # ORPHAN_FINDING lines extracted below are the findings-mode representation, mirroring
      # gate 5's own suppress-and-extract pattern. The loop below ALSO prints each finding to the
      # operator-visible stderr stream unconditionally (fail()'s own [FAIL]/hint lines are not
      # gated by --quiet either), independent of --findings -- see
      # context/patterns/deploy-orphan-detection.md's fail-time detail subsection for why:
      # without this, "re-run without --quiet for detail" was a false promise, since the
      # per-finding lines were previously appended to FINDINGS_LIST only.
      fail "whole-tree orphan detection reported $orphan_finding_count finding(s)" \
           "see findings below; classify against context/patterns/deploy-orphan-detection.md's exclusion classes" ""
      while IFS= read -r orphan_finding_line; do
        orphan_finding_detail="${orphan_finding_line#*ORPHAN_FINDING }"
        echo "         - $orphan_finding_detail" >&2
        if [ "$FINDINGS" = "true" ]; then
          FINDINGS_LIST+=("FINDING gate13 $orphan_finding_detail")
        fi
      done < <(echo "$orphan_output" | grep -o 'ORPHAN_FINDING .*')
    fi
  fi
fi

say ""

fi
# Gate 14: orchestrator runtime-file tracking policy (check-runtime-file-tracking.sh).
#
# Runs on ANY target, not just the source store -- unlike gates 3/4/6/7/8/9/10 (which SKIP on a
# deploy consumer because they inspect agent-system/extensions), this gate's three checks
# (ignore coverage, no tracked ephemeral file, provenance not over-ignored) apply equally to
# every repo that has a .claude/ deploy tree, since check-runtime-file-tracking.sh itself is
# deployed by the core extension's manifest.json (provides.scripts) into every consumer. Invokes
# the DEPLOYED copy from $TARGET's own repo root, since the script's probes
# (specs/000_probe/...) are relative paths that must resolve against the target's own specs/
# tree, not the source-store repo running this aggregator.
#
# Fast, not deferred by --skip-slow: three `git check-ignore` sweeps over a handful of probe
# paths, nowhere near gate 8's tests/run-all.sh cost. --skip-slow continues to defer gate 8 only.
if gate_selected 14; then
say "14. Orchestrator runtime-file tracking policy (check-runtime-file-tracking.sh)"
CURRENT_GATE="gate14"
if [ ! -x "$CLAUDE_DIR/scripts/check-runtime-file-tracking.sh" ] && [ ! -f "$CLAUDE_DIR/scripts/check-runtime-file-tracking.sh" ]; then
  fail "check-runtime-file-tracking.sh not deployed"
else
  runtime_tracking_output=$(cd "$TARGET" && bash "$CLAUDE_DIR/scripts/check-runtime-file-tracking.sh" 2>&1)
  runtime_tracking_status=$?
  if [ "$runtime_tracking_status" -eq 0 ]; then
    pass "runtime-file tracking policy: all three checks passed"
  else
    fail "runtime-file tracking policy reported failures" \
         "re-run for detail: bash .claude/scripts/check-runtime-file-tracking.sh" ""
    if [ "$FINDINGS" = "true" ]; then
      while IFS= read -r runtime_tracking_line; do
        FINDINGS_LIST+=("FINDING gate14 ${runtime_tracking_line#*FAIL }")
      done < <(printf '%s\n' "$runtime_tracking_output" | sed -E 's/\x1b\[[0-9;]*m//g' | grep -E '^  FAIL ')
    fi
  fi
fi

say ""

fi
# ── 15. Lifecycle status-variable regression lint gate ────────────────────────
# Only meaningful in the source-store repo, mirroring gates 6-7/11-12's SKIP-if-not-source-store
# precedent -- a deploy consumer has no agent-system/extensions directory and the gate correctly
# skips there. Runs the SOURCE-STORE copy (REPO_ROOT="$TARGET" override), matching gates 6/7's
# convention rather than gate 9's deployed-tree convention: this lint's own default scan corpus
# is `agent-system/extensions/*/skills/*/SKILL.md` and `agent-system/extensions/*/context/
# patterns/*` -- source-store paths, not deployed ones -- so invoking the deployed copy would
# resolve REPO_ROOT to the wrong depth and silently scan nothing, exactly as gate 6/7's own
# precedent already documents for their scripts.
if gate_selected 15; then
say "15. Lifecycle status-variable lint (lint-lifecycle-status-var.sh --verbose)"
CURRENT_GATE="gate15"
if [ ! -d "$TARGET/agent-system/extensions" ]; then
  say "  [SKIP] $TARGET is a deploy consumer, not the source store -- lifecycle status-variable lint does not apply"
elif [ ! -f "$TARGET/agent-system/extensions/core/scripts/lint/lint-lifecycle-status-var.sh" ]; then
  fail "lint-lifecycle-status-var.sh not found in source store"
else
  lifecycle_status_lint_output=$(cd "$TARGET" && REPO_ROOT="$TARGET" bash "$TARGET/agent-system/extensions/core/scripts/lint/lint-lifecycle-status-var.sh" --verbose 2>&1)
  lifecycle_status_lint_status=$?
  if [ "$lifecycle_status_lint_status" -eq 0 ]; then
    pass "lifecycle status-variable lint reports no violations"
  else
    fail "lifecycle status-variable lint reported violations" \
         "re-run for detail: bash agent-system/extensions/core/scripts/lint/lint-lifecycle-status-var.sh --verbose" ""
    if [ "$FINDINGS" = "true" ]; then
      while IFS= read -r lifecycle_status_lint_line; do
        FINDINGS_LIST+=("FINDING gate15 ${lifecycle_status_lint_line#*VIOLATION\] }")
      done < <(printf '%s\n' "$lifecycle_status_lint_output" | grep -F '[VIOLATION]')
    fi
  fi
fi

say ""

fi
# ── 16. hard_contracts migration warning (non-blocking) ───────────────────────
# routing_hard was retired by the routing-ladder collapse (no manifest declares it any longer;
# this gate's jq check keeps looking for it defensively, in case it ever reappears). The
# surviving block, routing_agents_hard, is itself slated for outright removal once the one
# remaining follow-on (migrating cslib/lean onto hard_contracts) lands -- NOT a migration of
# routing_agents_hard's VALUES onto hard_contracts, which is an unrelated manifest key: it
# resolves the list of behavioral-contract files injected into a --hard dispatch's prompt, never
# a skill or agent name (see context/guides/manifest-routing-schema.md). This gate WARNS, never
# fails: routing_agents_hard remains genuinely consulted by command-route-agent.sh until that
# follow-on lands, so declaring it today is not yet an error -- only a removal-is-coming nudge
# for new/updated extensions.
if gate_selected 16; then
say "16. hard_contracts migration warning (routing_hard/routing_agents_hard)"
CURRENT_GATE="gate16"
gate16_hits=0
for gate16_manifest in "$CLAUDE_DIR"/extensions/*/manifest.json; do
  [ -f "$gate16_manifest" ] || continue
  gate16_ext=$(jq -r '.name // empty' "$gate16_manifest" 2>/dev/null)
  gate16_declares=$(jq -r '(has("routing_hard") or has("routing_agents_hard"))' "$gate16_manifest" 2>/dev/null)
  if [ "$gate16_declares" = "true" ]; then
    gate16_hits=$((gate16_hits + 1))
    warn "${gate16_ext:-$gate16_manifest} still declares routing_hard/routing_agents_hard" \
         "slated for outright removal once the dependent hard-mode work lands -- NOT a migration to hard_contracts, which is unrelated (it resolves injected contract files, not skill or agent names; see context/guides/manifest-routing-schema.md)"
  fi
done
if [ "$gate16_hits" -eq 0 ]; then
  pass "no extension manifest declares routing_hard/routing_agents_hard"
fi
unset gate16_manifest gate16_ext gate16_declares gate16_hits

say ""

fi
# Gate 17: scoped-commit boundary lint (lint-scoped-commit-boundary.sh --verbose)
#
# Same source-store-vs-deploy-consumer [SKIP] posture as the sibling lint gates (6, 7, 9, 11, 12):
# only the source store (agent-system/extensions/core/**) is validated, regardless of which copy
# (source store or deployed .claude/) invoked this script. Invokes the source-store copy
# directly, resolving REPO_ROOT the same way gate 12 does.
if gate_selected 17; then
say "17. Scoped-commit boundary lint (lint-scoped-commit-boundary.sh --verbose)"
CURRENT_GATE="gate17"
if [ ! -d "$TARGET/agent-system/extensions" ]; then
  say "  [SKIP] $TARGET is a deploy consumer, not the source store -- scoped-commit boundary lint does not apply"
elif [ ! -f "$TARGET/agent-system/extensions/core/scripts/lint/lint-scoped-commit-boundary.sh" ]; then
  fail "lint-scoped-commit-boundary.sh not found in source store"
else
  scoped_commit_lint_output=$(cd "$TARGET" && REPO_ROOT="$TARGET" bash "$TARGET/agent-system/extensions/core/scripts/lint/lint-scoped-commit-boundary.sh" --verbose 2>&1)
  scoped_commit_lint_status=$?
  if [ "$scoped_commit_lint_status" -eq 0 ]; then
    pass "scoped-commit boundary lint reports no hand-rolled bare git-commit call sites"
  else
    fail "scoped-commit boundary lint reported hand-rolled bare git-commit call sites" \
         "re-run for detail: bash agent-system/extensions/core/scripts/lint/lint-scoped-commit-boundary.sh --verbose" ""
    if [ "$FINDINGS" = "true" ]; then
      while IFS= read -r scoped_commit_lint_line; do
        FINDINGS_LIST+=("FINDING gate17 ${scoped_commit_lint_line#*VIOLATION\] }")
      done < <(printf '%s\n' "$scoped_commit_lint_output" | grep -F '[VIOLATION]')
    fi
  fi
fi

say ""

fi
# Gate 18: task-lookup adoption lint (lint-task-lookup-adoption.sh --verbose)
#
# Same source-store-vs-deploy-consumer [SKIP] posture as the sibling lint gates (6, 7, 9, 11, 12,
# 17): only the source store (agent-system/extensions/core/**) is validated, regardless of which
# copy (source store or deployed .claude/) invoked this script. Invokes the source-store copy
# directly, resolving REPO_ROOT the same way gate 12 does.
if gate_selected 18; then
say "18. Task-lookup adoption lint (lint-task-lookup-adoption.sh --verbose)"
CURRENT_GATE="gate18"
if [ ! -d "$TARGET/agent-system/extensions" ]; then
  say "  [SKIP] $TARGET is a deploy consumer, not the source store -- task-lookup adoption lint does not apply"
elif [ ! -f "$TARGET/agent-system/extensions/core/scripts/lint/lint-task-lookup-adoption.sh" ]; then
  fail "lint-task-lookup-adoption.sh not found in source store"
else
  task_lookup_lint_output=$(cd "$TARGET" && REPO_ROOT="$TARGET" bash "$TARGET/agent-system/extensions/core/scripts/lint/lint-task-lookup-adoption.sh" --verbose 2>&1)
  task_lookup_lint_status=$?
  if [ "$task_lookup_lint_status" -eq 0 ]; then
    pass "task-lookup adoption lint reports no hand-rolled full-record task-lookup shapes"
  else
    fail "task-lookup adoption lint reported hand-rolled full-record task-lookup shapes" \
         "re-run for detail: bash agent-system/extensions/core/scripts/lint/lint-task-lookup-adoption.sh --verbose" ""
    if [ "$FINDINGS" = "true" ]; then
      while IFS= read -r task_lookup_lint_line; do
        FINDINGS_LIST+=("FINDING gate18 ${task_lookup_lint_line#*VIOLATION\] }")
      done < <(printf '%s\n' "$task_lookup_lint_output" | grep -F '[VIOLATION]')
    fi
  fi
fi

say ""

fi
# Gate 19: branch-gated section threshold lint (lint-branch-gated-sections.sh --verbose)
#
# Same source-store-vs-deploy-consumer [SKIP] posture as the sibling lint gates (6, 7, 9, 11, 12,
# 17, 18): only the source store (agent-system/extensions/core/**) is validated, regardless of
# which copy (source store or deployed .claude/) invoked this script. Invokes the source-store
# copy directly, resolving REPO_ROOT the same way gate 18 does.
if gate_selected 19; then
say "19. Branch-gated section threshold lint (lint-branch-gated-sections.sh --verbose)"
CURRENT_GATE="gate19"
if [ ! -d "$TARGET/agent-system/extensions" ]; then
  say "  [SKIP] $TARGET is a deploy consumer, not the source store -- branch-gated section threshold lint does not apply"
elif [ ! -f "$TARGET/agent-system/extensions/core/scripts/lint/lint-branch-gated-sections.sh" ]; then
  fail "lint-branch-gated-sections.sh not found in source store"
else
  branch_gated_lint_output=$(cd "$TARGET" && REPO_ROOT="$TARGET" bash "$TARGET/agent-system/extensions/core/scripts/lint/lint-branch-gated-sections.sh" --verbose 2>&1)
  branch_gated_lint_status=$?
  if [ "$branch_gated_lint_status" -eq 0 ]; then
    pass "branch-gated section threshold lint reports no marked-but-unextracted sections over threshold"
  else
    fail "branch-gated section threshold lint reported marked-but-unextracted sections over threshold" \
         "re-run for detail: bash agent-system/extensions/core/scripts/lint/lint-branch-gated-sections.sh --verbose" ""
    if [ "$FINDINGS" = "true" ]; then
      while IFS= read -r branch_gated_lint_line; do
        FINDINGS_LIST+=("FINDING gate19 ${branch_gated_lint_line#*VIOLATION\] }")
      done < <(printf '%s\n' "$branch_gated_lint_output" | grep -F '[VIOLATION]')
    fi
  fi
fi

say ""

fi
# Gate 20: orchestrator context budget lock (measure-eager-context.sh --check + per-file ceilings)
#
# Same source-store-vs-deploy-consumer [SKIP] posture as the sibling lint gates (6, 7, 9, 11, 12,
# 17, 18, 19): only the source store (agent-system/extensions/core/**) is measured, regardless of
# which copy (source store or deployed .claude/) invoked this script -- matching
# measure-eager-context.sh's own "predict from source store, never read the deploy tree" policy.
#
# Three independent sub-checks, each with its own severity (see the ORCHESTRATOR_BUDGET_GATE_MODE
# comment above for the rationale):
#   A. volatile-file hits (measure-eager-context.sh --check's own exit code) -- unconditional
#      fail(), regardless of ORCHESTRATOR_BUDGET_GATE_MODE.
#   B. eager-load regression (live TOTAL vs. eager_load.baseline_bytes) -- fail() always; the
#      current measured value is comfortably under baseline, so this ships at fail() tier from
#      day one (research Decision 3).
#   C. per-file ceilings (commands/orchestrate.md, skills/skill-orchestrate/SKILL.md vs. their
#      configured ceiling_bytes) -- warn() in "warn" mode (the default), fail() in "hard" mode.
#
# NORMALIZED FINDING TEXT (hard constraint): every warn()/fail() call below passes a value-free
# 3rd argument -- no byte counts, no timestamps. This is load-bearing: the inter-cycle redeploy
# checkpoint (skill-orchestrate Stage MT-3 step 7) diffs --findings output across redeploys via
# deploy_findings_snapshot/deploy_baseline_new_findings, and a finding whose text embeds a live
# byte count would register as a "new finding" on every single redeploy even when nothing
# meaningfully changed -- spuriously tripping defer_reason:"deploy_checkpoint" for every
# remaining task in a batch. Live numbers are printed unconditionally via say() below instead, so
# drift direction stays visible without polluting --findings output.
if gate_selected 20; then
say "20. Orchestrator context budget lock (measure-eager-context.sh --check + per-file ceilings)"
CURRENT_GATE="gate20"
BUDGET_CONFIG="$TARGET/agent-system/extensions/core/context/config/orchestrator-context-budget.json"
if [ ! -d "$TARGET/agent-system/extensions" ]; then
  say "  [SKIP] $TARGET is a deploy consumer, not the source store -- orchestrator context budget lock does not apply"
elif [ ! -f "$BUDGET_CONFIG" ]; then
  fail "orchestrator-context-budget.json not found in source store" \
       "expected at agent-system/extensions/core/context/config/orchestrator-context-budget.json"
elif [ ! -f "$TARGET/agent-system/extensions/core/scripts/measure-eager-context.sh" ]; then
  fail "measure-eager-context.sh not found in source store"
elif ! command -v jq >/dev/null 2>&1; then
  fail "jq unavailable; cannot read orchestrator-context-budget.json"
else
  eager_output=$(cd "$TARGET" && REPO_ROOT="$TARGET" bash "$TARGET/agent-system/extensions/core/scripts/measure-eager-context.sh" --check 2>&1)
  eager_status=$?

  # Sub-check A: volatile-file hits -- unconditional fail(), independent of gate mode.
  if [ "$eager_status" -ne 0 ]; then
    fail "measure-eager-context.sh --check reported volatile-file hit(s)" \
         "re-run for detail: bash agent-system/extensions/core/scripts/measure-eager-context.sh --check" \
         "orchestrator context budget: volatile-file hit in the eager-load set"
  else
    pass "measure-eager-context.sh --check: no volatile-file hits"
  fi

  eager_total=$(printf '%s\n' "$eager_output" | grep -oE '^TOTAL: [0-9]+ B' | grep -oE '[0-9]+')
  baseline_bytes=$(jq -r '.eager_load.baseline_bytes' "$BUDGET_CONFIG" 2>/dev/null)

  # Sub-check B: eager-load regression -- fail() always (current value is under baseline).
  if [ -z "$eager_total" ]; then
    fail "could not parse TOTAL line from measure-eager-context.sh --check output" \
         "" "orchestrator context budget: eager-load total unparseable"
  elif [ -z "$baseline_bytes" ] || [ "$baseline_bytes" = "null" ]; then
    fail "orchestrator-context-budget.json missing eager_load.baseline_bytes" \
         "" "orchestrator context budget: config missing eager_load.baseline_bytes"
  elif [ "$eager_total" -gt "$baseline_bytes" ]; then
    fail "eager-load total ($eager_total B) exceeds recorded baseline ($baseline_bytes B)" \
         "re-derive only if the growth is deliberate and reviewed" \
         "orchestrator context budget: eager-load total over baseline"
  else
    pass "eager-load total ($eager_total B) within baseline ($baseline_bytes B)"
  fi

  # Sub-check C: per-file ceilings -- severity from ORCHESTRATOR_BUDGET_GATE_MODE.
  budget_files=$(jq -r '.files | keys[]' "$BUDGET_CONFIG" 2>/dev/null)
  while IFS= read -r rel_path; do
    [ -n "$rel_path" ] || continue
    ceiling=$(jq -r --arg p "$rel_path" '.files[$p].ceiling_bytes' "$BUDGET_CONFIG" 2>/dev/null)
    file_path="$TARGET/agent-system/extensions/core/$rel_path"
    if [ ! -f "$file_path" ]; then
      fail "$rel_path not found in source store" "" "orchestrator context budget: $rel_path missing"
      continue
    fi
    actual_bytes=$(wc -c < "$file_path" | tr -d ' ')
    if [ "$actual_bytes" -gt "$ceiling" ]; then
      if [ "$ORCHESTRATOR_BUDGET_GATE_MODE" = "hard" ]; then
        fail "$rel_path ($actual_bytes B) exceeds its configured ceiling ($ceiling B)" \
             "ORCHESTRATOR_BUDGET_GATE_MODE=hard" \
             "orchestrator context budget: $rel_path over ceiling"
      else
        warn "$rel_path ($actual_bytes B) exceeds its configured ceiling ($ceiling B)" \
             "ORCHESTRATOR_BUDGET_GATE_MODE=warn (default) -- promote to hard once trimmed" \
             "orchestrator context budget: $rel_path over ceiling"
      fi
    else
      pass "$rel_path ($actual_bytes B) within ceiling ($ceiling B)"
    fi
  done <<< "$budget_files"

  # Live figures printed unconditionally so drift direction is visible without a byte count ever
  # entering --findings output (see the NORMALIZED FINDING TEXT comment above).
  say ""
  say "  orchestrator context budget (live):"
  say "    eager load: ${eager_total:-?} B / baseline ${baseline_bytes:-?} B (mode: $ORCHESTRATOR_BUDGET_GATE_MODE for per-file ceilings)"
  while IFS= read -r rel_path; do
    [ -n "$rel_path" ] || continue
    ceiling=$(jq -r --arg p "$rel_path" '.files[$p].ceiling_bytes' "$BUDGET_CONFIG" 2>/dev/null)
    file_path="$TARGET/agent-system/extensions/core/$rel_path"
    if [ -f "$file_path" ]; then
      actual_bytes=$(wc -c < "$file_path" | tr -d ' ')
      if [ "$actual_bytes" -gt "$ceiling" ]; then marker="OVER"; else marker="under"; fi
      say "    $rel_path: $actual_bytes B / ceiling $ceiling B ($marker)"
    fi
  done <<< "$budget_files"
fi

say ""
fi
if [ "$FAILURES" -eq 0 ]; then
  echo "[verify-deploy] PASS -- $CHECKS check(s), 0 failure(s)"
  say ""
  say "NOTE: this verifies DEPLOYMENT only. Confirming that events actually flow requires real"
  say "command invocations afterwards -- inspect specs/events.jsonl for artifact_write,"
  say "subagent_stop, and session_stop lines postdating the deploy."
  if [ "$FINDINGS" = "true" ] && [ "${#FINDINGS_LIST[@]}" -gt 0 ]; then
    printf '%s\n' "${FINDINGS_LIST[@]}" | sort -u
  fi
  exit 0
fi

echo "[verify-deploy] FAIL -- $FAILURES of $CHECKS check(s) failed" >&2
if [ "$FINDINGS" = "true" ] && [ "${#FINDINGS_LIST[@]}" -gt 0 ]; then
  printf '%s\n' "${FINDINGS_LIST[@]}" | sort -u
fi
exit 1
