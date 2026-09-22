# Research Report: Task #248

**Task**: 248 - Revise Typst document viewing commands
**Started**: 2026-09-21T00:00:00Z
**Completed**: 2026-09-21T00:00:00Z
**Effort**: Medium (1 consolidation module + targeted fixes across 3 files; no new external deps)
**Dependencies**: None
**Sources/Inputs**: `after/ftplugin/typst.lua`, `lua/neotex/plugins/text/typst-preview.lua`,
  `lua/neotex/plugins/lsp/lspconfig.lua`, `lua/neotex/util/process.lua`, `docs/TYPST.md`,
  installed plugin source (`~/.local/share/nvim/lazy/typst-preview.nvim`), Neovim 0.12.3 runtime
  source (`vim/lsp/buf.lua`, `vim/lsp/client.lua`), and the three real multi-file Typst projects
  on this machine (`~/Projects/BimodalLogic/typst`, `~/Projects/Logos/Theory/typst`,
  `~/Projects/cslib/typst`)
**Artifacts**: this report
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- The two `detect_main_file`/`get_main_file` implementations are byte-for-byte duplicated logic
  in two files, and the two root-detection functions (`detect_project_root` in the ftplugin vs.
  `get_root` in the preview plugin config) **actively disagree**: the ftplugin special-cases a
  `typst/` subdirectory under a git root, the preview plugin does not. `docs/TYPST.md` already
  references a `require'typst-helpers'` module that does not exist — the codebase's own docs
  assume the consolidation this task is asking for.
- The alphabetical-fallback in main-file detection is correct for the one real project checked
  (`BimodalLogic/typst/BimodalReference.typ` sorts before the sibling `FormalFoundations.typ`,
  which is deliberately **not** a chapter container) only by coincidence of naming, not by
  design — a differently-named sibling document would silently pick the wrong main file with no
  error. A content-aware check (does the candidate `#include`/`#import` the current file's
  relative path?) is a small, targeted fix that removes the coincidence.
- The `<leader>lp` pin implementation has two real bugs, not just deprecated-API cosmetics: (1)
  `vim.b.typst_main_file` is buffer-local while tinymist's server-side pin is client/workspace-
  scoped, so switching buffers within the same project can silently desync the two; (2)
  `<leader>lk` (`tinymist_clear_cache`) restarts the LSP client, which drops tinymist's
  server-side pin, but never re-sends it — leaving cross-file LSP features (diagnostics,
  `exportPdf=onSave`, go-to-def) silently un-pinned while `<leader>lb`/`<leader>lw`/`<leader>lv`
  (which only read `vim.b`) still believe pinning is active.
- The web-preview toggle (`<leader>ll`) can desync from the plugin's own server registry: the
  process-manager wrapper tracks a single flat `"typst-preview"` name/boolean, but
  `typst-preview.nvim` internally keys servers by `(resolved_main_file_path, mode)`. If the
  detected main file differs between the buffer that started preview and the buffer active when
  `<leader>ll`/`<leader>lx` is next pressed (a real possibility given the duplicated,
  non-content-aware detection above), `TypstPreviewStop` silently targets the wrong path, the
  wrapper unconditionally deregisters anyway, and the *real* server is orphaned — the next
  `<leader>ll` then spawns a second, duplicate preview. This is a plausible, concrete mechanism
  for "preview occasionally unreliable."
- `exportPdf = "onSave"` (tinymist LSP setting) already gives continuous, automatic PDF freshness
  on every save with **zero** extra keybinding. `<leader>lw` (`typst watch`) is a second,
  fully independent CLI process that also continuously recompiles to the same output PDF path.
  Running both concurrently (a normal thing to do, since nothing warns against it) means two
  unsynchronized writers can race on the same `.pdf` file, and — because they use the ftplugin's
  vs. tinymist's independently-computed main-file/root — are not even guaranteed to be building
  the *same* target. This is the strongest concrete lead for "preview is occasionally unreliable"
  and the clearest opportunity to shrink the command surface without losing functionality.

## Context & Scope

Researched the `<leader>l` Typst command group defined in `after/ftplugin/typst.lua` (12
bindings) and the `typst-preview.nvim` plugin spec in
`lua/neotex/plugins/text/typst-preview.lua`, plus their interaction with the tinymist LSP
settings in `lua/neotex/plugins/lsp/lspconfig.lua`. Verified behavior against the installed
plugin source, Neovim 0.12.3's own deprecation notices, and three real multi-file Typst projects
present on this machine to ground "does the current heuristic actually work" claims in fact
rather than speculation.

## Findings

### Existing Configuration (current `<leader>l` surface, 12 bindings)

| Key | Function | Mechanism |
|-----|----------|-----------|
| `<leader>ll` | `typst_preview_toggle` | wraps `:TypstPreview`/`:TypstPreviewStop` + `process` registry |
| `<leader>lb` | `typst_compile` | one-shot `typst compile`, populates quickfix on failure |
| `<leader>lv` | `typst_view_pdf` | opens `{main}.pdf` in Sioyek (no sync) |
| `<leader>le` | `show_diagnostics` | `vim.diagnostic.open_float` (LSP diagnostics, current line) |
| `<leader>lf` | `typst_format` | `vim.lsp.buf.format` (typstyle via tinymist) |
| `<leader>lk` | `tinymist_clear_cache` | deletes stale `.svg`/`.pdf`, stops preview, `:LspRestart tinymist` |
| `<leader>lx` | `typst_stop_all` | stops `typst-watch` + preview if either is registered as running |
| `<leader>lw` | `typst_watch` | toggles a persistent `typst watch` CLI process (continuous compile) |
| `<leader>lq` | `show_compilation_errors` | `:copen` (quickfix populated by `<leader>lb`) |
| `<leader>ls` | `TypstPreviewSyncCursor` | one-shot scroll-preview-to-cursor (web preview only) |
| `<leader>lp` | `pin_main_file` | sets `vim.b.typst_main_file` + `tinymist.pinMain` LSP command |
| `<leader>lu` | `unpin_main_file` | clears `vim.b.typst_main_file` + `tinymist.pinMain(null)` |

Separately, `exportPdf = "onSave"` is set unconditionally in `lspconfig.lua`'s tinymist settings
(line 94), so tinymist itself already re-exports a PDF on every buffer write, independent of any
of the keybindings above.

### Duplicated / disagreeing logic (the core consolidation target)

- `detect_main_file()` (`after/ftplugin/typst.lua:44-90`) and the `get_main_file` closure
  (`lua/neotex/plugins/text/typst-preview.lua:23-65`) are structurally identical: check
  `vim.b.typst_main_file` → check if parent dir name is one of
  `{chapters,sections,parts,includes,content}` → search project root for
  `main.typ`/`index.typ`/`document.typ`/`{dirname}.typ` → fall back to the alphabetically-first
  `.typ` file in the project root → fall back to the current file. Any change to this heuristic
  today requires editing it twice and keeping the two copies byte-identical by hand.
- `detect_project_root()` (ftplugin, lines 11-41) and `get_root` (preview plugin, lines 67-78)
  **disagree**: both check `TYPST_ROOT` env, then search upward for `typst.toml`/`.git`; but only
  the ftplugin version adds a special case — if the marker found is `.git` and a sibling `typst/`
  subdirectory exists and contains the main file, use `typst/` as root instead of the git root.
  The preview-plugin's copy of this function omits that special case entirely (it matches the
  plugin's own upstream default verbatim, i.e. it was never actually customized).
  - Verified with `~/Projects/BimodalLogic` (no `typst.toml`, git root at the repo top,
    `typst/BimodalReference.typ` is the real main file that `#include`s the chapters): ftplugin
    computes root = `.../BimodalLogic/typst`; the preview plugin and the tinymist LSP client
    (`root_markers = {"typst.toml", ".git"}` in `lspconfig.lua`, no special case) both compute
    root = `.../BimodalLogic` (the git top). **Three different root computations exist across
    the three consumers** (ftplugin CLI, preview-plugin subprocess, LSP client attach), not two.
  - Consequence for `typst --root`: a narrower root is *more* restrictive (typst refuses to read
    files outside `--root`), so any relative import that reaches outside `typst/` (e.g. into a
    sibling `lean/` directory at the git root) would compile successfully via the LSP/preview
    path (wider root) but fail via `<leader>lb`/`<leader>lw` (narrower root) — an inconsistency
    that would look exactly like "the preview works but the CLI build sometimes doesn't," or vice
    versa for root-absolute (`"/..."`) imports if any existed.
  - Checked all three real projects that use this `typst/`-subdirectory layout
    (`BimodalLogic`, `Logos/Theory`, `cslib`) for root-absolute imports (`#import "/..."`,
    `image("/...")`, etc.) and found **none** currently. The special case is therefore not
    presently load-bearing for correctness in any known project — it can plausibly be simplified
    away (standardize all three consumers on "nearest `typst.toml` or `.git`," matching what the
    preview plugin and LSP already do by default) rather than replicated a third time into a
    shared helper. This should be confirmed with the user/planner rather than assumed, since the
    comment in the code ("Special case for Logos/Theory") suggests it was added for a concrete
    past reason that may not be visible from current file contents alone.
- `docs/TYPST.md:448` already documents `:lua print(vim.inspect(require'typst-helpers'.detect_main_file()))`
  as a troubleshooting step. No such module exists anywhere in the repo (confirmed by search) —
  this is a stale/aspirational reference that independently corroborates the "put this in one
  shared module" direction named in the dispatch, and gives it a natural home:
  `lua/neotex/util/typst.lua` (parallel to the existing `lua/neotex/util/process.lua`), required
  by both `after/ftplugin/typst.lua` and `lua/neotex/plugins/text/typst-preview.lua`.

### Main-file detection robustness (content-aware fix)

Verified directly against `~/Projects/BimodalLogic/typst/`:
- `BimodalReference.typ` `#include`s all 16 chapter files under `chapters/` (e.g. line 235:
  `#include "chapters/ax-lean-appendix.typ"`).
- A sibling top-level file, `FormalFoundations.typ`, explicitly documents itself (its own
  comment, line 11) as "NOT a chapter of BimodalReference.typ and is not `#include`'d" — it
  imports shared modules (`template.typ`, `notation/bimodal-notation.typ`,
  `generated/status.typ`) but does not include any `chapters/*.typ` file.
- The current alphabetical-fallback (`table.sort` over `glob(project_root .. "/*.typ")`) happens
  to return `BimodalReference.typ` correctly today only because `"B" < "F"` lexically. Renaming
  `FormalFoundations.typ` to something before `"B"`, or adding any other unrelated top-level
  `.typ` document, would silently redirect every chapter's `<leader>lb`/`<leader>lw`/`<leader>lv`
  to the wrong "main file" with no error — exactly the fragility named in the dispatch.
- Recommended fix: when scanning root-level `.typ` candidates, prefer the one whose contents
  contain a literal `#include "<relative-path-to-current-file>"` or
  `#import "<relative-path-to-current-file>"` (relative to the candidate's own directory) over
  the current name-based candidates (`main.typ`/`index.typ`/`document.typ`/`{dirname}.typ`).
  Keep the existing name-based and alphabetical fallbacks as a last resort (safety net) rather
  than removing them, so projects with no chapter cross-references still resolve to *something*
  reasonable. This only needs to scan one level (the immediate project root against the current
  file's `chapters/`-relative path) to fix the concrete case named in the dispatch; deeper nested
  subdirectories are already out of scope for the existing `common_subdirs` check too, so this
  fix does not need to solve nesting the current code doesn't handle either.

### Pin semantics (`<leader>lp`/`<leader>lu`)

- `pin_main_file()`/`unpin_main_file()` call `vim.lsp.buf.execute_command` (`after/ftplugin/typst.lua:100`
  and `:115`), confirmed **deprecated** against the installed Neovim 0.12.3 runtime
  (`vim/lsp/buf.lua`: `vim.deprecate('execute_command', 'client:exec_cmd', '0.12')`, verified live
  via `nvim --headless`). The sanctioned replacement, per `vim/lsp/client.lua:1082`, is
  `client:exec_cmd({command = ..., arguments = ...}, context, handler)` called per-client (the
  code already iterates `vim.lsp.get_clients({bufnr = 0, name = "tinymist"})`, so the fix is a
  call-site swap, not a restructure).
- Bug (not just deprecation): the "pin" is represented in two places with different scope —
  `vim.b.typst_main_file` is **buffer-local** (Neovim-side), while tinymist's own `pinMain`
  state is scoped to the LSP **client** (effectively the whole project, since all files in one
  project attach to the same tinymist client via `root_markers`). Pinning from buffer A sets
  both; opening buffer B in the same project (a different chapter, no `vim.b` set there) causes
  `detect_main_file()` in buffer B to re-run the *heuristic* (ignoring the still-active
  server-side pin) for ftplugin/preview purposes, while tinymist itself continues silently using
  the server-side pin for diagnostics/`exportPdf`/go-to-def. These two notions of "current main
  file" can therefore diverge per-buffer even though only one pin command was ever issued.
- Bug: `tinymist_clear_cache()` (`<leader>lk`) runs `:LspRestart tinymist`, which necessarily
  drops the tinymist client's in-memory pin (a fresh process starts unpinned), but never
  re-issues `pinMain` afterward even though `vim.b.typst_main_file` (the Neovim-side memory of
  "we're pinned") survives the restart untouched. Result: after `<leader>lk`, `<leader>lb`/
  `<leader>lw`/`<leader>lv` keep working correctly (they only read `vim.b`), but LSP-driven
  cross-file features (diagnostics scope, `exportPdf=onSave` target, cross-file go-to-def)
  silently revert to per-buffer analysis until the user manually re-pins — a confusing partial
  regression with no error message.

### Overlap between watch / build / preview / view-pdf verbs

Four independent, unsynchronized paths currently exist that can each (re)compile a Typst
document, each with its own main-file/root resolution:

1. tinymist LSP's `exportPdf = "onSave"` — always active in the background for every save, using
   tinymist's own (server-side pin or heuristic) main-file notion and the LSP client's
   `root_markers`-derived root.
2. `typst-preview.nvim`'s web preview (`<leader>ll`) — a `tinymist preview` subprocess, spawned
   per the plugin-config's `get_main_file`/`get_root` closures (duplicated logic, see above).
3. `<leader>lw` `typst watch` — a separate, persistent CLI process recompiling continuously,
   using the ftplugin's own `detect_main_file`/`detect_project_root`.
4. `<leader>lb` `typst compile` — one-shot, same ftplugin detection, populates quickfix.

(1) and (3) both write the same output `.pdf` on essentially every save, from two unrelated
processes, with no locking or coordination, and — per the root/main-file divergence findings
above — are not guaranteed to even target the same file. This is the single most concrete,
verifiable candidate mechanism for "preview [and PDF output] is occasionally unreliable," and the
clearest opportunity named in the dispatch to shrink the verb count without losing functionality:
`exportPdf=onSave` already provides what `<leader>lw` provides (continuous PDF freshness) with no
extra process and no extra keybinding, once main-file/root detection is unified so tinymist's
target is trustworthy. `<leader>lb` should be kept regardless, since it is the only path that
surfaces failures into the quickfix list (`exportPdf=onSave` fails silently from Neovim's point
of view — errors only show up as LSP diagnostics, which is what `<leader>le`/`<leader>lq` are for
today, so removing `<leader>lb` would lose real functionality; removing `<leader>lw` would not).

### Web-preview toggle/registry desync (second concrete unreliability mechanism)

- `typst-preview.nvim` already ships its own `:TypstPreviewToggle` (confirmed in the installed
  plugin's `lua/typst-preview/commands.lua:110-121`); the ftplugin reimplements toggle logic
  (`typst_preview_toggle`) rather than calling it directly, which is legitimate *only* because it
  also needs to update `lua/neotex/util/process.lua`'s registry (so `<leader>lx`/`typst_stop_all`
  knows to stop it) — this duplication is justified, not accidental, and should be preserved,
  just noted.
- However, the plugin's internal server registry (`lua/typst-preview/servers/manager.lua`) is
  keyed by `(resolved_main_file_path, mode)`, recomputed from `config.opts.get_main_file(current_buffer_path)`
  **at the time each command runs** — while the `process` registry wrapper tracks a single flat
  boolean under the name `"typst-preview"` with **no liveness check** (`process.register_external`
  never attaches a `job_id` or `on_exit`, so a crashed/externally-closed preview leaves the
  registry entry claiming `status = "running"` forever).
- Combined effect: if the detected main file differs between the buffer active when preview was
  started and the buffer active when `<leader>ll`/`<leader>lx` is next pressed (plausible given
  the per-buffer, non-cached detection heuristic discussed above, especially around pin/unpin or
  editing a second chapter file with a fresh `vim.b`), `:TypstPreviewStop` looks up the *current*
  buffer's resolved path in its `servers[path]` map, finds nothing, and does nothing — while the
  `process` wrapper (`typst_preview_stop()`) unconditionally deregisters its flat entry
  regardless of whether the underlying stop actually succeeded. The real server is now orphaned
  (still running, still holding its port/websocket) with zero registry visibility. The next
  `<leader>ll` believes nothing is running and starts a **second** preview server, which is
  exactly the kind of intermittent "preview didn't update" / "opened a stale tab" symptom
  described in the dispatch as "occasionally unreliable."

## Recommendations

1. **Create `lua/neotex/util/typst.lua`** (module name already implied by `docs/TYPST.md`'s
   stale `typst-helpers` reference) exporting one `detect_main_file(current_file)` and one
   `detect_project_root(main_file)`, required by both `after/ftplugin/typst.lua` and
   `lua/neotex/plugins/text/typst-preview.lua`. This resolves the byte-duplication and the
   three-way root disagreement in one place.
2. **Make main-file detection content-aware**: prefer a root-level `.typ` candidate that
   literally `#include`s/`#import`s the current file's relative path over the current
   name-based/alphabetical fallback; keep the existing fallbacks as a safety net, not a
   replacement.
3. **Resolve the root-detection three-way split** by either (a) teaching all three consumers
   (ftplugin, preview plugin, and `vim.lsp.config("tinymist", { root_dir = ... })`, which accepts
   a function callback) to call the same shared `detect_project_root`, or (b) — pending
   confirmation, since no currently-known project needs it for correctness — simplifying away the
   `typst/`-subdirectory special case entirely and standardizing on "nearest `typst.toml` or
   `.git`" everywhere, matching what the preview plugin and LSP already default to. Flag this
   choice for the planning phase rather than deciding unilaterally, since the "Special case for
   Logos/Theory" comment suggests deliberate history not fully visible from current file content.
4. **Fix the pin bugs**: migrate `pin_main_file`/`unpin_main_file` to `client:exec_cmd`; store
   pin state so it is consistent project-wide rather than purely buffer-local (e.g., keyed by
   project root in the new shared module rather than `vim.b`), so switching buffers within one
   pinned project doesn't cause ftplugin/preview and tinymist to compute different "main files";
   and have `tinymist_clear_cache` (`<leader>lk`) re-issue `pinMain` after `:LspRestart` when a
   pin is active, instead of silently losing server-side pin state.
5. **Drop `<leader>lw` (`typst watch`)** in favor of relying solely on tinymist's
   `exportPdf = "onSave"` for continuous PDF freshness, once (1)-(3) make that target
   trustworthy. This removes an entire redundant process/verb and the specific dual-writer race
   condition identified above, directly serving the "sturdy, minimal set" goal. Keep
   `<leader>lb` (one-shot, quickfix-populated) since it is not otherwise redundant.
6. **Fix the toggle/registry desync**: make `typst_preview_stop()` only deregister the
   `process` entry when `:TypstPreviewStop`'s underlying removal actually succeeded (the plugin's
   `preview_off()` already prints a distinguishable "Preview stopped" vs. "Preview not running"
   message that could be checked, or `servers.remove`'s return value could be surfaced), and/or
   make `<leader>lx`/`typst_stop_all` also directly clear the plugin's registry via
   `require('typst-preview').stop_all()`-equivalent rather than relying solely on the current
   buffer's recomputed path matching.

## Decisions

- No code changes made in this research phase (research-only dispatch).
- Chose not to unilaterally decide the `typst/`-subdirectory root special case's fate (keep vs.
  simplify away) — flagged for the plan phase since it affects three consumers and one comment
  in the code references history not verifiable from current file content alone.

## Risks & Mitigations

- **Risk**: dropping `<leader>lw` could regress a workflow the user actually relies on (e.g.,
  seeing compile progress live while typing, faster feedback than `onSave`).
  **Mitigation**: verify with the user/plan phase before removal; `exportPdf=onSave` is a strict
  subset of `typst watch`'s behavior (fires less often — only on save, not on every keystroke),
  so this is a real functional narrowing, not a pure simplification, and should be called out
  explicitly rather than silently dropped.
- **Risk**: consolidating main-file/root detection into a shared module touches three files
  (`after/ftplugin/typst.lua`, `lua/neotex/plugins/text/typst-preview.lua`,
  `lua/neotex/plugins/lsp/lspconfig.lua`) — a regression here breaks compile/preview/LSP
  simultaneously across every `.typ` project on this machine.
  **Mitigation**: verify against all three real multi-file projects found
  (`BimodalLogic`, `Logos/Theory`, `cslib`), not just `BimodalLogic`, before considering this
  complete; `Logos/Theory` and `cslib` were not checked as deeply as `BimodalLogic` in this
  research pass and lack an obvious single top-level `.typ` main file the way `BimodalLogic` does
  (their `typst/` subdirs contain further nested project directories, e.g. `MPL/`,
  `ModalAxiomArchitecture/` for `cslib`) — the content-aware detection algorithm should be
  smoke-tested against these too, since the "one level up, glob root `*.typ`" assumption may not
  hold for them at all.
- **Risk**: `client:exec_cmd` requires the target command to appear in the client's
  `executeCommandProvider.commands` capability list (or be registered as a Lua-side
  `client.commands`/`vim.lsp.commands` handler) — confirmed by reading
  `vim/lsp/client.lua:1082-1106`. If tinymist's advertised `executeCommandProvider` doesn't list
  `tinymist.pinMain` under some server versions, `client:exec_cmd` would warn and no-op rather
  than sending the request `execute_command` currently sends unconditionally.
  **Mitigation**: the implementation phase should verify the live capability list
  (`:lua =vim.lsp.get_clients({name="tinymist"})[1].server_capabilities.executeCommandProvider`)
  against the installed tinymist version before switching, or keep a
  `client.request('workspace/executeCommand', ...)` fallback if the capability isn't advertised.

## Context Extension Recommendations

- **Topic**: Typst multi-file project conventions across this machine's real projects (main-file
  patterns, whether `typst/`-as-root is still needed anywhere).
  **Gap**: `.claude/context/project/neovim/` has no Typst-specific domain file; all current
  knowledge lives only in `docs/TYPST.md` (user-facing, not agent context) and the code comments
  themselves.
  **Recommendation**: after this task's implementation lands, consider adding a short
  `context/project/neovim/domain/typst-multifile.md` documenting the shared helper's contract
  (content-aware detection algorithm, project-root resolution rule, pin-state storage) so future
  Typst-related tasks don't have to re-derive it from scratch.

## Appendix

- Verified live against installed Neovim 0.12.3 (`nvim --headless`) that
  `vim.lsp.buf.execute_command` triggers `vim.deprecate('execute_command', 'client:exec_cmd', '0.12')`.
- Verified `client:exec_cmd` signature and capability-list gating in
  `/nix/store/.../share/nvim/runtime/lua/vim/lsp/client.lua:1082-1106`.
- Verified `typst-preview.nvim`'s own `:TypstPreviewToggle` and per-`(path,mode)` server registry
  in the installed plugin (`~/.local/share/nvim/lazy/typst-preview.nvim/lua/typst-preview/commands.lua`,
  `.../servers/manager.lua`).
- Verified real project structure and include graph in
  `~/Projects/BimodalLogic/typst/{BimodalReference.typ,FormalFoundations.typ,chapters/*}`, and
  confirmed no root-absolute Typst imports exist in any of `BimodalLogic`, `Logos/Theory`, or
  `cslib`'s `typst/` trees (`grep -rnE '#(import|include)\s+"/|image\(\s*"/'`).
- Searched the whole repo for `typst-helpers`/`typst_helpers`; the only hit is the stale
  `docs/TYPST.md:448` reference — no such module currently exists.
