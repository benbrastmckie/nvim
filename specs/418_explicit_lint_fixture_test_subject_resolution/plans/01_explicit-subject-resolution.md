# Implementation Plan: Task #418

- **Task**: 418 - Make the lint-fixture-test family's subject resolution explicit and self-declaring
- **Status**: [IMPLEMENTING]
- **Effort**: 11 hours total; 5 hours discharged (Phases 1-3), 6 hours remaining (Phases 4-8)
- **Dependencies**: None (the three prior tasks on `context/standards/shell-script-testing.md` and `scripts/gate-registry.data` have landed)
- **Research Inputs**: specs/418_explicit_lint_fixture_test_subject_resolution/reports/01_explicit-subject-resolution.md
- **Reports Integrated**: 01_explicit-subject-resolution.md (plan-authoring); blocker-triage findings delivered inline by the revising dispatch (no standalone report artifact was written)
- **Artifacts**: plans/01_explicit-subject-resolution.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

The deploy-tree-first / source-store-fallback subject-resolution convention is real,
load-bearing, and implicit. This plan adds a mode-explicit resolution helper plus a mandatory
subject-declaration line to the one shared library (`scripts/lib/common.sh`), registers a new
gate-27 content lint that blocks any new suite from reintroducing an undeclared or
silently-ordered resolution, then migrates the measured 70-suite family onto the explicit form in
four reviewable batches — each batch shrinking the lint's allowlist by exactly the files it
converted, so a passing lint is never readable as "fully migrated" while files remain. The
default mode stays deploy-tree-first, because the Inter-Cycle Redeploy Checkpoint's pre/post
divergence signal depends on it.

### Research Integration

Key findings carried from the research report and independently re-derived at plan-authoring
time (see each phase's **Scope Hypothesis**):

- The family is **70 suites**, not the 41 figure recorded in
  `context/patterns/batch-orchestration-guardrails.md`, nor the 22 figure in this task's own
  creation-time description. Re-derived live: 144 `*.sh` under `scripts/tests/`; 70 reference
  `$REPO_ROOT/.claude/scripts`; 32 call some form of `resolve_candidate` (20 shared, 12
  local-duplicate); union 73; minus 3 deployed-only-by-design suites = 70.
- The family exists in **three shapes**: shared-helper callers (20), hand-duplicated local
  `resolve_candidate` functions (12), and inline `CANDIDATES`-array `for` loops with no named
  function at all (38). The third shape is invisible to `grep resolve_candidate`, which is why
  every prior count undershot.
- The implicit order is **not** uniformly deploy-tree-first: `test-gate-out-derived-staleness.sh`
  and `test-install-uninstall-extension.sh` pass the source-store candidate first. Migration must
  preserve each call site's existing effective order, not normalize it.
- `[SUBJECT]` is free as a declaration token — grepped live across `scripts/` and `context/`
  with zero hits — and is disjoint from `[PASS]`/`[FAIL]`/`[INFO]`/`[VIOLATION]`.
- `scripts/gate-registry.data` holds gates 1-26 contiguously; the new gate is id 27.
- `scripts/lib/suite-selection-lib.sh` already pairs `lint/lint-X.sh` -> `tests/test-lint-X.sh`
  and `lib/common.sh` -> `tests/test-common-lib.sh` by strict basename rule, so **no
  suite-selection edit is required** — which also keeps this task clear of sibling task 505's
  declared territory.

#### Revision-Time Re-Verification (blocker triage)

This plan was revised by a blocker-triage dispatch. **The reported blocker was spurious**: no
blocker ever prevented Phases 4-8, and none is recorded here. The preceding dispatch's wrap-up
handoff placed an already-resolved retrospective note (transport instability during an earlier
dispatch, whose own text ended "No blocker prevents resuming phases 4-8 in a normal dispatch")
into the length-counted `blockers[]` array, and omitted the `continuation_path` required when
`status` is `partial`. Because the triage classifier counts `blockers[]` entries rather than
reading them, a cleanly resumable partial task was classified `needs_human` and Phases 4-8 were
hard-blocked. Nothing in the plan below caused that, and nothing in it needed correcting.

Every load-bearing claim the revision rests on was re-measured rather than carried forward:

- **Phases 1-3 are committed**: `c51aa1e4f` (Phase 1), `b30bbbb5b` / `29db7fcab` / `91954aa3e` /
  `8edccf7e0` (Phase 2), `4b178352b` (Phase 3) — all six verified present in `git log`.
- **Phase 1-3 output is green**: gate 27, invoked exactly as `gate27_run` invokes it (no path
  argument, so the narrow default `scripts/tests/` corpus applies), exits 0 with
  `Total violations: 0`. Its own suite, `test-lint-subject-resolution-declaration.sh`, reports
  `13 passed, 0 failed`, including its live-corpus case.
- **Phases 4-6 scope is unchanged and correct**: counted directly from the gate-27 lint's
  `EXCLUDED_FILES` allowlist — the authoritative roster, since each migration phase shrinks it —
  there are exactly **12** `migration-pending: Group B` entries (matching Phase 4's file list
  one-for-one) and exactly **38** `migration-pending: Group C` entries (matching Phases 5 and 6
  at 19 + 19), plus 8 permanent exemptions. No phase's file list required rebalancing.
- **No concurrent-writer collision**: the two test suites dirty in the working tree at revision
  time (`test-gate-cache-equivalence.sh`, `test-verify-deploy-gate-selection-crash-net.sh`)
  belong to another writer and are **not** in this family — neither references
  `$REPO_ROOT/.claude/scripts`, declares a local `resolve_candidate()`, uses an inline
  `CANDIDATES` loop, nor appears on the allowlist. They are outside every remaining phase's
  declared file list.

A caution for the dispatch that resumes here, since the cost above was entirely a wrap-up
artifact defect rather than an implementation one: on any wrap-up that reports `status: partial`,
`blockers[]` must carry only conditions that actually prevent progress — a retrospective note
about a past, resolved condition belongs in `summary`, never in `blockers[]` — and
`continuation_path` must name the next phase. An empty `blockers[]` is the normal, expected value
for a partial that is cleanly resumable.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No `roadmap_path` was provided in this dispatch; ROADMAP.md was not consulted.

## Goals & Non-Goals

**Goals**:
- One shared, mode-explicit resolution helper with a caller-side selector and the existing
  environment-override idiom, living in `scripts/lib/common.sh` alongside (not replacing)
  `common_test_resolve_candidate`.
- A mandatory `[SUBJECT] <absolute path>` declaration line in every suite of the family, so a
  green run can never be confused with a vacuous one.
- A mechanical gate-27 lint that blocks a new suite from reintroducing any of the three
  undeclared shapes, carrying an explicitly-reasoned, visibly shrinking allowlist.
- All 70 measured suites migrated within this task, in four verifiable batches.
- The stale population figure in `context/patterns/batch-orchestration-guardrails.md` corrected,
  and the three-shape taxonomy documented in `context/standards/shell-script-testing.md`.

**Non-Goals**:
- Flipping the default order to source-store-first. The default stays deploy-tree-first.
- Changing any suite's pass/fail answer. This work makes the subject explicit, nothing else.
- Running only the deploy-tree-first suites against gate 8 post-deploy (the checkpoint-COVERAGE
  follow-up the dispatch places explicitly out of scope). Not folded in, not created from here.
- Fixing the known-unrelated pre-existing failures (Gate 3 lean4 doc-lint index.json entry,
  Gate 20 eager-load budget, Gate 8 `test-detect-noop-bash.sh` / `test-four-tier-conflict.sh` /
  `test-guard-git-push.sh`).
- Editing `scripts/lib/suite-selection-lib.sh` or any other file in a concurrent sibling's
  declared territory, except `scripts/tests/test-lint-dead-command-recommendations.sh` (see
  Risks).

## Design Decisions Settled by This Plan

The research report deliberately left four names and one precedence rule to the plan phase.
Settled here so implementation has no open choice:

| Decision | Value |
|---|---|
| Resolver function | `common_test_resolve_subject <desc> <mode> <deployed_candidate> <source_store_candidate>` |
| Declaration function | `common_test_declare_subject <resolved_path>` |
| Declaration line | `[SUBJECT] <absolute path>` — line-initial token, exactly one space, then the path (satisfies the producer side of the verdict-line extraction contract; disjoint from all four anchor tokens) |
| Mode vocabulary | `deployed`, `source-store`, `deploy-tree-first` |
| Environment override | `CORE_TEST_SUBJECT_MODE`, same unset-means-sane-default idiom as `VERIFY_DEPLOY_GATE8_JOBS`; unset means `deploy-tree-first` |
| Precedence | A caller passing `deployed` or `source-store` has stated a **correctness requirement** and is never overridden by the environment. A caller passing `deploy-tree-first` (or an empty mode) has stated a **preference**, and `CORE_TEST_SUBJECT_MODE` overrides exactly that case. This is what keeps the two confirmed source-store-first callers correct under any environment while still giving the env var a real, single meaning |
| New lint | `scripts/lint/lint-subject-resolution-declaration.sh`, gate **27** |
| New lint's own suite | `scripts/tests/test-lint-subject-resolution-declaration.sh` (auto-paired by `suite_selection_select`'s strict basename rule) |

`common_test_resolve_candidate` keeps its existing variadic signature untouched: its 20 call
sites' arity must not break, and it has uses unrelated to the deployed/source-store duality.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Sibling task 512 owns `scripts/tests/test-lint-dead-command-recommendations.sh`, which is in this task's Group A | M | H | The file is declared in Phase 3's `Files to modify` so the admission gate serializes the two tasks rather than excluding the file. Re-read it immediately before editing; stage only this task's own hunks; never a directory or glob `git add` |
| A migration silently flips one call site's effective order | H | M | Batch by shape; verify each batch with its own `run-all.sh --only` list before the next starts; re-check `test-gate-out-derived-staleness.sh` and `test-install-uninstall-extension.sh` by name before and after migration (both move to `mode=source-store`, never to the default) |
| A global flip would blind the Inter-Cycle Redeploy Checkpoint | H | L | Default mode is deploy-tree-first, asserted by a dedicated Phase 1 fixture that proves a pre/post pair still diverges when the deployed copy is stale |
| The lint's Layer-1 detector false-positives on an unrelated `candidate` loop | M | M | Follow `lint-state-writer-boundary.sh` / `lint-verdict-extraction-anchoring.sh`: state the regex-only KNOWN LIMITATION in the header, lean on the reasoned allowlist for genuine false positives rather than over-fitting |
| The lint silently matches nothing and passes as working | H | M | Phase 2's fixture seeds a deliberate violation of each of the three shapes in a temp fixture tree (never the live tree) and asserts non-zero exit plus a `[VIOLATION]` row naming the seeded file |
| A later re-measurement repeats the grep-only undercount | M | M | Phase 7 names the inline-loop shape explicitly in both corrected documents |
| 70 files is large enough to exhaust one dispatch | M | M | Four independent batch phases, each independently green and committed; `git-snapshot.sh --no-revert` before the largest batches |

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
| 7 | 7 | 6 |
| 8 | 8 | 7 |

Phases within the same wave can execute in parallel. This plan is fully sequential: every
migration batch shrinks the same lint allowlist file, so the batches must not run concurrently.

---

### Phase 1: Mode-Explicit Resolver and Subject Declaration in common.sh [COMPLETED]

**Goal**: Add the two new functions to the single shared library, with a documented
producer/consumer contract, and prove every mode against two deliberately DIFFERENT copies.

**Tasks**:
- [x] Add `common_test_resolve_subject <desc> <mode> <deployed_candidate> <source_store_candidate>` *(completed)*
      to `scripts/lib/common.sh`, modeled structurally on
      `scripts/lib/gate-verdict-extract-lib.sh`: one job, explicit required parameter, stated
      contract in the header comment, never calls `exit` (caller keeps `|| exit 2`).
- [x] Implement mode semantics: `deployed` resolves the deployed candidate or fails; *(completed)*
      `source-store` resolves the source-store candidate or fails; `deploy-tree-first` returns the
      first of (deployed, source-store) that is a regular file.
- [x] Implement the precedence rule from Design Decisions: `CORE_TEST_SUBJECT_MODE` overrides an *(completed)*
      empty or `deploy-tree-first` mode argument only, never a hard-selected `deployed` or
      `source-store`. Reject an unrecognized mode value loudly (return non-zero, message to
      stderr) — never silently fall back.
- [x] Add `common_test_declare_subject <resolved_path>` printing exactly *(completed)*
      `[SUBJECT] <absolute path>` on stdout, one line, line-initial token plus one space.
      Resolve the path to absolute form inside the function so a caller passing a relative
      candidate still declares an absolute subject.
- [x] Document in the header comment that the declaration is MANDATORY for any suite resolving a *(completed)*
      subject-under-test, and that `[SUBJECT]` is deliberately disjoint from
      `[PASS]`/`[FAIL]`/`[INFO]`/`[VIOLATION]`.
- [x] Correct the stale population figure in `common_test_resolve_candidate`'s own header comment *(completed)*
      ("22/121 core suites") to the re-measured figures. Leave the unrelated `115/121` figure in
      `common_test_workdir_init`'s comment alone — it is a different, unmeasured claim.
- [x] Extend `scripts/tests/test-common-lib.sh` with fixtures, each built over two deliberately *(completed)*
      DIFFERENT copies of a fake subject (a source-store copy that exits 0 and a deployed copy
      that exits 1, plus the mirror image) so a mode that silently resolved the wrong copy fails:
  - [x] `deployed` mode resolves the deployed copy, both directions. *(completed)*
  - [x] `source-store` mode resolves the source-store copy, both directions. *(completed)*
  - [x] `deploy-tree-first` resolves the deployed copy when both exist, and the source-store copy *(completed)*
        when only it exists (the fallback branch).
  - [x] The declaration line names the path actually used, including under the fallback branch. *(completed)*
  - [x] `CORE_TEST_SUBJECT_MODE` overrides `deploy-tree-first` but does NOT override a *(completed)*
        hard-selected `deployed` or `source-store`.
  - [x] An unrecognized mode value fails loudly rather than defaulting. *(completed)*
  - [x] **Checkpoint-property fixture**: with the default (unset `CORE_TEST_SUBJECT_MODE`, mode *(completed)*
        `deploy-tree-first`), a stale deployed copy is still what resolves — so an
        Inter-Cycle-Redeploy-Checkpoint-style pre/post pair still diverges. Assert the resolved
        path, not merely a pass.

**Timing**: 1.5 hours

**Depends on**: none

**Verification Tier**: local

**Tier Justification**: `bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-common-lib.sh` is the strict-basename-paired covering suite for `scripts/lib/common.sh`, and because that suite sources the edited library it also catches any sourcing-level breakage the corpus-wide dependents would otherwise surface.

**Scope Hypothesis**: This phase asserts the figures 144 / 70 / 20 / 12 / 38 / 3 carried from `reports/01_explicit-subject-resolution.md` and re-derived at plan-authoring time by the commands in that report's Appendix. Re-run those commands at implementation time before writing any figure into `common.sh`'s comment, and write the figures measured then, not these.

**Files to modify**:
- `agent-system/extensions/core/scripts/lib/common.sh` - add `common_test_resolve_subject` and `common_test_declare_subject`; correct the stale count in `common_test_resolve_candidate`'s comment
- `agent-system/extensions/core/scripts/tests/test-common-lib.sh` - add the mode, declaration, fallback, precedence, and checkpoint-property fixtures

**Verification**:
- `bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-common-lib.sh` exits 0
  and the new assertions appear in its output.
- `bash -n agent-system/extensions/core/scripts/lib/common.sh` is clean.
- Each mode fixture is manually confirmed to use two copies with DIFFERENT behavior (grep the
  fixture for the two distinct exit codes) — a fixture over identical copies does not count.

---

### Phase 2: Gate-27 Subject-Declaration Lint with Full Allowlist [COMPLETED]

**Goal**: Ship the mechanical check before any migration, with an allowlist that names every
not-yet-migrated suite, so the unmigrated remainder can never be read as already-safe.

**Tasks**:
- [x] Create `scripts/lint/lint-subject-resolution-declaration.sh`, structurally modeled on *(completed)*
      `scripts/lint/lint-state-writer-boundary.sh` and
      `scripts/lint/lint-verdict-extraction-anchoring.sh` (two layers, `--verbose`, `[VIOLATION]`
      verdict rows, a stated KNOWN LIMITATION header paragraph).
- [x] Layer 1 (structural detection) over `scripts/tests/*.sh`, flagging a file that: *(completed)*
  - [x] declares a local function named `resolve_candidate` (the hand-duplicate shape), or *(completed)*
  - [x] contains an inline resolution loop over a `*CANDIDATES*`-named array or *(completed)*
        `for candidate in` (the inline shape), or
  - [x] calls `common_test_resolve_subject` without a paired `common_test_declare_subject` for the *(completed)*
        resolved value (the missing-declaration case), or
  - [x] calls `common_test_resolve_candidate` with a `$REPO_ROOT/.claude/scripts` candidate and a *(completed)*
        source-store sibling candidate (the un-migrated implicit-order shape).
- [x] Layer 2: an explicit, per-entry-reasoned allowlist. Seed it with all 70 not-yet-migrated *(completed)*
      suites plus the exemptions, each carrying a one-line reason; no bare paths.
- [x] Record the three deployed-only-by-design suites as permanent exemptions with their reason *(completed)*
      (one valid copy, so there is no ambiguity to declare): `test-backfill-file-scope.sh`,
      `test-double-loading-check.sh`, `test-update-task-status.sh`. Confirm each at
      implementation time rather than trusting this list.
- [x] Record the two known non-subject-resolution `candidate` users as permanent exemptions: *(completed)*
      `test-check-record-versioning.sh`, `test-check-task-references.sh` (they describe a
      production script's own internal resolution, not the harness's subject).
- [x] Add `gate27_run()` to `scripts/verify-deploy.sh`, copying `gate26_run`'s exact shape: *(completed)*
      `gate_selected 27` guard, `say "27. ..."`, `CURRENT_GATE="gate27"`, source-store `[SKIP]`
      branch, missing-script `fail`, `--verbose` invocation with status capture, and
      `verify_deploy_extract_verdict_lines '[VIOLATION]'` folding into `FINDINGS_LIST`.
- [x] Add the gate-27 row to `scripts/gate-registry.data`: 9 TAB-separated fields, id 27, *(completed)*
      `gate27_run`, dependencies `-`, `requires_source_store` true, a timeout and cost class
      matching the comparable `free` lint rows, `serialized` false, and an `input_corpus` naming
      the corpus this lint actually reads.
- [x] Register both new scripts in `manifest.json` (`lint/lint-subject-resolution-declaration.sh` *(completed)*
      and `tests/test-lint-subject-resolution-declaration.sh`).
- [x] Create `scripts/tests/test-lint-subject-resolution-declaration.sh` using the harness trio *(completed)*
      and `common_test_workdir_init`, with a **deliberately seeded violation of each of the three
      shapes in a temp fixture tree, never the live tree**, asserting non-zero exit and a
      `[VIOLATION]` row naming the seeded file; plus a clean-fixture case asserting exit 0; plus a
      case proving an allowlisted file is not flagged.

**Timing**: 2 hours

**Depends on**: 1

**Verification Tier**: interface

**Tier Justification**: The edit changes `verify-deploy.sh`'s gate set and the registry it is driven by, whose direct dependents are enumerable and covered by `bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-lint-subject-resolution-declaration.sh,test-gate-registry-resolution.sh,test-manifest-scripts-sync.sh,test-deploy-verify-wiring.sh` plus `bash agent-system/extensions/core/scripts/lint/lint-gate-registry.sh --verbose`.

**Scope Hypothesis**: This phase asserts a 70-entry seed allowlist and a next-free gate id of 27. Confirm both at implementation time: re-derive the 70 by the report's Appendix commands, and re-read `scripts/gate-registry.data`'s tail to confirm 26 is still the highest id (a concurrent sibling could have taken 27).

**Files to modify**:
- `agent-system/extensions/core/scripts/lint/lint-subject-resolution-declaration.sh` - new two-layer content lint
- `agent-system/extensions/core/scripts/tests/test-lint-subject-resolution-declaration.sh` - new suite with seeded-violation fixtures
- `agent-system/extensions/core/scripts/gate-registry.data` - add the gate-27 row
- `agent-system/extensions/core/scripts/verify-deploy.sh` - add `gate27_run`
- `agent-system/extensions/core/manifest.json` - register the new lint and its suite

**Verification**:
- `bash agent-system/extensions/core/scripts/lint/lint-gate-registry.sh --verbose` exits 0
  (Checks A-G accept the new row, including A's "invoke function is defined in verify-deploy.sh"
  and E's contiguity).
- `bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-lint-subject-resolution-declaration.sh,test-gate-registry-resolution.sh,test-manifest-scripts-sync.sh,test-deploy-verify-wiring.sh`
  exits 0.
- The seeded-violation fixture is confirmed to FAIL the lint (non-zero exit status checked, not a
  stdout diff) — a lint matching nothing cannot pass this.
- `bash .claude/scripts/verify-deploy.sh --only-gate 27 "$(git rev-parse --show-toplevel)"` runs
  gate 27 and reports it, with no SKIP.

---

### Phase 3: Migrate Group A — the 20 Shared-Helper Callers [COMPLETED]

**Goal**: Convert every `common_test_resolve_candidate` subject lookup to the explicit-mode form
plus a mandatory declaration, preserving each call site's existing effective order exactly.

**Tasks**:
- [x] Re-derive Group A: `grep -l 'common_test_resolve_candidate' scripts/tests/*.sh`. *(completed)*
- [x] For each file, for each subject-resolution call site: determine the existing effective order *(completed)*
      from the literal argument order, then rewrite as `common_test_resolve_subject` with the
      mode that reproduces it — `deployed` or `deploy-tree-first` where the deployed candidate is
      first, `source-store` where the source-store candidate is first.
- [x] Explicitly migrate `test-gate-out-derived-staleness.sh` and *(completed)*
      `test-install-uninstall-extension.sh` to `mode=source-store`, and record their before/after
      resolved paths in the phase's verification notes — these are the two confirmed
      non-default-order callers.
- [x] Add a `common_test_declare_subject` call immediately after each resolution, once per *(completed)*
      resolved subject (suites with several subjects declare each one).
- [x] Leave non-subject uses of `common_test_resolve_candidate` (file-existence checks unrelated *(completed: test-task-type-detect.sh's REAL_EXT_ROOT lookup stays on the old helper, recorded as a permanent gate-27 allowlist exemption rather than only a commit-message note, since the lint's file-level check 4 could not otherwise distinguish it from the migrated call in the same file)*
      to the deployed/source-store duality) on the old helper, and note each one in the commit
      message so a later reader does not read it as a missed migration.
- [x] Remove each migrated file from the lint's Layer-2 allowlist in the same commit, so the *(completed)*
      roster visibly shrinks by exactly this batch.
- [x] **Territory**: `test-lint-dead-command-recommendations.sh` is in sibling task 512's declared *(completed: no foreign uncommitted modification was present; migrated cleanly)*
      file_scope. Re-read it immediately before editing; if it carries a foreign uncommitted
      modification, STOP and report rather than proceeding.

**Timing**: 1.5 hours

**Depends on**: 2

**Verification Tier**: local

**Tier Justification**: Every edit is confined to a single test suite with no externally visible signature change, and each suite is its own covering check — `bash agent-system/extensions/core/scripts/tests/run-all.sh --only <the Group A basenames>` exercises exactly the files this phase touched.

**Scope Hypothesis**: Group A is hypothesized to be these 20 suites, re-derived at plan-authoring time by `grep -l 'common_test_resolve_candidate' scripts/tests/*.sh`. Re-run that command at implementation time; a suite added or removed by a sibling since then changes the batch, and the measured list governs, not this one.

**Files to modify**:
- `agent-system/extensions/core/scripts/tests/test-audit-task-proposals.sh` - explicit mode + declaration
- `agent-system/extensions/core/scripts/tests/test-common-lib.sh` - explicit mode + declaration for its own subject lookups
- `agent-system/extensions/core/scripts/tests/test-gate-out-derived-staleness.sh` - migrate to `mode=source-store`
- `agent-system/extensions/core/scripts/tests/test-install-uninstall-extension.sh` - migrate to `mode=source-store`
- `agent-system/extensions/core/scripts/tests/test-lint-anchor-pointer-collapse.sh` - explicit mode + declaration
- `agent-system/extensions/core/scripts/tests/test-lint-branch-gated-sections.sh` - explicit mode + declaration
- `agent-system/extensions/core/scripts/tests/test-lint-dead-command-recommendations.sh` - explicit mode + declaration (sibling-owned; re-read first)
- `agent-system/extensions/core/scripts/tests/test-lint-directory-pathspec-boundary.sh` - explicit mode + declaration
- `agent-system/extensions/core/scripts/tests/test-lint-extension-readme-table.sh` - explicit mode + declaration
- `agent-system/extensions/core/scripts/tests/test-lint-hook-registration-paths.sh` - explicit mode + declaration
- `agent-system/extensions/core/scripts/tests/test-lint-scoped-commit-boundary.sh` - explicit mode + declaration
- `agent-system/extensions/core/scripts/tests/test-lint-shellcheck.sh` - explicit mode + declaration (the originating case)
- `agent-system/extensions/core/scripts/tests/test-lint-state-writer-boundary.sh` - explicit mode + declaration
- `agent-system/extensions/core/scripts/tests/test-lint-task-lookup-adoption.sh` - explicit mode + declaration
- `agent-system/extensions/core/scripts/tests/test-lint-unit-integration-boundary.sh` - explicit mode + declaration
- `agent-system/extensions/core/scripts/tests/test-lint-verdict-extraction-anchoring.sh` - explicit mode + declaration
- `agent-system/extensions/core/scripts/tests/test-mint-dispatch-seq.sh` - explicit mode + declaration
- `agent-system/extensions/core/scripts/tests/test-postflight-marker-schema.sh` - explicit mode + declaration
- `agent-system/extensions/core/scripts/tests/test-task-type-detect.sh` - explicit mode + declaration
- `agent-system/extensions/core/scripts/tests/test-validate-task-creation-audit.sh` - explicit mode + declaration
- `agent-system/extensions/core/scripts/lint/lint-subject-resolution-declaration.sh` - remove this batch's 20 entries from the allowlist

**Verification**:
- `bash agent-system/extensions/core/scripts/tests/run-all.sh --only <the 20 Group A basenames>`
  exits 0 with every suite's prior verdict unchanged.
- Every one of the 20 suites prints exactly one `[SUBJECT] <absolute path>` line per resolved
  subject, confirmed by grepping the captured output.
- `test-gate-out-derived-staleness.sh` and `test-install-uninstall-extension.sh` declare the
  source-store path, not the deployed one.
- `bash agent-system/extensions/core/scripts/lint/lint-subject-resolution-declaration.sh --verbose`
  exits 0 with the allowlist 20 entries shorter.

---

### Phase 4: Migrate Group B — the 12 Local-Duplicate Suites [COMPLETED]

**Goal**: Delete the 12 hand-duplicated `resolve_candidate` functions and route those suites
through the shared explicit helper with declarations.

**Resume Point**: This phase is the task's resume point. Phases 1-3 are complete, committed, and
re-verified green at revision time; see the revision-time re-verification subsection under
Research Integration. No blocker applies — begin here normally.

**Tasks**:
- [x] Re-derive Group B: *(completed: re-ran `grep -L 'common_test_resolve_candidate' scripts/tests/*.sh | xargs grep -l 'resolve_candidate'` -- confirmed the exact 12-file roster unchanged from plan-authoring time)*
      `grep -L 'common_test_resolve_candidate' scripts/tests/*.sh | xargs grep -l 'resolve_candidate'`.
- [x] For each file: confirm the local function body is a verbatim copy of *(completed: 11 of 12 were verbatim deploy-tree-first or source-store-first copies; test-force-phases.sh's `resolve_inverted` diverged -- source-store-first WITH a deploy fallback, labeled "the documented absent-fallback" -- preserved by migrating to mode=source-store, which is behaviorally equivalent since the suite's own harness-sanity check already fails loudly, exit 2, if resolution ever lands outside the source store)*
      `common_test_resolve_candidate`'s semantics (find-first-existing-candidate) before deleting
      it; if any copy diverges, record the divergence and preserve its behavior explicitly rather
      than assuming equivalence.
- [x] Delete the local function; rewrite each call site as `common_test_resolve_subject` with the *(completed: all 12 local functions (11 `resolve_candidate`, 1 `resolve_inverted`) deleted; every call site migrated with mode reproducing its existing effective order -- deploy-tree-first, source-store, or source-store for the hard-selected callers)*
      mode reproducing its existing effective order; add `common_test_declare_subject`.
- [x] Confirm each file already sources `scripts/lib/common.sh` (all 12 do, for the harness trio); *(completed: confirmed all 12 already sourced it)*
      add the source line if any does not.
- [x] Remove this batch's 12 entries from the lint's Layer-2 allowlist in the same commit. *(completed: Group B section now holds zero migration-pending entries; gate 27 exits 0 with Total violations: 0)*

**Timing**: 1 hour

**Depends on**: 3

**Verification Tier**: local

**Tier Justification**: Each edit is confined to one test suite with no externally visible signature change, and `bash agent-system/extensions/core/scripts/tests/run-all.sh --only <the 12 Group B basenames>` exercises exactly the files this phase touched.

**Scope Hypothesis**: Group B is hypothesized to be these 12 suites, re-derived at plan-authoring time by the `grep -L ... | xargs grep -l resolve_candidate` command above. Re-run it at implementation time and let the measured list govern; it must come out empty for this family once this phase closes.

**Files to modify**:
- `agent-system/extensions/core/scripts/tests/test-force-phases.sh` - drop local function, use shared helper + declaration
- `agent-system/extensions/core/scripts/tests/test-gate-out-repair-reporting.sh` - same
- `agent-system/extensions/core/scripts/tests/test-gate-out-self-attribution.sh` - same
- `agent-system/extensions/core/scripts/tests/test-handoff-reader-parity.sh` - same
- `agent-system/extensions/core/scripts/tests/test-lint-json-channel-discipline.sh` - same
- `agent-system/extensions/core/scripts/tests/test-lint-lifecycle-status-var.sh` - same
- `agent-system/extensions/core/scripts/tests/test-lint-postflight-boundary.sh` - same
- `agent-system/extensions/core/scripts/tests/test-lint-test-harness-adoption.sh` - same
- `agent-system/extensions/core/scripts/tests/test-orchestrate-build-dispatch.sh` - same
- `agent-system/extensions/core/scripts/tests/test-run-task-observers.sh` - same
- `agent-system/extensions/core/scripts/tests/test-skill-base-lifecycle.sh` - same
- `agent-system/extensions/core/scripts/tests/test-todo-move-pair-staging.sh` - same
- `agent-system/extensions/core/scripts/lint/lint-subject-resolution-declaration.sh` - remove this batch's 12 entries from the allowlist

**Verification**:
- `bash agent-system/extensions/core/scripts/tests/run-all.sh --only <the 12 Group B basenames>`
  exits 0 with every suite's prior verdict unchanged.
- `grep -l 'resolve_candidate()' scripts/tests/*.sh` returns nothing (no local duplicate remains).
- Each of the 12 prints its `[SUBJECT]` declaration.
- The lint passes with the allowlist 12 entries shorter.

---

### Phase 5: Migrate Group C Batch 1 — 19 Inline-Loop Suites [NOT STARTED]

**Goal**: Convert the first half of the inline `CANDIDATES`-loop shape — the shape invisible to a
`grep resolve_candidate` measurement — onto the explicit helper.

**Tasks**:
- [ ] Re-derive Group C: suites referencing `$REPO_ROOT/.claude/scripts` with no
      `resolve_candidate` token, minus the three deployed-only-by-design suites.
- [ ] For each file in this batch: read the inline loop, confirm it implements
      find-first-existing-candidate over a deployed/source-store pair, delete the loop and its
      `CANDIDATES` array, and replace with `common_test_resolve_subject` in the mode reproducing
      the array's existing order plus `common_test_declare_subject`.
- [ ] Where a loop ranges over more than two candidates, record the extra candidates and preserve
      the existing order explicitly (the two-candidate signature covers the deployed/source-store
      duality only) — do not silently drop a third candidate.
- [ ] Re-confirm per-file that `test-deploy-root-guard.sh` belongs in the migration family rather
      than the deployed-only exemption set; if its single-copy requirement is by design, move it
      to the permanent exemption list with its reason instead of migrating it.
- [ ] Remove this batch's entries from the lint's Layer-2 allowlist in the same commit.

**Timing**: 1.5 hours

**Depends on**: 4

**Verification Tier**: local

**Tier Justification**: Each edit is confined to one test suite with no externally visible signature change, and `bash agent-system/extensions/core/scripts/tests/run-all.sh --only <this batch's basenames>` exercises exactly the files this phase touched.

**Scope Hypothesis**: This batch is hypothesized to be these 19 of a 38-suite Group C, re-derived at plan-authoring time by the report's Appendix commands and split alphabetically. Re-run the derivation at implementation time; the split is a convenience, and the measured membership governs.

**Files to modify**:
- `agent-system/extensions/core/scripts/tests/test-assess-repo-health.sh` - replace inline loop with explicit helper + declaration
- `agent-system/extensions/core/scripts/tests/test-consumer-freshness.sh` - same
- `agent-system/extensions/core/scripts/tests/test-context-reachability.sh` - same
- `agent-system/extensions/core/scripts/tests/test-corroborate-phase-counts.sh` - same
- `agent-system/extensions/core/scripts/tests/test-deploy-freshness.sh` - same
- `agent-system/extensions/core/scripts/tests/test-deploy-orphans.sh` - same
- `agent-system/extensions/core/scripts/tests/test-deploy-propagation.sh` - same
- `agent-system/extensions/core/scripts/tests/test-deploy-root-guard.sh` - same, or move to the permanent exemption list if single-copy by design
- `agent-system/extensions/core/scripts/tests/test-deploy-verify-wiring.sh` - same
- `agent-system/extensions/core/scripts/tests/test-derived-artifact-probe-lib.sh` - same
- `agent-system/extensions/core/scripts/tests/test-dispatch-metrics.sh` - same
- `agent-system/extensions/core/scripts/tests/test-engine-written-state-paths-lib.sh` - same
- `agent-system/extensions/core/scripts/tests/test-errors-append.sh` - same
- `agent-system/extensions/core/scripts/tests/test-generate-task-order.sh` - same
- `agent-system/extensions/core/scripts/tests/test-index-entries-schema.sh` - same
- `agent-system/extensions/core/scripts/tests/test-issue-record.sh` - same
- `agent-system/extensions/core/scripts/tests/test-manifest-scripts-sync.sh` - same
- `agent-system/extensions/core/scripts/tests/test-orchestrate-conclusion-aggregate.sh` - same
- `agent-system/extensions/core/scripts/tests/test-orchestrate-record-decision.sh` - same
- `agent-system/extensions/core/scripts/lint/lint-subject-resolution-declaration.sh` - remove this batch's entries from the allowlist

**Verification**:
- `bash agent-system/extensions/core/scripts/tests/run-all.sh --only <this batch's basenames>`
  exits 0 with every suite's prior verdict unchanged.
- Each migrated suite prints its `[SUBJECT]` declaration.
- The lint passes with the allowlist shorter by exactly this batch's size.

---

### Phase 6: Migrate Group C Batch 2 — the Remaining 19 Inline-Loop Suites [NOT STARTED]

**Goal**: Finish the inline-loop shape, leaving the lint's allowlist holding nothing but the
permanent, reasoned exemptions.

**Tasks**:
- [ ] Apply Phase 5's per-file procedure to the remaining Group C suites.
- [ ] Remove this batch's entries from the lint's Layer-2 allowlist in the same commit, leaving
      only the permanent exemptions (the three deployed-only suites and the two
      non-subject-resolution `candidate` users).
- [ ] Confirm the allowlist now holds **zero** "not yet migrated" entries, and that every
      remaining entry carries a permanent, reasoned exemption rather than a migration-pending one.

**Timing**: 1.5 hours

**Depends on**: 5

**Verification Tier**: local

**Tier Justification**: Each edit is confined to one test suite with no externally visible signature change, and `bash agent-system/extensions/core/scripts/tests/run-all.sh --only <this batch's basenames>` exercises exactly the files this phase touched.

**Scope Hypothesis**: This batch is hypothesized to be the remaining 19 of Group C. Re-derive Group C at implementation time and take whatever this batch's membership actually is after Phase 5 closed; the alphabetical split is a convenience, not a measurement.

**Files to modify**:
- `agent-system/extensions/core/scripts/tests/test-orchestrate-suggest-next-batch.sh` - replace inline loop with explicit helper + declaration
- `agent-system/extensions/core/scripts/tests/test-phase-heading-patterns.sh` - same
- `agent-system/extensions/core/scripts/tests/test-postflight-deploy-gate.sh` - same
- `agent-system/extensions/core/scripts/tests/test-reconcile-demote-stranded.sh` - same
- `agent-system/extensions/core/scripts/tests/test-reconcile-handoff-status.sh` - same
- `agent-system/extensions/core/scripts/tests/test-record-version-patterns.sh` - same
- `agent-system/extensions/core/scripts/tests/test-redeploy-checkpoint-promotion.sh` - same
- `agent-system/extensions/core/scripts/tests/test-redeploy-remedy-lib.sh` - same
- `agent-system/extensions/core/scripts/tests/test-resume-scan-nonconformance.sh` - same
- `agent-system/extensions/core/scripts/tests/test-return-meta-status-vocabulary.sh` - same
- `agent-system/extensions/core/scripts/tests/test-roadmap-generation.sh` - same
- `agent-system/extensions/core/scripts/tests/test-script-inventory.sh` - same
- `agent-system/extensions/core/scripts/tests/test-status-vocabulary.sh` - same
- `agent-system/extensions/core/scripts/tests/test-sweep-invalidated-claims.sh` - same
- `agent-system/extensions/core/scripts/tests/test-update-plan-status.sh` - same
- `agent-system/extensions/core/scripts/tests/test-validate-artifact.sh` - same
- `agent-system/extensions/core/scripts/tests/test-validate-handoff.sh` - same
- `agent-system/extensions/core/scripts/tests/test-validate-return-meta.sh` - same
- `agent-system/extensions/core/scripts/tests/test-validate-state.sh` - same
- `agent-system/extensions/core/scripts/lint/lint-subject-resolution-declaration.sh` - drain the allowlist to the permanent exemptions only

**Verification**:
- `bash agent-system/extensions/core/scripts/tests/run-all.sh --only <this batch's basenames>`
  exits 0 with every suite's prior verdict unchanged.
- Each migrated suite prints its `[SUBJECT]` declaration.
- The lint's allowlist contains only permanent, reasoned exemptions — no migration-pending entry
  remains.

---

### Phase 7: Correct the Stale Figures and Document the Taxonomy [NOT STARTED]

**Goal**: Replace the stale population figure where it is stated, and document the three-shape
taxonomy, the mode vocabulary, the env override, and the mandatory declaration so the next author
copy-pasting from a neighbour copies the explicit form.

**Tasks**:
- [ ] Correct `context/patterns/batch-orchestration-guardrails.md`'s "of the 73 files under
      agent-system/extensions/core/scripts/tests/, 41 use a documented 'deploy-tree-first /
      source-store-fallback candidate resolution' pattern" sentence to the figures measured at
      implementation time, with the three-shape breakdown.
- [ ] Add one sentence there naming the inline-loop shape explicitly, so a future grep-based
      re-measurement for `resolve_candidate` does not reproduce the undercount.
- [ ] Confirm the Inter-Cycle Redeploy Checkpoint section's rejected-design rationale still reads
      correctly against the new mechanism, and state that the divergence property now rests on the
      **declared default mode** rather than an implicit argument order — without narrating this
      document's own revision history.
- [ ] Extend `context/standards/shell-script-testing.md`'s "Required structural model for a new
      suite" section with: the three-shape taxonomy; `common_test_resolve_subject`'s mode
      vocabulary and the `CORE_TEST_SUBJECT_MODE` precedence rule; the mandatory
      `common_test_declare_subject` call; and the `[SUBJECT]` token's disjointness from the four
      verdict anchors, cross-referenced from that file's own "Verdict-line extraction contract"
      section.
- [ ] Name gate 27 and `lint-subject-resolution-declaration.sh` as the mechanical enforcement, in
      the same shape the verdict-extraction contract names gate 25.
- [ ] Re-read both files immediately before editing: all three tasks in this task's sequencing
      chain also edit `context/standards/shell-script-testing.md`.

**Timing**: 1 hour

**Depends on**: 6

**Verification Tier**: local

**Tier Justification**: Both edits are prose-only in source-store markdown with no executable surface, covered by `bash .claude/scripts/verify-deploy.sh --skip-slow --only-gate 3,4 "$(git rev-parse --show-toplevel)"` (doc-lint and task-reference lint, with the repository root as TARGET so neither gate SKIPs) plus a diff read-through.

**Scope Hypothesis**: This phase asserts that the stale sentence still reads "73 files ... 41 use" in `context/patterns/batch-orchestration-guardrails.md`. Grep for it before editing; if a sibling has already changed it, correct whatever is actually there to the figures measured in this task rather than applying a prepared replacement.

**Files to modify**:
- `agent-system/extensions/core/context/patterns/batch-orchestration-guardrails.md` - correct the stale population figure; name the inline-loop shape
- `agent-system/extensions/core/context/standards/shell-script-testing.md` - document the taxonomy, mode vocabulary, env override, mandatory declaration, and gate 27

**Verification**:
- `bash .claude/scripts/verify-deploy.sh --skip-slow --only-gate 3,4 "$(git rev-parse --show-toplevel)"`
  exits 0 with neither gate reporting SKIP.
- No task-number reference and no record-versioning language appears in either edited file
  (`bash .claude/scripts/check-task-references.sh` and
  `bash .claude/scripts/check-record-versioning.sh` clean for both paths, exit status checked).
- Grepping the two corrected documents for the strings `73 files` and ` 41 ` finds no surviving
  stale figure.

---

### Phase 8: Redeploy and Full Gate Set [NOT STARTED]

**Goal**: Regenerate the deployed tree from the source store and discharge the complete gate set
with an explicit source-store TARGET.

**Tasks**:
- [ ] Redeploy: `timeout 540 bash .claude/scripts/deploy-headless.sh` (Bash tool `timeout`
      parameter raised to 600000, per the bounded-wait idiom).
- [ ] Run the complete gate set with an explicit TARGET:
      `bash .claude/scripts/verify-deploy.sh "$(git rev-parse --show-toplevel)"`. The bare form is
      not acceptable here — an explicit source-store TARGET is required so the source-store-only
      gates (including the new gate 27) do not silently SKIP.
- [ ] Confirm gate 27 runs and passes against the freshly-deployed tree.
- [ ] Confirm Gate 8 reports every migrated suite's prior verdict unchanged on the fresh tree, and
      that every migrated suite's `[SUBJECT]` line now names the **deployed** copy where its mode
      is `deployed` or `deploy-tree-first` — the post-redeploy half of the divergence property.
- [ ] Attribute nothing to this work from the known-unrelated pre-existing failures list (Gate 3
      lean4 doc-lint index.json entry, Gate 20 eager-load budget, Gate 8
      `test-detect-noop-bash.sh` / `test-four-tier-conflict.sh` / `test-guard-git-push.sh`), and do
      not fix them here. Record each observed occurrence as pre-existing in the phase notes.

**Timing**: 1 hour

**Depends on**: 7

**Verification Tier**: full

**Files to modify**:
- `__WHOLE_TREE__` - this phase regenerates the entire deployed tree via `deploy-headless.sh`

**Verification**:
- `bash .claude/scripts/verify-deploy.sh "$(git rev-parse --show-toplevel)"` — the complete gate
  set, every gate, with an explicit source-store TARGET — reports no new failures beyond the
  enumerated known-unrelated pre-existing ones.
- Gate 27 appears in the output as RUN (never SKIP) and passes.
- Gate 8's full battery passes for every migrated suite, with each suite's verdict identical to
  its pre-migration verdict.
- `grep -c '\[SUBJECT\]'` over a captured Gate 8 run confirms a declaration line from every suite
  in the migrated family.

## Testing & Validation

- [ ] Every selector mode resolves the copy it names, proven against two deliberately DIFFERENT
      copies of a subject (source-store passes / deployed fails, and the mirror image) — not two
      identical copies.
- [ ] The declaration line names the path actually used, including under the fallback branch.
- [ ] The deploy-tree-first mode still resolves the deployed copy, so an Inter-Cycle Redeploy
      Checkpoint pre/post pair still diverges when the deployed copy is stale.
- [ ] A deliberately-seeded violation of the new gate-27 lint, introduced in a fixture tree rather
      than the live tree, is detected (non-zero exit status, `[VIOLATION]` row naming the file).
- [ ] An allowlisted file is not flagged, and the allowlist drains to the permanent exemptions
      only.
- [ ] Every migrated suite produces its prior verdict on an unchanged, freshly-deployed tree.
- [ ] `lint-gate-registry.sh` accepts the gate-27 row (Checks A-G).
- [ ] The complete gate set passes with an explicit source-store TARGET.

## Artifacts & Outputs

- `agent-system/extensions/core/scripts/lib/common.sh` — `common_test_resolve_subject`,
  `common_test_declare_subject`
- `agent-system/extensions/core/scripts/lint/lint-subject-resolution-declaration.sh` — gate-27
  content lint with a drained, reasoned exemption list
- `agent-system/extensions/core/scripts/tests/test-lint-subject-resolution-declaration.sh` — its
  seeded-violation suite
- Gate-27 row in `agent-system/extensions/core/scripts/gate-registry.data`; `gate27_run` in
  `agent-system/extensions/core/scripts/verify-deploy.sh`; both scripts registered in
  `manifest.json`
- 70 migrated suites under `agent-system/extensions/core/scripts/tests/`, each declaring its
  subject
- Corrected figures and documented taxonomy in
  `context/patterns/batch-orchestration-guardrails.md` and
  `context/standards/shell-script-testing.md`
- A redeployed `.claude/` tree
- `specs/418_explicit_lint_fixture_test_subject_resolution/summaries/01_explicit-subject-resolution-summary.md`

## Rollback/Contingency

- The work is additive up to Phase 3: Phases 1-2 add two new library functions and one new gate
  without touching any existing call site, so a revert of those commits restores the prior state
  exactly.
- Each migration batch (Phases 3-6) is its own commit with its own `run-all.sh --only`
  verification, so a batch that changes a suite's verdict is revertible in isolation without
  unwinding the library or the lint.
- Before Phase 3 and before Phase 5, take a defensive checkpoint with
  `bash .claude/scripts/git-snapshot.sh 418 --no-revert` — the non-reverting form, never the
  reverting default.
- If a migration batch cannot preserve a suite's verdict, stop that batch, leave the affected
  files on the lint's allowlist with a reason naming the specific blocker, and report the
  remainder as a `[COMPLETED WITH EXCLUSIONS]` phase with a `#### Reasoned Exclusions` record —
  rather than forcing a behavior change this task's own verification bar forbids.
- If sibling task 512 has `test-lint-dead-command-recommendations.sh` in flight, leave that one
  file on the allowlist with that reason and migrate it in a follow-up round rather than editing
  over a concurrent writer.
- If a dispatch ends with phases still outstanding, report `status: partial` with
  `continuation_path` naming the next unstarted phase and with `blockers[]` holding only
  conditions that genuinely prevent progress. A resolved retrospective note placed in `blockers[]`
  is read by the triage classifier as a live blocker and hard-blocks the remaining phases; that is
  precisely what stalled this task once already.
