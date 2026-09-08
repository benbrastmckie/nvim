# Implementation Plan: Task #176

- **Task**: 176 - Fix the documented `lake-build-guard.sh` full-build invocation across the lean extension
- **Status**: [COMPLETED]
- **Effort**: 1.75 hours
- **Dependencies**: None
- **Research Inputs**: None (no research phase; the dispatch description is a confirmed specification -- defect, root cause, site list, and acceptance bar were all supplied and independently re-verified during planning)
- **Artifacts**: plans/01_fix-full-build-guard-invocation.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md, source-store-deploy-boundary.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Four documented full-repository build invocations in the `lean` extension pass an EMPTY lake
argument vector to `lake-build-guard.sh build`, which `validate_build_subcommand()` rejects with
exit 77 before any build is dispatched. Every affected site is a phase-end / final-verification
instruction -- exactly the command an agent reaches for when a phase closes. The fix is a
mechanical correction of five prose strings across four source-store files to the working form
(`-- build`), followed by a runtime proof that the corrected form actually dispatches to `lake`
rather than merely parsing, an exhaustive source-store audit, and a propagation record for the
three consumer repos that carry the broken text.

The premise was re-verified during planning against the guard's own source and a live probe (see
Research Integration), so no phase rests on an unconfirmed assumption about the guard's behavior.

### Research Integration

No research report exists for this round. The planning pass re-established every load-bearing
fact directly:

1. **Root cause confirmed in source.** `validate_build_subcommand()` at
   `agent-system/extensions/core/scripts/lake-build-guard.sh:773-792` exits 77 when
   `${#vec[@]}` is 0, before `resolve_project_root()` and before any lock acquisition. The
   `2>&1` in the broken sites is shell redirection consumed by the caller's shell, never an
   argument, so the vector is genuinely empty.
2. **Defect and fix reproduced live** (fake-`lake` probe, `LAKE_BUILD_GUARD_LAKE_BIN` seam,
   scratch dir with a bare `lakefile.toml`):
   - `build --timeout 1800 --` -> `build mode requires a lake subcommand ... none was given`, exit 77.
   - `build --timeout 1800 --no-share -- build` -> `FAKE_LAKE_ARGV: build`, exit 0.
   This is the harness Phase 2 reuses; it is already proven to work.
3. **Site inventory re-derived, not assumed.** `grep -rn "lake-build-guard.sh build"
   agent-system/` returns 11 hits. Four carry an empty vector (the four named in the dispatch);
   the remaining seven are correct: `-- Module.Name` (lean4.md:48,
   lean-implementation-hard-agent.md:237, skill-lake-repair/SKILL.md:79), the `-- <lake args>`
   placeholder (lean4.md:71, long-builds.md:75), and two `-- env <comparator> ...` forms
   (comparator-integration.md:82, 89) -- `env` is on the guard's `LAKE_SUBCOMMANDS` allowlist
   (line 190), so both pass validation.
4. **A fifth broken string was found beyond the dispatch's list.** `rules/lean4.md:74` compresses
   the same defect into prose: ``Full project: `--` (no module)``. It teaches the identical
   broken form and must be corrected with the other four.
5. **No test or lint asserts the documented string.** `grep -rn "timeout 1800" agent-system/
   --include="*.sh"` returns nothing, so no test breaks and no test needs updating.
6. **The `lean` extension is NOT active in this repo.** `.claude-extensions.json` lists
   `core, email, literature, memory, nix, nvim`. This directly affects the dispatch's deploy
   acceptance clause -- see Phase 3 and the Decision note below.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No `roadmap_path` was provided in the dispatch context, and no `specs/ROADMAP.md` exists in this
repository. No roadmap phases are included.

## Goals & Non-Goals

**Goals**:
- Every `lake-build-guard.sh build` invocation in the source store names a lake subcommand after
  `--`, or is an explicitly labelled usage-error example.
- Each corrected site keeps its surrounding prose intent: it remains a FULL-repository build
  instruction, never silently demoted to a per-module one.
- The corrected full-build form is proven to actually dispatch to `lake` -- not merely to parse.
- The three consumer repos carrying the broken deployed text are identified and their
  propagation status is recorded.
- The guard's contradictory usage banner (`[--] [LAKE ARGS...]` documented as optional) is
  recorded as a named handoff for the guard-terminal-record task.

**Non-Goals**:
- Modifying `agent-system/extensions/core/scripts/lake-build-guard.sh` or
  `agent-system/extensions/core/scripts/tests/test-lake-build-guard.sh`. The banner/validator
  contradiction is another task's `file_scope`; editing the guard here would collide on the same
  file.
- Changing any of the seven already-correct invocation sites.
- Adding a new lint or regression-check script to guard the corrected strings. Worth doing, but
  it is scope creep against the dispatch's SCOPE section; record it as a follow-up instead.
- Fixing the unrelated unguarded bare `lake build` at
  `context/project/lean4/agents/lean-implementation-flow.md:123-126`. Different defect (missing
  guard + detachment, not a missing subcommand); surface it, do not fix it.
- Hand-editing anything under `.claude/**` (see `rules/source-store-deploy-boundary.md`).
- Loading the `lean` extension into this repository to satisfy the deploy clause.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| An edit silently demotes a full build to a per-module build (e.g. replacing `--` with `-- Module.Name`) | H | L | Phase 1 fixes the exact replacement string per site; Phase 2 re-reads each hunk in context and asserts the surrounding "final verification"/"full project" prose is unchanged |
| The grep-derived site list is incomplete (a variant spelling, a line-wrapped invocation) | M | M | Phase 2 runs an exhaustive audit over the whole source store with two independent patterns (`lake-build-guard.sh build` and `--timeout 1800`), not just a re-run of the Phase 1 list |
| "Verified to actually run" is satisfied only by a parse-level check | M | M | Phase 2's harness asserts the fake `lake` was reached and logged `FAKE_LAKE_ARGV: build`; a run that exits 77 or never reaches the stub fails the phase |
| Deploy clause cannot be satisfied in-repo (lean not active here) | M | H (confirmed) | Phase 3 records the constraint explicitly and reports consumer staleness read-only; a `user_decision` surfaces the cross-repo alternative rather than the implementer taking it unilaterally |
| A cross-repo deploy into a consumer drags in every unrelated pending source change and could swap agent contracts under a live session there | H | M | Not taken on the recommended path; offered as the explicit alternative in the `user_decision` |
| The banner discrepancy gets fixed here by reflex, colliding with the other task's `file_scope` | M | L | Explicit Non-Goal above; Phase 4 produces a written handoff instead of an edit, and Phase 2's audit asserts the guard file is untouched |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1, 4 | -- |
| 2 | 2 | 1 |
| 3 | 3 | 2 |

Phases within the same wave can execute in parallel.

---

### Phase 1: Correct the full-build caller sites [COMPLETED]

**Goal**: Every empty-vector `lake-build-guard.sh build` invocation in the source store names
`build` as its lake subcommand, with surrounding prose intent preserved.

**Tasks**:
- [x] Re-run `grep -rn "lake-build-guard.sh build" agent-system/` and confirm the empty-vector
      set before editing anything -- do not edit from this plan's list without re-deriving it
      *(completed: confirmed exactly 5 broken sites across 4 files, matching plan)*
- [x] `agents/lean-implementation-agent.md:253`: `... build --timeout 1800 -- 2>&1`
      -> `... build --timeout 1800 -- build 2>&1` *(completed)*
- [x] `agents/lean-implementation-hard-agent.md:392`: same shape, same replacement *(completed)*
- [x] `rules/lean4.md:51`: `` `... build --timeout 1800 --` `` -> `` `... build --timeout 1800 -- build` ``
      (keep the "Final verification only:" lead-in and the "(full project)" continuation on line 52)
      *(completed)*
- [x] `rules/lean4.md:74`: `` Full project: `--` (no module) `` -> `` Full project: `-- build` ``
      (this is the fifth site, found during planning and NOT in the dispatch's list of four)
      *(completed)*
- [x] `skills/skill-lake-repair/SKILL.md:81`: `... build --timeout 1800 2>&1`
      -> `... build --timeout 1800 -- build 2>&1` (this site has no `--` at all; add it) *(completed)*
- [x] Confirm no other line in the five touched regions was altered *(completed: git diff hunks
      show exactly the 5 targeted lines changed, nothing else in context)*

**Timing**: 0.5 hours

**Depends on**: none

**Verification Tier**: local

**Commit Mode**: per-substep

**Scope Hypothesis**: This plan asserts exactly 5 broken strings across 4 files (the dispatch's
4 plus `lean4.md:74`). Confirm at implementation time by re-running
`grep -rn "lake-build-guard.sh build" agent-system/` plus
`grep -rn 'Full project\|no module\|unscoped' agent-system/extensions/lean/` and reconciling every
hit against the correct/broken classification in this plan's Research Integration section. If the
count differs, correct every genuine hit and record the divergence rather than deferring to the
number 5.

**Files to modify**:
- `agent-system/extensions/lean/agents/lean-implementation-agent.md` - line 253, full-build verification step
- `agent-system/extensions/lean/agents/lean-implementation-hard-agent.md` - line 392, full-build verification step
- `agent-system/extensions/lean/rules/lean4.md` - lines 51 and 74, final-verification workflow step and the compressed build-command summary
- `agent-system/extensions/lean/skills/skill-lake-repair/SKILL.md` - line 81, the no-module branch of the repair loop's build

**Verification**:
- `grep -rn "lake-build-guard.sh build" agent-system/` shows no invocation whose lake-argument
  vector is empty
- `grep -rn 'lake-build-guard.sh build --timeout 1800 -- build' agent-system/extensions/lean/`
  returns 4 hits (the two agents, lean4.md:51, skill-lake-repair:81)
- `git diff --stat` touches exactly the 4 files above and no file under
  `agent-system/extensions/core/scripts/`
- Each changed hunk read in context still reads as a full-repository build instruction

---

### Phase 2: Prove the corrected form runs, and audit the whole source store [COMPLETED]

**Goal**: The corrected invocation is demonstrated to reach `lake` (not merely to parse), and no
broken variant remains anywhere in the source store.

**Tasks**:
- [x] Build the runtime harness in the scratchpad: a directory containing a bare `lakefile.toml`
      and an executable `fakelake` stub that echoes `FAKE_LAKE_ARGV: $*` and exits 0 *(completed)*
- [x] Negative control: run the OLD form
      (`LAKE_BUILD_GUARD_LAKE_BIN=$PWD/fakelake bash <guard> build --timeout 1800 --`) and assert
      exit 77 with the `requires a lake subcommand` message, and that the stub was never reached
      *(completed: exit 77, "build mode requires a lake subcommand ... none was given", no
      FAKE_LAKE_ARGV in output)*
- [x] Positive proof: run the NEW form
      (`... bash <guard> build --timeout 1800 --no-share -- build`) and assert `FAKE_LAKE_ARGV: build`
      appears on stdout with exit 0 -- the stub being reached IS the "actually runs" evidence.
      Pass `--no-share` so a cached prior result cannot produce a false REPLAY pass
      *(completed: stdout was exactly `FAKE_LAKE_ARGV: build`, exit 0)*
- [x] Exhaustive audit pattern A: `grep -rn "lake-build-guard.sh build" agent-system/` -- classify
      every hit as correct, corrected-by-Phase-1, or a deliberate usage-error example
      *(completed: 16 hits, all classified -- scoped forms, the 4 corrected full-build forms,
      placeholder/env forms, and guard header/comment mentions; zero unexplained empty vectors)*
- [x] Exhaustive audit pattern B: `grep -rn -- "--timeout 1800" agent-system/` -- catches any
      invocation whose script name is line-wrapped away from the `build` token
      *(completed: 9 hits, all already covered by pattern A or prose mentioning the flag value;
      no new empty-vector site found)*
- [x] Assert the guard and its tests are untouched:
      `git diff --name-only` contains no `agent-system/extensions/core/scripts/lake-build-guard.sh`
      and no `.../tests/test-lake-build-guard.sh` *(completed: empty diff for both paths)*
- [x] Assert nothing under `.claude/**` was hand-edited: `git status --short` shows no such path
      *(completed: confirmed)*

**Timing**: 0.5 hours

**Depends on**: 1

**Verification Tier**: full

**Commit Mode**: per-substep

**Files to modify**:
- None (verification only; the harness lives in the scratchpad and is not committed)

**Verification**:
- Negative control exits 77; positive proof emits `FAKE_LAKE_ARGV: build` and exits 0
- Both audit patterns yield a fully classified hit list with zero unexplained empty-vector forms
- `agent-system/extensions/core/scripts/lake-build-guard.sh` is byte-identical to HEAD
- The full repository gate set passes before the phase closes

---

### Phase 3: Record deployment and consumer-propagation status [COMPLETED]

**Goal**: The deploy acceptance clause is resolved honestly: the in-repo constraint is stated,
the affected consumers are named, and the propagation path is recorded.

**Tasks**:
- [x] Confirm and record that `lean` is not among this repo's active extensions
      (`.claude-extensions.json`), so `deploy-headless.sh` here regenerates no lean artifact --
      the dispatch's "confirm the regenerated `.claude/**` copies carry the fix" cannot be
      satisfied in this repository *(completed: active extensions are literature, nvim, memory,
      nix, email, core -- no lean)*
- [x] Confirm the four touched files are all deploy-carried by
      `agent-system/extensions/lean/manifest.json` (`provides.agents`, `provides.rules`,
      `provides.skills`), so a consumer resync will propagate the fix with no manifest change
      *(completed: all 4 confirmed in provides.agents/provides.rules/provides.skills)*
- [x] Run `bash .claude/scripts/check-consumer-freshness.sh --stale-only` (read-only; guard with
      `|| true`) and record which lean-active consumers are behind source *(completed)*
- [x] Record the three lean-active consumers found during planning
      (`~/Projects/BimodalLogic`, `~/Projects/cslib`, `~/Projects/Logos/Theory`) and confirm
      which of their deployed copies still carry the broken string, read-only
      *(completed with a deviation: check-consumer-freshness.sh actually found 5 lean-registered
      consumers, not 3 -- see the phase-3 progress file's `notes` and the summary's propagation
      record)*
- [x] Do NOT write into any consumer repository on this path -- see the `user_decision`
      *(completed: no consumer repository was written; orchestrator-mode instruction confirmed
      the source-store-only recommended option)*

**Timing**: 0.4 hours

**Depends on**: 2

**Verification Tier**: local

**Commit Mode**: per-substep

**Scope Hypothesis**: This plan asserts 3 lean-active consumer repos, 2 of which still carry the
broken deployed string. Confirm by re-reading each registered consumer's
`.claude-extensions.json` and re-grepping its `.claude/` tree at implementation time rather than
trusting these numbers.

**Files to modify**:
- `specs/176_fix_documented_full_build_guard_invocation/summaries/01_*-summary.md` - propagation record

**Verification**:
- The summary states the in-repo deploy constraint, names the deploy-carried files, and lists
  each lean-active consumer with its current staleness
- No file under any consumer repository was written (`git status` in each consumer is untouched
  by this task)

---

### Phase 4: Hand off the guard usage-banner discrepancy [COMPLETED]

**Goal**: The second, separate discrepancy is recorded and explicitly assigned, without being
fixed here.

**Tasks**:
- [x] Record the contradiction precisely: `lake-build-guard.sh`'s header USAGE block (line ~77)
      and `print_help`'s Usage block (line ~201) both document the trailing lake arguments as
      optional (`[--] [LAKE ARGS...]`), while `validate_build_subcommand()` (line 773) requires a
      non-empty vector and exits 77 without one *(completed: confirmed exact lines 75-77 and
      200-202, and validator at line 773)*
- [x] Note the causal hypothesis: the optional-looking banner is the plausible origin of the
      broken form corrected in Phase 1, which makes fixing the banner a genuine recurrence
      guard, not cosmetics *(completed)*
- [x] Name the owner: the guard-terminal-record task, whose `file_scope` already covers
      `lake-build-guard.sh`; state that this task deliberately did not edit that file to avoid a
      same-file collision *(completed: identified as project_number 173,
      "guard_terminal_record_every_exit", file_scope includes lake-build-guard.sh and its test)*
- [x] Also surface, as a distinct out-of-scope observation, the unguarded bare `lake build` at
      `context/project/lean4/agents/lean-implementation-flow.md:123-126`, which contradicts
      `long-builds.md`'s detach-and-guard mandate *(completed: confirmed present)*
- [x] Note the declined follow-up: no regression lint was added for the corrected strings
      *(completed)*

**Timing**: 0.35 hours

**Depends on**: none

**Verification Tier**: prose

**Commit Mode**: per-substep

**Files to modify**:
- `specs/176_fix_documented_full_build_guard_invocation/summaries/01_*-summary.md` - discrepancy handoff section

**Verification**:
- The summary contains a clearly headed handoff naming the file, both banner locations, the
  validator location, and the owning task
- `git diff --name-only` confirms `lake-build-guard.sh` was not modified by this task

---

## Testing & Validation

- [ ] Negative control reproduces exit 77 on the old form
- [ ] Positive proof shows the corrected form reaching the `lake` stub (`FAKE_LAKE_ARGV: build`)
- [ ] `grep -rn "lake-build-guard.sh build" agent-system/` has zero unexplained empty-vector hits
- [ ] `grep -rn -- "--timeout 1800" agent-system/` adds no unclassified hit
- [ ] Exactly 4 files changed, all under `agent-system/extensions/lean/`
- [ ] `lake-build-guard.sh` and `test-lake-build-guard.sh` are unmodified
- [ ] No `.claude/**` path appears in `git status --short`
- [ ] Every corrected site still reads as a full-repository build instruction in context

## Artifacts & Outputs

- Corrected source-store files (4)
- `specs/176_fix_documented_full_build_guard_invocation/summaries/01_*-summary.md` containing:
  the corrected-site inventory, the runtime-proof transcript, the consumer-propagation record,
  the guard usage-banner handoff, and the two declined follow-ups

## Rollback/Contingency

All changes are five single-line prose edits across four markdown files, fully reverted with
`git checkout -- agent-system/extensions/lean/` (only if the working tree is otherwise clean, or
after `bash .claude/scripts/git-snapshot.sh 176`). No script, test, manifest, or deployed artifact
is touched, so there is no regeneration, no consumer, and no runtime state to unwind. If the
runtime proof in Phase 2 fails, stop before Phase 3: the corrected form is wrong and the site
list must be re-derived rather than deployed onward.
