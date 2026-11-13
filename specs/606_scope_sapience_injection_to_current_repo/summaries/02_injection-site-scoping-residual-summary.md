# Implementation Summary: Task #606

- **Task**: 606 - Scope Sapience context injection to the current repository so a session stops
  receiving other repos' facts
- **Status**: [COMPLETED]
- **Started**: 2026-11-12
- **Completed**: 2026-11-13
- **Effort**: ~2.5 hours
- **Dependencies**: 600 (completed), 611 (completed), 612 (completed)
- **Artifacts**: plans/02_injection-site-scoping-residual.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

Research established, by direct live measurement, that none of the three primary-session
injection sites (`SessionStart`, `UserPromptSubmit`, `PreToolUse`) can be scoped from this
repository: `POST /v1/cli/context` ignores the `project` field `UserPromptSubmit` already sends,
and its response carries no per-item attribution a local wrapper could filter or label by. This
task converts that measured, vendor-owned residual into durable source-store record, a
falsifiable read-only probe, and two verbatim owner actions — without suppressing, filtering, or
narrowing any hook, which would have cost the cross-corpus abstraction class the channel also
delivers.

## What Changed

- `agent-system/extensions/sapience/context/project/sapience/domain/injection-site-scoping.md` —
  new domain note: the three-site table (deployed command, endpoint, transmits?, honored?), both
  measured foreclosures with their reproduction, the label-never-suppress ruling, both owner
  actions verbatim, and the recorded (not built) claim-shape-heuristic follow-up.
- `agent-system/extensions/sapience/scripts/verify-sapience-context-scoping.sh` — new read-only
  probe script: replays the two-call `project=` comparison against `POST /v1/cli/context` on
  demand, reports `RESIDUAL_HOLDS` / `RESIDUAL_LIFTED` / `INCONCLUSIVE`, degrades loudly with no
  token leak on a missing config, and mints a unique `session_id` per run (a correctness fix
  applied mid-Phase-4; see Plan Deviations).
- `agent-system/extensions/sapience/manifest.json` — registered the new script in
  `provides.scripts`, alphabetical order preserved.
- `agent-system/extensions/sapience/context/project/sapience/README.md` — new Loading Strategy
  row for the domain note.
- `agent-system/extensions/sapience/context/project/sapience/domain/per-repo-scoping.md` — new
  Hazards item: the primary-session hook path has no scoping mechanism, independent of tagging
  state; the existing four-population census is unchanged, not renumbered.
- `agent-system/extensions/sapience/context/project/sapience/domain/vault-model.md` — scoped the
  CLI-inventory section explicitly to `mcp.py`; added a new section on `sapience_cli.py` and the
  `POST /v1/cli/context` endpoint it shares with the `tool`/`stop` hook modes.
- `agent-system/extensions/sapience/README.md` — new "Gap 5" entry (explicitly NOT closed,
  unlike Gaps 1-4) and a File Inventory row for the new probe script.
- `agent-system/extensions/sapience/EXTENSION.md` — new residual paragraph and a Context
  Pointers entry for the domain note (required a prose-compression pass to stay under the
  60-line Rule U limit; see Plan Deviations).
- `agent-system/extensions/sapience/index-entries.json` — new entry for the domain note;
  summary/keyword updates for `per-repo-scoping.md` and `vault-model.md`; `line_count`
  reconciliation for every moved context file.
- Deployed mirror under `.claude/` — regenerated twice (once after line-count reconciliation,
  once after the probe-script correctness fix); disposable, not a tracked deliverable.

## Decisions

- **Label, never suppress — and record that neither is reachable**, rather than building any
  client-side filter: Foreclosure 1 (no working filter parameter) and Foreclosure 2 (no
  per-item attribution) each independently foreclose a local mechanism, so the deliverable is
  measurement-plus-owner-action, not a workaround.
- **The claim-shape heuristic filter stays a recorded follow-up, not a built deliverable** — its
  brittleness risk was flagged by research and is not re-litigated here.
- **The probe's own noise is documented, not suppressed, in its output** — the server's
  repeat-suppression behavior can make two truly-identical-content calls look different for
  reasons unrelated to `project=`. Rather than engineering around it further (out of scope) or
  ignoring it (dishonest), the script's `RESIDUAL_LIFTED` wording explicitly tells the reader a
  single differing run is inconclusive-leaning and must be re-sampled before concluding the
  vendor ask landed.

## Plan Deviations

- **Task 3.5** (index-entries.json "three affected entries"): altered — only 2 of the asserted 3
  entries (`per-repo-scoping.md`, `vault-model.md`) needed a meaning-changing summary/keyword
  edit; `project/sapience/README.md`'s summary stayed accurate after Phase 1's new Loading
  Strategy row and was not re-worded.
- **Phase 3, EXTENSION.md**: the new Gap-5 residual paragraph initially pushed the file to 68
  lines, tripping `check-extension-docs.sh`'s Rule U (a hard 60-line limit, not advisory).
  Resolved by compressing three existing paragraphs to 59 lines with no loss of substance.
- **Phase 4, Batch Gate Deferral**: per this dispatch's directive (this task is one of several
  implement-phase dispatches in one multi-task `/orchestrate` batch), the final phase's full
  `verify-deploy.sh` criterion was discharged against the scoped tier
  `verify-deploy.sh --only-gate 1,2,3,4,5` (event/error-store presence, hook registrations,
  doc-lint, task-reference lint, nvim headless extension-manager verify_all) — 16/16 PASS. The
  full `--skip-slow` sweep was additionally run for this task's own diagnostic purposes and
  showed exactly 2 findings, neither attributable to this task's files: a transient gate10
  timeout and a pre-existing `skills/skill-orchestrate/SKILL.md` budget-ceiling finding unrelated
  to the sapience extension. The complete gate set still runs once at the end of the whole batch.
- **Phase 4, probe correctness fix**: live sampling surfaced a real defect in the Phase-2-shipped
  probe (two fixed literal `session_id` strings, vulnerable to the vault's own repeat-suppression
  accumulating across repeated manual runs). Fixed to mint a unique `session_id` per invocation
  and redeployed; the residual noise is reduced but not eliminated (it is not purely
  session-scoped), and is now documented in the script's own output rather than hidden.

## Verification

- Build: N/A (documentation + one new shell script).
- Tests: `bash -n` and `shellcheck` clean on the new script; degrade path (missing config) exits
  3 with a named reason, no stack trace, no token in output (verified by direct grep against the
  real token value).
- Scoped gate tier (`verify-deploy.sh --only-gate 1,2,3,4,5`): PASS, 16 checks, 0 failures.
- Full `--skip-slow` sweep (diagnostic, not the phase's own discharge criterion): 2 findings, 0
  attributable to this task.
- `check-extension-docs.sh`: clean for the sapience extension (no Rule Q/R/S/U finding) after the
  line-count reconciliation.
- Deployed mirror confirmed: `.claude/context/project/sapience/domain/injection-site-scoping.md`
  exists; `.claude/context/index.json` carries exactly one matching entry.
- Files verified: Yes (all new/modified files read back and confirmed).

## Acceptance Criteria Walkthrough

1. **A session in one repository receives no item making a factual claim about another
   repository — or receives it labelled with its source project.** Not achievable by any
   mechanism available to this repository, per direct measurement: `POST /v1/cli/context`
   ignores `project` (two otherwise-identical calls, differing only in `project`, return
   byte-identical bodies), and the response carries no per-item attribution to label with. This
   is recorded as a measured conclusion in `domain/injection-site-scoping.md`'s Foreclosures 1-2,
   not softened. `verify-sapience-context-scoping.sh` (`--print`) confirmed `RESIDUAL_HOLDS` live
   from this repository: `nvim` (real) vs. a sentinel project returned identical bodies.

2. **The cross-corpus abstraction class is demonstrably still delivered.** No phase in this task
   suppressed, filtered, or narrowed any of the three hooks, `settings-fragment.json`, or
   `sapience-retrieve.sh` (confirmed: both files' diffs against HEAD are empty). The same probe
   run's `--print` output shows a non-empty delivered block (a rule and two facts, each with a
   `(matched: ...)` keyword tail) — the channel still delivers content; nothing here regresses
   it.

3. **Every injection site is covered and enumerated by name.** `domain/injection-site-scoping.md`'s
   table names all three: `SessionStart` (`mcp.py --briefing-text` -> `GET /briefing` +
   `GET /v1/outstanding`, sends no repository identifier), `UserPromptSubmit`
   (`sapience_cli.py hook prompt` -> `POST /v1/cli/context`, sends `project=` but it is ignored),
   `PreToolUse` (`sapience_cli.py hook tool` -> `POST /v1/cli/context`, sends only `file=`, no
   project). The asymmetry (one of three transmits anything at all) is stated explicitly, not
   treated as a uniform surface.

4. **The local half of Leg 1 is actually closed.** Closed by the sibling write-side task, not
   repeated here: `scripts/sapience-remember.sh`'s `provenance` unconditionally carries
   `[repo:<slug>]`, and `rules/sapience-write-path.md` prohibits any instruction surface from
   naming an MCP write tool as a prescribed write path. The only residual is the genuinely
   vendor-owned remainder — server-authored provenance on transcript extraction, which drops the
   `project` field `upload.py`'s `_chunk()` already sends, before the KO is stored. No
   agent-editable write path is left untagged.

5. **Any owner action is written out as an exact, runnable instruction.** Both owner actions in
   `domain/injection-site-scoping.md` are verbatim, sendable text: Owner Action 1 is the vendor
   ask (honor `project` as a hard pre-filter on `POST /v1/cli/context`, or reflect it into
   authored `provenance`, plus exposing `GET /v1/outstanding`'s existing per-project grouping as
   an optional filter), including the two-call falsification example. Owner Action 2 is the
   exact `jq` inspection commands for the machine-wide duplicate hook surface in
   `~/.claude/settings.json`, naming the `retire_machine_wide_sapience_surface` work sited in
   `~/.dotfiles` as the correct owner of that remedy.

## Impacts

- A future reader of the sapience extension's own docs is told plainly, in five places
  (`EXTENSION.md`, `context/project/sapience/README.md`, `index-entries.json`,
  `per-repo-scoping.md`, `vault-model.md`), that primary-session content scoping is NOT closed —
  Gaps 1-4 in the top-level `README.md` are no longer readable as a complete account.
- `verify-sapience-context-scoping.sh` gives a mechanical, falsifiable detector for the day the
  vendor ask lands, rather than relying on manual re-discovery or an unverified assumption either
  way.

## Follow-ups

- The claim-shape heuristic filter (cross-checking a bulleted item's countable claim against this
  repository's own live `specs/state.json`/`specs/ROADMAP.md`) remains a recorded, not built,
  candidate — a separate, exploratory follow-up task, given its measured brittleness risk.
- The owner actions (both) require the user's own action outside this repository: sending the
  vendor ask, and running the named `jq` inspection against `~/.claude/settings.json` to confirm
  the machine-wide duplicate hook surface, whose retirement is tracked in `~/.dotfiles` as
  `retire_machine_wide_sapience_surface`.
- The probe script's residual sampling noise (server-side repeat-suppression not purely
  session-scoped) is documented but not eliminated; a future pass could investigate whether a
  longer inter-call delay or a structurally different prompt per call reduces it further, if the
  probe's reliability becomes load-bearing for an automated consumer.

## References

- Plan: `specs/606_scope_sapience_injection_to_current_repo/plans/02_injection-site-scoping-residual.md`
- Research: `specs/606_scope_sapience_injection_to_current_repo/reports/02_injection-site-scoping-findings.md`,
  `specs/606_scope_sapience_injection_to_current_repo/reports/01_seed-cross-repo-injection.md`
- New domain note: `agent-system/extensions/sapience/context/project/sapience/domain/injection-site-scoping.md`
- New probe script: `agent-system/extensions/sapience/scripts/verify-sapience-context-scoping.sh`
- Sibling write-side closure: `agent-system/extensions/sapience/rules/sapience-write-path.md`,
  `agent-system/extensions/sapience/scripts/sapience-remember.sh`
