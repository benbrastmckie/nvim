# Implementation Plan: Task #397

- **Task**: 397 - lean research compile-verify recommendation contract
- **Status**: [NOT STARTED]
- **Effort**: 2 hours
- **Dependencies**: None
- **Research Inputs**: specs/397_lean_research_compile_verify_recommendation/reports/01_compile-verify-recommendation-contract.md
- **Artifacts**: plans/01_compile-verify-recommendation-contract.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Add an always-on "Compile-Verify-Before-Recommend" contract clause to the lean research agent's
constraint section, and the matching evidence tag to both copies of the research-report skeleton,
so that a recommendation naming a concrete artifact whose acceptance an existing compiled gate
decides must carry a measured PASS/FAIL result before it is written up. The clause is prose only:
no tool-grant change, no new script, no hook. The edit lands in the lean extension's source store
(`agent-system/extensions/lean/**`), is mirrored across the two independent report skeletons that
have already drifted on exactly this kind of extension, and is followed by an `index-entries.json`
`line_count` correction and a redeploy.

### Premise Re-Validation

The dispatch's flagged lines were checked against the research report and live state. Results:

| Dispatch claim | Verdict |
|----------------|---------|
| "SOURCE STORE IS THE EDIT TARGET: `agent-system/extensions/lean/**`" | **Confirmed.** `.claude-extensions.json` resolves `extensions.lean.source_dir` to `/home/benjamin/.config/nvim/agent-system/extensions/lean`, and its `installed_files` list shows `.claude/agents/lean-research-agent.md` and `.claude/context/project/lean4/agents/lean-research-flow.md` are deploy outputs. |
| File scope includes `agents/lean-research-hard-agent.md` | **Refuted.** `ls agent-system/extensions/lean/agents/` returns exactly two files: `lean-implementation-agent.md`, `lean-research-agent.md`. The research report corroborates this three ways (manifest `hard_contracts.lean4` carries contract filenames, not agent names; core's `hard-mode-routing.md` states the `-hard` agent ladder is retired; filesystem absence). This path is dropped from the plan's file scope. |
| "always-on vs hard-mode-only … decided and recorded" | **Resolved by the report, carried into this plan.** Always-on, in `lean-research-agent.md`. Because no hard agent file exists, the only alternative placement would have been the H3/H4 contract overrides; the cited failure occurred in a standard dispatch, so that placement would not have caught it. |
| `index-entries.json` records a `line_count` for the flow file that any edit invalidates | **Confirmed, with the current figure re-measured.** The entry under `"path": "project/lean4/agents/lean-research-flow.md"` declares `"line_count": 186`, and `wc -l` on the live file returns 186 — currently exact, and invalidated by Phase 2's edit. |
| "the two sibling records in this chain also declare `index-entries.json`" | **Does not currently hold.** Concurrent sibling 412's live `file_scope` in `specs/state.json` is three lean implementation-side files and does **not** include `index-entries.json`, even though its edit to `lean-implementation-flow.md` (declared `line_count: 224`) would invalidate that file's entry too. Recorded as a risk below, not a blocker: the two entries are distinct lines in the same JSON file. |

Additionally measured at authoring time, and load-bearing for the tier justifications below:

- `suite_selection_select` returns `__FULL_SWEEP__` for both markdown targets
  (`lean-research-agent.md`, `lean-research-flow.md`) and five real suites for
  `index-entries.json` (`test-context-reachability.sh`, `test-deploy-orphans.sh`,
  `test-index-entries-schema.sh`, `test-install-uninstall-extension.sh`,
  `test-manifest-scripts-sync.sh`).
- `bash .claude/scripts/generate-context-line-counts.sh --check` **already fails before any edit
  in this plan**: one pre-existing mismatch in the `core` extension
  (`formats/frontmatter.md` declared 705, actual 706). That failure is not ours, and
  `--write` must NOT be used to clear it — `--write` rewrites every extension's
  `index-entries.json`, which would silently edit `core/index-entries.json` (already modified in
  the working tree) outside this task's declared scope.

### Research Integration

The report's five decisions are adopted unchanged and are the substance of this plan: trigger
**(a)** (concrete artifact + existing compiled gate), triggers (b) and (c) rejected with reasons
recorded in the contract text itself, always-on placement as a sibling subsection to
"### Zero-Debt Policy Compliance", the FAIL obligation mirroring Zero-Debt item 3's non-silent
failure path, and an inline `[VERIFIED: …]` tag on each recommendation rather than a new table.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No `roadmap_path` was provided in this dispatch; no roadmap phases are included.

## Goals & Non-Goals

**Goals**:
- A trigger for compile-verification stated so an agent can apply it without judgment calls, with
  the two rejected candidate triggers and their reasons recorded in the contract text.
- A stated FAIL obligation: report the negative result, revise the recommendation, and fall back
  to the documented `[BLOCKED]` path only when no revised recommendation can be constructed.
- An inline evidence tag on every recommendation, so a checked-and-passed, a checked-and-failed,
  and an out-of-trigger recommendation are three visually distinct states — never
  indistinguishable by omission.
- Both report skeletons (`lean-research-agent.md` Stage 1, `lean-research-flow.md` Stage 5)
  carrying the same tag convention, closing the drift the report measured.
- `index-entries.json`'s `line_count` for the flow file re-measured and corrected in the same
  change, and the deployed tree regenerated.

**Non-Goals**:
- No change to the Zero-Debt Policy, the Literature Extraction Protocol, or the Tactic Discovery
  Survey Protocol (the survey's evidence shape is cited as precedent, not modified).
- No change to the research agent's tool grant — it already holds `lake build`, `lean_run_code`,
  `lean_verify`, `lean_multi_attempt`, and `lean_build`.
- No hard-mode overlay, and no creation of or reference to any `-hard`-suffixed agent file.
- No implementation-side guidance change (sibling record's territory).
- No new scripts or hooks.
- No `hard-mode.md` pointer paragraph (the report's deferred Context Extension Recommendation) —
  outside this task's file scope.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Concurrent sibling 412 edits `index-entries.json`'s `lean-implementation-flow.md` entry while Phase 3 edits the `lean-research-flow.md` entry | M | M | Distinct lines in the same file. Re-read `index-entries.json` immediately before editing (territory rule 1), edit only the one `line_count` line under the `lean-research-flow.md` `path` key, and stage only that file with an explicit single-path `git add --`. If a foreign uncommitted change to the sibling's entry is observed, report it rather than reverting or absorbing it. |
| `generate-context-line-counts.sh --write` used as a shortcut, sweeping in `core`'s unrelated pre-existing mismatch | M | M | Phase 3 forbids `--write` explicitly and specifies a surgical single-line edit. `--check` is used read-only, and its output is filtered to the `lean:` census line, because the whole-run exit status is already non-zero for a reason outside this task. |
| "Names a concrete artifact" drifts into a judgment call at the margin | M | M | The clause states the test operationally (a specific identifier, a fully-specified definition body, or an inventory/table row) and carries two worked examples on each side of the line, per the report's mitigation. |
| Future editor drifts the clause toward rejected trigger (b) | M | L | The rejection of (b) and (c), with reasons, is written into the contract text itself — mirroring how the Zero-Debt section states its FORBIDDEN list in place — not left only in the report. |
| The two report skeletons drift again on this clause | M | L | Phase 2 is gated on Phase 1 and mirrors the identical tag block; Phase 4's gate run covers both files. |
| Task-number text leaks into a file under `agent-system/**` | L | L | The clause's worked examples use durable anchors only (`certA`, `c36Sliced`, "the inventory-row gate"). Gate 4 (task-reference lint) in Phases 1-3 and the full gate in Phase 4 catch a leak. |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |
| 3 | 3 | 2 |
| 4 | 4 | 3 |

Phases within the same wave can execute in parallel.

---

### Phase 1: Add the Compile-Verify-Before-Recommend clause to the research agent [NOT STARTED]

**Goal**: `lean-research-agent.md` carries the always-on contract clause, its rejected-trigger
record, its FAIL obligation, the matching Critical Requirements entries, and the `[VERIFIED: …]`
tag convention in its own Stage 1 report skeleton.

**Tasks**:
- [ ] Re-read `agent-system/extensions/lean/agents/lean-research-agent.md` immediately before
      editing (concurrent-sibling territory rule).
- [ ] Insert a new `### Compile-Verify-Before-Recommend` subsection under
      `## Research Constraints for Lean Tasks`, placed immediately after the
      `### Zero-Debt Policy Compliance` subsection and before `### Literature Extraction
      Protocol`, mirroring Zero-Debt's two-list shape. Content to carry:
  - **Trigger (both conjuncts must hold)**: the recommendation (i) names a concrete artifact to
    be added or landed — a specific identifier, a fully-specified definition body, or an
    inventory/table row — AND (ii) an existing compiled gate, predicate, `#eval`, or decision
    procedure *already present in the current codebase* (found, not hypothesized) determines
    whether that artifact is accepted.
  - **Worked examples on each side of the line**: "land `certA` as the Tier-2 inventory row,
    where the existing `c36Sliced` predicate decides row acceptance" triggers the clause (both
    conjuncts hold); "use induction here instead of a case split" does not (no artifact named);
    "add a `Nat.succ`-shaped helper lemma, no gate decides its acceptance" does not (second
    conjunct fails).
  - **REQUIRED when the trigger fires**: run the gate against the artifact with the tools already
    granted (`lean_run_code`, `lean_verify`, `lean_multi_attempt`, `lean_build`, detached
    `lake build`) BEFORE the recommendation is written, and record the measured result inline on
    the recommendation.
  - **On a FAIL result** (mirroring Zero-Debt item 3's non-silent-failure shape): (a) report the
    compiled result — method and outcome — inline on the recommendation; (b) do not suppress or
    drop the recommendation; replace it with a revised recommendation that addresses the gate's
    actual requirement; (c) only when no revised recommendation can be constructed, document the
    finding plainly and recommend the task be marked `[BLOCKED]` for user review.
  - **FORBIDDEN**: writing a triggering recommendation with no measured result; silently dropping
    a recommendation whose check failed; asserting a gate outcome that was not actually run.
  - **Rejected trigger scopes, recorded in place with reasons**: "any recommendation whose
    correctness is decidable by a bounded mechanical check" — rejected, because nearly any claim
    about an existing codebase qualifies under a generous reading of "bounded", leaving the agent
    no judgment-free boundary; "only the report's primary recommendation, whatever its shape" —
    rejected, because primacy and gate-existence are independent axes: a primary recommendation
    may name no landable artifact at all, while a secondary one can carry exactly this defect.
- [ ] Extend the same file's Stage 1 report skeleton: under `### Recommendations`, replace the
      bare `- {Implementation approaches, including whether a sorry-free path exists}` guidance
      with the tagged shape, keeping the existing sorry-free-path guidance intact:
      ```
      ### Recommendations
      - {recommendation} [VERIFIED: PASS -- <method, e.g. "#eval c36Sliced on certA via lean_run_code">]
      - {recommendation} [VERIFIED: FAIL -- <method>; revised to: {revised recommendation}]
      - {recommendation} [No compiled gate applicable]
      ```
- [ ] Add a short note immediately after the skeleton code block, in the same style as the
      existing "Populate `## Tactic Survey Results` …" note, stating that every recommendation
      carries exactly one of the three tags and that `[No compiled gate applicable]` is the
      correct tag when the trigger does not fire — never an omitted tag.
- [ ] Add one `MUST DO` item and one `MUST NOT` item to `## Critical Requirements` referencing
      the new subsection by name (MUST DO: run the gate before writing a triggering
      recommendation; MUST NOT: write a triggering recommendation with no measured result or an
      unrun asserted outcome).
- [ ] Confirm no task-number reference was introduced into the file.

**Timing**: 45 minutes

**Depends on**: none

**Verification Tier**: local

**Commit Mode**: per-substep

**Scope Hypothesis**: this phase touches exactly one file and adds roughly 50-60 lines across
three insertion points (the new subsection, the skeleton block plus its note, and two Critical
Requirements entries) with no deletion of existing guidance. Confirm at implementation time with
`git diff --stat -- agent-system/extensions/lean/agents/lean-research-agent.md` before committing;
if the diff touches a section not named above, stop and reconcile rather than widening the phase.

**Tier Justification**: `suite_selection_select` returns `__FULL_SWEEP__` for this path (measured,
not asserted), so no suite covers it; the honest covering check for a source-store non-`specs/**`
markdown edit is `bash /home/benjamin/.config/nvim/.claude/scripts/verify-deploy.sh --skip-slow
--only-gate 3,4 /home/benjamin/.config/nvim` alongside the `local` tier's diff read-through.

**Files to modify**:
- `agent-system/extensions/lean/agents/lean-research-agent.md` - adds the new
  Compile-Verify-Before-Recommend subsection after the Zero-Debt Policy Compliance subsection;
  the Stage 1 report skeleton's Recommendations block gains the three-tag convention plus
  a following note; two entries added to Critical Requirements. This file exists (confirmed
  at authoring time, 407 lines); if it is absent at implementation time, stop and report rather
  than creating it.

**Verification**:
- Diff read-through confirming every changed hunk lies in one of the three named regions.
- `grep -n "Compile-Verify-Before-Recommend" agent-system/extensions/lean/agents/lean-research-agent.md`
  returns the new subsection heading and both Critical Requirements references.
- `grep -n "VERIFIED: PASS\|VERIFIED: FAIL\|No compiled gate applicable" agent-system/extensions/lean/agents/lean-research-agent.md`
  returns all three tag forms inside the Stage 1 skeleton.
- `bash /home/benjamin/.config/nvim/.claude/scripts/verify-deploy.sh --skip-slow --only-gate 3,4 /home/benjamin/.config/nvim`
  passes (gates 3 and 4: doc-lint and task-reference lint).

---

### Phase 2: Mirror the clause and the tag convention into the shared research flow [NOT STARTED]

**Goal**: `lean-research-flow.md` carries a cross-reference to the new clause and the identical
`[VERIFIED: …]` tag convention in its Stage 5 report skeleton, so the two skeletons do not drift
again on this extension.

**Tasks**:
- [ ] Re-read `agent-system/extensions/lean/context/project/lean4/agents/lean-research-flow.md`
      immediately before editing.
- [ ] In Stage 4 (Synthesize Findings) or at the head of Stage 5, add a short cross-reference
      paragraph naming the clause and pointing at
      `agents/lean-research-agent.md`'s `### Compile-Verify-Before-Recommend` subsection as the
      authoritative statement of the trigger and the FAIL obligation. Do not restate the full
      FORBIDDEN/REQUIRED lists here — one authoritative copy, one pointer.
- [ ] Extend the Stage 5 report skeleton's `## Recommendations` block from
      `1. {Prioritized recommendations}` to the tagged shape used in Phase 1, keeping the
      prioritized-list numbering this skeleton already uses:
      ```
      ## Recommendations
      1. {recommendation} [VERIFIED: PASS -- <method>]
      2. {recommendation} [VERIFIED: FAIL -- <method>; revised to: {revised recommendation}]
      3. {recommendation} [No compiled gate applicable]
      ```
- [ ] Add the same one-line note that every recommendation carries exactly one of the three tags.
- [ ] Confirm no task-number reference was introduced into the file.
- [ ] Record the file's new `wc -l` value for Phase 3.

**Timing**: 25 minutes

**Depends on**: 1

**Verification Tier**: local

**Commit Mode**: per-substep

**Scope Hypothesis**: this phase touches exactly one file and adds roughly 12-18 lines at two
insertion points, changing the file's line count from its current 186. Confirm with
`wc -l agent-system/extensions/lean/context/project/lean4/agents/lean-research-flow.md` and
`git diff --stat` on that path; the measured new count is the input to Phase 3, never a figure
carried from this plan.

**Tier Justification**: `suite_selection_select` returns `__FULL_SWEEP__` for this path
(measured), so no suite covers it; the honest covering check for a source-store non-`specs/**`
markdown edit is `bash /home/benjamin/.config/nvim/.claude/scripts/verify-deploy.sh --skip-slow
--only-gate 3,4 /home/benjamin/.config/nvim` alongside the `local` tier's diff read-through.

**Files to modify**:
- `agent-system/extensions/lean/context/project/lean4/agents/lean-research-flow.md` -
  cross-reference paragraph to the new clause, and the Stage 5 `## Recommendations` skeleton
  block gains the three-tag convention plus a following note. This file exists (confirmed at
  authoring time, 186 lines); if it is absent at implementation time, stop and report rather than
  creating it.

**Verification**:
- Diff read-through confirming both changed hunks lie in the cross-reference paragraph and the
  Stage 5 skeleton respectively.
- `grep -n "Compile-Verify-Before-Recommend" agent-system/extensions/lean/context/project/lean4/agents/lean-research-flow.md`
  returns the cross-reference.
- `grep -n "VERIFIED: PASS\|VERIFIED: FAIL\|No compiled gate applicable"` returns all three tag
  forms.
- `bash /home/benjamin/.config/nvim/.claude/scripts/verify-deploy.sh --skip-slow --only-gate 3,4 /home/benjamin/.config/nvim`
  passes.

---

### Phase 3: Correct the flow file's `line_count` in the lean index entries [NOT STARTED]

**Goal**: `index-entries.json`'s entry for `project/lean4/agents/lean-research-flow.md` declares
the re-measured line count, with no other entry in the file touched.

**Tasks**:
- [ ] Re-read `agent-system/extensions/lean/index-entries.json` immediately before editing —
      concurrent sibling 412 may have touched the `lean-implementation-flow.md` entry in the same
      file.
- [ ] Re-measure:
      `wc -l agent-system/extensions/lean/context/project/lean4/agents/lean-research-flow.md`.
      Use that output, never the `186` figure recorded in this plan or in the research report.
- [ ] Edit only the `"line_count"` line belonging to the entry whose `"path"` is
      `"project/lean4/agents/lean-research-flow.md"`. That entry exists and currently declares
      `"line_count": 186` (confirmed at authoring time). If the entry is absent at implementation
      time, stop and report rather than inserting a new entry — an absent entry means the index
      changed underneath this plan and the sibling-territory situation must be reassessed.
- [ ] Do NOT run `bash .claude/scripts/generate-context-line-counts.sh --write`: it rewrites every
      extension's `index-entries.json` and would silently correct an unrelated pre-existing
      mismatch in `core/index-entries.json` (`formats/frontmatter.md`), a file outside this task's
      scope and already modified in the working tree.
- [ ] Confirm nothing else in the file changed:
      `git diff -- agent-system/extensions/lean/index-entries.json` shows exactly one changed line.

**Timing**: 15 minutes

**Depends on**: 2

**Verification Tier**: local

**Commit Mode**: per-substep

**Scope Hypothesis**: exactly one line changes in one file — the `"line_count"` value under the
`lean-research-flow.md` entry. Confirm with
`git diff --numstat -- agent-system/extensions/lean/index-entries.json` reading `1  1` before
committing; any other figure means the edit reached further than intended or a sibling's change
has been picked up, and must be reconciled rather than committed.

**Tier Justification**: `suite_selection_select` maps this path to five real suites (measured),
so the covering check is `bash /home/benjamin/.config/nvim/.claude/scripts/tests/run-all.sh --only
test-context-reachability.sh,test-deploy-orphans.sh,test-index-entries-schema.sh,test-install-uninstall-extension.sh,test-manifest-scripts-sync.sh`.

**Files to modify**:
- `agent-system/extensions/lean/index-entries.json` - updates the line_count value of the one
  entry whose path key is project/lean4/agents/lean-research-flow.md, set to the Phase 2
  measurement.

**Verification**:
- `python3 -c` (or `jq`) read-back confirming the entry's `line_count` equals the live `wc -l` of
  the flow file.
- `bash /home/benjamin/.config/nvim/.claude/scripts/generate-context-line-counts.sh --check 2>&1 | grep '^lean:'`
  reports `0 mismatch, 0 null, 0 missing source` for the lean extension. The command's overall
  exit status is already non-zero for the unrelated `core` mismatch described in the Overview —
  read the filtered `lean:` census line, not the exit code.
- `bash /home/benjamin/.config/nvim/.claude/scripts/tests/run-all.sh --only test-context-reachability.sh,test-deploy-orphans.sh,test-index-entries-schema.sh,test-install-uninstall-extension.sh,test-manifest-scripts-sync.sh`
  passes.

---

### Phase 4: Redeploy and run the full gate set [NOT STARTED]

**Goal**: the deployed `.claude/` tree carries the new clause and both tagged skeletons, and the
complete gate set is observed green over the whole change.

**Tasks**:
- [ ] Confirm Phases 1-3 are committed and the working tree holds no uncommitted hunks of this
      task's own (siblings' uncommitted changes may legitimately be present — do not revert or
      absorb them).
- [ ] Redeploy with a bounded wait:
      `timeout 540 bash /home/benjamin/.config/nvim/.claude/scripts/deploy-headless.sh`, invoked
      with the Bash tool's `timeout` parameter raised to 600000 per
      `context/patterns/external-process-wait.md` Rule 1.
- [ ] Verify the deployed copies carry the change:
      `grep -c "Compile-Verify-Before-Recommend" .claude/agents/lean-research-agent.md .claude/context/project/lean4/agents/lean-research-flow.md`
      returns non-zero counts for both.
- [ ] Run the complete gate set: `bash /home/benjamin/.config/nvim/.claude/scripts/verify-deploy.sh`.
- [ ] If a gate fails in a file outside this task's `file_scope`, check `git log` before
      concluding it is this task's regression — a concurrent sibling's in-flight edit is the more
      likely cause, and must be reported rather than fixed here.

**Timing**: 35 minutes

**Depends on**: 3

**Verification Tier**: full

**Commit Mode**: per-substep

**Scope Hypothesis**: the redeploy regenerates the whole `.claude/` tree; this task's own source
changes account for exactly the three files named in Phases 1-3. Confirm with
`git status --short -- agent-system/` showing no unexpected source-store modification attributable
to this phase.

**Files to modify**:
- `__WHOLE_TREE__` - `deploy-headless.sh` regenerates the entire deployed tree, an implicit scope
  claim over all of it that no real declared path expresses.

**Verification**:
- `bash /home/benjamin/.config/nvim/.claude/scripts/verify-deploy.sh` passes — the complete gate
  set it aggregates, not a hand-picked subset, and not under `--skip-slow` or `--only-gate`.
- Deployed-copy grep above confirms both regenerated files carry the clause.
- `bash /home/benjamin/.config/nvim/.claude/scripts/generate-context-line-counts.sh --check 2>&1 | grep '^lean:'`
  still reports `0 mismatch` for the lean extension after the redeploy.

---

## Testing & Validation

- [ ] Gates 3 and 4 (`--skip-slow --only-gate 3,4 <repo_root>`) pass after each markdown phase.
- [ ] The five `index-entries.json`-covering suites pass after Phase 3.
- [ ] `generate-context-line-counts.sh --check`'s `lean:` census line reports `0 mismatch`.
- [ ] The complete `verify-deploy.sh` gate set passes in Phase 4.
- [ ] No file under `agent-system/**` gained a task-number reference (gate 4 enforces this).
- [ ] All three `[VERIFIED: …]` tag forms are present in both report skeletons.
- [ ] `agents/lean-research-hard-agent.md` is neither created nor referenced anywhere.

## Artifacts & Outputs

- `agent-system/extensions/lean/agents/lean-research-agent.md` — new
  `### Compile-Verify-Before-Recommend` subsection, tagged Stage 1 `### Recommendations` skeleton,
  two `## Critical Requirements` entries.
- `agent-system/extensions/lean/context/project/lean4/agents/lean-research-flow.md` —
  cross-reference to the clause, tagged Stage 5 `## Recommendations` skeleton.
- `agent-system/extensions/lean/index-entries.json` — corrected `line_count` for the flow entry.
- Regenerated `.claude/` deploy tree (disposable artifact, not committed).
- `specs/397_lean_research_compile_verify_recommendation/summaries/01_*-summary.md` at completion.

## Rollback/Contingency

All four phases are additive prose and one JSON scalar; the natural rollback is a forward fix or a
`git revert` of this task's own scoped commits, which is safe because every phase commits only its
own explicitly-listed paths.

Do not take a reverting working-tree snapshot in this task: concurrent siblings are editing the
same tree this cycle, and a reverting rollback would discard their uncommitted work. If a genuine
rollback of uncommitted work becomes necessary despite that, follow
`context/contracts/recovery.md`'s rollback rung for the exact invocation shape, including its
out-of-scope override flag, rather than improvising a `git reset`/`git clean`. For an ordinary
defensive checkpoint before a risky edit, use `bash .claude/scripts/git-snapshot.sh 397
--no-revert`, which is durable without reverting the working tree.

If Phase 4's full gate set fails on a file outside this task's `file_scope`, the contingency is to
report the foreign failure and stop, not to fix it here.
