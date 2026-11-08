# CHECKPOINT-BEFORE-OVERFLOW Pattern

**Created**: 2026-07-03
**Purpose**: Define, once, the procedure a dispatched agent runs at the context-pressure
threshold so a handoff is always preceded by a durable git checkpoint — never a stale handoff
sitting on top of a RED, uncommitted working tree.
**Audience**: general-implementation-agent (both effort modes — core's own standalone hard-mode
implementation agent is deleted), general-research-agent, cslib's and lean's own hard-mode
implementation agents (and any future agent that writes context-pressure handoffs)
**Related**: `context-exhaustion-detection.md`, `../formats/handoff-artifact.md`,
`../contracts/wrap-up.md`, `.claude/scripts/git-snapshot.sh` (the sanctioned snapshot helper)

---

## Overview

Context exhaustion is an expected event (see `context-exhaustion-detection.md`), not a failure.
That pattern defines *when* to notice pressure and *what* a handoff document looks like. This
pattern defines the missing middle step: **before** writing the handoff, checkpoint the working
tree so the next dispatch (or a human) can always recover exactly what was in progress, whether
the tree was green (safe to commit) or RED (broken, must not be committed as-is).

**Procedure name**: CHECKPOINT-BEFORE-OVERFLOW.

**Sequence**: STOP new work -> git checkpoint (commit-or-snapshot) -> write handoff naming the
exact next action -> terminate cleanly (return `partial` + `handoff_path`).

This is purely additive to each agent's existing pressure-detection and handoff-writing logic —
it inserts one new step, it does not replace or duplicate the detection/monitoring stage(s) that
already exist (implementation agents' Stage 4.5) or that are newly wired (research agents' Stage
3.5). See each agent file for where in its existing pressure path this step is inserted.

---

## The STOP Condition

Once a detection signal fires (per `context-exhaustion-detection.md`'s thresholds, or an agent's
own adapted signals), the agent MUST:

1. Stop starting any new file operation, search, fetch, or multi-file read.
2. Finish the smallest atomic unit of work already in flight (do not abandon a half-written
   file or a half-applied edit — complete or cleanly revert it first).
3. Proceed directly to the git checkpoint branch below, then the handoff.

Do not use the checkpoint procedure as a reason to curtail work early when no genuine pressure
signal has fired — this is a safety valve for real exhaustion, not a shortcut.

---

## The Git Checkpoint Branch (Commit-or-Snapshot)

Run this decision procedure exactly once per handoff, immediately before writing the handoff
document:

```bash
git status --porcelain
```

- **Clean tree** (`git status --porcelain` produces no output): No git action is needed. Nothing
  to checkpoint. Proceed straight to writing the handoff.

- **Dirty tree, confirmably green**: "Green" means the work completed so far is in a state you
  can positively confirm is not broken — e.g., the phase's own verification criteria passed, a
  build/test command that was run succeeded, or (for markdown/meta edits with no build step) the
  files written are syntactically complete and were verified to exist and be non-empty. In this
  case, apply the `implement` scope from `.claude/context/standards/git-staging-scope.md` (task
  dir + `plan_path` + self-reported `modified_files`) — under-stage, never a repo-wide add:
  ```bash
  stage_paths=("specs/${padded_num}_${project_name}/" "specs/TODO.md" "specs/state.json" "$plan_path")
  while IFS= read -r f; do
    [ -n "$f" ] && stage_paths+=("$f")
  done < <(jq -r '.modified_files[]? // empty' "specs/${padded_num}_${project_name}/.return-meta.json" 2>/dev/null)
  bash .claude/scripts/git-commit-scoped.sh \
    --message "task {N}: checkpoint before context-pressure handoff" \
    --session "{session_id}" \
    --honest-index-rows {N} \
    -- "${stage_paths[@]}"
  ```
  Record the resulting commit SHA for the handoff's Current State.

- **Dirty tree, RED or green cannot be confirmed**: If the tree is known-broken (a build/test
  failed, an edit was left half-applied, or there simply was no way to verify green before the
  pressure signal fired), do **not** commit broken state to the branch. Instead, run the
  sanctioned snapshot helper:
  ```bash
  bash .claude/scripts/git-snapshot.sh --no-revert {task_number}
  ```
  This writes a durable `working-progress-{ts}.patch` under the task directory, records a
  belt-and-suspenders stash entry, and copies untracked files to
  `untracked-backup-{ts}/`. Capture whichever reference(s) the script reports — the patch
  path, the `stash@{N}` ref, and the untracked-backup directory — for the handoff's Current
  State. On a clean tree the script itself is a no-op; this branch only runs it when the tree
  is dirty and RED, so that no-op case does not apply here.

  **`--no-revert` is required at this call site.** The script's default mode runs
  `git stash push -u`, which leaves the working tree clean at HEAD — the RED work this step
  exists to protect would disappear from the working directory, and the successor picking up
  the handoff would find nothing to resume from. `--branch` does not help: it commits the
  dirty tree to a scratch branch and then checks the original branch back out, which reverts
  the tree exactly as much as the stash path does. Only `--no-revert` leaves the tree intact.

**Decision table**:

| Tree state | Confirmably green? | Action |
|---|---|---|
| Clean | n/a | No git action |
| Dirty | Yes | `git commit` (checkpoint commit) |
| Dirty | No / RED | `bash .claude/scripts/git-snapshot.sh --no-revert {task_number}` |

---

## Recording the Checkpoint Reference in the Handoff

Whatever the git checkpoint branch produced, record it explicitly in the handoff document's
**Current State** section (see `../formats/handoff-artifact.md`) so a successor never has to
re-derive it:

- Commit path: `**Git checkpoint**: commit {sha} ("task {N}: checkpoint before context-pressure
  handoff")`
- Snapshot path: `**Git checkpoint**: RED tree snapshotted via git-snapshot.sh --no-revert
  — patch: {working-progress-{ts}.patch path}, stash: {stash@{N} or NONE},
  untracked-backup: {untracked-backup-{ts} path or NONE}; working tree left intact`
- Clean-tree path: `**Git checkpoint**: tree was clean, no git action needed`

For agents that also write `.orchestrator-handoff.json` (hard-mode implementation), additionally
surface the same reference there — see that agent's own checkpoint sub-section for the exact
field.

---

## Relationship to `guard-destructive-git.sh`

This procedure is purely additive: it only ever runs `git add`, `git commit`, or the sanctioned
`git-snapshot.sh` helper — never a destructive command (`reset --hard`, `checkout --`, `restore`,
`clean -fd`, `stash drop/clear`, forced checkout/switch). It therefore never exercises
`guard-destructive-git.sh`'s (the PreToolUse Bash hook) blocking path, and it does not consume or
depend on the freshness marker that hook and `git-snapshot.sh` coordinate through. Agents
following this pattern do not need to reason about the guard hook at all.

`git-snapshot.sh` itself is call-only from this pattern and from every
agent that references it — no agent may modify it.

---

## Research-Shaped Handoff Guidance (Distinct from H9)

Research agents (`general-research-agent`, used identically regardless of effort mode) that
adopt this pattern write a **research-shaped** handoff, not the hard-mode implementation
contract's H9 wrap-up schema:

- **Use**: `../formats/handoff-artifact.md`'s template, plus a `partial`-status
  `.return-meta.json` with `handoff_path` set in `partial_progress` — exactly the same
  `partial`/`handoff_path` contract implementation agents already use (see
  `context-exhaustion-detection.md`'s "Handoff Writing Protocol").
- **Do NOT use**: `../contracts/wrap-up.md`'s H9 schema (`.orchestrator-handoff.json`,
  `sorry_inventory`, `continuation_path`, territory `blockers`). That schema and its consumer
  allowlist belong to hard-mode implementation dispatch (per-phase orchestration, `skill-
  orchestrate-hard`) and have no research-side consumer.
- **Why the distinction matters**: writing an H9-shaped artifact that nothing reads is worse than
  writing nothing — it looks like a supported continuation mechanism when none exists. Research's
  checkpoint value is crash-avoidance (never lose in-progress findings to an uncommitted RED
  tree) plus a discoverable partial report on disk that a fresh research-phase dispatch for that task can
  build on, not automatic resume.

See each research agent's own Stage 3.6 (or equivalent) for the full research handoff sequence
and its explicit Option (A) scoping note.

---

## Related Documentation

- [Context Exhaustion Detection](context-exhaustion-detection.md) — detection signals and
  handoff-writing protocol this pattern's checkpoint step slots into
- [Handoff Artifact Schema](../formats/handoff-artifact.md) — handoff document template
- [Wrap-Up Contract (H9)](../contracts/wrap-up.md) — the hard-mode implementation schema this
  pattern explicitly does NOT extend to research
- `.claude/scripts/git-snapshot.sh` — the sanctioned snapshot helper, call-only
