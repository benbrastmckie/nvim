# Implementation Plan: Task #490

- **Task**: 490 - Fix active_goal read path
- **Status**: [NOT STARTED]
- **Effort**: 4.25 hours
- **Dependencies**: None
- **Research Inputs**: specs/490_fix_active_goal_read_path/reports/01_fix-active-goal-read-path.md
- **Artifacts**: plans/01_fix-active-goal-read-path.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

`generate-task-order.sh` renders the `**Goal**:` line in `TODO.md`'s `## Task Order` section but
never reads `state.json`'s `active_goal`, so the field is a dead write. The fix replaces the
script's mode-gated Goal resolution with a single `resolve_goal_text()` chain
(`--goal` > non-empty `.active_goal` > existing `TODO.md` Goal line > omit) called identically
from both `--print` and `--update-todo`, driven by regression cases written first so the
currently-silent no-op is demonstrated red before the fix lands. The precedence and its conflict
rule are then documented in `task-order-format.md` and in the two places that declare the field,
and the source-store edits are deployed and gated.

### Research Integration

The report confirms the dispatch's diagnosis and adds a second, more severe layer: `--print`
mode never renders a Goal line from *any* source, because the `read_existing_goal()` call site is
gated `[[ "$MODE" == "update" ]]`. That matters because every caller that regenerates `TODO.md`
through `generate-todo.sh` — `state-write.sh --regen-todo`, `orchestrator-postflight.sh`,
`skill-base.sh`, and the task's own motivating caller `commands/review.md` Section 6.7.3 — reaches
`--print` and never `--update-todo`. A fix threaded only into the `--update-todo` branch would
leave review.md's workflow exactly as broken as it is today, and would leave Outcome #1's "the
existing ... preserve-across-regeneration behaviors must not regress" untrue of the dominant call
path. The plan therefore removes the mode gate (Phase 2) and covers both modes in the regression
suite (Phases 1-2), per the report's Decisions section. The report's conflict rule —
`active_goal` wins over a hand-edited `TODO.md` line when non-empty, with unset/null/`""` all
falling through to the preserve behavior — is treated as settled, not re-opened.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No `roadmap_path` was provided in this dispatch's context and no `roadmap_flag` was set, so no
roadmap phases are included. The repository's live `active_goal` string does name roadmap
generation as the current aim, which is incidental context, not a roadmap input to this plan.

### Premise Re-Validation

The dispatch's Carried-Figure extraction flagged its `SOURCE STORE` line; every load-bearing
claim in the Description was re-checked against live state today, and all hold:

| Description claim | Live check | Result |
|---|---|---|
| `active_goal` declared at `context/schemas/state-schema.json:164` | `grep -n -A4 '"active_goal"'` | Confirmed, line 164 |
| Recognized by `validate-state.sh:858` | `sed -n '850,865p'` | Confirmed, in `KNOWN_TOP_LEVEL_FIELDS` at line ~858 |
| Written by `commands/review.md` Section 6.7.3 | `sed -n '725,750p'` | Confirmed, `state-write.sh '.active_goal = $goal' ... --regen-todo` |
| Never read: `grep -n active_goal scripts/generate-task-order.sh` returns nothing | re-run | Confirmed, exit 1, no output |
| `GOAL_OVERRIDE` at lines ~92, 110-112; `read_existing_goal()` ~909-931; resolution site ~1040-1042 | `grep -n` / `sed -n` | Confirmed: 92, 112, 909, 1040-1046 |
| Source store is `agent-system/extensions/core/` | `jq -r '.extensions.core.source_dir' .claude-extensions.json` | Confirmed: `/home/benjamin/.config/nvim/agent-system/extensions/core` |
| Reproduction: a non-empty `active_goal` renders no Goal line | `jq -r .active_goal specs/state.json` is non-empty; `specs/TODO.md`'s `## Task Order` section carries no `**Goal**:` line | Reproduced **live in this repository**, not only in a scratch tree |

Two figures measured today, for the phases below to hold themselves to: the existing suite
`test-generate-task-order.sh` reports `18 passed, 0 failed`, and
`suite_selection_select scripts/generate-task-order.sh` returns ten suite basenames (enumerated in
Phase 2's Tier Justification).

## Goals & Non-Goals

**Goals**:
- `generate-task-order.sh` resolves the Goal line from one defined precedence chain —
  `--goal` override, then non-empty `state.json` `.active_goal`, then the existing `TODO.md` Goal
  line, then omit — applied identically in `--print` and `--update-todo` (Outcome #1).
- The conflict rule between `active_goal` and a hand-edited `TODO.md` Goal line is stated
  explicitly, with its rationale, in `task-order-format.md` rather than left implicit in the code
  (Outcome #2).
- `task-order-format.md`'s Goal Statement, Generation → Script Usage, and Generation Algorithm
  sections all document the chain and the two modes' parity (Outcome #3).
- `test-generate-task-order.sh` carries regression cases that fail against the current script and
  pass after the fix, covering both modes (Outcome #4).
- `commands/review.md` Section 6.7.3 is confirmed to need no functional change, and that
  confirmation is recorded (Outcome #5).
- The two places that declare `active_goal` stop asserting that no script reads it.
- The source-store edits reach the deployed `.claude/` tree and the complete gate set is green.

**Non-Goals**:
- Fixing `generate-todo.sh`'s non-default `--state-file`/`--todo-file` mismatch with its internal
  `generate-task-order.sh --print` call (archive-regeneration flows). Pre-existing, flagged by
  `generate-todo.sh`'s own source comment, and inherited rather than introduced by this fix; no
  archive-path caller writes `active_goal`.
- Correcting `task-order-format.md`'s "Optional Status Summary" claim that the `**Status**:` line
  is "also preserved across regenerations". `read_existing_goal()` reads only the Goal line, so
  that claim is false independently of this task. Record it in the implementation summary as a
  separate finding; do not edit it here.
- Widening to any caller other than `commands/review.md` Section 6.7.3. The report's full caller
  survey confirms it is the sole in-tree writer of `active_goal`.
- Adding a `minLength` or pattern constraint to the schema's `active_goal`. The empty-string case
  is handled by the resolver's non-empty test, not by tightening validation.
- Hand-authoring anything under `.claude/**`. All edits land in
  `agent-system/extensions/core/`; the deployed tree is reached only by the sanctioned deploy
  path in Phase 4.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Removing the `MODE == "update"` gate makes `--print` read `TODO_FILE`, a file that mode never touched | L | H (by design) | `read_existing_goal()` already returns `""` when `TODO_FILE` is absent, and `TODO_FILE` defaults to the same `specs/TODO.md` that `generate-todo.sh` is about to rebuild. Phase 2 adds a case asserting print-mode preservation; the non-default-path mismatch is an explicit Non-Goal |
| A stale `active_goal` silently overwrites a future hand-edit of the `TODO.md` Goal line | M | M | Accepted trade-off, decided in the report: the stale case self-corrects through `/review`'s goal-update flow or a direct `state-write.sh` call, whereas the reverse rule would make that flow silently fail with no recovery path. Phase 3 documents the rule and the rationale so the trade-off is discoverable without reading source |
| An empty-string `active_goal` permanently suppresses the preserve-from-TODO fallback | M | M | The schema's `active_goal` is an unconstrained string, so `""` validates. The resolver treats unset, `null`, and `""` alike as absent; Phase 2 case 5e pins this |
| A naive test addition hand-rolls a parallel `jq -n` state builder, diverging from the suite's single fixture builder | L | M | Phase 1 refactors `build_state()` into a thin wrapper over one shared constructor rather than duplicating it; all 18 existing assertions must still pass with zero call-site edits |
| A sibling task edits a shared file mid-flight (task 603 declares `context/reference/state-management-schema.md` in its own `file_scope`) | M | M | Phase 3 re-reads each target immediately before editing, confines the change to one table row, and stages only that hunk — never a directory or glob add, per the dispatch's concurrency note |
| Gate 8 runs the deployed copy of the suite, so the new cases are invisible to it until deployment | M | H | Phases 1-3 verify against the source-store entry point (`agent-system/extensions/core/scripts/tests/...`); Phase 4 deploys and re-runs from the deployed tree |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |
| 3 | 3 | 2 |
| 4 | 4 | 3 |

Phases within the same wave can execute in parallel. This plan is fully serial: the regression
cases need the harness extension, the documented precedence must describe the implemented
resolver, and the deploy gate must observe all three.

---

### Phase 1: Extend the test harness for Goal-line cases [NOT STARTED]

**Goal**: Give `test-generate-task-order.sh` the two things its Goal-resolution cases need — a
fixture builder that can emit `active_goal` in all three states (absent, empty, non-empty) and a
`--print`-mode runner — without altering any existing case.

**Tasks**:
- [ ] Refactor `build_state()` into a thin wrapper over a new
      `build_state_goal <scratch> <active_topics_json> <active_goal_json> <fixture_json...>`, where
      `<active_goal_json>` is a raw JSON value: `null` omits the key entirely, `""` writes an empty
      string, any other JSON string writes it verbatim. `build_state` delegates with `null`, so
      every existing call site is untouched and the `jq -s` construction stays single-source.
- [ ] Add `run_gto_print <scratch>`: runs `bash "$scratch/.claude/scripts/generate-task-order.sh"
      --print`, capturing stdout to `$scratch/print-stdout.log` and stderr to
      `$scratch/print-stderr.log`. No positional file arguments — print mode resolves
      `TODO_FILE`/`STATE_FILE` from `PROJECT_ROOT`, which `common_repo_root` derives from the
      scratch tree's own `.claude/scripts` location, so the scratch fixture is already the target.
- [ ] Add `goal_line_from <file-or-text-source>`: prints the captured group of the first
      `^\*\*Goal\*\*: (.+)$` line within the `## Task Order` section, or empty if none. Use it from
      the new cases rather than re-deriving the regex per case.
- [ ] Add a `seed_goal_line <scratch> <text>` helper that inserts a `**Goal**: <text>` line into
      the scratch `TODO.md`'s `## Task Order` section, for the preserve-behavior cases. Leave
      `build_scratch()`'s default fixture Goal-line-free, which is the no-prior-line condition
      Outcome #4 requires.
- [ ] Run the suite from the source store and confirm the assertion count and outcome are
      unchanged.

**Timing**: 0.75 hours

**Depends on**: none

**Verification Tier**: local

**Tier Justification**: `suite_selection_select` over this phase's single touched path returns
exactly `test-generate-task-order.sh` and `test-roadmap-generation.sh`, both covered by
`bash /home/benjamin/.config/nvim/agent-system/extensions/core/scripts/tests/run-all.sh --only test-generate-task-order.sh,test-roadmap-generation.sh`.

**Scope Hypothesis**: the suite reports `18 passed, 0 failed` as measured today, and this
phase's refactor is hypothesized to leave that count and outcome exactly unchanged (helpers added,
no case edited). Confirm by running the suite immediately before and after the edit and comparing
the `Results:` line verbatim; if the count moves, the refactor touched a case and must be
narrowed.

**Files to modify**:
- `agent-system/extensions/core/scripts/tests/test-generate-task-order.sh` - `build_state()`
  refactored into a wrapper over `build_state_goal()`; `run_gto_print`, `goal_line_from`, and
  `seed_goal_line` helpers added

**Verification**:
- `bash /home/benjamin/.config/nvim/agent-system/extensions/core/scripts/tests/test-generate-task-order.sh`
  exits 0 and prints `Results: 18 passed, 0 failed` — byte-identical to the pre-phase run.
- `bash /home/benjamin/.config/nvim/agent-system/extensions/core/scripts/tests/run-all.sh --only test-generate-task-order.sh,test-roadmap-generation.sh`
  exits 0.
- `grep -c 'build_state ' agent-system/extensions/core/scripts/tests/test-generate-task-order.sh`
  is unchanged, proving no existing call site was rewritten.

---

### Phase 2: Add the failing Goal-resolution cases, then implement the unified resolver [NOT STARTED]

**Goal**: Pin the precedence chain with cases that fail against today's script, then implement
`resolve_goal_text()` and remove the mode gate so every case passes.

**Tasks**:
- [ ] Case 5a (Outcome #4, literal): `active_goal` = `"Finish the widget migration"`, scratch
      `TODO.md` with no Goal line, `run_gto` (`--update-todo`) must leave
      `**Goal**: Finish the widget migration` in the `## Task Order` section.
- [ ] Case 5b: same fixture, `run_gto_print` must emit that same Goal line on stdout. This is the
      mode the task's motivating caller actually reaches.
- [ ] Case 5c: `--goal "Explicit override"` passed alongside a non-empty `active_goal` — the
      override wins in `--update-todo`, and the `active_goal` text appears nowhere in the output.
- [ ] Case 5d: `active_goal` absent (`null`) plus a seeded hand-written
      `**Goal**: Pre-existing hand-written goal line` — the seeded line survives in **both**
      `--update-todo` and `--print`. The print half is the preserve-across-regeneration guarantee
      that Outcome #1 forbids regressing and that does not hold today.
- [ ] Case 5e: `active_goal` = `""` plus the same seeded line — the chain treats the empty string
      as absent and preserves the hand-written line, in both modes.
- [ ] Run the suite against the **unmodified** script and capture the `Results:` line and each new
      case's failure text verbatim into the implementation summary. This is Outcome #4's "the test
      must fail against the current script" evidence; expect 5a, 5b, 5d's print half, and 5e's
      print half red, and record whichever cases actually fail rather than asserting this list.
- [ ] Add `resolve_goal_text()` to `generate-task-order.sh`, adjacent to `read_existing_goal()`:
      echo `$GOAL_OVERRIDE` if non-empty; else `jq -r '.active_goal // empty' "$STATE_FILE"
      2>/dev/null` and echo it if non-empty; else `read_existing_goal`; else echo `""`. Guard the
      `jq` read so an absent or malformed `STATE_FILE` yields empty rather than a hard failure.
- [ ] Replace the `if/elif [[ "$MODE" == "update" ]]/else` block at the "Determine goal text" site
      (lines ~1040-1046 today — re-read before editing, the number may have drifted) with a single
      unconditional `GOAL_TEXT="$(resolve_goal_text)"`, so `--print` and `--update-todo` share one
      chain. Leave argument parsing and `generate_section()` untouched.
- [ ] Re-run the suite and confirm every existing assertion plus every new one passes.

**Timing**: 1.5 hours

**Depends on**: 1

**Verification Tier**: interface

**Tier Justification**: `generate-task-order.sh`'s rendered output is consumed by ten enumerated
dependent suites, which is exactly what `suite_selection_select` returns for that path —
`bash /home/benjamin/.config/nvim/agent-system/extensions/core/scripts/tests/run-all.sh --only test-generate-task-order.sh,test-init-specs.sh,test-orchestrate-cycle-plan.sh,test-orchestrate-cycle-postflight.sh,test-orchestrate-unwind-dispatch.sh,test-postflight-deploy-gate.sh,test-redeploy-checkpoint-promotion.sh,test-roadmap-generation.sh,test-state-write-regen-timing.sh,test-update-task-status.sh`
is the covering check.

**Scope Hypothesis**: the script-side fix is hypothesized to be confined to two sites in
`generate-task-order.sh` — one new function beside `read_existing_goal()` (~line 909) and the
resolution block (~lines 1040-1046) — with no change to argument parsing or `generate_section()`.
Confirm with `git diff --numstat` naming only the two files in this phase's `Files to modify`, and
with `grep -n active_goal agent-system/extensions/core/scripts/generate-task-order.sh` returning
only the new resolver's own read. If the diff reaches `generate_section()` or the argument parser,
stop and reconsider rather than widening.

**Files to modify**:
- `agent-system/extensions/core/scripts/tests/test-generate-task-order.sh` - five Goal-resolution
  cases added using Phase 1's helpers
- `agent-system/extensions/core/scripts/generate-task-order.sh` - `resolve_goal_text()` added; the
  mode-gated resolution block replaced by one unconditional call

**Verification**:
- Against the unmodified script: the suite exits non-zero and the new cases' failure text is
  captured verbatim (red evidence recorded before the fix).
- After the fix:
  `bash /home/benjamin/.config/nvim/agent-system/extensions/core/scripts/tests/test-generate-task-order.sh`
  exits 0 with every pre-existing assertion still passing and the new cases passing.
- `bash /home/benjamin/.config/nvim/agent-system/extensions/core/scripts/tests/run-all.sh --only test-generate-task-order.sh,test-init-specs.sh,test-orchestrate-cycle-plan.sh,test-orchestrate-cycle-postflight.sh,test-orchestrate-unwind-dispatch.sh,test-postflight-deploy-gate.sh,test-redeploy-checkpoint-promotion.sh,test-roadmap-generation.sh,test-state-write-regen-timing.sh,test-update-task-status.sh`
  exits 0.
- `bash -n agent-system/extensions/core/scripts/generate-task-order.sh` exits 0.
- `git diff --numstat` lists only the two files named above.

---

### Phase 3: Document the precedence, the conflict rule, and the field's live readers [NOT STARTED]

**Goal**: Make the written record match the implemented resolver, state the conflict rule and its
rationale explicitly, and retire the now-false claim that no script reads `active_goal`.

**Tasks**:
- [ ] `context/formats/task-order-format.md`, **Goal Statement** section (~line 53 today —
      re-read before editing): replace "the generation script reads the existing Goal line from
      TODO.md and retains it unless `--goal` is passed explicitly" with the full four-tier chain
      (`--goal` > non-empty `state.json` `.active_goal` > existing `TODO.md` Goal line > omit the
      line), and state the conflict rule outright: a non-empty `active_goal` takes precedence over
      a hand-edited `TODO.md` Goal line; unset, `null`, and `""` all fall through to the preserve
      behavior unchanged. Give the rule its one-sentence rationale — `state.json` is the
      authoritative store and `TODO.md` a generated render target, so the field, not a hand edit,
      is the deliberate way to change the goal — and name the accepted trade-off (a stale
      `active_goal` overwrites a hand edit; it self-corrects through the goal-update flow, whereas
      the reverse rule would make that flow silently fail).
- [ ] Same file, **Generation → Script Usage** section (~lines 299-310): note that `--print` and
      `--update-todo` resolve the Goal line identically, both reading the same target `TODO.md` for
      the fallback tier — the parity is the behavior, not an implementation detail.
- [ ] Same file, **Generation Algorithm** section (~lines 312-330): insert a "Resolve Goal text"
      step before "Build wave table", naming the three sources in precedence order. This section
      currently enumerates everything the script reads from `state.json` and omits Goal resolution
      entirely, which is what Outcome #3 names.
- [ ] `context/schemas/state-schema.json`, the `active_goal` description (lines 164-167 today):
      correct the clause "No script in the agent system writes or reads it" — `/review`'s
      goal-update flow writes it and `generate-task-order.sh`'s Goal resolution reads it. Change
      that clause only; leave the rest of the description, and the `{"type": "string"}` shape,
      exactly as they are.
- [ ] `context/reference/state-management-schema.md`, the `active_goal` table row (~line 77
      today): the same one-clause correction. **Territory**: sibling task 603 declares this file in
      its own `file_scope`. Re-read the file immediately before editing, confine the change to that
      single table row, and stage only that hunk with an explicit file-list `git add` — never a
      directory or glob pathspec.
- [ ] `commands/review.md` Section 6.7.3 (Outcome #5): confirm no functional change is needed —
      its `--regen-todo` rationale becomes literally accurate once the reader exists — and record
      that confirmation in the implementation summary. Optionally add a single comment line above
      the `state-write.sh` call noting that `--regen-todo`'s `generate-todo.sh` call now renders
      `active_goal` through `generate-task-order.sh --print`'s Goal resolution. Touch no other
      caller: the report's survey confirms this is the sole writer.
- [ ] Leave `task-order-format.md`'s "Optional Status Summary" preserved-across-regenerations
      claim alone (explicit Non-Goal) and note the separate finding in the summary instead.

**Timing**: 1 hour

**Depends on**: 2

**Verification Tier**: local

**Tier Justification**: `suite_selection_select` over this phase's four touched paths returns the
`__FULL_SWEEP__` sentinel (the markdown paths are source-store, non-`specs/**` guidance files with
no mapped suite, and the sentinel collapses the whole set), so no suite covers them and the
covering check is the sentinel's source-store sub-case:
`bash /home/benjamin/.config/nvim/.claude/scripts/verify-deploy.sh --skip-slow --only-gate 3,4 /home/benjamin/.config/nvim`.

**Scope Hypothesis**: three sections in `task-order-format.md` plus two single-clause field
description corrections, and zero or one comment line in `commands/review.md`. Confirm with
`git diff --numstat` across the four files and by re-reading each target's current text before
editing — every line number cited above was read today and may have drifted under concurrent
sibling edits.

**Files to modify**:
- `agent-system/extensions/core/context/formats/task-order-format.md` - Goal Statement, Script
  Usage, and Generation Algorithm sections document the chain, the parity, and the conflict rule
- `agent-system/extensions/core/context/schemas/state-schema.json` - `active_goal` description's
  "no script writes or reads it" clause corrected
- `agent-system/extensions/core/context/reference/state-management-schema.md` - the `active_goal`
  table row's same clause corrected (shared with sibling task 603; one row only)
- `agent-system/extensions/core/commands/review.md` - comment-only, or unchanged if the
  confirmation needs no annotation

**Verification**:
- `bash /home/benjamin/.config/nvim/.claude/scripts/verify-deploy.sh --skip-slow --only-gate 3,4 /home/benjamin/.config/nvim`
  exits 0 with both gates reporting a real (non-SKIP) result.
- `bash /home/benjamin/.config/nvim/agent-system/extensions/core/scripts/tests/run-all.sh --only test-assess-repo-health.sh,test-status-vocabulary.sh,test-validate-state.sh`
  exits 0.
- `jq -e '.properties.active_goal.type == "string"' agent-system/extensions/core/context/schemas/state-schema.json`
  exits 0, proving the schema shape is unchanged by a description-only edit.
- `grep -c 'No script' agent-system/extensions/core/context/schemas/state-schema.json
  agent-system/extensions/core/context/reference/state-management-schema.md` shows the
  `active_goal` occurrences gone.
- `grep -n 'Goal' agent-system/extensions/core/context/formats/task-order-format.md` shows the
  precedence chain present in all three named sections.

---

### Phase 4: Deploy and run the complete gate set [NOT STARTED]

**Goal**: Carry the source-store change into the deployed `.claude/` tree, confirm the live
reproduction is closed end to end, and close the task against the full gate set.

**Tasks**:
- [ ] Re-read every file this task touched immediately before deploying — siblings are dispatched
      on this same working tree this cycle — and confirm no foreign modification is present in
      them. If one is, stop and report it after checking `git log`, rather than deploying over it.
- [ ] Run `bash /home/benjamin/.config/nvim/.claude/scripts/deploy-headless.sh` and confirm
      `RESULT=landed_verify_clean` with exit 0.
- [ ] Confirm the deployed copy carries the reader:
      `grep -n active_goal /home/benjamin/.config/nvim/.claude/scripts/generate-task-order.sh`
      returns the resolver's read, and
      `bash /home/benjamin/.config/nvim/.claude/scripts/tests/run-all.sh --only test-generate-task-order.sh`
      passes from the deployed tree.
- [ ] Close the live reproduction end to end: `specs/state.json` carries a non-empty `active_goal`
      while `specs/TODO.md`'s `## Task Order` section carries no `**Goal**:` line. Regenerate
      `TODO.md` through the sanctioned path (`bash .claude/scripts/generate-todo.sh`, the same
      `--print`-driven rebuild that `state-write.sh --regen-todo` performs) and confirm the Goal
      line now renders with the `active_goal` text. Do not hand-edit `TODO.md` and do not write
      `active_goal` — the field is already populated; only the render was missing.
- [ ] Run the complete gate set: `bash /home/benjamin/.config/nvim/.claude/scripts/verify-deploy.sh`.
      Record any failure that is demonstrably pre-existing or owned by a concurrent sibling as a
      Reasoned Exclusion with its evidence, rather than absorbing it into this task's scope.
- [ ] Write the implementation summary: the captured red-then-green evidence for Outcome #4, the
      recorded conflict-rule decision, the Outcome #5 confirmation for `commands/review.md`, the
      `**Status**:`-line finding noted as out of scope, and the measured gate outcome.

**Timing**: 1 hour

**Depends on**: 3

**Verification Tier**: full

**Files to modify**:
- `__WHOLE_TREE__` - `deploy-headless.sh` regenerates the entire deployed `.claude/` tree from the
  source store; this phase claims whole-tree regeneration and declares the reserved sentinel so a
  concurrently-admitted task that would also regenerate the tree is serialized against it
- `specs/490_fix_active_goal_read_path/summaries/` - the implementation summary
- `specs/TODO.md` - regenerated through `generate-todo.sh` (generated artifact, not hand-edited)

**Verification**:
- `bash /home/benjamin/.config/nvim/.claude/scripts/deploy-headless.sh` emits
  `[deploy-headless] RESULT=landed_verify_clean` and exits 0.
- The complete gate set is green:
  `bash /home/benjamin/.config/nvim/.claude/scripts/verify-deploy.sh` exits 0 (or every
  non-green gate is recorded as a Reasoned Exclusion with evidence that it is pre-existing or
  sibling-owned).
- `bash /home/benjamin/.config/nvim/.claude/scripts/tests/run-all.sh --only test-generate-task-order.sh`
  passes from the deployed tree.
- `awk '/^## Task Order$/{f=1} f&&/^## /&&!/^## Task Order$/{exit} f' specs/TODO.md | grep '^\*\*Goal\*\*: '`
  prints a line whose text equals `jq -r .active_goal specs/state.json`.
- `specs/state.json`'s `active_goal` and `next_project_number` are byte-identical to their
  pre-task values (`git diff` shows no change to either).

---

## Testing & Validation

- [ ] `test-generate-task-order.sh`'s pre-existing assertions all still pass, with the
      pre-phase-1 `Results:` count preserved through the harness refactor.
- [ ] Case 5a passes: `active_goal` set, no prior Goal line, `--update-todo` emits the line — the
      exact condition that silently no-ops today (Outcome #4).
- [ ] Case 5b passes: the same condition under `--print`, the mode the motivating caller reaches.
- [ ] Case 5c passes: `--goal` still wins over `active_goal` (the existing override does not
      regress, Outcome #1).
- [ ] Cases 5d and 5e pass in both modes: a hand-written Goal line survives regeneration when
      `active_goal` is absent or empty (the preserve behavior does not regress, and now holds in
      `--print` where it never did).
- [ ] Every new case was observed red against the unmodified script before the fix, with the
      output captured in the implementation summary.
- [ ] `task-order-format.md` states the full chain in all three named sections and the conflict
      rule explicitly with its rationale (Outcomes #2 and #3).
- [ ] Neither `state-schema.json` nor `state-management-schema.md` still claims no script reads
      `active_goal`.
- [ ] `commands/review.md` Section 6.7.3's functional behavior is unchanged, and the
      no-change-needed confirmation is recorded (Outcome #5).
- [ ] The complete gate set is green from the deployed tree, and `specs/TODO.md` renders the Goal
      line from `active_goal`.
- [ ] No file under `agent-system/**` landed by this task carries a task-number reference or
      record-versioning language.

## Artifacts & Outputs

- `agent-system/extensions/core/scripts/generate-task-order.sh` — unified `resolve_goal_text()`
  chain, mode gate removed
- `agent-system/extensions/core/scripts/tests/test-generate-task-order.sh` — extended harness plus
  five Goal-resolution regression cases
- `agent-system/extensions/core/context/formats/task-order-format.md` — documented precedence,
  conflict rule, and `--print`/`--update-todo` parity
- `agent-system/extensions/core/context/schemas/state-schema.json` and
  `agent-system/extensions/core/context/reference/state-management-schema.md` — corrected
  `active_goal` descriptions
- `agent-system/extensions/core/commands/review.md` — comment-only or unchanged
- Regenerated deployed `.claude/` tree and `specs/TODO.md` carrying the rendered Goal line
- `specs/490_fix_active_goal_read_path/summaries/01_fix-active-goal-read-path-summary.md`

## Rollback/Contingency

Every phase lands as its own scoped commit, so reverting is `git revert` of the offending
commit(s) in reverse order, followed by one `bash .claude/scripts/deploy-headless.sh` to bring the
deployed tree back in line with the restored source store. No state migration, schema shape
change, or data write is involved: the script change is additive (a new function plus one
simplified branch) and the doc changes are prose, so a revert restores exactly the prior behavior
— `active_goal` returns to being unread, which is the status quo rather than a broken state. If
the full gate set in Phase 4 fails in a way attributable to this task, revert Phase 2's commit
first (it is the only behavioral change) and re-run the gate set to isolate. Before any
destructive working-tree operation, take a non-reverting checkpoint with
`bash .claude/scripts/git-snapshot.sh 490 --no-revert`; never run the reverting default form
while siblings share this tree.
