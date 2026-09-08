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

**Goal (two halves, in priority order)**

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

**Batch 3 — the next one to run.** Stage A is closed, so the serialization constraint that
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
7. **Research on demand.** The planner is dispatched first and asks for research only when the
   plan would otherwise rest on guesses; `--research` forces research first. 150.
8. **Dry-run report: retired.** Rarely used, and two renderings of one verdict is how 141's
   defect arose. `orchestrate-cycle-plan.sh --dry-run` prints the plan it would dispatch. 147.
9. **Consumer validation: no fixed checks.** This file recommends tests to run (next section);
   it does not gate completion on them.

Nothing is open. New questions go here as they arise.

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

**One caveat on this table**: Stages B-E were surveyed 2026-09-02 and have not been re-surveyed
since. Twenty-six open tasks filed after that date appear nowhere in them — see "Filed since the
last survey" below. The stage rows above are accurate for what they cover and silent about the
rest; do not read "3/9 done" as "6 tasks left in B".

### Filed since the last survey (2026-09-03 onward, unplaced in any stage)

Recorded here so the roadmap stops implying these do not exist. Grouped by theme, not yet
prioritized into stages — a re-survey pass should place them properly.

| Cluster | Tasks | Note |
|---|---|---|
| Redeploy checkpoint | 180, 181, 182 | Measured ~10 min per firing; deferred a whole batch once. Batch 3a |
| Pre-dispatch review correctness | 188, 189 | Class A false positives; Class C false negatives + stdout/budget defects. Batch 3a |
| `file_scope` lifecycle | 162, 163, 164, 165 | Coherent four-task arc, own topic; harvest → surface → backfill → admission posture |
| Build-waiter hygiene | 172, 173, 174, 175 | Bounded-wait idiom, terminal records, reaper pass, contract enforcement |
| Lean extension | 176, 177, 184 | Extension-side, independent |
| Artifact/doc drift | 157, 166, 185, 186, 187 | TODO.md summary lines, report headings, stage→move vocabulary, doc paths, commit attribution |
| Misc | 167, 168, 170, 171, 183 | latex rule, opencode claim, test isolation, literature hang, loop-guard disposition |
