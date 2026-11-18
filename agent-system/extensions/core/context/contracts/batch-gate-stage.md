# Batch Gate Stage (Move 4)

## Overview

The batch gate stage is Mechanism B of the batch-shared verify-deploy-gate design: a single,
once-per-invocation run of the complete `verify-deploy.sh` gate set, sited inside Move 4 of
`/orchestrate`'s four-move loop — after `exit_status` resolution, before consolidated-output
emission — rather than once inside every task's own final implement phase. Its companion,
Mechanism A, is `orchestrate-build-dispatch.sh`'s `## Batch Gate Deferral` section: the
dispatch-time directive that narrows a final implement phase's own in-dispatch obligation to a
scoped tier, deferring the complete gate set's discharge to this stage. See
`context/formats/plan-format.md`'s "Batch-aware deferral" subsection for the plan-level contract
Mechanism A implements, and `context/contracts/phase-closure.md`'s no-promotion-without-evidence
carve-out for how a deferred `full` declaration stays honest.

**Narrowing-invocation paths are resolved, not hardcoded.** Mechanism A's emitted directive names
two narrowing invocations — a scoped `run-all.sh --only SUITE[,SUITE...]` and a scoped
`verify-deploy.sh --only-gate N[,M...] --skip-unchanged` — and the composer resolves each one
across the deploy/source-store boundary before interpolating it into the directive text: the
deployed mirror
(`.claude/scripts/tests/run-all.sh`, `.claude/scripts/verify-deploy.sh`) is tried first, with the
agent-system source-store path (`agent-system/extensions/core/scripts/tests/run-all.sh`,
`agent-system/extensions/core/scripts/verify-deploy.sh`) as the fallback for when the composer
runs inside the agent-system repository itself. A deploy-target repository never carries the
source-store path, so a directive that hardcoded it unconditionally named a path that could not
resolve there. If neither candidate exists, the directive degrades to stating the full gate set
as such rather than naming a dead path — see `orchestrate-build-dispatch.sh`'s
`batch_gate_deferral_flag` block for the resolution logic itself.

**The two narrowing invocations are not flag-symmetric.** The `verify-deploy.sh --only-gate` form
carries `--skip-unchanged` as the sanctioned cheap probe for re-confirming an already-green
scoped tier; the `run-all.sh --only` form never does. `run-all.sh` does not parse
`--skip-unchanged` at all — its argument loop ends in a catch-all unknown-argument exit — and a
narrowed `--only` run already bypasses the `specs/.gate-lock` bracket, so it carries none of the
mutex contention the cache fast path exists to relieve.

Each confirmed finding this stage's shared run produces is attributed to the task(s) whose own
`modified_files` plausibly caused it. A finding attributable to no task is recorded as a
batch-level unattributed finding and stays blocking — never dropped, never pinned on one
arbitrary task. This is the stage's load-bearing acceptance claim: the shared run is not merely
cheaper than N per-task runs, it is also a MORE HONEST attribution than a per-task run under
concurrency, where every sibling's in-flight edits pollute every other sibling's own gate result.

## Suite-Level Narrowing Convergence (Gate 8)

Mechanism A's scoped `verify-deploy.sh --only-gate 8` directive selects GATES, not suites — it
still runs Gate 8's complete shell-test battery, only skipping every OTHER gate. `verify-deploy.sh`
separately carries an opt-in, caller-supplied `--gate8-touched PATH[,PATH...]` input
(`context/standards/shell-script-testing.md`'s "Gate 8's own touched-paths narrowing" section) that
narrows Gate 8's OWN internal `run-all.sh` invocation to the covering suite(s) for the given
path(s). The two compose: a caller holding both a scoped gate selection and a touched-paths list
can reach a result genuinely narrower than "all of Gate 8," not just "only Gate 8 among the 29."

This stage's own Move 4 run never carries `--gate8-touched` and stays unnarrowed by design — it
is the batch's one unconditional, full-coverage signal, and narrowing it would trade that away for
a per-batch cost reduction with no periodic full-sweep cadence yet built to compensate. Wiring
Mechanism A's own emitted directive (or `orchestrate-batch-gate.sh`'s Move 4 call site) to
actually supply touched paths is separate, not-yet-built work — this section records the
convergence point a future caller would use, not a claim that either call site uses it today.

## Trigger

A no-op (exit 0, one explanatory line, no `batch_gate` key written to the multi-task state file)
unless at least one `implement`-phase dispatch occurred this invocation. This mirrors the
"don't fire on every invocation regardless of relevance" reasoning already recorded for the
Inter-Cycle Redeploy Checkpoint (`context/patterns/batch-orchestration-guardrails.md`) — a
research-only or plan-only invocation never touches source-store files the gate would have
anything new to say about.

**Single-task and single-task-implement-dispatch invariance**: this stage's trigger is read from
the multi-task engine's own state, which a single-task implement-phase dispatch never creates and
a single-task
`/orchestrate N` populates with exactly one `implement_agents` entry — but critically, Mechanism A
(the dispatch-time deferral) is gated on `.task_numbers | length > 1` at `orchestrate-cycle-plan.sh`'s
`build_args` composition, so a single-task invocation never emits the `## Batch Gate Deferral`
directive in the first place. That task's own final phase therefore still runs the complete gate
set inline, exactly as before this design existed — this stage running afterward (or not; the
`--batch-gate-deferral` flag was never set, so there is nothing deferred to discharge) changes
nothing observable for that invocation shape. The non-negotiable invariant from
`context/formats/plan-format.md`'s `## Verification Tiers` section — the complete gate set still
runs, once, before the batch's tasks are done — is preserved by Mechanism A/B together across a
genuine multi-task batch, and by the UNCHANGED per-task final phase alone for every other
invocation shape.

## Evidence Base

The stage's evidence is `scripts/orchestrate-batch-gate.sh`'s own two-capture pipeline, built
entirely from `scripts/lib/deploy-baseline-lib.sh`'s existing functions (no new attribution logic
was added):

1. **Capture**: `deploy_findings_snapshot` at full depth (no `--skip-slow`) against the resolved
   project root, exactly once.
2. **Confirm**: a second fresh snapshot, intersected with the first via
   `deploy_baseline_confirm_new_findings` — a candidate finding that does not reproduce on this
   re-run is dropped as flaky (ambient-load-sensitive), never treated as a real regression. This
   mirrors the Inter-Cycle Redeploy Checkpoint's own load-sensitivity rationale: running the full
   gate set once already adds enough ambient load to flake a load-sensitive suite, so a single
   capture cannot be trusted to tell flaky from real.
3. **Attribute**: for every task this invocation's own `invocation_modified_files` map names
   (`scripts/orchestrate-cycle-postflight.sh`'s invocation-scoped, never-reset accumulator — see
   that script's own header comment for why `cycle_modified_files`, which the redeploy checkpoint
   resets every cycle, could not be reused here), `deploy_baseline_self_attributable_findings`
   narrows the confirmed set to the lines that positively name an identifier matching that task's
   own files. A line claimed by no task's attribution is the batch-level unattributed set —
   computed as the plain set complement against the union of every task's own attributed lines,
   deliberately NOT via `deploy_baseline_unattributable_findings`'s own narrowing filter: that
   function's documented fail-safe never prints an identifier-free line at all (it fail-safes
   toward leaving such a line blocking BY OMISSION from its own narrowed set), which is the wrong
   shape for a function whose JOB is to positively enumerate the unattributed set, including
   identifier-free lines.

## Owed-Sweep Discharge

This stage's once-per-invocation complete, unnarrowed `verify-deploy.sh` run is the ONLY event
that discharges a task's own OWED-NOT-PAID fallback obligation
(`scripts/verify-touched.sh` / `scripts/lib/unmapped-fallback-lib.sh`'s durable
`records/full-sweep-owed.jsonl` row per owed path, written when a touched-path run resolves a
path to neither a real suite nor an explicit map/class row). Owed is never forgiven: a row is
appended once and never deleted, and the only mutation ever applied to an existing row is this
stage's own discharge stamp.

**Discharge fires only when this run was clean.** Immediately after `gate_exit_code` is settled
(the same value the confirmed-findings summary line above reports), and before this script's own
`batch_gate` JSON is built: for every task number in `.task_numbers`, resolve that task's
directory (the same `find specs -maxdepth 1 -type d -name "${padded}_*"` glob
`scripts/git-snapshot.sh`/`scripts/task-lock.sh` already use elsewhere) and, if its
`records/full-sweep-owed.jsonl` exists and carries at least one row with `discharged_ts == null`,
stamp every such row with the current timestamp **if and only if** `gate_exit_code -eq 0` AND
this invocation is not `--dry-run`. A failing run (any nonzero `gate_exit_code`, including the
sentinel case) or a `--dry-run` invocation discharges NOTHING — every open row stays exactly as
it was, and is rostered into `batch_gate.owed_open_roster` instead so it is still visible in the
consolidated output.

**Carried in the `batch_gate` record**: `owed_discharged_count` (rows stamped this run, 0 when
nothing was due or the run was not clean/was dry-run), `owed_open_count` (rows still open after
this run, across every iterated task), and `owed_open_roster` (an array of `{task, path}`
objects for every row still open) — read by
`context/patterns/orchestrate-batch-results-template.md`'s Batch Gate Stage Result section to
render an undischarged owed record in the consolidated output rather than leaving it visible only
in each task's own `records/` directory.

**Why this lives here, not in a dedicated discharge script**: this stage already iterates
`.task_numbers` once for finding attribution (see "Evidence Base" above) and is the ONE place a
"this run was clean" verdict exists at all; a separate discharge pass would need to re-derive or
duplicate that verdict rather than reading it directly off `gate_exit_code`.

## Finding Severity: `FINDING ` vs. `WARN-FINDING `

The evidence pipeline's `deploy_findings_snapshot` (`scripts/lib/deploy-baseline-lib.sh`) filters
`verify-deploy.sh --findings` output with `grep '^FINDING '`, so only BLOCKING findings ever
reach this stage's capture/confirm/attribute pipeline. A gate's deliberately non-escalating
notice — gate16's `routing_hard`/`routing_agents_hard` absence guard, and gate8's all-expected
branch, both emitted via `warn_advisory()` rather than `fail()`/`warn()` — begins with the
literal token `WARN-FINDING ` instead, which that same `grep '^FINDING '` filter does not match.
Such a notice is therefore invisible to this stage's evidence base by construction: it never
becomes a batch-level unattributed finding, never blocks the batch. gate16 itself keeps running
unconditionally and reports `pass` in the ordinary case (both retired keys are fully migrated
away, so no manifest declares either any more) — the `warn_advisory()` channel exists for the
regression case, a manifest declaring either key again, not for an ongoing migration. An
ordinary `warn()` call (e.g. gate20's per-file budget-ceiling check) still emits a plain
`FINDING ` line and is still tracked by this stage like any other finding, attributed or not —
only a notice that is both non-blocking AND
perpetually-unattributable (no task's `modified_files` could ever plausibly have caused it)
needs the `WARN-FINDING ` treatment. See `verify-deploy.sh`'s own `warn()`/`warn_advisory()`
header comments for the full rationale.

**A third `WARN-FINDING ` site: gate8's contention-detected annotation.** `gate8_run()` times its
own `specs/.gate-lock` acquire wait and samples the entry 1-minute load average; when either
measured signal clears a declared, env-overridable threshold, it emits a `[CONTENTION]` stderr
note and — in `--findings` mode — a `WARN-FINDING gate8 [CONTENTION] ...` line, written directly
to the findings list rather than via an actual `warn_advisory()` call (that function also
increments `CHECKS` and forces `GATE_DIRTY_LIST`, side effects this annotation must never cause
independent of the gate's real verdict). This is annotation only, never a reclassification: the
contention signal is additive evidence that a FAIL or a slow PASS may have been influenced by
ambient contention rather than a genuine break, and it changes nothing about `fail()`/`warn()`
call sites, `CHECKS`, `FAILURES`, exit status, or the `^FINDING ` stream itself — a genuinely
failing suite still FAILs, with its ordinary `FINDING ` line, whether or not the contention tag
is also set alongside it.

## Single-Capture Distinction

`context/patterns/batch-orchestration-guardrails.md` records a REJECTED design that shared one
Gate-8 capture across the Inter-Cycle Redeploy Checkpoint's own pre/post pair, because roughly 41
of 73 Gate-8 suites resolve the DEPLOYED copy of their subject-under-test in preference to the
source-store copy — a pre-redeploy capture and a post-redeploy capture are therefore provably not
interchangeable there. This stage's sharing is safe on a different axis: it shares one capture
across sibling TASKS inside ONE already-deployed tree, after each has already committed its own
work — it never straddles a deploy boundary. The two designs differ on exactly that axis; this
stage does not re-trigger the rejection. `scripts/orchestrate-batch-gate.sh`'s own header states
this distinction again, at the point a future reader is most likely to be editing it.

## The Executable Stage Body

Executed verbatim inside Move 4, at the siting documented in `skills/skill-orchestrate/SKILL.md`'s
own Move 4 section (after `exit_status` resolution, before consolidated-output emission) — see
that file for the exact bounded-waiter invocation. In outline:

1. Resolve `mt_state_file` (already in scope at this point in Move 4 — the same file Move 1 seeded
   and every cycle's postflight has been accumulating into).
2. Invoke `scripts/orchestrate-batch-gate.sh --session "$session_id" --state-file "$mt_state_file"`
   via the bounded-waiter idiom (`context/patterns/bounded-build-waiter.md`): a captured PID, a
   `kill -0` liveness loop, an outer `timeout 540` inside a single Bash tool call whose own
   `timeout` parameter is raised to `600000`.
3. The script's own durable side effect — a `batch_gate` key added to `mt_state_file` — is read
   back, when present, by the consolidated-output renderer
   (`context/patterns/orchestrate-batch-results-template.md`'s batch-gate result section) and by
   the final `.return-meta-multi-${session_id}.json` write (`context/formats/return-metadata-file.md`).
4. No task's own `state.json` entry, status, or completion verdict is touched by this stage. A
   `batch_gate` finding — attributed or unattributed — is rendered as a BATCH-level result,
   informational to the user, never folded into one task's own completion status. Whether and how
   a future task mechanically enforces against this record is explicitly out of this contract's
   scope (see `context/formats/plan-format.md`'s Non-Goals on mechanical tier enforcement).

## Coexistence Boundary With the Conclusion Stage

This stage and Move 5's Conclusion stage (`context/contracts/conclusion-stage.md`) are disjoint
mechanisms sharing one trigger seam — both fire once per invocation, late in the loop, and
neither subsumes the other:

- This stage fires inside Move 4, strictly BEFORE Move 4's own consolidated-output emission and
  therefore strictly before Move 5 begins at all. The Conclusion stage fires strictly AFTER Move
  4's full finalization sequence has completed.
- This stage's evidence base is a fresh `verify-deploy.sh` capture; the Conclusion stage's
  evidence base is the aggregated per-task `issues.jsonl` logs. The two evidence sources do not
  overlap, and this stage's findings are never fed into the Conclusion stage's three-channel
  classification (fix-now / agent-system change / follow-up task) — a `batch_gate` finding is
  rendered in its own batch-attributed result section, never reclassified into one of the
  Conclusion stage's channels.
- Neither stage gates the other: the Conclusion stage's per-channel `AskUserQuestion` approvals
  have no bearing on whether this stage ran or what it found, and this stage never blocks Move 4
  from reaching Move 5.

**The alternative considered and rejected**: folding this stage's logic into Move 5's Conclusion
body (e.g. treating an unattributed finding as a fourth Conclusion channel). Rejected because the
Conclusion stage's entire design is gated, per-channel, user-approved action on CLASSIFIED
issue-log entries — a verify-deploy finding is not an issue-log entry and classifying it into one
of three unrelated channels would strain that design's own exactly-one-channel rule for no
benefit. This stage's job is strictly narrower (run once, attribute, record, render) and ends
before Move 5 begins, by design.

## Mechanism A's Dispatch-Time Siting

Mechanism A's `## Batch Gate Deferral` section is emitted immediately after `## Description` in
the composed dispatch file, ahead of the entire `## Artifact Round` / `## Plan` / `## Continuation`
/ `## Phase Mission` group. The reason is readability order, not mechanism: a dispatched agent
reads a composed dispatch file top-down, and the plan body (typically the single largest section
in the file) together with the phase mission both describe the WORK; the directive constrains HOW
that work's own verification step is run. An agent that reaches the plan and the phase mission
before reaching the constraint on their verification can — and, in the motivating incident, did —
start the phase's full verification run before ever reading the directive that would have scoped
it. Siting the directive ahead of the sections it constrains removes that ordering hazard
structurally, rather than relying on a careful top-to-bottom read to happen to reach it in time.

Emission remains confined to `implement`-phase dispatches via an explicit guard conjunction
(`[ "$phase" = "implement" ] && [ "$batch_gate_deferral_flag" = "true" ]`), independent of where
in the composer's output stream the section is written. The heading string,
`## Batch Gate Deferral`, is unchanged by this siting decision.

The directive's own CONSUMPTION scoping, by contrast, is no longer final-phase-only: the composer
scans `$plan_path` for every phase section declaring `**Verification Tier**: full`, regardless of
that phase's own status marker, and the rendered directive names the complete set of qualifying
phases (e.g. "Phases 2, 4 of the plan declare…"), not only the plan's literal final phase. The
previous final-phase-only scoping left any intermediate `full` phase with NO deferral coverage at
all — a dispatch scoped into such a phase read the directive, saw it name only the final phase,
and reasonably concluded it did not apply, then ran (and risked abandoning) an unscoped aggregator
sweep for a phase the directive was never written to reach. See `context/formats/plan-format.md`'s
"Batch-aware deferral" subsection for the full override contract this widened scan now satisfies.

**Two alternatives were considered and rejected**:

- **Restating the directive inside `## Phase Mission`.** Rejected because `## Phase Mission` is
  emitted only for hard mode's per-phase dispatch (gated on `--phase-number` being set) — it does
  not exist in the ordinary, non-hard-mode dispatch shape, which is exactly the shape the
  motivating incident occurred under. A restatement there could not have reached the dispatch that
  actually needed it.
- **Making the verification aggregator itself batch-aware** (having `verify-deploy.sh`, or a
  dispatch-side wrapper, detect an active multi-task batch and auto-narrow or refuse). This is the
  only alternative that would survive a reader who never reads the dispatch file's directive
  section at all, and so is the most robust in principle — but it requires a reliable,
  identity-scoped signal that a batch is currently live, and the nearest such signal (an
  `.orchestrator-multi-state-*.json` file's mere presence) has no cleanup path and so cannot be
  trusted as evidence of liveness without risking a false-positive narrowing on a genuinely
  standalone run. Rejected as not buildable fail-open today; left for a future record if a
  reliable liveness signal is designed.
