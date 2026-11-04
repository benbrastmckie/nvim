# Implementation Plan: Task #407

- **Task**: 407 - Derive artifact round from existing artifacts
- **Status**: [IMPLEMENTING]
- **Effort**: 3 hours
- **Dependencies**: None
- **Research Inputs**: specs/407_derive_artifact_round_from_existing_artifacts/reports/01_derive-artifact-round-from-artifacts.md
- **Artifacts**: plans/01_derive-artifact-round-max-prefix.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

`skill_read_artifact_number()` in the core source store's `scripts/skill-base.sh` resolves a
task's artifact round from `state.json`'s `next_artifact_number`, defaulting an absent field to
`1` with `jq -r '.next_artifact_number // 1'`. That default pre-empts the very next line's
`[ "$next_num" = "null" ]` guard, making the directory-derivation branch below it unreachable for
the (near-universal) absent-field case, so a task whose artifacts already occupy round `01` gets
round `01` minted a second time. The fix replaces the read with an **unconditional max-prefix
normalization**: scan the task's canonical artifact subdirectories for the highest `MM` sequence
prefix, take `max(stored_counter, max_on_disk + 1)`, then apply the existing `current`/`prev` mode
logic to that single normalized value. Definition of done: a task created with a pre-supplied
`reports/01_*.md` and no `next_artifact_number` resolves round `2` for research and round `1` for
plan/implement, with the existing `current`/`prev`, archive-aware, and counter-present behaviours
byte-identical.

### Research Integration

The research report (`reports/01_derive-artifact-round-from-artifacts.md`) is integrated as
follows:

- **Root cause confirmed in the source store, not just the deployed copy.** The function starts
  at `scripts/skill-base.sh:557`; the `// 1` default is on line 570 and the dead guard on line
  571. The deployed-copy line anchors in the task description did not drift for `skill-base.sh`;
  the `orchestrate-build-dispatch.sh` call site sits at line 275 (its section comment at 269),
  not the description's cited 241. Re-derived here, as the description instructed.
- **Prior art adopted rather than reinvented.** `skills/skill-reviser/SKILL.md` Stage 3a already
  implements the exact max-prefix-not-count reconciliation this task needs (`find ...
  [0-9][0-9]_*.md | sed | sort -n | tail -1`, `10#` to defeat octal, bump when the counter-derived
  number is `<=` the max). Its algorithm is the reference design for this plan's normalization
  step. `skill-reviser/SKILL.md` itself is **not edited** (see Non-Goals).
- **`orchestrate-cycle-plan.sh` is out of scope.** Independently confirmed: a grep of that file
  for `next_artifact_number` returns zero matches; its "mint" comments concern `dispatch_seq`, an
  unrelated per-dispatch counter. See "Declared Scope Narrowing" below.
- **No creation-time write is needed.** No core creation path (`commands/task.md` Step 6,
  `context/contracts/conclusion-stage.md` Step 4c) writes a non-empty `artifacts[]`, and the only
  site anywhere that writes `next_artifact_number` (the literature extension's
  `literature-create-setup-task.sh`) writes `artifacts: []` alongside it. The round-resolution fix
  is necessary and sufficient; a creation-time write would be defense-in-depth with no live call
  site. See "Declared Scope Narrowing".
- **One research recommendation is deliberately strengthened.** The report proposes dropping the
  `// 1` default so the existing `null` guard re-arms, with max-prefix logic confined to that
  fallback branch. This plan instead normalizes **unconditionally**, for the reason recorded under
  "Plan-Time Finding Beyond Research" below.

### Plan-Time Finding Beyond Research

A grep of every `next_artifact_number` **write** site found a second-order defect the research
report does not cover. All three advance sites —

- `scripts/orchestrator-postflight.sh:365`
- `scripts/orchestrate-stage5-postflight.sh:276`
- `scripts/orchestrate-cycle-postflight.sh:1610`

— advance the counter with `((... .next_artifact_number // 1) + 1)`. So on the exact defect
scenario (field absent, `reports/01_*.md` pre-supplied): once the read-side fix mints round `2`
and research writes `reports/02_*.md`, postflight stores `1 + 1 = 2`, **not** `3`. The following
plan dispatch would then read `2`, apply `prev`, and resolve round `1` again — writing
`plans/01_*.md` beside the pre-supplied report instead of alongside `reports/02`. A fallback-only
fix therefore closes the first collision and leaves a second one standing one dispatch later.

Making the normalization **unconditional** closes both without touching any write site: on that
plan dispatch, `max_on_disk` is `2`, so the normalized value is `max(2, 3) = 3`, and `prev`
resolves `2` — the correct shared round. The counter becomes self-healing whenever it is behind
what is on disk, which is precisely the stale-counter class the three `// 1` advance sites can
produce. This is why the three advance sites stay out of scope (see Non-Goals) rather than being
fixed in parallel.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No `roadmap_path` was supplied in this dispatch and no roadmap phases are included.

### Declared Scope Narrowing (stated explicitly, per the task description's own instruction)

The task description asked that any plan-time narrowing be said out loud rather than left
standing unexamined. It is:

1. **`core/scripts/orchestrate-cycle-plan.sh` is dropped from scope.** It was named in the
   description as "the minting surface," inherited verbatim from the originating record in another
   repository. It carries no `next_artifact_number` logic at all. **The three declared TERRITORY
   EDGES against it are therefore droppable**: the reviser-agent handoff contradiction record, the
   whole-tree-regeneration scope-claim record, and the shared-verify-deploy-gate-run record. No
   phase below lists that file in **Files to modify**, so `plan-file-scope-harvest.sh` will narrow
   this task's `file_scope` off it without any manual edit; the three dependency edges can be
   removed by the operator (`update-task-status.sh --depends-on-remove`) at will — they are
   ordering-only edges and leaving them in place costs nothing but serialization.
2. **`core/scripts/orchestrate-build-dispatch.sh` is dropped from scope.** It is the only
   orchestrate call site of the changed function, but the function's signature and both exported
   variables (`ARTIFACT_NUMBER`, `ARTIFACT_PADDED`) are unchanged, so the call site needs no edit.
   It remains covered as a *consumer* by the integration suite in Phase 2.
3. **`core/commands/task.md` is dropped from scope — no creation-time write.** The chosen design
   is round-resolution-side only. Consequently, both "adjacent claims to check at plan time" named
   in the description resolve to *no edge needed*: `core/scripts/state-write.sh` is not touched
   (so no edge to the task-number-allocation-staleness record), and
   `context/contracts/conclusion-stage.md` is not touched (so no edge to the conclusion-stage Step
   4c record or the siting-and-target-root record). Recorded here as the description required.
4. **Two surfaces are added that the description did not name.**
   `core/scripts/tests/test-skill-base-lifecycle.sh` (Phase 3 — the function is explicitly listed
   as uncovered residual in that suite's own summary, and the per-mode matrix is far cheaper to
   assert at unit level than through dispatch fixtures) and
   `core/context/reference/state-management-schema.md` (Phase 4 — its "Backward Compatibility"
   subsection documents the count-based derivation this task replaces, and would otherwise
   describe behaviour the code no longer has). The schema doc is also claimed by two
   `not_started` records (the todo-archival record and the multi-task-creation-standard record);
   that overlap is declared here through this plan's `file_scope` so the batch-admission machinery
   serializes rather than races, and no edge is added by hand.

## Goals & Non-Goals

**Goals**:

- A task entry with no `next_artifact_number` and a pre-supplied `reports/01_*.md` resolves
  artifact round `2` for a research dispatch (`mode=current`) and round `1` for plan/implement
  (`mode=prev`).
- Round derivation is **max sequence prefix + 1**, never a file count, so a gap in the sequence
  (`01`, `03` present) resolves `4`, not `3`.
- A stored counter that is *behind* what is on disk self-heals at read time; a stored counter at
  or ahead of disk wins unchanged.
- The three preserved behaviours stay intact: `mode=current` for research, `mode=prev` sharing the
  preceding research round for plan/implement, and the archive-aware `task_lookup_entry` lookup
  plus archive-aware scan root (`TASK_DIR`).
- Regression coverage: the dispatch-required absent-field-plus-pre-supplied-artifact case in
  `test-orchestrate-build-dispatch.sh`, plus a direct per-mode unit matrix.
- The source store is the only edit target, and the deployed tree is regenerated to
  `RESULT=landed_verify_clean`.

**Non-Goals**:

- **No creation-time `next_artifact_number` write.** No live core creation path produces the
  triggering condition (see Research Integration); adding the write would touch
  `commands/task.md` and `context/contracts/conclusion-stage.md` for no reachable caller.
- **No change to the three `next_artifact_number` advance sites.** Their `// 1` is rendered
  harmless by the unconditional read-side normalization, which is the stated reason the
  normalization is unconditional. Fixing them would widen scope across three heavily-claimed
  orchestrate scripts for no behavioural gain.
- **No shared-helper extraction and no edit to `skills/skill-reviser/SKILL.md`.** The research
  report floats de-duplicating the two copies of the max-prefix scan into `scripts/lib/`. That
  would add a new file to `manifest.json`'s `provides.scripts` (a new deploy surface) and rewrite
  a second consumer's working code, for a readability gain only. The scan is implemented as a
  file-local helper inside `skill-base.sh` instead.
- **No signature change** to `skill_read_artifact_number()` — the `artifact_dir` positional is
  retained for call-site stability (see Phase 1's note on how to comment it).
- No `ROADMAP.md` read or write.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| A stray high-prefix file in the task directory (e.g. a hand-dropped `09_notes.md`) inflates every subsequent round | M | L | Scan only the three canonical artifact subdirectories (`reports/`, `plans/`, `summaries/`) and only names matching `[0-9][0-9]_*.md` — not the task-directory root, where `.dispatch/`, `issues.jsonl`, and operator notes live |
| Unconditional normalization changes a currently-correct resolution somewhere | H | L | For every gap-free, counter-ahead-of-disk state (the normal lifecycle), `max(stored, max_on_disk+1) == stored` by construction, so the value is unchanged. Phase 3's unit matrix pins the counter-present cases explicitly as regression assertions; Phase 2 keeps the two existing integration assertions (`artifact_number: 2` for `mode=current` with counter `2`; `artifact_number: 1` for `mode=prev`) untouched and passing |
| New helper breaks `set -e`/`pipefail` in a sourcing script (a glob miss, or a trailing false test as the last statement) | H | M | Pure-bash globbing with a `[ -e "$f" ] || continue` guard instead of `ls`/`find` in a pipeline; explicit `if` blocks rather than `&&` one-liners; the helper's last statement is the `printf`. The existing code's own `|| count=0` comment documents exactly this hazard |
| Leading-zero prefixes parsed as octal (`08`, `09` → error) | M | M | `$((10#${prefix}))`, the same guard `skill-reviser/SKILL.md` Stage 3a already uses |
| A doc/comment edit introduces record-versioning or task-number language into `agent-system/**` | M | M | Both are blocked by rule (`no-record-versioning-in-deliverables.md`, `no-task-references-in-deliverables.md`) and by gate 4; Phase 1 and Phase 4 each carry an explicit wording instruction, and the final gate runs the lint |
| Edits land in the deployed `.claude/**` tree and are silently wiped | H | L | Source store resolved from `.claude-extensions.json` (`core` → `/home/benjamin/.config/nvim/agent-system/extensions/core`, re-resolved at plan time and confirmed); Phase 1 re-resolves before editing; Phase 5 redeploys |

## Implementation Phases

**Dependency Analysis**:

| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2, 3, 4 | 1 |
| 3 | 5 | 2, 3, 4 |

Phases within the same wave can execute in parallel.

### Phase 1: Normalize the artifact round in `skill_read_artifact_number()` [COMPLETED]

**Goal**: Replace the `// 1`-defaulted read and the count-based fallback with one unconditional
max-prefix normalization feeding the unchanged `current`/`prev` mode logic.

**Tasks**:

- [x] Re-resolve the source store: `jq -r '.extensions.core.source_dir' .claude-extensions.json`
      (expected `/home/benjamin/.config/nvim/agent-system/extensions/core`). Confirm
      `scripts/skill-base.sh` exists there. Never edit under `.claude/**`. *(completed)*
- [x] Add a file-local helper above `skill_read_artifact_number()` that echoes the highest `MM`
      prefix across the task's canonical artifact subdirectories, or `0` when none match: *(completed)*

      ```bash
      # Highest MM sequence prefix across the task's canonical artifact subdirectories.
      # Echoes 0 when no artifact matches. Pure-bash globbing (never ls/find in a pipeline)
      # so a glob miss cannot abort a `set -e -o pipefail` caller; the last statement is the
      # printf, so the function never returns a trailing false.
      _skill_artifact_max_prefix() {
        local task_dir="$1"
        local max=0
        local subdir f base n
        for subdir in reports plans summaries; do
          [ -d "${task_dir}/${subdir}" ] || continue
          for f in "${task_dir}/${subdir}"/[0-9][0-9]_*.md; do
            [ -e "$f" ] || continue
            base="$(basename "$f")"
            n=$((10#${base:0:2}))
            if [ "$n" -gt "$max" ]; then
              max="$n"
            fi
          done
        done
        printf '%s\n' "$max"
      }
      ```

- [x] Rewrite the body of `skill_read_artifact_number()` to normalize first, then apply mode: *(completed)*

      ```bash
      local stored max_on_disk derived scan_dir
      stored=$(task_lookup_entry "$task_number" specs/state.json | jq -r '.next_artifact_number')
      # An absent key yields the literal string "null"; a non-numeric or empty value is treated
      # the same way -- as "no usable counter", i.e. 0, which the disk-derived value then wins.
      case "$stored" in ''|null|*[!0-9]*) stored=0 ;; esac
      scan_dir="${TASK_DIR:-specs/${padded_num}_${project_name}}"
      max_on_disk=$(_skill_artifact_max_prefix "$scan_dir")
      derived=$((max_on_disk + 1))
      next_num="$stored"
      if [ "$derived" -gt "$next_num" ]; then
        next_num="$derived"
      fi
      if [ "$next_num" -lt 1 ]; then
        next_num=1
      fi
      if [ "$mode" = "current" ]; then
        ARTIFACT_NUMBER="$next_num"
      else
        # mode = "prev": planner/implementer share the same round as preceding research
        if [ "$next_num" -le 1 ]; then
          ARTIFACT_NUMBER=1
        else
          ARTIFACT_NUMBER=$((next_num - 1))
        fi
      fi
      ARTIFACT_PADDED=$(printf "%02d" "$ARTIFACT_NUMBER")
      export ARTIFACT_NUMBER ARTIFACT_PADDED
      ```

- [x] Keep the archive-awareness commentary that explains why `task_lookup_entry` (not an inline
      `.active_projects` jq) is used and why the scan root prefers the ambient `TASK_DIR` — both
      rationales survive the rewrite verbatim in substance. *(completed)*
- [x] Update the function's header comment to state the resolution rule in the present tense:
      the round is `max(stored next_artifact_number, highest on-disk MM prefix + 1)`, with
      `current` using it as-is and `prev` using it minus one (floored at 1). *(completed)*
- [x] Comment the now-unconsulted `artifact_dir` positional **without record-versioning
      language**: state that it is accepted for call-site signature stability and is not
      consulted, because a round shares one sequence number across `reports/`, `plans/`, and
      `summaries/`, so the scan is round-wide. Do not write "no longer", "previously", or
      "used to" — `rules/no-record-versioning-in-deliverables.md` applies to every file landing
      under `agent-system/**`. *(completed)*
- [x] Confirm no task-number reference entered the file (`rules/no-task-references-in-deliverables.md`). *(completed: grep clean)*
- [x] Sanity-check by sourcing in isolation against a scratch fixture (a throwaway directory with
      `specs/state.json` plus `reports/01_x.md`), asserting `current → 2` and `prev → 1`.
      *(completed: also probed empty-dir, gap, behind-counter, and counter-present-pin cases)*

**Timing**: 1 hour

**Depends on**: none

**Verification Tier**: interface

**Commit Mode**: per-substep

**Scope Hypothesis**: this phase asserts the change is confined to one function plus one new
file-local helper in a single file (`scripts/skill-base.sh`), with no signature change and no
call-site edit. Confirm at implementation time by re-grepping
`grep -rn "skill_read_artifact_number" ` across the source store: exactly one definition and one
call site (`scripts/orchestrate-build-dispatch.sh:275`) are expected; a second call site would
require re-checking its `mode`/`artifact_dir` expectations before proceeding.

**Tier Justification**: `skill-base.sh` is sourced by many orchestrate scripts, so the enumerated
dependent set is the suite list `scripts/lib/suite-selection-lib.sh` resolves for this path —
discharged by `bash agent-system/extensions/core/scripts/tests/run-all.sh --only
test-corroborate-phase-counts.sh,test-force-phases.sh,test-gate-out-derived-staleness.sh,test-gate-out-repair-reporting.sh,test-gate-out-self-attribution.sh,test-handoff-dispatch-identity.sh,test-lint-task-lookup-adoption.sh,test-mint-dispatch-seq.sh,test-orchestrate-build-aux-dispatch.sh,test-orchestrate-build-dispatch.sh,test-orchestrate-context-growth.sh,test-orchestrate-cycle-plan.sh,test-orchestrate-cycle-postflight.sh,test-orchestrate-recover-message-findings.sh,test-orchestrate-unwind-dispatch.sh,test-postflight-marker-schema.sh,test-skill-base-lifecycle.sh`,
which covers every suite mapped to this file without paying the other seven gates of a full run.

**Files to modify**:

- `agent-system/extensions/core/scripts/skill-base.sh` - add `_skill_artifact_max_prefix()`;
  rewrite `skill_read_artifact_number()`'s body to normalize unconditionally and apply mode once;
  update its header and `artifact_dir` commentary

**Verification**:

- The `--only` suite list above runs green, with no new failure relative to a pre-edit run of the
  same list (capture the pre-edit result first so a pre-existing red suite is not misread as a
  regression).
- `bash -n agent-system/extensions/core/scripts/skill-base.sh` parses.
- Scratch-fixture probe: absent field + `reports/01_x.md` → `current` yields `ARTIFACT_NUMBER=2`,
  `prev` yields `1`; empty task dir + absent field → both yield `1`.

---

### Phase 2: Extend the dispatch integration suite with the absent-field case [COMPLETED]

**Goal**: Add the regression case the task description requires — absent `next_artifact_number`
plus a pre-supplied, linked `01` artifact must yield `artifact_number: 2` — to the existing
fixture suite, plus the gap and stale-counter discriminators.

**Tasks**:

- [x] Append a new group (next in sequence after `Group 19`) to
      `scripts/tests/test-orchestrate-build-dispatch.sh`, following the established in-file
      convention: rewrite `$FIXTURE/specs/state.json` with a heredoc, create any extra artifact
      files, call `run_sut <phase> --clean --seq N`, assert on the dispatch file's content with
      `assert_contains`, and call `build_fixture` at the end of the group to restore the baseline
      fixture for any suite appended later (the convention Group 11 already follows). *(completed
      as Group 20; also added a defensive rebuild of reports/plans/summaries at the group's start,
      since this function's unconditional scan picks up Group 11's leftover
      reports/02_fixture-report-round2.md, which the old counter-present-always fixture never
      exercised against a real disk scan)*
- [x] Case A (**the dispatch-required case**): entry with **no** `next_artifact_number` key and
      `artifacts: [{"type": "report", "path": "${TASK_DIR_REL}/reports/01_fixture-report.md", ...}]`,
      the file present on disk (the baseline fixture already creates it) → `run_sut research` →
      assert `artifact_number: 2`. *(completed)*
- [x] Case B: same absent-field fixture → `run_sut plan` → assert `artifact_number: 1`
      (`mode=prev` shares the pre-supplied report's round rather than minting its own). *(completed)*
- [x] Case C (max-prefix, not count): with the absent-field fixture, additionally create
      `reports/03_fixture-report-gap.md` → `run_sut research` → assert `artifact_number: 4`. A
      count-based derivation would yield `3` here, so this assertion is what pins max-prefix
      semantics. Remove the gap file (or let the closing `build_fixture` restore state) before the
      next case. *(completed)*
- [x] Case D (self-healing counter): entry with `"next_artifact_number": 1` and
      `reports/02_fixture-report-round2.md` present → `run_sut plan` → assert `artifact_number: 2`,
      pinning the behaviour that absorbs the `// 1` advance-site arithmetic described under
      "Plan-Time Finding Beyond Research". *(completed)*
- [x] Leave the two existing assertions untouched (line ~217 `artifact_number: 2` for
      `mode=current` with counter `2`; line ~297 `artifact_number: 1` for `mode=prev`) — they are
      the counter-present regression pins and must still pass unmodified. *(completed: git diff
      confirms purely additive, no removed lines)*
- [x] Add a group header comment explaining what each case discriminates, in the voice the
      surrounding groups use. No task-number references. *(completed)*

**Timing**: 45 minutes

**Depends on**: 1

**Verification Tier**: local

**Commit Mode**: per-substep

**Scope Hypothesis**: this phase asserts four new assertions in exactly one file and zero changes
to existing assertions. Confirm by diffing the suite before and after: the diff must be purely
additive apart from the new group header.

**Tier Justification**: the edit is confined to one test file, and the covering check is
`bash agent-system/extensions/core/scripts/tests/run-all.sh --only
test-orchestrate-build-aux-dispatch.sh,test-orchestrate-build-dispatch.sh,test-orchestrate-context-growth.sh,test-orchestrate-cycle-plan.sh`
— the exact suite set `suite_selection_select` maps this path to.

**Files to modify**:

- `agent-system/extensions/core/scripts/tests/test-orchestrate-build-dispatch.sh` - append one new
  group covering the absent-field, gap, and behind-counter cases for both `mode=current` and
  `mode=prev`

**Verification**:

- `bash agent-system/extensions/core/scripts/tests/test-orchestrate-build-dispatch.sh` exits 0
  with four more passes than before and zero failures.
- The `--only` set above runs green.
- `git diff` on the suite shows no modification to the two pre-existing `artifact_number`
  assertions.

---

### Phase 3: Add direct unit coverage for the resolver [COMPLETED]

**Goal**: Pin the full per-mode resolution matrix — including the archive-aware scan root — at
unit level in the suite that owns `skill-base.sh`, and retire the function from that suite's
uncovered-residual list.

**Tasks**:

- [x] Add a group to `scripts/tests/test-skill-base-lifecycle.sh` that sources the resolved
      `skill-base.sh` (that suite already resolves it) and calls `skill_read_artifact_number`
      directly against scratch fixture directories under its `WORKDIR`, honouring the suite's
      existing isolation contract — never the real `specs/` tree, and preserving its
      real-`specs/`-unchanged baseline assertion at the end of the run. *(completed as Group 6,
      deviation: altered — see note below on resolution order)*
- [x] Matrix to assert, each for both `mode=current` and `mode=prev`:
      - absent field, `reports/01_*.md` present → `2` / `1`
      - absent field, empty task directory → `1` / `1`
      - `next_artifact_number: 2`, `reports/01_*.md` present → `2` / `1` (counter-present
        regression pin: identical to the behaviour before this change)
      - absent field, `reports/01_*.md` and `reports/03_*.md` present (a gap) → `4` / `3`
      - `next_artifact_number: 1`, `reports/02_*.md` present (counter behind disk) → `3` / `2`
      - `ARTIFACT_PADDED` is zero-padded two digits in at least one case
      *(completed: full matrix asserted, all pass)*
- [x] Archive-awareness case: set the ambient `TASK_DIR` to a fixture
      `specs/archive/{NNN}_{slug}/` directory holding `reports/01_*.md` while no such active
      directory exists, and assert the scan honours `TASK_DIR` rather than reconstructing an
      active-only path. *(completed)*
- [x] Update the suite's closing "Residual (uncovered by this suite...)" echo block to drop
      `skill_read_artifact_number` from the uncovered list, matching the phrasing the block
      already uses for functions it has since covered. *(completed)*
- [x] No task-number references; no record-versioning language in the new comments.
      *(completed: grep clean)*

**Timing**: 45 minutes

**Depends on**: 1

**Verification Tier**: local

**Commit Mode**: per-substep

**Scope Hypothesis**: this phase asserts the change is confined to one file
(`scripts/tests/test-skill-base-lifecycle.sh`) and that `skill_read_artifact_number` is currently
listed as uncovered residual in its closing summary. Confirm the latter by grepping that file for
`skill_read_artifact_number` before editing — exactly one occurrence, inside the residual echo
block, is expected.

**Tier Justification**: the edit is confined to one test file, covered by
`bash agent-system/extensions/core/scripts/tests/run-all.sh --only
test-force-phases.sh,test-gate-out-repair-reporting.sh,test-manage-topics-create-order.sh,test-mint-dispatch-seq.sh,test-orchestrate-build-dispatch.sh,test-postflight-marker-schema.sh,test-skill-base-lifecycle.sh,test-task-type-detect.sh,test-update-task-status.sh,test-validate-return-meta.sh`
— the suite set `suite_selection_select` maps this path to.

**Files to modify**:

- `agent-system/extensions/core/scripts/tests/test-skill-base-lifecycle.sh` - add a direct
  resolution-matrix group for `skill_read_artifact_number`; drop that function from the closing
  residual list

**Verification**:

- `bash agent-system/extensions/core/scripts/tests/test-skill-base-lifecycle.sh` exits 0, with the
  new matrix passing and the suite's own real-`specs/`-unchanged assertion still passing.
- The `--only` set above runs green.

---

### Phase 4: Align the state-management schema doc with the implemented derivation [NOT STARTED]

**Goal**: Replace the "Backward Compatibility" subsection's count-based derivation snippet with
the max-prefix normalization the code implements, so the schema reference stays the source of
truth.

**Tasks**:

- [ ] Edit the "Backward Compatibility" subsection of
      `context/reference/state-management-schema.md` (the subsection following the round-flow
      example, around lines 208-214) to describe the implemented rule: the resolver takes
      `max(stored next_artifact_number, highest on-disk MM prefix + 1)`, scanning `reports/`,
      `plans/`, and `summaries/` together for `[0-9][0-9]_*.md` names, so a missing counter and a
      counter that has fallen behind the files on disk both resolve correctly, and a gap in the
      sequence does not collapse two rounds onto one number.
- [ ] Replace the illustrative `count=$(ls ... | wc -l)` snippet with a snippet matching the
      implemented derivation, and name `skill_read_artifact_number()` in `scripts/skill-base.sh`
      as the implementing function so a reader can find it.
- [ ] Note that `skills/skill-reviser/SKILL.md` Stage 3a applies the same max-prefix
      reconciliation for plan revisions, so the two are described as one concept rather than two.
- [ ] State the current behaviour only — no "previously", "no longer", "superseded", or version
      framing (`rules/no-record-versioning-in-deliverables.md`), and no task-number references
      (`rules/no-task-references-in-deliverables.md`).

**Timing**: 20 minutes

**Depends on**: 1

**Verification Tier**: prose

**Commit Mode**: per-substep

**Scope Hypothesis**: this phase asserts the edit is confined to one subsection of one markdown
file and that no test pins the superseded snippet's text. Confirm by grepping the source store's
`scripts/tests/` for the snippet's distinctive text (`wc -l` together with
`next_artifact_number`) before editing; a doc-sync pin on that string would have to be updated in
the same phase.

**Tier Justification**: the edit is markdown-only with no executable surface, so the diff
read-through is paired with `bash agent-system/extensions/core/scripts/verify-deploy.sh
--skip-slow --only-gate 3,4 agent-system/extensions/core` (doc-lint and task-reference lint, with
the explicit source-store TARGET the no-argument form would miss) plus
`bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-orchestrate-build-dispatch.sh`,
the one suite `suite_selection_select` maps this path to.

**Files to modify**:

- `agent-system/extensions/core/context/reference/state-management-schema.md` - rewrite the
  "Backward Compatibility" subsection's derivation description and snippet

**Verification**:

- Diff read-through confirms every changed hunk is prose or a fenced illustrative snippet.
- Gate 3/4 subset against the source-store TARGET reports no new finding relative to a pre-edit
  run of the same subset.
- `run-all.sh --only test-orchestrate-build-dispatch.sh` green.
- Manual read-back: the subsection's described rule matches Phase 1's implemented arithmetic
  exactly (including the `prev` floor at 1).

---

### Phase 5: Redeploy and full gate [NOT STARTED]

**Goal**: Regenerate the deployed `.claude/` tree from the edited source store and prove the
complete gate set is clean.

**Tasks**:

- [ ] Confirm the working tree holds no un-landed source-store edits from Phases 1-4 (all four
      phases committed).
- [ ] Run `bash .claude/scripts/deploy-headless.sh` and read its final
      `[deploy-headless] RESULT=<token>` line. Require `RESULT=landed_verify_clean`.
- [ ] On `RESULT=landed_verify_red`, compare each reported finding against a pre-change baseline
      before attributing it to this work: the deploy result contract explicitly does not
      distinguish pre-existing findings from newly-introduced ones at that layer. Fix forward on
      anything this task introduced; record a pre-existing finding in the issue log rather than
      silently absorbing it.
- [ ] Verify the deployed copy actually carries the change:
      `grep -n "_skill_artifact_max_prefix" .claude/scripts/skill-base.sh` returns the helper, and
      the deployed `skill-base.sh` contains no `.next_artifact_number // 1` read.
- [ ] Re-run the two edited suites from the **deployed** tree as a post-deploy spot check.
- [ ] Record the dispatch's issue-log entries for anything that arose during implementation.

**Timing**: 30 minutes

**Depends on**: 2, 3, 4

**Verification Tier**: full

**Commit Mode**: per-substep

**Scope Hypothesis**: this phase asserts the deploy regenerates the whole `.claude/` tree and that
no source-store file outside Phases 1-4's four files changes as a result. Confirm with
`git status --short` after the deploy: `.claude/**` is gitignored, so the only tracked
modifications expected are the four source-store files already committed, plus any deploy-derived
tracked artifact the deploy script itself writes (e.g. a regenerated line-count file) — inspect
and account for each rather than assuming.

**Files to modify**:

- `__WHOLE_TREE__` - `deploy-headless.sh` regenerates the entire deployed `.claude/` tree
- `agent-system/extensions/core/scripts/skill-base.sh` - verification read-back only, no edit
  expected in this phase

**Verification**:

- `bash .claude/scripts/deploy-headless.sh` emits `[deploy-headless] RESULT=landed_verify_clean`
  (exit 0), i.e. the complete gate set aggregated by `verify-deploy.sh` — all gates, including
  gate 3 doc-lint, gate 4 task-reference lint, and gate 8's full shell-suite battery — is clean.
  No `--skip-slow` and no `--only-gate` narrowing is accepted as discharging this phase.
- The deployed `.claude/scripts/skill-base.sh` carries `_skill_artifact_max_prefix` and no
  `// 1`-defaulted `next_artifact_number` read.
- `bash .claude/scripts/../../agent-system/extensions/core/scripts/tests/run-all.sh --only
  test-orchestrate-build-dispatch.sh,test-skill-base-lifecycle.sh` green against the deployed
  tree.

---

## Testing & Validation

- [ ] Absent `next_artifact_number` + pre-supplied linked `reports/01_*.md` → research dispatch
      resolves `artifact_number: 2` (the task description's acceptance criterion).
- [ ] Same state → plan/implement dispatch resolves `artifact_number: 1` (`prev` shares the round).
- [ ] Sequence gap (`01`, `03` present, field absent) → research resolves `4`, proving max-prefix
      rather than count.
- [ ] Counter behind disk (`next_artifact_number: 1`, `reports/02_*.md` present) → plan resolves
      `2`, proving the counter self-heals.
- [ ] Counter-present regression pins unchanged: counter `2` → `current` `2`, `prev` `1`.
- [ ] Empty task directory + absent field → `1` for both modes (no behaviour change for a fresh
      task).
- [ ] Archive-aware: an ambient `TASK_DIR` under `specs/archive/` is the scan root.
- [ ] `ARTIFACT_PADDED` remains two-digit zero-padded.
- [ ] `bash agent-system/extensions/core/scripts/tests/test-orchestrate-build-dispatch.sh` and
      `test-skill-base-lifecycle.sh` both exit 0.
- [ ] `deploy-headless.sh` reaches `RESULT=landed_verify_clean`.

## Artifacts & Outputs

- `agent-system/extensions/core/scripts/skill-base.sh` — `_skill_artifact_max_prefix()` helper and
  the normalized `skill_read_artifact_number()`.
- `agent-system/extensions/core/scripts/tests/test-orchestrate-build-dispatch.sh` — one new group
  with the absent-field, gap, and behind-counter cases.
- `agent-system/extensions/core/scripts/tests/test-skill-base-lifecycle.sh` — direct resolution
  matrix for `skill_read_artifact_number`, and an updated residual list.
- `agent-system/extensions/core/context/reference/state-management-schema.md` — "Backward
  Compatibility" subsection aligned with the implemented derivation.
- Regenerated deployed `.claude/` tree (gitignored, not a committed artifact).
- `specs/407_derive_artifact_round_from_existing_artifacts/summaries/01_*.md` — implementation
  summary.

## Rollback/Contingency

The change is four committed source-store files plus a regenerated, gitignored deploy tree, so
rollback is ordinary and cheap:

- **Committed work**: `git revert` the phase commits in reverse order, then re-run
  `bash .claude/scripts/deploy-headless.sh` to regenerate `.claude/` from the reverted source
  store. No deployed-tree surgery is needed or permitted — `.claude/**` is a disposable deploy
  artifact.
- **Partial, uncommitted work that must be discarded**: this is a genuine rollback, so follow
  `context/contracts/recovery.md`'s rollback rung for the exact snapshot-then-rollback invocation
  shape (including its out-of-scope override flag, which the whole-tree deploy case may need)
  before running any destructive git command. Do not emit a bare precautionary snapshot as a
  routine start-of-phase step.
- **Behavioural contingency**: if the unconditional normalization turns out to change a round in a
  live task in an unwanted way, the narrowest retreat is to gate the normalization on the stored
  counter being absent or non-numeric — i.e. the research report's fallback-only variant. That
  retreat reopens the second-order advance-site collision documented under "Plan-Time Finding
  Beyond Research", so it is a stopgap to be paired with a follow-up record against the three
  `// 1` advance sites, not a resting state.
