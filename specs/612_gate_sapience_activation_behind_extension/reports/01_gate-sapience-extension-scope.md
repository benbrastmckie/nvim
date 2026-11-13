# Research Report: Task #612

**Task**: 612 - Gate every Sapience activation surface behind the sapience extension so Sapience runs only in repos that load it
**Started**: 2026-11-13T05:30:00Z
**Completed**: 2026-11-13T05:48:00Z
**Effort**: medium
**Dependencies**: Task 611 (completed — repo_tag_sapience_write_paths)
**Sources/Inputs**: Codebase (this repo and `/home/benjamin/.dotfiles`), `specs/state.json`/`TODO.md` in both repos, `agent-system/extensions/sapience/**`, `agent-system/extensions/lean/**`, loader/merge engine source, `.claude/rules/sapience-write-path.md`
**Artifacts**: - this report
**Standards**: report-format.md, subagent-return.md, source-store-deploy-boundary.md (Task Siting subsection)

## Executive Summary

- **Blocking finding, before anything else**: task 612's dispatched free-text `description`
  field is not its own task's instructions. It is a verbatim, word-for-word duplicate of the
  description that belongs to a separate, correctly-sited `.dotfiles` task (`project_number 138`,
  `retire_machine_wide_sapience_surface`, `status: not_started`). Executing it literally would
  mean editing `.dotfiles`-owned files (`modules/home/services/sapience.nix`,
  `config/claude/settings.json`, `docs/sapience.md`) from inside this repository, which contradicts
  task 612's own `file_scope` and the Task Siting rule the description itself cites.
- Task 612's `file_scope`, `title`, `project_name` (`gate_sapience_activation_behind_extension`),
  and physical siting (`specs/612_.../` under `/home/benjamin/.config/nvim`) all agree, independent
  of the broken description text: this task is the **first half** — build the per-repo Sapience
  activation surface inside `agent-system/extensions/sapience/` — not the removal half.
- The ordering constraint embedded in the (misplaced) description, read literally against task
  612, is self-referentially paradoxical: it calls task 612 "the second half" waiting on a
  companion identified by task 612's own project name. Read correctly (task 612 = first half,
  dotfiles-138 = second half, `not_started`), the real-world dependency direction is the opposite
  of what the text says: dotfiles-138 must wait on task 612, not vice versa, and nothing blocks
  task 612 from proceeding now.
- The hard technical piece this task needs — a per-repository, extension-driven mechanism for
  registering an MCP server in `~/.claude.json` — already has a complete, shipped precedent in
  this repository: the `lean` extension's `install-lean-lsp-session-hook.sh` +
  `hooks/lean-lsp-register-project.sh` + `scripts/setup-lean-mcp.sh` triad. This resolves what
  would otherwise be the single largest feasibility risk.
- The settings-merge engine (`lua/neotex/plugins/ai/shared/extensions/merge.lua`) already fully
  supports merging a Claude-Code-native `hooks` object (not just `permissions.allow`) into a
  consuming repo's `.claude/settings.local.json`, with correct dedup and clean removal on
  unload — confirmed by reading the merge/unmerge code paths directly (an uncommitted local fix
  in the working tree hardens an edge case in this same code, not the base capability).
- Recommended action for this research dispatch: do **not** attempt to plan or implement the
  description's literal (removal) content. Record the defect (done, via `issue-record.sh`),
  reconstruct task 612's real scope from `file_scope` + title + the codebase evidence below, and
  raise a `user_decision` so a human confirms the description should be corrected (or the
  reconstructed scope accepted as authoritative) before a plan is written.

## Context & Scope

This dispatch is the `research` phase for task 612 in `/home/benjamin/.config/nvim`. The GOAL
stated in the dispatch ("gate every Sapience activation surface behind the extension") spans two
companion tasks in two different repositories, per the dispatch's own SITING paragraph:

- **First half** (extension-side): build the per-repo activation surface inside
  `agent-system/extensions/sapience/` in `/home/benjamin/.config/nvim` — this is what task 612's
  `file_scope`, title, and siting all say task 612 *is*.
- **Second half** (removal): remove the machine-wide Sapience activation surfaces from
  `/home/benjamin/.dotfiles` (`modules/home/services/sapience.nix`, `config/claude/settings.json`,
  `docs/sapience.md`) once the first half has landed and been verified — this is what task 612's
  *description text* actually narrates, and it is a different task (`.dotfiles` project 138).

The scope of this report is therefore twofold: (1) establish and evidence the description/
file_scope mismatch so the plan phase does not inherit it uncorrected, and (2) do the codebase
research the *first half* (task 612's real job) actually needs, so a plan can be written against
the reconstructed scope without re-doing this discovery.

## Findings

### The description/file_scope mismatch (evidenced)

| Signal | Task 612 (`.config/nvim`) | `.dotfiles` task 138 |
|---|---|---|
| `project_name` | `gate_sapience_activation_behind_extension` | `retire_machine_wide_sapience_surface` |
| `title` | "Gate every Sapience activation surface behind the sapience extension so Sapience runs only in repos that load it" | "Retire the machine-wide Sapience surface so the extension's per-repo gating is the only activation path" |
| `task_type` | `meta` | `nix` |
| `status` | `researching` | `not_started` |
| `file_scope` | `agent-system/extensions/sapience/{settings-fragment.json, manifest.json, EXTENSION.md, README.md, index-entries.json, context/project/sapience/domain/{per-repo-scoping.md, review-gate-boundary.md}, scripts/}` | `config/claude/settings.json`, `modules/home/services/sapience.nix`, `docs/sapience.md` |
| `description` text | **Identical, word-for-word**, to `.dotfiles` task 138's description — opens "GOAL. Remove every machine-wide Sapience activation surface..." and states "SITING. This task belongs in /home/benjamin/.dotfiles..." | Same text (its own, correctly) |

Confirmed by direct read of both repositories' `specs/state.json` (`project_number: 612` entry
in this repo; `project_number: 138` entry in `.dotfiles`) — the description bodies are byte-
identical. Task 612's `file_scope` paths were also confirmed to exist under
`agent-system/extensions/sapience/` in this repo, and the three paths named in the description
(`modules/home/services/sapience.nix`, `config/claude/settings.json`, `docs/sapience.md`) do
**not** exist anywhere under `/home/benjamin/.config/nvim` — only under `/home/benjamin/.dotfiles`.

This is a task-authoring/paste defect (two companion tasks created together, one description
copied onto both records), not evidence that the underlying two-part plan is wrong. Recorded via
`issue-record.sh` (class `design-record defect or ambiguity`, severity `blocking`).

### What task 612 actually needs to build (reconstructed from file_scope + codebase evidence)

Reconstructing from `file_scope`, the title, and the root `CLAUDE.md`'s "Sapience Extension"
section (which already documents the *current*, machine-wide-dependent state: "Already ambient:
the MCP server registration and the three SessionStart/SessionEnd/Stop hooks in `~/.dotfiles`");
cross-checked against the (misplaced but factually accurate, since it describes the shared
target end-state) "WHAT IS BEING REMOVED" section of the dispatched description, which inventories
exactly what the first half must cause to exist *per-repo instead*:

1. **MCP server registration**, currently a top-level `~/.claude.json` merge done by
   `.dotfiles`'s `modules/home/services/sapience.nix` (`sapienceMcpServer` activation entry,
   confirmed read directly — merges `.mcpServers.sapience` at the **top level**, unconditionally,
   on every `home-manager switch`). Needs to become per-repo.
2. **Seven read-tool permission grants** (`mcp__sapience__sapience{,_search,_briefing,_context,
   _ask,_outstanding,_papers}`), currently in `.dotfiles`'s `config/claude/settings.json`
   `permissions.allow`, merged machine-wide into `~/.claude/settings.json` because `permissions`
   is an enforced key. Needs to move into `agent-system/extensions/sapience/settings-fragment.json`
   so it merges per-repo instead (same mechanism already used for the 4 write-tool grants that
   file currently carries — confirmed by reading it directly, see below).
3. **Five hooks** (SessionStart briefing, UserPromptSubmit, PreToolUse `Edit|Write|MultiEdit`,
   SessionEnd, Stop), currently in the same `.dotfiles` settings file's `hooks` object. Needs to
   become extension-provided so they are present only when the extension is loaded.
4. **The `_SAPIENCE_NOTE`** explaining why `hooks`/`permissions` are enforced keys — this is a
   `.dotfiles`-side documentation artifact, not something task 612 owns; noted here only because
   the (misplaced) description conflates it with task 612's own acceptance criteria.

### Current state of `agent-system/extensions/sapience/` (this repo)

Read directly:

- `manifest.json`: `provides.hooks: []` (empty — no Claude-Code-native hooks declared yet), no
  top-level `hooks` lifecycle-hook object, `merge_targets.settings` → `.claude/settings.local.json`.
- `settings-fragment.json`: carries **only** the 4 MCP write-tool grants
  (`sapience_remember`, `sapience_wrapup`, `sapience_handoff`, `sapience_adddoc`). No read-tool
  grants, no `hooks` key, no `mcpServers` key.
- `scripts/`: `sapience-remember.sh`, `sapience-retrieve.sh`, `tests/test-sapience-capture.sh` —
  none of these touch `~/.claude.json` or register an MCP server.
- `.claude-extensions.json`'s live `sapience` entry confirms the *actual* deployed effect today:
  `merged_sections.settings.permissions.children.allow` (the 4 write grants only), plus a
  `context` index merge. No `hooks` merge is in effect yet.

Conclusion: none of the three building blocks in "What task 612 actually needs to build" above
exist yet in the extension. This is genuinely unstarted first-half work, consistent with task
612's `status: researching` (not previously planned or implemented).

### The settings-merge engine already supports per-repo hook merging

`lua/neotex/plugins/ai/shared/extensions/merge.lua` (read directly, including the currently
uncommitted working-tree diff) implements, as already-shipped, general-purpose capability (not
something to build for this task):

- `is_hook_event_array` / hook-identity-based dedup (`find_hook_match`) for merging a Claude-Code
  `hooks` object's per-event matcher arrays (the exact shape `SessionStart`/`PreToolUse`/etc. use)
  into a target settings file, concatenating in first-appearance order and de-duplicating by hook
  identity rather than blind concatenation.
- `unmerge_settings` / `remove_orphaned_hook_registrations`, which cleanly remove an extension's
  own hook entries on unload, including pruning a matcher block left with zero hooks and (per the
  uncommitted fix) dropping an emptied `hooks` key entirely rather than leaving a `[]` that Claude
  Code rejects.

This means `settings-fragment.json`'s `hooks` key is a proven, already-working merge target —
adding the 5 Sapience hooks there is not new engineering, it is reusing an existing mechanism the
sapience extension simply has not used yet (today it only exercises the `permissions.allow`
merge path).

### The MCP-server-registration precedent: `lean-lsp`

The one piece genuinely outside the settings-merge engine's remit — writing to `~/.claude.json`,
which lives outside any repository's tree and is never a `settings-fragment.json`/`.claude/`
merge target — already has a complete, shipped, per-project (not machine-wide) precedent in the
**lean** extension, read directly:

- `agent-system/extensions/lean/scripts/install-lean-lsp-session-hook.sh` installs two files to
  **stable, user-level** paths (never inside any single repository's disposable `.claude/` tree,
  explicitly because the mechanism must also work in a fresh git worktree with no `.claude/`
  deploy at all):
  - `$HOME/.claude/hooks/lean-lsp-register-project.sh` — a `SessionStart` hook.
  - `$HOME/.claude/scripts/setup-lean-mcp.sh` — the writer it calls.
- `hooks/lean-lsp-register-project.sh` fires on every session start, detects whether the
  session's CWD is a Lean project (`lakefile.lean`/`lakefile.toml` at CWD or git root), and if so
  invokes `setup-lean-mcp.sh --scope project --quiet` to register/repair **that project's own**
  `.projects["<abs path>"].mcpServers."lean-lsp"` entry in `~/.claude.json` — never the top-level
  `.mcpServers` key (which `setup-lean-mcp.sh --retire-global` explicitly tears down as the
  superseded shape).
- The hook is documented as silent on steady-state (already-correct) sessions and only emits an
  `additionalContext` notice when it actually writes, because a `SessionStart` hook's own write
  is not reliably visible within the same session (a measured, documented trap).

This is the exact shape task 612's reconstructed scope needs for Sapience: a stable, user-level
`SessionStart` hook that checks "does this repo's `.claude-extensions.json` show
`extensions.sapience.status == "active"`" (the Sapience analogue of "is there a lakefile"), and
if so registers/repairs `.projects["<abs path>"].mcpServers.sapience` — never the top-level key
`.dotfiles`'s `sapienceMcpServer` activation entry currently writes.

**Correction to the dispatch's own claim**: the (misplaced) description asserts "the same file
[`modules/home/services/sapience.nix`] already contains a worked precedent for the per-project
shape: `~/.claude.json`'s `.projects[<path>].mcpServers` carries `lean-lsp` for four Lean repos
today." This is factually wrong about *where* the precedent lives. `sapience.nix`'s own
`sapienceMcpServer` entry merges the **top-level** key, not a per-project one — it is not itself
an example of the per-project shape. The real per-project precedent is implemented entirely by
the **lean extension's own scripts** (`setup-lean-mcp.sh`, `lean-lsp-register-project.sh`,
`install-lean-lsp-session-hook.sh`, `verify-lean-mcp.sh`), i.e. exactly the kind of artifact task
612's own `file_scope` (`agent-system/extensions/sapience/scripts/`) says it should produce. This
is good news for task 612's feasibility — the pattern to mirror already exists, fully built and
tested, in a sibling extension — but the description's framing of *where* to find it would send
a planner looking in the wrong file.

### Ordering constraint, re-derived correctly

With task 612 correctly identified as the first half, the dependency direction is:
`.dotfiles` task 138 (second half, `not_started`) depends on task 612 landing and being verified
— not the reverse the misplaced description text asserts. Nothing in either repository shows the
first half (task 612's real job) has already landed, so there is no companion-completion check
that blocks task 612 from proceeding to planning now. The "before starting implementation,
confirm the companion has completed; if not, stop and report" instruction in the dispatched
description applies, correctly, to the *.dotfiles* task (138), not to this one.

### Dependency check (task 611)

Task 612 declares a dependency on task 611 (`repo_tag_sapience_write_paths`). Confirmed completed
(`git log`: "task 611: complete implementation (post-deploy reconcile)"), and its artifact
(`.claude/rules/sapience-write-path.md`) is present and read for this report — it governs write-
path language inside `agent-system/extensions/sapience/**` and does not conflict with anything
task 612's reconstructed scope would add (none of the additions above name an MCP write tool as a
write path).

## Decisions

- Treat task 612's `file_scope`, title, `project_name`, and siting — not its `description`
  field — as authoritative for what this task is, pending the correction below. All research in
  this report targets the first-half (extension-side) scope, not the description's literal
  (removal) content.
- Did not attempt to research or scope the `.dotfiles`-side removal work (settings.json hook/
  permission removal, `docs/sapience.md` rewrite, `nix flake check` verification) — that belongs
  to the separate, already-existing `.dotfiles` task 138 and is out of this task's `file_scope`
  and out of this repository's tree entirely.
- Recorded the mismatch via `issue-record.sh` (class `design-record defect or ambiguity`,
  severity `blocking`) rather than silently self-correcting and proceeding, because the correct
  fix (editing the task's stored description) is not something a research-phase report can do to
  `specs/state.json` directly, and a human should confirm the reconstructed scope before a plan
  is written against it.
- Recorded the lean-lsp precedent discovery as a `win` via `issue-record.sh`, since it resolves
  what would otherwise be the open feasibility question for the plan phase.

## Recommendations

1. **Correct task 612's description before planning**, replacing the pasted removal narrative
   with a description of the actual first-half scope (the three building blocks in "What task
   612 actually needs to build" above), or — if a description edit is judged out of scope for an
   automated pass — have the plan phase explicitly treat this report's "Findings" section as the
   scope statement of record and cite it, rather than re-deriving it from the description.
2. **Mirror the lean-lsp triad for Sapience's MCP registration**, adapted:
   - A writer script (`agent-system/extensions/sapience/scripts/setup-sapience-mcp.sh` or
     similar) that registers/repairs `.projects["<abs path>"].mcpServers.sapience` in
     `~/.claude.json` for one project, reading the token from `~/.sapience/config.json` exactly as
     `.dotfiles`'s `sapienceMcpServer` activation entry does today (same `jq` merge shape, same
     "register without a token until config.json has one" fallback).
   - A `SessionStart` hook that checks the current repo's `.claude-extensions.json` for
     `extensions.sapience.status == "active"` (in place of lean's lakefile detection) and invokes
     the writer.
   - An install script that seeds both to stable user-level paths (`~/.claude/hooks/`,
     `~/.claude/scripts/`), mirroring `install-lean-lsp-session-hook.sh`'s two-file,
     idempotent, `--remove`-capable install — needed for the same reason lean's is: a fresh
     worktree with no repo-local `.claude/` deploy must still work.
   - A verification script mirroring `verify-lean-mcp.sh`'s per-project entry check, adapted to
     the acceptance criteria's "a session in a repo WITHOUT the extension shows no tools/grants/
     hooks; `.dotfiles`/`.config/nvim` keep all" requirement.
3. **Move the 7 read-tool grants and the 5 hooks into `settings-fragment.json`** (the merge
   engine already supports both key shapes — no new merge-engine work needed, confirmed above).
   Keep the existing 4 write-tool grants intact (per
   `.claude/rules/sapience-write-path.md`'s "Accepted Residual" — out of scope to narrow here).
4. **Do not scope `nix flake check`, `home-manager switch`, or any `.dotfiles`-rooted
   verification into this task's plan** — those are `.dotfiles` task 138's acceptance criteria,
   against files outside this repository's tree. Task 612's own verification is: confirm, after
   loading the sapience extension into a fresh repo, that the merged `.claude/settings.local.json`
   carries all 11 grants and 5 hooks, and that `~/.claude.json`'s `.projects[<that repo's abs
   path>].mcpServers.sapience` entry appears after a session start; then confirm unloading the
   extension removes all three.
5. **Flag the `.dotfiles`-side owner action** (the `~/.sapience/config.json` `folders`/
   `capture.projects` reconciliation named in the misplaced description) as out of this task's
   remit entirely — it is a `.dotfiles` task 138 deliverable, not task 612's.

## Risks & Mitigations

- **Risk**: a plan phase reads the dispatched description literally and attempts to edit
  `.dotfiles` files from this repository. **Mitigation**: this report's Decisions section states
  the authoritative scope explicitly and the `user_decision` raised below surfaces the mismatch
  for human confirmation before planning proceeds.
- **Risk**: the per-project `SessionStart` hook pattern, if copied too literally from lean-lsp,
  could collide identity-wise with the existing lean hook in the same `hooks.SessionStart` array
  when both extensions are loaded in the same repo (e.g. a future Lean+Sapience repo). The merge
  engine's `find_hook_match` dedup is identity-based (command string), so two distinct hook
  scripts with distinct paths will not collide — but this should be verified empirically once
  both fragments exist, not assumed.
- **Risk**: writing to `~/.claude.json` from an extension-provided hook is a stable-user-level
  write outside any repository's tree, which is a different trust/ownership boundary than the
  normal `.claude/` deploy artifact. The lean precedent already established this boundary and its
  rationale (works in a deploy-less fresh worktree); the plan should cite
  `context/patterns/mcp-server-ownership.md` (named in `.claude/rules/sapience-write-path.md`'s
  "Accepted Residual" paragraph) for the ownership invariant governing this class of write.
- **Risk**: this report's reconstructed scope is itself a judgment call, not something the
  (broken) description can confirm. See the `user_decision` set in `.return-meta.json`.

## Context Extension Recommendations

None — the relevant context (`context/patterns/mcp-server-ownership.md`,
`.claude/rules/source-store-deploy-boundary.md`'s Task Siting subsection,
`.claude/rules/sapience-write-path.md`) already exists and already covers the invariants this
task's plan will need to respect. No new context file is recommended.

## Appendix

- Searches/reads performed: `specs/state.json`/`TODO.md` in both `/home/benjamin/.config/nvim`
  and `/home/benjamin/.dotfiles`; `agent-system/extensions/sapience/**` (manifest.json,
  settings-fragment.json, scripts/); `.claude-extensions.json`'s live `sapience` entry;
  `agent-system/extensions/lean/manifest.json` and its `scripts/setup-lean-mcp.sh`,
  `hooks/lean-lsp-register-project.sh`, `scripts/install-lean-lsp-session-hook.sh`;
  `lua/neotex/plugins/ai/shared/extensions/merge.lua` (including its current uncommitted diff);
  `.dotfiles/modules/home/services/sapience.nix` lines ~770-1060 (`sapienceMcpServer`,
  `claudeMcpServers` activation entries); `.claude/rules/sapience-write-path.md`;
  `.claude/context/guides/loader-reference.md`.
- Related: `.claude/scripts/claude-refresh.sh` (contains an independent, already-shipped pass
  that audits top-level `~/.claude.json` `mcpServers` fan-out — read but not otherwise used by
  this report; may be relevant context for the plan phase's verification design).
