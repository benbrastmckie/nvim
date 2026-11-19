# Orchestrate Batch Results Template

This file holds the `## Batch Orchestrate Results` consolidated-output template.
`skill-orchestrate/SKILL.md` Move 4 renders and stages it after the lifecycle-cycling loop
exits, but Move 5's own Step 6 is the sole site that EMITS it — folded into that step's combined
report alongside the conclusion stage's own channels. It was extracted verbatim from
`commands/orchestrate.md`'s former inline fence, before batch-output ownership moved into the
four-move loop. The template MUST be followed exactly — every interleaved "rendered only when X"
/ "populated from Y" gating rule on each of its twelve `###`-level subsections is part of the
contract, not commentary. Read this file at Move 4's render-and-stage step, and again at Move 5
Step 6's emission, before the consolidated output is ever shown.

```markdown
## Batch Orchestrate Results

Session: {batch_session_id}
Tasks requested: {count}
Succeeded: {succeeded_count}
Failed: {failed_count}
Skipped: {skipped_count}
Cycles used: {cycles_used}/{max_cycles}

### ZERO DISPATCH

(Rendered only when `forward_progress_violated` resolved true above. Placed immediately after the
counts block and BEFORE `### Succeeded` — never omitted, never demoted below the ordinary tables.)

[ZERO DISPATCH - 0 of {validated_count} validated candidates dispatched; forward-progress invariant violated]
<!-- forward-progress violated=true dispatched=0 validated={validated_count} -->

This is not a failure: no task was marked failed or blocked and `specs/state.json` was not
mutated (see `context/patterns/batch-orchestration-guardrails.md`'s
`### The Forward-Progress Invariant` subsection).

| Task | defer_reason | Detail |
|------|--------------|--------|
| #10 | self_modifying | matched critical path .claude/scripts/task-lock.sh (concurrency lock) |
| #11 | file_scope_collision | colliding out-of-batch task #{N} (status: implementing) |

Re-run sequence (dependency order; printed, not executed):
```
/orchestrate 10
/orchestrate 11
```

### Succeeded

| Task | Title | Final Status |
|------|-------|--------------|
| #42 | task_title | [COMPLETED] |

### Failed

| Task | Error |
|------|-------|
| #43 | Partial: blockers present (no continuation) |

### Skipped

| Task | Reason |
|------|--------|
| #44 | predecessor #43 failed |
| #99 | terminal status [ABANDONED] |

### Admitted (idle overlap advisory)

(Renders whenever `idle_overlap_ledger` is non-empty — populated from that per-cycle accumulator,
one row per admitted task carrying `idle_overlap_advisory`, per Move 3's reporting
instruction in `skill-orchestrate/SKILL.md`. These tasks were ADMITTED, not deferred — this
section is placed on the admitted side, near the `### Deferred (...)` cluster below, because the
overlap it surfaces is the same idle cross-batch mechanism those sections cover for the deferring
case.)

| Task | Colliding Task | Colliding Status | Overlapping Path | Note |
|------|-----------------|--------------------|---------------------|------|
| #24 | #25 | not_started | agent-system/extensions/core/scripts/orchestrate-batch-admit.sh | admitted; no execution evidence on colliding task — add a dependencies[] edge if ordering matters |

Not an exclusion and not a failure: the task dispatched normally. Operator remedy (optional):
add a `dependencies[]` edge between the two task numbers if ordering between them actually
matters; otherwise no action is required.

### Deferred (self-modifying)

(Renders on every batch, not only zero-dispatch ones — populated from
`tasks_deferred_self_modifying_json`, each task's FINAL status at loop exit, per Move 3's
reporting instruction in `skill-orchestrate/SKILL.md`.)

| Task | Final Status | Note |
|------|--------------|------|
| #21 | [COMPLETED] | deferred at least one cycle by the self-modification gate — an OBSERVATION; went on to complete before loop exit |
| #22 | still pending | deferred, not yet redispatched this invocation — remains eligible for a future `/orchestrate` run (solo or batched) or `--allow-self-modifying` |

### Deferred (other admission exclusions)

(Populated from `defer_ledger` entries whose `defer_reason` is neither `self_modifying` nor
`deploy_checkpoint` — i.e. `file_scope_collision` deferrals — so they are visible on ordinary
partial batches too, not only inside the ZERO DISPATCH section above.)

| Task | defer_reason | collision_scope | Detail |
|------|--------------|------------------|--------|
| #23 | file_scope_collision | cross_batch | colliding out-of-batch task #{N} (status: implementing) |

### Deferred (redeploy checkpoint)

| Task | Reason |
|------|--------|
| #55 | inter-cycle redeploy checkpoint gate failed ({gate}, exit {code}; {n} new finding(s) vs. pre-redeploy baseline); not dispatched for the remainder of this invocation |

Operator remedy (distinct from a deferred-self-modifying task): resolve the deploy/verify
failure, redeploy manually, then re-run `/orchestrate` on the remaining task numbers. See
`context/patterns/batch-orchestration-guardrails.md`'s `### The Inter-Cycle Redeploy Checkpoint`
subsection for the full contract; not restated here.

### Pre-Existing Deploy-Verify Failures (Not Deferred)

(Rendered only when `verify_deploy_baseline_notices` is non-empty — populated from
`mt_state_file.verify_deploy_baseline_notices`, one row per entry. Renders on a SUCCEEDED
(`"implemented"`) batch just as readily as a `"partial"` one: the third operator-visible state is
never omitted merely because the batch otherwise completed cleanly. Placed immediately after
`### Deferred (redeploy checkpoint)`, before `### Next Steps`.)

[PRE-EXISTING VERIFY-DEPLOY FAILURE - N finding(s) predate this redeploy, 0 newly introduced; batch continuing]
<!-- verify-deploy-baseline pre={pre_count} post={post_count} new=0 proceeded=true -->

These findings are REAL problems that were not introduced by this batch's redeploy — the
pre-redeploy baseline already contained every one of them. Operator remedy: fix the standing
failure at your convenience, then re-run `bash .claude/scripts/verify-deploy.sh` manually to
confirm. Unlike `### Deferred (redeploy checkpoint)` above, no task was excluded because of this.

| Cycle | Gate | Pre-existing findings | New findings | Outcome |
|-------|------|------------------------|---------------|---------|
| 2 | verify-deploy.sh | 4 | 0 | proceeded — pre-existing, batch continuing |

When `post_exit` is `2`, the row's Outcome instead reads "verify-deploy could not run, before or
after this redeploy — pre-existing condition" (the symmetric exit-2 case: `verify-deploy.sh`
could not be run either before or after this redeploy, for the identical reason).

See `context/patterns/batch-orchestration-guardrails.md`'s `### The Inter-Cycle Redeploy
Checkpoint` subsection (Failure contract branch (c), Baseline mechanism, and Exit-2 resolution)
for the full contract; not restated here.

### System Defects Detected

(Rendered only when `detected_defects` is non-empty — populated from
`mt_state_file.detected_defects` / `specs/.orchestration/.return-meta-multi-{session_id}.json`'s
`metadata.detected_defects`, one
row per entry. Renders on a SUCCEEDED (`"implemented"`) batch just as readily as a `"partial"`
one: a detection is an OBSERVATION about the agent system, never a failure signal about the
batch, and is never omitted merely because the batch otherwise completed cleanly. Placed
immediately after `### Pre-Existing Deploy-Verify Failures (Not Deferred)`, before
`### Conclusion`. See `context/patterns/system-defect-discrimination.md` for the underlying
predicate.)

| Task | Defect Class | Attributed Source Path | Detecting Site | Detail |
|------|--------------|-------------------------|------------------|--------|
| #{N} | OFF_SCHEMA_STATUS | agent-system/extensions/core/skills/skill-orchestrate/SKILL.md | skill-orchestrate/SKILL.md:cycle-postflight-tier-c | handoff dispatch_status is off-schema |

These rows name a defect in the agent system itself, not in any task's work. Operator remedy: fix
the named source-store path under `agent-system/extensions/**`; the durable record of each firing
is already in `specs/events.jsonl`. **No task was excluded and no task status was mutated because
of these rows** — unlike every Deferred section above, this one costs the batch nothing.

### Batch Gate Stage Result

(Rendered only when `batch_gate` is present on `mt_state_file` — i.e. the Batch Gate Stage's
trigger condition fired this invocation: at least one `implement`-phase dispatch occurred,
whether the batch held one task or many. Absent entirely on a research-only/plan-only invocation,
which never dispatches an implementation agent. Populated from
`mt_state_file.batch_gate` / `specs/.orchestration/.return-meta-multi-{session_id}.json`'s
`metadata.batch_gate`. Placed immediately after `### System Defects Detected`, before
`### Conclusion` — it fires inside Move 4 (before this template's own render completes), so it is
rendered here, never deferred to Move 5. See `context/contracts/batch-gate-stage.md` for the full
contract; not restated here.)

[BATCH GATE: verify-deploy.sh ran once for this batch — {confirmed_count} confirmed finding(s), {attributed_count} attributed, {unattributed_count} unattributed]
<!-- batch-gate exit={gate_exit_code} confirmed={confirmed_count} unattributed={unattributed_count} -->

A finding attributed to a task below is this batch's own evidence that that task's work caused
it — review and fix as part of that task, same as any other result in this run. A finding in the
Unattributed row below is NOT pinned on any one task: it stays blocking at the batch level and is
never dropped or reported as though it were attributable to whichever task happens to be listed
nearby.

| Task | Attributed Finding(s) |
|------|------------------------|
| #42 | `FINDING gate8 test-foo.sh failure referencing agent-system/extensions/core/scripts/foo.sh` |
| Unattributed (batch-level) | `FINDING gate14 some advisory prose with no file identifier at all` |

This result is BATCH-attributed, never folded into one task's own `### Succeeded`/`### Failed`
row above — a task whose own work is confirmed clean everywhere else can still appear here if
this shared run found something new, and conversely a task's presence in `### Succeeded` is never
contradicted by this section (the two answer different questions: "did this task's own dispatch
succeed" vs. "did the complete gate set, run once for the whole batch, find anything").

**Owed-sweep sub-result** (rendered only when `batch_gate.owed_discharged_count` or
`batch_gate.owed_open_count` is nonzero — both are 0, and this sub-result is omitted entirely,
when no task this invocation iterated ever wrote an owed record at all; see
`context/contracts/batch-gate-stage.md`'s "Owed-Sweep Discharge" section for the full discharge
contract this renders):

[OWED SWEEP: {owed_discharged_count} full-sweep-owed record(s) discharged this run, {owed_open_count} still open]

A still-open row is NEVER silently dropped from view — it stays in its task's own
`records/full-sweep-owed.jsonl` until a future clean batch-gate run discharges it, and is listed
below every time this template renders until then:

| Task | Owed Path |
|------|-----------|
| #42 | `agent-system/extensions/core/scripts/some-new-untracked-file.sh` |

An empty table with `{owed_open_count}` of 0 means every owed record this invocation could see
was just discharged (or none existed); it does NOT mean no task anywhere has an open owed record
— only tasks this invocation's own `.task_numbers` iterated are ever checked.

**Red-close sub-result** (rendered only when `batch_gate.close_red_recorded_count` is nonzero;
omitted entirely on a clean close or a `--dry-run` invocation, where it is always 0; see
`context/contracts/batch-gate-stage.md`'s "Red-Close Per-Task Record" section for the full write
contract this renders):

[RED CLOSE: {close_red_recorded_count} per-task record(s) written — the complete gate set found
an attributed break this invocation]

A row below names a task this invocation's own close battery found attributable evidence
against, with its own open `records/close-battery-red.jsonl` row and finding count. **Operator
remedy**: re-run the named scoped check (`scripts/verify-touched.sh` or `scripts/verify-deploy.sh
--only-gate N[,M...]`) for that task's own files, fix what it finds, then re-run the close so a
clean result discharges the row.

| Task | Record Path | Finding Count |
|------|-------------|----------------|
| #42 | `specs/042_some_task/records/close-battery-red.jsonl` | 2 |

A task appearing here that was also marked `[COMPLETED]` earlier in this run is the attributed
cause of a red close and does not stay `[COMPLETED]` on the strength of its own scoped check
alone — see `scripts/orchestrate-close-status-bind.sh`'s own contract and
`context/standards/status-markers.md`'s `[COMPLETED]` subsection for the demotion this produces,
rendered separately from this roster.

**Open close obligations sub-result** (rendered only when `batch_gate.close_obligations_found_count`
is nonzero; omitted entirely when this invocation found no stale foreign
batch-gate-pending marker, which is the ordinary case; see
`context/contracts/batch-gate-stage.md`'s "Open Close Obligations" section for the full
report/discharge contract this renders):

[OPEN CLOSE OBLIGATIONS: {close_obligations_found_count} stale marker(s) found this invocation —
{close_obligations_markers_discharged_count} discharged this run,
{close_obligations_red_rows_discharged_count} close-battery-red.jsonl row(s) paid alongside them]

A stale marker names a prior orchestration that dispatched an implement phase and never reached
this stage to discharge it (a stop verdict, a crash, an operator interrupt) — the complete gate
set it owed was still owed until this line. `close_obligations_markers_discharged_count` is 0 on
a red or `--dry-run` close: a failing or skipped run proves nothing about the obligation and
discharges nothing, so a nonzero `close_obligations_found_count` alongside a 0 discharged count
means the obligation is STILL open and will be reported again by the next invocation's own
startup scan (`orchestrate-cycle-plan.sh`), not silently dropped.

| Stale Marker Session | Age (sec) | Declared Task(s) |
|-----------------------|-----------|-------------------|
| sess_1700000000_abc123 | 9000 | 42, 43 |

### Conclusion

(Rendered once per invocation, as part of Move 5's own Step 6 — the single site that EMITS this
entire template, including every section above. Move 4 renders and stages those other sections
but prints none of them; Step 6 is where this Conclusion section is composed and where the whole
combined report (everything above, plus this section) is shown for the first and only time. See
`context/contracts/conclusion-stage.md`. ALWAYS placed last, immediately before `### Next
Steps`, since Step 6 runs only after Move 4 has fully finalized, including this template's own
render-and-stage pass. Never merged with `### System Defects Detected` above: that section is
unconditional and
engine-written; this one derives from subagent-written `issues.jsonl` evidence via
`scripts/orchestrate-conclusion-aggregate.sh`, and only channel (a) is gated behind an explicit
approval — channels (b) and (c) record unconditionally.)

**Wins**: {wins_summary} — `kind: "win"` entries from the aggregated issue logs, summarised only,
never actioned.

**Channel (a) — Direct fixes**: {channel_a_outcome} (`approved` / `declined` / `not asked — no
proposals`). When approved, lists the fix(es) applied with their `{task, entry_id}` citations.

**Channel (b) — Agent-system changes**: {channel_b_outcome} (`recorded — N proposals` /
`not recorded — no proposals`). When recorded, names each proposal's `class`, `severity_max`, and
citations now durable in `specs/events.jsonl` (`event_type: "conclusion_proposal_recorded"`),
awaiting the batched, dedup-aware consumer, `/distill --meta`.

**Channel (c) — Follow-up tasks**: {channel_c_outcome} (`recorded — N proposals` /
`not recorded — no proposals`). When recorded, names each proposal's `class`, `severity_max`, and
citations now durable in `specs/events.jsonl` (`event_type: "conclusion_proposal_recorded"`),
awaiting the batched, dedup-aware consumer, `/distill --meta`.

**Unknown-class tally**: {unknown_classes_table} — one row per `class` outside the 17-class seed
enum, with its cross-task count.

**Implicit-open count**: {implicit_open_count} — candidates above that reached classification
because their `resolution` was null or omitted rather than an explicit `"open"`; informational
only.

**Zero-contribution dispatches**: {no_contribution_tasks_list} — touched tasks whose
`issues.jsonl` was absent or empty this invocation.

**Roadmap**: regenerated (`specs/ROADMAP.md`).

**Suggested next batch**: from `orchestrate-suggest-next-batch.sh --next-batch`
(`context/contracts/conclusion-stage.md`'s Step 7). The suggester first walks
`specs/state.json`'s authored `roadmap_batches` array, in authored order: each batch's members
are readiness-filtered locally, an empty-filtered batch is skipped at zero probe cost, and the
first non-empty filtered batch is probed through the same admission chain every other candidate
source uses. On success, the render names the batch's authored position and `description`
(`Authored roadmap batch N -- {description}:`), notes any omitted not-ready member by name when
the filtered set is a proper subset of the authored `task_ids`, and the three mechanical options
below are NOT also rendered for that invocation. When no authored batch survives filtering and
probing — including when `roadmap_batches` is absent or an empty array, which is a silent,
zero-probe fallback with no extra line — and at least one authored batch WAS checked, one
explicit line states how many batches were checked, how many were skipped as empty-filtered, and
how many were probed but deferred, before falling through to the mechanical options.

Only once the roadmap walk yields nothing does Mode A fall back to up to `MAX_BATCH_OPTIONS` (3)
distinct, labelled, probe-verified mechanical options — one per selection-doctrine criterion
(shared territory / topic cohesion / graph width) — each under its own `Option N --
{criterion}:` header naming why it coheres, each carrying its own admission evidence
(`render_verdict_evidence()`'s `task N: admit`/`defer (reason)` lines). A criterion whose own
candidate pool is empty is skipped; an option whose task set duplicates an already-rendered
option's is skipped rather than printed twice.

A `file_scope`-colliding pair is ADDITIVE information alongside a probe-verified joint batch,
NEVER a replacement for one: it renders as its own ordered-sequence line
(`/orchestrate A, then B (ordered sequence -- file_scope collision)`) with the proposed
`--depends-on-add` command, in the SAME option's output as any joint batch line that option's
own conflict-free-subset second pass admits. Every suggestion states it was admissible when
suggested and should be re-verified at actual dispatch time.

**Proposed edges and the edge-write approval outcome**: `{edge_write_outcome}` — one of
`approved — written` (lists each written edge and its post-write re-probe evidence, both
members now `admit`), `declined` (`specs/state.json` is byte-identical to before this stage
ran), or `not asked — no proposed edges` (Step 7 found no colliding pair this invocation, so
the `edges` approval gate was never reached). The `edges` key is an independent, non-channel
approval key (`context/contracts/conclusion-stage.md`'s Step 7) — it is never satisfied by any
channel's own approval, and no channel is ever satisfied by it.

The shared probe-invocation cap (`MAX_PROBE_INVOCATIONS`) is honored across every option in one
invocation; reaching it mid-render is rendered EXPLICITLY (the suggester's own cap-reached
line, plus the stage's "cut short by the cap" line), retaining every option already rendered
rather than silently truncating the list. When the suggester finds nothing suggestible at all,
this whole block is OMITTED WITH AN EXPLICIT REASON (the suggester's own "no suggestible batch"
line, quoted here) rather than left blank.

### Next Steps
- Re-run failed tasks: /orchestrate {failed_task_numbers}
- **When ZERO DISPATCH fired**: there are no failed tasks to re-run — point at the re-run
  sequence in the ZERO DISPATCH section above instead of this line.
- Hear a short spoken recap of this run: Run /recap
```
