#!/usr/bin/env bash
# test-handoff-reader-parity.sh - Reader presence/correctness suite for the handoff fields both
# /orchestrate engines consume. Builds ONE shared .orchestrator-handoff.json fixture, extracts
# the literal jq filter strings the current implementation actually ships for each field, and
# asserts each filter is present and produces the expected value against the shared fixture.
#
# RETARGETED (Phase 7 of the task that built orchestrate-cycle-postflight.sh): the
# `dispatch_status`/`dispatch_summary`/`phases_completed`/`phases_total`/`plan_markers_verified`/
# `artifacts[0].*` reads this suite used to extract from skill-orchestrate/SKILL.md's own Stage 5
# now live inside `orchestrate-cycle-postflight.sh` (the single shared per-cycle postflight
# script both engines call) -- extraction for those fields is retargeted at `$SCRIPT_FILE`
# accordingly. `blockers` still lives in SKILL.md's own Stage 5 (a caller-side re-derivation
# `orchestrate-cycle-postflight.sh`'s compact JSON output does not carry -- see
# docs/architecture/orchestrate-cycle-postflight.md), so its extraction stays targeted at
# `$SKILL_FILE`, unchanged in form. `next_action_hint`/`continuation` are RETIRED from this
# suite: neither field has a live reader in either file any more (verified by inspection --
# Stage 4's OWN independent continuation-normalization read, for the NEXT cycle's dispatch
# context, is a structurally different mechanism reading the handoff fresh from disk, not a
# consumer of Stage 5's old `continuation`/`next_hint` variables, which had no downstream
# consumer even before this cutover). The hard_mode-only fields (.skeleton, .sorry_inventory,
# .blockers[0].target/.verbatim_goal) are UNCHANGED -- they live in Stage 4's H1 branch and
# Stage 5b, neither of which Phase 7 touched, so their extraction stays targeted at
# `$SKILL_FILE` exactly as before.
#
# Structural model: scripts/tests/test-validate-handoff.sh / test-corroborate-phase-counts.sh
# (mktemp -d workdir with an EXIT-trap cleanup, source-store-first candidate resolution for the
# files under active development, pass()/fail()/info() helpers with integer counters,
# exit 0 all-pass / 1 any-fail / 2 environment error).
#
# Why extraction, not hand-copied jq: hand-copying the filter strings into this test would not
# catch drift if a future editor changes the actual read without updating this test to match --
# the whole point of extraction is proving the SHIPPED file's actual filter still does what this
# test expects, not that this test agrees with itself. Extraction is anchored on stable,
# already-unique surrounding text (verified via grep -c == 1 at authoring time) rather than raw
# line numbers, so it survives ordinary prose edits elsewhere in either file.
#
# Exit codes: 0 -- all cases PASS; 1 -- at least one case FAILED; 2 -- environment error (a
# required file was not found at any candidate path).

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# REPO_ROOT resolution must work from BOTH invocation sites this suite supports: the
# source-store copy (agent-system/extensions/core/scripts/tests/) and the deployed copy
# (.claude/scripts/tests/), which sit at different depths below the repo root. A single
# fixed levels-up count cannot be correct for both depths at once, so resolve via the git
# worktree root first (depth-independent) and only fall back to the fixed-depth guess
# (matching the source-store depth) when SCRIPT_DIR is not inside a git work tree.
REPO_ROOT="$(cd "$SCRIPT_DIR" && git rev-parse --show-toplevel 2>/dev/null)"
if [[ -z "$REPO_ROOT" ]]; then
  REPO_ROOT="$(cd "$SCRIPT_DIR/../../../../.." && pwd)"
fi

# Source-store-first (see test-validate-handoff.sh's identical rationale): this suite exercises
# the SKILL.md files under active development, which live in the source store before a redeploy
# copies them to the deploy tree. After redeploy the two are identical, so either order then
# yields the same result.
resolve_candidate() {
  local relative="$1" candidate
  for candidate in "$SCRIPT_DIR/../../$relative" "$REPO_ROOT/.claude/$relative"; do
    if [[ -f "$candidate" ]]; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done
  return 1
}

SKILL_FILE="$(resolve_candidate "skills/skill-orchestrate/SKILL.md")" || {
  echo "ERROR: skill-orchestrate/SKILL.md not found (source store or deploy tree)" >&2
  exit 2
}
SCRIPT_FILE_CANDIDATES=(
  "$SCRIPT_DIR/../orchestrate-cycle-postflight.sh"
  "$REPO_ROOT/.claude/scripts/orchestrate-cycle-postflight.sh"
)
SCRIPT_FILE=""
for candidate in "${SCRIPT_FILE_CANDIDATES[@]}"; do
  if [[ -f "$candidate" ]]; then
    SCRIPT_FILE="$candidate"
    break
  fi
done
if [[ -z "$SCRIPT_FILE" ]]; then
  echo "ERROR: orchestrate-cycle-postflight.sh not found at any candidate path" >&2
  exit 2
fi
VALIDATOR_CANDIDATES=(
  "$SCRIPT_DIR/../validate-handoff.sh"
  "$REPO_ROOT/.claude/scripts/validate-handoff.sh"
)
VALIDATOR=""
for candidate in "${VALIDATOR_CANDIDATES[@]}"; do
  if [[ -f "$candidate" ]]; then
    VALIDATOR="$candidate"
    break
  fi
done
if [[ -z "$VALIDATOR" ]]; then
  echo "ERROR: validate-handoff.sh not found at any candidate path" >&2
  exit 2
fi

PASSED=0
FAILED=0

pass() { echo "[PASS] $1"; PASSED=$((PASSED + 1)); }
fail() { echo "[FAIL] $1"; FAILED=$((FAILED + 1)); }
info() { echo "[INFO] $1"; }

WORKDIR="$(mktemp -d)"
cleanup() { [ -n "${WORKDIR:-}" ] && [ -d "$WORKDIR" ] && rm -rf "$WORKDIR"; }
trap cleanup EXIT

# ── Shared fixture: ONE handoff satisfying the validator AND both readers ──────────────────────
# Rich enough to exercise every field either engine reads, including the hard-only extras.
FIXTURE="$WORKDIR/shared-handoff.json"
cat > "$FIXTURE" << 'EOF'
{
  "status": "implemented",
  "summary": "Completed all phases with one tracked strategic sorry and one historical blocker entry.",
  "artifacts": [
    {"type": "summary", "path": "specs/000_x/summaries/01_x-summary.md", "summary": "Partial summary"}
  ],
  "phases_completed": 1,
  "phases_total": 3,
  "blockers": [
    {
      "phase": 2,
      "target": "example-target.sh",
      "verbatim_goal": "example verbatim goal text",
      "what_was_tried": "attempted approach",
      "why_it_failed": "reason it failed"
    }
  ],
  "continuation_path": "specs/000_x/handoffs/phase-1-handoff-20260101T000000Z.md",
  "next_action_hint": "implement",
  "plan_markers_verified": true,
  "skeleton": true,
  "sorry_inventory": [
    {
      "file": "path/to/File.lean",
      "line": 1,
      "statement": "theorem foo : ...",
      "strategic": true,
      "assumption": "assumption text",
      "why_deferred": "deferred reason",
      "follow_up_task": "999"
    }
  ]
}
EOF

if bash "$VALIDATOR" "$FIXTURE" >"$WORKDIR/validator.out" 2>&1; then
  pass "Shared fixture passes validate-handoff.sh -- one schema satisfies validator and both readers"
else
  fail "Shared fixture failed validate-handoff.sh -- see $WORKDIR/validator.out"
  cat "$WORKDIR/validator.out"
fi

# ── extract_jq_filter <file> <anchor_pattern> <var_name> ───────────────────────────────────────
# Locates the unique line assigning var_name from `$handoff` via jq inside the window starting at
# the first line matching anchor_pattern (grep -A80), and prints the filter string between the
# outer single quotes. Fails (empty output) if not found -- callers must check for empty.
extract_jq_filter() {
  local file="$1" anchor="$2" var="$3"
  grep -A80 -F -- "$anchor" "$file" \
    | grep -P "^\s*${var}=\\\$\(echo \"\\\$handoff\" \| jq -[rc] '" \
    | head -1 \
    | grep -oP "jq -[rc] '\K[^']*(?=')"
}

# Anchor: the comment immediately preceding orchestrate-cycle-postflight.sh's handoff-present
# field-read block (Phase 7 retarget -- these reads used to live inline in skill-orchestrate/
# SKILL.md's own Stage 5). Verified unique (grep -c == 1) in the script.
ANCHOR='─── Handoff-present path ───'

# Fields the script's handoff-present block extracts. Each field's EXPECTED value is derived from
# the shared fixture above by hand, once, at authoring time (not re-derived from the filter under
# test -- that would make the assertion vacuous). `next_action_hint`/`continuation` are
# deliberately absent -- retired, see this file's header comment.
SHARED_FIELDS=(dispatch_status dispatch_summary phases_completed phases_total plan_markers_verified)
declare -A SHARED_FIELD_EXPECTED=(
  [dispatch_status]="implemented"
  [dispatch_summary]="Completed all phases with one tracked strategic sorry and one historical blocker entry."
  [phases_completed]="1"
  [phases_total]="3"
  [plan_markers_verified]="true"
)

for field in "${SHARED_FIELDS[@]}"; do
  filter="$(extract_jq_filter "$SCRIPT_FILE" "$ANCHOR" "$field")"
  if [[ -z "$filter" ]]; then
    fail "$field: could not extract jq filter from orchestrate-cycle-postflight.sh"
    continue
  fi
  val="$(jq -r "$filter" "$FIXTURE" 2>/dev/null)"
  expected="${SHARED_FIELD_EXPECTED[$field]}"
  if [[ "$val" == "$expected" ]]; then
    pass "$field: filter ('$filter') present and produces the expected value ('$val') against the shared fixture"
  else
    fail "$field: filter present but value diverges -- got='$val' expected='$expected'"
  fi
done

# ── blockers: RETARGETED (the four-move loop rewrite deleted the single-task engine and its own
# Stage 5 caller-side re-derivation -- see docs/architecture/orchestrate-state-machine.md). The
# read now lives directly inside orchestrate-cycle-postflight.sh's own H5/H6 churn-detection
# block (`churn_blockers_json`), which is the SAME script SCRIPT_FILE already resolves for the
# SHARED_FIELDS/artifacts checks above -- there is no second file to target any more. Anchored on
# the comment immediately preceding that read (verified unique, grep -c == 1, in the script).
BLOCKERS_ANCHOR="H6/H5 (Decision 3): the churn signature"
blockers_filter="$(extract_jq_filter "$SCRIPT_FILE" "$BLOCKERS_ANCHOR" "churn_blockers_json")"
if [[ -z "$blockers_filter" ]]; then
  fail "blockers: could not extract jq filter from orchestrate-cycle-postflight.sh"
else
  blockers_expected='[{"phase":2,"target":"example-target.sh","verbatim_goal":"example verbatim goal text","what_was_tried":"attempted approach","why_it_failed":"reason it failed"}]'
  # blockers is a jq -c array; compare parsed JSON structurally, not as a raw string, so key
  # ordering in the filter's own output can't cause a spurious mismatch.
  blockers_val_c="$(jq -c "$blockers_filter" "$FIXTURE" 2>/dev/null)"
  if [[ "$(jq -c -e --argjson a "$blockers_val_c" --argjson b "$blockers_expected" -n '$a == $b' 2>/dev/null)" == "true" ]]; then
    pass "blockers: filter ('$blockers_filter') present and produces the expected value against the shared fixture"
  else
    fail "blockers: filter present but value diverges from expected -- got='$blockers_val_c' expected='$blockers_expected'"
  fi
fi

# `next_action_hint`/`continuation` (dual-form resolution): RETIRED from this suite as of Phase 7
# -- neither field has a live reader in either file any more. See this file's header comment for
# the full reasoning (Stage 4's own, structurally distinct continuation-normalization read is
# unaffected and untested here by design -- it was never this suite's subject).

# ── artifacts[0].{path,type,summary}: presence + expected value against the shared fixture ─────
# Phase 7 retarget: these now live in orchestrate-cycle-postflight.sh's handoff-present block
# (same $ANCHOR as SHARED_FIELDS above), under the variable names `artifact_path`/`artifact_type`/
# `artifact_summary` -- NOT `handoff_artifact_*`, which was skill-orchestrate/SKILL.md's own old
# naming for the same values before this cutover.
declare -A ARTIFACT_SUB_EXPECTED=(
  [path]="specs/000_x/summaries/01_x-summary.md"
  [type]="summary"
  [summary]="Partial summary"
)
for sub in path type summary; do
  var="artifact_${sub}"
  filter="$(extract_jq_filter "$SCRIPT_FILE" "$ANCHOR" "$var")"
  if [[ -z "$filter" ]]; then
    fail "artifacts[0].$sub: could not extract from orchestrate-cycle-postflight.sh"
    continue
  fi
  val="$(jq -r "$filter" "$FIXTURE" 2>/dev/null)"
  expected="${ARTIFACT_SUB_EXPECTED[$sub]}"
  if [[ "$val" == "$expected" ]]; then
    pass "artifacts[0].$sub: filter present and produces the expected value ('$val') against the shared fixture"
  else
    fail "artifacts[0].$sub: filter present but value diverges -- got='$val' expected='$expected'"
  fi
done

# ── hard_mode-only allowlisted fields: extraction succeeds and produces the expected value ──────
# against the shared fixture. NOT compared against a second engine -- there is only one engine
# now, and these fields are never read on the base-mode path by design (H5 divergence audit
# routing and blocked-escalation blocker_desc are hard_mode-only concerns).

# RETIRED, RECORDED (not silently dropped): .skeleton (as last_skeleton) and .sorry_inventory
# (inlined into follow_up_tasks) lived EXCLUSIVELY in single-task Stage 4's hard_mode-gated
# per-phase-dispatch (H1) branch -- the Lean/formal skeleton-plan completion path
# (pr_ready postflight, completion-summary propagation, .dispatch/loop-guard cleanup,
# EXIT (success)). `orchestrate-cycle-plan.sh`'s own H1 port (built before this task, porting
# single-task features into the batch engine) explicitly named this branch as a KNOWN,
# OUT-OF-SCOPE GAP rather than a silent omission: "a hard-mode skeleton plan routed through the
# batch engine today falls through to the 'no open heading' branch below (ordinary dispatch)
# rather than the single-task engine's specialized skeleton-completion handling" (see that
# script's own H1 comment block, "Scope Hypothesis confirmation" paragraph). This task's deletion
# of single-task Stage 4 removes the LAST reachable copy of that already-acknowledged gap's code
# -- there is no batch-engine equivalent to retarget onto, and porting one is new script behavior
# this task's own Non-Goals put out of scope ("Changing any decision the three cycle scripts
# make... script behavior is out of scope except for the additive .decisions.json read path").
# Recorded here, loudly, as a genuine capability loss for a hard-mode Lean/formal skeleton plan
# (not a false pass and not a silent test deletion): a future task should decide whether to port
# skeleton-completion routing into orchestrate-cycle-plan.sh's own H1 section.

# .blockers[0].target / .blockers[0].verbatim_goal: RETARGETED. Stage 5b's own read (against
# `$handoff` directly) is gone along with the deleted single-task engine; the SAME two field
# reads now live inside `orchestrate-churn.sh` (called by orchestrate-cycle-postflight.sh's H5/H6
# block above), operating on the caller's already-extracted `$blockers_json` (== the handoff's
# `.blockers` array) rather than `$handoff` directly -- so the composed full-fixture equivalent
# is `.blockers | (<extracted filter>)`.
blocker_target_filter="$(grep -oP "blocker_target=\\\$\(echo \"\\\$blockers_json\" \| jq -r '\K[^']*(?=')" "$SCRIPT_DIR/../orchestrate-churn.sh" | head -1)"
if [[ -n "$blocker_target_filter" ]]; then
  val="$(jq -r ".blockers | ($blocker_target_filter)" "$FIXTURE" 2>/dev/null)"
  if [[ "$val" == "example-target.sh" ]]; then
    pass "hard_mode-only allowlisted: .blockers[0].target (orchestrate-churn.sh H5/H6 churn detection) extracts 'example-target.sh' from the shared fixture"
  else
    fail "hard_mode-only allowlisted: .blockers[0].target unexpected value '$val'"
  fi
else
  fail "hard_mode-only allowlisted: could not extract .blockers[0].target filter from orchestrate-churn.sh"
fi

verbatim_goal_filter="$(grep -oP "verbatim_goal=\\\$\(echo \"\\\$blockers_json\" \| jq -r '\K[^']*(?=')" "$SCRIPT_DIR/../orchestrate-churn.sh" | head -1)"
if [[ -n "$verbatim_goal_filter" ]]; then
  val="$(jq -r ".blockers | ($verbatim_goal_filter)" "$FIXTURE" 2>/dev/null)"
  if [[ "$val" == "example verbatim goal text" ]]; then
    pass "hard_mode-only allowlisted: .blockers[0].verbatim_goal (orchestrate-churn.sh H5/H6 churn detection) extracts the expected text from the shared fixture"
  else
    fail "hard_mode-only allowlisted: .blockers[0].verbatim_goal unexpected value '$val'"
  fi
else
  fail "hard_mode-only allowlisted: could not extract .blockers[0].verbatim_goal filter from orchestrate-churn.sh"
fi

# ── Every extracted field name must appear in the schema's properties (grep-audit lock-in) ─────
SCHEMA_CANDIDATES=(
  "$SCRIPT_DIR/../../context/schemas/orchestrator-handoff-schema.json"
  "$REPO_ROOT/.claude/context/schemas/orchestrator-handoff-schema.json"
)
SCHEMA=""
for candidate in "${SCHEMA_CANDIDATES[@]}"; do
  if [[ -f "$candidate" ]]; then
    SCHEMA="$candidate"
    break
  fi
done
if [[ -z "$SCHEMA" ]]; then
  fail "schema file not found at any candidate path -- cannot lock in field-name audit"
else
  schema_props="$(jq -r '.properties | keys[]' "$SCHEMA" 2>/dev/null)"
  # Top-level field names read by either engine (sub-field paths like artifacts[0].path and
  # blockers[0].target collapse to their top-level property names: artifacts, blockers).
  AUDITED_FIELDS=(status summary artifacts blockers phases_completed phases_total plan_markers_verified skeleton sorry_inventory next_action_hint continuation_path continuation_context)
  audit_ok=true
  for f in "${AUDITED_FIELDS[@]}"; do
    if ! grep -qx -- "$f" <<< "$schema_props"; then
      fail "grep-audit: field '$f' is read by a reader but absent from schema properties"
      audit_ok=false
    fi
  done
  if [[ "$audit_ok" == "true" ]]; then
    pass "grep-audit: all ${#AUDITED_FIELDS[@]} reader-referenced field names appear in schema properties"
  fi
fi

# dispatch_seq Stage 5 gate parity (Defect A) -- REMOVED. This block used to extract the
# `dispatch-seq-gate:begin`/`:end` sentinel region from both engines and diff them for
# byte-equality. With one merged engine, that comparison would extract the SAME region from the
# SAME file twice and diff it against itself -- a vacuous, always-green no-op, not a real parity
# check. The real coverage for this gate (including its dispatch_seq-mismatch behavioral cases,
# not just a structural diff) already lives in test-handoff-dispatch-identity.sh, which exercises
# the extracted region directly against fixtures. Removed deliberately here rather than left as a
# silently-passing no-op.

# ── Summary ──────────────────────────────────────────────────────────────────────────────────
info "Engine resolved to:    $SKILL_FILE"
info "Validator resolved to: $VALIDATOR"
echo ""
echo "========================================"
echo "test-handoff-reader-parity.sh Summary"
echo "========================================"
echo "Passed: $PASSED"
echo "Failed: $FAILED"

if [[ "$FAILED" -gt 0 ]]; then
  exit 1
fi
exit 0
