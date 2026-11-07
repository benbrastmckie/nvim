# Implementation Plan: Task #478

- **Task**: 478 - Ungate lint-agent-contracts.sh Check J: replace the content gate with a curated
  in-scope list so removal of a handoff-writer section is detected
- **Status**: [IMPLEMENTING]
- **Effort**: 3.5 hours
- **Dependencies**: None
- **Research Inputs**: `specs/478_ungate_lint_check_j_handoff_contract/reports/01_ungate-check-j-curated-list.md`
- **Artifacts**: plans/01_ungate-check-j-curated-list.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Check J's subject set is currently derived from the very content it verifies: a one-line content
gate (`grep -qF '.orchestrator-handoff.json' "$f" || continue`) means an agent file that removes
its entire handoff-writing section also removes the only occurrence of that literal string, drops
out of the loop, and the lint goes green at exactly the moment the contract is violated. The fix
inverts the default: iterate `enumerate_dispatchable_agents()` with no content pre-filter, skip
only a file that is either explicitly listed in a new, short, per-entry-justified exclusion array
or whose own matching heading states "never write one," and FAIL by name on everything else. A
second, cheap detector closes the inverted drift direction (a stale exclusion entry), and the
existing fixture suite gains the cases the content gate could not express.

### Research Integration

The research report supplied four findings this plan builds on directly rather than re-deriving:

1. **The measured population shape.** All dispatchable agent files resolve into exactly three
   justified buckets: 44 carrying a recognized writer heading, 23 `*research*agent.md` files
   carrying the documented "never write one" contract (correctly handled today by the existing
   return-2 branch, because the string genuinely IS present in those files by design), and 8
   files with zero mention of the string anywhere, each individually verified to be invoked only
   via the forked-subagent pattern from inside another skill or agent and never reached through a
   `skill-orchestrate` `dispatch[]`/`aux_dispatch[]` row. This plan phase independently
   re-confirmed the 8-file set: every one has zero handoff-section headings and zero occurrences
   of the literal string.
2. **The convention to match, named.** `lint-agent-contracts.sh` carries two distinct flavors of
   curated-array lint. The INCLUDED-style flavor (Checks C/G/H/M) hand-picks a small subset of a
   large population and is drift-prone in the silent direction — which is precisely why Check N
   exists as a bolted-on completeness net for it. The EXCLUDED-style flavor (Check E's
   `EXCLUDED_TERMINAL_STATUS_RELATIVE_PATHS`, Check F's
   `EXCLUDED_ARTIFACTS_TEMPLATE_RELATIVE_PATHS`, Check N's own
   `CHECK_G_EXCLUDED_RELATIVE_PATHS`/`CHECK_M_EXCLUDED_RELATIVE_PATHS`) puts almost the whole
   population in scope and names the few genuine exceptions, each with its own reason comment.
   Check J's measured 44-writers-vs-8-exceptions shape matches the EXCLUDED-style precedent, and
   that is the convention this plan matches. Both flavors live as literal bash arrays inside
   `lint-agent-contracts.sh` itself; there is no precedent in this file for a
   frontmatter-declared opt-in or a separate registry file, which settles the "where" question.
3. **No Check-N-equivalent net is needed.** Because the redesigned check iterates the full
   enumeration and fails by default, a brand-new agent file is in scope the moment it is added —
   nothing has to remember to register it. The one case requiring deliberate action is a new
   forked-subagent-pattern-only agent, and until it is added to the exclusion array the lint
   fails loudly by name. This is the opposite, safer failure direction from both the original
   content gate (silent pass) and from Checks C/G/M's INCLUDED-style risk (silent omission).
4. **The "dispatch-derived predicate" history, checked as the description required.** That idea
   was neither rejected on merit nor abandoned as unworkable: it was merged into a separate
   record during a backlog consolidation and then *completed* there, for
   `orchestrate-cycle-postflight.sh` — a runtime script with a live dispatch row carrying a real
   `handoff_path`/`orchestrator_mode` field to derive from. It does not transfer here because
   `lint-agent-contracts.sh` is a static lint over markdown files with no dispatch context at
   lint time; "dispatch-derived" is a category error for Check J. The correct analog for a
   markdown-file lint is the role/content-derived classification every other check in the file
   already uses.

Two cautions carried forward from the research. First, do **not** narrow the in-scope set to the
role-named writer list in `docs/architecture/handoff-schema.md`'s "Handoff Writers" table: the
founder and present extensions route many additional per-task-type terminal and plan agents
through the same `orchestrator_mode`-gated writer contract, and those files already correctly
carry the canonical section. Narrowing to the role-named subset would regress those
currently-correct files to unchecked status — reproducing this task's own hole one level removed.
Second, Check J's universe must be sourced from `enumerate_dispatchable_agents()` (frontmatter-
based, already correct for both the `*-implementation-agent` and `*-implement-agent` naming
variants) and never from a freshly-invented filename glob: Check N's own
`'*implementation*agent.md'` glob demonstrably misses the `*-implement-agent.md` variant, and
that substring trap must not be reproduced in a new location. Check N's glob gap is out of this
task's file scope and recorded separately.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No `roadmap_path` was provided in this dispatch, so no roadmap consultation was performed.

## Goals & Non-Goals

**Goals**:

- Replace Check J's content gate with a fail-closed-by-default iteration over
  `enumerate_dispatchable_agents()`, so that removing a handoff-writer section from a file that
  is required to carry one turns the lint RED.
- Establish the in-scope criterion from what makes the section necessary (an agent that writes,
  or is contractually expected to write, `.orchestrator-handoff.json` under `orchestrator_mode`)
  and record the exceptions — not the inclusions — in a short, per-entry-justified EXCLUDED-style
  array matching the file's own established precedent.
- Keep FAIL as the severity, consistent with every check in the file except Check I's
  separately-reasoned advisory WARN.
- Close the inverted drift direction the exclusion array itself introduces, so a stale exclusion
  entry is a finding rather than a silent permanent skip.
- Extend `test-lint-agent-contracts-handoff-section.sh` with the cases the content gate cannot
  express, above all a required-but-sectionless file that must FAIL.
- Confirm no collateral damage to the other checks sharing the file, and land the change in the
  deployed tree.

**Non-Goals**:

- Fixing Check N's `'*implementation*agent.md'` glob gap (a different check's pre-existing gap,
  outside this task's file scope; recorded separately in the issue log).
- Adding the founder/present writer-registration pointer to
  `docs/architecture/handoff-schema.md`'s "Handoff Writers" section (a docs file outside this
  task's file scope; recorded as a context-extension recommendation).
- Changing the existing return-2 "never write one" skip branch, which already correctly covers
  every research agent via content and needs no curation.
- Introducing a frontmatter-declared opt-in or a separate registry file as the list's home —
  rejected because this file has no such precedent and the EXCLUDED-style literal array does.
- Building a Check-N-style bolted-on completeness net, which the fail-closed default makes
  redundant.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| A future forked-subagent-pattern-only agent FAILs the lint until registered in the exclusion array | L | H | This is the intended, safer failure direction and the point of the design. The FAIL message must name the file AND the exclusion array by name, so the remedy is a one-line addition rather than an investigation. |
| An exclusion entry goes stale (file renamed/deleted, or the agent later becomes dispatch-routed) and silently keeps a real writer unchecked | M | M | Phase 2's stale-exclusion detector: an entry naming a nonexistent file, or a file that now carries a recognized writer heading, is itself a FAIL. Confirmed not to fire today — all 8 entries exist and all have zero writer headings. |
| The exclusion array is written in the wrong path form and silently matches nothing, re-opening the hole | H | M | `rel_path()` strips `$REPO_ROOT/`, so entries MUST use the full `agent-system/extensions/<ext>/agents/<file>.md` form, exactly as Check E's and Check F's arrays do. Check N's shorter `<ext>/agents/...` form is computed differently and MUST NOT be copied. Phase 1 verification asserts each entry matches a real enumerated file. |
| Narrowing the in-scope set to the architecture doc's role-named writer table regresses the founder/present terminal agents to unchecked | H | L | Explicit Non-Goal and an explicit MUST NOT in Phase 1's steps; the design records exceptions only, never inclusions, so no role list is ever consulted. |
| Removing the gate surfaces a latent failure in a file nobody expected to be in scope | M | L | The research measured zero currently-misclassified files, and this phase independently re-confirmed the 8-file no-mention set. Phase 1's verification is a full lint run diffed against the recorded 421-passed / 15-warn / 0-failed baseline. |
| A sibling task editing `lint-agent-contracts.sh` concurrently causes a confusing failure | M | M | Per the dispatch's territory notes, re-read the file immediately before each edit, stage only this task's own hunks with an explicit file list, never a directory or glob add, and never run `git-snapshot.sh` in its reverting default mode. Treat an unexpected failure outside this task's file scope as possibly a sibling's in-flight edit and report rather than "fix" it. |

## Implementation Phases

**Dependency Analysis**:

| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |
| 3 | 3 | 2 |
| 4 | 4 | 3 |

Phases within the same wave can execute in parallel. This plan is a strict chain: each phase
edits or verifies the artifact the previous one produced.

---

### Phase 1: Replace the content gate with the curated EXCLUDED-style array [COMPLETED]

**Goal**: Check J iterates every dispatchable agent with no content pre-filter and FAILs by name
on any file that is neither a recognized writer, nor a "never write one" contract, nor an
explicitly justified exclusion. Removal of a handoff-writer section turns the lint red.

**Tasks**:

- [x] Re-read `agent-system/extensions/core/scripts/lint/lint-agent-contracts.sh` immediately
      before editing (a sibling task claims this same file for a different check). *(completed)*
- [x] Declare `CHECK_J_EXCLUDED_RELATIVE_PATHS` immediately above
      `check_j_handoff_section_artifacts()`, following the file's own location pattern: a header
      comment documenting the derivation criterion ("an agent that writes, or is contractually
      expected to write, `.orchestrator-handoff.json` under `orchestrator_mode`"), a reproduce
      command, and one per-entry reason comment each — never "see above" as the whole
      justification, matching `CHECK_G_EXCLUDED_RELATIVE_PATHS`'s comment style. *(completed)*
- [x] Populate it with the 8 confirmed forked-subagent-pattern-only files, in the FULL
      `agent-system/extensions/...` path form that `rel_path()` produces:
      `core/agents/code-reviewer-agent.md`, `core/agents/meta-builder-agent.md`,
      `core/agents/spawn-agent.md`, `cslib/agents/cslib-vet-agent.md`,
      `filetypes/agents/document-agent.md`, `literature/agents/literature-agent.md`,
      `present/agents/pptx-assembly-agent.md`, `present/agents/slide-critic-agent.md` — each
      prefixed `agent-system/extensions/`. Each entry's reason comment states that the agent is
      invoked only via the forked-subagent pattern from inside another skill or agent and never
      reaches a `skill-orchestrate` dispatch row, so `orchestrator_mode` never applies to it.
      *(completed)*
- [x] Add `is_excluded_from_check_j()`, mirroring `is_excluded_from_terminal_status()` /
      `is_excluded_from_artifacts_template()` verbatim in shape. *(completed)*
- [x] Delete the content gate line `grep -qF '.orchestrator-handoff.json' "$f" || continue`.
      *(completed)*
- [x] Insert the exclusion skip in its place: if `is_excluded_from_check_j "$rel"`, emit a
      `log_info` skip notice naming the file and the array, and `continue`. *(completed)*
- [x] In the `_check_j_locate_handoff_section` return-1 branch, split the message by whether the
      file mentions the string at all. If it does, keep the existing heading-drift FAIL wording.
      If it does NOT, emit a new FAIL stating that the file is a required handoff writer with no
      handoff-writing section at all, and naming `CHECK_J_EXCLUDED_RELATIVE_PATHS` as the place
      to record a genuine exception. Both branches set `any_writer=true`. *(completed)*
- [x] MUST NOT: do not derive the in-scope set from `docs/architecture/handoff-schema.md`'s
      role-named "Handoff Writers" table, and do not add an inclusion array of writer files —
      the design records exceptions only. *(confirmed: not done)*
- [x] MUST NOT: do not introduce a filename glob as Check J's universe;
      `enumerate_dispatchable_agents()` stays the sole source of the population. *(confirmed: not
      done — enumerate_dispatchable_agents() remains the sole population source)*
- [x] Stage and commit only this file's own hunks with an explicit single-file pathspec.
      *(completed below)*

**Timing**: 1 hour

**Depends on**: none

**Verification Tier**: local

**Tier Justification**: `scripts/tests/test-lint-agent-contracts-handoff-section.sh` plus a full
`lint-agent-contracts.sh` run are the specific covering checks for an edit confined to one
function and one new array in a single shell script, and the suite resolves `LINT_SRC` by a plain
source-store-sibling path (not `resolve_candidate()`), so it exercises the edited script rather
than a stale deployed copy.

**Scope Hypothesis**: The exclusion array holds exactly 8 entries and the full lint stays at the
recorded 421-passed / 15-warn (Check I only) / 0-failed baseline, because excluded files emit
`log_info` rather than `log_pass`. The implementer must confirm both by running the lint and
comparing counts, not assume them — the independently re-measured population count differed from
the research report's stated 81 under a cruder dispatchability predicate (the 8-file no-mention
set itself reproduced exactly), so the pass-count arithmetic is a hypothesis, not a fact.

**Files to modify**:

- `agent-system/extensions/core/scripts/lint/lint-agent-contracts.sh` - add
  `CHECK_J_EXCLUDED_RELATIVE_PATHS` + `is_excluded_from_check_j()`; remove the content gate from
  `check_j_handoff_section_artifacts()`; split the return-1 FAIL message into heading-drift and
  missing-section variants.

**Verification**:

- `bash agent-system/extensions/core/scripts/lint/lint-agent-contracts.sh` exits 0 with 0 failed
  and warnings confined to Check I; record the passed/warn/failed counts and compare against the
  421 / 15 / 0 baseline, explaining any delta rather than accepting it.
- Check J's own output section names every one of the 8 exclusions in a skip INFO line — proving
  each array entry matched a real enumerated file and none is a silently-nonmatching path form.
- `bash agent-system/extensions/core/scripts/tests/test-lint-agent-contracts-handoff-section.sh`
  still reports 6/6 passed (the pre-existing cases are unaffected by the gate removal).

---

### Phase 2: Close the exclusion array's own inverted drift direction [COMPLETED]

**Goal**: A stale exclusion entry is a finding, not a silent permanent skip. This is the
"mechanically checkable criterion" half of the drift-hazard requirement; Phase 1 supplied the
other half (a qualifying-but-unregistered agent fails loudly by construction).

**Tasks**:

- [x] Re-read `lint-agent-contracts.sh` immediately before editing. *(completed)*
- [x] Inside `check_j_handoff_section_artifacts()`, before the enumeration loop, sweep every
      `CHECK_J_EXCLUDED_RELATIVE_PATHS` entry and FAIL on either staleness condition: (a) the
      entry names a path that does not exist under `$REPO_ROOT`, or (b) the file exists and now
      carries a recognized writer heading (the same
      `^#+.*(\`\.orchestrator-handoff\.json\`|Wrap-Up)` pattern
      `_check_j_locate_handoff_section()` uses), meaning the recorded exception is no longer
      true and the file must be removed from the array so it is checked on its merits.
      *(completed: `_check_j_sweep_stale_exclusions()`)*
- [x] Word each FAIL so the remedy is explicit: remove the entry from the array (condition b) or
      correct/remove the path (condition a). *(completed)*
- [x] Keep the sweep's severity at FAIL, consistent with Phase 1's finding on tiering.
      *(completed)*
- [x] Guard condition (a) so it cannot fire spuriously inside a fixture `REPO_ROOT` tree that
      legitimately contains only a subset of the real agent files — this is the one real design
      constraint of this phase, and it is why the fixture suite in Phase 3 must place a real
      excluded file's path in its scratch tree. Decide and document the resolution in a comment:
      either condition (a) applies only when the file's extension directory itself exists in the
      tree, or the sweep is scoped to entries whose extension directory is present. Do not leave
      the interaction undocumented. *(completed: per-extension `agents/` directory presence
      guard, documented in `_check_j_sweep_stale_exclusions()`'s header comment — an entry is
      evaluated only if `$AGENTS_ROOT/<ext>/agents` exists in the current tree)*
- [x] Stage and commit only this file's own hunks with an explicit single-file pathspec.
      *(completed below)*

**Timing**: 45 minutes

**Depends on**: 1

**Verification Tier**: local

**Tier Justification**: The same `test-lint-agent-contracts-handoff-section.sh` suite plus a full
`lint-agent-contracts.sh` run cover this edit, which adds one bounded sweep to the same function
Phase 1 touched and introduces no new file, no new consumer, and no cross-script surface.

**Scope Hypothesis**: The new sweep emits zero findings against the real tree today — all 8
entries exist and all 8 carry zero writer headings, independently confirmed during planning. The
implementer must re-run and see a clean sweep; a finding here means either an entry's path form
is wrong (a Phase 1 defect) or a sibling task has edited one of the 8 files.

**Files to modify**:

- `agent-system/extensions/core/scripts/lint/lint-agent-contracts.sh` - add the stale-exclusion
  sweep to `check_j_handoff_section_artifacts()`.

**Verification**:

- Full `lint-agent-contracts.sh` run: still 0 failed, the stale-exclusion sweep reports clean.
- Negative control, run in a scratch copy so the working tree is never mutated: copy the script
  to the scratchpad, append a nonexistent path to the array in the copy, run the copy, and
  confirm a named FAIL; then append a path to a real writer file and confirm the second FAIL
  branch fires. Discard the copy.
- `test-lint-agent-contracts-handoff-section.sh` still 6/6 — in particular the sweep must not
  fire inside the suite's narrow fixture tree.

---

### Phase 3: Extend the fixture suite with the cases the content gate could not express [NOT STARTED]

**Goal**: `test-lint-agent-contracts-handoff-section.sh` is the regression home for this hole.
After this phase it contains a case that fails under the old content gate and passes under the
new design, so the hole cannot silently reopen.

**Tasks**:

- [ ] Re-read `agent-system/extensions/core/scripts/tests/test-lint-agent-contracts-handoff-section.sh`
      immediately before editing.
- [ ] Add case (b), the central regression test, FIRST: a minimal dispatchable fixture agent file
      under `agent-system/extensions/fixture/agents/` with zero mention of
      `.orchestrator-handoff.json` anywhere and no entry in the exclusion array. Assert a named
      `[FAIL]` line for it inside the Check-J-scoped output slice, and assert the FAIL text names
      `CHECK_J_EXCLUDED_RELATIVE_PATHS` so the remediation pointer itself is regression-tested.
- [ ] Confirm case (b) has real bug-detection power without mutating the working tree: copy the
      current `lint-agent-contracts.sh` to the scratchpad, re-add the deleted content gate line
      in the copy, point the suite at the copy via a one-off `LINT_SRC` override run, and confirm
      case (b) does NOT fail there. Record the observation in the phase notes, then discard the
      copy. A regression test that would also pass against the bug is worthless, and this is the
      cheapest available proof that it would not.
- [ ] Add case (c): a fixture file placed at one of the REAL excluded relative paths inside the
      scratch tree (e.g. `agent-system/extensions/core/agents/code-reviewer-agent.md`), minimal
      and with zero mention of the string. Assert it produces the exclusion skip INFO line and
      that NO `[PASS]` or `[FAIL]` line names it — mirroring the existing case-5 assertion shape
      for a decided skip. Using a real excluded path avoids polluting the production array with a
      fixture-namespace entry and avoids inventing a test-only override seam.
- [ ] Case (a) — a curated file WITH the section passes — is already covered by existing cases 1
      and 2 (prose-form and JSON-form writers); confirm that explicitly rather than adding a
      redundant fixture, and say so in the suite's header comment.
- [ ] Case (d) — a qualifying-but-unregistered file produces the intended finding — is the SAME
      mechanism as case (b) under the fail-closed design, since any unregistered dispatchable
      agent is in scope by default. State that equivalence in the header comment rather than
      adding a duplicate fixture, and additionally cover Phase 2's stale-exclusion sweep with one
      assertion that the sweep reports clean against the fixture tree (the condition-(a)
      interaction Phase 2 documented).
- [ ] Update the suite's header comment block to describe the new case count and each case's
      intent, matching the existing numbered-list style.
- [ ] Stage and commit only this file's own hunks with an explicit single-file pathspec.

**Timing**: 1 hour

**Depends on**: 2

**Verification Tier**: local

**Tier Justification**: `bash agent-system/extensions/core/scripts/tests/run-all.sh --only` over
the four lint-agent-contracts suites is the specific covering check: the edit is confined to one
test file plus its own scratch fixtures, touches no production code path, and those four suites
are the complete set of consumers of the script under test.

**Scope Hypothesis**: The suite grows from 6 assertions to 9 (case b, case c, and the
stale-exclusion-clean assertion), with cases (a) and (d) covered by existing cases and by case
(b)'s mechanism respectively. The implementer must confirm the final assertion count and that
every assertion passes, rather than assuming the arithmetic.

**Files to modify**:

- `agent-system/extensions/core/scripts/tests/test-lint-agent-contracts-handoff-section.sh` - add
  the new fixture files to `build_fixture_tree()`, add the new assertions, update the header
  comment block.

**Verification**:

- `bash agent-system/extensions/core/scripts/tests/test-lint-agent-contracts-handoff-section.sh`
  reports all assertions passed, 0 failed.
- The scratch-copy negative control above confirmed case (b) does not fire against a script with
  the content gate restored.
- `bash agent-system/extensions/core/scripts/tests/run-all.sh --only` over the four lint suites
  passes.

---

### Phase 4: Full verification sweep and redeploy [NOT STARTED]

**Goal**: Confirm no collateral damage to the other checks sharing `lint-agent-contracts.sh`,
land the change in the deployed tree, and close the task against the full gate set.

**Tasks**:

- [ ] Run the full lint and all four sibling suites in the FOREGROUND with a bounded timeout,
      redirecting each run's output to a file under the scratchpad and grepping that file:
      `lint-agent-contracts.sh`, `test-lint-agent-contracts.sh`,
      `test-lint-agent-contracts-await-notification.sh`,
      `test-lint-agent-contracts-heartbeat.sh`, `test-lint-agent-contracts-handoff-section.sh`.
- [ ] Compare against the research-recorded baseline — lint 421 passed / 15 warn / 0 failed, and
      61/61, 6/6, 6/6, 6/6 — and account for every delta explicitly. The only expected deltas are
      Check J's own new skip INFO lines and the handoff-section suite's new assertion count.
- [ ] Redeploy via `agent-system/extensions/core/scripts/deploy-headless.sh` using the
      bounded-wait idiom (`timeout 540`, Bash tool timeout raised to 600000), waiting to
      `RESULT=landed_verify_clean`. Read `context/patterns/bounded-build-waiter.md` before
      waiting: a hard timeout, writer liveness via `kill -0` on the captured PID, never
      `ps | grep` or `pgrep -f`, one waiter per log.
- [ ] Re-run `lint-agent-contracts.sh` and the handoff-section suite once more after the
      redeploy, to confirm the deployed tree agrees with the source store.
- [ ] Confirm no file landing under `agent-system/**` carries a task-number reference or
      record-versioning language (both are permitted in the task description and in `specs/**`,
      neither is permitted in the edited files).
- [ ] Write the implementation summary and run the task's full gate set.

**Timing**: 45 minutes

**Depends on**: 3

**Verification Tier**: full

**Scope Hypothesis**: The comparison baseline quoted above (lint 421 passed / 15 warn / 0 failed;
suites 61/61, 6/6, 6/6, 6/6) is the research phase's recorded measurement, not a fact about the
tree at this phase's run time — three sibling records nominally claim these same files and one
claims `lint-agent-contracts.sh` for a different check, so the baseline may legitimately have
moved. The implementer must re-establish it by running each command and reading its exit status,
and must attribute every delta to a named cause (this task's own edits, or a sibling's) rather
than treating a mismatch as either noise or a regression by default.

**Files to modify**:

- `__WHOLE_TREE__` - `deploy-headless.sh` regenerates the entire deployed tree, so this phase
  carries a whole-tree claim and must serialize against any concurrent task that also
  regenerates it.
- `specs/478_ungate_lint_check_j_handoff_contract/summaries/01_ungate-check-j-curated-list-summary.md` -
  implementation summary.

**Verification**:

- The complete gate set for this task runs and passes, unnarrowed: the full
  `lint-agent-contracts.sh`, the four sibling suites, `run-all.sh`, and `verify-deploy.sh` with
  no `--only-gate` narrowing.
- `deploy-headless.sh` reached `RESULT=landed_verify_clean`.
- Post-redeploy re-run of the lint and the handoff-section suite agrees with the pre-redeploy
  run.
- Every delta from the recorded baseline is accounted for in the summary, with the counts quoted
  rather than characterized.

---

## Testing & Validation

- [ ] A dispatchable agent file required to carry a handoff-writer section, with the section
      removed entirely, makes `lint-agent-contracts.sh` FAIL by name — the case the content gate
      could not express.
- [ ] That same case does NOT fail against a copy of the script with the content gate restored
      (proof of bug-detection power).
- [ ] A file in `CHECK_J_EXCLUDED_RELATIVE_PATHS` with no handoff section is a decided skip: an
      INFO line, never a `[PASS]` or `[FAIL]`.
- [ ] All 23 research agents remain decided skips via the untouched return-2 "never write one"
      branch.
- [ ] All 44 writer-shaped agents, including the founder/present per-task-type terminal agents,
      remain checked and passing — none regressed to unchecked.
- [ ] A stale exclusion entry (nonexistent path, or a path that now carries a writer heading) is
      itself a FAIL.
- [ ] The four sibling suites and the full lint show no regression against the recorded baseline.
- [ ] `verify-deploy.sh` is clean after redeploy.

## Artifacts & Outputs

- `agent-system/extensions/core/scripts/lint/lint-agent-contracts.sh` — ungated Check J, new
  `CHECK_J_EXCLUDED_RELATIVE_PATHS` array with per-entry reason comments,
  `is_excluded_from_check_j()`, split missing-section vs. heading-drift FAIL messages, and the
  stale-exclusion sweep.
- `agent-system/extensions/core/scripts/tests/test-lint-agent-contracts-handoff-section.sh` —
  extended fixture suite covering removal, exclusion, and stale-exclusion.
- The regenerated deployed tree.
- `specs/478_ungate_lint_check_j_handoff_contract/summaries/01_ungate-check-j-curated-list-summary.md`.

## Rollback/Contingency

Both edited files are tracked and each phase commits its own hunks separately, so reverting is a
per-phase `git revert` of the relevant commit followed by a redeploy. If the lint shows failures
that cannot be attributed to this task's own edits, check `git log` first to confirm the work is
not a sibling task's in-flight edit — the dispatch names three records nominally claiming these
same files, and one claiming `lint-agent-contracts.sh` for a different check — and report rather
than "fix" a foreign change. If an intentional rollback requires discarding uncommitted work,
take a checkpoint with `git-snapshot.sh --no-revert` first; never run `git-snapshot.sh` in its
reverting default mode under the concurrency this cycle carries.
