# Implementation Plan: Task #601

- **Task**: 601 - Close the class of invocation-path-dependent repo-root resolution in test suites with a durable lint
- **Status**: [IMPLEMENTING]
- **Effort**: 5.75 hours
- **Dependencies**: None
- **Research Inputs**: specs/601_root_walkup_class_closure_lint/reports/01_root-walkup-closure-lint.md
- **Artifacts**: plans/01_root-walkup-closure-lint.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Build `lint-test-root-resolution.sh` under the core extension's `scripts/lint/` directory, modeled
structurally on the existing `lint-test-harness-adoption.sh` (shared test-suite scan scope,
line-oriented regex detection with a stated KNOWN LIMITATION, `path:line`-keyed reasoned allowlist,
`[--verbose] [--help] [path...]` usage, exit 0/1/2, sibling fixture suite). The lint forbids an
*unconditional* fixed-depth parent walk used as the sole repo-root/extensions-root computation in a
test suite, and sanctions the two guarded shapes already in wide corpus use (git-first fallback;
validated candidate). Three currently-live violating instances are migrated to the existing
`common_test_repo_root` / `common_test_ext_root` helpers first, so the lint can land at zero
violations. The lint is then registered as gate 29 (declarative `gate-registry.data` row plus a
`gate29_run()` block in `verify-deploy.sh`), because an unregistered lint has no deploy-time
enforcement and "durable guard" is the task's stated goal. Finally the discriminator rule is
documented in `context/standards/shell-script-testing.md` and the source store is redeployed.

### Premise Re-Validation (Carried-Figure Discipline)

Every measurable claim in the dispatch `## Description` and in the research report was re-checked
live in this planning dispatch, not carried forward on citation:

- **CONFIRMED, measured directly this dispatch**: four levels up from the source-store
  `agent-system/extensions/core/scripts` resolves to `/home/benjamin/.config/nvim` (the repository
  root); the identical four-level walk from the deployed `.claude/scripts` resolves to
  `/home/benjamin` — outside the repository. (Note the arithmetic is anchored at the `scripts/`
  directory, which is what `CORE_DIR="$SCRIPT_DIR/.."` evaluates to in a suite living under
  `scripts/tests/`; anchoring at `core/` instead gives a different answer and is not the shape
  under discussion.)
- **CONFIRMED**: `gate-registry.data`'s highest registered id is 28
  (`lint-deliberate-break-residue.sh`); next free id is 29, and `lint-gate-registry.sh` requires a
  contiguous range from 1, which appending 29 satisfies.
- **CONFIRMED**: all three newly-found live instances named by the research report still carry the
  unconditional shape at the cited lines —
  `scripts/test-state-write-spill-names.sh:74` (`$SCRIPT_DIR/../../../..`),
  `scripts/tests/test-source-store-path-lib.sh:136` (`$SCRIPT_DIR/../../../../..`),
  `scripts/tests/test-orchestrate-context-growth.sh` (`CORE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"` at
  line 46, consumed by bare `"$CORE_DIR/../../../.."` uses at lines 308 and 313-314).
- **CONFIRMED**: `test-verify-deploy-gate-selection-crash-net.sh:50-51` carries the forbidden shape
  with no git-first and no validated-candidate guard — it is the allowlist case, not a
  mechanically-discriminable one.
- **CORRECTED vs. the dispatch's open question**: the dispatch asks to "coordinate or serialize"
  with task 584 over `gate-registry.data`. Task 584 is `not_started` and is **not** among this
  cycle's `concurrent_siblings`; a third task (604) also declares the file and is likewise
  `not_started` and not dispatched. No live collision exists this cycle — but the standing
  re-read-immediately-before-editing territory rule still applies.
- **CORRECTED vs. this task's own declared `file_scope`**: state.json declares
  `agent-system/extensions/core/scripts/lint-test-root-resolution.sh` (directly under `scripts/`).
  Every one of the 23 existing lints lives under `scripts/lint/`, and both `verify-deploy.sh`'s gate
  blocks and gate 25's `input_corpus` glob reference `scripts/lint/*.sh`. This plan sites the new
  lint at `scripts/lint/lint-test-root-resolution.sh`. `file_scope` is descriptive, not validated,
  so this is a declaration refinement, not a violation.
- **NOT NEEDED**: `scripts/lib/common.sh` is in the declared `file_scope`, but
  `common_test_repo_root` and `common_test_ext_root` already exist and are used by ~80 suites. No
  edit to `common.sh` is planned; the lint enforces existing machinery and invents no helper.

### Research Integration

Three research findings are load-bearing and shape the phase structure rather than merely informing
it: (1) the lint's name, structural model, and core discriminator are already settled by the prior
remedy's own completion summary and plan Non-Goals, so no design derivation is budgeted; (2) the
crash-net suite's tolerance is a property of *what it asserts*, not of its path arithmetic, so it
needs a reasoned allowlist entry and no amount of regex cleverness will discriminate it; (3) three
live violating instances exist today, two of which silently degrade a real guard into a false PASS —
these are migrated before the lint lands so its first run is honestly clean rather than allowlisted.

### Prior Plan Reference

No prior plan for this task.

### Roadmap Alignment

No `roadmap_path` was provided in this dispatch; no roadmap phases are included.

## Goals & Non-Goals

**Goals**:
- A standalone `lint-test-root-resolution.sh` that mechanically forbids the unconditional
  fixed-depth root walk in test-suite-classified shell files, and passes the two sanctioned guarded
  shapes.
- A sibling fixture suite exercising both polarities against synthetic fixtures (never the live
  tree), classified in `suite-classification.data`.
- Zero live violations at launch: the three currently-live instances migrated to
  `common_test_repo_root` / `common_test_ext_root`.
- Deploy-time enforcement: registration as gate 29 (registry row + `gate29_run()` block).
- The discriminator rule documented in prose where a future suite author will find it.

**Non-Goals**:
- Production (non-test) scripts carrying the same shape — the five `zotero-*.sh` scripts under the
  literature extension. Same underlying defect class, but outside both this task's "test suites"
  framing and the model lint's scan-scope precedent. Named here deliberately, not omitted silently;
  a follow-up candidate.
- Any new helper in `scripts/lib/common.sh`. The canonical replacement already exists.
- Editing `scripts/tests/suite-cost-hints.txt`. That file is mechanically generated by
  `measure-gate-costs.sh --regen-hints` and is explicitly advisory — hand-adding a row would be
  overwritten on the next regeneration and changes nothing about which suites run.
- Any `.claude/**` hand-edit. The source store is the edit target; `.claude/` is regenerated.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Regex-only line-oriented detection misses a shape spread across statements or behind variable indirection | M | H | Scope detection to the two concrete shapes every real instance exhibits; document the limitation in the lint header exactly as the model lint does; claim only "the known bad shape is not present" |
| The lint false-positives on one of the two sanctioned shapes, failing ~80 already-correct suites | H | M | Phase 3 runs the lint over the full live corpus and requires exit 0 before the gate is wired; the fixture suite asserts both sanctioned shapes stay silent |
| Migrating a root computation unmasks a second, previously-silent defect in the same suite (the prior remedy hit exactly this) | M | M | Phase 1 runs each migrated suite from BOTH invocation paths and diffs pass/fail tallies; a newly-surfaced failure is in scope for that phase, not deferred |
| Gate 29 registration drifts (row without function, or vice versa) | M | L | `lint-gate-registry.sh` checks contiguity and row shape; Phase 4 verification runs `--only-gate 29` and the 31-suite covering set including `test-gate-registry-resolution.sh` and `test-deploy-verify-wiring.sh` |
| `gate-registry.data` collides with task 584 or 604 | M | L | Both are `not_started` and absent from this cycle's `concurrent_siblings`; re-read the file immediately before editing and append a new row rather than touching an existing one |
| New gate's `input_corpus` too broad, re-triggering the full-battery-on-any-touch cost problem | M | M | Scope `input_corpus` to the test-suite shell globs only, never `@extensions` |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1, 2 | -- |
| 2 | 3 | 1, 2 |
| 3 | 4 | 3 |
| 4 | 5 | 4 |

Phases within the same wave can execute in parallel.

### Phase 1: Migrate the Three Live Violating Instances [COMPLETED]

**Goal**: Bring the three currently-live unconditional-walk instances onto
`common_test_repo_root` / `common_test_ext_root`, so the lint can launch at zero violations rather
than needing allowlist entries for genuine, understood defects.

**Tasks**:
- [x] Re-read each of the three files immediately before editing (concurrent-sibling territory rule). *(completed)*
- [x] For each file, record the pre-migration measured root from BOTH the source-store and the
      deployed invocation path, before changing anything. *(completed: source-store walk resolves to repo root; deployed walk resolved to /home/benjamin, outside the repo)*
- [x] `scripts/test-state-write-spill-names.sh:74`: replace
      `REAL_REPO_ROOT="$(cd "$SCRIPT_DIR/../../../.." && pwd)"` with the
      `common_test_repo_root "$SCRIPT_DIR"` call, confirming the file already sources
      `lib/common.sh` (add the source if it does not). *(completed: added source line + `common_test_repo_root "$SCRIPT_DIR" 4`, since this file lives one level shallower than scripts/tests/)*
- [x] `scripts/tests/test-source-store-path-lib.sh:136`: replace the five-level
      `REAL_REPO_ROOT` walk with `common_test_repo_root "$SCRIPT_DIR"`; keep the existing
      `[ -f "$REAL_REPO_ROOT/.claude-extensions.json" ]` guard and its visible-skip `else` branch. *(completed)*
- [x] `scripts/tests/test-orchestrate-context-growth.sh`: replace the three bare
      `"$CORE_DIR/../../../.."` / `"$CORE_DIR/../../../../specs/..."` uses (lines 308, 313-314) with
      a single `common_test_repo_root`-derived variable; leave `CORE_DIR` itself alone where it is
      used for its actual purpose (locating sibling scripts). *(completed: added `REAL_REPO_ROOT`)*
- [x] Run each migrated suite from the source-store path AND from the deployed path; diff the
      pass/fail tallies against the pre-migration run. *(completed: 5/5, 21/21, 6/6 respectively, matching on both paths; deployed copies updated in place ahead of Phase 5's full redeploy to make this check meaningful)*
- [x] If a migration unmasks a previously-silent real failure (the prior remedy hit this), fix it in
      this phase rather than deferring — the masked assertion is the point of the migration. *(completed: no previously-silent failure was unmasked; all tallies matched pre-migration)*

**Timing**: 1.25 hours

**Depends on**: none

**Verification Tier**: local

**Scope Hypothesis**: Exactly three files carry the forbidden shape today beyond those the prior
remedy already migrated, at the lines cited above. Confirmed by grep + direct `cd` measurement in
this planning dispatch, but the implementer MUST re-run the sweep
(`grep -rnE '\.\./\.\./\.\.' ` over test-suite-classified files, checking each hit for a git-first or
validated-candidate guard) before declaring the set closed — a third independent sweep is exactly
what surfaced these three.

**Tier Justification**: `suite_selection_select` over this phase's three paths returns exactly
`test-state-write-spill-names.sh`, `test-source-store-path-lib.sh`, and
`test-orchestrate-context-growth.sh` (each path maps to itself), so
`run-all.sh --only test-state-write-spill-names.sh,test-source-store-path-lib.sh,test-orchestrate-context-growth.sh`
is the cheapest check that covers the whole edit.

**Files to modify**:
- `agent-system/extensions/core/scripts/test-state-write-spill-names.sh` - root computation migrated to `common_test_repo_root`
- `agent-system/extensions/core/scripts/tests/test-source-store-path-lib.sh` - root computation migrated to `common_test_repo_root`
- `agent-system/extensions/core/scripts/tests/test-orchestrate-context-growth.sh` - three walk-up use sites migrated

**Verification**:
- `bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-state-write-spill-names.sh,test-source-store-path-lib.sh,test-orchestrate-context-growth.sh`
  exits 0.
- Each of the three suites run directly from the deployed `.claude/scripts/` copy as well as the
  source store, with matching pass tallies (not merely "both exit 0").
- `grep -n 'common_test_repo_root\|common_test_ext_root'` shows the helper in each of the three
  files, and no `../../../..` walk remains in them.

---

### Phase 2: Author lint-test-root-resolution.sh [NOT STARTED]

**Goal**: A standalone lint that flags the unconditional fixed-depth root walk in
test-suite-classified shell files and stays silent on both sanctioned guarded shapes.

**Tasks**:
- [ ] Create `agent-system/extensions/core/scripts/lint/lint-test-root-resolution.sh`, structurally
      mirroring `lint-test-harness-adoption.sh`: WHY THIS EXISTS header, the two-valid-shapes
      section, DETECTION MODEL, an explicit KNOWN LIMITATION paragraph, SCAN SCOPE, usage block,
      exit-code block.
- [ ] Reuse the shared test-suite scan scope verbatim (a `*.sh` file is in scope when it lives under
      a `tests/` directory anywhere in its path, OR its basename starts with `test-`), matching
      `script-inventory.sh`'s classification so the two stay in lockstep.
- [ ] Resolve the lint's OWN root git-first with a fixed-depth fallback — the lint practices what it
      polices.
- [ ] Implement the detection rule: flag an assignment of the shape
      `VAR="$(cd "<path-expr with one or more literal ../ segments>" [2>/dev/null] && pwd [|| true])"`
      (and the two-statement `cd ...; VAR=$(pwd)` variant) UNLESS the same variable's assignment is
      guarded by either (a) a `git rev-parse --show-toplevel` / `git -C ... rev-parse --show-toplevel`
      attempt tried first (typically the fixed-depth `cd` sitting inside an `if [[ -z "$VAR" ]]`
      fallback block), or (b) a validated candidate — the computed path tested with
      `[ -d ... ]` / `[ -f ... ]` before being accepted, with a differently-shaped fallthrough.
- [ ] Skip full-line comments from the scan, as the model lint does.
- [ ] Seed a `declare -A ALLOWLIST` with exactly one entry, keyed
      `agent-system/extensions/core/scripts/tests/test-verify-deploy-gate-selection-crash-net.sh:51`,
      carrying a one-line justification: the suite's sole assertion is a crash net (no registered
      gate crashes), insensitive to fixture correctness by design, so a wrong root cannot change its
      verdict. Document in the array's header comment that an entry is a deliberate, inspected,
      per-instance act and never the default response to a failing run.
- [ ] Implement `[--verbose] [--help] [path...]` with explicit paths REPLACING the default corpus
      (used only by the fixture suite), and exit codes 0 clean / 1 violations / 2 environment-usage.
- [ ] Emit findings as `[VIOLATION] <relpath>:<line>: <reason>` lines so
      `verify_deploy_extract_verdict_lines '[VIOLATION]'` can harvest them in Phase 4.

**Timing**: 1.5 hours

**Depends on**: none

**Verification Tier**: local

**Scope Hypothesis**: None asserted beyond Phase 1's.

**Tier Justification**: `suite_selection_select` returns the `__FULL_SWEEP__` sentinel for this
phase's single new path under `scripts/lint/` — no suite covers a file that does not yet exist and
whose fixture suite lands only in Phase 3 — so the honest in-phase check is the `local` row's
single-module lint: `bash -n` plus a `lint-shellcheck.sh --verbose` pass over that one new file
(exact invocations in this phase's Verification block below).

**Files to modify**:
- `agent-system/extensions/core/scripts/lint/lint-test-root-resolution.sh` - new standalone lint

**Verification**:
- `bash -n agent-system/extensions/core/scripts/lint/lint-test-root-resolution.sh` is clean.
- `bash agent-system/extensions/core/scripts/lint/lint-shellcheck.sh --verbose agent-system/extensions/core/scripts/lint/lint-test-root-resolution.sh`
  exits 0.
- `--help` prints usage and exits 0; an unknown argument exits 2.
- A manual spot-run against three known-sanctioned suites (`test-approve-*.sh`, `run-all.sh`,
  `test-common-lib.sh`) produces no violations.

---

### Phase 3: Fixture Suite, Classification Row, and Zero-Violation Live Run [NOT STARTED]

**Goal**: Prove both polarities against synthetic fixtures, register the fixture suite so the
unit/integration boundary lint cannot fail on it, and establish that the lint runs clean over the
entire live corpus before it is given gate authority.

**Tasks**:
- [ ] Create `agent-system/extensions/core/scripts/tests/test-lint-test-root-resolution.sh`,
      modeled on `test-lint-test-harness-adoption.sh`: synthetic fixtures written into a scratch
      directory, never the live tree.
- [ ] Positive cases (lint MUST fire): an unconditional single-line `VAR="$(cd "$DIR/../../../.." && pwd)"`;
      the two-statement `cd`-then-`$(pwd)` variant; a bare `"$VAR/../../../.."` consumed inline.
- [ ] Negative cases (lint MUST stay silent): the git-first-guarded fallback shape; the
      validated-candidate shape; a file outside the test-suite scan scope carrying the shape; an
      allowlisted `path:line`.
- [ ] Assert the exit-code contract (0/1/2) and that an explicit path argument replaces the default
      corpus rather than adding to it.
- [ ] Add the row `test-lint-test-root-resolution.sh<TAB>unit<TAB>-` to
      `scripts/tests/suite-classification.data`, matching `test-lint-test-harness-adoption.sh`'s own
      row. This is required, not cosmetic: `lint-unit-integration-boundary.sh` fails loudly on an
      unclassified discovered suite.
- [ ] Run the lint over the full default corpus and require exit 0. If it fires on anything not
      already migrated in Phase 1, triage each hit as either a real defect (fix it, or re-scope) or
      a false positive (fix the detection rule) — do NOT add allowlist entries to reach green.

**Timing**: 1.0 hour

**Depends on**: 1, 2

**Verification Tier**: local

**Scope Hypothesis**: Seven fixture cases (three positive, four negative) suffice to pin both
polarities plus the scope and allowlist behaviors. The implementer confirms sufficiency by checking
each fixture actually exercises a distinct branch of the detection function, and adds cases if any
branch is unreached.

**Tier Justification**: `suite_selection_select` returns `__FULL_SWEEP__` for this phase's
touched paths today because the fixture suite does not yet exist, so the covering check is
`run-all.sh --only` over the selector's actual output re-measured AFTER the files are created — which
the implementer MUST run and use verbatim rather than assume (the selector does map a
`scripts/lint/` lint path to its same-named fixture suite once that suite exists; measured against
the existing harness-adoption lint and fixture pair during planning).

**Files to modify**:
- `agent-system/extensions/core/scripts/tests/test-lint-test-root-resolution.sh` - new fixture suite
- `agent-system/extensions/core/scripts/tests/suite-classification.data` - one `unit` row for the new suite

**Verification**:
- `bash agent-system/extensions/core/scripts/tests/test-lint-test-root-resolution.sh` exits 0 with
  every fixture case asserted.
- `bash agent-system/extensions/core/scripts/lint/lint-test-root-resolution.sh --verbose` over the
  default corpus exits 0 with zero violations (the task's stated completion bar).
- `bash agent-system/extensions/core/scripts/lint/lint-unit-integration-boundary.sh` exits 0
  (classification row present).
- `run-all.sh --only <selector output for the three touched paths>` exits 0.

---

### Phase 4: Register as Gate 29 [NOT STARTED]

**Goal**: Give the lint deploy-time enforcement — the difference between a script someone may run
and a durable guard.

**Tasks**:
- [ ] Re-read `scripts/gate-registry.data` immediately before editing (tasks 584 and 604 both
      declare it; both are `not_started` and not dispatched this cycle, but the rule stands).
- [ ] Append one 9-field TAB-separated row:
      `29`, `Test-suite root-resolution lint (lint-test-root-resolution.sh)`, `gate29_run`, `-`,
      `true`, `30`, `free`, `false`, and an `input_corpus` scoped to the test-suite shell globs only
      — `agent-system/extensions/core/scripts/tests/*.sh,agent-system/extensions/*/scripts/tests/*.sh,agent-system/extensions/*/scripts/test-*.sh`
      — never `@extensions`.
- [ ] Add a `gate29_run()` function to `scripts/verify-deploy.sh`, copying `gate28_run()`'s shape
      exactly: `gate_selected 29` wrapper, the `say "29. ..."` line, `CURRENT_GATE="gate29"`, the
      deploy-consumer `[ ! -d "$TARGET/agent-system/extensions" ]` SKIP branch, the
      lint-script-missing `fail` branch, the `cd "$TARGET" && REPO_ROOT="$TARGET" bash ... --verbose`
      invocation, pass/fail reporting, and the `FINDINGS_LIST` population via
      `verify_deploy_extract_verdict_lines '[VIOLATION]'`.
- [ ] Confirm no separate call-site list needs updating: the registry's own executor
      (`gate_registry_execute` in `lib/gate-registry-lib.sh`) looks up and calls the `invoke`
      function, and gate 28 has exactly two touch points (its row and its function).

**Timing**: 0.75 hours

**Depends on**: 3

**Verification Tier**: interface

**Scope Hypothesis**: Exactly two files and two touch points are needed to register a gate.
Confirmed by grepping every `gate28` occurrence in the source store outside `scripts/tests/`, which
returns only the `verify-deploy.sh` function body and the `gate-registry.data` row. The implementer
re-runs that grep for `gate28` before editing and matches the touch-point set.

**Tier Justification**: `suite_selection_select` over this phase's two paths
(`verify-deploy.sh`, `gate-registry.data`) returns a 31-suite union out of 151 corpus suites — a
real narrowing, not the full battery — so `run-all.sh --only` over exactly that selector output
covers the aggregator change at a fraction of a `full` run's cost.

**Files to modify**:
- `agent-system/extensions/core/scripts/gate-registry.data` - one appended row for gate 29
- `agent-system/extensions/core/scripts/verify-deploy.sh` - new `gate29_run()` function

**Verification**:
- `bash agent-system/extensions/core/scripts/lint/lint-gate-registry.sh` exits 0 (contiguous ids
  1-29, 9 fields, valid `invoke` name).
- `bash .claude/scripts/verify-deploy.sh --only-gate 29 /home/benjamin/.config/nvim` reports gate 29
  as a pass (not SKIP, since that TARGET holds both the deployed tree and the source store).
- `bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-check-task-references.sh,test-claude-refresh-matcher.sh,test-deploy-baseline-lib.sh,test-deploy-orphans.sh,test-deploy-verify-overlap.sh,test-deploy-verify-wiring.sh,test-gate3-strict-equivalence.sh,test-gate8-expected-new-distinction.sh,test-gate-cache-equivalence.sh,test-gate-cache-lib.sh,test-gate-lock.sh,test-gate-out-self-attribution.sh,test-gate-registry-resolution.sh,test-lint-branch-gated-sections.sh,test-lint-hook-registration-paths.sh,test-lint-json-channel-discipline.sh,test-lint-shellcheck-parallel.sh,test-lint-task-lookup-adoption.sh,test-lint-unit-integration-boundary.sh,test-lint-verdict-extraction-anchoring.sh,test-measure-gate-costs.sh,test-orchestrate-batch-gate.sh,test-orchestrate-build-dispatch.sh,test-orchestrate-cycle-plan.sh,test-run-all-failure-reporting.sh,test-run-all-parallel.sh,test-run-all-selection.sh,test-validate-artifact.sh,test-verify-deploy-context-budget.sh,test-verify-deploy-gate-selection-crash-net.sh,test-verify-deploy-gate-selection.sh`
  exits 0 (regenerate this list from `suite_selection_select` rather than trusting it verbatim if
  the touched-path set changes).

---

### Phase 5: Document the Discriminator, Redeploy, and Run the Full Gate Set [NOT STARTED]

**Goal**: Make the sanctioned-vs-forbidden rule discoverable in prose for a future suite author,
regenerate the deployed tree from the source store, and close the task against the complete gate
set.

**Tasks**:
- [ ] Add a subsection to
      `agent-system/extensions/core/context/standards/shell-script-testing.md`, alongside the
      existing `common_test_repo_root` / `common_test_ext_root` guidance, stating the rule in prose:
      git-first-guarded fallback = sanctioned; validated-candidate-with-fallthrough = sanctioned;
      unconditional fixed-depth walk = forbidden and caught by gate 29. Cite the lint by filename
      and the helpers by name; cite no task numbers (deliverable files outside `specs/**`).
- [ ] Note in that subsection why the shape fails: the deployed `.claude/scripts/` tree sits two
      levels shallower than its source-store mirror, so an identical walk lands outside the
      repository and can silently degrade a real guard into a false PASS.
- [ ] Redeploy the source store: `bash agent-system/extensions/core/scripts/deploy-headless.sh`.
- [ ] Run the complete gate set and require green.

**Timing**: 0.75 hours

**Depends on**: 4

**Verification Tier**: full

**Scope Hypothesis**: One documentation file needs the new subsection. The implementer confirms by
grepping `shell-script-testing.md` for existing `common_test_repo_root` guidance and siting the
subsection adjacent to it rather than creating a second, competing location.

**Files to modify**:
- `agent-system/extensions/core/context/standards/shell-script-testing.md` - new subsection stating the root-resolution discriminator
- `__WHOLE_TREE__` - this phase invokes `deploy-headless.sh`, regenerating the entire deployed tree

**Verification**:
- `bash agent-system/extensions/core/scripts/deploy-headless.sh` completes without error and the
  new lint plus fixture suite appear in the deployed `.claude/scripts/lint/` and
  `.claude/scripts/tests/`.
- `bash .claude/scripts/verify-deploy.sh` (the complete gate set, gates 1-29, no `--skip-slow` and
  no `--only-gate` narrowing) exits green.
- Gate 29 reports a pass within that full run, not a SKIP.
- The new lint, run from the DEPLOYED copy
  (`bash .claude/scripts/lint/lint-test-root-resolution.sh --verbose`), exits 0 — i.e. the lint
  itself is invocation-path-independent, the property it exists to enforce.

---

## Testing & Validation

- [ ] The lint fires on all three positive fixture shapes and stays silent on both sanctioned shapes.
- [ ] The lint exits 0 over the full live corpus (zero violations at launch).
- [ ] The three migrated suites pass identically from the source-store and the deployed invocation
      paths, with matching pass tallies rather than merely matching exit codes.
- [ ] `lint-gate-registry.sh` and `lint-unit-integration-boundary.sh` both exit 0.
- [ ] Gate 29 passes under `--only-gate 29` and again inside the full `verify-deploy.sh` run.
- [ ] The deployed copy of the lint behaves identically to the source-store copy.

## Artifacts & Outputs

- `agent-system/extensions/core/scripts/lint/lint-test-root-resolution.sh` (new)
- `agent-system/extensions/core/scripts/tests/test-lint-test-root-resolution.sh` (new)
- One appended row in `agent-system/extensions/core/scripts/gate-registry.data` (gate 29)
- One `gate29_run()` function in `agent-system/extensions/core/scripts/verify-deploy.sh`
- One `unit` row in `agent-system/extensions/core/scripts/tests/suite-classification.data`
- Three migrated test suites (`test-state-write-spill-names.sh`, `test-source-store-path-lib.sh`,
  `test-orchestrate-context-growth.sh`)
- A new discriminator subsection in `context/standards/shell-script-testing.md`
- A regenerated deployed `.claude/` tree

## Rollback/Contingency

Every phase is additive or a localized substitution, and each lands as its own commit, so rollback
is a per-phase `git revert` of that commit. Specific contingencies:

- **If the lint false-positives broadly at Phase 3's live run**, the correct response is to narrow
  the detection rule, not to add allowlist entries; if the rule cannot be narrowed without losing
  the real class, stop at Phase 3 and return `partial` with the detection rule as the open question
  rather than shipping a gate that fails the corpus.
- **If gate 29 registration destabilizes `verify-deploy.sh`**, revert only the Phase 4 commit: the
  lint and its fixture suite remain useful standalone (the model lint itself is unregistered), and
  the task degrades to the standalone precedent rather than to nothing.
- **If a Phase 1 migration unmasks a defect too large for this task**, record it, leave that one
  suite's migration reverted, and carry a single reasoned allowlist entry for it with the unmasked
  defect named — but not silently, and not as the response to more than one instance.
