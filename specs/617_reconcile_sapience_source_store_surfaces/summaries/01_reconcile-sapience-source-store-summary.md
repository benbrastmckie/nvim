# Implementation Summary: Task #617

- **Task**: 617 - Reconcile sapience extension source store with retired machine-wide surfaces
- **Status**: [COMPLETED]
- **Started**: 2026-11-13T00:00:00Z
- **Completed**: 2026-11-13T00:50:00Z
- **Effort**: ~1 hour
- **Dependencies**: Companion work `retire_machine_wide_sapience_surface` (sited in
  `/home/benjamin/.dotfiles`) -- re-confirmed landed in Phase 1
- **Artifacts**: plans/01_reconcile-sapience-source-store.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

Reconciled the remaining sapience extension source-store surfaces that still described the
machine-wide `SessionStart`/`mcpServers.sapience` retirement as a pending companion gap, now that
the companion has landed and the durable registration entry has a confirmed owner. Four phases:
re-confirm the landed arrangement, rewrite two scripts' companion-gated comment blocks,
reconcile `EXTENSION.md`'s registration-hook sentence, and redeploy plus sweep for the
acceptance properties.

## What Changed

- `agent-system/extensions/sapience/scripts/verify-sapience-mcp.sh` -- three comment blocks
  restated: the header's top-level-entry paragraph (no top-level entry exists on this machine;
  registration is per-project; `--retire-global` has nothing to retire here), check (d)'s
  failure note (replaced the "reset ... on every home-manager switch" wipe premise with the
  accurate "`hooks` remains ENFORCED, but the dotfiles entry restores rather than removes it"
  framing), and the trailing conditional NOTE (a surviving top-level entry is now framed as a
  stale leftover, not an expected machine-wide registration pending a companion task).
- `agent-system/extensions/sapience/scripts/setup-sapience-mcp.sh` -- header paragraph restated:
  no top-level entry is written by this machine's home-manager activation any more (the
  `sapienceMcpServer` block and `registerMcpServer` option have been retired), so
  `--retire-global` is an ordinary cleanup action rather than a deliberately inert one.
- `agent-system/extensions/sapience/EXTENSION.md` -- the "Per-repo activation" paragraph's
  registration-hook sentence now names the companion-owned durable entry in
  `~/.dotfiles/config/claude/settings.json` as the writer that survives a `home-manager switch`,
  with this extension's own installer as the converging second writer, agreeing with
  `per-repo-scoping.md`'s Hazards section. Reflowed to stay within `check-extension-docs.sh`'s
  60-line Rule U limit after the initial rewording pushed it to 61-62 lines (deviation, see
  below); the hook-surface count sentence ("six hook surfaces total, five extension-merged") is
  unchanged.
- Deployed `.claude/` tree redeployed twice (once before, once after the EXTENSION.md line-count
  fix) so the merged `.claude/CLAUDE.md` Sapience Extension section is current.

No file under `/home/benjamin/.dotfiles` and no file under `.claude/**` was hand-edited; the
deploy is the only path by which `.claude/**` changed.

## Scope Judgment: `verify-sapience-mcp.sh` and `setup-sapience-mcp.sh` Beyond the Dispatch's Four Named Surfaces

The dispatch named four surfaces (`per-repo-scoping.md`, `install-sapience-mcp-session-hook.sh`,
`injection-site-scoping.md`, and a `merge-sources/claudemd.md` path that turned out to be
`EXTENSION.md`). The planning stage found two further scripts in the same source store still
asserting the companion-gated gap and brought them into this task's scope rather than deferring
them again, for two reasons recorded in the plan's Decisions section: (1) the dispatch's own
acceptance criterion 1 is worded source-store-wide ("No surface in the source store asserts..."),
not limited to the four named paths, and `verify-sapience-mcp.sh`'s check (d) failure note was a
literal instance of the forbidden wipe-premise wording; (2) leaving `setup-sapience-mcp.sh`'s
sibling claim about the top-level `.mcpServers.sapience` entry standing would have reproduced the
exact "reader assumes this is current too" risk the research report flagged, at the cost of one
comment block. Both edits are restricted to comment lines; no executable line changed in either
script.

## Decisions

- Reversed the research dispatch's earlier deferral of `verify-sapience-mcp.sh` (see Scope
  Judgment above) rather than leaving it for a follow-up task.
- `EXTENSION.md` received the minimal adjustment the original dispatch anticipated, rather than
  the "or nothing at all" branch the research phase chose, because the prior sentence was
  incomplete (attributed registration solely to this extension's own installer) rather than
  false, but left it disagreeing with `per-repo-scoping.md` on who owns the durable entry.
- No `merge-sources/claudemd.md` file was created; `EXTENSION.md` is the byte-confirmed real
  merge source the deploy pipeline consumes.

## Plan Deviations

- **Phase 4, Task 4.1** altered: the first redeploy's own internal fast gates (gate3 doc-lint)
  caught that Phase 3's `EXTENSION.md` rewording pushed the file past `check-extension-docs.sh`'s
  60-line Rule U limit (61 lines, then still 61 after a partial trim, finally reflowed to exactly
  60). Re-ran the scoped gates (`verify-deploy.sh --only-gate 3,26 --skip-slow`) to confirm PASS
  before redeploying a second time. No content requirement was dropped -- the companion-owned
  durable writer, the converging second-writer framing, and the unchanged hook-surface count are
  all still present in the final 60-line version.

## Verification

- Build: N/A (no build step for this task type)
- Tests: `bash -n` passes on both edited scripts; `verify-sapience-mcp.sh` reports check (d)
  `[PASS] (d) SessionStart entry present in /home/benjamin/.claude/settings.json`;
  `setup-sapience-mcp.sh --dry-run` runs clean; `install-sapience-mcp-session-hook.sh` reports
  `(no-op) /home/benjamin/.claude/settings.json already has the sapience SessionStart hook`;
  `verify-deploy.sh --only-gate 3,26 --skip-slow` (the scoped discharge for this phase's own
  touched files, per the dispatch's Batch Gate Deferral directive) reports `PASS -- 3 check(s),
  0 failure(s)`.
- Files verified: Yes -- deployed `.claude/CLAUDE.md` Sapience Extension section confirmed
  byte-identical to the edited `EXTENSION.md`; whole-source-store sweep for `home-manager switch`
  (5 hits) confirmed none asserts the registration entry is wiped;
  `injection-site-scoping.md`'s Owner Action 1, Foreclosure 1, Foreclosure 2, and the
  `verify-sapience-context-scoping.sh` pointer are all present; `per-repo-scoping.md`'s
  one-session-start removal lag note is present.
- **Full gate set**: per the dispatch's Batch Gate Deferral directive, the complete
  `verify-deploy.sh` battery is deferred to the batch-level run at the end of this
  `/orchestrate` invocation, not independently run to green by this phase. `deploy-headless.sh`'s
  own internal fast-gate run (the same battery, inline) reported `landed_verify_red` both times
  this phase ran it, with 3 of 43 checks failing: gate10 (a 60s timeout kill, transient, no
  content relation) and gate20 (orchestrator context-budget lock; eager-load total over its
  recorded baseline, dominated by `skills/skill-orchestrate/SKILL.md` independently exceeding its
  own size ceiling). Both are pre-existing/sibling-task conditions unrelated to the sapience
  surfaces this task edited -- this task's own `EXTENSION.md` trim measurably reduced the
  eager-load overage (145B over, then 44B over) rather than causing it. Recorded via
  `issue-record.sh`.
- `verify-sapience-mcp.sh`'s overall exit is 1 because check (e) fails on an unrelated,
  pre-existing residual (11/7 sapience permission grants) that the script's own existing comment
  already documents as expected for a repository that loaded sapience before the grant was
  narrowed to 7. Check (d) -- the acceptance bar's named check -- is `[PASS]`.

## Impacts

- A future reader of any of the three edited scripts or `EXTENSION.md` will see the current
  registration-durability arrangement (companion-owned dotfiles entry + this extension's
  converging installer), not a stale assertion that a pending companion task still needs to land.
- `--retire-global` in `setup-sapience-mcp.sh` is now described accurately as an ordinary cleanup
  action rather than a deliberately inert one, since there is no longer a companion task gating
  its usefulness.

## Follow-ups

- None required by this task. The two pre-existing, unrelated conditions noted under
  Verification (gate20's context-budget overage, dominated by `skill-orchestrate/SKILL.md`'s own
  ceiling excess, and `verify-sapience-mcp.sh` check (e)'s 11/7 grant residual) are both
  out-of-scope, sibling-task-attributable conditions recorded via `issue-record.sh` rather than
  follow-up tasks spawned from here.

## References

- `specs/617_reconcile_sapience_source_store_surfaces/plans/01_reconcile-sapience-source-store.md`
- `specs/617_reconcile_sapience_source_store_surfaces/reports/01_reconcile-sapience-source-store.md`
- `agent-system/extensions/sapience/context/project/sapience/domain/per-repo-scoping.md`
- `agent-system/extensions/sapience/context/project/sapience/domain/injection-site-scoping.md`
