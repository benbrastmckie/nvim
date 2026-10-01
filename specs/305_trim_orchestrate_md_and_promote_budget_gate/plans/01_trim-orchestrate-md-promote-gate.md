# Implementation Plan: Task #305

- **Task**: 305 - Trim `agent-system/extensions/core/commands/orchestrate.md` below its 21,000 B ceiling, then promote `ORCHESTRATOR_BUDGET_GATE_MODE` from warn to hard
- **Status**: [NOT STARTED]
- **Effort**: 2.5 hours
- **Dependencies**: None
- **Research Inputs**: `specs/305_trim_orchestrate_md_and_promote_budget_gate/reports/01_trim-orchestrate-md-budget-gate.md`
- **Artifacts**: plans/01_trim-orchestrate-md-promote-gate.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md, source-store-deploy-boundary.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Close the last open finding in `verify-deploy.sh` Gate 20 by shrinking the restated
forced-phase/`--fast` documentation in `agent-system/extensions/core/commands/orchestrate.md`
down to short summaries plus pointers, making
`agent-system/extensions/core/docs/architecture/orchestrate-state-machine.md` the single
authoritative long-form source for that material, then flipping the
`ORCHESTRATOR_BUDGET_GATE_MODE` default from `warn` to `hard` in the same change. Research
already verified, clause by clause, that every sentence slated for removal is present (usually in
more detail) in the destination doc, so constraint (b) is satisfied by the status quo and no new
content needs to be written into the destination before cutting. The remaining work is the cut
itself, two reciprocity fixes in the destination doc, the one-line gate-mode flip with its dated
comment, the measurement/narrative record refresh, and narrow verification.

### Research Integration

Key findings carried into this plan:

- The file measures **21,328 B** against a 21,000 B ceiling (328 B over), confirmed by `wc -c`.
- Five specific spots carry the duplication: the Options table rows for `--fast` (668 B),
  `--research` (981 B), `--plan` (706 B), `--implement` (852 B) — 3,207 B subtotal — and the
  forced-phase Constraints bullet (896 B). A byte-measured draft replacement reclaims ~2,304 B,
  landing near **19,024 B** — under both the 21,000 B ceiling and the ~20,500 B headroom target
  constraint (d) asks for.
- Every clause to be cut is already present in `docs/architecture/orchestrate-state-machine.md`:
  `## The \`needs_research\` Fork (the \`--fast\` Escape Hatch)`, `### Forced Phases on a
  Terminal or Archived Task`, and `### Dependency Gating Model`.
- The destination doc currently points *back* at `commands/orchestrate.md`'s Options table "for
  the full per-flag wording" in two places (~lines 754 and 767). After the trim those pointers
  are backward and must be dropped or reworded.
- The gate-mode flip is a single line (`verify-deploy.sh` line 192,
  `ORCHESTRATOR_BUDGET_GATE_MODE="${ORCHESTRATOR_BUDGET_GATE_MODE:-warn}"` -> `:-hard`) plus the
  dated comment block above it (lines 179-191) that currently narrates the deferred promotion.
- The 13-case suite `scripts/tests/test-verify-deploy-context-budget.sh` needs **no code
  changes** — every case sets the env var explicitly against a `pad_file` fixture. Research ran
  it: 14 passed / 1 failed, where the single failure is the "baseline fixture is clean" check and
  is caused by *pre-existing lean-extension deploy staleness* (gate3/gate5/gate16 findings), not
  by this overage. Verification must therefore be narrow.

Verified independently while writing this plan (not taken on faith from the report):

- Gate 20 sub-check C measures the **source store** path
  (`$TARGET/agent-system/extensions/core/$rel_path`), so trimming the source-store file is what
  satisfies the gate; the deployed `.claude/` copy is not what is measured.
- `commands/orchestrate.md` is **not** in `measure-eager-context.sh`'s eager-load set, so the
  trim cannot regress Gate 20 sub-check B (eager total vs. baseline). Only sub-check C changes.
- `.claude/` is gitignored and untracked in this repo, so an optional redeploy carries no
  commit-scope consequences.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

`roadmap_flag` was not set for this dispatch, so no roadmap review/update phases are added.
`specs/ROADMAP.md` line 29 nevertheless carries a now-stale status row for this exact file
("328 B OVER (new)... blocks promoting `ORCHESTRATOR_BUDGET_GATE_MODE` to `hard`"). Refreshing
that one row is treated as part of the record-keeping phase below (Phase 3), matching how the
adjacent eager-load and `SKILL.md` rows in the same table already narrate their own closures.

## Goals & Non-Goals

**Goals**:

- Bring `agent-system/extensions/core/commands/orchestrate.md` to roughly 19,000-20,500 B — real
  headroom, not a bare pass — without moving `ceiling_bytes` or `baseline_bytes`.
- Leave `docs/architecture/orchestrate-state-machine.md` self-sufficient as the authoritative
  long-form source, with no backward pointer treating the trimmed file as the fuller one.
- Flip `ORCHESTRATOR_BUDGET_GATE_MODE`'s default to `hard` in the same change, with its dated
  comment rewritten to narrate the successful promotion.
- Refresh the measurement and narrative record (`orchestrator-context-budget.json`,
  `specs/ROADMAP.md` row) so no file still claims the finding is open.
- Confirm Gate 20 passes in `hard` mode and the 13-case suite is green.

**Non-Goals**:

- Moving `ceiling_bytes` or `eager_load.baseline_bytes` (constraint (a)) — the drafted trim
  clears the target with margin, so there is no pressure to revisit either.
- Relocating the ~10 KB STAGE 0 executable bash block (constraint (c)) — that is a
  code-relocation change, not a documentation trim.
- Chasing the pre-existing gate3/gate5/gate16 lean-extension staleness findings to a fully clean
  full-battery `verify-deploy.sh` run. They are out of scope and the dispatch's own
  `<deploy-freshness-context>` block already names them.
- Any change to `scripts/tests/test-verify-deploy-context-budget.sh` — verified unnecessary.
- Hand-editing anything under `.claude/**` (see `rules/source-store-deploy-boundary.md`); all
  edits land in the source store under `agent-system/extensions/core/`.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Trimming a clause that is NOT actually present in the destination doc, silently losing information | H | M | Phase 1 opens with an explicit read-and-confirm pass over the three named destination sections before any cut; a clause with no destination home is kept rather than cut |
| Flipping the gate to `hard` before the file is actually under ceiling, turning a warn into a repo-wide FAIL | H | L | Phase 2 depends on Phase 1 and opens by re-measuring with `wc -c`; the flip does not land unless the measurement is under ceiling |
| Implementer chases the pre-existing lean-staleness findings toward a clean full-battery run and reports the task blocked | M | M | Non-Goals and Phase 4 both state the narrow verification contract explicitly: `--only-gate 20` plus the 13-case suite, not a clean full run |
| Trimming to a razor-thin margin, repeating `skill-orchestrate/SKILL.md`'s fragile 7 B-under-ceiling state | M | L | Phase 1's acceptance bar is <= 20,500 B, not <= 21,000 B; if the measurement lands between those two values the phase is not done |
| Markdown table-row rewrapping shifts the actual byte savings away from the ~2,304 B estimate | L | M | The estimate is declared a Scope Hypothesis in Phase 1 and confirmed by re-measuring with `wc -c`, never assumed |
| JSON edit breaks `orchestrator-context-budget.json`, making Gate 20 fail at the `jq` read instead of the ceiling check | M | L | Phase 3 verifies with `jq -e '.files' ` on the edited file before closing |

## Implementation Phases

**Dependency Analysis**:

| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |
| 3 | 3 | 1, 2 |
| 4 | 4 | 1, 2, 3 |

Phases within the same wave can execute in parallel. This plan is strictly serial: each phase's
acceptance input is the previous phase's output (the measured byte count gates the flip; the flip
and the measurement are both narrated by the record refresh; verification covers all three).

---

### Phase 1: Trim the restated forced-phase documentation and fix destination reciprocity [NOT STARTED]

**Goal**: `agent-system/extensions/core/commands/orchestrate.md` measures <= 20,500 B with every
cut clause verifiably still present in
`agent-system/extensions/core/docs/architecture/orchestrate-state-machine.md`, and that
destination doc no longer points back at the trimmed file as the fuller source.

**Tasks**:

- [ ] Read the three destination sections in full before cutting anything:
      `## The \`needs_research\` Fork (the \`--fast\` Escape Hatch)` (~line 75),
      `### Forced Phases on a Terminal or Archived Task` (~line 752), and
      `### Dependency Gating Model` (~line 720) of
      `agent-system/extensions/core/docs/architecture/orchestrate-state-machine.md`.
- [ ] Clause-by-clause coverage check (constraint (b)): for each of the five source spots, confirm
      each distinct assertion has a home in the destination. The assertions to account for are:
      `--fast` skips the default research-first phase for a `not_started` task; the planner can
      still route back via `needs_research`; `--hard` does not skip research; `--research` forces
      research even under `--fast`; forced phases are admitted on terminal/archived tasks;
      canonical lifecycle ordering regardless of typed order; stop-after-last-named-phase; a new
      `MM_` artifact round, landing in the archive directory for an archived task; status is never
      regressed; `--plan` always admitted, resolving to `reviser-agent` with an existing plan and
      `planner-agent` otherwise; `--implement` admitted only with an existing plan artifact, else
      blocked with "no plan artifact; run --plan first"; an unforced invocation on a fully
      terminal set still stops with `all_terminal`; per-task forced-phase tracking in multi-task
      mode via `scripts/orchestrate-cycle-plan.sh`'s `--force-phases`; each task stops rather than
      falling through to status-derived classification once its forced sequence is exhausted, with
      a `blocked[]` row naming the reason. Any assertion WITHOUT a destination home is kept in the
      source file (or added to the destination first), never silently dropped.
- [ ] Replace the four Options table rows (`--fast`, `--research`, `--plan`, `--implement`) with
      short summaries plus a pointer to the named destination sections, preserving the
      `| flag | description | false |` table shape and the surrounding row order. The
      byte-measured draft in the research report's "Drafted replacement text" block is a usable
      starting point, not a mandate.
- [ ] Replace the forced-phase Constraints bullet (currently lines 28-37) with the short
      summary-plus-pointer form, keeping the multi-task `--force-phases` mechanism named and the
      artifact-keyed-admission distinction intact (both are operationally load-bearing one-liners,
      not restatement).
- [ ] Re-measure: `wc -c agent-system/extensions/core/commands/orchestrate.md`. If the result is
      above 20,500 B, continue trimming restatement in the same five spots (never the STAGE 0
      bash block) until it is at or below that figure.
- [ ] Commit this sub-step.
- [ ] Reciprocity fix: in `docs/architecture/orchestrate-state-machine.md`, drop or reword the two
      backward sentences (~lines 754 and 767, "See `commands/orchestrate.md`'s Options table for
      the full per-flag wording") so the doc reads as self-sufficient long-form rather than
      deferring to a now-short summary.
- [ ] Commit this sub-step.

**Timing**: 1.25 hours

**Depends on**: none

**Verification Tier**: local

**Commit Mode**: per-substep

**Scope Hypothesis**: the five named spots total ~4,103 B and the drafted replacements total
~1,799 B, so the trim reclaims ~2,304 B and lands the file near 19,024 B. Confirm at
implementation time with `wc -c` on the edited file (and on the replaced regions if the first
measurement disappoints) — markdown rewrapping can shift the figure. The acceptance bar is the
measured `wc -c` result being <= 20,500 B, not the estimate matching.

**Files to modify**:

- `agent-system/extensions/core/commands/orchestrate.md` - trim four Options table rows and the
  forced-phase Constraints bullet to summary-plus-pointer form
- `agent-system/extensions/core/docs/architecture/orchestrate-state-machine.md` - drop/reword the
  two sentences that point back at the trimmed file as the fuller source

**Verification**:

- `wc -c agent-system/extensions/core/commands/orchestrate.md` returns <= 20,500 (and therefore
  < 21,000).
- `grep -n 'commands/orchestrate.md.*full per-flag wording'
  agent-system/extensions/core/docs/architecture/orchestrate-state-machine.md` returns nothing.
- Each of the four trimmed Options rows still renders as a single valid table row with three
  cells (`grep -c '^| \`--' ` on the Options table is unchanged from its pre-trim value).
- Diff read-through confirms the coverage check above: no assertion was cut without a named
  destination.

---

### Phase 2: Promote `ORCHESTRATOR_BUDGET_GATE_MODE` from warn to hard [NOT STARTED]

**Goal**: Gate 20's per-file ceiling sub-check defaults to `fail()` severity, with its dated
comment block narrating the successful promotion instead of the deferred attempt.

**Tasks**:

- [ ] Re-confirm the gate precondition before flipping:
      `wc -c agent-system/extensions/core/commands/orchestrate.md` is under 21,000 B AND
      `wc -c agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` is under its 20,000 B
      ceiling. Both per-file entries in the config become `fail()`-tier at once, so both must be
      clear — not just the one this task trimmed. If either is over, stop and report rather than
      flipping.
- [ ] Change `agent-system/extensions/core/scripts/verify-deploy.sh` line ~192 from
      `ORCHESTRATOR_BUDGET_GATE_MODE="${ORCHESTRATOR_BUDGET_GATE_MODE:-warn}"` to
      `...:-hard}"`, leaving the env-var override mechanism itself untouched.
- [ ] Rewrite the dated comment block above it (currently lines ~179-191) to record the
      successful 2026-10-01 promotion: the restatement trim that closed the
      `commands/orchestrate.md` overage, the fact that both per-file ceilings were clear at
      promotion time, and that no ceiling or `baseline_bytes` was moved. Keep the existing
      `SCHEMA_CONFORMANCE_GATE_MODE` / `STRICT_CORE_DEPLOY` precedent sentence and the closing
      note that this variable does NOT gate the eager-load regression or volatile-file sub-checks.
- [ ] `bash -n agent-system/extensions/core/scripts/verify-deploy.sh` to confirm the script still
      parses.
- [ ] Commit this sub-step.

**Timing**: 0.5 hours

**Depends on**: 1

**Verification Tier**: interface

**Commit Mode**: per-substep

**Files to modify**:

- `agent-system/extensions/core/scripts/verify-deploy.sh` - flip the
  `ORCHESTRATOR_BUDGET_GATE_MODE` default to `hard`; rewrite the preceding dated comment block

**Verification**:

- `bash -n agent-system/extensions/core/scripts/verify-deploy.sh` exits 0.
- `grep -n 'ORCHESTRATOR_BUDGET_GATE_MODE:-' agent-system/extensions/core/scripts/verify-deploy.sh`
  shows exactly one occurrence, with `:-hard`.
- The comment block no longer contains "Promotion is deferred" or "deferred again".
- A `--only-gate 20` run (or equivalent narrow invocation) with no env var set prints
  `mode: hard` on its live-figures line and reports both per-file ceilings as `under`.

---

### Phase 3: Refresh the measurement and narrative record [NOT STARTED]

**Goal**: No file in the repo still claims the `commands/orchestrate.md` overage is open or that
the gate promotion is pending.

**Tasks**:

- [ ] In `agent-system/extensions/core/context/config/orchestrator-context-budget.json`, update
      the `files["commands/orchestrate.md"]` entry: `measured_bytes` to the figure actually
      measured in Phase 1, `measured_at` to the implementation date, and extend `derivation` with
      a dated sentence recording the restatement trim that closed the overage. Leave
      `ceiling_bytes` at 21000 untouched (constraint (a)).
- [ ] Update the same file's top-level `_comment`: replace the "ORCHESTRATOR_BUDGET_GATE_MODE
      therefore remains warn-tier pending a follow-up trim of commands/orchestrate.md" narrative
      with a dated record of the completed promotion. Leave `eager_load.baseline_bytes` and its
      fixed-historical-record note untouched.
- [ ] Optionally refresh `files["skills/skill-orchestrate/SKILL.md"]`'s `measured_bytes`/
      `measured_at` if it drifted (informational snapshots, explicitly refreshable per the
      config's own `_comment`); do not touch its `ceiling_bytes`.
- [ ] `jq -e '.files["commands/orchestrate.md"].ceiling_bytes == 21000 and .eager_load.baseline_bytes != null'`
      on the edited config to confirm valid JSON and unmoved limits.
- [ ] Update `specs/ROADMAP.md` line ~29's status row for `commands/orchestrate.md`: replace the
      "328 B OVER (new)... blocks promoting `ORCHESTRATOR_BUDGET_GATE_MODE` to `hard`" text with
      the measured under-ceiling figure and a note that the promotion landed, matching the
      closure phrasing already used by the adjacent eager-load and `SKILL.md` rows.
- [ ] Commit this sub-step.

**Timing**: 0.5 hours

**Depends on**: 1, 2

**Verification Tier**: local

**Commit Mode**: per-substep

**Files to modify**:

- `agent-system/extensions/core/context/config/orchestrator-context-budget.json` -
  `measured_bytes`, `measured_at`, `derivation`, and the top-level `_comment`; no ceiling or
  baseline change
- `specs/ROADMAP.md` - refresh the `commands/orchestrate.md` budget status row

**Verification**:

- `jq -e .` on the config exits 0 and `ceiling_bytes` is still 21000,
  `eager_load.baseline_bytes` unchanged (`git diff` on the file shows no change to either key).
- `grep -rn 'remains warn-tier\|Promotion is deferred\|328 B OVER'
  agent-system/extensions/core/ specs/ROADMAP.md` returns nothing.
- `measured_bytes` for `commands/orchestrate.md` equals the live `wc -c` output.

---

### Phase 4: Narrow verification and deploy sync [NOT STARTED]

**Goal**: Gate 20 passes in `hard` mode and the 13-case suite is green, with the pre-existing
out-of-scope findings explicitly distinguished rather than chased.

**Tasks**:

- [ ] Run `bash agent-system/extensions/core/scripts/tests/test-verify-deploy-context-budget.sh`
      and record the pass/fail tally. The expectation is 15/15 once the trim removes the one
      pre-existing per-file ceiling WARN that the baseline-fixture check tolerates at `-le 1`.
- [ ] If the baseline-fixture case still fails, confirm the cause is the pre-existing lean
      staleness (gate3/gate5/gate16) and NOT gate20, by inspecting the reported finding lines
      before concluding anything. Do not treat an unrelated FAIL as this task's failure.
- [ ] Run the narrow gate check over the real repo (a `--only-gate 20` invocation, or a
      `--findings` run filtered with `grep gate20`) and confirm no gate20 FINDING remains and the
      live-figures block shows `mode: hard` with both files `under`.
- [ ] Optional deploy sync: run `bash .claude/scripts/deploy-headless.sh` so the deployed
      `.claude/commands/orchestrate.md` matches the trimmed source (and the dispatch's noted lean
      staleness clears). `.claude/` is gitignored and untracked, so this changes nothing
      committable. If the deploy surfaces unrelated failures, record them and move on — it is
      hygiene, not an acceptance criterion for this task.
- [ ] Commit any remaining task-scoped changes and record the verification evidence (tallies,
      byte counts, gate output excerpts) in the implementation summary.

**Timing**: 0.5 hours

**Depends on**: 1, 2, 3

**Verification Tier**: full

**Commit Mode**: per-substep

**Files to modify**:

- none planned (verification phase; the implementation summary under
  `specs/305_trim_orchestrate_md_and_promote_budget_gate/summaries/` is written by postflight)

**Verification**:

- `test-verify-deploy-context-budget.sh` reports 15 passed / 0 failed; any residual failure is
  documented as pre-existing and unrelated, with the evidence that establishes it.
- No `FINDING gate20` line appears in a `--findings` run over the real repo.
- The live-figures block reports `commands/orchestrate.md: <N> B / ceiling 21000 B (under)` and
  `skills/skill-orchestrate/SKILL.md: <N> B / ceiling 20000 B (under)` with
  `mode: hard`.

---

## Testing & Validation

- [ ] `wc -c agent-system/extensions/core/commands/orchestrate.md` <= 20,500 B.
- [ ] Every assertion removed from the trimmed spots has a confirmed home in
      `docs/architecture/orchestrate-state-machine.md` (clause-by-clause, per Phase 1).
- [ ] No backward "see `commands/orchestrate.md`'s Options table for the full per-flag wording"
      pointer remains in the destination doc.
- [ ] `bash -n agent-system/extensions/core/scripts/verify-deploy.sh` exits 0 and the sole
      `ORCHESTRATOR_BUDGET_GATE_MODE:-` default reads `hard`.
- [ ] `jq -e .` passes on `orchestrator-context-budget.json`; `ceiling_bytes` and
      `eager_load.baseline_bytes` are byte-identical to their pre-task values.
- [ ] `test-verify-deploy-context-budget.sh`: 15 passed, 0 failed (or a documented pre-existing,
      non-gate20 failure).
- [ ] No `FINDING gate20` in a `verify-deploy.sh --findings` run.
- [ ] No new occurrence of a task-number reference in any file outside `specs/**`.

## Artifacts & Outputs

- Trimmed `agent-system/extensions/core/commands/orchestrate.md` (~19,000-20,500 B).
- Reciprocity-corrected
  `agent-system/extensions/core/docs/architecture/orchestrate-state-machine.md`.
- `agent-system/extensions/core/scripts/verify-deploy.sh` with `ORCHESTRATOR_BUDGET_GATE_MODE`
  defaulting to `hard` and a dated promotion comment.
- Refreshed `agent-system/extensions/core/context/config/orchestrator-context-budget.json`
  measurement and narrative fields.
- Refreshed `specs/ROADMAP.md` budget status row.
- Implementation summary under
  `specs/305_trim_orchestrate_md_and_promote_budget_gate/summaries/`.

## Rollback/Contingency

All five touched files are tracked and committed per sub-step, so rollback is a targeted
`git revert` or `git checkout <sha> -- <path>` of the specific commit(s). The riskiest single
state is a gate flipped to `hard` while a file is still over ceiling, which would turn a
repo-wide WARN into a FAIL: Phase 2's opening precondition check exists to prevent reaching that
state, and if it is reached anyway the contingency is to revert only the `verify-deploy.sh`
commit (restoring `warn`), leaving the trim in place, and to report the residual overage rather
than moving `ceiling_bytes` to make the gate pass. If the trim cannot reach 20,500 B without
cutting load-bearing content, the correct outcome is a `partial` return naming the shortfall —
not a ceiling move (constraint (a)) and not a STAGE 0 bash-block relocation (constraint (c)).
