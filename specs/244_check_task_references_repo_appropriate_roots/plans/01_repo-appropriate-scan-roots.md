# Implementation Plan: Task #244

- **Task**: 244 - check-task-references.sh: scan repo-appropriate roots instead of a hard-coded nvim-repo TREE_ROOTS list
- **Status**: [IMPLEMENTING]
- **Effort**: 6 hours
- **Dependencies**: None
- **Research Inputs**: specs/244_check_task_references_repo_appropriate_roots/reports/01_repo_appropriate_scan_roots.md
- **Artifacts**: plans/01_repo-appropriate-scan-roots.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Two independent defects land in one task. (1) `check-task-references.sh` enumerates only a
hard-coded `TREE_ROOTS=(agent-system/extensions .opencode lua .memory)` — this repo's own layout
— so in a consumer repo (Verification's `docs/`/`README.md`/`framed_channel/`, ModelChecker's
`code/`) the lint scans nothing the repo actually ships, while
`rules/no-task-references-in-deliverables.md` claims repo-wide reach. Fix: enumerate the whole
repo via one `git ls-files` walk filtered through the existing shared `is_exempt_path`
(`specs/**` only), and drop the `PATH_SCOPE`-must-be-under-TREE_ROOTS check that makes an
out-of-tree scope exit 2. (2) `validate-wiring.sh`'s `all` arm validates both `.claude` and
`.opencode` with no existence check, turning a normal consumer configuration (no OpenCode deploy)
into hard `[FAIL]` rows that mask the real `.claude`-side result. Fix: per-tree existence guard
emitting a `[SKIP]` line. Done when both scripts are fixed, two new fixture-driven test suites
pass, the enforcement narrative no longer asserts the four-root model, and the full gate set is
green with a measured 0/0 scan equivalence for this repo.

### Research Integration

Every implementation decision below is taken from `reports/01_repo_appropriate_scan_roots.md`:

- **Option (a), coverage, chosen over option (b), carve-out** (dispatch requirement 7). Research
  measured the repo-wide walk at **0 findings**, byte-identical to today's four-tree scan (also
  0), so closing the gap costs nothing here; a documented carve-out would instead require
  narrowing the rule's "entire repository EXCEPT `specs/**`" principle into something
  repo-specific and permanent.
- **No per-repo config file, no nvim-layout detection.** `git ls-files` already respects
  `.gitignore` (so `.claude/`, build output, and vendored trees are excluded by construction),
  which is why it produces the measured equivalence directly.
- **`scripts/lib/task-reference-patterns.sh` needs no change** (requirement 4): `is_exempt_path`
  already is the sole correct scope predicate; only the *enumeration* is wrong.
- **`hooks/validate-no-task-references.sh` needs no code change** (requirement 8): it keys on the
  path of the current write, filtered only through `is_exempt_path`, and was never tree-scoped.
  The drift ran in the *opposite* direction from what the corroboration implied — the batch lint
  was narrower than the hook. After this fix both consumers share exactly one predicate. The file
  stays in scope for verified parity plus a test asserting agreement, not for editing.
- **Preserve the per-finding line format verbatim**: `verify-deploy.sh` gate 4 (line ~417) greps
  `^  [^:]+:[0-9]+:` out of non-quiet output to build its `FINDING gate4` list. Re-confirmed
  during planning: gate 4 depends *only* on that shape plus the exit code — the per-tree summary
  line text (`"  $key: $n occurrence(s)"`) is free to change.
- **`validate-wiring.sh` fix mirrors an existing precedent**: `scan_tree`'s
  `"[SKIP] $label does not exist under $REPO_ROOT"` guard is the wording model.
- **`deploy-root-guard.sh`, `validate-state.sh`, `hooks/validate-handoff-location.sh` are SAFE**
  and out of scope — but Phase 4 re-verifies rather than trusting the note, as the dispatch
  directs.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No `roadmap_path` was provided in this dispatch; ROADMAP.md was not consulted.

## Goals & Non-Goals

**Goals**:
- `check-task-references.sh`'s default scan covers the whole git-tracked repo minus `specs/**`,
  in any repo, with no hard-coded layout knowledge (requirements 1, 2).
- An explicit `PATH_SCOPE` anywhere in the repo is scanned, never rejected with exit 2
  (requirement 3).
- Exemption and pattern logic stays sourced exclusively from
  `scripts/lib/task-reference-patterns.sh`, unmodified (requirement 4).
- `context/standards/task-reference-exemptions.md`'s Enforcement narrative stops asserting the
  four-deliverable-tree model (requirement 5).
- Two new fixture-driven suites: a consumer-repo-shaped fixture for the lint, including a
  lint/hook scope-agreement assertion (requirements 6, 8); and a `.claude`-present/
  `.opencode`-absent fixture for `validate-wiring.sh` (absorbed task's requirement 3).
- `validate-wiring.sh` skips a non-existent tree root for both arms, so exit status reflects only
  trees actually present.

**Non-Goals**:
- Option (b): declaring consumer source trees out of scope in the rule text. Explicitly rejected
  on measured evidence; the rule's existing repo-wide claim stands and is now backed.
- Any change to `scripts/lib/task-reference-patterns.sh`'s patterns or exemption semantics.
- Any change to `hooks/validate-no-task-references.sh`'s logic.
- Removing any `.opencode` reference, editing the frozen-mirror policy, or narrowing
  `deploy-root-guard.sh`/`validate-state.sh`'s deliberately general two-system guards.
- Detecting or reporting an *accidentally deleted* `.opencode` tree as distinct from a
  never-deployed one (explicitly out of scope per the absorbed task's note).
- Adding new exemption categories or a new exemption mechanism for vendored directories;
  `is_exempt_path` remains the single documented extension point.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Widening scope surfaces latent violations in newly-included trees (`docs/`, `README.md`, `init.lua`, `scripts/`, `after/`), breaking requirement 1 | M | L | Measured 0/0 already; Phase 1 re-measures immediately before the change and Phase 6 re-measures after, so any drift from concurrent sibling tasks is caught rather than blamed on this change |
| Reporting-shape change breaks `verify-deploy.sh` gate 4's `FINDING gate4` parsing | H | L | Per-finding `"  $rel:$finding"` line is preserved verbatim; Phase 6 runs the real gate 4 against the deployed copy and `test-verify-deploy-gate-selection.sh` |
| Concurrent sibling tasks edit shared files in this same orchestrate cycle | M | M | Declared `file_scope` is disjoint from every listed sibling's; still re-read each file immediately before editing, stage only this task's own hunks with an explicit file list (never a directory/glob `git add`) |
| Gate 4 exercises the **deployed** `.claude/scripts/` copy, so an un-redeployed fix looks unchanged | M | M | Phase 6 runs `deploy-headless.sh` before `verify-deploy.sh`; all source edits land in `agent-system/extensions/core/**` per `source-store-deploy-boundary.md` |
| `validate-wiring.sh` fixture cannot run from a scratch dir because `deploy-root-guard.sh` requires the script to sit under a literal `.claude/scripts/` or `.opencode/scripts/` | M | M | Fixture places the script copy at `<fixture>/.claude/scripts/validate-wiring.sh`, mirroring `test-deploy-verify-wiring.sh`'s established layout |
| A future repo commits a large vendored/generated tree, producing repo-wide scan noise | L | L | `git ls-files` excludes gitignored paths; `is_exempt_path` is the documented single extension point if a committed exception ever appears |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1, 4 | -- |
| 2 | 2, 5 | 1 (for 2), 4 (for 5) |
| 3 | 3 | 2 |
| 4 | 6 | 2, 3, 4, 5 |

Phases within the same wave can execute in parallel.

---

### Phase 1: Baseline equivalence measurement [COMPLETED]

**Goal**: Capture today's four-tree scan result and the repo-wide walk result side by side, as the
recorded baseline requirement (1) is checked against, before any production file changes.

**Tasks**:
- [x] Run the current scan verbatim and save output:
      `REPO_ROOT=$(pwd) bash agent-system/extensions/core/scripts/check-task-references.sh > /tmp/.../baseline-four-tree.txt 2>&1; echo "exit=$?"` *(completed)*
- [x] Run the same non-quiet scan without `--quiet` into the same capture so per-finding lines (if
      any ever appear) are in the baseline, not just counts. *(completed)*
- [x] Run a throwaway repo-wide walk (a scratch script sourcing the *unmodified*
      `scripts/lib/task-reference-patterns.sh`, enumerating `git ls-files` repo-wide, filtering
      through `is_exempt_path`, piping each file through `strip_exempt_regions | grep -nEi
      "$PHASE_PATTERN|$TASK_PATTERN"`) into `/tmp/.../baseline-repo-wide.txt`. *(completed)*
- [x] Diff the two finding sets (not the summary lines — the summary shape is expected to change)
      and record the result. Both are expected empty. *(completed)*
- [x] If the diff is NON-empty: stop and record every newly-surfaced file. Requirement (1) is
      about *same files flagged*; a non-empty delta must be triaged (real violation to fix, or a
      missing exemption category) before Phase 2 proceeds — it is not a reason to abandon option
      (a).

**Timing**: 0.5 hours

**Depends on**: none

**Verification Tier**: local

**Scope Hypothesis**: Research measured both scans at 0 findings on 2026-09-28. This is a
hypothesis about a working tree that concurrent sibling tasks are actively modifying; confirm it
by re-running both scans in this phase rather than citing the report's number.

**Files to modify**:
- None (measurement only; all output goes to the scratchpad directory)

**Verification**:
- Both capture files exist and the finding-line diff between them is empty (or its non-empty
  delta is enumerated in the phase's progress notes with a triage decision per file).
 *(completed)*
---

### Phase 2: Repo-wide enumeration in check-task-references.sh [COMPLETED]

**Goal**: Replace the hard-coded `TREE_ROOTS` default with one repo-wide `git ls-files` walk, and
make any in-repo `PATH_SCOPE` scannable instead of exit-2.

**Tasks**:
- [x] Re-read `agent-system/extensions/core/scripts/check-task-references.sh` immediately before
      editing (sibling-concurrency discipline). *(completed)*
- [x] Delete the `TREE_ROOTS` array and the `declare -A TREE_COUNT`/`REPORT_KEYS` per-tree
      plumbing that exists only to serve it. *(completed)*
- [x] Default (no `PATH_SCOPE`) path: enumerate `git -C "$REPO_ROOT" ls-files` once, repo-wide;
      run every non-`is_exempt_path` file through the unchanged
      `strip_exempt_regions | grep -nEi "$PHASE_PATTERN|$TASK_PATTERN"` pipeline; accumulate one
      repo-wide count. *(completed)*
- [x] Keep the per-finding print EXACTLY `info "  $rel:$finding"` — leading two spaces, `$rel`
      colon-free — because `verify-deploy.sh` gate 4 greps `^  [^:]+:[0-9]+:`. *(completed)*
- [x] Replace the four per-tree summary lines with a single repo-wide line (e.g.
      `"  repo (excluding specs/): $TOTAL occurrence(s)"`) and adjust the final `PASS:`/`FAIL:`
      lines so they no longer say "across N tree(s)" when the scan is repo-wide. Confirmed during
      planning that nothing outside this script keys off the summary line's text. *(completed)*
- [x] `PATH_SCOPE` mode: delete the `TREE_ROOTS`-membership validation block and its
      `exit 2` (requirement 3). Keep the `[[ ! -d "$enum_dir" ]]` -> `[SKIP]` guard for a scope
      naming a non-existent path; keep `git ls-files "$PATH_SCOPE"` enumeration so a scope that is
      a single file also works. *(completed)*
- [x] Leave exit-code semantics untouched: 0 clean, 1 findings, 2 reserved for genuine
      usage/environment errors (missing library, missing git, unknown flag, extra arguments). *(completed)*
- [x] Update the script's own header comment block (lines ~4-6 and the `PATH_SCOPE` paragraph at
      ~25-29), which currently documents the four trees and the exit-2-if-outside rule as the
      contract. *(completed)*
- [x] Re-run the Phase 1 baseline comparison against the *modified* script; the finding set must
      match `/tmp/.../baseline-repo-wide.txt`.

**Timing**: 1.25 hours

**Depends on**: 1

**Verification Tier**: interface

**Scope Hypothesis**: This phase assumes `verify-deploy.sh` gate 4 is the only consumer keying off
this script's output shape, and that it depends only on the per-finding line regex plus the exit
code. Confirm at implementation time with a fresh
`grep -rn "check-task-references" agent-system/extensions/ scripts/ context/ rules/` before
changing the summary lines.

**Files to modify**:
- `agent-system/extensions/core/scripts/check-task-references.sh` - remove `TREE_ROOTS` and
  per-tree reporting; repo-wide `git ls-files` default; drop `PATH_SCOPE` membership validation;
  rewrite header contract comment

**Verification**:
- `REPO_ROOT=$(pwd) bash agent-system/extensions/core/scripts/check-task-references.sh` exits 0
  and its finding set equals the Phase 1 repo-wide baseline.
- `REPO_ROOT=$(pwd) bash .../check-task-references.sh docs` (a path outside the old TREE_ROOTS)
  exits 0 or 1 — never 2.
- `REPO_ROOT=$(pwd) bash .../check-task-references.sh --bogus` still exits 2; an extra positional
  argument still exits 2.
- `bash -n` clean; `shellcheck` shows no new findings relative to the pre-edit run.
 *(completed)*
---

### Phase 3: Consumer-repo fixture test suite for the lint [COMPLETED]

**Goal**: A new `test-check-task-references.sh` proving the lint scans a consumer-shaped layout
and that the lint and the write-time hook admit/block the same set.

**Tasks**:
- [x] Read `scripts/tests/test-validate-no-task-references.sh` (assertion-style template) and
      `scripts/tests/test-deploy-verify-wiring.sh` (throwaway git-fixture template) before
      writing; follow `context/standards/shell-script-testing.md`'s `pass()`/`fail()`/`info()` +
      `mktemp -d` + trap-cleanup convention. *(completed)*
- [x] Build a consumer-repo-shaped fixture: `git init -q` a scratch dir with `docs/`,
      `README.md`, a source dir (`code/` or `framed_channel/`), `.github/`, and a
      `specs/{NNN}_{slug}/reports/` artifact — deliberately NO `agent-system/extensions`, `lua`,
      `.memory`, or `.opencode`. Place the script plus its shared library at
      `<fixture>/.claude/scripts/` so `deploy-root-guard.sh` resolves, or invoke with an explicit
      `REPO_ROOT`. *(completed)*
- [x] Assertion: a planted unexempted citation in `docs/` is found (exit 1, finding line names the
      `docs/` path). This is the case that fails today. *(completed)*
- [x] Assertion: a planted citation in the source dir (`code/`-style) is found — the ModelChecker
      reproduction. *(completed)*
- [x] Assertion: a citation inside `specs/**` is NOT found (exit 0) — the one path exemption holds. *(completed)*
- [x] Assertion: a `task-ref-ok`-marked region is NOT found — `strip_exempt_regions` still applies
      through the new enumeration. *(completed)*
- [x] Assertion: a gitignored file carrying a citation is NOT found — `git ls-files` exclusion. *(completed)*
- [x] Assertion (requirement 3): `PATH_SCOPE=docs` exits 0/1 with the `docs/` finding, never 2;
      and a `PATH_SCOPE` naming a non-existent path prints the `[SKIP]` line and exits 0. *(completed)*
- [x] Assertion (requirement 8, lint/hook agreement): for each fixture file, compare the lint's
      in-scope/out-of-scope verdict against `hooks/validate-no-task-references.sh`'s verdict for a
      Write of that same path+content. They must agree on every file — a repo-wide lint paired
      with a differently-scoped gate is the new defect this assertion exists to prevent. *(completed)*
- [x] Assertion: per-finding line matches `^  [^:]+:[0-9]+:` (the `verify-deploy.sh` gate 4
      contract), asserted directly in this suite so a future reshaping breaks here rather than in
      gate 4. *(completed)*
- [x] No `run-all.sh` registration needed — it auto-discovers `scripts/tests/test-*.sh` (confirmed
      at `run-all.sh:185`). Optionally add a `suite-cost-hints.txt` row; purely advisory.

**Timing**: 1.5 hours

**Depends on**: 2

**Verification Tier**: local

**Scope Hypothesis**: This phase asserts nine test cases and that `run-all.sh` needs no manual
registration. Confirm the discovery glob at `scripts/tests/run-all.sh:185` still matches
`test-*.sh` before relying on auto-discovery, and confirm the final case count against what the
fixture can actually express.

**Files to modify**:
- `agent-system/extensions/core/scripts/tests/test-check-task-references.sh` - new suite
- `agent-system/extensions/core/scripts/tests/suite-cost-hints.txt` - optional advisory row

**Verification**:
- `bash agent-system/extensions/core/scripts/tests/test-check-task-references.sh` exits 0 with
  every assertion passing.
- Reverting Phase 2's change (in a scratch copy, not the working tree) makes the `docs/` and
  source-dir assertions FAIL — proving the suite actually tests the fix rather than passing
  vacuously.
 *(completed)*
---

### Phase 4: validate-wiring.sh missing-tree-root SKIP guards [COMPLETED]

**Goal**: An absent tree root becomes an informational `[SKIP]`, not a cascade of `[FAIL]` rows,
so exit status reflects only trees actually present.

**Tasks**:
- [x] Re-read `agent-system/extensions/core/scripts/validate-wiring.sh` immediately before
      editing. *(completed)*
- [x] In `main()` (~lines 275-312), guard the `.claude` arm on `[[ -d "$PROJECT_ROOT/.claude" ]]`
      before calling `validate_core_system` + `validate_extensions_loaded`; emit a `log_info`
      `[SKIP]` line when absent, wording it after `check-task-references.sh`'s
      `"[SKIP] $label does not exist under $REPO_ROOT"` precedent. *(completed)*
- [x] Apply the identical guard to the `.opencode` arm. *(completed)*
- [x] Verify `$FAILED` (and therefore the exit code) is untouched by a skip, so an all-skipped run
      exits 0 and a present-but-broken tree still exits 1. *(completed)*
- [x] Re-verify, do not trust the note: confirm `deploy-root-guard.sh` (~lines 18-19) and
      `validate-state.sh` (~line 238) match the *running script's own* path against
      `*/.claude/scripts/` or `*/.opencode/scripts/`, and that
      `hooks/validate-handoff-location.sh` (~line 65) matches only a `specs/` path shape. Record
      the confirmed line numbers in the phase notes. If any is in fact unsafe, stop and report
      rather than widening this phase. *(completed)*
- [x] Do NOT remove any `.opencode` reference or touch the frozen-mirror policy.

**Timing**: 0.75 hours

**Depends on**: none

**Verification Tier**: local

**Scope Hypothesis**: This phase asserts exactly two call sites need guarding and that three other
scripts are SAFE. Confirm both by re-reading `main()` for any third unguarded tree-root use, and
by re-reading the three named line ranges rather than citing the report.

**Files to modify**:
- `agent-system/extensions/core/scripts/validate-wiring.sh` - existence guard + `[SKIP]` line per
  tree arm in `main()`

**Verification**:
- `bash -n` clean.
- In this repo (both trees present) `validate-wiring.sh all` output and exit code are unchanged
  from a pre-edit capture — the guard is a no-op where both trees exist.
- `validate-wiring.sh --claude` and `--opencode` each still behave as before.
 *(completed)*
---

### Phase 5: Regression suite for missing-tree-root handling [NOT STARTED]

**Goal**: A new `test-validate-wiring.sh` locking in the consumer layout `.claude` present /
`.opencode` absent.

**Tasks**:
- [ ] Follow `test-deploy-verify-wiring.sh`'s fixture model: `mktemp -d`, trap cleanup,
      `git init -q`, and place the script under test at `<fixture>/.claude/scripts/` (required —
      `deploy-root-guard.sh` demands the parent-of-parent directory literally be `.claude` or
      `.opencode`, with no env override), copying whatever libraries it sources.
- [ ] Build the fixture with a minimally-valid `.claude` tree (index.json, the agents/skills/rules
      `validate_core_system` checks) and NO `.opencode` directory at all.
- [ ] Assertion (a): `all` output contains a `[SKIP]` line naming `.opencode`.
- [ ] Assertion (b): no `[FAIL]` line mentions `.opencode`.
- [ ] Assertion (c): the exit code depends only on the `.claude` side — clean `.claude` gives
      exit 0; deliberately break one `.claude` file and the same run gives exit 1 with a
      `.claude`-attributed failure.
- [ ] Assertion (d): the mirror case — `.opencode` present, `.claude` absent — skips `.claude`
      symmetrically, since the fix covers both arms.
- [ ] Assertion (e): both trees absent gives exit 0 with two `[SKIP]` lines and zero failures.
- [ ] No `run-all.sh` registration needed (auto-discovery).

**Timing**: 1.25 hours

**Depends on**: 4

**Verification Tier**: local

**Scope Hypothesis**: This phase asserts five cases and that a minimal `.claude` fixture can be
built cheaply enough to satisfy `validate_core_system`. If the minimal tree proves impractically
large, narrow the fixture to the SKIP/FAIL-attribution assertions (a, b, d, e) plus a documented
note, rather than silently dropping case (c).

**Files to modify**:
- `agent-system/extensions/core/scripts/tests/test-validate-wiring.sh` - new suite
- `agent-system/extensions/core/scripts/tests/suite-cost-hints.txt` - optional advisory row

**Verification**:
- `bash agent-system/extensions/core/scripts/tests/test-validate-wiring.sh` exits 0.
- Reverting Phase 4 in a scratch copy makes assertions (a) and (b) fail.

---

### Phase 6: Documentation alignment and full gate run [NOT STARTED]

**Goal**: The enforcement narrative describes the actual scan, the rule's repo-wide claim is
backed rather than merely asserted, and the whole repository's gate set is green.

**Tasks**:
- [ ] Re-read `context/standards/task-reference-exemptions.md` immediately before editing.
- [ ] Rewrite the `## Enforcement` section's two four-root assertions: the lead sentence
      (`"specs/** is the ONLY exempt tree — agent-system/extensions/**, .opencode/**, lua/**, and
      .memory/** are all deliverables subject to this rule"`) and the lint bullet (`"scans every
      git-tracked file under the four deliverable tree roots above"`). Both must describe the
      repo-wide-minus-`specs/**` scan; keep the `specs/**`-is-the-only-exemption fact, drop the
      four-root framing, and keep the gate-4 wiring pointer.
- [ ] Add one sentence recording that the lint and the write-time hook now share exactly one scope
      predicate (`is_exempt_path`), so the two enforcement layers cannot silently diverge in scope
      (requirement 8's durable documentation).
- [ ] Re-read `rules/no-task-references-in-deliverables.md` and confirm its "the entire repository
      EXCEPT `specs/**/*`" claim is now backed by the lint. No substantive change expected
      (requirement 7 is satisfied by closing the gap, not by editing the rule). If any wording
      still implies a narrower mechanical scope, correct only that wording.
- [ ] Consider the research report's Context Extension Recommendation — a short note capturing the
      general "a multi-repo lint should default to the widest safe scope, not this repo's own
      directory list" principle — as a subsection of the exemptions doc. Include it if it fits in
      a few sentences; otherwise leave it for a follow-up rather than growing this phase.
- [ ] Verify no task-number references were introduced in any file outside `specs/**` by these
      edits (the new lint will catch it).
- [ ] Redeploy so gate 4 exercises the fixed script:
      `bash agent-system/extensions/core/scripts/deploy-headless.sh` (gate 4 invokes
      `$CLAUDE_DIR/scripts/check-task-references.sh`, the deployed copy, not the source store).
- [ ] Run the full gate set: `bash agent-system/extensions/core/scripts/tests/run-all.sh` and
      `bash agent-system/extensions/core/scripts/verify-deploy.sh` (gates 1-5, with gate 4 the one
      of direct interest here).
- [ ] Re-run the Phase 1 equivalence check one final time immediately before the final commit, to
      catch any violation introduced by a concurrent sibling task in this same orchestrate cycle.

**Timing**: 1.0 hours

**Depends on**: 2, 3, 4, 5

**Verification Tier**: full

**Scope Hypothesis**: This phase asserts exactly two sentences in
`task-reference-exemptions.md`'s Enforcement section need rewriting and that
`no-task-references-in-deliverables.md` needs no substantive change. Confirm with a fresh
`grep -n "four\|TREE_ROOTS\|tree root" context/standards/task-reference-exemptions.md
rules/no-task-references-in-deliverables.md` before editing.

**Files to modify**:
- `agent-system/extensions/core/context/standards/task-reference-exemptions.md` - Enforcement
  section rewritten for the repo-wide scan; shared-predicate note added
- `agent-system/extensions/core/rules/no-task-references-in-deliverables.md` - verified; edited
  only if wording implies a narrower mechanical scope

**Verification**:
- `grep -n "four deliverable tree roots\|four tree" context/standards/task-reference-exemptions.md`
  returns nothing.
- `run-all.sh` exits 0, including both new suites.
- `verify-deploy.sh` exits 0 with gate 4 passing against the redeployed script.
- The final equivalence re-run matches the Phase 1 baseline finding set.

---

## Testing & Validation

- [ ] `test-check-task-references.sh` passes all assertions and fails against a reverted Phase 2.
- [ ] `test-validate-wiring.sh` passes all assertions and fails against a reverted Phase 4.
- [ ] `test-validate-no-task-references.sh` (existing hook suite) still passes — parity, not
      regression.
- [ ] `test-verify-deploy-gate-selection.sh` and `test-deploy-verify-wiring.sh` still pass — the
      gate-4 output contract is intact.
- [ ] `run-all.sh` exits 0 across the whole core suite.
- [ ] `verify-deploy.sh` exits 0; gate 4 passes against the deployed copy.
- [ ] Requirement 1: this repo's finding set is identical before and after (measured, both
      expected empty).
- [ ] Requirement 2: a consumer-shaped fixture's `docs/`, `README.md`, and source dir are scanned.
- [ ] Requirement 3: a `PATH_SCOPE` outside the old TREE_ROOTS is scanned, never exit 2.
- [ ] Requirement 4: `git diff` shows `scripts/lib/task-reference-patterns.sh` untouched.
- [ ] Requirement 8: lint and hook agree on every fixture file; `git diff` shows
      `hooks/validate-no-task-references.sh` untouched (or changed only for verified parity).

## Artifacts & Outputs

- `agent-system/extensions/core/scripts/check-task-references.sh` (modified)
- `agent-system/extensions/core/scripts/validate-wiring.sh` (modified)
- `agent-system/extensions/core/scripts/tests/test-check-task-references.sh` (new)
- `agent-system/extensions/core/scripts/tests/test-validate-wiring.sh` (new)
- `agent-system/extensions/core/context/standards/task-reference-exemptions.md` (modified)
- `agent-system/extensions/core/rules/no-task-references-in-deliverables.md` (verified; edited
  only if needed)
- `agent-system/extensions/core/scripts/tests/suite-cost-hints.txt` (optional advisory rows)
- Regenerated `.claude/` deploy tree (generated artifact, not hand-authored)
- `specs/244_check_task_references_repo_appropriate_roots/summaries/01_*-summary.md`

## Rollback/Contingency

Every phase is committed separately per the commit-per-green-substep mandate, so rollback is a
targeted `git revert` of the specific phase commit, followed by
`bash agent-system/extensions/core/scripts/deploy-headless.sh` to bring `.claude/` back in line
with the source store.

Phases 2-3 (`check-task-references.sh`) and Phases 4-5 (`validate-wiring.sh`) touch disjoint code
paths, so either pair can be reverted without disturbing the other.

Should a working-tree rollback of uncommitted work be required, use the snapshot-then-rollback
recipe in `context/contracts/recovery.md`'s rollback rung for the exact invocation shape
(including its out-of-scope override flag) — never a bare precautionary `git-snapshot.sh` in its
default reverting mode. For an ordinary defensive checkpoint before the Phase 2 rewrite, use
`bash .claude/scripts/git-snapshot.sh 244 --no-revert`, which is durable and does not revert the
working tree.

Contingency if Phase 1 surfaces a non-empty delta: triage each newly-surfaced file as either a
real violation (fix it in Phase 2's commit, which strengthens rather than blocks option (a)) or a
genuinely missing exemption category (add the case arm to the shared library's `is_exempt_path`,
documenting it as a new category in `task-reference-exemptions.md` — this is the one circumstance
in which requirement 4's "no change to the shared lib" expectation is legitimately revised, and it
should be reported as a scope note rather than done silently).
