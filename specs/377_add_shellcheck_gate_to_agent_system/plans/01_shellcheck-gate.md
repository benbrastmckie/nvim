# Implementation Plan: Task #377

- **Task**: 377 - Add shellcheck gate to agent-system
- **Status**: [NOT STARTED]
- **Effort**: 10.5 hours
- **Dependencies**: None
- **Research Inputs**: specs/377_add_shellcheck_gate_to_agent_system/reports/01_shellcheck_gate.md
- **Artifacts**: plans/01_shellcheck-gate.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Add a shellcheck lint to the agent system's source store and land it green in the same task. The
work is one new standalone lint script following the twelve-precedent `lint/lint-*.sh` shape, one
both-polarity fixture test auto-discovered by `run-all.sh`, a numbered-gate wiring in
`verify-deploy.sh`, and a four-pass fix sweep over the 196 findings currently present. The fix
sweep lands **before** the gate wiring so the gate is green the moment it becomes enforceable,
which is what the task's framing ("green from the day it lands") requires; the lint script and its
fixture test can land earlier because neither is wired into any gate until the final phase.

### Research Integration

The research report's recommendations are adopted essentially intact, with three corrections that
plan-time verification surfaced:

- **Measurement confirmed, not carried.** `shellcheck -x -S warning -f gcc` over
  `git ls-files -- 'agent-system/extensions/*.sh'` (359 tracked files, shellcheck 0.11.0) was
  re-run at plan time and reproduces the report exactly: **196 findings across 82 files**, with an
  identical per-code histogram (SC2034 108, SC2164 31, SC2155 15, SC2154 10, SC2088 6, SC2043 5,
  SC2010 4, SC1090 4, SC2207 3, SC2319 2, SC2206 2, SC2066 2, SC2063 2, SC2125 1, SC2053 1). Every
  specifically named site matches, including both SC2066 single-pass loops and both `session_id`
  SC2154 sites.
- **Correction 1 — manifest registration is required and the report omits it.**
  `agent-system/extensions/core/manifest.json`'s `provides.scripts` array (238 entries) lists
  every sibling lint and its fixture test by relative path
  (`lint/lint-state-writer-boundary.sh`, `tests/test-lint-state-writer-boundary.sh`). Without the
  two new entries the script and test never deploy into `.claude/`, and Gate 22 would pass in the
  source store while being absent from every consumer tree.
- **Correction 2 — `git ls-files` alone cannot serve the fixture test.** The acceptance criterion
  requires a seeded SC2155 in a fixture to fail the lint, and the established fixture pattern
  writes synthetic scripts into a `mktemp -d` workdir that is not a git work tree. The resolution
  is already precedented: `lint-state-writer-boundary.sh` accepts positional scan paths
  (`bash "$LINT_SCRIPT" "$DIRTY_DIR"`) and walks them with `find`. The new lint adopts the same
  dual contract — no argument means `git ls-files` over the source store, an explicit path
  argument means `find` over that path.
- **Correction 3 — five range-literal sites, not two.** The report names
  `verify-deploy.sh:119,125`. There are four live `1-21` occurrences (two in the header comment
  block around lines 80 and 86, two in the `--only-gate` error strings) plus one already-stale
  inline comment reading `in 1..20`. Phase 7 targets all of them by grep, not by line number.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No `roadmap_path` was supplied in this dispatch, so `specs/ROADMAP.md` was not loaded as planning
input. It was consulted only to check for territory collisions, which surfaced one material
finding carried into Risks below: ROADMAP lists task **318** as `ready` with the description
"Wire lint-directory-pathspec-boundary.sh into verify-deploy.sh as a numbered gate". That task and
this one would both claim the next free gate number and both must edit the same `--only-gate`
range literals.

## Goals & Non-Goals

**Goals**:
- A standalone shellcheck lint covering every tracked `*.sh` under `agent-system/extensions/`
  (all five extensions with findings: core, lean, literature, nix, nvim), at `-S warning`.
- An unresolvable `shellcheck` binary is a named non-zero failure (exit 70, adopting the cited
  `Logos/Verification/scripts/lint-shell.sh` convention) — never a silent skip, never a `bash -n`
  substitute.
- Zero findings at `-S warning` on the source store when the task closes.
- A both-polarity fixture test proving the gate actually fails on a seeded SC2155.
- The lint wired into `verify-deploy.sh` as a numbered gate and reachable through the normal
  runner, with both the lint and its test registered in core's manifest so they deploy.
- Every deliberate exception is an inline `# shellcheck disable=SCxxxx` with a one-line reason.

**Non-Goals**:
- Consumer repos' own lint sets. Logos/Verification dropping `.claude/` from its CI Hygiene scope
  is filed there, not here.
- Raising severity below `warning` (no `-S style`/`-S info` sweep).
- Pinning the shellcheck version, or adding a nix devShell re-entry wrapper — this repo resolves
  `shellcheck` directly on `PATH` (confirmed at `/home/benjamin/.nix-profile/bin/shellcheck`,
  v0.11.0), unlike the sibling repo whose precedent is being borrowed.
- Any file- or repo-level blanket disable, including a root `.shellcheckrc` suppressing a whole
  code class. Explicitly forbidden by the task.
- A new `context/standards/*.md` doc for the lint. None of the twelve sibling lints has one; each
  self-documents in its own header.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Gate-number collision with ROADMAP task 318, which also wires a new numbered gate and bumps the same range literals | M | M | Do not hardcode 22. Phase 7 re-derives the next free gate number from `grep -c 'gate_selected'` and the live range literals at implementation time (recorded as that phase's Scope Hypothesis), and bumps every `1-NN` site found by grep rather than by line list |
| SC2034's 108 findings are the dominant scope risk; deleting a variable shellcheck calls unused but that is a live closed-over global or exported-for-a-child-process silently changes runtime behavior | H | M | Split into two phases (core 74, non-core 34). Default to inline-disable-with-reason, not deletion; delete only when a `grep -rn` for the name across the extension confirms no other consumer. `lib/phase-heading-patterns.sh` (10) and `scripts/skill-base.sh` (3) are shared surfaces and drive Phase 5's `full` tier |
| SC2164 `cd` fixes inside the backgrounded worker subshells of `test-state-write-concurrency.sh` (20 findings) could use `|| exit` where `|| return` was meant, killing a concurrency harness early and turning a real regression into a silent pass | H | M | Use `\|\| return 1` inside any function/subshell context. Phase 4 asserts the suite's PASS count and worker count are unchanged after the fix, not merely that shellcheck is quiet |
| The new lint script or fixture test itself emits shellcheck findings, making the gate fail on its own authors | M | M | Phase 1 and Phase 2 each run the new lint over their own new file before closing |
| Shellcheck version drift: 196/82 is measured against 0.11.0; a different version on `PATH` reports a different set at the same severity | L | M | Inherent to any unpinned binary-resolved lint and shared by the cited precedent. The acceptance bar is "passes on the source store" at implementation time. The lint prints the resolved `shellcheck --version` so a future drift is diagnosable from gate output rather than mysterious |
| Missing manifest registration would leave Gate 22 green in the source store and the lint absent from every deployed tree | M | L | Explicit manifest steps in Phases 1, 2, and 7; Phase 7 verifies the deployed `.claude/scripts/lint/lint-shellcheck.sh` and `.claude/scripts/tests/test-lint-shellcheck.sh` exist after redeploy |
| `--findings` scraping convention mismatch: Gates 12/21 scrape `[VIOLATION]`-prefixed lines, shellcheck's native `gcc` format has no such prefix | L | M | The lint emits each finding as its own `[VIOLATION] file:line:col: severity: message [SCxxxx]` line, so Gate 22's scrape is a verbatim copy of Gate 21's with no new mechanism |

## Implementation Phases

**Dependency Analysis**:

| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2, 3 | 1 |
| 3 | 4 | 3 |
| 4 | 5 | 4 |
| 5 | 6 | 5 |
| 6 | 7 | 2, 6 |

Phases within the same wave can execute in parallel. Two separate reasons drive the sequencing,
and they are not interchangeable:

- **Phase 1 gates every fix phase** because `lint/lint-shellcheck.sh` is the repository's
  sanctioned entry point for shellcheck once it exists, and every fix phase's verification
  criteria must invoke that entry point and check its exit status rather than calling the bare
  `shellcheck` binary. The fix passes are not logically dependent on the lint script — they are
  dependent on it as their *verifier*.
- **Phases 3 -> 4 -> 5 -> 6 are serialized** because their file territories overlap:
  `tests/test-resume-scan-nonconformance.sh` carries both a Phase 3 class and a Phase 4 class
  finding, and several files carry both an SC2034 and a non-SC2034 finding. Shared territory is a
  reason to serialize, not to exclude.

---

### Phase 1: Author lint-shellcheck.sh [NOT STARTED]

**Goal**: A standalone `lint-shellcheck.sh` that lints every tracked `*.sh` under
`agent-system/extensions/` at `-S warning`, fails non-zero with a named message when the binary
is unresolvable, and is registered in core's manifest. Wired into no gate yet.

**Tasks**:
- [ ] Create `agent-system/extensions/core/scripts/lint/lint-shellcheck.sh`, structurally modeled
      on `lint/lint-state-writer-boundary.sh` (357 lines) and `lint/lint-hook-registration-paths.sh`
      (595 lines): `set -uo pipefail`, `--verbose`/`--quiet` flags, positional scan paths
      accumulated into a `SCAN_PATHS` array, `SCRIPT_DIR` resolution, a self-documenting header.
- [ ] Write the header's `WHY THIS EXISTS` and `EXIT-CODE CONTRACT` sections. Exit codes:
      `0` no findings; `1` one or more findings; `2` script error (unresolvable repo root,
      unreadable scan path); `70` `shellcheck` not resolvable on `PATH`.
- [ ] Implement binary resolution: `command -v shellcheck` first. On failure print a named stderr
      message naming the tool and stating that no substitute check was run, then `exit 70`. Never
      fall back to `bash -n`, never exit 0. Echo the resolved `shellcheck --version` line under
      `--verbose` so version drift is diagnosable from gate output.
- [ ] Implement the dual file-set contract (Correction 2 above): with no positional scan path, run
      `git ls-files -z -- 'agent-system/extensions/*.sh'` from the resolved repo root; with one or
      more positional paths, walk each with `find "$path" -type f -name '*.sh'`. Both branches feed
      the same array.
- [ ] Invoke `shellcheck -x -S warning -f gcc "${files[@]}"` and re-emit each output line prefixed
      `[VIOLATION] ` so Gate 22 can reuse Gate 21's scrape verbatim. Honor `--quiet` (counts only)
      and `--verbose` (per-file progress plus the resolved version).
- [ ] Handle the empty-file-set case as a named exit 2, not a silent exit 0 — an empty set means
      the scan root or the `git ls-files` pathspec is wrong, which must never read as green.
- [ ] Register `"lint/lint-shellcheck.sh"` in `agent-system/extensions/core/manifest.json`'s
      `provides.scripts` array, in the array's existing sort position.
- [ ] Run the new lint against its own file and fix anything it reports.

**Timing**: 1.5 hours

**Depends on**: none

**Verification Tier**: local

**Scope Hypothesis**: The lint is asserted to need no behavior beyond what the two modeled sibling
scripts already demonstrate (flag parsing, `SCAN_PATHS`, repo-root resolution, `[VIOLATION]`
emission). Confirm by diffing the new script's structure against
`lint/lint-state-writer-boundary.sh` before closing; any divergence beyond the shellcheck-specific
binary resolution and file-set logic is unplanned scope and must be justified in the commit.

**Tier Justification**: The new file has no caller and is wired into no gate in this phase, so the
covering check is direct invocation of both polarities plus
`bash agent-system/extensions/core/scripts/lint/lint-shellcheck.sh <fixture-dir>`; no suite exists
for it until Phase 2 creates `tests/test-lint-shellcheck.sh`.

**Files to modify**:
- `agent-system/extensions/core/scripts/lint/lint-shellcheck.sh` - new file, the lint itself
- `agent-system/extensions/core/manifest.json` - add the lint to `provides.scripts`

**Verification**:
- `bash agent-system/extensions/core/scripts/lint/lint-shellcheck.sh --verbose` exits 1 today
  (196 findings — the pre-fix tree) and prints `[VIOLATION]`-prefixed lines.
- Against a scratch directory holding one clean script: exits 0.
- Against a scratch directory holding one script with `local x=$(false)`: exits 1 and the output
  names SC2155.
- With `PATH` stripped of `shellcheck`: exits 70 and the stderr message names the tool.
- `bash -n` on the new script passes, and the lint reports zero findings on itself.
- `jq -e '.provides.scripts | index("lint/lint-shellcheck.sh")' agent-system/extensions/core/manifest.json`
  succeeds.

---

### Phase 2: Both-polarity fixture test [NOT STARTED]

**Goal**: `tests/test-lint-shellcheck.sh` proves the lint fails on a seeded SC2155 and passes on a
clean fixture, is discovered by `run-all.sh` without extra wiring, and is registered in core's
manifest. This phase satisfies the acceptance criterion's fixture clause.

**Tasks**:
- [ ] Create `agent-system/extensions/core/scripts/tests/test-lint-shellcheck.sh`, structurally
      modeled on `tests/test-lint-state-writer-boundary.sh` (203 lines): `set -uo pipefail`,
      `SCRIPT_DIR`, the depth-independent `REPO_ROOT` resolution via `git rev-parse --show-toplevel`
      with a fixed-depth fallback, the `resolve_candidate` helper trying the deployed
      `.claude/scripts/lint/` path before the source-store `../lint/` path, `pass`/`fail`/`info`
      counters, a `mktemp -d` workdir with a `trap cleanup EXIT`.
- [ ] Negative polarity: write a fixture script containing `local x=$(false)` inside a function;
      assert the lint exits non-zero and its output names SC2155.
- [ ] Positive polarity: write a fixture script that is clean at `-S warning`; assert exit 0.
- [ ] Unresolvable-binary polarity: invoke the lint with a `PATH` that cannot resolve
      `shellcheck`; assert exit status is exactly 70 and that the message names the tool. This is
      the task's "never a silent skip" requirement, so it is asserted, not assumed.
- [ ] Empty-scan-path polarity: assert a scan path containing no `*.sh` files exits 2, not 0.
- [ ] Assert `--quiet` suppresses per-finding lines while preserving the exit code, and `--verbose`
      emits the resolved shellcheck version — matching the sibling test's flag-behavior cases.
- [ ] Leave the live tree deliberately out of scope for this test, matching
      `test-lint-state-writer-boundary.sh`'s own documented posture ("never depends on the live
      tree being clean (that is a separate, whole-tree assertion)"); the whole-tree assertion is
      Gate 22's job in Phase 7.
- [ ] Register `"tests/test-lint-shellcheck.sh"` in core's `manifest.json` `provides.scripts`.
- [ ] Run the new lint against the new test file and fix anything it reports.

**Timing**: 1 hour

**Depends on**: 1

**Verification Tier**: local

**Scope Hypothesis**: `run-all.sh` is asserted to discover the new suite with no wiring change, by
its existing `tests/test-*.sh` glob. Confirm with
`bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-lint-shellcheck.sh`, which
refuses loudly on an unknown basename — so a passing `--only` run is itself the discovery proof.

**Tier Justification**: Covered by `bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-lint-shellcheck.sh`,
which both runs the new suite and proves its discovery; the only other file touched is a manifest
array entry with no executable surface.

**Files to modify**:
- `agent-system/extensions/core/scripts/tests/test-lint-shellcheck.sh` - new file, the fixture test
- `agent-system/extensions/core/manifest.json` - add the test to `provides.scripts`

**Verification**:
- `bash agent-system/extensions/core/scripts/tests/test-lint-shellcheck.sh` exits 0 with every
  case `[PASS]` and `FAILED=0`.
- `bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-lint-shellcheck.sh`
  exits 0 (and thereby proves discovery, since `--only` rejects an undiscovered basename).
- The lint reports zero findings on the new test file.
- `jq -e '.provides.scripts | index("tests/test-lint-shellcheck.sh")' agent-system/extensions/core/manifest.json`
  succeeds.

---

### Phase 3: Real-defect fix pass [NOT STARTED]

**Goal**: Clear the 33 findings that are genuine or exit-code-masking defects rather than hygiene
noise: both SC2066 single-pass loops, both SC2319 sites, all 15 SC2155, all 10 SC2154, and the
four glob/quote-semantics findings (SC2053, SC2125, SC2063 x2). These are the "real defects first"
set the task description names.

**Tasks**:
- [ ] Fix the 2 SC2066 single-pass loops — `tests/test-resume-scan-nonconformance.sh:140` and
      `lean/scripts/tests/test-lean-mcp-preflight-check.sh:102`. These are real bugs: the loop
      body currently runs once instead of per item. Unquote or restructure so the loop actually
      iterates, then confirm the enclosing suite's assertion count rises accordingly — a
      single-pass loop that was silently skipping cases will now exercise them, and any newly
      exposed failure is a real finding to fix, not a regression to revert.
- [ ] Fix the 2 SC2319 sites at `tests/test-orchestrate-cycle-plan.sh:4040,4042`: capture the real
      command's exit status into a variable before the conditional instead of reading `$?` after a
      condition.
- [ ] Fix all 15 SC2155 by splitting `local x=$(cmd)` into `local x; x=$(cmd)` so `cmd`'s exit
      code is no longer masked. Heaviest: `scripts/uninstall-extension.sh` and
      `scripts/install-extension.sh`.
- [ ] Triage all 10 SC2154 per site into "caller-provided closed-over global" vs. "genuine bug".
      The 2 `session_id` sites (`lib/territory-contention-lib.sh:237`,
      `lib/redeploy-checkpoint-lib.sh:216`) are confirmed closed-over globals the sourcing caller
      sets — inline-disable with a one-line reason. For each of the remaining 8
      (`post_deploy_reconcile_json`, `dry_run`, `cycle_count`, `canonical_force_phases_json`,
      `new_cycle_count`, `triage_ndjson`, `admit_ndjson`, `_p`) run `grep -rn` for the name to
      confirm a caller assigns it before concluding it is intentional.
- [ ] Fix the 4 glob/quote-semantics findings: SC2125 at `core/hooks/claude-stop-notify.sh:44`,
      SC2063 x2 at `scripts/deprecated/roadmap-integration.sh:683,687`, SC2053 at
      `lib/file-scope-overlap.sh:211`. Each needs a per-site read of whether the glob behavior is
      intentional; where it is, inline-disable with a reason rather than changing semantics.
- [ ] Confirm every deliberate exception added in this phase is an inline
      `# shellcheck disable=SCxxxx` with a one-line reason on the same or preceding line, matching
      house style (`lib/territory-contention-lib.sh:221,225`,
      `scripts/deprecated/roadmap-integration.sh:324`, `scripts/skill-base.sh:195`).

**Timing**: 1.5 hours

**Depends on**: 1

**Verification Tier**: interface

**Scope Hypothesis**: 33 findings across 15 files is asserted from the plan-time measurement.
Confirm at implementation time via the sanctioned entry point, not the bare binary: run
`bash agent-system/extensions/core/scripts/lint/lint-shellcheck.sh --verbose` before starting and
filter its `[VIOLATION]` output with `grep -cE 'SC2066|SC2319|SC2155|SC2154|SC2053|SC2125|SC2063'`
(expect 33), then repeat after finishing (expect 0). A different before-count means the tree moved
and the file list below must be re-derived rather than trusted from this plan.

**Tier Justification**: The SC2154 and SC2155 edits change assignment structure inside shared
sourced libraries (`lib/territory-contention-lib.sh`, `lib/redeploy-checkpoint-lib.sh`,
`lib/task-classification-lib.sh`, `lib/file-scope-overlap.sh`) whose sourcers are enumerable but
span files; the covering check is
`bash agent-system/extensions/core/scripts/tests/run-all.sh --only <basenames resolved by suite_selection_select over this phase's touched paths>`.

**Files to modify**:
- `agent-system/extensions/core/scripts/uninstall-extension.sh` - 6 findings (SC2155)
- `agent-system/extensions/core/scripts/install-extension.sh` - 5 findings (SC2155)
- `agent-system/extensions/core/scripts/lib/redeploy-checkpoint-lib.sh` - 4 SC2154
- `agent-system/extensions/lean/scripts/tests/test-lean-mcp-preflight-check.sh` - SC2066 + SC2154
- `agent-system/extensions/core/scripts/tests/test-orchestrate-cycle-plan.sh` - 2 SC2319
- `agent-system/extensions/core/scripts/task-lock.sh` - 2 SC2155
- `agent-system/extensions/core/scripts/orchestrate-cycle-plan.sh` - 2 SC2154
- `agent-system/extensions/core/scripts/lib/territory-contention-lib.sh` - 2 SC2154
- `agent-system/extensions/core/scripts/deprecated/roadmap-integration.sh` - 2 SC2063
- `agent-system/extensions/lean/scripts/lean-comparator-run.sh` - 1 SC2155
- `agent-system/extensions/core/scripts/tests/test-resume-scan-nonconformance.sh` - 1 SC2066
- `agent-system/extensions/core/scripts/lib/task-classification-lib.sh` - 1 SC2154
- `agent-system/extensions/core/scripts/lib/file-scope-overlap.sh` - 1 SC2053
- `agent-system/extensions/core/hooks/subagent-postflight.sh` - 1 SC2155
- `agent-system/extensions/core/hooks/claude-stop-notify.sh` - 1 SC2125

**Verification**:
- `bash agent-system/extensions/core/scripts/lint/lint-shellcheck.sh --verbose` is re-run and its
  `[VIOLATION]` output filtered for these seven codes reports 0. (Its overall exit status is still
  1 at this point — the SC2034 and SC2164 classes remain — so the per-class count is the
  phase-scoped signal here; the exit-status check is Phase 6's and Phase 7's bar.)
- The suites resolved by `suite_selection_lib`'s `suite_selection_select` over this phase's touched
  paths all pass via `run-all.sh --only <list>`, checked by that command's exit status.
- `test-resume-scan-nonconformance.sh` and `test-lean-mcp-preflight-check.sh` both still exit 0
  after their loops are made to actually iterate, and their reported case counts are recorded in
  the commit message as evidence the loops now run more than once.

---

### Phase 4: Mechanical hygiene fix pass [NOT STARTED]

**Goal**: Clear the 55 remaining non-SC2034 findings: 31 SC2164 (`cd` without `|| exit`), 6
SC2088 (quoted tilde), 5 SC2043, 4 SC2010 (`ls | grep`), 4 SC1090, 3 SC2207, 2 SC2206.

**Tasks**:
- [ ] Fix the 31 SC2164 `cd` sites, 20 of them in `scripts/test-state-write-concurrency.sh` and a
      further block in `scripts/test-state-write-large-payload.sh`. Use `|| exit 1` only at
      top-level script scope; inside any function or backgrounded worker subshell use
      `|| return 1` or the worker's existing failure-flag convention, so a `cd` failure cannot
      terminate the harness early and convert a real concurrency regression into a silent pass.
- [ ] Fix the 6 SC2088 quoted-tilde sites by substituting `$HOME` or unquoting, after confirming
      per site which the surrounding code intends.
- [ ] Fix the 4 SC2010 `ls | grep` sites with a glob or a `for f in dir/*pattern*` loop.
- [ ] Triage the 5 SC2043 single-iteration loops: simplify a genuinely dead loop; inline-disable
      with a reason where a one-element list is intentional (symmetry with a list that is expected
      to grow).
- [ ] Add inline `# shellcheck disable=SC1090` with a reason at the 4 non-constant-source sites,
      matching the ~40 pre-existing SC1090 disables already in the tree.
- [ ] Fix the 3 SC2207 and 2 SC2206 array-assignment sites with `mapfile`/`read -a`, or
      inline-disable with a reason where the word-splitting is intentional (precedent:
      `scripts/deprecated/roadmap-integration.sh:324`).
- [ ] Re-run the Phase 3 class filter to confirm this phase introduced no regression in the
      already-cleared codes.

**Timing**: 2 hours

**Depends on**: 3

**Verification Tier**: interface

**Scope Hypothesis**: 55 findings across 14 files is asserted from the plan-time measurement, with
33 of them concentrated in `test-state-write-concurrency.sh` (20) and
`test-state-write-large-payload.sh` (13). Confirm via the sanctioned entry point: run
`bash agent-system/extensions/core/scripts/lint/lint-shellcheck.sh --verbose` and filter its
`[VIOLATION]` output with `grep -cE 'SC2164|SC2088|SC2010|SC2043|SC1090|SC2207|SC2206'` before
(expect 55) and after (expect 0).

**Tier Justification**: The two heaviest files are themselves flat `scripts/test-*.sh` suites and
the rest are leaf scripts and narrow suites, so the covering check is
`bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-state-write-concurrency.sh,test-state-write-large-payload.sh,<remaining basenames resolved by suite_selection_select>`.

**Files to modify**:
- `agent-system/extensions/core/scripts/test-state-write-concurrency.sh` - 20 findings, mostly SC2164 in worker subshells
- `agent-system/extensions/core/scripts/test-state-write-large-payload.sh` - 13 findings
- `agent-system/extensions/core/scripts/tests/test-resume-scan-nonconformance.sh` - 3 findings
- `agent-system/extensions/core/scripts/tests/test-deploy-baseline-lib.sh` - 3 findings
- `agent-system/extensions/core/scripts/lint/lint-hook-registration-paths.sh` - 3 findings
- `agent-system/extensions/core/scripts/tests/test-lint-hook-registration-paths.sh` - 2 findings
- `agent-system/extensions/core/scripts/tests/test-force-phases.sh` - 2 findings
- `agent-system/extensions/core/scripts/tests/test-askuserquestion-rehome.sh` - 2 findings
- `agent-system/extensions/core/scripts/export-to-markdown.sh` - 2 findings
- `agent-system/extensions/literature/scripts/zotero-attach-chunks.sh` - 1 finding
- `agent-system/extensions/lean/scripts/verify-lean-mcp.sh` - 1 finding
- `agent-system/extensions/core/scripts/validate-wiring.sh` - 1 finding
- `agent-system/extensions/core/scripts/validate-context-index.sh` - 1 finding
- `agent-system/extensions/core/scripts/update-task-status.sh` - 1 finding

**Verification**:
- `bash agent-system/extensions/core/scripts/lint/lint-shellcheck.sh --verbose` re-run: its
  `[VIOLATION]` output reports 0 for these seven codes, and the Phase 3 class filter over the same
  output still reports 0.
- `bash agent-system/extensions/core/scripts/test-state-write-concurrency.sh` exits 0 with the
  same PASS count and the same worker count as before the fix — recorded in the commit message,
  since "shellcheck is now quiet" alone does not prove the harness still exercises every worker.
- `bash agent-system/extensions/core/scripts/test-state-write-large-payload.sh` exits 0.
- The suites resolved by `suite_selection_select` over this phase's touched paths all pass.

---

### Phase 5: SC2034 pass, core extension [NOT STARTED]

**Goal**: Clear the 74 SC2034 "appears unused" findings inside `agent-system/extensions/core/`,
each resolved as either a justified inline disable or a confirmed dead-code deletion.

**Tasks**:
- [ ] Work file-at-a-time rather than code-at-a-time, heaviest first:
      `scripts/lib/phase-heading-patterns.sh` (10), `scripts/tests/test-claude-refresh-matcher.sh`
      (5), `scripts/check-extension-docs.sh` (4), `scripts/skill-base.sh` (3), then the remaining
      core files.
- [ ] For each site, decide between two outcomes and record which in the commit message:
      (a) **inline disable with a one-line reason** when the variable is a closed-over global, an
      exported-for-a-child-process value, or part of a sourced library's public contract
      (precedent: `scripts/skill-base.sh:195`'s `SKILL_HOOK_LAST_*` comment); (b) **deletion**
      when it is genuinely dead.
- [ ] Gate every deletion behind an explicit `grep -rn '<name>' agent-system/extensions .claude`
      check showing no other consumer. `lib/phase-heading-patterns.sh` is the single sourced anchor
      for the phase-heading grammar and its exported names are consumed by sourcers found via
      `grep -rl 'phase-heading-patterns.sh'` — treat every name it exports as public contract and
      disable rather than delete unless that grep proves otherwise.
- [ ] Treat `scripts/skill-base.sh` the same way: it is the lifecycle entry point every skill
      sources, so an "unused" variable there is far more likely a contract than dead code.
- [ ] Re-run the Phase 3 and Phase 4 class filters to confirm no regression.

**Timing**: 2 hours

**Depends on**: 4

**Verification Tier**: full

**Scope Hypothesis**: 74 SC2034 findings inside `agent-system/extensions/core/` is asserted from
the plan-time measurement (108 SC2034 total: core 74, nix 10, literature 10, lean 9, nvim 5).
Confirm via the sanctioned entry point scoped to core —
`bash agent-system/extensions/core/scripts/lint/lint-shellcheck.sh --verbose agent-system/extensions/core`,
filtering its `[VIOLATION]` output with `grep -c SC2034` — before (expect 74) and after (expect
0); the scoped run also exercises the lint's positional scan-path branch. The split between
disables and deletions is deliberately
NOT predicted here — any ratio asserted up front would be a guess, and the per-site `grep -rn`
check is what decides it.

**Tier Justification**: Deleting a variable shellcheck calls unused in
`scripts/lib/phase-heading-patterns.sh` or `scripts/skill-base.sh` silently removes a closed-over
global or exported value consumed by sourcers across every skill and lifecycle stage — a
global-config and shared-library surface that no suite subset enumerates and no cheaper tier
observes, because the breakage appears only when an unrelated consumer sources the library at
runtime.

**Files to modify**:
- `agent-system/extensions/core/scripts/lib/phase-heading-patterns.sh` - 10 SC2034; exported grammar names, prefer disables
- `agent-system/extensions/core/scripts/tests/test-claude-refresh-matcher.sh` - 5 SC2034
- `agent-system/extensions/core/scripts/check-extension-docs.sh` - 4 SC2034
- `agent-system/extensions/core/scripts/skill-base.sh` - 3 SC2034; lifecycle contract, prefer disables
- `agent-system/extensions/core/scripts/tests/test-phase-heading-patterns.sh` - 2 SC2034
- (remaining core files in the SC2034 set, enumerated by the before-measurement at implementation time)

**Verification**:
- `bash agent-system/extensions/core/scripts/lint/lint-shellcheck.sh --verbose agent-system/extensions/core`
  reports 0 SC2034 lines in its `[VIOLATION]` output.
- `bash agent-system/extensions/core/scripts/verify-deploy.sh` passes (the complete gate set it
  aggregates, gates 1 through the current maximum, including Gate 8's full `run-all.sh` battery —
  not `--skip-slow`, not an `--only-gate` subset).
- Every disable added in this phase carries a one-line reason; no file- or repo-level disable and
  no `.shellcheckrc` was introduced (confirm with
  `git diff --stat` and `ls .shellcheckrc agent-system/.shellcheckrc` returning not-found).

---

### Phase 6: SC2034 pass, non-core extensions [NOT STARTED]

**Goal**: Clear the 34 remaining SC2034 findings in the nix (10), literature (10), lean (9), and
nvim (5) extensions, bringing the whole tree to zero findings at `-S warning`.

**Tasks**:
- [ ] nix (10): `scripts/nix-preflight.sh` (5), `scripts/nix-context.sh` (5).
- [ ] nvim (5): `scripts/nvim-context.sh` (5).
- [ ] lean (9): `scripts/lean-challenge-snapshot.sh` (3),
      `scripts/tests/test-lean-src-roots.sh` (2), `scripts/tests/test-lean-comparator-run.sh` (2),
      and the remainder.
- [ ] literature (10): `scripts/test-lit-pipeline.sh` (2) and the remainder.
- [ ] Apply the same disable-vs-delete discipline as Phase 5, with the `grep -rn` consumer check
      scoped to the owning extension plus the deployed `.claude/` tree.
- [ ] Run the whole-tree measurement and confirm it is now zero — this is the acceptance
      criterion's first clause, reached here, one phase before the gate that enforces it.

**Timing**: 1 hour

**Depends on**: 5

**Verification Tier**: interface

**Scope Hypothesis**: 34 SC2034 findings across the four non-core extensions (nix 10, literature
10, lean 9, nvim 5) is asserted from the plan-time measurement. Confirm via the sanctioned entry
point: `bash agent-system/extensions/core/scripts/lint/lint-shellcheck.sh --verbose`, filtering
its `[VIOLATION]` output with `grep SC2034 | grep -vc '/core/'`, before (expect 34) and after
(expect 0).

**Tier Justification**: These are leaf context/preflight/snapshot scripts and narrow per-extension
suites rather than shared libraries, so the covering check is
`bash agent-system/extensions/core/scripts/tests/run-all.sh --only <basenames resolved by suite_selection_select over the touched lean/literature/nix/nvim paths>`;
nothing in this phase touches core's sourced libraries or lifecycle entry points.

**Files to modify**:
- `agent-system/extensions/nix/scripts/nix-preflight.sh` - 5 SC2034
- `agent-system/extensions/nix/scripts/nix-context.sh` - 5 SC2034
- `agent-system/extensions/nvim/scripts/nvim-context.sh` - 5 SC2034
- `agent-system/extensions/lean/scripts/lean-challenge-snapshot.sh` - 3 SC2034
- `agent-system/extensions/lean/scripts/tests/test-lean-src-roots.sh` - 2 SC2034
- `agent-system/extensions/lean/scripts/tests/test-lean-comparator-run.sh` - 2 SC2034
- `agent-system/extensions/literature/scripts/test-lit-pipeline.sh` - 2 SC2034
- (remaining lean/literature files in the SC2034 set, enumerated by the before-measurement at implementation time)

**Verification**:
- `bash agent-system/extensions/core/scripts/lint/lint-shellcheck.sh` exits **0** over the whole
  tracked tree (exit status checked, not stdout compared to a baseline) — the first time in the
  task that the whole-tree run is green.
- The Phase 3, 4, and 5 class filters over that same run's output all still report 0.
- The suites resolved by `suite_selection_select` over this phase's touched paths all pass.

---

### Phase 7: Wire the numbered gate, redeploy, full gate set [NOT STARTED]

**Goal**: Wire the lint into `verify-deploy.sh` as the next free numbered gate, bump every
`--only-gate` range literal, sync the manifest and redeploy so the lint and its test exist in
`.claude/`, and confirm the complete gate set is green with the new gate enforcing zero findings.

**Tasks**:
- [ ] Determine the next free gate number rather than assuming 22: read the current maximum from
      `grep -oE 'gate_selected [0-9]+' agent-system/extensions/core/scripts/verify-deploy.sh | sort -t' ' -k2 -n | tail -1`
      and the live range literals from `grep -n '1-[0-9]\+\|1\.\.[0-9]\+' .../verify-deploy.sh`.
      If ROADMAP task 318 has landed its own gate in the interim, this task's gate is the one
      after it.
- [ ] Insert the new gate block immediately after today's final `gate_selected 21` block and
      before the closing `if [ "$FAILURES" -eq 0 ]` summary, modeled line-for-line on Gate 21:
      `if gate_selected N; then`, a `say "N. ..."` title, `CURRENT_GATE="gateN"`, the
      `[ ! -d "$TARGET/agent-system/extensions" ]` deploy-consumer `[SKIP]` branch, the
      `[ ! -f ... ]` missing-script `fail` branch, the `cd "$TARGET" && REPO_ROOT="$TARGET" bash ... --verbose`
      invocation with its status capture, `pass`/`fail` with a re-run remedy string, the
      `FINDINGS_LIST` scrape over `[VIOLATION]` lines, a trailing `say ""`, and `fi`.
- [ ] Bump every range literal found by the grep above — the two header-comment occurrences, the
      two `--only-gate` error strings, and the stale inline comment currently reading `in 1..20`
      (which was already wrong before this task and is corrected here rather than left to drift
      further).
- [ ] Verify the new gate is reachable in isolation: `verify-deploy.sh --only-gate N` runs it, and
      `--only-gate N+1` is rejected as out of range.
- [ ] Sync the manifest and redeploy so `.claude/scripts/lint/lint-shellcheck.sh` and
      `.claude/scripts/tests/test-lint-shellcheck.sh` exist in the deployed tree, then confirm both
      files are present and the deployed `verify-deploy.sh` carries the new gate.
- [ ] Run the complete gate set and the full suite battery; confirm the new gate reports
      zero findings and nothing else regressed.

**Timing**: 1.5 hours

**Depends on**: 2, 6

**Verification Tier**: full

**Scope Hypothesis**: Two figures are asserted and both must be re-derived at implementation time
rather than trusted from this plan: (a) the next free gate number is **22** as of plan time, which
ROADMAP task 318 may have taken first — confirm with the `gate_selected` grep above before
editing; (b) **five** range-literal sites need bumping (four `1-21`, one stale `1..20`) — confirm
with `grep -c '1-21\|1\.\.20'` and bump every hit found, never a line list from this plan.

**Files to modify**:
- `agent-system/extensions/core/scripts/verify-deploy.sh` - new numbered gate block; bump all five range-literal sites
- `agent-system/extensions/core/manifest.json` - confirm both Phase 1/2 entries are present and sorted

**Verification**:
- `bash .claude/scripts/verify-deploy.sh` reports PASS with 0 failures — the complete gate set it
  aggregates, every gate from 1 through the new maximum, with Gate 8's full `run-all.sh` battery
  run in full (no `--skip-slow`, no `--only-gate` subset), plus the new shellcheck gate.
- `bash agent-system/extensions/core/scripts/verify-deploy.sh --only-gate <N>` runs only the new
  gate and passes; `--only-gate <N+1>` exits 2 with the out-of-range message naming the new upper
  bound.
- `bash agent-system/extensions/core/scripts/tests/run-all.sh` passes with every discovered suite
  green, including `test-lint-shellcheck.sh`.
- `bash .claude/scripts/lint/lint-shellcheck.sh` exits 0 — zero findings over the whole tracked
  tree through the deployed copy of the sanctioned entry point, the acceptance criterion's first
  clause. Exit status is the check; captured output is diagnostic only.
- The seeded-failure clause is proven live: temporarily seed `local x=$(false)` into a scratch
  fixture, confirm the gate fails and names SC2155, then remove the seed and confirm the gate is
  green again. The fixture is never committed.
- `ls .claude/scripts/lint/lint-shellcheck.sh .claude/scripts/tests/test-lint-shellcheck.sh` both
  resolve after redeploy.
- No `.shellcheckrc` exists at any level and no file-level blanket disable was introduced.

---

## Testing & Validation

- [ ] `bash agent-system/extensions/core/scripts/lint/lint-shellcheck.sh` exits 0 — zero findings
      at `-S warning` across all 359 tracked `*.sh` files in all five extensions. The exit status
      is the assertion; the `[VIOLATION]` output is read for diagnosis only, never diffed against
      a stored baseline.
- [ ] A seeded SC2155 in a fixture fails the gate and the failure output names SC2155.
- [ ] An unresolvable `shellcheck` binary produces exit 70 and a named stderr message, asserted by
      the fixture test rather than assumed.
- [ ] An empty scan set produces exit 2, not a silent exit 0.
- [ ] `run-all.sh` discovers and passes `test-lint-shellcheck.sh` with no wiring change beyond the
      manifest entry.
- [ ] `verify-deploy.sh` reports PASS with the new numbered gate included, and the new gate is
      individually selectable via `--only-gate`.
- [ ] `test-state-write-concurrency.sh` and `test-state-write-large-payload.sh` retain their
      pre-fix PASS and worker counts after the SC2164 sweep.
- [ ] The two SC2066 loops demonstrably iterate more than once after the fix.
- [ ] Every deliberate exception is an inline `# shellcheck disable=SCxxxx` with a one-line reason;
      no `.shellcheckrc`, no file-level or repo-level blanket disable.

## Artifacts & Outputs

- `agent-system/extensions/core/scripts/lint/lint-shellcheck.sh` - the lint
- `agent-system/extensions/core/scripts/tests/test-lint-shellcheck.sh` - its both-polarity fixture test
- `agent-system/extensions/core/scripts/verify-deploy.sh` - new numbered gate, bumped range literals
- `agent-system/extensions/core/manifest.json` - two new `provides.scripts` entries
- ~82 scripts across five extensions with their shellcheck findings resolved
- `.claude/scripts/lint/lint-shellcheck.sh` and `.claude/scripts/tests/test-lint-shellcheck.sh` - deployed copies
- `specs/377_add_shellcheck_gate_to_agent_system/summaries/01_shellcheck-gate-summary.md` - on completion

## Rollback/Contingency

Each phase commits independently, so rollback is per-phase rather than whole-task. If a fix pass
turns out to have changed runtime behavior — the concurrency-harness risk is the concrete one —
revert that phase's commit alone; the lint script, the fixture test, and the gate wiring are in
separate commits and survive.

The gate wiring is deliberately the last phase, so the task can stop after any earlier phase
without leaving a red gate behind: before Phase 7 the lint exists and is runnable by hand but is
enforced nowhere. If Phase 7 cannot complete (for instance because ROADMAP task 318 has taken the
gate number and the two edits conflict), the correct partial state is "lint and fixture test
landed and green, tree at zero findings, gate not yet wired" — which is coherent, commits cleanly,
and leaves the wiring as a small follow-up rather than a blocker.

If the whole task must be abandoned, the fix commits are independently valuable (they close real
defects: two single-pass loops, fifteen masked exit codes, thirty-one unguarded `cd` calls) and
should be kept even if the gate never lands.
