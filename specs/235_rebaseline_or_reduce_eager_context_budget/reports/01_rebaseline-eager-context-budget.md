# Research Report: Task #235

**Task**: 235 - Re-baseline or reduce the eager-context budget
**Started**: 2026-09-18T22:58:11Z
**Completed**: 2026-09-18T23:10:00Z
**Effort**: medium
**Dependencies**: None
**Sources/Inputs**: Codebase (git log/show, direct measurement scripts), local script execution
**Artifacts**: - specs/235_rebaseline_or_reduce_eager_context_budget/reports/01_rebaseline-eager-context-budget.md
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- **The task's original premise (sub-check B red) is already resolved.** A different, earlier
  task (`task 213`, its own phase 6/7 commits `f9355fff8` and `5937a0d8b`, landed
  2026-09-17 22:46 / 23:15 -0700) deliberately bumped `eager_load.baseline_bytes` from 64450 to
  65950 and recorded a dated justification in the config's own `note` field. A direct re-run of
  `measure-eager-context.sh --check` right now measures `TOTAL: 65889 B` against that baseline,
  i.e. sub-check B currently **passes** (65889 <= 65950) and sub-check A also passes ("CHECK
  PASSED: no volatile-file hits"). This task's own description quotes numbers (baseline 64450,
  measured 65198) that predate that fix and are now stale.
- **Growth attribution for the +804 B originally reported is already done and already recorded**:
  only `task 213`'s commits touched `merge-sources/**`, `rules/**`, or the budget config itself
  in the window since 2026-09-09 (`git log --since=2026-09-09` on those three path globs returns
  exactly those two commits). The config's `eager_load.note` already names the cause (the
  `/orchestrate` command-table row documenting the per-run cycle-budget contract, artifact-keyed
  forced admission, and `$2+` focus-string threading) — no further attribution work is needed.
- **A genuinely NEW regression has appeared since task 213's fix, discovered during this
  research**: `skills/skill-orchestrate/SKILL.md` now measures 21,318 B against its own
  `ceiling_bytes: 20000` — newly OVER ceiling. This is not the file task 235's WORK item (3)
  names (it names only `commands/orchestrate.md`), and it postdates task 213: commit `9465df20d`
  ("task 212 phase 4: wire message recovery into Move 3 and amend Postflight Boundary", landed
  2026-09-18 14:35 -0700 — chronologically AFTER task 213's fix) added 32 lines / ~2,325 B of
  legitimate new D4 message-findings-recovery documentation to `SKILL.md`. The config's own
  per-file `derivation` note for this file is now stale: it still says "16,025 B measured ...
  currently under ceiling," which is no longer true.
- **`commands/orchestrate.md` remains over its ceiling, and by more than previously recorded.**
  Live: 19,967 B vs. `ceiling_bytes: 8000` (config's stale `measured_bytes` says 15,812 B from
  2026-09-07). This over-ceiling condition is not new — it was deliberately shipped warn-tier
  from day one per the config's own top-level `_comment` — but the gap has grown ~4,155 B since
  last recorded.
- **Work item (4) — deploy-headless.sh's exit-3 semantics — is already fully implemented and
  already correctly consumed.** `deploy-headless.sh` documents and emits a three-way
  `RESULT=not_landed|landed_verify_clean|landed_verify_red` / exit `1,2|0|3` contract (see
  `deploy-headless.sh:96-169`). `command-gate-out.sh`'s postflight completion-deploy gate
  (`gate_out_rc=6` branch, lines ~175-216) explicitly excludes exit 3 from the "redeploy failed"
  branch and instead runs a baseline-relative pre-existing-vs-new-findings comparison, exactly
  the mechanism needed so a landed-but-budget-red deploy is never misread as a failed/stale one.
  No code change is required for item (4) — only confirming this and recording it, which this
  report does.
- **Recommended approach**: this task's remaining real work has narrowed to (a) deciding whether
  to trim `SKILL.md`'s new growth or record a reviewed ceiling-bump justification for it
  alongside `commands/orchestrate.md`'s existing gap, and (b) re-running
  `test-verify-deploy-context-budget.sh` to confirm its baseline-fixture assumption ("at most one
  pre-existing gate20 WARN") still holds now that a second file (`SKILL.md`) is over ceiling —
  it likely no longer holds and the test's baseline comment/assertion may need updating to
  acknowledge two pre-existing WARNs instead of one.

## Context & Scope

Verified: current live state of `agent-system/extensions/core/context/config/orchestrator-context-budget.json`, live byte counts of the two tracked per-file targets, the eager-load total via `measure-eager-context.sh --check`, `verify-deploy.sh` Gate 20's exact comparison logic (read directly, lines 880-989), `deploy-headless.sh`'s exit-code contract, and `command-gate-out.sh`'s consumption of that contract. Git history since 2026-09-08/09 was inspected via `git log`/`git show` on the specific paths named in the task description plus the two ceiling-tracked files.

A full `verify-deploy.sh` (all 34 checks across 20 gates) run was started early in this session and initially did not complete within the session's active time budget (compounded by concurrent sibling tasks in this same `/orchestrate` cycle running their own verify/redeploy activity on the same tree — observed via `ps aux`, additional `verify-deploy.sh` and fixture-based `verify-deploy.sh --skip-slow` processes not started by this dispatch). It finished in the background after the Gate 20 sub-check A/B/C outcomes below had already been derived by directly re-implementing the gate's own comparison logic (same commands: `measure-eager-context.sh --check`, `wc -c` against `.files[path].ceiling_bytes`); the completed run's actual Gate 20 output **exactly matches** that direct derivation:

```
20. Orchestrator context budget lock (measure-eager-context.sh --check + per-file ceilings)
  [PASS] measure-eager-context.sh --check: no volatile-file hits
  [PASS] eager-load total (65889 B) within baseline (65950 B)
  [WARN] commands/orchestrate.md (19967 B) exceeds its configured ceiling (8000 B)
  [WARN] skills/skill-orchestrate/SKILL.md (21318 B) exceeds its configured ceiling (20000 B)

[verify-deploy] FAIL -- 1 of 34 check(s) failed
```

Note the overall run reports 1 failure among 34 total checks, but Gate 20 itself contributed 0 failures (2 PASS, 2 WARN — WARN never increments `FAILURES`, see Findings below). The one failing check therefore belongs to a different, unrelated gate (1-19) and is out of scope for this task; it was not investigated further here since it does not affect Gate 20's own state.

`test-verify-deploy-context-budget.sh` was also started but was killed by its own 300s external `timeout` wrapper before completing, again due to the same concurrent-sibling contention (its fixture-based `verify-deploy.sh --skip-slow --findings --quiet` sub-invocations were each independently slow). Its actual pass/fail result on the "at most 1 pre-existing gate20 WARN" baseline assertion (see Findings below) was **not** captured in this session and remains an open confirmation item for the next phase.

## Findings

### Codebase Patterns

- **Gate 20 structure** (`agent-system/extensions/core/scripts/verify-deploy.sh:880-989`): three
  independent sub-checks — A (volatile-file hits, unconditional `fail()`), B (eager-load total vs.
  `eager_load.baseline_bytes`, unconditional `fail()`), C (per-file ceilings vs.
  `.files[path].ceiling_bytes`, severity gated by `ORCHESTRATOR_BUDGET_GATE_MODE`, default
  `warn`, defined at `verify-deploy.sh:147`). `warn()` increments `CHECKS` but not `FAILURES`
  (`verify-deploy.sh:149-182`), so a warn-tier per-file overage never makes the overall script
  exit non-zero — this is why `commands/orchestrate.md` has been allowed to stay over ceiling
  "from day one" per the config's own comment.
- **Config note narrates its own history accurately.** The `_comment` and `eager_load.note`
  fields in `orchestrator-context-budget.json` are living documentation, not just data — the
  `eager_load.note` already records the exact justification, date, and originating work
  (documentation growth from the focus-prompt/forced-phase/cycle-budget task) that WORK item (1)
  and (2) of this task's description ask for. This confirms the config's own stated rule
  ("`baseline_bytes` ... must never be silently re-derived ... only a deliberate, reviewed change
  should move it") was followed correctly by task 213, and that this task does not need to redo
  that attribution/decision work — only the `files.*` ceilings/`derivation` fields are now stale.
- **`deploy-headless.sh` exit contract** (`deploy-headless.sh:88-169`): a documented, three-way
  `RESULT=`/exit-code contract with an explicit design note that `not_landed` (exit 1/2) and
  `landed_verify_red` (exit 3) are "NEVER conflated in the exit code" — this is exactly the
  distinction WORK item (4) asks for, already built.
- **`command-gate-out.sh`'s consumption** (lines ~175-216): the redeploy-trigger branch on
  `gate_out_rc=6` explicitly separates branch (a) `deploy-headless.sh` exit 1/2 ("did not land",
  do not retry) from branches (b)/(c), which cover exit 0 AND exit 3 together via a
  `deploy_findings_snapshot` pre/post baseline-relative diff — branch (c) is commented as "the
  expected case today, per deploy-headless.sh's universal exit 3," i.e. the code already
  anticipates and correctly handles the every-deploy-exits-3 situation this task's description
  describes, treating a landed-but-red deploy as a pre-existing-failure pass-through rather than
  a stale/failed deploy.
- **Fixture test's baseline assumption may now be false.** `test-verify-deploy-context-budget.sh`
  (lines 111-124) asserts the real-repo-copied fixture is "clean" at baseline with "at most 1"
  `gate20` finding line, documented as "the pre-existing over-ceiling state of the real
  `commands/orchestrate.md`." With `SKILL.md` now also over its ceiling, a fresh run of this test
  would very likely see 2 gate20 WARN lines at that baseline checkpoint, which the test's current
  assertion (`-le 1`) would treat as a genuine failure of test-fixture cleanliness rather than a
  now-expected second pre-existing WARN. This was not independently confirmed by letting the test
  run to completion in this session (see Context & Scope) — flagged as a likely, not certain,
  outcome for the next phase to confirm and, if confirmed, adjust the assertion/comment (not the
  gate logic) to account for two pre-existing WARNs.

### External Resources

Not applicable — this is a self-contained internal tooling/config task with no external
dependencies or third-party documentation.

### Recommendations

1. **Do not re-touch `eager_load.baseline_bytes`.** It is currently correct (65950, set
   2026-09-18 by task 213 with a recorded justification) and the live measured total (65889) is
   comfortably under it. No action needed for WORK items (1)/(2); the report satisfies the
   "attribute and decide" requirement by confirming the prior task already did so correctly.
2. **Resolve `SKILL.md`'s new over-ceiling state** (WORK item (3), extended to cover the file the
   task description didn't anticipate). Two options, either acceptable per the config's own
   `_comment` precedent for `commands/orchestrate.md`:
   - Trim: the D4 message-findings-recovery documentation added by commit `9465df20d` is
     functional (not restated prose), so a trim would need to move detail into a
     lazily-loaded context file (e.g. a `context/patterns/` doc) rather than deleting content,
     consistent with the task description's own stated preference ("preferred where the growth is
     restatement or prose that belongs in lazily-loaded context files" — here it is *not* pure
     restatement, so this option should be weighed carefully against readability of the skill
     file).
   - Re-baseline: bump `files["skills/skill-orchestrate/SKILL.md"].ceiling_bytes` (or accept the
     warn-tier gap the way `commands/orchestrate.md`'s is already accepted) with an updated
     `measured_bytes`/`measured_at`/`derivation` recording the 9465df20d cause, mirroring the
     `eager_load.note` precedent's structure and dating convention.
3. **Re-attempt/confirm `commands/orchestrate.md`'s remediation** per WORK item (3) as originally
   scoped: its flag table and forced-phase prose are noted in the task description as duplicating
   `merge-sources/claudemd.md` and `docs/architecture/orchestrate-state-machine.md` — this
   research did not diff those three sources line-by-line to identify exact removable
   duplication; that comparison is implementation-phase work, not additional research, since the
   task description already names the specific sections to compare.
4. **For WORK item (4), no code change — only documentation.** Record in the plan/summary that
   `deploy-headless.sh`'s exit 3 contract and `command-gate-out.sh`'s consumption of it were
   confirmed correct as-is (cite `deploy-headless.sh:88-169` and `command-gate-out.sh:175-216`).
   Optionally (not required by ACCEPTANCE): add a small fixture case to
   `test-verify-deploy-context-budget.sh` or a new test exercising `command-gate-out.sh`'s
   branch (c) directly, since no existing test currently drives that branch end-to-end — flagged
   as a nice-to-have, not blocking.
5. **Before closing the task**, re-run (outside this research session's time budget) both
   `bash agent-system/extensions/core/scripts/verify-deploy.sh` (full, to see sub-check C's live
   WARN lines and overall exit 0) and
   `bash agent-system/extensions/core/scripts/scripts/tests/test-verify-deploy-context-budget.sh`
   (correct path: `agent-system/extensions/core/scripts/tests/test-verify-deploy-context-budget.sh`)
   to confirm the baseline-fixture assertion discussed above, and adjust the assertion/comment if
   it now needs to tolerate 2 pre-existing WARNs instead of 1.

## Decisions

- Treated the task description's specific numbers (baseline 64450, measured 65198,
  measured_bytes 64394 on 2026-09-09) as historical/stale context rather than the current live
  state, since a concurrently-landed prior task (213) already re-baselined the config
  legitimately and with a recorded justification before this dispatch began its work. Verified
  this directly against the live config file and a live `measure-eager-context.sh --check` run
  rather than assuming the task description's snapshot was still accurate.
- Did not block on the full `verify-deploy.sh` / `test-verify-deploy-context-budget.sh` runs
  (both slowed by concurrent sibling task activity on the same working tree per this cycle's
  territory note) — instead derived the same sub-check A/B/C outcomes by directly re-running the
  same underlying commands the gate itself uses, then let the full runs finish in the background.
  The full `verify-deploy.sh` run has since completed and its Gate 20 output exactly matches the
  direct derivation (see Context & Scope); `test-verify-deploy-context-budget.sh` was killed by
  its own 300s timeout before finishing and remains an open confirmation item for the next phase.

## Risks & Mitigations

- **Risk**: `SKILL.md`'s new over-ceiling state could keep growing if not tracked, silently
  eroding the entire eager-context budget discipline this gate exists to enforce.
  **Mitigation**: whichever option (trim or re-baseline) is chosen for WORK item (3), update the
  config's per-file `derivation` note the same way `eager_load.note` was updated by task 213, so
  future drift is attributable again.
- **Risk**: `test-verify-deploy-context-budget.sh`'s baseline assertion silently starts failing
  in CI/local runs due to the new second pre-existing WARN, and gets treated as "the test is
  broken" rather than "the fixture's pre-existing-WARN count legitimately changed."
  **Mitigation**: the implementation phase should run the test first, read its actual failure (if
  any) before touching gate logic, and only adjust the test's threshold/comment, never Gate 20's
  actual comparison logic, to accommodate a real second pre-existing over-ceiling file.
- **Risk**: Concurrent sibling tasks in this same `/orchestrate` cycle (228, 236, and evidently
  212's already-landed work) are touching adjacent files; this task's own territory
  (`agent-system/extensions/core/context/config/orchestrator-context-budget.json`,
  `agent-system/extensions/core/scripts/verify-deploy.sh`,
  `agent-system/extensions/core/scripts/deploy-headless.sh`,
  `agent-system/extensions/core/scripts/command-gate-out.sh`,
  `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md`,
  `agent-system/extensions/core/commands/orchestrate.md`) does not overlap the declared
  `file_scope` of siblings 228/236 per this dispatch's Territory block, but `SKILL.md` and
  `orchestrate.md` are both high-churn files under active concurrent development (see
  `9465df20d`, landed hours before this dispatch) — re-read both files immediately before editing
  in the implementation phase, per the standing concurrency protocol.

## Context Extension Recommendations

- **Topic**: none identified as missing. The existing `orchestrator-context-budget.json`
  `_comment`/`note` fields and `verify-deploy.sh`'s Gate 20 header comments already document the
  gate's design rationale thoroughly; no new context file is warranted by this research.

## Appendix

### Commands run

```
REPO_ROOT=$(pwd) bash .claude/scripts/measure-eager-context.sh --check
wc -c agent-system/extensions/core/commands/orchestrate.md agent-system/extensions/core/skills/skill-orchestrate/SKILL.md
git log --oneline --since=2026-09-09 -- agent-system/extensions/core/merge-sources/ agent-system/extensions/core/rules/ agent-system/extensions/core/context/config/orchestrator-context-budget.json
git log --format='%h %ci %s' -- agent-system/extensions/core/skills/skill-orchestrate/SKILL.md
git log --format='%h %ci %s' -- agent-system/extensions/core/commands/orchestrate.md
git show 9465df20d -- agent-system/extensions/core/skills/skill-orchestrate/SKILL.md
```

### Key live numbers (2026-09-18, this session)

| Metric | Live value | Configured ceiling/baseline | Status |
|---|---|---|---|
| Eager-load TOTAL | 65,889 B | baseline_bytes 65,950 B | PASS (sub-check B) |
| Volatile-file hits | 0 | n/a | PASS (sub-check A) |
| `commands/orchestrate.md` | 19,967 B | ceiling_bytes 8,000 B | WARN (sub-check C, warn-tier, pre-existing) |
| `skills/skill-orchestrate/SKILL.md` | 21,318 B | ceiling_bytes 20,000 B | WARN (sub-check C, warn-tier, **newly** over as of `9465df20d`) |

### References

- `agent-system/extensions/core/context/config/orchestrator-context-budget.json`
- `agent-system/extensions/core/scripts/verify-deploy.sh:880-989`
- `agent-system/extensions/core/scripts/deploy-headless.sh:88-169`, `:406-454`
- `agent-system/extensions/core/scripts/command-gate-out.sh:150-220`
- `agent-system/extensions/core/scripts/tests/test-verify-deploy-context-budget.sh`
- Commits: `5937a0d8b`, `f9355fff8`, `c8ff5c68b`, `413d6f9ae` (task 213), `9465df20d` (task 212
  phase 4, the SKILL.md growth source)
