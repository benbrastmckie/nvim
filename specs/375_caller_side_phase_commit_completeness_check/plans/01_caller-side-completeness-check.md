# Implementation Plan: Task #375

- **Task**: 375 - Caller-side phase-commit completeness check
- **Status**: [IMPLEMENTING]
- **Effort**: 6.5 hours
- **Dependencies**: None
- **Research Inputs**: specs/375_caller_side_phase_commit_completeness_check/reports/01_caller-side-completeness-check.md
- **Artifacts**: plans/01_caller-side-completeness-check.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

The incident this task exists to close was a caller-side omission: a phase commit's
`stage_paths` array was hand-typed, one of ten regenerated files was never named, and
`git-commit-scoped.sh` committed exactly what it was given and exited 0. The fix is to stop
asking agent prose to type the list. This plan adds one new mechanized wrapper script
(`git-commit-phase.sh`) that derives the stage list from the phase's own progress-file
`files_touched` arrays, invokes `git-commit-scoped.sh` unpiped, and then verifies post-commit
that every derived path is clean against HEAD — failing loudly and naming each dirty path
otherwise. Both phase-commit call sites in `general-implementation-agent.md` migrate to it, a
lint rule mechanizes the no-pipe/exit-code requirement, and two durable records that still carry
the disproven causal attribution are corrected.

### Research Integration

The research report settles four things this plan builds on directly:

- **F1 (root cause, re-verified against the primary transcript)**: the originating `tool_use`
  (`toolu_01JgkBy3RifdvaRCCs4DZDtt`, 2026-10-08T21:28:54Z) named exactly nine
  `typst/manual/generated/components/*.typ` paths and never named `zigzag.typ`;
  `git show --stat fc9f786e` carries exactly those same nine. Input and output agree — the script
  behaved correctly and the omission was entirely in constructing the array.
- **F3 (the mechanical gap)**: `general-implementation-agent.md` has two phase-commit sites.
  The per-objective site (Stage 4B-iii) already derives `stage_paths` with a working `jq` loop.
  The per-phase site (Phase Checkpoint Protocol step 5) has only a **comment** telling the agent
  to append `files_touched` — no derivation code. That is the exact site the incident's commit
  message matches, and the exact gap a hand-typed enumeration filled in by hand. Both sites were
  re-read at plan time and both were confirmed as the report describes.
- **F4 (scope item 3)**: an exhaustive sweep of every `.md`/`.sh` under
  `agent-system/extensions/core/` found **no** documented template that pipes
  `git-commit-scoped.sh` through `tail`/`head`/`grep` — the incident's `| tail -25` was ad hoc,
  not inherited. Re-confirmed at plan time (the only pipe match in the tree is an assertion
  inside `tests/test-git-commit-scoped.sh`, not an invocation template). The present-tense gap is
  different and real: neither phase-commit site shows any exit-code check at all, not even
  `checkpoint-commit.md`'s bare `$?` pattern.
- **F5/D3 (scope item 4, in-repo half)**: already discharged. Both disproven causal claims in
  `git-commit-scoped.sh` and `git-staging-scope.md` have been withdrawn in the source store.

Three pieces of transcript evidence supplied by the orchestrator (confirmed independently of the
research pass) are the direct argument for derivation over hand-typing, and are recorded here
because they are the justification for Phase 1's design rather than an optional detail:
`zigzag.typ` **was** regenerated on disk (transcript line 735), **was** recorded in the caller's
own progress `files_touched` (line 802), and **was** showing as modified in a `git status` check
run immediately before the commit (line 812). The data needed to catch the omission was already
present in three separate places the caller itself had produced. Only the stage-list construction
step lost it.

**Citation correction carried into this plan.** The research report's Decisions section attributes
the withdrawal of the two causal claims in `git-commit-scoped.sh` to commit `b33aca69c`. That
attribution is wrong and is not propagated here: `b33aca69c`
("task 374 phase 4: record the V8 ruling, git semantics, and corrected fail-open comment") is the
commit that **introduced** those claims. The withdrawal landed in **`db9e092af`** (the edits to
`git-commit-scoped.sh` and `git-staging-scope.md`) and **`da3fb6cdc`** (the issue-log record,
committed as "task 374 phase 4.1: withdraw unsupported causal claims about the fc9f786e
incident"). All three were verified by `git show --stat` at plan time. The report's *conclusion* —
that the claims are corrected and need no further in-repo action — is correct and stands.

**The same inverted attribution has since been written into a durable record in this
repository**, and a future reader trusting that record would reintroduce the error, so it is
named here rather than left implicit. Entry `iss_1791536517779_09aSQf` in
`specs/374_diagnose_silent_staging_drop_in_git_commit_scoped/issues.jsonl` asserts the prose
corrections "were ALREADY corrected as part of commit `b33aca69c` itself" and that the earlier
`da3fb6cdc` record "misleadingly implied a separate commit that never existed." Both halves are
false, measured directly: occurrences of the uncorrected fail-open text
(`OVERLAPPING path can drop`) in `git-commit-scoped.sh` run `b33aca69c` 1, `6e97da77a` 1,
`6c4699f0a` 1, `db9e092af` 0, HEAD 0; and `git log --` on that single file lists `db9e092af` as
the most recent commit touching it. Both measurements were reproduced at plan time. That entry's
*substantive* third-location finding is accurate and unaffected — a third occurrence did survive
in `tests/test-git-commit-scoped.sh` and `fb73104cb` genuinely corrected it, suite 47/47. Phase 5
appends a correcting entry covering the provenance half only, and says so explicitly, so the real
fix is not discredited along with the bad citation.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No roadmap path was provided in this dispatch; no roadmap phases are included.

## Goals & Non-Goals

**Goals**:

- Remove hand-typed phase-commit stage lists at their source by deriving them mechanically from
  the phase's own progress-file `files_touched` arrays (scope item 2).
- Add a post-commit completeness check that fails loudly, naming each `files_touched` path not
  clean against HEAD after the phase commit (scope item 1).
- Make `git-commit-scoped.sh`'s real exit code observable at both phase-commit call sites, and
  mechanize the no-pipe requirement so the ad hoc `| tail` shape cannot reappear unnoticed
  (scope item 3).
- Correct the three durable records that still assert a disproven claim: the two the dispatch
  named, plus an in-repo issue-log entry that inverts the provenance of the correction this task
  relies on (scope item 4).
- Leave deployed trees refreshed so live dispatches run the new check.

**Non-Goals**:

- Changing `git-commit-scoped.sh`'s staging semantics, exit-code vocabulary, or any of its
  existing safety gates (V2-V8). The new script is strictly a caller sitting in front of it.
- Deciding whether `specs/.commit-lock` should fail closed (a separate, already-flagged
  follow-up).
- Widening any pathspec beyond `files_touched` plus the fixed task-directory scope.
- Folding in the backlog items targeting in-script pathspec defects (scoped-commit directory
  pathspec and task lease, out-of-repo pathspec aborts, directory-pathspec lint as a gate) —
  each targets a defect inside the script, not caller-side completeness.
- Pushing anything to any remote, in this repository or the cross-repo one.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Migrating the call sites silently drops the existing Phase-Commit Containment Self-Check, which operates on a `stage_paths` array the agent will no longer build | H | H | Phase 1 ports that prose check into the wrapper verbatim — same drop-and-warn, same unconditional fail-open, same `issue-record.sh` call. This is a port of documented behavior, required so the migration does not regress a live safety behavior; it is not new policy. |
| A progress file is missing or malformed when the wrapper runs (an agent not using the progress-file machinery) | M | M | Fail open to the existing fixed task-directory scope with a loud stderr warning, and skip the completeness check (there is nothing to check against). Never block a commit over a missing optional input — `git-staging-scope.md`'s settled Fail-Safe Direction. |
| The completeness check produces false positives on paths a concurrent writer dirtied after the commit | M | M | Check only the derived `files_touched` set, never the whole tree; report paths rather than refusing to proceed; the exit code is the signal, and the caller's recovery is a follow-up commit of the named paths, not a widened pathspec. |
| The wrapper's own exit code collides with `git-commit-scoped.sh`'s 0-5 vocabulary and confuses callers | M | M | Reserve a distinct code (6) for the completeness failure, pass every inner code through verbatim otherwise, and document the full mapping in the wrapper's header and at both migrated call sites. |
| The cross-repo append runs while a sibling correction is in flight in the same file | L | L | `issues.jsonl` is append-only, so a second append cannot conflict destructively. Re-read the file immediately before appending and confirm no later entry already records the correction. |
| Editing the agent contract trips `lint-agent-contracts.sh` or Rule E (a script referenced in docs but undeclared in the manifest) | M | M | Declare the new script in `manifest.provides.scripts` in Phase 1, before any doc references it in Phase 3; re-verify with `sync-manifest-scripts.sh --check` at the final gate. |

## Implementation Phases

**Dependency Analysis**:

| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1, 4, 5 | -- |
| 2 | 2, 3 | 1 |
| 3 | 6 | 1, 2, 3, 4, 5 |

Phases within the same wave can execute in parallel.

### Phase 1: Mechanized Phase-Commit Wrapper Script [COMPLETED]

**Goal**: Create `agent-system/extensions/core/scripts/git-commit-phase.sh` — the single
mechanical chokepoint that derives the stage list, commits unpiped through
`git-commit-scoped.sh`, and runs the post-commit completeness check. This one script discharges
scope items 1 and 2 together.

**Tasks**:

- [x] Write the script header documenting: the incident it closes (a caller-side omission, with *(completed)*
      the three places the data was already present), the `update-phase-status.sh` mechanization
      precedent (a prose heartbeat instruction fired 0/8 times; mechanizing the identical step
      inside a script every caller must invoke fired 16/16), the full argument interface, and the
      exit-code mapping.
- [x] Implement the argument interface, flag-style to match the script it wraps: *(completed)*
      `--task N --project SLUG --phase P --message MSG --session SID [--objective ID]
      [--plan-path PATH]`. `--objective ID` narrows derivation to one objective (the
      per-objective green-substep site); absent, derivation unions every objective in the phase
      (the per-phase closing-commit site).
- [x] Resolve the task directory (`specs/{NNN}_{SLUG}/`) and the progress file *(completed)*
      (`specs/{NNN}_{SLUG}/progress/phase-{P}-progress.json`).
- [x] Derive the `files_touched` set: `jq -r '[.objectives[].files_touched[]?] | unique[]'` for *(completed)*
      the whole-phase form, and the existing single-objective `select(.id == ...)` form when
      `--objective` is given. Deduplicate; tolerate absent/empty arrays.
- [x] Prepend the fixed `implement` scope exactly as `git-staging-scope.md` already defines it: *(completed)*
      `{task_dir}/`, `specs/TODO.md`, `specs/state.json`, and the plan path when supplied. These
      four stay structurally outside the containment filter, as that document already specifies.
- [x] Port the Phase-Commit Containment Self-Check (currently prose at Stage 4B-iii of *(completed)*
      `general-implementation-agent.md`) into the script, preserving its semantics exactly: read
      the task's declared `file_scope` from `specs/state.json`; carve out the four fixed paths;
      apply the containment predicate (exact match, or either path an ancestor of the other);
      drop-and-warn on an uncontained entry with the existing warning wording; record it
      non-fatally via `issue-record.sh --class "scope excursion"`; and fail OPEN on any missing,
      empty, unreadable, or malformed `file_scope` or any internal error.
- [x] Invoke `git-commit-scoped.sh` with the derived pathspec, forwarding `--task`, with **no *(completed)*
      pipe** — capture its exit code directly into a variable.
- [x] Implement the post-commit completeness check: for every derived `files_touched` path, run *(completed)*
      `git status --porcelain -- <path>`. If any is non-empty, print
      `ERROR: phase commit completeness check failed — the following files_touched path(s) are
      not clean against HEAD after the commit:` followed by each dirty path on its own line.
- [x] Implement the exit-code mapping and document it in the header: `6` when the completeness *(completed)*
      check failed (whatever the inner code was, since the defining feature of this defect is an
      inner code of 0); otherwise the inner code passed through verbatim (0, 1, 2, 3, 4, 5).
      Note explicitly that "nothing to commit" (inner 1) with dirty `files_touched` paths is
      itself the silent-drop shape and correctly yields 6.
- [x] Implement the fail-open path: a missing or malformed progress file emits a loud stderr *(completed)*
      warning, falls back to the fixed task-directory scope, **skips** the completeness check,
      and exits with the inner code.
- [x] Add `git-commit-phase.sh` to `manifest.provides.scripts` via *(completed)*
      `bash agent-system/extensions/core/scripts/sync-manifest-scripts.sh --write` (before any
      doc references it in Phase 3, so Rule E and Rule Q stay green throughout).

**Timing**: 1.5 hours

**Depends on**: none

**Verification Tier**: local

**Commit Mode**: per-substep

**Tier Justification**: `bash -n` on the new script plus a scratch-repo smoke run (a synthetic
task directory, a progress file naming two paths, one of them deliberately left out of the
commit) covers a single new standalone script that no other file calls yet.

**Files to modify**:

- `agent-system/extensions/core/scripts/git-commit-phase.sh` - new; the mechanized wrapper
- `agent-system/extensions/core/manifest.json` - declare the new script in `provides.scripts`

**Verification**:

- `bash -n agent-system/extensions/core/scripts/git-commit-phase.sh` exits 0.
- A scratch git repo smoke run: a progress file declaring two `files_touched` paths where only
  one is reachable by the commit produces exit 6 and names the other path on stderr.
- The same smoke run with both paths committed produces exit 0 and no ERROR line.
- A smoke run with the progress file deleted produces the fail-open warning, no completeness
  check, and the inner exit code.
- `bash agent-system/extensions/core/scripts/sync-manifest-scripts.sh --check` exits 0.

---

### Phase 2: Fixture Suite for the Wrapper [NOT STARTED]

**Goal**: Add `tests/test-git-commit-phase.sh`, the regression suite that pins the acceptance
criterion: a phase touching N files whose commit reaches only N-1 fails loudly and names the
missing path.

**Tasks**:

- [ ] Write `agent-system/extensions/core/scripts/tests/test-git-commit-phase.sh` following
      `test-git-commit-scoped.sh`'s structural model (pass/fail counters, `mktemp -d` workdir
      with a `trap EXIT` cleanup, source-store-first resolution of the script under test, an
      explicit exit-code contract of 0/1/2).
- [ ] **Acceptance fixture**: a synthetic repo and task directory whose
      `phase-{P}-progress.json` declares N `files_touched` paths, where the commit lands only
      N-1 (planted via a pre-commit hook that unstages one path, mirroring the sibling suite's
      V8 fixture technique). Assert exit 6, assert the missing path is named in the output, and
      assert the other N-1 paths are not named.
- [ ] Derivation fixture: assert the derived pathspec is the union of every objective's
      `files_touched` plus the four fixed paths, deduplicated — and that no hand-typed list is
      required for the commit to be complete.
- [ ] `--objective` fixture: assert derivation narrows to the named objective only, matching the
      existing per-objective behavior it replaces.
- [ ] Fail-open fixtures: missing progress file, malformed JSON, and empty `files_touched` each
      warn, skip the check, and return the inner exit code rather than refusing the commit.
- [ ] Containment-port fixtures: an uncontained path is dropped with the warning and the commit
      still lands; a missing or malformed `file_scope` proceeds exactly as if the check were
      absent.
- [ ] Exit-code pass-through fixture: an inner non-zero code with a clean `files_touched` set is
      returned verbatim, not rewritten to 6.
- [ ] Register the suite in `manifest.provides.scripts` via `sync-manifest-scripts.sh --write`,
      and add a `suite-cost-hints.txt` entry consistent with neighbouring git-suite hints.

**Timing**: 1.5 hours

**Depends on**: 1

**Verification Tier**: local

**Commit Mode**: per-substep

**Tier Justification**: `bash agent-system/extensions/core/scripts/tests/run-all.sh --only
test-git-commit-phase` exercises every assertion in the new suite, which is the only consumer of
this phase's edits.

**Files to modify**:

- `agent-system/extensions/core/scripts/tests/test-git-commit-phase.sh` - new; the fixture suite
- `agent-system/extensions/core/scripts/tests/suite-cost-hints.txt` - add the new suite's hint
- `agent-system/extensions/core/manifest.json` - declare the new test in `provides.scripts`

**Verification**:

- `bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-git-commit-phase`
  reports every assertion passing and exits 0.
- The N-vs-N-1 assertion fails as expected when the completeness check is temporarily stubbed out
  (confirming the fixture actually tests the check rather than passing vacuously).
- `bash agent-system/extensions/core/scripts/sync-manifest-scripts.sh --check` exits 0.

---

### Phase 3: Migrate Both Phase-Commit Call Sites [NOT STARTED]

**Goal**: Replace the hand-typed and comment-only stage-list construction at both phase-commit
sites in `general-implementation-agent.md` with a single call to the wrapper, and point
`git-staging-scope.md` at the wrapper as the canonical per-phase implementation.

**Tasks**:

- [ ] Replace the Stage 4B-iii per-objective bash block (the `stage_paths=(...)` + `jq` loop +
      direct `git-commit-scoped.sh` call) with a single `git-commit-phase.sh --objective ...`
      invocation, followed by an explicit exit-code check that names what each code means for the
      agent's next move — including 6, whose recovery is a follow-up commit of the named paths and
      never a widened pathspec.
- [ ] Replace the Phase Checkpoint Protocol step 5 bash block (whose only derivation today is a
      comment) with the whole-phase `git-commit-phase.sh` invocation plus the same explicit
      exit-code check. Delete the now-redundant derivation comment and the surrounding prose that
      instructs the agent to append `files_touched` by hand.
- [ ] Rewrite the Phase-Commit Containment Self-Check section to state that the wrapper now
      performs the check mechanically, keeping the predicate's documentation (it is still the
      durable description of the policy) but removing the instruction to run it by hand. Record
      honestly that the self-check's own prose named `git-commit-scoped.sh` as the eventual
      mechanical home; the wrapper is that home instead, because changing
      `git-commit-scoped.sh`'s staging semantics is out of scope for this task — and the wrapper,
      unlike that script, actually knows what the phase touched.
- [ ] Add a cross-reference from `git-staging-scope.md`'s Reference Template to
      `git-commit-phase.sh` as the sanctioned per-phase derivation implementation, matching how
      that document already treats `git-commit-scoped.sh` for the base commit. Keep the
      template's prose as documentation of the shape.
- [ ] Re-grep for any other file in the source store that shows a hand-typed phase-commit
      `stage_paths` array, and migrate or cross-reference each one found.

**Timing**: 1 hour

**Depends on**: 1

**Verification Tier**: interface

**Commit Mode**: per-substep

**Scope Hypothesis**: exactly two phase-commit call sites exist in
`general-implementation-agent.md` (Stage 4B-iii, around line 400, and Phase Checkpoint Protocol
step 5, around line 880). Confirm at implementation time with
`grep -n "git-commit-scoped.sh" agent-system/extensions/core/agents/general-implementation-agent.md`
before editing, and migrate whatever that grep actually returns rather than assuming two.

**Tier Justification**: these edits change the agent contract that `lint-agent-contracts.sh`
parses and that Rule E of `check-extension-docs.sh` cross-checks against
`manifest.provides.scripts`; both of those plus `lint-scoped-commit-boundary.sh` are the covering
checks, and no cheaper local check sees the doc-to-manifest surface.

**Files to modify**:

- `agent-system/extensions/core/agents/general-implementation-agent.md` - migrate both call
  sites; rewrite the containment self-check section
- `agent-system/extensions/core/context/standards/git-staging-scope.md` - cross-reference the
  wrapper as the canonical per-phase implementation

**Verification**:

- `grep -n "git-commit-scoped.sh" agent-system/extensions/core/agents/general-implementation-agent.md`
  shows no remaining direct phase-commit invocation (narrative references to the script are
  expected and fine).
- `bash agent-system/extensions/core/scripts/lint/lint-agent-contracts.sh` exits 0.
- `bash agent-system/extensions/core/scripts/check-extension-docs.sh` reports no Rule E or Rule Q
  finding for the new script.
- `bash agent-system/extensions/core/scripts/lint/lint-scoped-commit-boundary.sh --verbose`
  exits 0.

---

### Phase 4: Mechanize the No-Pipe / Exit-Code Requirement [NOT STARTED]

**Goal**: Extend `lint-scoped-commit-boundary.sh` with a rule that detects a phase-commit
invocation whose output is piped (so the caller cannot observe the real exit code), and extend
its fixture suite. This turns scope item 3 from a one-time prose cleanup into a standing
guardrail, wired as a gate for free.

**Tasks**:

- [ ] Record the scope item 3 enumeration result explicitly in the lint's header: a sweep of
      every `.md` and `.sh` under `agent-system/extensions/` found **zero** documented templates
      piping `git-commit-scoped.sh` through `tail`/`head`/`grep`. The incident's `| tail -25` was
      ad hoc, not inherited from any template. There is therefore nothing to remove — and that is
      precisely why a standing detector is the deliverable instead of a cleanup pass.
- [ ] Add the detection rule: a line invoking `git-commit-scoped.sh` or `git-commit-phase.sh`
      whose invocation is piped into another command, without `set -o pipefail` in effect, is a
      finding. Name the file, the line, and the reason (the caller cannot observe the script's
      real exit code, so the dedicated silent-drop exit code never reaches it).
- [ ] Document the rule's limitation in the same honest register the lint's existing KNOWN
      LIMITATION section uses: this is a regex-only, line-oriented content lint, so it cannot see
      a pipe assembled across lines or routed through a wrapper function whose body it never
      reads.
- [ ] Extend `tests/test-lint-scoped-commit-boundary.sh` with fixtures: a piped invocation is
      flagged; the same invocation under `set -o pipefail` is not; an unpiped invocation is not;
      a pipe inside a test assertion (`echo "$out" | grep -q ...`, the shape that already exists
      legitimately in `test-git-commit-scoped.sh`) is not flagged.

**Timing**: 1 hour

**Depends on**: none

**Verification Tier**: local

**Commit Mode**: per-substep

**Scope Hypothesis**: zero existing invocations in the source store will be flagged by the new
rule, so it lands green. Confirm before writing the rule by running
`grep -rn "git-commit-scoped.sh" agent-system/extensions/ -A3 | grep -E "\| *(tail|head|grep)"`
and checking that every hit is a test assertion rather than an invocation template; if a real
piped invocation turns up, fix it in this phase rather than exempting it.

**Tier Justification**: `bash agent-system/extensions/core/scripts/tests/run-all.sh --only
test-lint-scoped-commit-boundary` plus a self-run of the lint over the whole source store covers
both the new rule's logic and its behavior against every real call site.

**Files to modify**:

- `agent-system/extensions/core/scripts/lint/lint-scoped-commit-boundary.sh` - add the piped-
  invocation rule and the enumeration record
- `agent-system/extensions/core/scripts/tests/test-lint-scoped-commit-boundary.sh` - add the four
  fixtures

**Verification**:

- `bash agent-system/extensions/core/scripts/tests/run-all.sh --only
  test-lint-scoped-commit-boundary` passes and exits 0.
- `bash agent-system/extensions/core/scripts/lint/lint-scoped-commit-boundary.sh --verbose` over
  the real source store exits 0 (no false positives on existing call sites).
- `bash agent-system/extensions/core/scripts/verify-deploy.sh --only-gate 17` passes, confirming
  the new rule is wired into the existing gate without further plumbing.

---

### Phase 5: Correct the Three Durable Records [NOT STARTED]

**Goal**: Discharge what remains of scope item 4 — the cross-repo append, the one in-repo
miscount that still carries the disproven detail, and the in-repo issue-log entry that inverts
the provenance of the very correction this task relies on.

**Tasks**:

- [ ] Re-read `~/Projects/Logos/Verification/specs/224_review_and_refactor_fragile_gate_infrastructure/issues.jsonl`
      immediately before appending, and confirm no later entry already records this correction.
- [ ] **Append** (never edit — the file is append-only) a correcting entry for
      `iss_1791495993077_nD5IuJ`, minting a fresh `entry_id` and `timestamp` at append time per
      that file's own `iss_{timestamp}_{rand}` convention. The entry must cite the transcript
      evidence directly: the originating `tool_use` (`toolu_01JgkBy3RifdvaRCCs4DZDtt`,
      2026-10-08T21:28:54Z) named nine `components/*.typ` paths and never named `zigzag.typ`;
      `fc9f786e`'s own diff carries exactly those nine; the phase's progress file already
      recorded `zigzag.typ` in objective 2's `files_touched`; and the script committed exactly
      what it was given and exited 0. State that the correction addresses the causal attribution
      only and does not reopen `nD5IuJ`'s `fixed_inline` resolution — commit `96986be6` genuinely
      fixed the stale file.
- [ ] Note in the entry that the follow-up commit `96986be6`'s own message makes the same
      incorrect claim, so a future reader encountering it has the correction in hand.
- [ ] Commit that one file in the Verification repository, scoped to it alone, via that tree's
      own `git-commit-scoped.sh`, using that repository's owning-task message convention. Do not
      push, and do not touch any other file there.
- [ ] Fix `git-staging-scope.md`'s Staging-Layer Containment Filter passage (the "Empirical
      basis" paragraph, around line 263): change "ten generated Typst files" to "nine" and remove
      `zigzag.typ` from the enumerated brace list. Leave the passage's actual point — that the
      originating task's declared `file_scope` named exactly one of them — untouched, since
      declared-scope-versus-landed-files is a different predicate from the drop this task
      researches and is unaffected by the count.
- [ ] Re-check the current state of `git-commit-scoped.sh`'s fail-open comment and V8 header
      before concluding no in-repo script correction is needed. The withdrawal of the two causal
      claims landed in `db9e092af` (the edits) and `da3fb6cdc` (the issue-log record); confirm
      both still read as withdrawn and that a concurrent sibling dispatch has not reintroduced
      either claim.
- [ ] **Append** a correcting entry to
      `specs/374_diagnose_silent_staging_drop_in_git_commit_scoped/issues.jsonl` for entry
      `iss_1791536517779_09aSQf`, which asserts the two prose corrections "were ALREADY corrected
      as part of commit `b33aca69c` itself" and that the earlier `da3fb6cdc` record "misleadingly
      implied a separate commit that never existed." Both halves of that provenance claim are
      false, and the correcting entry must carry the measurement that refutes them rather than
      merely contradicting them: counting occurrences of the uncorrected fail-open text
      (`OVERLAPPING path can drop`) in `git-commit-scoped.sh` at each commit gives `b33aca69c` 1,
      `6e97da77a` 1, `6c4699f0a` 1, `db9e092af` 0, HEAD 0 — so `b33aca69c` **introduced** the
      claims and `db9e092af` **withdrew** them, three commits later. Separately,
      `git log -- agent-system/extensions/core/scripts/git-commit-scoped.sh` lists `db9e092af` as
      the most recent commit touching that file, directly refuting "nothing after `b33aca69c`
      touched either file." Reproduce both measurements at append time rather than copying these
      numbers forward.
- [ ] In that same entry, state explicitly that only the **provenance half** of `09aSQf` is
      wrong. Its substantive third-location finding is accurate and independently verified: a
      third occurrence of the false mechanism-equivalence did survive in
      `tests/test-git-commit-scoped.sh`, and `fb73104cb` genuinely corrected it with the suite
      passing 47/47. A correcting entry that left that ambiguous would discredit a real fix, which
      is the opposite of this phase's purpose. Also note that the earlier entry `09aSQf` impugns
      (`iss_1791536155128_hv53qb`, "both claims corrected by a follow-up commit") was accurate as
      written and needs no correction of its own.
- [ ] Do not edit or retract `09aSQf` — `issues.jsonl` is append-only in this repository exactly
      as it is in the Verification one. The remedy is the appended entry and nothing else.

**Timing**: 0.75 hours

**Depends on**: none

**Verification Tier**: local

**Commit Mode**: per-substep

**Scope Hypothesis**: the "ten generated Typst files" miscount occurs exactly once in the source
store, in `git-staging-scope.md`'s Empirical-basis paragraph. Confirm with
`grep -rn "zigzag" agent-system/` before editing and fix every occurrence that turns up, not just
the one line this plan names.

**Tier Justification**: `jq -e . ` over each appended JSONL line (confirming it parses and both
files stay one-object-per-line) plus `check-task-references.sh` over the edited in-repo document
covers all three edits; none touches code any suite exercises.

**Files to modify**:

- `~/Projects/Logos/Verification/specs/224_review_and_refactor_fragile_gate_infrastructure/issues.jsonl`
  - append one correcting entry (cross-repo; the only mutation outside this repository)
- `agent-system/extensions/core/context/standards/git-staging-scope.md` - correct the count and
  drop `zigzag.typ` from the enumerated list
- `specs/374_diagnose_silent_staging_drop_in_git_commit_scoped/issues.jsonl` - append one
  correcting entry for the inverted provenance claim in `iss_1791536517779_09aSQf`

**Verification**:

- `tail -1` of the Verification `issues.jsonl` parses as a single JSON object under `jq -e .`,
  and the file's line count increased by exactly one.
- `grep -c zigzag` over `agent-system/extensions/core/context/standards/git-staging-scope.md`
  returns 0, and the passage reads "nine generated Typst files".
- `grep -n "ten generated" agent-system/` returns nothing.
- `git -C ~/Projects/Logos/Verification log -1 --stat` shows exactly one file in the new commit,
  and `git -C ~/Projects/Logos/Verification status --porcelain` is clean afterwards.
- `git-commit-scoped.sh`'s fail-open comment and V8 header still read as withdrawn (no
  `(reproduced)` claim, no concurrency-race or dropped-named-pathspec attribution).
- `tail -1` of `specs/374_.../issues.jsonl` parses under `jq -e .`, the file's line count
  increased by exactly one, and `iss_1791536517779_09aSQf` is still present byte-identical
  (confirming the append-only contract held and nothing was retracted in place).
- The per-commit occurrence count and the `git log --` single-file history are both re-run at
  append time and reproduce the figures the entry cites.

---

### Phase 6: Manifest Sync, Redeploy, and Full Gate Set [NOT STARTED]

**Goal**: Land the new machinery in the deployed trees so live dispatches actually run the new
check, and confirm the whole change is green against the complete gate set.

**Tasks**:

- [ ] `bash agent-system/extensions/core/scripts/sync-manifest-scripts.sh --check` and confirm
      both new files are declared; run `--write` and re-check if anything drifted.
- [ ] `bash agent-system/extensions/core/scripts/deploy-headless.sh` to refresh the deployed
      `.claude/` tree(s) from the source store.
- [ ] Confirm the deployed `git-commit-phase.sh` is present, executable, and byte-identical to
      the source-store copy.
- [ ] Run the complete gate set and record the results: `verify-deploy.sh` (full battery, no
      `--only-gate`), `tests/run-all.sh` (full, no `--only`), `check-extension-docs.sh`,
      `lint-agent-contracts.sh`, `lint-scoped-commit-boundary.sh --verbose`,
      `lint-directory-pathspec-boundary.sh`, and `check-task-references.sh`.
- [ ] Confirm no task-number reference landed in any file under `agent-system/**`, per the
      no-task-references rule — the new script's header must cite the incident by commit SHA and
      transcript id, never by task number.
- [ ] Write the implementation summary.

**Timing**: 0.75 hours

**Depends on**: 1, 2, 3, 4, 5

**Verification Tier**: full

**Commit Mode**: per-substep

**Files to modify**:

- `agent-system/extensions/core/manifest.json` - final sync if anything drifted
- deployed `.claude/` tree(s) - regenerated by `deploy-headless.sh`, not hand-edited
- `specs/375_caller_side_phase_commit_completeness_check/summaries/01_caller-side-completeness-check-summary.md`
  - new; the implementation summary

**Verification**:

- `bash agent-system/extensions/core/scripts/verify-deploy.sh` full battery passes (all gates
  1-21, no `--only-gate` filter).
- `bash agent-system/extensions/core/scripts/tests/run-all.sh` full run passes, with any failure
  present in `known-failures.txt` and no NEW failure.
- `bash agent-system/extensions/core/scripts/check-extension-docs.sh` reports no new finding.
- `bash agent-system/extensions/core/scripts/lint/lint-agent-contracts.sh`,
  `lint/lint-scoped-commit-boundary.sh --verbose`, and
  `lint/lint-directory-pathspec-boundary.sh` each exit 0.
- `bash agent-system/extensions/core/scripts/check-task-references.sh` reports no occurrence
  under `agent-system/**`.
- The deployed `.claude/scripts/git-commit-phase.sh` exists and matches the source-store copy.

## Testing & Validation

- [ ] The acceptance fixture passes: a phase declaring N `files_touched` paths whose commit lands
      only N-1 exits non-zero and names the missing path.
- [ ] The derived stage list equals the union of every objective's `files_touched` plus the four
      fixed `specs/` paths, with no hand-typed enumeration anywhere in the path.
- [ ] `--objective` narrows derivation to one objective, preserving the per-objective
      green-substep behavior it replaces.
- [ ] Every fail-open path (missing progress file, malformed JSON, empty `files_touched`, missing
      or malformed `file_scope`) warns loudly and still permits the commit.
- [ ] The containment port drops an uncontained path with the existing warning and records it
      non-fatally, matching the prose it replaces.
- [ ] `git-commit-scoped.sh`'s real exit code reaches the caller at both migrated sites, with no
      pipe between them, and the new lint rule flags a piped invocation while leaving legitimate
      test-assertion pipes alone.
- [ ] Both `issues.jsonl` appends parse as JSON and leave their files append-only and
      one-object-per-line.
- [ ] `git-commit-scoped.sh` itself is unchanged by this task — no edit to its staging semantics,
      exit-code vocabulary, or safety gates.

## Artifacts & Outputs

- `agent-system/extensions/core/scripts/git-commit-phase.sh` - the mechanized phase-commit
  wrapper (derivation + containment + unpiped commit + post-commit completeness check)
- `agent-system/extensions/core/scripts/tests/test-git-commit-phase.sh` - its fixture suite,
  carrying the N-vs-N-1 acceptance criterion
- Edits to `general-implementation-agent.md` migrating both phase-commit call sites
- A new piped-invocation rule in `lint-scoped-commit-boundary.sh` plus its fixtures
- One appended correcting entry in the Verification repository's `issues.jsonl`
- One appended correcting entry in this repository's
  `specs/374_diagnose_silent_staging_drop_in_git_commit_scoped/issues.jsonl`, correcting the
  inverted commit provenance while preserving that entry's accurate third-location finding
- Corrected count and enumeration in `git-staging-scope.md`'s Empirical-basis passage
- Refreshed deployed `.claude/` tree(s)
- An implementation summary under this task's `summaries/`

## Rollback/Contingency

The new script and its suite are additive: deleting both files and reverting the
`manifest.provides.scripts` entries restores the prior state exactly, with no consumer left
dangling. The call-site migration in Phase 3 is the only edit that removes working behavior
(the `jq` loop at Stage 4B-iii); reverting that one file restores it, and because the wrapper
performs the same derivation, a partial state where the wrapper exists but the call sites are not
yet migrated is functional rather than broken. The Phase 4 lint rule can be reverted
independently. Neither of Phase 5's two appends can be reverted by deletion — both files are
append-only by contract — so if either entry turns out to be wrong, the remedy is a further
appended correction, never an edit or a revert of the line. The Phase 6 redeploy is regenerable:
re-running `deploy-headless.sh` after any source-store revert brings the deployed trees back into
agreement.
