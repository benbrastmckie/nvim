# Implementation Plan: Task #197

- **Task**: 197 - Make `/orchestrate N --research`/`--plan`/`--implement` work on a terminal (and/or archived) task
- **Status**: [IMPLEMENTING]
- **Effort**: 11 hours
- **Dependencies**: specs/196_research_first_default_unless_fast/ (COMPLETED; landed first, established the "routing rules live in the classifier, not in a caller post-adjustment" precedent reused here)
- **Research Inputs**: specs/197_forced_phase_on_terminal_and_archived_tasks/reports/01_forced-phase-terminal-archived-tasks.md
- **Artifacts**: plans/01_forced-phase-terminal-archived-tasks.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md, shell-strict-mode.md, shell-script-testing.md, source-store-deploy-boundary.md
- **Type**: meta
- **Lean Intent**: false

## Overview

`/orchestrate N --research` on a completed task silently dispatches nothing. The forcing
machinery (`--force-phases` parsing, `force_phases_remaining` seeding/consumption, the
`force_invoked` postflight pipeline) is already built and already correct; the task never
reaches it, because two `is_terminal_status` `continue`s in `orchestrate-cycle-plan.sh` run
first. Research confirmed that defect and the archived-classifier defect as described, and
surfaced two further blockers that sit on the same acceptance path (a hard terminal `exit 1`
inside `skill_validate_input`, and the total absence of a status-regression clamp on the
preflight side, which would permanently downgrade a `completed` task once a forced round
finished). This plan closes all four, plus a fifth surfaced during planning (an archived task's
directory has been moved to `specs/archive/`, so every `specs/{NNN}_{slug}` path derivation
resolves to a non-existent sibling), behind one shared archive-resolution library so the
archive rule exists in exactly one executable place.

Definition of done: a forced round dispatches and writes a new `MM_` artifact for a terminal
task in `active_projects` and for a completed-and-archived task; an unforced `/orchestrate` on
the same terminal set still stops with `all_terminal`; the task's status is `completed` before,
during, and after the forced round; classifier and cycle-plan agree on an archived task's
status; and the full gate set is green.

### Research Integration

The report (`reports/01_forced-phase-terminal-archived-tasks.md`) is integrated as follows:

- **Defect 1's fix is narrow.** Everything downstream of `eligible_tasks` already works for a
  forced phase on an already-advanced task. Only admission into `eligible_tasks` is missing.
  Section (f) is NOT reordered (Decision (a)); an exemption predicate guards the two existing
  `is_terminal_status` `continue`s instead. Phase 2.
- **Defect 2 (classifier archive-blindness)** is fixed in the classifier itself, mirroring
  `lookup_project`'s shape, per task 196's precedent — not as a caller post-adjustment.
  Phase 5.
- **Defect 3 (`skill_validate_input` hard-blocks terminal statuses and is archive-blind)** was
  not named in the task description; without it a forced round passes eligibility and is then
  `deferred to a later cycle` forever, reproducing the original complaint one layer down.
  Added to scope. Phase 3.
- **Defect 4 (no preflight-side regression clamp)** would permanently downgrade a `completed`
  task to `researched`/`planned`, violating this task's own MUST NOT clause. The postflight
  clamp cannot cover it: it reads its comparator live from `state.json`, by which point the
  same round's preflight has already overwritten it. Added to scope. Phase 4.
- The report's Risks table (stale-comparator invisibility, `needs_research` unranked carve-out,
  single-vs-mt engine parity, stubbed-vs-live fixture shape) is carried into Risks & Mitigations
  below.

### Prior Plan Reference

No prior plan for this task. Task 196's plan and summary were read by research; its Decision (a)
("routing logic lives in the classifier, not in a caller post-adjustment, to avoid a fifth
drift-prone site") is reused verbatim as the rationale for Phase 5's shape.

### Roadmap Alignment

No `specs/ROADMAP.md` in this repository. No roadmap phases.

## Goals & Non-Goals

**Goals**:
- `/orchestrate N --research|--plan|--implement` dispatches a forced round on a terminal task
  present in `active_projects`.
- The same works for a completed-and-**archived** task, with the classifier and cycle-plan
  agreeing on its resolved status.
- A terminal task's status is never regressed by a forced round: `completed` before, during,
  and after.
- All three forcing flags have an explicit, implemented, documented posture on terminal tasks.
- Fixture coverage for the active-terminal, archived-terminal, and unforced-terminal cases,
  including one LIVE (non-stubbed) fixture that pins the no-regression guarantee end to end.
- The archive normalization rule lives in exactly one sourced library, not in N hand-copied
  jq expressions.

**Non-Goals**:
- Making terminal tasks eligible for ORDINARY (unforced) dispatch. An `/orchestrate` with no
  forcing flag on a fully terminal set must still stop with `all_terminal`.
- Un-archiving. The archive read is strictly read-only; `specs/archive/state.json` is never
  written and `/todo`'s archive is left untouched (Decision (e)).
- Changing `not_started` default routing (task 196's territory).
- Changing `failed_tasks` / `deferred_deploy_checkpoint` membership handling — those two
  `continue`s are independent of `is_terminal_status` and stay exactly as they are.
- Any edit under `.claude/**` (disposable deploy tree). The source store
  `agent-system/extensions/core/**` is the sole edit target.

## Decisions

These resolve the five decision points the task description deferred to research and planning.
Research's recommendations are adopted; (c) is decided here, since research correctly declined
to resolve it.

- **(a) Eligibility mechanism**: compute a per-task "has a pending forced phase" predicate up
  front and use it to exempt exactly those tasks from the two `is_terminal_status` `continue`s.
  Do NOT reorder section (f). Its seeding and consumption logic is correct as-is once terminal
  tasks can reach it, and the (b)/(c)/(f) section structure plus the `mt_` write ordering stay
  coherent.
- **(b) Status during and after a forced round on a terminal task**: stays `completed`
  throughout. This requires the NEW preflight clamp (Phase 4) — verified, not assumed: today
  `skill_preflight_update` has no clamp parameter at all and `update-task-status.sh`'s
  `map_status()` has no current-status guard anywhere in the file, so `preflight:research`
  writes `researching` unconditionally, and the existing postflight clamp then compares against
  that preflight-corrupted value rather than the task's true status.
- **(c) `--implement` on a terminal task**: permitted on the same terms as `--research` and
  `--plan`; no stricter code-level gate. Rationale: on the status axis it is the *safest* of
  the three (`postflight:implement` resolves to `completed` unconditionally, and `implemented`
  is deliberately unranked, so no regression is even possible); the residual risk — dispatching
  an implementation agent against already-shipped code — is a risk the user takes on
  deliberately by typing the flag, and is not distinguishable in kind from `--implement` on an
  already-`implementing` task, which is already permitted today. Adding a confirmation gate
  here would be the only interactive gate in an explicitly non-interactive command. The posture
  is documented rather than gated (Phase 8), including the explicit warning that a forced
  `--implement` on a completed task re-runs implementation work.
- **(d) Classifier archive read**: the classifier gains its own archive read, sourced from the
  shared library of Phase 1, applied above the `engine` branch so `single` and `mt` move
  together. It keeps returning `group:"terminal"` for an archived-and-terminal candidate — no
  new verdict value. (A forced dispatch never consults the verdict anyway, since
  `effective_group` overrides it; the fix is required for correctness in its own right and
  because the single-task engine consumes the classifier's verdict directly.)
- **(e) All-terminal message and archive write posture**: no new message variant is needed —
  once (a)'s exemption is in place, a terminal-but-forced task no longer sets `all_done=true`,
  so the existing `all_terminal` message only ever fires when it is genuinely correct. The
  archive read is read-only. Completion of a forced round on an archived task is recorded by
  the artifact FILE written into the archived task directory; the `state.json` artifact link and
  `next_artifact_number` advance are no-ops for an archived task (their jq updates select an
  empty set) and the status write is deliberately skipped. That asymmetry is documented rather
  than papered over — see Phase 8.
- **(f) Archived task directory** (surfaced during planning, not in the report): `/todo` MOVES
  the task directory to `specs/archive/{NNN}_{slug}/`. Every `specs/{NNN}_{slug}` derivation
  therefore resolves to a non-existent path for an archived task, which would scatter the new
  round's dispatch file and artifacts into a fresh empty sibling directory. Resolution: a single
  `task_lookup_dir` helper prefers `specs/{NNN}_{slug}` when it exists and falls back to
  `specs/archive/{NNN}_{slug}` when that exists, so a forced round's artifacts land next to the
  task's existing reports and plans. Still no write to `specs/archive/state.json`.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Defect 4 ships unfixed and a forced `--research` permanently downgrades a `completed` task | H | H without an explicit guard (confirmed never exercised end-to-end today) | Phase 4 adds the preflight clamp; Phase 6 adds a LIVE non-stubbed fixture asserting final `state.json` status is still `completed` after a full forced round |
| Defect 3 is missed because it is absent from the task description's defect list | H | H without flagging | Named explicitly in Scope and given its own phase (Phase 3); Phase 6's dispatch assertions fail loudly if the build step defers |
| The preflight clamp is implemented differently from the postflight clamp and the two drift | M | M | Phase 4 mirrors `skill_postflight_update`'s exact shape: same optional-positional convention, same two-candidate `status-vocabulary.sh` resolution order, same unranked-target-means-no-clamp rule, same `[monotonic-max]` notice wording. Do not special-case `needs_research` at preflight — preflight's operation is always `research`/`plan`/`implement`, never that token |
| Widening `skill_validate_input` accidentally lets ordinary (unforced) dispatch reach a terminal task | H | L | The bypass is opt-in and default-off: absent the new argument, behavior is byte-for-byte today's. Phase 6's unforced-terminal fixture is the regression guard |
| An archived task's status write reaches `update-task-status.sh`, which exits 1 on a task absent from `active_projects`, killing the cycle under `set -e` | H | M | Phase 4 adds an explicit absent-from-`active_projects` skip (with a named notice) to both `skill_preflight_update` and `skill_postflight_update`, ahead of the clamp |
| Archive normalization gets hand-copied into the classifier and drifts from `lookup_project` | M | M | Phase 1 extracts it into one sourced library and refactors `lookup_project` to use it, so there is exactly one implementation (same discipline as `phase-heading-patterns.sh`) |
| Test suites resolve the DEPLOYED `.claude/scripts/` copies rather than the source store, so a source-only change appears to fail or a stale copy silently wins | M | M | Phase 9 redeploys via `bash .claude/scripts/deploy-headless.sh` before the gate run; the same deploy-first hazard is already documented in `skill_postflight_update`'s clamp comment |
| Single-task engine still breaks on an archived task if Phase 5 is scoped only to the `mt` table | M | M | Phase 5 places the archive read above the `engine` branch, applying identically to both engines; Phase 7 asserts both engines |
| Multiple phases edit `orchestrate-cycle-plan.sh` and `skill-base.sh` | M | M | Waves are sequenced so no two phases touching the same file run in parallel (see Dependency Analysis) |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2, 5 | 1 |
| 3 | 3, 7 | 3 blocked by 1, 2; 7 blocked by 5 |
| 4 | 4 | 1, 3 |
| 5 | 6, 8 | 6 blocked by 2, 3, 4; 8 blocked by 2, 3, 4, 5 |
| 6 | 9 | 6, 7, 8 |

Phases within the same wave can execute in parallel.

---

### Phase 1: Shared archive-aware task-lookup library [COMPLETED]

**Goal**: One sourced library owning the archive-state read, the status normalization, the
active-wins lookup, and the archived-task-directory resolution — so no consumer hand-copies the
rule.

**Tasks**:
- [x] Create `agent-system/extensions/core/scripts/lib/task-lookup-lib.sh`, following the
      shape and header conventions of `scripts/lib/status-vocabulary.sh` and
      `scripts/lib/phase-heading-patterns.sh` (idempotent source guard, exported functions,
      doc header naming its consumers and the "grep for sourcers" discovery mechanism). *(completed)*
- [x] Implement `task_lookup_archived_projects_json <state_file>`: reads
      `${state_file%state.json}archive/state.json`, flattens `completed_projects` and
      `archived_projects`, preserves `completed`/`abandoned`/`expanded` verbatim and maps any
      other archive-only status (e.g. `orphan_archived`) to `completed`. Emits `[]` when the
      archive file is absent or unreadable. Transcribe the existing jq from
      `orchestrate-cycle-plan.sh` verbatim — this is an extraction, not a rewrite. *(completed)*
- [x] Implement `task_lookup_entry <project_number> <state_file>`: echoes the matching record.
      Active projects win; the archive is consulted only when the number is absent from
      `active_projects`. Echoes nothing when neither has it. *(completed)*
- [x] Implement `task_lookup_is_active <project_number> <state_file>`: exit 0 iff the number is
      present in `active_projects` (the predicate the status-write skip in Phase 4 needs). *(completed)*
- [x] Implement `task_lookup_dir <project_number> <project_name> <repo_root>`: returns
      `specs/{NNN}_{project_name}` when that directory exists, else
      `specs/archive/{NNN}_{project_name}` when THAT exists, else the active path (so a
      brand-new task with no directory yet is unchanged). Path is repo-root-relative. *(completed)*
- [x] Refactor `orchestrate-cycle-plan.sh` to source the library and delete its inline
      `archived_projects_json` block and `lookup_project` body, delegating to the library
      functions. Preserve the existing function name `lookup_project` as a thin wrapper so no
      call site changes in this phase. *(completed)*
- [x] Resolve the library with the same two-candidate order used elsewhere in `skill-base.sh`:
      `${SKILL_REPO_ROOT}/.claude/scripts/lib/...` first, `$(dirname "${BASH_SOURCE[0]}")/lib/...`
      fallback second. Do not invent a third order. *(completed)*
- [x] `shellcheck` clean per `context/standards/shell-strict-mode.md`. *(completed)*

**Timing**: 1.5 hours

**Depends on**: none

**Verification Tier**: interface

**Scope Hypothesis**: this phase asserts that `orchestrate-cycle-plan.sh` is the ONLY current
site holding the archive-normalization jq. Confirm at implementation time with
`grep -rn 'archived_projects\|completed_projects' agent-system/extensions/core/scripts/` and
fold any additional site found into this phase's refactor rather than leaving a second copy.

**Files to modify**:
- `agent-system/extensions/core/scripts/lib/task-lookup-lib.sh` - new library
- `agent-system/extensions/core/scripts/orchestrate-cycle-plan.sh` - source the library;
  `lookup_project` becomes a wrapper; inline archive jq removed

**Verification**:
- `bash -n` and `shellcheck` clean on both files.
- `bash agent-system/extensions/core/scripts/tests/test-orchestrate-cycle-plan.sh` still green,
  in particular Group 7 (dependency resolution spans the archive) — the pre-existing regression
  guard for exactly this code path, which must pass unmodified.

---

### Phase 2: Forced-phase exemption in cycle-plan eligibility (Defect 1) [COMPLETED]

**Goal**: A terminal task with a pending forced phase reaches `eligible_tasks`; an unforced
terminal task still does not.

**Tasks**:
- [x] Add `task_has_forced_phase <t>` to `orchestrate-cycle-plan.sh`, defined next to
      `is_terminal_status`. Returns 0 when EITHER `canonical_force_phases_json` is non-empty
      (the CLI supplied forcing this invocation — already computed well before
      `is_terminal_status` is defined) OR `mt_json`'s `.force_phases_remaining[$t]` is a
      non-empty array (a queue seeded on a prior cycle and not yet exhausted). *(completed)*
- [x] Guard the all-terminal check's terminal `continue` (section (b)) with the new predicate:
      a terminal task with a pending forced phase must NOT be skipped, so `all_done` goes false
      and `emit_and_exit` with `stop_reason="all_terminal"` is not reached. *(completed)*
- [x] Guard the eligibility loop's terminal `continue` (section (c)) with the same predicate. *(completed)*
- [x] Leave the `failed_tasks` and `deferred_deploy_checkpoint` `continue`s in both sections
      completely untouched — they are independent of `is_terminal_status`. *(completed)*
- [x] Leave every OTHER `is_terminal_status` use untouched: the predecessor/dependency
      evaluations inside the eligibility loop and below it govern whether a *dependency* is
      satisfied, not whether the candidate itself is eligible. *(completed)*
- [x] Confirm section (f)'s seeding loop now reaches the terminal-but-forced task (it iterates
      `eligible_tasks`) and that `effective_group[$t]` is set from the forced phase, overriding
      whatever the classifier returned — including `group:"terminal"`. *(completed)*
- [x] Add a short comment at both guarded sites naming the contract: only an explicitly forced
      phase may admit a terminal task; ordinary dispatch never can. *(completed)*
- [x] `shellcheck` clean. *(completed)*

**Timing**: 1.5 hours

**Depends on**: 1

**Verification Tier**: local

**Files to modify**:
- `agent-system/extensions/core/scripts/orchestrate-cycle-plan.sh` - new predicate; two guarded
  `continue`s

**Verification**:
- `bash agent-system/extensions/core/scripts/tests/test-orchestrate-cycle-plan.sh` green,
  including Group 10 Case I's existing `all_terminal` fixture (which is `failed_tasks`-driven,
  not status-driven, and must remain valid unmodified) and Group 2's `--force-phases` dry-run
  fixtures.
- Manual `--dry-run` against a scratch fixture: a `completed` task with `--force-phases research`
  appears in the dispatch rows; the same task without the flag yields `stop_reason:"all_terminal"`.

---

### Phase 3: Terminal bypass and archive fallback in dispatch validation (Defect 3) [COMPLETED]

**Goal**: A forced dispatch survives `skill_validate_input`, resolves an archived task's
identity and directory correctly, and is not silently deferred forever.

**Tasks**:
- [x] `skill-base.sh`: give `skill_validate_input` an optional 2nd positional
      `allow_terminal` (default empty/false), following the same optional-positional convention
      `skill_postflight_update` already uses. When true, the `completed|abandoned|expanded`
      block is skipped and a named notice is emitted to stderr recording that a forced dispatch
      is proceeding against a terminal task. Absent the argument, behavior is byte-for-byte
      unchanged. *(completed)*
- [x] `skill-base.sh`: replace `skill_validate_input`'s `active_projects`-only `TASK_DATA`
      lookup with `task_lookup_entry` from Phase 1, so an archived task is found rather than
      hitting the "not found in state.json" `exit 1`. The not-found `exit 1` remains for a task
      present in neither. *(completed)*
- [x] `skill-base.sh`: export a new `TASK_IS_ARCHIVED` (`true`/`false`) from
      `skill_validate_input`, set from `task_lookup_is_active`. Phase 4 consumes it. *(completed)*
- [x] `skill-base.sh`: derive `TASK_DIR` via `task_lookup_dir` (Phase 1) instead of the
      hardcoded `specs/${PADDED_NUM}_${PROJECT_NAME}`, so an archived task's dispatch file and
      artifacts land in `specs/archive/{NNN}_{slug}/` next to its existing reports and plans.
      `TASK_DIR_ABS` continues to be `${SKILL_REPO_ROOT}/${TASK_DIR}`. *(completed)*
- [x] `orchestrate-build-dispatch.sh`: add an `--allow-terminal` flag to the argument loop,
      forwarded as `skill_validate_input`'s 2nd argument. Update the usage block and the
      script's own exit-code doc header (which currently transcribes the unconditional terminal
      `exit 1` as one of its two exit-1 causes). *(completed)*
- [x] `orchestrate-cycle-plan.sh`: append `--allow-terminal` to `build_args` when
      `forced_this_cycle[$t]` is true, using the same empty-value-skips-flag convention the
      surrounding flags already use. *(completed)*
- [x] `orchestrate-cycle-plan.sh`: route the remaining hardcoded
      `specs/${padded}_${project_name}` derivations through `task_lookup_dir` so an archived
      task's loop-guard, handoff anchor, dispatch-row `task_dir`, aux-dispatch paths, and
      hard-mode plan/handoff reads all resolve to the same directory the dispatch file was
      written into. Do not leave a mixed set. *(completed)*
- [x] `shellcheck` clean on all three files. *(completed)*

**Timing**: 2 hours

**Depends on**: 1, 2

**Verification Tier**: interface

**Scope Hypothesis**: this phase asserts there are five `specs/${padded}_${project_name}`-shaped
derivations in `orchestrate-cycle-plan.sh` (loop-guard seed, aux dispatch, exhausted loop guard,
hard-mode H1, and the dispatch-row `task_dir_rel`/`task_dir_abs` pair). Confirm at
implementation time with
`grep -n 'specs/\${\?padded\|specs/\$(printf' agent-system/extensions/core/scripts/orchestrate-cycle-plan.sh`
and convert every hit; if the count differs, convert what is actually there and record the
**(correction, implementation time)**: the live grep found SEVEN sites, not five — the aux
`.blocker-research.json`/`.drift-inspection.json` consume/rm sites (a separate pair from the aux
dispatch decision computation) use the same `specs/${aux_padded2}_${project_names[$t]}` shape and
were missed by the plan's own enumeration. All seven were converted (loop-guard seed, aux
dispatch decision, the two aux consume/rm sites, exhausted loop guard, hard-mode H1, and the
dispatch-row pair) — see the file diff. Also surfaced at implementation time, outside this
phase's originally enumerated files: `skill_read_artifact_number` in `skill-base.sh` had its own
independent, unenumerated archive-blindness bug (its `next_artifact_number` lookup only ever read
`.active_projects`, and its legacy fallback both reconstructed the active-only directory shape
AND crashed under `set -e -o pipefail` on a non-matching glob). Left unfixed, a forced round on
an archived task would build a valid `TASK_DIR` via `skill_validate_input` and then abort inside
`orchestrate-build-dispatch.sh`'s very next call, reproducing this task's own defect one call
deeper. Fixed in the same phase (archive-aware lookup via `task_lookup_entry`, archive-aware
fallback directory via ambient `TASK_DIR`, and the `set -e`-safety fix) since it sits squarely on
this phase's acceptance path.
correction rather than stopping at five.

**Files to modify**:
- `agent-system/extensions/core/scripts/skill-base.sh` - `skill_validate_input` signature,
  archive-aware lookup, `TASK_IS_ARCHIVED`, `TASK_DIR` resolution
- `agent-system/extensions/core/scripts/orchestrate-build-dispatch.sh` - `--allow-terminal` flag,
  usage, exit-code header
- `agent-system/extensions/core/scripts/orchestrate-cycle-plan.sh` - pass the flag; route task-dir
  derivations through the library

**Verification**:
- `bash agent-system/extensions/core/scripts/tests/test-orchestrate-cycle-plan.sh` green
  (Groups 4/5 exercise the live dispatch path; Group 12 asserts build-dispatch argv forwarding
  and must still pass with the new flag absent from unforced dispatches).
- Manual: `orchestrate-build-dispatch.sh <completed-task> research --session S --seq 1` exits 1
  without `--allow-terminal` and exits 0 with it, writing the dispatch file under the correct
  (archived or active) task directory.

---

### Phase 4: Preflight status clamp and archive-absent write skip (Defect 4, Decision (b)) [COMPLETED]

**Goal**: A forced round on a terminal task never writes an in-progress status, so `state.json`
reads `completed` before, during, and after — and an archived task's status write is skipped
rather than exiting 1.

**Tasks**:
- [x] `skill-base.sh`: give `skill_preflight_update` an optional 4th positional
      `status_clamp_mode`, mirroring `skill_postflight_update`'s existing shape exactly. Absent
      or empty preserves today's behavior byte-for-byte for every existing call site. *(completed)*
- [x] `skill-base.sh`: when `status_clamp_mode == "monotonic-max"`, resolve
      `lib/status-vocabulary.sh` with the same two-candidate order the postflight clamp uses,
      read the task's current status (archive-aware, via Phase 1's `task_lookup_entry`), and
      when `status_vocabulary_would_regress "$current" "$target"` is true, SKIP the
      `update-task-status.sh preflight` call with a named `[monotonic-max]` notice — while still
      running the extension hook and appending the lifecycle event, exactly as the postflight
      clamp does. Return 0; a clamp skip is never a refusal. *(completed)*
- [x] `skill-base.sh`: map the preflight operation to the resting status it would write
      (`research -> researching`, `plan -> planning`, `implement -> implementing`) for the
      regression comparison, mirroring `update-task-status.sh`'s `map_status()` rather than
      re-deriving a second table. Do NOT add a `needs_research` special case: preflight's
      operation is always one of the three above. *(completed)*
- [x] `skill-base.sh`: add an archive-absent guard AHEAD of the clamp in BOTH
      `skill_preflight_update` and `skill_postflight_update` — when
      `task_lookup_is_active` is false, skip the `update-task-status.sh` call entirely with a
      named notice explaining that the archive is read-only. Without this, an archived task's
      status write reaches `update-task-status.sh`'s "task not found in state.json" `exit 1`
      and kills the cycle under `set -e`. *(completed)*
- [x] `skill-base.sh`: make `skill_postflight_update`'s existing `_clamp_current_status` read
      archive-aware via `task_lookup_entry`, so the clamp's comparator is correct for an
      archived task rather than empty (empty currently disables the clamp silently). *(completed)*
- [x] `orchestrate-cycle-plan.sh`: pass `"monotonic-max"` as `skill_preflight_update`'s 4th
      argument when `forced_this_cycle[$t]` is true, and nothing otherwise. This value is
      already computed in the same process before the preflight call. *(completed)*
- [x] Confirm (do not assume) that with the clamp in place, `skill_postflight_update`'s existing
      monotonic-max clamp now reads `completed` as its comparator and correctly skips the
      `researched`/`planned` write, and that `implemented` remains a no-op rewrite to `completed`. *(completed)*
- [x] `shellcheck` clean. *(completed)*

**Timing**: 2 hours

**Depends on**: 1, 3

**Verification Tier**: interface

**Files to modify**:
- `agent-system/extensions/core/scripts/skill-base.sh` - preflight clamp parameter and body,
  archive-absent guards in both update functions, archive-aware postflight comparator, fail-safe
  shim for an unresolvable task-lookup-lib.sh
- `agent-system/extensions/core/scripts/orchestrate-cycle-plan.sh` - pass the clamp mode at the
  preflight call site
- `agent-system/extensions/core/scripts/tests/test-orchestrate-cycle-postflight.sh` - add
  `task-lookup-lib.sh` to the sandbox's require/copy lists (surfaced during this phase)

**Verification**:
- `bash agent-system/extensions/core/scripts/tests/test-orchestrate-cycle-postflight.sh` green
  (its Acceptance 6/7 monotonic-max fixtures must still pass unchanged).
- Manual scratch run of a full forced `--research` round against a `completed` fixture task with
  the REAL `update-task-status.sh`: `state.json` status is `completed` at every observation
  point. Phase 6 turns this into a committed fixture. Confirmed: ran to completion, dispatch file
  written, `state.json` status observed `completed` both before and after the forced round.

**(correction, implementation time)**: adding the unconditional `task_lookup_is_active` guard to
`skill_preflight_update`/`skill_postflight_update` surfaced two issues not named in the plan
text, both fixed in this phase:
1. `test-orchestrate-cycle-postflight.sh`'s sandbox never copied the new
   `lib/task-lookup-lib.sh` alongside its `skill-base.sh` copy (the same gap Phase 1 already hit
   and fixed in `test-orchestrate-cycle-plan.sh`, missed here because this test suite's own
   sandbox-setup list is independent). Without the fix, `task_lookup_is_active` was UNDEFINED in
   the sandbox process, and `! task_lookup_is_active ...` read the resulting "command not found"
   (exit 127) as "not active", silently skipping every preflight/postflight status write for
   every task in that suite (5 failures: acceptance 6/7/8b and the fd-3 invariant). Fixed by
   adding `task-lookup-lib.sh` to both the `require_file` and copy loops.
2. More generally: an undefined `task_lookup_is_active`/`task_lookup_entry` (a missing or
   not-yet-redeployed library, in ANY consumer, not just this test) would fail SILENTLY toward
   skipping every status write rather than failing loudly or preserving old behavior. Added a
   fail-safe shim block in `skill-base.sh` immediately after the two-candidate source attempt:
   if the functions did not resolve, define minimal shims reproducing this codebase's
   PRE-EXISTING active-projects-only behavior (with a loud one-time `WARNING:`), so a missing
   library degrades to yesterday's behavior instead of a silent global write outage.

---

### Phase 5: Classifier archive read (Defect 2, Decision (d)) [COMPLETED]

**Goal**: `orchestrate-triage-classify.sh` and `orchestrate-cycle-plan.sh` agree on an archived
task's status instead of one calling it nonexistent.

**Tasks**:
- [x] Source Phase 1's `task-lookup-lib.sh` in `orchestrate-triage-classify.sh`, with the same
      two-candidate resolution order used elsewhere, placed ABOVE the `engine` branch so
      `single` and `mt` behave identically. *(completed)*
- [x] Extend the up-front `lookup_json` jq (which resolves each candidate's `status` and
      `project_name` for the handoff read) to fall back to the flattened archive projects when
      the candidate is absent from `active_projects`. Active entries win. *(completed)*
- [x] Extend the verdicts jq the same way, so an archived-and-terminal candidate reaches the
      `is_terminal` branch and returns `group:"terminal"` with its real status — not the
      null-entry `group:"skip"` / "not found in state.json" branch. No new verdict value. *(completed)*
- [x] Keep the null-entry `skip` branch for a candidate genuinely present in neither store. *(completed)*
- [x] Update the classifier's own file-header table and its Context Flatness Constraint note to
      record that it now reads the sibling `archive/state.json` in addition to `state.json` —
      the same kind of read, not a new capability class. Keep both engine tables in the header
      in lockstep. *(completed)*
- [x] Consider the handoff read for an archived candidate: the handoff path must be derived
      from the resolved (possibly archived) task directory, not the active-path assumption.
      Use `task_lookup_dir`. *(completed)*
- [x] `shellcheck` clean. *(completed)*

**Timing**: 1.5 hours

**Depends on**: 1

**Verification Tier**: local

**Files to modify**:
- `agent-system/extensions/core/scripts/orchestrate-triage-classify.sh` - archive read, both jq
  lookups, header table and constraint note
- `agent-system/extensions/core/scripts/tests/test-orchestrate-triage-classify.sh` - add
  `lib/task-lookup-lib.sh` to the sandbox's require/copy lists (surfaced during this phase, same
  gap as Phase 1/4's test-fixture misses)

**Verification**:
- `bash agent-system/extensions/core/scripts/tests/test-orchestrate-triage-classify.sh` green
  (existing suite must pass unchanged; Phase 7 adds the new coverage). Confirmed: 48 passed,
  0 failed, after adding the missing library copy to the sandbox.
- Manual: the classifier returns `group:"terminal"` with `status:"completed"` for an archived
  task number, for BOTH `--engine single` and `--engine mt`. Confirmed against a fixture with one
  `completed_projects` entry and one `archived_projects` entry carrying `orphan_archived`
  (normalizes to `completed`) -- both resolved to `group:"terminal"`, `status:"completed"` on
  both engines.

**(correction, implementation time)**: sourcing `task-lookup-lib.sh` initially crashed this
script's own `bash -n`/execution with a bash syntax error, NOT a jq error: an apostrophe inside a
newly-added comment (`` the blocked arm's own ``) sat inside the jq program's *outer bash
single-quoted string*, terminating that string early and leaving the rest of the embedded jq
source to be parsed as literal bash. Fixed by rewording the comment without a contraction — this
file has zero apostrophes anywhere inside its embedded jq blocks for exactly this reason, a
convention now confirmed by grep rather than assumed.

---

### Phase 6: cycle-plan fixture coverage [NOT STARTED]

**Goal**: The three acceptance cases plus the no-regression guarantee are pinned by committed
fixtures that fail against the pre-fix scripts.

**Tasks**:
- [ ] Add a new Group to
      `agent-system/extensions/core/scripts/tests/test-orchestrate-cycle-plan.sh`, following the
      suite's existing conventions (`pass`/`fail`/`info` helpers, `mktemp -d` workdir with
      `trap EXIT`, inline heredoc fixtures, exit 0 iff `FAILED == 0`) per
      `context/standards/shell-script-testing.md`.
- [ ] Case A — active terminal, forced: a `completed` task in `active_projects` with
      `--force-phases research` produces a dispatch row with `phase: "research"` and
      `force: true`, and does NOT emit `stop_reason: "all_terminal"`.
- [ ] Case B — archived terminal, forced: a task absent from `active_projects` but present in
      `archive/state.json`'s `completed_projects`, with its directory at
      `specs/archive/{NNN}_{slug}/`, dispatches, and the dispatch row's `task_dir` points at
      the ARCHIVE directory. Model the archive fixture shape on Group 7, which already builds
      `archive/state.json` alongside a sibling `active_projects` state.
- [ ] Case C — unforced terminal: the same `completed` task with NO forcing flag yields
      `stop_reason: "all_terminal"` and zero dispatch rows. This is the Non-Goal regression
      guard.
- [ ] Case D — LIVE no-regression: a non-`--dry-run` run against a `completed` fixture task with
      `--force-phases research`, using the REAL `update-task-status.sh` and `skill-base.sh`
      (NOT the stubbed-`update-task-status.sh` pattern Groups 4/5 use), asserting `state.json`'s
      status is still exactly `completed` after the dispatch. Model the sandbox on
      `test-orchestrate-cycle-postflight.sh`, which copies real collaborator scripts unmodified.
- [ ] Case E — `--force-phases implement` on a `completed` task dispatches (Decision (c)'s
      posture is tested, not just documented).
- [ ] Verify Group 10 Case I's existing `all_terminal` fixture still passes UNMODIFIED (it is
      driven by a pre-seeded `failed_tasks` entry against an `implementing` task, so this
      task's change does not touch it). If it needed modification, that is a signal the
      exemption predicate was written too broadly — investigate rather than edit the fixture.
- [ ] Mutation check per `shell-script-testing.md`: confirm each new case FAILS against the
      pre-fix scripts (stash the source changes, or run against a pristine copy) and record that
      evidence in the commit body.
- [ ] `shellcheck` clean.

**Timing**: 2 hours

**Depends on**: 2, 3, 4

**Verification Tier**: full

**Scope Hypothesis**: this phase asserts five new cases (A-E) suffice for the acceptance bar.
Confirm at implementation time by re-reading the ACCEPTANCE clause in the dispatch and mapping
each sentence to a case; add cases for any unmapped sentence rather than declaring the list
closed.

**Files to modify**:
- `agent-system/extensions/core/scripts/tests/test-orchestrate-cycle-plan.sh` - new group,
  Cases A-E

**Verification**:
- `bash agent-system/extensions/core/scripts/tests/test-orchestrate-cycle-plan.sh` exits 0 with
  every new case reported PASS.
- Each new case reported FAIL against the pre-fix source (mutation evidence).

---

### Phase 7: classifier fixture coverage [NOT STARTED]

**Goal**: The archived-task lookup is pinned for both engines.

**Tasks**:
- [ ] Add archive fixture support to
      `agent-system/extensions/core/scripts/tests/test-orchestrate-triage-classify.sh` — the
      suite has no archive surface today, so the sandbox needs a
      `$WORKDIR/specs/archive/state.json` alongside its existing `$WORKDIR/specs/state.json`.
- [ ] Case: a candidate present ONLY in `archive/state.json`'s `completed_projects` classifies
      as `group:"terminal"` with `status:"completed"`, NOT `group:"skip"` / "not found in
      state.json". Assert for both `--engine single` and `--engine mt`.
- [ ] Case: a candidate present in `archived_projects` with an archive-only status
      (`orphan_archived`) normalizes to `completed` and classifies as `terminal`.
- [ ] Case: a candidate present in NEITHER store still classifies as `group:"skip"` with the
      existing "not found in state.json" reason — the null-entry branch is preserved.
- [ ] Case: a candidate present in BOTH stores is governed by its ACTIVE entry (active wins).
- [ ] Mutation check: confirm the archived cases FAIL against the pre-fix classifier.
- [ ] `shellcheck` clean.

**Timing**: 1.5 hours

**Depends on**: 5

**Verification Tier**: full

**Files to modify**:
- `agent-system/extensions/core/scripts/tests/test-orchestrate-triage-classify.sh` - archive
  sandbox plus four new cases

**Verification**:
- `bash agent-system/extensions/core/scripts/tests/test-orchestrate-triage-classify.sh` exits 0.
- Archived cases FAIL against the pre-fix classifier (mutation evidence).

---

### Phase 8: Documentation [NOT STARTED]

**Goal**: The forcing flags' behavior on terminal and archived tasks is stated plainly where a
reader looks for it, and the preflight/postflight clamp pairing is recorded.

**Tasks**:
- [ ] `agent-system/extensions/core/commands/orchestrate.md`: extend the `--research`,
      `--plan`, and `--implement` rows to state plainly that each applies to a terminal
      (completed/abandoned/expanded) task and to an archived one; that the task's status is NOT
      regressed by the forced round; that an `/orchestrate` with NO forcing flag on a terminal
      task still stops with `all_terminal` and dispatches nothing; and, for `--implement`
      specifically, that forcing it on a completed task re-runs implementation work against
      already-shipped code (Decision (c)'s posture, documented rather than gated).
- [ ] `agent-system/extensions/core/docs/architecture/orchestrate-state-machine.md`: update the
      Dependency Gating Model prose so the eligibility rule carries the forced-phase exemption;
      update the ASCII diagram's "All-terminal check" and "Eligibility" nodes; update the worked
      examples with a terminal-but-forced walkthrough.
- [ ] Same file: add a short subsection recording that BOTH `skill_preflight_update` and
      `skill_postflight_update` must be clamp-aware for a forced round on an already-advanced
      task, and why — the two calls are separate processes potentially far apart in time, with
      `state.json` as the only persisted intermediate signal, so a preflight write corrupts the
      postflight clamp's own comparator.
- [ ] Same file: record the archived-task posture — the archive is read-only; a forced round's
      artifacts land in `specs/archive/{NNN}_{slug}/`; the `state.json` artifact link,
      `next_artifact_number` advance, and status write are all skipped or no-ops for an archived
      task, and that asymmetry is intended, not a bug.
- [ ] `agent-system/extensions/core/merge-sources/claudemd.md` (the `/orchestrate` command-table
      row): extend the existing "never regressing status" clause to name terminal and archived
      tasks, so the generated `CLAUDE.md` row is accurate.
- [ ] Do NOT write task numbers into any of these files (they live outside `specs/`) — cite
      durable anchors: script names, function names, section headings. See
      `rules/no-task-references-in-deliverables.md`.

**Timing**: 1 hour

**Depends on**: 2, 3, 4, 5

**Verification Tier**: prose

**Files to modify**:
- `agent-system/extensions/core/commands/orchestrate.md` - three flag rows
- `agent-system/extensions/core/docs/architecture/orchestrate-state-machine.md` - gating prose,
  diagram nodes, worked examples, two new subsections
- `agent-system/extensions/core/merge-sources/claudemd.md` - `/orchestrate` row

**Verification**:
- Diff read-through confirming every changed hunk is prose/markdown with no executable surface.
- `bash .claude/scripts/check-task-references.sh` clean (no task numbers introduced outside
  `specs/`).

---

### Phase 9: Gate set, deploy, and mirror [NOT STARTED]

**Goal**: Everything green against the deployed tree the tests actually resolve.

**Tasks**:
- [ ] `shellcheck` clean on every modified shell file, per
      `context/standards/shell-strict-mode.md`.
- [ ] Redeploy the source store to `.claude/` via `bash .claude/scripts/deploy-headless.sh`
      before running the gate set — several collaborators resolve
      `${SKILL_REPO_ROOT}/.claude/scripts/...` first, so a source-only change can otherwise be
      silently masked by a stale deployed copy.
- [ ] Confirm the new `scripts/lib/task-lookup-lib.sh` is actually present in the deployed tree
      after the redeploy (a new file is the most likely deploy-manifest omission).
- [ ] Run the full gate set: `test-orchestrate-cycle-plan.sh`,
      `test-orchestrate-triage-classify.sh`, `test-orchestrate-cycle-postflight.sh`,
      `check-task-references.sh`.
- [ ] Verify no file under `.claude/**` was hand-edited at any point (only the deploy wrote
      there): `git status` review plus a scan of the working tree.
- [ ] End-to-end smoke, live: `/orchestrate` cycle-plan against a real `completed` task with
      `--force-phases research` dispatches and leaves the task's status at `completed`; the same
      task unforced stops with `all_terminal`.

**Timing**: 1 hour

**Depends on**: 6, 7, 8

**Verification Tier**: full

**Files to modify**:
- none (verification and deploy only)

**Verification**:
- All four gate scripts exit 0.
- `shellcheck` reports no findings on the modified scripts.

---

## Testing & Validation

- [ ] `bash agent-system/extensions/core/scripts/tests/test-orchestrate-cycle-plan.sh` exits 0,
      including the five new cases and the unmodified Group 7 and Group 10 Case I fixtures.
- [ ] `bash agent-system/extensions/core/scripts/tests/test-orchestrate-triage-classify.sh`
      exits 0, including the four new archive cases for both engines.
- [ ] `bash agent-system/extensions/core/scripts/tests/test-orchestrate-cycle-postflight.sh`
      exits 0 with its existing monotonic-max fixtures unmodified.
- [ ] `bash .claude/scripts/check-task-references.sh` clean.
- [ ] `shellcheck` clean on `task-lookup-lib.sh`, `orchestrate-cycle-plan.sh`,
      `orchestrate-triage-classify.sh`, `orchestrate-build-dispatch.sh`, `skill-base.sh`, and
      both modified test suites.
- [ ] Mutation evidence recorded for every new fixture case (each fails pre-fix).
- [ ] Acceptance walk: forced research on an active-terminal task dispatches and writes a new
      `MM_` artifact; forced research on an archived-terminal task dispatches into
      `specs/archive/{NNN}_{slug}/`; unforced terminal stops with `all_terminal`; status stays
      `completed` throughout in all three.

## Artifacts & Outputs

- `agent-system/extensions/core/scripts/lib/task-lookup-lib.sh` (new)
- `agent-system/extensions/core/scripts/orchestrate-cycle-plan.sh` (modified)
- `agent-system/extensions/core/scripts/orchestrate-triage-classify.sh` (modified)
- `agent-system/extensions/core/scripts/orchestrate-build-dispatch.sh` (modified)
- `agent-system/extensions/core/scripts/skill-base.sh` (modified)
- `agent-system/extensions/core/scripts/tests/test-orchestrate-cycle-plan.sh` (modified)
- `agent-system/extensions/core/scripts/tests/test-orchestrate-triage-classify.sh` (modified)
- `agent-system/extensions/core/commands/orchestrate.md` (modified)
- `agent-system/extensions/core/docs/architecture/orchestrate-state-machine.md` (modified)
- `agent-system/extensions/core/merge-sources/claudemd.md` (modified)
- `specs/197_forced_phase_on_terminal_and_archived_tasks/summaries/01_forced-phase-terminal-archived-tasks-summary.md`

## Rollback/Contingency

Every phase is a self-contained commit against the source store, so `git revert` of a phase
commit restores prior behavior; `.claude/` is disposable and is restored by re-running
`deploy-headless.sh` after any revert.

The two highest-risk reversals:

- **Phase 4 (clamps)**: if the preflight clamp misfires and blocks an ordinary (unforced)
  status write, the blast radius is every dispatch. Mitigation before revert: the clamp is
  opt-in via the 4th positional argument and only cycle-plan's forced path passes it, so
  reverting only cycle-plan's one-line call-site change disarms it entirely while leaving the
  rest of the work in place.
- **Phase 3 (`skill_validate_input` widening)**: if the terminal bypass leaks into unforced
  dispatch, revert `orchestrate-cycle-plan.sh`'s `--allow-terminal` append; the flag then has no
  caller and the terminal block behaves exactly as before.

If Phase 1's library extraction destabilizes `lookup_project`, revert Phase 1 alone and
re-implement Phases 3/4/5's archive reads against the existing inline `lookup_project` shape —
accepting the duplication risk the library was meant to remove, and recording that trade-off.
