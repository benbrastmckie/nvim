# Review Report — Backlog Reconciliation

**Date**: 2026-10-01
**Scope**: all 48 non-terminal tasks in `specs/state.json`, plus `specs/ROADMAP.md`
**Question asked**: should any task be combined, revised, abandoned or added; should any topic,
dependency edge or `file_scope` be adjusted; and bring `ROADMAP.md` into line.

## Summary

The backlog itself is in good shape. **Nothing qualified for combination and nothing for
abandonment.** The decay was in `ROADMAP.md`, which had drifted from the state it describes, and in
three `file_scope` declarations.

| Finding | Count |
|---|---|
| Duplicate/merge candidates | 0 |
| Abandonment candidates | 0 |
| Topic mis-assignments | 0 |
| `file_scope` corrections applied | 5 tasks |
| New tasks filed | 0 (the one candidate proved already filed) |
| `ROADMAP.md` rows stale | 3 removed, 18 added |

## Combination, abandonment, topics, dependencies — all negative, with evidence

- **No duplicates.** The one duplication incident on record (310 duplicate-of-272, 309
  subset-of-302) was already resolved before this pass. 302 and 304 both edit
  `git-commit-scoped.sh` but implement distinct mechanisms (staging-lease consultation vs.
  partial-pathspec-abort behaviour); their `file_scope` overlap already serializes them, so no
  dependency edge is warranted and no merge is appropriate.
- **No abandonments.** Checked specifically against settled decision 14 (worktree isolation removed
  wholesale): no open task still assumes that layer exists as live design. 277 had already dropped
  its worktree-targeting half.
- **No topic changes.** 290 (`topic=core-agent-system`, `task_type=neovim`) is a defensible
  cross-cutting case — Lua-implemented deploy-gate logic — not an error.
- **No new dependency edges.** `ROADMAP.md`'s "165 → 265 → 263" is sequencing advice, not a
  prerequisite chain: none of the three declares the others, and `file_scope` overlap already
  handles admission. Recording it as a hard edge would have changed wave computation for no reason.
  This is now stated as advice in the file so a future reader does not mistake it for an edge.

## The candidate new task was already filed

`ROADMAP.md` instructed filing the three red `verify-deploy` gates as one task. Re-measurement
disproved the premise:

| Gate | ROADMAP claim | Measured 2026-10-01 |
|---|---|---|
| Manifest content-hash (gate 5) | red | **still red**, 3 findings — already task 290's exact scope |
| Postflight boundary lint (gate 9) | red | **green**, full corpus |
| Eager-load total (gate 20) | red, 67,980 B vs 65,950 | **green**, 65,663 B vs 65,950 |

`verify-deploy.sh --skip-slow` now returns **FAIL — 1 of 33**, and gate 5's three findings are
byte-for-byte the three contract paths 290 names as cross-extension false positives. Filing a new
task would have created a duplicate-of-290 — the exact failure mode task 312 exists to prevent — so
none was filed. 290 is now promoted to the blocking position in `Next`.

Consequence for planning: 89 and 251 were described as "load-bearing" because they could clear the
eager-load failure. That failure is gone; both remain worth running on cost grounds only.

## `file_scope` corrections applied

| Task | Change | Why |
|---|---|---|
| **268** | Dropped `dispatch-worktree.sh` and `test-dispatch-worktree.sh` | Both files no longer exist — deleted with the worktree layer. Pure factual correction |
| **270** | Replaced two bare directories with 5 concrete paths | Its `scripts/` entry overlapped **23** non-terminal tasks; `ROADMAP.md` already directed narrowing. Now: the anticipated check script and its test, the one confirmed defect site (`orchestrate-build-dispatch.sh:389-392`), the inventory doc, and `scripts/lib/` (kept — deliverable 2 may land a helper there). Worst overlap fell 23 → 3 |
| **294, 295, 296** | Added `file_scope` (previously absent) | All three were filed by an earlier review pass with no scope at all; their target files are named explicitly in their own descriptions |

The two anticipated paths in 270 (`check-jq-null-safety.sh` and its test) follow the `check-*.sh`
convention 270's own description cites; adjust at plan time if the audit names it differently, and
widen if the audit finds further defect sites.

## Remaining `file_scope` warning worth acting on

`validate-state.sh --deep` now reports **18 passed, 2 warnings, 0 failed** (was 2 warnings, both
270's). The two warnings are now:

- **300**: `scripts/tests/` overlaps **19** non-terminal tasks — the worst remaining coarse
  declaration, and the one most likely to serialize a lane. Narrow at plan time.
- **270**: `scripts/lib/` overlaps 3 (263, 280, 281) — the narrowest honest declaration while its
  deliverable 2 remains undecided.

## `ROADMAP.md` reconciliation

- Removed the `Where things stand` status table, as requested. The two facts that lived only there
  — `MAX_TASKS` is 8, and all eight consumer repos are STALE — were relocated rather than dropped.
- Removed 3 stale rows: 286, 287, 288 are completed and archived, as are the sub-item
  parentheticals (190, 224, 264, 267) and 301. Call 0 is now 277 and 279 only.
- Added **Call F** for the 18 tasks that appeared nowhere in the file: 290, 294–300, 302–304,
  306–309, 311–313. Grouped into five themed, separately-runnable batches (`MAX_TASKS` forbids
  merging them): commit-staging correctness, orchestrator defects, roadmap/TODO automation, the red
  gate plus the books extension, and Neovim config hygiene.
- Refreshed every measured number against a live run, per standing rule 3.
- Accounting line now reads 2 + 4 + 8 + 4 + 7 + 5 + 18 = 48 and matches `state.json` exactly.

## Recommendation

This file was reconciled by hand, and that is the thing to fix rather than repeat. Tasks 306, 307,
308 and 313 (call F3) make the roadmap generated, wire `/todo` to prune it, wire `/review` to
regenerate it, and lint hand-authored batch blocks. Until that lane lands, every pass like this one
re-derives by hand a structure the system already computes in `TODO.md`'s Dependency Waves table.

Run order from here: **290** (the red gate), then call A.
