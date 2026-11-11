# Research Report: Task #430

**Task**: 430 - Feed observed-but-undeclared implement paths back into a task's declared
`file_scope` instead of silently dropping them from phase commits
**Started**: 2026-11-07T22:15:10Z
**Completed**: 2026-11-07T23:10:00Z
**Effort**: ~1.5 hours
**Dependencies**: 362, 394, 395, 425, 428, 494 (all confirmed `[COMPLETED]`/archived; no blocking work remains)
**Sources/Inputs**: Codebase (source store `agent-system/extensions/core/`), six archived sibling-task summaries, `specs/state.json`
**Artifacts**: this report
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- `git-commit-phase.sh` already computes, synchronously and in-hand, exactly which
  `files_touched` paths it is about to drop for containment at the moment it drops them — this is
  a strictly more reliable signal than relying on the implementing agent to notice and self-report
  the same paths later, and it is the same "mechanize over instructing" move the script's own
  header comment already documents for the derivation step itself.
- The existing `proposed_file_scope` channel (`.return-meta.json` top-level field, consumed by
  `update-task-status.sh --file-scope-add` inside its single mutex-guarded `state-write.sh`
  write) is the right channel to extend — not a reason to invent a parallel one. Its restriction
  to `research` is enforced in exactly two places (a validation gate in `update-task-status.sh`
  and a branch condition in `skill-base.sh`'s live `skill_postflight_update()`), both small,
  mechanical edits, not an architectural rework.
- Recommended ruling: git-commit-phase.sh, at drop time, writes every dropped path into the
  task's own `.return-meta.json`'s `proposed_file_scope` (flock-guarded read-modify-write,
  fail-open on any error), reversing today's producer-ownership direction for that field on the
  implement path — the SCRIPT becomes the producer, and `general-implementation-agent`'s own
  final Stage 7 write becomes the LATER writer that must preserve it, not originate it.
- Auto-merge (no operator confirmation gate), matching research's existing precedent, is the
  defensible ruling: the evidence backing an implement-phase proposal (an actual, already-landed
  commit from THIS task's own dispatch) is strictly stronger than research's own proposal
  (a prediction of future need), and the admission-gate overlap-masking risk this choice is
  sometimes weighed against is not a new risk class — it is the identical, already-accepted risk
  research's own auto-merge carries today, just extended to one more phase.
- Task 394 (the file_scope-containment chokepoint in `git-commit-scoped.sh`, named in this
  dispatch's territory edges as moving containment in "the OPPOSITE direction") is **already
  landed**, and landed as a second, redundant drop-and-warn gate (exit 7 on commit-succeeded-
  with-drops) — not a refusal. The ordering/reconciliation concern the dispatch raised
  speculatively before 394 shipped does not apply: there is no refusal to race against.

## Context & Scope

Researched the exact mechanics of the containment drop in `git-commit-phase.sh`, the existing
(research-only) `proposed_file_scope` feedback channel and its two forwarding call sites, the
current validation gate restricting that channel to `research`/`plan`, and the six tasks this
dispatch's territory-edges/dependencies sections name as neighbors — to confirm which are already
landed (all six), what they actually changed (as opposed to what the dispatch's own speculative
framing anticipated), and where this task's design must reconcile with or build on them.

## Findings

### Codebase Patterns

**The drop site** (`agent-system/extensions/core/scripts/git-commit-phase.sh:270-290`): after
deriving `files_touched` from the phase progress file and widening `file_scope_arr` with the
task's own directory and the engine-written-state allowlist, the script loops over each
`files_touched` entry, tests `is_contained`, and for every failing entry does exactly three
things in order: emit a `WARNING:` to stderr, call `issue-record.sh --class "scope excursion"`
non-fatally, and drop the path from `kept_files_touched`. The loop variable `f` at the point of
the `warn`/`issue-record.sh` call is the exact, authoritative dropped-path value — nothing
downstream needs to re-derive or re-discover it.

**`proposed_file_scope` today** (`context/formats/return-metadata-file.md:519-548`): optional
top-level `string[]` in `.return-meta.json`, additions-only, union-merged by
`update-task-status.sh`'s `--file-scope-add` flag inside its existing mutex-guarded write, with
an explicit "Include if: the operation is `research` ... Unused and absent for `plan` and
`implement` operations" restriction. Two forwarding call sites both carry this same restriction
as a literal branch condition:
- `orchestrator-postflight.sh:329-349` — **this script has no live caller** (its own header
  comment says so explicitly: "implement did this inline in the now-deleted base lifecycle
  implement skill before calling this script (historical; this script has no current caller)").
  Its `if operation_type == "research"` branch reads `proposed_file_scope`; an `elif
  operation_type == "plan"` branch harvests from the plan artifact instead; there is no
  `implement` arm.
- `skill-base.sh`'s `skill_postflight_update()` (the actually-live path, confirmed by its real
  callers in `orchestrate-cycle-postflight.sh` and `orchestrate-stage5-postflight.sh`, which pass
  `operation="implement"` literally on the live implement-postflight call) — same two-armed
  `if operation == "research" ... elif operation == "plan"` shape at lines ~1049-1073, inside
  the `case "$status" in researched|planned|implemented)` block that DOES already run for
  `implemented`. There is simply no third arm for `implement`; the branch falls through with
  `_fsa_args=()` and the forward is silently skipped.

**The validation gate** (`update-task-status.sh:333-348`): `--file-scope-add`'s value is
validated as a JSON string array unconditionally, then a second check hard-errors ("naming both
permitted target statuses") unless `operation == postflight && target_status in {research,
plan}`. This is the single mechanical chokepoint that would need its allowed set widened to
include `implement` — the merge logic itself (lines ~1140-1160, a plain jq union on
`active_projects[].file_scope`, scoped by `project_number`, riding inside the one
`state-write.sh` call) is already status-agnostic and needs no change.

**A latent spec inconsistency worth flagging**: `return-metadata-file.md`'s own "Multiple
Sequential Writers" section (line 65) already lists `proposed_file_scope` among the fields
"producer-owned by the implementation agent" — language that reads as already anticipating a
non-research producer, even though the field's own dedicated subsection two pages later still
says "Unused and absent for ... `implement` operations." The two passages were never reconciled.
This is not strong evidence of original design intent either way, but it does mean extending the
field to `implement` closes an existing internal inconsistency rather than opening a new one.

**Mechanize-over-instructing precedent, in the same file**: `git-commit-phase.sh`'s own header
comment documents, as its explicit founding rationale, that a prose "remember to do X"
instruction fired 0/8 times in one measured run, while moving the identical step inside a script
every caller must already invoke fired 16/16 in the same class of run. Relying on the
implementing agent to notice a stderr warning and later remember to list the same path in its own
`proposed_file_scope` reproduces exactly the failure mode this task's own root cause describes
("The dispatched agent had to notice the drop itself..."). Sourcing the proposal mechanically
from the script's own drop-time loop variable is the same fix pattern already proven in this
exact file, not a new technique being introduced.

### Containment is drop-and-warn at two layers, not one — and the second layer already landed

Three sites in this codebase apply a file_scope Containment predicate: `git-commit-phase.sh`'s
own self-check (interim, now redundant), V10 inside `git-commit-scoped.sh` (the durable answer,
landed by task 394), and `orchestrate-cycle-postflight.sh`'s WORK (h)/(i) (postflight-only, out
of reach for a mid-dispatch phase commit — see `git-staging-scope.md`'s "Phase Commit
(mid-dispatch)" subsection). Task 394's summary states explicitly: "`git-commit-phase.sh`'s own
Phase-Commit Containment Self-Check is left in place as a deliberately redundant, non-load-
bearing belt-and-suspenders check — V10 now structurally subsumes its reach for every caller
that forwards `--task` (which it always does)." Both layers are drop-and-warn; V10's reserved
exit code 7 means "commit succeeded, but one or more paths were dropped," never a refusal.

This matters for this dispatch's own TERRITORY EDGES section, which named the chokepoint record
as "mov[ing] containment in the OPPOSITE direction... with exception code 7 reserved for it" and
warned that "if that record lands a refusal where today there is a drop, this record's situation
stops being twenty warnings and becomes a failed commit." That record has already landed, and it
did not land a refusal. There is no reconciliation hazard left to resolve here: whichever path
`git-commit-phase.sh` keeps after its self-check (today) or after the proposed widened
`file_scope` takes effect (post-430), V10 re-evaluates containment independently against the
same `state.json` `file_scope` and will reach the same contained/uncontained verdict — once a
path is genuinely merged into the task's declared scope, both layers stop dropping it together,
with no risk of one layer refusing while the other commits.

### The six named/dependency tasks are all landed; none conflicts

| Task | Title | Status | Relevance here |
|---|---|---|---|
| 394 | file_scope-containment chokepoint (`git-commit-scoped.sh` V10) | COMPLETED | Second containment layer; drop-and-warn, not refusal (see above) |
| 395 | surface failed per-cycle commit into task status | COMPLETED | Commit-failure status demotion; unrelated to scope-widening |
| 425 | state files dropped as file_scope excursions | COMPLETED | Landed a **literal, static** allowlist splice (`specs/TODO.md`, `specs/state.json`) in `orchestrate-cycle-postflight.sh`'s WORK (h) — this is the "classification distinguishing legitimate-but-undeclared from genuine excursion" the territory edges reference. It is a hardcoded admit-list, not a general mechanism; this task's dynamic, drop-time-sourced proposal is the natural generalization of the same idea (an admitted-as-legitimate set), not a duplicate of it. |
| 428 | enforce planner-agent terminal write | COMPLETED | Ordering dependency only; no file overlap found |
| 494 | phase-commit task-own-artifact scope carve-out | COMPLETED | Landed the "own-task-directory member" splice already visible in `git-commit-phase.sh`'s current source (confirmed read in place); no further action needed |
| 362 | shared-worktree history-read discipline | COMPLETED | Already added Critical-Requirements MUST-NOT item 16 to `general-implementation-agent.md`; this task must re-read the file's **current** state before editing it (done — see Mechanics above) but there is no content conflict, only a shared-file ordering note that is already resolved by 362 having landed first |

No duplicate-absorption candidate exists among these six; the dispatch's own duplicate-check
(performed by the orchestrate lead before dispatch) is confirmed correct by this independent
re-check.

## Decisions

- **Reuse the existing `proposed_file_scope` channel for `implement`** rather than inventing a
  parallel one — see Decision 1 below for the full mechanics.
- **Source the proposal from `git-commit-phase.sh`'s own drop-time computation**, not from
  agent self-report, per the "mechanize over instructing" precedent already established in that
  same script.
- **Auto-merge, no operator confirmation gate** — see Decision 2 below for the full
  justification.
- **No change to the existing drop-and-warn visibility** — see Decision 3 below.

## Recommendations

**Decision 1 — Channel and source**: Extend the existing `proposed_file_scope` channel to
`implement`, rather than inventing a parallel one, and source it from `git-commit-phase.sh`'s own
drop-time loop (the containment-dropped set), not from agent self-report. Concretely:

1. `git-commit-phase.sh`, immediately after (not instead of) the existing `warn` +
   `issue-record.sh` call for a dropped path, performs a flock-guarded read-modify-write against
   `${task_dir}/.return-meta.json`: read the current `proposed_file_scope` array (defaulting to
   `[]` on missing/malformed/absent), append the dropped path if not already present, write back.
   Fail-open on any error (missing file, invalid JSON, lock timeout) — log a non-fatal warning
   and proceed with the commit exactly as today; this must never be allowed to affect the commit
   itself or its exit code.
2. `update-task-status.sh`'s validation gate (line ~345) widens its accepted `target_status` set
   for `--file-scope-add` from `{research, plan}` to `{research, plan, implement}`.
3. `skill-base.sh`'s `skill_postflight_update()` gains an `elif operation == "implement"` arm
   (mirroring the existing `research` arm exactly: read `${_task_dir}/.return-meta.json`'s
   `proposed_file_scope`, forward as `--file-scope-add` if non-empty).
4. `orchestrator-postflight.sh`'s dead `implement` gap is left as-is (it has no live caller;
   touching it would be cosmetic-only and is not required by the hard constraints) — but note
   this explicitly in the plan so a future reader does not mistake the omission for an oversight.
5. `return-metadata-file.md`'s `proposed_file_scope` subsection is rewritten to permit `implement`
   explicitly, and — this is the one genuinely new piece of prose needed — to say plainly that on
   the implement path the field is **producer-owned by `git-commit-phase.sh`, not by the
   implementing agent**, reversing today's stated direction for that one operation. The existing
   "Multiple Sequential Writers" general section already requires every writer after the first to
   read-modify-write rather than overwrite; this is the concrete instance that makes that
   requirement bite for `general-implementation-agent`'s own Stage 7 (`agents/general-
   implementation-agent.md`, "Write Metadata File"): before that final `Write` call, the agent
   must read any `proposed_file_scope` already present (deposited mid-dispatch by
   `git-commit-phase.sh`) and carry it through into its own final write untouched — never a blind
   overwrite from a freshly-built object that silently drops it.

**Decision 2 — Auto-merge, no operator confirmation gate.** Reuse research's existing silent
auto-merge, visible only via `update-task-status.sh`'s existing non-blocking `[file-scope]`
stderr notice (`emit_file_scope_notice`, already reports the post-merge delta count and paths).
Justification: (a) the hard constraint already directs preserving `proposed_file_scope`'s
existing semantics "if that channel is the one extended" — there is no existing infrastructure
for a confirmation-gated variant of this one merge path, and building one would be a materially
larger, unrequested scope increase; (b) the evidence standard here is *stronger* than research's
own trigger — a path only reaches this proposal because it was actually, already committed as
real work in this task's own dispatch, not merely predicted; (c) the admission-gate overlap risk
named in the dispatch (file_scope is also "the batch admission gate's conflict-detection input")
is not a *new* risk introduced by this extension — `research`'s own `proposed_file_scope` already
carries the identical blind-union-merge-with-no-cross-task-check exposure today, so extending the
mechanism to one more phase does not change the risk's kind, only (very slightly) its frequency;
(d) a genuine net *benefit* was found, not just a managed cost: `batch-orchestration-guardrails.md`
documents that lock-acquisition-time conflict detection compares a task's live `file_scope`
against every *other currently-held* lock's `file_scope` on every acquire throughout the task's
lifecycle (not only at creation) — so a path this task is already, demonstrably touching but has
never declared is today an *undetected* blind spot for a future colliding task's own admission
check; widening `file_scope` to match reality closes that blind spot rather than opening one.

**Decision 3 — Visibility.** No change to the existing drop-and-warn behavior: the `WARNING:` and
the `issue-record.sh --class "scope excursion"` call both fire unconditionally on every drop,
exactly as today, regardless of whether the path is also being proposed forward. The proposal is
additive to, never a replacement for, the existing warning. A path that recurs *within the same
phase* (multiple objectives touching it before the phase-ending postflight runs) is still dropped
and warned on each occurrence — the structural fix is for *subsequent phases/dispatches*, which
is exactly the shape of the twenty-firing incident this task exists to close (all twenty were
"dropped on every subsequent phase," not within one objective).

## Risks & Mitigations

- **New writer of `.return-meta.json` mid-dispatch.** No script in this source store currently
  writes `.return-meta.json` outside the owning agent itself; `git-commit-phase.sh` writing it
  (even just one field) is a genuinely new pattern. Mitigation: flock-guard the read-modify-write
  (mirroring `errors-append.sh`'s and `events-append.sh`'s existing `flock -x` precedent on
  per-task files), keep the write strictly additive/idempotent (skip if already present), and
  make every failure mode fail-open and silent to the commit's own exit code — the hard
  constraint that this check must never become fatal extends naturally to this new write path.
- **A genuine scope excursion also gets proposed forward**, since the script cannot
  semantically distinguish "legitimate but undeclared work" from "a real mistake/excursion" at
  drop time — both look identical (an uncontained `files_touched` entry). This is a real,
  accepted cost, not eliminable without new semantic input the script does not have. It is
  bounded by: the path must already be `files_touched`-reported by the SAME dispatching agent in
  THIS task's own phase (not an arbitrary path), the warning still fires so a human reviewing
  issues.jsonl at the conclusion stage still sees every such event, and the `[file-scope]` widen
  notice names exactly what was absorbed.
- **`issues.jsonl` is explicitly CAPTURE ONLY** (`context/formats/issue-log.md`: "Nothing is
  surfaced to the user mid-run. No proposal is generated, no gate is added, no task status is
  changed... do not add one here by analogy to any other log in this codebase"). This rules out
  sourcing the proposal by reading back `issues.jsonl` entries after the fact — which this report
  confirms is also unnecessary, since `git-commit-phase.sh` already has the exact path in hand
  synchronously at drop time and never needs to read its own emitted log to recover it. The
  design in Decision 1 does not touch `issues.jsonl`'s read path at all, so this boundary is
  observed by construction, not by special-casing.

## Context Extension Recommendations

- **Topic**: file_scope producer-ownership reversal for one field on one operation.
- **Gap**: `context/formats/return-metadata-file.md`'s "Multiple Sequential Writers" section
  states a blanket "producer-owned by the implementation agent" for `proposed_file_scope` that
  does not match its own field-specific "research-only" restriction two sections later; neither
  passage anticipates a non-agent (script) producer. The plan phase following this report should
  resolve both inconsistencies in the same edit, not just add the `implement` case alongside the
  unreconciled older text.
- **Recommendation**: when `return-metadata-file.md` is edited for Decision 1 item 5 above, also
  correct the "Multiple Sequential Writers" list's description of `proposed_file_scope` so it
  names its actual per-operation producer (`general-research-agent` for `research`;
  `git-commit-phase.sh` for `implement`) rather than a single blanket "the implementation agent."

## Appendix

- Files read in full or in relevant part: `scripts/git-commit-phase.sh`,
  `context/formats/return-metadata-file.md`, `scripts/orchestrator-postflight.sh`,
  `scripts/skill-base.sh` (lines ~976-1090), `scripts/update-task-status.sh` (lines ~280-400,
  ~975-1160), `agents/general-implementation-agent.md` (lines ~380-460, ~790-900),
  `context/standards/git-staging-scope.md` (lines ~132-225), `context/formats/issue-log.md`
  (lines ~47-100, ~189-230), `context/patterns/batch-orchestration-guardrails.md` (file_scope
  references), `scripts/lib/return-meta-artifacts-lib.sh`.
- Archived summaries read in full: tasks 394, 395, 425, 428 (skimmed), 494 (skimmed via code
  cross-reference), 362.
- `specs/state.json` queried for task 430's own current `file_scope`, `dependencies`, and status,
  and for each dependency's resolution to its archive directory.
