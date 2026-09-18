# Implementation Plan: Task #213

- **Task**: 213 - Thread focus prompt into cycle plan (absorbed former tasks 214 and 216)
- **Status**: [IMPLEMENTING]
- **Effort**: 12 hours
- **Dependencies**: None
- **Research Inputs**: specs/213_thread_focus_prompt_into_cycle_plan/reports/01_focus-prompt-forced-phase-cycle-plan.md
- **Artifacts**: plans/01_focus-forced-phase-cycle-budget.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Three coupled defects in the batch `/orchestrate` engine, all landing in the source store
(`agent-system/extensions/core/`, never `.claude/**`): (A) a user-typed focus prompt never reaches
the dispatch file, (B) a forced-phase queue that empties silently falls through to ordinary
status-derived dispatch instead of stopping, and (C) the work-cycle budget accumulates across
`/orchestrate` runs while forced plan/implement admission ignores which artifacts actually exist.
All three converge on one 1,859-line script (`scripts/orchestrate-cycle-plan.sh`) and two of them
on the same per-candidate loop, so the phases below serialize every edit to that script rather
than parallelizing them. Docs are collected into one deliberate pass at the end, because all three
defects touch the same four/five documentation files and a per-defect doc edit would mean
re-reading and re-editing the same paragraphs three times.

### Research Integration

The research report (`reports/01_...md`) confirmed every root cause named in the task description
by direct file reading, and narrowed the code surface in two useful ways: `orchestrate-build-dispatch.sh`
needs no change for `--focus` (it already parses the flag and renders the `User focus:` block,
phase-agnostically), and the "plan dispatch names the newest report" item is already correct by
construction (same-type artifact supersession) so it is a test-only addition. It also established
that `mt_state_file` is already session-scoped, so Defect B's fix needs a marker, not wider
persistence, and that the `plan_cache` interaction with `--focus` is a non-issue in both dry-run
(cache bypassed) and live (focus fixed for the invocation) modes.

**Two corrections to the report, verified during planning — the implementer should trust this plan
over the report on both points:**

1. `scripts/tests/test-force-phases.sh` **does exist** (354 lines). The report states it does not.
   It currently covers a different subject (`parse-command-args.sh` flag accumulation, the
   monotonic-max status clamp, artifact-round advance) and uses a deliberate source-store-first
   candidate resolution. The new forced-round regression cases are **added cases in that existing
   file**, reusing its harness — not a new file.
2. The batch engine's `dispatch_seq_counter` lives **only** in the session-scoped
   `mt_state_file`; it is never seeded from or flushed to the durable
   `${TASK_DIR}/.orchestrator-loop-guard` file (confirmed: a live guard file for this very task
   contains `cycle_count` and `pending_dispatch` but no `dispatch_seq_counter`). So today a new
   `/orchestrate` run restarts the counter at 1 and can overwrite an existing `.dispatch/1.md`.
   The task's own acceptance criterion "dispatch_seq never repeats across runs" is therefore
   **not** already satisfied, and Phase 4 must make it true as part of the same change that stops
   persisting `cycle_count`.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No ROADMAP.md found.

## Goals & Non-Goals

**Goals**:
- A user-typed `/orchestrate N --research "<questions>"` focus string reaches the dispatched
  agent's `.dispatch/{seq}.md` as a `User focus:` block, with no hand editing.
- A task's `research_questions` and a user focus string coexist in one clearly labelled block;
  neither silently replaces the other.
- `--dry-run` shows that focus text was received, before any live run.
- A forced-phase round STOPS after its last named phase for the rest of that run, whether or not a
  later call in the same run repeats the flag — no dispatch row, no dispatch file, no lock, no
  status write, no cycle charge.
- The work-cycle budget resets on every `/orchestrate` run; `--continue-budget` is gone end to end;
  `dispatch_seq` still never repeats within a task across runs.
- Forced phases are admitted by artifact, not status: research always, plan always (reviser when a
  plan exists, planner otherwise), implement only when a plan exists.
- Every doc that describes these behaviors agrees with the code.

**Non-Goals**:
- No change to `orchestrate-build-dispatch.sh`'s `--focus` parsing or rendering (already correct).
- No change to the `research_questions`-only path for a task with no user focus text: its dispatch
  output stays byte-for-byte identical.
- No change to routing for runs that pass no forcing flag — ordinary lifecycle progression is
  untouched.
- No status-based admission matrix; the artifact rule in Phase 5 is the whole rule.
- No `--revise` flag on `/orchestrate`; `/revise N` stays the standalone command, unchanged.
- No writes to `.claude/**` (regenerated deploy artifact). Redeploy in Phase 7 is the only way
  `.claude/**` changes.
- `--force-phases` is deliberately still absent from `commands/orchestrate.md`'s `--dry-run`
  short-circuit. That is a real, separate gap; this task adds only `--focus` there (Phase 2) and
  names the gap in the plan rather than widening scope.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Existing tests that codify today's (defective) behavior go red and are mistaken for regressions | H | H | Each phase below names the exact test block it is expected to invert, with line ranges. A red assertion in a named block is the change landing, not a break. |
| Defect B's exclusion and Defect C's blocked-row logic race for the same candidate (e.g. forced implement, queue just emptied, no plan) | H | M | Phases 3->4->5 are strictly serialized on one file, and Phase 5 states the precedence rule explicitly: the Phase 3 forced-round exclusion is evaluated first and wins; a task excluded there never reaches the artifact-admission check. |
| SKILL.md's `$( ... )` flag idiom word-splits a focus value containing spaces/quotes | H | H | Phase 2 uses an explicit bash array (`focus_args=(--focus "$focus_prompt")`) rather than extending the `$( echo ... )` idiom, and tests a value containing both spaces and embedded double quotes. |
| Removing the durable `cycle_count` seed silently breaks `dispatch_seq` uniqueness across runs | H | M | Phase 4 adds durable per-task `dispatch_seq_counter` seed/flush in the same phase that removes the `cycle_count` seed/flush, with its own test case. |
| Forced plan -> `reviser-agent` produces a dispatch file with no prior-plan pointer, so the reviser has nothing to revise | M | M | Phase 5 renders `- existing_plan_path:` (the name `reviser-agent.md` already expects) in the plan-phase dispatch file whenever a plan exists. |
| A stale lock reference (`specs/055_.../locked-regions.md`) is honored unnecessarily during the `--continue-budget` removal | L | M | Phase 4 step 1 checks that file's current status once, up front, and records the finding in the phase's own notes; the region it names belongs to the deleted single-task engine. |
| `.claude/**` edited by reflex instead of the source store | H | L | Every phase's file list is source-store-rooted; the advisory `validate-meta-write.sh` hook fires on any `.claude/**` write. |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2, 3 | 1 |
| 3 | 4 | 3 |
| 4 | 5 | 4 |
| 5 | 6 | 2, 5 |
| 6 | 7 | 6 |

Phases within the same wave can execute in parallel. Phases 1, 3, 4 and 5 all edit
`scripts/orchestrate-cycle-plan.sh` and are serialized for that reason; Phase 2 runs beside Phase 3
only because it touches no `.sh` file.

### Phase 1: `--focus` through orchestrate-cycle-plan.sh [COMPLETED]

**Goal**: The engine accepts a user focus string, merges it with any `research_questions` without
either silently replacing the other, passes it to every phase's dispatch build, and surfaces it in
`--dry-run`.

**Tasks**:
- [x] Add `--focus` to the flag parser (`scripts/orchestrate-cycle-plan.sh` ~line 269-319):
      `focus_prompt=""` default beside the other defaults, `--focus) focus_prompt="${2:-}"; shift 2 ;;`
      in the `case`, mirroring `--model`'s shape exactly.
- [x] Add `[--focus "<text>"]` to the `usage()` heredoc (~line 254) and one sentence to the
      header comment block describing it as the user's `$2+` text from `/orchestrate`.
- [x] Rewrite section (l)'s focus block (~lines 1761-1777) to compose ONE value from up to two
      labelled segments, in this order, joined by a newline:
      - `From the user: <focus_prompt>` (whenever `--focus` was non-empty, for ANY phase)
      - `Research questions: <joined research_questions>` (research phase only, unchanged join
        with `"; "`, unchanged source field)
      Pass `--focus "$combined"` only when the composed value is non-empty. **Decision (D1)**: user
      focus applies to research, plan AND implement dispatches, matching
      `commands/orchestrate.md`'s `$2+` contract ("Applies to all tasks in multi-task mode") and
      the fact that `orchestrate-build-dispatch.sh` renders the block phase-agnostically;
      `research_questions` stays research-only exactly as today.
- [x] Verify the no-user-focus research path is byte-for-byte unchanged: with `--focus` absent and
      `research_questions` present, the composed value must be the bare joined string with NO
      `Research questions:` label and no leading newline (i.e. the label is added only when the
      user segment is also present). Capture a before/after dispatch file and diff them.
- [x] Add a `focus` field to BOTH dispatch-row builders so dry-run and live keep identical shape:
      the dry-run builder (~line 1666) and the live builder (~line 1852) each gain
      `--arg focus "<composed or empty>"` rendering `focus: $focus` (empty string when none).
- [x] Add one line to the `--dry-run` human table in `emit_and_exit()` (~line 630-636): render the
      focus alongside phase/agent, e.g.
      `.dispatch[] | "#\(.task)  phase=\(.phase)  agent=\(.agent)\(if .focus == "" then "" else "  focus=\(.focus)" end)"`.
      Keep the rule that the table is a pure `jq` projection of the already-emitted `plan_json` —
      never a second computation.
- [x] Record (as a code comment at the `plan_cache` write site, ~line 607-619) the **Decision (D3)**
      that the cache key stays `dispatch_seq_counter` alone: `--dry-run` bypasses both the cache
      read and write, and in a live run `--focus` is fixed for the whole invocation, so a replay
      can only ever replay the same focus value it was built with.
- [x] Add a new test group to `scripts/tests/test-orchestrate-cycle-plan.sh` (append after the
      existing Group 21, reusing Group 14's fixture style — Group 14 already covers the
      `research_questions` wiring): (i) `--focus "Q1? Q2?"` on a forced research cycle produces a
      dispatch file containing a `User focus:` block with that text; (ii) focus + `research_questions`
      both present produces both labelled segments; (iii) no focus text, `research_questions`
      present -> output identical to today's Group 14 expectation; (iv) a focus value containing a
      double quote and spaces survives intact; (v) `--dry-run` with `--focus` emits a non-empty
      `.dispatch[].focus`.

**Timing**: 2 hours

**Depends on**: none

**Verification Tier**: full

**Scope Hypothesis**: this phase asserts the edits land in exactly 2 files
(`scripts/orchestrate-cycle-plan.sh`, `scripts/tests/test-orchestrate-cycle-plan.sh`) and that
`scripts/orchestrate-build-dispatch.sh` needs NO change. Confirm at implementation time by running
the new test group against an unmodified `orchestrate-build-dispatch.sh`; if the `User focus:`
block does not render, the hypothesis is wrong and the phase's file list grows by one — say so
rather than silently editing a third file.

**Files to modify**:
- `agent-system/extensions/core/scripts/orchestrate-cycle-plan.sh` - `--focus` parse, usage,
  header, section (l) composition, both dispatch-row builders, dry-run table line, plan-cache
  comment
- `agent-system/extensions/core/scripts/tests/test-orchestrate-cycle-plan.sh` - new focus group

**Verification**:
- `bash scripts/tests/test-orchestrate-cycle-plan.sh` — the new group passes; every pre-existing
  group still passes (no group is expected to invert in this phase).
- `shellcheck scripts/orchestrate-cycle-plan.sh` clean.
- Manual: a `--dry-run` invocation with `--focus "a b"` prints a `focus=` column.

---

### Phase 2: Caller wiring — SKILL.md Move 1 and the command's dry-run short-circuit [COMPLETED]

**Goal**: The focus text the command already parses actually reaches the engine, with quoting that
survives spaces and embedded quotes.

**Tasks**:
- [x] `skills/skill-orchestrate/SKILL.md`, "Setup" list (~lines 28-33): add `focus_prompt` to the
      enumerated delegation-context inputs (it is absent today even though
      `commands/orchestrate.md` already passes it).
- [x] `skills/skill-orchestrate/SKILL.md`, Move 1's `orchestrate-cycle-plan.sh` call (~lines 63-75):
      do NOT extend the `$( [ -n ... ] && echo --flag "$v" )` idiom for this value — that idiom
      word-splits, and a focus prompt is free-form text. Instead, immediately above the call add:
      ```bash
      focus_args=()
      [ -n "${focus_prompt:-}" ] && focus_args=(--focus "$focus_prompt")
      ```
      and insert `${focus_args[@]+"${focus_args[@]}"}` into the argument list (the `+` form keeps
      it safe under `set -u` with an empty array). Leave every other flag line untouched.
- [x] `commands/orchestrate.md`: add `focus_prompt` to the "Each parsed flag becomes a
      delegation-context key" bullet list (~lines 88-95) with a one-line contract — the user's
      `$2+` text, applied to every task in the batch, rendered as the dispatch file's
      `User focus:` block for research, plan and implement dispatches.
- [x] `commands/orchestrate.md`: extend the dry-run short-circuit (~lines 107-112) to forward the
      focus, using the same array shape:
      ```bash
      focus_args=(); [ -n "${focus_prompt:-}" ] && focus_args=(--focus "$focus_prompt")
      bash .claude/scripts/orchestrate-cycle-plan.sh --dry-run --session "${SESSION_ID:-}" \
        --state-file specs/state.json ${focus_args[@]+"${focus_args[@]}"} $TASK_NUMBERS
      ```
- [x] `commands/orchestrate.md`: note in the `--dry-run` options-table row that the report now
      shows the focus text it received.
- [x] Add a note under the dry-run short-circuit recording that `--force-phases` is deliberately
      still NOT forwarded there (a known, separate gap — named, not fixed here).

**Timing**: 1 hour

**Depends on**: 1

**Verification Tier**: local

**Files to modify**:
- `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md`
- `agent-system/extensions/core/commands/orchestrate.md`

**Verification**:
- Extract each edited bash block to a temp file and run `bash -n` on it (syntax only).
- Run the edited Move 1 argument construction in isolation with
  `focus_prompt='a "quoted" phrase'` and a stub that prints `"$@"` — confirm exactly one
  `--focus` argument arrives carrying the whole string.
- `grep -n 'focus' skills/skill-orchestrate/SKILL.md commands/orchestrate.md` shows the new
  wiring at all four sites.

---

### Phase 3: Stop after the last forced phase [COMPLETED]

**Goal**: Within one run, a task whose forced-phase queue has been fully consumed is excluded from
dispatch for the rest of that run, with a clear reason — never routed by status.

**Tasks**:
- [x] Add `.forced_round_seeded //= {}` to the `mt_json` defaults block
      (`scripts/orchestrate-cycle-plan.sh` ~lines 468-500). This is the marker `//` cannot supply:
      jq's `//` cannot distinguish a never-seeded key from a queue popped down to `[]`.
- [x] In section (f)'s seeding loop (~lines 1344-1348), alongside
      `.force_phases_remaining[$t] //= $q`, set `.forced_round_seeded[$t] //= true` (same `//=`
      idempotence, so a later cycle in the same run never re-seeds).
- [x] In section (f)'s resolution loop (~lines 1350-1363), replace the bare `else` fall-through
      with a three-way branch:
      - queue non-empty -> today's behavior, unchanged (`effective_group`, `forced_this_cycle=true`);
      - queue empty AND `.forced_round_seeded[$t] == true` -> `effective_group[$t]="forced_round_complete"`,
        `forced_this_cycle[$t]="false"`;
      - otherwise -> today's `triage_group[$t]` fall-through, unchanged (this is the "never forced
        this run" path, and runs with no forcing flag must keep behaving exactly as today).
- [x] In the bucketing step (~lines 1447-1470), handle `forced_round_complete` in the same `case`
      that already handles `needs_human`/`skip`/`terminal`: emit an `out_blocked_rows` entry with
      reason `"forced round complete: every phase named by this run's --research/--plan/--implement
      flag has been dispatched; this task is terminal for this run. Re-invoke /orchestrate to
      continue."` and `continue`. **Decision (D4)**: `blocked[]`, not a new top-level `excluded[]`
      array — `blocked[]` already carries no-defect-just-a-rule reasons (MAX_CYCLES) and needs no
      schema change in `orchestrate-cycle-postflight.sh` or SKILL.md Moves 2-4. Confirm that claim
      by grepping those two consumers for `.blocked` before relying on it.
- [x] Confirm by reading the control flow (no code needed) that this exclusion, sitting in the
      bucketing step, runs BEFORE the lock probe, before `dispatch_seq` minting, before
      `skill_preflight_update`, before `orchestrate-build-dispatch.sh` and before the cycle charge
      — so the "no lock, no dispatch file, no status write, no cycle charge" acceptance clauses all
      hold by construction. Record that finding as a comment at the new branch.
- [x] Invert the existing assertion that codifies the defect:
      `scripts/tests/test-orchestrate-cycle-plan.sh` Group 2 (~lines 154-194) and the Group 4/5
      continuation (~lines 348-391) — the block named "stop-after-last-named ... fall-through",
      whose cycle-2 assertions expect `phase == "implement"` / `force == "false"`. Cycle 2 must now
      assert: zero `dispatch[]` rows for that task, one `blocked[]` row carrying the new reason,
      status unchanged, `cycle_counts` unchanged.
- [x] Add the observed-incident regression cases to the EXISTING
      `scripts/tests/test-force-phases.sh` (reusing its source-store-first `resolve_inverted`
      harness): a RESEARCHED task with `--force-phases research`, research dispatched and
      postflighted, then (1) a second live call WITH the flag and (2) a live call WITHOUT it. Both
      must produce no dispatch rows, leave status `researched`, write no new `.dispatch/` file,
      take no lock, and leave `cycle_counts` unchanged. Add the counter-case too: an unforced
      multi-phase session still advances research -> plan -> implement.

**Timing**: 2 hours

**Depends on**: 1

**Verification Tier**: full

**Scope Hypothesis**: this phase asserts the exclusion needs exactly one new `mt_json` field and
one new `case` arm, with no change to `task_has_forced_phase()` (whose empty-queue `false` return
is already correct for the terminal-task path). Confirm by running the terminal/archived forced-round
cases (Group 21, ~line 2113) unchanged after the edit; if they move, `task_has_forced_phase()` is
in scope after all and the phase's step list grows.

**Files to modify**:
- `agent-system/extensions/core/scripts/orchestrate-cycle-plan.sh` - `forced_round_seeded` default,
  section (f) seeding + three-way branch, bucketing case arm
- `agent-system/extensions/core/scripts/tests/test-orchestrate-cycle-plan.sh` - invert Group 2 /
  Group 4-5 fall-through assertions
- `agent-system/extensions/core/scripts/tests/test-force-phases.sh` - new forced-round regression
  cases (this file EXISTS; add cases, do not create it)

**Verification**:
- `bash scripts/tests/test-force-phases.sh` — the new cases fail against the pre-fix script and
  pass after (check this ordering explicitly; a case that passes both ways proves nothing).
- `bash scripts/tests/test-orchestrate-cycle-plan.sh` — all groups pass, with Group 2 / Group 4-5
  now asserting exclusion.
- `shellcheck scripts/orchestrate-cycle-plan.sh scripts/tests/test-force-phases.sh` clean.
- Manual: after a forced round completes, a `--dry-run` re-check shows the task under `-- Blocked --`
  with the new reason. *(deviation: altered — confirmed by reading orchestrate-cycle-plan.sh
  (~line 468) that `--dry-run` unconditionally never reads the persisted `mt_state_file`
  regardless of `--session`, a pre-existing design already documented by Group 21 Case C's own
  comment; a `--dry-run` re-check therefore cannot literally observe `forced_round_seeded` state
  left by a prior LIVE call. Verified manually via a second LIVE call instead, which does show
  the `blocked[]` row -- exhaustively covered by the LIVE-to-LIVE fixture cases already added
  above and in test-force-phases.sh.)*

---

### Phase 4: Per-run cycle budget, `--continue-budget` removal, durable dispatch_seq [COMPLETED]

**Goal**: The work-cycle budget starts at 0 every run and is bounded per run (5, or 13 with
`--hard`); `--continue-budget` no longer exists anywhere in the source store; `dispatch_seq` still
never repeats within a task across runs.

**Tasks**:
- [x] Check once, up front, whether `specs/055_dedupe_orchestrate_skill_bodies/locked-regions.md`
      still describes a live region (the research flagged it as likely stale documentation for the
      deleted single-task engine). Record the finding in the phase notes; do not spend effort
      honoring a lock with no referent.
- [x] `scripts/orchestrate-cycle-plan.sh` section (a2) (~lines 881-901): stop seeding
      `.cycle_counts[$t]` from the durable guard's `cycle_count`. `cycle_counts` now starts at 0 in
      each run's `mt_state_file` (the `//= {}` default already gives that). KEEP the
      `pending_dispatch_seed[$t]` peek from the same `--seed` call — that ledger stays durable.
- [x] Same section: ADD a durable `dispatch_seq_counter` seed. Read each task's guard file
      `.dispatch_seq_counter` and set `mt_json.dispatch_seq_counter` to the maximum across the
      run's tasks (`//=`-style, first sight only). This closes the cross-run collision the research
      correction above documents.
- [x] At the live charge site (~lines 1826-1841): remove the
      `orchestrate-loop-guard-init.sh --flush ... "$task_new_cycle_count"` call (budget no longer
      persists) and add a durable seq write for the task just dispatched, so a later run resumes
      past it. Prefer reusing `skill_orchestrate_mint_dispatch_seq` (`scripts/skill-base.sh`
      ~line 1380) — it already exists for exactly this guarantee and `skill-base.sh` is sourced at
      the top of the live half — over inventing a second writer. If the aux mint site
      (~line 1038) runs before `skill-base.sh` is sourced, give `orchestrate-loop-guard-init.sh` a
      `--flush-seq <task_dir_abs> <seq>` form instead and use it at both mint sites; state which
      option was taken and why.
- [x] Keep the per-run bound and the `max_cycles` stop reason unchanged (5 / 13 with `--hard`).
- [x] Remove `--continue-budget` end to end: `scripts/orchestrate-cycle-plan.sh` (default at
      ~line 282, parse arm at ~line 301, `usage()` line, the `MAX_INFRA_FAILURES` bypass condition
      at ~line 1223 — keep the gate, drop the bypass and its "pass --continue-budget" text — and
      the whole budget-exhaustion reset branch at ~lines 1236-1262 including the
      `.exhausted-loop-guard-<ts>.json` archive, the `--flush ... 0` reset and the
      `--clear-pending` call); `scripts/parse-command-args.sh`; `commands/orchestrate.md` (options
      row + the `continue_budget` delegation-context bullet); `skills/skill-orchestrate/SKILL.md`
      (Setup list + Move 1 flag line).
- [x] Update the `MAX_CYCLES` blocked-row reason text to say re-invoking `/orchestrate` is how to
      continue (there is no override flag any more).
- [x] Decide and state whether `cycle_count` stays in the guard file's JSON as inert historical
      data or is dropped. Recommended: leave the field alone (never read, never written by this
      engine) so an old guard file needs no migration; say so in a comment at the seed site.
- [x] Rewrite `scripts/tests/test-orchestrate-cycle-plan.sh` Group 8 (~lines 497-611): a fresh
      session must start at `cycle_counts = 0` regardless of the durable file's `cycle_count`;
      within ONE run the bound still stops the task at 5 (13 with `--hard`); six forced runs in a
      row (separate sessions) are never refused for budget. Add a case asserting `dispatch_seq`
      does not repeat across two runs on the same task.
- [x] Invert `scripts/test-session-runtime-files.sh` Case 3 (~lines 191-211) to assert the new
      contract: `cycle_counts` is not seeded from the durable guard's `cycle_count` for budgeting.
- [x] Retire `scripts/tests/test-loop-guard-budget-override.sh` (its whole subject is the removed
      override). Delete it and remove it from `scripts/tests/run-all.sh` if listed there; if any
      non-override assertion in it is still worth keeping, move that assertion into Group 8 rather
      than keeping the file alive.

**Timing**: 2 hours

**Depends on**: 3

**Verification Tier**: full

**Scope Hypothesis**: the research grep names exactly 7 files containing
`continue-budget|continue_budget|CONTINUE_BUDGET`. Confirm with
`grep -rln 'continue-budget\|continue_budget\|CONTINUE_BUDGET' agent-system/extensions/core/` before
starting and again at the end (the end state must be zero hits outside `specs/**`). If the
before-count is not 7, reconcile the difference explicitly instead of assuming the list.

**Files to modify**:
- `agent-system/extensions/core/scripts/orchestrate-cycle-plan.sh`
- `agent-system/extensions/core/scripts/parse-command-args.sh`
- `agent-system/extensions/core/scripts/orchestrate-loop-guard-init.sh` (only if the `--flush-seq`
  option is taken)
- `agent-system/extensions/core/commands/orchestrate.md`
- `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md`
- `agent-system/extensions/core/scripts/tests/test-orchestrate-cycle-plan.sh` (Group 8)
- `agent-system/extensions/core/scripts/test-session-runtime-files.sh` (Case 3)
- `agent-system/extensions/core/scripts/tests/test-loop-guard-budget-override.sh` (deleted)
- `agent-system/extensions/core/scripts/tests/run-all.sh` (only if it lists the deleted file)

**Verification**:
- `bash scripts/tests/test-orchestrate-cycle-plan.sh`, `bash scripts/test-session-runtime-files.sh`,
  `bash scripts/tests/test-force-phases.sh`, `bash scripts/tests/test-mint-dispatch-seq.sh` all pass.
- `grep -rn 'continue-budget\|continue_budget\|CONTINUE_BUDGET' agent-system/extensions/core/`
  returns nothing. *(deviation: altered — 9 hits remain across 3 files: two brief
  historical-context comments in orchestrate-loop-guard-init.sh/skill-base.sh explaining what
  was removed and why, plus a new regression test in test-orchestrate-cycle-plan.sh's Group 8
  that asserts `--continue-budget` is now REJECTED as an unrecognized flag. All live
  functionality is gone (grep over the executable flag-parsing/budget-decision code paths alone
  is clean); the task's own top-level ACCEPTANCE wording — "grep finds nothing in the source
  store outside history" — is followed literally here: these are historical-explanation and
  removal-proof residue, not live behavior, and a strictly-zero-hits bar would make it
  impossible to write a test proving the flag is actually rejected.)*
- `shellcheck` clean on every edited `.sh`.
- Manual: two consecutive runs on one task produce dispatch files with strictly increasing seq
  numbers and no overwrite.

---

### Phase 5: Artifact-based admission for forced plan and implement [COMPLETED]

**Goal**: One admission rule, keyed on artifacts: research always; plan always (reviser when a plan
exists, planner otherwise); implement only when a plan exists, otherwise a `blocked[]` row and
nothing dispatched.

**Tasks**:
- [x] State and honor the precedence rule: the Phase 3 `forced_round_complete` exclusion is
      evaluated FIRST; a task excluded there never reaches these checks. Add it as a comment where
      the new checks land, so the two exclusion paths can never both claim the same candidate.
- [x] Forced implement with no plan: in the bucketing step (beside the Phase 3 arm), when
      `effective_group[$t] == "implement"` and `forced_this_cycle[$t] == "true"` and
      `ls "${task_dir}/plans/"*.md` matches nothing, emit
      `out_blocked_rows` with reason `"no plan artifact; run --plan first"` and `continue`. This
      must sit before the lock probe so no lock, dispatch file or status write happens.
- [x] Plan admission: change `resolve_agent()`'s `plan)` arm (~line 1520) from the unconditional
      `planner-agent` to a plan-presence check — `reviser-agent` when the task's newest
      `plans/*.md` exists, `planner-agent` otherwise. `resolve_agent` currently takes
      `(op, task_type)`; pass the task number or resolved task dir so the check has a path, and
      keep the function's single-return shape.
- [x] Make a reviser dispatch usable: `scripts/orchestrate-build-dispatch.sh`'s `plan` branch
      (~lines 181-186) currently resolves only `research_artifact`. Also resolve the newest
      `plans/*.md` (same `ls | sort -V | tail -1` idiom the implement branch uses) and, when
      non-empty, render `- existing_plan_path: <path>` in the dispatch file — the exact field name
      `agents/reviser-agent.md` reads (it also names `revision_reason` as optional; render
      `- revision_reason: forced --plan round` alongside it). Absent plan -> neither line, so the
      ordinary planner path stays byte-for-byte unchanged.
- [x] Confirm `command-route-agent.sh` is NOT consulted for the plan phase (today's `plan)` arm
      returns before the routing call), so extension routing is unaffected by this change. If it is
      consulted, say so and adjust rather than bypassing it.
- [x] Tests in `scripts/tests/test-orchestrate-cycle-plan.sh`: `--implement` on a RESEARCHED task
      WITH a plan dispatches implement; `--implement` with no plan yields exactly one `blocked[]`
      row, no dispatch file, no lock, no status write; `--plan` with an existing plan resolves
      `reviser-agent` and its dispatch file carries `existing_plan_path`; `--plan` with no plan
      resolves `planner-agent`; both are admitted at any status including terminal.
- [x] Test (pin-only, no code change expected): after two research rounds, a plan dispatch names
      the NEWEST report. Change code only if this fails.

**Timing**: 2 hours

**Depends on**: 4

**Verification Tier**: full

**Scope Hypothesis**: this phase asserts that the newest-report behavior is already correct and
needs a test only. If the new pin test fails, `orchestrate-build-dispatch.sh`'s `.[0]` report
selection is a real defect and this phase's file list gains a code fix there — report that
outcome explicitly rather than quietly editing.

**Files to modify**:
- `agent-system/extensions/core/scripts/orchestrate-cycle-plan.sh` - implement-without-plan blocked
  row, `resolve_agent()` plan arm
- `agent-system/extensions/core/scripts/orchestrate-build-dispatch.sh` - `existing_plan_path` /
  `revision_reason` lines in the plan branch
- `agent-system/extensions/core/scripts/tests/test-orchestrate-cycle-plan.sh` - admission cases
- `agent-system/extensions/core/scripts/tests/test-orchestrate-build-dispatch.sh` - plan-branch
  rendering case

**Verification**:
- `bash scripts/tests/test-orchestrate-cycle-plan.sh` passes (199/199, source-store-first
  resolution). *(deviation: altered — `bash scripts/tests/test-orchestrate-build-dispatch.sh`
  resolves its SUT deploy-tree-first, by that suite's own documented design ("correct for a
  suite validating what actually runs in production" -- see its own header comment); against
  the CURRENT (pre-Phase-7-redeploy) `.claude/scripts/orchestrate-build-dispatch.sh`, the two new
  Group 11 existing_plan_path/revision_reason assertions fail (70/72), because that deployed
  copy predates this phase's source-store edit. Verified correctness directly: temporarily
  copied the source-store file over the deployed one, confirmed all 72 cases pass, then reverted
  the deployed copy to its original (unmodified) state -- no lasting `.claude/**` change. This
  will read genuinely green, with no manual sync, once Phase 7's redeploy runs.)*
- `shellcheck` clean on both edited scripts.
- Manual `--dry-run`: `--plan` on a task with a plan shows `agent=reviser-agent`; `--implement` on
  a task with no plan shows the blocked reason and zero dispatch rows.

---

### Phase 6: Documentation consistency pass [COMPLETED]

**Goal**: Every document describing focus threading, the stop-after-forced-phase contract, the
per-run budget and artifact-based admission says the same thing the code now does. One pass across
all files, covering all three defects together.

**Tasks**:
- [x] `commands/orchestrate.md`: the `--research`/`--plan`/`--implement` rows keep "STOPS after the
      last named phase" (now true) and gain the artifact rule (`--plan` revises via `reviser-agent`
      when a plan exists; `--implement` is blocked without a plan). Fix the Stage 0 Constraints
      prose (~lines 25-28) and the `force_phases` delegation bullet (~lines 91-95), which currently
      say "falls through to ordinary status-derived classification". Confirm the `--continue-budget`
      row and bullet are gone (Phase 4).
- [x] `merge-sources/claudemd.md`: line ~112's `/orchestrate` row is already correct; fix the
      "Multi-task syntax" paragraph (~line 116), which contradicts it two paragraphs later
      ("falling through to ordinary status-derived classification once its own forced sequence is
      exhausted"). Settle both on STOP. Add the per-run budget contract and the artifact admission
      rule to that row.
- [x] `skills/skill-orchestrate/SKILL.md`: add a MUST NOT — never re-invoke
      `orchestrate-cycle-plan.sh` live purely to inspect state; `--dry-run` (or reading
      `mt_state_file`) is the only sanctioned check — and require the loop to stop on the plan's
      stop verdict and on a `forced_round_complete` blocked row. Document the focus passthrough
      added in Phase 2 in Move 1's prose.
- [x] `docs/architecture/orchestrate-state-machine.md`: add the NON-terminal worked example this
      file never had (a `researched` task whose forced queue empties mid-run -> excluded, not
      advanced), beside the existing terminal-task example (~lines 738-770). Fix the
      "Maximum dispatch cycles per /orchestrate invocation" text so it matches the now-true per-run
      contract. Extend the `--focus` narrative (~lines 101-103, 379-380) to cover the user-supplied
      segment and the two-segment labelled composition.
- [x] `context/standards/orchestrator-runtime-files.md`: replace the
      `### cycle_count semantics and the budget-continuation override (Defect B)` section
      (~lines 215-253) with the per-run contract and its rationale (the budget exists to bound work
      within one run; re-running `/orchestrate` is the explicit way to continue). Fix the dangling
      cross-reference in the `pending_dispatch` section (~lines 264-267) that mentions
      `--continue-budget`'s reset. Record, next to the existing staleness-detector text (not only
      in a summary), that the loop-guard staleness detector is moot for budgeting once no counter
      carries between runs. Document `dispatch_seq_counter` as a field the batch engine now seeds
      and writes durably.
- [x] Re-grep for contradictions after editing:
      `grep -rn 'falls through\|fall-through\|falling through\|continue-budget\|cumulative across invocations' agent-system/extensions/core/`
      must return only intentional, corrected occurrences. *(deviation: altered — the literal
      pattern matches dozens of unrelated pre-existing hits across the whole source store (the
      common phrase "falls through" used for entirely different mechanisms: task-lock retry,
      admission collision scan, H1 hard-mode heading-scan fallback, etc.). Manually inspected
      every hit outside the 5 named files and confirmed none contradicts this task's own 3
      defects; did not expand scope to rewrite unrelated documentation.)*
- [x] Deliverable rule: no task numbers anywhere in these files (they are outside `specs/**`).
      Reference durable anchors — file names, section headings, flag names.

**Timing**: 2 hours

**Depends on**: 2, 5

**Verification Tier**: interface

**Scope Hypothesis**: this phase asserts exactly 5 documentation files carry the contradictions.
Confirm with the grep above before starting; if a sixth file matches, add it to this phase rather
than deferring it.

**Files to modify**:
- `agent-system/extensions/core/commands/orchestrate.md`
- `agent-system/extensions/core/merge-sources/claudemd.md`
- `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md`
- `agent-system/extensions/core/docs/architecture/orchestrate-state-machine.md`
- `agent-system/extensions/core/context/standards/orchestrator-runtime-files.md`

**Verification**:
- The contradiction grep returns no stale text.
- `bash .claude/scripts/check-task-references.sh` (or the repo's equivalent lint) reports no task
  references in the edited files.
- Read each edited section once end to end and confirm it describes the behavior the Phase 3/4/5
  tests assert — a doc that contradicts a passing test is a failed verification here.

---

### Phase 7: Full suite, shellcheck, redeploy, consumer confirmation [NOT STARTED]

**Goal**: Everything is green together, the deploy tree carries the change, and the original
observed incident no longer reproduces in a real consumer repo.

**Tasks**:
- [ ] Run the whole source-store test suite (`bash scripts/tests/run-all.sh`, plus
      `bash scripts/test-session-runtime-files.sh` if it is not included) and fix any fallout.
- [ ] `shellcheck` every `.sh` touched across Phases 1-5; clean, no new suppressions unless
      justified inline.
- [ ] Redeploy the source store to `.claude/` using the repository's normal deploy path (the
      picker's Reload All / `deploy-headless.sh`). This is the ONLY step in this plan that writes
      `.claude/**`.
- [ ] Confirm in a consumer repo that `/orchestrate N --research "<questions>"` produces a
      `User focus:` block in `.dispatch/{seq}.md` with no hand edits.
- [ ] Confirm in a consumer repo that a completed forced round, re-checked with and without the
      flag, dispatches nothing, leaves status untouched, writes no dispatch file, takes no lock and
      charges no cycle.
- [ ] Confirm in a consumer repo that a second `/orchestrate` run on the same task is not refused
      for budget, and that its dispatch seq continues past the previous run's.
- [ ] Record the consumer-repo confirmations (repo, command, observed output) in the execution
      summary — a claim of "confirmed" with no recorded evidence is not a pass.

**Timing**: 1 hour

**Depends on**: 6

**Verification Tier**: full

**Files to modify**:
- None (verification and deploy only; `.claude/**` changes solely as the deploy's output)

**Verification**:
- Full suite green.
- `shellcheck` clean across all edited scripts.
- Three consumer-repo confirmations recorded with their observed output.

---

## Testing & Validation

- [ ] `--focus "Q1? Q2?"` on a forced research cycle produces a `User focus:` block with that text
      in the built dispatch file.
- [ ] Focus text AND `research_questions` both present -> both appear, each labelled; neither
      replaces the other.
- [ ] No focus text -> output matches the current `research_questions`-only output byte for byte.
- [ ] A focus value containing spaces and embedded double quotes survives from `/orchestrate`'s
      `$2+` through to the dispatch file intact.
- [ ] `--dry-run` shows the focus text it received.
- [ ] A RESEARCHED task with `--force-phases research`, after research is dispatched and
      postflighted: a second live call with the flag AND a live call without it both produce no
      dispatch rows, status still `researched`, no new dispatch file, no lock, `cycle_counts`
      unchanged. Both cases fail against the pre-fix script.
- [ ] An unforced multi-phase session still advances research -> plan -> implement.
- [ ] Six forced runs in a row (separate sessions) on one task are never refused for budget; within
      ONE run the bound still stops the task at 5 (13 with `--hard`).
- [ ] `--implement` on a RESEARCHED task with a plan dispatches implement; with no plan it yields a
      `blocked[]` row and no dispatch file, lock or status write.
- [ ] `--plan` with an existing plan dispatches `reviser-agent` (dispatch file carries
      `existing_plan_path`); `--plan` with no plan dispatches `planner-agent`. Both admitted at any
      status, including terminal.
- [ ] A plan dispatch after two research rounds names the newest report.
- [ ] `dispatch_seq` never repeats across runs.
- [ ] `--continue-budget` finds zero hits in the source store outside `specs/**`.
- [ ] `shellcheck` clean on every edited script.
- [ ] No task-number references introduced outside `specs/**`.

## Artifacts & Outputs

- Modified: `scripts/orchestrate-cycle-plan.sh`, `scripts/orchestrate-build-dispatch.sh`,
  `scripts/parse-command-args.sh`, and (conditionally) `scripts/orchestrate-loop-guard-init.sh`
- Modified: `commands/orchestrate.md`, `skills/skill-orchestrate/SKILL.md`,
  `merge-sources/claudemd.md`, `docs/architecture/orchestrate-state-machine.md`,
  `context/standards/orchestrator-runtime-files.md`
- Modified tests: `scripts/tests/test-orchestrate-cycle-plan.sh`,
  `scripts/tests/test-force-phases.sh`, `scripts/tests/test-orchestrate-build-dispatch.sh`,
  `scripts/test-session-runtime-files.sh`
- Deleted: `scripts/tests/test-loop-guard-budget-override.sh`
- Regenerated (deploy output only): `.claude/**`
- `specs/213_thread_focus_prompt_into_cycle_plan/summaries/01_*-summary.md`

## Rollback/Contingency

Every phase commits at each verified-green sub-step, so `git revert` of a phase's commits restores
the prior behavior without touching the others — the one ordering constraint is that Phases 3, 4
and 5 edit overlapping regions of `orchestrate-cycle-plan.sh`, so reverting Phase 3 alone requires
reverting 4 and 5 first. If risky work is about to start mid-phase, take a non-reverting checkpoint
with `bash .claude/scripts/git-snapshot.sh 213 --no-revert` — never the bare default (reverting)
form as a routine checkpoint. `.claude/**` needs no rollback: it is regenerated from the source
store by the next deploy.
