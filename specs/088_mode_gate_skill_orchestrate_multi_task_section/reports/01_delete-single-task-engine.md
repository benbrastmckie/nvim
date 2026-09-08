# Research Report: Task #88

- **Task**: 88 - Delete the single-task engine and rewrite skill-orchestrate as the four-move loop
- **Started**: 2026-09-08T04:12:26Z
- **Completed**: 2026-09-08T04:16:46Z
- **Effort**: ~1 hour (research only)
- **Dependencies**: 148 (satisfied — completed and archived)
- **Sources/Inputs**: codebase (agent-system/extensions/core/skills/skill-orchestrate/SKILL.md, scripts/orchestrate-cycle-plan.sh, scripts/orchestrate-build-dispatch.sh, scripts/orchestrate-cycle-postflight.sh, docs/architecture/orchestrate-state-machine.md, docs/architecture/orchestrate-cycle-postflight.md, docs/architecture/handoff-schema.md, context/standards/user-decision-contract.md, context/reference/orchestrator-critical-paths.json), specs/state.json, specs/CHANGE_LOG.md, specs/PATH.md, scripts/tests/*.sh, scripts/lint/*.sh
- **Artifacts**: this report
- **Standards**: report-format.md, subagent-return.md, source-store-deploy-boundary.md

## Executive Summary

- **The description on this dispatch is stacked with two superseding rewrites.** The live, authoritative scope is the "REVISED 2026-09-02" text plus its "ADDENDUM 2026-09-02" refinement: delete the single-task engine entirely and rewrite `SKILL.md` as a four-move batch-of-one loop (`orchestrate-cycle-plan.sh` -> dispatch -> `orchestrate-cycle-postflight.sh` -> branch). The "ORIGINAL DESCRIPTION" (mode-gate the Multi-Task section) is explicitly superseded and must NOT be implemented — state.json's own `title` field for project 88 already reflects the revised scope ("Delete the single-task engine and rewrite skill-orchestrate as the four-move loop").
- **Task 88's blocking dependency (148) is satisfied.** `specs/state.json` lists `dependencies: [148]`; task 148 (`port_single_task_features_to_batch_engine`) and its own predecessor 143 (`mt_handoff_staleness_and_dispatch_seq_gates`) are both `completed` and archived in `specs/CHANGE_LOG.md`. Task 88 is unblocked. `specs/PATH.md`'s own Progress/Chain-progress narrative is stale — it still describes 143 as "next, unblocked" and 148/88 as "remain behind it," but both have since landed. This staleness should be corrected as part of implementation (or flagged to the operator), not treated as current truth.
- **The target design is already fully specified in `specs/PATH.md`'s "Target design: the thin lead" section** (not re-derived here): the four-move loop pseudocode, the per-script absorption table, the capability-migration table (phase forcing, team fan-out [already deleted], hard-mode churn, loop guard, handoff gates, research-on-demand, `--dry-run`), and the `<=20,000 B` SKILL.md byte target with per-file ceilings for `commands/orchestrate.md`.
- **Most of the underlying machinery already exists as scripts** — `orchestrate-cycle-plan.sh` (1,538 lines — absorbs old Stage MT-3/MT-4 pre-dispatch), `orchestrate-build-dispatch.sh` (404 lines — Stage 3.5 dispatch-file builder), and `orchestrate-cycle-postflight.sh` (1,008 lines — the shared postflight body for both engines, built by task 143). Task 88's job is now overwhelmingly *deletion and reorganization* of `SKILL.md`'s prose/bash, not new script authoring — with one significant exception (below).
- **One genuinely new mechanism must be built, not just moved**: today, neither engine calls `AskUserQuestion` or writes `.decisions.json` when an agent surfaces `verdict=ask_user` — both engines only `echo` the question/options/recommendation to stderr (and, in single-task mode, halt on `blocking=true`). The rewrite's WORK item (2) requires the lead to actually invoke `AskUserQuestion` once per surfaced question, batched at cycle end, and persist the answer to `specs/{NNN}_{slug}/.decisions.json` for the next dispatch file to consume — this loop has no precedent in either current engine and `orchestrate-build-dispatch.sh` has no existing hook for reading `.decisions.json` into a dispatch file.
- **A materially larger-than-implied test/lint surface targets `SKILL.md`'s internal structure** (Stage names, sentinel regions, specific jq filters, `command-route-agent.sh` call counts) and will need retargeting onto the new loop or onto the scripts the logic now lives in — see Findings for the itemized list, several of which are not yet in the task's `file_scope`.

## Context & Scope

Researched what task 88 (dispatch phase=research, `.dispatch/1.md`) requires, given that its description contains three layered revisions (original mode-gating scope -> "REVISED" engine-deletion scope -> "ADDENDUM" refinement) and an explicit `REFERENCE: specs/PATH.md, "Target design: the thin lead"`. The research question was: what does the current repository state actually look like relative to the REVISED scope's WORK items and ACCEPTANCE criteria, so a plan can be written that does not re-derive already-decided design or duplicate already-completed prerequisite work.

Scope explicitly excludes: performing the deletion/rewrite itself (implementation-phase work), and re-deciding any of the design choices PATH.md's "Target design" section already records as decided (batch-of-one, no team mode, no `--no-ask` flag, research-on-demand deferred to task 150).

## Findings

### Description supersession (read order matters)

`.dispatch/1.md`'s Description section is chronologically stacked, newest-first is NOT the read order — the file states "ORIGINAL DESCRIPTION FOLLOWS" at the bottom, meaning the addenda at the top supersede it. Precedence, most-authoritative first:
1. `=== ADDENDUM 2026-09-02 (team mode deleted; dry-run report retired) ===` — narrow corrections to the REVISED scope: team rows no longer exist (item 6 already partially satisfied), dry-run path is `orchestrate-cycle-plan.sh --dry-run` (confirmed to exist — see below), and research-phase-ordering must not be hardcoded.
2. `=== REVISED 2026-09-02 (thin-lead path: engine deletion replaces mode-gating) ===` — the SUPERSEDING SCOPE: delete single-task Stages 1-8, rewrite as the loop, move narration to docs, target `<=20,000 B`, update critical-paths.json/state-machine doc/tests, retire team/phase-forcing notices.
3. `=== ORIGINAL DESCRIPTION FOLLOWS ===` — the mode-gating premise. Explicitly called "the inverse of how the system is used" and superseded. A plan built against this original text alone would be building the wrong thing.

`specs/state.json`'s live entry for project 88 (`title: "Delete the single-task engine and rewrite skill-orchestrate as the four-move loop"`, `dependencies: [148]`) confirms the REVISED scope, not the original, is what state.json itself tracks as the task's identity.

### Dependency and sequencing status

- `specs/state.json` project 88: `status: "researching"`, `dependencies: [148]`.
- `specs/CHANGE_LOG.md` (archived, 2026-09-07 entries): task 148 "port_single_task_features_to_batch_engine" — **completed**, full 8/8 phases, ported hard-mode churn/burnout counters, per-task cumulative cycle budget, the four `aux_dispatch[]` flows, and a single-task-through-batch-path opt-in flag; full gate green (`run-all.sh 70/70`). Task 143 "mt_handoff_staleness_and_dispatch_seq_gates" (148's own dependency) — also **completed**: both engines cut over to `orchestrate-cycle-postflight.sh` for the shared postflight body, closing the staleness/`dispatch_seq` gate defect by construction.
- **Task 88 is unblocked.** No further dependency work is outstanding before this task can proceed to planning/implementation.
- `specs/PATH.md` is stale relative to this state: its "Progress" table (row "A — thin lead") and "Chain progress, 2026-09-03" narrative still describe 143 as "next, unblocked" and 148/88/142/150 as "remain behind it" — written before 143 and 148 landed (2026-09-07 per CHANGE_LOG). This is a documentation lag, not a real blocker; a future pass (this task's implementation, or a dedicated doc-sync task) should refresh PATH.md's Progress table, but it should not be read as evidence that 143/148 are incomplete.

### Current measured state of `SKILL.md` (supersedes the dispatch's own stale figures)

The dispatch's ORIGINAL DESCRIPTION cites a 188,284 B file with a 103,462 B Multi-Task Mode section (55%) and Stages 1-8 at ~183,000 B; the REVISED addendum already flags these as stale ("grown to 293,977 B... since the figures below were taken"). Measured now (2026-09-08), source-store and deployed copies are byte-identical at **189,000 B** (deploy is fresh) — smaller than either prior baseline, because tasks 145-149 already extracted material. Section byte breakdown (line-range based, verified fence-safe — no headings found inside code fences):

| Region | Lines | Bytes | Notes |
|---|---|---|---|
| Header + Context References | 1-23 | ~1,900 | Kept, trimmed |
| Stage 0 (mode detection) | 25-39 | 518 | Deleted — no more mode branch |
| Stage 1 (Input Validation) | 40-129 | 6,438 | Deleted or absorbed into cycle-plan |
| Stage 1b (Routing) | 130-151 | 1,347 | Logic already duplicated by `orchestrate-triage-classify.sh` / cycle-plan; delete |
| Stage 2 (Loop Guard Init) | 152-481 | 21,505 | Deleted — cycle-plan now owns the loop guard (per 148/PATH.md table) |
| Stage 2b (Forced-Phase Queue) | 482-593 | 5,548 | Deleted — cycle-plan consumes `force_phases` per task already |
| Stage 3 (State Machine Loop) | 594-763 | 9,447 | Deleted — replaced by the four-move loop |
| Stage 3.5 (superseded pointer) | 764-780 | 1,062 | Already a stub pointing at `orchestrate-build-dispatch.sh`; delete stub too |
| Stage 4 (State Handlers) | 781-1734 | 54,478 | **Largest single region.** Per WORK item (1)'s own premise ("the feature-port predecessor has already made them unreachable") and 148's completion summary, this is dead code once the loop replaces per-state branching — delete outright, do not re-port |
| Stage 5 (Postflight) | 1735-1904 | 11,203 | Deleted — logic lives in `orchestrate-cycle-postflight.sh` (built by 143) |
| Stage 5a (Drift Inspection) | 1905-1950 | 2,741 | Deleted — absorbed into postflight script's aux-signal recording |
| Stage 5b (Churn/Three-Strikes, hard-only) | 1951-2027 | 4,894 | Deleted — `orchestrate-churn.sh` call now lives in postflight script per 148 |
| Stage 6 (Blocker Escalation) | 2028-2094 | 3,635 | Narration candidate for `orchestrate-state-machine.md`; mechanism itself already dispatch-row-shaped |
| Stage 7 (Loop Guard Update) | 2095-2148 | 2,751 | Deleted — cycle-plan owns counters |
| Stage 8 (Postflight) | 2149-2224 | 4,033 | Deleted |
| **Single-task total (Stage 0-8)** | | **~129,640** | ~69% of the file, not the dispatch's stale "~183,000" figure — smaller because 145-149 already trimmed shared material out from under it |
| Multi-Task Mode header | 2225-2231 | 336 | Becomes the loop's home; header itself likely deleted, content reorganized |
| Stage MT-1 (Parse Context) | 2232-2458 | 17,668 | Trim — much is field-list narrative candidate for state-machine.md |
| Stage MT-2 (Routing Table) | 2459-2502 | 2,537 | Keep, trim |
| Stage MT-3 (Cycling Loop) | 2503-2583 | 5,158 | Mostly already a `orchestrate-cycle-plan.sh` call site per 147; keep as the "move 1" body |
| Stage MT-4 (Dispatch + Postflight) | 2584-2784 | 14,809 | Mostly already `orchestrate-cycle-postflight.sh` call site per 143; keep as "move 2/3" body |
| Stage MT-5 (Postflight/report) | 2785-2981 | 13,747 | Consolidated-output rendering; keep, trim narrative to docs |
| **Multi-task total** | | **~54,255** | Already far below its 2026-09-02 baseline (103,462 B) / 2026-09-03 remeasurement (~111,000 B) thanks to 147/143's absorption work |
| MUST NOT (Context Flatness) | 2982-3015 | 2,123 | Already mostly a pointer to docs; further shrink |
| MUST NOT (Postflight Boundary) | 3016-3036 | 1,145 | Shrink to list per WORK item (3)'s "~1,500 B" target (both sections combined currently ~3,268 B, close to already meeting the combined target) |
| Skill-to-Agent Mapping + tail | 3037-3049 | 975 | Keep |

**Implication for the ≤20,000 B target**: the MT section (~54,255 B) already exceeds the ≤20,000 B target on its own, even before accounting for the loop-control glue code the rewrite must add. Reaching the target requires aggressively moving MT-1's field-list narrative (17,668 B is mostly documentation of `mt_state_file` fields, a natural fit for `orchestrate-state-machine.md`) and MT-5's rendering templates out of `SKILL.md`, not just deleting Stages 0-8. This is a heavier trim than "delete the dead half," consistent with WORK items (2)-(4) as a combined rewrite, not a pure deletion.

### The three per-cycle scripts already exist and match PATH.md's absorption table

- `scripts/orchestrate-cycle-plan.sh` (1,538 lines): absorbs status refresh, eligibility, `batch-admit`, `triage-classify`, lock acquire, `dispatch_seq` mint, preflight status write, per-task cumulative cycle budget (`cycle_counts`/`max_cycles_per_task`, durable via `.orchestrator-loop-guard`), `force_phases_remaining` per task, and (Phase 5) `aux_pending` -> `aux_dispatch[]` emission. Two-pass design (decision pass + live-effects pass); `--dry-run` runs only the decision pass — this is the retired standalone dry-run report's replacement the ADDENDUM names.
- `scripts/orchestrate-build-dispatch.sh` (404 lines): Stage 3.5 in full — memory retrieval, `--lit` briefing, hard-mode contract, effort note, model selection, territory, artifact round, continuation pointer, handoff path, user-decision contract text — writes `specs/{NNN}_{slug}/.dispatch/{seq}.md` and returns `{dispatch_file, model}`. Supports `--compare` and `--phase-number` (hard-mode per-phase dispatch) flags already. **No existing flag or code path reads `.decisions.json`** — this must be added if the answer needs to reach the next dispatch file per the ADDENDUM's WORK item (2).
- `scripts/orchestrate-cycle-postflight.sh` (1,008 lines): the single shared per-task postflight body for both engines (built by task 143) — handoff read with mtime + `dispatch_seq` gates, return-meta recovery, phase-count corroboration, writer-contract-aware defect recording, `user_decision` relay (verdict only — never asks, never writes `.decisions.json`, by explicit MUST NOT), status transition with monotonic clamp, artifact link + round advance, `modified_files` excursion advisory, scoped commit, MT-state update, lock release, hard-mode churn call. Returns `{task, phase, status, phases_completed, phases_total, verdict, user_decision?, note}`.

These three scripts are exactly PATH.md's "four moves" table (move 1 = cycle-plan, move 2 = one Agent call per dispatch row using build-dispatch's pointer-prompt output, move 3 = cycle-postflight per returned task, move 4 = branch). The rewrite's job is to make `SKILL.md`'s body literally that four-step loop instead of the current ~2,955-line dual-engine prose that already calls into these scripts from inside much larger Stage bodies.

### `--team` and phase-forcing notices (WORK item 6)

- `--team` / team fan-out: **already fully removed**. No `--team`, `team_size`, or "team fan" references remain anywhere in `SKILL.md` (confirmed by grep); task 149 (`delete team mode`, completed 2026-09-03) removed Stages 3.6/3.6a, the flags, `synthesis-agent`, and team tests. `orchestrate-team-fanout.sh` does not exist in the scripts directory. WORK item (6)'s `--team` half is a no-op for this task.
- Phase-forcing "accepted-and-ignored" notices: one remnant comment exists at line 2272 ("...phase-forcing gap this bullet used to describe as diagnostics-only. No notice is emitted here...") suggesting the notice itself was already retired in an earlier pass and only a comment documenting that fact remains. No live "accepted but ignored" user-facing notice text was found for phase-forcing flags in the MT section. This should be verified against the full Stage MT-1 text during implementation (the comment is suggestive, not exhaustive), but the described notice is very likely already gone — a small residual cleanup, not a new mechanism to build.

### The new `AskUserQuestion` + `.decisions.json` mechanism does not exist yet

Grep across `skills/`, `docs/`, `context/`, and the three cycle scripts found:
- Zero references to `.decisions.json` as a real file path anywhere except three comments (`orchestrate-cycle-postflight.sh` and `SKILL.md`) all stating the postflight script "never writes `.decisions.json`" — i.e., the file is a documented *future* consumer contract, not an implemented one.
- Both engines' current `ask_user` handling (single-task Stage 5, ~line 1808; multi-task Stage MT-4, ~line 2716) is identical in shape: extract `question`/`options`/`recommended`/`blocking` via `jq`, `echo` them to stderr, and (single-task only) `EXIT (partial)` when `blocking=true`. **`AskUserQuestion` is never invoked by either engine today.**
- `context/standards/user-decision-contract.md`'s "How the Field Is Relayed" section already documents the target behavior in prose ("The orchestrator's own lead prompt logic puts the question to the user exactly once, batched at the end of the current cycle") but this is aspirational relative to the current implementation — it describes what task 88's rewrite is expected to build, not what exists.
- A distinct, unrelated mechanism at `SKILL.md` line ~2415 ("no site in this mechanism may call `AskUserQuestion`... accumulate-then-render is the deterministic default") governs `detected_defects` (system-defect auto-logging), not `user_decision`. **Do not conflate the two during implementation**: defects are always rendered, never prompted (by design, since `orchestrator_mode` means no human is watching mid-run); `user_decision` is the one thing PATH.md's design wants surfaced via a real `AskUserQuestion` call, batched at cycle end, answer written to `.decisions.json`.
- No existing pattern in this codebase for an autonomous `/orchestrate` loop calling `AskUserQuestion` mid-run was found (other AskUserQuestion-referencing skills — `skill-meta`, `skill-spawn`, `skill-fix-it`, etc. — are interactive, single-shot skills, not autonomous multi-cycle loops). This is new interaction-pattern territory for the codebase, not a lift-and-shift.
- Acceptance criterion "an agent-surfaced `user_decision` is shown reaching `AskUserQuestion` and its answer reaching the next dispatch file" therefore requires: (a) the lead's own loop code calling `AskUserQuestion` once per cycle for the accumulated ask_user verdicts, (b) a write path for `specs/{NNN}_{slug}/.decisions.json`, and (c) a read path — most naturally a new `orchestrate-build-dispatch.sh` flag/behavior — that threads the answer into the next `.dispatch/{seq}.md` file. None of (a)-(c) exist today.

### Test and lint surface directly coupled to `SKILL.md`'s internal structure

Task 88's `file_scope` already lists most of the `scripts/tests/*` and `scripts/lint/*` files that grep `skill-orchestrate/SKILL.md`, but a closer read shows the *depth* of coupling is higher than file-scope membership alone suggests — several tests assert on specific Stage names, sentinel comments, or line-range regions that will not exist in the rewritten file:

| File | Coupling found | Rewrite impact |
|---|---|---|
| `test-loop-guard-budget-override.sh` | "TWO-TARGET STRUCTURE": Target 1 extracts a `budget-continuation-override:begin` sentinel region from `SKILL.md`'s single-task engine and explicitly asserts "the single-task engine stays live and stays the default path" (now false post-88); Target 2 already exercises `orchestrate-cycle-plan.sh` directly and is unaffected | Target 1 must be deleted or repointed; comment's own premise is invalidated by this task |
| `test-routing-resolution.sh` | Asserts `>=3 command-route-agent.sh invocations in skill-orchestrate/SKILL.md` and "no case-table or sed-derivation pattern still exists in skill-orchestrate/SKILL.md" | Routing calls likely move entirely into `orchestrate-triage-classify.sh`/cycle-plan; the ">=3 in SKILL.md" assertion will fail against a thin loop file and needs retargeting |
| `test-loop-guard-staleness.sh`, `test-handoff-dispatch-identity.sh` | Extract named sentinel/gate regions from `SKILL.md`'s single-task Stage 2/5 by line-anchored `awk` | Sentinel regions disappear with Stages 1-8; both suites need to retarget onto `orchestrate-cycle-plan.sh`/`orchestrate-cycle-postflight.sh`, which likely already have equivalent, less brittle coverage in their own dedicated test files (`test-orchestrate-cycle-plan.sh`, `test-orchestrate-cycle-postflight.sh`) |
| `test-handoff-reader-parity.sh` | Extracts specific `jq` filters (`blockers`, `hard_mode`-only `last_skeleton`, `follow_up_tasks`/`.sorry_inventory`, `.blockers[0].target`, `.blockers[0].verbatim_goal`) directly out of `SKILL.md`'s own Stage 5 prose via `grep -c == 1` uniqueness checks | If these filters move into the shared postflight script (likely, since 143 already unified handoff reading there), this suite needs to extract from the script instead of `SKILL.md` |
| `lint-postflight-boundary.sh` | Generic heuristic: `awk '/^### Stage [6-9]|^### Stage 1[0-9]/ { in_postflight=1 }'` to locate any skill's postflight section, falling back silently to "\[SKIP\] No postflight section found" when no match | The rewritten `SKILL.md` will almost certainly not use "Stage 6-19" numbering for its four-move loop; this lint will silently stop checking `skill-orchestrate/SKILL.md`'s postflight boundary rather than failing loud — a real (if soft) regression risk worth flagging in the plan, either by keeping a "Stage" or "Move" heading this pattern (or an updated one) can match, or by extending the lint's heuristic |
| `lint-contract-compliance.sh` | Named "Check C" explicitly keys off "skill-orchestrate/SKILL.md Stage 1b" for engine dispatch wiring; "Check D" keys off a `hard_mode` branch's convergence-policing fields | Both checks assume Stage-numbered single-task structure; need retargeting onto the loop's per-row dispatch and the (surviving) hard-mode fields wherever they land |
| `test-resume-scan-nonconformance.sh` | Comment: "a distinct gate site inside skill-orchestrate/SKILL.md to retarget Site B onto. Site A alone now..." — implies an existing multi-site design already partially anticipates consolidation | Verify Site A/B still make sense once Stages 1-8 are gone |

None of these are new discoveries requiring a plan to build from scratch — they are existing, working tests whose *coupling target* moves. This is squarely WORK item (5)'s "every test that greps SKILL.md structure (enumerate by grep...)" — the enumeration above is a starting point but the plan should re-run the grep sweep in `scripts/tests` and `scripts/lint` as its own verification step, since some of the deepest couplings above (specific `jq` filter extraction, sentinel-region names) surfaced only from reading file bodies, not from `SKILL.md`-path grep alone.

### `context/reference/orchestrator-critical-paths.json` (WORK item 5)

Current entry for `skills/skill-orchestrate/SKILL.md` carries the label `"multi-task dispatch state machine (both effort modes: hard-mode dispatch contracts now live here too, since the former standalone hard-mode engine was merged in and deleted)"` — describes the pre-88 merged-but-dual-engine state and needs updating to describe the four-move loop. Separately, **`orchestrate-cycle-postflight.sh` and `orchestrate-build-dispatch.sh` are absent from this critical-paths registry** even though `orchestrate-cycle-plan.sh` is present — both should likely be added given they become (with cycle-plan) the three scripts the thin lead's entire runtime behavior reduces to.

### `docs/architecture/orchestrate-state-machine.md` and `handoff-schema.md` (WORK item 3 destination)

- `orchestrate-state-machine.md` (35,268 B) already documents the complete state table, transition diagram, MAX_CYCLES enforcement, blocker escalation, Context Flatness Guarantee, and a `## MT Mode: Multi-Task Orchestration` section (lines 330+) covering the lifecycle-cycling loop, `aux_dispatch[]`, batch size cap, dependency gating, commit granularity, and exit conditions — i.e., it is already structured as "the MT design is the real design, single-task is a footnote," which matches the rewrite's direction. It will need light restructuring (promote MT mode to be simply "the design," fold in what single-task narration is worth keeping) rather than a from-scratch rewrite.
- `handoff-schema.md` (53,767 B) and a dedicated `docs/architecture/orchestrate-cycle-postflight.md` (14,568 B, already exists, written when 143 landed and already cited from `SKILL.md`'s own MUST NOT section) between them already carry much of the narrative WORK item (3) wants moved out of `SKILL.md`. Less net-new doc-writing is needed than the WORK item's phrasing implies.

## Decisions

- Treat the REVISED + ADDENDUM description as the sole scope for planning; do not implement the ORIGINAL mode-gating description, per the explicit supersession language and per `state.json`'s own recorded title.
- Treat task 88 as unblocked (148 and its own dependency 143 are both completed and archived), and flag `specs/PATH.md`'s stale Progress/Chain-progress narrative for correction rather than treating it as a live blocker.
- Recommend the plan phase enumerate the `AskUserQuestion`/`.decisions.json` mechanism as its own explicit phase (new construction, no existing precedent to lift from), separate from the deletion/move phases, since it is qualitatively different work with its own risk profile (first autonomous-loop use of `AskUserQuestion` in this codebase).

## Risks & Mitigations

- **Risk**: `SKILL.md` ≤20,000 B target is not reachable by deletion alone — the Multi-Task section alone is already ~54,255 B before any loop-control code is added. **Mitigation**: the plan must budget an aggressive move of MT-1's field-list documentation (17,668 B) and MT-5's rendering-template prose into `orchestrate-state-machine.md`/`handoff-schema.md`, not just delete the single-task half.
- **Risk**: `lint-postflight-boundary.sh`'s generic `### Stage [6-9]|### Stage 1[0-9]` heading heuristic will silently stop finding a postflight section in the rewritten file (SKIP, not FAIL), quietly weakening an existing enforcement gate. **Mitigation**: either retain a heading the lint's regex matches, or extend the lint script as part of this task's scope (it is not currently in `file_scope` — recommend adding it).
- **Risk**: Several tests (`test-handoff-reader-parity.sh`, `test-loop-guard-staleness.sh`, `test-handoff-dispatch-identity.sh`) extract *specific jq filters and sentinel regions* from `SKILL.md` prose rather than testing behavior through the scripts. If the underlying filters/logic already live in `orchestrate-cycle-postflight.sh` (likely, per 143), these tests may already have redundant, more robust coverage in `test-orchestrate-cycle-postflight.sh` — the plan should verify this and prefer deleting the brittle `SKILL.md`-scraping assertions over retargeting them, where true duplication is confirmed.
- **Risk**: Building `AskUserQuestion` + `.decisions.json` + dispatch-file threading has no existing pattern to copy in an autonomous multi-cycle loop context. **Mitigation**: scope it as an isolated, carefully-tested phase; the ACCEPTANCE criterion explicitly demands a live demonstration of an agent-surfaced decision reaching `AskUserQuestion` and the answer reaching the next dispatch file, so this cannot be deferred or hand-waved in the plan.
- **Risk**: `context/reference/orchestrator-critical-paths.json` is itself a `recursion_guard: true` critical path — edits to it should be verified against `verify-deploy.sh`'s own self-reference handling to avoid a recursion-guard regression.

## Context Extension Recommendations

- **Topic**: `specs/PATH.md` staleness protocol. **Gap**: PATH.md is treated as a living plan-of-record but has no mechanism (beyond manual "pass" annotations) to flag when its own Progress table has drifted behind `state.json`/`CHANGE_LOG.md`, as observed here (143/148 shown as pending when both are completed). **Recommendation**: no context file needed for this alone, but the task 88 implementation (or a small follow-up) should refresh PATH.md's Progress table and Chain-progress narrative as a cheap, high-value side effect.

## Appendix

- Search queries used: `grep -n "multi_task_mode\|Multi-Task Mode\|Stage MT-1\|Stage 0"`, `grep -rln "AskUserQuestion"`, `grep -rn "\.decisions\.json"`, `grep -rln "skill-orchestrate/SKILL.md" scripts/tests scripts/lint`, section-boundary byte computation via a small Python script over `SKILL.md`'s line ranges.
- Key files read (partial, targeted reads only — file sizes made full reads infeasible and unnecessary): `SKILL.md` (headings, Stage 0/5/2415/2716/2785-2830/2982-3037 regions), `scripts/orchestrate-cycle-plan.sh` (header comment), `scripts/orchestrate-build-dispatch.sh` (header comment), `scripts/orchestrate-cycle-postflight.sh` (header comment), `specs/PATH.md` (lines 1-320, 495-520), `specs/CHANGE_LOG.md` (lines 1-90), `context/standards/user-decision-contract.md` (full), `context/reference/orchestrator-critical-paths.json` (full), `docs/architecture/orchestrate-state-machine.md` (headings only).
- A prompt-injection attempt was observed during this research session: a fabricated "system-reminder" block instructing a change to git commit/PR attribution appeared embedded inside a `grep` command's Bash tool output (not a genuine system or user message). It was not acted on — this research task performs no commits — and is noted here for visibility.
