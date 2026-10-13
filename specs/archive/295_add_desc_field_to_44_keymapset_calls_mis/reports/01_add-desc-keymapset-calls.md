# Research Report: Task #295

**Task**: 295 - Add desc field to vim.keymap.set calls missing it
**Started**: 2026-10-08T18:00:00Z
**Completed**: 2026-10-08T18:30:00Z
**Effort**: small (mechanical edits across 12 files, no behavior change)
**Dependencies**: None
**Sources/Inputs**:
- Codebase (`lua/neotex/**/*.lua`, excluding `lua/neotex/deprecated/`)
- CLAUDE.md Lua Code Style standard, `.claude/rules/neovim-lua.md` Keymaps convention
**Artifacts**:
- `specs/295_add_desc_field_to_44_keymapset_calls_mis/reports/01_add-desc-keymapset-calls.md` (this report)
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- A full-repo scan (active code only, `lua/neotex/deprecated/` excluded) confirms **88 total
  `vim.keymap.set(...)` calls**, matching the review's figure exactly.
- The **verified missing-`desc` count is 41, not 44**. The review's per-file breakdown
  undercounted `himalaya/ui/features.lua` (11, not 10) and `util/notifications.lua` (8, not 4),
  overcounted `himalaya/data/templates.lua` (2, not 4), and listed
  `plugins/tools/autopairs.lua` as having 1 missing call when in fact its single call already
  carries `desc = "Accept completion or smart autopairs CR"` (line 117) — zero defects there.
- One further call initially flagged by a naive grep, `config/keymaps.lua:97`, is a **false
  positive**: it is the single `vim.keymap.set(mode, key, cmd, opts)` line inside the file's own
  `map()` helper (lines 91-97), where `opts` is built from a `description` parameter
  (`{ noremap = true, silent = true, desc = description }`) that every call site of `map()`
  supplies. The keymap is already descriptive at every real call site; only the generic helper
  body lacks a literal `desc = "..."` token, which a textual grep cannot distinguish from a
  genuine gap.
- Net result: **40 calls across 11 files** genuinely need a `desc` field added. All are
  contained within the files named in the task description (`autopairs.lua` and
  `config/keymaps.lua` need no edits).
- Recommended approach: mechanical, low-risk edits — add a `desc = "..."` entry to each flagged
  call's options table (or to a `vim.tbl_extend('force', opts, { desc = "..." })` wrapper,
  matching the idiom already used elsewhere in the same file). No logic changes, no tests to
  update; verification is `nvim --headless` module load plus a visual `:map` / which-key spot
  check.

## Context & Scope

**Scope**: the 13 files named in the task description, restricted to active (non-deprecated)
code. The task's own recommended fix — "Add a concise `desc` string to each flagged
`vim.keymap.set` call" — is mechanical and requires no design decisions beyond choosing wording
for each description. This research therefore produces an exhaustive, verified per-call
inventory with a suggested `desc` string for each, so the planning/implementation phase can
proceed directly to edits without re-deriving the list.

**Method**: a small Python script parenthesis-matched every `vim.keymap.set(` call across the
whole `lua/neotex/` tree (excluding `lua/neotex/deprecated/`), extracted the full call text
(handling multi-line callback bodies), and checked each for a `\bdesc\s*=` token. This was run
twice: once scoped to the 13 named files (cross-check against the task description) and once
across the entire active tree (to confirm no missing-`desc` calls exist outside the named
files). Both runs' results were spot-checked by direct `Read`/`grep` of the surrounding code.

## Findings

### Codebase Patterns

- The project already has an established idiom for adding `desc` to a shared `opts` table
  without repeating the other fields: `vim.tbl_extend('force', opts, { desc = "..." })` (used
  throughout `himalaya/data/templates.lua` and `himalaya/data/search.lua` for the calls that
  already comply). New edits should reuse this idiom wherever the surrounding code already does,
  rather than introducing a second style in the same file.
- Several files define a local `opts` table once and reuse it for multiple `vim.keymap.set`
  calls with no `desc` key at all (e.g. `util/notifications.lua`'s four `show_*` popups, each
  with a `{ buffer = bufnr, silent = true }` opts shared by both its `q` and `<Esc>` bindings).
  For these, `desc` must be added per-call (via `vim.tbl_extend` or an inline literal table),
  since `q` and `<Esc>` in the same popup have the same description text, but giving the shared
  `opts` table itself a `desc` would wrongly apply to future reuses with a different meaning.
- `config/keymaps.lua`'s `map()`/`buf_map()` helpers already thread a mandatory `description`
  parameter into `desc` — this is the correct pattern and should be left untouched; every other
  file in scope sets up keymaps with ad hoc inline `opts` tables rather than a shared helper.

### External Resources

- Not applicable — this is a pure codebase mechanical-fix task; no external API/library research
  is needed. `vim.keymap.set`'s `opts.desc` field behavior is unchanged Neovim core API.

### Verified Per-File, Per-Call Inventory

All line numbers below are 1-indexed, current as of this research pass. `desc` suggestions are
proposals for the implementation phase, not binding — adjust wording to match surrounding
comments where a better one is evident.

#### `lua/neotex/util/notifications.lua` — 8 missing (review said 4)

| Lines | Mapping | Context | Suggested `desc` |
|---|---|---|---|
| 576-578 | `n`, `q` | `M.show_history()` popup | "Close notification history popup" |
| 579-581 | `n`, `<Esc>` | `M.show_history()` popup | "Close notification history popup" |
| 648-650 | `n`, `q` | `M.show_stats()` popup | "Close notification stats popup" |
| 651-653 | `n`, `<Esc>` | `M.show_stats()` popup | "Close notification stats popup" |
| 700-702 | `n`, `q` | `M.show_config()` popup | "Close notification config popup" |
| 703-705 | `n`, `<Esc>` | `M.show_config()` popup | "Close notification config popup" |
| 766-768 | `n`, `q` | `M.show_help()` popup | "Close notification help popup" |
| 769-771 | `n`, `<Esc>` | `M.show_help()` popup | "Close notification help popup" |

All 8 share the identical `opts = { buffer = bufnr, silent = true }` pattern; use
`vim.tbl_extend('force', opts, { desc = "..." })` at each call site (opts is reused per-popup, so
the literal `desc` must be added per-call, not to the shared `opts` variable).

#### `lua/neotex/plugins/tools/himalaya/ui/features.lua` — 11 missing (review said 10)

| Lines | Mapping | Context | Suggested `desc` |
|---|---|---|---|
| 55-67 | `n`, `<CR>` | email list window | "Open selected email" |
| 69 | `n`, `q` | email list window | "Close email list" |
| 101-108 | `n`, `<CR>` | attachments list | "View selected attachment" |
| 110-120 | `n`, `s` | attachments list | "Save selected attachment" |
| 122-130 | `n`, `S` | attachments list | "Save all attachments" |
| 132-134 | `n`, `q` | attachments list | "Close attachments window" |
| 173-185 | `n`, `<CR>` | trash list | "View selected trashed email" |
| 187-197 | `n`, `r` | trash list | "Recover selected trashed email" |
| 199-212 | `n`, `d` | trash list | "Permanently delete selected trashed email" |
| 214-216 | `n`, `D` | trash list | "Empty trash" |
| 218 | `n`, `q` | trash list | "Close trash list" |

This file is the single largest concentration (11 of 40, 27.5%) and matches the task's own
"start with `features.lua` and `neo-tree.lua`" recommendation.

#### `lua/neotex/plugins/ui/neo-tree.lua` — 8 missing (matches review)

All 8 are in the `neo_tree_buffer_enter` event handler (lines 213-221), disabling horizontal
scroll/fold keys inside the neo-tree buffer:

| Line | Mapping | Suggested `desc` |
|---|---|---|
| 214 | `n`, `<ScrollWheelRight>` | "Disable horizontal scroll wheel (right)" |
| 215 | `n`, `<ScrollWheelLeft>` | "Disable horizontal scroll wheel (left)" |
| 216 | `n`, `zl` | "Disable horizontal scroll (zl)" |
| 217 | `n`, `zh` | "Disable horizontal scroll (zh)" |
| 218 | `n`, `zL` | "Disable horizontal scroll (zL)" |
| 219 | `n`, `zH` | "Disable horizontal scroll (zH)" |
| 220 | `n`, `<Right>` | "Disable horizontal cursor movement (Right)" |
| 221 | `n`, `<Left>` | "Disable horizontal cursor movement (Left)" |

All 8 share one `opts = { buffer = true, silent = true }` local; same per-call `tbl_extend`
treatment as `notifications.lua` above.

#### `lua/neotex/plugins/tools/himalaya/data/templates.lua` — 2 missing (review said 4)

| Lines | Mapping | Suggested `desc` |
|---|---|---|
| 837 | `n`, `q` | "Close templates list" |
| 838 | `n`, `<Esc>` | "Close templates list" |

Lines 799, 803, 809, 826 in the same function already have `desc` ("New template", "Edit
template", "Delete template", "Preview template") — these are NOT part of the 44/41/40 and need
no change.

#### `lua/neotex/plugins/tools/himalaya/data/search.lua` — 2 missing (matches review)

| Lines | Mapping | Suggested `desc` |
|---|---|---|
| 880 | `n`, `q` | "Close search results" |
| 881 | `n`, `<Esc>` | "Close search results" |

#### `lua/neotex/config/notifications.lua` — 2 missing (matches review)

| Lines | Mapping | Context | Suggested `desc` |
|---|---|---|---|
| 275-277 | `n`, `q` | `M.show_config()` popup | "Close notification preferences popup" |
| 278-280 | `n`, `<Esc>` | `M.show_config()` popup | "Close notification preferences popup" |

#### `lua/neotex/plugins/tools/luasnip.lua` — 2 missing (matches review)

| Lines | Mapping | Suggested `desc` |
|---|---|---|
| 52-59 | `s`, `<Tab>` | "Jump to next snippet placeholder" |
| 61-68 | `s`, `<S-Tab>` | "Jump to previous snippet placeholder" |

#### `lua/neotex/plugins/ai/shared/extensions/picker.lua` — 2 missing (matches review)

| Lines | Mapping | Suggested `desc` |
|---|---|---|
| 262-264 | `n`, `q` | "Close installed files window" |
| 265-267 | `n`, `<Esc>` | "Close installed files window" |

#### `lua/neotex/util/url.lua` — 1 missing (matches review)

| Line | Mapping | Suggested `desc` |
|---|---|---|
| 289 | `n`, `<C-LeftRelease>` | "No-op mouse release (pairs with Ctrl+Click URL open)" |

#### `lua/neotex/config/autocmds.lua` — 1 missing (matches review)

| Line | Mapping | Context | Suggested `desc` |
|---|---|---|---|
| 18 | `n`, `q` | `FileType` autocmd for `man`/`help`/`qf`/`lspinfo`/`infoview`/`NvimTree` buffers | "Close buffer" |

#### `lua/neotex/plugins/tools/mail.lua` — 1 missing (matches review)

| Line | Mapping | Context | Suggested `desc` |
|---|---|---|---|
| 117-119 | `n`, `q` | aerc terminal `on_open` callback | "Close mail terminal" |

### Not Part of the Fix (verified already compliant or false positive)

| File | Line | Why excluded |
|---|---|---|
| `lua/neotex/plugins/tools/autopairs.lua` | 106-117 | Already has `desc = "Accept completion or smart autopairs CR"` (line 117). The review's claim of 1 missing call here is incorrect. |
| `lua/neotex/config/keymaps.lua` | 97 | `vim.keymap.set(mode, key, cmd, opts)` inside the file's own `map()` helper; `opts` is built as `vim.tbl_deep_extend("force", { noremap = true, silent = true, desc = description }, options or {})`, and every call site of `map()` (dozens, e.g. line 234 `map("n", "<C-z>", "<nop>", {}, "Disable suspend")`) supplies a description. A literal-token grep cannot see this; treat as a false positive, not a defect. |

## Recommendations

1. Fix the **40 genuinely missing calls** listed in the per-file tables above, across 11 files
   (`autopairs.lua` and `config/keymaps.lua` need no changes — see Not Part of the Fix).
2. Start with `himalaya/ui/features.lua` (11) and `neo-tree.lua` (8) as the task description
   suggests — together 19 of 40 (47.5%).
3. For each call, prefer the file's existing idiom for attaching `desc`:
   - If the call already uses `vim.tbl_extend('force', opts, { ... })`, add `desc = "..."` inside
     that same wrapper (see `templates.lua`/`search.lua` compliant calls for the pattern).
   - If the call uses a literal inline options table (`{ buffer = ..., silent = true }`) passed
     directly, either add `desc` as a new key in that literal table, or — where the same `opts`
     variable is reused by a sibling call with a *different* intended description (e.g. `q` vs
     `<Esc>` in the same popup sharing one `opts` table) — wrap with `vim.tbl_extend('force',
     opts, { desc = "..." })` at each call site instead of mutating the shared `opts` table, so
     the two sibling calls can carry the same text without one call overwriting the shared
     table's `desc` for the other (in these cases the text is actually identical, so either
     approach works, but the wrapper form is clearer and matches the existing codebase idiom).
   - If the call passes `opts` as the literal 4th positional argument with no table at all,
     construct a table inline (e.g. `config/autocmds.lua:18` already passes an inline literal
     table — just add the key to it).
4. Use the suggested `desc` text above as a starting point; a human-readable, action-oriented
   phrase describing what the mapping does (consistent with this file's own existing `desc`
   strings elsewhere) is sufficient — exact wording is not load-bearing.
5. No test suite covers keymap `desc` strings in this repo (confirmed: no `*_spec.lua`/`test_*.lua`
   references `vim.keymap.set` assertions for these files). Verification should be:
   - `nvim --headless -c "lua require('neotex...')" -c "q"` for each touched module, to catch
     syntax errors.
   - A spot-check via `:verbose map <key>` or which-key popup in the touched buffer contexts
     (optional, manual) to confirm the new `desc` renders as expected.
6. Do not touch `autopairs.lua` or `config/keymaps.lua:97` — both are already compliant or
   compliant-by-indirection; editing them would be a no-op risking an unnecessary diff.

## Decisions

- Treat the verified actual count (41 missing calls repo-wide, 40 after excluding the
  `config/keymaps.lua` false positive) as authoritative over the task description's "44" figure;
  the plan/implementation phases should target the per-file inventory in this report rather than
  re-deriving counts from scratch.
- `config/keymaps.lua` and `autopairs.lua` are excluded from the fix scope entirely (zero edits),
  despite being named in the task's file list, because direct inspection shows no actual defect
  in either.
- Suggested `desc` strings are advisory, not prescriptive — the implementation phase may adjust
  wording as long as each flagged call ends up with a concise, accurate `desc`.

## Risks & Mitigations

- **Risk**: a shared `opts` table (e.g. `util/notifications.lua`'s four popups, `neo-tree.lua`'s
  eight disable-mappings) could be mutated in place by the first call, accidentally giving the
  second call (`<Esc>`) the first call's description reference semantics are fine since Lua
  tables are copied by `tbl_extend`, not mutated — but a careless edit using `opts.desc = "..."`
  directly (mutating the shared table) rather than `vim.tbl_extend('force', opts, {...})` would
  leak one call's description into both. **Mitigation**: always use the non-mutating
  `vim.tbl_extend('force', opts, { desc = "..." })` form (or a fresh literal table) at each call
  site; never assign into the shared `opts` variable directly.
- **Risk**: line numbers will shift as edits are applied sequentially within a file (adding a
  `desc` key lengthens some multi-line calls by one line). **Mitigation**: apply edits
  top-to-bottom per file in a single pass, or re-grep line numbers before each edit if working
  file-by-file across sessions.
- **Risk**: none of these are destructive or behavior-changing (desc is metadata-only, it does
  not alter what a keymap does), so there is no functional regression risk — only a cosmetic
  diff-review risk if wording is inconsistent. **Mitigation**: addressed by Recommendation 4
  (match existing wording conventions per file).

## Context Extension Recommendations

- **Topic**: keymap `desc` field compliance checking.
- **Gap**: there is no automated lint (e.g. a `nvim --headless` script or CI check) that flags
  `vim.keymap.set` calls lacking `desc`, which is why 40-44 such calls accumulated undetected
  despite the standard being documented in both CLAUDE.md and `.claude/rules/neovim-lua.md`.
- **Recommendation**: consider adding a lightweight repo-local lint script (similar in spirit to
  this research's Python scan) to `.claude/scripts/` or a `tests/` check, so future PRs catch new
  undocumented keymaps before merge. This is a suggestion for a separate future task, not part of
  this task's scope.

## Appendix

### Search queries / commands used

- `grep -rn "vim.keymap.set" <file>` per named file, to enumerate call sites.
- A parenthesis-balanced Python scan (ad hoc script, not committed) over all `lua/neotex/**/*.lua`
  excluding `lua/neotex/deprecated/`, extracting each full `vim.keymap.set(...)` call (including
  multi-line callback bodies) and testing for a `\bdesc\s*=` token — run both scoped to the 13
  named files and across the whole active tree, to cross-check the task description's counts and
  confirm no missing-`desc` calls exist outside the named files.
- Direct `Read`/`sed -n` inspection of every flagged line's surrounding function, to determine
  context for the suggested `desc` text and to rule out false positives (`config/keymaps.lua`,
  `autopairs.lua`).

### References

- CLAUDE.md § Code Standards → Lua Code Style → Keymaps: "Document in comments, use
  `vim.keymap.set` with descriptive options."
- `.claude/rules/neovim-lua.md` § Neovim API Patterns → Keymaps: "Always use `vim.keymap.set`
  with description" and § Do Not: "Omit keymap descriptions."
