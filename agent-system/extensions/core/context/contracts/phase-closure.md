# Phase-Closure Contract

This contract governs how a single implementation dispatch sequences its own work across the
phases of a plan. It exists because a dispatch that opens several phases at once strands the
earlier ones at `[PARTIAL]`, which is costly (see "Why `[PARTIAL]` is costly" below) and, left
unaddressed, blocks a task from ever reaching `COMPLETED`.

## Loaded via explicit reference in BOTH modes

This is the first non-hard-exclusive occupant of `context/contracts/`. Every other file
currently in this directory is loaded only by `*-hard` agents and skills — a strong precedent
that could mislead a future reader into assuming directory placement alone implies
hard-mode-only applicability. It does not. Placement in `context/contracts/` is a naming and
genre convention; the actual load-bearing mechanism, in this codebase, is an explicit
`@`-reference bullet in the consuming agent's or skill's `## Context References` section. This
contract carries that bullet in `agents/general-implementation-agent.md` (standard mode, and —
since core's standalone hard-mode implementation agent was deleted and merged into
`skill-orchestrate`'s H1 per-phase dispatch branch — the sole surviving core implement-dispatch
target for hard mode too). It is additionally referenced from every non-core extension
implementer agent that runs a plan-phase loop, and from at least one extension skill file
maintaining its own contract-bullet list (`cslib/skills/skill-cslib-implementation-hard/SKILL.md`),
following the same explicit-bullet mechanism rather than a separate injection path. See
`context/architecture/context-layers.md`'s "Contracts directory: convention vs. load path"
subsection for the full finding.

**Correction (re-verified by grep, this task)**: an earlier version of this section additionally
claimed `skills/skill-orchestrate/SKILL.md` carries a discoverability reference to this file. A
repo-wide `grep -rl "phase-closure.md"` found no such reference in that file — the claim was
stale and has been removed rather than repeated. `skill-orchestrate/SKILL.md` delegates entirely
to the dispatched agent's own contract, with no separate pointer of its own.

## Close-before-open

A dispatch closes one phase **entirely** — all of its steps done, its own verification run, and
its heading marker advanced past `[IN PROGRESS]` to `[COMPLETED]` or
`[COMPLETED WITH EXCLUSIONS]` — before opening any other phase. "Opening" a phase means beginning
any of its steps or advancing its heading to `[IN PROGRESS]`. A dispatch must never have two
phases simultaneously sitting at `[IN PROGRESS]` or `[PARTIAL]` as a result of its own actions.

See `context/standards/status-markers.md` for the full phase-heading marker vocabulary
(`[NOT STARTED]`, `[IN PROGRESS]`, `[COMPLETED]`, `[COMPLETED WITH EXCLUSIONS]`, `[PARTIAL]`,
`[BLOCKED]`) and the five-condition admission test for `[COMPLETED WITH EXCLUSIONS]`. Both of
those terminal outcomes count as "closed" for the purposes of this contract; only `[PARTIAL]` and
`[IN PROGRESS]` are open.

## Cheapest-closure-first ordering

Among the phases eligible to open next, prefer the one that can be **closed** soonest — not the
one that is numerically first in the plan, and not the one that looks most important. "Eligible"
already accounts for dependencies: a phase whose `**Depends on**:` prerequisites are unmet is not
eligible to open regardless of how cheap it would be to close, so this clause reorders only
within what the dependency graph already allows. When several phases are equally eligible, prefer
the one with the smallest remaining work — fewer steps, a lower `**Verification Tier**`, or a
shorter stated `**Timing**` estimate.

## Stop-at-a-closed-phase-boundary

When a dispatch judges that it cannot finish the next eligible phase within its remaining budget
(context, time, or tool-call budget), it **stops at the current closed phase boundary and hands
off**, rather than opening that phase and leaving it `[PARTIAL]`.

This clause is **not redundant with** "work depth-first" and must not be summarized away or
merged into the close-before-open clause above. Close-before-open tells an agent what *order* to
work in once it has decided to open a phase; this clause tells it *whether to open a phase at
all* — specifically, to refuse to start a phase it cannot finish, even though nothing in the
close-before-open clause forbids starting it. An agent that always works depth-first but never
stops will still open its last phase mid-dispatch and leave it `[PARTIAL]` exactly as often as one
that ignores ordering entirely; the two failure modes are independent, and closing one does not
close the other.

## Why `[PARTIAL]` is costly

A task cannot be marked `COMPLETED` while any phase heading is `[PARTIAL]`. Breadth-first work —
opening phase 2 before phase 1 is closed, then phase 3 before phase 2 is closed — actively
prevents completion even when a large fraction of total work has been done, because every opened
phase is a `[PARTIAL]` liability until it closes. One phase closed cleanly, with a clean handoff
for the rest, strictly dominates four phases opened with only one of them closed: the first state
has zero `[PARTIAL]` phases and a clear resume point; the second has three.

## Scope limitation

This contract governs a single dispatch's own phase-opening sequencing only: it forbids ONE AGENT
from opening several phases at once; it does NOT forbid the orchestrator from dispatching
independent phases to different agents in the same wave.

This is not in tension with `context/formats/plan-format.md`'s Dependency Analysis wave table
("Phases within the same wave can execute in parallel") or with `context/contracts/territory.md`
(which governs file ownership and commit coordination when multiple agents are dispatched
simultaneously to different phases of the same plan). The wave table and the territory contract
both describe what the *orchestrator* may hand to *different agents* concurrently. This contract
describes how *one agent* sequences its *own* work within *one* dispatch. An agent executing a
plan under this contract still closes one phase entirely before opening the next, even where the
plan's wave table shows two phases in the same wave — because that agent, within its own
dispatch, is doing single-agent sequencing regardless of what the wave table permits at the
orchestrator level.

## Mode applicability

Both observed failure shapes are in scope:

- **Standard mode** (`agents/general-implementation-agent.md`, Stage 4 "Execute File Operations
  Loop"): a single dispatch iterates `For each phase starting from resume point:` with no
  cost-ordering and no stop condition other than "all phases complete." Under this contract, that
  loop still closes each phase before advancing to the next iteration, and terminates at a closed
  boundary rather than starting the next iteration when the remaining budget cannot finish it.
- **Hard mode** (`skills/skill-orchestrate/SKILL.md`'s Hard branch: Per-Phase Dispatch (H1),
  formerly the standalone hard-mode implementer skill's Stage 3b "Single-Phase Dispatch Context
  (H1)" before that file was merged in and deleted): the phase selector is a top-to-bottom
  heading scan —
  `grep -E '^### Phase ... \[(NOT STARTED|PARTIAL|IN PROGRESS)\]' | head -1` — that treats
  `PARTIAL` and `NOT STARTED` as equal-priority, position-ordered candidates. This is precisely
  what permits opening a new phase while an earlier-opened one sits `PARTIAL`. **Behavioral
  override, stated plainly: an already-open `PARTIAL` or `IN PROGRESS` phase is closed before any
  `NOT STARTED` phase is opened, regardless of heading position.** This contract does not modify
  the selector regex itself — the override is a behavioral constraint layered on top of the
  existing selection mechanism, not a rewrite of it.

## No fan-out to phase sub-agents

A dispatched implementation agent MUST NOT delegate plan-phase execution to sub-agents. This
resolves, as a flat prohibition, the question of whether a single dispatch may fan out to
per-phase children: it may not.

**Reasoning.** The dispatched agent alone owns its `.return-meta.json` and, when running under
`orchestrator_mode: true`, its `.orchestrator-handoff.json`. A child sub-agent cannot write the
parent's terminal status on the parent's behalf — only the parent dispatch itself can. A parent
that returns while its children are still running is precisely the observed failure mode: twice
in one dispatch batch, a dispatched implementation agent fanned out to per-phase sub-agents,
returned before they finished, and left `.return-meta.json` at `status: "in_progress"` — which
`context/formats/return-metadata-file.md` documents as early-metadata-only and never a legal
terminal dispatch outcome. Both occurrences cost a full recovery cycle even though real work (a
majority of the plan's phases, in each case) had already landed.

**Carve-out.** Read-only search/exploration fan-out is permitted — spawning a helper to search
the codebase, run a read-only grep sweep, or gather context cannot itself leave plan-phase work
uncommitted, so it does not create the hazard this section closes.

**Terminal-status corollary.** The dispatched agent writes its own terminal `.return-meta.json`
**before returning**, covering all work performed under it during this dispatch — never partway,
and never assuming a status update will happen later. `in_progress` is early-metadata-only (set
at dispatch start, per Stage 0 of `agents/general-implementation-agent.md`) and is never a legal
terminal dispatch outcome; see `context/formats/return-metadata-file.md` for the full status
vocabulary. This corollary retires the per-dispatch prompt text that was used as the incident
workaround (explicitly instructing a resumed dispatch to "write the handoff FIRST") — that
wording is known to work, and the point of this section is that it now lives in the contract
every in-scope agent already loads, rather than needing to be re-typed into dispatch prompts.

## Marker/commit synchrony is bidirectional

A phase-heading marker and the commit(s) implementing that phase must never be allowed to
diverge silently. Both directions are requirements, not just one:

- **Promotion-on-commit (the under-claim direction).** A phase's marker promotion — its heading
  advancing to `[COMPLETED]` or `[COMPLETED WITH EXCLUSIONS]` — is committed together with that
  phase's final work, never deferred to a later commit or to the end of the dispatch.
  `agents/general-implementation-agent.md`'s existing scoped-commit staging set already includes
  `{plan_path}` alongside the task directory, so satisfying this is a sequencing requirement
  (commit the marker promotion in the SAME commit as the phase's landing work), not a new
  staging requirement. Failing this direction is what let sub-agent-committed phases sit at
  `[NOT STARTED]` against landed commits in the incident that motivated this section — a resume
  driven by markers alone would have redone already-completed work.
- **No-promotion-without-evidence (the over-claim direction).** A marker is promoted only after
  that phase's own declared verification has been **run in this dispatch and observed green**.
  An inherited `[COMPLETED]` or `[IN PROGRESS]` marker on a resumed dispatch is re-verified by
  actually running the phase's verification, never trusted on sight just because the heading
  already says so. Failing this direction produced the inverse incident: a plan carrying five of
  seven phases marked `[COMPLETED]` while its sole declared `file_scope` target was unmodified
  against `HEAD` — a resume driven by those markers would have skipped real work that had never
  landed.

**Both directions are needed independently.** The over-claim case above was caught only because
the orchestrator cross-checked the marker count against the working tree; a fix that merely
tightened promotion-on-commit (the first bullet) would not have caught it, since that direction
says nothing about verifying an INHERITED marker. Treating this as one problem with one fix would
have left the other direction's failure mode open.

## Record issues and wins during the phase, not reconstructed at the end

Call `scripts/issue-record.sh` AS SOON AS an event worth recording happens during this phase —
a deviation from plan, a blocker (whether or how it cleared), a workaround applied in place of
the planned approach, a gate collision, or an unusually smooth or time-saving result
(`kind: "win"`, recorded on equal footing with an issue). Do not wait to reconstruct this at the
final `.return-meta.json` write or handoff — that end-of-dispatch reconstruction is exactly what
produces the free prose this log exists to replace. See `context/formats/issue-log.md` for the
full field contract, the severity scale, and the 15-class seed enum; the dispatch file's own
"## Issue Log" section carries the exact resolved `--task-dir` and non-fatal call form for this
dispatch.

**Non-fatal, always.** A recording failure must never fail this dispatch or block a phase
closure — invoke the writer in its documented non-fatal form
(`... >/dev/null 2>&1 || echo "Note: issue recording failed (non-fatal)" >&2`) exactly as every
other call site in this codebase does.
