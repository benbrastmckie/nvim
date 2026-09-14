# Research Report: Task #197

- **Task**: 197 - Make `/orchestrate N --research`/`--plan`/`--implement` work on a terminal (and/or archived) task
- **Started**: 2026-09-09T13:15:00Z
- **Completed**: 2026-09-09T13:43:00Z
- **Effort**: ~2 hours (codebase archaeology, no web research needed)
- **Dependencies**: specs/196_research_first_default_unless_fast/ (companion task, lands first, COMPLETED)
- **Sources/Inputs**: Codebase read of agent-system/extensions/core/scripts/{orchestrate-cycle-plan,orchestrate-triage-classify,orchestrate-cycle-postflight,orchestrate-build-dispatch,update-task-status,skill-base}.sh, agent-system/extensions/core/scripts/lib/status-vocabulary.sh, agent-system/extensions/core/commands/orchestrate.md, agent-system/extensions/core/docs/architecture/orchestrate-state-machine.md, agent-system/extensions/core/scripts/tests/{test-orchestrate-cycle-plan,test-orchestrate-triage-classify,test-orchestrate-cycle-postflight}.sh, specs/196_research_first_default_unless_fast/{plans,summaries}/01_*.md
- **Artifacts**: reports/01_forced-phase-terminal-archived-tasks.md (this file)
- **Standards**: report-format.md, subagent-return.md, shell-strict-mode.md

## Executive Summary

- **Defect 1 (ordering) and Defect 2 (archive lookup), as described in the task, are both real and confirmed on disk with exact line numbers.** Defect 1's actual required fix is narrower than it first appears: `force_phases_remaining` seeding and the entire `force_invoked` pipeline (clamp, artifact linking, artifact-round advance) downstream of eligibility **already exist and are already correct** for research/plan — they were built by an earlier task specifically for "force a phase on an already-advanced task." The only missing piece is admitting a terminal-but-forced task into `eligible_tasks` at all.
- **A third, previously unnamed defect blocks the fix even after 1 and 2 are closed**: `orchestrate-build-dispatch.sh` calls `skill_validate_input()` (`scripts/skill-base.sh:184-210`), which unconditionally `exit 1`s on any terminal status (and, independently, is `active_projects`-only with no archive fallback — the same gap as the classifier). Left unfixed, a forced round on a terminal task would pass eligibility but then get silently `deferred to a later cycle` forever by `orchestrate-cycle-plan.sh`'s own `build_exit != 0` handling (`orchestrate-cycle-plan.sh:1758-1767`) — reproducing the user's original complaint one layer down.
- **A fourth, previously unnamed defect threatens the task's own MUST NOT clause**: `skill_postflight_update`'s "monotonic-max" clamp (`scripts/skill-base.sh:689-714`, already shipped for the general "force a phase on an already-advanced task" feature) is the ONLY status-regression guard in the whole pipeline — `skill_preflight_update` (`scripts/skill-base.sh:217-233`, called first, in the SAME process, moments before dispatch) has no such guard and unconditionally overwrites `state.json`'s status to the phase's in-progress variant (`researching`/`planning`/`implementing`) regardless of the task's current status. Because the postflight clamp reads its "current status" comparator live from `state.json` at postflight time — by which point preflight has already overwritten it — the clamp's comparison is against the value preflight just wrote, not the task's true pre-round status. For a task at `completed` (rank 7) this produces a genuine, **permanent** downgrade to `researched` (rank 2) or `planned` (rank 4) once the forced round completes, exactly the regression the task's MUST NOT clause forbids. This has apparently never been exercised end-to-end: every existing fixture that exercises `--force-phases` either runs `--dry-run` (which never persists) or stubs `update-task-status.sh` entirely.
- Recommendation for Decision (a): compute a per-task "has a pending forced phase" boolean up front (from the CLI's `canonical_force_phases_json`, already computed before the all-terminal check, plus any already-stored `mt_json` `.force_phases_remaining[$t]`) and use it to exempt exactly those tasks from the `is_terminal_status` `continue` at both the all-terminal check (`orchestrate-cycle-plan.sh:1138-1150`) and the eligibility loop (`:1152-1259`) — not reordering the (f) section, whose actual seeding/consumption logic can stay exactly where it is.
- Recommendation for Decision (b): extend the monotonic-max clamp to `skill_preflight_update` (mirroring the existing 7th-argument `status_clamp_mode` shape `skill_postflight_update` already has) so a forced round on a `completed` task never writes `researching`/`planning`/`implementing` in the first place — state.json shows `completed` throughout and after. This is a NEW code change, not reuse of existing plumbing, and is required for the FAVORED design in the task description to actually hold.
- Recommendation for Decision (c): `--implement` forced on a `completed` task is uniquely safe on the STATUS axis (postflight always resolves to `completed` regardless, since `"implemented"` is deliberately unranked and `map_status` collapses `postflight:implement` to `completed` unconditionally) but is the one flag where the real-world risk is not a plumbing defect at all — it is dispatching a fresh implementation agent against code that already shipped. Recommend the same mechanical treatment as `--research`/`--plan` (no code-level special case) but flag this explicitly as a product/policy decision for the planner or user, not a research-resolvable one.
- Recommendation for Decision (d): reuse Decision (a)'s classifier-owns-the-rule precedent from the companion task (196) — give `orchestrate-triage-classify.sh` its own archive read, mirroring `lookup_project()`'s existing shape in `orchestrate-cycle-plan.sh:405-425`, rather than having the caller pre-resolve and pass in a status. This keeps the "one code path" discipline the classifier's own header asserts, and independently matters because the single-task engine calls this classifier directly (its own archive-blindness is a live bug irrespective of the forced-phase question).
- Recommendation for Decision (e): the all-terminal message differentiation falls out for free once (a)'s exemption is implemented in `is_terminal_status`'s two call sites — a terminal-but-forced task no longer trips `all_done=true`, so the existing `stop_reason="all_terminal"` message only ever fires when it is genuinely correct. The archive read should be read-only (no un-archiving); the eventual completion of a forced round on an archived task is recorded via the existing artifact-link + `next_artifact_number` advance mechanism (`orchestrate-cycle-postflight.sh:772-797`), which already runs against whatever `state.json`/archive location `lookup_project` resolved — no new write path is needed.

## Context & Scope

This is a meta task on `/orchestrate`'s own state machine. The description names two defects
(ordering, archive) and asks the research phase to weigh five decisions before planning begins.
Per `.claude/rules/source-store-deploy-boundary.md`, all citations below are to
`agent-system/extensions/core/**` (the source store); `.claude/**` is the disposable deploy
mirror and was not read for this research.

The companion task (196, "research-first default unless `--fast`") landed first and is
COMPLETED; its plan/summary were read in full as required by Decision (d)'s pointer ("the
research-first default task lands first and may already have established a precedent"). That
precedent — **routing logic lives in the classifier itself, not as a caller post-adjustment,
specifically to avoid a fifth drift-prone site and to keep `--dry-run` fidelity free** — is
reused directly in Decision (d) below.

## Findings

### Codebase Patterns

**Defect 1 (ordering) — confirmed, and narrower than described.**

- `is_terminal_status()` (`orchestrate-cycle-plan.sh:1123-1128`) is a pure predicate
  (`completed|abandoned|expanded`).
- The all-terminal check (`:1138-1150`) and the eligibility loop's terminal `continue`
  (`:1152-1259`, terminal check at `:1156`) both run **before** any force-phases logic. Section
  (f) "Per-task force_phases consumption" does not begin until `:1328`.
- Critically, section (f)'s lazy-seed loop (`:1332-1336`, `.force_phases_remaining[$t] //= $q`)
  and the effective-group override (`:1338-1350`) both iterate **only over `eligible_tasks`** —
  the array `is_terminal_status`'s `continue` at `:1156` already excluded the terminal candidate
  from. A terminal task therefore never gets `force_phases_remaining` seeded at all today, on any
  cycle, regardless of how many times `--force-phases` is passed.
- Everything downstream of `eligible_tasks` that a forced round needs is **already built and
  already correct**, because it was built for the general "force a phase on an already-advanced,
  non-terminal task" feature (e.g. `--research` forced on an `implementing` task):
  - `effective_group[$t]="$forced_phase"` (`:1345`) overrides whatever the classifier said,
    unconditionally, whenever `force_phases_remaining[$t]` is non-empty — so even the
    classifier's own `group:"terminal"` verdict (see Defect 2 below) or the degraded fallback's
    `*) triage_group[$t]="skip"` arm (`:1315`, no `completed` case exists) are harmless once a
    task reaches this point, because neither is consulted when a forced phase is pending.
  - `forced_this_cycle[$t]` (`:1339-1350`) is threaded all the way to the dispatch row's `force`
    field (`:1831-1833`) and from there to `orchestrate-cycle-postflight.sh --force-invoked`
    (comment at `orchestrate-cycle-plan.sh:177-183`; consumed at
    `orchestrate-cycle-postflight.sh:157,176,662`).
  - `orchestrate-cycle-postflight.sh:662-666` sets `clamp_mode="monotonic-max"` whenever
    `force_invoked=true`; artifact linking (`:772-790`) is **unconditional** on `artifact_path`
    being set (independent of the status case-statement and its clamp), matching the
    `[monotonic-max]` skip notice's own claim that "the artifact link, if any, is still applied
    by the caller" (`skill-base.sh:709`); and `next_artifact_number` advance
    (`orchestrate-cycle-postflight.sh:792-797`) already special-cases `force_invoked=true` +
    `planned`/`implemented` to open a new round even though those dispatch statuses do not
    ordinarily advance the round.
  - Nothing after the eligibility loop (`orchestrate-batch-admit.sh` admission at `:1353-1440`,
    task-lock, dispatch-seq mint, `skill_preflight_update`, `orchestrate-build-dispatch.sh`) reads
    `current_statuses[$t]` again or contains any other `is_terminal_status` gate — confirmed by
    exhaustive grep (`is_terminal_status` appears only at lines 1123, 1140, 1156, 1170, 1268,
    1300; none of the latter three are reachable once a task is in `eligible_tasks`).
  - **Conclusion**: Defect 1's code fix is genuinely narrow — exempt a terminal-but-forced task
    from exactly the two `is_terminal_status`-based `continue`s at `:1140` and `:1156`. No
    restructuring of (f) is needed or advisable.

**Defect 2 (archive lookup in the classifier) — confirmed, functionally inert for forced
dispatch today, but a real independent defect.**

- `orchestrate-cycle-plan.sh`'s own `current_statuses[t]` (populated at `:865-883`, via
  `lookup_project()` at `:415-425`) is **already archive-aware** — `lookup_project` checks
  `active_projects` then falls back to `${STATE_FILE%state.json}archive/state.json`'s flattened
  `completed_projects`/`archived_projects` (`:405-413`), exactly as the task description states.
  This means the top-level `task_args` (the numbers a user names on `/orchestrate N`) already
  resolve correctly today for a completed-and-archived task.
- `orchestrate-triage-classify.sh` independently reads `$state_arr[0].active_projects` only
  (`:256-257`, `:350`), with no archive fallback. For a candidate absent from `active_projects`,
  `$entry == null` → `group:"skip"`, `reason:"...not found in state.json"` (`:355-358`).
- **However**, because `effective_group` (Decision above) overrides the classifier's verdict
  unconditionally whenever a forced phase is pending, an archived-and-terminal task with
  `--research` forced would *still dispatch correctly* today purely by luck of override order —
  the classifier's wrong "skip" verdict is never consulted. `triage_reason[$t]` is only read when
  `effective_group[$t] == "needs_human"` (`:1442`), which a forced dispatch never is.
- This does **not** make Defect 2 optional to fix. Two independent reasons: (1) the task
  description's own bar — "the classifier and cycle-plan agreeing on its status" — is a
  correctness requirement in itself, not merely an instrumental one; (2) the classifier is also
  called directly by the **single-task** `/orchestrate` engine (per its own header comment,
  `orchestrate-triage-classify.sh:12-23`), which has no analogue of `orchestrate-cycle-plan.sh`'s
  pre-filtering `lookup_project` — for that engine, an archived task's classification is
  consumed directly and is genuinely broken today, independent of forcing.
- Decision (d)'s companion-task precedent (196): effort-awareness was added as a new classifier
  input (`--effort <fast|hard>`) rather than a caller-side post-adjustment, specifically to avoid
  a fifth drift-prone site (`orchestrate-triage-classify.sh`'s own header names four sites that
  must move in lockstep: the live classifier, both engine tables in its own header comment, and
  the degraded fallback in `orchestrate-cycle-plan.sh`). Applying that same principle here favors
  giving the classifier its own archive read (mirroring `lookup_project`'s exact shape) rather
  than threading a caller-resolved status in — the classifier's file-header already documents the
  read-only Context Flatness Constraint ("reads ONLY specs/state.json and... never a plan,
  report, or summary file"), and reading the sibling `archive/state.json` file is the same kind
  of read, not a new capability class.

**Defect 3 (newly discovered) — `orchestrate-build-dispatch.sh` independently hard-blocks
terminal tasks, with no bypass and no archive fallback.**

- `orchestrate-build-dispatch.sh:147` calls `skill_validate_input "$task_number"`
  (`skill-base.sh:185-210`), which:
  - Reads `TASK_DATA` from `.active_projects` only (`:188-190`, no archive fallback — same gap
    class as Defect 2, but in a different file).
  - `exit 1`s immediately if `TASK_DATA` is empty ("not found in state.json").
  - `exit 1`s immediately if `TASK_STATUS` is `completed|abandoned|expanded` (`:204-208`), with
    **no parameter to bypass this for a forced dispatch** — `skill_validate_input`'s signature
    is a single positional argument, and no caller passes anything else.
- This function's own header (`:181-184`) documents the exit-1 contract explicitly and
  `orchestrate-build-dispatch.sh`'s own header (`:59-60`) transcribes it verbatim as one of its
  two exit-1 causes.
- `orchestrate-cycle-plan.sh`'s call site (`:1758-1767`) captures this exit code via
  `run_capture_stdout` and, on any non-zero, emits a `deferred` row with reason
  `"orchestrate-build-dispatch.sh failed; deferring to a later cycle"` — never a hard failure of
  the cycle itself, but also never anything that would resolve on a later cycle, since the SAME
  terminal status (once Defects 1/2 are fixed but this one is not) reproduces the exact same
  refusal every time. **This is the same silent-no-op failure mode the task exists to fix,
  relocated one call deeper.**
- Because `skill_validate_input` reads status directly from `state.json` at call time (which by
  then reflects whatever `skill_preflight_update` — called immediately before, at `:1725` — just
  wrote), this defect interacts with Defect 4 below: if Defect 4 is fixed first (preflight clamp
  keeps status at `completed`), `skill_validate_input` would still see `completed` and still
  refuse — so Defect 3 must be fixed independently; fixing Defect 4 does not incidentally fix it.
- **This defect is not named in the task description's DEFECT 1/DEFECT 2 list and must be added
  to scope**, or the acceptance criteria ("`/orchestrate N --research` on a completed task...
  dispatches a research round and writes a new MM_ artifact") cannot be met even after Defects 1
  and 2 are closed.

**Defect 4 (newly discovered) — no preflight-side status-regression guard; the existing
monotonic-max clamp cannot protect a terminal task's status through a forced round as currently
wired.**

- `skill_preflight_update` (`skill-base.sh:217-233`) has a 3-argument signature
  (`task_number, operation, session_id`) with **no clamp parameter at all**, unlike
  `skill_postflight_update`'s optional 7th `status_clamp_mode` argument. It calls
  `update-task-status.sh preflight ...` (`:223`) unconditionally.
- `update-task-status.sh`'s `map_status()` (`:278-312`) has no current-status guard whatsoever —
  confirmed by exhaustive grep for `regress|rank|status_vocabulary|current_status` in that file
  (only hits are the preflight/postflight `case` arms themselves and unrelated phase-accounting
  code). `preflight:research → researching`, `preflight:plan → planning`,
  `preflight:implement → implementing` are written unconditionally regardless of the task's
  current status.
- `skill_postflight_update`'s monotonic-max clamp (`skill-base.sh:689-714`) is the **only**
  regression guard in the pipeline, and it reads `_clamp_current_status` **live from
  `specs/state.json` at postflight-call time** (`:704-706`) — by which point, in the real
  two-process pipeline (`orchestrate-cycle-plan.sh` dispatches; a later, separate
  `orchestrate-cycle-postflight.sh` invocation reports the outcome), the SAME forced round's own
  preflight write has already overwritten `state.json`'s status to the in-progress variant.
- Concretely, for a task originally `completed` (rank 7) with `--research` forced: preflight
  writes `researching` (rank 1, unconditional, no clamp). Later, postflight's clamp compares
  `_clamp_current_status="researching"` (rank 1, the value preflight itself just wrote) against
  `target="researched"` (rank 2). `status_vocabulary_would_regress` returns false (2 > 1, "not a
  regression"), so the clamp does **not** skip the write — `state.json` ends the round at
  `researched`, a **permanent regression from the task's true original status (`completed`,
  rank 7)**, directly violating this task's own MUST NOT clause ("Do not regress a completed
  task's status as a side effect of the fix").
- The clamp's own design comments (`skill-base.sh:648-650`) describe exactly the intended
  protected scenario — "a forced `--plan` dispatch where the task is already at `planning`
  (rank 3)" — which implicitly assumes `_clamp_current_status` still reflects that elevated
  status at postflight time. That assumption silently fails whenever the SAME forced round's own
  preflight write has already downgraded it, which is true for every forced round on any
  already-advanced task, not just terminal ones — but it is invisible for the already-shipped,
  already-tested use cases specifically because their target ranks happen to be forward of (or
  equal to) the task's ordinary resting rank at that phase, so the wrong comparator input
  coincidentally does not change the verdict. Terminal tasks (`completed` rank 7, the highest
  rank in the whole enum) are the first case where the coincidence breaks.
- This gap has **never been exercised end-to-end**: `test-orchestrate-cycle-plan.sh`'s only
  `--force-phases` fixtures either run `--dry-run` (Group 2, "dry-run never persists
  `force_phases_remaining`... mutates nothing") or stub `update-task-status.sh` completely (Group
  4/5's live fixture at `:264-269`, which explicitly asserts status 501's `"implementing"` is
  "unaffected by dispatch" at `:377` — precisely because the stub never really writes it).
  `test-orchestrate-cycle-postflight.sh`'s monotonic-max fixtures (Acceptance 6/7, `:354-449`)
  seed the "current status" directly via `write_state`, exercising the clamp function in
  isolation with a hand-picked comparator value — never the real preflight-then-postflight
  sequence that would reveal the stale-comparator problem.
- `status_vocabulary_rank("implemented")` is separately unranked (only `"implementing"` is a
  ranked key; see `status-vocabulary.sh`'s `STATUS_VOCABULARY_LIFECYCLE_RANK`), so
  `status_vocabulary_would_regress` always returns false for an `"implemented"` target regardless
  of current status — but this happens to be harmless for `--implement`, since
  `map_status`'s `postflight:implement` arm resolves to `STATE_STATUS="completed"`
  unconditionally (`update-task-status.sh:288`) — a no-op rewrite for an already-`completed`
  task, not a regression, independent of whether the clamp fires.

### Documentation and Test Surfaces Requiring Updates (Scope confirmation)

- `commands/orchestrate.md:51-53` — the `--research`/`--plan`/`--implement` rows already document
  general forcing ("Force a research round even if the task progressed past it") but say nothing
  about terminal or archived tasks specifically; this is the exact gap the SCOPE section asks to
  close.
- `docs/architecture/orchestrate-state-machine.md`'s "Dependency Gating Model" section
  (`:619-639`) states the eligibility rule in prose ("Its current status is not terminal... and
  not in `failed_tasks`") without the forced-phase exemption; the ASCII diagram's "All-terminal
  check" / "Eligibility" nodes (`:514, 523-524`) and the worked examples (`:704-731`) are the
  adjacent sections that will need the same update.
- `test-orchestrate-cycle-plan.sh:1027-1051` (Group 10 Case I) already has an `all_terminal`
  fixture, but it is driven by a pre-seeded `failed_tasks: [1002]` entry against a task whose
  status is `"implementing"` (not actually terminal) — the `failed_tasks_json` membership check
  (`orchestrate-cycle-plan.sh:1141`) is independent of `is_terminal_status` and is untouched by
  this task's fix, so this fixture remains valid unmodified, exactly as the dispatch anticipates.
  A genuinely new fixture (status `"completed"`, no forcing) is needed to pin the "unforced
  terminal task still stops with all_terminal" acceptance case.
- `test-orchestrate-cycle-plan.sh:422-479` (Group 7) is the existing template for an
  archive-aware dependency-resolution fixture (`archive/state.json` with
  `completed_projects`/`archived_projects`, consumed via a sibling `write_state` for
  `active_projects`) — the natural template to copy for the new "completed-and-archived
  top-level candidate with `--force-phases`" fixture this task's SCOPE requires.
- `test-orchestrate-triage-classify.sh` has no archive-read test surface at all today (confirmed
  by absence of `archive` in that file); Defect 2's fix needs new fixture coverage from scratch,
  not an existing pattern to extend.

## Recommendations

1. **Defect 1 fix** (`orchestrate-cycle-plan.sh`): add a `task_has_forced_phase(t)` predicate
   evaluated once per `t` before the all-terminal check, reading `canonical_force_phases_json`
   (CLI-level, already computed at `:443-454`, before `is_terminal_status` is even defined) OR
   `$mt_json`'s already-loaded `.force_phases_remaining[$t]` (for a task whose queue was seeded on
   a prior cycle and is not yet exhausted). Use it to guard both `continue`s: `if
   is_terminal_status "${current_statuses[$t]}" && ! task_has_forced_phase "$t"; then continue;
   fi` at `:1140` and `:1156`. No other section needs to move.
2. **Defect 2 fix** (`orchestrate-triage-classify.sh`): give it its own archive read, mirroring
   `orchestrate-cycle-plan.sh`'s `lookup_project`/`archived_projects_json` shape exactly (same
   sibling-path resolution, same completed/abandoned/expanded-verbatim +
   `orphan_archived`→`completed` normalization), consulted whenever a candidate is absent from
   `active_projects`. Keep `group:"terminal"` for the archived-and-terminal case (matches the
   live row's existing terminal handling for an active terminal task — no new verdict value is
   needed).
3. **Defect 3 fix** (`skill_validate_input` / `orchestrate-build-dispatch.sh`): thread a bypass
   (e.g. an optional `--allow-terminal` or reusing the `force_invoked` concept as a new
   positional/flag argument to `skill_validate_input`) so a forced dispatch does not `exit 1` on a
   terminal `TASK_STATUS`, and add the same archive fallback `lookup_project` already has so an
   archived task is found at all rather than hitting the "not found" branch.
4. **Defect 4 fix** (`skill_preflight_update`): add the same `status_clamp_mode` 4th/optional
   argument shape `skill_postflight_update` already has, and have `orchestrate-cycle-plan.sh` pass
   `"monotonic-max"` at its preflight call site (`:1725`) whenever `forced_this_cycle[$t]=true` —
   this information is already computed in the same process, before that call. This keeps
   `state.json` at `completed` throughout the round, which in turn makes the EXISTING postflight
   clamp's comparator correct again (it will read `completed`, not a preflight-corrupted
   in-progress value).
5. Decisions (b)/(c)/(e) as stated in the Executive Summary.

## Decisions

- **(a)** Compute forced-phase membership up front from data already in scope
  (`canonical_force_phases_json` + `mt_json`), and use it purely as an exemption predicate at the
  two existing `is_terminal_status` call sites. Do not reorder section (f) — its seeding and
  consumption logic is unaffected and correct as-is once terminal tasks can reach it.
- **(b)** A `completed` task keeps `status: "completed"` both **during** and **after** a forced
  `--research`/`--plan` round. This requires the NEW preflight clamp (Defect 4 fix above); it is
  not achievable with the existing postflight-only clamp alone, contrary to what that clamp's
  design comments might suggest at first read.
- **(c)** `--implement` forced on a `completed` task: mechanically safe on the status axis
  (`postflight:implement` always resolves to `completed`, `"implemented"` deliberately unranked).
  The real risk is re-dispatching implementation work against already-shipped code, which is a
  product decision, not a plumbing defect this research can resolve — recommend treating it
  identically to `--research`/`--plan` at the code level (no special gate), while flagging to the
  planner/user that this is the flag most likely to warrant an explicit confirmation step or a
  narrower rollout if the user wants one.
- **(d)** The classifier gains its own archive read (mirroring `lookup_project`'s shape directly),
  per the companion task's "keep the rule in exactly one executable place" precedent. It keeps
  returning `group:"terminal"` for an archived-and-terminal candidate — no new verdict value.
- **(e)** All-terminal message differentiation is a natural side effect of (a)'s fix, not
  independent work — the same exemption used in the all-terminal loop already prevents `all_done`
  from going true when a forced phase is pending. The archive read stays read-only; no
  un-archiving. Completion of a forced round is recorded via the existing artifact-link +
  `next_artifact_number` advance path, which needs no new write logic.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Defect 3 (`skill_validate_input` hard block) is missed because it is not named in the task description | H | H if not flagged | This report names it explicitly with exact line numbers; planner must add it to Scope |
| Defect 4 (preflight has no regression clamp) ships unfixed, causing forced `--research`/`--plan` on a `completed` task to permanently downgrade it | H | H if not flagged (confirmed untested end-to-end today) | This report names the exact mechanism and fix shape; add a LIVE (non-dry-run, non-stubbed) fixture that asserts final `state.json` status equals `completed` after a full forced `--research` round on a `completed` fixture task |
| Fixing Defect 4 by clamping preflight could interact with the `needs_research` unranked-target carve-out (`skill-base.sh:639-653`) if implemented naively | M | L | Mirror the postflight clamp's exact resolution order and unranked-means-no-clamp rule; do not special-case `needs_research` differently at preflight, since preflight's `$g` is always `research`/`plan`/`implement`, never the literal `needs_research` token (that value only ever appears at postflight time) |
| A single-task-engine dispatch of the classifier (not routed through `orchestrate-cycle-plan.sh`'s pre-filtering) still breaks on an archived task even after this task's fix, if Defect 2's fix is scoped only to the `mt` engine table | M | M | The classifier's own header states both engine tables must move together; the archive read should live above the `engine` branch, applying identically to `single` and `mt` |
| New fixtures for Defect 3/4 require exercising the REAL `update-task-status.sh` (not a stub), unlike the existing Group 4/5 live fixture pattern | M | M | Model the new fixture on `test-orchestrate-cycle-postflight.sh`'s own sandbox shape (copies real collaborator scripts unmodified), not `test-orchestrate-cycle-plan.sh`'s stubbed-`update-task-status.sh` pattern |

## Context Extension Recommendations

- **Topic**: the monotonic-max clamp's reliance on a live `state.json` read as its "current
  status" comparator, and the preflight/postflight process-boundary hazard this creates for any
  forced-phase-on-already-advanced-task scenario (not just terminal tasks).
- **Gap**: `docs/architecture/orchestrate-state-machine.md` and `skill-base.sh`'s own clamp
  comments describe the clamp's intended protection but do not document (or, before this task,
  provide) the preflight-side half of the guarantee.
- **Recommendation**: once Defect 4 is fixed, add a short subsection to
  `docs/architecture/orchestrate-state-machine.md` (near the existing forced-phase / needs_research
  fork material) documenting that BOTH `skill_preflight_update` and `skill_postflight_update`
  must be clamp-aware for a forced round on an already-advanced task, and why (the two calls are
  separate processes, potentially far apart in time, with `state.json` as the only persisted
  intermediate signal).

## Appendix

### Verified line anchors (source store, `agent-system/extensions/core/`)

- `scripts/orchestrate-cycle-plan.sh`: `is_terminal_status` 1123-1128; all-terminal check
  1138-1150; eligibility loop 1152-1259 (terminal continue at 1156); `lookup_project`/archive read
  405-425; force-phases parse+canonicalize 427-454; classifier call 1287-1326; force_phases
  consumption 1328-1350; admission 1353-1440; preflight call 1725; build-dispatch call + deferred
  handling 1758-1767; forced-phase pop 1712-1715; `force` field on dispatch row 1824-1833.
- `scripts/orchestrate-triage-classify.sh`: usage/effort parsing 195-223; active-projects-only
  lookup 256-262, 350; null-entry skip branch 355-358; terminal-status branch 361-364;
  not_started effort-conditional branch 365-373.
- `scripts/orchestrate-build-dispatch.sh`: exit-code doc 57-60; `skill_validate_input` call 147.
- `scripts/skill-base.sh`: `skill_validate_input` 184-210 (archive-blind lookup 188-190; terminal
  block 204-208); `skill_preflight_update` 217-233 (no clamp parameter); `skill_postflight_update`
  605-800 (monotonic-max clamp 689-714, live `state.json` read 704-706; `needs_research` unranked
  carve-out rationale 639-653).
- `scripts/update-task-status.sh`: `map_status` 278-312 (no current-status guard anywhere in the
  file, confirmed by grep).
- `scripts/lib/status-vocabulary.sh`: `STATUS_VOCABULARY_LIFECYCLE_RANK` (not_started=0 ...
  completed=7, `implemented` absent/unranked); `status_vocabulary_would_regress` (target_rank <=
  current_rank, unranked either side ⇒ no regression).
- `scripts/orchestrate-cycle-postflight.sh`: `force_invoked` parse 157, 176; clamp_mode set
  662-666; artifact link (unconditional) 772-790; artifact-round advance (force-aware for
  planned/implemented) 792-797.
- `commands/orchestrate.md`: 51-53 (`--research`/`--plan`/`--implement` rows, no terminal/archive
  statement yet).
- `docs/architecture/orchestrate-state-machine.md`: 619-639 (Dependency Gating Model prose);
  514, 523-524 (ASCII diagram nodes); 704-731 (worked examples).
- `scripts/tests/test-orchestrate-cycle-plan.sh`: Group 2 (152-193, dry-run only); Group 4/5 live
  fixture with stubbed `update-task-status.sh` (233-391); Group 7 archive-dependency template
  (421-479); Group 10 Case I existing all_terminal fixture, `failed_tasks`-driven not
  status-driven (1021-1051).
- `scripts/tests/test-orchestrate-cycle-postflight.sh`: sandbox copies real collaborators
  unmodified (header, 1-40); Acceptance 6/7 monotonic-max fixtures with hand-seeded current status
  (346-449).

### Precedent read in full (companion task 196)

- `specs/196_research_first_default_unless_fast/plans/01_research-first-default-unless-fast.md`
  Decision (a): "Effort-awareness lives in the classifier, not in a caller post-adjustment" —
  reused directly for Decision (d) above.
- `specs/196_research_first_default_unless_fast/summaries/01_research-first-default-unless-fast-summary.md`:
  confirms 196 is COMPLETED, out of scope overlap is by design (both tasks' file scopes touch
  `orchestrate-triage-classify.sh` and `orchestrate-cycle-plan.sh`, sequenced deliberately).
