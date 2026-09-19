# Implementation Plan: Task #238

- **Task**: 238 - Carry an external-process wait-discipline pointer in every orchestrate dispatch file
- **Status**: [NOT STARTED]
- **Effort**: 1.25 hours
- **Dependencies**: 236 (authored `context/patterns/external-process-wait.md`; complete, committed)
- **Research Inputs**: specs/238_carry_wait_pointer_in_dispatch_files/reports/01_wait-discipline-dispatch-pointer.md
- **Artifacts**: plans/01_wait-pointer-dispatch-plan.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md, shell-strict-mode.md
- **Type**: meta
- **Lean Intent**: false

## Overview

`agent-system/extensions/core/scripts/orchestrate-build-dispatch.sh` is the single writer of every
`/orchestrate` dispatch file, for all three phases and both base and `--hard` modes. The plan adds
one **unconditional** `## Wait Discipline` section (a pointer to
`context/patterns/external-process-wait.md` plus a one-line summary) to the script's single
`{ ... } > "$dispatch_file"` write block, immediately before the always-rendered
`## User-Decision Contract` section, and documents this self-owned behavior in a header comment.
A new test group in `scripts/tests/test-orchestrate-build-dispatch.sh` then asserts the pointer is
present across the base/`--hard` x research/plan/implement matrix.

### Research Integration

- Placement template is the unconditional `## User-Decision Contract` block (no surrounding `if`),
  not the conditionally-gated `## Territory` pointer. The Territory header note is the precedent
  for *documenting* a script-owned behavior in the header, not for gating.
- Do not route the pointer through `routing_lookup_flat "hard_contracts"` -- that mechanism is
  hard-mode-only and task-type-scoped, contradicting "base mode as well as `--hard`".
- Keep the summary free of numeric constants (no "540s", no "45 minutes") so it does not drift
  when the pattern file is tuned.
- Existing diff-based tests (Groups 9, 10, 12) compare two post-change dispatch files built by the
  same SUT, so an unconditional block appears on both sides and does not perturb their exact
  line counts. Confirm by running the full suite.
- The test suite already resolves the SUT source-store-first (Group 13's inversion), so tests
  exercise the edited `agent-system/extensions/core/` copy, not the stale `.claude/` deploy.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

Not consulted (no roadmap_path in dispatch).

## Goals & Non-Goals

**Goals**:
- Every dispatch file (research/plan/implement, base and `--hard`) carries a pointer to
  `context/patterns/external-process-wait.md` with a one-line summary.
- The script's header documents the block as a deliberate, permanent exception to the
  "byte-identical when a feature is inactive" invariant.
- Test coverage asserting presence across the phase x mode matrix; shellcheck clean.

**Non-Goals**:
- Inlining the six rules of `external-process-wait.md` into the dispatch file.
- Editing agent contract files (sibling territory: general-implementation-agent.md,
  general-research-agent.md) or the no-op-bash hook / settings-hooks.json / manifest.json
  (sibling territory).
- Editing anything under `.claude/**` (disposable deploy tree).
- Adding any task-number reference in the script or test (deliverable rule).

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Future contributor "fixes" the unconditional block into a gated one | M | L | Header comment explicitly names it a deliberate exception to the byte-identical invariant, alongside `## User-Decision Contract` |
| Existing exact-line-count diff tests break | M | L | Both sides of every diff are built by the post-change SUT; run the full suite to confirm |
| Wording drift vs. pattern file | L | M | Summary names behaviors only, no numeric constants |
| Concurrent sibling edits on the shared tree | M | L | Territories are disjoint; re-read each file before editing; stage only this task's two files by explicit path (never `git add -A` or a directory); never run `git-snapshot.sh` in reverting mode |
| Non-ASCII em dash in echo text | L | L | The script already uses em dashes in the User-Decision Contract echo lines; keep consistent, or use `--` -- either is acceptable |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |

Phases within the same wave can execute in parallel.

### Phase 1: Emit the unconditional wait-discipline pointer [NOT STARTED]

**Goal**: The dispatch builder writes a `## Wait Discipline` section into every dispatch file.

**Tasks**:
- [ ] Re-read `agent-system/extensions/core/scripts/orchestrate-build-dispatch.sh` immediately
  before editing (concurrency note).
- [ ] In the `{ ... } > "$dispatch_file"` block, immediately before `echo "## User-Decision Contract"`
  and outside every `if`, add:
  ```bash
    echo "## Wait Discipline"
    echo ""
    echo "Read context/patterns/external-process-wait.md before waiting on any long-running external"
    echo "or remote process (e.g. a CI run) — bounded polling only; never an unbounded watch, no-op"
    echo "filler calls, or a Monitor/background wait that wakes you on every unchanged poll."
    echo ""
  ```
  (One pointer sentence plus summary; line-wrapped to the file's ~100-column style. Exact wording
  may be tuned, but it MUST contain the literal path `context/patterns/external-process-wait.md`
  and MUST NOT restate the pattern's numbered rules or numeric constants.)
- [ ] Add a header comment paragraph (next to the `--territory` / Prior Decisions notes) stating:
  the script unconditionally appends a `## Wait Discipline` pointer to every dispatch file it
  writes, in every phase and mode, so a dispatched agent receives the external-process wait
  discipline independent of which agent contract or `hard_contracts` routing it loads; this block
  and `## User-Decision Contract` are the two deliberate exceptions to the byte-identical-when-
  inactive invariant and must not be gated. No task numbers in the comment.
- [ ] `shellcheck agent-system/extensions/core/scripts/orchestrate-build-dispatch.sh` -- no new
  findings.

**Timing**: 0.5 hours

**Depends on**: none

**Verification Tier**: local

**Files to modify**:
- `agent-system/extensions/core/scripts/orchestrate-build-dispatch.sh` - new unconditional section + header comment

**Verification**:
- shellcheck clean.
- `grep -n "external-process-wait.md" agent-system/extensions/core/scripts/orchestrate-build-dispatch.sh`
  shows the echo line and header reference; the echo lines sit outside any `if` block.

---

### Phase 2: Test coverage across the phase x mode matrix [NOT STARTED]

**Goal**: A new test group asserts the pointer is present in base-mode and hard-mode dispatch
output for research, plan and implement.

**Tasks**:
- [ ] Re-read `agent-system/extensions/core/scripts/tests/test-orchestrate-build-dispatch.sh`
  immediately before editing.
- [ ] Add `Group 14: wait-discipline pointer present in every dispatch` before the Summary block,
  using existing `run_sut` / `assert_contains` helpers, with six cases (distinct `--seq` values,
  e.g. 14a-14f):
  - base research (`research --clean`), base plan (`plan --clean`), base implement
    (`implement --clean`)
  - hard research (`research --clean --hard`), hard plan (`plan --clean --hard`), hard implement
    (`implement --clean --hard`)
  - each asserts `assert_contains "$content" "context/patterns/external-process-wait.md"` and
    `assert_contains "$content" "## Wait Discipline"`; each fails loudly if the SUT did not
    exit 0, following Group 13's pattern.
- [ ] One additional assertion that the pointer appears exactly once per file
  (`grep -c "context/patterns/external-process-wait.md"` equals 1) in at least the hard implement
  case, guarding against a future double-emit via `hard_contracts_block`.
- [ ] Optional: one ordering assertion that `## Wait Discipline` precedes
  `## User-Decision Contract` (line-number comparison via `grep -n`).
- [ ] Group header comment describes the behavior by durable anchor (script name, section name),
  with no task numbers.
- [ ] `shellcheck` the test file -- no new findings.
- [ ] Run the full suite:
  `bash agent-system/extensions/core/scripts/tests/test-orchestrate-build-dispatch.sh`
  -- all groups pass, including pre-existing Groups 9, 10, 12 exact-diff checks.

**Timing**: 0.75 hours

**Depends on**: 1

**Verification Tier**: local

**Scope Hypothesis**: If `--hard` with `plan` or `research` requires additional fixture state in
this suite (e.g. a hard-contract routing entry or a report artifact), the implementer should
confirm by checking how Group 13 Case B (`research --hard`) and Group 4 (`plan`) set up fixtures,
and reuse that setup; if a `plan --hard` case cannot be built cheaply, cover hard mode with
research + implement and note the gap.

**Files to modify**:
- `agent-system/extensions/core/scripts/tests/test-orchestrate-build-dispatch.sh` - new Group 14

**Verification**:
- Suite exits 0 with `Failed: 0`.
- Temporarily reverting Phase 1's echo lines (local, uncommitted experiment, then restore) makes
  Group 14 fail -- confirms the test actually detects absence.

## Testing & Validation

- [ ] `shellcheck` clean on both modified files.
- [ ] `test-orchestrate-build-dispatch.sh` passes in full.
- [ ] `bash agent-system/extensions/core/scripts/check-task-references.sh` (or the deployed
  equivalent) reports no new task-number references in the two modified files, if the lint is
  available.
- [ ] No files outside the two named paths are modified (`git diff --stat`).

## Artifacts & Outputs

- Modified `agent-system/extensions/core/scripts/orchestrate-build-dispatch.sh`
- Modified `agent-system/extensions/core/scripts/tests/test-orchestrate-build-dispatch.sh`
- Implementation summary under `specs/238_carry_wait_pointer_in_dispatch_files/summaries/`

## Rollback/Contingency

Both changes are additive and confined to two files. Revert with
`git revert <commit>` for the phase commit(s), or `git checkout HEAD~N -- <the two paths>`. Do
not use a reverting `git-snapshot.sh` (shared tree with concurrent siblings).
