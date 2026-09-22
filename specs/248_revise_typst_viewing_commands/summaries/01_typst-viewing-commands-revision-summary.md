# Implementation Summary: Task #248

**Completed**: 2026-09-22
**Duration**: ~5 phases across two orchestration cycles (Phase 1 in a prior cycle; Phases 2-5 in this dispatch)

## Overview

Collapsed the duplicated Typst main-file/project-root detection logic (previously
independently implemented in `after/ftplugin/typst.lua` and
`lua/neotex/plugins/text/typst-preview.lua`, and disagreeing with each other about root
computation) into one shared module, `lua/neotex/util/typst.lua`. Main-file detection is now
content-aware: a chapter file resolves to the root document that actually `#include`s/
`#import`s it, rather than to whichever file happens to sort first alphabetically. Tinymist's
pin is now project-wide and kept in sync automatically (including across `:LspRestart`), the
redundant `typst watch` command was removed in favor of tinymist's own `exportPdf = "onSave"`,
and the preview toggle/stop is now authoritative against `typst-preview.nvim`'s own server
registry instead of a flat boolean.

## What Changed

- `lua/neotex/util/typst.lua` — new shared helper: `project_root`, content-aware `main_file`,
  `pin`/`unpin`/`pinned`, `pdf_path`, `sync_pin`, `setup_autocmds`
- `lua/neotex/util/typst_spec.lua` — new plenary busted spec, 8 passing assertions
- `after/ftplugin/typst.lua` — removed `detect_project_root`/`detect_main_file` (now routes
  through the helper); removed `typst_watch` and the `<leader>lw` binding; pin/unpin rewritten
  to use `typst.pin`/`typst.unpin`/`sync_pin` (project-wide, no `vim.lsp.buf.execute_command`);
  preview toggle/stop/stop-all now check `typst-preview.servers.manager` directly
- `lua/neotex/plugins/text/typst-preview.lua` — `get_main_file`/`get_root` delegate to the
  shared helper instead of duplicating detection logic
- `docs/TYPST.md` — rewrote Multi-File Projects section (content-aware detection order, unified
  root rule, project-wide pin semantics), removed watch references, fixed a stale
  `typst-helpers` troubleshooting command and a stray `<leader>lp` line in the preview command
  list, corrected the LaTeX-comparison table's compilation row
- `docs/MAPPINGS.md` — removed `<leader>lw` from the Typst section, renamed `<leader>lx` to
  "Stop preview", updated the DOCUMENT summary table's Typst `<leader>lx` cell
- `lua/neotex/util/README.md` — added a `typst.lua` entry (file structure, module structure,
  and a new "Typst Helper" section with an API table and quick-usage example)

## Decisions

- Dropped the `typst/`-subdirectory root special case; one rule (`TYPST_ROOT` env, else nearest
  `typst.toml`/`.git`, else the main file's directory) now covers all three real projects.
- Dropped `<leader>lw` (`typst watch`): `exportPdf = "onSave"` already reacts to the same save
  trigger, and dropping it removes tinymist and `typst watch`'s dual-writer race on the same
  PDF. `<leader>lb` remains for an on-demand rebuild.
- Tinymist's pin is kept project-wide (keyed by root in the shared module, not `vim.b`) and is
  always kept in sync with the resolved main file — whether pinned explicitly or detected —
  via `LspAttach`/`BufEnter` autocmds, so it survives `:LspRestart` and `exportPdf=onSave`
  always targets the right document.
- Used `client:exec_cmd` alone for `tinymist.pinMain` (no hand-rolled
  `client:request("workspace/executeCommand", ...)` fallback): Neovim 0.12's stdlib
  `Client:exec_cmd` already checks capability advertisement and performs that fallback
  internally.
- Preview liveness is now decided by querying `typst-preview.servers.manager.get_all()`
  directly, not the flat `process` registry entry, so a server that outlives (or never
  reaches) that entry is still detected and stopped.

## Plan Deviations

- **Task 2 (Phase 2)**: also updated `typst_watch`'s body to call the new helper functions
  (not explicitly listed in the Phase 2 task list) because deleting the two local detection
  functions it called would otherwise have left it calling undefined identifiers between
  Phase 2 and its removal in Phase 4.
- **Task 3 (Phase 3)**: added an explicit `typst.sync_pin(0)` call immediately after
  `typst.setup_autocmds()` in the ftplugin (beyond the plan's literal task list), so the
  buffer already open when the ftplugin first runs is synced immediately rather than waiting
  for the next `BufEnter`/`LspAttach`.
- **Task 4 (Phase 4)**: reordered the preview-control functions (`preview_running`,
  `typst_preview_start`, `typst_preview_stop`, `typst_preview_toggle`, `typst_stop_all`) ahead
  of `tinymist_clear_cache` in file order — content unchanged from the plan's spec — because
  `tinymist_clear_cache` now calls `typst_preview_stop`, and Lua locals must be declared before
  a sibling function's body can close over them as an upvalue.
- No functional deviations beyond the above three implementation-detail adjustments, all
  annotated inline on their respective phase checklists in the plan file.

## Verification

- `lua/neotex/util/typst_spec.lua`: 8/8 assertions pass under `plenary.test_harness`.
- Neovim startup: clean (`nvim --headless -c "lua print('OK')" -c "q"`).
- Headless buffer load of a real chapter file (BimodalLogic): no errors.
- `grep -rn "typst_main_file|detect_main_file|detect_project_root|typst-watch|typst_watch|typst-helpers|buf.execute_command" docs lua after`: empty.
- Cross-project smoke test (chapter -> resolved main/root -> `typst compile` result):

  | Project | Chapter | Resolved main | Resolved root | Compile |
  |---------|---------|----------------|----------------|---------|
  | BimodalLogic | `typst/chapters/ax-lean-appendix.typ` | `typst/BimodalReference.typ` | `~/Projects/BimodalLogic` | exit 0 |
  | cslib MPL | `typst/MPL/chapters/00-introduction.typ` | `typst/MPL/MplReport.typ` | `~/Projects/cslib` | exit 0 (2 pre-existing unrelated font warnings) |
  | Logos/Theory manual | `typst/manual/chapters/01-introduction.typ` | `typst/manual/LogosManual.typ` | `~/Projects/Logos/Theory` | exit 0 |

  All three resolved via the content-aware `#include` scan (confirmed by grepping each
  resolved main file for the tested chapter's relative include path), not the name-based or
  alphabetical fallback.
- Live save-triggered export check (BimodalLogic, headless): opened
  `chapters/ax-lean-appendix.typ`, waited for tinymist to attach (confirmed 1 client, pinned
  via `setup_autocmds`), forced a save. `BimodalReference.pdf`'s mtime and size changed
  (2395472 -> 2421383 bytes); no `chapters/*.pdf` was created.
- Preview server lifecycle (headless): `:TypstPreview` registered one entry in
  `typst-preview.servers.manager.get_all()`; `manager.remove_all()` cleared it. No orphaned
  `tinymist`/`typst` process was left behind by any test run in this dispatch.

## Notes

- The plan's Risk table anticipated Logos/Theory's `typst/manual` might have no root-level
  `.typ` file; at implementation time it does (`LogosManual.typ`), so all three smoke-tested
  projects exercised the content-aware scan path rather than the alphabetical/name-based
  fallback. The fallback paths remain covered by the Phase 1 fixture spec.
- A prior orchestration cycle for this task was blocked partway through Phase 1/2 by an
  unrelated, pre-existing uncommitted keymap-renaming diff in these same files (a continuation
  of a separate keymap-rename theme). Per the user's decision (recorded in
  `.decisions.json`), that diff was committed separately (outside this task's history) before
  Phases 2-5 resumed; this task's own edits land on top of it and preserve its renames.
