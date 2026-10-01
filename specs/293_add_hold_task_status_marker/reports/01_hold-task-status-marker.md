# Research Report: Task #293

**Task**: 293 - Add a HOLD task status marker that pauses a task and excludes it from dispatch
**Started**: 2026-10-01T03:51:23Z
**Completed**: 2026-10-01T03:57:27Z
**Effort**: Medium-Large (5 phases, ~10 source files + 5 test files + 4 doc files)
**Dependencies**: None
**Sources/Inputs**:
- Codebase: `agent-system/extensions/core/` (the source store — see
  `rules/source-store-deploy-boundary.md`)
- Live consumer repository: `/home/benjamin/Projects/Logos/Verification` (9 hand-set `hold`
  tasks, used to confirm the exact breakage this task fixes)
**Artifacts**:
- `specs/293_add_hold_task_status_marker/reports/01_hold-task-status-marker.md` (this report)
**Standards**: report-format.md, subagent-return.md, status-markers.md, state-management-schema.md

## Executive Summary

- Confirmed the live breakage firsthand: in the consumer repo, `generate-todo.sh` hard-fails
  (`ERROR: off-schema status 'hold' ... Nothing was written.`) and `validate-state.sh` reports
  exactly 12 FAILs (9 off-schema-status + 3 unknown-entry-field: `held_at`, `hold_reason`,
  `prior_status`) across the 9 hand-set tasks (125, 126, 127, 128, 141, 142, 143, 162, 165).
  Phase 1 alone fixes both.
- The closed 12-value enum and its schema twin are a tight, well-tested pair
  (`scripts/lib/status-vocabulary.sh` / `context/schemas/state-schema.json`'s
  `definitions.taskStatus.enum`, kept byte-equal by `test-status-vocabulary.sh`). Adding `hold`
  is mechanical: one array entry, one marker-map entry, one schema enum entry, one drift-test
  count bump (12 -> 13).
- `blocking_reason` confirmed absent from every script and schema (only a documentation-prose
  mention in `status-markers.md`'s `[BLOCKED]` "Required Information" bullet) — `hold_reason`,
  `held_at`, `prior_status` are genuinely new schema fields, not reuses of an existing pattern.
- Found a real, pre-existing admission gap unrelated to HOLD but adjacent to Phase 2's work:
  `commands/orchestrate.md`'s STAGE 0 `validated_tasks` loop unconditionally skips any
  `completed|abandoned|expanded` task — it never consults `$FORCE_PHASES_FLAG` before dropping
  the task from the batch, even though the forced-admission machinery
  (`task_has_forced_phase`/`force_phases_remaining`) lives entirely inside
  `orchestrate-cycle-plan.sh`, which STAGE 0 never reaches for a task it has already dropped.
  **This is a pre-existing gap this task did not introduce and is not asked to fix for the
  terminal case** — but HOLD's own STAGE 0 arm must NOT copy it verbatim, or the
  "forcing flag overrides hold" decision (explicitly mandated by the dispatch) silently breaks:
  `$FORCE_PHASES_FLAG` is already a populated shell variable at STAGE 0's position, so the new
  `hold` arm can and must branch on it directly, independent of whatever the terminal arm does.
- Verified two Phase 4 "already-true" claims by reading the actual code rather than trusting the
  dispatch's prose: (a) `skill-todo/SKILL.md`'s Stage 2 `ScanTasks` and its archive-write
  (`.completed_projects`/`.archived_projects` jq, ~line 454) both positive-match only
  `completed`/`abandoned`/`expanded` — a `hold` task is excluded from the archive set by
  construction, no new guard needed; (b) the Stage 2.5 `TopicRevision` inverted-select pattern at
  lines 164-166 is a *different* selector (topic backfill, not archival) from the one that
  actually governs archival (Stage 2's positive match) — the dispatch's claim is correct in
  effect but names the wrong line range for the actual archival guard.
- Confirmed the real open design question: the expanded-parent subtask-blocking `case` statement
  (identical code duplicated in both `skill-todo/SKILL.md` and `commands/todo.md`) treats any
  non-`completed|abandoned|expanded` subtask status as blocking via its `*)` catch-all — a held
  subtask blocks its parent's archival indefinitely with no escape hatch today. This needs an
  explicit decision (see Decisions below), not a silent fix.
- Recommend: in `orchestrate-triage-classify.sh`, give `hold` its own dedicated `group:"hold"`
  verdict (not `needs_human`, not `skip`) so the reason text is `hold_reason`-specific rather
  than reusing the generic "transitional/unknown" wording the final `else` branch currently
  produces; in `orchestrate-cycle-plan.sh`'s bucketing switch, add a `hold)` case arm that mirrors
  the existing `forced_round_complete` arm exactly (push a reasoned `blocked[]` row, `continue`
  before the lock probe) — this is the closest existing precedent and the dispatch explicitly
  points at it.

## Context & Scope

The task adds a 13th value, `hold`, to the closed task-status enum so an operator can pause a
task (exclude it from `/orchestrate` dispatch and from single-command gate-in) without the
irreversibility of `[ABANDONED]` (which triggers `/todo` archival) or the false permissiveness of
`[BLOCKED]` (whose documented contract is "any command can run from this status" — it does not
actually enforce a pause). Three new per-task fields (`hold_reason`, `held_at`, `prior_status`)
make the hold both informative and reversible. The consumer repo
`/home/benjamin/Projects/Logos/Verification` has already hand-written `status: "hold"` plus all
three fields onto 9 tasks ahead of this support landing, so Phase 1 must treat that data as valid
input requiring no migration — confirmed live (see Findings).

Scope is exactly the 5 phases the dispatch lays out: (1) enum + schema + field allowlist, (2)
dispatch/gate-in exclusion, (3) operator-settable + reversible via `update-task-status.sh`, (4)
`/todo` archival interaction (mostly already-correct, one real open design question), (5)
documentation. Research did not write code or tests; it verified every factual claim in the
dispatch against the actual source-store files and the live consumer repo, and resolved the two
decisions research is positioned to resolve ahead of planning (see Decisions).

## Findings

### Phase 1 — Enum, schema twin, field allowlist

- `scripts/lib/status-vocabulary.sh` (`agent-system/extensions/core/scripts/lib/status-vocabulary.sh`):
  `STATUS_VOCABULARY_ENUM` is a 12-element bash array (lines 38-51) and
  `STATUS_VOCABULARY_TODO_MARKER_MAP` is its parallel associative array (lines 56-69). The header
  comment (lines 2, 6) and the enum's own inline comment both say "closed 12-value" in prose —
  both need updating to 13. `status_vocabulary_is_valid`/`status_vocabulary_todo_marker` are pure
  membership/lookup functions requiring no change beyond the array growing by one.
  `STATUS_VOCABULARY_LIFECYCLE_RANK` (lines 105-114) deliberately omits
  `blocked`/`partial`/`abandoned`/`expanded` as non-linear exception/terminal states — `hold`
  belongs in this same omitted set (non-linear, exception-state), confirmed by its own doc
  comment's rationale.
- `context/schemas/state-schema.json`: `definitions.taskStatus.enum` is the exact 12-string array
  to extend (confirmed via `jq`). `definitions.projectEntry.properties` currently has exactly 20
  keys (confirmed via `jq '... | keys'`) with `additionalProperties: false` — `hold_reason`,
  `held_at`, `prior_status` must all three be added here as typed properties (likely all
  `"type": "string"`, following the `completion_summary` precedent: "Required when status is X;
  schema-optional here since only completed entries carry it").
- `scripts/validate-state.sh`: `KNOWN_ENTRY_FIELDS` (lines 461-465) is a flat bash array of 17
  names, checked via Check 4's unknown-field scan (lines 466-481) and Check 5's status-enum
  membership scan (lines 484-496, calls `status_vocabulary_is_valid` directly — fixed
  transitively by the library edit, confirmed no separate status arm exists here).
- Live confirmation in the consumer repo: `bash .claude/scripts/validate-state.sh` currently
  reports exactly 12 FAILs — 9 "off-schema status 'hold'" (one per hand-set task) + 3 "Unknown
  entry field" (`held_at`, `hold_reason`, `prior_status`, each listing all 9 project numbers) —
  and `bash .claude/scripts/generate-todo.sh` hard-fails with "Nothing was written" because
  `format_status()` (generate-todo.sh lines 145-156) calls `status_vocabulary_todo_marker` and
  exits 1 on its failure, by design (no silent catch-all fallback — the comment explicitly notes
  the old permissive catch-all "has been removed entirely"). Both symptoms disappear once the
  enum/map/schema are extended; no separate code path in either script needs its own `hold` case.
- `scripts/tests/test-status-vocabulary.sh`: asserts `schema_count -eq 12 && lib_count -eq 12`
  (line 107) — bump both to 13. The file's header (lines 3, 11) also narrates "12-value" in
  prose.
- `blocking_reason` grep across the entire source store returns exactly one hit, and it is prose
  only: `context/standards/status-markers.md`'s `[BLOCKED]` section's "Required Information"
  bullet (`- \`- **Blocking Reason**: {reason}\` or \`- **Blocked by**: {dependency}\``). It is
  never read or written by any script or schema. This confirms the dispatch's framing:
  `hold_reason`/`held_at`/`prior_status` are a genuinely new schema addition, not a parallel to an
  existing enforced pattern — `[BLOCKED]`'s "Required Information" has always been TODO.md prose
  convention only, never machine-checked.

### Phase 2 — Dispatch exclusion

- `scripts/orchestrate-triage-classify.sh`: the classification is one long jq `if/elif` chain
  (lines ~409-516) ending in a catch-all `else` (lines 514-517) that currently produces
  `group:"skip"` with reason `"status \"$status\" is transitional/unknown; skip"`. Today, a
  `hold`-status task falls all the way through every `elif` (not terminal, not `not_started`,
  not `researched`, not `planned|implementing`, not `researching`, not `planning`, not `partial`,
  not `blocked`) into this catch-all. The documented group vocabulary is `skip / terminal /
  needs_human / research / plan / implement` — none of these names fits a *known, intentional*
  pause the way the catch-all's "unknown" framing would misrepresent it. A new dedicated
  `group:"hold"` is the correct choice over reusing `needs_human` (hold is not an error state
  requiring operator triage of a stuck dispatch — it is an operator-chosen pause that is already
  fully explained by `hold_reason`) and over reusing `skip` (the existing `skip` reason text is
  generic and would read as if the status were unrecognized garbage, exactly the opposite of a
  deliberately-set, well-understood value). The per-phase comment table at the top of this file
  (lines ~71-90) documenting every status->group row for both engines needs a new `hold` row
  too.
- `scripts/orchestrate-cycle-plan.sh`: two distinct mechanisms matter here, confirmed by reading
  both:
  - `is_terminal_status()` (lines 1459-1463) is a 3-case `case` statement
    (`completed|abandoned|expanded`) — confirmed it must NOT be widened to include `hold` (would
    let `/todo` archive a held task; also would wrongly let a held task satisfy a *dependent*
    task's "all dependencies completed" discharge check in the `blocked`-status discharge logic
    elsewhere in this same file, since that logic explicitly treats `is_terminal_status` dependencies
    as resolved only when they equal exactly `"completed"`).
  - `task_has_forced_phase()` (lines 1483-1491) returns true when EITHER this invocation's
    `--force-phases` was non-empty (`canonical_force_phases_json`) OR the task already carries a
    non-empty `force_phases_remaining[]` queue from a prior cycle — this is the single existing
    predicate the dispatch says to reuse, confirmed it requires no modification: it is a pure
    function of CLI/state, entirely independent of status, so it already "just works" for hold
    without change.
  - The actual precedence that makes "forcing flag overrides hold" work is the `effective_group`
    computation (lines ~1679-1702): a task's forced phase (from `canonical_force_phases_json` or
    a carried-over queue) is resolved BEFORE `triage_group[$t]` (the status-derived verdict,
    which would say `hold`) is ever consulted — the `else` branch at line 1701 that falls back to
    `"${triage_group[$t]:-skip}"` is only reached when neither forced-phase condition holds. This
    means: once `orchestrate-triage-classify.sh` emits `group:"hold"`, the existing
    `effective_group` logic *already* lets a forced phase override it with zero further changes —
    confirmed by reading the precedence chain, not assumed.
  - The bucketing `case "$g" in ...` switch (starting ~line 1831) needs a new `hold)` arm. The
    closest and best precedent, exactly as the dispatch points out, is the `forced_round_complete)`
    arm (lines ~1836-1848): it pushes a `blocked[]` row via `out_blocked_rows+=(...)` with a
    human-readable reason and `continue`s *before* the lock probe, dispatch_seq mint,
    `skill_preflight_update`, and `orchestrate-build-dispatch.sh` — i.e., no lock touched, no
    dispatch file written, no status write, no cycle charge. A `hold)` arm should do the exact
    same thing, with a reason string built from the task's own `hold_reason` field (read from
    state.json, not hard-coded) so the acceptance criterion ("blocked[] row with a hold reason")
    is satisfied with real per-task content, not a generic message.
  - The `skip|terminal|exit_partial|""`) arm (~line 1853) is the one `hold` must NOT fall into —
    if the triage classifier's new `hold` group is not matched by its own case arm, it would
    silently land in this generic no-row, no-reason `continue`, which fails the acceptance
    criterion (no visible `blocked[]` row at all).
- `commands/orchestrate.md`: STAGE 0's `validated_tasks` loop (lines ~158-174) has exactly one
  `case "$status" in completed|abandoned|expanded)` arm, which can only express "terminal, always
  skip." Confirmed by reading the surrounding command file that `$FORCE_PHASES_FLAG` is already a
  populated shell variable at this point in the script (parsed earlier, referenced again at
  lines ~244/261 when building the delegation JSON for `skill-orchestrate`) — so the new `hold`
  arm has everything it needs to implement the forcing-flag override locally: `if [ -n
  "$FORCE_PHASES_FLAG" ]`, admit into `validated_tasks` (let `orchestrate-cycle-plan.sh`'s own
  `task_has_forced_phase`/`effective_group` machinery take over downstream); else, skip with a
  reason distinct from the terminal one (e.g. `"$task_num: held [$hold_reason]"`) so
  `skipped_tasks` warnings distinguish a pause from a true terminal skip. **Important adjacent
  finding, explicitly out of this task's scope**: the existing `completed|abandoned|expanded)` arm
  does *not* perform this same `$FORCE_PHASES_FLAG` check — it unconditionally skips, which
  appears to conflict with this same file's own documented claim (lines 59-61) that "`--research`/
  `--plan`/`--implement` admit a terminal task, including an archived one." That documented
  behavior, if actually honored anywhere, must be happening only in the `--dry-run` path (which
  forwards the *raw, unfiltered* `$TASK_NUMBERS` to `orchestrate-cycle-plan.sh --dry-run`,
  bypassing STAGE 0's filter entirely) — the live dispatch path's `task_numbers_json` is built
  from `validated_tasks`, i.e. from the *filtered* set, so a forced terminal task is in fact never
  reachable by `skill-orchestrate` in the live path today. This is a pre-existing gap, not
  something this task introduces or is asked to fix — flagging it so the new `hold` arm is not
  written to *copy* this same silent gap, since hold explicitly must support the override and
  terminal (apparently) does not, today, in the live path.
- `scripts/command-gate-in.sh`: the terminal guard (lines 77-85) is a `case "$TASK_STATUS" in
  completed|abandoned|expanded)` inside `if [ "$operation" != "revise" ]`, placed *before* the
  task-lock acquire (comment at line 89 explicitly says so, "so terminal-status tasks fail fast
  without ever touching the lock"). A `hold` arm belongs inside the *same* `if` block (preserving
  the `revise` exemption — `skill-reviser`'s contract is "no status-based ABORT rules"), ahead of
  the lock acquire, emitting its own distinct ABORT message (referencing `hold_reason` and
  pointing at the lift path) rather than reusing the terminal message. Unlike `/orchestrate`,
  this single-command entry point has no `$FORCE_PHASES_FLAG`-equivalent plumbing at all (it is
  the gate for one bare `/research`, `/plan`, or `/implement N` invocation) — so there is no
  override to wire here; a held task simply ABORTs on every single-command entry point until a
  human lifts the hold (via `update-task-status.sh`) or routes through `/orchestrate N
  --research|--plan|--implement` instead, whose forcing-flag override is a *different* mechanism
  that never calls this guard.

### Phase 3 — Operator-settable, reversible

- `scripts/update-task-status.sh`: `target_status` validation (line ~211) is a flat `[[ ... !=
  ... ]]` chain of 7 string literals (`research|plan|implement|pr_ready|needs_research|partial|
  blocked`) — needs `hold` added. `map_status()` (lines ~281-320) is a `case "${op}:${target}"`
  switch with 10 literal arms, each resolving to a static `STATE_STATUS`/`TODO_STATUS` pair; the
  comment directly above the `postflight:partial)`/`postflight:blocked)` arms explicitly
  documents *why* there is deliberately no `preflight:partial`, `preflight:blocked`, or
  `preflight:needs_research` arm ("postflight-only task-level termini... derived from a dispatch
  outcome"). `hold` is the first status in this enum that is human-initiated rather than
  dispatch-derived, so `preflight:hold` is the one new arm that genuinely breaks this pattern —
  confirmed this needs the comment extended (not silently contradicted) to say so explicitly, as
  the dispatch directs.
- **Setting a hold** (`preflight:hold`) must write three NEW fields atomically alongside the
  normal `STATE_STATUS`/`TODO_STATUS` write: `hold_reason` (from a new `--hold-reason=<string>`
  CLI flag, following the exact validation shape `--file-scope-add`/`--research-questions`
  already use — a malformed/absent-when-required value is a hard validation error, never a silent
  no-op), `held_at` (today's date, `YYYY-MM-DD` — every other date-stamp in this script is
  produced the same way state-write.sh's jq transform already stamps `last_updated`, so this
  should reuse that same timestamp source rather than a second `date` call), and `prior_status`
  (the task's CURRENT `.status` value in state.json, read BEFORE the overwrite — the script
  already reads the current entry for other purposes, e.g. idempotent no-op detection, so this is
  a read that already happens or needs only a small addition, not a new read path).
- **Lifting a hold**: the dispatch asks research to "decide and document the lift surface." Two
  candidate designs, both viable:
  1. A `target_status` value on this same script (e.g. `unhold`), operation `preflight` (lifting
     is equally human-initiated, not dispatch-derived — same reasoning as setting the hold).
  2. A `/task` flag (e.g. `/task --unhold N`) that shells out to this script internally.
  Recommendation (see Decisions): option 1, via a new `target_status=unhold` arm, because it
  keeps the single atomic state-write.sh transaction that `update-task-status.sh` already owns,
  avoids introducing a second top-level command surface for what is fundamentally still a status
  write, and composes naturally with the existing preflight/postflight CLI shape every other
  caller already knows. The one wrinkle `map_status()`'s current design does not cleanly
  accommodate: `STATE_STATUS` for `unhold` is NOT a fixed literal — it must come from the task's
  own `prior_status` field, read from state.json at call time, then validated via
  `status_vocabulary_is_valid` before being used as the write target (a defensive check against a
  corrupted/missing `prior_status`, which must be a loud error, not a silent fall-back to e.g.
  `not_started`). This means the `unhold` arm cannot be a bare `case` literal like its 10 siblings
  — it needs a short preamble that reads `prior_status` before calling (or substituting for)
  `map_status()`. Clearing the three fields on lift should be a `del(.hold_reason, .held_at,
  .prior_status)` in the jq transform, matching the established convention this codebase already
  uses for "optional, present only in one state" fields (`completion_summary`'s doc comment:
  "Required when status is completed... schema-optional here since only completed entries carry
  it" — i.e., the field is omitted entirely when not applicable, never nulled).

### Phase 4 — `/todo` archival and held subtasks

- `skills/skill-todo/SKILL.md` Stage 2 (`ScanTasks`, lines 79-83) identifies archive candidates by
  three POSITIVE matches only (`status = "completed"`, `"abandoned"`, `"expanded"`) — confirmed a
  `hold`-status task is never selected into `candidate_tasks` in the first place, and the later
  archive-write jq (lines ~454-455) independently re-confirms this by also positive-matching only
  those same three values when moving entries into `.completed_projects`/`.archived_projects`.
  **Held tasks are already never archived, by construction, at two independent points** — no
  redundant guard is needed, matching the dispatch's claim. (The dispatch's own line pointer,
  ~164-166, actually names the Stage 2.5 `TopicRevision` selector, which is a different,
  inverted-select mechanism used only to find tasks missing a `topic` field for backfill — not
  the archival-candidate selector. Both selectors independently exclude `hold`, but for different
  reasons and via different code; worth noting precisely in case a future reader follows the
  dispatch's line number expecting to find the archival guard there.)
- **The real open question**, confirmed exactly as the dispatch frames it: the `expanded)` arm's
  nested subtask-blocking loop (duplicated verbatim in both `skill-todo/SKILL.md`, lines ~106-131,
  and `commands/todo.md`, lines ~163-190) uses `case "$subtask_status" in
  completed|abandoned|expanded) ;; *) ((blocking_count++)) ;; esac`. A held subtask hits the `*)`
  branch and increments `blocking_count`, deferring the parent's archival indefinitely (into
  `deferred_expanded[]`) with no path to ever un-defer it short of lifting every held subtask's
  hold. Both documented candidate readings are legitimate:
  - (a) Correct as-is: a parent with genuinely paused work is genuinely not done, and
    `deferred_expanded[]`'s existing surfacing (both files already report deferred parents back
    to the user/dry-run output) already gives visibility — no silent archival of work-in-progress.
  - (b) Treat a held subtask as non-blocking (add `hold` to the `completed|abandoned|expanded)`
    arm's case pattern) and rely on the existing `deferred_expanded` reporting surface to instead
    surface *which specific subtasks are held* as an informational note, distinct from "genuinely
    still active" blocking.
  Recommendation (see Decisions): (a), unmodified — a hold is explicitly a *pause*, not a
  completion-equivalent, and conflating "held" with "terminal enough to not block" would make a
  parent task's `[EXPANDED]` -> archive transition stop accurately reflecting whether its
  subtasks' work has actually concluded. The one-line mitigation this report recommends adding
  (not a code change, a reporting improvement already in scope for Phase 4): when a subtask's
  `blocking_count` increment is attributable specifically to a `hold` status, name it in the
  existing deferred/blocking message the two files already produce, so an operator reviewing
  `/todo`'s output immediately sees "deferred because subtask N is held (reason: ...)" rather than
  a generic "still active" message that gives no actionable next step.
- `scripts/generate-todo.sh`: the `terminal_count`/`active_count` split (lines ~452-455) is a
  2-arm `case "$task_status" in completed|abandoned|expanded) ...; *) active_count ...; esac` —
  confirmed `hold` falls to the `*)` branch, counting as active. This is defensible and requires
  no code change: a held task is explicitly non-terminal, so counting it among "active" (as
  opposed to a nonexistent third bucket) is the correct and simplest behavior; a documentation
  note suffices (Phase 5 already covers this file implicitly via the TODO.md marker-mapping
  table).
- `commands/todo.md` line ~184's `completed|abandoned|expanded)` arm is the SAME duplicated
  subtask-blocking code as `skill-todo/SKILL.md`'s (confirmed via diff-by-eye — both files are
  near-byte-identical at this block, `commands/todo.md`'s own comment calling itself "the
  reference implementation this mirrors"). Any decision made for Phase 4's open question must be
  applied to BOTH files in lockstep, not just one, or the command and the skill silently diverge.
- Stage 1.5 `ReconcileScan` (`skills/skill-todo/SKILL.md`, lines ~48-56) selects exactly
  `researching`, `planning`, `implementing`, `partial` — confirmed `hold` is absent from this
  four-value positive-match selector, so a held task is never a candidate for
  `reconcile-task-status.sh`'s dry-run promotion-detection pass. No change needed; this matches
  the dispatch's expectation that a held task must not be silently promoted out of hold by
  reconciliation.

### Phase 5 — Documentation

- `context/standards/status-markers.md`: confirmed the exact template to mirror —
  `#### [PARTIAL]` / `#### [BLOCKED]` (lines 132-149) are the two shortest, most directly
  analogous sections (both non-terminal exception states with a "Required Information" block for
  `[BLOCKED]`). The TODO.md-vs-state.json mapping table (lines 272-285), the Command -> Status
  mapping table (lines 296-302), and the Valid Transition Diagram (lines 345-369, which currently
  lists the 8 non-terminal statuses explicitly in its box and the 3 terminal ones in its closing
  note) all need a `hold`/`[HOLD]` row or mention. The diagram in particular needs care: `hold`
  must NOT be added to the "Any Non-Terminal Status" box's implicit "anything here can be
  dispatched" framing, since that box's whole point is "/research, /plan, /implement all work
  from here" — hold is the first status for which that is false. A third, separate annotation
  (not a box membership) correctly captures "non-terminal yet non-dispatchable."
- `merge-sources/claudemd.md` (the file whose content is deployed verbatim into both
  `/home/benjamin/.config/nvim/CLAUDE.md`'s sibling `.claude/CLAUDE.md` and reproduced in this
  very conversation's system reminder) lines 39-40 currently define exactly two categories:
  "Terminal states" (`[ABANDONED]`, `[EXPANDED]`) and "Exception states (non-terminal; any
  command can resume from these)" (`[BLOCKED]`, `[PARTIAL]`). Confirmed `[HOLD]` fits neither
  bullet's stated property — it is non-terminal (fits category 2's first half) but explicitly NOT
  resumable by any ordinary command (violates category 2's second half) — so a third bullet is
  required, e.g. "`[HOLD]` - Paused state (non-terminal, but not resumable by any command except
  an explicit `/orchestrate --research|--plan|--implement` override or an operator-run lift)."
- `context/reference/state-management-schema.md`: the "Project Entry Fields" table (lines ~76-93)
  is the right place for three new rows (`hold_reason`, `held_at`, `prior_status`), following the
  exact "Documented-optional... present only after X" phrasing convention already used for
  `research_questions`. A short "### Hold Fields" subsection (mirroring the existing "###
  Research Questions Field" subsection at line 278) should additionally narrate that
  `prior_status` is what makes the hold reversible (the field that distinguishes this from a
  one-way archival) and document the chosen lift surface from Phase 3's decision.

## Decisions

1. **Triage-classifier group for `hold`**: a new dedicated `group:"hold"` (not a reuse of
   `needs_human` or `skip`). Rationale: `needs_human` already carries connotations of an
   exceptional/error condition requiring triage; `skip`'s existing reason text ("transitional/
   unknown") would misdescribe a deliberately-set, fully-explained status. A dedicated group lets
   `orchestrate-cycle-plan.sh`'s bucketing switch produce a `hold`-specific `blocked[]` reason
   built from the task's own `hold_reason` field.
2. **Cycle-plan bucketing precedent**: mirror `forced_round_complete)` exactly — a `hold)` case
   arm pushing a reasoned `blocked[]` row and `continue`ing before the lock probe, dispatch_seq
   mint, status write, or cycle charge. This is the closest existing precedent in the file and
   satisfies the acceptance criterion (a visible `blocked[]` row, never a dispatch) without
   inventing a new top-level array.
3. **`is_terminal_status` stays unwidened**: `hold` is explicitly excluded from this 3-case
   function. Widening it would let `/todo` archive held tasks and would let a held dependency
   wrongly satisfy a dependent task's "all dependencies completed" discharge check — both
   directly contradict the feature's purpose.
4. **Forcing-flag override wiring differs by entry point, deliberately**: `/orchestrate`'s STAGE 0
   gains a direct `$FORCE_PHASES_FLAG`-conditional admit for `hold` (the variable is already
   populated at that point in the script); `command-gate-in.sh` (the single-command `/research`,
   `/plan`, `/implement` gate) gets NO override — it has no forcing-flag plumbing at all, so a
   held task simply ABORTs there until lifted or routed through `/orchestrate ... --research|
   --plan|--implement` instead. These are two different, deliberately non-identical guards, not a
   bug to reconcile.
5. **Lift surface**: a new `target_status=unhold` value on `update-task-status.sh`, operation
   `preflight` (lifting is human-initiated, same reasoning as setting). `STATE_STATUS` for this
   arm is read dynamically from the task's own `prior_status` field (validated via
   `status_vocabulary_is_valid` before use — a missing/corrupt `prior_status` must be a loud
   error, not a silent fallback), not a fixed literal like `map_status()`'s other 10 arms. The
   three hold fields are cleared via `del(...)` (field omission), not nulled, matching this
   codebase's existing convention for state-only-in-one-status fields.
6. **Held-subtask blocking (Phase 4's open design question)**: resolved as reading (a) — a held
   subtask continues to BLOCK its parent `[EXPANDED]` task's archival (no change to the
   `completed|abandoned|expanded)` case pattern in either `skill-todo/SKILL.md` or
   `commands/todo.md`). A held subtask represents genuinely paused, not-done work; conflating it
   with terminal states would make `/todo` archive a parent whose subtask work has not actually
   concluded. The recommended mitigation is a reporting improvement (name the hold reason in the
   existing deferred-parent message), not a behavior change to the blocking logic itself.
7. **`generate-todo.sh`'s `active_count`/`terminal_count` split**: left unmodified — `hold` falls
   to `active_count` via the existing `*)` catch-all, which is correct (a held task is
   non-terminal) and requires no code change, only a documentation note.

## Recommendations

- Land Phase 1 first and alone, exactly as the dispatch directs — it is independently valuable
  (un-breaks the consumer repo's `generate-todo.sh`/`validate-state.sh` immediately) and fully
  decoupled from Phases 2-5.
- In Phase 2, write the new `hold` guard in `commands/orchestrate.md`'s STAGE 0 to branch on
  `$FORCE_PHASES_FLAG` directly (per Decision 4) rather than copying the existing
  `completed|abandoned|expanded)` arm's unconditional-skip shape — flag the adjacent
  terminal+forced-admission gap found during research (see Findings, Phase 2) in the plan as an
  explicitly OUT-OF-SCOPE observation, not something this task's phases should silently fix.
- In Phase 3, implement `--hold-reason=<string>` using the exact same validation shape
  `--file-scope-add`/`--research-questions` already establish (malformed/missing-when-required is
  a hard validation error, never silent). Read `prior_status` from the CURRENT state.json entry
  before any jq transform runs, not after.
- In Phase 4, apply the Decision 6 resolution identically to both `skill-todo/SKILL.md` and
  `commands/todo.md` (they are near-byte-duplicated at this exact block) — do not patch one and
  miss the other.
- In Phase 5, when editing the Valid Transition Diagram, add `hold` as a distinct annotation
  outside the "Any Non-Terminal Status" box rather than inside it, since box membership currently
  implies "any command can dispatch from here," which is precisely false for `hold`.
- Re-run the live consumer-repo discovery (`jq` query over `/home/benjamin/Projects/Logos/
  Verification/specs/state.json`) immediately before claiming Phase 1/2 completion, exactly as
  the dispatch's acceptance section requires — this research confirmed 9 held tasks
  (125, 126, 127, 128, 141, 142, 143, 162, 165) as of this research pass, but another active
  session may change that set before implementation lands.

## Risks & Mitigations

- **Risk**: adding `hold` to `is_terminal_status` or to the discharge-eligible set in
  `orchestrate-cycle-plan.sh`'s `blocked`-discharge logic by mistake (both currently check for
  dependency status equal to exactly `"completed"`, so this risk is more about `is_terminal_status`
  itself being reused in a context where "hold should count as resolved" might seem tempting).
  Mitigation: Decision 3 above states explicitly that `is_terminal_status` must stay a 3-case
  function; code review / tests should assert `is_terminal_status hold` returns 1 (false).
- **Risk**: the two duplicated subtask-blocking `case` blocks (`skill-todo/SKILL.md` and
  `commands/todo.md`) drift — a future edit touches one and not the other. Mitigation: call this
  out explicitly in the implementation plan as a "both files, same change" item, and consider
  (as a documentation follow-up, not required by this task) a comment cross-referencing the two
  files as the dispatch itself already does for other duplicated-logic pairs in this codebase
  (e.g. `orchestrate-triage-classify.sh`'s own header documents a "four sites must change
  together" rule for a similar duplication).
- **Risk**: `update-task-status.sh`'s new `unhold` arm, because `STATE_STATUS` is dynamic rather
  than a fixed literal, is architecturally different from every other `map_status()` arm and could
  be implemented inconsistently (e.g. skipping the `status_vocabulary_is_valid` revalidation that
  every other arm gets "for free" via the closed `case` statement). Mitigation: explicit test
  coverage for (a) lifting a hold whose `prior_status` is a valid enum member succeeds and
  restores it exactly, and (b) lifting a hold whose `prior_status` is missing or corrupt fails
  loudly rather than defaulting silently to e.g. `not_started`.
- **Risk**: Phase 2's new `hold` guard in `commands/orchestrate.md` STAGE 0 is written by copying
  the existing terminal arm's shape, silently inheriting the same "never checks
  `$FORCE_PHASES_FLAG`" gap this research found (see Findings, Phase 2) — which would make the
  dispatch's explicit, decided requirement ("an explicit --research/--plan/--implement CAN
  override a hold") simply not work in the live (non-dry-run) path. Mitigation: this is flagged
  prominently in both Findings and Decisions above specifically so the implementer does not copy
  that shape uncritically; acceptance testing should include a live (non-`--dry-run`)
  `/orchestrate N --implement` against a held task with a plan artifact and confirm a dispatch
  actually happens.

## Context Extension Recommendations

- **Topic**: HOLD status lifecycle. **Gap**: `context/standards/status-markers.md` and
  `context/reference/state-management-schema.md` will, after this task, be the only places this
  feature's full contract lives in prose; there is no single "non-terminal-but-non-dispatchable"
  category precedent elsewhere in the context tree to point a future similar feature at.
  **Recommendation**: once landed, consider a short cross-reference note in
  `context/patterns/` (if a `status-lifecycle-exceptions.md`-shaped pattern file does not already
  exist) explaining the three-way split (terminal / exception-resumable / exception-paused) as a
  reusable design vocabulary, since a 4th status marker with yet another nuance is plausible
  future work. Not creating this file now — it is speculative beyond this task's scope — but
  naming the gap per this section's purpose.

## Appendix

### Search queries / commands used

- `jq '.definitions.taskStatus'` / `jq '.definitions.projectEntry.properties | keys'` /
  `jq '.definitions.projectEntry.additionalProperties'` against
  `context/schemas/state-schema.json`
- `grep -n "KNOWN_ENTRY_FIELDS" -A 30 scripts/validate-state.sh`
- `grep -n "is_terminal_status\|task_has_forced_phase" scripts/orchestrate-cycle-plan.sh`
- `grep -rn "blocking_reason" .` (source store root) — confirmed single prose-only hit
- `grep -rln '"hold"\|\bhold\b' --include="*.sh" --include="*.md" --include="*.json" .` then
  targeted `grep -n '"hold"\|== "hold"'` on the actual dispatch/postflight/triage scripts —
  confirmed zero existing `hold`-status handling anywhere (clean, from-scratch addition)
- Live consumer-repo checks (read-only): `jq '[.active_projects[] | select(.status=="hold") |
  {project_number, status, hold_reason, held_at, prior_status}]' specs/state.json`,
  `bash .claude/scripts/generate-todo.sh`, `bash .claude/scripts/validate-state.sh` — all run
  against `/home/benjamin/Projects/Logos/Verification`, read-only, no writes performed there

### Files read (source store, `agent-system/extensions/core/` unless noted)

- `scripts/lib/status-vocabulary.sh` (full)
- `context/schemas/state-schema.json` (targeted `jq` reads)
- `scripts/validate-state.sh` (targeted: KNOWN_ENTRY_FIELDS, status-enum check)
- `scripts/generate-todo.sh` (targeted: `format_status`, `terminal_count`/`active_count` split,
  the base64/jq task-row pipeline)
- `scripts/orchestrate-triage-classify.sh` (header table + full jq classification chain)
- `scripts/orchestrate-cycle-plan.sh` (targeted: `is_terminal_status`, `task_has_forced_phase`,
  eligibility loop, `effective_group` computation, bucketing switch incl. `forced_round_complete`)
- `commands/orchestrate.md` (targeted: STAGE 0 validated_tasks loop, dry-run short-circuit,
  `--research`/`--plan`/`--implement` flag table, delegation JSON)
- `scripts/command-gate-in.sh` (targeted: terminal guard, lock-acquire ordering)
- `scripts/update-task-status.sh` (targeted: usage/validation, `map_status()`, optional-flag
  patterns for `--file-scope-add`/`--research-questions`)
- `skills/skill-todo/SKILL.md` (targeted: Stage 1.5 ReconcileScan, Stage 2 ScanTasks +
  subtask-blocking case, Stage 2.5 TopicRevision, archive-write jq)
- `commands/todo.md` (targeted: duplicated subtask-blocking case block)
- `context/standards/status-markers.md` (targeted: `[PARTIAL]`/`[BLOCKED]`/`[ABANDONED]`
  sections, mapping table, command table, transition diagram)
- `merge-sources/claudemd.md` (targeted: Status Markers section, lines 30-46)
- `context/reference/state-management-schema.md` (targeted: Top-Level/Project-Entry field tables)
- `scripts/tests/test-status-vocabulary.sh` (targeted: 12-value assertion)
- Test-file existence/size confirmation only (not read in depth — implementation-phase work):
  `test-validate-state.sh`, `test-orchestrate-triage-classify.sh`,
  `test-orchestrate-cycle-plan.sh`, `test-force-phases.sh`, `test-update-task-status.sh`,
  `scripts/tests/known-failures.txt`
