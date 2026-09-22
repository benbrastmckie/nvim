# Research Report

**Task**: 243 - Reconcile research handoff writer contract
**Started**: 2026-09-22T08:42:00Z
**Completed**: 2026-09-22T09:15:00Z
**Effort**: small-medium (doc/contract text fix across 22 files; no script changes required)
**Dependencies**: None
**Sources/Inputs**: Codebase (agent-system/extensions/core and 15 extension directories), grep/read of executable postflight logic
**Artifacts**: - specs/243_reconcile_research_handoff_writer_contract/reports/01_reconcile-handoff-writer-contract.md
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- The runtime source of truth — `orchestrate-cycle-postflight.sh:539` — hardcodes the log line
  `"expected outcome for this phase's writer (base-mode research/plan/implement never write
  one)"`. This is the actual consumer's own stated expectation: **research (and plan and
  implement) dispatches never write `.orchestrator-handoff.json`.** `docs/architecture/handoff-schema.md`'s
  "Handoff Writers — the settled decision" table agrees with this, in detail, with a documented
  design rationale (deleted agent-name allowlist, WORK(d) double-miss analysis).
- `agents/general-research-agent.md`'s own `.orchestrator-handoff.json` (orchestrator-mode
  dispatches) section directly contradicts this: it unconditionally instructs "this agent MUST
  write `.orchestrator-handoff.json` before returning" whenever `orchestrator_mode: true`. Worse,
  its own Stage 3.6 "Scoping Decision" paragraph cross-references that section as "this agent's
  own handoff-writing obligation" — the exact passage `handoff-schema.md` misquotes as the
  citation for "Research is explicitly prohibited from writing one."
- This is not a one-off: **every one of the 21 `*research-agent.md` / `*research-hard-agent.md`
  files in the repo** (core plus 15 extensions) carries the identical, verbatim-copied "MUST
  write" section. All 21 conflict with the settled-decision table and with the postflight log
  line the same way.
- Recommended fix: delete/replace the `.orchestrator-handoff.json` (orchestrator-mode dispatches)
  section in all 21 research-agent files with an explicit non-writing statement, and correct
  `general-research-agent.md`'s Stage 3.6 cross-reference sentence to stop claiming an
  "obligation." No change is needed in `docs/architecture/handoff-schema.md` (already correct) or
  `scripts/orchestrate-build-dispatch.sh` (its `## Handoff` block is phase-agnostic boilerplate —
  it supplies `handoff_path`/`task_dir` for every dispatch without asserting a writing
  obligation, so it does not need to change either).

## Context & Scope

Evidence source: an observed live `/orchestrate` batch where 7 of 8 research dispatches wrote
`.orchestrator-handoff.json` and 1 refused, citing the schema doc — nondeterministic behavior
caused by a documentation conflict between `general-research-agent.md` and
`handoff-schema.md`. Task scope: reconcile the three named artifacts
(`general-research-agent.md`, `handoff-schema.md`, dispatch template text) plus sweep other
research-agent contracts for the same conflict. Source-store edit target for any follow-on
implementation is `agent-system/extensions/core/` (core) and the relevant extension
`agents/` directories (`.claude/**` is a disposable deploy artifact, never a hand-edit target).

## Findings

### The conflict, precisely

`agent-system/extensions/core/agents/general-research-agent.md` (Stage 3.6 "Scoping Decision",
~line 224, and the section immediately below it, ~lines 228-241):

> "See the `.orchestrator-handoff.json` (orchestrator-mode dispatches) subsection below for
> this agent's own handoff-writing obligation, which is a separate file, a separate consumer,
> and a separate trigger from the partial-report handoff artifact above."

> "### `.orchestrator-handoff.json` (orchestrator-mode dispatches)
> On every dispatch whose delegation context carries `orchestrator_mode: true`, this agent MUST
> write `.orchestrator-handoff.json` before returning — on success and on a `partial` or
> `blocked` outcome alike."

`agent-system/extensions/core/docs/architecture/handoff-schema.md` ("Handoff Writers — the
settled decision, in one place", ~lines 390-406):

> "`.orchestrator-handoff.json` is formally **hard-mode-implement-only**. Base-mode
> research/plan/implement return via `.return-meta.json` ... research agents never write a
> handoff at all, in any mode. This is a decided contract, not a default that happened to
> emerge."
>
> Handoff Writers table, row for base-mode `general-research-agent`/`planner-agent`/
> `general-implementation-agent`: "Never writes a handoff, by design ... Research is explicitly
> prohibited from writing one (Stage 3.6 'Scoping Decision' in the research agents)."

The schema doc's citation is a misreading of the very passage it points to: Stage 3.6 in
`general-research-agent.md` does not prohibit handoff-writing — it affirms an obligation via a
forward cross-reference to the section that mandates it. The two files disagree about the rule
itself, and one of them (the schema doc) also misquotes the other as agreeing with it.

### The consumer's own expectation settles the question

`agent-system/extensions/core/scripts/orchestrate-cycle-postflight.sh:539` (executable, not
documentation) reads:

```
echo "${notice_prefix} RECOVERY: no handoff written for this dispatch — expected outcome for
this phase's writer (base-mode research/plan/implement never write one). .return-meta.json
(fresh, within this dispatch window) reports status=${dispatch_status}; recovering the dispatch
outcome from it." >&2
```

This is the actual postflight consumer stating its own design assumption in a log line: for
base-mode research/plan/implement dispatches, an absent `.orchestrator-handoff.json` is the
*expected*, non-defective case, recovered entirely via `.return-meta.json`. `--handoff-expected`
defaults to `true` for every dispatch (`orchestrate-cycle-postflight.sh:180`), but the
double-miss branch (`WORK (d)`, absent-handoff-AND-failed-`.return-meta.json`-recovery) is what
actually records a defect — a present handoff from research is never required to avoid that
branch, and its absence alone is explicitly non-fatal. This confirms `handoff-schema.md`'s rule
is the one the runtime system is built around, and `general-research-agent.md`'s "MUST write"
instruction is the defect, not the other way around.

`agent-system/extensions/core/scripts/orchestrate-build-dispatch.sh`'s `## Handoff` block
(~lines 461-465) is phase-agnostic: it prints `handoff_path`/`task_dir` unconditionally for
every dispatch (research, plan, implement alike), purely as connectivity information, without
asserting any writing obligation. It does not need to change under either rule and is not a
source of the conflict — noted for completeness since the dispatch explicitly named it in scope.

### Sweep: every research-agent contract carries the same defect

All 21 `*-research-agent.md` / `*-research-hard-agent.md` files in the repository (core plus
every loaded extension) carry a verbatim copy of the same unconditional "MUST write
`.orchestrator-handoff.json`" section:

```
./core/agents/general-research-agent.md
./cslib/agents/cslib-research-agent.md
./cslib/agents/cslib-research-hard-agent.md
./cslib/agents/pr-review-research-agent.md
./epidemiology/agents/epi-research-agent.md
./formal/agents/formal-research-agent.md
./formal/agents/logic-research-agent.md
./formal/agents/math-research-agent.md
./formal/agents/physics-research-agent.md
./founder/agents/deck-research-agent.md
./latex/agents/latex-research-agent.md
./lean/agents/lean-research-agent.md
./lean/agents/lean-research-hard-agent.md
./nix/agents/nix-research-agent.md
./nvim/agents/neovim-research-agent.md
./present/agents/slides-research-agent.md
./python/agents/python-research-agent.md
./rust/agents/rust-research-agent.md
./typst/agents/typst-research-agent.md
./web/agents/web-research-agent.md
./z3/agents/z3-research-agent.md
```

(paths relative to `agent-system/extensions/`). Every file matched; none were missing the
section, indicating it was propagated from a shared template at some point after
`handoff-schema.md`'s "settled decision" language was written (or the schema doc's restriction
was decided later and never swept back into the per-agent contracts). Either way, the fix is
identical across all 21 files: replace the unconditional "MUST write" section with an explicit
non-writing statement, and (for `general-research-agent.md` specifically) correct the Stage 3.6
cross-reference sentence that currently claims "this agent's own handoff-writing obligation."
The sentence-level cross-reference is unique to `general-research-agent.md` (not replicated
verbatim in the 20 extension copies, which mostly lack an equivalent Stage-3.6-style
self-citation), so extension copies need only the section itself corrected, not a second
sentence.

### Adjacent, out-of-scope finding: planner-agent.md and general-implementation-agent.md

`agent-system/extensions/core/agents/planner-agent.md` (~line 465) and
`agent-system/extensions/core/agents/general-implementation-agent.md` (~line 712) carry the
identical unconditional "MUST write" section, which likewise contradicts the same Handoff
Writers table row ("Base-mode `general-research-agent`, `planner-agent`,
`general-implementation-agent` ... Never writes a handoff, by design"). This is the same class
of defect but is **not research-agent territory** and is explicitly out of this dispatch's
scope: `general-implementation-agent.md` is already claimed in this same `/orchestrate` cycle by
a concurrent sibling task's `file_scope`. Flagged here for a follow-up task; not touched by this
research pass or its recommended fix.

## Decisions

- **The one rule**: base-mode research agents (core and every extension, standard or hard mode
  alike) never write `.orchestrator-handoff.json`, in any mode, orchestrator or otherwise. This
  is the rule `orchestrate-cycle-postflight.sh` is built around and the rule
  `docs/architecture/handoff-schema.md` already documents; it requires zero script changes.
- **Fix direction**: correct the 21 research-agent contract files (listed above) to match — not
  `handoff-schema.md`, which is already correct and should not change.
- The planner-agent.md / general-implementation-agent.md instance of the same defect is noted
  but left untouched (different territory; `general-implementation-agent.md` is claimed by a
  concurrent sibling task this cycle).

## Risks & Mitigations

- **Risk**: a future extension author scaffolds a new research agent from an existing (still
  uncorrected) research-agent file and reintroduces the "MUST write" section. **Mitigation**:
  fixing all 21 known copies removes every current template source; a plan-phase acceptance
  check (grep across all 21 files plus any future `*research*agent.md`) should be part of the
  implementation plan's verification step, matching the dispatch's stated acceptance criterion
  ("a grep for the handoff-writer rule across the three named files yields one consistent
  statement" — the swept sitewide grep is the practical way to confirm that consistency holds
  everywhere, not just the three originally named files).
- **Risk**: touching 21 files raises the chance of a stray edit outside declared territory.
  **Mitigation**: the implementation phase should scope `file_scope` explicitly to the 21 listed
  research-agent paths plus `docs/architecture/handoff-schema.md` (read-only verification, no
  edit expected) and avoid any edit to `planner-agent.md` / `general-implementation-agent.md`.

## Context Extension Recommendations

- **Topic**: cross-agent contract drift after a "settled decision" doc update.
- **Gap**: no existing context file documents the propagation risk when a decision recorded in
  `docs/architecture/handoff-schema.md` needs to fan out to every per-agent contract file that
  was originally templated from a common source (as observed here: 21 research-agent copies plus
  2 more in planner/implementation).
- **Recommendation**: consider adding a note to `context/contracts/wrap-up.md` or a new
  `context/patterns/` file describing this template-fan-out hazard and recommending a grep-based
  consistency check whenever `docs/architecture/handoff-schema.md`'s Handoff Writers table is
  next revised.

## Appendix

- Search queries / commands used:
  - `grep -rn "orchestrator-handoff.json.*orchestrator-mode dispatches" agent-system/extensions`
  - `grep -rln "\`.orchestrator-handoff.json\`" agent-system/extensions --include="*.md"`
  - `find agent-system/extensions -iname "*research-agent.md" -o -iname "*research-hard-agent.md"`
  - `grep -n "handoff_expected\|phase.*research" agent-system/extensions/core/scripts/orchestrate-cycle-postflight.sh`
  - `grep -n "handoff" agent-system/extensions/core/scripts/orchestrate-build-dispatch.sh`
- Files read in full or in relevant part: `agent-system/extensions/core/agents/general-research-agent.md`,
  `agent-system/extensions/core/docs/architecture/handoff-schema.md`,
  `agent-system/extensions/core/scripts/orchestrate-cycle-postflight.sh`,
  `agent-system/extensions/core/scripts/orchestrate-build-dispatch.sh`, plus spot checks of
  `lean/agents/lean-research-agent.md`, `nix/agents/nix-research-agent.md`,
  `agent-system/extensions/core/agents/planner-agent.md`,
  `agent-system/extensions/core/agents/general-implementation-agent.md`.
