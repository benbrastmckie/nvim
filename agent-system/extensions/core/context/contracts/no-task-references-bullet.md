# No-Task-References Bullet (Canonical Fragment)

This file is the single authoritative source for the no-task-references MUST-NOT bullet that
in-scope agents carry in their `## Critical Requirements` / MUST NOT list. It exists so the
bullet has exactly one place to edit, instead of drifting independently across ~20 agent files.

## Generated-Copy Source, Not an `@`-Import

**This fragment is a generated-copy source, read by a human or a lint script — it is NOT
`@`-imported into agent bodies at spawn time.** Research for this task (see
`specs/989_agent_contract_normalization/reports/01_agent-contract-normalization-research.md`)
proved empirically, and against the official sub-agents documentation, that `@`-references inside
an agent body do not auto-resolve when Claude Code spawns a subagent. An agent body carries a
**literal copy** of the bullet text below; `lint-agent-contracts.sh` Check C keeps every copy in
sync by comparing it against this file, not against a hardcoded string baked into the lint.

The precedent for this generated-copy-plus-lint shape is this repo's own `.claude/CLAUDE.md`,
which is generated from `agent-system/extensions/core/merge-sources/` rather than hand-maintained
— the same principle applied here at agent-body granularity instead of whole-file granularity.

## The Bullet Text

Copy this exact text (including the placeholder forms `"task N"` / `"tasks N-M"`, which contain
no digits and therefore do not trip `check-task-references.sh`'s own gate) into the target
agent's MUST NOT list, as the next sequential numbered item, held on a single physical line (never
wrapped across multiple lines) — `lint-agent-contracts.sh` Check C matches the fragment's expected
text with `grep -qF` against one line, so a correctly-worded bullet that is line-wrapped still
fails the check:

```
Reference task numbers ("task N", "tasks N-M") in files outside specs/** -- see .claude/rules/no-task-references-in-deliverables.md; reference durable anchors (filenames, section headings) instead
```

## Classification Rule: Which Agents Must Carry the Bullet

An agent MUST carry this bullet **if and only if it authors deliverable files outside
`specs/**`**. This is a decision, stated explicitly, not an omission:

**In scope** (authors deliverable files outside `specs/**`):
- Every dispatchable implementation agent (core and every extension: books, general, cslib,
  pr-review, email, epi, founder, latex, lean, nix, neovim, python, typst, web, z3, and any
  future addition) — these write source files, configuration, and other deliverables directly.
- The planning agents — `planner-agent`, `reviser-agent` — because plan
  files, while they live under `specs/**`, are frequently copied, quoted, or referenced into
  deliverables outside `specs/**` by the implementers that consume them, and because these agents
  routinely author cross-references into non-`specs/**` documentation as part of planning.
- `meta-builder-agent` — because it authors `.claude/**`-adjacent system files (via the source
  store) and task descriptions that get referenced elsewhere.

**Out of scope** (excluded by explicit decision, not by oversight):
- Research agents whose only output is a report under `specs/**/reports/` (e.g.
  `general-research-agent`, domain research agents). A research
  report is itself a `specs/**` artifact — exempt under this rule's own exemption category 1 (see
  `.claude/context/standards/task-reference-exemptions.md`'s Exemption Taxonomy) — so an agent that
  produces nothing else has no deliverable-authoring surface this bullet needs to guard.

Document-authoring agents in `filetypes/`, `present/`, and `founder/` (which generate XLSX,
DOCX, slide decks, and similar non-prose deliverables outside `specs/**`) are a genuine edge
case: they author files outside `specs/**`, but of a document kind where a task-number citation
is a much less likely failure mode than in prose/code deliverables. The classification rule above
still applies to them at face value; the specific include/exclude call for each such agent is
made and recorded where the bullet is rolled out (see
`specs/989_agent_contract_normalization/plans/01_agent-frontmatter-normalization.md` Phase 5),
not decided in this fragment.

## Placement

Insert the bullet as the **last numbered item** of the target agent's existing MUST NOT list,
matching the placement already used in the compliant agents
(`general-implementation-agent`, `cslib-implementation-agent`, `lean-implementation-agent`,
`books-implementation-agent`). Where an agent has no MUST NOT list, add one under
`## Critical Requirements` with a `**MUST NOT**:` heading rather than inventing a new section
shape. Do not renumber or reword any surrounding bullet.
