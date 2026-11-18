# Implementation Summary: Task #526

- **Task**: 526 - Announce completion and input-needed over TTS from the source store, with a cooldown
- **Status**: [COMPLETED]
- **Started**: 2026-11-18T08:00:00Z
- **Completed**: 2026-11-18T09:00:00Z
- **Effort**: ~4 hours (estimated 8.5h)
- **Dependencies**: Territory edge to the open record `reword_dead_lifecycle_command_prose_per_class` (serialization only, no subject overlap)
- **Artifacts**: plans/01_tts-completion-input-needed.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

Made an `/orchestrate` run's completion and an input-needed wait each announce themselves exactly
once, distinguishably by ear, with a pane-keyed cooldown gate collapsing any repeat into a single
utterance. Three coupled source-store changes land this: a cooldown gate plus a new `--stop` mode
in `tts-notify.sh`; the Stop hook's no-marker branch wired to call that new mode; and the
`Notification` matcher widened to include `idle_prompt` in both declaring surfaces. Two
documentation surfaces that previously asserted the opposite of the landed behavior are
reconciled, three new regression suites are added and registered, and the whole set is
redeployed and demonstrated against the real measured notification cadence.

## What Changed

- `agent-system/extensions/core/hooks/tts-notify.sh` -- Added `TTS_COOLDOWN`/`COOLDOWN_FILE`
  config, `cooldown_blocked()`/`cooldown_stamp()` helpers, a single cooldown gate covering all
  three modes, and a new `--stop` mode speaking "Tab N done" (distinguishable from the bare
  "Tab N" interactive utterance). `--lifecycle` and interactive vocabularies left byte-identical.
- `agent-system/extensions/core/hooks/claude-stop-notify.sh` -- The no-workflow-marker branch now
  calls `tts-notify.sh --stop` (guarded, same `-f`-test + `2>/dev/null || true` shape as the
  sibling `wezterm-notify.sh` call), after the existing wezterm call. The `agent_id` subagent
  guard and the global `workflow-active-*` glob suppression loop are byte-identical (verified
  via `git diff`: zero changed lines in either region).
- `agent-system/extensions/core/merge-sources/settings-hooks.json`,
  `agent-system/extensions/core/root-files/settings.json` -- Widened the `Notification` matcher
  from `permission_prompt|elicitation_dialog` to `permission_prompt|idle_prompt|elicitation_dialog`
  in both surfaces (confirmed byte-identical via `jq`).
- `agent-system/extensions/core/scripts/lifecycle-notify.sh` -- Header comment only (zero
  executable lines changed): restated the `orchestrate-active` decision table honestly (that
  marker has zero writers in the source store, so its auto-suppression path does not currently
  engage) and correctly attributed Stop-hook TTS to `claude-stop-notify.sh`'s own
  workflow-active-marker mechanism.
- `agent-system/extensions/nvim/context/project/neovim/guides/tts-stt-integration.md` -- Restated
  the Stop-hook claim to the implemented behavior, documented `idle_prompt` and the Stop-branch
  completion row in the Notification Event Types table, documented the three modes and the
  cooldown contract, updated the embedded matcher snippet, and added `TTS_COOLDOWN` to the
  environment-variable table.
- Created `agent-system/extensions/core/scripts/tests/test-tts-notify.sh` (9 cases: utterance
  vocabularies, cooldown in both directions, pane independence, `TTS_ENABLED=0`).
- Created `agent-system/extensions/core/scripts/tests/test-claude-stop-notify.sh` (7 cases:
  `agent_id` guard, global marker suppression including a foreign session's marker, single
  `--stop` invocation on the no-marker path, valid JSON + exit 0 on every path, a sandbox-copy
  regression anchor proving non-vacuousness).
- Created `agent-system/extensions/core/scripts/tests/test-notification-matcher-parity.sh` (3
  cases: byte-equality of the two surfaces' matchers, `idle_prompt` presence, a deliberately
  divergent fixture pair proving the check can fail).
- `agent-system/extensions/core/manifest.json` -- Registered the three new test suites in
  `provides.scripts` via `sync-manifest-scripts.sh --write`.
- `agent-system/extensions/core/scripts/tests/suite-classification.data` -- Registered the three
  new suites (unit class) plus, as the real cause of an acceptance-criterion-4 gap, discovered
  they were initially missing rows; added.
- `agent-system/extensions/nvim/index-entries.json` -- Reconciled the derived `line_count` for
  `tts-stt-integration.md` (433 -> 458) via the redeploy's own regeneration step.
- `specs/state.json` -- Widened task 526's own declared `file_scope` by one entry
  (`suite-classification.data`) so the mechanically-dropped fix from the Phase-Commit Containment
  Self-Check could land via a scoped follow-up commit, per
  `context/standards/git-staging-scope.md`'s documented producer/consumer contract for
  `proposed_file_scope`.
- Redeployed the source store into this repository's `.claude/` tree via `deploy-headless.sh`
  (`RESULT=landed_verify_clean`).

## Decisions

- The cooldown lands uniformly across all three `tts-notify.sh` modes, placed once after the
  existing `TTS_ENABLED`/`piper` early-exit guards, so any current or future double registration
  collapses to one utterance rather than requiring a per-mode gate.
- Cooldown window: 75 seconds, non-sliding (stamp written only on a path that reaches `speak()`),
  env-overridable via `TTS_COOLDOWN`. Stamp lives at
  `${XDG_RUNTIME_DIR:-/tmp}/claude-tts-cooldown-${UID}-${WEZTERM_PANE:-nopane}` (ephemeral
  per-pane runtime state, not a repo-local evidence surface), keyed by `WEZTERM_PANE` so
  concurrent panes never suppress each other, failing open on any file-operation error.
- `--stop` is a third, distinct mode (not a reuse of `--lifecycle`), satisfying both
  distinguishability and the "lifecycle vocabulary unchanged" constraint simultaneously.

## Plan Deviations

- None in the implementation itself. Two verification-time observations, both out of this
  task's own file scope and recorded via `issue-record.sh` rather than fixed here:
  - `test-lint-hook-registration-paths.sh`'s frozen `theorem_proving_in_lean4` exemplar fixture
    (dated 2026-11-17, owned by the explicitly out-of-scope `hook_registration_set_lint_assertion`
    record) hardcodes the pre-widening matcher and now reports a drift finding against this
    task's correctly widened matcher. Not fixed here per this task's own Non-Goals.
  - `test-lint-fixture-dependency-declaration.sh` has no row in `suite-classification.data`; this
    predates this task (introduced by a different, already-completed task) and is reported, not
    fixed.

## Verification

- Build: N/A (shell scripts and JSON/Markdown, no compiled build step)
- Tests: Passed -- all three new suites green individually and via scoped `run-all.sh --only`
  runs; `deploy-headless.sh`'s own inline `verify-deploy.sh --skip-slow` passed 41/41 checks
  (0 failures) during Phase 5's redeploy. The complete unflagged `verify-deploy.sh`/`run-all.sh`
  battery is deferred to the once-per-batch stage per this dispatch's Batch Gate Deferral
  directive, not independently re-run here.
- Files verified: Yes -- `jq` confirms the widened matcher in both settings surfaces; `git diff`
  confirms zero executable-line drift in the two guard-preserving/header-only edits; the deployed
  `.claude/` copies of every edited file are byte-identical to the source store.

## Acceptance Criteria (from the dispatch)

1. **Exactly one, distinguishable announcement on completion**: confirmed against the deployed
   `claude-stop-notify.sh` -- no-marker path fires exactly one `tts-notify.sh --stop` ("Tab N
   done"); the Notification path fires the bare "Tab N" with no "done". Final by-ear confirmation
   is left to the operator's next real `/orchestrate` run, not claimed here.
2. **Idle re-fire cooldown, against the real cadence**: replayed all 199 inter-announcement
   intervals from `~/Projects/Logos/Theory/specs/tmp/claude-tts-notify.log` against the deployed
   `tts-notify.sh`. Measured: 63 intervals in the 10-70s band (all suppressed), 11 under 2s (all
   suppressed, a subset of the band), 113 beyond 70s (all fired). Zero exceptions in either
   direction. (The dispatch's own cited figures, 65 and 21 respectively, were measured at an
   earlier point against a log that has since grown by a few more entries -- re-measured here
   directly against live state rather than assumed unchanged.)
3. **Mid-orchestrate pause stays silent**: both the `agent_id` subagent guard and the global
   `workflow-active-*` marker suppression (including a foreign session's marker) reach zero TTS
   invocations against the deployed hook.
4. **Matcher parity asserted by a check**: `test-notification-matcher-parity.sh` passes and is
   discovered by `run-all.sh` with no `--only` filter (confirmed after closing a
   `suite-classification.data` registration gap found along the way).
5. **No contradicted documentation claim**: both reconciled files are byte-identical between
   source store and deployed tree; a fresh end-to-end re-read found no surviving stale claim.
6. **`TTS_ENABLED=0` disables everything**: zero fires and an unperturbed (never-created) cooldown
   stamp across all three `tts-notify.sh` modes and the deployed `claude-stop-notify.sh`'s
   no-marker path.

## Impacts

- An `/orchestrate` run reaching completion will now announce itself by voice (in addition to the
  WezTerm tab-color change that already fired).
- An actionable "waiting for input" moment (`idle_prompt`) now has a live trigger for the first
  time; its re-fire cadence is cooled down so it degrades to one utterance rather than a
  repeating nuisance.
- Downstream, differently-owned records (`orphan_sweep_for_removed_merge_target_entries`,
  `hook_registration_set_lint_assertion`) retain their own territory unchanged; this task recorded,
  but did not attempt to close, the one collision it surfaced in the latter's frozen fixture.

## Follow-ups

- `hook_registration_set_lint_assertion`'s own fixture owner should refresh the frozen
  `theorem_proving_in_lean4` exemplar (case 23b) to the new matcher value, or otherwise account
  for the drift this task's matcher widening introduced against that frozen snapshot.
- `test-lint-fixture-dependency-declaration.sh`'s missing `suite-classification.data` row
  (pre-existing, from a different completed task) remains open for whichever task owns that gap.
- The deployed `root-files/settings.json`-seeded `.claude/settings.json` in OTHER already-deployed
  repositories (outside this one) will not pick up the widened matcher until their own next
  resync/redeploy; this task proves the fix at the source-store surface and via the parity check,
  not by asserting every already-deployed repo's content (explicitly out of scope per the plan's
  own Risks table).

## References

- plans/01_tts-completion-input-needed.md
- reports/01_tts-completion-input-needed.md
- Issue log entries (classes: scope excursion, verification collision, gate collision,
  measurement, process mistake caught and corrected)
