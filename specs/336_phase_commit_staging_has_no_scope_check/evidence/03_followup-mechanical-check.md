# Follow-Up Specification: Mechanical Containment Chokepoint Inside `git-commit-scoped.sh`

Date: 2026-10-07

## Status

**This is a specification, not an implemented change, and not a filed task.** This task
(`phase_commit_staging_has_no_scope_check`) does not file the follow-up via `/task` — a future
reader must not assume a task number exists for this work yet. `scripts/git-commit-scoped.sh` is
deliberately outside this task's `file_scope` (per the dispatch's item 3 and the plan's
Non-Goals), so nothing here is implemented in this round.

## Mechanism

A Containment check inside `git-commit-scoped.sh` itself, reading the invoking task's own
`file_scope` directly from `specs/state.json` (looked up by the task number the caller already
supplies to a flag), independent of the cycle-scoped contention manifest
(`specs/.contention-manifest/*.json`) that the existing V5 `--task` block consults. Two viable
shapes, to be weighed by whoever picks this up:

1. **New behavior layered onto the existing `--task` flag.** When `--task <N>` is supplied, run
   both the existing V5 Overlap check (against the contention manifest) AND a new Containment
   check (against task `<N>`'s own declared `file_scope`), so one flag buys both predicates.
2. **A distinct, separately opt-in flag** (e.g. `--containment-check <N>`), so a caller can opt
   into Containment without opting into the V5 lease, or vice versa, if some future caller needs
   that separation.

This specification does not rule between the two; that is deliberately left to the follow-up's
own research stage, since it depends on whether any current or anticipated caller wants one
predicate without the other (none is known today — every one of the fifteen recipes wired in
this task's Phases 2-4 wants both).

## Why It Is the Durable Fix

A chokepoint inside the one script every one of these fifteen (now `--task`-plus-self-check)
recipes already calls cannot be forgotten by a sixteenth agent definition someone adds next —
unlike the prose self-check landed in this task, which depends on every future agent-definition
author remembering to copy or point at it. The prose step is explicitly interim (stated in the
canonical block itself); this mechanical chokepoint is the stated durable replacement.

## Required Fail-Open Posture

A missing, malformed, or unreadable `file_scope` (most `specs/state.json` rows carry no
`file_scope` at all today), or any internal error while evaluating the Containment predicate,
MUST proceed exactly as today — a scope guard must never be the sole reason a commit cannot
happen. This mirrors the existing V5 block's own fail-open language verbatim (`git-commit-
scoped.sh`'s header: "FAILS OPEN unconditionally... a concurrency guard must never be the reason
an agent cannot commit at all") and the drop-and-warn (never refuse-the-whole-commit) posture
this task's own prose self-check already adopted in `general-implementation-agent.md`'s
`#### Phase-Commit Containment Self-Check` block.

## Exit-Code Requirement

A new exit code, OR a deliberately and explicitly reused one, distinct from the existing V5
contended-path refusal (exit 3) — Containment is a different predicate from lease contention
(one concrete path tested against one task's own declared scope, vs. two-or-more tasks declaring
the same path), and the two failure modes should remain distinguishable to a caller that
branches on exit codes, even though today's callers mostly do not (see `git-commit-scoped.sh`'s
own V6 commentary on this residual). Whether Containment should REFUSE (an exit code) or only
DROP-AND-WARN (exit 0, warning on stderr) is itself an open design question for the follow-up:
this task's own prose self-check chose drop-and-warn (per the "under-stage, never over-stage"
fail-safe direction in `context/standards/git-staging-scope.md`), and the mechanical chokepoint
should very likely inherit that same posture rather than introduce a new refusal mode — but that
choice belongs to the follow-up's own research, not asserted here as settled.

## Coordination Constraint

This follow-up MUST be coordinated with the task that owns `git-commit-scoped.sh`'s exit-code
contract — task 304 (`out_of_repository_pathspec_aborts_whole_commit`), which names itself in
`specs/TODO.md` as owning that script's drop-pass classification and its exit-code table. Whoever
files this follow-up must read task 304's description before proposing any code change to
`git-commit-scoped.sh`, to avoid a second, independently-designed modification to the same
drop-pass/exit-code surface landing out of sequence with task 304's own work.

## Rider: `git-staging-scope.md`'s "Phase Commit (mid-dispatch)" Subsection

The follow-up should also author a new "Phase Commit (mid-dispatch)" subsection in
`context/standards/git-staging-scope.md`, documenting the asymmetry this task's own research and
implementation surfaced: a phase commit fires mid-dispatch, inside an already-running agent, with
no postflight in scope and no guarantee the cycle-scoped contention manifest exists or is
current — so any guard for this surface must be sited either in the recipe itself (what this
task landed, as an interim measure) or inside `git-commit-scoped.sh` (what this follow-up
proposes). This subsection rides along with the follow-up's own implementation; it is not
authored in this task, per the plan's Non-Goals (amending `context/standards/*.md` is not in
this task's `file_scope`).

## Evidence This Follow-Up Is Needed

See `evidence/01_pre-fix-regression.md` for the live, dated proof that `--task` supplied does
NOT catch the observed undeclared-path case, and `evidence/02_uniformity-audit.md` for
confirmation that the interim prose self-check this task landed is the only mechanism currently
protecting the fifteen recipes against a repeat of that case — a mechanism that depends on every
future agent-definition author remembering to invoke it, which is exactly the residual risk this
follow-up exists to close.
