# Implementation Plan: Task #354

- **Task**: 354 - Decide whether general-implementation-agent.md's Local Long-Running Command Discipline needs a third case covering an agent that dispatches a subagent and waits on it
- **Status**: [NOT STARTED]
- **Effort**: 2 hours
- **Dependencies**: None (follow-up to the local-gate mandate work; no blocking task)
- **Research Inputs**: `specs/354_bound_agent_wait_on_dispatched_subagent/reports/01_dispatched-subagent-wait.md`
- **Artifacts**: plans/01_dispatched-subagent-wait-ruling.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

The research phase established the ruling this plan implements: the textual gap in
`general-implementation-agent.md`'s "Local Long-Running Command Discipline" is real, but the
three-way deadline fork does **not** transfer to a dispatched-subagent wait, because an
async/backgrounded `Agent`-tool dispatch exposes no PID or status primitive the dispatching agent
can poll from inside its own turn (unlike `gh run view` for the CI case and `kill -0 "$pid"` for
the local-gate case). The ruling adopted is therefore the refined middle position: bless
synchronous nested delegation explicitly as outside the discipline, and prohibit outright — not
bound with a deadline — ending a turn to await an async/backgrounded subagent dispatch.

This is a documentation-only change across four source-store files plus a redeploy. No script,
hook, or predicate changes; `stall_suspected`'s trigger is affirmatively left unchanged. The work
splits into three independent prose edits (the mandate subsection, the ruling record plus
cross-reference pointers, the probe-diagnostic subsection) and a closing redeploy-and-gate phase.

### Research Integration

Findings carried into this plan from the research report:

- **The gap is verbatim-verifiable**: the mandate section names exactly two cases (CI/remote,
  local gate/build) and never mentions an `Agent`-tool dispatch.
- **No confirmed stranding exists**; the one incident that looked like evidence was a
  misdiagnosis (artifact mtimes showed the dispatch actively working throughout). The plan's
  wording must rest on the *demonstrated capability* (a dispatched agent already issued a nested
  `Agent` fork-probe call; async/backgrounded `Agent` dispatch is a live harness mode), never on
  the retracted observation.
- **The deadline-and-poll shape must not be copied**: writing a bounded-wait allowance here would
  describe a mechanism that does not exist. The rule is a flat MUST NOT plus an explicit
  permitted carve-out.
- **Homes settled**: the mandate subsection in `agents/general-implementation-agent.md` (the
  contract's authoritative home per `bounded-build-waiter.md`'s own classification note); short
  pointers in both wait-pattern files' "Related Documentation" sections; the probe diagnostic in
  `docs/architecture/orchestrate-state-machine.md` immediately after "Abandoned Wrap-Up".
- **`bounded-build-waiter.md`'s canonical bullet pair is explicitly NOT the home** for the new
  case — folding it in would misstate the PID idiom as available.

### Prior Plan Reference

No prior plan. `specs/354_bound_agent_wait_on_dispatched_subagent/plans/` is empty.

### Roadmap Alignment

No `roadmap_path` was supplied in this dispatch and no roadmap flag was set; no roadmap
consultation performed.

## Goals & Non-Goals

**Goals**:

- Record the ruling durably: which of the three positions (extend / decline / middle) was taken,
  and why the deadline fork does not transfer — in a location a future reader of the mandate
  family will find without reading `specs/**`.
- Close the textual gap in `general-implementation-agent.md` with wording that distinguishes
  awaiting a delegated subagent from backgrounding a local gate, and that does not forbid
  ordinary nested delegation.
- Document the live-vs-stranded probe (artifact mtimes, live child processes) with the
  handoff-absence false signal named explicitly.
- Redeploy so the deployed `.claude/` copies match the source store.

**Non-Goals**:

- Any change to `stall_suspected`'s trigger predicate, its phase gating, or its git-commit gate.
  The research phase produced no new evidence and affirmatively confirms the standing
  non-widening ruling.
- Propagating the new MUST NOT to the other implementation agents in
  `lint-agent-contracts.sh`'s `BOUNDED_WAIT_IN_SCOPE_RELATIVE_PATHS` set. The report names this
  as explicitly out of scope until nested async subagent use grows beyond the single measured
  fork-probe case.
- Folding the new case into `bounded-build-waiter.md`'s canonical generated-copy bullet pair, or
  adding a new Check-H-style lint for the new subsection.
- Adding a standalone note on the harness-level async/"teammate" `Agent` mode (the report's
  Context Extension Recommendation). That is a separate follow-up.
- Fixing the pre-existing dangling `@.claude/context/patterns/fork-patterns.md` references in
  already-deployed files (see Risks).

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| New prose in `bounded-build-waiter.md` collides with `lint-agent-contracts.sh` Check H, which greps that file for `canonical idiom VERBATIM` and ``arm a `Monitor` to watch a local verification`` and takes `head -n1` | H | M | Each string occurs exactly once today (verified at plan-authoring time). Phase 2 MUST NOT introduce either literal string anywhere in the file, and its verification re-asserts both counts are still 1 |
| A plain `docs/fork-patterns.md` citation added to `general-implementation-agent.md` dangles in the deployed tree — that file is source-store-only and is not in any extension's `installed_files` | M | H | Phase 1 cites the fork-mechanics narrative by section name without an `@`-import path, matching the plain-path style already used for `docs/architecture/handoff-schema.md`, and records in its verification that the target is source-store-only. Pre-existing dangling `@.claude/context/patterns/fork-patterns.md` references elsewhere are out of scope and must not be "fixed" opportunistically |
| A task-number reference leaks into `agent-system/**` prose while explaining the provenance ("deferred by task N") | H | M | Cite durable anchors only — "the local-gate case", the section names. `check-task-references.sh` runs inside `verify-deploy.sh` in Phase 4 and is also asserted per-phase |
| `deploy-headless.sh` in Phase 4 overwrites `.claude/**` while a concurrent sibling (task 335, scoped to `orchestrate-cycle-postflight.sh`, its test, and `git-staging-scope.md`) is mid-edit | M | M | No file-scope overlap with this task. `.claude/` is gitignored and the deploy is idempotent, so a race produces no commit conflict. If a foreign commit, foreign uncommitted modification, or a build this dispatch did not start is observed, STOP and report per the dispatch concurrency note rather than proceeding |
| The prohibition reads as justified by the retracted stranding observation, making the mandate rest on a false premise | H | M | Phase 1's wording and Phase 2's ruling record both state the capability/incident distinction explicitly: the capability is demonstrated, the specific stranding is not, and the rule is flat rather than mechanism-mandating precisely because of that |
| A future reader copies the local-gate deadline-and-poll shape onto the new case by analogy | M | M | Phase 1's wording states *why* no bounded-poll allowance is offered, rather than leaving the asymmetry implicit |
| `verify-deploy.sh` reports pre-existing failures unrelated to this change (recent sibling plans recorded 2-of-34 doc-lint/staleness failures on this tree) | L | M | Phase 4 captures the baseline failure set before the edits land (or attributes each failure by `git log`/`git status` overlap) and records any pre-existing failure as such rather than charging it to this change |

## Implementation Phases

**Dependency Analysis**:

| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1, 3 | -- |
| 2 | 2 | 1 |
| 3 | 4 | 1, 2, 3 |

Phases within the same wave can execute in parallel.

---

### Phase 1: Dispatched-Subagent Wait Discipline subsection [NOT STARTED]

**Goal**: Close the textual gap in the mandate with a third, clearly delimited subsection that
blesses synchronous nested delegation and prohibits an async/backgrounded dispatch left
unresolved at turn end.

**Tasks**:

- [ ] Re-read `agent-system/extensions/core/agents/general-implementation-agent.md` immediately
      before editing (concurrency note obligation), confirming the insertion point: after the
      "A bounded-wait deadline reached with no result is, by itself, neither case 2 nor case 3"
      paragraph that closes the three-way fork, and before the
      "**Derive `project_name` and `task_number` before first use**" paragraph.
- [ ] Insert a bold-label subsection titled **Dispatched-Subagent Wait Discipline**, opening with
      the same "(distinct from both cases above: ...)" framing the two sibling subsections use,
      scoping it to this dispatched agent itself invoking the `Agent` tool to delegate further.
- [ ] Write the **permitted** carve-out first: an ordinary synchronous `Agent`-tool call that
      blocks in the same tool invocation until the subagent's result returns is the normal,
      intended nested-delegation primitive, has no turn-ending choice point, is not a background
      wait, and nothing in this discipline restricts it.
- [ ] Write the **MUST NOT**: do not issue a subagent dispatch in any asynchronous/backgrounded
      mode (any mode where the `Agent` call returns control before the result is ready, leaving a
      notification to arrive later) and then end this turn to await that notification.
- [ ] State explicitly why no bounded-poll allowance is offered: unlike the CI case (a
      foreground-pollable status call) and the local-gate case (`kill -0` on a captured PID), a
      backgrounded subagent dispatch exposes no PID and no status call the dispatching agent can
      inspect from inside its own turn, so there is nothing to bound the wait with; the only
      sanctioned way to use the result within this dispatch is to have awaited it synchronously.
      Name the fork-mechanics narrative by its document and section name, with no `@`-import
      prefix (the target is source-store-only; see Risks).
- [ ] Tie the defect back to the shared rationale already stated for the other two cases: the
      harness's asynchronous detach-then-await-notification path hands the dispatch back
      unfinished with nothing guaranteed to resume it.
- [ ] Close with the explicit non-prohibition: this does not forbid or discourage ordinary nested
      delegation, only an async/backgrounded dispatch left unresolved at turn end.
- [ ] Confirm no task-number reference was introduced.

**Timing**: 0.5 hours

**Depends on**: none

**Verification Tier**: prose

**Commit Mode**: per-substep

**Files to modify**:
- `agent-system/extensions/core/agents/general-implementation-agent.md` - new
  **Dispatched-Subagent Wait Discipline** subsection appended to the Local Long-Running Command
  Discipline block

**Verification**:
- `grep -c "Dispatched-Subagent Wait Discipline" agent-system/extensions/core/agents/general-implementation-agent.md`
  returns 1.
- The new text sits between the three-way-fork closing paragraph and the
  "Derive `project_name`" paragraph: confirm by `grep -n` on all three anchors and checking line
  ordering.
- `grep -c -F 'canonical idiom VERBATIM' agent-system/extensions/core/agents/general-implementation-agent.md`
  is unchanged from its pre-edit value (the mandate's existing local-gate MUST is untouched).
- `bash agent-system/extensions/core/scripts/lint/lint-agent-contracts.sh` exits 0 (this file is a
  recorded Check H exclusion, so the new subsection must not change that outcome).
- `bash .claude/scripts/check-task-references.sh` reports no new violation for this file.
- Diff read-through confirms every changed hunk is prose inside the agent contract body, with no
  frontmatter or fenced-block change.

---

### Phase 2: Ruling record and cross-reference pointers [NOT STARTED]

**Goal**: Record the ruling (which position was taken and why the deadline fork does not
transfer) where the mandate family's other rulings already live, and point readers of both
wait-pattern files at the new subsection without duplicating the PID idiom onto a case that
cannot use it.

**Tasks**:

- [ ] Re-read `agent-system/extensions/core/context/patterns/bounded-build-waiter.md` immediately
      before editing. Note its existing ruling-record convention (`### Item 1 Ruling: ...`,
      `### Rule 5 Non-Propagation Ruling`, `### Item 3 Ruling: ...`,
      `### Item 4 Ruling: Research Agents Are Out of Scope Here, Not Dismissed`) — the new record
      follows that shape.
- [ ] Add a short ruling subsection (sibling to the existing ruling records, not inside the
      `## Canonical Agent-Contract Bullet (Generated-Copy Source)` bullet pair) recording: the
      middle position was adopted in refined form; synchronous nested delegation is outside the
      discipline; an async/backgrounded dispatch awaited across a turn boundary is prohibited
      outright rather than bounded; the reason is that no foreground-pollable liveness or status
      primitive exists for it, so a deadline-and-poll clause would describe a mechanism that does
      not exist; the capability is demonstrated but no stranding incident is confirmed, which is
      why the rule is flat rather than mechanism-mandating; and this file's own canonical bullet
      pair is deliberately not the home for the new case.
- [ ] Add one line to `bounded-build-waiter.md`'s `## Related Documentation` section pointing at
      `agents/general-implementation-agent.md`'s "Dispatched-Subagent Wait Discipline" as the
      complementary nested-subagent-dispatch case, noting that this file's PID-liveness idiom does
      not apply to it.
- [ ] Add one line to `agent-system/extensions/core/context/patterns/external-process-wait.md`'s
      `## Related Documentation` section pointing at the same subsection, noting that the
      CI-status-poll idiom does not apply to it either.
- [ ] Confirm neither edit introduced the literal strings `canonical idiom VERBATIM` or
      ``arm a `Monitor` to watch a local verification`` anywhere in `bounded-build-waiter.md`.
- [ ] Confirm no task-number reference was introduced in either file.

**Timing**: 0.5 hours

**Depends on**: 1

**Verification Tier**: prose

**Commit Mode**: per-substep

**Scope Hypothesis**: This phase asserts that `lint-agent-contracts.sh` Check H greps
`bounded-build-waiter.md` for exactly two literal strings, each occurring exactly once today
(`canonical idiom VERBATIM` -> 1, ``arm a `Monitor` to watch a local verification`` -> 1, both
re-derived by `grep -c -F` at plan-authoring time against the source-store copy). Confirm at
implementation time by re-running both `grep -c -F` counts before and after the edit and
asserting each is still exactly 1, and by reading `check_h_bounded_wait_contract_bullet`'s
`expected_must`/`expected_mustnot` extraction to confirm no third grepped string was added to
that function since.

**Files to modify**:
- `agent-system/extensions/core/context/patterns/bounded-build-waiter.md` - new ruling-record
  subsection plus one `## Related Documentation` line
- `agent-system/extensions/core/context/patterns/external-process-wait.md` - one
  `## Related Documentation` line

**Verification**:
- Both `## Related Documentation` sections contain a line naming
  `general-implementation-agent.md`'s "Dispatched-Subagent Wait Discipline"
  (`grep -c "Dispatched-Subagent Wait Discipline"` is >= 1 in each file).
- `grep -c -F 'canonical idiom VERBATIM' agent-system/extensions/core/context/patterns/bounded-build-waiter.md`
  is exactly 1, and
  `grep -c -F 'arm a `Monitor` to watch a local verification' agent-system/extensions/core/context/patterns/bounded-build-waiter.md`
  is exactly 1 — the Scope Hypothesis confirmation.
- `bash agent-system/extensions/core/scripts/lint/lint-agent-contracts.sh` exits 0 and its Check H
  section reports no new failure.
- The new ruling subsection is NOT nested under
  `## Canonical Agent-Contract Bullet (Generated-Copy Source)`'s bullet-pair block: confirm by
  `grep -n "^#"` heading ordering.
- `bash .claude/scripts/check-task-references.sh` reports no new violation for either file.
- Diff read-through confirms both files' changed hunks are prose only.

---

### Phase 3: Dispatch-liveness probe diagnostic [NOT STARTED]

**Goal**: Document the correct live-vs-stranded probe for an externally watched dispatch, with the
handoff-absence false signal named explicitly, and affirm in the same place that
`stall_suspected`'s trigger predicate is unchanged.

**Tasks**:

- [ ] Re-read `agent-system/extensions/core/docs/architecture/orchestrate-state-machine.md`
      immediately before editing, confirming the insertion point: immediately after the
      `## Abandoned Wrap-Up: Re-Prompt Once Before Accepting a No-Outcome Verdict` section
      (which ends with the "**Where this actually runs**" paragraph) and before
      `## Loop-Owned Runtime State: mt_state_file Field Reference`.
- [ ] Insert a short subsection on diagnosing dispatch liveness, stating the two discriminating
      signals: artifact mtimes actively advancing, and a live child-process tree.
- [ ] State the false signal explicitly: the absence of a handoff file is not evidence of a stall,
      because (a) the research phase never writes one in any mode — a fact this document already
      states as part of `stall_suspected`'s own scoping rationale — and (b) more generally,
      "has not reached its closing write yet" and "never will" are indistinguishable from
      presence/absence alone.
- [ ] Frame the subsection as guidance for a non-mechanical external watcher (an operator, an
      orchestrator session, a teammate relay), cross-referencing `stall_suspected`'s existing
      git-commit-gated, phase-gated design as the worked example of getting this right
      mechanically.
- [ ] State in the same place that `stall_suspected`'s trigger predicate is deliberately
      unchanged by this guidance, and that widening it with an OR against handoff-absence would
      destroy its only discriminating signal (pointing at `handoff-schema.md`'s freshness
      section, which the field's own header already cites).
- [ ] Confirm no change was made to any `stall_suspected` field description, its phase gate, or
      its commit gate — this phase adds a subsection and edits nothing existing.
- [ ] Confirm no task-number reference was introduced.

**Timing**: 0.5 hours

**Depends on**: none

**Verification Tier**: prose

**Commit Mode**: per-substep

**Files to modify**:
- `agent-system/extensions/core/docs/architecture/orchestrate-state-machine.md` - new
  dispatch-liveness-probe subsection inserted after "Abandoned Wrap-Up"

**Verification**:
- The new subsection heading exists and sits between the two anchors: confirm by `grep -n "^#"`
  and checking it falls after `## Abandoned Wrap-Up` and before
  `## Loop-Owned Runtime State`.
- The subsection names all three required elements: artifact mtimes, live child processes, and
  handoff-absence-is-not-evidence (`grep -i` for each).
- `git diff -- agent-system/extensions/core/docs/architecture/orchestrate-state-machine.md`
  consists only of added lines in the new subsection — no modified or deleted line anywhere in
  the `## The mechanical signal`, `## Loop obligation`, or `mt_state_file` field-reference blocks.
- `git diff -U0 -- agent-system/extensions/core/docs/architecture/orchestrate-state-machine.md | grep -c '^-'`
  is 0 (pure insertion; confirms no `stall_suspected` prose was altered).
- No change to `agent-system/extensions/core/scripts/orchestrate-cycle-postflight.sh`:
  `git status --short` shows that file unmodified by this task.
- `bash .claude/scripts/check-task-references.sh` reports no new violation for this file.

---

### Phase 4: Redeploy and full gate set [NOT STARTED]

**Goal**: Regenerate the deployed `.claude/` tree so the three deployed files match the source
store, and run the repository's complete gate set, attributing any failure to this change or to
pre-existing breakage.

**Tasks**:

- [ ] Before deploying, record the baseline: run
      `bash .claude/scripts/verify-deploy.sh` and capture its failure set (recent sibling plans
      on this tree recorded a 2-of-34 doc-lint/staleness failure pattern). Any failure present in
      the baseline is pre-existing, not caused by this change.
- [ ] Check for concurrent activity before deploying: `git status --short` and `git log -3`. If a
      foreign commit, a foreign uncommitted modification, or a running build this dispatch did
      not start is observed, STOP and report it per the dispatch concurrency note rather than
      proceeding.
- [ ] Run `bash agent-system/extensions/core/scripts/deploy-headless.sh` (non-destructive resync
      mode, no flags).
- [ ] Confirm each of the three deployed copies now matches its source:
      `.claude/agents/general-implementation-agent.md`,
      `.claude/context/patterns/bounded-build-waiter.md`,
      `.claude/context/patterns/external-process-wait.md`,
      `.claude/docs/architecture/orchestrate-state-machine.md`.
- [ ] Re-run `bash .claude/scripts/verify-deploy.sh` and compare against the baseline failure set.
      Any new failure is attributable to this change and must be fixed forward, not excluded.
- [ ] Record, as an explicit written statement in the summary, that `stall_suspected`'s trigger
      predicate was not changed and no new evidence was produced that would justify reopening it.
- [ ] Commit the source-store edits with targeted, per-file staging (never `git add -A`, never a
      directory or glob pathspec). `.claude/**` is gitignored and is not staged.

**Timing**: 0.5 hours

**Depends on**: 1, 2, 3

**Verification Tier**: full

**Commit Mode**: per-substep

**Scope Hypothesis**: This phase asserts that exactly four source-store files change and that
exactly four deployed `.claude/` copies correspond to them (the fifth document cited in the new
prose, `docs/fork-patterns.md`, is source-store-only and appears in no extension's
`installed_files` — re-derived at plan-authoring time via
`grep -c "fork-patterns" .claude-extensions.json` returning 0). Confirm at implementation time by
`git status --short -- agent-system/` listing exactly the four files, and by `ls` on the four
deployed paths after the deploy plus a `diff` of each against its source.

**Files to modify**:
- none planned (this phase runs the deploy and the gates; it modifies no file except by
  regenerating the gitignored `.claude/` tree)

**Verification**:
- Full gate set for this tier: `bash .claude/scripts/verify-deploy.sh` (source-store path
  `agent-system/extensions/core/scripts/verify-deploy.sh`) passes, or every remaining failure is
  shown present in the pre-deploy baseline with the baseline output quoted.
- `diff` of each of the four source files against its deployed `.claude/` counterpart is empty.
- `bash .claude/scripts/check-task-references.sh` exits 0 for `agent-system/**`.
- `bash .claude/scripts/lint/lint-agent-contracts.sh` exits 0 (or the deployed-path equivalent).
- `git diff --staged` reviewed before the commit; `git status --short` confirms no file outside
  this task's four-file scope is staged.
- `git log -1` after the commit shows only this task's own files.

---

## Testing & Validation

- [ ] All four source-store files carry their intended additions; `git status --short --
      agent-system/` lists exactly those four and nothing else.
- [ ] `grep -c "Dispatched-Subagent Wait Discipline"` is >= 1 in each of
      `general-implementation-agent.md`, `bounded-build-waiter.md`, `external-process-wait.md`.
- [ ] The new mandate subsection contains both a permitted carve-out for synchronous nested
      delegation and a MUST NOT for an async/backgrounded dispatch awaited across a turn
      boundary, and states why no bounded-poll allowance is offered.
- [ ] The ruling record in `bounded-build-waiter.md` names which of the three positions was taken
      and why, and is not nested inside the canonical generated-copy bullet pair.
- [ ] The probe-diagnostic subsection names artifact mtimes, live child processes, and the
      handoff-absence false signal explicitly.
- [ ] `lint-agent-contracts.sh` Check H still finds its two grepped strings exactly once each in
      `bounded-build-waiter.md`.
- [ ] `check-task-references.sh` exits 0: no task-number reference landed under
      `agent-system/**`.
- [ ] `stall_suspected`'s trigger predicate is byte-identical to its pre-task state:
      `git diff -- agent-system/extensions/core/scripts/orchestrate-cycle-postflight.sh` is empty
      for this task's commits.
- [ ] `verify-deploy.sh` green, or every failure attributed to the pre-deploy baseline with
      evidence.
- [ ] Deployed copies match their sources for all four files.

## Artifacts & Outputs

- `agent-system/extensions/core/agents/general-implementation-agent.md` — new
  **Dispatched-Subagent Wait Discipline** subsection
- `agent-system/extensions/core/context/patterns/bounded-build-waiter.md` — new ruling record plus
  a `## Related Documentation` pointer
- `agent-system/extensions/core/context/patterns/external-process-wait.md` — a
  `## Related Documentation` pointer
- `agent-system/extensions/core/docs/architecture/orchestrate-state-machine.md` — new
  dispatch-liveness-probe subsection
- Regenerated `.claude/**` deploy tree (gitignored, not committed)
- `specs/354_bound_agent_wait_on_dispatched_subagent/summaries/01_*-summary.md` — execution
  summary, including the explicit written statement that `stall_suspected` was not changed

## Rollback/Contingency

All four edits are pure prose insertions into existing markdown files, each committed
per-substep, so a revert is a `git revert` of the relevant commit (or
`git checkout <pre-task-sha> -- <path>` for a single file) followed by
`bash agent-system/extensions/core/scripts/deploy-headless.sh` to regenerate the deployed tree.
`.claude/**` is gitignored and the deploy is idempotent, so no deploy state needs separate
rollback.

If Phase 4's post-deploy `verify-deploy.sh` surfaces a failure attributable to this change that
cannot be fixed forward within the phase, close the phase `[PARTIAL]`, write the handoff with the
concrete resume command, and return `status: "partial"` — do not discard uncommitted changes to
reach a passing gate (`rules/error-handling.md`'s write-gating constraint).

If the concurrency check in Phase 4 observes foreign work on the tree, do not deploy: close the
phase `[PARTIAL]` with the deploy named as the outstanding step and report the observation, as a
sibling plan on this tree has already done once for the same reason.
