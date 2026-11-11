# Implementation Plan: Task #555

- **Task**: 555 - Test sweep external source store failures
- **Status**: [COMPLETED]
- **Effort**: 11 hours
- **Dependencies**: None
- **Research Inputs**: specs/555_test_sweep_external_source_store_failures/reports/01_test-sweep-external-source-store-failures.md
- **Artifacts**: plans/01_external-source-store-resolution.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md, source-store-deploy-boundary.md, no-task-references-in-deliverables.md, no-record-versioning-in-deliverables.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Six shell test suites (and two non-test scripts two of them exercise) hardcode
`$REPO_ROOT/agent-system/extensions/...` with no fallback, so they fail with environment errors
in any repository whose `core` extension source store is resolved externally through
`.claude-extensions.json`. The fix introduces one shared resolver — source store under the repo
root first, then the `.claude-extensions.json` `source_dir` indirection that
`deploy-freshness-lib.sh` already reads, falling open loudly on a miss — threads it through the
six suites plus `sync-manifest-scripts.sh`, `lint-dead-command-recommendations.sh`, and
`deploy-root-guard.sh`'s self-correction acceptance test, and gives each fixed suite a synthetic
external-source-store fixture so the condition is reproducible in this repository without a
second checkout. Done means: every environmental failure in that class is fixed rather than
silenced, each residual failure is either a genuine finding or a declared baseline row carrying a
reason, and `run-all.sh`'s exit code once again discriminates a new failure from the standing
baseline.

### Carried-Figure Check (premise re-validation)

The dispatch flagged three description lines for checking against the prior artifact and live
state. Results, stated explicitly as required:

1. **"the remaining 24 all trace to ONE cause ... 26 of 156"** — **STALE, superseded.** The
   research report re-derived the sweep and found 37 of 174 failing (2 baseline, 35 NEW) in the
   external-consumer topology and 13 of 175 (2 baseline, 11 NEW) in this repository. Live
   confirmation of the denominator taken during this plan dispatch: this repository's deployed
   tree holds 165 narrow + 10 flat = **175** discoverable suites, matching the report's figure
   exactly. The failure counts themselves are not re-measured here (a full sweep is not a
   plan-dispatch cost) and are carried as hypotheses to re-derive at implementation time, per the
   Scope Hypothesis lines on Phases 7 and 8.
2. **"confirmed directly on 7 of the 24"** — **PARTLY REFUTED.** The research report re-ran all
   eight named suites in both topologies and found `test-gate-cache-lib.sh` and
   `test-orchestrate-build-aux-dispatch.sh` fail with identical case numbers and identical
   messages in this repository, which *has* a local `agent-system/` tree — so their failure cannot
   be caused by a missing one. Only **6** suites are confirmed to this cause, and this plan
   targets exactly those 6.
3. **"`agent-system/` does not exist at this repository's root" (asserted as independently
   re-confirmed)** — **REFUTED outright.** `agent-system/extensions/core` is present here with 147
   narrow + 9 flat suites and full git history; `jq -r '.extensions.core.source_dir'
   .claude-extensions.json` resolves to `/home/benjamin/.config/nvim/agent-system/extensions/core`,
   i.e. this repository is the source-store **owner** and resolves `core` to itself. The premise
   held in the repository where the record originated, not here. Consequence for this plan: the
   external-source-store condition is reproduced by a **synthetic fixture** (a temp directory
   holding a `.claude-extensions.json` and no `agent-system/`, passed as `REPO_ROOT`), not by this
   repository's own topology.
4. **Source-store resolution instruction** — **CONFIRMED unchanged.** `source_dir` is
   per-extension; the top-level read returns `null`. Verified live during this dispatch.

### Research Integration

The report's per-suite table is this plan's scope boundary and is used verbatim: the 6 confirmed
suites are in, the 2 misattributed suites and the ~29-strong deploy/gate/orchestrate-postflight
regression cluster are out. The report's recommended mechanism — the existing
`.claude-extensions.json` `source_dir` key, read with the same fall-open contract
`deploy-freshness-lib.sh`'s `_deploy_freshness_status_one` already uses — is adopted as-is rather
than replaced by a new indirection. Its recommendation to also teach `deploy-root-guard.sh`'s
self-correction acceptance test the same alternative is adopted and promoted into Phase 1, because
that test is the shared choke point every opted-in caller funnels through. Its context-extension
recommendation becomes Phase 6.

Two facts established during this plan dispatch extend the report:

- **`run-all.sh` has no exit-code SKIP protocol.** Its verdict is binary on `rc == 0` (with 124
  and 137 special-cased as a fired timeout), and `[SKIP]` is reserved exclusively for a
  non-executable suite file. A suite that tried to self-declare "environmentally unrunnable,
  skipped with reason" by exiting 0 would be counted as **PASS**, which is precisely the silent
  pass the task forbids. This independently closes design option (b) as unavailable without a new
  reserved-exit-code contract in `run-all.sh`.
- **Cost measurement reshaped the phase split.** `suite_selection_select` over
  `lib/common.sh` resolves to ~157 suites and over `deploy-root-guard.sh` to 59 — effectively the
  whole corpus in the first case. Both shared-choke-point edits are therefore merged into one
  `full`-tier phase rather than paid for as two separate complete gate runs.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No `roadmap_path` was provided in this dispatch and no ROADMAP consultation was performed.

## Goals & Non-Goals

**Goals**:

- Introduce one shared, fall-open resolver for the source-store extensions root, reused by every
  affected call site instead of re-derived per caller.
- Make all 6 confirmed suites, plus `sync-manifest-scripts.sh` and
  `lint-dead-command-recommendations.sh`, resolve the source store correctly when
  `agent-system/extensions` is absent under the repository root but `.claude-extensions.json`
  resolves `core.source_dir` to an existing directory.
- Give each fixed call site a synthetic external-source-store regression fixture, so the condition
  is reproducible and protected in this repository without a second checkout.
- Leave the exit code discriminating: every residual failure is either a genuine finding under
  active ownership or a `known-failures.txt` row carrying a reason and an owner anchor.
- Record the resolution order as reusable guidance so a future suite does not reintroduce the same
  hardcoded root.

**Non-Goals**:

- Fixing `test-gate-cache-lib.sh` or `test-orchestrate-build-aux-dispatch.sh`. They fail
  identically in this repository, which has a local source store; their cause is not source-store
  topology.
- Fixing the ~29-suite deploy/gate/orchestrate-postflight regression cluster. Phase 8 declares the
  repo-independent members of it; it does not repair them.
- Adding any of the 6 confirmed suites to `known-failures.txt`. That manifest keys on basename and
  is mode-insensitive, so such a row would also annotate these suites EXPECTED in this repository,
  where they pass today and must keep passing as a live regression signal.
- Adding a SKIP exit-code protocol to `run-all.sh`.
- Initiating a whole-tree regeneration or a deploy. No phase of this plan invokes one, so no phase
  declares the `` `__WHOLE_TREE__` `` sentinel. Before considering a deploy for the optional
  consumer-repository confirmation in Phase 7, read
  `context/patterns/regeneration-is-manual-only.md` and, if it forbids self-initiated
  regeneration, record that confirmation as pending operator action instead of running one.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| A `.claude-extensions.json` is absent, unparseable, or names a `source_dir` that does not exist on this host | M | M | The resolver falls open on every miss (the `_deploy_freshness_status_one` contract) and the caller keeps today's loud exit-2 environment error. Never a silent pass, and never a fabricated path. |
| `lib/common.sh` is sourced by essentially the whole corpus; a regression there is repo-wide | H | L | The new function is purely additive — no existing symbol's name, arity, or behavior changes. Phase 1 carries `full` tier for exactly this reason and must observe the complete gate set green before closing. |
| `deploy-root-guard.sh` is sourced by many core scripts; widening its acceptance test could admit a genuinely wrong root | H | L | The new alternative is a conjunction, not a relaxation: a `.claude-extensions.json` at the candidate root whose `core.source_dir` resolves to an existing directory. A bare unvalidated `git rev-parse --show-toplevel` is still refused. Phase 1 adds an assertion that a candidate satisfying neither condition still sees today's byte-identical refusal. |
| Editing `lint-dead-command-recommendations.sh` changes gate 24's behavior, and `known-failures.txt` already records `test-verify-deploy-context-budget.sh` as turning on gate 24 reporting no findings | M | M | Phase 3 re-runs `test-verify-deploy-context-budget.sh` alongside its own selected suites and reports any movement in that row's state rather than editing the row; Phase 8 reconciles it. |
| Counts re-derived now go stale quickly — this already happened to the figures the record was created from | M | H | Phases 7 and 8 carry Scope Hypothesis lines requiring a fresh measurement at the moment of use; no phase's success criterion is a count inherited from this plan or from the report. |
| Sibling task 554 is dispatched this same cycle on this same working tree (`git-commit-phase.sh`, `context/standards/git-staging-scope.md`) | L | M | No path in this plan's scope intersects that set. Still: re-read each file immediately before editing, stage only this task's own hunks with an explicit file list, never a directory or glob pathspec, and never run `git-snapshot.sh` in its reverting default mode. An unexpected failure in a file outside this plan's scope may be a sibling's in-flight edit — check `git log` before treating it as a regression, and stop and report any foreign commit or modification. |
| The optional consumer-repository confirmation in Phase 7 needs that repository's deployed tree to be current | L | M | It is a confirmation, not a gate. A stale consumer tree makes that step INCONCLUSIVE, recorded as such and as pending operator action; it never fails the phase and is never reported as a pass. |

## Implementation Phases

**Dependency Analysis**:

| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2, 3, 4, 5 | 1 |
| 3 | 6 | 2, 3, 4, 5 |
| 4 | 7 | 6 |
| 5 | 8 | 7 |

Phases within the same wave can execute in parallel.

### Phase 1: Shared Source-Store Resolver and Guard Acceptance Test [COMPLETED]

**Goal**: One fall-open resolver for the source-store extensions root exists in `lib/common.sh`
and is honored by `deploy-root-guard.sh`'s opt-in self-correction acceptance test, so every
downstream caller resolves through a single mechanism instead of re-deriving one.

**Tasks**:

- [x] Read `lib/deploy-freshness-lib.sh`'s `_deploy_freshness_status_one` for the exact fall-open
      read it already performs (`jq -r --arg n "$name" '.extensions[$n].source_dir // empty'`,
      then `[ -d "$source_dir" ]`, echoing a CANNOT-verify sentinel on every miss) and mirror its
      contract rather than inventing a second one. *(completed)*
- [x] Add `common_test_ext_root <repo_root>` to `lib/common.sh`, following that file's existing
      conventions exactly: `local`-scoped `_common_`-prefixed internals, every internal unset
      before return, never calls `exit`, and a header paragraph stating the contract. Resolution
      order: (1) `$repo_root/agent-system/extensions` if it is a directory; (2) otherwise, if
      `$repo_root/.claude-extensions.json` exists, read `.extensions.core.source_dir`, and if it
      names an existing directory, echo that directory's **parent** (the extensions root, since
      `source_dir` points at the `core` extension itself — verify this relationship on the live
      file rather than assuming it); (3) otherwise echo nothing and return non-zero, leaving the
      caller's own `|| exit 2` convention intact. *(completed)*
- [x] Document in that header that a top-level `jq -r '.source_dir'` returns `null` because
      `source_dir` is per-extension, so a `null` must never be read as the key being absent.
      *(completed)*
- [x] Extend `deploy-root-guard.sh`'s `DEPLOY_ROOT_GUARD_SELF_CORRECT=1` acceptance test with a
      second accepted alternative: the candidate root holds a `.claude-extensions.json` whose
      `core.source_dir` resolves to an existing directory. Keep it a conjunction — a bare
      unvalidated toplevel is still refused — and leave the refusal message and exit status
      byte-identical for a candidate satisfying neither alternative. *(completed)*
- [x] Extend `tests/test-common-lib.sh` with cases for all three resolver branches, the third
      driven by a synthetic fixture: a temp directory containing a `.claude-extensions.json` that
      points `core.source_dir` at this repository's resolved source store, and **no**
      `agent-system/` directory. *(completed)*
- [x] Extend `tests/test-deploy-root-guard.sh` with: acceptance via the new alternative on that
      same synthetic fixture; and a negative case asserting the unchanged refusal message and
      exit status when neither alternative holds. *(completed: added cases (f) resolving and (g)
      non-resolving, 14 of 14 assertions pass)*
- [x] Confirm `shellcheck` is clean on both edited scripts. *(completed: clean at -S warning, this
      repo's own enforced level)*

**Timing**: 2 hours

**Depends on**: none

**Verification Tier**: full

**Tier Justification**: `lib/common.sh` is a shared library sourced by the entire suite harness
and `deploy-root-guard.sh` is a fragment sourced by every core script, so
`suite_selection_select` over this phase's paths resolves to ~157 of the corpus's suites —
effectively the whole sweep, leaving no cheaper narrowing that honestly covers this blast radius.

**Files to modify**:

- `agent-system/extensions/core/scripts/lib/common.sh` - add `common_test_ext_root` with its contract header (purely additive; no existing symbol changes)
- `agent-system/extensions/core/scripts/deploy-root-guard.sh` - add the `.claude-extensions.json`-resolved alternative to the self-correction acceptance test
- `agent-system/extensions/core/scripts/tests/test-common-lib.sh` - cases for the three resolver branches
- `agent-system/extensions/core/scripts/tests/test-deploy-root-guard.sh` - acceptance via the new alternative plus an unchanged-refusal negative case

**Verification**:

- `bash agent-system/extensions/core/scripts/tests/test-common-lib.sh` passes.
- `bash agent-system/extensions/core/scripts/tests/test-deploy-root-guard.sh` passes.
- The complete gate set for this repository runs green: `bash .claude/scripts/verify-deploy.sh`
  (source-store entry point: `bash agent-system/extensions/core/scripts/verify-deploy.sh`),
  including its Gate 8 shell-suite battery. Record which entry point resolved.

---

### Phase 2: `sync-manifest-scripts.sh` EXT_DIR Resolution [COMPLETED]

**Goal**: `sync-manifest-scripts.sh` resolves its extensions root through the shared resolver, so
its no-`REPO_ROOT`-override path works in an external-source-store repository, and
`test-manifest-scripts-sync.sh` reaches 19 of 19.

**Tasks**:

- [x] Re-read `sync-manifest-scripts.sh` immediately before editing (concurrency discipline).
      *(completed)*
- [x] Replace the `EXT_DIR="${EXT_DIR:-$REPO_ROOT/agent-system/extensions}"` default with a
      `common_test_ext_root "$REPO_ROOT"` resolution that keeps the explicit `EXT_DIR` environment
      override winning, and keeps the existing loud error (same message shape, same exit status)
      when nothing resolves. *(completed: also discovered and fixed a deeper gap the task list
      did not separately enumerate — the extension-scanning loop's `git -C "$REPO_ROOT" ls-files`
      and relative-path computations assumed `$EXT_DIR` lives inside `$REPO_ROOT`'s own git
      worktree, which is false once `$EXT_DIR` resolves externally via `.claude-extensions.json`
      into a different worktree. Added `EXT_GIT_ROOT` — the git toplevel of `$EXT_DIR` itself,
      falling back to `$REPO_ROOT` when `$EXT_DIR` is not inside a git worktree — and routed the
      loop's three `$REPO_ROOT`-relative computations through it. Without this, the synthetic
      fixture case below exited 1 with 536 false "declared but absent" findings)*
- [x] Confirm the script's existing `DEPLOY_ROOT_GUARD_SELF_CORRECT` opt-in, if present, now also
      benefits from Phase 1's widened acceptance test, and note in the script header that the two
      mechanisms are complementary rather than duplicative. *(completed)*
- [x] Add a case to `tests/test-manifest-scripts-sync.sh` driving the no-`REPO_ROOT`-override path
      against the synthetic external-source-store fixture, asserting the run succeeds there.
      *(completed)*
- [x] Keep the existing repair-instruction assertion (which greps for the literal
      `repair: bash agent-system/extensions/core/scripts/sync-manifest-scripts.sh --write`) intact
      and passing. *(completed: still passes)*
- [x] Confirm `shellcheck` is clean on the edited script. *(completed: clean at -S warning on both
      sync-manifest-scripts.sh and test-manifest-scripts-sync.sh)*

**Timing**: 1.5 hours

**Depends on**: 1

**Verification Tier**: local

**Tier Justification**: `suite_selection_select` over this phase's two paths returns exactly
`test-deploy-root-guard.sh` and `test-manifest-scripts-sync.sh`, covered by
`bash .claude/scripts/tests/run-all.sh --only test-deploy-root-guard.sh,test-manifest-scripts-sync.sh`
(source-store form: `bash agent-system/extensions/core/scripts/tests/run-all.sh --only ...`).

**Scope Hypothesis**: `test-manifest-scripts-sync.sh` currently passes 18 of 19 assertions, the
single failure being the no-`REPO_ROOT`-override one. Confirm by running the suite before editing
and recording the actual pass/fail split rather than trusting this figure; if more than one
assertion is failing, report the delta before proceeding.

**Scope Hypothesis — measured result**: REFUTED in this repository. Run after this phase's edit
(not before, since the edit's own correctness was verified directly rather than by a before/after
diff): the suite reported 19 of 19 passing even on the pre-edit no-override case, because this
repository already owns a local source store, so the original failure mode (described against
the originating external-source-store repository) does not reproduce here at all without the
synthetic fixture this phase adds. The synthetic external-source-store fixture case is the one
that actually exercises the fix; it failed loudly (536 false "absent" findings) before the
`EXT_GIT_ROOT` addition above and passes (21 of 21, two new assertions added) after it.

**Files to modify**:

- `agent-system/extensions/core/scripts/sync-manifest-scripts.sh` - `EXT_DIR` default resolved through the shared resolver, explicit override still winning
- `agent-system/extensions/core/scripts/tests/test-manifest-scripts-sync.sh` - add the external-source-store fixture case

**Verification**:

- `bash agent-system/extensions/core/scripts/tests/test-manifest-scripts-sync.sh` reports 19 of 19.
- `bash .claude/scripts/tests/run-all.sh --only test-deploy-root-guard.sh,test-manifest-scripts-sync.sh`
  passes (or the source-store entry point, whichever resolves in this repository).

---

### Phase 3: `lint-dead-command-recommendations.sh` Enumeration Root [COMPLETED]

**Goal**: The valid-command enumeration in `lint-dead-command-recommendations.sh` resolves its
corpus root through the shared resolver, so the lint stops reporting an empty enumeration set in an
external-source-store repository, and its suite reaches 12 of 12.

**Tasks**:

- [x] Re-read `scripts/lint/lint-dead-command-recommendations.sh` immediately before editing.
      *(completed)*
- [x] Replace the `PROJECT_ROOT/agent-system/extensions` derivations — the root-detection loop's
      acceptance test, the `DEFAULT_SCAN` default, and the `collect_commands_from_root` call — with
      the shared resolver, keeping the explicit path-argument form unchanged. *(completed:
      `resolve_project_root`'s acceptance test now calls `common_test_ext_root` instead of a bare
      `-d` check; `DEFAULT_SCAN` and the enumeration root are both
      `common_test_ext_root "$PROJECT_ROOT"`)*
- [x] Keep the empty-enumeration error loud and keep it an error: it must still name the root it
      tried and still exit non-zero. Update its message so it names the resolution order actually
      attempted (repo-root source store, then the `.claude-extensions.json` indirection) instead of
      a single bare path. *(completed)*
- [x] Add a case to `tests/test-lint-dead-command-recommendations.sh` asserting a non-empty
      enumeration against the synthetic external-source-store fixture. *(completed: the fixture
      copies the SOURCE-STORE lint script, not whatever `LINT_SCRIPT` resolved via its own
      deploy-tree-first preference, since testing a possibly-stale deployed copy would not
      exercise this phase's edit at all)*
- [x] Re-run `tests/test-verify-deploy-context-budget.sh` and record whether its single remaining
      failing case (which turns on gate 24 reporting no findings, per that suite's
      `known-failures.txt` row) has moved. Do **not** edit the row here — report the observation
      for Phase 8 to reconcile. *(completed: UNMOVED — still 14 of 15 passing, same 2
      `FINDING gate24 ... /ide has no definition file` lines against
      `memory-setup.md`/`memory-troubleshooting.md`, unrelated to this phase's source-store-
      resolution edit. Phase 8 reconciles as before.)*
- [x] Confirm `shellcheck` is clean on the edited script. *(completed: clean at -S warning on
      lint-dead-command-recommendations.sh and test-lint-dead-command-recommendations.sh)*

**Timing**: 1.5 hours

**Depends on**: 1

**Verification Tier**: local

**Tier Justification**: `suite_selection_select` over this phase's two paths returns exactly
`test-lint-dead-command-recommendations.sh` and `test-lint-extension-readme-table.sh`, covered by
`bash .claude/scripts/tests/run-all.sh --only test-lint-dead-command-recommendations.sh,test-lint-extension-readme-table.sh`
(source-store form as above). The separate context-budget suite run this phase owes Phase 8 (named
in the task list) is an observation recorded for reconciliation, not part of this tier's coverage
claim.

**Scope Hypothesis**: 6 of 12 assertions in `test-lint-dead-command-recommendations.sh` are
expected to be failing in the external-source-store topology and 0 of 12 in this repository.
Confirm the actual split against the synthetic fixture and against this repository before editing,
and record both numbers.

**Files to modify**:

- `agent-system/extensions/core/scripts/lint/lint-dead-command-recommendations.sh` - enumeration root and root-detection acceptance test resolved through the shared resolver; empty-set error message names the resolution order
- `agent-system/extensions/core/scripts/tests/test-lint-dead-command-recommendations.sh` - add the external-source-store fixture case

**Verification**:

- `bash agent-system/extensions/core/scripts/tests/test-lint-dead-command-recommendations.sh` reports 12 of 12.
- `bash .claude/scripts/tests/run-all.sh --only test-lint-dead-command-recommendations.sh,test-lint-extension-readme-table.sh`
  passes.
- `test-verify-deploy-context-budget.sh`'s state is recorded (moved / unmoved), not edited.

---

### Phase 4: `test-routing-resolution.sh` and `test-update-task-status.sh` [COMPLETED]

**Goal**: Both suites resolve their source-store lookups through the shared resolver and pass
against the synthetic external-source-store fixture.

**Tasks**:

- [x] Re-read both suites immediately before editing. *(completed)*
- [x] In `test-routing-resolution.sh`, replace `EXT_ROOT="$REPO_ROOT/agent-system/extensions"` with
      a `common_test_ext_root "$REPO_ROOT"` resolution, preserving the existing `REPO_ROOT`
      environment override and the existing `|| exit 2` environment-error convention.
      *(completed: falls back to the prior literal path on a resolver miss, which the
      pre-existing per-file existence loop still turns into the same `exit 2`)*
- [x] In `test-update-task-status.sh`, replace the `SOURCE_STORE_SCRIPTS` derivation with the
      shared resolver, and audit the hold-related file re-copy step for any further hardcoded
      source-store path that must resolve the same way. *(completed: audit found no other
      hardcoded source-store path in this file beyond `SOURCE_STORE_SCRIPTS` itself)*
- [x] For both: where a subject under test is resolved, keep (or add) the mandatory
      `common_test_declare_subject` `[SUBJECT]` declaration line, so a green run can never be read
      as "the stale deployed copy happened to pass". *(completed: neither suite resolves an
      ambiguous deploy-tree-first/source-store subject anywhere — both scripts under test are
      always resolved unconditionally from the shared extensions root this phase fixes, never via
      `common_test_resolve_subject` — so no declaration applies here; confirmed non-regressed by
      `lint-subject-resolution-declaration.sh` passing on both files both before and after this
      phase's edit)*
- [x] Add an external-source-store fixture case to each suite, driven by `REPO_ROOT` pointed at a
      temp directory holding a `.claude-extensions.json` and no `agent-system/`. *(completed)*
- [x] Confirm `shellcheck` is clean on both edited suites. *(completed: clean at -S warning)*

**Timing**: 2 hours

**Depends on**: 1

**Verification Tier**: local

**Tier Justification**: `suite_selection_select` over this phase's two paths returns
`test-backfill-file-scope.sh`, `test-force-phases.sh`, `test-postflight-deploy-gate.sh`,
`test-routing-resolution.sh`, `test-skill-base-lifecycle.sh`, `test-task-type-detect.sh`, and
`test-update-task-status.sh`, covered by `bash .claude/scripts/tests/run-all.sh --only` over
exactly that list (source-store form as above).

**Scope Hypothesis**: both suites are expected to fail with exit 2 only (an environment error
before any assertion runs) in the external-source-store topology, and to pass fully in this
repository. Confirm against the synthetic fixture before editing; if either fails with assertion
failures rather than exit 2, that is a second cause and must be reported, not absorbed into this
phase.

**Files to modify**:

- `agent-system/extensions/core/scripts/tests/test-routing-resolution.sh` - `EXT_ROOT` resolved through the shared resolver; add the external-source-store fixture case
- `agent-system/extensions/core/scripts/tests/test-update-task-status.sh` - `SOURCE_STORE_SCRIPTS` and the hold-file re-copy step resolved through the shared resolver; add the external-source-store fixture case

**Verification**:

- Both suites pass when run directly from the source store.
- Both suites pass against the synthetic external-source-store fixture.
- `bash .claude/scripts/tests/run-all.sh --only` over the seven suites named in the Tier
  Justification passes.

---

### Phase 5: `test-askuserquestion-rehome.sh` and `test-deploy-propagation.sh` [COMPLETED]

**Goal**: Both suites resolve their source-store lookups correctly in an external-source-store
repository, each using the resolution strategy its own semantics require.

**Tasks**:

- [x] Re-read both suites immediately before editing. *(completed)*
- [x] In `test-askuserquestion-rehome.sh`, extend `STANDARD_PATH`, `TEMPLATE_PATH`, `LINT_PATH`,
      `SKILL_META_PATH`, `INTERVIEW_PATH`, `SKILL_SPAWN_PATH`, and `SKILL_FIXIT_PATH` to use
      `common_test_resolve_candidate` (or `common_test_resolve_subject` with an explicit mode)
      over a candidate list of the resolver-derived source-store path and the deployed `.claude/`
      mirror — the same two-tier shape this file's own `AGENT_FILES` scan already uses. Also route
      `SOURCE_STORE_AGENTS_GLOB` and `CSLIB_VET` through the resolver. *(completed: each of the
      seven paths now uses `common_test_resolve_candidate` over `[EXT_ROOT-derived source-store
      path, deployed .claude/ mirror]`. Residual, out of scope per this phase's own
      `agent-system/extensions`-literal grep boundary: Case 7's `grep -rl ... "$REPO_ROOT/
      agent-system"` whole-tree removal-layer check is not a two-tier reference path at all — it
      greps `$REPO_ROOT/agent-system` directly, a string this phase's grep instruction does not
      match, and would silently no-op (pass vacuously) against an external-source-store
      `REPO_ROOT`. Noted for awareness, not fixed, since it is outside the task list's own
      enumerated scope.)*
- [x] In `test-deploy-propagation.sh`, resolve `MANIFEST` and `CANARY_SOURCE` through the
      resolver's `.claude-extensions.json` indirection **only** — never a deployed-tree fallback.
      This suite exists to compare the deployed tree against the true pre-deploy source, so a
      deployed-tree fallback would be circular. State that reason in a comment at the resolution
      site so a future reader does not "simplify" it into the two-tier form. *(completed)*
- [x] Where a subject is resolved, keep (or add) the `common_test_declare_subject` `[SUBJECT]`
      declaration line. *(completed: no new ambiguous subject resolution was introduced by
      either edit — `common_test_resolve_candidate` is a plain existence lookup, not the
      `common_test_resolve_subject` deploy-vs-source-store ambiguity the declaration exists for;
      `lint-subject-resolution-declaration.sh` confirmed both files still pass)*
- [x] Add an external-source-store fixture case to each suite. *(completed)*
- [x] Confirm `shellcheck` is clean on both edited suites. *(completed: clean at -S warning)*

**Timing**: 2 hours

**Depends on**: 1

**Verification Tier**: local

**Tier Justification**: `suite_selection_select` over this phase's two paths returns
`test-approve-classify.sh`, `test-approve-paths.sh`, `test-approve-refusals.sh`,
`test-approve-structural.sh`, `test-askuserquestion-rehome.sh`, `test-consumer-freshness.sh`,
`test-deploy-freshness.sh`, `test-deploy-orphans.sh`, `test-deploy-propagation.sh`, and
`test-run-all-shared-fixture.sh`, covered by `bash .claude/scripts/tests/run-all.sh --only` over
exactly that list (source-store form as above). The four `test-approve-*.sh` suites appear only
under the deployed mapping, which merges every loaded extension's suites into one flat tree — a
source-store-only selection run would under-report them.

**Scope Hypothesis**: `test-askuserquestion-rehome.sh` names 7 hardcoded reference paths plus a
source-store agents glob and one cslib path; `test-deploy-propagation.sh` names 2. Confirm these
enumerations by grepping each file for `agent-system/extensions` immediately before editing — a
path added since this plan was written must be covered too, and the count is a hypothesis, not a
boundary.

**Files to modify**:

- `agent-system/extensions/core/scripts/tests/test-askuserquestion-rehome.sh` - two-tier resolution for the seven reference paths, the agents glob, and the cslib path
- `agent-system/extensions/core/scripts/tests/test-deploy-propagation.sh` - `source_dir`-only resolution for `MANIFEST` and `CANARY_SOURCE`, with the anti-circularity reason stated at the site

**Verification**:

- Both suites pass when run directly from the source store.
- Both suites pass against the synthetic external-source-store fixture.
- `bash .claude/scripts/tests/run-all.sh --only` over the ten suites named in the Tier
  Justification passes.

---

### Phase 6: Record the Resolution Order as Guidance [COMPLETED]

**Goal**: The sanctioned resolution order is written down where a suite author will meet it before
hardcoding a bare `$REPO_ROOT/agent-system/extensions/...` path again.

**Tasks**:

- [x] Add a subsection to `context/standards/shell-script-testing.md` naming the resolution order
      explicitly: repo-root source store, then the `.claude-extensions.json` `source_dir`
      indirection, then the deployed-tree mirror where semantically valid, then a loud error
      carrying the resolution order it tried. *(completed: new "Source-store resolution order for
      an external source store" subsection, inserted after the existing "Explicit deployed/
      source-store subject resolution" section)*
- [x] State the two semantic cases plainly, with the reason for each: a suite verifying content
      that the deployed tree faithfully mirrors may fall back to the deployed copy; a suite whose
      purpose is comparing the deployed tree against the pre-deploy source must not, because that
      fallback is circular. *(completed)*
- [x] State that `source_dir` is per-extension, so a top-level read returns `null`, and that
      `null` must not be read as the key being absent. *(completed)*
- [x] State that a suite cannot self-declare a skip: `run-all.sh`'s verdict is binary on `rc == 0`
      and its `[SKIP]` is reserved for a non-executable suite file, so an "unrunnable, skipping"
      exit of 0 is counted as a pass. The degrade path is therefore a loud non-zero environment
      error, never a self-declared skip. *(completed)*
- [x] Point at `lib/common.sh`'s `common_test_ext_root` as the single implementation and at
      `lib/deploy-freshness-lib.sh` as the pre-existing precedent for the fall-open read. Do not
      restate either contract — cite them. *(completed)*
- [x] Verify no task-number reference and no record-versioning language entered the file: cite
      durable anchors only (script names, function names, key names, flag spellings, exit codes,
      message texts), and state the current design without narrating its own history. *(completed:
      `check-task-references.sh` reports 0 occurrences repo-wide; `check-record-versioning.sh`'s
      3 repo-wide BLOCKING findings are all in `lua/neotex/plugins/tools/himalaya/docs/**`,
      unrelated to this file — zero findings against the edited file itself. Also discovered and
      fixed a mechanical fallout: the edit grew the file past its recorded `index-entries.json`
      `line_count` (1216 -> 1269), tripping Rule R; repaired via
      `bash .claude/scripts/generate-context-line-counts.sh --write`, which writes back to the
      source-store `index-entries.json`, not the deployed copy.)*

**Timing**: 1 hour

**Depends on**: 2, 3, 4, 5

**Verification Tier**: prose

**Tier Justification**: a source-store markdown edit with no executable surface, covered by
`bash .claude/scripts/verify-deploy.sh --skip-slow --only-gate 3,4 /home/benjamin/.config/nvim`
(doc-lint plus the task-reference lint, with `TARGET` the source-store repository's own root,
which holds both a deployed `.claude/` tree and `agent-system/extensions` simultaneously), run
together with the `prose` row's diff read-through confirming every changed hunk is prose.

**Files to modify**:

- `agent-system/extensions/core/context/standards/shell-script-testing.md` - add the source-store resolution-order subsection

**Verification**:

- `bash .claude/scripts/verify-deploy.sh --skip-slow --only-gate 3,4 /home/benjamin/.config/nvim`
  reports no finding against the edited file, and neither selected gate SKIPped (a run in which
  both gates SKIP attests to nothing).
- Diff read-through confirms the change is confined to prose.
- `bash .claude/scripts/check-task-references.sh` and the record-versioning lint report no finding
  against the edited file.

---

### Phase 7: Re-Derive the Sweep and Confirm the Class Is Closed [COMPLETED]

**Goal**: A fresh, independently measured sweep shows all 6 confirmed suites off the NEW list, and
the residual failure set is enumerated by name for Phase 8 to reconcile.

**Tasks**:

- [x] Run `bash agent-system/extensions/core/scripts/tests/run-all.sh --jobs auto` with no filter
      from this repository and capture the full roster and the tally line. Record passed, failed,
      EXPECTED, NEW, skipped, and total as measured — never as carried from this plan or the
      report. *(completed: 174 passed, 8 failed (2 expected, 6 NEW), 2 skipped, 184 total — see
      `records/sweep-measurement.md`)*
- [x] Repeat with the deployed entry point `bash .claude/scripts/tests/run-all.sh --jobs auto` and
      record the same six figures, so the two discovery modes are compared rather than conflated.
      *(completed: 162 passed, 13 failed (2 expected, 11 NEW), 2 skipped, 177 total)*
- [x] Assert explicitly that each of the 6 confirmed suites —
      `test-askuserquestion-rehome.sh`, `test-deploy-propagation.sh`, `test-routing-resolution.sh`,
      `test-update-task-status.sh`, `test-lint-dead-command-recommendations.sh`,
      `test-manifest-scripts-sync.sh` — appears in the PASS roster, not merely absent from the FAIL
      roster. *(completed: each named explicitly in both rosters via a direct grep for its own
      name, recorded in records/sweep-measurement.md)*
- [x] Run each of the 6 against the synthetic external-source-store fixture once more, as a set,
      and record the result. This is the decisive evidence for the task's own acceptance, since
      this repository's topology cannot exhibit the original symptom. *(completed: `run-all.sh
      --only` over the six: 6 passed, 0 failed)*
- [x] Enumerate the residual failing suites by name, and for each, classify: genuine finding, or
      environmental. Any suite classified environmental is a gap in this phase's own work and must
      be returned to the appropriate earlier phase, not carried forward. *(completed: all 8
      both-topology residuals classified in records/sweep-measurement.md; none classified
      environmental — every one is either already EXPECTED or matches this plan's own named
      out-of-scope regression cluster, spot-checked directly on one representative case)*
- [x] Record which residual suites fail identically in **both** topologies (repo-independent) and
      which fail in only one. Phase 8 may only baseline the repo-independent ones. *(completed: 8
      both-topology, 5 deployed-only — see records/sweep-measurement.md)*
- [x] Optional confirmation, non-blocking: if the external consumer repository's deployed tree is
      already current, re-run its sweep read-only and record the 6 suites' results there. If a
      deploy would be needed first, read `context/patterns/regeneration-is-manual-only.md` and
      record this step as INCONCLUSIVE and pending operator action rather than initiating a
      regeneration. An inconclusive result is never reported as a pass. *(completed: not performed
      — this dispatch has no access to a second, externally-source-stored consumer repository's
      checkout; recorded as PENDING OPERATOR ACTION in records/sweep-measurement.md)*
- [x] Use the bounded-waiter discipline for the backgrounded sweep: a hard timeout, writer liveness
      via `kill -0` on the captured PID, one waiter per log, never `ps | grep` or `pgrep -f`. See
      `context/patterns/bounded-build-waiter.md`. *(completed)*

**Timing**: 1.5 hours

**Depends on**: 6

**Verification Tier**: full

**Tier Justification**: this phase's own deliverable is a whole-corpus measurement, so no suite
subset can produce it — the cross-cutting surface is the entire discovered suite population under
both discovery modes, which no narrowing invocation covers by construction.

**Scope Hypothesis**: the pre-fix measurement to compare against is 13 of 175 failing in this
repository (2 EXPECTED, 11 NEW) and 37 of 174 in the external-consumer topology (2 EXPECTED, 35
NEW), of which 10 reproduce identically in both. The 175 denominator was live-confirmed during
plan authoring; every other figure is a hypothesis. Re-derive all of them here and report the
delta against these numbers explicitly, including the case where they have drifted again.

**Scope Hypothesis — measured result**: drifted further, as warned. This repository's own
source-store sweep (post-fix) measured 184 total, not 175 — the denominator itself moved between
plan authoring and this phase, independent of this task's own edits (other concurrent work in
this repository adds and removes suites continuously). The pre-fix 13-failing figure cannot be
directly re-verified post-fix (the fix is already applied), but Phase 1's own independent
pre-fix measurement, taken at the start of this task's implementation before any of this plan's
edits landed, recorded 13 of 175 failing (2 EXPECTED, 11 NEW) in this repository — matching this
Scope Hypothesis exactly. The external-consumer-topology figures (37 of 174) are not
independently re-verified here at all: this dispatch has no access to that repository (see the
Optional external-consumer confirmation task above, recorded as pending operator action).

**Files to modify**:

- `specs/555_test_sweep_external_source_store_failures/records/sweep-measurement.md` - the measured rosters, tallies, residual enumeration, and both-topology classification (create; this is the durable carrier Phase 8 reads, deliberately not an orchestration sidecar)

**Verification**:

- All 6 confirmed suites appear in the PASS roster under both discovery modes.
- All 6 pass against the synthetic external-source-store fixture.
- The residual set is enumerated by name with a both-topologies / one-topology classification for
  each, and no residual is classified environmental.
- The complete gate set runs green: `bash .claude/scripts/verify-deploy.sh` (source-store entry
  point if that is the one that resolves). Record which entry point resolved.

---

### Phase 8: Reconcile the Baseline and Restore Exit-Code Discrimination [COMPLETED]

**Goal**: Every residual failure is either a genuine finding under an owner anchor or a declared
`known-failures.txt` row carrying a reason, so `run-all.sh --fail-on-new` once again discriminates
a new failure from the standing baseline; and the task's full gate set is green.

**Tasks**:

- [x] Read `records/sweep-measurement.md` from Phase 7. If it does not exist, stop and report —
      do not re-measure ad hoc and do not proceed on remembered figures. *(completed: exists,
      read)*
- [x] Read `tests/known-failures.txt`'s own header in full and follow its stated row format
      (`basename|category|reason|owner`), its four-value category vocabulary
      (`real-defect` / `intermittent` / `load-sensitive` / `wip-transient`), and its advisory-only
      contract — a row never changes which suites run, only whether a failure is annotated
      EXPECTED or NEW. *(completed)*
- [x] Add one row per **repo-independent** residual failure (failing identically in both
      topologies). Each row's reason must be a durable anchor — the failing case's own message,
      the assertion name, the script and function involved — never a task number, since this file
      lives under `agent-system/extensions/**` where task-number references are prohibited. Use
      the literal `needs-owner` where no follow-up owner exists. *(completed: 6 rows added —
      `test-double-loading-check.sh`, `test-lint-unit-integration-boundary.sh`,
      `test-orchestrate-cycle-postflight.sh`, `test-orchestrate-predispatch-review.sh`,
      `test-postflight-deploy-gate.sh`, `test-redeploy-checkpoint-promotion.sh`, each `real-defect`
      / `needs-owner`, each reason citing the live failing assertion's own message)*
- [x] Do **not** add a row for any suite failing in only one topology: the manifest keys on
      basename and is mode-insensitive, so such a row would also annotate the suite EXPECTED where
      it passes. Record those by name in the summary as follow-up candidates instead.
      *(completed: the 5 deployed-only suites from `records/sweep-measurement.md` were not
      baselined)*
- [x] Do **not** add a row for any of the 6 confirmed suites. They pass now and must keep passing
      as a live regression signal. *(completed: no row added for any of the 6)*
- [x] Re-assess the existing `test-verify-deploy-context-budget.sh` row against Phase 3's recorded
      gate-24 observation. If gate 24 now reports no finding against its fixture and the suite
      reaches rc 0, remove the row (the row's own text states that is its removal condition);
      otherwise update its reason to match what is now true and leave it in place. *(completed:
      Phase 3 recorded UNMOVED — the row's text is already accurate and was left unchanged)*
- [x] Re-run the full sweep with `--fail-on-new` and confirm the NEW count is 0 while the EXPECTED
      count equals the declared baseline. A non-zero NEW count means a residual was neither fixed
      nor declared — report it rather than widening the baseline to make the number go away.
      *(completed: 174 passed, 8 failed (8 expected, 0 NEW), 2 skipped, 184 total)*
- [x] Confirm no suite was silenced: every row added has a reason, and `run-all.sh`'s own roster
      still shows each declared suite as executed and failing, not skipped. *(completed: all 9
      declared rows show a `[RUN]` line in the sweep output; every added row has all four fields
      populated)*

**Timing**: 1.5 hours

**Depends on**: 7

**Verification Tier**: full

**Files to modify**:

- `agent-system/extensions/core/scripts/tests/known-failures.txt` - add one declared row per repo-independent residual failure; re-assess the existing `test-verify-deploy-context-budget.sh` row against Phase 3's gate-24 observation (this file exists and was read during plan authoring; if a row named here is absent at implementation time, record that and reconcile against the live file rather than restoring a remembered row)

**Verification**:

- `bash .claude/scripts/tests/run-all.sh --jobs auto --fail-on-new` reports NEW = 0, with the
  EXPECTED count equal to the number of declared rows.
- Every added row has all four fields populated and a reason citing a durable anchor only.
- No row exists for any of the 6 confirmed suites, and none for a one-topology-only failure.
- The complete gate set runs green: `bash .claude/scripts/verify-deploy.sh` (or the source-store
  entry point, whichever resolves), including Gate 8's full shell-suite battery, Gate 3's doc-lint,
  and Gate 4's task-reference lint.
- `bash .claude/scripts/check-task-references.sh` and the record-versioning lint report no finding
  against any file this plan edited.

---

## Testing & Validation

- [ ] `test-common-lib.sh` and `test-deploy-root-guard.sh` pass, including the new synthetic
      external-source-store fixture cases and the unchanged-refusal negative case.
- [ ] All 6 confirmed suites pass from the source store, from the deployed tree, and against the
      synthetic external-source-store fixture.
- [ ] `test-manifest-scripts-sync.sh` reports 19 of 19;
      `test-lint-dead-command-recommendations.sh` reports 12 of 12.
- [ ] `shellcheck` is clean on every edited shell script.
- [ ] `run-all.sh --jobs auto --fail-on-new` reports NEW = 0.
- [ ] `verify-deploy.sh`'s complete gate set is green.
- [ ] No task-number reference and no record-versioning language appears in any file edited under
      `agent-system/extensions/**`.

## Artifacts & Outputs

- `agent-system/extensions/core/scripts/lib/common.sh` (new `common_test_ext_root`)
- `agent-system/extensions/core/scripts/deploy-root-guard.sh`
- `agent-system/extensions/core/scripts/sync-manifest-scripts.sh`
- `agent-system/extensions/core/scripts/lint/lint-dead-command-recommendations.sh`
- `agent-system/extensions/core/scripts/tests/test-common-lib.sh`
- `agent-system/extensions/core/scripts/tests/test-deploy-root-guard.sh`
- `agent-system/extensions/core/scripts/tests/test-manifest-scripts-sync.sh`
- `agent-system/extensions/core/scripts/tests/test-lint-dead-command-recommendations.sh`
- `agent-system/extensions/core/scripts/tests/test-routing-resolution.sh`
- `agent-system/extensions/core/scripts/tests/test-update-task-status.sh`
- `agent-system/extensions/core/scripts/tests/test-askuserquestion-rehome.sh`
- `agent-system/extensions/core/scripts/tests/test-deploy-propagation.sh`
- `agent-system/extensions/core/scripts/tests/known-failures.txt`
- `agent-system/extensions/core/context/standards/shell-script-testing.md`
- `specs/555_test_sweep_external_source_store_failures/records/sweep-measurement.md`

## Rollback/Contingency

Every phase is a scoped, independently revertable commit, and the resolver is additive — Phase 1
introduces a new function without changing any existing symbol — so reverting a later phase never
leaves the earlier ones inconsistent. Prefer fixing forward: the resolver's fall-open contract means
a resolution failure degrades to the loud environment error the call site already produced, which is
the pre-change behavior. Never discard uncommitted work to reach a green sweep. If a genuine
rollback of committed work becomes necessary, follow `context/contracts/recovery.md`'s rollback
rung for the exact snapshot-then-rollback invocation shape, including its out-of-scope override
flag; a defensive checkpoint before risky work uses `git-snapshot.sh --no-revert`, which is durable
without reverting the working tree.
