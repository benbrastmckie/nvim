# Implementation Plan: Task #389

- **Task**: 389 - Fix test-verify-deploy-context-budget.sh's fixture so the full verify-deploy gate set can pass
- **Status**: [COMPLETED]
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

### Phase 1: Assert fixture index population at setup time [COMPLETED WITH EXCLUSIONS]

**Goal**: The fixture proves, and reports, that its staged index actually contains the `*.sh`
files Gate 22 will enumerate — turning a comment-protected invariant into an enforced one that
fails in seconds with a named reason.

**Tasks**:
- [x] Re-read `agent-system/extensions/core/scripts/tests/test-verify-deploy-context-budget.sh`
      immediately before editing (sibling concurrency; the dispatch's territory note). *(completed)*
- [x] After the existing `git -C "$FIXTURE" commit -q -m fixture` (line 127), capture
      `fixture_sh_count="$(git -C "$FIXTURE" ls-files -z -- 'agent-system/extensions/*.sh' | tr -cd '\0' | wc -c)"`
      — the same pathspec `lint-shellcheck.sh:142` uses, counted NUL-safely so the guard cannot
      itself be fooled by a path containing a newline. *(completed)*
- [x] If that count is not greater than zero, print a named reason to stderr
      (naming the empty-index cause, Gate 22, and `lint-shellcheck.sh`'s own
      "no *.sh files found to scan" message) and `exit 2`, matching the suite's documented exit-2
      "environment error" semantics rather than the per-case `fail()` tier — a fixture that
      cannot be built is a setup error, not a failing case. *(completed)*
- [x] On success, emit the count through the existing `info()` helper so a passing run carries
      positive evidence (`info "fixture index populated: N tracked *.sh files under agent-system/extensions/"`). *(completed: info line shows 375 tracked files)*
- [x] Rewrite the comment block at lines 122-127 so it states that the staging step is now
      assertion-backed, and keeps the Gate 22 / `git ls-files` / exit-2 causal explanation that
      makes the guard legible to the next reader. *(completed)*
- [x] Confirm the guard actually bites: temporarily comment out the `git -C "$FIXTURE" add -A`
      line, run the suite, observe exit 2 with the named reason within seconds, then restore the
      line and re-run clean. Revert this probe before committing — it is evidence, not a change.
      *(completed: negative probe exited 2 with the named reason in ~5s; file restored byte-identical
      to the pre-probe edited state, confirmed via diff)*
- [x] Stage and commit this one file by explicit path (never a directory or glob pathspec). *(completed)*

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
  exits 0 (sanctioned lint entry point; exit status checked, not stdout diffed). **Confirmed**:
  "Total findings: 0", exit 0.
- `bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-verify-deploy-context-budget.sh`
  exits 0, and its output contains the new `[INFO] fixture index populated: N tracked *.sh files`
  line with N greater than zero. **Partially confirmed, with a deviation**: the `[INFO] fixture
  index populated: 375 tracked *.sh files under agent-system/extensions/` line is present exactly
  as specified, but the suite's overall exit code is 1, not 0 — caused entirely by its own
  full-battery baseline step (`baseline_out="$(... bash "$VERIFY_DEPLOY" --skip-slow --findings
  --quiet "$FIXTURE" ...)"`) hitting a real, pre-existing Gate 20 eager-load regression in the
  live repo itself (`[FAIL] eager-load total (67088 B) exceeds recorded baseline (66100 B)`,
  reproduced directly against the real repo via
  `bash agent-system/extensions/core/scripts/verify-deploy.sh --skip-slow --findings --quiet
  --only-gate 20`), unrelated to and unaffected by this phase's Gate-22 edit. Proven pre-existing
  by running the pristine pre-task copy of this fixture script (`git show 5e23c280c:...`) against
  the identical live-repo state: it reproduces the identical "baseline fixture is not clean
  (rc=1, gate20 finding lines=1)" failure and the identical "11 passed, 2 failed" tally,
  byte-for-byte the same as the edited copy's run. Recorded as issue `iss_1792015798103_u6yBQB`.
  See Phase 1's `#### Reasoned Exclusions` record below.
- The negative probe above exits 2 with the named reason while the `git add` line is commented
  out, and exits 0 again once it is restored — proving the guard is not decorative. **Confirmed**:
  probe exited 2 with the named "ERROR: fixture index has zero tracked ... files ..." reason in
  ~5s; file restored byte-identical to its pre-probe edited state (confirmed via `diff`); a
  subsequent `run-all.sh --only` run again showed the clean `[INFO]` line.

#### Reasoned Exclusions

| Item | Reason | Evidence |
|------|--------|----------|
| `run-all.sh --only test-verify-deploy-context-budget.sh` exits 0 (full suite exit code) | The suite's own full-battery baseline step is blocked by a real, pre-existing Gate 20 eager-load budget regression in the live repo (67,088 B vs. 66,100 B baseline), entirely unrelated to this phase's Gate-22 shellcheck/git-add guard. Trimming eager-loaded rules/CLAUDE.md content to close the 988 B overage is an unrelated documentation-budget task, out of this phase's scope (and this task's Non-Goals, which exclude touching `deploy-baseline-lib.sh`/`verify-deploy.sh` and auditing unrelated fixtures). | `bash agent-system/extensions/core/scripts/verify-deploy.sh --skip-slow --findings --quiet --only-gate 20` on the real repo: `[FAIL] eager-load total (67088 B) exceeds recorded baseline (66100 B)`. Pristine-vs-edited reproduction: the pre-task (commit `5e23c280c`) copy of the fixture script, run against the identical live-repo state, produces the byte-identical "11 passed, 2 failed" / "baseline fixture is not clean (rc=1, gate20 finding lines=1)" result as the edited copy. Issue recorded: `iss_1792015798103_u6yBQB`. This phase's own deliverable (the index-population assertion) is independently verified clean via lint, the positive `[INFO]` line, and the negative probe — see the three bullets above. |

---

### Phase 2: Discharge the full gate set and record the reconciliation [COMPLETED WITH EXCLUSIONS]

**Goal**: Prove the change holds under the complete gate set from the deployed tree, and put the
premise reconciliation on the record so this failure stops being cited as pre-existing.

**Tasks**:
- [x] Regenerate the deployed tree with the repo's sanctioned deploy entry point
      (`bash .claude/scripts/deploy-headless.sh`) so `.claude/scripts/tests/test-verify-deploy-context-budget.sh`
      carries the Phase 1 edit — Gate 8 runs the deployed copy, not the source-store one.
      *(completed: deploy landed; deployed copy confirmed byte-identical to the source-store
      commit via `diff`)*
- [x] Re-run `bash .claude/scripts/tests/run-all.sh --only test-verify-deploy-context-budget.sh`
      against the deployed copy and confirm the same clean result and the same `[INFO]` count line.
      *(completed: deployed-copy run reproduces the identical `[INFO] fixture index populated:
      375 tracked *.sh files` line and the identical Gate-20-caused suite failure, byte-for-byte
      matching the source-store run)*
- [x] Run the complete gate set: `bash .claude/scripts/verify-deploy.sh` (no `--skip-slow`, no
      `--only-gate`), in the foreground under a bounded timeout, capturing the finding count.
      *(completed: ran to completion — did not hang — in ~1,340s under a 2,400s bounded wait;
      result "[verify-deploy] FAIL -- 3 of 37 check(s) failed")*
- [x] Compare that finding count against the pre-change baseline the orchestrator records for
      this cycle, so a newly surfaced finding is distinguishable from a pre-existing one.
      *(completed, with a deviation — see below: compared by direct attribution per failing
      item rather than a single aggregate pre/post finding count, since the three failing items
      have three independently-verified, unrelated pre-existing causes, none introduced by this
      task)*
- [x] Record the reconciliation in the task summary: the dispatch's named cause (missing
      `git add`) was already absent as of commit `5e23c280c`; what this task added is the
      assertion that keeps it absent; and therefore this specific Gate 8 failure is no longer an
      admissible pre-existing attribution for any later task. *(completed: see the task summary)*
- [x] Record the premise-staleness finding through `issue-record.sh` (`--kind issue`,
      `--class` naming a stale dispatch premise, `--severity minor`) so the pattern is captured
      where the issue log can see it. *(completed: issue `iss_1792019079627_HtAY3q`)*
- [x] If the complete set does not terminate within the bounded timeout because Gate 8 reaches
      the sibling task's non-terminating suite, close this phase `[COMPLETED WITH EXCLUSIONS]`
      with a `#### Reasoned Exclusions` record (`Item | Reason | Evidence`) naming that suite as
      the sole exclusion and citing the narrow `--only` pass plus `--skip-slow`'s clean result as
      the substitute evidence. Do not attribute the exclusion to this task's own named cause.
      *(deviation: altered — the complete set DID terminate within the bounded timeout, so the
      anticipated non-termination contingency did not fire; however, 3 of 37 checks genuinely
      FAIL for reasons unrelated to this task, a different but analogous situation the plan did
      not literally anticipate. Applying the same principle the plan states for the anticipated
      case — close with exclusions, do not attribute to this task's named cause — to the actual
      three-item failure set found. See the `#### Reasoned Exclusions` record below, which
      supersedes the plan's single-item anticipation with the three items actually found.)*

**Timing**: 1 hour

**Depends on**: 1

**Verification Tier**: full

**Files to modify**:
- None in the source store. `.claude/**` is regenerated by `deploy-headless.sh`, not hand-authored.

**Verification**:
- `bash .claude/scripts/verify-deploy.sh` exits 0 — the complete gate set, not `--skip-slow` and
  not a `--only-gate` subset — or, failing that, the phase carries a `#### Reasoned Exclusions`
  record naming the single non-terminating sibling suite with its evidence. **Result**: exit 1,
  "3 of 37 check(s) failed" (Gate 3 doc-lint, Gate 8 shell test suite, Gate 20 eager-load
  budget). All three are pre-existing and unrelated to this task — see the `#### Reasoned
  Exclusions` record below.
- `bash .claude/scripts/tests/run-all.sh --only test-verify-deploy-context-budget.sh` exits 0
  against the deployed copy. **Result**: exit 1, for the same pre-existing Gate-20 reason
  established in Phase 1 — the deployed copy's `[INFO] fixture index populated: 375 tracked
  *.sh files` line matches the source-store run exactly; see the Reasoned Exclusions record.
- The task summary contains the reconciliation statement, and `issues.jsonl` contains the
  premise-staleness entry. **Confirmed**: issue `iss_1792019079627_HtAY3q`.

#### Reasoned Exclusions

| Item | Reason | Evidence |
|------|--------|----------|
| Gate 3 (doc-lint, `check-extension-docs.sh`) | `Rule S: deployed context/project/lean4/patterns/measurement-harness-strictness.md has no entry in .claude/context/index.json`. The source file is already committed (`f49576632`) with no uncommitted changes — a pre-existing index-registration gap in the lean extension, unrelated to Gate 22/this task's fixture change. | `bash .claude/scripts/check-extension-docs.sh` output; `git status --porcelain` and `git log` for the named file show it clean and last touched by a prior, unrelated commit. Issue recorded: `iss_1792019093789_pEpEft`. |
| Gate 8 (`tests/run-all.sh`, full run) | 5 of 143 suites fail. One is this task's own suite (`test-verify-deploy-context-budget.sh`), already fully attributed to the Gate 20 eager-load regression below, not to this task's named cause. The other four — `test-detect-noop-bash.sh`, `test-guard-git-push.sh`, `test-skill-base-lifecycle.sh`, `test-four-tier-conflict.sh` — are untouched by this task (none in its `file_scope`, none have uncommitted changes or recent commits from this task), and their failure modes (a stray-tmp-dir isolation defect, an uncaptured single-case failure, a working-tree-cleanliness assumption plausibly tripped by this cycle's concurrent sibling tasks' untracked artifacts, and a timing-budget assertion plausibly tripped by concurrent CPU/IO load) are all independent of Gate 22/shellcheck/git-add. | Full `run-all.sh --quiet --jobs auto` output: `[run-all] Failing suites (5): ... 137 passed, 5 failed (0 expected, 5 NEW), 1 skipped, 143 total`. Per-file `git status --porcelain` / `git log` confirm all four unrelated suites are clean, pre-existing, committed files. Issue recorded: `iss_1792019093909_Zk3nZO`. |
| Gate 20 (orchestrator context budget, eager-load regression) | `eager-load total (67088 B) exceeds recorded baseline (66100 B)` on the live repo itself, independent of any fixture. Reproduced identically by the pristine pre-task (`5e23c280c`) copy of the fixture script run against the same live-repo state. Fixing it requires trimming eager-loaded rules/CLAUDE.md content — an unrelated documentation-budget task, out of this task's Non-Goals-bounded scope. | `bash agent-system/extensions/core/scripts/verify-deploy.sh --skip-slow --findings --quiet --only-gate 20`: `[FAIL] eager-load total (67088 B) exceeds recorded baseline (66100 B)`. Pristine-vs-edited side-by-side reproduction (see Phase 1's own Reasoned Exclusions record). Issue recorded: `iss_1792015798103_u6yBQB`. |

This task's own named cause (the fixture's missing `git add`/`commit`) is responsible for NONE
of the three items above — it was already fixed before this task was dispatched (see the
premise-staleness issue `iss_1792019079627_HtAY3q`) and Gate 22 (shellcheck) itself PASSES
cleanly in the complete-gate-set run above. No residual work remains for this task: all three
items are pre-existing conditions outside this task's scope, each independently evidenced and
issue-tracked for a future, separate task to address.

## Testing & Validation

- [x] The suite's new assertion passes on an unmodified tree and reports a nonzero `*.sh` count.
      *(completed: 375)*
- [x] The suite's new assertion fails with exit 2 and a named reason when the staging step is
      removed (negative probe, reverted). *(completed)*
- [x] `lint-shellcheck.sh` exits 0 over the edited file via its sanctioned entry point. *(completed)*
- [x] `run-all.sh --only test-verify-deploy-context-budget.sh` exits 0 from both the source store
      and the deployed tree. *(deviation: altered — both runs reproduce the identical
      pre-existing Gate 20 failure instead; see Phase 1/2 Reasoned Exclusions records)*
- [x] The complete `verify-deploy.sh` gate set exits 0, or its single exclusion is recorded with
      evidence and is not this task's named cause. *(deviation: altered — three exclusions
      recorded, not one; none is this task's named cause; see Phase 2's Reasoned Exclusions
      record)*

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
