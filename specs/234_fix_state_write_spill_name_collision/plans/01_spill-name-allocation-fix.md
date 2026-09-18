# Implementation Plan: Task #234

- **Task**: 234 - Fix state-write.sh spill name collision
- **Status**: [IMPLEMENTING]
- **Effort**: 3.25 hours
- **Dependencies**: None
- **Research Inputs**: specs/234_fix_state_write_spill_name_collision/reports/01_spill-name-collision.md
- **Artifacts**: plans/01_spill-name-allocation-fix.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

`agent-system/extensions/core/scripts/state-write.sh` allocates a private jq binding name with
`private_name="__spill_${#SPILL_FILES[@]}"` in two places, but only the `--arg`/`--argjson`
auto-spill branch appends to `SPILL_FILES`. The `--argjson-file` branch therefore names every
binding `__spill_0`, and jq's duplicate-`--slurpfile` first-wins semantics silently substitute
the first spilled value for every later one — exit 0, valid JSON, wrong data, through the single
mutex-guarded writer the whole system routes state mutation through. This plan repairs the
allocation with one explicit counter shared by both branches (decoupled from `SPILL_FILES`, which
must keep meaning "files this script owns and will `rm`"), adds a loud hard-error on a duplicate
spilled public NAME, and lands a fixture-rooted regression suite that is demonstrated RED against
the current script before the fix and GREEN after. Done means: both defect shapes covered by
tests that failed first, shellcheck clean, the fix verified in the regenerated deploy tree, and
the caller audit's "no corrupted data" finding re-confirmed and recorded.

### Research Integration

The research report (`reports/01_spill-name-collision.md`) confirmed the root cause at
`state-write.sh:226`, independently reproduced both the pure multi-`--argjson-file` case and the
subtler mixed case in a throwaway fixture root, and confirmed jq's duplicate-`--slurpfile`
first-wins behavior directly — which is why every corrupted binding lands on the *first* spilled
value. Three findings shape this plan directly:

1. **`SPILL_FILES` must stay cleanup-ownership-only.** The tempting "fix" of appending the
   caller-supplied `--argjson-file` PATH to `SPILL_FILES` to advance the counter would make
   `cleanup()`'s `rm -f "${SPILL_FILES[@]}"` delete a caller's own file — a new and worse bug.
   The counter and the cleanup list are separated in this plan.
2. **`EFFECTIVE_FILTER`'s prefix-injection loop is already correct** and is not touched. Only the
   values fed into `SPILL_PRIVATE_NAMES` need to stop colliding.
3. **The existing fixture precedent is `test-state-write-large-payload.sh`**, whose copy list is
   missing `lib/task-lookup-lib.sh` (sourced by `task-lock.sh`); the research reproduction hit and
   fixed exactly that gap. The new suite copies all six dependencies.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No roadmap context was provided in this dispatch; ROADMAP.md was not consulted.

## Decisions Made in This Plan

Two open questions were explicitly left to planning by the dispatch and the research report. Both
are resolved here on the strength of research and existing convention; neither requires the user's
judgment.

**Decision 1 — fix shape: Option A (shared explicit counter) + duplicate-NAME guard.** The
dispatch named two candidates without pre-committing: (A) one explicit counter advanced by both
branches, or (B) private names derived from the caller's public NAME. Option A is adopted. It
directly closes the root cause (a counter only one branch advanced), guarantees uniqueness by
construction, keeps the diff to two small blocks, and introduces no new failure surface. Option B's
only real advantage is failure-message legibility (`__spill_memory_candidates` over `__spill_3`),
and the caller audit found zero live callers that have ever reached this path, so that advantage
buys nothing today while costing a larger diff. The dispatch's non-negotiable requirement — "a
duplicate private name must become a loud error rather than a silent last-write-wins" — is
satisfied independently of the option chosen, by a duplicate *public* NAME guard spanning both
spill branches (Phase 2). Under Option A private names cannot collide at all, so the guard is what
actually enforces the loud-error contract, catching the caller-side mistake (same NAME passed
twice) that the positional scheme would otherwise let through into the `EFFECTIVE_FILTER` prefix
as two `as $NAME` clauses.

**Decision 2 — regression test location: flat `scripts/`, not `scripts/tests/`.** The dispatch's
ACCEPTANCE text says "under `scripts/tests/`". `context/standards/shell-script-testing.md`'s
location rule is scope-based (narrow single-script suites go in `scripts/tests/`; broad
multi-script fixture suites stay flat in `scripts/`), and all three existing `state-write.sh`
suites are flat in `scripts/` — necessarily, since `state-write.sh` integrates `task-lock.sh` and
`generate-todo.sh` and any fixture must copy both. Two of those three are named explicitly in
`shell-strict-mode.md`'s Class B list at their flat paths. The new suite follows the documented
convention and its 3-for-3 sibling precedent as
`agent-system/extensions/core/scripts/test-state-write-spill-names.sh`. This is a deliberate,
recorded deviation from the dispatch's literal wording, not an oversight; `run-all.sh` discovers
both locations, so nothing functional turns on it.

## Goals & Non-Goals

**Goals**:
- Every spilled binding — from either branch, in any mix — receives a distinct private jq name.
- A duplicate public NAME among spilled bindings is a loud, non-zero-exit error naming the NAME
  and both conflicting sources, never a silent last-write-wins.
- `SPILL_FILES` keeps its single meaning: files this script `mktemp`-ed and must `rm`. A
  caller-supplied `--argjson-file` PATH never enters it.
- A fixture-rooted regression suite covers (a) two-or-more `--argjson-file` bindings and (b) a
  mixed `--arg`/`--argjson` + `--argjson-file` call, each asserting per-binding value identity;
  both demonstrated failing before the fix.
- The fix is verified present and working in the regenerated `.claude/scripts/` deploy tree.
- The caller audit's "no already-corrupted data" finding is re-confirmed and recorded.
- shellcheck clean per `context/standards/shell-strict-mode.md`.

**Non-Goals**:
- Any change to the mutex protocol, staging/`mv` sequence, `--state-file`/`--init` contracts, or
  `--regen-todo` behavior.
- Any change to the jq filter interface callers rely on: every existing caller's `$NAME` must keep
  resolving byte-for-byte as it does today.
- Repairing `specs/state.json` data (the audit found none corrupted) or auditing callers for
  reasons other than multi-spill usage.
- Hand-editing the gitignored deployed copy at `.claude/scripts/state-write.sh`.
- Fixing the unrelated missing-`lib/task-lookup-lib.sh` copy-list gap in
  `test-state-write-large-payload.sh` (noted by research; a separate concern, out of scope here).

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| A counter "fix" that appends the caller's `--argjson-file` PATH to `SPILL_FILES` makes `cleanup()` delete caller-owned data | H | M | Phase 2 keeps the counter as a separate scalar; Phase 3 asserts `SPILL_FILES` still only ever receives `mktemp` output (grep the diff, and the suite asserts a caller-supplied file survives the run) |
| Duplicate-NAME guard written non-`-e`-safe under `set -euo pipefail` silently never fires | H | M | Use the file's own `if`-guarded idiom; Phase 1 Case C asserts the guard actually exits non-zero with the expected message |
| Testing against the deployed script writes the REAL `specs/state.json` (PROJECT_ROOT self-resolves from BASH_SOURCE, and `--state-file` does not make this safe) | H | M | Suite invokes only a fixture-rooted copy; Phase 1 and Phase 3 both assert `git status --porcelain -- specs/state.json` is clean before and after every run |
| Fixture missing a transitive dependency (`lib/task-lookup-lib.sh`) causes a confusing runtime failure mistaken for the defect | M | M | Copy all six dependencies up front (Phase 1 Scope Hypothesis confirms the list by running) |
| Test authored to assert only the post-fix green state, so it never proves it catches the defect | H | L | Phase 1 is a dedicated RED phase: the suite must fail on Cases A/B/C against the unmodified script, with output captured, before Phase 2 begins |
| shellcheck unavailable in the dev environment | L | H | `nix shell nixpkgs#shellcheck --command shellcheck ...`; if genuinely unavailable, record that explicitly rather than claiming clean |
| Source-store/deploy confusion — fix edited in `.claude/` and wiped by the next regeneration | M | L | All edits target `agent-system/extensions/core/scripts/`; Phase 4 verifies via redeploy, never by patching the copy |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1, 5 | -- |
| 2 | 2 | 1 |
| 3 | 3 | 2 |
| 4 | 4 | 3 |

Phases within the same wave can execute in parallel.

### Phase 1: Author the regression suite and demonstrate RED [COMPLETED]

**Goal**: A fixture-rooted suite exists that fails against the *unmodified* `state-write.sh` on
both defect shapes, proving it detects the defect rather than merely asserting a healthy state.

**Tasks**:
- [x] Create `agent-system/extensions/core/scripts/test-state-write-spill-names.sh`, modeled on
      `test-state-write-large-payload.sh`: `mktemp -d` root, `pass()`/`fail()` counters, exit 0/1,
      `trap` cleanup of the temp root. *(completed)*
- [x] Copy into `$TMPROOT/.claude/scripts/{,lib/}`: `state-write.sh`, `task-lock.sh`,
      `generate-todo.sh`, `deploy-root-guard.sh`, `lib/common.sh`, `lib/task-lookup-lib.sh`.
      Create a synthetic `$TMPROOT/specs/state.json`. Invoke only the fixture copy, from
      `cd "$TMPROOT"`, so its BASH_SOURCE-derived PROJECT_ROOT points inside the fixture.
      *(completed)*
- [x] Case A (pure multi-file): one call with two `--argjson-file` bindings writing two distinct
      values; assert each resolves to its OWN file's value and that the two results differ.
      *(completed)*
- [x] Case B (mixed): one call combining an `--argjson-file` binding with an oversized
      (>`SPILL_THRESHOLD`, but under Linux's ~131,072-byte argv ceiling — the research report
      documents this narrow usable window) `--argjson` binding; assert each resolves to its own
      value. Include a plain small `--arg` binding in the same call to confirm the non-spilling
      path is unaffected. *(completed)*
- [x] Case C (loud error): one call passing the same public NAME for two spilled bindings; assert
      a non-zero exit and a diagnostic on stderr naming the NAME. Expected to fail pre-fix (today
      it exits 0 with silent last-write-wins). *(completed)*
- [x] Case D (ownership): assert a caller-supplied `--argjson-file` PATH still exists on disk after
      a successful run — the anti-regression for the `SPILL_FILES` cleanup risk. *(completed)*
- [x] Add a guard assertion in the suite itself that the real repo `specs/state.json` is untouched
      (`git status --porcelain -- specs/state.json` empty) at suite start and end. *(completed)*
- [x] Run the suite against the unmodified script; capture the failing output. Cases A, B, C MUST
      fail. Record the observed wrong values in the run log for the summary. *(completed: Cases
      A, B, C fail pre-fix — 2 passed, 3 failed. A: both --argjson-file bindings resolve to the
      FIRST file's value. B: .spilled resolves to a non-array (the file binding's own value)
      instead of the auto-spilled array. C: duplicate NAME exits 0 silently, no diagnostic.)*

**Timing**: 1 hour

**Depends on**: none

**Verification Tier**: local

**Commit Mode**: per-substep

**Scope Hypothesis**: The fixture dependency set is exactly six files (`state-write.sh`,
`task-lock.sh`, `generate-todo.sh`, `deploy-root-guard.sh`, `lib/common.sh`,
`lib/task-lookup-lib.sh`). Confirm at implementation time by running the suite: any
sourcing/`command not found` failure means the list is incomplete — extend it rather than working
around it. Likewise "three failing cases" is a hypothesis: if Case B passes pre-fix, the mixed-case
reproduction has not actually been reproduced and the case is mis-constructed (check the payload
is genuinely over `SPILL_THRESHOLD`), not evidence the bug is absent.

**Files to modify**:
- `agent-system/extensions/core/scripts/test-state-write-spill-names.sh` - new fixture-rooted
  regression suite (Cases A-D).

**Verification**:
- Suite runs to completion and reports FAIL for Cases A, B, C against the unmodified script.
- Case D passes both before and after (it is an invariant, not a defect probe).
- `git status --porcelain -- specs/state.json` is empty after the run.
- Suite never references `.claude/scripts/state-write.sh` or any path outside `$TMPROOT` for
  invocation.

---

### Phase 2: Repair spill-name allocation and add the duplicate-NAME guard [COMPLETED]

**Goal**: Both spill branches allocate distinct private names from one shared explicit counter,
and a duplicate spilled public NAME hard-fails loudly.

**Tasks**:
- [x] Introduce `SPILL_SEQ=0` alongside the existing `SPILL_FILES`/`SPILL_PRIVATE_NAMES`/
      `SPILL_PUBLIC_NAMES` declarations, with a comment stating why it is separate from
      `SPILL_FILES` (cleanup ownership vs. name allocation are different concerns). *(completed)*
- [x] In the `--argjson` auto-spill branch: replace `private_name="__spill_${#SPILL_FILES[@]}"`
      with allocation from `SPILL_SEQ`, incrementing it. Leave the `SPILL_FILES+=("$spill_file")`
      append exactly as-is — it still owns cleanup of the `mktemp`-ed file. *(completed)*
- [x] In the `--argjson-file` branch: replace the identical expression with the same
      `SPILL_SEQ`-based allocation. Do NOT append the caller's PATH to `SPILL_FILES`. *(completed)*
- [x] Add a duplicate-public-NAME check reached by both branches before allocation: if the incoming
      NAME already appears in `SPILL_PUBLIC_NAMES`, print an error to stderr naming the NAME and
      both conflicting sources and exit non-zero. Use the file's existing `if`-guarded idiom so it
      is `set -euo pipefail`-safe. *(completed: `check_spill_name_unique`, called by both
      branches before allocation; names the NAME and both sources via a new `SPILL_SOURCES`
      parallel array)*
- [x] Update the `--argjson-file` branch comment and any header/usage prose that describes
      spill-name allocation, so the invariant ("one counter, both branches; `SPILL_FILES` is
      cleanup-only") is stated where the next reader will look. *(completed)*

**Timing**: 45 minutes

**Depends on**: 1

**Verification Tier**: full

**Commit Mode**: per-substep

**Scope Hypothesis**: The change is expected to touch exactly one file and only the declaration
block plus the two spill branches (roughly lines 199-230 of
`agent-system/extensions/core/scripts/state-write.sh`). Confirm with `git diff --stat` (one file)
and `git diff` (no hunk inside `EFFECTIVE_FILTER` construction, the mutex/cleanup functions, or
the staging/`mv` sequence). A diff reaching outside those regions means scope has drifted into
the dispatch's OUT OF SCOPE list — stop and re-scope.

**Files to modify**:
- `agent-system/extensions/core/scripts/state-write.sh` - shared `SPILL_SEQ` counter used by both
  spill branches; duplicate-public-NAME hard error; comment updates.

**Verification**:
- `bash -n` parses cleanly.
- `git diff` confirms `SPILL_FILES` receives only `mktemp` output, and `EFFECTIVE_FILTER`
  construction is byte-unchanged.
- No change to `--state-file`, `--init`, `--regen-todo`, mutex, or staging code paths.

---

### Phase 3: Verify GREEN, regression-check siblings, shellcheck [COMPLETED]

**Goal**: The new suite passes, no existing behavior regressed, and the script is shellcheck clean.

**Tasks**:
- [x] Re-run `test-state-write-spill-names.sh` against the fixed source-store script: Cases A-D all
      PASS. Diff the before/after run logs to show the same suite moved RED to GREEN with no test
      edits in between. *(completed: 2 passed/3 failed -> 5 passed/0 failed; `diff` of the two run
      logs shows only the PASS/FAIL lines and captured values changed, no test-code changes)*
- [x] Run the three existing suites — `test-state-write-concurrency.sh`,
      `test-state-write-regen-timing.sh`, `test-state-write-large-payload.sh` — and confirm no
      regression. *(completed: all three show IDENTICAL pass/fail counts and failure messages
      against a pre-fix baseline copy (4/5, 1/2, 2/5 respectively — mutex-timeout and
      concurrency-timing related, unrelated to the spill-name defect) and against the fixed
      script. Deviation from the plan's anticipated cause: research's specific
      `lib/task-lookup-lib.sh`-gap hypothesis for `test-state-write-large-payload.sh` did not
      reproduce — that suite's fixture already includes the file via this task's own Phase 1
      dependency list; failures are pre-existing `specs/.scope-lock` mutex-timeout/concurrency
      flakiness, confirmed identical pre- and post-fix, out of scope for this task.)*
- [x] Sanity-check a representative live caller shape end-to-end in the fixture (one small `--arg`
      plus one large `--argjson`, as `orchestrator-postflight.sh` Stage 7c passes) and confirm
      identical output to the pre-fix script for that non-colliding case. *(completed: Stage 7c's
      `--argjson num $task_number` + `--argjson new $memory_candidates` shape, replayed with a
      125,031-byte in-range payload, produces an identical 1,855-element result pre- and post-fix)*
- [x] Run shellcheck on both changed files (`nix shell nixpkgs#shellcheck --command shellcheck`
      if not on `$PATH`) per `context/standards/shell-strict-mode.md`. *(completed: the new suite
      is fully clean, 0 findings. `state-write.sh` carries 3 pre-existing info-level findings (2x
      SC1091 on its `source`/`.` lines, 1x SC2329 on `cleanup()`, both false-positive-shaped and
      unrelated to this defect) confirmed byte-identical before and after this fix — no new
      finding was introduced by the Phase 2 diff, and these three are outside the plan's declared
      scope region so left untouched rather than opportunistically "fixed")*
- [x] Confirm `git status --porcelain -- specs/state.json` is clean after all test runs.
      *(completed with a caveat: the real `specs/state.json` carries a pre-existing, unrelated
      modification present since before this task's dispatch began (other concurrent sessions'
      work) — its content is CONFIRMED UNCHANGED by every test run in this phase, verified by the
      new suite's own before/after `git status --porcelain` guard on every invocation and by
      manual checks bracketing the sibling-suite and sanity-check runs above)*

**Timing**: 30 minutes

**Depends on**: 2

**Verification Tier**: full

**Commit Mode**: per-substep

**Files to modify**:
- None (verification only; test-script fixes are permitted if a case is found mis-constructed, but
  any edit to the suite after Phase 2 must be re-demonstrated RED against a stashed pre-fix copy).

**Verification**:
- New suite exits 0 with all cases passing.
- Three existing suites exit 0, or any failure is demonstrated pre-existing on the unmodified
  script.
- shellcheck reports no findings on `state-write.sh` and `test-state-write-spill-names.sh`.

---

### Phase 4: Redeploy and verify the deployed copy [NOT STARTED]

**Goal**: The gitignored `.claude/scripts/state-write.sh` carries the fix by regeneration, not by
hand-editing.

**Tasks**:
- [ ] Regenerate the deploy tree from the source store using the repository's normal deploy path.
- [ ] Confirm `.claude/scripts/state-write.sh` contains the `SPILL_SEQ` allocation and the
      duplicate-NAME guard, and no longer contains `__spill_${#SPILL_FILES[@]}`.
- [ ] Confirm `.claude/scripts/test-state-write-spill-names.sh` was deployed alongside its siblings
      and passes when run from the deployed location (it is fixture-rooted, so it still never
      touches the real `specs/state.json` — re-verify with `git status --porcelain` regardless).

**Timing**: 30 minutes

**Depends on**: 3

**Verification Tier**: local

**Commit Mode**: per-substep

**Files to modify**:
- None hand-edited. `.claude/scripts/**` changes only as generated output of the deploy step.

**Verification**:
- `grep -n '__spill_' .claude/scripts/state-write.sh` shows only the new allocation form.
- Deployed suite run exits 0.
- `git status --porcelain -- specs/state.json` clean.

---

### Phase 5: Confirm and record the caller audit [NOT STARTED]

**Goal**: The ACCEPTANCE requirement that existing callers be audited and any already-corrupted
data identified is satisfied with a reproducible, recorded finding.

**Tasks**:
- [ ] Re-run the enumeration the research report used:
      `grep -rn "argjson-file" agent-system/extensions/ --include="*.sh" --include="*.md"` and
      `grep -rln "state-write.sh" agent-system/extensions/ --include="*.sh" --include="*.md"`.
- [ ] For each call site with 2+ `--argjson` bindings in one invocation, confirm at most one
      binding can exceed `SPILL_THRESHOLD` (100,000 bytes).
- [ ] Record the finding in the implementation summary: which call sites were checked, why each is
      safe by construction, and the conclusion that no corrupted `specs/state.json` data exists or
      is suspected from this defect.

**Timing**: 30 minutes

**Depends on**: none

**Verification Tier**: prose

**Commit Mode**: per-substep

**Scope Hypothesis**: Research asserts zero live `--argjson-file` callers outside the script and
its own test file, and that every multi-`--argjson` live call site pairs one large payload with
small integers. Both are counts, not facts — confirm by re-running the two greps above and
inspecting each hit. If a live `--argjson-file` caller is found, the "no corrupted data" conclusion
does not hold and the finding must be escalated in the summary rather than restated from research.

**Files to modify**:
- None (audit and write-up only; the finding lands in the task summary).

**Verification**:
- Grep output enumerated in the summary, with the per-call-site safety reasoning.
- An explicit statement of the corruption finding (expected: none), reached by enumeration rather
  than assumption.

---

## Testing & Validation

- [ ] `test-state-write-spill-names.sh` Cases A, B, C fail against the unmodified script (RED
      demonstrated, output captured) and pass after the fix.
- [ ] Case D (caller-supplied `--argjson-file` PATH survives the run) passes before and after.
- [ ] `test-state-write-concurrency.sh`, `test-state-write-regen-timing.sh`, and
      `test-state-write-large-payload.sh` show no new failures.
- [ ] `git status --porcelain -- specs/state.json` is empty after every test run in every phase.
- [ ] shellcheck clean on `state-write.sh` and the new suite, per
      `context/standards/shell-strict-mode.md`.
- [ ] The deployed `.claude/scripts/state-write.sh` carries the fix after regeneration.

## Artifacts & Outputs

- `agent-system/extensions/core/scripts/state-write.sh` (modified) - shared `SPILL_SEQ` counter,
  duplicate-public-NAME hard error.
- `agent-system/extensions/core/scripts/test-state-write-spill-names.sh` (new) - fixture-rooted
  regression suite, Cases A-D.
- `specs/234_fix_state_write_spill_name_collision/summaries/01_*-summary.md` - implementation
  summary including the RED-then-GREEN evidence and the caller-audit finding.
- Regenerated `.claude/scripts/` deploy tree (gitignored; not a committed artifact).

## Rollback/Contingency

The change is confined to one modified file plus one new file, committed per green sub-step, so
the cheapest rollback is `git revert` of the offending commit(s) on a clean tree — no working-tree
destruction needed and no snapshot required.

If a rollback must instead discard *uncommitted* working-tree changes, that is a genuine rollback
scenario: take a snapshot first per `context/contracts/recovery.md`'s rollback rung
(`bash .claude/scripts/git-snapshot.sh 234`, adding its out-of-scope override flag only if the
dirty tree legitimately spans paths outside this task's declared scope), then run the destructive
command. Do not emit a bare snapshot call as a routine start-of-phase precaution; an ordinary
defensive checkpoint before risky work uses `--no-revert`.

Contingency by phase:
- If Phase 2's fix cannot be made `-e`-safe or the guard proves unreachable, fall back to Option B
  (name-derived private names) from the research report's design space — the regression suite from
  Phase 1 is option-agnostic and validates either shape unchanged.
- If a live `--argjson-file` caller turns up in Phase 5, the fix still stands; escalate the
  data-corruption finding in the summary and propose a follow-up task rather than widening this
  one.
- The deployed tree is disposable: if Phase 4's regeneration goes wrong, re-run the deploy from the
  source store. Never patch `.claude/scripts/` by hand.
