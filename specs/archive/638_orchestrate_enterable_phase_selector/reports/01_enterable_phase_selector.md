# Research Report: Task #638

**Task**: 638 - Make /orchestrate's hard-mode phase selector pick the first ENTERABLE phase, not the first heading that merely parses as open.
**Started**: 2026-11-16
**Completed**: 2026-11-16
**Effort**: medium (one selector call site, one new library alternation, new Depends-on parsing, regression fixtures)
**Dependencies**: task 547 (completed; serializes the shared-file edit, no remaining conflict)
**Sources/Inputs**: - Codebase (agent-system/extensions/core/scripts/, context/formats/, context/standards/, context/contracts/)
**Artifacts**: - specs/638_orchestrate_enterable_phase_selector/reports/01_enterable_phase_selector.md
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- The defect is real and precisely as described: `orchestrate-cycle-plan.sh`'s H1 branch (current
  line 2453, not 2393 — the file has grown since task filing) selects the first phase-heading
  matching `PHASE_HEADING_ERE .* PHASE_STATUS_OPEN_ERE` via `grep ... | head -1`, with zero
  awareness of a phase's own `Depends on:` line and zero distinction between a `[BLOCKED]`
  phase-heading that is a legitimate, already-decided, never-to-be-reentered decision gate and
  one that is merely temporarily blocked. `PHASE_STATUS_OPEN_ERE` (derived from
  `PHASE_STATUS_OPEN_ALT='NOT STARTED|IN PROGRESS|PARTIAL|BLOCKED'` in
  `scripts/lib/phase-heading-patterns.sh:120`) is confirmed the sole real consumer anywhere in
  the source store — the only other grep hit, in `agents/general-implementation-agent.md:703`,
  is a comment explaining why that file's OWN narrower, independently-defined
  `STALE_STATUS_ALT='NOT STARTED|IN PROGRESS|PARTIAL'` deliberately excludes `BLOCKED`, not an
  actual second consumer of the shared constant.
- A structured "disposition" signal for the dynamic-bypass case (a decision gate that executes,
  fails, and whose contingency branch runs instead) **already exists and is already correctly
  excluded from the selector today**: `plan-format.md`'s "Decision gates and contingency
  branches" section mandates that bypassed phases close as `[COMPLETED WITH EXCLUSIONS]` (with a
  `#### Reasoned Exclusions` record), and `COMPLETED WITH EXCLUSIONS` is already a member of
  `PHASE_STATUS_DONE_ALT`, not `PHASE_STATUS_OPEN_ALT`. This means a fix does **not** need to
  invent a new "do not enter"/"closed by exclusion" prose-disposition mechanism for that case —
  it is a pre-existing, already-structured, already-correctly-handled signal. See Findings for
  the one case that genuinely remains unhandled: a decision gate that is `[BLOCKED]` at
  plan-authoring time (never executes), which the same document treats as a *legitimate closed*
  phase-heading state sharing the same marker text as an ordinary, temporarily-blocked, possibly
  re-enterable phase — i.e. `[BLOCKED]` is overloaded between two meanings and the selector
  cannot and should not try to tell them apart; both are simply non-enterable today.
- The per-phase `**Depends on:**` field (`plan-format.md` line ~106: `none`, `1`, `1, 3`) is
  **pure prose today — no script anywhere parses it**. Its documented default when the field is
  *absent* is "depends on all prior phases" (full sequential), not "no dependency." A correct
  enterability predicate must implement this parser from scratch; nothing to extend exists.
- Regression coverage has an obvious, already-established home: `scripts/tests/test-orchestrate-cycle-plan.sh`'s
  "Group 9: H1 hard-mode per-phase dispatch" (current lines ~760–945), which already contains
  Cases A–E for the existing H1 behaviors (non-conforming heading, marker/handoff mismatch,
  successful selection, no-open-heading fallthrough, `--dry-run` parity) using a concrete,
  copyable harness idiom (`run_sut --session X --hard -- N`, a plan-file heredoc, `jqf` queries
  against `.dispatch`/`.blocked`, and `grep` against a captured `$ARGV_LOG` for
  `--phase-number`/`--territory`).

## Context & Scope

Researched the exact call site named in the task description, its sole dependent library
constant, the plan-authoring conventions that already govern phase-heading disposition
(`[BLOCKED]`, `[COMPLETED WITH EXCLUSIONS]`, `Depends on:`), whether any existing machinery
parses per-phase dependencies, and where regression tests for this exact selector already live.
Did not design the implementation (left to planning); did not touch any file (research only, per
dispatch contract). Confirmed deployed/source byte-identity for both named files via `diff -q`
before reading (source and deploy agree; `.claude/scripts/orchestrate-cycle-plan.sh` and
`.claude/scripts/lib/phase-heading-patterns.sh` are byte-identical to their
`agent-system/extensions/core/scripts/...` counterparts).

## Findings

### Codebase Patterns

- **Selector call site** — `agent-system/extensions/core/scripts/orchestrate-cycle-plan.sh:2453`:
  ```
  h1_next_heading=$(grep -E "${PHASE_HEADING_ERE} .*${PHASE_STATUS_OPEN_ERE}" "$h1_plan_path" | head -1) || true
  ```
  runs inside a per-candidate loop (`for t in "${probed_dispatch[@]}"`) that already performs, in
  order: (1) a whole-file non-conforming-heading gate (`has_nonconforming_phase_headings`,
  INCONCLUSIVE → blocked), (2) the `head -1` selection shown above, (3) `extract_phase_number` on
  the match, (4) a marker/handoff crosscheck (`PHASE_HEADING_DONE_ERE` count vs. the handoff's
  `phases_completed`) that can itself downgrade a disputed heading to `[PARTIAL]` and block the
  candidate. Any new enterability predicate slots into step (2): either replacing the single
  `head -1` grep with a loop over every heading matching the (narrower) open-marker set, checking
  each candidate's `Depends on:` closure before accepting it, or leaving steps (1)/(3)/(4)
  untouched and only changing what counts as a "hit" at step (2).
- **`PHASE_STATUS_OPEN_ALT` consumer count** — `grep -rn PHASE_STATUS_OPEN_ERE
  agent-system/extensions/` returns exactly the definition site
  (`scripts/lib/phase-heading-patterns.sh:120-122`) plus the one selector use above, plus a
  **comment-only** mention in `agents/general-implementation-agent.md:703` that explicitly notes
  its own Stage-5a stale-phase repair loop uses a **separately defined**, narrower
  `STALE_STATUS_ALT='NOT STARTED|IN PROGRESS|PARTIAL'` (excluding `BLOCKED`) *because* a `BLOCKED`
  phase must never be silently auto-repaired to `COMPLETED` by that backstop. This confirms the
  task description's claim and additionally shows that excluding `BLOCKED` from an "actionable"
  set is already established practice elsewhere in the codebase, for an analogous reason.
- **`[COMPLETED WITH EXCLUSIONS]` already closes the dynamic-bypass case** —
  `context/formats/plan-format.md`'s "Decision gates and contingency branches" section (around
  line 1080) gives a worked seven-phase example: when a gate executes and fails, every phase its
  contingency branch bypasses closes as `[COMPLETED WITH EXCLUSIONS]` with a `#### Reasoned
  Exclusions` record — explicitly **not** `[NOT STARTED]` ("exactly what deadlocks the completion
  gate") and **not** `[PARTIAL]` ("nothing about the bypassed phases is resumable or in
  progress"). `PHASE_STATUS_DONE_ALT='COMPLETED|COMPLETED WITH EXCLUSIONS'` already treats this
  as closed, so these phases are **already invisible to today's selector** (and must stay
  invisible to any new predicate too — no new work needed here).
- **`[BLOCKED]` is overloaded between two meanings at the phase-heading grain** — the same
  plan-format.md section's next subsection, "A decision gate that is already `[BLOCKED]` at
  plan-authoring time," describes a *different*, legitimate, pre-decided, permanently-closed use
  of the identical `[BLOCKED]` marker: such a gate is placed in wave 1 with `Depends on: none`
  (exempted from the transitive final-phase dependency rule precisely because "an executable
  phase cannot depend on a phase that will never complete"), and the plan's final phase is
  required to re-observe that gate's own measurement in its own verification criteria instead.
  Nothing in the phase-heading marker text itself, nor in `status-markers.md`, distinguishes this
  permanently-closed `[BLOCKED]` from an ordinary, temporarily-blocked, *possibly later
  re-enterable* `[BLOCKED]` phase (task-level `[BLOCKED]`'s own "Valid Transitions: any command
  can run from this status" note underscores that at the **task** grain blocked is routinely
  re-entered; no equivalent phase-heading-grain "valid transitions" text exists to say the same
  for a phase). Practically: the selector cannot tell these two `[BLOCKED]` meanings apart from
  the heading alone, and does not need to — in both meanings, dispatching an implement agent
  *into* a `[BLOCKED]` phase today is wrong (one case is a worked-as-designed permanent gate, the
  other is a thing waiting on an external unblock that re-dispatch cannot itself resolve by
  brute-force entry). This is consistent with the task's framing: dropping `BLOCKED` from the
  enterable set is a correct narrow component of the fix, just not sufficient alone.
- **Phase-level `Depends on:` is prose-only; no existing parser.** `grep -rn "Depends
  on\|depends_on\|DEPENDS_ON" scripts/*.sh scripts/lib/*.sh` turns up only comment coincidences
  (`orchestrate-batch-admit.sh`, `orchestrate-predispatch-review.sh` use the English word
  "Depends" in unrelated prose) and the wholly separate **task-level** `dependencies[]` /
  `--depends-on-add` machinery in `update-task-status.sh` (task-to-task edges in `state.json`,
  cycle-checked, machine-parsed) — a different grain entirely from a phase's own `**Depends
  on:**` line inside one plan file. `context/formats/plan-format.md` line ~106 documents the
  phase-level field's grammar (`none`, `1`, `1, 3`) and its default: **"Absence means sequential
  (depends on all prior phases)"** — a parser must treat a missing field as "every earlier phase
  number," not as "no dependency," or it will under-gate exactly the plans that rely on the
  documented default. The companion "Dependency Analysis" wave table (line ~380) is checked only
  for bare string presence by `scripts/validate-artifact.sh:542-544`
  (`grep -qF "Dependency Analysis"`), never parsed into a graph — confirmed by `grep -rln
  "Dependency Analysis" scripts/`, one hit, that one check.
- **Regression-test home already exists and shows the exact harness idiom.**
  `scripts/tests/test-orchestrate-cycle-plan.sh`, "Group 9: H1 hard-mode per-phase dispatch"
  (current lines ~760–945), already covers: Case A (non-conforming heading → blocked, named
  reason), Case B (marker/handoff mismatch → blocked + disputed-heading downgrade to
  `[PARTIAL]`), Case C (well-formed open heading → dispatches with `--phase-number N` and
  `--territory` in the captured dispatch argv), Case D (no open heading at all, not inconclusive
  → falls through to an ordinary, non-phase-scoped dispatch — this is the "all genuinely
  complete / not a skeleton plan" fallthrough and is explicitly **not** the same condition as
  "open headings exist but none are enterable"), and Case E (`--dry-run` parity: same blocked
  verdict, zero plan-file mutation). New fixtures for the three acceptance-criteria plan shapes
  (BLOCKED-as-closed-gate wrongly selected today; `Depends on:`-unmet `[NOT STARTED]` wrongly
  selected today; no-enterable-phase-at-all should report rather than fall through to unscoped
  dispatch) belong here, as new Group 9 cases, following the identical `write_state` /
  `mkdir -p .../plans` heredoc / `run_sut --session X --hard -- N` / `jqf` / `$ARGV_LOG` pattern
  already used by Cases A–E.
- **No per-phase operator-override mechanism exists today.** The only forcing-flag override in
  the codebase (`status-markers.md`'s "Forcing-Flag Override (decision record)" under `[HOLD]`)
  operates at the **task** grain (`task_has_forced_phase()` / `effective_group` precedence,
  admits a held *task* for exactly one dispatch) — there is no analogous per-phase force flag to
  re-admit a specific `[BLOCKED]` phase-heading. This matches the dispatch's own framing of
  open question 4 as optional, not required.
- **Dependency edge 547 → 638 is already discharged.** Task 547 ("Confirm the blocker-research
  aux carrier landed...") is `[COMPLETED]` in `specs/state.json`; its own plan's six phases are
  all `[COMPLETED]`. No remaining conflict on the shared file.

### External Resources

- None consulted — this is a pure in-repo mechanism fix; no external library or API is involved.

## Recommendations

- **Add a new, narrower alternation rather than redefining `PHASE_STATUS_OPEN_ALT`**, per the
  task's own instruction and `phase-heading-patterns.sh`'s existing export-contract convention —
  e.g. `PHASE_STATUS_ENTERABLE_MARKER_ALT='NOT STARTED|IN PROGRESS|PARTIAL'` (OPEN minus
  `BLOCKED`) plus its `_ERE` form, defined immediately beside `PHASE_STATUS_OPEN_ALT` with a
  one-line comment explaining the split (discharges the acceptance criterion that `OPEN`'s
  meaning for any other consumer is preserved and the split is deliberate and recorded in the
  library header).
- **Implement enterability as marker-in-narrower-set AND Depends-on-closure — no third
  "disposition" signal needs inventing.** Because `[COMPLETED WITH EXCLUSIONS]` already removes
  the dynamic-bypass case from the open set, and excluding `BLOCKED` already removes both
  meanings of the pre-decided/temporarily-blocked case, the remaining work is purely: for each
  heading matching the new narrower marker alternation, parse its `**Depends on:**` line (or
  default to "every phase number strictly less than this one," per the documented absence rule)
  and accept the candidate only if every named dependency's own heading marker is in
  `PHASE_STATUS_DONE_ALT`. Select the first (lowest file-order) candidate that passes both
  checks, in place of the current single `head -1`.
- **Keep the existing whole-file conformance gate, `extract_phase_number` call, and
  marker/handoff crosscheck exactly where they are** — they operate on whatever single heading
  the (now smarter) selection step produces, and nothing about the acceptance criteria asks to
  change their behavior.
- **Give "no enterable phase" its own named, blocking outcome distinct from today's Case-D
  fallthrough.** Case D ("no OPEN heading at all") must keep falling through to ordinary
  status-derived dispatch unchanged (an explicit acceptance criterion). The **new** case — one or
  more OPEN-by-marker headings exist, but none passes the enterability check — should produce a
  new `h1_blocked_reason` entry (e.g. "H1: no enterable phase — every open-marker heading in
  <plan> is either `[BLOCKED]` or has an unmet `Depends on:` prerequisite; the plan needs a
  `/revise`") rather than silently falling through to an unscoped dispatch, per the dispatch's own
  stated preference.
- **Do not special-case the pre-decided-`[BLOCKED]`-gate convention inside the selector.** Because
  `plan-format.md` already requires such a gate to declare `Depends on: none` and forbids any
  later phase from declaring a literal dependency edge onto it, excluding `BLOCKED` from the
  enterable marker set plus honest Depends-on parsing is sufficient without bespoke gate-aware
  logic — *provided* plan authors follow that documented exemption. No mechanical check enforces
  that assumption today; flagging it below as a Context Extension Recommendation (a cheap
  bonus lint), not a requirement of this task's acceptance criteria.
- **Author new fixtures as Group 9 Cases F/G/H** (or renumbered appropriately) in
  `scripts/tests/test-orchestrate-cycle-plan.sh`, reusing the exact `write_state` /
  `mkdir -p .../plans` heredoc / `run_sut --session X --hard -- N` / `jqf` / `$ARGV_LOG` idiom
  Cases A–E already establish: (F) a plan whose first OPEN-by-marker heading is `[BLOCKED]` but a
  later heading is enterable → selects the later one; (G) a plan whose first OPEN heading has an
  unmet `Depends on:` (explicit or via the absence-means-all-priors default) while a later phase's
  dependencies are all closed → selects the later, enterable one; (H) a plan with zero enterable
  phases among one-or-more OPEN headings → blocked with the new named reason, never dispatched.
  Keep Cases A–E's existing assertions passing unchanged (the acceptance criterion that
  already-enterable-first-heading behavior is unchanged).

## Decisions

- Scoped this research strictly to the selector mechanism and its direct supporting
  vocabulary/tests; did not expand into designing a per-phase operator-override flag (dispatch's
  own open question 4, explicitly optional) or into mechanically enforcing the
  `Depends-on: none`-for-pre-decided-gates convention (new, separate, bonus lint — see Context
  Extension Recommendations).
- Treated the dynamic-bypass "disposition" question as already answered by existing structure
  (`[COMPLETED WITH EXCLUSIONS]`) rather than recommending a new prose-disposition field, since
  that would duplicate a mechanism that already exists and is already correctly excluded from the
  open set.

## Risks & Mitigations

- **Risk**: a hand-rolled Depends-on parser mis-splits a combined list (`1, 3` vs `1,3` vs
  decimal sub-phases like `1.1, 2`). *Mitigation*: reuse `PHASE_NUMBER_TOKEN_ERE` (already
  exported by `phase-heading-patterns.sh` for exactly this per-token validation) to validate each
  comma-split token rather than inventing a second number grammar.
- **Risk**: changing the selector's behavior on a plan that previously fell through at Case D
  (no OPEN heading) could be accidentally widened to also catch "OPEN headings exist, none
  enterable" and dispatch unscoped anyway, silently preserving today's exact bug under a renamed
  code path. *Mitigation*: Case D's own existing test assertions (no OPEN heading → ordinary
  dispatch, no `--phase-number`) must be kept passing verbatim, and the new "no enterable phase"
  branch must be reached only when at least one OPEN-by-marker heading was found and all were
  rejected — these are two different boolean conditions and must not collapse into one check.
- **Risk**: a plan author who has NOT followed the `Depends on: none`-for-pre-decided-gates
  convention (e.g. a later phase literally names a permanently-`[BLOCKED]` gate as its own
  dependency) would see that later phase become permanently non-enterable too, through no fault
  of the new selector logic — correct behavior given the input, but potentially confusing without
  the bonus lint below. *Mitigation*: not required for this task's acceptance criteria; named as
  a follow-up.
- **Risk**: multi-wave plans (parallel waves per the Dependency Analysis table) that already
  place a later-numbered, dependency-satisfied phase after an earlier-numbered, still-open one in
  file order will, under the new predicate, start selecting the later phase instead of blocking
  on file order — this is almost certainly the *intended*, improved behavior (closer to
  cheapest-closure-first per `context/contracts/phase-closure.md`), but it is a genuine behavior
  change beyond pure bug-fixing and worth calling out explicitly to the planner as an
  in-scope, acceptance-criteria-sanctioned side effect ("a plan with an enterable phase later in
  file order selects that phase") rather than scope creep.

## Context Extension Recommendations

- **Topic**: mechanical verification that a pre-decided, permanently-`[BLOCKED]` decision gate
  (per `plan-format.md`'s "A decision gate that is already `[BLOCKED]` at plan-authoring time"
  subsection) is never named as a literal dependency by any later phase's own `Depends on:` line.
- **Gap**: today this is a documented authoring obligation with no mechanical check anywhere in
  `scripts/` or `scripts/tests/` — a plan author could violate it and nothing would surface the
  violation until the new enterability predicate (once built) silently and permanently refuses to
  enter every downstream phase.
- **Recommendation**: a small, separate lint (candidate location: alongside
  `validate-artifact.sh`'s existing "Dependency Analysis" presence check, or as a new function in
  `phase-heading-patterns.sh` itself) that cross-references every phase's `Depends on:` list
  against the marker of the named phase, flagging any dependency edge that targets a `[BLOCKED]`
  heading. Out of scope for this task; recorded here as a natural follow-up once the Depends-on
  parser this task needs to write already exists to reuse.

## Appendix

- Search queries used (all local, `rg`/`grep`/`jq` against the repo, no web search):
  - `grep -rn PHASE_STATUS_OPEN_ERE agent-system/extensions/`
  - `grep -rn "Depends on\|depends_on\|DEPENDS_ON" scripts/*.sh scripts/lib/*.sh scripts/tests/*.sh`
  - `grep -rln "Dependency Analysis" scripts/`
  - `grep -rn "h1_next_phase\|H1:\|hard-mode per-phase\|next_heading" scripts/tests/*.sh`
  - `grep -rn "not re-entered\|closed by exclusion\|disposition table\|do not enter\|DO NOT ENTER" context/ scripts/` (zero hits — confirms no existing structured "disposition" vocabulary beyond `[COMPLETED WITH EXCLUSIONS]` and the `[BLOCKED]`-at-authoring-time convention)
  - `diff -q agent-system/extensions/core/scripts/orchestrate-cycle-plan.sh .claude/scripts/orchestrate-cycle-plan.sh` and the matching `phase-heading-patterns.sh` pair (both byte-identical, confirming the source/deploy claim at task filing)
- Files read in full or in relevant part: `scripts/orchestrate-cycle-plan.sh` (lines ~2300–2620),
  `scripts/lib/phase-heading-patterns.sh` (full), `agents/general-implementation-agent.md`
  (lines ~670–730), `context/contracts/phase-closure.md` (full), `context/formats/plan-format.md`
  (lines ~1080–1170, plus the `Depends on:`/Dependency-Analysis field definitions), `context/standards/status-markers.md`
  (`[BLOCKED]`, `[HOLD]`/Forcing-Flag-Override, `[COMPLETED WITH EXCLUSIONS]`, phase-level vs.
  task-level marker sections), `scripts/tests/test-orchestrate-cycle-plan.sh` (Group 9, lines
  ~760–945), `scripts/validate-artifact.sh` (Dependency Analysis check), `scripts/update-task-status.sh`
  (task-level `--depends-on-add`, to confirm it is a different grain), `specs/state.json` (task
  547/638 status and dependency edge).
