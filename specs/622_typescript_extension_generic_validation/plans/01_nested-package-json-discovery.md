# Implementation Plan: Task #622

- **Task**: 622 - Validate the typescript extension's generic toolchain detection against a real no-tsconfig node:test repository
- **Status**: [IMPLEMENTING]
- **Effort**: 4.25 hours
- **Dependencies**: Task 621 (completed)
- **Research Inputs**: specs/622_typescript_extension_generic_validation/reports/01_typescript-generic-validation.md
- **Artifacts**: plans/01_nested-package-json-discovery.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

The research phase loaded the `typescript` extension, unmodified, into
`/home/benjamin/Projects/Sapience/sf1-engine` and established two separable results: the
extension's *detection logic* is correct and generic for the target profile, but the extension
*fails the task's PASS CONDITION* because the verification-stage hook is invoked with cwd fixed
at the repo root and only ever looks for `package.json` relative to that cwd. sf1-engine's
TypeScript project lives at `sf1-v2/opencode-plugin/`, so the gate prints `SKIP: no package.json
found` and never runs at all. This plan closes that gap entirely inside the extension's own
source-store hook (`agent-system/extensions/typescript/scripts/typescript-verify.sh`) via a
bounded, vendor-excluded fallback search, adds the regression suite the extension currently
lacks, syncs the two prose/derived surfaces that are coupled to those edits, and then re-runs
the original falsifiability experiment end-to-end against the same real repository.

### Premise Re-Validation (Carried-Figure Discipline)

The dispatch's `## Description` carried two flagged lines. Both were checked against live state
during this planning dispatch, not merely against the prior report:

- **"86 test suites"** — CONFIRMED UNCHANGED. `ls sf1-v2/opencode-plugin/test/*.test.ts | wc -l`
  returns `86` today. The rest of the target profile also re-confirmed live: `"type": "module"`,
  `"test": "node --test test/*.test.ts"`, `find . -iname 'tsconfig*.json'` returns nothing, no
  `package.json` at the repo root.
- **"PASS CONDITION. The extension's detection logic must correctly identify that profile and
  run the verification gate appropriately"** — CONFIRMED STILL FAILING. Re-running
  `bash .claude/scripts/typescript-verify.sh 622 typescript specs/dummy sess_replan preflight`
  from the sf1-engine repo root today still prints `SKIP: no package.json found -- no
  Node/TypeScript project in scope, nothing to verify` / `summary: ran_pass=0 ran_fail=0
  skipped_no_command=1`, exit 0. The defect is live, not an artifact of the research run.

### Research Integration

- The fix layer is settled by the research and is not re-opened here: **not** a `cd` at the
  `skill_run_extension_hook` / `command-gate-out.sh` call site (no generically correct directory
  exists at that layer — `$task_dir` is a `specs/NNN_slug/` management directory), but a bounded
  fallback search inside the hook's own detection. This is also where the task's HARD CONSTRAINT
  points.
- The research re-derived the `find`-based fallback against the live corpus and confirmed it
  locates `sf1-v2/opencode-plugin/package.json` and nothing else under sf1-engine.
- `typescript` is the only extension declaring a `verification` hook, so there is no sibling
  directory-scoping pattern to borrow; the shape below is originated here.
- sf1-engine's own lab suite has 29 pre-existing failing subtests. Reporting `ran_fail` for that
  project is the hook working correctly, not a defect, and is explicitly out of scope.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No `roadmap_path` was provided in this dispatch and no `roadmap_flag` is set; no roadmap phases
are added and no roadmap file was read or written.

## Goals & Non-Goals

**Goals**:
- The verification hook discovers a Node/TypeScript project that lives below cwd when none
  exists at cwd, using only generic, repo-independent signals.
- The existing single-root fast path stays byte-identical in behavior and cost (no `find` is
  executed when `package.json` already exists at cwd).
- Findings across multiple discovered projects are aggregated, never collapsed, and each line
  names which project directory it came from.
- The extension gains its first regression suite, discovered by `run-all.sh` and declared in its
  manifest.
- The original falsifiability experiment is re-run end-to-end and passes, with zero
  sf1-engine-specific content anywhere in `agent-system/extensions/typescript/`.

**Non-Goals**:
- Changing `skill_run_extension_hook`, `command-gate-out.sh`, or any other call-site cwd
  behavior.
- Fixing sf1-engine's own 29 failing subtests, or any other property of that repository.
- Giving the hook a blocking mode, or changing its exit-code contract (exit 0 for any finding;
  non-zero only for the hook itself being unable to run).
- Generalizing the fallback to other extensions' hooks (no other extension declares one).

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| `find` fallback is slow/noisy on a large monorepo | M | M | Hard `-maxdepth` bound, vendor/VCS exclusions, a cap on projects verified with a loud notice when the cap truncates; fallback never runs at all in the common single-root case |
| Aggregated output obscures which project failed | M | M | Prefix every line of a non-cwd project's sub-checks with that project's relative directory; keep the three-state counters per project and in the final summary |
| One malformed nested `package.json` blanks out the whole gate | H | L | Keep `exit 1` only for the cwd-local project (unchanged contract); for a discovered nested project, warn on stderr, count `skipped_no_command`, and continue (documented in the script header and the prose doc) |
| Counter loss through a `find | while read` subshell | H | M | Iterate with `while IFS= read -r dir; do ... done < <(find ...)` process substitution, never a pipeline, so the counters live in the parent shell |
| Regression suite accidentally shells out to a real `npm install` | M | M | Hermetic fixtures: a stub `npm`/`pnpm`/`yarn`/`bun` placed first on `PATH` inside each `mktemp -d` workdir; no network, no real package manager |
| New script/doc files silently break Gate 3 doc-lint | M | H | Both coupled derived surfaces (`manifest.json` `provides.scripts`, `index-entries.json` `line_count`) are regenerated in the same phase that moves their input — see Phases 2 and 3 |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2, 3 | 1 |
| 3 | 4 | 1, 2, 3 |

Phases within the same wave can execute in parallel.

### Phase 1: Bounded nested-project discovery in typescript-verify.sh [COMPLETED]

**Goal**: The hook finds and verifies every Node/TypeScript project beneath cwd when none exists
at cwd, with no repo-specific knowledge and no change to the single-root path.

**Tasks**:
- [x] Extract the existing per-directory detection (lockfile-priority package-manager resolution,
      `package.json` parse check, typecheck sub-check, test sub-check) into one function that
      takes a directory and a display prefix, `cd`s into it, runs the sub-checks unchanged, and
      restores the original cwd before returning. Keep the three counters (`ran_pass`,
      `ran_fail`, `skipped_no_command`) as parent-shell globals incremented by that function.
      *(completed: `verify_project()` function added)*
- [x] Preserve the fast path exactly: when `package.json` exists at cwd, verify that one
      directory with an empty display prefix and do **not** invoke `find`. Output for this case
      must be byte-identical to today's. *(completed: fixture A confirmed byte-identical output)*
- [x] Add the fallback, reached only when no `package.json` exists at cwd:
      `find . -maxdepth 4 -name package.json -not -path '*/node_modules/*' -not -path '*/.git/*'
      -not -path '*/dist/*' -not -path '*/build/*' -not -path '*/.next/*' -not -path '*/out/*'
      -not -path '*/vendor/*' -not -path '*/.venv/*'`, results sorted for determinism, iterated
      via `while IFS= read -r ... done < <(find ...)` (process substitution, never a pipeline —
      a pipeline puts the loop in a subshell and silently discards every counter increment).
      *(completed: fixtures B, D, H confirm discovery, exclusion, and depth bound)*
- [x] Cap the number of discovered projects verified (10) and print an explicit, named notice
      when the cap truncates the list — a truncated run must never look like a complete one.
      *(completed: fixture G confirms 10 verified, loud NOTICE for remaining 2)*
- [x] Prefix every output line of a discovered (non-cwd) project with its relative directory,
      extending the existing `[typescript-verify]` prefix rather than replacing it.
      *(completed: fixture B shows `[typescript-verify][a/b] ...`)*
- [x] Preserve the terminal no-project behavior: when the fallback also finds nothing, print the
      existing `SKIP: no package.json found ...` line verbatim, increment
      `skipped_no_command`, print the summary, and `exit 0`. *(completed: fixture C verbatim)*
- [x] Malformed-`package.json` policy, decided here and recorded in the script header: a
      malformed `package.json` **at cwd** keeps today's `exit 1` hook-input-error contract
      unchanged; a malformed one at a **discovered nested** project emits an `ERROR: ...
      skipping` line on stderr, counts `skipped_no_command`, and continues, so one bad nested
      manifest cannot blank out findings for every sibling project.
      *(completed: fixtures E (nested, exit 0, warned+skipped) and F (cwd-local, exit 1) confirm)*
- [x] Re-check `set -euo pipefail` interactions on every new path (`find` with zero matches, the
      `ls tsconfig*.json` guard inside the extracted function, arithmetic increments at value 0).
      *(completed: audit recorded in script header comment)*
- [x] Update the script's own header comment to describe the two-tier detection (cwd-local fast
      path, then bounded fallback), the exclusion list, the depth bound, the project cap, and the
      malformed-manifest policy above. *(completed)*

**Timing**: 1.25 hours

**Depends on**: none

**Verification Tier**: local

**Tier Justification**: `bash -n` plus direct execution of the edited script against three
throwaway `mktemp -d` layouts covers this edit completely — the script is not deployed in this
repo (`typescript` is not among this repo's loaded extensions), nothing else in the repo
references it yet, and no cross-file wiring moves in this phase.

**Scope Hypothesis**: this fix is contained to `typescript-verify.sh` alone and needs no change
to any other *executable or wiring* file in the extension (manifest `hooks` block, agents,
skills, rules). Confirm before closing by grepping `agent-system/extensions/typescript/` for any
other file that re-states single-location detection; the only expected companion is the prose
doc, which Phase 3 owns.

**Files to modify**:
- `agent-system/extensions/typescript/scripts/typescript-verify.sh` - extract per-directory
  verification into a function; add the bounded, vendor-excluded fallback search, path-prefixed
  output, project cap, and the nested-malformed-manifest policy; update the header comment.

**Verification**:
- `bash -n agent-system/extensions/typescript/scripts/typescript-verify.sh` is clean, and
  `shellcheck` on the same file reports nothing new (if `shellcheck` is on PATH).
- Hand-run against three `mktemp -d` layouts: (a) `package.json` at the workdir root — output
  byte-identical to the pre-change script run on the same fixture; (b) `package.json` only at
  `a/b/package.json` — discovered, lines path-prefixed, sub-checks run; (c) no `package.json`
  anywhere — the verbatim terminal SKIP line, summary, exit 0.
- Pre-deploy live smoke: `cd /home/benjamin/Projects/Sapience/sf1-engine && timeout 300 bash
  /home/benjamin/.config/nvim/agent-system/extensions/typescript/scripts/typescript-verify.sh
  622 typescript specs/dummy sess_test preflight` names `sf1-v2/opencode-plugin` and runs the
  test sub-check (the authoritative, deployed-copy version of this run is Phase 4's).

---

### Phase 2: Regression suite and manifest script declaration [COMPLETED]

**Goal**: The new detection behavior is pinned by a hermetic suite that `run-all.sh` discovers
and that the extension's manifest declares.

**Tasks**:
- [x] Create `agent-system/extensions/typescript/scripts/tests/test-typescript-verify.sh`
      following this extension family's valid harness shape (a): locally defined
      `pass()`/`fail()`/`info()`, `PASSED`/`FAILED` integer counters, `SCRIPT_DIR` via
      `$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)`, `mktemp -d` workdir with `trap ... EXIT`,
      exit 0 on all-pass and 1 on any-fail — mirroring the sibling precedent at
      `agent-system/extensions/lean/scripts/tests/test-lean-src-roots.sh`. The extension has no
      `scripts/lib/common.sh` of its own, so the shared-harness shape (b) is not reachable from
      the source store here; both shapes are explicitly sanctioned by
      `context/standards/shell-script-testing.md` and `lint-test-harness-adoption.sh`.
      *(completed)*
- [x] Resolve the script under test as `$SCRIPT_DIR/../typescript-verify.sh` with a deployed
      `.claude/scripts/typescript-verify.sh` fallback, so the suite runs from both trees.
      *(completed)*
- [x] Make every fixture hermetic: write a stub `npm` (and, where the case needs it, `pnpm` /
      `yarn` / `bun`) into a `bin/` directory inside the `mktemp -d` workdir and prepend it to
      `PATH` for the duration of the case. No case may invoke a real package manager, hit the
      network, or install anything. *(completed: one shared `.stubbin/` prepended once for the
      whole suite run, reused across all 15 fixtures rather than per-case)*
- [x] Cases to cover: (1) `package.json` at cwd — fast path, no fallback, output unchanged;
      (2) lockfile priority at cwd across all four lockfiles; (3) no `package.json` at cwd, one
      at `a/b/` — discovered, path-prefixed, typecheck SKIPped for a no-tsconfig fixture, test
      sub-check run; (4) the only `package.json` lives under `node_modules/` — NOT discovered,
      terminal SKIP preserved; (5) nothing anywhere — terminal SKIP line and summary
      byte-identical to today's; (6) two nested projects — counters aggregated across both;
      (7) a `package.json` deeper than the depth bound — deliberately not discovered, asserting
      the bound rather than leaving it untested; (8) npm placeholder `test` script at a nested
      project — still rejected; (9) malformed nested `package.json` — warned, counted as
      skipped, other projects still verified, exit 0. *(completed: all nine cases plus two
      additional cases (project cap, cwd-malformed) -- 15 assertions total, all PASS)*
- [x] Add the mutation-check comment the testing standard requires: name which assertion
      (case 3) would start passing vacuously if the fallback search were deleted, and which
      (case 4) kills a mutation that dropped the `node_modules` exclusion. *(completed: comment
      added at the top of the suite; independently verified in a scratch mutated copy of
      typescript-verify.sh with the tier-2 fallback block reverted — cases 3, 6, 8, 9, and cap
      FAIL as expected, confirming the suite is not vacuous)*
- [x] Sync the coupled derived surface in this same phase:
      `bash .claude/scripts/sync-manifest-scripts.sh --write`, then confirm
      `bash .claude/scripts/sync-manifest-scripts.sh --check` exits clean. `provides.scripts` is
      derived from the on-disk `scripts/` tree and a missing entry fails
      `check-extension-docs.sh` Rule Q, which is `verify-deploy.sh` Gate 3 — commit-blocking, so
      it is regenerated here, not deferred. *(completed: `provides.scripts` now lists
      `tests/test-typescript-verify.sh` and `typescript-verify.sh`; `--check` reports
      `typescript: 2 on disk, 2 declared, 0 missing, 0 absent`)*

**Timing**: 1.5 hours

**Depends on**: 1

**Verification Tier**: interface

**Tier Justification**: the covering checks are `sync-manifest-scripts.sh --check` and
`check-extension-docs.sh --quiet` (Rule Q), which are exactly what verify the one cross-file
wiring contract this phase creates — a `provides.scripts` declaration matching the on-disk
`scripts/` tree. No pre-existing suite selection covers
`agent-system/extensions/typescript/**` (suite selection returns `__FULL_SWEEP__` for these
paths), because this phase is what first gives the extension a suite at all; running that new
suite is listed under Verification below as a direct invocation, not claimed here as
pre-existing coverage.

**Scope Hypothesis**: the suite is expected to need exactly the nine fixture cases enumerated
above and exactly one new `provides.scripts` entry (plus any fixture files, if the implementer
chooses on-disk fixtures over inline heredocs). Confirm the entry count from
`sync-manifest-scripts.sh --check`'s own report rather than asserting it; if fixtures are
written to disk, each one is a further `provides.scripts` entry that the same `--write` run must
pick up.

**Files to modify**:
- `agent-system/extensions/typescript/scripts/tests/test-typescript-verify.sh` - new hermetic
  regression suite for the two-tier detection.
- `agent-system/extensions/typescript/manifest.json` - `provides.scripts` regenerated to declare
  the new suite (and any on-disk fixtures); derived surface, not hand-edited.

**Verification**:
- `bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-typescript-verify.sh`
  discovers and passes the suite (source-store mode), and the suite is executable.
- Deliberately revert the fallback block in a scratch copy and confirm case 3 fails — the suite
  discriminates the fix rather than passing vacuously.
- `bash .claude/scripts/sync-manifest-scripts.sh --check` exits 0 with no gap in either
  direction.
- `bash .claude/scripts/check-extension-docs.sh --quiet` reports no new FAIL for `[typescript]`.

---

### Phase 3: Prose-doc sync for nested-project detection [COMPLETED]

**Goal**: The human-readable companion doc states the same two-tier detection the hook now
implements, and its derived `line_count` stays accurate.

**Tasks**:
- [x] Add a `## No \`package.json\` At cwd, But One Exists Below` section to
      `agent-system/extensions/typescript/context/project/typescript/tools/package-manager-detection.md`
      describing the bounded fallback: the depth bound, the vendor/VCS exclusion list, the
      deterministic sort, the project cap and its loud truncation notice, per-project
      path-prefixed output, aggregated three-state counters, and the
      nested-malformed-manifest-is-skipped-not-fatal policy. *(completed)*
- [x] Amend the existing `## No \`package.json\` At All` section so its "normal, expected
      terminal outcome" claim is scoped to *after* the bounded search has also come up empty —
      today it reads as unconditional and would now be wrong. *(completed)*
- [x] Grep `agent-system/extensions/typescript/` (`README.md`, `EXTENSION.md`, the two skills,
      the two agents, `rules/typescript-rules.md`, the adversarial-verification contract) for
      any other statement that detection is single-location, and update only those that are
      actually wrong. If `EXTENSION.md` is touched, re-check Rule U (length limit) and Rule V
      (claudemd merge-source byte ceiling) still pass. *(completed: grep found two hits, both in
      `typescript-rules.md` and `typescript-implementation-agent.md`, both about source-root
      layout flexibility within a project, not about the hook's cwd-fixed search -- neither was
      wrong, so neither was touched; `README.md`/`EXTENSION.md` statements about the
      verification hook already describe its per-sub-check behavior generically and were also
      not wrong. `EXTENSION.md` was not touched, so the Rule U/V re-check does not apply.)*
- [x] Sync the coupled derived surface in this same phase:
      `bash .claude/scripts/generate-context-line-counts.sh --check` to see the drift, then
      `--write`, then `--check` again to confirm clean. `index-entries.json`'s `line_count` for
      `project/typescript/tools/package-manager-detection.md` is currently `64` and matches
      `wc -l` exactly; any edit to that file moves it, and `check-extension-docs.sh` Rule R
      fails on the mismatch at `verify-deploy.sh` Gate 3 — commit-blocking, so it is regenerated
      here, not deferred. *(completed: line_count moved 64 -> 100, regenerated via --write,
      --check now reports typescript 9/9 exact)*

**Timing**: 0.5 hours

**Depends on**: 1

**Verification Tier**: prose

**Tier Justification**: this phase moves markdown plus the one derived `line_count` field, and
`generate-context-line-counts.sh --check` together with `check-extension-docs.sh --quiet` on
this extension is the exact check that covers both.

**Files to modify**:
- `agent-system/extensions/typescript/context/project/typescript/tools/package-manager-detection.md`
  - new nested-discovery section; terminal-outcome claim scoped to post-fallback.
- `agent-system/extensions/typescript/index-entries.json` - `line_count` regenerated for the
  edited context file(s); derived surface, not hand-edited.
- `agent-system/extensions/typescript/README.md` / `EXTENSION.md` - conditional, only if the
  grep above finds a now-wrong single-location claim.

**Verification**:
- `bash .claude/scripts/generate-context-line-counts.sh --check` exits 0.
- `bash .claude/scripts/check-extension-docs.sh --quiet` reports no new FAIL for `[typescript]`
  (covers Rules R, T, U, V and the context-orphan checks).
- Read-back: the doc's described fallback (depth bound, exclusions, cap, aggregation, malformed
  policy) matches the shipped script line for line, with no sf1-engine-specific example.

---

### Phase 4: Live re-validation against sf1-engine and full gate set [COMPLETED]

**Goal**: The original falsifiability experiment is re-run end-to-end on the real external
repository and now meets the PASS CONDITION, with the HARD CONSTRAINT mechanically falsified
rather than asserted.

**Tasks**:
- [x] Propagate the fixed hook to the target repo:
      `cd /home/benjamin/Projects/Sapience/sf1-engine && timeout 540 bash
      .claude/scripts/deploy-headless.sh` (invoke with the Bash tool's `timeout` parameter raised
      to 600000, per the bounded-wait idiom in `context/patterns/external-process-wait.md` Rule
      1). Then `diff` the deployed `.claude/scripts/typescript-verify.sh` against the source-store
      copy and confirm they are identical — a stale deployed copy would make the whole experiment
      vacuous. *(completed: deploy landed, `diff` confirmed byte-identical. Inline verification
      reported 2 pre-existing FAILs in sf1-engine's own tree -- task-reference lint and
      runtime-file-tracking policy -- both unrelated to the typescript extension; see
      verification notes)*
- [x] Re-run the hook exactly as the real lifecycle invokes it, from the repo root and with no
      `cd` into the project: `cd /home/benjamin/Projects/Sapience/sf1-engine && bash
      .claude/scripts/typescript-verify.sh 622 typescript specs/dummy sess_test preflight`, with
      a bounding `timeout` (the test sub-check runs the project's full suite). *(completed)*
- [x] Assert the PASS CONDITION against that output: it names `sf1-v2/opencode-plugin`; the
      typecheck sub-check SKIPs (no tsconfig and no typecheck script); the package manager
      resolves to `npm` (no lockfile); the test sub-check runs `npm run test` ->
      `node --test test/*.test.ts`; and the final summary is no longer
      `ran_pass=0 ran_fail=0 skipped_no_command=1`. *(completed: all five hold. New summary:
      `ran_pass=0 ran_fail=1 skipped_no_command=1` -- the test sub-check ran and reported real
      findings, 531 passed / 29 failed / 46 skipped subtests)*
- [x] Falsify the HARD CONSTRAINT mechanically: `grep -rniE 'sf1|opencode-plugin|sapience'
      agent-system/extensions/typescript/` must return nothing. Any hit means the fix was
      special-cased to the repo and the phase fails. *(completed with a recorded clarification:
      the literal combined grep returns 2 lines, both the pre-existing, universal
      `sapience-retrieve.sh` memory-context call present in every extension's skills since task
      499/620, well before this task. `sf1` alone and `opencode-plugin` alone each return ZERO
      hits -- the HARD CONSTRAINT's actual intent, no sf1-engine-specific content, is satisfied;
      recorded via issue-record.sh as class "verification ambiguity")*
- [x] Record the live test outcome as a finding, not a defect: a `ran_fail` for
      `sf1-v2/opencode-plugin` caused by that repo's own pre-existing failing subtests is the
      hook working as intended and is out of scope for this task. *(completed: 29 failing
      subtests, matching the Scope Hypothesis's carried-forward figure exactly)*
- [ ] Redeploy this repo (`timeout 540 bash .claude/scripts/deploy-headless.sh`, same bounded-wait
      idiom) — its deployed tree is currently stale for the `lean` extension, and the
      completion-deploy gate refuses on a stale deploy when `modified_files` overlap
      `agent-system/extensions/**`, which this task's do.
      *(deviation: deferred -- this dispatch's own `.dispatch/13.md` carries a Batch Gate
      Deferral directive for this phase: the costly whole-tree redeploy and full gate battery
      are deferred to the batch-level invocation at the end of this multi-task `/orchestrate`
      cycle rather than run independently here. A prior session's own finding
      ("Completion-deploy gate is self-healing") additionally confirms the next cycle's
      Inter-Cycle Redeploy Checkpoint performs this redeploy and reconciliation automatically, so
      no action is lost by deferring it)*
- [ ] Run the full gate set (below) and resolve any failure before closing.
      *(deviation: deferred -- discharged against the scoped tier instead, per the same Batch
      Gate Deferral directive: Gate 3 doc-lint was already run directly in Phases 2-3
      (`check-extension-docs.sh --quiet`, typescript PASS); Gate 8's shell-test content was run
      scoped via `run-all.sh --only test-typescript-verify.sh` (Phase 2, PASS) rather than the
      full unfiltered battery; `sync-manifest-scripts.sh --check` and
      `generate-context-line-counts.sh --check` are both clean. The full unfiltered
      `verify-deploy.sh`/`run-all.sh`, `check-task-references.sh --quiet`, and
      `validate-state.sh --deep` are deferred to the once-per-invocation batch-level stage, per
      `context/formats/plan-format.md`'s "Batch-aware deferral" subsection -- never forgiven,
      only deferred)*

**Timing**: 1 hour

**Depends on**: 1, 2, 3

**Verification Tier**: full

**Scope Hypothesis**: the expectation that the run reports `ran_fail` for exactly one project,
driven by 29 pre-existing failing subtests out of 560, is carried from the prior research run and
is a hypothesis, not a fact — the suite is timing- and environment-sensitive. Confirm the actual
counts from this run's own output and record them; a different failure count does not by itself
indicate a defect in the hook, whereas a *missing* `sf1-v2/opencode-plugin` line does.

**Files to modify**:
- `__WHOLE_TREE__` - this phase invokes `deploy-headless.sh`, regenerating whole deployed trees.

**Verification**:
- The live sf1-engine run from the repo root names `sf1-v2/opencode-plugin` and runs the test
  sub-check — the literal inverse of the failure reproduced at plan time.
- `grep -rniE 'sf1|opencode-plugin|sapience' agent-system/extensions/typescript/` returns
  nothing.
- `bash .claude/scripts/verify-deploy.sh` passes (notably Gate 3 doc-lint and Gate 8 shell test
  suites).
- `bash agent-system/extensions/core/scripts/tests/run-all.sh` passes unfiltered (not the
  `--only` subset used in Phase 2 — a selected-subset pass is not evidence for the battery).
- `bash .claude/scripts/check-extension-docs.sh --quiet`, `bash
  .claude/scripts/check-task-references.sh --quiet`, and `bash .claude/scripts/validate-state.sh
  --deep` all pass.

---

## Testing & Validation

- [x] Single-root fast path produces byte-identical output to the pre-change script, and runs no
      `find`. *(verified: fixture A / Case 1)*
- [x] A project one or more directories below cwd is discovered and fully verified. *(verified:
      fixture B / Case 3)*
- [x] A `package.json` reachable only through `node_modules/` (or another excluded directory) is
      never discovered. *(verified: fixture D / Case 4)*
- [x] A repo with no `package.json` anywhere keeps the verbatim terminal SKIP line, summary, and
      exit 0. *(verified: fixture C / Case 5, byte-identical comparison)*
- [x] Multiple discovered projects aggregate their three-state counters, with each line naming
      its project directory. *(verified: Case 6)*
- [x] The depth bound and the project cap are each asserted by a case, and the cap prints a loud
      truncation notice. *(verified: fixture H / Case 7 (depth), fixture G / Case cap (project
      cap))*
- [x] A malformed nested `package.json` is skipped with a stderr warning while sibling projects
      are still verified; a malformed cwd-local one keeps the exit-1 contract. *(verified:
      fixture E / Case 9 (nested), fixture F / Case cwd-malformed (cwd-local))*
- [x] The live sf1-engine run from the repo root meets the PASS CONDITION. *(verified: Phase 4)*
- [x] No sf1-engine-specific string exists anywhere under
      `agent-system/extensions/typescript/`. *(verified with a recorded clarification: `sf1` and
      `opencode-plugin` each return zero hits; the combined grep's 2 `sapience` hits are the
      pre-existing, universal `sapience-retrieve.sh` memory boilerplate shared by every
      extension, unrelated to the target repo -- see Phase 4's verification notes)*

## Artifacts & Outputs

- Updated `agent-system/extensions/typescript/scripts/typescript-verify.sh` with two-tier
  detection.
- New `agent-system/extensions/typescript/scripts/tests/test-typescript-verify.sh` regression
  suite (the extension's first).
- Regenerated `agent-system/extensions/typescript/manifest.json` `provides.scripts` and
  `agent-system/extensions/typescript/index-entries.json` `line_count`.
- Updated `package-manager-detection.md` nested-discovery documentation.
- A recorded live-run transcript from sf1-engine demonstrating the PASS CONDITION, to be carried
  into the implementation summary.

## Rollback/Contingency

Every edit in this plan is confined to `agent-system/extensions/typescript/**` plus two derived
files inside that same directory; nothing in core, no call site, and no other extension is
touched. If the fallback proves unworkable, reverting the single commit that touches
`typescript-verify.sh` restores today's exact single-location behavior, and the regression suite
added in Phase 2 remains valid for the cwd-local cases (its nested cases become the documented
known-failing record of the open gap). The deployed copies in both repos are disposable deploy
artifacts regenerated from this source store, so no rollback action is needed in
`/home/benjamin/Projects/Sapience/sf1-engine` beyond re-running its `deploy-headless.sh`. If the
live re-validation in Phase 4 fails in a new way, that is a finding for a follow-up research
round, not a reason to special-case sf1-engine — the HARD CONSTRAINT holds regardless of
outcome.
