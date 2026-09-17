# Implementation Path

*Rewritten 2026-09-02 from a full re-survey of the agent system after the orchestrate-centric
consolidation (116 → 117-127, 135) landed. Supersedes every earlier revision of this file, all of
which described a Stage 0-6 structure whose tasks are now complete, abandoned, or renumbered. The
prior text survives in git history; nothing from it is carried forward except the standing rules
at the end.*

*Second pass, same day: three decisions recorded (batch of one; the orchestrator never asks on its
own; a bounded Workflow spike after Stage A), and the backlog manifest **applied** to
`state.json` — 145-148 created, 143/88/142/144/72 revised, 138/53/100/42 abandoned into
successors, three stale `file_scope` entries removed, `TODO.md` regenerated.*

*Third pass, same day: four more decisions (team mode deleted; hard mode kept in full; research on
demand; the dry-run report retired into the cycle-plan script) — 149 and 150 created, 145/147/148/
88/72 revised, 141 abandoned into 147. A "Validation to run" section added.*

*Fourth pass, 2026-09-03: Batch 1 (125, 144, 20, 113, 27, 72) and Stage A steps A.0-A.3 (149, 145,
146, 147) all landed and archived — five of Stage A's nine tasks are now complete. Sizes
re-measured by execution, not inherited: `SKILL.md` 293,977 B → 225,553 B (146/147's 46,180 B
Stage MT-3/MT-4 collapse), `commands/orchestrate.md` 46,874 B → 19,104 B (145's slim), eager
CLAUDE.md-chain load unchanged at 62,985 B (~15.7k tokens; Stage A has not touched CLAUDE.md/rules
yet). **143 is next**: its dependency (147) is satisfied and it is the sole remaining gate on 148.
No new decisions this pass — see the updated tables below for the full status sweep.*

*Fourth pass, addendum (same day): "143 is next, unblocked" was true on paper and **false in
practice** — a dry run showed 143 silently absent from the dispatch plan. `orchestrate-cycle-plan.sh`
resolved `dependencies[]` against `active_projects` only, so this morning's archival made every
COMPLETED predecessor unresolvable, and an unresolvable predecessor read as "still in flight". Five
tasks (143, 127, 139, 44, 89) were permanently un-dispatchable, and none of them surfaced in
`blocked[]` — they vanished from the plan, leaving only the aggregate `no_eligible_stuck` message.
Fixed directly in the source store (archive-aware `lookup_project`; dangling edges now reported in
`blocked[]`), with 9 regression assertions verified to fail against the pre-change script. All five
now dispatch. Standing rule 3 earned its keep again: the paper status was wrong and only execution
caught it.*

*Fifth pass, 2026-09-08: **Stage A is complete.** 142 and 150 landed, closing the thin-lead chain
at 10/10. The engine went 189,000 B → 15,459 B across the arc; the default lifecycle is now
planner-first with research on demand. Two process facts earned by this pass, both recorded below:
a self-modifying task is not finished until `.claude/` is resynced (150's completion was gated on
exactly that, correctly), and the pre-dispatch review's Class C reports "0 findings" for a solo
self-modifying candidate whose verdict says `self_modifying: true` — a false negative now filed.
Batch 3 proposed. Stages B-E were **not** re-surveyed this pass; the 26 tasks filed since
2026-09-03 are listed under "Filed since the last survey" rather than folded into stage rows,
so the gap is visible instead of implied away.*

*Sixth pass, 2026-09-14: **re-survey of everything filed since 2026-09-03** (tasks 155-212), ranked
by how essential each is to the core agent system working correctly rather than by theme. The
result is the new "Core-essential path" section directly below, which supersedes Batch 3 and the
"Filed since the last survey" table. Two facts changed underneath this file since the fifth pass:
**decision 7 is superseded** (196 made research-first the default again, planner-first only under
`--fast`), and 197 made forced phases work on terminal and archived tasks. Checked by execution this
pass, not read off task text: three core test suites are red on `master` (one cause is 206's; one is
an unfiled regression from 197; one is undiagnosed), the postflight verdict ladder accepts a
`researched` status without checking that a report file exists, and the handoff-writer allowlist
still names only two hard-mode agents. 22 completed tasks are awaiting `/todo`.*

*Sixth pass, addendum (same day): three `/orchestrate` defects were hit live in the Verification
repo during `/research 4 --research "<focus>"` and filed as **213 → 214 → 215**. (213) The focus
text is dropped before it reaches the dispatch file. (214) Forced phases don't stop as documented:
once the forced queue is empty the task falls through to status routing, so a later "check" call
moved a RESEARCHED task to PLANNING. (215) Nothing can undo a dispatch that was set up but never run.
213 and 214 go into Tier 1, ahead of 212, because they edit `orchestrate-cycle-plan.sh` and
`SKILL.md`. By decision 12, eight open tasks that edit those files now wait on them. 215 goes into
Tier 3. 55 tasks are open.*

*Seventh pass, 2026-09-17: **the backlog grew from 55 to 72 open tasks and no core task closed.**
Eighteen tasks were filed since the sixth pass (217-234); the one completion (222, a Rust
extension) is off the core path. Tier 1 stands at 0/9. This pass is a consolidation survey, ranked
by one test: does the task make the core system correct for the Lean work that runs on it in the
consumer repos. It proposes merging twelve tasks into their siblings and abandoning seven, which
leaves 53. The manifest was proposed, then **applied the same day** on the user's instruction
(decision 13); the scope corrections, ordering edges and description addenda were applied
alongside it. The section "Seventh pass" directly below supersedes the sixth pass's
tiers and batches where they disagree.*

---

## Seventh pass (2026-09-17): consolidate before dispatching

### What changed since the sixth pass (2026-09-14 → 2026-09-17)

| Filed | What it is | Lean-supporting? |
|---|---|---|
| 217 → 218 → 219 | `/refresh` cost-aware idle Lean LSP tree reclamation (PSS accounting, CPU-delta idleness, notify-before-kill). One feature in one script, filed as a three-task chain | yes (Lean LSP trees) |
| 220 → 221 | `lake-build-guard.sh result` subcommand; lean agent contracts stop reading a piped `$?` and stop `pgrep -f`-ing themselves. Both halves observed live in BimodalLogic | yes |
| 223 | Comparator-on-NixOS fixes for the lean extension; research done (moved from Verification) | yes |
| 224 → 225 | `/please` single-use grant, push guard, grant check in the destructive-git guard, plus the command and docs | no (user-requested feature) |
| 226 | `git-commit-scoped.sh` drops staged deletions; observed twice in BimodalLogic | yes |
| 227 | The source-store boundary rule names a path that exists only here; unfollowable in every consumer | yes |
| 228 → 229 → 230/231 → 232, 231 → 233 | Six dependency-graph tasks: batch-as-default doc, reasons on edges, terminal-edge disposition, post-burst analysis pass, graph metrics, scope-derived edge inference | no |
| 234 | `state-write.sh` silently binds every `--argjson-file` after the first to the first file's value; exit 0 | yes (every state write in every repo) |

Also: `/todo` has not run since 2026-09-14; 183 (abandoned) and 222 (completed) sit in
`active_projects` awaiting it.

### Verified by execution this pass

- **All 63 core suites were run.** 61 green, 2 red, both known: `test-postflight-deploy-gate.sh`
  (7 FAIL, the `task-lookup-lib.sh` fixture gap) and `test-lint-json-channel-discipline.sh` (2
  FAIL, the redirect-to-`$var` false positive at `orchestrate-triage-classify.sh:225`).
  **`test-gate-out-repair-reporting.sh` is green (19/19)**, so 206's third suite is gone; its
  description and `file_scope` were narrowed accordingly.
- **Sizes are flat.** `SKILL.md` 16,025 B, `commands/orchestrate.md` 17,755 B, eager load 65,198 B
  (~16.3k tokens), all identical to 2026-09-14. The engine is not regrowing. The weight is now in
  scripts and context: core holds 431 files / 6.3 MB, 112 scripts, 64 test suites and 1.67 MB of
  `context/` (`patterns/` alone is 613 KB). The three largest scripts are `orchestrate-cycle-plan.sh`
  111,813 B, `skill-base.sh` 90,535 B and `task-lock.sh` 86,540 B.
- **The dry run over all 72 open tasks** (`orchestrate-cycle-plan.sh --dry-run`, `state.json`
  checksum unchanged) admits 26 research dispatches, 188 and 223 to plan, 39 to implement; 0
  blocked. Before this pass's scope fix, 224's directory-level declarations (`hooks/`,
  `scripts/tests/`) deferred **234** (the state-write data-corruption fix) behind a feature and
  collided with 129. After narrowing 224 to its nine concrete files, 234 dispatches.
- **226's root cause is in the code, not a hypothesis.** `git-commit-scoped.sh:181` keeps a positive
  pathspec only if it exists on disk or in the index. After `git rm` it is in neither, so the V2 gate
  drops it with a WARN and commits the rest. A rename loses its delete half the same way. The fix is
  to also accept a path present in HEAD or in the staged diff. Recorded in 226's description.
- **The wave table already ignores edges to archived tasks.** 51 sits in wave 2 although its edge
  to 143 (archived) is still declared; 14 is "blocked by 139" only, not by 88. `generate-task-order.sh`
  binds `active_projects` only, and unresolvable targets fall out of Kahn's BFS as satisfied.
  `orchestrate-cycle-plan.sh` and `orchestrate-triage-classify.sh` resolve archived targets
  explicitly (197). So 230's and 232's central premise, that archived edges corrupt the critical
  path and wave widths, does not hold; the one live harm is the classifier's `nonexistent` verdict,
  which 188 (researched) already owns.
- **184 is live, not a paper concern.** `skeleton=true` appears in 11 artifacts across BimodalLogic,
  cslib and Theory; the batch engine has no completion branch for a skeleton plan
  (`orchestrate-cycle-plan.sh:1558` records the deletion).
- **Runtime-file clutter (51)**: 34 session files sit in this repo's `specs/` root, 42 in Theory's,
  15 in BimodalLogic's.
- **Consumer deploy (200)**: `check-consumer-freshness.sh` reports PossibleWorlds' core STALE.
- **Two agent-system defects are filed in a consumer repo** (standing rule 1): cslib 595 wants a
  dependency-integrity gate that `validate-state.sh` Check D3 already provides (their deployed copy is
  behind), and cslib 608 is a `\bsorry\b` word-boundary double count in `lean-sorry-census.sh`, which
  is exactly 129's class on a file already in 129's scope. 608's evidence was carried into 129.
- **96 pairs of open tasks share file territory with no ordering edge** between them (direct or
  transitive). Most are directory-level declarations (170's `scripts/tests/`, 194's `*/agents/`,
  224's former `hooks/`). The runtime wave-split check defers these at dispatch, so they cost cycles
  rather than correctness; the merges below remove the densest clusters (five tasks on the two lean
  implementation-agent files; four on `orchestrate-cycle-plan.sh` + `SKILL.md`).

### The lean-supporting core set

These are the core tasks whose absence is felt in a Lean repo's `/orchestrate` run. Everything
else is either a defect only this repo hits, or an improvement.

| Cluster | Tasks (after the manifest) | Why it bites Lean work |
|---|---|---|
| Silent data loss in the writers | **234**, **226** | Every state write and every scoped commit in every repo. Both tiny |
| Forced phases and honest postflight | **213** (absorbing 214, 216) → **212** (absorbing 195) → 215; 194 first | The `--research`/`--plan` workflow the user runs on proofs; research phases recorded complete without a report |
| Build verdict | 172; **173** (absorbing 220) → **221** (absorbing 175, 198) | A broken build looked green; 56 minutes idled on a finished build; a snapshot reverted a sibling's work |
| Idle Lean trees | 174 → **217** (absorbing 218, 219) | Memory pressure on the Lean host; prompt, never silent kill |
| Skeleton plans | **184** | Strategic-sorry plans cannot reach a terminal status under the batch engine |
| Lean extension content | **223**, 177 | Comparator on NixOS; dependency tracing |
| Propagation and bootstrap | **200**, **227**, 209 → 210 (absorbing 211), 51 | A fix stays broken in BimodalLogic until someone redeploys; the boundary rule is unfollowable there; `/task` fails on a fresh repo |
| Concurrency in a shared tree | 188; 162 (absorbing 164) → 165 → 190; 163; 193 → 199 | The 574/575 and 544/545 incidents; the classifier noise |
| Agent contracts | 194 → **136** (absorbing 14), 139 → 140 | Fan-out, marker/commit sync, Status ownership, history rewrites |

### Manifest (APPLIED 2026-09-17, decision 13)

**Applied the same day, by the user's instruction**, in one `state-write.sh` transaction
(`validate-state.sh`: 0 failures, 3 warnings, down from 6). Each merge appended the absorbed task's
description verbatim under an `=== ABSORBED 2026-09-17 from former task N ===` header, unioned
its `file_scope`, and repointed every dependent; the surviving task got a new title. Each
abandonment prefixed the task's description with its reason. The 19 abandoned entries stay in
`active_projects` until `/todo` archives them, exactly like 183. Open count **72 → 53**; the wave
table went from six waves to four; the dry run admits 22 tasks with 0 blocked. No metatask was
created: the revision work was mechanical and is finished, so a task to do it would only add to
the backlog it was cutting. The table below is the record of what was done.

Two rules drove it. A linear chain of small tasks that all serialize on one file is one task with
phases, not three tasks: the chain costs three dispatches per link and a critical-path slot per
cycle, and produces no more than the single task would. And an analysis surface is not built over
a graph whose own declarations are known to be too coarse to carry it.

| Op | Tasks | Result |
|---|---|---|
| Merge | **214, 216 → 213** | One "forced-phase fixes" task, three phases: focus text through; stop after the last forced phase within a run; per-run cycle bound and admit-by-artifact. 215 and the eight dependents (14, 162, 182, 193, 195, 199, 212, plus 183's successor) repoint to 213 |
| Merge | **220 → 173** | Guard: terminal record on every exit path, then `result` subcommand and `--expect-pid/--expect-scope`. Same two files |
| Merge | **175, 198 → 221** | Lean implementation-agent contract corrections: build-verdict method, waiter teardown, `--no-revert` snapshot. Same two agent files, one incident family. Deps 172, 173 |
| Merge | **218, 219 → 217** | Cost-aware idle Lean tree reclamation, three phases. Dep 174 |
| Merge | **14 → 136** | Implementation-agent contract text: fan-out prohibition, marker/commit sync, plan-level Status ownership, validator catch. Drop `SKILL.md` from scope (that half landed). Deps 166, 194, 139 |
| Merge | **195 → 212** | Postflight honesty: gate research on a report file, derive the handoff-writer predicate from the dispatch row. Drop the 162 edge |
| Merge | **164 → 162** | Harvester, its three wiring sites (`orchestrator-postflight.sh`, `reconcile-task-status.sh`, `/revise`), then the backfill as a final phase |
| Merge | **211 → 210** | `/task` create defects: topic order and registration, keyword false positives. Same file |
| Merge | **225 → 224** | `/please`: mechanism, then command, rule exception and docs, two phases |
| Abandon | **229** | Reasons on edges have no machine consumer; record the prose convention ("ORDERING:" in the description) in `state-management-schema.md` when 162 lands, no schema change |
| Abandon | **230, 232** | Premise falsified above: wave and eligibility consumers already ignore archived edges. Pruning at archival is a one-line addition to `/todo`'s existing dependency-update step; file it only if the classifier fix (188) leaves anything to prune |
| Abandon | **231, 233** | Both build passes over `file_scope` at a granularity 233's own text calls too coarse. One idea survives as an observation: persist the step-4.5 wave-split deferral as an edge, after 165 rules on absent scope |
| Abandon | **168** | A doc correction in a tree the user declared frozen (22's policy) |
| Abandon | **187** | Cosmetic; the harness now supplies attribution and `git-commit-scoped.sh` composes its own trailer |
| Keep, reorder | 74 → 75/76 after **167** | 167 is the always-on rule; land it, then decide whether the three-task mechanism is still wanted |
| Keep | 228 | Doc only; low; carries the collision-visibility argument, which is worth stating once |

Net: 72 open → 53 (12 merged away, 7 abandoned). Every capability in a merged or abandoned task
has a named home above, except 229-233's analysis surfaces, which are dropped by decision.

Abandoned this pass (19): 14, 164, 168, 175, 187, 195, 198, 211, 214, 216, 218, 219, 220, 225,
229, 230, 231, 232, 233. Plus 183 from the sixth pass and 222 completed: **21 entries await
`/todo`.**

**Dependency graph after the manifest** (from the regenerated `TODO.md`, read-only dry run
confirmed `state.json` untouched):

| Wave | Tasks |
|---|---|
| 1 | 22, 29, 39, 45, 89, 127, 129, 167, 172, 177, 184, 185, 188, 194, 200, 202, 206, 207, 209, 213, 223, 224, 226, 227, 228, 234 |
| 2 | 30, 43, 51, 74, 139, 162, 163, 166, 173, 174, 193, 208, 210, 212, 215 |
| 3 | 44, 75, 76, 136, 140, 165, 170, 182, 199, 217, 221 |
| 4 | 190 |

Deferred by the runtime scope check in the dry run, all correctly: 29 and 45 behind 22 (picker
Lua), 202 behind 45, 224 behind 129 (`guard-destructive-git.sh`).

### Applied to `state.json` this pass

Through `state-write.sh --regen-todo`; `validate-state.sh` 0 failures, 5 warnings (was 6).

| Change | Tasks | Why |
|---|---|---|
| `file_scope` narrowed | 224: `hooks/`, `scripts/tests/` → nine concrete files | The directory declarations deferred 234 and collided with 129 in the dry run |
| `file_scope` filled | 226: `git-commit-scoped.sh` + its suite · 227: the rule file | Both were empty, invisible to admission |
| `file_scope` narrowed | 206: `test-gate-out-repair-reporting.sh` removed | Suite is green |
| Description extended | 206 (suite 3 withdrawn) · 226 (root cause at line 181) · 129 (the `warn.sorry` instance from cslib) | See above |
| Dependency added | 136←194, 166←194, 43←194 | 194 audits every agent file; the specific agent edits go after it. 43←194 also frees 194 from the dry run's deferral behind 43 |

Not committed: `specs/state.json`, `specs/TODO.md` and this file carry the changes uncommitted.

### Recommended batches (the manifest is applied; these are live)

```
# Batch A: writers, forced phases, build verdict, bootstrap. Critical-path members: 213, 200, 212.
/orchestrate 234, 226, 206, 213, 200, 194, 209, 188, 173, 172, 174, 184, 223, 177, 227
#   wave 1: 234, 226, 206, 194, 209, 188(plan), 172, 174, 184, 223(plan), 177, 227  + 213, 200 (critical)
#   wave 2: 173 (after 172)                                                        + 212 (after 194, 213)

# Batch B: contracts and concurrency. Serial where it touches cycle-plan/postflight.
/orchestrate 221, 217, 215, 136, 139, 210, 51, 162, 163, 193, 140, 165, 190, 199

# Batch C: the rest, whenever there is room.
/orchestrate 228, 182, 170, 127, 89, 44, 185, 129, 224, 166, 167, 22, 43, 39, 207, 208, 45, 202, 29, 30
```

Before Batch A: `/todo` to archive the 21 terminal entries (19 abandoned this pass, 183, 222).
Then re-run the dry run once; 197's archive-aware lookup has held under every archival so far,
but standing rule 3 applies.

### Decisions

13. **The manifest: applied in full**, by the user's instruction on 2026-09-17. Nine merges, seven
    abandonments, and 74←167. The merges are recoverable by `/task --recover` on the absorbed
    number; the abandonments are terminal.
14. **74/75/76 after 167.** Applied as the edge 74←167. Land the rule first and reassess the
    mechanism trio when 167 completes.
15. **`/todo` next.** 21 entries await archival; run it before Batch A.
16. **No metatask for the revision work.** It was mechanical and is done; filing a task to do it
    would have added to the backlog it was cutting.

---

1. `/orchestrate` is the only lifecycle entry point, driven by flags. **Done** in shape:
   `/research`, `/plan`, `/implement` are deleted (124); hard mode and team mode are folded into
   the single engine (117-123); phase forcing works in single-task mode (126); team mode is
   deleted (149). One deletion task remains (127 — 125 landed 2026-09-03).
2. The orchestrator is **token-cheap by construction**: it delegates, reads back compact verdicts,
   asks the user only when a decision is genuinely the user's, and otherwise carries almost
   nothing in context. **Not done.** The consolidation moved logic *into* the engine file without
   thinning it, and the engine is now the single largest per-invocation context cost in the
   system. Everything in Stage A below is about this.

---

## Core-essential path (surveyed 2026-09-14)

*Superseded in part by the seventh pass above (2026-09-17): the tiers still describe the defect
classes correctly, but the task numbers, batches and the "0/9" progress line are stale once the
manifest is applied. Where the two disagree, the seventh pass wins.*

Stage A is closed, so the orchestrator is no longer the bottleneck. What's left is a set of
defects where the core system **silently does the wrong thing**: it loses work, reports a phase
complete when it isn't, fails on its own entry command, or ships a fix that never reaches the repos
that use it. This section ranks the 52 open tasks by that test. Everything under Stages B-E below is
now historical context; where they disagree, this section wins.

### What landed since the fifth pass (2026-09-08 → 2026-09-14)

| Task | What it changed for the core |
|---|---|
| 180, 181 | Redeploy checkpoint: consumer walk opt-in (`--consumer-report`); defer messages name the blocking finding; flaky/unattributable findings no longer defer a batch |
| 189 | JSON stdout channel discipline across the orchestrate pipeline, plus `lint-json-channel-discipline.sh` |
| 191, 192 | `git-snapshot.sh` refuses to revert out-of-scope work; `guard-destructive-git.sh` blocks directory/glob `git add` pathspecs |
| **196** | **Research-first is the default again**; planner-first only under `--fast`. Supersedes decision 7 below; `needs_research` plumbing kept |
| 197 | Forced phases on terminal and archived tasks; shared archive-aware `lib/task-lookup-lib.sh` |
| 201 | Canonical runtime-file class in `lib/runtime-file-patterns.sh` |
| 203-205 | Per-project lean-lsp MCP registration (extension) |
| 155-157, 171, 176, 178-179, 186 | Extension or doc fixes |

All 22 were archived by `/todo` on 2026-09-14 (`5817a9cc1`); 52 tasks remain active.

**Measured this pass**: `skill-orchestrate/SKILL.md` 16,025 B (≤ 20,000 B ceiling holds; +566 B
since 2026-09-08), `commands/orchestrate.md` 17,755 B, eager load 65,198 B (~16.3k tokens,
+2,213 B), `commands/task.md` 40,726 B (44 recorded 37,465 B).

### Verified by execution this pass

- **Three core suites are red on `master`.**
  - `test-postflight-deploy-gate.sh`: 7 FAIL. The fixture's `REQUIRED_LIBS` omits
    `task-lookup-lib.sh`, which `task-lock.sh:197` now sources unconditionally. This is **206**.
  - `test-lint-json-channel-discipline.sh`: 2 FAIL. Real-corpus violation at
    `orchestrate-triage-classify.sh:225`, added by 197 phase 9's argv-length fix (`3d100ff42`).
    **Unfiled.**
  - `test-gate-out-repair-reporting.sh`: 4 FAIL (Cases 3, 4, 6). This fixture copies `lib/*.sh`
    whole, so it isn't 206's cause. **Undiagnosed, unfiled.**
  - For contrast, the eight orchestrate suites that source the new lib directly all pass
    (cycle-plan, cycle-postflight, triage-classify, churn, phase-heartbeat, loop-guard-budget,
    context-growth, predispatch-review).
- **A missing research report is not caught.** In `orchestrate-cycle-postflight.sh`'s verdict
  ladder (~line 857), a recovered `.return-meta.json` reporting `researched` maps straight to
  `verdict=ok`, and nothing checks that the report file exists. A dispatch that writes neither file
  gets `failed`, but any findings it sent by message are thrown away. This is **212**'s part (a),
  answered.
- **The handoff-writer allowlist is unchanged.** `is_contractual_handoff_writer()`
  (`orchestrate-cycle-postflight.sh:421-424`) names only `cslib-implementation-hard-agent` and
  `lean-implementation-hard-agent`. When any base-mode agent's handoff is missing, no defect is
  recorded. This is **195**, still live.
- **188 is still live.** `orchestrate-predispatch-review.sh` contains no archive lookup, even though
  197 shipped the shared archive-aware library it could call.

### Tier 1: the core misreports or fails on its own entry path (do first)

| Rank | Task | Why it's essential | Eligible | Collides with |
|---|---|---|---|---|
| 1 | **213 → 214** pass focus text through; forced phases stop as documented | Both observed live in Verification on 2026-09-14. (213) The text after `--research` never reaches the dispatch file: `SKILL.md` Move 1 doesn't pass it on, and `orchestrate-cycle-plan.sh` has no `--focus` option. (214) After a forced phase the task falls through to status routing, and passing the flag again doesn't refill the queue. So any live re-check moves a RESEARCHED task to PLANNING, writes a dispatch file, takes the lock and counts a cycle. The state change is silent. Small fixes, and they gate eight tasks | 213 yes; 214 after 213 | `orchestrate-cycle-plan.sh` + `SKILL.md`: 14, 162, 182, 183, 193, 195, 199, 212 (all now depend on 213 and 214, decision 12); 182 also `test-orchestrate-cycle-plan.sh`; 170 (`scripts/tests/`, via 215) |
| 1b | **216** reset the cycle bound on each run; admit forced phases by artifact | Asked for by the user after 213-215. The saved per-task `cycle_count` (the "Defect B" decision) adds up across runs, so repeated `--research`/`--plan` runs use up the 5-cycle budget and later runs are refused. 216 makes the bound last one run and removes `--continue-budget`. It also sets one admission rule: `--research`/`--plan` at any status, with `--plan` using `reviser-agent` when a plan already exists (no `--revise` flag; `/revise N` is unchanged), and `--implement` whenever `plans/*.md` exists | after 214 | Same forced-phase code as 214 (`orchestrate-cycle-plan.sh` section (f), `SKILL.md`, `commands/orchestrate.md`); 215 (`orchestrate-loop-guard-init.sh`, `orchestrate-state-machine.md`; edge 215←216 applied); supersedes 183 |
| 2 | **212** gate research dispatch on a missing report | Records a research phase complete with no report (verified above) and loses message-borne findings. Every task's first dispatch is research by default since 196, so this sits on the hottest path in the system | after 194, 213, 214 | 195 (`orchestrate-cycle-postflight.sh`, now in 212's `file_scope`; edge 195←212 applied); 194 (`general-research-agent.md`; edge 212←194 applied); 213/214 (`skill-orchestrate/`) |
| 3 | **200** consumer deploy propagation | A completed fix stays broken in consumer repos indefinitely; observed live with 176's lean fix. Without this, every other row in this table is "done" only in this repo. **213 and 214 need it too**: Verification only gets them after a redeploy | yes | 76 (`skill-base.sh`, a critical path) |
| 4 | **194 → 195** handoff contract, then writer predicate | Base-mode failures are excused at postflight and go unattributed (verified above). 195 also waits on 162 | 194 yes; 195 after 194 + 162 + 212 + 213 + 214 | 212, 198, 139 (agent files) |
| 5 | **209** init consumer `specs/` + `specs/.gitignore` | `/task` fails at its first command in any fresh repo, and every scoped commit there picks up lock and session files (observed 2026-09-14, twice). Its description was extended the same day: Verification tracks `.lock/holder.json`, `.dispatch/`, `.orchestrator-loop-guard`, `.events.lock` and the multi-state files, and ignore rules don't untrack files git already tracks. So 209 now also runs `git rm --cached` and fails the tracking check while any remain tracked | yes | 210, 211, 44 (`commands/task.md`); 51 (edges applied) |
| 6 | **210** topic assignment order in `/task` create | Create mode as written always exits 4 at step 4.5 and leaves `active_topics` empty; the zero-topic picker isn't a valid `AskUserQuestion` input | after 209 | 209, 211 |
| 7 | **206** + the two unfiled red suites | A red gate teaches people to ignore gates. Cheap. `file_scope` now names all three suites | yes | 170 (`core/scripts/tests/`; edge applied) |

### Tier 2: wide batches are safe (the default mode runs many tasks at once)

Three live incidents on 2026-09-08 and 09-09 share one root cause: concurrent dispatches write to
shared state, and admission can't see the collision. They were (a) two sessions editing
`orchestrate-cycle-plan.sh` at once (190), (b) a default-mode snapshot stashing a sibling
dispatch's work (198, 199), and (c) a pair dispatched with no collision check because neither task
declared a `file_scope` (165). 191 and 192 closed two of the mechanisms. The rest is one chain:

```
162 (harvest file_scope from plans) ─┬─> 164 (backfill) ─┐
                                     └─> 195             ├─> 165 (admission posture for absent scope) ─┬─> 190 (cross-session admission)
188 (Class A archived false positive) ──> 163 (surface absent scope) ─┘                                └─> 193 (territory in base-mode briefs) ─┬─> 199 (isolation posture)
                                                                                                                                                └─> 182 (redeploy ledger) ─> 183
194 (handoff contract, all agent files) ─┬─> 139 (forbid concurrent history rewrites) ─┬─> 140 (hook predicate)
                                        │                                             └─> 14  (no fan-out; marker/commit sync)
                                        ├─> 198 (lean agents: --no-revert snapshot)
                                        └─> 212 ─> 195
```

The diagram above predates two 2026-09-14 edge updates. **193 no longer depends on 165.** And
**162, 193, 195, 199 and 182 → 183, plus 14, now also wait on 213 → 214** (Tier 1 rank 1), because
they edit `orchestrate-cycle-plan.sh` or `SKILL.md`. So 188 is the only chain head still eligible
right now. 162 and 193 become eligible once 214 lands.

**Edge loosened (applied 2026-09-14)**: 193←165 was removed. Putting territory into base-mode
briefs only needs whatever `file_scope` already exists; it doesn't need the absent-scope ruling.

### Tier 3: correct but costly, noisy, or misrouting

| Task | Why not higher |
|---|---|
| **211** task-type keyword false positives | Misroutes to the wrong agent (meta/lean4) but the user sees the type at creation. Serialize after 209/210 (`commands/task.md`) |
| **51** runtime files out of `specs/` root + reaper coverage | Clutter and unreaped files, not wrong behaviour; must re-check 209's generated `specs/.gitignore` whichever lands second |
| **172 → 173/174/175** bounded build waiters | 22 leaked poll loops in one lean batch; the core pattern gap is real but the trigger is lean builds |
| **170** isolate shell suites from host state | Flaky gates under load; eligible (151, 169 done) |
| **127** collapse routing ladder | Dead manifest keys; its item (6), which lints routing entries that name a nonexistent agent, is the part with correctness value |
| **136** plan Status-line ownership, **166** section-heading conformance | Validator noise; recoverable |
| **182** redeploy ledger (183 abandoned 2026-09-14, superseded by 216) | Cost, not correctness, now that 180/181 removed the batch-deferring behaviour; gated behind 193 in Tier 2 |
| **89, 44** context budgets | Per-invocation tokens only |
| **215** undo a set-up-but-unrun dispatch (`orchestrate-unwind-dispatch.sh`) | Recovery tooling, not a correctness fix. Once 214 lands, the stray transition that needed it should stop happening. Today a manual undo means editing four artifacts by hand, and it still misses `last_updated`/`session_id`, because `guard-destructive-git.sh` blocks a git undo (correctly). Runs after 214. 140 now waits on it (both edit `git-safety.md`), and so does 170 (`scripts/tests/`) |

### Not on the core path

Extension, editor, or doc work. Some items are live defects inside their own extension and matter
there: **43** (email safety context never loads) and **207** (a Zotero export silently truncates and
overwrites a complete export) deserve priority within their extensions.

22 (.opencode spam), 29 → 30 (MCP from manifests), 39, 43, 45, 202 (picker UI), 74 → 75/76,
167 (latex watcher), 168, 177, 184, 185, 187, 129, 207 → 208.

### Edges and scopes applied to `state.json` (2026-09-14)

These went through `state-write.sh --regen-todo`. The result was diffed against a dry run and
matched. `validate-state.sh` reports 0 failures.

| Change | Tasks | Why |
|---|---|---|
| Dependency added | 212←194, 198←194, 139←194 | Same agent files. 194's former glob scope was invisible to the overlap predicate, which admitted 194 alongside all three |
| | 195←212 | Both edit `orchestrate-cycle-postflight.sh` |
| | 210←209, 211←210, 44←211 | All edit `commands/task.md`; fix behaviour before slimming |
| | 51←209 | Same runtime-file list and standards doc |
| | 170←206 | Both edit `core/scripts/tests/` |
| | 136←166 | Both edit `validate-artifact.sh` |
| Dependency removed | 193←165 | See Tier 2 |
| `file_scope` added | 212: `orchestrate-cycle-postflight.sh` · 188: `orchestrate-predispatch-review.sh` · 206: the three red suites, plus `lint-json-channel-discipline.sh` (added later the same day) · 183: `orchestrate-cycle-plan.sh` | These tasks declared no scope, or an incomplete one, so admission couldn't see them |
| `file_scope` replaced | 194: `agent-system/extensions/*/agents/**` → the 19 concrete `extensions/<ext>/agents/` directories | A glob matches nothing in the prefix-overlap predicate. `validate-state.sh` now WARNs that 194's scope is coarse (it overlaps 14, 76, 136, 139, 166, 175, 198, 212). That's accurate and intended: 194 audits every agent |
| Created (addendum) | 213 (deps none), 214←213, 215←214; topic `core-agent-system` | See the sixth-pass addendum and Tier 1 rank 1 |
| Dependency added (addendum) | 14, 162, 182, 183, 193, 195, 199, 212 ← 213, 214 | Each edits `orchestrate-cycle-plan.sh` and/or `SKILL.md`; the new fixes go first (decision 12) |
| | 140←215 | Both edit `context/standards/git-safety.md` |
| | 170←215 | 170's `core/scripts/tests/` covers the tests added by 213, 214 and 215 (215 depends on 214, and 214 on 213) |
| Description extended (addendum) | 209: untrack runtime files git already tracks (`git rm --cached`) and fail the tracking check while any remain | Found in the Verification repo |
| Created (second addendum) | 216←214; topic `core-agent-system` | Cycle bound resets on each run; forced phases admitted by artifact; `--plan` revises when a plan exists; `--continue-budget` removed. See Tier 1 rank 1b |
| Dependency added (second addendum) | 215←216 | 215 no longer rolls back a saved cycle count (description amended); both edit `orchestrate-loop-guard-init.sh` and `orchestrate-state-machine.md` |
| Description amended (second addendum) | 214: forced-round state is scoped to one run's multi-state file, so a new run with a new forcing flag starts clean | Keeps 214 consistent with 216 |
| Abandoned (second addendum) | 183, superseded by 216 | Without a counter carried between runs, a stale loop guard is never trusted for budgeting, so the staleness detector has nothing to protect. 216 records this in `orchestrator-runtime-files.md` |

### Recommended batches (supersede Batch 3)

Two admission rules shape what actually runs in parallel:

1. **Critical-path tasks run one per cycle.** A task whose `file_scope` names an orchestrator-critical
   path (`context/reference/orchestrator-critical-paths.json`) takes the single designated slot.
   Those paths include `SKILL.md`, `skill-base.sh`, `task-lock.sh`, `orchestrate-batch-admit.sh` and
   the cycle scripts.
2. **The lowest task number wins that slot, not the highest priority.** Keep 14, 51 and 170 out of
   any batch whose critical members should go first.

Waves below are dependency waves. Each task still takes several cycles, one per phase
(research → plan → implement).

```
# Batch A: Tier 1 + chain heads (15 tasks). Critical-path members: 200, 212, 213, 214.
/orchestrate 213, 214, 216, 215, 194, 206, 209, 188, 139, 200, 212, 210, 198, 163, 140, 211
#   wave 1: 194, 206, 209, 188            + 200, 213 (critical)   <- confirmed by orchestrate-cycle-plan.sh --dry-run
#   wave 2: 210, 198, 139, 163            + 214 (critical)
#   wave 3: 211                           + 216, 212 (critical; 216 after 214; 212 after 194, 213, 214)
#   wave 4: 215 (after 216)
#   wave 5: 140 (after 139 and 215)

# Batch B: file_scope chain + handoff predicate (7 tasks). Nearly all critical-path, so effectively serial.
# Needs 213 and 214 (Batch A) done first: 162, 193, 195 and 199 all wait on them.
/orchestrate 162, 164, 193, 195, 165, 190, 199
#   order: 162 -> 193 (+164 alongside) -> 195 -> 165 -> 190 -> 199

# Batch C: Tier 3 cleanup (14 tasks). Parallel: 166, 172, 127, 89, then 173/174/175, 136, 44.
/orchestrate 166, 172, 127, 89, 173, 174, 175, 136, 44, 14, 51, 170, 182
#   critical-path, serial: 14 -> 51 -> 170 -> 182   (183 abandoned, superseded by 216)
```

**Dry-run evidence (2026-09-14)**: `orchestrate-cycle-plan.sh --dry-run` on Batch A's twelve
numbers dispatched exactly 194, 206, 209, 188 and 200, with nothing deferred or blocked. 139 was
correctly withheld pending 194. Batches B and C were not dry-run; their dependencies aren't
satisfied yet, so a dry run would show only their heads.

**Re-run after the addendum (2026-09-14)**: the same dry run on the 15-number Batch A dispatched
194, 206, 209 and 200 to research, 188 to plan, and **213 to research**, with nothing deferred or
blocked. 214, 215 and 212 were correctly withheld behind their new edges. `state.json`'s checksum
and `git status` of `specs/` were identical before and after, so `--dry-run` wrote nothing. That is
the read-only re-check 214 will require. In the same research cycle it admitted both 200 and 213,
though both declare critical paths. So the one-per-cycle rule (admission rule 1 above) evidently
binds at a phase that edits files, not at research. Expect 200 and 213 to split into separate cycles
at plan or implement.

Keep 76 out of any batch containing 200 (both edit `skill-base.sh`). Off-path tasks (see "Not on the
core path") can ride along with any batch that has room.

~~Before Batch A: run `/todo` to archive the 22 completed tasks.~~ **Done 2026-09-14.** The dry run
was repeated after archival and again after 206's scope edit. Both times it dispatched the same five
tasks (194, 206, 209 and 200 to research, 188 to plan), with nothing deferred or blocked, so 197's
archive-aware lookup held under a real archival. Batch A is clear to run.

---

## Where things stand (measured 2026-09-02, baseline before Stage A)

| Surface | Size | Loaded when |
|---|---|---|
| `skills/skill-orchestrate/SKILL.md` | **293,977 B (~74k tokens)** | every `/orchestrate` |
| `commands/orchestrate.md` | 46,874 B (~12k tokens) | every `/orchestrate` |
| CLAUDE.md chain + eager rules (`measure-eager-context.sh`) | 63,973 B (~16k tokens) | every session |
| **Total before the first dispatch** | **~405 KB, ~100k tokens** | |

The engine file had **grown 56%** (188 KB → 294 KB) since task 88 was filed against it, because
117-123 merged the hard-mode residue and the team fan-out into it. Task 88's "~83.5k baseline" is
stale; the honest figure at that point was ~100k.

**Re-measured 2026-09-03, after A.0-A.3 landed (125, 149, 145, 146, 147):**

| Surface | 2026-09-02 | 2026-09-03 | Change | Target |
|---|---|---|---|---|
| `skills/skill-orchestrate/SKILL.md` | 293,977 B | **225,553 B (~56k tokens)** | -68,424 B (-23%) | ≤ 20,000 B |
| `commands/orchestrate.md` | 46,874 B | **19,104 B (~4.8k tokens)** | -27,770 B (-59%) | ≤ 8,000 B |
| CLAUDE.md chain + eager rules | 63,973 B | 62,985 B (~15.7k tokens) | -988 B (noise; untouched by Stage A) | ≤ 25k tokens total |
| **Total before the first dispatch** | ~405 KB, ~100k tokens | **~308 KB, ~77k tokens** | **-97 KB, -23k tokens** | ≤ 25k tokens |

Both files are well past the halfway mark toward their per-file ceilings but still far above
them: 143, 148, and 88 (which deletes the entire single-task engine, ~183 KB of the remaining
225,553 B) carry the rest of the reduction. `measure-eager-context.sh --check` confirms no
volatile-file hits; `verify-deploy.sh` was not re-run this pass (see Validation to run below).

**Inside the engine** (section split verified fence-safe; zero headings inside code fences):

| Region | Bytes | Runs when |
|---|---|---|
| Single-task Stages 1-8 (`## Execution Flow`) | **~183,000** | only when exactly one task number is given |
| of which Stage 4 state handlers | 52,282 | |
| of which Stage 5 handoff reading | 25,439 | |
| of which Stage 2 loop guard init | 21,436 | |
| of which Stage 3.6 / 3.6a team fan-out | 19,414 | only under `--team` |
| of which Stage 5b churn / three-strikes | 4,918 | only under `--hard` |
| Multi-task Stages MT-1..MT-5 (`## Multi-Task Mode`) | **~111,000** | only when 2+ task numbers are given |
| `## MUST NOT` sections | ~10,000 | always |

Both engines load on every invocation; Stage 0 line 35 then skips one of them. The
mode-gating convention from 87 (`<!-- branch-gated:begin -->`) exists and is used by **zero**
files other than its own doc.

**Per-cycle cost is not the ~450 tokens the Context Flatness section claims.** The lead itself
authors every dispatch prompt, interpolating the full task description (open-task average
**4,612 B, max 11,598 B**) plus memory context, literature briefing, hard-contract block, and
handoff path, three near-identical recipes at `SKILL.md:3769-3808`. A five-task wave therefore
costs the lead **25-60 KB of self-authored prompt text per cycle**, all retained, before a single
verdict or handoff is read. This, not the handoff reads, is why a 5-task batch was observed to
exhaust most of its context before the second dispatch (142's filing).

**The two engines have drifted apart.** Multi-task mode lacks the handoff staleness and
`dispatch_seq` identity gates (143, a live correctness defect), lacks phase forcing and the
artifact-round advance (138), and lacks team fan-out. Single-task mode has all of them. Every
feature added to one path is a parity bug in the other until someone notices.

**Three smaller facts worth recording:**

- `commands/orchestrate.md` carries a 28,393 B `### MULTI-TASK DISPATCH` section that its own
  text labels "illustrative of the contract, not code this file itself runs". It costs ~7k tokens
  per invocation and executes never.
- `--hard` is parsed and stripped by `parse-command-args.sh:119,179` and consumed by the engine
  (63 `hard_mode` references), but is **absent from the Options table** in `orchestrate.md`. It
  is undocumented, not gone.
- The engine's lazy references point at ~520 KB of context/docs (`task-lock.md` 88 KB,
  `batch-orchestration-guardrails.md` 79 KB, `batch-admit-schema.md` 54 KB,
  `handoff-schema.md` 51 KB). Any cycle that follows one pulls it in whole.

Deploy state: `.claude/` is byte-identical to the source store for both orchestrator files.
`check-deploy-freshness.sh` reports clean. The 240 MB literature virtualenv is still untracked in
the source store and still shows in `git status` (unchanged from the prior survey; still unfiled).

---

## Target design: the thin lead

The design principle, stated once so every task below can cite it: **the lead never reads,
authors, or reasons about anything a script or a dispatched agent could own.** Its whole job per
cycle is four moves, and its context grows by the size of three small JSON objects per task.

### One engine, batch of one

Single-task mode is deleted. `/orchestrate 42` is a batch whose wave table has one row. Every
capability that exists only in the single-task engine today becomes a per-dispatch option in the
one engine:

| Capability | Lives today | Lives after |
|---|---|---|
| Phase forcing (`--research/--plan/--implement`) | single-task Stage 2b | cycle-plan script consumes `force_phases` per task |
| Team fan-out (`--team`) | single-task Stage 3.6/3.6a | **deleted** (149): ~5x cost, rarely used, an unfixed ownership defect; not worth a script |
| Hard-mode contract injection | Stage 3.5 (script-side already) | dispatch builder, unchanged |
| Hard-mode churn / burnout counters | single-task Stage 2 + 5b | **kept**: `orchestrate-churn.sh`, called from the postflight script when `hard_mode` |
| Loop guard / cycle budget | single-task Stage 2 + 7, MT-3 | cycle-plan script; one counter, one file |
| Handoff staleness + `dispatch_seq` gates | single-task Stage 5 only | postflight script, both paths, by construction (143) |
| Research phase | always first | **on demand** (150): the planner is dispatched first and asks for research only when the plan would otherwise rest on guesses; `--research` forces it |
| `--dry-run` | a separate 677-line report that re-renders the verdict and drifts | `orchestrate-cycle-plan.sh --dry-run`: the same JSON the live path dispatches, one rendering |

This is the single largest lever available, larger than 88's mode-gating ever was, and it
retires the parity-drift defect class outright rather than fixing instances of it.

### The four moves per cycle

```
1. plan     = $(orchestrate-cycle-plan.sh --session $sid --flags ...)      # one JSON object
2. for each row in plan.dispatch: Agent(subagent_type=row.agent, model=row.model,
                                        prompt="Read {row.dispatch_file} and execute it.")
   -- all rows in ONE message --
3. for each dispatched task: result=$(orchestrate-cycle-postflight.sh $task $sid)  # one JSON line
4. continue; or, only if some result.verdict == ask_user, relay that agent's question once
   (batched at cycle end); or stop when plan.stop is set
```

| Script | Absorbs (from the engine's inline prose/bash today) | Returns |
|---|---|---|
| `orchestrate-cycle-plan.sh` (**147**) | status refresh, heartbeat, all-terminal check, eligibility, admission (`batch-admit`), classification (`triage-classify`), lock acquire, `dispatch_seq` mint + window stamp, preflight status write, cycle/budget counters, redeploy-checkpoint decision, `force_phases` per task, missing task-dir creation | `{cycle, dispatch:[{task, phase, agent, model, dispatch_file, team}], deferred:[{task, reason}], blocked:[..], stop: null\|{reason, message}}` |
| `orchestrate-build-dispatch.sh N phase` (**146**) | Stage 3.5 in full (memory retrieval, `--lit` briefing, hard-contract block, effort note, model), territory, artifact round, continuation pointer, handoff path, the user-decision contract text; writes `specs/NNN_slug/.dispatch/{seq}.md` | `{dispatch_file, model}` |
| `orchestrate-cycle-postflight.sh N` (**143**, revised) | handoff read with mtime + `dispatch_seq` gates, return-meta recovery (now seq-checked), phase-count corroboration, writer-contract-aware defect recording, `user_decision` relay, status transition with monotonic clamp, artifact link, artifact-round advance, `modified_files` vs `file_scope` excursion advisory, scoped commit, MT-state update, lock release | `{task, phase, status, phases_completed, phases_total, verdict: ok\|defer\|blocked\|failed\|ask_user, user_decision?, note}` |

The dispatched agent reads its dispatch file. The lead never sees a task description, a memory
block, a briefing, or a contract again. The three scripts already have precedents in the repo
(`orchestrate-stage5-gates.sh`, `orchestrate-stage5-postflight.sh`, `orchestrate-triage-classify.sh`);
this is the same shape applied to the whole loop.

### Where the user is asked (decided 2026-09-02)

**The orchestrator never asks on its own, and never decides.** A run proceeds to the end
uninterrupted by default. The engine's own decision points — self-modifying or colliding
candidates, budget exhaustion, blockers, deploy-pending completions — stay exactly as autonomous
as today (defer in sequence, stop with an honest message, escalate through the existing blocker
dispatch), and the opt-in flags (`--allow-self-modifying`, `--allow-scope-collision`,
`--continue-budget`) remain the way to pre-answer them. There is no `--no-ask` flag because
there is nothing to switch off.

Decisions belong to the dispatched agents. A research, planner, or implementation agent decides
on its own and records the decision with its reasoning in its artifact. Only when a choice
genuinely requires the user's judgment — a preference the artifacts cannot infer, an external
cost or risk the user must accept, an ambiguity research cannot resolve — does it set
`user_decision: {question, options, recommended, blocking}` in its return metadata. Agents are
told to look for such choices and to avoid raising them unless actually needed. The postflight
script relays the field as a verdict; the lead's only role is to put the question to the user
once, batched at the end of the cycle after every other task has progressed, write the answer to
`specs/NNN_slug/.decisions.json`, and carry it into the next dispatch file. A non-blocking
decision proceeds on the agent's recommendation and is surfaced for review in the consolidated
output. The contract is written once (146) and referenced from every agent, never restated.

### Budgets (become gates, not aspirations)

| File | Today | Target | Gate |
|---|---|---|---|
| `skills/skill-orchestrate/SKILL.md` | 293,977 B | **≤ 20,000 B** | per-file ceiling in verify-deploy (142) |
| `commands/orchestrate.md` | 46,874 B | ≤ 8,000 B | same |
| Lead context growth per task per cycle | 5-12 KB authored + reads | ≤ ~1 KB (three JSON objects) | measured on a 5-task batch, recorded in 142's summary |
| Eager load before first dispatch | ~100k tokens | **≤ 25k tokens** | 142 |

Narrative, rationale, incident history, and exception taxonomies move to
`docs/architecture/orchestrate-state-machine.md` and the existing schema docs, which the lead is
forbidden to read during the loop. The `## MUST NOT` sections shrink to a list; their 9 KB of
branch enumeration is architecture documentation, not runtime instruction.

### A note on the harness Workflow tool

Claude Code now ships a `Workflow` tool: a deterministic JavaScript script that fans `agent()`
calls out in the background with structured-output schemas, consuming zero lead context per step.
That is, structurally, the thin lead. Two reasons it is not the recommendation here: the script
cannot run shell (admission, locks, commits, status writes would all have to move into agents),
and its availability in the consuming repos' harness versions is unverified. **Decided**: one
bounded spike **after** Stage A lands, when the three cycle scripts exist and a workflow could
simply call agents that call them. Stage E; file it when 88 completes, not before.

---

## Stage A — Thin lead (critical path)

Ordered. Each task touches an orchestrator-critical path and therefore takes the
designated-candidate slot: they serialize one per cycle whether batched or not. The
`dependencies[]` chain below makes one `/orchestrate` invocation carry the whole stage.

| # | Task | State | What lands | Saving |
|---|---|---|---|---|
| A.0 | **125** delete base lifecycle skills | **completed 2026-09-03** | Pure deletion; its plan's Phase 7 also swept `orchestrate.md`, so it preceded A.1 | dead surface |
| A.0b | **149** delete team mode | **completed 2026-09-03** | Stages 3.6/3.6a, the `--team`/`--team-size` flags and parser exports, `synthesis-agent` if it has no other caller, the CLAUDE.md merge-source text, the team artifact convention, and the team tests. Preceded 145 so the command file was slimmed against the final flag set | ~19 KB out of the engine; retires 72's Part A |
| A.1 | **145** slim `commands/orchestrate.md` | **completed 2026-09-03** | Deleted the illustrative `### MULTI-TASK DISPATCH` block and the consolidated-output template; kept Arguments, Options (added the undocumented `--hard`), STAGE 0 parse + dispatch, checkpoints. 46,874 B → 19,104 B (target ≤ 8 KB not yet reached) | ~7k tokens/invocation, zero risk |
| A.2 | **146** `orchestrate-build-dispatch.sh` + pointer prompts + user-decision contract | **completed 2026-09-03** | Stage 3.5 became a script writing `.dispatch/{seq}.md`; all eight dispatch sites send a fixed pointer prompt; agent contracts gained "read your dispatch file first" and the `user_decision` contract; threads the artifact round | the per-cycle authored-prompt cost, on both engines |
| A.3 | **147** `orchestrate-cycle-plan.sh` | **completed 2026-09-03** | MT-3 steps 1-4.5 and MT-4's per-task preflight/mint collapsed into one script returning the dispatch plan; consumes `force_phases` per task; creates missing task dirs; gained `--dry-run` and retired `orchestrate-dry-run-report.sh` (absorbed 141's verification bar). SKILL.md's MT-3/MT-4 pre-dispatch region: 271,733 B → 225,553 B (-46,180 B) | MT-3 (35 KB) + half of MT-4 left the engine; one fewer critical-path script |
| A.4 | **143** `orchestrate-cycle-postflight.sh` | **completed 2026-09-07** | 143's two gates are the seed; the script also absorbs recovery (now seq-checked), corroboration, writer-contract-aware recording, `user_decision` relay, status clamp, artifact link + round advance, excursion advisory, scoped commit, MT-state update, lock release | remainder of MT-4 + MT-5 (56 KB) left the engine; 53, 138, 100 closed |
| A.5 | **148** port single-task-only features into the one engine | **completed 2026-09-07** | Hard-mode counters into `orchestrate-churn.sh` (kept in full by decision); one loop-guard counter; drift/blocker dispatches as next-cycle rows; a single task number routed through the batch path behind a flag. Team item withdrawn | prerequisite for A.6, landed |
| A.6 | **88** delete the single-task engine; rewrite `SKILL.md` as the four-move loop | **completed 2026-09-08 (this pass)** | Stages 0-8 deleted (189,000 B → 59,439 B); MT-1..5 rewritten as the four-move loop (Move 1-4, 15,459 B final); narration moved to `docs/architecture/orchestrate-state-machine.md` and `handoff-schema.md`; both `## MUST NOT` sections combined to 1,369 B; the batched `AskUserQuestion` -> `.decisions.json` -> next-dispatch-file relay built end to end; every coupled test/lint retargeted or retired with recorded deviations. The original mode-gating premise (single-task is the hot path) is inverted by the default use and was dropped | **~70k tokens/invocation** |
| A.7 | **142** orchestrator context budget: measure and lock | **completed 2026-09-08** | Baseline captured (numbers above), re-measured after each landing; per-file ceilings for the two orchestrator files and an eager-load ceiling wired into verify-deploy (absorbs 42); a 3-task batch's per-cycle growth measured and recorded | prevents regrowth |
| A.8 | **150** research on demand | **completed 2026-09-08** | Planner dispatched first on a fresh task; it plans if the description and codebase suffice, else returns `needs_research` with a question list that becomes the research focus; `--research` forces research first. Built once, in the thin engine, exactly as filed. Vocabulary admitted at every upstream gate (`orchestrate-recover-outcome.sh`, `validate-return-meta.sh`, `validate-handoff.sh`), not only at the consumer switch; `state-schema.json` also needed the new `research_questions` property (recorded deviation — its `additionalProperties: false` enforced it). 191 fixture assertions green across the three retargeted suites | one full dispatch per specification-shaped task, which is most of them |

**Dependency chain, applied in `state.json`**: 149←[125]; 145←[149]; 146←[145]; 147←[146];
143←[147]; 148←[143]; 88←[148]; 142←[88]; 150←[88]. 88's former edges [87, 127] are dropped;
127 no longer gates it. 142 and 150 can run in the same cycle (disjoint scopes).

**Chain progress, 2026-09-08 — STAGE A IS COMPLETE** (supersedes the 2026-09-03 snapshot above,
which is stale): 125 → 149 → 145 → 146 → 147 → 143 → 148 → 88 → 142 → 150 are ALL done, in that
order, exactly as filed. Nothing remains in Stage A.

150's completion was delayed by one cycle, for a reason worth recording: it rewrote
orchestrator-critical paths in the source store, so the postflight deploy gate correctly refused
the `[IMPLEMENTING] → [COMPLETED]` write until `.claude/` was resynced. The implementation was
already committed and green at that point; a `<leader>al` → `[Reload All]` and a re-run cleared it,
and the entry reconcile — not a fresh dispatch — performed the transition. **Expect this for every
self-modifying task: the deploy is part of the task, not an afterthought.**

**Why A.2 before A.3.** The dispatch-file builder is independent of the loop rewrite and lands
the per-cycle saving on the engine *as it exists today*. If Stage A stalls after A.2, multi-task
runs are already materially longer-lived.

**Why not just mode-gate (the 88 approach).** Mode-gating leaves both engines on disk, keeps the
parity-drift class alive, and saves ~26k of the ~100k. Deleting one engine and scripting the
other saves ~70k and removes the class. 87's convention remains useful for `--team`/`--hard`
residue if any prose survives in the thin file, and for 89/44.

---

## Stage B — Correctness and throughput for wide batches (independent, batchable)

These make the default (many tasks at once) safer and wider. None touches `SKILL.md`; all can run
alongside one Stage A member.

| # | Task | Op | Note |
|---|---|---|---|
| B.1 | **141** relay admission verdict in dry-run report | abandoned → 147 | The report is retired; `orchestrate-cycle-plan.sh --dry-run` renders the live verdict once, and 141's verification bar (relay the ORDERING CONSTRAINT text; the stale "runs solo only" strings appear nowhere) is carried into 147 verbatim |
| B.2 | **144** narrow coarse `file_scope` declarations | **completed 2026-09-03** | The three stale `general-implementation-hard-agent.md` scopes (76, 136, 139) were removed at the state level; 144 verified none remain and recorded the "scope unknown before research" convention. 88's `context/patterns/` entry was replaced with its rewrite; 44's `core/context/` root is the widest coarse declaration left |
| B.3 | **139 → 140** forbid concurrent-writer history rewrites; hook predicate | keep | The motivating incident was a five-agent batch. Directly proportional to batch width |
| B.4 | **14** implementation agents: no fan-out, terminal status, marker/commit sync | keep | Agent-contract side only. Serialize after 139 (both edit `general-implementation-agent.md`) and not alongside 146 (same file; 146 is now done, so this constraint is moot going forward) |
| B.5 | **20** `/todo` phantom build_errors + `MAX_ARG_STRLEN` archive failure | **completed 2026-09-03** | The second defect is data-loss class; this run's own archival (55 tasks in one call) exercised the `MAX_ARG_STRLEN` path directly (`state-write.sh --argjson` failed at 55 tasks' worth of JSON, worked via `--argjson-file`) — live confirmation the fix's scope was real |
| B.6 | **51** runtime files out of `specs/` root; wire reap into `/todo` | keep | Coordinate with 143, which now owns the multi-state file's writer (147 is done); land after 143 or declare the new path there |
| B.7 | **91 → 136** plan Status-line diagnosis; producer-side ownership boundary | keep | Independent of the engine |
| B.8 | **72** subagent-postflight marker correlation | **completed 2026-09-03** | The `head -1` arbitrary-marker pick in `hooks/subagent-postflight.sh` bit concurrent single-task sessions too: a foreign stop could burn another session's continuation budget or delete its marker. Landed independent of Stage A |
| B.9 | **13** gate-out auto-repair reporting | keep | Independent; low |
| B.10 | **129** `\b` grep audit | keep | Independent; low. Depends on 128 (done); eligible |

---

## Stage C — Other context-budget items (independent, low priority)

| Task | Op | Note |
|---|---|---|
| **44** slim `commands/task.md` | keep (planned, eligible: 87 done) | ~6k tokens per `/task`; plan is good; run whenever a batch has room. Its `core/context/` scope is the widest coarse declaration in 144's list; narrow it there first |
| **89** mode-gate `skill-literature` / `skill-distill` | keep | ~25k tokens per `/literature` and `/distill`; mechanical; outside the engine |
| **42** verify-deploy context gates | abandoned → absorbed into 142 | Item (a) is a regression guard for an already-held state; item (b) is exactly 142's lock. One task, not two |

---

## Stage D — Extension and repo work (unrelated to the orchestrator)

Kept as filed; sequenced by whatever batch has room. None are on the path.

| Task | Note |
|---|---|
| **113** briefing SIGPIPE crash | **Completed 2026-09-03.** Hard crash of `--lit` in repo mode |
| **74 → 75 / 76** LaTeX build guard | 76's scope must drop the deleted `-hard` agent file; 76 also touches `skill-base.sh` (critical path) |
| **137** lean agent artifact skeletons | Extension-side; produces validator-clean artifacts |
| **134** `/tag` reachability gate | Small; user-only skill |
| **29 → 30** `.mcp.json` from manifests; obsidian memory server | Deploy-engine Lua work |
| **43** email safety context decision | Extension-internal |
| **39** Zotero metadata resolution | Literature; planned |
| **45** `<leader>al` global update | Neovim Lua UI |
| **27** delete dead `.opencode` router | **Completed 2026-09-03.** |
| **22** `.opencode` freeze: silence spam, record policy | Stranded at `[RESEARCHING]` with no task directory; safe to re-dispatch |

---

## Stage E — Optional, after Stage A

| Item | Note |
|---|---|
| Workflow-tool spike (approved, unfiled until 88 lands) | One bounded task: a `/orchestrate --workflow` path that hands the wave table to a `Workflow` script whose agents call the three cycle scripts. Measure lead context (should be ~zero) and confirm harness availability in each consuming repo before deciding anything |
| Lazy-reference diet | The ~520 KB the engine points at. After A.6 the thin lead cites only the three scripts and the state-machine doc; audit what remains referenced from agent files instead |

---

## Backlog operation manifest (applied 2026-09-02)

| Task | Operation | Reason |
|---|---|---|
| **145** `slim_orchestrate_command` | CREATED; deps [125] | A.1; zero-risk ~10k saving; also documents `--hard` |
| **146** `build_orchestrate_dispatch_builder` | CREATED; deps [145] | A.2; removes the lead's authored-prompt cost on both engines now; carries the user-decision contract |
| **147** `build_orchestrate_cycle_plan` | CREATED; deps [146] | A.3 |
| **143** | REVISED into "Build orchestrate-cycle-postflight.sh"; deps [147] | A.4; its two gates are the seed of the script |
| **148** `port_single_task_features_to_batch_engine` | CREATED; deps [143] | A.5 |
| **88** | REVISED into "Delete the single-task engine and rewrite skill-orchestrate as the four-move loop"; deps [148] (was [87, 127]) | A.6; original premise inverted |
| **142** | REVISED into "Orchestrator context budget: measure and lock" (absorbs 42); deps [88] | A.7 |
| **138** | ABANDONED → 147 (gap 1), 143 (gap 2), 146 (gap 3) | all three gaps close by construction in one engine |
| **53** | ABANDONED → 143 | recording order is a postflight-script concern; its live-predecessor evidence becomes 143's fixtures |
| **100** | ABANDONED → 143 | direction (a) is one comparison in the postflight script; (b)/(c) stay unfiled until (a) quantifies the class |
| **42** | ABANDONED → 142 | item (a) already holds; item (b) is 142 |
| **144** | REVISED (addendum): stale-scope verification and the pre-research convention | B.2 |
| **72** | REVISED (addendum): re-pointed to the fan-out and dispatch-builder scripts; deps [148] (was [122]) | B.8 |
| **76, 136, 139** | `file_scope`: deleted `general-implementation-hard-agent.md` entry removed | admission gate reads them |
| **149** `delete_team_mode` | CREATED (third pass); deps [125]; 145 now depends on it | decision: drop team mode |
| **150** `research_on_demand` | CREATED (third pass); deps [88] | decision: planner-first, research when asked or forced |
| **141** | ABANDONED (third pass) → 147 | the report is retired; one rendering of the verdict |
| **147** | REVISED (addendum): `--dry-run`, retire the report script, 141's bar | |
| **148** | REVISED (addendum): team item withdrawn; hard-mode counters kept in full | |
| **72** | REVISED (third pass): Part A moot, narrowed to marker correlation; deps [] | |
| **145, 88** | REVISED (addenda): team rows gone; dry-run path repointed | |
| 125, 127, 139, 140, 14, 20, 51, 91, 13, 129, 44, 89, and all Stage D | KEPT as filed | |

Net across both passes: 6 created, 8 revised, 5 abandoned into successors; open count 36 → 37.
Every capability named in an abandoned task has a named successor line above, except team
mode's Part A of 72, which is dropped with the feature by decision.

---

## Recommended batches

**Batch 1 — clear the deck.** `/orchestrate 125, 144, 20, 113, 27, 72` — **done, 2026-09-03.**
All six archived. The report's stale "runs solo only" wording is moot now (147 retired the
report entirely; `--dry-run` reads live off `orchestrate-cycle-plan.sh`).

**Batch 2 — Stage A as one chain.** `/orchestrate 149, 145, 146, 147, 143, 148, 88, 142, 150` —
**done, 2026-09-08.** All nine landed in the filed order. The total-order-by-design constraint
held throughout: each member touched `SKILL.md` or another critical path, so each took the
designated-candidate slot and serialized one per cycle whether batched or not.

**Batch 3: mostly done, superseded 2026-09-14.** 180, 181 and 189 landed. 182 is now gated
behind 193, and 188 moved into Tier 2's chain head. 44 and 89 were not run. See "Recommended
batches (supersede Batch 3)" under Core-essential path for what to run next. The original text
follows for the record.

**Batch 3 (as proposed 2026-09-08).** Stage A is closed, so the serialization constraint that
shaped Batches 1-2 is gone for everything except the orchestrator-critical cluster below. Two
candidate groupings, in priority order:

```
# 3a. Make /orchestrate cheap and honest to operate (all touch orchestrate-cycle-plan.sh
#     or deploy-headless.sh -- serialize within this group, one per cycle)
/orchestrate 180, 181, 182     # redeploy-checkpoint cost + gate-depth + durable ledger
/orchestrate 189               # stdout/JSON channel, budget-charged-on-read, Class C false negative
/orchestrate 188               # Class A archived-dependency false positive

# 3b. Free-running, batchable alongside any one member of 3a
/orchestrate 44, 89            # Stage C context budgets, both unblocked
```

**Why 3a first.** Every one of these is a defect in the machinery you use to run everything else,
and all were found by execution rather than review — 180/181/182 from a single session that burnt
~10 minutes on a checkpoint and then deferred the whole batch; 188/189 from the session that
closed Stage A. Their cost is paid on every future invocation in every consuming repo until fixed.

**Still standing**: **do not** run 76 alongside anything in 3a (it touches `skill-base.sh`).
**New**: 181/182 and 189 all edit `orchestrate-cycle-plan.sh` in disjoint regions — serialize
them, either direction, rather than batching them together.

**Lifted 2026-09-03**: the "don't run 44 alongside `core/context/`" constraint — 144 narrowed
44's `file_scope` (one of 9 flagged projects it fixed) before archiving. The "don't run 14
alongside 146 or 149" constraint is moot the same way: both are done. **Still standing**: **do
not** run 76 alongside a Stage A member (it touches `skill-base.sh`).

---

## Decisions

**Recorded 2026-09-02:**

1. **Batch of one.** Confirmed. Stage A deletes the single-task engine; team, hard and phase
   forcing survive as per-dispatch options.
2. **The orchestrator never asks and never decides.** Confirmed. Runs proceed to the end
   uninterrupted by default; only an agent-surfaced `user_decision` reaches the user, and agents
   are told to raise one only when the user's judgment is genuinely required.
3. **Workflow spike.** Approved, bounded, after 88 lands.
4. **Manifest applied** to `state.json`; `TODO.md` regenerated.

**Recorded 2026-09-02, third pass:**

5. **Team mode: dropped.** 149 deletes it; 72 narrows to the marker-correlation defect that
   outlives it.
6. **Hard mode: kept in full**, contract injection and the stateful counters both. 148 builds
   `orchestrate-churn.sh` as specified.
7. ~~**Research on demand.** The planner is dispatched first and asks for research only when the
   plan would otherwise rest on guesses; `--research` forces research first. 150.~~ **Superseded
   2026-09-09 by 196**: research-first is the default for a fresh task again; `--fast` restores
   planner-first. 150's `needs_research` return path survives and is still honoured when the
   planner runs first.
8. **Dry-run report: retired.** Rarely used, and two renderings of one verdict is how 141's
   defect arose. `orchestrate-cycle-plan.sh --dry-run` prints the plan it would dispatch. 147.
9. **Consumer validation: no fixed checks.** This file recommends tests to run (next section);
   it does not gate completion on them.

**Recorded 2026-09-14:**

10. **193←165 dropped.** Applied to `state.json`, together with the ten edges and five scope fixes in
    "Edges and scopes applied".
11. **206 widened to all three red suites.** Done. The description already covered all three causes
    (rewritten in `58bf24aab`); the "still the one-line title" note here was stale, and a
    `/revise 206` on 2026-09-14 found nothing to add. The remaining gap was scope: `file_scope`
    now also names `scripts/lint/lint-json-channel-discipline.sh`, since suite (2)'s likely fix is
    the lint predicate. `skill-base.sh` was deliberately not added: suite (3)'s cause is
    undiagnosed, and declaring a critical path on a guess would move 206 into the one-per-cycle
    slot 200 needs. Batch A's dry run is unchanged after the edit.
12. **The `/orchestrate` fixes (213, 214) go before the tasks that edit the same files.** Chosen by
    the user when 213-215 were created. The alternative was to queue them behind 14, 162, 182, 183,
    193, 195, 199 and 212. They are small, observed live, and a live re-check of phase forcing
    corrupts task state until 214 lands. Applied as edges. 215 stays a separate task instead of
    being merged into 214 (also the user's choice), with 140←215 and 170←215 added for its
    overlapping files.

---

## Validation to run (recommended, not gating)

After each Stage A landing, in this repo:

- `bash .claude/scripts/verify-deploy.sh` (the full run, not `--skip-slow`) and
  `bash .claude/scripts/measure-eager-context.sh --check`. Record both numbers against the
  baseline table above; 142 turns them into gates at the end.
- One real two-task batch of low-risk Stage B or D work through the changed engine, for
  example `/orchestrate 13, 129`, and read the consolidated output for anything the lead did
  that a script should have.

**Done, 2026-09-03**: `measure-eager-context.sh --check` re-run — 62,985 B (~15.7k tokens), no
volatile-file hits, essentially flat against baseline (expected; Stage A hasn't touched
CLAUDE.md/rules yet). **Not done this pass**: the full `verify-deploy.sh` run and the real
two-task Stage B/D batch through the changed engine — both still open, and worth doing before or
alongside 143.

After 146 (dispatch files): open one generated `specs/NNN_slug/.dispatch/*.md` and confirm it
carries the description, the artifact round, the plan/report path, and the user-decision
contract, since the agents now see nothing else. **Done, 2026-09-03**: spot-checked
`specs/archive/147_build_orchestrate_cycle_plan/.dispatch/7.md` — carries Identity, Description
(with the addendum), Artifact Round, and a Plan section; confirms the contract holds on a real
dispatch, not just 146's own tests.

After 88 (engine rewrite), before declaring Stage A done:

- `<leader>al` reload in one consuming repo (BimodalLogic or Theory) and
  `bash .claude/scripts/check-consumer-freshness.sh` here to confirm the fleet picked it up.
- One real batch of two or three tasks in that consuming repo. This is the only test that
  exercises extension routing (`lean`, `latex`) through the thin lead; nothing in this repo does.
- A deliberate `user_decision`: give a research or planner agent a task whose description leaves
  a genuine preference open, and confirm the question reaches you once, at cycle end, and the
  answer reaches the next dispatch file.

After 150 (research on demand): run one specification-shaped task and one vague task, and
confirm the first goes planner → implement while the second routes through research with the
planner's questions as its focus.

---

## Observations, unfiled

- **New 2026-09-17**: the runtime wave-split check (`orchestrate-cycle-plan.sh` step 4.5) defers a
  cross-batch `file_scope` collision on every run and records nothing. Persisting that deferral as
  a `dependencies[]` edge is the one idea from the abandoned 231 worth keeping; it belongs after
  165 rules on absent scope, and it is a one-line write through `state-write.sh`, not a task of its
  own yet.
- **New 2026-09-17**: two agent-system defects live in cslib's task list (595, 608). 608's
  evidence is now in 129; 595 is satisfied by `validate-state.sh` Check D3 once cslib redeploys
  (200's class). Both should be abandoned there with a pointer here.
- **New 2026-09-17**: `state-write.sh`'s `--argjson-file` collision (234) means any caller passing
  two of them, or mixing one with `--arg`, has been writing corrupt data silently. This pass used
  `--arg` only, for that reason. 234's caller audit should start with `/task` multi-create and
  `/todo`.
- **New 2026-09-14 (Verification repo, one-off cleanup, not a task)**: after the stray
  `[PLANNING]` transition was undone by hand, that repo still has uncommitted deletions
  (`.commit-lock/`, `004_*/.lock/holder.json`, four files under `006_*/.dispatch/`). It also still
  tracks `.events.lock`, three old `.orchestrator-multi-state-*.json` files and each task's
  `.orchestrator-loop-guard`. Its `specs/state.json` carries a newer `last_updated`/`session_id`
  for task 4 that nobody has committed. To fix: commit the deletions, `git rm --cached` the tracked
  runtime files, then commit `specs/state.json`. 209's extension prevents the tracking half from
  recurring. 214 and 215 cover the rest.

- **New 2026-09-14**: `test-lint-json-channel-discipline.sh` fails on the real corpus at
  `orchestrate-triage-classify.sh:225` (`printf ... > "$archived_projects_tmpfile"` in a script
  whose header declares JSON-on-stdout). It was introduced by `3d100ff42`, and it's probably a lint
  false positive on a redirected write rather than a real channel leak. Either way the suite is red.
- **New 2026-09-14**: `test-gate-out-repair-reporting.sh` Cases 3, 4 and 6 fail (fix counts read 0).
  The last edits to its subjects came from 197 phases 3-4 (`skill-base.sh`). Undiagnosed.
- ~~212's declared `file_scope` omits `orchestrate-cycle-postflight.sh`~~ **Resolved 2026-09-14**:
  added, with edge 195←212.
- **New 2026-09-14**: a glob entry in `file_scope` collides with nothing in practice. Admission
  admitted 194 (`*/agents/**`) alongside 198, 139 and 212, all of which edit agent files. The
  prefix-overlap predicate (`lib/file-scope-overlap.sh`) evidently doesn't expand globs. 194 was the only instance and is
  fixed. Neither task creation nor `validate-state.sh` rejects glob entries, though, so the class
  can recur.
- The 240 MB `literature-pyenv/` virtualenv is **still** untracked and un-ignored (re-checked
  2026-09-14).

- ~~`--hard` undocumented in `orchestrate.md`'s Options table~~ **Resolved by 145, 2026-09-03**:
  `orchestrate.md:46` now documents it in the Options table.
- cslib and lean manifests still declare four `routing_hard`/`routing_agents_hard` keys each. 121
  deliberately left lean's untouched and only pruned cslib's dead pairs; 127 owns the rest.
- The 240 MB `literature-pyenv/` virtualenv remains untracked and un-ignored in the source store
  (carried forward from the prior survey; one `.gitignore` line; still shows in `git status` as
  of 2026-09-03).
- ~~Task 22 sits at `[RESEARCHING]` with no `specs/022_*` directory; the multi-task path has no
  `mkdir -p`~~ **Resolved by 147, 2026-09-03**: `orchestrate-cycle-plan.sh` now creates missing
  task directories. 22 itself is still un-dispatched and should pick this up on its next run.
- The write-time task-reference hook fires on scratch files outside the repo tree (it blocked a
  throwaway script in the session scratchpad for containing "task 147"). Harmless, but its path
  filter could exempt `/tmp/**`.
- **Archived-dependency resolution (found and FIXED 2026-09-03, out of band)**: eligibility
  resolved `dependencies[]` against `active_projects` only, so archival silently made dependent
  tasks permanently un-dispatchable — and dropped them from the plan entirely rather than
  reporting them. Fixed in `orchestrate-cycle-plan.sh` (archive-aware lookup + dangling edges
  reported in `blocked[]`), Group 7 regression tests added. **Worth auditing whether the same
  active-only resolution exists elsewhere** — `orchestrate-batch-admit.sh` and
  `orchestrate-triage-classify.sh` each bind their own `$all` from `active_projects`, and the
  not-yet-built postflight composer (143) will need the same archive awareness. A candidate task
  for whoever picks up 143.
- **New, from 147's Phase 10 Reasoned Exclusions (2026-09-03)**: 4 pre-existing `verify-deploy.sh`
  findings remain open, none introduced by 147 and each outside its `file_scope`:
  `test-force-phases.sh` hand-rolled state writes; `index-entries.json` `line_count` drift on
  `patterns/postflight-control.md` and `schemas/state-schema.json`; one ghost `index-entries.json`
  declaration surfaced by whole-tree orphan detection. (The `abandon_reason`/`blocks_note`
  schema-drift FAILs are the same class as the bullet below and already tracked there.) Each
  traces to a different, already-completed task's commit; worth a task scoped to the owning file
  rather than folding into whichever task next touches `verify-deploy.sh`.
- `validate-state.sh` fails on two fields its own writers produce: `abandon_reason` (every
  abandoned task since 31, including the four abandoned today) and `blocks_note` (106, 107,
  109). Same class as the `blockers` mismatch the prior survey recorded. Either add all three to
  `state-schema.json` or stop writing them; until then the gate-10 result carries no signal.
  Cheap; worth folding into 144 or 20 rather than filing separately.

---

## Standing rules (carried forward)

1. **Agent-system defects get filed here.** A fix in a consuming repo's `.claude/` is wiped on
   reload.
2. **Propose, then apply, across repos.**
3. **Verify by execution, not by reading.** This survey's own corrections: the "~450 tokens per
   cycle" claim was falsified by reading the dispatch recipe; the "83.5k baseline" was stale by
   56%; and 88's premise (single-task is the hot path) is the inverse of how the system is used.
4. **The lead never reads a report, plan, summary, description, or context file during the
   loop.** After Stage A this is a byte budget with a gate, not a MUST-NOT paragraph.

---

## Progress

*As of 2026-09-08, second refresh (Stage A closed by 142 and 150 landing; prior snapshot earlier
the same day read "8/9 done" and is superseded).*

| Stage | Tasks | State |
|---|---|---|
| Consolidation (116 → 117-127, 135) | 117-126, 128, 130-131, 133, 135 ☑ · **127 ☐** | shape done; one deletion left |
| A — thin lead | 125 ☑ → 149 ☑ → 145 ☑ → 146 ☑ → 147 ☑ → 143 ☑ → 148 ☑ → 88 ☑ → 142 ☑ → **150 ☑** | **COMPLETE (10/10)**; single-task engine deleted, `SKILL.md` rewritten as the four-move loop (measured 189,000 B → 15,459 B), context budget locked, research-on-demand live |
| B — wide-batch correctness | 144 ☑, 20 ☑, 72 ☑, 139→140 ☐, 14 ☐, 51 ☐, 91→136 ☐, 13 ☐, 129 ☐ (141 absorbed) | 3/9 done; rest batchable |
| C — other budgets | 44 ☐, 89 ☐ (42 absorbed) | ☐ low; 44 unblocked by 144's narrowing |
| D — extensions/repo | 113 ☑, 27 ☑, 74→75/76 ☐, 137 ☐, 134 ☐, 29→30 ☐, 43 ☐, 39 ☐, 45 ☐, 22 ☐ | 2/10 done; independent |
| E — optional | Workflow spike, lazy-reference diet | after A |

**Critical path now**: there isn't one — Stage A is closed. The single-task engine is deleted
outright, `skill-orchestrate/SKILL.md` is the four-move loop (plan -> dispatch -> postflight ->
branch) at 15,459 B (target was `<= 20,000 B`), the batched `AskUserQuestion` -> `.decisions.json`
-> next-dispatch-file relay is built end to end, the context budget is measured and gated, and the
default lifecycle is planner-first with research on demand. Both halves of the Goal at the top of
this file are now met in shape; the second one ("token-cheap by construction") is met in
measurement too.

**What replaces it**: no remaining task is a *gate* on any other outside the orchestrator-critical
cluster, so sequencing is now a priority question rather than a dependency question. See Batch 3
under "Recommended batches" — the operational-defect group (180, 181, 182, 189, 188) is the
recommended next front, because it is the machinery every other task runs on.

**Re-surveyed 2026-09-14.** The stage rows above are stale for B-D: 13, 91, 134 and 137 have
also completed and been archived. Every open task, including the ones filed after 2026-09-03, is now
placed in a tier under "Core-essential path" near the top of this file.

| Tier | Tasks | State |
|---|---|---|
| 1: core misreports or fails on its entry path | 213 → 214, 212, 200, 194 → 195, 209, 210, 206 | 0/9 done; 213, 200, 194, 209, 206 eligible now; 214 after 213; 212, 195, 210 behind their edges |
| 2: wide batches safe | 162, 188 → 163, 164 → 165 → 190; 193 → 199; 194 → 139 → 140, 14; 194 → 198 | 0/12 done; 188 eligible now; 162, 193 after 214; 139, 198 after 194; 140 also after 215 |
| 3: costly, noisy, misrouting | 211, 51, 172 → 173/174/175, 170, 127, 136, 166, 182 → 183, 89, 44, 215 | 0/15 done; 215 after 214 |
| Off the core path | 22, 29 → 30, 39, 43, 45, 202, 74 → 75/76, 167, 168, 177, 184, 185, 187, 129, 207 → 208 | extension/editor/doc |

**Critical path now**: 213 → 214 → 212 → (194 → 195), with 200 alongside. Those are the defects
that make a correct-looking run wrong. 213 and 214 come first because they gate eight tasks and
corrupt state on a live re-check. Then the Tier 2 chain from 162/188.

**Re-surveyed 2026-09-17 (seventh pass).** Nothing in the tier table above closed; 18 tasks were
filed. Open count 72. The lean-supporting critical path, after the proposed manifest, is
234 + 226 (writers) → 213 (forced phases, absorbing 214/216) → 212 (postflight honesty, absorbing
195), with 200 alongside, then 173 → 221 (build verdict) and 194 → 136/139 (contracts). See
"Seventh pass" near the top of this file for the manifest, the applied edges and the batches.

### Filed 2026-09-03 → 2026-09-08 (superseded by the tiers above; kept for the record)

| Cluster | Tasks | Note |
|---|---|---|
| Redeploy checkpoint | 180, 181, 182 | Measured ~10 min per firing; deferred a whole batch once. Batch 3a |
| Pre-dispatch review correctness | 188, 189 | Class A false positives; Class C false negatives + stdout/budget defects. Batch 3a |
| `file_scope` lifecycle | 162, 163, 164, 165 | Coherent four-task arc, own topic; harvest → surface → backfill → admission posture |
| Build-waiter hygiene | 172, 173, 174, 175 | Bounded-wait idiom, terminal records, reaper pass, contract enforcement |
| Lean extension | 176, 177, 184 | Extension-side, independent |
| Artifact/doc drift | 157, 166, 185, 186, 187 | TODO.md summary lines, report headings, stage→move vocabulary, doc paths, commit attribution |
| Misc | 167, 168, 170, 171, 183 | latex rule, opencode claim, test isolation, literature hang, loop-guard disposition |
