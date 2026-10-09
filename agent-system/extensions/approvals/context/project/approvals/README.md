# Approvals Context

Context files for the `approvals` extension's `/approve` command.

## Structure

- `standards/` — decided, durable rulings the command's own behavior must match.
- `patterns/` — the interaction design the command's prompting flow implements.

## Key Files

- `standards/approval-artifact-convention.md` — the persisted-review path, the task-keyed and
  no-task-keyed naming forms, the instance-number collision rule, and the deliberately-tracked
  status of `specs/certificates/` against the managed `.gitignore` block.
- `standards/confidence-vocabulary.md` — the two-tier `MEASURED`/`INFERENCE` vocabulary and the
  owner-facing summary contract.
- `patterns/approve-interaction-design.md` — the single ruling covering the four-option cap, the
  bulk triage gate, the per-item step-through walk, and both escapes.

## For `/approve`

Load all three files above before running any step of the flow; they are the contract the skill
implements, not optional background.
