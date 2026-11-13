# Research Report: Task #617

**Task**: 617 - Reconcile sapience extension source store with retired machine-wide surfaces
**Started**: 2026-11-13T16:30:00Z
**Completed**: 2026-11-13T16:53:00Z
**Effort**: ~25 minutes
**Dependencies**: Companion task `retire_machine_wide_sapience_surface` (sited in
`/home/benjamin/.dotfiles`, task number 138) -- confirmed `[COMPLETED]`
**Sources/Inputs**: Codebase (source store under `agent-system/extensions/sapience/`), the
companion repository's task artifacts (`/home/benjamin/.dotfiles/specs/138_retire_machine_wide_sapience_surface/`),
live inspection of `$HOME/.claude/settings.json` and `$HOME/.claude.json`, re-running
`install-sapience-mcp-session-hook.sh` and `verify-sapience-mcp.sh` against the live file
**Artifacts**: this report; edits to three source-store files (listed under Findings)
**Standards**: report-format.md, subagent-return.md, source-store-deploy-boundary.md,
no-record-versioning-in-deliverables.md

## Executive Summary

- Precondition confirmed before any edit: companion task 138 in `/home/benjamin/.dotfiles` is
  `[COMPLETED]` and its own `records/04_live-verification.md` plus direct live-file inspection
  both confirm the durable `SessionStart` registration entry is in place and the retired
  machine-wide surfaces (seven permission grants, five hooks, the top-level
  `mcpServers.sapience` merge) are gone from the live, merged files on this machine.
- Three of the four named source-store surfaces asserted a hazard that no longer holds and were
  rewritten to state the current arrangement: `per-repo-scoping.md`'s Hazards section and its
  "divergence from the lean model" paragraph, and `install-sapience-mcp-session-hook.sh`'s header
  comment and its (renamed) `print_registration_note` function.
- `injection-site-scoping.md`'s Owner Action 2 section (the only thing in that file this task's
  trigger touches) was rewritten to describe the current, per-repo-gated hook surface; Owner
  Action 1, both Foreclosure measurements, and the `verify-sapience-context-scoping.sh` pointer
  were left untouched, as required.
- The fourth named surface, `EXTENSION.md` (the actual merge source for `.claude/CLAUDE.md`'s
  Sapience Extension section -- the dispatch's own reference to
  `merge-sources/claudemd.md` does not exist on disk; see Findings), needed no change: it never
  asserted the non-durability hazard in the first place.
- Re-ran `install-sapience-mcp-session-hook.sh` against the live file twice (before and after
  editing it) and both runs reported `(no-op) ... already has the sapience SessionStart hook`,
  satisfying the companion's requested checkable property.
- `verify-sapience-mcp.sh`'s check (d) passes for this repository: `[PASS] (d) SessionStart entry
  present in /home/benjamin/.claude/settings.json`.

## Context & Scope

Dispatch 1 for this task named four source-store surfaces to reconcile against a companion
task's landing: `per-repo-scoping.md`, `install-sapience-mcp-session-hook.sh`,
`injection-site-scoping.md`, and a merge-source file for `.claude/CLAUDE.md`'s Sapience Extension
section. The precondition gate required confirming the companion actually landed before touching
any of the four, since discharging a still-live hazard would be worse than leaving the text
alone. All edits are scoped to `agent-system/extensions/sapience/**` (the source store); no
`.claude/**` deploy path and no file in `/home/benjamin/.dotfiles` was touched.

## Findings

### Codebase Patterns

- **Companion landed, verified two ways.** `/home/benjamin/.dotfiles/specs/TODO.md` shows task
  138 as `[COMPLETED]`, and its summary and `records/01-04` document a durable `SessionStart`
  entry added to `~/.dotfiles/config/claude/settings.json` invoking the byte-identical command
  string `bash $HOME/.claude/hooks/sapience-mcp-register-project.sh 2>/dev/null || echo '{}'`.
  Independently, live inspection in this session confirmed: `jq '.hooks.SessionStart'
  "$HOME/.claude/settings.json"` shows exactly three entries (sleep-inhibitor, lean-lsp,
  sapience-mcp-register-project), `jq '.mcpServers.sapience' "$HOME/.claude.json"` returns
  `null`, and no `mcp__sapience*` grant remains in `$HOME/.claude/settings.json`'s
  `permissions.allow`.
- **The dispatch's surface-4 path does not exist.** `agent-system/extensions/sapience/merge-sources/claudemd.md`
  is not a file on disk. Only `core` and `literature` use the `merge-sources/claudemd.md`
  convention; every other extension, including `sapience`, uses `EXTENSION.md` directly as its
  `.claude/CLAUDE.md` merge source. `EXTENSION.md`'s content was confirmed to byte-match the
  deployed `.claude/CLAUDE.md`'s "## Sapience Extension" section, so it is unambiguously the
  intended surface 4. It was read in full and found to make no durability claim at all (it
  describes the registration hook mechanism neutrally, without asserting non-durability), so no
  edit was needed there -- this is the dispatch's own anticipated "or nothing at all" branch.
- **A dangling cross-reference was removed as a side effect.** `per-repo-scoping.md`'s old
  Hazards bullet referenced "the write-grant residual above," but no write-grant residual is
  defined earlier in that same file (that residual lives in a *different* file,
  `rules/sapience-write-path.md`'s "Accepted Residual" section). Replacing the resolved-hazard
  bullet removed this dangling self-reference along with it.
- **`verify-sapience-mcp.sh` (not a named surface) now carries stale framing too, left alone.**
  Its header comment (~lines 13-18) and its live-check note (~lines 255-263) both still frame the
  surviving top-level `~/.claude.json` `.mcpServers.sapience` entry as "EXPECTED, not drift...
  until a companion task disables `programs.sapience.registerMcpServer`." That companion task has
  landed and the live top-level key is already gone (confirmed above), so this framing is stale.
  This script was not one of the four surfaces named in the dispatch's SCOPE, so it was left
  unedited and the staleness is recorded as a follow-up (see Context Extension Recommendations
  and the task's issue log).

### External Resources

Not applicable -- this task is a self-contained reconciliation between two sibling repositories'
source stores; no external documentation was consulted.

## Recommendations

- File a follow-up task (sited in this repository, since the edit target
  `agent-system/extensions/sapience/scripts/verify-sapience-mcp.sh` lives in this source store)
  to reconcile `verify-sapience-mcp.sh`'s header comment and its live-check note with the
  now-landed companion arrangement, mirroring the rewrite style applied here.
- No other follow-up is needed for the four surfaces this dispatch named: all are now consistent
  with the live arrangement, and the two companion-landing-coordinated follow-ups recorded in
  the companion's own `records/03_nvim-sited-followups.md` (the `mcp-server-ownership.md` worked
  example, and the SF-1 worktree registration gap) remain open and unaffected by this task's
  narrower scope.

## Decisions

- Edited `EXTENSION.md` as the real surface-4 target (the dispatch's named path does not exist),
  rather than creating a new `merge-sources/claudemd.md` file to match the dispatch's literal
  path -- `EXTENSION.md` is already the file the deploy pipeline merges into `.claude/CLAUDE.md`,
  confirmed by direct content comparison, and introducing a second, unused merge-source file
  would only create drift risk for no benefit.
- Made no edit to `EXTENSION.md` itself, having confirmed it asserts no durability claim to
  correct.
- Renamed `install-sapience-mcp-session-hook.sh`'s internal `print_durability_warning` function
  to `print_registration_note`, since its content is no longer a warning about an unresolved
  hazard -- it is an informational note about the two-writer relationship that now holds. No test
  or external caller references the old function name (checked both test files under
  `scripts/tests/`).
- Left `verify-sapience-mcp.sh` unedited, consistent with the dispatch's explicit four-surface
  SCOPE, and recorded its staleness as a follow-up rather than silently absorbing it into this
  task's edit set.

## Risks & Mitigations

- **Risk**: a reader of the now-updated surfaces could assume `verify-sapience-mcp.sh`'s
  companion-task framing is equally current, since the two live in the same extension. 
  **Mitigation**: recorded explicitly as a follow-up, both here and via `issue-record.sh`, rather
  than left to be rediscovered from scratch.
- **Risk**: the installer's renamed function or restructured header comment could regress its
  own idempotency behavior. **Mitigation**: re-ran the script against the live
  `$HOME/.claude/settings.json` after editing and confirmed the no-op path still fires
  byte-identically; also re-ran `verify-sapience-mcp.sh`'s check (d), which passed.

## Context Extension Recommendations

- **Topic**: `verify-sapience-mcp.sh`'s companion-task framing.
- **Gap**: the script's header comment and live-check note still describe the top-level
  `~/.claude.json` `.mcpServers.sapience` entry's survival as contingent on a companion task that
  has, in fact, already landed and removed that entry.
- **Recommendation**: a follow-up task, sited in this repository, should rewrite those two
  comment blocks to state the current (post-landing) arrangement, the same reconciliation this
  task performed for the three documents and the one script named in its own SCOPE.

## Appendix

- Commands used: `jq -r '.active_projects[] | select(.number==138)'`
  `/home/benjamin/.dotfiles/specs/state.json`; `grep -n "138" /home/benjamin/.dotfiles/specs/TODO.md`;
  `jq '.hooks.SessionStart'`/`jq '.mcpServers.sapience'`/`jq -r '.permissions.allow[]?'` against
  the live `$HOME/.claude/settings.json` and `$HOME/.claude.json`; two runs of
  `bash agent-system/extensions/sapience/scripts/install-sapience-mcp-session-hook.sh` (before and
  after editing it); one run of `bash agent-system/extensions/sapience/scripts/verify-sapience-mcp.sh`.
- Files edited (all under the source store, none under `.claude/**` or `/home/benjamin/.dotfiles`):
  - `agent-system/extensions/sapience/context/project/sapience/domain/per-repo-scoping.md`
  - `agent-system/extensions/sapience/context/project/sapience/domain/injection-site-scoping.md`
  - `agent-system/extensions/sapience/scripts/install-sapience-mcp-session-hook.sh`
- Files read and confirmed to need no change: `agent-system/extensions/sapience/EXTENSION.md`.
- Companion task artifacts read:
  `/home/benjamin/.dotfiles/specs/138_retire_machine_wide_sapience_surface/summaries/01_retire-machine-wide-sapience-summary.md`,
  `records/03_nvim-sited-followups.md`, `records/04_live-verification.md`.
