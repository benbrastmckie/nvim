# Research Report: Task #215

**Task**: 215 - Unwind an unconsumed /orchestrate dispatch
**Started**: 2026-09-18
**Completed**: 2026-09-18
**Effort**: medium (one new script, two doc edits, one SKILL.md pointer, one fixture test suite)
**Dependencies**: None (this task's own follow-on, the per-run cycle-budget task, has already
landed — confirmed live in the codebase; see Findings)
**Sources/Inputs**: Codebase read (agent-system/extensions/core/scripts/*.sh,
agent-system/extensions/core/skills/skill-orchestrate/SKILL.md,
agent-system/extensions/core/docs/architecture/orchestrate-state-machine.md,
agent-system/extensions/core/context/standards/{orchestrator-runtime-files,git-safety}.md,
agent-system/extensions/core/scripts/tests/test-orchestrate-cycle-plan.sh)
**Artifacts**: - This report
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- The AMENDMENT is already true of the live codebase: the per-run cycle-budget task has landed.
  `cycle_count` in `.orchestrator-loop-guard` is inert/backward-compat only; the durable,
  cross-invocation field that must be rolled back is `dispatch_seq_counter`, alongside
  `pending_dispatch`. WORK item (a)'s original "rolls back the cycle count" is correctly dropped;
  the amended acceptance criterion (`pending_dispatch` and `dispatch_seq_counter` match their
  earlier values) is exactly what the current schema supports.
- Every mechanism WORK (a) asks the new script to reuse already exists in a directly-callable,
  argument-compatible form: `orchestrate-loop-guard-init.sh --flush-seq <task_dir_abs> <old_seq>`
  rolls `dispatch_seq_counter` back, `--clear-pending <task_dir_abs>` clears `pending_dispatch`,
  `task-lock.sh release <task_number> <holder_session>` is already session-safe (WARNs and no-ops
  on a session mismatch instead of force-removing), and `state-write.sh` accepts an arbitrary jq
  filter with `--regen-todo`, so restoring `status`/`last_updated`/`session_id` to an exact prior
  triple and regenerating `TODO.md` is one call. **No new verb needs to be added to
  `orchestrate-loop-guard-init.sh` or `task-lock.sh`.**
- One genuine gap remains, exactly as WORK (a) flags: nothing today captures the **pre-dispatch**
  `status`/`last_updated`/`session_id` triple anywhere. `orchestrate-cycle-plan.sh`'s live loop
  overwrites all three via `skill_preflight_update` (which calls
  `update-task-status.sh preflight`) before the `pending_dispatch` record is ever built later in
  the same iteration. Closing this requires a small, surgical change to
  `orchestrate-cycle-plan.sh` itself (capture the pre-image immediately before the
  `skill_preflight_update` call, thread it into the `pending_dispatch` JSON built later in the
  same iteration) — `orchestrate-loop-guard-init.sh --record-pending` already accepts an
  arbitrary JSON object verbatim, so widening the record's shape needs no change there.
- A subtlety the planner should resolve explicitly: `task-lock.sh acquire` always uses the BARE
  `$session_id` as the lock holder, but `skill_preflight_update`'s `session_id` argument (and
  hence the value written into `state.json`) is the SUFFIXED `${session_id}_${t}` for
  research/plan phases (bare only for implement — see the "Bare-vs-suffixed session_id invariant"
  documented in `orchestrate-cycle-plan.sh`'s own header). The unwind script therefore MUST NOT
  derive the lock-release session from the stray `state.json.session_id` value for a
  research/plan dispatch — it should instead read the *lock's own* holder session via
  `task-lock.sh check <task_number>` and release with that value. `task-lock.sh release` already
  double-checks the holder itself, so this is belt-and-braces, not merely convenient.
- `context/standards/git-safety.md` does **not currently contain any `guard-destructive-git.sh`
  explanation** — that explanation actually lives in `context/standards/git-staging-scope.md` and
  `context/patterns/checkpoint-before-overflow.md`. WORK (b)'s phrase "next to the
  guard-destructive-git.sh explanation" does not have a literal target inside `git-safety.md`
  today; the planner should either add a short guard-destructive-git.sh cross-reference to
  `git-safety.md` alongside the new documentation, or re-target the phrase's intent (a
  destructive-git-adjacent safety doc) to `git-staging-scope.md` instead/in addition. This is
  flagged as a documentation-placement decision, not a blocker.
- `.orchestrator-loop-guard` and `.dispatch/` are both gitignored (`specs/.gitignore`, generated
  by `runtime_specs_ignore_block()`). Only `specs/state.json` and `specs/TODO.md` are tracked
  targets for the optional scoped commit — `git status --porcelain -- specs/` will show nothing
  else once those two are committed, confirming the acceptance criterion is achievable with a
  two-path `git-commit-scoped.sh` call.
- A real-world risk to flag: the acceptance/refusal condition ("dispatch_file still on disk")
  mirrors the existing UNCONSUMED-DISPATCH-REPLAY detection exactly, but it also means the
  sanctioned tool becomes **inapplicable after the fact** if a user does what the observed
  incident's user actually did — manually delete the dispatch file first. The tool only helps if
  reached for *before* manual cleanup. Worth a one-line callout in the new documentation.
- Recommendation for WORK (c): **by-hand only**, never auto-invoked from the Setup/Move loop.
  Justification below (Decisions section) — the existing `pending_dispatch` REPLAY mechanism
  already encodes the system's answer to "prepared-but-unconsumed dispatch, should we continue
  it automatically", and it says yes (resume it as a legitimate work cycle, don't re-charge). An
  automatic unwind would fight that mechanism on the exact same signal with no way to
  distinguish "the operator wants to abandon this" from "this is a normal crash-and-resume".
  There is also no reliable liveness signal at the moment a *fresh* `/orchestrate` invocation
  starts that can safely infer "the prior session is truly gone and truly did not want this," as
  opposed to a still-running prior session about to reach Move 2 momentarily (`task-lock.sh`'s
  own staleness threshold is the only signal, and it is already committed to the opposite
  (resume) interpretation for `reconcile-task-status.sh`'s demotion path).

## Context & Scope

Task 215 asks for a new script, `orchestrate-unwind-dispatch.sh`, that reverses everything
`orchestrate-cycle-plan.sh`'s live path mutates during Move 1 (status/last_updated/session_id
preflight write, task lock, `.dispatch/{seq}.md` file, the multi-state file, and the durable
per-task `.orchestrator-loop-guard`'s `pending_dispatch`/`dispatch_seq_counter`) for the specific
case where Move 2 (the Agent tool dispatch) never actually ran — a crash, an abandoned run, or an
operator who decides not to proceed. This research pass traced every one of those six mutation
sites to its exact current implementation, confirmed which already expose a safe, reusable
undo-capable interface and which do not, confirmed the amendment (per-run cycle-budget change)
is already live, and surfaced the concrete design questions the planning phase needs to resolve
(pre-image capture location/shape, lock-release session-identity, and documentation placement).

No code was written in this phase — this is upstream research for `/plan 215`.

## Findings

### The six mutation sites, and what already exists to reverse each

1. **Preflight status write** (`status`, `last_updated`, `session_id` on the task's
   `active_projects[]` entry in `specs/state.json`). Written by
   `skill_preflight_update` (`scripts/skill-base.sh:325`), which calls
   `update-task-status.sh preflight <task_number> <operation> <session_id>`
   (`scripts/orchestrate-cycle-plan.sh:1863`). `update-task-status.sh`'s `update_state_json()`
   (lines 750-761) does exactly:
   ```
   (.active_projects[] | select(.project_number == ($num|tonumber))) |= . + {
     status: $status, last_updated: $ts, session_id: $sid
   }
   ```
   `update-task-status.sh` cannot be reused for the *restore* direction: its `target_status`
   argument is a closed vocabulary mapped through `map_status()` (research/plan/implement/
   pr_ready/needs_research/partial/blocked) — it has no way to write back an arbitrary historical
   `status` string, nor to set an arbitrary historical `last_updated`/`session_id` pair. The
   dispatch's own hint ("update-task-status.sh and state-write.sh are the sanctioned state
   writers") is correct in aggregate, but for THIS specific restore, only `state-write.sh` is the
   right tool — it takes an arbitrary jq filter:
   ```bash
   bash .claude/scripts/state-write.sh \
     '(.active_projects[] | select(.project_number == ($num|tonumber))) |= . + {
        status: $status, last_updated: $ts, session_id: $sid
      }' \
     --session-id "$session_id" --arg num "$task_number" \
     --arg status "$prior_status" --arg ts "$prior_last_updated" --arg sid "$prior_session_id" \
     --regen-todo
   ```
   `--regen-todo` folds in the "regenerates TODO.md" requirement for free (same mechanism
   `update-task-status.sh` itself rides on).

2. **Task lock** (`<task_dir>/.lock/`). `task-lock.sh release <task_number> <session_id>`
   (`scripts/task-lock.sh:974-1003`) already implements "release only if this session holds it":
   it reads `holder.json`'s `session_id`, and if the given `session_id` doesn't match, it WARNs
   and returns 0 **without removing the lock** (line 989-996) — i.e. it is already a safe no-op
   on mismatch, never a force-remove. The only design question is *which* session value to pass
   (see the bare-vs-suffixed subtlety below) — no new verb is needed.

3. **`.dispatch/{seq}.md` file.** A plain `rm -f` of the path recorded in `pending_dispatch.
   dispatch_file` is sufficient — the file is gitignored (`**/.dispatch/` in
   `specs/.gitignore`), so no git bookkeeping is needed for its removal either.

4. **`dispatch_seq_counter`** in the durable `<task_dir>/.orchestrator-loop-guard` file.
   `orchestrate-loop-guard-init.sh --flush-seq <task_dir_abs> <n>` (lines 76-89, 142-168)
   already does exactly "read-modify-write, set `.dispatch_seq_counter = $s`, preserve
   everything else" — the unwind script can call it directly with
   `<pending_dispatch.seq - 1>` (the value the counter held immediately before this dispatch's
   own mint) to roll it back. No new verb needed.

5. **`pending_dispatch`** in the same guard file. `orchestrate-loop-guard-init.sh
   --clear-pending <task_dir_abs>` (lines 102-108, 221-236) already does `del(.pending_dispatch)`,
   is idempotent, and is exactly the semantics needed ("un-record the charge"). This is the SAME
   call `orchestrate-cycle-postflight.sh` makes as the very first act of every real postflight
   (`scripts/orchestrate-cycle-postflight.sh:318-320`) — which is also the refusal check's basis
   (see below). No new verb needed.

6. **The multi-state file** (`specs/.orchestrator-multi-state-{session_id}.json`). This file is
   keyed by the (dead) session's own `session_id`, is ephemeral/gitignored
   (`**/.orchestrator-multi-state*.json`), and is scoped per-invocation — a fresh `/orchestrate`
   run mints a brand-new one under a brand-new `session_id` and never reads the old one (Move 1's
   `mt_state_file` path is derived fresh from `--session $session_id` each invocation; see
   `orchestrate-cycle-plan.sh:463`). WORK (a) says "fixes the multi-state file if it is present" —
   this is a defensive best-effort touch (the file may not even exist by the time the unwind
   script runs, if the crash happened before Move 1 finished, or the file's owning session_id may
   not be independently knowable from the task alone without also being given the crashed
   session's `session_id`). The planner should treat this as "if the caller can name the crashed
   session's mt_state_file path, patch or delete it; otherwise this step is a no-op" rather than
   something the unwind script can always locate purely from `<task_number>`.

### The genuinely missing piece: pre-dispatch status/last_updated/session_id capture

`orchestrate-cycle-plan.sh`'s live per-task loop (`scripts/orchestrate-cycle-plan.sh:1805-1980`)
runs, in order: task directory creation, lock acquire, dispatch_seq mint, **preflight status
write** (line 1863), `orchestrate-build-dispatch.sh` (line 1899), agent resolution, and only THEN
(lines 1937-1968) the replay-check / `pending_dispatch` record-or-reuse logic. By the time
`_pd_record_json` is built (line 1963), the task's PRE-dispatch `status`/`last_updated`/
`session_id` triple has already been overwritten in `state.json` and is nowhere else captured.

The fix is small and surgical: read `lookup_project "$t"` (or the equivalent
`task_lookup_entry`) **immediately before** the `skill_preflight_update` call at line 1863,
capture `status`/`last_updated`/`session_id` into local shell variables, and add them to the
`_pd_record_json` object built at lines 1963-1966 (the non-replay branch only — see next
paragraph for why the replay branch needs no change). `orchestrate-loop-guard-init.sh
--record-pending` takes the JSON object **verbatim** (its own header: "sets `.pending_dispatch`
to the given JSON object verbatim... this form does not construct it") — so widening the shape
from `{seq, phase, forced, dispatch_file, recorded_at}` to add `prior_status`,
`prior_last_updated`, `prior_session_id` requires **zero changes** to
`orchestrate-loop-guard-init.sh`. It is purely a caller-side (`orchestrate-cycle-plan.sh`) change,
confined to the one already-identified `_pd_record_json` construction site.

**Why the REPLAY branch (lines 1948-1953) needs no equivalent change**: on a replay cycle,
`skill_preflight_update` still runs unconditionally every cycle (it is called once per iteration
regardless of what the later replay/non-replay branch decides), so re-capturing "prior status"
at that point would actually observe the *already-in-flight* marker from the original,
never-consumed dispatch — not the true pre-dispatch value. This is harmless only because the
replay branch never calls `--record-pending` again; the original record (with its correctly
captured prior_status from the FIRST charge) is left untouched on disk. The planner must preserve
this invariant: only the non-replay (`else`) branch may write the prior-image fields into
`pending_dispatch`.

### Session-identity subtlety for lock release

`orchestrate-cycle-plan.sh`'s own header documents a load-bearing "Bare-vs-suffixed session_id
invariant": `task-lock.sh acquire`/`check`/`heartbeat` always use the **bare** `$session_id`
(the value passed to `orchestrate-cycle-plan.sh` itself via `--session`), while
`skill_preflight_update`'s `session_id` argument — and hence the value that lands in
`state.json`'s `session_id` field — is the **suffixed** `${session_id}_${t}` for research/plan
phases (bare only for `implement`, since the implement dispatch's own context also needs the bare
form). Consequently:

- For an **implement**-phase stray dispatch, `state.json.session_id` and the lock holder's
  session_id are identical.
- For a **research/plan**-phase stray dispatch, they differ by the `_<task_number>` suffix.

The unwind script should NOT assume it can derive the lock-release session from the captured
`prior_session_id`/current stray `session_id` field. The robust approach: call
`task-lock.sh check <task_number>` first, parse `session=<holder_session>` out of its output
(`scripts/task-lock.sh:1008-1037`, `held-fresh`/`held-stale` output format), and release with
THAT value. `task-lock.sh release` independently re-verifies the holder before removing anything
(lines 989-996), so this is defense in depth, not a single point of trust.

### Refusal condition and its relationship to the existing REPLAY detector

WORK (a)'s refusal condition — "a `pending_dispatch` exists whose `dispatch_file` is still on
disk and no postflight has consumed it" — is literally the same predicate
`orchestrate-cycle-plan.sh`'s own UNCONSUMED-DISPATCH-REPLAY branch already evaluates (lines
1939-1947: phase match, forced match, `dispatch_file` non-empty AND `-f` on disk). "No postflight
has consumed it" reduces to "`pending_dispatch` is still present at all", because
`orchestrate-cycle-postflight.sh` clears it **unconditionally, as the very first mutating act, on
every outcome** (success/failure/defer/off-schema — `scripts/orchestrate-cycle-postflight.sh:
305-320`). So the unwind script's whole refusal gate is: read `orchestrate-loop-guard-init.sh
--seed <task_dir_abs>` (a read-only peek that already returns `pending_dispatch` — line 61's
output contract), refuse if it is `null`, refuse if `pending_dispatch.dispatch_file` does not
exist on disk. Both a fixture asserting the happy path and a fixture asserting the
already-consumed refusal (call `--clear-pending` first, then run the unwind script) map directly
onto existing test-fixture idioms already used in `scripts/tests/test-orchestrate-cycle-plan.sh`
Group 19 (durable pending_dispatch ledger tests, lines ~1998-2152), which construct exactly this
kind of `.orchestrator-loop-guard` fixture by hand.

**Risk to flag in documentation**: this refusal condition means the tool is USELESS after a
dispatch file has already been deleted by hand — exactly what happened in the observed live
incident (2026-09-14) this task cites. The new documentation (WORK b) should say, explicitly,
"run this before touching the dispatch file/lock/state by hand", not just describe the mechanism.

### Amendment status: already true of the live codebase

The AMENDMENT text in the dispatch describes a follow-on task ("cycle_counts lives only in the
run's multi-state file, and the saved guard file no longer carries cycle_count") as something
that WILL land. It has already landed: `orchestrate-loop-guard-init.sh`'s own header (lines
21-35) and `context/standards/orchestrator-runtime-files.md` (lines 229-264) both describe the
current, live state exactly as the amendment predicts — `cycle_count` is inert/backward-compat
only, never read or written for budgeting by the batch engine, while `dispatch_seq_counter` is
the field that durably crosses invocations. No further verification action is needed here beyond
confirming (done) that the amended acceptance criterion is achievable with the fields that
actually exist today.

### Git/commit scope

Every one of the six mutation targets except `specs/state.json` and `specs/TODO.md` is
gitignored:
- `.orchestrator-loop-guard`, `.lock/`, `.dispatch/`, `.orchestrator-multi-state*.json` are all
  covered by the managed block in `specs/.gitignore` (confirmed live:
  `git check-ignore -v` on this task's own `.dispatch/1.md` resolves to the `**/.dispatch/`
  pattern).

So the "optionally commits only the paths it touched" step reduces to exactly:
```bash
bash .claude/scripts/git-commit-scoped.sh \
  --message "task {N}: unwind unconsumed {phase} dispatch (seq {S})" \
  --session "$session_id" \
  -- specs/state.json specs/TODO.md
```
which matches this codebase's existing `task {N}: {action}` commit convention
(`.claude/rules/git-workflow.md`) and satisfies the acceptance criterion
("`git status --porcelain -- specs/` shows no leftovers") by construction, since nothing else the
unwind script touches is tracked. `git-commit-scoped.sh` already serializes the add+commit pair
through `specs/.commit-lock/` and handles "nothing to commit" as a non-error (exit 1, documented,
non-fatal per its own header) — the unwind script does not need its own commit-mutex handling.

### Existing, related-but-distinct recovery mechanism

`reconcile-task-status.sh`'s lock-aware demotion (`researching -> not_started`,
`planning -> researched`, `scripts/reconcile-task-status.sh:246-` `demote_stranded_status()`) is
a DIFFERENT, already-automatic mechanism that partially overlaps in observable effect (it also
restores a task's status after a stranded in-flight marker) but is time-gated on
`task-lock.sh check`'s staleness threshold, runs unconditionally at the top of every
`/orchestrate` invocation's Setup stage (`skill-orchestrate/SKILL.md`'s per-task
`reconcile-task-status.sh` call, before Move 1), and does **not** touch `last_updated`/
`session_id` restoration to an exact prior value, does not release the lock, does not delete the
dispatch file, and does not roll back `dispatch_seq_counter`/`pending_dispatch`. It is a
coarser, delayed, artifact-blind safety net for the SAME underlying failure class, not a
substitute for the new unwind script. Worth one clarifying cross-reference in the new
documentation so a future reader does not conflate the two.

### Documentation placement findings

- `docs/architecture/orchestrate-state-machine.md`'s MAX_CYCLES/loop-guard section (lines
  198-253) is the natural home for the new sanctioned-recovery-path documentation: it already
  documents the loop guard file's schema and the `dispatch_seq_counter`/`pending_dispatch`
  cross-invocation contract in prose immediately adjacent (lines 224-235). A new subsection
  ("Unwinding an Unconsumed Dispatch") fits directly after this block.
- `context/standards/git-safety.md` does not currently mention `guard-destructive-git.sh` at all
  (verified: zero matches). The dispatch's placement instruction ("next to the
  guard-destructive-git.sh explanation") therefore has no literal anchor in that file today. The
  actual guard-destructive-git.sh narrative lives in `context/standards/git-staging-scope.md`
  (lines ~163-222) and `context/patterns/checkpoint-before-overflow.md` (lines ~131-136). The
  planner should pick one of: (a) add a short guard-destructive-git.sh cross-reference to
  `git-safety.md` as part of this task so the placement instruction becomes literally true, or
  (b) document the new script in `git-staging-scope.md` instead (where the real
  guard-destructive-git.sh explanation lives) and leave a pointer from `git-safety.md`. Both are
  reasonable; this is a placement decision for planning, not a research blocker.
- `skills/skill-orchestrate/SKILL.md`'s Move 1 section (lines 55-119) has a `**MUST NOT**` bullet
  about never re-invoking `orchestrate-cycle-plan.sh` LIVE purely to inspect state, and documents
  the `stop_json` handling immediately above it (lines 90-95). A one-line pointer to the new
  unwind script fits naturally either right after the `stop_json` handling paragraph (for the
  "this run stopped for some other reason, and there might be a stray unconsumed dispatch to
  clean up" case) or as an addition to the existing MUST NOT bullet's paragraph (since both are
  about "what NOT to do instead, and what TO do instead" at Move 1). No dedicated new section is
  needed there — a pointer sentence suffices per WORK (b)'s own phrasing ("point to it from").
- No entry for `orchestrate-unwind-dispatch.sh` currently exists in
  `docs/reference/utility-scripts-inventory.md`. That inventory's own framing ("Operator-facing
  scripts that are not invoked as part of the normal task lifecycle") matches this new script
  exactly (WORK (c)'s recommended by-hand-only posture reinforces this). This is not named in
  WORK (b)'s three explicit doc targets, so it is offered here as an optional, low-cost addition
  for the planner to accept or decline — not a requirement this report is asserting.

## Decisions

- **WORK (c) recommendation: by-hand only, never auto-invoked.** Three independent reasons,
  all grounded in code already read this session:
  1. The system already has an automatic answer to "a dispatch was prepared but never
     consumed" — the UNCONSUMED-DISPATCH-REPLAY mechanism in `orchestrate-cycle-plan.sh`
     (lines 1937-1968), which treats it as a legitimate, resumable work cycle and deliberately
     avoids re-charging the budget for it. Auto-invoking the unwind script from the same
     Setup/Move-1 entry point would directly contend with that mechanism on the identical
     signal (a present, file-backed `pending_dispatch`) with no way to tell which behavior
     the operator wants this time.
  2. There is no reliable liveness signal, at the moment a *new* `/orchestrate` invocation
     starts, that distinguishes "the prior session is truly gone and this dispatch should be
     discarded" from "the prior session is still mid-flight and about to reach Move 2" other
     than `task-lock.sh`'s own staleness threshold — and that signal is already committed to
     the opposite (resume-oriented) interpretation via `reconcile-task-status.sh`'s demotion
     path and the REPLAY mechanism above.
  3. WORK's own MUST NOT is unconditional: "Do not unwind a dispatch that an agent has started
     or that postflight has consumed." An automatic caller has no additional information beyond
     what a human operator already has (the dispatch file exists, the lock is stale) to prove an
     agent never started — it would rely on exactly the same heuristic that already backs the
     resume path, making an automatic unwind a coin-flip between two directly contradictory
     "automatic" behaviors triggered by the same evidence.
  The by-hand posture is also the cheaper, safer implementation: an explicit `--session SID`
  argument plus (recommended) an interactive/explicit confirmation step keeps the destructive
  direction (discard) opt-in, while the non-destructive direction (resume) stays the default,
  automatic behavior it already is.
- **Lock release must key off `task-lock.sh check`'s own reported holder session, never off the
  unwind script's own `--session SID` argument or off the stray `state.json.session_id` value.**
  See the bare-vs-suffixed subtlety above. `--session SID` should be reserved for commit/state-
  write attribution only.
- **`pending_dispatch`'s shape needs three new optional fields** (`prior_status`,
  `prior_last_updated`, `prior_session_id`), populated by a small, surgical addition to
  `orchestrate-cycle-plan.sh`'s existing `_pd_record_json` construction site (the non-replay
  branch only), with zero changes required to `orchestrate-loop-guard-init.sh` itself (verbatim
  passthrough already supports an arbitrary shape).

## Risks & Mitigations

- **Risk**: the refusal condition (dispatch_file must still exist on disk) makes the tool
  inapplicable once a user has manually deleted the file — exactly the order of operations the
  cited 2026-09-14 incident followed. **Mitigation**: state this explicitly, first, in the new
  documentation ("run this before any manual cleanup"), and consider (planning-phase decision,
  not asserted here) whether a `--force` escape hatch that trusts an operator-supplied prior
  status/session/last_updated triple (when `pending_dispatch` still exists but its file does not)
  is worth the added complexity — WORK's MUST NOT list does not forbid this, but it is out of
  this report's scope to decide.
- **Risk**: a stray, never-flushed multi-state file may not be locatable from `<task_number>`
  alone (it is keyed by the dead session's own `session_id`, which the unwind script's own
  `--session SID` argument will generally NOT match). **Mitigation**: treat multi-state cleanup
  as best-effort/optional, exactly as WORK (a)'s "if it is present" phrasing already allows, and
  do not make the unwind script's success depend on finding it.
- **Risk**: the `_pd_record_json` prior-image capture, if placed at the wrong point in
  `orchestrate-cycle-plan.sh`'s loop, could capture the already-in-flight status on a replay
  cycle instead of the true pre-dispatch value. **Mitigation**: confine the capture-and-persist
  to the non-replay branch exactly as analyzed above; add a fixture test asserting a second,
  same-task replay cycle does not corrupt the originally-recorded `prior_status`.

## Context Extension Recommendations

- **Topic**: sanctioned recovery paths for orchestrator runtime state.
- **Gap**: `context/standards/orchestrator-runtime-files.md` documents `pending_dispatch`'s
  writer/reader/clearer trio in detail but has no "what if none of these ever run" recovery
  section. Once `orchestrate-unwind-dispatch.sh` exists, a short cross-reference from that file's
  `pending_dispatch` subsection to the new script (and to
  `docs/architecture/orchestrate-state-machine.md`'s new subsection) would close a documentation
  gap this research pass noticed but which is outside WORK (b)'s three named targets.

## Appendix

### Search/read queries used

- Direct reads: `orchestrate-cycle-plan.sh` (full, in two passes), `orchestrate-loop-guard-init.sh`
  (full), `orchestrate-cycle-postflight.sh` (targeted region around `pending_dispatch`
  clearing), `update-task-status.sh` (`update_state_json()` and validation sections),
  `state-write.sh` (header/usage), `task-lock.sh` (`cmd_acquire`/`cmd_release`/`cmd_check`),
  `git-commit-scoped.sh` (header), `reconcile-task-status.sh` (header and
  `demote_stranded_status()`), `skill-orchestrate/SKILL.md` (Move 1-4), `context/standards/
  orchestrator-runtime-files.md` (`pending_dispatch`/`dispatch_seq_counter` sections),
  `docs/architecture/orchestrate-state-machine.md` (MAX_CYCLES section), `context/standards/
  git-safety.md` (full), `docs/reference/utility-scripts-inventory.md` (full).
- Grep queries: `pending_dispatch` (repo-wide), `record-pending|pending_dispatch|task-lock.sh|
  skill_preflight_update|dispatch_seq_counter|orchestrate-build-dispatch.sh|
  orchestrate-loop-guard-init` (within `orchestrate-cycle-plan.sh`), `unwind` (repo-wide, zero
  hits, confirming no prior art), `guard-destructive-git` (repo-wide, to locate the real
  explanation site).
- Live check: `git check-ignore -v` against this task's own `.dispatch/1.md` to confirm the
  gitignore-coverage claim empirically rather than by inspection alone.

### Key file/line references

- `agent-system/extensions/core/scripts/orchestrate-cycle-plan.sh:1799-1980` (live per-task
  dispatch loop: lock acquire, dispatch_seq mint, preflight write, build-dispatch call, replay
  check, pending_dispatch record).
- `agent-system/extensions/core/scripts/orchestrate-loop-guard-init.sh:48-236` (`--seed`,
  `--flush-seq`, `--record-pending`, `--clear-pending`).
- `agent-system/extensions/core/scripts/orchestrate-cycle-postflight.sh:305-320`
  (unconditional `--clear-pending` as postflight's first act).
- `agent-system/extensions/core/scripts/update-task-status.sh:671-791` (`update_state_json()`,
  showing why it cannot restore an arbitrary historical status).
- `agent-system/extensions/core/scripts/task-lock.sh:974-1037` (`cmd_release`, `cmd_check`).
- `agent-system/extensions/core/scripts/reconcile-task-status.sh:246-` (`demote_stranded_status`).
- `agent-system/extensions/core/context/standards/orchestrator-runtime-files.md:229-293`
  (per-run cycle-budget contract and `pending_dispatch` schema, confirming the amendment is
  already live).
- `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md:55-119` (Move 1, stop handling,
  the "never re-invoke live to inspect state" MUST NOT).
