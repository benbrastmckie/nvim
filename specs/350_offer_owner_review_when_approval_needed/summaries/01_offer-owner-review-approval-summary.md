# Implementation Summary: Task #350

- **Task**: 350 - Offer the owner the review path when a books task reaches a point that needs
  an approval, instead of requiring the owner to know to run /approve
- **Status**: [COMPLETED]
- **Started**: 2026-10-17T08:30:00Z
- **Completed**: 2026-10-17T11:20:00Z
- **Effort**: ~3 hours
- **Dependencies**: `add_approve_command_owner_labeled_approvals` (shipped). `owner_labeled_agent_assisted_approvals` (Logos/Verification repository) — read-only input, never edited.
- **Artifacts**: plans/01_offer-owner-review-approval.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

Added a detection-and-offer surface over the existing `user_decision`/Move 3/Move 4 relay, scoped
to the books extension's source store, with no new interaction machinery. A books component
gate's approvals stage failing specifically because approval records are absent or stale is now
recognized by a read-only shell script, which emits a correctly shaped `user_decision` (enter
review now / defer / decline, `blocking: false`, `recommended` = defer) that a books
implementation agent copies verbatim into its own return metadata. Declining or deferring never
weakens the approval requirement.

## What Changed

- `agent-system/extensions/books/context/project/books/domain/approvals-detection.md` — new
  record: the detection-seam ruling (books agent definitions, not postflight) with its reason,
  the pinned six-family/thirteen-family signature read from `check-approvals.sh`/`check.sh`
  (2026-10-17), the stage-attribution line, the three options and their exact semantics, the
  `blocking: false`/`recommended=defer` ruling, the hand-off design, the no-human-attached
  ruling (mirroring `skill-approve`'s own Stage 2 refusal), and the explicit never-suppress MUST
  NOT block.
- `agent-system/extensions/books/context/project/books/domain/gate-tiers.md` — the `full-gate.sh`
  tier's Checks row now names the approvals leg; added a `Related` pointer to the new record.
- `agent-system/extensions/books/context/project/books/README.md` — navigation row for the new
  record.
- `agent-system/extensions/books/index-entries.json` — index entry for the new record.
- `agent-system/extensions/books/scripts/books-approvals-signal.sh` — new read-only recognizer.
  Reads a captured gate run's output, matches the six recognized absent-or-stale message
  families (never the exit code alone), applies the mixed-red honesty clause, probes for the
  deployed `/approve` surface with a bounded fallback to the component's own `approve.sh` lines,
  and emits (or withholds) a single `user_decision`-shaped JSON object.
- `agent-system/extensions/books/scripts/tests/test-books-approvals-signal.sh` — new suite, 76
  cases: six positive-recognition cases, thirteen excluded-family negatives plus a green-gate
  and a usage-error negative, seven shape assertions, decline/defer intactness (same-offer
  re-emission, unreadable-`.decisions.json` no-effect, unchanged fixture-tree digest, both
  answers), a no-self-answering structural assertion, five forgery probes over the recognizer,
  and structural assertions (plus two forgery probes) over both agent files.
- `agent-system/extensions/books/manifest.json` — registered the new script and suite in
  `provides.scripts`; added `"approve.sh"` to `external_scripts` (see Plan Deviations).
- `agent-system/extensions/books/agents/books-implementation-agent.md` — cross-cutting
  approvals-need detection rule near Stage 5's gate-tier guidance, four new MUST NOT
  prohibitions, and a context pointer to the new record.
- `agent-system/extensions/books/agents/books-implementation-hard-agent.md` — the same rule by
  reference (not restated), the same four prohibitions, and the same context pointer.

## Decisions

- **D1 (detection seam)**: the books agent definitions, not postflight — postflight has no
  access to raw gate output, and `user_decision` is producer-owned.
- **D2 (pinned signature)**: six recognized absent-or-stale message families, thirteen excluded
  families (including `--require-person`), read 2026-10-17 from the external repository's
  `check-approvals.sh`/`check.sh`. The signature is matched on message text, on stdout, never on
  the exit code alone.
- **D3**: detection is a read-only recognizer script, not prose alone, so every acceptance
  clause is a fixture test.
- **D4**: the recognizer lives in the books extension.
- **D5**: `blocking: false`, `recommended` = the defer option — "enter review now" cannot be a
  silent default, and "decline" must never be chosen for the owner.

## Plan Deviations

- **Step 2** (no formal step number — mechanical): the line-count entries this task introduced
  in `index-entries.json` had to be corrected via `generate-context-line-counts.sh --write`
  after the initial edit; not a deviation, the expected mechanical follow-up to editing a
  counted file.
- **Step 4.1-4.3**: a bare `approve.sh` mention in both agent files' MUST NOT lists tripped
  `check-extension-docs.sh`'s Rule E (`check_referenced_scripts_declared`). Fixed by adding
  `"approve.sh"` to `agent-system/extensions/books/manifest.json`'s `external_scripts` array —
  the sanctioned escape hatch for exactly this case (the `approvals` extension's own manifest
  already uses it for the same name).
- **Step 5.1** (altered, worth flagging explicitly): the plan's instruction to "deploy... and
  confirm the new script, suite, and context record are present under `.claude/`" assumed the
  `books` extension is loaded in this repository. It is not — `.claude-extensions.json` here
  loads `literature, core, approvals, nix, email, nvim, memory, lean`, and `books` is not among
  them, so `deploy-headless.sh` correctly deploys nothing for it (this is a pre-existing
  condition of this repository, not something this task caused or should change — loading a new
  extension was explicitly out of this task's scope and would have been a materially larger,
  riskier action than what was asked). `deploy-headless.sh` was still run (Step 5.1's own
  instruction) and its internal `verify-deploy.sh` pass came back **36 checks, 0 failures** for
  every extension that *is* loaded — confirming this task's source-store edits introduced no
  regression anywhere reachable from this repository's actual deploy configuration. The
  end-to-end relay demonstration (Step 5.2/5.3, below) does not depend on `books` being deployed:
  it uses the recognizer directly from the source store plus `core`'s own deployed
  `orchestrate-cycle-postflight.sh`, which is extension-agnostic about who produced the
  `user_decision` it relays.
- **Step 5.4** (altered, per the dispatch file's own Batch Gate Deferral directive — this
  dispatch is one of several `implement`-phase dispatches inside one multi-task `/orchestrate`
  batch invocation): discharged against the scoped narrowing invocations
  (`run-all.sh --only test-books-approvals-signal.sh`, and
  `verify-deploy.sh --skip-slow --only-gate 3,4`) rather than independently running the complete
  `verify-deploy.sh` gate set. The complete set still ran once, as a necessary side effect of
  Step 5.1's `deploy-headless.sh` call (which always verifies after deploying), and came back
  clean (36/0) — corroborating evidence, not a substitute for the batch's own once-per-invocation
  full run, which is attributed back to this task by its own `modified_files`.
- **Scope Hypothesis confirmation (Phase 4)**: `books-research-agent.md`/
  `books-research-hard-agent.md` DO run `lake build`/`books-tool`/the certify driver for
  live-tree verification, but neither invokes `check.sh`/`full-gate.sh`/`check-approvals.sh` (the
  only place the approvals stage lives per D2) — confirmed by grep. The plan's decision to wire
  only the two implementation agents is therefore confirmed correct, not contradicted.

## Verification

- Build: N/A (no Lean content; shell + markdown + JSON only)
- Tests: `test-books-approvals-signal.sh` — 76/76 passed; `bash -n`/`shellcheck --severity=warning`
  clean on both the recognizer and the suite
- Files verified: Yes — `verify-deploy.sh --skip-slow --only-gate 3,4` passed after every phase;
  `deploy-headless.sh`'s own internal full gate passed (36/0); JSON files (`index-entries.json`,
  `manifest.json`) parse
- End-to-end relay demonstration (acceptance clause "demonstrated, not asserted"): a scratch
  `.return-meta.json` carrying the recognizer's own emitted `user_decision` object was run
  through `orchestrate-cycle-postflight.sh --dry-run` against an isolated scratch state file and
  multi-state file (never the real `specs/state.json`). Observed output:
  `verdict: "ask_user"`, `status: ""` (unchanged — the gate red is still a red), and the relayed
  `user_decision` object verified **byte-for-byte identical** (`jq -c` comparison) to the
  recognizer's own stdout. stderr confirmed: `"USER_DECISION payload present ... relaying
  verbatim as verdict=ask_user ... this script never asks and never writes .decisions.json"`.
  `git status --porcelain` on the real repository was unchanged (39 lines, before and after)
  across the whole demonstration, confirming nothing under any approvals tree — or anywhere else
  in the real repository — was touched.
- Declining/deferring leaves the requirement intact: shown by test (`decline-reemits-same-offer`,
  `decline-unreadable-decisions-file-no-effect`, `decline-fixture-tree-unchanged`, and the mirror
  trio for defer).
- No-human path: by construction, not a separate code path — the recognizer never auto-invokes
  `/approve`, so there is no action to take on anyone's behalf; this is asserted by the
  no-self-answering structural test and documented in `approvals-detection.md`'s "no-human case"
  section, mirroring `skill-approve`'s own `orchestrator_mode: true` Stage 2 refusal.

## Impacts

- A books dispatch that hits an absent-or-stale approvals leg now surfaces the review option to
  the owner automatically, instead of the owner having to already know an approval is
  outstanding and already know `/approve` exists.
- No change to `skill-orchestrate/SKILL.md`, `orchestrate-cycle-postflight.sh`,
  `orchestrate-record-decision.sh`, `/approve`, `approve.sh`, or `check-approvals.sh` — nothing
  in the existing relay, approval, or gate path can regress from this change.

## Follow-ups

- `--require-person` (approved by an agent, but a person is required) is a candidate follow-up
  for a second recognized class, recorded but deliberately not built here (out of this task's
  scope — the records are present and current, so it is not the absent-or-stale mode).
- The `books` extension is not currently loaded in this repository; the full
  deploy-to-`.claude/` and real end-to-end dispatch demonstration can only be observed in a
  repository where `books` is an active extension (e.g. the Logos/Verification companion
  repository this convention targets).

## References

- Plan: `specs/350_offer_owner_review_when_approval_needed/plans/01_offer-owner-review-approval.md`
- Research report: `specs/350_offer_owner_review_when_approval_needed/reports/01_offer-owner-review-approval.md`
- New record: `agent-system/extensions/books/context/project/books/domain/approvals-detection.md`
