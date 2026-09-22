# Implementation Plan: Task #221

- **Task**: 221 - Correct the lean implementation-agent contracts: build-verdict method, waiter teardown, no-revert snapshot
- **Status**: [NOT STARTED]
- **Effort**: 3.5 hours
- **Dependencies**: 172, 173, 194 (all completed)
- **Research Inputs**: specs/221_lean_build_verdict_evidence_contracts/reports/01_build_verdict_evidence_contracts.md
- **Artifacts**: plans/01_build-verdict-evidence-contracts.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

This task edits documentation and contracts only. It adds pointer-based text to five source-store
files so that (1) the evidence for a build verdict is defined in one place,
`long-builds.md` "Reading the build's verdict"; (2) the passive-progress section says where a PID
comes from and bans `pgrep -f` patterns that match the polling shell itself; (3) the three
`build_passed` sites in the lean agents say how the verdict is obtained; (4) the teardown rule
covers the supersession case and lists the lean agents as fix sites; and (5) both lean agents
require `git-snapshot.sh --no-revert` under `orchestrator_mode`. A final phase redeploys `.claude/`
and diffs it against the source store.

### Research Integration

The report confirmed the guard-side work is already in the source store: the `result` subcommand,
the "READING THE VERDICT" header and help block, the STATUS line, the `.lake/build-guard.{result,stdout,stderr,log}`
capture paths, and the `holder_pid`/`kill -0` idiom with its `pgrep -f` prohibition. It also
confirmed the bounded-waiter idiom lives in `bounded-build-waiter.md`. What remains is four
verdict/PID gaps, one teardown-wiring gap and one `--no-revert` gap, all inside the five
`file_scope` files. The report also found that `general-implementation-agent.md` has no general
"orchestrator_mode means --no-revert" bullet. Its only `--no-revert` use is in the Stage 4C
context-pressure checkpoint. The new bullet therefore copies that sentence's parenthetical style
and takes its hazard wording from `git-snapshot.sh`'s own header. It is not a verbatim copy.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No roadmap consultation requested for this dispatch.

## Goals & Non-Goals

**Goals**:
- Define the three-tier verdict evidence hierarchy exactly once, in `long-builds.md`, ordered
  strongest last.
- State the un-piped exit-code prohibition exactly once (in the same section).
- Close the PID-source gap and ban self-matching `pgrep -f` patterns in "Passive progress checks".
- Make every `build_passed` / phase-completion verdict site name its method by pointing at the anchor.
- Wire the teardown rule (including supersession) and the bounded-waiter idiom into both lean
  agents by pointer only.
- Add the `--no-revert` bullet to both lean agents, with its one-line rationale.
- Redeploy and confirm the deployed `.claude/` copies match the source store.

**Non-Goals**:
- Editing `lake-build-guard.sh` or `tests/test-lake-build-guard.sh`.
- Editing `skill-lake-repair/SKILL.md`. Its `$(...)` capture is correct.
- Editing `core/scripts/git-snapshot.sh`, `core/rules/git-workflow.md`, or the plan format.
- Restating the bounded-waiter contract or the teardown rule inside the lean files.
- Fixing the other two concurrent-dispatch failure modes (commit bleed, `.lake` contention).
- Any edit under `.claude/**`.

## Decisions

- **Verdict bar per site type.** One rule, applied by site type rather than chosen file by file:
  - *Terminal full-project verification*: plain agent Final Verification step 4, and hard agent
    Stage 6 step 4. Requires Tier 1 (un-piped guard exit or `result`), plus Tier 2 (success line
    and zero `error:` count over stdout and stderr), plus Tier 3 (`.olean` newer than source) for
    every module the task touched.
  - *Scoped phase-end check*: hard agent Stage 4 step D. Requires Tier 1 plus Tier 3 for the
    phase's scoped module or modules. Tier 2 is optional there.
  - Each site states its bar in one line and points at the anchor. The hierarchy itself is never
    copied.
- **Anchor name**: `## Reading the build's verdict` in `long-builds.md`. Every pointer cites the
  file plus that heading, never a line number.
- **Placement**: the verdict section goes right after "Passive progress checks" and its liveness
  caveat, before "Blocking on a detached build". The order is then: interim observation, then the
  terminal outcome, then blocking.
- **`--no-revert` bullet placement**: in each lean agent, next to the `orchestrator_mode` /
  `.orchestrator-handoff.json` section, which is the file's existing orchestrator-mode locus.
- **Background-harness verdict**: the step D and step 4 commands run via
  `Bash(run_in_background: true)` without a pipe. The harness-reported exit code is therefore the
  guard's own, which is Tier 1. The pointer says this explicitly so nobody later "improves" the
  command by adding a `| tail`.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| The hierarchy or the pipe prohibition gets duplicated across files | M | M | Phase 6 greps all five files and fails if the hierarchy text or the "pipe's exit code" prohibition appears outside `long-builds.md` |
| New text recommends `pgrep -f` in a self-matching form | H | L | The only positive `pgrep -f` examples use the bracket trick; Phase 6 greps `agent-system/extensions/lean/` for every `pgrep` and reviews each hit |
| Pointer targets drift (heading renamed) | M | L | Phase 6 checks that every pointer's heading text exists verbatim in its target file |
| Task numbers leak into deliverables | M | M | Run `check-task-references.sh` (or the blocking hook) over touched files in Phase 6 |
| Deploy transforms files, so a byte diff against the source fails spuriously | L | M | Scope Hypothesis in Phase 6: confirm whether the copies are verbatim; if merged or templated, diff the relevant sections instead |
| Case 21 of the guard test suite breaks | L | L | No guard or test file is touched; Phase 6 re-runs the suite as a regression check |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1, 2 | -- |
| 2 | 3, 4, 5 | 1, 2 |
| 3 | 6 | 3, 4, 5 |

Phases in the same wave can run in parallel. Phases 4 and 5 touch different files.

### Phase 1: Verdict anchor and PID-source fix in long-builds.md [NOT STARTED]

**Goal**: Add the single canonical verdict-evidence section and close the passive-progress PID
vacuum, in `agent-system/extensions/lean/context/project/lean4/operations/long-builds.md`.

**Tasks**:
- [ ] Add a new `## Reading the build's verdict` section between "The liveness caveat" and
      "Blocking on a detached build". List the evidence strongest last:
      (1) the guard's own exit code, captured un-piped (`... > <log> 2>&1; GUARD_EXIT=$?`), or the
      guard's `result` subcommand. Point at the guard's "READING THE VERDICT" header block and
      `--help` for the exit-code bands instead of restating them.
      (2) the `Build completed successfully (N jobs)` line in the captured output together with
      `grep -c 'error:'` returning 0 over both captured stdout and captured stderr. Name the capture
      files (`.lake/build-guard.stdout` / `.stderr`) by pointer to the guard's documented paths.
      (3) strongest: for each touched module, a check that its `.olean` is newer than its source,
      because this proves the module is present in the build, not merely that nothing complained.
- [ ] State the prohibition once, in that section: never pipe the guard into
      `tail`/`head`/`grep` and then read `$?`, because that is the pipe's exit code, not the
      guard's. Redirect to a log and capture `GUARD_EXIT=$?` instead.
- [ ] In "Passive progress checks", add a lead-in naming the PID source: `holder_pid` from the
      guard's result record, or `lake-build-guard.sh status --verbose`.
- [ ] Add the prohibition: any `pgrep -f` pattern naming the guard, the watcher, or the wrapper
      script matches the polling shell's own argv and can never return empty while the watcher
      lives. Point at `bounded-build-waiter.md` and the guard's header rather than re-deriving
      this. Name the bracket-trick escape hatch for a genuine real-worker match
      (`pgrep -f '[b]in/lake build'`, `[c]heck-module-invariants`).
- [ ] Strengthen "The liveness caveat" with the sentence: a process count is never evidence of a
      build's OUTCOME, and a count that cannot go to zero is not evidence of anything at all. Add a
      pointer forward to the new verdict section.
- [ ] Keep to the file's single-statement-plus-pointer convention. Do not restate the
      bounded-waiter idiom or the completion-discipline rule.

**Timing**: 1 hour

**Depends on**: none

**Verification Tier**: prose

**Files to modify**:
- `agent-system/extensions/lean/context/project/lean4/operations/long-builds.md` - new section, passive-checks lead-in and prohibition, sharper caveat

**Verification**:
- `grep -n "^## Reading the build's verdict" long-builds.md` returns exactly one hit.
- The section lists the three tiers in the order specified. The pipe prohibition appears once.
- Every `<PID>` in "Passive progress checks" is now preceded by a named source.
- Every positive `pgrep -f` example in the file uses a bracketed first character.

---

### Phase 2: Supersession clause and fix-site list in dispatch-report-not-termination.md [NOT STARTED]

**Goal**: Extend the teardown rule to cover the supersession case and register the lean agents
as fix sites, in `agent-system/extensions/core/context/patterns/dispatch-report-not-termination.md`.

**Tasks**:
- [ ] Add one sentence to "Tear Down Watchers/Monitors Before Reporting": a waiter must also be
      torn down before its watched build is cancelled or superseded (for example, a re-run or a
      replacement build), not only before reporting. That transition is what orphans waiter loops.
- [ ] Add two entries to "Where This Is Referenced": `lean-implementation-agent.md`'s Final
      Verification Stage build step, and `lean-implementation-hard-agent.md`'s Stage 4 step D and
      Stage 6 step 4. Cite them by section name, not line number.

**Timing**: 0.25 hours

**Depends on**: none

**Verification Tier**: prose

**Files to modify**:
- `agent-system/extensions/core/context/patterns/dispatch-report-not-termination.md` - one sentence and two list entries

**Verification**:
- The teardown section names supersession or cancellation explicitly.
- "Where This Is Referenced" has 5 entries.
- No text from `bounded-build-waiter.md` is copied into this file.

---

### Phase 3: Un-piped capture form in lean4.md Build Commands [NOT STARTED]

**Goal**: Give the canonical invocation shape exit-code discipline, by pointer, in
`agent-system/extensions/lean/rules/lean4.md`.

**Tasks**:
- [ ] Under the canonical invocation block in "Build Commands", add the un-piped capture form
      (`bash .claude/scripts/lake-build-guard.sh build --timeout 1800 -- <lake args> > <log> 2>&1; GUARD_EXIT=$?`)
      or the equivalent `result` read.
- [ ] Add one pointer line to `long-builds.md`'s "Reading the build's verdict". Do not restate the
      hierarchy or the prohibition rationale.

**Timing**: 0.25 hours

**Depends on**: 1

**Verification Tier**: prose

**Files to modify**:
- `agent-system/extensions/lean/rules/lean4.md` - capture form plus pointer

**Verification**:
- "Build Commands" contains `GUARD_EXIT=$?` (or a `result` read) and the anchor pointer.
- No tier list appears in this file.

---

### Phase 4: Plain lean agent: verdict method, waiter/teardown pointer, --no-revert bullet [NOT STARTED]

**Goal**: Close the three open points in `agent-system/extensions/lean/agents/lean-implementation-agent.md`.

**Tasks**:
- [ ] In the Final Verification Stage, step 4 ("Verify build passes"), replace
      `Record: build_passed (true/false), build_output (if failed)` with a determination line.
      It sets `build_passed` from the terminal full-project bar (Tier 1 plus Tier 2 plus Tier 3
      for touched modules) in `long-builds.md` "Reading the build's verdict". It notes that the
      background harness's exit code is the guard's own only because the command is unpiped. It
      keeps `build_output` (if failed) sourced from the guard's captured stderr/stdout.
- [ ] At that same build step, add a one-line pointer: any waiter armed on the build follows
      `bounded-build-waiter.md`, and must be torn down before reporting or before its build is
      superseded, per `dispatch-report-not-termination.md` "Tear Down Watchers/Monitors Before
      Reporting". Do not restate either rule.
- [ ] Next to the `orchestrator_mode` handoff section, add the `--no-revert` bullet. Under
      `orchestrator_mode: true`, `git-snapshot.sh` MUST be invoked with `--no-revert`, and
      `--no-revert` SHOULD be preferred whenever the agent intends to keep working after the
      snapshot. The one-line rationale: the default and `--branch` modes revert the working tree
      repo-globally (an unscoped `git stash push -u`), which captures a concurrent sibling
      dispatch's in-flight edits. Match the parenthetical style of `general-implementation-agent.md`'s
      Stage 4C `--no-revert` sentence and the hazard wording in `git-snapshot.sh`'s header.
- [ ] Leave the JSON `"build_passed"` examples in the return-metadata section unchanged. They are
      output fields, not determination sites.

**Timing**: 0.5 hours

**Depends on**: 1, 2

**Verification Tier**: prose

**Scope Hypothesis**: this file has exactly one determination site (Final Verification step 4).
The other `build_passed` hits (JSON examples) are output-shape only. Confirm with
`grep -n build_passed` before editing, and treat any extra determination site as in scope.

**Files to modify**:
- `agent-system/extensions/lean/agents/lean-implementation-agent.md` - verdict line, waiter/teardown pointer, --no-revert bullet

**Verification**:
- No `build_passed (true/false)` text remains without a method.
- `grep -c -- '--no-revert'` is at least 1, and the bullet names `orchestrator_mode`.
- Both `bounded-build-waiter` and `dispatch-report-not-termination` are cited at the build step.

---

### Phase 5: Hard lean agent: two verdict sites, waiter/teardown pointer, --no-revert bullet [NOT STARTED]

**Goal**: Close the same gaps at both determination sites in
`agent-system/extensions/lean/agents/lean-implementation-hard-agent.md`.

**Tasks**:
- [ ] Stage 4, step D ("Verify Phase Completion"): after "wait for the harness's completion
      notification before recording the result", add a determination line. The phase passes on the
      scoped phase-end bar (Tier 1 plus Tier 3 for the phase's module or modules), per
      `long-builds.md` "Reading the build's verdict". The harness exit code is the guard's own only
      because the command is unpiped.
- [ ] Stage 6, step 4 ("Verify build passes"): replace `Record: build_passed (true/false)` with
      the same determination line as Phase 4, using the terminal full-project bar.
- [ ] At step D and at Stage 6 step 4 (or once, in a shared spot that both clearly cover), add the
      same one-line waiter/teardown pointer as Phase 4.
- [ ] Add the same `--no-revert` bullet as Phase 4, word for word, next to this file's
      `orchestrator_mode` handoff section. Identical wording keeps the two agents consistent.
- [ ] Leave the Stage 7 metadata line that lists `build_passed` as a field unchanged.

**Timing**: 0.75 hours

**Depends on**: 1, 2

**Verification Tier**: prose

**Scope Hypothesis**: exactly two determination sites exist (Stage 4 step D and Stage 6 step 4).
The line-608 metadata mention is output-shape only. Confirm with `grep -n "build_passed\|Verify Phase Completion"`
before editing.

**Files to modify**:
- `agent-system/extensions/lean/agents/lean-implementation-hard-agent.md` - two verdict lines, waiter/teardown pointer, --no-revert bullet

**Verification**:
- Both sites cite `long-builds.md` "Reading the build's verdict" and state their bar.
- The `--no-revert` bullet text is identical to Phase 4's (check with a diff of the two extracted bullets).

---

### Phase 6: Cross-file acceptance checks, redeploy, and deploy-tree diff [NOT STARTED]

**Goal**: Mechanically confirm all four acceptance statements, then propagate the changes to
`.claude/` and prove the deployed copies match.

**Tasks**:
- [ ] Duplication check: grep all five files for tier-list phrases ("Build completed successfully",
      "newer than", "pipe's exit code"). They may appear only in `long-builds.md`. Pointers may name
      the heading only.
- [ ] `pgrep` audit: `grep -rn pgrep agent-system/extensions/lean/`. Every hit must be either a
      prohibition or a bracket-trick pattern. None may name the guard, the watcher, or a wrapper
      without brackets.
- [ ] Verdict-site audit: every `build_passed` determination site, and step D, names a method.
- [ ] Anchor integrity: every pointer's heading text exists verbatim in its target file.
- [ ] Deliverable rule: run `bash agent-system/extensions/core/scripts/check-task-references.sh`
      (or the equivalent) over the five touched files. It must report zero task-number references.
- [ ] Regression check: run `bash agent-system/extensions/core/scripts/tests/test-lake-build-guard.sh`
      and confirm case 21 still passes (no guard file was touched).
- [ ] Redeploy: `bash agent-system/extensions/core/scripts/deploy-headless.sh` (default,
      non-destructive resync) targeting this repo. Then run `verify-deploy.sh` if applicable.
- [ ] Diff each of the five source files against its deployed `.claude/` counterpart.
- [ ] Record in the summary the note for the git-snapshot script-level remedy: its proposed
      "tracked paths outside the declared file_scope" refusal predicate does not cover a concurrent
      sibling editing inside an overlapping scope. A live-concurrent-dispatch predicate is a
      different condition. Also record the scope ceiling: the bullet addresses only working-tree
      revert, by convention.

**Timing**: 0.75 hours

**Depends on**: 3, 4, 5

**Verification Tier**: full

**Scope Hypothesis**: deploy copies these five files verbatim to `.claude/context/project/lean4/operations/long-builds.md`,
`.claude/rules/lean4.md`, `.claude/agents/lean-implementation{,-hard}-agent.md`, and
`.claude/context/patterns/dispatch-report-not-termination.md`. Confirm each target path exists
after the deploy. If any file is merged or templated rather than copied, diff the edited sections
instead of the whole file and note this in the summary.

**Files to modify**:
- none in the source store (verification and deploy only; `.claude/` is regenerated by the deploy script, never hand-edited)

**Verification**:
- Every grep audit above is clean.
- `diff` between each source file and its deployed copy is empty, or has only documented
  deploy-time transforms.
- The guard test suite passes.

## Testing & Validation

- [ ] `long-builds.md` has exactly one `## Reading the build's verdict` heading. The three tiers
      appear strongest last. The pipe prohibition appears once.
- [ ] "Passive progress checks" names the PID source before first use.
- [ ] No self-matching `pgrep -f` recommendation remains anywhere under `agent-system/extensions/lean/`.
- [ ] All three verdict sites name their method and bar, by pointer.
- [ ] Both lean agents carry identical `--no-revert` bullets, with the rationale and the
      `orchestrator_mode` trigger.
- [ ] The teardown rule names supersession. "Where This Is Referenced" lists both lean agents.
- [ ] Zero task-number references in the touched deliverables.
- [ ] The deployed `.claude/` copies match the source store.

## Artifacts & Outputs

- Modified: the five `file_scope` files in `agent-system/extensions/{lean,core}/`
- Regenerated: the corresponding `.claude/` deploy copies (by the deploy script)
- `specs/221_lean_build_verdict_evidence_contracts/summaries/01_build-verdict-evidence-contracts-summary.md`

## Rollback/Contingency

All edits are additive markdown in git-tracked source-store files. To revert, run
`git checkout -- <file>` on the affected files (or `git revert` the phase commits), then re-run
`deploy-headless.sh` so `.claude/` is regenerated from the reverted source. If the deploy fails,
the source edits stand on their own. Record the deploy failure as a blocker rather than
hand-editing `.claude/`.
