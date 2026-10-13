# Research Report: Task #296

**Task**: 296 - Repo hygiene: remove stale init.lua.backup, regenerate project-overview.md, fix README.md link
**Started**: 2026-10-08T18:30:00Z
**Completed**: 2026-10-08T18:50:00Z
**Effort**: ~20 minutes
**Dependencies**: None
**Sources/Inputs**: Codebase exploration (git log, diff, grep), `.claude-extensions.json`, `.syncprotect`, prior task 300 archive
**Artifacts**: specs/296_repo_hygiene_remove_stale_initluabackup_/reports/01_repo-hygiene-three-fixes.md
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- **Issue 1 (`init.lua.backup`)**: confirmed tracked, byte-identical to `init.lua`, with no
  code/doc reference anywhere outside `specs/` review/TODO text. No repo-wide `.backup` naming
  convention exists (the only other `backup` hits are an unrelated Lua module name and
  task-specific artifacts). Safe to delete outright; no `.gitignore` carve-out needed.
- **Issue 2 (`project-overview.md`)**: the file's true edit location, per the source-store/deploy
  boundary rule, is `agent-system/extensions/core/context/repo/project-overview.md` (confirmed via
  `.claude-extensions.json`'s `extensions.core.source_dir`, and already byte-identical to the
  deployed `.claude/context/repo/project-overview.md`) — this is already reflected in task 296's
  `file_scope` in `state.json`. **The `.syncprotect` entry the issue asked for already exists**
  (added in an unrelated prior task, 2026-08-09) — that half of the fix is done. What remains
  undone is the actual regeneration. Critically, `/project-overview` (`skill-project-overview`) is
  an **interactive, `AskUserQuestion`-driven, direct-execution skill** that **creates a new task**
  with a research artifact rather than writing `project-overview.md` itself — and per the settled
  finding in archived task 300 (`askuserquestion_unreachable_in_subagents`), `AskUserQuestion` is
  categorically unreachable from any dispatched subagent. A later implementation phase of task 296
  dispatched as a subagent (e.g. `general-implementation-agent`) **cannot** invoke `/project-overview`
  to satisfy this fix.
- **Issue 3 (`README.md:185`)**: confirmed broken — links to `.claude/README.md`, which does not
  exist. `.claude/docs/docs-README.md` exists and is the real architecture entry point (per
  `.claude/CLAUDE.md`'s own Quick Reference: "Architecture: `.claude/docs/docs-README.md`").
  `README.md` at repo root is an ordinary hand-edited file, not under the source-store/deploy
  boundary, so the fix is a direct one-line edit. One secondary, out-of-scope observation:
  `docs-README.md` itself has a self-referential `../README.md` header link that also resolves to
  the nonexistent `.claude/README.md` — not part of this task's `file_scope`, noted for awareness
  only.
- **Recommended approach**: implement issues 1 and 3 as direct, mechanical edits. For issue 2,
  do not attempt to invoke `/project-overview` from a dispatched implementation agent; instead
  have the implementation phase author `project-overview.md` content directly (using the same
  auto-scan categories `skill-project-overview` Stage 1 performs — directory structure, language
  detection, package managers/build tools, frameworks — all of which are already evident from this
  repository's `CLAUDE.md`/`.claude/CLAUDE.md` and extension manifests) at the source-store path,
  skipping the interactive interview, since task 296 already owns this file in its `file_scope`
  and no interactive clarification is strictly required to replace the generic template with a
  real description.

## Context & Scope

Scope is the three independent, no-shared-file issues named in the task description, each
investigated for (a) current on-disk state, (b) git history/tracking status, and (c) the correct
fix location per this repo's own conventions (source-store/deploy boundary, `.syncprotect`,
subagent tool-reachability).

## Findings

### Codebase Patterns

**Issue 1 — `init.lua.backup`**
- `git ls-files init.lua.backup` confirms it is tracked.
- `diff init.lua init.lua.backup` is empty (byte-identical).
- `git log --follow -- init.lua.backup` traces back through the pre-vault-numbering era
  ("first pass adapting lunar vim", "fixed lsp", etc.) — confirms it is a long-stale leftover,
  not a recent artifact.
- `git log -1` shows `init.lua.backup` last touched by "task 516: create implementation plan"
  (2026-05-02) while `init.lua` was last touched by "task 518: complete research" (2026-05-03) —
  the two files diverged in commit history by a day, yet remain content-identical today, which is
  exactly the "silent drift risk" the issue describes (they happen to still match, but nothing
  enforces that).
- `grep -rn "init.lua.backup"` across `*.lua`/`*.sh`/`*.md` (excluding `specs/`) returns no hits —
  nothing in the live config or tooling reads or depends on this file.
- No generic `*.backup` convention exists in the active tree: the only other `backup` hits in
  `git ls-files` are `lua/neotex/plugins/ai/shared/extensions/settings_backup.lua` (an unrelated
  module name, not a backup-of-a-file convention), and task-archive-scoped artifacts under
  `specs/archive/` and `specs/vault/` (a literature-index task, a `.claude`-wipe tarball, and a
  recovered-PDF path file) — none of these establish or depend on an `init.lua.backup`-style
  convention.
- `.gitignore` has no `*.backup` or similar pattern; the closest entries
  (`/.claude-settings-backup/`, `/.opencode-settings-backup/`, `**/untracked-backup-*/`) are
  directory patterns for unrelated settings-backup and git-snapshot mechanisms, not a precedent
  for a stray `.backup` sibling file.
- **Conclusion**: deletion is the correct fix; the `.gitignore` alternative the issue floated is
  not supported by any existing convention, and git history on `init.lua` already covers the
  "preserve prior states" need.

**Issue 2 — `project-overview.md`**
- `.claude/context/repo/project-overview.md` (deployed) still begins with
  `<!-- GENERIC TEMPLATE: ... -->` and is byte-identical to
  `agent-system/extensions/core/context/repo/project-overview.md` (source store copy).
- `.claude-extensions.json`'s top-level `source_dir` key is `null` (there is no single top-level
  source dir — it's per-extension); `.extensions.core.source_dir` resolves to
  `/home/benjamin/.config/nvim/agent-system/extensions/core`, confirming the correct edit target
  is the source-store copy, per `source-store-deploy-boundary.md`. This matches task 296's
  existing `file_scope` entry `agent-system/extensions/core/context/repo/project-overview.md`
  (already set in `state.json`, i.e. this resolution call was already made at task-creation time).
- `.syncprotect` at the repo root **already contains** the line `context/repo/project-overview.md`
  (added 2026-08-09 by an unrelated task, "task 985 phase 3: documentation notes and the dead
  syncprotect line"). The issue's instruction to "add ... to `.syncprotect`" is therefore already
  satisfied and needs no further action — only the regeneration itself remains.
- `/project-overview` (`agent-system/extensions/core/commands/project-overview.md` →
  `skill-project-overview`) is explicitly documented as NOT writing `project-overview.md`
  directly: "The skill does NOT write `project-overview.md` directly. It creates a task and
  research artifact, then guides the user to `/plan` and `/implement`." Its frontmatter declares
  `allowed-tools: Bash, Read, Write, Edit, Glob, Grep, AskUserQuestion` and `context: direct`
  (i.e. it is a root-session direct-execution skill, never dispatched as a subagent) — Stage 2 of
  its 3-stage flow is an interactive interview via `AskUserQuestion`.
- Archived task 300 (`specs/archive/300_askuserquestion_unreachable_in_subagents/`) settled, by
  live measurement, that `AskUserQuestion` is categorically unreachable from any `Agent`-tool
  dispatch of a named subagent type, and rehomed every other such gate out of subagent-dispatched
  agents accordingly (e.g. `/meta`'s interview was moved into `skill-meta`'s own pre-delegation
  stage). `skill-project-overview` already correctly lives outside subagent dispatch (it is
  `context: direct`), so there is no latent bug here — but it does mean a *later phase of task
  296 itself*, if that phase is executed by a dispatched implementation agent, cannot invoke
  `/project-overview` to satisfy the fix; the interactive flow is simply unreachable from that
  vantage point.
- Separately, even if reachable, `/project-overview`'s output is a *new task* in `[RESEARCHED]`
  status with its own research artifact, not a direct edit to task 296's own artifacts — using it
  would mean spawning an unrelated task rather than closing this one's issue 2 directly.

### External Resources

No external (web) research was needed — this is a self-contained repo-hygiene task resolved
entirely by codebase/state inspection.

## Recommendations

- **Issue 1**: delete `init.lua.backup` via `git rm init.lua.backup`. No `.gitignore` entry is
  needed (nothing suggests a repo-wide backup-file convention). Verification: `git status --short`
  shows the removal staged; re-run the `grep -rn "init.lua.backup"` sweep post-delete to confirm no
  dangling reference remains (it already returns none pre-delete, so this is a no-regression
  check, not an expected find).
- **Issue 2**: edit `agent-system/extensions/core/context/repo/project-overview.md` directly (never
  the deployed `.claude/context/repo/project-overview.md` copy, which is regenerated) to replace
  the generic template with a real description of this repository: the dual-layer extension
  architecture, the `specs/`-based task lifecycle, the loaded extensions (core, nix, nvim, email,
  lean, literature, memory — per `.claude-extensions.json`), and key entry points (`CLAUDE.md`,
  `.claude/CLAUDE.md`, `.claude/docs/docs-README.md`). Do not attempt to invoke `/project-overview`
  from an implementation-phase subagent — it is unreachable there (`AskUserQuestion`) and would in
  any case spawn a separate task rather than closing this one. Confirm `.syncprotect` already
  covers this path (it does; no change needed there). After editing the source-store copy, the
  deployed `.claude/context/repo/project-overview.md` is a regenerated artifact and does not need
  (and per `.syncprotect`, will not have) a parallel hand-edit — but implementers should verify the
  deploy mechanism actually re-syncs it (or hand-mirror it once) so the live `.claude/` copy isn't
  left stale relative to the source store until the next full regenerate.
- **Issue 3**: edit `README.md:185`, replacing `[.claude/README.md](.claude/README.md)` with
  `[.claude/docs/docs-README.md](.claude/docs/docs-README.md)` (the actual, existing architecture
  entry point per `.claude/CLAUDE.md`'s own Quick Reference). This is a plain root-level file edit,
  not subject to the source-store boundary.

## Decisions

- Issue 1: delete, do not `.gitignore`-exempt — no convention supports retaining a parallel
  `.backup` file, and git history already serves the "preserve prior states" purpose.
- Issue 2: edit location is the source-store copy
  (`agent-system/extensions/core/context/repo/project-overview.md`), consistent with the task's
  pre-set `file_scope`; the `.syncprotect` sub-step is already satisfied and should not be
  redundantly re-applied; the regeneration itself must be done as a direct content edit (by
  whichever phase/agent has the ability to write it) rather than via a chained `/project-overview`
  invocation, which is both unreachable from a subagent and semantically the wrong mechanism
  (it spawns a new task rather than completing this one).
- Issue 3: edit target is `.claude/docs/docs-README.md` (per CLAUDE.md's own Quick Reference
  naming it the architecture entry point), not `.claude/CLAUDE.md` directly — the issue named
  both as acceptable; `docs-README.md` is preferred because it is purpose-built as a documentation
  hub, whereas `.claude/CLAUDE.md` is explicitly machine-generated and self-describes as "do not
  edit directly" rather than as a navigable README.

## Risks & Mitigations

- **Risk**: hand-editing the deployed `.claude/context/repo/project-overview.md` directly (instead
  of the source-store copy) would be silently discarded on the next full sync/regenerate per
  `source-store-deploy-boundary.md`. **Mitigation**: edit only the source-store path; the research
  above already confirms which path that is.
- **Risk**: an implementation phase attempting to literally follow the issue text ("run
  `/project-overview`") inside a dispatched subagent would stall or fail silently on the
  unreachable `AskUserQuestion` call. **Mitigation**: documented above; the plan phase should
  author content directly instead.
- **Minor, out-of-scope risk noted for awareness**: `.claude/docs/docs-README.md`'s own header
  link `[Architecture](../README.md)` also resolves to the nonexistent `.claude/README.md`. This
  is a pre-existing, separate broken link not named in this task's `file_scope`/related files, and
  is not recommended for inclusion in this task's fix — flagged only so a future reviewer doesn't
  mistake it for a regression introduced by this task's issue-3 fix.

## Context Extension Recommendations

- **Topic**: none — this is a `meta`/repo-hygiene task type and `.claude/context/` already fully
  documents the source-store/deploy boundary, `.syncprotect` mechanics, and the
  `AskUserQuestion`-unreachability constraint (via archived task 300's changes). No new context
  file is warranted.

## Appendix

- Search queries/commands used: `git ls-files`, `git log --follow`, `diff`, `grep -rn` (scoped
  exclusions for `.git/`, `specs/archive/`, `specs/296_*`), `jq` against `.claude-extensions.json`
  and `specs/state.json`, `cat .syncprotect`.
- Key files read: `.claude-extensions.json`, `.syncprotect`, `README.md`,
  `.claude/context/repo/project-overview.md`,
  `agent-system/extensions/core/context/repo/project-overview.md`,
  `agent-system/extensions/core/commands/project-overview.md`,
  `agent-system/extensions/core/skills/skill-project-overview/SKILL.md`,
  `specs/archive/300_askuserquestion_unreachable_in_subagents/summaries/01_rehome-askuserquestion-gates-summary.md`,
  `.claude/docs/docs-README.md`.
