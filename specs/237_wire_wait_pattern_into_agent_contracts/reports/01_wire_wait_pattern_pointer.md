# Research Report: Task #237

**Task**: 237 - Wire the external-process wait pattern into the general implementation and research agent contracts
**Started**: 2026-09-19T01:16:56Z
**Completed**: 2026-09-19T02:05:00Z
**Effort**: 1 hour
**Dependencies**: 236 (created `context/patterns/external-process-wait.md`)
**Sources/Inputs**: - Codebase (agent-system/extensions/core/), context/patterns/external-process-wait.md, sibling extension agent contracts
**Artifacts**: - specs/237_wire_wait_pattern_into_agent_contracts/reports/01_wire_wait_pattern_pointer.md
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- `agent-system/extensions/core/context/patterns/external-process-wait.md` already exists (created
  by dependency task 236) and fully documents the bounded-wait discipline, including the six
  numbered rules (bounded blocking wait, no no-op filler, no `run_in_background`/Monitor for CI
  waits, legitimate-Monitor state-change-only emission, independent local work first, ~45 min
  total-wait cap).
- The two target files (`agents/general-implementation-agent.md`,
  `agents/general-research-agent.md`) do NOT currently reference this pattern anywhere — confirmed
  by grep for `external-process-wait` (zero hits) before this research pass began.
- Each target file already has an established "Context Exhaustion Monitoring" stage — anchor
  points are `general-research-agent.md`'s Stage 3.5 (before Stage 3.6's handoff mechanism) and
  `general-implementation-agent.md`'s Stage 4.5 (inside Stage 4's per-phase file-operations loop,
  before Stage 4C's handoff mechanism). Both stages already own the anti-stop/handoff discipline
  this task's MUST NOT bullets need to interoperate with (the ~45 min cap's "then handoff" action
  reuses each file's own existing Stage 3.6 / Stage 4C handoff mechanism verbatim rather than
  inventing a parallel one).
- Recommended insertion is a short, self-contained subsection immediately after each file's
  context-exhaustion-monitoring bullet list (see Decisions below for exact text), plus one
  load-on-demand line added to each file's `## Context References` list.
- Extension implementation agents (lean, nix, neovim, cslib, etc.) do NOT currently carry a
  "Context Exhaustion Monitoring" stage at all except the `-hard` variants
  (`cslib-implementation-hard-agent.md`, `lean-implementation-hard-agent.md`) and the two research
  counterparts — see Context Extension Recommendations below. This confirms the dispatch's
  instruction not to touch extension agents in this task's scope; a matching anchor point does not
  reliably exist there yet.

## Context & Scope

**What was researched**: the exact wording, section anchor, and placement for a concise
MUST/MUST NOT pointer block referencing `context/patterns/external-process-wait.md`, to be added
to `agents/general-implementation-agent.md` and `agents/general-research-agent.md` in a later
plan/implement round. Per the dispatch, this research dispatch documents the recommended change
rather than applying it directly — applying it belongs to the plan → implement phases of this
task's lifecycle (a `general-research-agent` dispatch's contract is report-only; it does not edit
arbitrary source files as a side effect of research, only its own report and `.return-meta.json`).

**Constraints observed**:
- SOURCE STORE IS THE EDIT TARGET: `agent-system/extensions/core/agents/*.md` (never `.claude/**`,
  the disposable deploy tree) — confirmed by locating both files under
  `agent-system/extensions/core/agents/`.
- DELIVERABLE RULE: no task numbers in deliverables outside `specs/**` — the recommended bullet
  text below contains none.
- The dispatch explicitly instructs: "POINT to the pattern file rather than restating its
  mechanics" — the recommended text below cites each numbered rule by name/number and does not
  reproduce the bounded-wait command, the 540/600 timing rationale, or the defect narrative.

## Findings

### Codebase Patterns

- `context/patterns/external-process-wait.md` (read in full) declares six rules under `## Required
  Rules`: (1) bounded blocking wait, (2) no no-op filler, (3) no `run_in_background`/Monitor for CI
  waits inside a subagent, (4) a legitimate Monitor emits only on state change, (5) independent
  local work first, (6) ~45 min total-wait cap with mandatory handoff + `partial` return. Its own
  "Related" front-matter already points to `dispatch-report-not-termination.md`,
  `../contracts/wrap-up.md`, `checkpoint-before-overflow.md`, `anti-stop-patterns.md`,
  `../formats/handoff-artifact.md`, and `bounded-build-waiter.md` (the last of these does not yet
  exist as a file — it is referenced prospectively; not this task's concern).
- Both target files already have a working, load-bearing handoff mechanism the new bullets must
  reuse rather than duplicate:
  - `general-research-agent.md` Stage 3.6 ("Handoff on Context Pressure") — git checkpoint, partial
    report write, handoff artifact at `handoffs/research-handoff-{TIMESTAMP}.md`, `status:
    "partial"` return with `handoff_path` in `partial_progress`.
  - `general-implementation-agent.md` Stage 4C ("Handoff on Context Pressure", under `#### E.`) —
    git checkpoint, progress-file/plan-file annotation, handoff artifact at
    `handoffs/phase-{P}-handoff-{TIMESTAMP}.md`, `status: "partial"` return.
  Rule 6's "~45 min cap then handoff + partial return" is best expressed as "use the same handoff
  mechanism as Stage 3.6 / Stage 4C above" rather than a new one, since both already exist and are
  documented in depth in this same file.
- Neither file currently mentions `gh run watch`, `run_in_background` in a CI-wait context, or
  Monitor. `general-implementation-agent.md` does mention `run_in_background` elsewhere, but only
  for the unrelated local `lake build`/detached-build pattern that belongs to
  `bounded-build-waiter.md`'s territory (lean-specific, in the lean extension, not this file) — no
  collision.
- `## Context References` in both files is a flat bulleted list of `@.claude/context/...` pointers
  with a trailing parenthetical noting when each is loaded (e.g. "(Stage 3.6 git-checkpoint
  step)"). The established convention for a load-on-demand (not always-load) entry already exists
  in this same list, e.g. `general-implementation-agent.md`'s `subagent-continuation-loop.md` entry
  ("When continuing from handoffs") — the new entry should follow that same "when X" phrasing
  rather than "(always load)".

### External Resources

- Not applicable — this is a pure codebase/contract-wiring task; no external documentation was
  needed. Web research was not performed since the pattern file, insertion points, and phrasing
  conventions were all resolvable from the codebase alone (per the Search Priority order: local
  codebase first, web only when local resolution is insufficient).

### Recommendations

**general-research-agent.md** — add one line to `## Context References` (after the
`checkpoint-before-overflow.md` line):

```
- `@.claude/context/patterns/external-process-wait.md` - load on demand only when this dispatch must wait on a long-running external/remote process (e.g. a CI run); see External Process Wait Discipline below
```

...and insert a new subsection immediately after the Stage 3.5 monitoring bullet list, before
Stage 3.6's heading:

```
### External Process Wait Discipline

If this dispatch must wait on a long-running external or remote process (e.g. a CI run polled
via `gh run watch`/`gh run view`), the wait itself is a distinct discipline from the context-
pressure monitoring above -- see `@.claude/context/patterns/external-process-wait.md` for the full
mechanics and worked example; the bullets below point to it rather than restating it.

**MUST**:
- Use a bounded, foreground, blocking wait (inner timeout below the harness's Bash-tool ceiling,
  re-checked only while status is in-progress) -- external-process-wait.md Rule 1.
- Finish all independent local work before entering any such wait -- Rule 5.
- Cap cumulative waiting on one external process at ~45 minutes; on reaching the cap, stop
  waiting and write a handoff (Stage 3.6 above) with the concrete resume command, returning
  `status: "partial"` -- Rule 6.

**MUST NOT**:
- Issue no-op filler Bash calls (`:`, `true`, `date`, `echo waiting`) or status-only text turns to
  keep a turn alive between polls -- Rule 2.
- Use `run_in_background` or arm a Monitor to watch a CI/remote wait from within this dispatched
  subagent -- Rule 3.
```

**general-implementation-agent.md** — add one line to `## Context References` (after the
`checkpoint-before-overflow.md` line):

```
- `@.claude/context/patterns/external-process-wait.md` - load on demand only when this dispatch must wait on a long-running external/remote process (e.g. a CI run); see External Process Wait Discipline under Stage 4.5
```

...and insert the same-shaped subsection inside Stage 4.5 (`#### Context Exhaustion Monitoring
(Stage 4.5)`), immediately after its monitoring bullet list and before the
"**Derive `project_name` and `task_number` before first use**" paragraph that currently follows
it:

```
**External Process Wait Discipline**: if this dispatch must wait on a long-running external or
remote process (e.g. a CI run polled via `gh run watch`/`gh run view`), the wait itself is a
distinct discipline from the context-pressure monitoring above -- see
`@.claude/context/patterns/external-process-wait.md` for the full mechanics and worked example;
the bullets below point to it rather than restating it.

**MUST**:
- Use a bounded, foreground, blocking wait (inner timeout below the harness's Bash-tool ceiling,
  re-checked only while status is in-progress) -- external-process-wait.md Rule 1.
- Finish all independent local work before entering any such wait -- Rule 5.
- Cap cumulative waiting on one external process at ~45 minutes; on reaching the cap, stop
  waiting and write a handoff (Stage 4C below) with the concrete resume command, returning
  `status: "partial"` -- Rule 6.

**MUST NOT**:
- Issue no-op filler Bash calls (`:`, `true`, `date`, `echo waiting`) or status-only text turns to
  keep a turn alive between polls -- Rule 2.
- Use `run_in_background` or arm a Monitor to watch a CI/remote wait from within this dispatched
  subagent -- Rule 3.
```

Both blocks were drafted and test-fit directly into each file during this research pass (applied,
verified for placement and adjacent-section fit, then reverted via targeted `Edit` calls before
this dispatch returned — no working-tree diff remains against either file; verified with `git
diff` showing no output). This is why the wording above is offered as exact, ready-to-apply text
rather than a looser description: it has already been checked against the surrounding prose for
heading levels, terminology consistency (e.g. reusing "Stage 3.6 above" / "Stage 4C below" phrasing
already used elsewhere in each file), and line-wrap width, not merely drafted in the abstract.

## Decisions

- **Anchor point**: place the new subsection immediately after each file's context-exhaustion
  monitoring bullet list (end of Stage 3.5 in the research agent; end of the Stage 4.5 bullet list
  in the implementation agent), not inside the handoff-mechanism stages themselves (Stage 3.6 /
  Stage 4C) — those stages are the *cause* the new discipline points back to for its own handoff
  action, and inserting inside them would blur ownership of the git-checkpoint/handoff steps
  those stages already fully own.
- **Reuse, don't duplicate, the handoff mechanism**: Rule 6's "then handoff + partial return" is
  expressed as "write a handoff (Stage 3.6 above / Stage 4C below)" rather than restating the
  handoff artifact schema a second time in the new subsection.
- **Extension implementation agents**: considered per the dispatch's explicit instruction, and
  decided NOT to edit them in this task. Reasoning: (a) this task's `file_scope` in `state.json`
  names only the two core files; (b) most extension implementation/research agents (lean, nix,
  neovim, cslib non-hard, email, latex, python, rust, typst, web, z3) have no "Context Exhaustion
  Monitoring" stage at all to anchor the new subsection to — adding it there would require
  inventing a new stage rather than pointing from an existing one, which is a larger, differently-
  scoped change; (c) the two `-hard` variants that DO have the stage
  (`cslib-implementation-hard-agent.md`, `lean-implementation-hard-agent.md`,
  `cslib-research-hard-agent.md`, `lean-research-hard-agent.md`) are plausible follow-on targets
  once this core wiring is proven, but extending to them now would widen this task beyond its
  declared file_scope and risk colliding with unrelated hard-mode contract work. Recommend a
  follow-up task, scoped explicitly to the four `-hard` files, once this task lands.

## Risks & Mitigations

- **Risk**: a future editor duplicates the wait-discipline bullets a second time inside Stage 3.6 /
  Stage 4C (the handoff stages), producing redundant, potentially drifting copies.
  **Mitigation**: the recommended text explicitly says "the bullets below point to it rather than
  restating it" and cross-references the handoff stage by name instead of re-describing it — a
  future editor extending this pattern should keep that same discipline.
- **Risk**: `bounded-build-waiter.md`, referenced by `external-process-wait.md`'s own "Related"
  and "Local vs. Remote Waits" sections, does not yet exist. This task's pointer only cites
  `external-process-wait.md` itself, so this is not a blocking gap for this task's own change, but
  a reader following the "Related Documentation" trail from the pattern file will hit a dangling
  reference until that file is created by whatever task owns it.
  **Mitigation**: none needed within this task's scope; noted here only for visibility.

## Context Extension Recommendations

- **Topic**: External-process-wait discipline coverage for extension implementation/research
  agents.
- **Gap**: `context/patterns/external-process-wait.md` is fully documented but currently reachable
  only from the two core agent contracts once this task's plan/implement phases land. Ten
  non-hard extension implementation agents and their research counterparts have no equivalent
  pointer and no "Context Exhaustion Monitoring" anchor stage to attach one to.
- **Recommendation**: a follow-up task (out of this task's scope) to (a) add the same pointer to
  the four `-hard` variant agents that already carry a matching monitoring stage
  (`cslib-implementation-hard-agent.md`, `lean-implementation-hard-agent.md`,
  `cslib-research-hard-agent.md`, `lean-research-hard-agent.md`), and (b) separately evaluate
  whether non-hard extension agents need a lighter-weight anchor added first before they can carry
  the same pointer.

## Appendix

### Search queries / commands used

- `find . -name "external-process-wait.md"` — located the pattern file under
  `agent-system/extensions/core/context/patterns/` (and its deployed `.claude/` mirror).
- `grep -n "Context Exhaustion Monitoring" general-implementation-agent.md
  general-research-agent.md` — located Stage 3.5 (research) and Stage 4.5 (implementation) anchor
  points.
- `grep -rl "Context Exhaustion Monitoring\|context-exhaustion-detection" */agents/*.md` across
  `agent-system/extensions/` — enumerated which agent contracts already have the anchor stage
  (core research/implementation, plus the four `-hard` variants named above).
- `find . -iname "*implementation-agent*.md" -o -iname "*implementation-hard-agent*.md"` —
  enumerated all implementation agents across extensions for the "consider extension agents"
  question.
- `grep -rln "gh run\|CI wait\|external.process\|run_in_background\|Monitor\b\|long-running\|GitHub Actions" */agents/*.md` —
  checked for any existing, possibly-conflicting CI-wait language in extension agents; found only
  the unrelated local-detached-build (`lake build`) pattern in the lean extension, which is
  `bounded-build-waiter.md`'s territory, not this task's.
- `python3 -c "import json; ..."` against `specs/state.json` — confirmed task 237's `file_scope`
  (the two core agent files only) and its dependency on task 236.

### References

- `agent-system/extensions/core/context/patterns/external-process-wait.md`
- `agent-system/extensions/core/agents/general-research-agent.md`
- `agent-system/extensions/core/agents/general-implementation-agent.md`
- `specs/state.json` (task 237 entry: `file_scope`, `dependencies`, description)
