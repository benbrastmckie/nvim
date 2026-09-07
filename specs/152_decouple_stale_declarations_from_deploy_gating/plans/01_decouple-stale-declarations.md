# Implementation Plan: Decouple stale declarations from deploy gating

- **Task**: 152 - Decouple stale declarations from deploy gating
- **Status**: [IMPLEMENTING]
- **Effort**: 7 hours
- **Dependencies**: None (a sibling task fixes the two live `line_count` gate failures; this task
  addresses the defect class)
- **Research Inputs**: `specs/152_decouple_stale_declarations_from_deploy_gating/reports/01_decouple-stale-declarations.md`
- **Artifacts**: plans/01_decouple-stale-declarations.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md,
  source-store-deploy-boundary.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Three stale hand-maintained `line_count` integers stalled an entire `/orchestrate` batch because
four mechanisms are coupled end-to-end: Rule R fails on drift, `verify-deploy.sh` gate 3 fails,
`deploy-headless.sh` exits 3, and `orchestrate-cycle-plan.sh`'s inter-cycle redeploy checkpoint
treats any non-zero deploy exit as an unconditional whole-batch defer. This plan cuts the coupling
at two independent points: (a) `line_count` stops being hand-maintained — every deploy repairs it
from `wc -l` first and reports what it repaired, so drift cannot reach Rule R silently; and (b) the
checkpoint's already-built pre-existing-baseline tolerance is made reachable on `deploy-headless.sh`
exit 3, by extracting the working (a)/(b)/(c) split that `command-gate-out.sh` already implements
into a shared library and sourcing it at both call sites. Done means: a `line_count` drift is
auto-repaired and announced rather than blocking; a pre-existing red gate lets the batch proceed
with a recorded notice; a newly-introduced failure still defers the batch; and a caller can tell
"deploy did not land" from "deploy landed, gate red" from "consumer repos stale".

### Research Integration

The research report is integrated as follows, and materially changed three design choices:

- **`line_count` is consumed, not display-only.** `validate-context-budgets.sh`,
  `validate-index.sh`, `validate-context-index.sh` and `install-extension.sh` (the last with a
  `.line_count // 100` fallback) all read it for token-budget math. Dispatch option (iii) "drop
  it" is therefore **rejected on evidence**, exactly as the dispatch instructed it be checked
  before choosing. The field stays declared and git-tracked.
- **No new counting logic is needed.** `generate-context-line-counts.sh` already implements the
  `--check`/`--write` `wc -l` regenerator against the SOURCE `index-entries.json`, with a
  deliberate surgical line-oriented substitution (no `jq` round-trip) to keep diffs reviewable.
  Phase 5 wires the existing script rather than writing a second implementation.
- **The (b) fix already exists in this codebase and only needs porting.**
  `command-gate-out.sh`'s `rc == 6` handler implements the exact three-branch contract
  (`deploy_rc -eq 1 || -eq 2` → unconditional refuse; else → pre/post `comm -13` baseline →
  refuse-on-new / proceed-loudly-on-pre-existing), including the exit-2 sentinel folding. The
  checkpoint in `orchestrate-cycle-plan.sh` is the one call site that never caught up.
- **The third confound does not reproduce from static reading.** `deploy-headless.sh`'s
  `check-consumer-freshness.sh --stale-only` call is fully `|| true`-guarded and its result never
  touches `verify_rc` or the single trailing `exit "$verify_rc"`. The research recommended
  confirming this at runtime before designing a fix; Phase 4 does exactly that and branches on the
  answer instead of assuming either outcome.

Two findings this plan adds on top of the research, both verified during planning:

- **The checkpoint also lacks the documented exit-2 sentinel.** Its `pre_raw`/`post_raw` captures
  discard `verify-deploy.sh`'s exit code entirely (`if pre_raw=$(...); then :; fi`), so an exit-2
  "cannot run" produces an empty finding set rather than the `FINDING gate0 [SENTINEL] ...` line
  `batch-orchestration-guardrails.md`'s "Exit-2 resolution" rule requires. Porting the helper
  closes this second, smaller divergence at the same time as the main one.
- **`orchestrate-cycle-postflight.sh` does populate `cycle_modified_files`.** The comment above
  the checkpoint in `orchestrate-cycle-plan.sh` claiming it is "always a no-op today until the
  future postflight composer starts populating cycle_modified_files" is stale — the composer
  landed. The checkpoint is live, which is consistent with the observed batch stall, and the
  stale comment must be corrected in Phase 2 so the next reader does not dismiss this code path
  as dead.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No ROADMAP.md found at `specs/ROADMAP.md`; no roadmap phases are included and no roadmap items
are claimed.

## Goals & Non-Goals

**Goals**:

- A `line_count` drift cannot silently block a gate: every deploy repairs it from `wc -l` before
  Rule R evaluates, and every repair is reported (never silent), honoring the
  `validate-artifact.sh --fix` / D-A auto-repair-reporting precedent.
- `orchestrate-cycle-plan.sh`'s redeploy checkpoint implements the same three-branch failure
  contract `batch-orchestration-guardrails.md` already documents and `command-gate-out.sh`
  already implements, so a pre-existing unrelated red gate no longer defers a whole batch.
- The two call sites of that contract share ONE sourced implementation, so they cannot drift
  apart again.
- `deploy-headless.sh`'s three confounded outcomes — deploy did not land / deploy landed with a
  red gate / consumer repos stale — are distinguishable by a caller without parsing prose.
- The documentation that describes these contracts matches the code after this task.

**Non-Goals**:

- Removing `line_count` from the `index-entries.json` schema, or teaching `merge.lua` to
  recompute it at upsert time. Both are rejected: the field has four real consumers, and a
  merge-time derivation would only cover loaded extensions while Rule R is deliberately a
  SOURCE-level check that fires for unloaded extensions too.
- Making any gate non-blocking wholesale, or lowering `INDEX_TRUTH_GATE_MODE` from `hard`. A
  genuinely broken deploy, and a genuinely new finding, must still stop the batch.
- Changing `update-task-status.sh`'s exit-6 completion-deploy gate semantics. Research confirmed
  it is a per-task, path-scoped freshness check that already behaves correctly; it is a sibling
  mechanism, not this defect.
- Fixing the three specific stale declarations named in the dispatch. A sibling task owns those
  instances; this task owns the class.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Self-modification ordering gate: `orchestrate-cycle-plan.sh` and `verify-deploy.sh` are registered orchestrator-critical paths, so this task's own implementation trips the admission gate and the redeploy checkpoint it is editing | H | H | Expect single-candidate-per-cycle admission; do not co-schedule with another self-modifying task. Verify each checkpoint edit against a scratch deploy-tree copy per the hazard-1 contract, not only in place |
| Bootstrapping: the checkpoint fix cannot protect the batch that installs it — the old unconditional-defer code is what runs during its own landing cycle | M | H | Accept and state it. Land Phase 2 as its own scoped commit and redeploy before relying on the new behavior; the acceptance demonstrations in Phase 7 run against the deployed tree, after the redeploy, not before |
| Auto-repair dirties the working tree at a surprising moment (mid-unrelated-edit deploy) | M | M | Only ever write inside the explicit, announced deploy step — never inside a bare read-only lint path — and echo every corrected entry plus a total. Rule R keeps failing loudly for the one case that cannot be auto-repaired (missing source file) |
| `deploy-headless.sh` runs in consumer repos that have no `agent-system/extensions/` tree, where the regenerator exits 1 | M | H | Guard the repair call on `[ -d "$TARGET/agent-system/extensions" ]` and make its absence a silent, documented no-op, matching `check-consumer-freshness.sh`'s own guard convention in the same script |
| Extracting a shared library changes behavior at the already-working `command-gate-out.sh` site | M | L | Phase 1 ports the helper verbatim in behavior and adds unit tests before Phase 3 swaps the call site; Phase 3 is a pure substitution with no semantic change |
| `events-append.sh` requires `--session`, which `deploy-headless.sh` has no natural source for | L | M | Console reporting is the mandatory part; the durable event row uses `${SESSION_ID:-sess_$(date +%s)_deploy}`. If that synthesized id is judged wrong at implementation time, drop the event row and keep the console report — never drop the report |
| New `scripts/lib/` and `scripts/tests/` files are invisible to the deploy without manifest registration, and the orphan gates (Rules J-N) fail on unregistered deployed files | M | M | Register every new file in `agent-system/extensions/core/manifest.json` `provides.scripts` in the same phase that creates it, alongside the existing `lib/*.sh` and `tests/*.sh` entries |

## Implementation Phases

**Dependency Analysis**:

| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1, 4 | -- |
| 2 | 2, 3, 5 | 1 (for 2, 3); 4 (for 5) |
| 3 | 6, 7 | 2, 3, 4, 5 |

Phases within the same wave can execute in parallel. Phases 4 and 5 both edit
`deploy-headless.sh` and are deliberately serialized (5 depends on 4) to avoid a same-file
collision; Phases 2 and 3 touch disjoint files and are genuinely parallel.

### Phase 1: Extract the deploy-baseline decision into a shared library [COMPLETED]

**Goal**: Create one sourced home for the pre/post `verify-deploy.sh --findings` snapshot and the
new-findings set difference, so the two consumers of the (a)/(b)/(c) contract share an
implementation instead of each carrying their own.

**Tasks**:

- [x] Create `agent-system/extensions/core/scripts/lib/deploy-baseline-lib.sh`, modelled
      structurally on `lib/deploy-freshness-lib.sh` (header stating it is the single home of the
      algorithm, safe to source, sets no shell options a caller inherits, exports nothing a
      caller must guess at).
- [x] Export `deploy_findings_snapshot <verify_deploy_path>`: runs `verify-deploy.sh --findings
      --quiet`, folds exit 2 into the findings vocabulary as the single sentinel line
      `FINDING gate0 [SENTINEL] verify-deploy could not run (exit 2)`, otherwise prints
      `^FINDING ` lines `sort -u`'d. This is `command-gate-out.sh`'s `_gate_out_deploy_findings`
      behavior, moved here.
- [x] Export `deploy_baseline_new_findings <pre> <post>`: the `comm -13` set difference over the
      two snapshots, printing only newly-introduced findings.
- [x] Document in the header the three-branch contract this library serves, cross-referencing
      `context/patterns/batch-orchestration-guardrails.md`'s "### The Inter-Cycle Redeploy
      Checkpoint" subsection by path rather than restating it.
- [x] Register `lib/deploy-baseline-lib.sh` in `agent-system/extensions/core/manifest.json`
      `provides.scripts`, in the existing `lib/*.sh` block.
- [x] Change no call site in this phase.

**Timing**: 0.75 hours

**Depends on**: none

**Verification Tier**: local

**Files to modify**:

- `agent-system/extensions/core/scripts/lib/deploy-baseline-lib.sh` - new file, two exported
  functions
- `agent-system/extensions/core/manifest.json` - add the new lib to `provides.scripts`

**Verification**:

- `bash -n` on the new library, and a direct source-and-invoke in a scratch shell showing
  `deploy_findings_snapshot` emits the sentinel line when the verify script it is pointed at
  exits 2, and `FINDING` lines otherwise.
- `deploy_baseline_new_findings` returns empty for identical inputs and exactly the added lines
  for a superset.

---

### Phase 2: Rewire the inter-cycle redeploy checkpoint onto the three-branch contract [COMPLETED]

**Goal**: Make `orchestrate-cycle-plan.sh`'s checkpoint reach its own baseline-tolerance branch
when `deploy-headless.sh` exits 3, so a pre-existing unrelated red gate no longer defers the
whole batch, while exit 1/2 still does.

**Tasks**:

- [x] Source `lib/deploy-baseline-lib.sh` alongside the existing `lib/common.sh` source.
- [x] Replace the bare `if bash deploy-headless.sh; then ... else ... fi` with a captured exit
      code (`deploy_exit=0; bash "$SCRIPT_DIR/deploy-headless.sh" >&2 || deploy_exit=$?`),
      mirroring `command-gate-out.sh`'s `gate_out_deploy_rc` shape.
- [x] Branch (a): `[ "$deploy_exit" -eq 1 ] || [ "$deploy_exit" -eq 2 ]` → the existing
      unconditional defer, unchanged in behavior, with the warning text tightened to say the
      deploy did not land. Carry over `command-gate-out.sh`'s comment explaining that exit 3 is
      deliberately excluded from this branch.
- [x] All other exit codes (0 and 3) fall through to the existing `post_findings` /
      `new_findings` logic, which becomes reachable from exit 3 for the first time. Branch (b)
      (non-empty `new_findings`) defers as today; branch (c) (empty) proceeds, records
      `deployed_critical_paths`, appends the `verify_deploy_baseline_notices` entry, and prints
      the existing banner and machine marker.
- [x] Replace the two ad hoc `pre_raw`/`post_raw` captures with `deploy_findings_snapshot`, so
      the checkpoint gains the exit-2 sentinel folding its own documented contract requires and
      the two call sites compute findings identically.
- [x] Preserve the existing `post_exit -eq 0` fast path's behavior (clean verify → record and
      announce) rather than collapsing it into the baseline branch.
- [x] Correct the stale comment above the checkpoint that claims it is "always a no-op today
      until the future postflight composer starts populating cycle_modified_files" —
      `orchestrate-cycle-postflight.sh` populates it; the checkpoint is live.

**Timing**: 1.25 hours

**Depends on**: 1

**Verification Tier**: full

**Scope Hypothesis**: This phase is hypothesized to change exactly one file
(`orchestrate-cycle-plan.sh`) within roughly the 30-line region currently spanning the checkpoint's
`if bash deploy-headless.sh` block, and to require no change to `mt_set`/`mt_get_json` call
shapes or to the `mt_state_file` schema. Confirm at implementation time by re-reading the whole
checkpoint block before editing and by diffing the resulting `mt_state_file` keys written
(`deployed_critical_paths`, `verify_deploy_baseline_notices`, `deferred_deploy_checkpoint`,
`defer_ledger`) against the pre-edit set; a new or renamed key falsifies the hypothesis and
requires updating `docs/architecture/orchestrate-state-machine.md` as well.

**Files to modify**:

- `agent-system/extensions/core/scripts/orchestrate-cycle-plan.sh` - checkpoint block: captured
  exit code, exit-1/2 branch, fall-through to the baseline comparison, library-sourced snapshots,
  stale-comment correction

**Verification**:

- `bash -n` plus a `--dry-run` invocation showing the checkpoint path is not entered when
  `cycle_modified_files` is empty (no behavior change to the common case).
- Full gate set (`verify-deploy.sh`) green, since this file is an orchestrator-critical path.
- Behavioral proof is deferred to Phase 7's harness, which drives all three branches with a
  stubbed `deploy-headless.sh`.

---

### Phase 3: Adopt the shared library at the `command-gate-out.sh` call site [COMPLETED]

**Goal**: Remove the second, now-duplicate implementation so the two sites cannot drift apart
again — the drift that made this defect possible in the first place.

**Tasks**:

- [x] Source `lib/deploy-baseline-lib.sh` in `command-gate-out.sh` (it already sources
      `.claude/scripts/skill-base.sh`; follow that path convention).
- [x] Delete the inline `_gate_out_deploy_findings()` definition and call
      `deploy_findings_snapshot` for both the pre and post captures.
- [x] Replace the inline `comm -13` with `deploy_baseline_new_findings`.
- [x] Leave every branch's message text, the retry-once policy, and the `[PRE-EXISTING
      VERIFY-DEPLOY FAILURE]` banner exactly as they are — this is a substitution, not a
      behavior change.
- [x] Add a one-line comment at the deleted helper's former site pointing to the library, so a
      reader following `batch-orchestration-guardrails.md` still lands somewhere useful.

**Timing**: 0.5 hours

**Depends on**: 1

**Verification Tier**: local

**Files to modify**:

- `agent-system/extensions/core/scripts/command-gate-out.sh` - source the library, drop the
  inline helper, call the two exported functions

**Verification**:

- `bash -n`, and `bash agent-system/extensions/core/scripts/tests/test-gate-out-repair-reporting.sh`
  still passes (the existing gate-out regression suite).
- Diff review confirming no message string changed.

---

### Phase 4: Make `deploy-headless.sh`'s three outcomes distinguishable by a caller [COMPLETED]

**Goal**: Resolve the dispatch's third confound with evidence rather than assumption, and give a
caller a machine-readable way to tell "did not land" from "landed, gate red" from "consumer repos
stale".

**Tasks**:

- [x] **Runtime confirmation first** (the research's verify-then-decide item): register a
      deliberately-stale consumer repo, run `deploy-headless.sh` against this repo, and record
      the observed exit code. Static reading says the consumer report is `|| true`-guarded and
      never reaches `exit "$verify_rc"`; confirm or refute that before writing any fix.
- [x] If the runtime check confirms the guard holds: do NOT add a new exit code for the consumer
      condition. Instead emit a machine-readable marker line so the condition is legible without
      prose parsing — `[deploy-headless] CONSUMERS_STALE=<n>` alongside the existing human
      report.
- [ ] If the runtime check refutes it (the consumer path can influence the exit code): fix the
      leak so it cannot, and record the reproduction in the phase notes. *(deviation: skipped — the runtime check confirmed the guard holds, not refuted it; this conditional branch was inapplicable)*
- [x] Emit a single machine-readable outcome marker before the final exit —
      `[deploy-headless] RESULT=landed_verify_clean` (0), `RESULT=landed_verify_red` (3), and
      `RESULT=not_landed` on the exit-1/2 paths — so callers stop having to infer the
      distinction from an exit code plus log prose.
- [x] Tighten the header's `# Exit codes:` block to state explicitly that consumer staleness is
      report-only and can never change the exit code, naming the `|| true` guard as the
      mechanism.

**Timing**: 1 hour

**Depends on**: none

**Verification Tier**: interface

**Scope Hypothesis**: This phase assumes the consumer-freshness confound is already inert and
that the work is therefore documentation plus two marker lines, not a code fix. That is a
hypothesis from static reading only. Confirm by the runtime step above BEFORE writing any of the
remaining tasks; if it is refuted, the phase's task list changes and its timing estimate should
be re-derived rather than held to.

**Files to modify**:

- `agent-system/extensions/core/scripts/deploy-headless.sh` - `RESULT=` markers at each exit
  path, `CONSUMERS_STALE=` marker, header exit-code block

**Verification**:

- Each of the three outcomes produces exactly one `RESULT=` line, confirmed by a scratch run for
  the success path and by a forced-failure scratch run for the others.
- `command-gate-out.sh`'s existing `grep -oE '(Resynced|Wiped and regenerated) [0-9]+ extension'`
  on the deploy log still matches — the new markers must not displace that line.

---

### Phase 5: Stop hand-maintaining `line_count` — repair before the gate, always reported [NOT STARTED]

**Goal**: Make declared `line_count` self-correcting at every deploy, so drift can never reach
Rule R silently and no human ever needs to hand-edit the integer again — while keeping the field
declared for its four consumers.

**Tasks**:

- [ ] In `deploy-headless.sh`'s `main()`, call `generate-context-line-counts.sh --write` BEFORE
      the headless nvim deploy invocation — not after — so the corrected source
      `index-entries.json` is what gets copied into `.claude/context/index.json` in the same run,
      and Rule R never sees drift in the inline verify that follows.
- [ ] Guard the call on `[ -d "$TARGET/agent-system/extensions" ]`, making it a silent,
      header-documented no-op in consumer repos that carry no source store, matching the
      `check-consumer-freshness.sh` guard convention already in this script.
- [ ] Report every repair, never silently: echo the regenerator's per-extension summary lines and
      a total corrected count under a `[deploy-headless]` prefix, on both the repaired and clean
      paths — the D-A precedent's "report the clean case too" rule.
- [ ] Emit one durable `specs/events.jsonl` row via `events-append.sh` with event type
      `index_line_count_auto_repair`, category `deviation` when any entry was corrected and
      `milestone` when none were, session `${SESSION_ID:-sess_$(date +%s)_deploy}`, and a
      `--detail-json` carrying the corrected count and the affected extension names. If the
      synthesized session id proves unacceptable at implementation time, drop the event row and
      keep the console report.
- [ ] Skip the repair under `--dry-run` (which returns before verification runs today) so a
      dry run stays non-mutating.
- [ ] Extend Rule R's three failure messages in `check-extension-docs.sh` to name the remedy
      (`generate-context-line-counts.sh --write`) for the mismatch and missing-key cases, so a
      standalone lint run outside a deploy still tells the reader what to do. Leave the
      missing-source-file case as a plain hard failure — it is the one case that genuinely
      cannot be auto-repaired and must keep failing loudly.
- [ ] Leave `INDEX_TRUTH_GATE_MODE` at `hard`. No staged rollout is needed: the repair runs
      before the gate, so the gate has nothing left to trip on.

**Timing**: 1.25 hours

**Depends on**: 4

**Verification Tier**: interface

**Scope Hypothesis**: This phase asserts that `generate-context-line-counts.sh --write` needs no
modification and that wiring plus a Rule R message change is sufficient. Confirm at
implementation time by running `generate-context-line-counts.sh --check` from within
`deploy-headless.sh`'s working directory and environment (notably its `REPO_ROOT`/`EXT_DIR`
resolution and the `deploy-root-guard.sh` bypass) before wiring `--write`; a `REPO_ROOT`
resolution mismatch between the deployed `.claude/scripts/` copy and the source-store copy would
falsify this and require an explicit `REPO_ROOT=` in the call.

**Files to modify**:

- `agent-system/extensions/core/scripts/deploy-headless.sh` - guarded, reported pre-deploy
  `--write` call and its `--dry-run` skip
- `agent-system/extensions/core/scripts/check-extension-docs.sh` - Rule R remedy pointers in the
  mismatch and missing-key messages

**Verification**:

- Acceptance demonstration: append a line to an indexed context file, run `deploy-headless.sh`,
  and show the run reports the correction, `verify-deploy.sh` is green, and `git diff` shows the
  `line_count` change was made by the script rather than by hand.
- A run with no drift still prints the clean-case report line.
- A run in a directory with no `agent-system/extensions/` produces no repair output and no error.

---

### Phase 6: Update the contract documentation to match the code [NOT STARTED]

**Goal**: Close the doc/code divergences this task creates or resolves, so the next reader is not
misled the way `regeneration-is-manual-only.md` predicted.

**Tasks**:

- [ ] `context/patterns/batch-orchestration-guardrails.md`, "### The Inter-Cycle Redeploy
      Checkpoint" → "Failure contract": scope branch (a) explicitly to "`deploy-headless.sh`
      exit 1 or 2 (the deploy did not land)", matching `command-gate-out.sh`'s own comment, and
      state that exit 3 routes to the baseline comparison.
- [ ] Same subsection: note that both consumers now source `scripts/lib/deploy-baseline-lib.sh`,
      and that the exit-2 resolution rule is implemented there rather than separately at each
      site.
- [ ] `context/patterns/regeneration-is-manual-only.md`, "### deploy-headless.sh's Inline
      Verification and Exit Code 3": mark the follow-up it explicitly foresaw ("a distinct exit
      code was chosen specifically so a follow-up task can route exit 3 through the existing
      baseline-comparison branches") as DONE, and correct its "would touch
      `skills/skill-orchestrate/SKILL.md`" pointer — the prose has since collapsed into a single
      delegated call, so the live edit target is `scripts/orchestrate-cycle-plan.sh`.
- [ ] Same file: document that `line_count` is now derived at deploy time and must not be
      hand-edited, and that the repair is reported, never silent.
- [ ] `docs/architecture/orchestrate-state-machine.md`: update the redeploy-checkpoint
      description if and only if Phase 2's Scope Hypothesis turned up a changed `mt_state_file`
      key set.
- [ ] Add the `RESULT=` / `CONSUMERS_STALE=` marker vocabulary from Phase 4 to
      `deploy-headless.sh`'s header as the caller-facing contract.

**Timing**: 0.75 hours

**Depends on**: 2, 4, 5

**Verification Tier**: prose

**Files to modify**:

- `agent-system/extensions/core/context/patterns/batch-orchestration-guardrails.md`
- `agent-system/extensions/core/context/patterns/regeneration-is-manual-only.md`
- `agent-system/extensions/core/docs/architecture/orchestrate-state-machine.md` (conditional)
- `agent-system/extensions/core/scripts/deploy-headless.sh` (header only)

**Verification**:

- Diff read-through confirming every changed hunk is prose or a comment.
- `check-extension-docs.sh` Rule R stays green after the edits (context files are indexed, so
  their `line_count` changes — Phase 5's repair should absorb this automatically, which is
  itself a live demonstration of the acceptance criterion).

---

### Phase 7: Tests and the four acceptance demonstrations [NOT STARTED]

**Goal**: Prove the tolerance is narrow rather than assume it, with a harness that drives all
three checkpoint branches and demonstrates each of the dispatch's four acceptance criteria.

**Tasks**:

- [ ] Create `scripts/tests/test-deploy-baseline-lib.sh`: unit coverage of
      `deploy_findings_snapshot` (exit 0 → findings; exit 1 → findings; exit 2 → the single
      sentinel line) and `deploy_baseline_new_findings` (identical sets → empty; superset →
      exactly the added lines; the documented pre-exit-0/post-exit-2 case → non-empty).
- [ ] Extend `scripts/tests/test-orchestrate-cycle-plan.sh` with a stubbed `deploy-headless.sh`
      driving the checkpoint through all three branches, asserting on `mt_state_file`:
      exit 1 → `deferred_deploy_checkpoint` populated, no baseline notice; exit 3 with an
      unchanged finding set → `verify_deploy_baseline_notices` appended, `deployed_critical_paths`
      updated, batch NOT deferred; exit 3 with an added finding → deferred, no baseline notice.
- [ ] Register both test files in `manifest.json` `provides.scripts` (the second is already
      registered; confirm rather than assume).
- [ ] Acceptance demonstration 1 (`line_count` drift cannot occur silently): edit an indexed
      file, deploy, show the gate green with no manual declaration edit — capture the console
      report and the resulting `git diff`.
- [ ] Acceptance demonstration 2 (pre-existing red gate no longer defers a batch): introduce a
      deliberate pre-existing failure, run the checkpoint, show branch (c) fires and the batch
      proceeds with a recorded `verify_deploy_baseline_notices` entry.
- [ ] Acceptance demonstration 3 (a NEW failure still stops the batch): introduce a failure
      between the pre and post snapshots, show branch (b) defers.
- [ ] Acceptance demonstration 4 (the three exit-3 causes are distinguishable): show the
      `RESULT=` marker differing across the three outcomes, and the `CONSUMERS_STALE=` marker
      present with a stale consumer registered and an unchanged exit code.
- [ ] Run `scripts/tests/run-all.sh` and the full `verify-deploy.sh` gate set.

**Timing**: 1.5 hours

**Depends on**: 2, 3, 4, 5

**Verification Tier**: full

**Scope Hypothesis**: This phase assumes `test-orchestrate-cycle-plan.sh` can stub
`deploy-headless.sh` via `SCRIPT_DIR` interposition, the way the existing checkpoint invocation
(`bash "$SCRIPT_DIR/deploy-headless.sh"`) implies. Confirm by reading that test file's existing
fixture setup before writing the new cases; if it cannot interpose on `SCRIPT_DIR`, the three
branch cases move into a new dedicated test file rather than being dropped.

**Files to modify**:

- `agent-system/extensions/core/scripts/tests/test-deploy-baseline-lib.sh` - new
- `agent-system/extensions/core/scripts/tests/test-orchestrate-cycle-plan.sh` - three branch cases
- `agent-system/extensions/core/manifest.json` - register the new test file

**Verification**:

- `bash agent-system/extensions/core/scripts/tests/run-all.sh` passes.
- `bash .claude/scripts/verify-deploy.sh` (full gate set, not `--skip-slow`) passes.
- All four acceptance demonstrations produce captured evidence recorded in the implementation
  summary.

---

## Testing & Validation

- [ ] `bash -n` clean on every modified shell script.
- [ ] `scripts/tests/test-deploy-baseline-lib.sh` passes (new).
- [ ] `scripts/tests/test-orchestrate-cycle-plan.sh` passes with the three new branch cases.
- [ ] `scripts/tests/test-gate-out-repair-reporting.sh` still passes after the Phase 3
      substitution.
- [ ] `scripts/tests/run-all.sh` passes.
- [ ] `bash .claude/scripts/verify-deploy.sh` (full gate set) passes.
- [ ] Acceptance 1: an edited indexed file deploys green with no hand-edited `line_count`.
- [ ] Acceptance 2: a pre-existing unrelated red gate lets the batch proceed with a recorded
      `verify_deploy_baseline_notices` entry.
- [ ] Acceptance 3: a newly-introduced failure still defers the batch.
- [ ] Acceptance 4: the three `deploy-headless.sh` outcomes are distinguishable by marker.

## Artifacts & Outputs

- `agent-system/extensions/core/scripts/lib/deploy-baseline-lib.sh` (new)
- `agent-system/extensions/core/scripts/tests/test-deploy-baseline-lib.sh` (new)
- Modified: `scripts/orchestrate-cycle-plan.sh`, `scripts/command-gate-out.sh`,
  `scripts/deploy-headless.sh`, `scripts/check-extension-docs.sh`,
  `scripts/tests/test-orchestrate-cycle-plan.sh`, `manifest.json`
- Modified docs: `context/patterns/batch-orchestration-guardrails.md`,
  `context/patterns/regeneration-is-manual-only.md`,
  `docs/architecture/orchestrate-state-machine.md` (conditional)
- `specs/152_decouple_stale_declarations_from_deploy_gating/summaries/01_*-summary.md`

## Rollback/Contingency

Every phase is an independently revertable scoped commit, and the two axes are independent — axis
(a) (Phase 5) and axis (b) (Phases 1-3) can be reverted separately without affecting each other.

- **Axis (b) rollback**: revert Phases 2 and 3, then Phase 1. The checkpoint returns to
  unconditional defer on any non-zero deploy exit, which is strictly conservative — it over-defers,
  never under-defers, so a rollback cannot let a broken deploy through.
- **Axis (a) rollback**: revert Phase 5. `line_count` returns to hand-maintained and Rule R
  returns to failing on drift; `generate-context-line-counts.sh --write` remains available for
  manual repair, exactly as before this task.
- **Partial-landing contingency**: if Phase 4's runtime check refutes the static reading, Phase 4
  can be reduced to the marker lines and the consumer-leak fix split into its own follow-up task
  without blocking Phases 5-7 — record the reproduction so the follow-up is not rediscovered
  from scratch.
- **Deploy-tree contingency**: because `orchestrate-cycle-plan.sh` and `verify-deploy.sh` are
  orchestrator-critical paths, a bad landing is recovered by `git revert` plus
  `bash .claude/scripts/deploy-headless.sh` to restore the deployed tree from the reverted source
  store — never by hand-editing `.claude/**`.
