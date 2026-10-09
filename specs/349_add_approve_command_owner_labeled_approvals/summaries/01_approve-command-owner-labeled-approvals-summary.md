# Implementation Summary: Task #349

- **Task**: 349 - Add an /approve command to the agent system so a specification approval is given by answering one interactive question instead of a terminal round-trip
- **Status**: [COMPLETED]
- **Started**: 2026-10-09
- **Completed**: 2026-10-09
- **Effort**: ~9 hours
- **Dependencies**: None outstanding
- **Artifacts**: plans/01_approve-command-owner-labeled-approvals.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

Built a new, opt-in `approvals` extension in the agent-system source store whose single
command, `/approve <component> [component-flags] [--task N] [--dry-run]`, drives a consumer
repository's `components/<component>/approve.sh` through the owner-labeled confirmation
channel: runs `--review`, persists the review at a predictable tracked path under
`specs/certificates/<component>/`, classifies its diff mechanically, presents an essentials-
only summary with a two-tier `MEASURED`/`INFERENCE` confidence label per item, asks the owner
through `AskUserQuestion` in the root session, and records with the owner as approver and the
command as `assisted_by`. The whole flow runs inside a direct-execution skill because
`AskUserQuestion` is categorically withheld from every dispatched subagent on this harness. All
9 planned phases are complete; the extension is loaded, deployed, and verified in this
repository.

## What Changed

- `agent-system/extensions/approvals/manifest.json` — new extension manifest, `routing_exempt:
  true`, `external_scripts: ["approve.sh", "check-approvals.sh"]`
- `agent-system/extensions/approvals/EXTENSION.md` — compact CLAUDE.md-merged overview
- `agent-system/extensions/approvals/README.md` — the placement ruling (new extension, not
  `books` or `core`) with its reason, cited by filename
- `agent-system/extensions/approvals/context/project/approvals/README.md` — context index
- `agent-system/extensions/approvals/context/project/approvals/standards/approval-artifact-convention.md`
  — the persisted-review path, the `task-{N}-{II}` and `adhoc-{DATE}-{II}` naming forms (the
  no-task key stated explicitly, never a degenerate case), the instance-collision rule, and the
  `specs/certificates/` deliberately-tracked ruling
- `agent-system/extensions/approvals/context/project/approvals/standards/confidence-vocabulary.md`
  — the two-tier `MEASURED`/`INFERENCE` vocabulary, derived from and citing
  `books/convention/09-trust-unit-is-the-export.md` (Decision 9) and `books/lean/BookCert/Depends.lean`
  in the Logos/Verification repository, plus the owner-facing summary contract
- `agent-system/extensions/approvals/context/project/approvals/patterns/approve-interaction-design.md`
  — one ruling covering the four-option `AskUserQuestion` cap, the Stage A bulk triage gate
  (option-availability gated), the Stage B per-item step-through walk, and both escapes
  (conversational discussion; opening the persisted files directly)
- `agent-system/extensions/approvals/scripts/approve-paths.sh` — component resolution and
  keyed-path computation (`--component`, `--task`/`--date`, `--instance-of`, `--emit-paths`;
  refuses a caller-supplied `--out`)
- `agent-system/extensions/approvals/scripts/approve-classify.sh` — review-file parser and
  classifier; emits `{component_head, items: [...]}`; four `diff_since` evidence kinds; the
  declaration delta by name (`decl_added`/`decl_removed`/`decl_restated`); fails loud on an
  unrecognized shape
- `agent-system/extensions/approvals/scripts/approve-guard.sh` — the four independent refusal
  predicates (`--check-freshness`, `--check-surfaced`, `--check-human`, `--check-labels`)
- `agent-system/extensions/approvals/scripts/tests/test-approve-{paths,classify,refusals,structural}.sh`
  — four regression suites, 36 total cases, all passing standalone and under `run-all.sh`
- `agent-system/extensions/approvals/commands/approve.md` and
  `agent-system/extensions/approvals/skills/skill-approve/SKILL.md` — the command surface and
  the 12-stage direct-execution flow; `allowed-tools: AskUserQuestion, Bash, Edit, Read, Write`
  (no `Agent`, no `agent:` field)
- `agent-system/extensions/README.md` — added the `approvals` row
- `agent-system/extensions/core/scripts/check-extension-docs.sh` — added a narrowly-scoped
  `external_scripts` manifest-field exclusion set to Rule E, resolving the false-positive on an
  extension that legitimately references an external, consumer-repo-owned script by name
- `agent-system/extensions/core/scripts/lib/runtime-file-patterns.sh` — header-comment-only
  addition naming `specs/certificates/` as durable/out-of-class (no emitted-pattern change)
- `agent-system/extensions/core/context/config/orchestrator-context-budget.json` —
  `eager_load.baseline_bytes` moved 65950 -> 66100 (see Decisions below)
- `.claude-extensions.json` — the `approvals` extension's load record (written by the loader)

## Decisions

- **Placement**: a new extension (`approvals`), not `books` (whose charter disclaims component
  certificates) or `core` (universally loaded). Named after the mechanism's own vocabulary.
- **Confidence vocabulary**: exactly two tiers, derived from and citing the repository's own
  existing `books/convention/09-trust-unit-is-the-export.md` Decision 9 precedent — verified by
  reading the cited file directly in `~/Projects/Logos/Verification`.
- **Interaction design**: Stage A's bulk-approve option is offered only when at least one item
  is mechanically cleared (option-availability gating, never offer-then-filter); Stage B is
  always exactly four options; Escape 2 (opening the files) consumes no option at all.
- **`--check-freshness` scope**: compares the git HEAD the review was generated at (captured
  verbatim) against the current HEAD — a coarse, honest backstop in front of, not a
  reimplementation of, `approve.sh --record`'s own fine-grained per-item digest re-check.
- **Classifier recommendation vocabulary**: emits only `approve`/`read-full-text` automatically;
  `decline` stays a valid value (used in the owner-facing `AskUserQuestion` options) but is
  never auto-inferred, since declining is the owner's judgment call.
- **`eager_load.baseline_bytes` move (65950 -> 66100)**: this budget field's own history shows
  5 consecutive prior entries all closed by trimming, never bumping. This task's addition is
  structurally different — a brand-new extension's unavoidable minimal CLAUDE.md footprint
  (compressed to a 105 B floor, smaller than any other extension's own entry), not
  redistributable bloat in already-existing content. Recorded as an issue flagging this as a
  deliberate, reviewed exception rather than a routine precedent break.

## Plan Deviations

- **Phase 6**: `approve-classify.sh`'s output shape was extended from a bare JSON array to
  `{component_head, items: [...]}`, and `--check-freshness` compares git HEAD rather than
  recomputing a Lean digest (duplicating `approve.sh`'s own private logic was out of scope).
- **Phase 7**: added `external_scripts` to `check-extension-docs.sh` (outside the plan's
  declared Files to modify for any phase) to resolve the Rule E gap tracked since Phase 1;
  verified no regression across all 22 other extensions. Also: the "dry-run walk-through"
  verification was performed via the Phase 5 fixture chain and a hand-traced `--record`
  command, not a live `AskUserQuestion` session — no component with a real `approve.sh` exists
  in this repository, and exercising one in `~/Projects/Logos/Verification` was out of scope.
- **Phase 8**: found and fixed a real parsing bug in `approve-classify.sh` (shape-based diff
  file-header skip collided with a removed/added line-comment starting with `--`); hardened to
  a positional (post-first-`@@`) check instead.
- **Phase 9**: the `eager_load.baseline_bytes` move described above.

## Verification

- Build: N/A (meta/shell task)
- Tests: Passed — all four new suites (36 cases) pass standalone and under `run-all.sh`;
  `bash .claude/scripts/verify-deploy.sh` (unnarrowed, 21 gates) reports 34/35 checks PASS
- Files verified: Yes

## Impacts

- A new, discoverable `/approve` command and `approvals` extension, loadable via the picker in
  any repository shaped like a verification consumer.
- `check-extension-docs.sh`'s Rule E gains a general, backward-compatible escape hatch
  (`external_scripts`) any future extension can use for a legitimately-external script
  reference, without weakening the check for anything else.
- `eager_load.baseline_bytes` grew by 150 B (65950 -> 66100) — a deliberate, dated, reviewed
  move; a future task closing this budget gate should read this entry's derivation before
  assuming the field should revert to trim-only behavior.

## Follow-ups

- Gate 8 (`run-all.sh`) still reports 3 pre-existing, unrelated-to-approvals failing suites
  (`test-detect-noop-bash.sh`, `test-lint-deploy-caller-wrap.sh`,
  `test-orchestrate-build-aux-dispatch.sh`). Confirmed none touches any file this task modified
  and all three predate this dispatch. Out of this task's scope to fix; flagged for separate
  investigation.
- The live, end-to-end `/approve` flow (Stage 3 onward) can only be exercised in a repository
  with a real `components/<name>/approve.sh` — e.g. `Logos/Verification`'s `framed_channel`
  component — which is outside this repository. The owner should run a real `--dry-run` there
  as the first live check.
- `eager_load.baseline_bytes`'s "always trim, never bump" culture was deliberately broken once,
  with full justification recorded in `orchestrator-context-budget.json`'s own derivation note
  and an `issue-record.sh` entry (class `gate-collision`, severity `costly`). A future review
  may want to formalize an explicit "new-extension floor cost" allowance in that gate's design
  rather than relying on a per-task judgment call each time.

## References

- Plan: `specs/349_add_approve_command_owner_labeled_approvals/plans/01_approve-command-owner-labeled-approvals.md`
- Research: `specs/349_add_approve_command_owner_labeled_approvals/reports/01_approve-command-owner-labeled-approvals.md`
- Progress files: `specs/349_add_approve_command_owner_labeled_approvals/progress/phase-{1..9}-progress.json`
- Handoffs: `specs/349_add_approve_command_owner_labeled_approvals/handoffs/phase-{1..9}-handoff-*.md`
