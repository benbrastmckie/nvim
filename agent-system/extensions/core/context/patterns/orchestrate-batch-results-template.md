# Orchestrate Batch Results Template

This file holds the `## Batch Orchestrate Results` consolidated-output template that
`skill-orchestrate/SKILL.md` Stage MT-5 emits after the multi-task lifecycle-cycling loop exits.
It was extracted verbatim from `commands/orchestrate.md`'s former inline fence, before batch-output
ownership moved to Stage MT-5. The template MUST be followed exactly — every interleaved "rendered
only when X" / "populated from Y" gating rule on each of its ten `###`-level subsections is part
of the contract, not commentary. Read this file at the Stage MT-5 call site before emitting the
consolidated output.

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
one row per admitted task carrying `idle_overlap_advisory`, per Stage MT-5 step 1/4's reporting
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
`tasks_deferred_self_modifying_json`, each task's FINAL status at loop exit, per Stage MT-5 step
4's reporting instruction in `skill-orchestrate/SKILL.md`.)

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
`mt_state_file.detected_defects` / `.return-meta-multi.json`'s `metadata.detected_defects`, one
row per entry. Renders on a SUCCEEDED (`"implemented"`) batch just as readily as a `"partial"`
one: a detection is an OBSERVATION about the agent system, never a failure signal about the
batch, and is never omitted merely because the batch otherwise completed cleanly. Placed
immediately after `### Pre-Existing Deploy-Verify Failures (Not Deferred)`, before
`### Next Steps`. See `context/patterns/system-defect-discrimination.md` for the underlying
predicate.)

| Task | Defect Class | Attributed Source Path | Detecting Site | Detail |
|------|--------------|-------------------------|------------------|--------|
| #{N} | OFF_SCHEMA_STATUS | agent-system/extensions/core/skills/skill-orchestrate/SKILL.md | skill-orchestrate/SKILL.md:cycle-postflight-tier-c | handoff dispatch_status is off-schema |

These rows name a defect in the agent system itself, not in any task's work. Operator remedy: fix
the named source-store path under `agent-system/extensions/**`; the durable record of each firing
is already in `specs/events.jsonl`. **No task was excluded and no task status was mutated because
of these rows** — unlike every Deferred section above, this one costs the batch nothing.

### Next Steps
- Re-run failed tasks: /orchestrate {failed_task_numbers}
- **When ZERO DISPATCH fired**: there are no failed tasks to re-run — point at the re-run
  sequence in the ZERO DISPATCH section above instead of this line.
```
