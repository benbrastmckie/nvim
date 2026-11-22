# Implementation Plan: Task #660

- **Task**: 660 - Init specs ignores specs by default
- **Status**: [COMPLETED]
- **Effort**: 5.75 hours
- **Dependencies**: None blocking (task 658 already completed; task 338 shares territory, declared not blocking)
- **Research Inputs**: specs/660_init_specs_ignores_specs_by_default/reports/01_init-specs-ignores-by-default.md
- **Artifacts**: plans/01_init-specs-ignores-by-default.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

A freshly initialized repository should land with its whole `specs/` tree gitignored, and the
only placement that achieves this is the consumer's **repo-root** `.gitignore` — a rule confined
to `specs/.gitignore` cannot make `git check-ignore -q -- specs` succeed, which is the exact
mechanism `scripts/lib/specs-ignore-lib.sh`'s `specs_tree_is_gitignored()` (and therefore the
whole V13 commit-path gate) depends on. This plan adds one new, idempotent step to
`init-specs.sh` that writes a sentinel-delimited root-level managed block containing a single
`/specs/` line, gated on `git ls-files -- specs/` being empty, so a repository that already
tracks its task history is never touched at the root by any init, deploy, redeploy, or loader
run. It also makes `check-runtime-file-tracking.sh`'s Check C posture-aware (it currently asserts
unconditionally that durable provenance is never ignored, which the new default contradicts by
design), documents the posture split and a manual opt-in runbook in
`orchestrator-runtime-files.md`, and closes with a negative control asserted against the git
index rather than inferred from any script's exit code.

### Research Integration

The research report's design is adopted essentially unchanged:

- Detection is `git ls-files -- specs/` being empty, **not** `specs_tree_is_gitignored()` — the
  predicate answers "does a rule already exist," not "has anything ever been committed."
- The new write is a repo-root `.gitignore` managed block with a **distinct** sentinel pair
  (`specs-tree-ignore`), never confused with the existing `runtime-file-patterns.sh` sentinels or
  with the optional hand-added root-level ephemeral block the standards file already documents.
- Step 5 (`specs/.gitignore`'s ephemeral block) stays unconditional in both postures.
- No automatic bulk-untrack flow is built; the opt-in path for an already-tracked consumer is a
  documented manual runbook plus a one-line discoverability hint from `init-specs.sh`.

One recommendation is resolved in the direction the report flagged as preferred but left open:
**Recommendation 6 is folded in, not deferred.** `check-runtime-file-tracking.sh` and the two
affected test files are added to this plan's scope. Plan authoring found the collision is not
hypothetical — `tests/test-init-specs.sh` Case 6 bootstraps a fresh fixture with no root
`.gitignore`, commits `specs/`, and asserts `check-runtime-file-tracking.sh` exits 0, which
breaks the moment the fresh-repo path writes a root `/specs/` line. Leaving Check C unaddressed
would ship a known-red suite, so the posture-awareness work and its tests are phases here rather
than a follow-on.

The report's first risk (that this change could expose an `orchestrate-cycle-postflight.sh`
demotion hazard) was already assessed as closed by task 658's completed exit-8/9 arm; this plan
does not re-open it, and the report's own re-confirmation suggestion is satisfied by Phase 6's
positive control exercising a full lifecycle on top of an ignored tree.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No `roadmap_path` was provided in this dispatch's delegation context; no roadmap consultation was
performed and no roadmap phases are included.

### Carried-Figure Re-Validation

The dispatch's Premise Re-Validation section extracted three description lines. Each was checked
against live state at plan-authoring time:

1. **"SOURCE STORE IS THE EDIT TARGET: agent-system/extensions/core/\*\*"** — CONFIRMED live.
   `.claude-extensions.json` resolves `extensions.core.source_dir` to
   `/home/benjamin/.config/nvim/agent-system/extensions/core`. Every edit path in this plan is
   under that tree; no `.claude/**` path is a write target.
2. **"11,572 tracked files"** (the reference repository's tracked specs tree) — RE-DERIVED and
   DIFFERENT. `git ls-files -- specs/ | wc -l` returns **11,614** at plan-authoring time; the
   research report recorded 11,606. The figure drifts upward with every artifact commit, so the
   exact number carries no load: what is load-bearing is the qualitative claim (a large, tracked
   task history that no code path may untrack), and that is unchanged. `git check-ignore -q --
   specs` exits **1** in this repository, confirming the tracked-posture reference case. No
   assertion in this plan hard-codes a count; Phase 6's negative control compares a
   before-count to an after-count instead.
3. **"Task 338 ... edits both init-specs.sh and runtime-file-patterns.sh"** — CONFIRMED still
   live. Task 338 ("Classify every task-support file as tracked or ignored") is `[NOT STARTED]`
   in `specs/state.json`, so the never-co-admit ruling and the re-read-the-other's-result
   obligation both still apply. Phase 6 re-checks 338's state before committing.

## Goals & Non-Goals

**Goals**:

- A repository with nothing tracked under `specs/` gets its whole `specs/` tree ignored on its
  first `init-specs.sh` run, via a managed block in its own repo-root `.gitignore`.
- A repository that already tracks `specs/` keeps tracking it — no init, deploy, redeploy, or
  loader run writes anything to its repo root or untracks anything, proven against the index.
- `check-runtime-file-tracking.sh` passes in both postures, with Check C skipped (named, not
  silent) under the whole-tree-ignored posture.
- `orchestrator-runtime-files.md` states the posture for both cases, the inner-block
  disposition, and a manual opt-in runbook for an already-tracked consumer.
- Both postures are covered by tests that assert against git state, not exit codes alone.

**Non-Goals**:

- No automatic or flag-driven bulk-untrack flow for an already-tracked consumer. The opt-in is a
  documented manual procedure only.
- No change to `runtime_ignore_block()` or `runtime_specs_ignore_block()` output, and no change
  to the 27-member ephemeral-class enumeration itself (that enumeration is task 338's subject).
- No change to `specs-ignore-lib.sh`, `git-commit-scoped.sh`'s V13 gate, or
  `orchestrate-cycle-postflight.sh` — task 658's machinery is consumed as-is.
- No retroactive history backfill, and no migration of any existing consumer repository.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| A code path untracks an existing consumer's task history | H | L | Detection gate is `git ls-files -- specs/` non-empty => touch nothing at the root; Phase 6's negative control asserts the tracked count, the check-ignore rc, and the root `.gitignore` hash are all unchanged after a re-init |
| Check C starts failing on every freshly bootstrapped repo | H | H (certain without Phase 3) | Phase 3 makes Check C posture-aware; Phase 4 pins both postures |
| `tests/test-init-specs.sh` Case 6 goes red | M | H (certain without Phase 4) | Phase 4 reconciles Case 6 to the posture-aware expectation without dropping the `specs/.gitignore`-only coverage assertion it exists to protect |
| Task 338 lands first and moves the enumeration this plan's scaffolding renders | M | M | Never co-admit 338 and this task into one batch (user ruling); Phase 6 re-reads 338's state and both shared files before committing |
| `init-specs.sh` run from a non-root CWD writes the root block in the wrong place | M | L | The new write resolves its target via `git rev-parse --show-toplevel`, unlike the `specs/`-relative writes around it |
| A consumer's root `.gitignore` already matches `specs` by some unrelated wildcard | L | L | The new step checks for its own sentinel before writing, so a second run never double-appends; a pre-existing broader match is harmless in the fail-open direction |
| Doc-sync pin drift between the standards file's fenced blocks and the lib | M | L | Phase 1 leaves `runtime_ignore_block()` untouched (Case 3's pin holds); Phase 5 adds a parallel pin for the new fenced block in the same phase that adds it |

## Implementation Phases

**Dependency Analysis**:

| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |
| 3 | 3 | 2 |
| 4 | 4 | 3 |
| 5 | 5 | 4 |
| 6 | 6 | 5 |

Phases within the same wave can execute in parallel. This plan is deliberately linear: phases 4
and 5 both edit `tests/test-runtime-file-tracking.sh`, so they are serialized rather than placed
in one wave, and every later phase depends on the behavior the earlier one introduces.

---

### Phase 1: Add the whole-tree ignore block renderer [COMPLETED]

**Goal**: Give the new root-level managed block one canonical definition, alongside the two
existing block renderers, so no consumer of it hand-writes the pattern.

**Tasks**:
- [x] Re-read `agent-system/extensions/core/scripts/lib/runtime-file-patterns.sh` immediately
      before editing — task 338 shares this file and a concurrent sibling may have changed it. *(completed)*
- [x] Add `specs_tree_ignore_block()` after `runtime_specs_ignore_block()`, emitting the managed
      block's body: an explanatory comment preamble plus exactly one pattern line, `/specs/`. *(completed)*
- [x] Write the preamble to state (a) why the rule must sit at the repo root — only a
      `.gitignore` at or above the root makes `git check-ignore -q -- specs` succeed, which is
      what `specs-ignore-lib.sh`'s `specs_tree_is_gitignored()` consults; (b) that it is written
      only for a repository with nothing tracked under `specs/`; (c) a pointer to
      `context/standards/orchestrator-runtime-files.md` for the posture split and the manual
      opt-in runbook. *(completed)*
- [x] Leave `runtime_ignore_block()` and `runtime_specs_ignore_block()` output byte-identical —
      `tests/test-runtime-file-tracking.sh` Case 3 pins the former to the standards file's
      fenced block. *(completed)*
- [x] Export the new function exactly as the two existing renderers are exported. *(completed)*

**Timing**: 0.5 hours

**Depends on**: none

**Verification Tier**: local

**Tier Justification**: `bash agent-system/extensions/core/scripts/verify-touched.sh agent-system/extensions/core/scripts/lib/runtime-file-patterns.sh` covers this single-file addition, which changes no existing renderer's output and no caller's behavior.

**Files to modify**:
- `agent-system/extensions/core/scripts/lib/runtime-file-patterns.sh` - add the new
  whole-tree ignore block renderer; no change to existing renderers or to the class enumeration

**Verification**:
- `bash -n` on the lib parses clean; sourcing it and calling `specs_tree_ignore_block` emits
  exactly one non-comment, non-blank line, and that line is `/specs/`.
- `runtime_ignore_block()`'s output still matches the standards file's existing fenced block
  byte-for-byte (the same extraction Case 3 performs).
- The `verify-touched.sh` invocation above runs green.

---

### Phase 2: Fresh-repo detection and root `.gitignore` managed write [COMPLETED]

**Goal**: `init-specs.sh` writes the root-level whole-tree ignore block when, and only when,
nothing is tracked under `specs/`; an already-tracked consumer's repo root is never written to.

**Tasks**:
- [x] Re-read `agent-system/extensions/core/scripts/init-specs.sh` immediately before editing
      (shared with task 338). *(completed)*
- [x] Add sentinel constants for the new block — `# BEGIN managed block: specs-tree-ignore` /
      `# END managed block: specs-tree-ignore` — kept textually distinct from the existing
      `runtime-file-patterns.sh` sentinel pair. *(completed)*
- [x] Insert a new Step 5b after Step 5: when not inside a git work tree, print a named SKIP and
      do nothing (mirroring Step 6's existing `git rev-parse --is-inside-work-tree` guard). *(completed)*
- [x] When inside a work tree, capture `git ls-files -- specs/`. Non-empty => print one
      non-actionable line pointing at `orchestrator-runtime-files.md`'s opt-in runbook section
      and touch nothing at the repo root. Empty => ensure the repo-root `.gitignore` carries the
      sentinel-delimited block rendered by `specs_tree_ignore_block()`. *(completed)*
- [x] Reuse Step 5's three-branch idiom verbatim in shape (create when the file is absent;
      replace only the region between sentinels when both are present; append preserving all
      existing content when neither is) and the existing `atomic_write` helper. *(completed)*
- [x] Resolve the write target for this new step via `git rev-parse --show-toplevel`, so a
      non-root CWD cannot strand a root-level file; fall back to the relative `.gitignore` path
      if resolution fails, and say so in a named notice. *(completed)*
- [x] Leave Step 5 unconditional and Step 6 untouched in both postures. *(completed)*
- [x] Update the script's header comment block: the numbered step list, the non-destructive
      paragraph, and Step 5's description — whose current sentence declares writing the
      consumer's repo-root `.gitignore` out of scope, which this step changes. State the two
      postures explicitly in the header. *(completed)*

**Timing**: 1.25 hours

**Depends on**: 1

**Verification Tier**: local

**Tier Justification**: `bash agent-system/extensions/core/scripts/verify-touched.sh agent-system/extensions/core/scripts/init-specs.sh` — the selector maps this path to `test-init-specs.sh`, the suite that owns this script's behavior end-to-end.

**Scope Hypothesis**: this task's description carries "11,572 tracked files" for the reference
repository; re-derived at plan-authoring time `git ls-files -- specs/ | wc -l` is 11,614 (the
research report recorded 11,606), so the count drifts with every artifact commit and must not be
hard-coded into any assertion or message. Confirm at implementation time by capturing the count
immediately before and after a re-init and comparing those two numbers to each other, never to a
literal.

**Files to modify**:
- `agent-system/extensions/core/scripts/init-specs.sh` - new Step 5b (fresh-repo detection plus
  root-level managed block write), new sentinel constants, header-comment update

**Verification**:
- Scratch repo, nothing tracked under `specs/`: after one run, the repo-root `.gitignore` exists
  and carries both sentinels with `/specs/` between them, and `git check-ignore -q -- specs`
  exits 0.
- A second run in the same scratch repo changes no bytes of that file (no double-append, no
  duplicate sentinels).
- This repository (tracked posture): after a run, the root `.gitignore` is byte-identical to its
  pre-run state and contains no `specs-tree-ignore` sentinel; `git check-ignore -q -- specs`
  still exits 1.
- The `verify-touched.sh` invocation above runs green.

---

### Phase 3: Make Check C posture-aware [COMPLETED]

**Goal**: `check-runtime-file-tracking.sh` passes on a freshly bootstrapped repository whose
whole `specs/` tree is ignored by design, without weakening the check for a tracked repository.

**Tasks**:
- [x] Source `lib/specs-ignore-lib.sh` using the same deploy-tree-first / source-store-fallback
      idiom the script already uses for `lib/runtime-file-patterns.sh`
      (`${SCRIPT_DIR}/lib/specs-ignore-lib.sh`), failing loudly with a named error if absent, in
      the same style as the existing library guard. *(completed)*
- [x] Gate Check C on `specs_tree_is_gitignored "$(git rev-parse --show-toplevel)"`: when it
      returns 0, print a named SKIP stating that the whole-tree-ignored posture makes the
      "provenance is not ignored" assertion inapplicable, and do not set `FAILURES`; when it
      returns non-zero, run today's assertion unchanged, including the `git check-ignore -v`
      offending-line output and the never-run-`git rm --cached` remediation note. *(completed)*
- [x] Leave Checks A and B unconditional — `specs/.gitignore` is still written in both postures,
      and no ephemeral file becomes tracked under either. *(completed)*
- [x] Update the summary output so a skipped Check C is not reported as "all three checks
      passed". *(completed)*
- [x] Update the script's header contract: Check C's description and the stated exit-code
      contract must name both postures. *(completed)*

**Timing**: 0.75 hours

**Depends on**: 2

**Verification Tier**: local

**Tier Justification**: `bash agent-system/extensions/core/scripts/verify-touched.sh agent-system/extensions/core/scripts/check-runtime-file-tracking.sh` — the selector maps this path to test-deploy-orphans.sh, test-deploy-propagation.sh, test-init-specs.sh and test-runtime-file-tracking.sh, which together own every consumer of this script.

**Scope Hypothesis**: Check C is hypothesized to be the only unconditional assertion in this
script that the new posture contradicts — Checks A and B are expected to stay valid because
`specs/.gitignore` is still written and no ephemeral file becomes tracked. Confirm at
implementation time by running the script in a scratch repo bootstrapped under the new default
and reading all three per-check verdicts, not the exit code alone.

**Files to modify**:
- `agent-system/extensions/core/scripts/check-runtime-file-tracking.sh` - posture-aware Check C,
  new library source, summary-line and header updates

**Verification**:
- Scratch repo bootstrapped under the new default: exit 0, with an explicit, named Check C SKIP
  line in the output and Checks A and B both reported as passed.
- This repository (tracked posture): Check C still runs and passes; no SKIP line appears.
- A fixture whose `specs/` tree is NOT whole-tree ignored but whose `.gitignore` over-ignores
  `.orchestrator-handoff.json`: Check C still FAILs with the offending line named (the existing
  Case 4 behavior is preserved, not bypassed by the new gate).
- The `verify-touched.sh` invocation above runs green.

---

### Phase 4: Test coverage for both postures [COMPLETED]

**Goal**: Both postures — fresh/ignored and existing/tracked — are pinned by tests that assert
against git state, and the one pre-existing case that collides with the new default is
reconciled rather than deleted.

**Tasks**:
- [x] Run `tests/test-init-specs.sh` and `tests/test-runtime-file-tracking.sh` first and record
      the per-case verdicts as the pre-change baseline. *(completed: 23 passed/0 failed and 9
      passed/0 failed respectively, captured before any Phase 4 edit)*
- [x] `tests/test-init-specs.sh`: add a case asserting a fresh bootstrap writes the root managed
      block (both sentinels, `/specs/` between them) and that `git check-ignore -q -- specs`
      exits 0 afterward. *(completed: Case 9)*
- [x] Add an idempotence case: a second run leaves that root `.gitignore` byte-identical.
      *(completed: Case 10)*
- [x] Add the negative control: a fixture that commits a file under `specs/` before running
      `init-specs.sh` must come out with no `specs-tree-ignore` sentinel anywhere in its root
      `.gitignore` and with `git ls-files -- specs/` returning the same set as before the run —
      asserted against the index, not the script's exit code. *(completed: Case 11; manually
      confirmed non-tautological by temporarily inverting the gate in a scratch copy and
      observing the sentinel leak, then restoring the real script unedited)*
- [x] Reconcile Case 6: it bootstraps a fresh fixture with no root `.gitignore`, commits
      `specs/`, and asserts `check-runtime-file-tracking.sh` exits 0. Under the new default
      `git add specs/` stages nothing and Check C would fire. Re-point it at the posture-aware
      expectation (exit 0 with Check C SKIPped), or split it into one case per posture — but do
      not drop the `specs/.gitignore`-only ephemeral-coverage assertion it exists to protect.
      *(completed: Case 6 now seeds a tracked specs/ file BEFORE the first init-specs.sh call so
      the fixture starts in the tracked posture it always existed to pin — exit 0, Check C not
      skipped, specs/.gitignore-only coverage preserved; the complementary "exit 0 with Check C
      SKIPped" scenario is covered by test-runtime-file-tracking.sh's new Case 6 below)*
- [x] `tests/test-runtime-file-tracking.sh`: add a case covering the posture-aware Check C skip
      (fresh/ignored fixture => exit 0 with the SKIP line present), and confirm Case 4
      (over-ignored provenance in a tracked-specs fixture still FAILs) and Case 7's
      force-tracked-ephemeral pin both still pass unchanged. *(completed: new Case 6; Case 4 of
      this suite and Case 7 of test-init-specs.sh both reconfirmed passing unchanged)*
- [x] Re-run both suites and compare per-case verdicts against the recorded baseline.
      *(completed: against the edited source-store scripts directly (TREE_ROOTS temporarily
      reordered in a disposable copy, since the deployed tree still resolves first and is stale
      until Phase 6) -- 30 passed/0 failed and 13 passed/0 failed; every pre-existing case name
      still passes except Case 6's intended reconciliation, plus the new cases)*

**Timing**: 1.25 hours

**Depends on**: 3

**Verification Tier**: local

**Tier Justification**: `bash agent-system/extensions/core/scripts/verify-touched.sh agent-system/extensions/core/scripts/tests/test-init-specs.sh agent-system/extensions/core/scripts/tests/test-runtime-file-tracking.sh` — the selector maps this pair to test-deploy-orphans.sh, test-deploy-propagation.sh, test-init-specs.sh and test-runtime-file-tracking.sh, which is exactly the set these two suites' behavior can break.

**Scope Hypothesis**: exactly one pre-existing case (`tests/test-init-specs.sh` Case 6) is
hypothesized to collide with the new default, and Case 7's force-tracked-ephemeral pin is
hypothesized to survive unchanged. Confirm by running both suites before any edit and again
after, comparing per-case verdicts rather than the suite exit codes alone — a second colliding
case would show up as a baseline-to-after verdict change on a case this plan does not name.

**Files to modify**:
- `agent-system/extensions/core/scripts/tests/test-init-specs.sh` - new fresh-posture,
  idempotence and tracked-posture negative-control cases; Case 6 reconciled
- `agent-system/extensions/core/scripts/tests/test-runtime-file-tracking.sh` - new posture-aware
  Check C case

**Verification**:
- Both suites exit 0, with every new case reported as passed by name.
- The tracked-posture negative-control case fails if the root-write gate is removed (verify by
  temporarily inverting the gate locally, then restoring — the case must go red, proving it is a
  real control and not a tautology).
- No pre-existing case's verdict changed from the recorded baseline except Case 6, whose change
  is the intended reconciliation.
- The `verify-touched.sh` invocation above runs green.

---

### Phase 5: Document the posture split and the opt-in runbook [COMPLETED]

**Goal**: `orchestrator-runtime-files.md` states the posture for a fresh repository and for an
already-tracked one, the inner-block disposition, the manual opt-in procedure, and what
verification means in each posture.

**Tasks**:
- [x] Add a subsection beside "Consumer Repo Setup" stating the new default: a repository with
      nothing tracked under `specs/` gets its whole `specs/` tree ignored via a managed block in
      its own repo-root `.gitignore`, and why the repo root is the only placement that can
      achieve it. *(completed: new "## Fresh-Repo Default: Whole specs/ Tree Ignored" section)*
- [x] State the hard guarantee for the other posture: a repository that already tracks `specs/`
      is never written to at the root and never untracked, by any init, deploy, redeploy, or
      loader run. *(completed)*
- [x] State the inner-block disposition: `specs/.gitignore`'s ephemeral-class managed block is
      still written unconditionally; it is functionally inert while the root-level `/specs/` line
      stands, and regains effect the moment a consumer removes that line to track `specs/` again.
      *(completed)*
- [x] Add the manual opt-in runbook for an already-tracked consumer that wants to switch posture
      — `git rm -r --cached specs/`, a scoped commit, add the root-level `/specs/` line, re-run
      `init-specs.sh` — stated explicitly as a manual procedure with no automated equivalent, and
      cross-referenced from "Untracking Already-Committed Ephemeral Files". *(completed)*
- [x] Add a fenced block showing the new root-level managed block, and pin it to
      `specs_tree_ignore_block()` with a new case in
      `tests/test-runtime-file-tracking.sh`, mirroring Case 3's extraction idiom. *(completed:
      fenced as `gitignore-specs-tree-ignore`, a distinct tag from Case 3's plain `gitignore`
      fence so the two extractions never collide; new Case 7 pins it)*
- [x] Extend the "Verification" section: Check C is posture-aware (state what it means in each
      posture), and cross-reference `context/standards/git-staging-scope.md`'s "Per-Operation
      Contract: Tracked vs. Gitignored `specs`". *(completed)*
- [x] Leave the existing Case-3-pinned fenced block byte-identical — it is generated from
      `runtime_ignore_block()` and is not this task's subject. *(completed: confirmed via Case 7's
      own regression check that Case 3's extraction/verdict is unaffected)*

**Timing**: 1 hour

**Depends on**: 4

**Verification Tier**: local

**Tier Justification**: `bash agent-system/extensions/core/scripts/verify-touched.sh agent-system/extensions/core/context/standards/orchestrator-runtime-files.md agent-system/extensions/core/scripts/tests/test-runtime-file-tracking.sh` (the selector maps this pair to test-audit-task-proposals.sh, test-deploy-orphans.sh, test-deploy-propagation.sh, test-handoff-dispatch-identity.sh, test-init-specs.sh, test-runtime-file-tracking.sh and test-session-runtime-files.sh), plus `bash .claude/scripts/verify-deploy.sh --skip-slow --only-gate 3,4 /home/benjamin/.config/nvim` for the source-store markdown lints that no suite covers.

**Scope Hypothesis**: the new doc-sync pin is hypothesized to be addable without touching the
existing Case 3 extraction logic, because the two fenced blocks are delimited independently.
Confirm at implementation time by running `tests/test-runtime-file-tracking.sh` and checking that
Case 3's verdict is unchanged alongside the new case's pass.

**Files to modify**:
- `agent-system/extensions/core/context/standards/orchestrator-runtime-files.md` - posture-split
  subsection, inner-block disposition, manual opt-in runbook, new fenced block, Verification
  section update
- `agent-system/extensions/core/scripts/tests/test-runtime-file-tracking.sh` - new doc-sync pin
  case for the fenced block added above (declared here, in the same phase that adds the derived
  block, because this pin is a commit-blocking Gate 8 suite check)

**Verification**:
- The new doc-sync pin case passes: the standards file's new fenced block is byte-identical to
  `specs_tree_ignore_block()`'s output.
- Case 3's verdict is unchanged (the pre-existing fenced block was not edited).
- `tests/test-runtime-file-tracking.sh` exits 0 overall.
- Both commands named in the Tier Justification run green; gate 3 and gate 4 must each report a
  real result, not SKIP (the `TARGET` is this repository's own root, which holds both a deployed
  `.claude/` tree and the `agent-system/extensions` source store).

---

### Phase 6: Redeploy, negative control against the index, and close [COMPLETED]

**Goal**: The change is live in the deployed tree, the fresh-repo default demonstrably works end
to end, and the reference repository's tracked task history is demonstrably untouched — asserted
against the git index, not inferred from any script's exit code.

**Tasks**:
- [x] Before anything else in this phase, capture three baselines in this repository:
      `git ls-files -- specs/ | wc -l`, the rc of `git check-ignore -q -- specs`, and
      `sha256sum .gitignore`. *(completed: 11643 files, rc=1, sha256=da06cbb...)*
- [x] Re-read task 338's current state in `specs/state.json`. If it has landed edits to
      `init-specs.sh` or `runtime-file-patterns.sh` since this plan was written, re-read both
      files in full and reconcile against its result rather than assuming this plan's
      enumeration. *(completed: still `not_started`, last_updated 2026-10-04 -- unchanged since
      plan authoring; no reconciliation needed)*
- [x] Run `bash .claude/scripts/deploy-headless.sh` to regenerate the deployed `.claude/` tree
      from the source store. *(completed: two self-inflicted lint collisions surfaced by the
      post-deploy fast-gate battery from Phase 5's new runbook prose -- lint 17 bare
      `git commit -m` text and lint 23 a bare `specs/` directory pathspec to
      `git-commit-scoped.sh` -- both fixed by rewording the manual opt-in runbook to avoid the
      flagged literal shapes, re-synced index-entries.json's line_count each time, then
      redeployed again clean of both)*
- [x] Negative control (blocking, all four assertions): re-run `bash .claude/scripts/init-specs.sh`
      from this repository's root, then assert (a) `git ls-files -- specs/ | wc -l` equals the
      captured before-count; (b) `git check-ignore -q -- specs` still exits 1; (c) `.gitignore`'s
      sha256 is unchanged and the file contains no `specs-tree-ignore` sentinel; (d)
      `git diff --cached --name-only -- specs/` shows no staged deletions. Any failure here is
      blocking — it is the defect this task's description names as worse than the one being
      fixed, not a note. *(completed: all four PASS -- count 11643/11643, rc 1/1, sha identical,
      no staged diff under specs/)*
- [x] Positive control: in a throwaway scratch repository outside this tree, stand up the
      deployed scripts, run `init-specs.sh`, and assert the whole `specs/` tree is ignored
      (`git check-ignore -q -- specs` exits 0); then exercise a working lifecycle on top of it —
      a `specs/state.json` write, `generate-todo.sh`, and `check-runtime-file-tracking.sh`
      exiting 0 with Check C SKIPped. *(completed: all PASS, using the real DEPLOYED scripts)*
- [x] Run the scoped touched-path check over this task's own touched paths and record, in the
      phase's verification notes, that the complete gate set is deferred to the orchestration
      close rather than independently run in this dispatch. *(completed: the plan's own named
      invocation -- `verify-touched.sh` with the six explicit touched paths -- resolves to a
      15-suite battery, 14 passed, 1 EXPECTED/0-NEW failure in `test-verify-deploy-context-budget.sh`
      caused entirely by a pre-existing, unrelated defect in `scripts/tests/run-all.sh` (gate 27,
      subject-resolution declaration lint) that predates this dispatch -- confirmed present
      already in Phase 1's very first verify-touched.sh run, before any of this task's phases
      landed, and confirmed by run-all.sh's own EXPECTED/0-NEW classification. Logged via
      issue-record.sh rather than fixed, since the file is outside this task's file_scope and
      the fix belongs to a separate task. The complete gate set is otherwise deferred to the
      once-per-invocation batch-gate stage, not independently run here)*

**Timing**: 1 hour

**Depends on**: 5

**Verification Tier**: full

**Files to modify**:
- `__WHOLE_TREE__` - `deploy-headless.sh` regenerates the entire deployed tree from the source
  store in this phase
- No source-store file is edited in this phase except any reconciliation the negative or positive
  control forces, or any realignment task 338's landed result requires

**Verification**:
- All four negative-control assertions pass, each read from git itself (`git ls-files`,
  `git check-ignore`, `sha256sum`, `git diff --cached`), never inferred from `init-specs.sh`'s
  exit code.
- The positive control's full lifecycle runs green on top of an ignored tree.
- In-dispatch obligation under `/orchestrate`: `bash .claude/scripts/verify-touched.sh
  agent-system/extensions/core/scripts/lib/runtime-file-patterns.sh
  agent-system/extensions/core/scripts/init-specs.sh
  agent-system/extensions/core/scripts/check-runtime-file-tracking.sh
  agent-system/extensions/core/scripts/tests/test-init-specs.sh
  agent-system/extensions/core/scripts/tests/test-runtime-file-tracking.sh
  agent-system/extensions/core/context/standards/orchestrator-runtime-files.md` runs green, and
  the complete gate set is explicitly DEFERRED to the orchestration close (the
  once-per-invocation batch gate stage), not independently invoked here. In a standalone,
  non-orchestrated run with no orchestration close to defer to, run
  `bash .claude/scripts/verify-deploy.sh` directly instead.

---

## Testing & Validation

- [ ] `tests/test-init-specs.sh` exits 0, including the new fresh-posture, idempotence, and
      tracked-posture negative-control cases.
- [ ] `tests/test-runtime-file-tracking.sh` exits 0, including the posture-aware Check C case and
      the new doc-sync pin, with Case 3, Case 4 and Case 7 unchanged.
- [ ] A fresh repository's whole `specs/` tree is ignored after one `init-specs.sh` run
      (`git check-ignore -q -- specs` exits 0) and a full task lifecycle functions on top of it.
- [ ] This repository's tracked `specs/` tree is unchanged after a redeploy plus re-init: same
      tracked-file count, same `check-ignore` rc of 1, byte-identical root `.gitignore`, no
      staged deletions.
- [ ] `check-runtime-file-tracking.sh` exits 0 in both postures, with the skip named rather than
      silent in the ignored posture.
- [ ] Gate 3 (doc-lint) and gate 4 (task-reference lint) both report real results, not SKIP, for
      the source-store markdown edit.
- [ ] No task-number reference and no record-versioning language appears anywhere under
      `agent-system/**` (both are permitted in this task's description and in `specs/**` only).

## Artifacts & Outputs

- `agent-system/extensions/core/scripts/lib/runtime-file-patterns.sh` — new
  `specs_tree_ignore_block()` renderer
- `agent-system/extensions/core/scripts/init-specs.sh` — new Step 5b, fresh-repo detection and
  root-level managed-block write
- `agent-system/extensions/core/scripts/check-runtime-file-tracking.sh` — posture-aware Check C
- `agent-system/extensions/core/scripts/tests/test-init-specs.sh` — both postures pinned
- `agent-system/extensions/core/scripts/tests/test-runtime-file-tracking.sh` — posture-aware
  Check C case and the new doc-sync pin
- `agent-system/extensions/core/context/standards/orchestrator-runtime-files.md` — posture split,
  inner-block disposition, manual opt-in runbook, Verification update
- A regenerated deployed `.claude/` tree (via `deploy-headless.sh`)
- `specs/660_init_specs_ignores_specs_by_default/summaries/01_init-specs-ignores-by-default-summary.md`

## Rollback/Contingency

Every edit is confined to six source-store files and is additive in shape: `git checkout` of
those six paths plus a `deploy-headless.sh` rerun restores the prior behavior completely, since
the deployed tree is a disposable artifact regenerated from the source store. No migration, no
history rewrite, and no index mutation is performed in any consumer repository, so there is
nothing to un-migrate.

If Phase 6's negative control fails on any of its four assertions, stop: do not commit, do not
deploy further, and treat it as blocking. Restore the six source files, rerun the deploy to
re-establish the prior deployed tree, and re-check the four assertions before any further work —
an untracked task history is the one outcome this task's own description rules out.

If task 338 lands between phases and moves the ephemeral-class enumeration, do not reconcile by
guessing: re-read its result and both shared files, and if the enumeration this plan's
scaffolding renders has genuinely changed, close the implementation as `[PARTIAL]` with the
conflict recorded rather than committing a reconciliation that was never verified against 338's
landed state.
