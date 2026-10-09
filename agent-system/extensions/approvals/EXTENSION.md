## Approvals Extension

Owner-labeled, agent-assisted specification approval. The `/approve` command drives a consumer
repository's `components/<component>/approve.sh` through an interactive question instead of a
terminal round-trip.

### Skill-Agent Mapping

| Skill | Agent | Purpose |
|-------|-------|---------|
| skill-approve | (direct execution, root session only) | Owner-labeled component approval |

### Commands

| Command | Usage | Description |
|---------|-------|-------------|
| `/approve` | `/approve <component> [component-flags] [--task N] [--dry-run]` | Review, classify, ask the owner, and record a component approval |

### Why This Is Never Dispatched

`AskUserQuestion` is categorically withheld from every dispatched subagent on this harness. The
`/approve` flow therefore runs entirely as a direct-execution skill in the root session — no
step is delegated to the `Agent` tool. See
`context/project/approvals/patterns/approve-interaction-design.md`.

### Owner-Labeled, Never Self-Approved

The owner, resolved from the repository's own git identity, is always recorded as the approver;
the command is recorded only as `assisted_by`. There is no fallback path that records the agent
as approver — if the prompt cannot be raised, the command stops and reports.

### Rulings

- Placement and extension-naming reason: `README.md`.
- Artifact path, no-task key, tracked-directory status:
  `context/project/approvals/standards/approval-artifact-convention.md`.
- Confidence vocabulary and summary contract:
  `context/project/approvals/standards/confidence-vocabulary.md`.
- Interaction design (option cap and step-through walk):
  `context/project/approvals/patterns/approve-interaction-design.md`.
