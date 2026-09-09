# Implementation Plan: Task #196

- **Task**: 196 - Make research the default first phase for an un-researched task unless --fast is given
- **Status**: [IMPLEMENTING]
- **Effort**: 4.5 hours
- **Dependencies**: None
- **Research Inputs**: None (no research artifact for this round; see "Research Integration")
- **Artifacts**: plans/01_research-first-default-unless-fast.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md, shell-strict-mode.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Invert the `/orchestrate` classifier's `not_started` default from `plan` back to `research`, but
make the inversion **effort-conditional**: `--fast` preserves today's plan-first behavior. The
routing rule stays in exactly one executable place — `orchestrate-triage-classify.sh` gains an
`--effort` input rather than having `orchestrate-cycle-plan.sh` post-adjust its verdict — so the
script's own "one code path" discipline and its four-site lockstep contract (live classifier,
both engine tables, the degraded inline fallback) survive intact. The `needs_research` verdict
and every piece of its plumbing are retained in full: it becomes the escape hatch that keeps
`--fast` safe. Work lands as classifier + fixtures, then caller wiring + fixtures, then the doc
and agent-contract surfaces, then the full gate set.

### Research Integration

No research report exists for this round, and none was requested. The task description is
specification-shaped: it carries the defect, the four decisions to resolve, per-file verified
anchors with line numbers, an explicit MUST NOT list, and a concrete acceptance bar. The prior
decision it inverts is fully recorded on disk at `specs/150_research_on_demand/` (report, plan,
summary) and was read in full during planning, as the description requires. The remaining
open questions (a)-(d) are choices between known-workable implementation approaches inside this
codebase — planning judgment, not investigation — so they are decided and justified in
"Decisions" below rather than deferred to a research dispatch.

Key facts confirmed on disk during planning:

- `orchestrate-triage-classify.sh` takes `<engine> <task_number>...` positionally and rejects any
  non-integer argument after the engine (lines 195-203); it has no effort/flag parsing at all.
- `orchestrate-cycle-plan.sh:1288` is the **only** live caller, always with engine `mt`; the
  `single` engine survives only in fixtures and in the two engine tables.
- `effort_flag` is already parsed at `orchestrate-cycle-plan.sh:292-293` (`hard` / `fast`) and
  forwarded to `command-route-agent.sh` (1509) and `orchestrate-build-dispatch.sh` (1729). It is
  in scope at the classifier call site, so no new plumbing is needed to reach it.
- `--dry-run` shares the same classifier call site, so dry-run fidelity is preserved for free.
- `force_phases_remaining` overrides `triage_group` wholesale into `effective_group`
  (lines 1330-1347), so `--research` still forces research even under `--fast`, with no
  precedence code to write.
- `state.json`'s `file_scope` for this task lists exactly the nine files enumerated below —
  independent corroboration that the surface is complete.

### Prior Plan Reference

No prior plan for task 196. The *inverted* work's plan
(`specs/150_research_on_demand/plans/01_research-on-demand-lifecycle.md`) and its summary were
read as reference: they supply the four-site lockstep discipline, the `researching`-as-resting-
state decision, the overwrite-on-write `research_questions` semantics, and the recorded hazard
that an unhandled `needs_research` falls into `orchestrate-cycle-postflight.sh`'s catch-all and
produces `halt=true` plus an `OFF_SCHEMA_STATUS` defect. Its effort calibration (~5 hours, 6
phases, all-green) informed this plan's 4.5-hour estimate; the surface here is a strict subset
(no vocabulary admission, no status-write plumbing, no postflight arms).

### Roadmap Alignment

No `roadmap_path` was provided in this dispatch. No roadmap phases added.

## Goals & Non-Goals

**Goals**:
- Without `--fast`, a `not_started` task dispatches `research`, then `plan`, then `implement`.
- With `--fast`, a `not_started` task still dispatches straight to `plan`.
- A task at `researched` or later never re-researches, with or without `--fast`.
- The live classifier, both engine tables, the blocked-discharge `previous_status` ladder, and
  the degraded inline fallback all agree on every row, proven by the existing parity fixture.
- Every doc/contract surface describes the new default with no residual plan-first claim.
- New fixture coverage for both the `--fast` and non-`--fast` `not_started` paths, which have no
  effort-aware fixture today.

**Non-Goals**:
- Retiring, weakening, or partially removing the `needs_research` verdict, its postflight case
  arm, its `update-task-status.sh` `map_status` arm, the `research_questions` field, or its
  `state-schema.json` admission. All are retained verbatim.
- Terminal-status handling and forced-phase (`force_phases_remaining`) consumption — the
  companion task's territory. File scopes overlap by design; this task lands first.
- Introducing a new flag distinct from `--fast` (see Decision (d)).
- Any edit under `.claude/**` (disposable deploy tree) or `.opencode/**` (no copy of these
  scripts exists there).
- Changing the `orchestrate-triage-v1` verdict schema's field set.

## Decisions

These are the four decision points the task description required be resolved and recorded.

**(a) Effort-awareness lives in the classifier, not in a caller post-adjustment.**
`orchestrate-triage-classify.sh` gains an optional `--effort <fast|hard>` input; the
`not_started` rows read it. Rejected alternative: let `orchestrate-cycle-plan.sh` rewrite the
verdict after the fact. The classifier's own header states its entire reason for existing is that
the routing rule "cannot drift into two silently-diverging copies again", and names four sites
that must move in lockstep. A caller post-adjustment would create a fifth site *and* would have
to be applied twice inside that one caller (once to the live verdict, once to the degraded
fallback table) — precisely the drift the parity fixture exists to catch. Keeping the rule inside
the classifier also means the read-only `--dry-run` path and any future caller inherit it with no
extra code.

**(b) "Has not already been researched" means exactly `not_started` (and a discharged
`previous_status` of `not_started`).** Row-by-row:

| status | today | non-`--fast` | `--fast` | rationale |
|--------|-------|--------------|----------|-----------|
| `not_started` | plan | **research** | plan | the flip |
| `researching` | research | research | **research** | in-flight or planner-requested; `--fast` must NOT skip a research phase the planner explicitly asked for |
| `researched` | plan | plan | plan | a report exists — never re-research |
| `planning` | plan | plan | plan | progressed past research |
| `planned`, `implementing`, `partial` | implement | implement | implement | progressed past research |
| `blocked`, discharged, `previous_status == not_started` | plan | **research** | plan | mirrors the live `not_started` row |
| `blocked`, discharged, other `previous_status` | (per ladder) | unchanged | unchanged | mirrors the live rows |
| `blocked` non-discharged, `unknown`, terminal | unchanged | unchanged | unchanged | not research-related |

Exactly two rows change, in each of the two implementations (live classifier, degraded fallback).
`--hard` is explicitly NOT `--fast`: only `effort == "fast"` alters routing, so `--hard` keeps the
new research-first default.

**(c) The `needs_research` verdict is retained on both paths, in full.** On `--fast` it is the
escape hatch the description favors and the only thing that keeps plan-first safe. It is *not*
unreachable on the research-first default path either: a plan dispatch with no research artifact
still arises from a forced `--plan`/`--force-phases plan` round, from a `planning` status
stranded by a dead session, and from a blocked discharge with `previous_status == planning`.
`planner-agent.md`'s Stage 1.5 already skips its assessment whenever a `research_path` is
present, so the ordinary research-first path (`research` → report → `plan`) never triggers it —
which is the correct behavior, not a defect. No plumbing is deleted; only Stage 1.5's *framing*
of "the ordinary entry point" changes (Phase 4).

**(d) `--fast` keeps its name and gains a second, explicitly documented meaning.** The user's
request names `--fast` directly, so a distinct new flag would not satisfy it, and "skip a whole
dispatch cycle" is the single largest latency reduction available under a flag already meaning
"faster". The cost is that `--fast` now has two independent semantics. That is paid for in
documentation, not silence: `commands/orchestrate.md`'s `--fast` row must state plainly that the
flag now changes **which phases run**, not merely reasoning depth, and must name the
`needs_research` escape hatch. The same statement is mirrored in
`docs/architecture/orchestrate-state-machine.md` and `context/standards/status-markers.md`.

**Classifier CLI shape** (implementation detail fixed here so the two implementations cannot
disagree): `orchestrate-triage-classify.sh [--effort <fast|hard>] <engine> <task_number>...`.
`--effort` is parsed before the positional `<engine>` so it can never be confused with a task
number; omitted means "no effort flag" (research-first). An `--effort` value other than `fast` or
`hard` exits 2 with a loud stderr line, matching the existing unknown-engine precedent. The
pinned `orchestrate-triage-v1` verdict schema gains **no new field**; the effort is surfaced only
inside the existing machine-templated `reason` string, so a `--dry-run` report still explains
itself without a schema change.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Degraded fallback table missed, silently shipping a research-first live path with a plan-first fallback | H | M | Phase 2 edits both in one phase; the Group 13 parity fixture is updated in the same phase and asserts both effort variants |
| The blocked-discharge `previous_status` ladder silently keeps the old default | H | M | Decision (b) names it as one of the two changing rows; Phase 1 edits it in the same commit as the live row, with a fixture per effort variant |
| `--fast` accidentally skips a research phase the planner explicitly requested (`researching`) | H | L | Only the `not_started` rows read effort; an explicit `--fast` + `researching` → `research` fixture pins this |
| `--hard` inherits `--fast`'s phase-skipping because both flow through `effort_flag` | M | M | Only the literal value `fast` alters routing; a `--effort hard` fixture asserts research-first |
| Adding a flag breaks the classifier's strict "every argument after the engine is an integer" loop | M | M | Flags are consumed strictly *before* the positional engine; existing call sites and fixtures are byte-for-byte unaffected |
| Doc line numbers in the task description have drifted since it was written | L | H | Every doc phase greps for the claim text, not the line number (see Scope Hypothesis lines) |
| Deleting or half-retiring `needs_research` plumbing produces `halt=true` + `OFF_SCHEMA_STATUS` | H | L | Explicit Non-Goal; Phase 5 greps that every `needs_research` site named in the task-150 summary is still present |

## Implementation Phases

**Dependency Analysis**:

| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |
| 3 | 3, 4 | 2 |
| 4 | 5 | 3, 4 |

Phases within the same wave can execute in parallel.

---

### Phase 1: Effort-aware classifier + its fixtures [COMPLETED]

**Goal**: `orchestrate-triage-classify.sh` accepts `--effort` and routes `not_started` (live row
and blocked-discharge ladder) to `research` unless effort is `fast`, with its own fixture suite
green.

**Tasks**:
- [x] Add flag parsing ahead of the positional `<engine>`: consume `--effort <value>` (and
      `--effort=<value>`), default empty, reject any value other than `fast`/`hard` with a loud
      stderr line and `exit 2`. *(completed)*
- [x] Update the usage string (line ~26) and the `Usage:` comment to the new signature. *(completed)*
- [x] Pass the parsed effort into the verdict `jq` invocation as `--arg effort`. *(completed)*
- [x] Flip the live `not_started` row: `group` is `research` unless `$effort == "fast"`, with a
      `reason` string that names which default applied and why. *(completed)*
- [x] Flip the blocked-discharge `previous_status` ladder's `not_started` arm identically
      (`if $p == "not_started" then (if $effort == "fast" then "plan" else "research" end)`). *(completed)*
- [x] Update the header engine table's `not_started` row to show both effort variants, and revise
      the adjacent prose that currently asserts the research-on-demand default as unconditional.
      Keep the four-site lockstep note, extending it to name the effort input. *(completed)*
- [x] In `tests/test-orchestrate-triage-classify.sh`: update the sandbox probe (expects
      `group=plan` for `not_started` today → `research`), the mt `not_started` fixture, and the
      discharged-`not_started` fixtures (single + mt), each with a comment naming the new
      contract rather than the old one. *(completed)*
- [x] Extend the fixture helper with an optional effort argument (e.g. a `check_fixture_effort`
      wrapper) rather than changing `check_fixture`'s five-argument signature at ~40 call sites. *(completed)*
- [x] Add NEW fixtures: `--effort fast` + `not_started` → `plan` (both engines);
      `--effort hard` + `not_started` → `research`; `--effort fast` + `researching` → `research`;
      `--effort fast` + `researched` → `plan`; `--effort fast` + discharged
      `previous_status=not_started` → `plan`; an invalid `--effort bogus` → exit 2. *(completed: 48 assertions passing, up from 38)*

**Timing**: 1.25 hours

**Depends on**: none

**Verification Tier**: interface

**Commit Mode**: per-substep

**Scope Hypothesis**: exactly two `jq` rows in this file encode the `not_started` default (the
live `elif $status == "not_started"` row near line 330 and the `$p == "not_started"` ladder arm
near line 409). Confirm at implementation time with
`grep -n 'not_started' agent-system/extensions/core/scripts/orchestrate-triage-classify.sh` and
treat every hit outside the header comment as a candidate before editing.

**Files to modify**:
- `agent-system/extensions/core/scripts/orchestrate-triage-classify.sh` - flag parsing, usage,
  header table + prose, live `not_started` row, blocked-discharge ladder arm, `reason` strings
- `agent-system/extensions/core/scripts/tests/test-orchestrate-triage-classify.sh` - three
  updated deliberate assertions, effort-aware fixture helper, six new fixtures

**Verification**:
- `bash agent-system/extensions/core/scripts/tests/test-orchestrate-triage-classify.sh` green,
  with a strictly higher assertion count than the 38 the prior round recorded.
- `bash -n` and `shellcheck` clean on the edited script per
  `context/standards/shell-strict-mode.md`.
- Existing call shape unchanged: `orchestrate-triage-classify.sh mt 105` still works with no
  flag.

---

### Phase 2: Caller wiring + degraded-fallback parity [COMPLETED]

**Goal**: `orchestrate-cycle-plan.sh` forwards its already-parsed `effort_flag` to the
classifier, and its inline degraded fallback table encodes the identical effort-conditional rule.

**Tasks**:
- [x] At the classifier call site (line ~1288), pass `--effort "$effort_flag"` when `effort_flag`
      is non-empty (empty-value-skips-flag convention, matching `--focus`/`--file-scope-add`). *(completed)*
- [x] Update the degraded fallback `case` (lines ~1297-1313): `not_started` routes to `research`
      unless `effort_flag == "fast"`, in which case `plan`. Leave `researching`,
      `researched|planning`, `planned|implementing|partial`, `blocked`, `*` untouched. *(completed)*
- [x] Replace the existing "not_started now routes to plan (research on demand -- Stage A.8)"
      comment block with one naming the new effort-conditional contract and the parity fixture
      that enforces it. *(completed)*
- [x] Update this script's own header/usage comment lines (~126, ~253) only if they assert the
      routing default; the `--fast` token already appears there. *(completed: confirmed neither line asserts a routing default, no edit needed)*
- [x] In `tests/test-orchestrate-cycle-plan.sh` Group 13: keep the degraded-classifier stub, and
      assert `not_started` → `research` for the default run; add a second `run_sut ... --fast ...`
      invocation over the same fixture asserting `not_started` → `plan` and `researching` →
      `research`. Rewrite the group's header comment to name the new contract. *(completed)*
- [x] Add a NEW group (Group 15) exercising the LIVE (non-degraded) classifier through
      `--dry-run`: `not_started` → `research` without `--fast`, → `plan` with `--fast`;
      `researched` → `plan` under both. This is the first fixture that proves the caller actually
      forwards the effort, as distinct from the fallback table having it hardcoded. *(completed: numbered Group 20, not Group 15 -- Groups 15/16 were already taken by the "stdout/stderr stream discipline" and "entry-point fd-3 redirect" groups this task's description did not anticipate; also restores orchestrate-batch-admit.sh alongside the classifier since Group 16 leaves both stubbed)*
- [x] Confirm Group 14 (`research_questions` `--focus` wiring) still passes unmodified; do not
      edit it. *(completed: unmodified, still passing)*

**Timing**: 1 hour

**Depends on**: 1

**Verification Tier**: interface

**Commit Mode**: per-substep

**Scope Hypothesis**: `effort_flag` is in lexical scope at the line-1288 call site (it is set
during CLI parsing at line ~293, before the cycle loop). Confirm before editing by checking that
no `local`/subshell boundary intervenes; if it is not in scope, thread it explicitly rather than
re-parsing.

**Files to modify**:
- `agent-system/extensions/core/scripts/orchestrate-cycle-plan.sh` - classifier call site,
  degraded fallback `case`, adjacent comments
- `agent-system/extensions/core/scripts/tests/test-orchestrate-cycle-plan.sh` - Group 13
  rewritten for both effort variants, new Group 15 for live-classifier forwarding

**Verification**:
- `bash agent-system/extensions/core/scripts/tests/test-orchestrate-cycle-plan.sh` green, with a
  strictly higher assertion count than the 96 the prior round recorded.
- `shellcheck` clean on the edited script.
- Live and degraded paths agree: Group 13 (degraded) and Group 15 (live) assert the same phase
  for the same status under the same effort.

---

### Phase 3: Documentation surfaces [NOT STARTED]

**Goal**: every doc asserting the plan-first default describes the new effort-conditional
research-first default, with no residual claim that plan-first is the default.

**Tasks**:
- [ ] `docs/architecture/orchestrate-state-machine.md`: rewrite the Complete State Table's
      `not_started` and `researching` rows for the effort-conditional default.
- [ ] Same file: rewrite "The `needs_research` Fork" section — the default lifecycle is now
      `research → plan → implement`; the fork is what makes `--fast` safe and what covers forced
      plan rounds and stranded `planning` statuses; `--research` remains independent and
      unaffected.
- [ ] Same file: fix the ASCII diagram (the `not_started` branch no longer merges into the
      `dispatch plan` node by default) and the prose footnote that currently says the
      `not_started`/`researched` fork "merges into a single `dispatch plan` node".
- [ ] Same file: update both worked examples. The current "Normal Flow (specification-shaped
      task, no research needed)" becomes the `--fast` flow (retitle and add `--fast` to the
      invocation); the "Research-on-Demand Flow" example is retained as the `--fast` +
      `needs_research` escape-hatch flow. Add a new default (non-`--fast`) three-cycle flow:
      `not_started` → research → plan → implement.
- [ ] `commands/orchestrate.md`: rewrite the `--fast` row to state plainly that the flag now
      changes WHICH PHASES RUN (skipping the default research phase for an un-researched task),
      not merely reasoning depth, and that the planner can still request research via
      `needs_research`. Note composability: `--hard` does NOT skip research; `--research` forces
      research even under `--fast`.
- [ ] `commands/orchestrate.md`: check the lifecycle prose near lines 2/11/25 for a stale
      default claim and correct it if present.
- [ ] `context/standards/status-markers.md`: rewrite the "The Two-Phase Default with Research on
      Demand" section (heading included) for the new default, keeping `[RESEARCHING]`'s
      two-producers note accurate (both producers survive) and keeping the pointer to
      `orchestrate-state-machine.md` for the routing mechanics.

**Timing**: 1 hour

**Depends on**: 2

**Verification Tier**: prose

**Commit Mode**: per-substep

**Scope Hypothesis**: the description names lines 25-26, 77, 90, 117, 161-162, 305 and 324 of
`orchestrate-state-machine.md`, and line 45 of `commands/orchestrate.md`. Line numbers may have
drifted. Confirm by grepping for the claim text instead:
`grep -rn 'research on demand\|plan → implement\|dispatch plan' agent-system/extensions/core/docs/architecture/orchestrate-state-machine.md agent-system/extensions/core/commands/orchestrate.md agent-system/extensions/core/context/standards/status-markers.md`
and resolve every hit before closing the phase.

**Files to modify**:
- `agent-system/extensions/core/docs/architecture/orchestrate-state-machine.md` - state table,
  fork section, ASCII diagram, prose footnote, worked examples
- `agent-system/extensions/core/commands/orchestrate.md` - `--fast` flag row, lifecycle prose
- `agent-system/extensions/core/context/standards/status-markers.md` - two-phase-default section

**Verification**:
- `grep -rn 'default lifecycle is .plan' agent-system/extensions/core/` returns nothing.
- `grep -rn 'research on demand' agent-system/extensions/core/{docs,commands,context}` — every
  remaining hit reads as the `--fast`/escape-hatch narrative, not as the default.
- `bash agent-system/extensions/core/scripts/check-task-references.sh` reports 0 unexempted
  occurrences (no task numbers written into these deliverables).

---

### Phase 4: Agent contract surfaces [NOT STARTED]

**Goal**: `planner-agent.md` and `general-research-agent.md` describe the new default without
weakening the `needs_research` contract.

**Tasks**:
- [ ] `agents/planner-agent.md` Stage 1.5: correct the framing that "most dispatched tasks reach
      this agent with NO `research_path` at all" and that a missing `research_path` is "the
      ordinary entry point for a fresh, `not_started` task". Under the new default, a plan
      dispatch with no `research_path` means one of: `--fast`, a forced `--plan`/`--force-phases
      plan` round, or a `planning` status stranded by a dead session — enumerate these.
- [ ] Same file: keep the `research_path`-present skip rule, the narrow bar, all four negative
      examples, and the `needs_research` vs. `user_decision` distinction verbatim. Only the
      framing paragraphs change.
- [ ] Same file: update the Error Handling bullet ("No `research_path` provided: this is the
      ordinary research-on-demand entry point") to match the new enumeration, and re-check
      Critical Requirements item 8 for a stale default claim.
- [ ] `agents/general-research-agent.md`: update the `focus_prompt` note so it no longer implies
      a research dispatch is the exceptional case; a `focus_prompt` carrying forwarded
      `research_questions` is still handled identically to any other focus.
- [ ] Verify no other agent contract asserts the plan-first default:
      `grep -rn 'research on demand\|not_started' agent-system/extensions/core/agents/`.

**Timing**: 0.75 hours

**Depends on**: 2

**Verification Tier**: local

**Commit Mode**: per-substep

**Scope Hypothesis**: only these two agent contracts assert the default (the file_scope for this
task names exactly these two). Confirm with the grep in the last task above before closing.

**Files to modify**:
- `agent-system/extensions/core/agents/planner-agent.md` - Stage 1.5 framing, Error Handling
  bullet, Critical Requirements item 8
- `agent-system/extensions/core/agents/general-research-agent.md` - `focus_prompt` note

**Verification**:
- `bash agent-system/extensions/core/scripts/lint/lint-agent-contracts.sh` green (101/101 or
  higher).
- `grep -n 'needs_research' agent-system/extensions/core/agents/planner-agent.md` still shows
  Stage 1.5, Stage 6c, the return shape, and the `user_decision` distinction intact.

---

### Phase 5: Full gate set and closeout [NOT STARTED]

**Goal**: every gate green, the acceptance bar demonstrably met, and no `needs_research` plumbing
lost.

**Tasks**:
- [ ] Run the four named gates: `tests/test-orchestrate-triage-classify.sh`,
      `tests/test-orchestrate-cycle-plan.sh`, `scripts/lint/lint-agent-contracts.sh`,
      `scripts/check-task-references.sh`.
- [ ] Run `tests/test-orchestrate-cycle-postflight.sh` and
      `tests/test-orchestrate-build-dispatch.sh` as regression checks (both assert
      `needs_research` behavior and the classifier's shared-library sourcing).
- [ ] Non-deletion audit: confirm each `needs_research` site named in
      `specs/150_research_on_demand/summaries/01_...-summary.md` is still present —
      `orchestrate-cycle-postflight.sh`'s case arm, `update-task-status.sh`'s
      `postflight:needs_research` `map_status` arm, `skill-base.sh`'s `needs_research)` arm,
      `validate-return-meta.sh`/`validate-handoff.sh` `valid_statuses`, and
      `context/schemas/state-schema.json`'s `research_questions` admission.
- [ ] `shellcheck` over both edited scripts and both edited test scripts.
- [ ] Acceptance walkthrough against the description's ACCEPTANCE paragraph, recording the
      evidence line for each of its six clauses.

**Timing**: 0.5 hours

**Depends on**: 3, 4

**Verification Tier**: full

**Commit Mode**: per-substep

**Files to modify**:
- None (verification-only phase; any defect found is fixed in the owning phase's files)

**Verification**:
- All six test/lint scripts exit 0.
- The non-deletion audit finds every named site present.
- Each ACCEPTANCE clause has a named piece of evidence.

---

## Testing & Validation

- [ ] `test-orchestrate-triage-classify.sh` green, assertion count > 38
- [ ] `test-orchestrate-cycle-plan.sh` green, assertion count > 96
- [ ] `test-orchestrate-cycle-postflight.sh` green (regression)
- [ ] `test-orchestrate-build-dispatch.sh` green (regression)
- [ ] `lint/lint-agent-contracts.sh` green
- [ ] `check-task-references.sh` reports 0 unexempted occurrences
- [ ] `shellcheck` clean on all four edited shell files
- [ ] `not_started` → `research` (no flag) and → `plan` (`--fast`) proven through BOTH the live
      classifier and the degraded fallback table
- [ ] `researched`, `planning`, `planned`, `implementing`, `partial` unchanged under both efforts
- [ ] `--fast` + `researching` → `research` (planner-requested research never skipped)
- [ ] `--hard` → research-first (not treated as fast)
- [ ] Blocked-discharge `previous_status == not_started` mirrors the live row under both efforts

## Artifacts & Outputs

- Modified: `agent-system/extensions/core/scripts/orchestrate-triage-classify.sh`
- Modified: `agent-system/extensions/core/scripts/orchestrate-cycle-plan.sh`
- Modified: `agent-system/extensions/core/scripts/tests/test-orchestrate-triage-classify.sh`
- Modified: `agent-system/extensions/core/scripts/tests/test-orchestrate-cycle-plan.sh`
- Modified: `agent-system/extensions/core/docs/architecture/orchestrate-state-machine.md`
- Modified: `agent-system/extensions/core/commands/orchestrate.md`
- Modified: `agent-system/extensions/core/context/standards/status-markers.md`
- Modified: `agent-system/extensions/core/agents/planner-agent.md`
- Modified: `agent-system/extensions/core/agents/general-research-agent.md`
- New: `specs/196_research_first_default_unless_fast/summaries/01_research-first-default-unless-fast-summary.md`

## Rollback/Contingency

Every phase is an independent commit against the source store, and `.claude/` is a disposable
deploy tree regenerated from it — so `git revert` of this task's commits fully restores the
prior default with no deploy-tree cleanup. Partial-failure contingency, in order of preference:

1. If Phase 1's flag parsing proves incompatible with the classifier's strict integer-argument
   loop, fall back to reading the effort from an environment variable set by the caller
   (`ORCHESTRATE_EFFORT`) rather than moving the rule into the caller — Decision (a)'s one-code-
   path property is the thing to preserve, the CLI shape is not.
2. If the degraded fallback and live classifier cannot be kept in agreement within Phase 2,
   stop and escalate rather than shipping a divergence; the parity fixture failing is a correct
   red, not an obstacle to route around.
3. Docs (Phase 3) and agent contracts (Phase 4) are revertible independently of the behavior
   change, but shipping the behavior change without them leaves the system self-contradictory —
   if either must be dropped, revert Phases 1-2 as well rather than landing a documented-wrong
   default.
