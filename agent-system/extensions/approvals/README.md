# Approvals Extension

Owner-labeled, agent-assisted specification approval: `/approve` drives a consumer repository's
`components/<component>/approve.sh` through an interactive question in the root session instead
of a terminal round-trip.

## Overview

| Task Type | Agent | Purpose |
|-----------|-------|---------|
| `-` (routing-exempt) | (direct execution) | Owner-labeled component approval |

| Command | Purpose |
|---------|---------|
| `/approve` | Review, classify, ask the owner, and record a component approval |

## Installation

Loaded via the extension picker. Once loaded, `/approve` becomes available. This extension is
useful only in a repository that has a `components/<name>/approve.sh` to drive (today, the
Logos/Verification repository's `framed_channel` component); it declares no `task_type` and no
`routing_agents` block.

## Placement Ruling

This is a new extension rather than an addition to `books` or `core`. The reason is recorded
here, not assumed:

- **Not `books`**: `books`' own charter (its `EXTENSION.md` and `README.md`) scopes that
  extension to the `book.toml`/`book.cert.json` metadata layer. Its certificate boundary is that
  layer's boundary and explicitly excludes originating or verifying new Lean content. The
  component-level release certificate `/approve` drives
  (`components/<name>/certificate/{digests,axioms,ladder,countermodels,recheck}.txt` plus
  `approvals.yaml`, Comparator-based) is a different, unrelated certificate concept that predates
  and sits outside `books`. Loading `approvals` alongside `books` does not collide: the two own
  disjoint artifacts.
- **Not `core`**: `core` loads in every deployment, including repositories with no
  `components/` directory at all. A command meaningful only in a repository shaped like the
  verification consumer does not belong in a universally-loaded extension.
- **Name**: `approvals`, after the mechanism's own vocabulary (`approvals.yaml`, `approve.sh`,
  `check-approvals.sh`) — not `certify`, which `books` already owns for a different artifact.
- **Shape precedent**: the nearest working model for an opt-in, narrowly-scoped, no-task-type
  utility extension with a command but no routing is `z3`/`formal`'s minimal shape, and for a
  no-task-routed command living beside `research`/`plan`/`implement`, `core`'s own `/tag`,
  `/please`, `/merge` (each listed in `manifest.json` with no `routing_agents` entry).

## Why `/approve` Is Never Dispatched

`AskUserQuestion` is categorically withheld from every `Agent`-tool dispatch of a named
`subagent_type` on this harness (settled by the in-repository investigation
`askuserquestion_unreachable_in_subagents`). `skill-approve` therefore declares
`AskUserQuestion` directly in its own `allowed-tools` and never delegates any part of the
prompting flow to the `Agent` tool — the same rehome pattern `skill-meta` already uses (a
pre-delegation interview stage that calls `AskUserQuestion` before any `Agent` dispatch, here
with no delegation stage following it at all).

## Owner-Labeled, Never Self-Approved

The owner, resolved from the repository's own git identity, is always recorded as the approver
(`by: person`, `confirmed_via: prompt`); the command is recorded only as `assisted_by`. There is
no fallback path that records the agent as approver — if the prompt cannot be raised (no human
attached, or an autonomous `orchestrate` dispatch), the command stops and reports instead of
weakening the channel.

## Rulings Index

- **Placement**: this file (above).
- **Artifact path, no-task key, tracked-directory status**:
  `context/project/approvals/standards/approval-artifact-convention.md`.
- **Confidence vocabulary and summary contract**:
  `context/project/approvals/standards/confidence-vocabulary.md`.
- **Interaction design** (option cap and step-through walk, reconciled):
  `context/project/approvals/patterns/approve-interaction-design.md`.

## Scripts

| Script | Purpose |
|--------|---------|
| `scripts/approve-paths.sh` | Resolve the component and compute the keyed review/sidecar paths |
| `scripts/approve-classify.sh` | Parse a generated review file into a per-item classification |
| `scripts/approve-guard.sh` | The four independent refusal predicates |

## Out of Scope

Changing `approve.sh` or `check-approvals.sh` in the consumer repository, and any approval-policy
question about which specifications deserve scrutiny. See the component's own documentation in
the consumer repository for that contract.
