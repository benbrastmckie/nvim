# Shared Postflight Flow (Stage 7, 7a, 8, 8a, 9)

**Placed in core context** so the `@`-import below resolves for every skill that reaches
postflight status update, memory-candidate propagation, artifact linking, TTS notification, and
cleanup, regardless of which extension owns the importing skill. This file is the SINGLE
canonical block for these five stages. Before it existed, every lifecycle skill hand-copied its
own status-update call, its own memory-candidate append (or, in most skills, no append at all —
the base lifecycle plan skill, since deleted, had never had a Stage 7a, silently discarding every
`memory_candidates` a `planner-agent` emitted), its own two-step artifact-linking jq pair, and one
of eleven
near-identical inline TTS blocks. Routing every importer through `skill_postflight_update`,
`skill_propagate_memory_candidates`, `skill_link_artifacts`, `skill_lifecycle_notify`, and
`skill_cleanup` in `skill-base.sh` makes that drift class structurally impossible: there is
exactly one implementation of each stage, and every caller gets whatever that one implementation
currently does. Every instruction below is DIRECT and EXECUTABLE — none of it is commented-out
pseudocode inside a bash fence.

A skill importing this block MUST NOT also keep an inline copy of any of Stage 7, 7a, 8, 8a, or
9. If the importing skill's own body still contains a hand-rolled `state-write.sh` call for
memory candidates, a hand-rolled two-step artifact-linking jq pair, or an inline
`lifecycle-notify.sh` invocation sitting alongside this import, that is drift re-accumulating and
must be deleted, not kept "just in case".

## Placement: the `## Postflight (ALWAYS EXECUTE)` Marker

This block's five stages sit inside the importing skill's existing
`## Postflight (ALWAYS EXECUTE)` section — the heading that marks "these stages run whether the
work was done by a subagent or inline (Stage 5b), and must not be skipped for any reason". This
import does not create that heading; it replaces the hand-written stage bodies underneath a
heading the importing skill already has. The heading itself, and Stage 6/6a (reading and
validating the return-metadata file, which precede this block and are not part of it), stay
skill-specific.

## Preconditions (variables the importing skill already has in scope)

- `task_number`, `padded_num`, `project_name`, `session_id`, `operation` — same meaning as in
  `skill-preflight-flow.md`.
- `status` — the operation's success-variant string read from `.return-meta.json` at Stage 6
  (`researched` | `planned` | `implemented`), or a failure/partial value.
- `artifact_path`, `artifact_type`, `artifact_summary` — read from `.return-meta.json` at Stage 6
  (via `skill_read_metadata` or an equivalent direct `jq` read).
- `memory_candidates` — the `memory_candidates` JSON array read from `.return-meta.json` at Stage
  6 (`jq -c '.memory_candidates // []'`).
- `field_name`, `next_field` — the two label strings `skill_link_artifacts` uses for its
  `field_name`/`next_field` parameters (e.g. `'**Research**'` / `'**Plan**'` for research,
  `'**Plan**'` / `'**Description**'` for plan/implement). These are operation-specific literals
  the importing skill already knows.
- `skill-base.sh` is already sourced by the importing skill; `skill_postflight_update`,
  `skill_propagate_memory_candidates`, `skill_link_artifacts`, `skill_lifecycle_notify`, and
  `skill_cleanup` are already in scope as shell functions.

## Stage 7: Update Task Status (Postflight)

```bash
skill_postflight_update "$task_number" "$operation" "$session_id" "$status"
```

An importing skill following this pattern calls the 4-argument form shown above (or the 5-argument
form with an explicit `phase_check_mode` — see `update-task-status.sh`'s opt-in phase-accounting
backstop). `skill_postflight_update` also accepts an optional 7th argument, `status_clamp_mode`
(A2's monotonic-max clamp; positional 6 is reserved, unrelated to this pattern): absent or empty —
every call this shared pattern documents — preserves the behavior below exactly.
`"monotonic-max"` instead skips the status write when it would regress the task's lifecycle
position (see `scripts/lib/status-vocabulary.sh`'s `status_vocabulary_would_regress`). This
pattern's own importers never pass it; it is consumed today only by `/orchestrate`'s own
per-cycle postflight path (`scripts/orchestrate-stage5-postflight.sh`, a script outside this
shared block — see that script's header), on a forced re-run of an already-passed phase.

This only performs the actual `update-task-status.sh postflight` call when `status` is one of the
success values (`researched`/`planned`/`implemented`); any other status is logged and skipped, so
a failed or partial run never advances state. It also runs the extension `postflight` hook and
appends a `lifecycle_stage` milestone event.

**Not covered by this shared call**: `next_artifact_number` incrementing is operation-specific
(only the research operation advances the sequence; plan/implement stay at `current - 1` to share
the same round) and has no dedicated `skill-base.sh` function. An importing skill that needs this
increment keeps that one `state-write.sh` call inline, immediately after this Stage 7 call —
converting it would require a new shared function this plan does not add (see the parent plan's
Non-Goals: "altering `skill-base.sh`'s existing function signatures"). This remains accurate for
every skill following this shared pattern; `/orchestrate`'s own single-task postflight path
(outside this shared block) additionally advances the sequence unconditionally on `researched`
and, under A2, on a FORCED `planned`/`implemented` dispatch — see
`scripts/orchestrate-stage5-postflight.sh`'s own header for that script-local variant.

**On partial/failed status**: `skill_postflight_update` already no-ops on a non-success status;
the importing skill still needs its own guard to skip whatever else it would otherwise do next
(e.g. an artifact-number increment) when the run did not succeed.

## Stage 7a: Propagate Memory Candidates

```bash
skill_propagate_memory_candidates "$task_number" "$memory_candidates" "$session_id"
```

Appends (never overwrites) any memory candidates the subagent emitted to the task's `state.json`
entry. A skill that has never had this stage (the report found the base lifecycle plan skill,
since deleted, in exactly this state) gains real memory-candidate propagation the first time it
imports this block — this is a deliberate fix carried by this import, not incidental.

## Stage 8: Link Artifacts

```bash
skill_link_artifacts "$task_number" "$artifact_path" "$artifact_type" "$artifact_summary" \
  "$field_name" "$next_field" "$session_id"
```

Performs the two-step jq pattern internally (remove same-type artifacts, then add the new entry —
using the `select(.type == $atype | not)` form to avoid Issue #1132's `!=` escaping bug) and
regenerates TODO.md via `generate-todo.sh` when `artifact_path` is non-empty. Never construct this
two-step pattern by hand at an importing skill's call site.

## Stage 8a: Lifecycle TTS Notification

```bash
skill_lifecycle_notify "$status"
```

Fires the TTS + WezTerm tab-coloring notification (e.g. "Tab 3 researched") in the background,
guarded on the notify script's presence, never blocking. `$status` is the same
lifecycle-status string the importing skill already threads through (its own `status` value, read
directly, not a separately named variable).

## Stage 9: Cleanup

```bash
skill_cleanup "$padded_num" "$project_name"
```

Removes `.postflight-pending` and `.postflight-loop-guard` for the task. `.return-meta.json` is
**NOT** removed here — `skill_cleanup` (Stage 9) always runs at the skill's OWN postflight, which
completes before the calling command's `command-gate-out.sh` (CHECKPOINT 2) and, further
downstream, that command's own CHECKPOINT 3 commit block ever read the file. Deleting it at Stage
9 made that entire downstream body structurally unreachable — this was a real, fixed defect, not
a hypothetical. `.return-meta.json`'s deletion is now owned by the calling command's own last
step that consumes it (see the reader table below); the one exception is `skill-spawn`, which has
no command-level consumer downstream and so deletes the file inline itself, immediately after
this same `skill_cleanup` call.
Note: `orchestrator-postflight.sh` also removes `.continuation-loop-guard` for implement
operations — that file is implement-specific and is removed with a separate `rm -f`, not folded
into `skill_cleanup` (which stays a 2-arg function shared by every importer).

## Ordering

Stages run in the numbered order above: 7, 7a, 8, 8a, 9. Do not run cleanup (Stage 9) before
artifact linking (Stage 8) — the marker files Stage 9 removes are still needed as inputs to
earlier stages (`artifact_path`/`artifact_type`/`artifact_summary` were read from
`.return-meta.json` at Stage 6, but Stage 8's `skill_link_artifacts` call itself has no file
dependency on the marker — the ordering constraint here is about not deleting
`.postflight-pending`/`.postflight-loop-guard` before every stage that reads them has run, and
Stage 8a's `$status` argument is the same already-read `status` value, not a fresh file
read). This same "delete only after every consumer has read it" discipline now extends PAST the
skill boundary: `.return-meta.json` must not be deleted until every consumer downstream of
DELEGATE — inside this skill AND inside the calling command that invoked it — has finished
reading it. See the reader table immediately below for the full per-command mapping.

## `.return-meta.json` Reader Table

Every consumer of `.return-meta.json` downstream of DELEGATE, and which step owns the file's
deletion. Reference sites by file and section name, never by line number (line numbers drift).

| Calling command | Consumers downstream of DELEGATE | Deletion owner |
|---|---|---|
| `/research` | `command-gate-out.sh` (defensive correction, `skill_validate_task_artifacts`); `commands/research.md` CHECKPOINT 3 `git add` (stages the file as durable provenance) | `commands/research.md` CHECKPOINT 3, final line of the commit block |
| `/plan` | `command-gate-out.sh` (same two mechanisms); `commands/plan.md` CHECKPOINT 3 `git add` (recursive task-dir add) | `commands/plan.md` CHECKPOINT 3, final line of the commit block |
| `/implement` | `command-gate-out.sh` (same two mechanisms); `commands/implement.md` CHECKPOINT 3 (`modified_files` read into `stage_paths`) | `commands/implement.md` CHECKPOINT 3, final line of both the completion and partial commit branches |
| `/revise` | `command-gate-out.sh` (same two mechanisms, gated on `skill-reviser`'s reported status); the revise-specific plan-file existence check | `commands/revise.md`, immediately after that plan-file existence check (no CHECKPOINT 3 exists for `/revise`) |
| `/orchestrate` (single-task) | `command-gate-out.sh` (same two mechanisms); `commands/orchestrate.md` CHECKPOINT 3 (`modified_files` read into `stage_paths`) | `commands/orchestrate.md` CHECKPOINT 3, completion branch only, after `git-commit-scoped.sh`. The partial/paused branch deliberately keeps the file so the next cycle's `orchestrate-stage5-gates.sh` outcome recovery still has its mtime-freshness-windowed fallback |
| `/research`, `/plan`, `/implement` multi-task batch loops | None of the above — these loops deliberately bypass `command-gate-in.sh`/`command-gate-out.sh` and never reach the single-task CHECKPOINT 3 | Each command's own Step 4 batch-commit block, iterating the dispatched task list, after the batch commit |
| `/orchestrate` (multi-task) | `skill-orchestrate`'s own Move 2 per-task dispatch loop, which dispatches directly to agents (bypassing the skill layer and `skill_cleanup` entirely) and reads `.return-meta.json` repeatedly across however many cycles a task's dispatch spans, for outcome recovery via `orchestrate-recover-outcome.sh` | **No deletion site exists, deliberately.** The file is never deleted in this path — it functions as an ongoing, multi-cycle recovery record, the same role the single-task completion-only scoping protects, but more conservative because an MT task's dispatch can legitimately span several cycles |
| `/spawn` | None (no `command-gate-out.sh`/CHECKPOINT 3 consumer) | `skill-spawn/SKILL.md` Stage 16, inline, immediately after `skill_cleanup` |

### Why `command-gate-out.sh`'s two mechanisms are retained, not removed

Before this table existed, `.return-meta.json` was deleted at Stage 9 (this skill's own
`skill_cleanup`), which always ran before `command-gate-out.sh` ever opened the file — so its
missing-metadata branch fired identically on every successful run and every genuine crash, and
everything past that branch (defensive status correction, `skill_validate_task_artifacts`) was
structurally unreachable dead code on every single invocation. Fixing the deletion's ordering (as
the table above records) makes both mechanisms reachable again for the first time. Both were
deliberately kept rather than deleted as dead code, because each does something the other layers
of this system do not:

- **Defensive status correction** is a genuinely independent second reader guarding a
  non-`set -e` Stage 7 call (`skill_postflight_update`) inside the skill — if that call silently
  no-ops or partially fails, this is the only check that later notices `state.json` disagrees
  with what the skill actually reported and repairs it.
- **`skill_validate_task_artifacts`** is a whole-task-directory sweep, strictly broader than each
  skill's own single-artifact Stage 6a check (which validates only the one artifact that skill
  itself just wrote) — it catches artifact-link drift Stage 6a has no way to see.

A future reader who finds these two blocks now firing on ordinary runs, having previously known
them only as silent no-ops, should read this as the fix working as intended — not as a new
defect to re-investigate or a candidate for removal.
