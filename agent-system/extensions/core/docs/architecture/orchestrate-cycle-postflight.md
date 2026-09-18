# orchestrate-cycle-postflight.sh: Unified Per-Task Postflight

**Status**: Current architecture — result of Phase 7 of the task that built
`orchestrate-cycle-postflight.sh` (Stage A.4 of `specs/PATH.md`, "The four moves per cycle").

**See Also**: `handoff-schema.md`, `orchestrate-state-machine.md`

---

## Overview

`orchestrate-cycle-postflight.sh` performs everything the `/orchestrate` lead does after a single
dispatched agent returns, for BOTH engines (single-task `skill-orchestrate/SKILL.md` Stage 5 and
multi-task Stage MT-4's per-task postflight). It is the third and last of the per-cycle scripts,
alongside `orchestrate-build-dispatch.sh` (pre-dispatch) and `orchestrate-cycle-plan.sh`
(dispatch-plan composition). Before this script existed, single-task Stage 5 and multi-task
Stage MT-4 each carried an independently-maintained copy of this logic; the two bodies had
already drifted (Stage 5 had a staleness gate and a `dispatch_seq` identity gate, Stage MT-4 had
neither) before this script closed the gap by construction — both engines now call the ONE
implementation, so they are structurally incapable of disagreeing on gate semantics again.

Both `skill-orchestrate/SKILL.md`'s Stage 5 and Stage MT-4 call this script and consume its
compact JSON output; neither carries its own copy of the logic below any more. See the script's
own header comment for the authoritative, line-numbered WORK (a)–(k) list; this document is the
narrative account of WHY each piece exists and how the two callers apply what the script does
not and must not own.

**WORK (k), added by the task that ported single-task-only features into the batch engine**:
when `--hard` is given, the script calls `orchestrate-churn.sh` with this cycle's
`dispatch_status`/`blockers`/`phases_completed` and, on a three-strikes audit REQUEST, persists it
to `aux_pending[task]` in the resolved state store (`$defect_store` — the same
loop-guard-file-or-multi-state-file resolution WORK (d) already uses). In base mode, a `partial`
outcome below 70% phase completion records a `drift-inspection` aux signal instead (mutually
exclusive with the churn branch by construction, since `hard_mode` is one flag for the whole
cycle). Independent of either mode, `verdict=blocked` records a `blocker-research` aux signal
carrying `state.json`'s own `.blockers` description. All three are informational-only — they
never change `verdict`, `halt`, or `infra_exempt_cycle`, and this script never dispatches
anything; the NEXT cycle's `orchestrate-cycle-plan.sh` is what turns a recorded `aux_pending`
entry into an `aux_dispatch[]` row (Decision 2 of that task's plan).

## What The Script Owns vs. What The Callers Own

The script performs the ENTIRE post-dispatch pipeline: the stray-handoff sweep, the mtime
staleness gate, the `dispatch_seq` identity gate, `.return-meta.json` recovery
(`dispatch_seq`-aware), phase-count corroboration, writer-contract-aware defect recording,
`user_decision` relay, status transition with the completion-claim gate, artifact link + round
advance, the `modified_files`-vs-`file_scope` excursion advisory, and the per-task scoped commit.

The callers (single-task Stage 5, multi-task Stage MT-4) keep ONLY what the script does not and
must not own:

- **The loop-control decision** (`EXIT (partial)` / `cycle_count` increment) — a script boundary
  must never silently absorb an orchestrator loop-control transition. The script computes and
  prints a `verdict`, `halt`, and `infra_exempt_cycle`; the caller applies them.
- **Defect 6's marker/handoff crosscheck** (base-mode single-task only) and **Stage 5b's
  churn/blockers read** (hard mode only) — both need the handoff's raw `blockers[]` array and/or
  full JSON, which the script's compact output does not carry (Context Flatness Constraint — the
  script's own contract is a compact status summary, never a pass-through of handoff content).
  Both callers re-derive their own tiny, read-only, gate-respecting view of the already-fetched
  handoff (the same mtime + `dispatch_seq` check the script itself already applied and already
  recorded defects for) rather than asking the script to carry more surface area.
- **`user_decision` surfacing to the human** — the script relays the payload verbatim as
  verdict `ask_user` and never asks or decides; the caller puts the question to the user exactly
  once, batched at the end of the current cycle. See `context/standards/user-decision-contract.md`
  for the full contract.

## Context Flatness: What Each Read Is Bounded To

The two files read per dispatch are `.orchestrator-handoff.json` (≤400 tokens) and, on the
missing/stale-handoff path only, `.return-meta.json`. This bounds THIS SCRIPT's own input reads
to ~450 tokens per cycle regardless of artifact complexity — enforced entirely inside the script
now, not duplicated across two engine bodies. (This is the script's own read ceiling, not the
lead's total per-cycle context growth, which also includes the cycle-plan JSON and the Move 2
dispatch prompt — see `docs/architecture/orchestrate-state-machine.md`'s `## Context Flatness
Guarantee` for that measured, larger figure.)

### Recovery exception (return-meta fallback)

When — and only when — the handoff is missing or stale, the script consults
`orchestrate-recover-outcome.sh`, which reads `<task_dir>/.return-meta.json` and returns a
single-line JSON object of scalar fields.

- **Fields-only**: `status`, `artifacts[0].path/type/summary`, `phases_completed`,
  `phases_total` — never a report, plan, summary, or handoff file's content.
- **Missing/stale-handoff-branch-only precondition**: fires only where the handoff read has
  already failed, never as a routine per-cycle read and never a substitute for reading a handoff
  that is present and fresh.
- **Token ceiling**: one JSON object of ~10 scalar fields, well under 100 tokens per recovery
  event.
- **Authoritative, unlike the phase-marker grep below**: a `recovered=true` outcome DOES
  synthesize a `dispatch_status` and DOES drive the normal postflight status transition —
  `.return-meta.json` is the file every research/plan/base-implement dispatch already writes as
  its own contractual success signal. This is the one place the two recovery exceptions diverge:
  the phase-marker grep below is diagnostic-only and never moves `state.json`, while this
  exception is the ONLY thing standing between "no handoff" and "task stranded."

### Recovery exception (phase-marker grep)

When — and only when — the handoff is missing or stale AND return-meta recovery above also
declined, the script MAY run at most two count-only `grep -c` calls against the plan file's
`### Phase N: {name} [STATUS]` heading lines to recover `phases_completed` / `phases_total`.

- **Count-only**: `grep -c`, never `grep`. No matched line content ever enters context — two
  calls return one integer each, a hard ceiling of ≤10 tokens per recovery event.
- **Heading lines only**: patterns anchor on `^### Phase N: `. Checklist items, prose, deviation
  annotations, and every other part of the plan file remain out of scope.
- **Three reachable branches, never elsewhere**:
  1. The missing/stale-handoff branch, after return-meta recovery has already declined — the raw
     inline two-`grep -c` idiom directly (diagnostic-only; never sets `plan_markers_verified` and
     never calls the shared function, since there is no recoverable `dispatch_status` to
     corroborate against).
  2. The `recovered=true` branch, but ONLY when return-meta recovery's own
     `evidence_suspect`/`evidence_reason` fields report `PHASES_ZERO_ON_SUCCESS` for a claimed
     `implemented` status — widening the exception's trigger to a scenario branch (1)
     structurally cannot see, since branch (1) requires `recovered=false`.
  3. The handoff-present branch, but ONLY when the handoff itself reports
     `dispatch_status = "implemented"` AND `phases_total -eq 0` — a scenario branches (1) and (2)
     structurally cannot see, since both require the handoff to be missing, stale, or recovered
     from `.return-meta.json` rather than read directly.

  Branches (2) and (3) both call the SAME shared `skill_corroborate_phase_counts`
  (`scripts/skill-base.sh`), which performs the same two `grep -c` calls inside itself rather
  than inline — the single anchor both branches share, the same way
  `scripts/lib/phase-heading-patterns.sh` is the single grammar anchor every phase-heading
  consumer sources rather than re-deriving.

  Branch (2)'s `recovered=true` site also carries a sibling `elif` arm on
  `evidence_reason="ARTIFACTS_SHAPE_MISMATCH"` (a `system-defect-record.sh` consumer call) — it
  shares branch (2)'s `recovered=true` precondition but never calls
  `skill_corroborate_phase_counts` and performs no `grep -c` of any kind, so it does not add a
  fourth reachable branch. Branch (3), the handoff-present path, ALSO calls
  `orchestrate-recover-outcome.sh` — as an ADVISORY EVIDENCE PROBE ONLY, immediately after its
  own PHASES_ZERO_ON_SUCCESS-style corroboration block. The probe reads only
  `evidence_suspect`/`evidence_reason` from a separate `.return-meta.json` read (if any exists
  for this dispatch) and ignores every other field the script returns; it never overrides the
  handoff-derived outcome, never changes `dispatch_status`, and never drives a status transition.
  On a fired `ARTIFACTS_SHAPE_MISMATCH` signal its sole effect mirrors branch (2)'s own arm for
  the same class: a loud `EVIDENCE:` stderr notice plus a non-fatal `system-defect-record.sh`
  call and a `detected_defects` log entry. Exit 1 and exit 2 from the probe (no recoverable
  `.return-meta.json`, or a usage/jq error) are both treated as "no signal available" and are not
  escalated — a handoff-present dispatch legitimately may have nothing left to probe.

- **Diagnostic in branch (1), evidence-based escalation in branches (2) and (3)**: in branch (1)
  the recovered counts are logged and recorded in the defect store only — they never synthesize a
  `dispatch_status` and never drive a status transition, since there is no recoverable outcome to
  trust. In branches (2) and (3) a *corroborating* grep result (heading count matches the claimed
  phase count exactly, or the plan is fully closed) DOES set `plan_markers_verified="true"` and
  corrects `phases_completed`/`phases_total` for the completion-claim gate to act on — the
  correction is always sourced from an independent artifact (the plan file), never from the
  off-schema value itself. A non-corroborating result in branch (2) or (3) is treated identically
  to branch (1): diagnostic-only, `plan_markers_verified` stays `absent`.

These three named branches are the ONLY places the report/plan/summary reading constraint is
narrowed for phase-marker recovery; it stays fully in force outside them. The normal path — a
fresh handoff with `phases_total > 0` or an already-populated `plan_markers_verified` — reads no
plan file at all, so the ~450-tokens-per-cycle flatness invariant is unaffected there.

## Writer-Contract Determination (D1) and dispatch_seq Recovery (D2)

See `handoff-schema.md`'s own "Writer-Contract Determination (D1)" section (immediately following
the "Handoff Writers" table) for the dispatch-derived `--handoff-expected true|false` predicate
(default `true`, no agent-name allowlist) and the D2 rationale for threading `dispatch_seq`
through `.return-meta.json` recovery too, not just the live handoff gate.

## The `halt` / `infra_exempt_cycle` Output Fields

The script's compact JSON output (`{task, phase, status, phases_completed, phases_total, verdict,
user_decision?, halt, infra_exempt_cycle, note}`) carries two boolean fields a bare `verdict`
string cannot express unambiguously:

- **`halt`**: true only when `dispatch_status` was off-schema (garbage/unrecognized) — the ONE
  case that still means "stop the whole `/orchestrate` invocation," mirroring the single-task
  engine's historical inline `EXIT (partial)`. A genuine in-vocabulary `verdict="failed"`
  (`dispatch_status="failed"`) leaves `halt=false` — the task stays in-flight for the next cycle.
  Multi-task mode reads `halt` for logging only; an off-schema outcome for one task in a batch is
  charged to that task's own `failed_tasks` membership (already applied inside the script's own
  WORK (j), gated to multi-task mode) and never halts sibling tasks in the same wave.
- **`infra_exempt_cycle`**: true only when this cycle was exempted from the `cycle_count` budget
  by the corroborated infra-failure discrimination (two corroborating signals required — see
  `context/patterns/infra-failure-discrimination.md`). Every other `verdict="defer"` (a partial
  dispatch, or an `implemented` outcome with the completion-claim gate refused) charges a cycle
  normally.

## Stray-Handoff Sweep (Phase 7 Addition)

Historically single-task-only (`orchestrate-stage5-gates.sh`, called only from single-task
Stage 5). A mechanism-agnostic backstop for a handoff written outside its task directory (the
`validate-handoff-location.sh` PostToolUse hook cannot see a Bash-redirect write). Bounded to two
exact paths (repo root, `specs/`), never a recursive find. Absorbed into
`orchestrate-cycle-postflight.sh` itself at Phase 7 cutover time so BOTH engines get it, rather
than left single-task-only via a bolted-on second call site, or dropped entirely for
multi-task's sake. Runs unconditionally, every call, never gated on the handoff staleness gate
(a stray file sits OUTSIDE the expected `handoff_file` path and this check never touches that
path at all).

## force / force_invoked (A2, Multi-Task)

Multi-task's `orchestrate-cycle-plan.sh` tracks each task's own `force_phases_remaining` queue
and pops the next forced phase off it at the moment that task's dispatch row is built — the ONLY
point in the pipeline where "was this task's phase forced this cycle" is still observable, since
the queue is already popped by the time postflight runs. `orchestrate-cycle-plan.sh`'s dispatch
rows therefore carry a `force` boolean field (Phase 7 addition), threaded by Stage MT-4's postflight
call as `--force-invoked`, mirroring single-task Stage 5's own `force_invoked` (A2) semantics for
the monotonic-max status clamp and the forced-dispatch artifact-round advance.

## What Remains Orphaned

`orchestrate-stage5-gates.sh` and `orchestrate-stage5-postflight.sh` have zero call sites after
the Phase 7 cutover (their sole caller, single-task Stage 5's own inline gate pair and postflight
tail, was replaced by the single script call this document describes). They are left in the tree,
untouched — deleting orphaned single-task-engine scripts is explicitly out of this task's
Non-Goals ("Deleting the single-task engine ... both engines call this script until then").
