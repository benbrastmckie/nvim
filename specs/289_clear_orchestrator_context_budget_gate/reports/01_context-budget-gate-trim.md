# Research Report: Task #289

**Task**: 289 - Clear orchestrator context budget gate
**Started**: 2026-10-01T05:36:03Z
**Completed**: 2026-10-01T05:41:16Z
**Effort**: medium (content trim + one default-value flip, three files in known scope, two of them
measurement-sensitive)
**Dependencies**: None (sibling task 293 — the prior blocker on the hard-mode promotion — is
already `completed`)
**Sources/Inputs**:
- Codebase: `agent-system/extensions/core/context/config/orchestrator-context-budget.json`,
  `agent-system/extensions/core/scripts/verify-deploy.sh` (Gate 20), `measure-eager-context.sh`,
  `skills/skill-orchestrate/SKILL.md`, `rules/git-workflow.md` and its narrative sidecar,
  `merge-sources/claudemd.md` (core's `.claude/CLAUDE.md` fragment), `claudemd-size-budget.json`
  (sibling gate), `scripts/tests/test-verify-deploy-context-budget.sh`, `specs/ROADMAP.md`
- Live measurements via `REPO_ROOT=$(pwd) bash agent-system/extensions/core/scripts/measure-eager-context.sh --check`
  and `wc -c`
**Artifacts**: - this report
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- Gate 20 (`verify-deploy.sh`) is live-failing right now, worse than the task description's own
  snapshot: eager-load total has grown from 67,980 B (task description) to **68,289 B** against
  `baseline_bytes: 65,950` — a **2,339 B** overage, not 2,030 B. `test-verify-deploy-context-budget.sh`
  independently confirms this (`current_eager='68289', baseline_bytes='65950'`), with two of its
  13 cases red for exactly this reason — fixing the eager overage clears both the gate and the test.
- The single largest eager contributor is the predicted assembled `.claude/CLAUDE.md`
  (36,968 B live, of which core's own `merge-sources/claudemd.md` fragment is 19,793 B alone), and
  within that fragment the `/orchestrate` row of the Command Reference table is one 1,670-byte
  table cell — nearly 5% of the entire predicted CLAUDE.md in one line — almost all of which is
  already independently documented in `docs/architecture/orchestrate-state-machine.md` (not
  eager). This is the single highest-leverage trim and alone exceeds the whole required cut.
- `rules/git-workflow.md` (9,740 B, second-largest eager rule) already delegates most elaboration
  to `context/standards/git-workflow-narrative.md`, but its "No Destructive Git on Uncommitted
  Work" section still carries ~1,400 B of operational narrative (rollback-procedure walkthrough,
  "never emit in default form" warning) that duplicates detail the narrative file and
  `git-snapshot.sh --help` already own.
- `skills/skill-orchestrate/SKILL.md` is 20,325 B against a 20,000 B ceiling (325 B over). The
  task-named known-safe trim (collapsing the three identical-notes lifecycle-dispatch rows in the
  Skill-to-Agent Mapping table) saves only ~133 B — not enough alone. A second genuine duplicate
  was found: the `detected_defects`/`AskUserQuestion` non-prompting constraint is stated in full
  twice (Move 4's "Batched `AskUserQuestion` relay" paragraph, and again in the "MUST NOT
  (Postflight Boundary)" D4-exception closing paragraph), ~150–200 B recoverable by keeping one
  copy and pointing to it from the other.
- The hard-mode promotion precondition in the config's own comment ("deferred until
  `commands/orchestrate.md` settles past the concurrent sibling task") is now satisfied: task 293
  (`add_hold_task_status_marker`), the file's most recent editor
  (`81a37ad16 task 293 phase 5: hold guard at single-command gate-in and /orchestrate STAGE 0`),
  is `completed`. The only other task whose `file_scope` names `commands/orchestrate.md` (273,
  `three_channel_orchestration_conclusion_stage`) is `not_started` — not concurrently editing it.
  `commands/orchestrate.md` itself sits comfortably under its own ceiling (20,228 B / 21,000 B),
  so flipping `ORCHESTRATOR_BUDGET_GATE_MODE` from `warn` to `hard` is safe once SKILL.md is back
  under its own ceiling.
- Recommended approach matches the user's stated preference and the task's own framing: **trim
  content**, do not move `baseline_bytes`. All identified trims are duplication removal /
  pointer-ization into existing (or already-referenced) `context/`/`docs/` files — the same
  pattern `source-store-deploy-boundary.md` already uses — not content loss.

## Context & Scope

Gate 20 of `verify-deploy.sh` ("orchestrator context budget lock") runs three independent
sub-checks against `agent-system/extensions/core/context/config/orchestrator-context-budget.json`:

- **Sub-check A** (volatile-file hits in the eager set): unconditional `fail()`. Currently clean
  (0 hits).
- **Sub-check B** (eager-load total vs. `eager_load.baseline_bytes`): unconditional `fail()`
  regardless of `ORCHESTRATOR_BUDGET_GATE_MODE`. **Currently failing** (68,289 B > 65,950 B).
- **Sub-check C** (per-file ceilings for `commands/orchestrate.md` and
  `skills/skill-orchestrate/SKILL.md`): severity gated by `ORCHESTRATOR_BUDGET_GATE_MODE`
  (`verify-deploy.sh` line 190, currently `warn`, defaulted via
  `ORCHESTRATOR_BUDGET_GATE_MODE="${ORCHESTRATOR_BUDGET_GATE_MODE:-warn}"`). SKILL.md is
  currently over its ceiling (warn-tier finding); `commands/orchestrate.md` is under.

The task bundles three changes that are genuinely one coordinated edit to one config file plus
its three governed/governing files:
1. (a) Close the eager-load overage (sub-check B) via content trim.
2. (b) Close the SKILL.md ceiling overage (sub-check C, the warn finding) via content trim.
3. (c) Re-check and act on the hard-mode promotion precondition, flipping the gate-mode default
   in `verify-deploy.sh`.

`file_scope` for task 289 lists four files: the config JSON, `skill-orchestrate/SKILL.md`,
`rules/git-workflow.md`, and `scripts/verify-deploy.sh`. It does **not** list
`merge-sources/claudemd.md` (core's `.claude/CLAUDE.md` fragment) even though the task
description explicitly names the assembled `.claude/CLAUDE.md` as a largest contributor and the
remedy target. `file_scope` is descriptive, not filesystem-validated (`state-management.md`), so
this is not a blocker, but the plan should explicitly widen `file_scope` to include
`agent-system/extensions/core/merge-sources/claudemd.md` (and, if touched, any specific
`docs/architecture/*.md` pointer target) rather than silently touching an out-of-scope file.

## Findings

### Codebase Patterns

**Eager-load composition (live measurement, `measure-eager-context.sh --check`), largest to
smallest:**

| Channel | Source | Bytes |
|---|---|---|
| claudemd | predicted assembled `.claude/CLAUDE.md` (all 7 active-extension fragments + header) | 36,968 |
| rules | `rules/git-workflow.md` | 9,740 |
| rules | `rules/artifact-formats.md` | 4,760 |
| rules | `rules/state-management.md` | 3,850 |
| parent_chain | repo root `CLAUDE.md` | 3,046 |
| rules | `rules/error-handling.md` | 2,987 |
| rules | `rules/pr-prohibition.md` | 2,574 |
| rules | `rules/no-task-references-in-deliverables.md` | 2,017 |
| rules | `rules/source-store-deploy-boundary.md` | 1,588 |
| rules | `rules/workflows.md` | 759 |
| | **TOTAL** | **68,289** |

**Within the predicted assembled CLAUDE.md, per-extension fragment contribution** (header
234 B + 7 fragments, separators make the sum slightly exceed the raw fragment total):

| Extension | Source | Bytes |
|---|---|---|
| core | `merge-sources/claudemd.md` | 19,793 |
| literature | `merge-sources/claudemd.md` | 4,876 |
| memory | `EXTENSION.md` | 4,054 |
| email | `EXTENSION.md` | 3,098 |
| lean | `EXTENSION.md` | 2,030 |
| nvim | `EXTENSION.md` | 1,491 |
| nix | `EXTENSION.md` | 1,385 |
| (header template) | `templates/claudemd-header.md` | 234 |

Core's own fragment is by far the largest single contributor to the predicted CLAUDE.md, and the
largest single cell within it is the `/orchestrate` row of the Command Reference table — one
table row, 1,670 bytes, documenting forced-phase semantics (canonical lifecycle order,
artifact-keyed admission, terminal/archived-task admission, multi-task independent tracking,
`User focus:` composition) that are already the explicit subject of
`docs/architecture/orchestrate-state-machine.md` (a non-eager, lazily-loaded doc; confirmed by
`measure-eager-context.sh`'s channel model, which only scans `agent-system/extensions/*/rules/*.md`
and resolved `@`-imports — `docs/` and `context/patterns/` are outside every eager channel).
Two further oversized cells in the same file: the Multi-task syntax paragraph under the Command
Reference table (811 B) and the Model Enforcement paragraph under Skill-to-Agent Mapping (842 B).
These three spots alone total 3,323 B of inline prose in a file whose own established style
elsewhere (e.g. "Hard Mode" and "Literature Mode" sections) is a short summary plus a
`See <path> for the full X` pointer.

Precedent for the pointer-extraction pattern is already live in the same merge source:
`rules/source-store-deploy-boundary.md` is a short "Path Pattern / Principle / Correct Edit
Target" rule (1,588 B) that points to
`context/standards/source-store-deploy-boundary-narrative.md` for "the full resolution procedure,
the unreachable-source-store fallback, a worked example, the Exceptions list, and the Enforcement
narrative" — exactly the shape the task description asks the planner to replicate.

**`rules/git-workflow.md` (9,740 B)**: already has a narrative sidecar
(`context/standards/git-workflow-narrative.md`, 7,769 B) covering Commit-Per-Green-Substep
elaboration, snapshot-mode detail, the history-rewrite incident, Session ID lifecycle, branch
strategy, and commit-failure error handling. Despite that, the "No Destructive Git on Uncommitted
Work" section (lines 101–150, 3,142 B — the largest single section in the rule) still carries
operational narrative beyond the bare rule:
- Lines 128–139 (964 B): a full rollback-procedure walkthrough, including the
  `--allow-out-of-scope` override story, that already ends by pointing to `git-snapshot.sh --help`
  and `context/contracts/recovery.md`'s rollback rung — i.e., it re-explains what those two
  references already own.
- Lines 141–146 (430 B): a "never emit in default form" warning that points to
  `context/patterns/checkpoint-before-overflow.md` for the alternative, after already stating the
  MUST NOT.

Both are candidates for compression to a bare MUST/MUST NOT + pointer, in the same style the
narrative file's own section headers promise ("No Destructive Git on Uncommitted Work — Snapshot
Mode Detail" already exists in the narrative file and currently only covers the exemption's
per-mode detail, not the rollback-procedure and never-emit-in-default-form paragraphs — those
would need to move there too, not just be deleted).

**`skills/skill-orchestrate/SKILL.md` (20,325 B / 20,000 B ceiling)**: this file is far denser
and more operationally load-bearing than `git-workflow.md` — nearly every sentence is a MUST/MUST
NOT contract or an inlined bash snippet the loop actually executes. The task description's named
known-safe trim (collapsing the three Skill-to-Agent Mapping rows for Research/Plan/Implement
dispatch, which all read `Fresh context; orchestrator_mode: true` in the Notes column and differ
only in which `$AGENT` variable and whether the resolution clause says "resolved by task type
..." vs. "(same resolution)") saves roughly 133 B — confirmed present and collapsible, but alone
insufficient for the 325 B deficit. A second genuine duplicate, not previously named in the
config's derivation history, was found by inspection: the constraint "`detected_defects` never
triggers `AskUserQuestion`" is stated in full twice:
- Move 4, end of the "Batched `AskUserQuestion` relay" paragraph (line 268): "Unrelated to
  `detected_defects` (accumulate-and-render only, never prompted)."
- "MUST NOT (Postflight Boundary)" section, closing sentence (lines 310–311): "...never let
  `detected_defects` call `AskUserQuestion` (accumulate-then-render only, per
  `orchestrate-state-machine.md`'s `mt_state_file` field reference)."

Collapsing the second occurrence to a short pointer back to the first (keeping only the
phase-order MUST NOT that precedes it, which is a distinct constraint) recovers roughly another
150–200 B, which combined with the row-collapse comfortably clears the 325 B deficit with margin.

### External Resources

Not applicable — this is a pure codebase-measurement task; no external documentation informs the
gate's own policy, which is locally defined in `orchestrator-context-budget.json`'s `_comment`
and `verify-deploy.sh`'s Gate 20 header comment.

### Hard-mode promotion precondition (finding c)

The config's `_comment` defers promoting `ORCHESTRATOR_BUDGET_GATE_MODE` to `hard` "until
commands/orchestrate.md settles past the concurrent sibling task editing it this cycle." The most
recent commit touching `commands/orchestrate.md` is
`81a37ad16 task 293 phase 5: hold guard at single-command gate-in and /orchestrate STAGE 0`; task
293 (`add_hold_task_status_marker`) status in `specs/state.json` is `completed`. The only other
task whose `file_scope` names `commands/orchestrate.md` is task 273
(`three_channel_orchestration_conclusion_stage`), status `not_started` — it has not begun editing
the file. The precondition is satisfied. `verify-deploy.sh`'s own `scripts/tests/test-verify-deploy-context-budget.sh`
exercises both `warn` and `hard` modes exclusively via explicit `ORCHESTRATOR_BUDGET_GATE_MODE=`
env-var overrides in every case (`run_gate20() { local mode="${1:-warn}"; ... }`), never relying
on the script's own default — flipping the default at `verify-deploy.sh` line 190 will not break
that test suite.

`commands/orchestrate.md` itself (20,228 B / 21,000 B ceiling, 772 B headroom) is comfortably
under ceiling today and is not part of this task's required trim — it is mentioned here only
because it is the other file sub-check C governs and because it is the file the deferred
precondition names.

## Recommendations

1. **Close the eager-load overage (finding a) by trimming, not moving `baseline_bytes`.**
   Extract the `/orchestrate` row's forced-phase/multi-task semantics (currently 1,670 B inline
   in `agent-system/extensions/core/merge-sources/claudemd.md`'s Command Reference table) down to
   a short summary + pointer to `docs/architecture/orchestrate-state-machine.md`, mirroring
   `rules/source-store-deploy-boundary.md`'s own pattern. This single cut (even alone) exceeds
   the required 2,339 B margin; the Multi-task-syntax paragraph (811 B) and Model Enforcement
   paragraph (842 B) in the same file are available as additional headroom if a smaller,
   more conservative `/orchestrate`-row trim is preferred instead. Widen task 289's `file_scope`
   to include this merge source explicitly before editing it (see Context & Scope). Re-measure
   with `REPO_ROOT=$(pwd) bash agent-system/extensions/core/scripts/measure-eager-context.sh --check`
   after the edit and confirm the live `TOTAL:` line is at or under 65,950 B before touching
   `baseline_bytes` at all — the config's own note requires `baseline_bytes` never be silently
   re-derived, so it should end this task unchanged unless the trim genuinely cannot close the
   gap (not expected here, given the single-row cut's size).
2. **Close the SKILL.md ceiling overage (finding b) via the two identified duplicates.**
   Collapse the three near-identical Skill-to-Agent Mapping rows (Research/Plan/Implement
   dispatch) into one row (~133 B), and collapse the duplicated
   `detected_defects`/`AskUserQuestion` restatement in "MUST NOT (Postflight Boundary)" down to a
   pointer back to the Move 4 paragraph that already states it in full (~150–200 B). Verify with
   `wc -c agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` that the result is
   comfortably under 20,000 B (leave margin — the file has grown before and will again) before
   relying on it to unblock the hard-mode promotion in the same change.
3. **Promote `ORCHESTRATOR_BUDGET_GATE_MODE` from `warn` to `hard` (finding c), but only after
   (2) lands.** Flip the default at `agent-system/extensions/core/scripts/verify-deploy.sh` line
   190 (`ORCHESTRATOR_BUDGET_GATE_MODE="${ORCHESTRATOR_BUDGET_GATE_MODE:-warn}"` ->
   `...:-hard}"`), and rewrite the explanatory comment above it (lines 179–189) to drop the
   now-stale "concurrently being edited" deferral and instead record that task 293 landed and the
   precondition was re-checked and satisfied (with a date). Mirror the same update in
   `orchestrator-context-budget.json`'s top-level `_comment`, which currently states the same
   deferred-promotion language — this is the field the config's own prose says governs the
   decision, so it must not be left contradicting the script.
4. **Update the config's informational snapshot fields, not its ceilings/baseline.** After the
   trims land, refresh `files."skills/skill-orchestrate/SKILL.md".measured_bytes/measured_at` and
   `eager_load.measured_bytes/measured_at` to the new, true values (these are documented as
   "informational snapshots and may be refreshed freely"), and append one dated sentence to each
   touched file's `derivation`/`note` narrative recording that this task closed the finding via a
   deliberate content trim (not a baseline move), per the config's own "must be deliberate and
   recorded" requirement. Do not touch `ceiling_bytes` or `baseline_bytes` themselves.
5. **Order of operations matters.** Do (1) and (2) first, re-measure both (eager total and
   SKILL.md bytes) and confirm both are at/under their respective ceiling/baseline, THEN do (3)
   (the hard-mode flip) in the same change — flipping to hard before SKILL.md is actually under
   ceiling would turn today's warn-tier finding into an immediate hard failure, the opposite of
   "clear the gate."
6. **Verification before closing the task**: re-run
   `REPO_ROOT=$(pwd) bash agent-system/extensions/core/scripts/verify-deploy.sh --only-gate 20`
   (all three sub-checks should report `[PASS]`) and
   `bash agent-system/extensions/core/scripts/tests/test-verify-deploy-context-budget.sh` (the two
   currently-red cases — "baseline fixture is not clean" and "could not compute a safe eager-load
   pad amount" — are both downstream of the real repo's current eager-overage state per their own
   error text, `current_eager='68289', baseline_bytes='65950'`, and should both clear once the
   eager trim lands).
7. **Optional, out-of-scope-but-adjacent**: `specs/ROADMAP.md`'s "Budgets" tracking table (lines
   26–29) still shows the task-description-era snapshot (67,980 B / 21,317 B), not live numbers;
   it is not in `file_scope` and updating it is not required to clear Gate 20, but the planner may
   want to note it as a one-line follow-up so the roadmap doesn't read as already-stale the moment
   this task closes.

## Decisions

- **Trim, don't move the baseline.** The user's explicit framing ("I'm concerned... files are
  more verbose than need be... cut off the fat while retaining and improving the functionality")
  and the task description's own "either outcome... must be deliberate and recorded" language,
  combined with the fact that the single largest identified cut (the `/orchestrate` row) alone
  exceeds the required margin, together make content trim clearly the right call over a baseline
  move. This report does not recommend touching `eager_load.baseline_bytes` or either file's
  `ceiling_bytes`.
- **Widen `file_scope` to include `agent-system/extensions/core/merge-sources/claudemd.md`.**
  The task description names the assembled `.claude/CLAUDE.md` as a required trim target, but the
  only editable source for it is this merge-source file (plus, in principle, any of the six other
  active extensions' own fragments — not needed here since core's own fragment alone suffices).
- **Hard-mode flip is sequenced last, gated on SKILL.md actually being back under ceiling**, not
  bundled as an independent first step — doing it first would be self-defeating given today's
  warn-tier SKILL.md finding.
- **No action needed on `commands/orchestrate.md`** — it is under ceiling with comfortable
  headroom and not part of either open finding; it appears in this report only as context for the
  hard-mode precondition check.

## Risks & Mitigations

- **Risk**: trimming the `/orchestrate` table row could remove operationally load-bearing detail
  a future `/orchestrate` reader needs inline (not everyone follows pointers).
  **Mitigation**: `docs/architecture/orchestrate-state-machine.md` already exists and is the
  established full-detail reference for exactly this content (confirmed non-eager, so no new
  document creation is required) — the `source-store-deploy-boundary.md` precedent shows this
  pattern already works for the same style of reader in this codebase.
- **Risk**: SKILL.md's prose is unusually dense and contract-bearing; an incautious trim could
  silently drop a MUST/MUST NOT. **Mitigation**: both identified trims are true duplicates (the
  same constraint stated twice in full), not unique content — removing the second occurrence in
  favor of a pointer to the first loses no information. No other SKILL.md section was identified
  as safely trimmable in this pass; the planner should not look for further cuts beyond these two
  without fresh duplicate-detection evidence.
- **Risk**: the eager-load total has drifted upward three times already during this very cycle
  (65,950 baseline -> 67,980 at task-description time -> 68,289 live now), suggesting ongoing
  background growth from unrelated tasks. A trim sized exactly to today's gap could be re-exceeded
  by the time this task's own changes land. **Mitigation**: recommendation 1 above deliberately
  identifies a cut (1,670 B alone) well in excess of the 2,339 B deficit, and recommendation 6
  requires a live re-measurement immediately before closing the task rather than trusting this
  report's numbers.
- **Risk**: flipping `ORCHESTRATOR_BUDGET_GATE_MODE` to `hard` makes Gate 20's per-file ceilings a
  hard deploy-blocking failure for any future task that grows either file past ceiling again.
  **Mitigation**: this is the intended, requested outcome ("promote it from warn to hard"), and
  the config's own `_comment` was always written as a planned follow-up, not a permanent warn
  posture — no mitigation needed beyond the sequencing in recommendation 5.

## Context Extension Recommendations

- **Topic**: eager-context trim precedent / "known-safe duplicate" catalogue.
- **Gap**: there is no single place documenting the general pattern "a `/orchestrate`-adjacent
  doc/rule/skill cell that duplicates `docs/architecture/orchestrate-state-machine.md` is always
  a trim candidate" — this report had to re-derive it by direct byte measurement and manual
  reading. A future context note under `context/patterns/` (e.g. a short
  "eager-context-trim-candidates.md") cataloguing the two duplicates found here (and inviting
  future additions) would make the next overage cycle faster to triage.
- **Recommendation**: not required for this task to close; worth a follow-up `/meta` or `/task`
  entry if recurring overage cycles continue (this is at least the second cycle to hit this gate
  per the ROADMAP.md snapshot cited above).

## Appendix

**Commands run**:
```
jq -r '.active_projects[] | select(.project_number==289)' specs/state.json
jq -r '.active_projects[] | select(.project_number==273) | .file_scope' specs/state.json
jq -r '.extensions | to_entries[] | select(.value.status=="active") | .key' .claude-extensions.json
REPO_ROOT=$(pwd) bash agent-system/extensions/core/scripts/measure-eager-context.sh --check
wc -c agent-system/extensions/core/rules/git-workflow.md
wc -c agent-system/extensions/core/skills/skill-orchestrate/SKILL.md
wc -c agent-system/extensions/core/merge-sources/claudemd.md
git log --oneline -10 -- agent-system/extensions/core/commands/orchestrate.md
bash agent-system/extensions/core/scripts/tests/test-verify-deploy-context-budget.sh
grep -n "ORCHESTRATOR_BUDGET_GATE_MODE" agent-system/extensions/core/scripts/verify-deploy.sh
```

**Key files referenced** (all paths relative to repo root; this is the SOURCE STORE per
`rules/source-store-deploy-boundary.md` — edits belong here, never under `.claude/`):
- `agent-system/extensions/core/context/config/orchestrator-context-budget.json`
- `agent-system/extensions/core/scripts/verify-deploy.sh` (Gate 20, lines ~179–190, ~974–1080)
- `agent-system/extensions/core/scripts/measure-eager-context.sh`
- `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md`
- `agent-system/extensions/core/rules/git-workflow.md`
- `agent-system/extensions/core/context/standards/git-workflow-narrative.md`
- `agent-system/extensions/core/merge-sources/claudemd.md` (not currently in `file_scope`;
  recommend widening)
- `agent-system/extensions/core/docs/architecture/orchestrate-state-machine.md`
- `agent-system/extensions/core/context/config/claudemd-size-budget.json` (sibling gate; core's
  fragment is 19,793 B against its own 19,950 B ceiling — unaffected, improved by any trim here)
- `agent-system/extensions/core/scripts/tests/test-verify-deploy-context-budget.sh`
- `specs/ROADMAP.md` (stale snapshot, optional follow-up only)
