# Research Report: Task #288

**Task**: 288 - Remove the per-dispatch worktree isolation layer and unwire every caller
**Started**: 2026-09-30
**Completed**: 2026-09-30
**Effort**: Large (re-derived footprint is bigger than the dispatch's own inventory suggested)
**Dependencies**: Task 286 (decision-record revision), Task 287 (co-scheduling admission rule) — both `[COMPLETED]`, confirmed in `specs/TODO.md` and `specs/state.json`'s `completed_projects`. Prerequisites are satisfied; this round is cleared to proceed.
**Sources/Inputs**: `specs/decisions/worktree-isolation-removal-verdict.md`; live `grep`/`sed` inspection of every file in `agent-system/extensions/core/` (the source store — see `.claude-extensions.json`'s `core.source_dir`); `scripts/measure-eager-context.sh --check`; `wc -c` on `skills/skill-orchestrate/SKILL.md`; `context/config/orchestrator-context-budget.json`.
**Artifacts**: this report.
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- The dispatch's own inventory table is a useful starting pointer but is **both over- and
  under-inclusive**: of the 18 named non-test files (excluding the two scripts that carry the
  heaviest counts), **10 are false positives** — their "worktree"/"isolation" hits are unrelated
  generic git-worktree or harness-`isolation`-parameter prose, not the dispatch-worktree.sh layer
  — and **4 test files carrying ~118 worktree-specific references are missing entirely** from the
  inventory (`test-orchestrate-cycle-plan.sh`, `test-orchestrate-cycle-postflight.sh`,
  `test-orchestrate-build-dispatch.sh`, `test-lake-build-guard.sh`). Re-deriving before editing
  (as the dispatch itself instructs) is not optional busywork here — it changes which files get
  touched.
- `task_selected_for_worktree_isolation()` in `orchestrate-cycle-plan.sh` is **dual-purpose**: it
  is also the sole reader the Mode 2 build-heavy co-scheduling admission rule (task 287) calls to
  test family membership. It must be **kept and renamed**, not deleted — only 2 of its 4 call
  sites go away.
- One of its 4 call sites (`build_contended_manifest()`'s exclusion) is not merely dead code to
  delete — it is now **actively wrong**: under a shared tree, a former build-heavy task DOES share
  working-copy paths with siblings, so excluding it from the contention manifest would produce a
  false negative (a real path collision never detected). This is a correctness fix, not cosmetic.
- `context/contracts/territory.md` line 136 is similarly now **factually wrong**, not merely
  stale: it calls working-tree/build isolation "a distinct, unimplemented remedy owned elsewhere."
  Isolation is implemented-then-removed (not unimplemented), and build isolation (mode 2) IS now
  implemented, via the co-scheduling rule, not "owned elsewhere."
- The repo-root `.gitignore` (NOT part of the `.claude/` source-store/deploy system — it is a
  directly-tracked repository file) has a dedicated, commented block
  (`/.orchestrate-worktrees/`, `**/.worktree-registry/`) that the dispatch's inventory never
  names at all. It needs its own edit.
- Re-measured now (pre-removal): `skill-orchestrate/SKILL.md` is 21,317 B against a 20,000 B
  ceiling (1,317 B over, confirming the decision record). The removable isolation-specific MUST
  NOT passage is ~950 B — likely not quite enough on its own to clear the ceiling; expect a small
  additional trim is needed and must be *verified*, not assumed. Eager-load total is 67,980 B
  against a 65,950 B baseline (2,030 B over, also confirming the decision record) — but **none of
  this task's editable files are eager-loaded** (no merge-source, no eagerly-loaded rule touches
  "worktree"/"isolation" anywhere). This task's removal is not expected to move the eager-load
  number at all; the dispatch's ACCEPTANCE framing that implies both gates gain headroom from this
  removal is accurate for the SKILL.md ceiling but not supportable for the eager-load baseline.

## Context & Scope

This is phase=research for a `meta` task whose job is to delete `scripts/dispatch-worktree.sh`
and its two dedicated test files outright, and unwire every live caller/reference across the rest
of the source store (`agent-system/extensions/core/`, never `.claude/**`). The decision record
(`specs/decisions/worktree-isolation-removal-verdict.md`) has already ruled on *whether* to
remove the layer and *how* mode 2 (build contention) is replaced (the co-scheduling admission
rule, task 287, already landed) — neither is re-openable here. This report's job is the concrete,
re-derived inventory and the structural gotchas a planner needs to sequence the edit safely:
exactly which lines in which files, which call sites are safe deletions vs. which require a
rename/correctness fix, which files the dispatch named but don't actually need touching, and
which files need touching but weren't named.

I did not write any plan or make any edits — this is research only, per phase=research.

## Findings

### Codebase Patterns

**Source-store boundary confirmed**: `.claude-extensions.json`'s `extensions.core.source_dir` is
`/home/benjamin/.config/nvim/agent-system/extensions/core`. All findings below are against that
tree; `.claude/**` is the disposable deploy copy and is never the edit target.

#### 1. The three files deleted outright (confirmed, no surprises)

| File | Lines | Notes |
|---|---|---|
| `scripts/dispatch-worktree.sh` | 670 | Confirmed present, confirmed sole implementer of `provision`/`path`/`land`/`release`/`prune` |
| `scripts/tests/test-dispatch-worktree.sh` | 661 | Confirmed present |
| `scripts/tests/test-dispatch-isolation-fixture.sh` | 471 | Confirmed present; also the only other file besides `orchestrate-cycle-plan.sh` that names `task_selected_for_worktree_isolation` — moot since this whole file is deleted |

Also remove the three corresponding entries from `manifest.json`'s `scripts`/`tests` file-listing
arrays: `"dispatch-worktree.sh"` (line 94), `"tests/test-dispatch-worktree.sh"` (line 199),
`"tests/test-dispatch-isolation-fixture.sh"` (line 200).

#### 2. `scripts/orchestrate-cycle-plan.sh` — the dual-purpose function is the key hazard

`task_selected_for_worktree_isolation(phase, ttype)` (defined ~line 1834, reading the
`BUILD_HEAVY_TASK_TYPES=("lean4" "cslib")` array hoisted just above it) has **four call sites**:

1. **Line ~1914**, inside the Mode 2 build-heavy co-scheduling admission loop (task 287's own
   code) — `if task_selected_for_worktree_isolation "$g" "${task_types[$t]:-}"; then` governs
   "defer a second build-heavy implement candidate this cycle." **MUST SURVIVE.** This is not
   dead code; deleting the function breaks the already-landed co-scheduling rule.
2. **Line ~2266**, inside `build_contended_manifest()` —
   `task_selected_for_worktree_isolation "$cg" "${task_types[$ct]:-}" && continue` excludes a
   build-heavy task from the contended-path manifest ("it has no shared working copy to contend
   over"). **MUST BE DELETED, and not just as dead code** — under a shared tree this exclusion is
   now *wrong*: a former build-heavy task shares the working copy like everyone else, so excluding
   it would silently hide a real `file_scope` collision from `git-commit-scoped.sh`'s refusal
   check. Removing this line is a correctness fix, not cleanup.
3. **Line ~2488** (`--dry-run` row builder): computes `dry_isolation` and emits
   `isolation`/`worktree_path` into every dispatch-row JSON object unconditionally. **DELETE**
   both the computation and both JSON fields — not just leave them at `"none"`/`null`. The
   ACCEPTANCE criterion ("no isolation or worktree_path fields") requires the fields absent from
   the jq template, not merely always-empty.
4. **Line ~2655** (live-path provision block, ~lines 2643–2671): the entire
   `task_isolation`/`task_worktree_path` computation, the `dispatch-worktree.sh provision` call,
   its failure-deferral branch, and `build_args+=(--worktree ...)`. **DELETE**, along with the
   `isolation`/`worktree_path` fields in the live row builder (~lines 2857–2863, byte-identical
   shape to the dry-run builder).

**Recommendation for the plan**: rename the function (e.g. to something naming "build-heavy
family membership," since it is no longer about isolation at all) and rewrite its header comment
block (~lines 1807–1833, which currently frames it entirely in terms of the now-removed isolation
selection) to describe only its surviving purpose. Leaving the name
`task_selected_for_worktree_isolation` on a function that no longer has anything to do with
worktrees would be a correctness-adjacent naming lie. This is a recommendation, not something the
decision record or dispatch already mandates — flagging it for the plan to decide explicitly.

Also remove: the `BUILD_HEAVY_TASK_TYPES` hoisting comment's framing that describes a "dual
meaning (a) ... (b)" — once (a) (the isolation selection) is gone, only (b) (co-scheduling
membership) remains, so the comment should drop the "dual meaning" framing entirely, not merely
edit around it. The `MUST STAY HOISTED HERE` structural warning about definition-before-call-site
ordering remains fully valid (still true, now only for the one surviving call site) and should be
kept.

The header comment block (~lines 200–251) documenting the `isolation`/`worktree_path` dispatch-row
schema fields also needs full removal — these are schema docs for fields that will no longer
exist.

#### 3. `scripts/orchestrate-cycle-postflight.sh` — delete a whole stage, fix one consumer

The entire **WORK (f0)** block (~lines 811–859: header comment, `worktree_land_blocked`/
`worktree_land_reason` variable init, the `dispatch-worktree.sh path`/`land`/`release`/`prune`
calls) is deleted outright — it exists only to land/release a worktree that will never again be
provisioned.

Its one consumer, inside the `implemented` status-transition arm (~line 941), currently reads:

```bash
if [ "$worktree_land_blocked" = "true" ]; then
  ...
elif skill_gate_completion_claim ...; then
```

This must become a plain `if skill_gate_completion_claim ...; then` — the `worktree_land_blocked`
branch and its body (~lines 941–948) are deleted, not merely left to evaluate a variable that no
longer exists (which would be a hard `set -u` failure, not a silent no-op).

A separate comment at ~line 1342 mentions "working-tree/build isolation posture decision record"
in the context of the *surviving* contended-path commit refusal (`git-commit-scoped.sh --task`) —
this is describing the mechanism that **replaces** isolation, not the isolation layer itself. No
functional change needed there; a planner may choose to reword for clarity but it is not part of
the removal footprint.

#### 4. `scripts/orchestrate-build-dispatch.sh` — a flag and a rendered section

Delete: the `--worktree PATH` header-comment block (~lines 80–88), the `worktree_path=""` default
and `--worktree)` case arm in argument parsing (~lines 155, 172), the `[--worktree PATH]` usage
line (~line 119), and the entire `if [ -n "$worktree_path" ]; then ... fi` block rendering the
"## Isolated Working Tree" dispatch-file section (~lines 480–498).

#### 5. `skills/skill-orchestrate/SKILL.md` — partial paragraph deletion, not whole-MUST-NOT deletion

The MUST NOT block at ~lines 166–177 has two sentences: a still-generally-true opening sentence
("no field of a `dispatch[]`/`aux_dispatch[]` row is ever forwarded as an Agent-tool argument
unless this section names it") that should be **kept**, followed by the isolation/worktree_path-
specific illustration ("In particular, never forward a row's `isolation`/`worktree_path`
fields...") through "...complementary rationale" that should be **deleted** (≈950 B). Do not
delete the whole MUST NOT paragraph — the general principle still has force for `agent`/`model`
and any future row field.

#### 6. `scripts/lake-build-guard.sh` — keep the convention, cut the dead-caller references

Three bullets name `dispatch-worktree.sh` specifically:
- ~lines 58–60: "a consumer that clones a Lean package root via `cp -al` (dispatch-worktree.sh's
  per-dispatch worktree provisioning is the confirmed, reproduced case)" — reword to drop the
  now-dead specific example; keep the standing convention itself (the bullet's actual rule, "this
  guard's own state files must never be hardlink-shared across trees," is a real rule for any
  future `cp -al`-cloning consumer and must survive).
- ~lines 65–66: "`dispatch-worktree.sh` now does this exclusion at its own clone step" — this
  claims a *present* fact about a script that will no longer exist; reword to past tense/history
  or delete, consistent with the dispatch's "remove the derived hazard reasoning too" instruction.
- ~lines 82–85 (RECORDED DEAD ENDS): "`git rev-parse --git-common-dir` is USELESS as a
  tree-identity source for distinguishing a dispatch worktree from its main tree" — this is a
  self-contained design note about *this script's own* `resolve_project_root()` choice, not a
  dependency on dispatch-worktree.sh's existence. **Judgment call for the plan**: it can be kept
  as a historical dead-end record (the investigation happened and the finding is still true of
  `git rev-parse`), reworded to drop the "dispatch worktree" framing, or deleted. I recommend
  keeping it, reworded, since it documents a real, reusable investigation outcome unrelated to
  whether dispatch-worktree.sh exists.

#### 7. `context/contracts/territory.md` — a correctness fix, not a deletion

Line 136's "Working-tree or build isolation between concurrent dispatches ... is a distinct,
**unimplemented** remedy **owned elsewhere**" is actually wrong post-removal on two counts: (a)
working-tree isolation was implemented and is now deliberately removed, not "unimplemented"; (b)
build isolation (mode 2) is now implemented in-repo via the co-scheduling admission rule, not
"owned elsewhere." Needs rewriting to state the current, accurate posture — this directly affects
the correctness of guidance a dispatched agent reads.

#### 8. `context/standards/orchestrator-runtime-files.md` — two rows retired, one row corrected

Per that file's own "Retired conventions" precedent (the `.meta-return-sess_*` case): a retired,
zero-writer runtime-file convention is removed from the Class Table outright rather than kept as
a dead row, since it carries no ongoing accumulation risk. Apply the same treatment here:
- Delete the `.orchestrate-worktrees/<task_number>-<seq>/` row entirely.
- Delete the `specs/.worktree-registry/<task_number>-<seq>.json` row entirely.
- Edit the `specs/.contention-manifest/{session_id}.json` row: remove the clause "excluding any
  task selected for worktree isolation (it has no shared working copy to contend over)" — this is
  the same now-false exclusion claim as the `build_contended_manifest()` code fix above (finding
  #2), just in its documentation form.

I confirmed via `git ls-files -- '**/.worktree-registry*' '.orchestrate-worktrees/**'` that no
stray tracked instance of either runtime path exists (both directories are also absent from disk
right now) — no "manual hunt" cleanup is needed beyond the table edit itself.

#### 9. The repo-root `.gitignore` — NOT in the dispatch's inventory, needs its own edit

`/home/benjamin/.config/nvim/.gitignore` (confirmed distinct from
`agent-system/extensions/core/root-files/.gitignore`, which is a much smaller file that deploys
into `.claude/.gitignore` for hook-log/settings patterns only — the repo-root `.gitignore` is a
separate, directly-tracked repository file, outside the `.claude/` source-store/deploy boundary
entirely) has, at lines 55–60, a dedicated commented block:

```
# Per-dispatch git-worktree isolation (dispatch-worktree.sh): the worktree checkout itself is
# root-scoped (every writer targets the repo root, never a per-task directory), while its
# registry record lives under specs/. Neither has a freshness gate on read -- see
# .claude/context/standards/orchestrator-runtime-files.md's Class Table for the full rationale.
/.orchestrate-worktrees/
**/.worktree-registry/
```

This whole block should be deleted. Since it lives outside `.claude/**`, it is edited directly
(not via the source store) and is simply missing from the dispatch's named footprint — a planner
should add it as its own small step.

#### 10. False positives in the dispatch's named 20-file inventory — do NOT edit these

Verified by reading surrounding context for every hit; each is a generic git-worktree concept or
the harness's own unrelated `isolation` parameter, never the dispatch-worktree.sh layer:

| File | What the hit actually is |
|---|---|
| `scripts/assess-repo-health.sh` | `git ls-files` reads "the worktree" (generic git-index-vs-worktree distinction for `phantom_paths`) |
| `scripts/skill-base.sh` | "stays correct inside git worktrees and nested repos" — generic repo-root resolution robustness note |
| `scripts/backfill-file-scope.sh` | "git worktree root first" — generic repo-root resolution, unrelated to the isolation feature |
| `commands/todo.md` | "the git index behind the worktree" — generic index/worktree staleness note for a metrics-probe ordering decision |
| `context/schemas/state-schema.json` | `phantom_paths` field description, generic git-index-vs-worktree wording |
| `context/reference/state-management-schema.md` | Same `phantom_paths` wording, mirrored from the schema |
| `context/patterns/mcp-server-ownership.md` | References to manually-created **PR-review** worktrees (e.g. `cslib-pr648`), an unrelated, human-driven git-worktree usage |
| `docs/reference/utility-scripts-inventory.md` | A hook's "freshly created worktree with no repository `.claude/` deploy" note — generic, and `dispatch-worktree.sh` is confirmed absent from this inventory entirely (it was never catalogued as a standalone utility script) |
| `docs/reference/standards/agent-frontmatter-standard.md` | Documents the Agent-tool's own **native** `isolation` frontmatter field (`worktree`/`remote`) — a harness capability wholly distinct from the custom dispatch-worktree.sh layer |
| `docs/architecture/extension-system.md` | "a freshly created git worktree" — generic hook-firing-scope note |

Spending plan phases on these 10 files would be wasted effort; I recommend the plan explicitly
exclude them (perhaps citing this report) so a future re-grep doesn't reintroduce them as "still
has a hit" false alarms.

#### 11. Test files NOT in the dispatch's inventory that DO need real work

Re-grepping confirmed `dispatch-worktree` (the literal script name, i.e. a hard file dependency,
not just incidental "worktree" prose) appears in exactly 5 files: the 2 being deleted outright,
plus:

- **`scripts/tests/test-orchestrate-cycle-plan.sh`** (45 "worktree"/"isolation" hits). Contains:
  - **Group 30** (~lines 4090–4282): the entire "working-tree isolation dispatch-site wiring" test
    group — selection predicate Cases A/B/C (dry-run), a staged fake `dispatch-worktree.sh` stub
    (`$WORKDIR/.claude/scripts/dispatch-worktree.sh`, written inline via heredoc at ~line 4166),
    Cases D/F (live provisioning + `--worktree` argv assertion), and a provision-failure-deferral
    case. **Delete this entire group.**
  - **Group 31, Case E** (~lines 4439–4465): "a task selected for worktree isolation is excluded
    from contention entirely" — tests the now-incorrect exclusion from finding #2. **Delete this
    case**; the exclusion it tests is being removed as a correctness fix, so the test asserting
    the old (now-wrong) behavior must go with it.
  - **Group 32**'s header comment (~lines 4518–4527) says it "reuses Group 30's
    dispatch-worktree.sh/orchestrate-build-dispatch.sh/update-task-status.sh stubs" — but I
    verified Group 32's actual assertions (the co-scheduling admission cases) never reference
    "worktree" in their bodies, only in this header comment, and every Group 32 fixture already
    declares `"file_scope": []`, so none of them reach a provision call site even today. Group 32
    is safe to keep once Group 30 is deleted; only its header comment's "reuses Group 30's
    dispatch-worktree.sh stub" framing needs rewording (the stub will no longer exist to reuse).
- **`scripts/tests/test-orchestrate-cycle-postflight.sh`** (44 hits). Contains:
  - Two `require_file`/`cp` list entries for `dispatch-worktree.sh` (~lines 44, 69) — these MUST
    be removed or the suite's own setup fails outright (file not found) regardless of whether any
    test body still references worktrees.
  - A "Phase 7" test group (~lines 1900–2100+): a "non-isolated regression" micro-check
    (~1906–1909) plus three full real-worktree-provisioning cases (clean land, conflict, specs/**
    refusal) using helper functions `provision_worktree_fixture`/`worktree_path_for` that shell
    out to a real, sandboxed `dispatch-worktree.sh`. **Delete this entire Phase 7 group** — WORK
    (f0) is gone, so nothing in the SUT exercises this path any more.
- **`scripts/tests/test-orchestrate-build-dispatch.sh`** (26 hits, but most are the unrelated
  "ISOLATION CONTRACT" test-harness naming convention at lines 15/95 — a sandbox-isolation
  guarantee for the test itself, not about the feature). The real work is **Group 15**
  (~lines 851–900): "`--worktree` flag -- `## Isolated Working Tree` section present with the
  flag, absent without" — Cases A/B/C. **Delete this entire group.**
- **`scripts/tests/test-lake-build-guard.sh`** (3 hits, all comments explaining a test case is
  "deliberately NOT routed through dispatch-worktree.sh's `provision`" — i.e. these tests never
  call the script, they just name it in a comment contrasting their own raw-`cp -al` approach).
  These comments must be reworded (they name `dispatch-worktree.sh` directly, which must not
  survive anywhere per the ACCEPTANCE bar) but no test logic changes — the tests are independent
  of the script already.

This is a **substantial** addition to the task's real footprint — roughly 118 more
"worktree"/"isolation" references across 4 files the dispatch's own inventory never names, on top
of the 228 it does name (of which, per finding #10, a meaningful fraction are false positives).
Skipping these four test files would leave `require_file`/`cp` calls pointing at a deleted script
in two of them (hard failures, not just stale assertions) and would leave the shell harness
asserting dispatch-row shapes (`isolation=worktree`) that can never occur again in the other two.

### External Resources

Not applicable — this is a pure in-repo mechanical removal task with no external library or API
surface involved.

## Decisions

- Treat the dispatch's named-file inventory as a **starting hypothesis to verify**, not a
  checklist to execute literally — 10 of its ~18 non-heavy-script entries are false positives and
  must not be edited; 4 test files carrying real, substantial work are entirely absent from it and
  must be added.
- `task_selected_for_worktree_isolation()` is renamed and kept (not deleted) because the
  build-heavy co-scheduling admission rule (task 287) depends on it as its sole array reader; only
  its worktree-provisioning and contention-exclusion call sites are removed.
- The `build_contended_manifest()` exclusion and the `context/contracts/territory.md` line are
  both **correctness fixes** enabled by this removal, not mere deletions of now-irrelevant code —
  the plan should frame them that way so a reviewer understands why the behavior itself changes
  (a former build-heavy task now DOES appear in contention accounting).
- The repo-root `.gitignore` edit is in scope for this task (it is the direct, load-bearing
  cleanup of the two runtime paths `dispatch-worktree.sh` used to create) even though it sits
  outside `agent-system/extensions/core/` and outside the dispatch's named footprint.
- Byte-budget re-measurement should be performed, and reported, **after** the edits land (per the
  ACCEPTANCE bar), not assumed from the decision record's figures. I already re-confirmed the
  *pre-removal* baseline now (SKILL.md 21,317 B / 20,000 B ceiling; eager-load 67,980 B / 65,950 B
  baseline) so the plan has a known starting point to diff against.

## Risks & Mitigations

- **Risk**: deleting `task_selected_for_worktree_isolation()` wholesale (a naive reading of "this
  function exists only for worktree isolation") would silently break the already-landed
  build-heavy co-scheduling rule, since it is that rule's sole array reader. **Mitigation**:
  rename-and-narrow, confirmed safe by this report's call-site enumeration (finding #2).
- **Risk**: leaving the `build_contended_manifest()` exclusion or the `territory.md` line
  unchanged (treating them as "just docs/comments, skip them") would leave a live correctness bug
  and a factually wrong contract document in place. **Mitigation**: both are called out explicitly
  above as correctness fixes, not optional cleanup.
- **Risk**: skipping the 4 untracked test files (since the dispatch doesn't name them) would leave
  two suites unable to even start (`require_file`/`cp` against a deleted script) and two suites
  asserting a dispatch-row shape (`isolation`/`worktree_path`) that becomes permanently
  unreachable, producing NEW shell-harness failures that `known-failures.txt` does not yet
  tolerate. **Mitigation**: finding #11 above gives line ranges for each.
- **Risk**: assuming the eager-load byte gate gains headroom from this removal (per the dispatch's
  ACCEPTANCE wording) when in fact none of this task's files are eager-loaded. **Mitigation**:
  report the SKILL.md-ceiling gain and the eager-load number separately and honestly at
  verification time; do not claim an eager-load improvement this task's own edits cannot produce.
- **Risk**: the SKILL.md MUST NOT trim (~950 B) may not, by itself, bring the file from 21,317 B
  under the 20,000 B ceiling (leaving ~300–400 B still over by rough estimate). **Mitigation**:
  measure after editing rather than assuming the ceiling clears; if it doesn't, a small additional
  wording-economy pass (consistent with how this same file cleared its ceiling before, per
  `orchestrator-context-budget.json`'s own derivation history) is a legitimate, in-scope follow-up
  inside this same file.

## Context Extension Recommendations

- **Topic**: known-failures.txt or test-suite documentation does not currently record anything
  about the worktree-isolation test groups. No gap to document — once those groups are deleted in
  this task's implementation, no trace needs to remain.
- **Gap**: none identified that warrants a new standing context file. The relevant standards
  (`orchestrator-runtime-files.md`'s retirement precedent, `shell-strict-mode.md`'s classification
  table) already cover the patterns this removal needs to follow; they just need their own content
  updated per findings #6 and #8 above.
- **Recommendation**: none beyond the in-task edits already enumerated.

## Recommendations

1. Sequence the plan phases around the *verified* footprint in this report, not the dispatch's raw
   counts: (a) `orchestrate-cycle-plan.sh` function rename/narrowing + 3 call-site deletions +
   contention-exclusion correctness fix; (b) `orchestrate-cycle-postflight.sh` WORK (f0) deletion +
   `implemented`-arm consumer fix; (c) `orchestrate-build-dispatch.sh` flag/section deletion;
   (d) `skill-orchestrate/SKILL.md` partial-paragraph trim; (e) `lake-build-guard.sh` reference
   cleanup (convention kept); (f) `territory.md` correctness rewrite; (g)
   `orchestrator-runtime-files.md` two-row deletion + one-row edit; (h) `manifest.json` 3-entry
   removal; (i) repo-root `.gitignore` block deletion; (j) the three outright file deletions;
   (k) the 4 untracked test files (Group 30 deletion, Group 31 Case E deletion, Group 32
   comment reword, two `require_file`/`cp` entries, Phase 7 postflight-test deletion, Group 15
   build-dispatch-test deletion, lake-build-guard comment rewording).
2. Explicitly exclude the 10 false-positive files from any edit phase, citing this report, so a
   fresh grep during implementation doesn't reintroduce wasted work chasing them.
3. Run the full shell harness (`scripts/tests/`) after the test-file edits and diff against
   `scripts/tests/known-failures.txt` (currently contains zero worktree/isolation-related rows) —
   any new failure not explained by an intentional behavior change (the contention-exclusion fix)
   is a real regression to fix before closing this task.
4. At verification time, re-run `wc -c skills/skill-orchestrate/SKILL.md` and
   `REPO_ROOT=$(pwd) bash scripts/measure-eager-context.sh --check`, and update
   `context/config/orchestrator-context-budget.json`'s `measured_bytes`/`measured_at`/
   `derivation` fields for `skills/skill-orchestrate/SKILL.md` with the real post-edit number and
   a dated note — per that file's own "may be refreshed freely" convention — while reporting the
   eager-load number as unchanged-by-this-task (with the reasoning from finding above), not
   silently omitted.
5. Run shellcheck on every edited `.sh` file per `context/standards/shell-strict-mode.md`; none of
   the edited scripts' strict-mode classification changes (no new Class A/B/C admission question
   is raised by this removal).
6. No task-number references belong in any deliverable outside `specs/**` — verified none of the
   edit sites above require citing a task number in the edited prose itself.

## Appendix

### Search queries used

- `grep -rl "dispatch-worktree\|worktree_isolation\|worktree-isolation\|WORKTREE_ISOLATION\|task_selected_for_worktree_isolation"` and the broader `grep -ril "worktree"` across `agent-system/extensions/core/`
- Per-file `grep -ci "worktree\|isolation"` to re-derive counts against the dispatch's claimed 228/20
- `grep -rln "dispatch-worktree" scripts/tests/*.sh` to isolate real hard-file-dependency hits from incidental prose
- `grep -rln "task_selected_for_worktree_isolation"` to enumerate every reference to the dual-purpose function
- `git ls-files -- '**/.worktree-registry*' '.orchestrate-worktrees/**'` to confirm no stray tracked runtime-path instance
- `REPO_ROOT=$(pwd) bash agent-system/extensions/core/scripts/measure-eager-context.sh --check` for the live eager-load total
- `wc -c skills/skill-orchestrate/SKILL.md` for the live SKILL.md byte count

### References

- `specs/decisions/worktree-isolation-removal-verdict.md` (verdict, not re-openable)
- `context/config/orchestrator-context-budget.json` (byte-ceiling gate config)
- `context/standards/orchestrator-runtime-files.md` (runtime-file Class Table + retirement precedent)
- `context/standards/shell-strict-mode.md` (shellcheck/strict-mode classification, confirmed unaffected)
