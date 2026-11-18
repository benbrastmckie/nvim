# Implementation Summary: Task #636

- **Task**: 636 - Close sapience activation-surface scoping gaps: vendor user-level hooks,
  capture coupling, verifier and docs
- **Status**: [COMPLETED]
- **Started**: 2026-11-17T16:45:57Z
- **Completed**: 2026-11-17T17:09:51Z
- **Effort**: ~2.5 hours
- **Dependencies**: None
- **Artifacts**: plans/01_activation-surface-scoping-gaps.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

Closed all five dispatched GOAL items in the sapience extension's source store
(`agent-system/extensions/sapience/**`): three new named checks in `verify-sapience-mcp.sh`
(machine-wide vendor hook recurrence, "active but hook fragment never merged", capture/activation
coupling), an N-repeat unanimous-agreement verdict in `verify-sapience-context-scoping.sh`, and
two documentation rewrites replacing claims the measured evidence had falsified. The extension
was redeployed and both verifiers were smoke-tested end-to-end against the live machine state.

## What Changed

- `agent-system/extensions/sapience/scripts/verify-sapience-mcp.sh` — added check (g) (machine-
  wide vendor hook recurrence detector, mirroring `sapience_upkeep.py`'s `hooks_opted_out()`/
  `wire_hooks()`, reporting the `config.json` `hooks` opt-out value unconditionally); check (h)
  ("active but hook fragment never merged", reading the same `EXTENSIONS_FILE` check (a) opens,
  cross-referenced with check (e)); check (i) (capture/activation coupling scoped to the current
  project, longest-`path_prefix`-wins resolution mirroring `sapience_capture.py`'s `for_cwd()`,
  with the reconciliation ruling recorded inline); extended the `--help` header for all three.
- `agent-system/extensions/sapience/scripts/tests/test-sapience-mcp-registration.sh` — added
  cases 37-47 covering checks (g)/(h)/(i) (fixtures for pass/fail/skip/opt-out-value/nested-
  prefix); extended case 20's all-green fixture to stay green under the new check (h). 47/47
  cases pass.
- `agent-system/extensions/sapience/scripts/verify-sapience-context-scoping.sh` — added
  `--repeat N` (default 3), wrapping the existing two-call comparison in an N-iteration loop
  with a per-iteration session-id suffix and a strictly-unanimous (never majority) agreement
  rule; rewrote the header/usage/outcomes documentation accordingly.
- `agent-system/extensions/sapience/scripts/tests/test-sapience-context-scoping.sh` (new) — 6
  cases covering unanimous-holds, unanimous-lifted, mixed tally, one-iteration network failure,
  `--repeat 1`, and bad `--repeat` values, reusing `test-sapience-capture.sh`'s curl-stub
  technique extended to an arbitrary-length per-call-index response table.
- `agent-system/extensions/sapience/manifest.json` — declared the new test script in
  `provides.scripts` via `sync-manifest-scripts.sh --write`.
- `agent-system/extensions/sapience/context/project/sapience/domain/injection-site-scoping.md` —
  rewrote "No Machine-Wide Duplicate Hook Surface" to describe both the settings-fragment-merged
  hooks and the vendor upkeep path as two independent, correctly-distinguished mechanisms, naming
  check (g) as the standing detector.
- `agent-system/extensions/sapience/context/project/sapience/domain/per-repo-scoping.md` —
  extended population-3 with the capture opt-in gating layer and added a new "Capture/Activation
  Reconciliation" subsection recording the ruling that this source store stops at the verifier
  check.
- `agent-system/extensions/sapience/index-entries.json` — `line_count` reconciled for both
  edited context files (325→348, 128→157) via `generate-context-line-counts.sh --write`.

## Decisions

- GOAL (2)'s reconciliation sub-question was ruled on, not deferred: this source store stops at
  the verifier check (i); writing `capture.projects[].enabled` belongs in `~/.dotfiles`, which
  already owns a capture-map writer — a second independent writer here would create the same
  two-writers-disagreeing hazard already named for the MCP-registration entry.
- Check (i)'s four outcomes (active+enabled, active+not-enabled, inactive+enabled,
  inactive+not-enabled) use the SAME informational-not-failure wording whether the cause is
  `enabled: false` or no matching `path_prefix` at all, per the plan's explicit requirement.
- `verify-sapience-context-scoping.sh --repeat`'s agreement rule is strictly unanimous, never a
  majority: the measured evidence motivating this feature was a 1-vs-2 split that a majority
  rule would have (wrongly) called conclusive.

## Plan Deviations

- **Phase 2**: case 20's all-green verifier fixture was extended to carry
  `merged_sections.settings.hooks: true` — adding check (h) made the previously-green fixture
  fail, so the fixture was updated rather than leaving case 20 red. Not a plan deviation in
  substance, only an un-enumerated knock-on fix the plan did not call out by name.
- No other deviations; all phases followed the plan as written.

## Verification

- Build: N/A (shell scripts and markdown, no build step)
- Tests: `test-sapience-mcp-registration.sh` 47/47 pass; `test-sapience-context-scoping.sh` 6/6
  pass; both run from the deployed tree post-redeploy. `test-manifest-scripts-sync.sh` and
  `test-script-inventory.sh` pass. `bash -n` and `shellcheck -S warning` clean on every edited or
  created shell file.
- Files verified: Yes — `deploy-headless.sh` reports `RESULT=landed_verify_clean` with its own
  inline verification at 40/40 checks; `verify-deploy.sh --skip-slow --only-gate 3,4` (doc-lint,
  task-reference lint) passes 3/3 post-redeploy with the pre-redeploy script-content drift
  resolved; `check-task-references.sh` reports 0 occurrences repo-wide.
- Live smoke checks: `verify-sapience-mcp.sh` passes (g)/(h)/(i) for this repository (`hooks`
  opt-out reported as `false`); check (h) reproduces the dispatched evidence (c) against
  `~/Projects/abood` (fails by name); check (i) reproduces the dispatched evidence (b) against
  `~/Projects/BimodalLogic` (informational line, not a failure); `verify-sapience-context-
  scoping.sh --repeat 3` against the live endpoint printed a real `INCONCLUSIVE` 2-vs-1 tally on
  one run, confirming the unanimous-agreement rule is exercised by genuine live disagreement, not
  only by synthetic fixtures.

## Impacts

- A machine-wide vendor hook recurrence (the exact class of drift that motivated this task) is
  now detected on every `verify-sapience-mcp.sh` run, not just discoverable by manual inspection.
- `~/Projects/abood`'s unmerged-hook-fragment state is now named by check (h) rather than left to
  inspection; the remedy (reload/redeploy) is stated at the check site.
- The capture/activation asymmetry (evidence (b)) is now visible per-project via check (i),
  though no automatic reconciliation is built — a future `~/.dotfiles`-sited task would need to
  read the ruling in `per-repo-scoping.md`'s new subsection before building one.
- `verify-sapience-context-scoping.sh`'s single-run unreliability (evidence (d), the 1-vs-2
  split) is resolved: a caller now gets `INCONCLUSIVE` honestly on disagreement rather than a
  confident but potentially wrong single-run verdict.

## Follow-ups

- None required by this task. Three items were explicitly excluded (see the plan's Reasoned
  Exclusions): softening `EXTENSION.md`'s "ONLY thing that turns Sapience on there" claim
  (recorded as a follow-up in the research report, not in this plan's scope); repairing
  `~/Projects/abood`'s own merge state (an operator action in a different repository); building
  active capture/activation reconciliation (ruled to belong in `~/.dotfiles`, if built at all).

## References

- Plan: `specs/636_sapience_activation_surface_scoping_gaps/plans/01_activation-surface-scoping-gaps.md`
- Research report: `specs/636_sapience_activation_surface_scoping_gaps/reports/01_activation-surface-scoping-gaps.md`
- Phase progress files: `specs/636_sapience_activation_surface_scoping_gaps/progress/phase-{1..6}-progress.json`
- Phase handoffs: `specs/636_sapience_activation_surface_scoping_gaps/handoffs/phase-{1..6}-handoff-*.md`
