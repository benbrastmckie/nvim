# Implementation Plan: Task #389

- **Task**: 389 - Fix test-verify-deploy-context-budget.sh's fixture so the full verify-deploy gate set can pass
- **Status**: [NOT STARTED]
- **Effort**: 1.5 hours
- **Dependencies**: None for the edit itself. Verification of the *complete* gate set is gated on the sibling hanging-suite task (see Risks); the narrow verification this plan relies on is not.
- **Research Inputs**: specs/389_verify_deploy_context_budget_fixture_missing_git_add/reports/02_independent-corroboration.md
- **Artifacts**: plans/01_fixture-index-population-guard.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

The dispatch premise — that `test-verify-deploy-context-budget.sh` builds its fixture with
`git init` but never stages the copied tree — is **no longer true in the tree**. The staging
fix already exists at `agent-system/extensions/core/scripts/tests/test-verify-deploy-context-budget.sh:122-127`
(`git -C "$FIXTURE" add -A` followed by `git -C "$FIXTURE" commit -q -m fixture`, under a comment
block that names Gate 22, `git ls-files`, and the zero-`*.sh` exit-2 symptom verbatim). It landed
in commit `5e23c280c` ("orchestrate conclusion: channel (a) direct fixes", 2026-10-12), before
this task was dispatched, and the deployed copy at `.claude/scripts/tests/test-verify-deploy-context-budget.sh`
is byte-identical to the source-store copy.

This plan therefore does not re-apply a fix that is already present. It converts the fix from a
*comment-protected* invariant into a *mechanically asserted* one — exactly what the research
report's recommendation 4 asks for ("assert the index is populated, not merely that the gate
passes") — and then discharges verification and records the reconciliation so that later tasks
stop attributing this failure in Reasoned Exclusions records. Definition of done: the fixture
proves its own `*.sh` discovery count is nonzero and says so in its output; a regression that
drops the staging step fails loudly at fixture-setup time within seconds instead of opaquely via
Gate 8 roughly a hundred seconds later; and the reconciliation is on the record.

### Research Integration

The report is explicit that this task's own research round died (`reports/01_recovered-agent-message.md`
is a one-sentence recovered fragment, not a report) and that the surviving artifact is an
observational seed. Its usable content is carried forward as follows:

- **Finding 2 ("independently re-confirmed live")** is the one claim this plan contradicts, on
  direct evidence rather than inference: the staging lines are present and committed, nothing
  under `agent-system/extensions/` with a `.sh` suffix is matched by the fixture's `.gitignore`
  (checked via `git check-ignore --stdin` over all 374 on-disk candidates — zero hits), and
  `lint-shellcheck.sh` exits 0 with 0 findings over 375 tracked files, so the fixture's Gate 22
  has both a populated index to enumerate and a clean tree to lint. The sibling's "still open"
  report is most plausibly an observation of the *symptom class* (a Gate 8 failure in the full
  set) rather than of this specific cause, which is precisely the masking hazard the dispatch
  description warns about.
- **Recommendation 3 (verify narrowly, not with the full battery)** is adopted for the in-phase
  check in Phase 1 and respected in Phase 2's contingency.
- **Recommendation 4 (assert the index is populated)** is the substance of Phase 1.
- **Recommendation 5 (declare a `file_scope`)** is satisfied without a dedicated phase: Phase 1's
  `**Files to modify**` list is harvested by `scripts/plan-file-scope-harvest.sh` and forwarded to
  `update-task-status.sh --file-scope-add=` by this dispatch's own postflight.
- **Risk "fixing the fixture reveals further gate-22 failures"** is retired as a live risk by the
  clean `lint-shellcheck.sh` run above, and restated in Risks at its reduced likelihood.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No `roadmap_path` was provided in this dispatch, so no ROADMAP.md consultation was performed and
this plan asserts no roadmap alignment.

## Goals & Non-Goals

**Goals**:
- The fixture asserts, immediately after its own `git commit`, that
  `git ls-files -z -- 'agent-system/extensions/*.sh'` (the exact pathspec `lint-shellcheck.sh:142`
  uses) returns a nonzero count, and refuses with a named reason and exit 2 if it does not.
- A passing run records that count in its output, so the evidence is positive rather than
  inferred from the absence of a failure.
- The comment block at lines 122-127 states what is now enforced, not merely what a reader must
  take on trust.
- The reconciliation is recorded: the described missing-`git add` cause is absent from the tree as
  of commit `5e23c280c`, so this failure is no longer a legitimate pre-existing attribution for
  any later task.

**Non-Goals**:
- Re-applying the `git add`/`commit` pair. It is already there; adding it again would be
  fabrication.
- Auditing or guarding the other nineteen `git init` fixture suites under
  `agent-system/extensions/core/scripts/tests/`. Several build deliberately un-tracked fixtures
  and none of them is named by this dispatch; a cross-suite sweep is its own task.
- Changing `deploy-baseline-lib.sh`, `verify-deploy.sh`, or `lint-shellcheck.sh`. Gate 22's own
  exit-2-on-empty-file-set behaviour is correct and is the mechanism this guard reports earlier,
  not a defect to soften.
- Fixing or working around the sibling suite that does not terminate under Gate 8. That is a
  separate task in the same cycle and its file territory is not touched here.
- Replacing the fixture's `git add -A` with a scoped pathspec. It operates on a `mktemp -d`
  scratch repository, not this working tree, and `lint-scoped-commit-boundary.sh` reports 0
  violations over 1317 files today.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| The complete gate set still cannot terminate, because Gate 8 reaches the sibling task's non-terminating suite | M | H | Discharge Phase 1 narrowly via `run-all.sh --only`; in Phase 2 run the complete set under a bounded foreground timeout and, if it does not return, close the phase `[COMPLETED WITH EXCLUSIONS]` with a `#### Reasoned Exclusions` record naming that suite and citing the narrow pass as the substitute evidence. Do not re-attribute this task's own named cause. |
| A reader of the dispatch description concludes the plan ignored its instruction, since no `git add` is added | M | M | The Overview states the contradiction, names the commit and the line numbers, and the Phase 2 record makes the reconciliation durable rather than leaving it in a dispatch message. |
| The fixture's Gate 22 fails for a *different* reason once it genuinely enumerates files (the masked-failure risk the research names) | M | L | Already measured away: `lint-shellcheck.sh` exits 0 with 0 findings over 375 files on the real tree, and the fixture is an `rsync -a` copy of that same content. If it nonetheless fails, the new assertion distinguishes "found zero files" from "found findings" in one line of output. |
| A concurrent sibling edits the same suite file mid-phase | L | L | Territory shows no sibling declaring this path. Re-read the file immediately before editing, stage only this file by explicit path, and stop and report any foreign modification per the dispatch's concurrency note. |
| The guard's own count drifts (e.g. a future `rsync --exclude` widening) and makes the assertion brittle | L | L | Assert `-gt 0`, never an exact count. The exact figure appears only in the informational line. |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |

Phases within the same wave can execute in parallel.

### Phase 1: Assert fixture index population at setup time [NOT STARTED]

**Goal**: The fixture proves, and reports, that its staged index actually contains the `*.sh`
files Gate 22 will enumerate — turning a comment-protected invariant into an enforced one that
fails in seconds with a named reason.

**Tasks**:
- [ ] Re-read `agent-system/extensions/core/scripts/tests/test-verify-deploy-context-budget.sh`
      immediately before editing (sibling concurrency; the dispatch's territory note).
- [ ] After the existing `git -C "$FIXTURE" commit -q -m fixture` (line 127), capture
      `fixture_sh_count="$(git -C "$FIXTURE" ls-files -z -- 'agent-system/extensions/*.sh' | tr -cd '\0' | wc -c)"`
      — the same pathspec `lint-shellcheck.sh:142` uses, counted NUL-safely so the guard cannot
      itself be fooled by a path containing a newline.
- [ ] If that count is not greater than zero, print a named reason to stderr
      (naming the empty-index cause, Gate 22, and `lint-shellcheck.sh`'s own
      "no *.sh files found to scan" message) and `exit 2`, matching the suite's documented exit-2
      "environment error" semantics rather than the per-case `fail()` tier — a fixture that
      cannot be built is a setup error, not a failing case.
- [ ] On success, emit the count through the existing `info()` helper so a passing run carries
      positive evidence (`info "fixture index populated: N tracked *.sh files under agent-system/extensions/"`).
- [ ] Rewrite the comment block at lines 122-127 so it states that the staging step is now
      assertion-backed, and keeps the Gate 22 / `git ls-files` / exit-2 causal explanation that
      makes the guard legible to the next reader.
- [ ] Confirm the guard actually bites: temporarily comment out the `git -C "$FIXTURE" add -A`
      line, run the suite, observe exit 2 with the named reason within seconds, then restore the
      line and re-run clean. Revert this probe before committing — it is evidence, not a change.
- [ ] Stage and commit this one file by explicit path (never a directory or glob pathspec).

**Timing**: 0.5 hours

**Depends on**: none

**Verification Tier**: local

**Tier Justification**: The edit is confined to one standalone test script that no other file
sources or imports, and `bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-verify-deploy-context-budget.sh`
executes that exact file end to end, so it covers the whole blast radius without paying for the
other nineteen suites.

**Scope Hypothesis**: This phase asserts that exactly one file is touched and that the fixture
currently stages a nonzero `*.sh` count — expected 374, derived from
`find agent-system/extensions -name '*.sh' -type f -not -path '*literature-pyenv*' | wc -l`
on 2026-10-14 against 375 tracked files repo-wide (the one difference being a tracked script
inside the `literature-pyenv` tree that `rsync --exclude` drops). The implementer confirms the
count from the new `info` line in the suite's own output, not from this number.

**Files to modify**:
- `agent-system/extensions/core/scripts/tests/test-verify-deploy-context-budget.sh` - add the
  post-commit index-population assertion and informational count line; update the lines 122-127
  comment block to describe the enforced invariant.

**Verification**:
- `bash agent-system/extensions/core/scripts/lint/lint-shellcheck.sh --verbose agent-system/extensions/core/scripts/tests/test-verify-deploy-context-budget.sh`
  exits 0 (sanctioned lint entry point; exit status checked, not stdout diffed).
- `bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-verify-deploy-context-budget.sh`
  exits 0, and its output contains the new `[INFO] fixture index populated: N tracked *.sh files`
  line with N greater than zero.
- The negative probe above exits 2 with the named reason while the `git add` line is commented
  out, and exits 0 again once it is restored — proving the guard is not decorative.

---

### Phase 2: Discharge the full gate set and record the reconciliation [NOT STARTED]

**Goal**: Prove the change holds under the complete gate set from the deployed tree, and put the
premise reconciliation on the record so this failure stops being cited as pre-existing.

**Tasks**:
- [ ] Regenerate the deployed tree with the repo's sanctioned deploy entry point
      (`bash .claude/scripts/deploy-headless.sh`) so `.claude/scripts/tests/test-verify-deploy-context-budget.sh`
      carries the Phase 1 edit — Gate 8 runs the deployed copy, not the source-store one.
- [ ] Re-run `bash .claude/scripts/tests/run-all.sh --only test-verify-deploy-context-budget.sh`
      against the deployed copy and confirm the same clean result and the same `[INFO]` count line.
- [ ] Run the complete gate set: `bash .claude/scripts/verify-deploy.sh` (no `--skip-slow`, no
      `--only-gate`), in the foreground under a bounded timeout, capturing the finding count.
- [ ] Compare that finding count against the pre-change baseline the orchestrator records for
      this cycle, so a newly surfaced finding is distinguishable from a pre-existing one.
- [ ] Record the reconciliation in the task summary: the dispatch's named cause (missing
      `git add`) was already absent as of commit `5e23c280c`; what this task added is the
      assertion that keeps it absent; and therefore this specific Gate 8 failure is no longer an
      admissible pre-existing attribution for any later task.
- [ ] Record the premise-staleness finding through `issue-record.sh` (`--kind issue`,
      `--class` naming a stale dispatch premise, `--severity minor`) so the pattern is captured
      where the issue log can see it.
- [ ] If the complete set does not terminate within the bounded timeout because Gate 8 reaches
      the sibling task's non-terminating suite, close this phase `[COMPLETED WITH EXCLUSIONS]`
      with a `#### Reasoned Exclusions` record (`Item | Reason | Evidence`) naming that suite as
      the sole exclusion and citing the narrow `--only` pass plus `--skip-slow`'s clean result as
      the substitute evidence. Do not attribute the exclusion to this task's own named cause.

**Timing**: 1 hour

**Depends on**: 1

**Verification Tier**: full

**Files to modify**:
- None in the source store. `.claude/**` is regenerated by `deploy-headless.sh`, not hand-authored.

**Verification**:
- `bash .claude/scripts/verify-deploy.sh` exits 0 — the complete gate set, not `--skip-slow` and
  not a `--only-gate` subset — or, failing that, the phase carries a `#### Reasoned Exclusions`
  record naming the single non-terminating sibling suite with its evidence.
- `bash .claude/scripts/tests/run-all.sh --only test-verify-deploy-context-budget.sh` exits 0
  against the deployed copy.
- The task summary contains the reconciliation statement, and `issues.jsonl` contains the
  premise-staleness entry.

## Testing & Validation

- [ ] The suite's new assertion passes on an unmodified tree and reports a nonzero `*.sh` count.
- [ ] The suite's new assertion fails with exit 2 and a named reason when the staging step is
      removed (negative probe, reverted).
- [ ] `lint-shellcheck.sh` exits 0 over the edited file via its sanctioned entry point.
- [ ] `run-all.sh --only test-verify-deploy-context-budget.sh` exits 0 from both the source store
      and the deployed tree.
- [ ] The complete `verify-deploy.sh` gate set exits 0, or its single exclusion is recorded with
      evidence and is not this task's named cause.

## Artifacts & Outputs

- `agent-system/extensions/core/scripts/tests/test-verify-deploy-context-budget.sh` — fixture
  setup guarded by an index-population assertion with an informational count line.
- Regenerated `.claude/scripts/tests/test-verify-deploy-context-budget.sh` (deploy artifact, not
  hand-authored).
- `specs/389_verify_deploy_context_budget_fixture_missing_git_add/summaries/01_*-summary.md` —
  carrying the premise reconciliation.
- An `issues.jsonl` entry recording the stale-premise finding.

## Rollback/Contingency

The entire source-store change is additive and confined to one test script, so rollback is
`git revert` of the Phase 1 commit (or `git checkout <prior-sha> -- agent-system/extensions/core/scripts/tests/test-verify-deploy-context-budget.sh`
followed by a redeploy). Nothing outside that file changes, no library or gate behaviour is
modified, and the fixture writes only inside its own `mktemp -d` `WORKDIR`, so a failed attempt
leaves no residue in the working tree. If the negative probe in Phase 1 is interrupted while the
`git add` line is commented out, restore the file from HEAD before doing anything else — a
committed probe state would reintroduce exactly the defect this task exists to prevent.
