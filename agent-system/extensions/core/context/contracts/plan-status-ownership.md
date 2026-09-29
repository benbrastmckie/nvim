# Plan-Level Status Ownership (Canonical Fragment)

This file is the single authoritative source for the plan-level-Status ownership MUST-NOT bullet
that in-scope implementation agents carry in their `## Critical Requirements` / MUST NOT list. It
exists so the bullet has exactly one place to edit, instead of drifting independently across 14
agent files.

## Generated-Copy Source, Not an `@`-Import

**This fragment is a generated-copy source, read by a human or a lint script — it is NOT
`@`-imported into agent bodies at spawn time.** An agent body carries a **literal copy** of the
bullet text below; `lint-agent-contracts.sh` Check G keeps every copy in sync by comparing it
against this file at runtime, not against a hardcoded string baked into the lint. This mirrors
the precedent established by `context/contracts/no-task-references-bullet.md` and its own Check
C.

## Why This Fragment Exists

`plan-format.md`'s "Plan-level vs. phase-level markers" subsection is the authority for the
two-vocabulary / two-owner distinction (that file is not edited by this fragment or by the
agents that carry this bullet — it is pointed at, not restated):

- The plan-level metadata field `- **Status**:` (vocabulary: `{NOT STARTED, IMPLEMENTING,
  PARTIAL, BLOCKED, ABANDONED, COMPLETED}`) is owned by `update-plan-status.sh`, invoked from
  `update-task-status.sh` postflight. It MUST NOT be hand-edited by an implementation agent.
- The phase-heading marker `### Phase N: {name} [MARKER]` (vocabulary: `{NOT STARTED, IN
  PROGRESS, COMPLETED, COMPLETED WITH EXCLUSIONS, PARTIAL, BLOCKED}`) and `- [ ]` checklist items
  ARE the implementation agent's own write authority, and every in-scope agent's contract already
  instructs editing them at phase boundaries.

An agent told, repeatedly and emphatically, to "update plan file phase markers" and to never
"leave plan file with stale status markers" generalizes from the phase-heading vocabulary to the
plan-level metadata field — which is exactly the failure mode this fragment closes. Hand-typing
the plan-level field loses the brackets (`- **Status**: COMPLETED` instead of
`- **Status**: [COMPLETED]`), producing a line `update-plan-status.sh` can neither parse nor
re-stamp.

## The Bullet Text

Copy this exact text (contains no digits, so it does not trip `check-task-references.sh`'s own
gate) into the target agent's MUST NOT list, as the next sequential numbered item:

```
Hand-edit the plan METADATA `- **Status**:` field -- it is owned by update-plan-status.sh (invoked from update-task-status.sh postflight), never by this agent; this agent's plan-file write authority is limited to `### Phase N: ... [MARKER]` headings and `- [ ]` checklist items
```

## Clarifying Sentence (adjacent placement)

Where an agent's contract already carries the sentence "Phase status lives ONLY in the heading.
Do NOT add or edit a separate `**Status**:` line per phase." (present at both the Mark-Phase-In-
Progress and Mark-Phase-Complete steps in several agents), append this sentence immediately after
it, so the boundary sits next to the instruction that produces the generalization, not only in
the MUST NOT list at the end of the file:

```
This is the per-phase case; the plan's own top-level metadata `- **Status**:` field is a separate, differently-owned field -- see `context/contracts/plan-status-ownership.md`.
```

Where the anchor sentence is absent, place this clarifying sentence next to the agent's own
`update-phase-status.sh` / phase-heading Edit instruction instead.

## Classification Rule: Which Agents Must Carry the Bullet

An agent MUST carry this bullet **if and only if its contract instructs editing a
`### Phase N: ... [MARKER]` heading** (directly via the Edit tool with an `old_string`/`new_string`
pair naming the bracketed marker, or by calling `update-phase-status.sh`) **during plan
execution** — i.e. it is an implementation agent responsible for transitioning phase-heading
markers as work proceeds.

This deliberately excludes an agent that merely *authors* the initial `### Phase N: {Name} [NOT
STARTED]` heading once, as a template, while creating a new plan (`planner-agent.md`,
`founder-plan-agent.md`, `present/agents/slide-planner-agent.md`) — that is plan-authoring write
authority over a brand-new file, not the transition-editing authority this bullet bounds. Those
agents are out of scope for this bullet.

## In-Scope Enumeration (14 files)

Derived by a predicate sweep over every `agent-system/extensions/*/agents/*.md` file — never a
filename glob — applying the classification rule above. Recorded here as Check C's list is
recorded, with a note that a future agent addition must be classified by the rule, not inferred
by copying this list forward unexamined:

```
core/agents/general-implementation-agent.md
cslib/agents/cslib-implementation-agent.md
cslib/agents/cslib-implementation-hard-agent.md
founder/agents/founder-implement-agent.md
latex/agents/latex-implementation-agent.md
lean/agents/lean-implementation-agent.md
lean/agents/lean-implementation-hard-agent.md
nix/agents/nix-implementation-agent.md
nvim/agents/neovim-implementation-agent.md
python/agents/python-implementation-agent.md
rust/agents/rust-implementation-agent.md
typst/agents/typst-implementation-agent.md
web/agents/web-implementation-agent.md
z3/agents/z3-implementation-agent.md
```

**Sweep result diverges from this task's own planning-time hypothesis of 13 files**:
`founder/agents/founder-implement-agent.md` was recorded during planning as "correctly out of
scope (no phase-heading write authority to bound)". Re-running the sweep during implementation
found this to be false: the file instructs `Mark phase [IN PROGRESS]` / `Mark phase [COMPLETED]`
via the Edit tool against `### Phase N: {Phase Name} [MARKER]` headings, identically to the other
13 confirmed agents (e.g. its Phase 1 step: `old_string: "### Phase 1: {Phase Name} [IN
PROGRESS]"` / `new_string: "### Phase 1: {Phase Name} [COMPLETED]"`). The sweep wins over the
hypothesis; the file is included.

Confirmed correctly OUT of scope by the same sweep (no phase-heading marker edit instructions
anywhere in the file):
`epidemiology/agents/epi-implement-agent.md`,
`cslib/agents/pr-review-implementation-agent.md`,
`email/agents/email-implementation-agent.md`.

## Placement

Insert the bullet as the next sequential numbered item of the target agent's existing
`## Critical Requirements` / MUST NOT list. Do not renumber or reword any surrounding bullet.
Where an agent has no MUST NOT list, add one under `## Critical Requirements` rather than
inventing a new section shape.
