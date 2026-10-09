---
description: Review, classify, ask the owner, and record an owner-labeled component approval
allowed-tools: AskUserQuestion, Bash, Edit, Read, Write
argument-hint: "<component> [component-flags...] [--task N] [--dry-run]"
---

# Command: /approve

**Purpose**: Drives a consumer repository's `components/<component>/approve.sh` through an
interactive question in the root session, instead of a terminal round-trip, and records the
result **owner-labeled**: the owner is always the approver, this command is always only
`assisted_by`.

**Layer**: 1 (Direct execution)
**Delegates To**: `skill-approve` — a direct-execution skill, never a dispatched agent. See
`../README.md`'s "Why `/approve` Is Never Dispatched": `AskUserQuestion` is categorically
withheld from every `Agent`-tool dispatch on this harness, so this command's entire flow must
run in the root session.

## Usage

```
/approve <component> [component-flags...] [--task N] [--dry-run]
```

- `<component>` — required. The name of a `components/<component>/` directory in the current
  repository that has its own `approve.sh`.
- `[component-flags...]` — any trailing flags (for example `--core-only`, `--aeneas`) are
  forwarded **verbatim** to the component's own `approve.sh --review`. This command never
  interprets or hardcodes a component's own flag vocabulary — see
  `../README.md`'s "Out of Scope".
- `--task N` — optional. Keys the persisted review under `task-{N}-{II}` instead of
  `adhoc-{DATE}-{II}`. See
  `../context/project/approvals/standards/approval-artifact-convention.md`.
- `--dry-run` — shows the full flow (summary, the would-be `--record` command, artifact paths)
  and records nothing: no `AskUserQuestion` prompt is raised, no presented sidecar is written.

**Refused unconditionally**: a caller-supplied `--out`. The persisted review's location is this
command's own business — see the artifact convention ruling above.

## What This Command Never Does

It never records the agent as approver. If `AskUserQuestion` cannot be reached — no human is
attached, or this command is running inside an autonomous `/orchestrate` dispatch (detected via
`orchestrator_mode: true` in the delegation context) — it stops and reports. There is no
fallback path that weakens this to an agent-recorded approval.
