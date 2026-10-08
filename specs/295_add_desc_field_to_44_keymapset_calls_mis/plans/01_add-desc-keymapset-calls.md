# Implementation Plan: Add `desc` to `vim.keymap.set` calls missing it

- **Task**: 295 - Add desc field to vim.keymap.set calls missing it
- **Status**: [IMPLEMENTING]
- **Effort**: 2 hours
- **Dependencies**: None
- **Research Inputs**: specs/295_add_desc_field_to_44_keymapset_calls_mis/reports/01_add-desc-keymapset-calls.md
- **Artifacts**: plans/01_add-desc-keymapset-calls.md (this file)
- **Standards**:
  - .claude/context/formats/plan-format.md
  - .claude/context/standards/status-markers.md
  - .claude/rules/artifact-formats.md
  - .claude/rules/neovim-lua.md
- **Type**: general
- **Lean Intent**: false

## Overview

Forty `vim.keymap.set(...)` call sites across eleven active Lua modules pass an options table
with no `desc` key, violating the project's own Lua Code Style standard and the Neovim
extension's "always use `vim.keymap.set` with description" rule. The fix is mechanical and
metadata-only: add a concise, action-oriented `desc` string to each flagged call, using each
file's existing idiom (`vim.tbl_extend('force', opts, { desc = "..." })` where a shared `opts`
local is reused, or a new key in an inline literal options table otherwise). No behavior,
signature, or logic changes; done when a parenthesis-balanced scan of the active tree reports
exactly one `desc`-less call remaining — the known `config/keymaps.lua:97` false positive.

### Research Integration

The research report supplies a verified, per-call, per-line inventory with a suggested `desc`
string for every flagged call, so no phase below re-derives the list. Three findings from it are
load-bearing for this plan:

1. **The task description's "44" is wrong.** The verified figure is 41 `desc`-less calls
   repo-wide, of which 40 are genuine defects.
2. **`lua/neotex/plugins/tools/autopairs.lua` is already compliant** (`desc = "Accept completion
   or smart autopairs CR"`, line 117) and is excluded from scope entirely — zero edits.
3. **`lua/neotex/config/keymaps.lua:97` is a false positive**: it is the single
   `vim.keymap.set(mode, key, cmd, opts)` line inside the file's own `map()` helper, where `opts`
   already carries `desc = description` threaded from a mandatory parameter every call site
   supplies. It must be left untouched, and it is the one call the final scan is expected to
   still report.

Research also recommends the non-mutating `vim.tbl_extend('force', opts, { ... })` form over
assigning `opts.desc = ...`, because several files share one `opts` local across sibling calls
(`q` / `<Esc>` in the same popup, eight disable-mappings in neo-tree) where in-place mutation
would leak one call's description into the others. That recommendation is adopted as a hard
constraint in every phase below.

**Counts re-derived at plan-authoring time** (not carried unverified): a parenthesis-balanced
scan of `lua/neotex/**/*.lua` excluding `lua/neotex/deprecated/` run while writing this plan
reports **87 total `vim.keymap.set` calls, 41 without a `desc` token**, with per-file line
numbers matching the research inventory exactly. The one discrepancy against the report is the
total (87 here vs. 88 there); the total is not load-bearing for any phase, and the 41/40
missing-count — which is — agrees exactly.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

`specs/ROADMAP.md` line 65 schedules this task in a hygiene batch, described there as "keymap
descs". The roadmap carries ordering only and no gate specific to this work; this plan advances
that single item and adds nothing to the roadmap.

## Goals & Non-Goals

**Goals**:
- Add a concise, accurate `desc` string to each of the 40 verified `desc`-less
  `vim.keymap.set` calls across 11 active modules.
- Use each file's pre-existing idiom for attaching `desc`, introducing no second style within a
  file.
- Leave the scan at exactly one remaining `desc`-less call (`config/keymaps.lua:97`,
  false positive) over the whole active tree.

**Non-Goals**:
- No edits to `lua/neotex/plugins/tools/autopairs.lua` (already compliant) or
  `lua/neotex/config/keymaps.lua` (false positive) — editing either would be a no-op diff.
- No edits under `lua/neotex/deprecated/`.
- No automated `desc` lint script or CI check — research recommends one, but explicitly as a
  separate future task, not part of this scope.
- No refactoring of keymap setup into shared helpers, no behavior changes, no reword of existing
  compliant `desc` strings.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| In-place `opts.desc = "..."` mutation of a shared `opts` local leaks one call's description into sibling calls | M | M | Mandatory `vim.tbl_extend('force', opts, { desc = "..." })` per call site; no phase may assign into a shared `opts`. Grep each touched file for `opts.desc` / `opts%["desc"%]` before closing its phase |
| Line numbers shift as edits are applied within a file (adding a key lengthens some multi-line calls) | L | H | Apply edits top-to-bottom within each file in one pass; re-grep the file before any out-of-order edit |
| A sibling task concurrently edits a file in this plan's scope | M | L | All 11 files are under `lua/neotex/**`; the three declared concurrent siblings (273, 296, 368) own only `agent-system/**`, `init.lua.backup`, and `README.md` — disjoint. Re-read each file immediately before editing and stage only this task's own files |
| Syntax error introduced in a multi-line callback call | H | L | Per-phase `nvim --headless` module load of every touched module before the phase closes |
| Inconsistent `desc` wording across the diff | L | M | Use the research report's suggested strings as the default wording; keep each popup's `q` and `<Esc>` pair textually identical |

## Implementation Phases

**Dependency Analysis**:

| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1, 2, 3 | -- |
| 2 | 4 | 1, 2, 3 |

Phases 1-3 touch pairwise-disjoint file sets and can execute in parallel. Phase 4 is the
whole-tree confirmation sweep and requires all three.

---

### Phase 1: Highest-concentration files (features.lua, neo-tree.lua) [COMPLETED]

**Goal**: Add `desc` to the 19 `desc`-less calls in the two largest concentrations — the pair the
task description itself names as the starting point.

**Tasks**:
- [x] `lua/neotex/plugins/tools/himalaya/ui/features.lua` — 11 calls at lines 55, 69, 101, 110,
      122, 132, 173, 187, 199, 214, 218. Suggested wording from the research inventory: "Open
      selected email", "Close email list", "View selected attachment", "Save selected
      attachment", "Save all attachments", "Close attachments window", "View selected trashed
      email", "Recover selected trashed email", "Permanently delete selected trashed email",
      "Empty trash", "Close trash list" *(completed)*
- [x] `lua/neotex/plugins/ui/neo-tree.lua` — 8 calls at lines 214-221, all sharing one
      `local opts = { buffer = true, silent = true }` in the `neo_tree_buffer_enter` handler.
      Wrap each with `vim.tbl_extend('force', opts, { desc = "..." })`; suggested wording:
      "Disable horizontal scroll wheel (right)" / "(left)", "Disable horizontal scroll (zl)" /
      "(zh)" / "(zL)" / "(zH)", "Disable horizontal cursor movement (Right)" / "(Left)" *(completed)*
- [x] Confirm no `opts.desc =` in-place assignment was introduced in either file *(completed)*
- [x] Load both modules headlessly *(completed)*

**Timing**: 45 minutes

**Depends on**: none

**Verification Tier**: local

**Scope Hypothesis**: This phase asserts 11 `desc`-less calls in `features.lua` and 8 in
`neo-tree.lua` (19 total), at the line numbers listed above. Both figures were re-derived at
plan-authoring time by a parenthesis-balanced scan (see Research Integration) and agree with the
research report; they are not carried unverified. Confirm at implementation time by re-running the
Phase 4 scan scoped to these two files before editing, and treat any divergence from 11/8 as a
signal that the files changed since 2026-10-08 — re-inventory rather than editing the listed line
numbers blind.

**Files to modify**:
- `lua/neotex/plugins/tools/himalaya/ui/features.lua` - add `desc` to 11 calls
- `lua/neotex/plugins/ui/neo-tree.lua` - add `desc` to 8 calls via `vim.tbl_extend`

**Verification**:
- `nvim --headless -c "lua require('neotex.plugins.tools.himalaya.ui.features')" -c "q"` exits 0
  with no error output
- `nvim --headless -c "lua assert(type(dofile('lua/neotex/plugins/ui/neo-tree.lua')) ~= 'nil')" -c "q"`
  exits 0 (plugin spec file: load, do not `require`)
- `grep -nE "opts\.desc\s*=|opts\[.desc.\]\s*=" ` over both files returns nothing
- A scan scoped to these two files reports 0 `desc`-less calls

---

### Phase 2: Notification popup close-mappings [COMPLETED]

**Goal**: Add `desc` to the 10 `desc`-less close-mappings across the two notification modules,
all following the identical shared-`opts` popup pattern.

**Tasks**:
- [x] `lua/neotex/util/notifications.lua` — 8 calls at lines 576, 579, 648, 651, 700, 703, 766,
      769: the `q` / `<Esc>` pair in each of `M.show_history()`, `M.show_stats()`,
      `M.show_config()`, `M.show_help()`. Each popup shares one
      `local opts = { buffer = bufnr, silent = true }`, so wrap per call with
      `vim.tbl_extend('force', opts, { desc = "..." })`. Suggested wording: "Close notification
      history popup", "Close notification stats popup", "Close notification config popup",
      "Close notification help popup" — identical text for the `q` and `<Esc>` of a given popup
      *(completed)*
- [x] `lua/neotex/config/notifications.lua` — 2 calls at lines 275, 278 (`M.show_config()`
      popup); suggested wording "Close notification preferences popup" for both *(completed)*
- [x] Confirm no `opts.desc =` in-place assignment was introduced in either file *(completed)*
- [x] Load both modules headlessly *(completed)*

**Timing**: 25 minutes

**Depends on**: none

**Verification Tier**: local

**Scope Hypothesis**: This phase asserts 8 `desc`-less calls in `util/notifications.lua` and 2 in
`config/notifications.lua`. Note the research report corrects the task description here: the
description claimed 4 for `util/notifications.lua`, the verified figure is 8. Both figures were
re-derived at plan-authoring time (see Research Integration) and agree with the report. Confirm
at implementation time by re-running the Phase 4 scan scoped to these two files before editing;
on divergence from 8/2, re-inventory rather than trusting the listed line numbers.

**Files to modify**:
- `lua/neotex/util/notifications.lua` - add `desc` to 8 popup close-mappings
- `lua/neotex/config/notifications.lua` - add `desc` to 2 popup close-mappings

**Verification**:
- `nvim --headless -c "lua require('neotex.util.notifications')" -c "q"` exits 0
- `nvim --headless -c "lua require('neotex.config.notifications')" -c "q"` exits 0
- `grep -nE "opts\.desc\s*=|opts\[.desc.\]\s*=" ` over both files returns nothing
- A scan scoped to these two files reports 0 `desc`-less calls

---

### Phase 3: Remaining long tail (7 files, 11 calls) [COMPLETED]

**Goal**: Add `desc` to the remaining 11 `desc`-less calls spread one or two per file across
seven modules.

**Tasks**:
- [x] `lua/neotex/plugins/tools/himalaya/data/templates.lua` — lines 837, 838 (`q`, `<Esc>`):
      "Close templates list". Leave the already-compliant calls at 799, 803, 809, 826 untouched
      *(completed)*
- [x] `lua/neotex/plugins/tools/himalaya/data/search.lua` — lines 880, 881 (`q`, `<Esc>`):
      "Close search results" *(completed)*
- [x] `lua/neotex/plugins/tools/luasnip.lua` — lines 52, 61 (select-mode `<Tab>` / `<S-Tab>`):
      "Jump to next snippet placeholder" / "Jump to previous snippet placeholder" *(completed)*
- [x] `lua/neotex/plugins/ai/shared/extensions/picker.lua` — lines 262, 265 (`q`, `<Esc>`):
      "Close installed files window" *(completed)*
- [x] `lua/neotex/util/url.lua` — line 289 (`<C-LeftRelease>` `<Nop>`): "No-op mouse release
      (pairs with Ctrl+Click URL open)". This file's immediately preceding call already uses
      `vim.tbl_extend("force", opts, { desc = ... })` — match it *(completed)*
- [x] `lua/neotex/config/autocmds.lua` — line 18 (`q` in the `man`/`help`/`qf`/`lspinfo`/
      `infoview`/`NvimTree` FileType autocmd): add `desc = "Close buffer"` as a new key in the
      existing inline `{ buffer = ev.buf, silent = true }` literal *(completed)*
- [x] `lua/neotex/plugins/tools/mail.lua` — line 117 (`q` in the aerc terminal `on_open`
      callback): add `desc = "Close mail terminal"` to the existing inline
      `{ buffer = term.bufnr, noremap = true, silent = true }` literal *(completed)*
- [x] Confirm no `opts.desc =` in-place assignment was introduced in any of the seven files *(completed)*
- [x] Load every touched module headlessly *(completed)*

**Timing**: 35 minutes

**Depends on**: none

**Verification Tier**: local

**Scope Hypothesis**: This phase asserts 11 `desc`-less calls across these seven files
(2+2+2+2+1+1+1), at the listed line numbers. Note two corrections the research report makes to
the task description: `templates.lua` has 2, not 4, and `autopairs.lua` — named in the
description — has 0 and is therefore absent from this list. All figures were re-derived at
plan-authoring time (see Research Integration). Confirm at implementation time by re-running the
Phase 4 scan scoped to these seven files before editing; on divergence, re-inventory.

**Files to modify**:
- `lua/neotex/plugins/tools/himalaya/data/templates.lua` - add `desc` to 2 calls
- `lua/neotex/plugins/tools/himalaya/data/search.lua` - add `desc` to 2 calls
- `lua/neotex/plugins/tools/luasnip.lua` - add `desc` to 2 calls
- `lua/neotex/plugins/ai/shared/extensions/picker.lua` - add `desc` to 2 calls
- `lua/neotex/util/url.lua` - add `desc` to 1 call
- `lua/neotex/config/autocmds.lua` - add `desc` to 1 inline options literal
- `lua/neotex/plugins/tools/mail.lua` - add `desc` to 1 inline options literal

**Verification**:
- `nvim --headless -c "lua require('<module>')" -c "q"` exits 0 for each of
  `neotex.plugins.tools.himalaya.data.templates`, `neotex.plugins.tools.himalaya.data.search`,
  `neotex.plugins.ai.shared.extensions.picker`, `neotex.util.url`, `neotex.config.autocmds`
- `luasnip.lua` and `mail.lua` are lazy.nvim plugin specs: load with `dofile` rather than
  `require`, asserting a non-nil return
- `grep -nE "opts\.desc\s*=|opts\[.desc.\]\s*=" ` over all seven files returns nothing
- A scan scoped to these seven files reports 0 `desc`-less calls

---

### Phase 4: Whole-tree confirmation and gate sweep [NOT STARTED]

**Goal**: Confirm the active tree now holds exactly one `desc`-less `vim.keymap.set` call (the
`config/keymaps.lua:97` false positive), that nothing outside scope was touched, and that the
repository's full gate set passes.

**Tasks**:
- [ ] Run the parenthesis-balanced scan over all of `lua/neotex/**/*.lua`, excluding
      `lua/neotex/deprecated/`, and confirm exactly 1 `desc`-less call remains, at
      `lua/neotex/config/keymaps.lua:97`
- [ ] Confirm `lua/neotex/plugins/tools/autopairs.lua` and `lua/neotex/config/keymaps.lua` are
      unmodified (`git diff --name-only` lists neither)
- [ ] Confirm `git diff --name-only` lists exactly the 11 files from Phases 1-3 and nothing else
- [ ] Spot-check rendered descriptions in a live session where practical (`:verbose map q` in a
      notification popup, which-key popup in a neo-tree buffer) — optional, manual, not blocking
- [ ] Run the full gate set: `bash .claude/scripts/verify-deploy.sh`

**Timing**: 20 minutes

**Depends on**: 1, 2, 3

**Verification Tier**: full

**Scope Hypothesis**: This phase asserts the post-fix residual is exactly 1 `desc`-less call out
of 87 total, and that the touched-file set is exactly 11 files. Both are predictions about
implementation-time state derived from the 40-defect inventory re-derived at plan-authoring time;
confirm them by the scan and the `git diff --name-only` checks in the task list above, and treat
any other residual count as a missed call in Phases 1-3 rather than adjusting this figure.

**Files to modify**:
- none planned (verification only)

**Verification**:
- Scan over the active tree reports total 87, missing 1, and names only
  `lua/neotex/config/keymaps.lua:97`
- `bash .claude/scripts/verify-deploy.sh` exits 0 (or its only failures are pre-existing rows in
  `known-failures.txt`)
- `git diff --name-only` is exactly the 11 in-scope files

---

## Testing & Validation

- [ ] Every touched module loads without error under `nvim --headless` (`require` for library
      modules, `dofile` for lazy.nvim plugin spec files)
- [ ] Parenthesis-balanced `desc` scan over active `lua/neotex/`: 1 residual, which is the known
      `config/keymaps.lua:97` false positive
- [ ] No in-place `opts.desc =` assignment anywhere in the diff
- [ ] `bash .claude/scripts/verify-deploy.sh` passes
- [ ] Diff touches exactly 11 files, all under `lua/neotex/`, with no logic or behavior change
      (metadata keys only)

**Reference scan command** (ad hoc, not committed — an automated lint is explicitly out of
scope):

```bash
python3 -I - <<'EOF'
import re, os
root = "lua/neotex"
tot = 0; miss = {}
for dp, dn, fn in os.walk(root):
    if "deprecated" in dp.split(os.sep): continue
    for f in (x for x in fn if x.endswith(".lua")):
        p = os.path.join(dp, f); s = open(p).read()
        for m in re.finditer(r"vim\.keymap\.set\(", s):
            j = m.end() - 1; depth = 0
            while j < len(s):
                if s[j] == '(': depth += 1
                elif s[j] == ')':
                    depth -= 1
                    if depth == 0: break
                j += 1
            tot += 1
            if not re.search(r"\bdesc\s*=", s[m.start():j+1]):
                miss.setdefault(p, []).append(s[:m.start()].count("\n") + 1)
print("total", tot, "missing", sum(len(v) for v in miss.values()))
for p in sorted(miss): print(len(miss[p]), p, miss[p])
EOF
```

## Artifacts & Outputs

- 11 modified Lua modules under `lua/neotex/` (see per-phase **Files to modify**)
- `specs/295_add_desc_field_to_44_keymapset_calls_mis/summaries/01_*-summary.md` at
  implementation completion
- One commit per phase per `.claude/rules/git-workflow.md`, staging only this task's own files
  (never `git add -A`, never a directory pathspec — three sibling tasks share this working tree)

## Rollback/Contingency

Every edit is metadata-only and additive: the contingency for a bad `desc` string is to correct
the string, not to revert. If a syntax error is introduced and the offending hunk is not obvious,
revert that single file from the last green commit (`git checkout <sha> -- <file>`, a
commit-sourced restore rather than a dirty-tree discard) and redo its calls one at a time. No
whole-tree rollback is contemplated; should one become necessary, follow
`.claude/context/contracts/recovery.md`'s rollback rung for the snapshot-then-rollback invocation
shape rather than discarding uncommitted work directly.
