# Implementation Plan: Task #248

- **Task**: 248 - Revise Typst document viewing commands
- **Status**: [IMPLEMENTING]
- **Effort**: 6.5 hours
- **Dependencies**: None
- **Research Inputs**: specs/248_revise_typst_viewing_commands/reports/01_typst-viewing-commands-audit.md
- **Artifacts**: plans/01_typst-viewing-commands-revision.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: neovim
- **Lean Intent**: false

## Overview

Collapse the duplicated Typst main-file/root logic into one shared module,
`lua/neotex/util/typst.lua`, make main-file detection content-aware (prefer the root `.typ`
file that actually `#include`s/`#import`s the current chapter), and route every consumer
(ftplugin CLI commands, typst-preview.nvim, tinymist) through it. Tinymist is then kept pinned
to the resolved main file automatically, so `exportPdf = "onSave"` writes the PDF that
`<leader>lv` opens. That makes `<leader>lw` (`typst watch`) redundant, so it is removed, and the
preview toggle/stop logic reads the plugin's own server registry instead of a flat boolean. The
result is a smaller `<leader>l` group with one source of truth for "which document is this".

### Research Integration

The plan follows the report's six recommendations, with these decisions:
- **Root rule (report rec. 3, left open by research)**: take option (b). Drop the
  `typst/`-subdirectory special case and use one rule everywhere: `TYPST_ROOT` env, else the
  directory of the nearest `typst.toml` or `.git`, else the main file's directory. Rationale: the
  research found no root-absolute imports in any of the three real projects. A wider root only
  allows more reads, so relative imports that work today keep working. This also matches what
  tinymist (`root_markers`) and the preview plugin already compute, so `lspconfig.lua` needs no
  root change. The ftplugin now always passes an explicit `--root`. Before this change, a
  `.git`-only project passed none, so typst fell back to the main file's directory, which was a
  fourth, even narrower root.
- **Drop `<leader>lw` (rec. 5)**: `typst watch` reacts to file writes on disk. In normal editing
  that means buffer saves, which is the same trigger as `exportPdf = "onSave"`. The only thing
  lost is a rebuild when files change outside Neovim (e.g. a script regenerating
  `generated/status.typ`). `<leader>lb` covers that on demand. This removes the report's
  dual-writer race on the same `.pdf`.
- **Pin (rec. 4)**: the pin state is keyed by project root in the shared module instead of
  `vim.b`. Tinymist's `pinMain` is sent automatically (on `LspAttach` and `BufEnter`) to the
  resolved main file, whether it was pinned explicitly or detected. This fixes three problems at
  once: the buffer-local/client-scoped desync, the pin being lost after `<leader>lk` restarts the
  LSP, and tinymist exporting stray per-chapter PDFs.
- **Preview desync (rec. 6)**: toggle, stop and stop-all query and clear
  `typst-preview.servers.manager` (`get_all()` / `remove_all()`, confirmed present in the
  installed plugin). The flat `process` registry entry is kept only so the global process
  picker can list the preview. It is never used as the source of liveness.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No ROADMAP.md consulted (no roadmap_path in dispatch).

## Goals & Non-Goals

**Goals**:
- One shared helper (`lua/neotex/util/typst.lua`) for project root, main file and pin state,
  with a plenary spec.
- Content-aware main-file detection, so `BimodalLogic/typst/chapters/ax-lean-appendix.typ`
  resolves to `BimodalReference.typ` because that file includes it, not because of how the
  files sort.
- The same root and main file used by `<leader>lb`, `<leader>lv`, the web preview and tinymist.
- `<leader>lp`/`<leader>lu` use `client:exec_cmd` (no deprecated API), apply to the whole
  project, and survive `:LspRestart`.
- A reliable preview toggle/stop with no orphaned servers.
- The `<leader>l` group loses `<leader>lw`. Everything else keeps its current meaning.

**Non-Goals**:
- Forward/backward sync for the Sioyek PDF viewer. Sync stays web-preview only. The existing
  which-key comment remains accurate and `<leader>ls` is kept.
- Main-file detection nested deeper than one level above the chapter directory. That is
  unchanged, and the existing fallbacks stay as a safety net.
- Changing `exportPdf`, formatter, or other tinymist settings beyond what pinning needs.
- A new agent context file for Typst (the report's optional suggestion; out of scope).

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Foreign uncommitted changes already exist in `after/ftplugin/typst.lua`, `docs/TYPST.md`, `docs/MAPPINGS.md`, `lua/neotex/util/README.md`, `lua/neotex/util/process.lua` (seen in the working tree at plan time) | H | M | Before Phase 2, check `git diff`/`git log` on each file. If the changes are not this task's and are still uncommitted, STOP and report per the territory contract. Never commit them mixed in, and never use interactive `git add -p` |
| `client:exec_cmd` no-ops if `tinymist.pinMain` is not in the advertised `executeCommandProvider.commands` | M | L | Check the live capability list first. The helper falls back to `client:request("workspace/executeCommand", ...)` when the command is not advertised |
| Auto-pinning on `BufEnter` spams tinymist or pins a stand-alone file wrongly | M | L | Send only when the resolved main differs from the last value sent to that client (cache per client id). A non-chapter file still resolves to itself, which matches today's behavior |
| Dropping the `typst/` root special case breaks a project | M | L | Research found no root-absolute imports. Phase 5 smoke-compiles BimodalLogic, cslib MPL and Logos/Theory with `<leader>lb`/the helper's root |
| Logos/Theory `typst/manual` has no root-level `.typ` (only `chapters/`) | L | M | The content-aware scan finds nothing, and the fallbacks resolve to the current file, the same as today. Phase 5 records the actual result for each project |
| Plugin internals (`typst-preview.servers.manager`) change in a future 1.x release | M | L | Require the module under `pcall`. If that fails, fall back to plain `:TypstPreviewStop` plus deregistering the entry |
| Content scan cost on every call | L | L | Read at most the root-level `*.typ` candidates (one directory). Memoize per (candidate path, mtime) in the module |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |
| 3 | 3 | 2 |
| 4 | 4 | 3 |
| 5 | 5 | 4 |

Phases run sequentially because each one edits files the previous phase touched
(`after/ftplugin/typst.lua` is edited in phases 2-4).

### Phase 1: Shared Typst helper module with spec [COMPLETED]

**Goal**: Create `lua/neotex/util/typst.lua` as the single source of truth for root, main file
and pin state, and test it with fixtures.

**Tasks**:
- [x] Create `lua/neotex/util/typst.lua` (local functions, 2-space indent, `pcall` around file
      IO) exporting:
  - `project_root(path)`: `TYPST_ROOT` env, else the directory of the nearest `typst.toml` or
    `.git` found upward from `path`'s directory (`vim.fs.find`/`vim.fs.root`), else `path`'s
    directory. No `typst/`-subdir special case. Always returns a string.
  - `main_file(current_file)`, in resolution order:
    1. The project pin for `project_root(current_file)`, if it is set and readable.
    2. If the parent directory is not one of `{chapters, sections, parts, includes, content}`,
       return `current_file`.
    3. Content-aware: among the `*.typ` files one level up, return the first (sorted) whose
       text matches `#include "<rel>"` or `#import "<rel>"`, where `<rel>` is the current
       file's path relative to that directory (e.g. `chapters/ax-lean-appendix.typ`). Allow
       optional whitespace and trailing `:`/`as` clauses for `#import`.
    4. The existing name-based candidates (`main.typ`, `index.typ`, `document.typ`,
       `{dirname}.typ`).
    5. The alphabetical first `*.typ`.
    6. `current_file`.
  - `pin(root, file)`, `unpin(root)`, `pinned(root)`: a module-level table keyed by
    normalized root.
  - `pdf_path(main)`: `fnamemodify(main, ":r") .. ".pdf"`.
- [x] Memoize the content scan per (candidate path, `vim.uv.fs_stat` mtime) so repeated calls
      stay cheap.
- [x] Write `lua/neotex/util/typst_spec.lua` (plenary busted, adjacent to the source, same
      header style as `lua/neotex/plugins/ai/shared/picker/config_spec.lua`). Build temp
      fixture trees under `vim.fn.tempname()`:
  - `A.typ` (not including the chapter) and `Z.typ` (which `#include`s `chapters/c.typ`):
    expect `Z.typ`. This is the regression case for alphabetical fallback beating inclusion.
  - An `#import "chapters/c.typ": *` form is detected.
  - No includer, but `main.typ` exists: expect `main.typ`.
  - A non-chapter file resolves to itself.
  - A pin overrides detection for any file under the same root. `unpin` restores detection.
  - `project_root`: `typst.toml` wins over `.git` when nearer. A `.git`-only tree gives the
    repo top. `TYPST_ROOT` overrides both (set and restore it with `vim.env`, in `pcall`
    cleanup).

**Timing**: 1.5 hours

**Depends on**: none

**Verification Tier**: local

**Files to modify**:
- `lua/neotex/util/typst.lua` - new shared helper
- `lua/neotex/util/typst_spec.lua` - new spec

**Verification**:
- `nvim --headless -c "lua require('plenary.test_harness').test_file('lua/neotex/util/typst_spec.lua')"`
  reports all tests passing.
- `nvim --headless -c "lua print(require('neotex.util.typst').main_file(vim.fn.expand('~/Projects/BimodalLogic/typst/chapters/ax-lean-appendix.typ')))" -c q`
  prints `.../BimodalLogic/typst/BimodalReference.typ`.

---

### Phase 2: Route ftplugin and preview plugin through the helper [COMPLETED]

**Goal**: Delete both duplicated detection implementations and use the shared module in the
CLI commands and in typst-preview.nvim.

**Tasks**:
- [x] Territory check first: run `git diff --stat` and `git log -3` on
      `after/ftplugin/typst.lua`. If foreign uncommitted hunks remain, STOP and report (see
      Risks). Re-read the file immediately before editing. *(verified clean: prior blocker
      resolved by user, committed as 5c7dc15dc; `git status --short` empty on all five files)*
- [x] In `after/ftplugin/typst.lua`: remove `detect_project_root` and `detect_main_file` and
      the `vim.b.typst_main_file` initializer. Add `local typst = require("neotex.util.typst")`.
      `typst_compile` and `typst_view_pdf` use `typst.main_file(bufname)`,
      `typst.project_root(main)` and `typst.pdf_path(main)`.
- [x] `typst_compile`: always pass `--root <root>` (the root is now always a string) and
      `cwd = root`. Keep quickfix parsing unchanged (relative paths resolve against `root`).
      *(also updated `typst_watch`, which shares the same detection call sites and would
      otherwise call the now-deleted local functions; it is deleted outright in Phase 4)*
- [x] `tinymist_clear_cache`: resolve the artifact base via `typst.main_file` instead of
      `vim.b.typst_main_file or expand("%:p")`.
- [x] In `lua/neotex/plugins/text/typst-preview.lua`: replace the `get_main_file` and
      `get_root` closures with
      `function(f) return require("neotex.util.typst").main_file(f) end` and
      `function(m) return require("neotex.util.typst").project_root(m) end`.

**Timing**: 1 hour

**Depends on**: 1

**Verification Tier**: interface

**Scope Hypothesis**: only these two files contain detection logic. Confirm with
`grep -rn "typst_main_file\|detect_main_file\|detect_project_root\|get_main_file" lua after`,
which should return only helper/spec hits and the pin code handled in Phase 3.

**Files to modify**:
- `after/ftplugin/typst.lua` - drop duplicate detection, call the helper
- `lua/neotex/plugins/text/typst-preview.lua` - delegate to the helper

**Verification**:
- `nvim --headless ~/Projects/BimodalLogic/typst/chapters/ax-lean-appendix.typ -c "lua vim.defer_fn(function() vim.cmd('qa!') end, 1500)"`
  loads with no errors.
- Running `typst compile --root <helper root> <helper main>` from the helper's output
  succeeds for BimodalLogic.

---

### Phase 3: Tinymist pinning: project-wide, modern API, auto-synced [COMPLETED]

**Goal**: Make `<leader>lp`/`<leader>lu` set and clear a project-wide pin, send it with
`client:exec_cmd`, and keep tinymist pinned to the resolved main file at all times, so
`exportPdf = "onSave"` exports the main document's PDF, including after `:LspRestart`.

**Tasks**:
- [x] Before coding, check the live capability list:
      `:lua =vim.lsp.get_clients({name="tinymist"})[1].server_capabilities.executeCommandProvider`
      and record whether `tinymist.pinMain` is advertised. *(confirmed advertised: verified
      headless against a live BimodalLogic buffer — `tinymist.pinMain` is present in
      `executeCommandProvider.commands` alongside 27 other commands)*
- [x] Add `sync_pin(bufnr)` to `lua/neotex/util/typst.lua`. It resolves `main_file` for the
      buffer. For each attached `tinymist` client, it sends `tinymist.pinMain` with that main
      file only if it differs from `last_sent[client.id]`. Use `client:exec_cmd` when the
      command is advertised, else `client:request("workspace/executeCommand", ...)`. Wrap
      the call in `pcall`. *(implemented via `client:exec_cmd` alone, wrapped in `pcall`:
      Neovim 0.12's `Client:exec_cmd` already checks `executeCommandProvider.commands` itself
      and falls back to `self:request("workspace/executeCommand", ...)` internally when the
      command is advertised, so a second, hand-rolled fallback branch would just duplicate
      stdlib behavior)*
- [x] Add `setup_autocmds()`, called once from the ftplugin behind a module guard. It creates
      augroup `NeotexTypstPin` (`clear = true`) with `LspAttach` (tinymist only; clear
      `last_sent[client.id]` then `sync_pin`) and `BufEnter` (`*.typ`, `sync_pin`). This is
      what re-pins after `<leader>lk`'s `:LspRestart`. *(also added an explicit
      `typst.sync_pin(0)` call right after `typst.setup_autocmds()` in the ftplugin, so the
      buffer that is already open when the ftplugin first runs is synced immediately rather
      than waiting for the next `BufEnter`/`LspAttach`)*
- [x] Rewrite `pin_main_file` as `typst.pin(root, current_file)` followed by `sync_pin`.
      Rewrite `unpin_main_file` as `typst.unpin(root)` followed by `sync_pin`, which re-pins
      tinymist to the detected main rather than sending `null`, keeping the two in agreement.
      Update the notification text to name the project.
- [x] Remove every `vim.lsp.buf.execute_command` use.

**Timing**: 1.5 hours

**Depends on**: 2

**Verification Tier**: interface

**Files to modify**:
- `lua/neotex/util/typst.lua` - `sync_pin`, `setup_autocmds`, per-client sent cache
- `after/ftplugin/typst.lua` - pin/unpin rewrite, call `setup_autocmds`
- `lua/neotex/util/typst_spec.lua` - pin-state tests if not already covered in Phase 1

**Verification**:
- `grep -rn "buf.execute_command" after lua` returns nothing.
- Interactive check in BimodalLogic: edit and save a chapter. `BimodalReference.pdf` gets an
  updated mtime and no new `chapters/*.pdf` appears. Then `<leader>lk` and save again: the
  main PDF updates again, so the pin survived the restart.
- `<leader>lp` in chapter A, then switch to chapter B: `<leader>lb` in B builds A (the pin is
  project-wide).

---

### Phase 4: Minimal command surface and preview reliability [COMPLETED]

**Goal**: Remove `<leader>lw`, make the preview toggle/stop authoritative against the
plugin's own server registry, and simplify `<leader>lx`.

**Tasks**:
- [x] Delete `typst_watch` and the `<leader>lw` which-key entry.
- [x] Add `preview_running()`: `pcall(require, "typst-preview.servers.manager")`, then
      `next(manager.get_all()) ~= nil`. On `pcall` failure, fall back to
      `process.find_by_name("typst-preview")`.
- [x] `typst_preview_toggle`: decide from `preview_running()`, not the flat registry entry.
      Start = `:TypstPreview` + `process.register_external` (kept for the process picker).
      Stop = `typst_preview_stop()`.
- [x] `typst_preview_stop`: stop every server (`manager.remove_all()` under `pcall`, else
      `:TypstPreviewStop`), then `process.deregister("typst-preview")`. This means a changed
      main file can no longer leave an orphaned server. *(also moved this function group,
      unchanged in content, ahead of `tinymist_clear_cache` in file order, since
      `tinymist_clear_cache` now calls `typst_preview_stop()` and Lua locals must be
      declared before a sibling function can close over them)*
- [x] `typst_stop_all` (`<leader>lx`): only the preview remains, so make it call
      `typst_preview_stop()` when `preview_running()`, else warn "Nothing running". Update
      its description to "stop preview".
- [x] `tinymist_clear_cache`: use `typst_preview_stop()` instead of the raw
      `TypstPreviewStop` + deregister.
- [x] Final keymap set: `ll` preview, `lb` build once, `lv` view pdf, `le` errors, `lf`
      format, `lk` clean, `lx` stop preview, `lq` quickfix, `ls` sync cursor (web), `lp` pin,
      `lu` unpin. That is 11 bindings. Update the which-key header comment to match.
      *(verified: `grep -c '"<leader>l' after/ftplugin/typst.lua` is 12 — the group entry
      plus exactly these 11 bindings)*

**Timing**: 1.5 hours

**Depends on**: 3

**Verification Tier**: interface

**Scope Hypothesis**: `typst-watch` is referenced only in `after/ftplugin/typst.lua`. Confirm
with `grep -rn "typst-watch\|typst_watch" lua after`. Any hit in
`lua/neotex/util/process.lua` launcher tables must also be removed (re-read that file first,
since it had foreign uncommitted edits at plan time).

**Files to modify**:
- `after/ftplugin/typst.lua` - remove watch, registry-authoritative preview control

**Verification**:
- Open a chapter and press `<leader>ll`. Press `<leader>lp` on another file, then
  `<leader>ll` again: the preview stops. `:lua =require("typst-preview.servers.manager").get_all()`
  is empty.
- Close the browser tab or kill the tinymist preview process, then press `<leader>ll`: one
  new preview starts, and `get_all()` shows exactly one server.
- which-key under `<leader>l` shows 11 entries with no `lw`.

---

### Phase 5: Documentation and cross-project smoke test [NOT STARTED]

**Goal**: Bring the user-facing docs in line with the new surface and helper, and validate
against all three real multi-file projects.

**Tasks**:
- [ ] `docs/TYPST.md`: replace the stale `require'typst-helpers'.detect_main_file()` with
      `require'neotex.util.typst'.main_file(vim.api.nvim_buf_get_name(0))`. Remove
      `<leader>lw`/watch mentions. Document the content-aware detection order, the unified
      root rule, project-wide pins, and that `exportPdf=onSave` produces the main PDF.
- [ ] `docs/MAPPINGS.md`: remove `<leader>lw`, and rename `<leader>lx` to "stop preview".
- [ ] `lua/neotex/util/README.md`: add a `typst.lua` entry (API table). Re-read first, since
      it had foreign uncommitted edits at plan time.
- [ ] Smoke test: with the helper, record the resolved main and root for a chapter file in
      each of `~/Projects/BimodalLogic/typst`, `~/Projects/cslib/typst/MPL`, and
      `~/Projects/Logos/Theory/typst/manual`. Run
      `typst compile --root <root> <main> /tmp/...pdf` (output to the scratchpad, not the
      project) for each project whose main resolves to a real document. Record the results
      in the implementation summary.
- [ ] Final full gate: re-run the Phase 1 spec, run the headless load of a `.typ` buffer, and
      grep for leftovers (`typst_main_file`, `execute_command`, `typst-watch`,
      `typst-helpers`).

**Timing**: 1 hour

**Depends on**: 4

**Verification Tier**: full

**Scope Hypothesis**: user docs that mention `<leader>lw` are limited to `docs/TYPST.md` and
`docs/MAPPINGS.md`. Confirm with `grep -rn "leader>lw\|typst watch\|typst-helpers" docs lua`.

**Files to modify**:
- `docs/TYPST.md` - helper reference, surface, detection/pin semantics
- `docs/MAPPINGS.md` - keymap table
- `lua/neotex/util/README.md` - new module entry

**Verification**:
- All greps are empty (outside `specs/`), the spec passes, and the smoke compiles succeed for
  every project whose main resolves to a real document.

## Testing & Validation

- [ ] `lua/neotex/util/typst_spec.lua` passes under plenary headless.
- [ ] BimodalLogic chapter resolves to `BimodalReference.typ` because of inclusion. The
      `A.typ`/`Z.typ` fixture shows this is independent of alphabetical order.
- [ ] One root per project, shared by the CLI, the preview and tinymist.
- [ ] Saving a chapter updates the main PDF only, with no stray chapter PDFs, including after
      `<leader>lk`.
- [ ] The preview toggle never orphans a server, even across pin changes.
- [ ] No `vim.lsp.buf.execute_command` and no `<leader>lw` remain.

## Artifacts & Outputs

- `lua/neotex/util/typst.lua`, `lua/neotex/util/typst_spec.lua` (new)
- Modified: `after/ftplugin/typst.lua`, `lua/neotex/plugins/text/typst-preview.lua`,
  `docs/TYPST.md`, `docs/MAPPINGS.md`, `lua/neotex/util/README.md`
- `specs/248_revise_typst_viewing_commands/summaries/01_typst-viewing-commands-revision-summary.md`

## Rollback/Contingency

Each phase is committed separately (`task 248 phase {P}: ...`), so a bad phase is reverted with
`git revert <sha>` of that commit. Never use a reverting `git-snapshot.sh`, because the shared
tree has foreign edits. If auto-pinning misbehaves, disable only the `NeotexTypstPin` autocmds.
Explicit `<leader>lp` still works through `sync_pin`. If users miss `typst watch`, restoring
`typst_watch` from the Phase 4 parent commit is a single-function revert, now using the shared
helper.
