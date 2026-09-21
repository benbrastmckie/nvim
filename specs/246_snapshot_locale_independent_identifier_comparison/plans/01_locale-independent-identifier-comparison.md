# Implementation Plan: Task #246

- **Task**: 246 - Make lean-challenge-snapshot.sh identifier comparison locale-independent (false mismatch under en_US.UTF-8)
- **Status**: [IMPLEMENTING]
- **Effort**: 2 hours
- **Dependencies**: None
- **Research Inputs**: specs/246_snapshot_locale_independent_identifier_comparison/reports/01_locale-independent-identifier-comparison.md
- **Artifacts**: plans/01_locale-independent-identifier-comparison.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

`lean-challenge-snapshot.sh` builds its **Goals** identifier list with an ambient-locale
`sort -u` but builds the declared-identifier list with Python `sorted()` (code-point order), then
compares the two with `comm`, which needs both inputs in the same collation. Mixed-case identifiers
(`hnStabMirror` next to `hn_stab`) sort differently in the two orders, so the check reports false
mismatches (exit 71). The fix pins `LC_ALL=C` inline on that one `sort -u` and on both `comm`
calls, with comments explaining why. A red/green suite case with a mixed-case fixture proves the
fix works. The lean extension is then redeployed into the consuming repo so a running agent
picks up the fix.

### Research Integration

The research report reproduced the defect live and confirmed every line number (347, 434,
447-448, 602, 145). Its audit found exactly five sort/compare sites, and only 347/447/448 need a
change: 434 and 602 already use code-point `sorted()`, and 145 (`sort -V`, which picks the plan
file) is never compared against another list. Pinning only the producer is enough for today's
data flow. Pinning `comm` as well is defense-in-depth and is where the required comment lives.
The report also found that the R2 route reads its names from the goals file, so fixing line 347
covers R1 and R2 together.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No roadmap consultation requested for this dispatch.

## Goals & Non-Goals

**Goals**:
- The goals-side sort and both `comm` calls use byte-order collation, scoped inline, each with a
  short comment giving the reason.
- `--dry-run` output is byte-identical under `LC_ALL=en_US.UTF-8` and `LC_ALL=C` for a mixed-case
  identifier set.
- A new suite case is RED against the unfixed script and GREEN against the fixed one (checked by
  hand).
- Every cross-tool sort/compare site is either pinned or documented as not needing a pin.
- The regenerated `.claude/**` copy in a consuming repo that loads the lean extension carries the
  fix.

**Non-Goals**:
- Changing what counts as an identifier (the backtick regex) or loosening the mismatch check.
- Exporting `LC_ALL` for the whole process.
- Touching `lake-build-guard.sh` or any file outside the script, its suite and its fixtures
  directory.
- Adding a separate false-negative regression fixture (optional, not required by acceptance).
- Adding a new context/patterns doc for this hazard class (a follow-up, outside file scope).

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| `en_US.UTF-8` missing in some environment, so the new case never triggers the bug and passes vacuously | M | L | Probe `locale -a` for a UTF-8 dictionary locale (prefer `en_US.UTF-8`, accept `en_US.utf8` spelling); call `skip()` with a clear message if none is found, never a silent pass |
| New case asserts only exit 0 and passes for an unrelated reason | M | L | Also assert that the ERROR/mismatch text is absent, that `comm:` sortedness warnings are absent, and that all three names appear in `theorem_names` |
| A future edit unpins one site | M | L | Pin both producer and `comm` sites, each with a WHY comment |
| Deploying into the external consuming repo (`~/Projects/BimodalLogic`) is a write outside this repo | M | L | Use the non-destructive default resync mode of `deploy-headless.sh` (never `--wipe`); run `--dry-run` first; change nothing else there. This repo does not load the lean extension (`.claude-extensions.json` has no `lean`), so this repo's own `.claude/` cannot carry the fix |
| The Lean suite leaves shell state behind (such as the locale) that affects later cases | L | L | Scope the locale to the one `run_tool` call (an env prefix or a subshell), not an exported variable |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |
| 3 | 3 | 2 |

Phases within the same wave can execute in parallel.

### Phase 1: Add RED mixed-case suite case and fixture [COMPLETED]

**Goal**: Add the regression case first, and show it goes RED against the current, unfixed
script.

**Tasks**:
- [x] Create `agent-system/extensions/lean/scripts/tests/fixtures/challenge/plan_mixed_case.md`,
  modeled on `plan_r1.md`/`plan_mismatched.md`. Its `**Goals**:` line and its
  `## Lean Challenge Statements` block both name the SAME set: `hnOpenMirror`, `hnStabMirror`,
  `hn_stab`. Use `{N}` where existing fixtures do. *(completed)*
- [x] Add case `R5` to `test-lean-challenge-snapshot.sh` after `R4` and before the `M1` block,
  following the file's per-case comment-block and `pass`/`fail` conventions:
  - Find a UTF-8 dictionary-collation locale via `locale -a` (prefer `en_US.UTF-8` or
    `en_US.utf8`). If none exists, `skip` with a message.
  - Run `LC_ALL=<that locale> run_tool "$repo" --dry-run` with the locale scoped to that call
    only.
  - Assert rc 0. Assert the output has no `identifier-set mismatch` and no `comm:` warning. Assert
    `theorem_names` lists all three identifiers.
  - Run the same call again under `LC_ALL=C` and assert the two outputs are byte-identical
    (the acceptance criterion).
  - In the comment block, state the mutation this case kills: removing the `LC_ALL=C` pin from
    the goals-side `sort -u` (with or without the `comm` pins) turns it RED with exit 71 and
    `hn_stab` on both sides. *(completed)*
- [x] Run the suite against the UNFIXED script and confirm R5 fails and every other case still
  passes. Record the observed output for the summary. *(completed: R5 FAIL rc=71,
  "named in **Goals**: but not declared: hn_stab" / "declared but not named in **Goals**:
  hn_stab" on both sides — same-names-both-sides symptom reproduced exactly; 13 passed, 1
  failed, 0 skipped)*

**Timing**: 45 minutes

**Depends on**: none

**Verification Tier**: local

**Files to modify**:
- `agent-system/extensions/lean/scripts/tests/fixtures/challenge/plan_mixed_case.md` - new fixture
- `agent-system/extensions/lean/scripts/tests/test-lean-challenge-snapshot.sh` - new case R5

**Verification**:
- `bash agent-system/extensions/lean/scripts/tests/test-lean-challenge-snapshot.sh` shows R5 FAIL
  (exit 71 path) and all other cases unchanged.

---

### Phase 2: Pin collation at the producer and comparison sites [COMPLETED]

**Goal**: Fix the ordering mismatch with the narrowest possible scope, and document every sort
site.

**Tasks**:
- [x] Re-derive the line numbers with
  `grep -n "sort\b\|comm \|uniq\|join " agent-system/extensions/lean/scripts/lean-challenge-snapshot.sh`.
  *(completed: confirmed 145 sort -V, 347 sort -u, 447-448 comm -23/-13 -- matched research)*
- [x] In `extract_goal_names()`, change the trailing `sort -u` to `LC_ALL=C sort -u`. Add a
  one-line comment saying it matches the code-point order of Python `sorted()` in the R1/R2
  extractors, which `comm` needs. *(completed)*
- [x] In `cross_validate_identifiers()`, prefix both `comm -23`/`comm -13` calls with `LC_ALL=C`.
  Add a short comment at that site: `comm` checks sortedness and merges under its own locale, so
  both inputs must share one collation, and unpinning either site brings back false (or silently
  missed) mismatches. *(completed)*
- [x] Do not add `export LC_ALL` anywhere. Do not change the regex, the mismatch logic, or the
  messages. *(completed: verified via grep, no export added)*
- [x] Audit the other sites and leave them unchanged: the Python `sorted(set(declared_names))`
  (R1) and `sorted(names)` (R2) are already code-point order, and the `sort -V` used for plan-file
  selection is never compared across tools. Optionally add a one-line comment at the Python sites
  noting that they match the pinned shell side. *(completed: comments added at both Python sites;
  sort -V at line 145 left unchanged and uncommented since it is never compared cross-tool)*
- [x] Re-run the suite and confirm R5 is GREEN and every case passes. *(completed: 14 passed,
  0 failed, 0 skipped)*
- [x] Mutation check by hand: temporarily remove only the `sort -u` pin, confirm R5 goes RED,
  then restore it. Record the result. *(completed: removing the pin turned R5 RED with rc=71
  "comm: file 1 is not in sorted order"; 13 passed, 1 failed; restored, suite back to 14/0)*
- [x] Byte-identity check: run the new fixture under `LC_ALL=en_US.UTF-8` and under `LC_ALL=C`
  with `--dry-run` and `diff` the outputs (they must be empty). *(completed: diff empty, outputs
  byte-identical)*

**Timing**: 45 minutes

**Depends on**: 1

**Verification Tier**: local

**Files to modify**:
- `agent-system/extensions/lean/scripts/lean-challenge-snapshot.sh` - inline `LC_ALL=C` pins
  plus comments

**Verification**:
- The full suite passes. The mutation turns R5 RED. The cross-locale `diff` is empty.
- `grep -n "export LC_ALL\|export LC_COLLATE"` on the script returns nothing.

---

### Phase 3: Redeploy to the consuming repo and verify [NOT STARTED]

**Goal**: Get the source-store fix into a running agent's `.claude/**` copy.

**Tasks**:
- [ ] Confirm which repos load the lean extension. This repo does not (its
  `.claude-extensions.json` lists core, email, literature, memory, nix and nvim).
  `~/Projects/BimodalLogic` does.
- [ ] Run `agent-system/extensions/core/scripts/deploy-headless.sh --dry-run ~/Projects/BimodalLogic`,
  then run the default non-destructive resync, `deploy-headless.sh ~/Projects/BimodalLogic`. Never
  use `--wipe`.
- [ ] Verify with
  `diff agent-system/extensions/lean/scripts/lean-challenge-snapshot.sh ~/Projects/BimodalLogic/.claude/scripts/lean-challenge-snapshot.sh`
  (it must be empty, or show only deploy-time substitutions), and grep the deployed copy for the
  `LC_ALL=C sort -u` and `LC_ALL=C comm` pins.
- [ ] Optionally run the deployed suite from the consuming repo if it is deployed there.
- [ ] Record in the summary the audit disposition of all five sites (pinned or not needed, with
  the reason).

**Timing**: 30 minutes

**Depends on**: 2

**Verification Tier**: full

**Scope Hypothesis**: `~/Projects/BimodalLogic` is the only consuming repo that needs the
redeploy. Confirm by checking which known repos list `lean` in `.claude-extensions.json`. If the
deploy fails for environmental reasons, report partial with the exact error instead of editing
`.claude/**` by hand.

**Files to modify**:
- None in this repo. The deploy regenerates `~/Projects/BimodalLogic/.claude/scripts/lean-challenge-snapshot.sh`
  (and its tests, if deployed)

**Verification**:
- The deployed copy matches the source store and contains both pins.

## Testing & Validation

- [ ] R5 is RED against the unfixed script and GREEN against the fixed script
- [ ] Removing the `sort -u` pin by hand turns R5 RED
- [ ] `--dry-run` output is byte-identical under `LC_ALL=en_US.UTF-8` and `LC_ALL=C` for the
  mixed-case fixture
- [ ] The full `test-lean-challenge-snapshot.sh` suite passes, including the AV1 guard
- [ ] No process-wide `export LC_ALL`/`LC_COLLATE` in the script
- [ ] No task-number references in the modified deliverable files
- [ ] The consuming repo's deployed copy carries the fix

## Artifacts & Outputs

- Modified `agent-system/extensions/lean/scripts/lean-challenge-snapshot.sh`
- Modified `agent-system/extensions/lean/scripts/tests/test-lean-challenge-snapshot.sh`
- New `agent-system/extensions/lean/scripts/tests/fixtures/challenge/plan_mixed_case.md`
- Regenerated `.claude/**` in `~/Projects/BimodalLogic`
- Implementation summary in `specs/246_snapshot_locale_independent_identifier_comparison/summaries/`

## Rollback/Contingency

Revert the source-store commits with `git revert` and re-run the default `deploy-headless.sh`
resync into the consuming repo to restore the prior deployed copy. The change is three inline
env prefixes plus a test case, so a revert is trivial and has no data implications.
