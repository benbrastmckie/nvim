# Research Report: Task #240

**Task**: 240 - Restore verify-deploy.sh to green
**Started**: 2026-09-22T05:36:00Z
**Completed**: 2026-09-22T06:00:00Z
**Effort**: Small (one test-fixture wording fix; one config-note correction, no code fix needed)
**Dependencies**: None
**Sources/Inputs**: Codebase (agent-system/extensions/core/**), direct execution of
  `lint-scoped-commit-boundary.sh`, `measure-eager-context.sh`, `test-detect-noop-bash.sh`, git
  history/archive inspection
**Artifacts**: - specs/240_restore_verify_deploy_green/reports/01_restore-verify-deploy-green.md
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- **GATE 17 (scoped-commit boundary lint) is currently failing, exactly as described.** One
  violation: `agent-system/extensions/core/scripts/tests/test-detect-noop-bash.sh:152` contains
  the literal fixture string `'git commit -m "true"'`, which the lint's candidate pattern
  (`git commit -m`, a plain substring match) flags as a hand-rolled bare commit call site, even
  though it is inert test data for `detect-noop-bash.sh`'s classifier, never an executed commit.
- **GATE 20 SUB-CHECK B (eager-load regression) is currently PASSING, not failing.** A fresh
  run of `measure-eager-context.sh --check` (via both the source-store path and the deployed
  `.claude/scripts/` copy — they are byte-identical) reports `TOTAL: 65257 B`, which is **693 B
  under** the recorded `eager_load.baseline_bytes` of 65950 in
  `agent-system/extensions/core/context/config/orchestrator-context-budget.json`. This
  contradicts the dispatch description's premise of `66026 B` (76 B over baseline). See Findings
  for the reconciliation: the `66026`/`measured_at: 2026-09-18` figure recorded in that config
  file's own `eager_load.note` appears to have been an inaccurate measurement at the time it was
  written, not a regression that occurred afterward — a git-archive checkout of the exact commit
  that wrote `66026` (`9c419d6c6`) and a fresh run of the script against it reproduces `65257`,
  not `66026`, with the relevant source files byte-identical to HEAD.
- **Recommended fix scope is narrower than the task description assumes**: only GATE 17 needs an
  actual code change. GATE 20 needs, at most, a documentation correction to the stale
  `measured_bytes`/`note` fields (which are informational only — `verify-deploy.sh` Sub-check B
  reads only `eager_load.baseline_bytes`, never `measured_bytes`) plus a re-verification at
  implementation time (concurrent sibling task 248 has an undeclared file scope and could still
  move the live number before this task's fix lands).
- **Preferred GATE 17 fix**: reword the fixture from `'git commit -m "true"'` to
  `'git commit --message "true"'` (or another rewording that preserves the exact same
  no-op-classifier test intent while no longer containing the literal substring `git commit -m`).
  This is a one-line, semantically-neutral change: `--message` is git's documented long form of
  `-m`, so `detect-noop-bash.sh`'s classifier still sees a single non-trivial segment (it is not
  in the hook's trivial-command case list either way), and the fixture continues to test exactly
  what its label says: "trivial word inside unrelated quoted string". All 40 assertions in
  `test-detect-noop-bash.sh` currently pass and remain unaffected by this wording change.

## Context & Scope

Task 240 exists to close out the last two reported failures in `verify-deploy.sh` before four
dependent tasks (224, 227, 139, 140) land edits to eager-loaded files (`merge-sources/claudemd.md`,
`rules/pr-prohibition.md`, `rules/source-store-deploy-boundary.md`, `rules/git-workflow.md`).
Scope is restricted to `agent-system/extensions/core/**` (never `.claude/`, which is a disposable
deploy artifact — see `agent-system/extensions/core/rules/source-store-deploy-boundary.md`).

Both checks were reproduced directly (not just read about) by running the actual gate scripts
against the current working tree:

```
bash agent-system/extensions/core/scripts/lint/lint-scoped-commit-boundary.sh --verbose
REPO_ROOT=$(pwd) bash agent-system/extensions/core/scripts/measure-eager-context.sh --check
bash agent-system/extensions/core/scripts/tests/test-detect-noop-bash.sh
```

A full `bash .claude/scripts/verify-deploy.sh` run was started to get an end-to-end gate count,
but it is long-running (all ~20+ gates, including test suites); it was interrupted after several
minutes with no output yet (the `| tail -80` pipe does not flush until the whole script exits).
Given the two specific gates were independently reproduced and matched/contradicted the dispatch
description exactly as detailed above, the full run was not needed to reach research conclusions,
but the implementer should still run a full `deploy-headless.sh` (per the dispatch's own VERIFY
instruction) after applying the GATE 17 fix, both to confirm gate 17 is now clean and to catch any
other check whose status may have shifted since this report was written (i.e. do not skip the
end-to-end verification just because this report found only one gate needing a code change).

## Findings

### GATE 17 — Scoped-Commit Boundary Lint

- Script: `agent-system/extensions/core/scripts/lint/lint-scoped-commit-boundary.sh`
- Current run: `Files checked: 1119`, `Candidate lines exempted: 47`, `Total violations: 1`.
- The single violation:
  ```
  [VIOLATION] .../agent-system/extensions/core/scripts/tests/test-detect-noop-bash.sh:152: 'git commit -m "true"'
  ```
- Mechanism: the lint's `CANDIDATE_PATTERN='git commit -m'` is a plain `grep -F` substring match
  (deliberately broad, per the script's own header comment), narrowed by two layers: Layer 1
  (structural) exempts a line that ends in a trailing `-- <pathspec>`; Layer 2 (file-level
  allowlist) exempts specific named files with an inline reason each. Line 152 of
  `test-detect-noop-bash.sh` matches neither exemption: it does not end in a pathspec, and the
  file is not on the `EXCLUDED_FILES` allowlist.
- Context of the fixture: `test-detect-noop-bash.sh` (added by task 239, commits `778109ec0` /
  `954077fd9` — before the scoped-commit lint's own allowlist was last reviewed) is a
  fixture-driven regression suite for `detect-noop-bash.sh`, the PostToolUse hook that flags
  runs of trivial (`:`, `true`, bare `date`, literal `echo`, `sleep N`) Bash calls. Line 152's
  assertion:
  ```lua
  assert_nontrivial "classify: trivial word inside unrelated quoted string" \
    'git commit -m "true"'
  ```
  exercises `is_trivial_command()` / `is_trivial_segment()` in
  `agent-system/extensions/core/hooks/detect-noop-bash.sh`: the whole raw command is checked
  against the small case list (`:`, `true`, `date`, `date -u`, `echo`, `echo -n`, a `sleep N`
  pattern) — `git commit -m "true"` matches none of them and is correctly classified
  non-trivial. The fixture's job is to prove that the presence of the trivial *word* `true`
  inside an unrelated quoted string does not fool the classifier into treating the whole command
  as trivial. No actual git commit is ever executed by the test.
- **This is a genuine lint false positive, not a real anti-pattern.** The fixture never invokes
  `git-commit-scoped.sh`'s bypass; it is inert string data passed to a subprocess via a synthetic
  JSON payload (`run_hook`), exactly the same shape as two already-allowlisted files
  (`test-guard-destructive-git.sh`, `test-lint-scoped-commit-boundary.sh`) that intentionally
  contain the `git commit -m` anti-pattern text as fixture data for a *different* classifier.
- **Two fix options, per the dispatch and the lint's own documented conventions**:
  1. **Reword the fixture (preferred)** — change the command string so it no longer contains the
     literal substring `git commit -m`, while still testing the identical classification
     scenario. Confirmed candidate: `'git commit --message "true"'`. `--message` is git's
     documented long-form equivalent of `-m` for `git commit`, so the line remains a
     recognizable, realistic non-trivial command; `is_trivial_segment()`'s case-list match is
     exact-string (`":"|"true"|"date"|"date -u"|"echo"|"echo -n"`), so this segment was never
     matched by content resembling `-m` vs `--message` in the first place — the wording change
     has zero effect on what the test actually exercises. Verified the literal substring
     `git commit -m` does not appear inside `git commit --message "true"` (the extra dash before
     `message` breaks the match at the position after `git commit -`).
  2. **Allowlist entry (fallback)** — add
     `agent-system/extensions/core/scripts/tests/test-detect-noop-bash.sh` to
     `EXCLUDED_FILES` in `lint-scoped-commit-boundary.sh`, with an inline reason mirroring the
     two existing test-fixture allowlist entries (`test-guard-destructive-git.sh`,
     `test-lint-scoped-commit-boundary.sh`). This is a valid fallback but less precise: it would
     exempt the *entire file* rather than the one fixture line, silently permitting any future
     line in that file to also escape the lint even if it becomes a real violation. The dispatch
     explicitly calls option 1 preferred; this research agrees — the rewording is a strictly
     smaller, more targeted change with no allowlist-maintenance cost.
- Confirmed via `bash agent-system/extensions/core/scripts/tests/test-detect-noop-bash.sh`:
  **40 assertions currently pass, 0 fail.** The rewording does not touch any assertion's
  semantics (label text, `assert_nontrivial` expectations), so the same 40/0 result is expected
  after the fix; this should be re-run as part of implementation to confirm.
- No other occurrence of the literal string `git commit -m "true"` exists anywhere under
  `agent-system/` (`grep -rn` confirms exactly one hit), so this is an isolated, one-line fix.

### GATE 20 SUB-CHECK B — Eager-Load Regression

- Script: `agent-system/extensions/core/scripts/measure-eager-context.sh --check`, gated in
  `verify-deploy.sh`'s Gate 20 (`say "20. Orchestrator context budget lock..."`, around line 908
  onward). Gate 20 has three independent sub-checks: A (volatile-file hits, unconditional
  `fail()`), B (eager-load total vs. `eager_load.baseline_bytes`, unconditional `fail()`), and C
  (two per-file ceilings — `commands/orchestrate.md`,
  `skills/skill-orchestrate/SKILL.md` — `warn()`-tier by default via
  `ORCHESTRATOR_BUDGET_GATE_MODE="${ORCHESTRATOR_BUDGET_GATE_MODE:-warn}"`, only escalating to
  `fail()` under an explicit `hard` override that is not the default).
- **Current measured total: `65257 B`** (via `REPO_ROOT=$(pwd) bash
  agent-system/extensions/core/scripts/measure-eager-context.sh --check`, cross-checked
  identically through the deployed `.claude/scripts/measure-eager-context.sh`, which is
  byte-identical to the source-store copy). Breakdown: `parent_chain 3046 B`, predicted
  assembled `.claude/CLAUDE.md 33690 B`, `at_import 0 B`, `rules 28521 B` (8 currently-eager
  rule files matched against the representative touched-path set).
- **Recorded baseline**: `eager_load.baseline_bytes: 65950` in
  `agent-system/extensions/core/context/config/orchestrator-context-budget.json`. Since
  `65257 <= 65950`, Sub-check B's `elif [ "$eager_total" -gt "$baseline_bytes" ]` branch is not
  taken; the `pass()` branch runs. **Sub-check B currently passes**, with 693 B of headroom.
- **Reconciling against the dispatch's stated `66026 B` / `76 B over` premise**: the same
  config file's `eager_load.measured_bytes` field (last written by commit `9c419d6c6`, "task 235
  phase 4: refresh budget config and gate-mode comment", 2026-09-18) records `66026`, with an
  accompanying `note` attributing the growth to a same-day sibling task's landed commits touching
  `merge-sources/claudemd.md` and `commands/orchestrate.md`. This research traced that specific
  claim and could not reproduce it:
  - `git log --oneline 9c419d6c6..HEAD` for every file that feeds the four eager-load channels
    (`merge-sources/claudemd.md` and every other active extension's `merge_targets.claudemd.source`
    file — `EXTENSION.md` for `memory`/`email`/`nix`/`nvim`, `merge-sources/claudemd.md` for
    `core`/`literature` — plus every active extension's `rules/*.md`, the header template, and
    `.claude-extensions.json`'s active-extension set) shows **no content change** to any of them
    since `9c419d6c6`. `core/merge-sources/claudemd.md` itself is byte-identical (`19435 B`) both
    then and now.
  - A `git archive` checkout of commit `9c419d6c6` into a scratch directory, with
    `measure-eager-context.sh --check` re-run against that checkout with `REPO_ROOT` pointed at
    it, reproduces **`65257 B`, not `66026 B`** — i.e. even at the exact commit whose own config
    file recorded `66026`, a fresh, faithful re-run of the measurement script it names produces a
    different (lower, passing) number.
  - Conclusion: the `66026` figure in the config's `note` was very likely a stale or
    differently-obtained measurement at the time it was written (e.g. captured before some
    same-cycle edit fully settled, or computed via a slightly different invocation), not a
    regression that has since been fixed by any later commit. This is a **documentation accuracy
    issue in the config file's informational fields**, not a live gate failure requiring a
    content trim.
  - This field is read by nothing: `verify-deploy.sh` Sub-check B parses only
    `eager_load.baseline_bytes` from the config (`jq -r '.eager_load.baseline_bytes'`); the
    `measured_bytes`/`measured_at`/`note` fields are documented in the file's own top-level
    `_comment` as "informational snapshots" that "may be refreshed freely" — refreshing them is
    optional hygiene, not required for the gate to pass.
- **Per-file ceiling sub-check (C) is also currently clean**: `skill-orchestrate/SKILL.md` is
  `19535 B` (ceiling `20000 B`), `commands/orchestrate.md` is `20228 B` (ceiling `21000 B`) —
  both re-measured directly via `wc -c` and matching the config's own recorded values exactly,
  both under ceiling (this sub-check is warn-tier regardless, so it would not fail the gate even
  if over).
- **Risk factor for plan/implementation phases**: the dispatch's own territory block lists task
  248 as a concurrent sibling THIS SAME orchestrate cycle with **no declared `file_scope`** ("it
  may touch any file in the repository"). If task 248 (or any other concurrently-dispatched task)
  lands an edit to an eager-loaded file before this task's implementation phase re-measures, the
  live total could shift by the time of the final `deploy-headless.sh` verification. The
  implementation phase should re-run `measure-eager-context.sh --check` immediately before
  finalizing, not rely on this report's snapshot.

## Recommendations

1. **GATE 17 fix** (mandatory, in scope): edit
   `agent-system/extensions/core/scripts/tests/test-detect-noop-bash.sh` line 152, changing the
   fixture command from `'git commit -m "true"'` to `'git commit --message "true"'` (exact
   string change only — the surrounding `assert_nontrivial "classify: trivial word inside
   unrelated quoted string" \` label line is unaffected and needs no wording change since it
   never named `git commit -m` specifically). Re-run
   `bash agent-system/extensions/core/scripts/tests/test-detect-noop-bash.sh` and confirm
   `40 passed, 0 failed` (unchanged from today's baseline run). Re-run
   `bash agent-system/extensions/core/scripts/lint/lint-scoped-commit-boundary.sh --verbose` and
   confirm `Total violations: 0`.
2. **GATE 20 handling** (documentation-only, optional but recommended): update the stale
   `eager_load.measured_bytes` (66026 -> current re-measured value), `measured_at`, and `note`
   fields in `agent-system/extensions/core/context/config/orchestrator-context-budget.json` to
   record the corrected, reproducible figure and this research's finding that the prior 66026
   figure did not reproduce against its own named commit. **Do not change `baseline_bytes`**
   (65950) — there is no regression to justify moving it, and the file's own policy is that the
   baseline is a fixed ceiling moved only by a deliberate, reviewed decision, never routinely.
   This step is optional relative to gate-greenness (the gate does not read `measured_bytes`) but
   valuable so a future reader of the config's `note` is not misled by an unreproducible number.
3. **Do not perform a speculative eager-set trim.** Given 693 B of headroom already exists and no
   content regression was found, trimming rules/merge-source prose now would be solving a problem
   that does not currently exist and risks removing operational content for no gate benefit. The
   four dependent tasks (224, 227, 139, 140) that motivated this task's "restore headroom first"
   ordering will each consume some of the existing 693 B headroom themselves; if their combined
   growth pushes the total over 65950 B, that is the standing policy already documented in the
   config file's `_comment` ("a sibling's own regression is that sibling's to own, not to
   silently absorb") — each of those tasks (or a future task) should trim or re-baseline at that
   point, not this one pre-emptively.
4. **Final verification** (per dispatch VERIFY step, for the implementation phase): after
   applying the GATE 17 fix (and optionally the GATE 20 documentation correction), run
   `bash .claude/scripts/deploy-headless.sh` and confirm `RESULT` is `landed` (exit 0) with
   `0 failed checks` in `verify-deploy.sh`'s summary. This full run should be done fresh at
   implementation time (it was not completed during this research pass — see Context & Scope) to
   pick up any other gate whose status may shift due to concurrent sibling task activity in this
   same orchestrate cycle.

## Decisions

- Confirmed the GATE 17 violation is a lint false positive against inert test-fixture data, not a
  real hand-rolled commit call site; the preferred fix (reword, not allowlist) matches the
  dispatch's own stated preference and the lint's existing precedent of narrow, reasoned
  allowlist entries only where a rewording isn't possible (this case, rewording is possible).
- Determined GATE 20 SUB-CHECK B is not currently reproducing a failure: live measurement
  (65257 B) is under the recorded baseline (65950 B) by 693 B, verified through two independent
  invocation paths (source-store script, deployed script copy) and cross-checked against a
  git-archive reconstruction of the exact commit that recorded the contradicting `66026 B`
  figure. Recommending against a speculative trim given no reproducible regression exists.

## Risks & Mitigations

- **Risk**: a concurrent sibling task (esp. task 248, undeclared file scope) lands an eager-set
  edit between this research pass and the implementation phase, pushing the live total back over
  baseline. **Mitigation**: implementation phase must re-run
  `measure-eager-context.sh --check` immediately before finalizing rather than trusting this
  report's snapshot number; if it is over baseline at that point, apply the dispatch's original
  trim-then-fallback-rebaseline guidance at that time, scoped to whatever actually caused the
  regression.
- **Risk**: rewording the GATE 17 fixture in a way that inadvertently changes what
  `detect-noop-bash.sh` classifies (e.g. picking a replacement string that happens to match one
  of the hook's trivial-segment patterns). **Mitigation**: the recommended replacement
  (`'git commit --message "true"'`) was checked against `is_trivial_segment()`'s exact-match case
  list and regex patterns — it matches none of them, same as the original — and the full 40-case
  test suite must be re-run after the edit as a hard verification gate, not just visually
  inspected.

## Context Extension Recommendations

- None. This is a narrow, self-contained bugfix; no gap in `.claude/context/` documentation was
  identified. (Meta task type — this section is intentionally minimal.)

## Appendix

### Commands run (read-only, no files modified during research)

```
REPO_ROOT=$(pwd) bash agent-system/extensions/core/scripts/measure-eager-context.sh --check
bash .claude/scripts/measure-eager-context.sh --check
bash agent-system/extensions/core/scripts/lint/lint-scoped-commit-boundary.sh --verbose
bash agent-system/extensions/core/scripts/tests/test-detect-noop-bash.sh
git log --oneline -N -- <eager-load-channel files>
git merge-base --is-ancestor ea849d410 9c419d6c6
git archive 9c419d6c6 agent-system .claude-extensions.json CLAUDE.md | tar -x -C /tmp/eager-check-9c4
wc -c agent-system/extensions/core/skills/skill-orchestrate/SKILL.md agent-system/extensions/core/commands/orchestrate.md
grep -rn 'git commit -m "true"' agent-system/
```

### Key files referenced

- `agent-system/extensions/core/scripts/lint/lint-scoped-commit-boundary.sh`
- `agent-system/extensions/core/scripts/tests/test-detect-noop-bash.sh` (line 152)
- `agent-system/extensions/core/hooks/detect-noop-bash.sh`
- `agent-system/extensions/core/scripts/measure-eager-context.sh`
- `agent-system/extensions/core/context/config/orchestrator-context-budget.json`
- `agent-system/extensions/core/scripts/verify-deploy.sh` (Gate 17 ~line 799, Gate 20 ~line
  882-990)
