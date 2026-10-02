# Research Report: Task #294

**Task**: 294 - Fix CLAUDE.md standards pointer paths to the nonexistent extensions/nvim directory
**Started**: 2026-10-02T13:17:56Z
**Completed**: 2026-10-02T13:30:00Z
**Effort**: trivial (4-line path substitution, single file)
**Dependencies**: None
**Sources/Inputs**:
- Codebase: root `CLAUDE.md`, `.claude/extensions/nvim/`, `.claude/context/project/neovim/standards/`
- `specs/state.json` task 294 entry (`file_scope`)
**Artifacts**:
- `specs/294_fix_claude_md_standards_pointer_paths_to/reports/01_fix-standards-pointer-paths.md` (this report)
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- Confirmed: root `CLAUDE.md` contains four `[Used by: ...]` pointer paths of the form
  `.claude/extensions/nvim/context/project/neovim/standards/{name}.md` — all four are dead paths.
- Confirmed: `.claude/extensions/nvim/` contains only `manifest.json`; it has no `context/`
  subtree at all. It is the extension's manifest/source directory, not a deploy-context path.
- Confirmed: the real, current standards files exist at
  `.claude/context/project/neovim/standards/{documentation-policy,box-drawing-guide,emoji-policy,lua-assertion-patterns}.md`.
- Recommended approach: a direct 4-line find/replace in root `CLAUDE.md`, changing the prefix
  `.claude/extensions/nvim/context/project/neovim/standards/` to
  `.claude/context/project/neovim/standards/` on each of the four lines. No other files, no
  deploy/source-store boundary concern (root `CLAUDE.md` is outside `.claude/**`), no code or
  script changes.

## Context & Scope

The review finding (from all-review on 2026-10-01) identified that root `CLAUDE.md` (the
hand-maintained "Neovim Configuration Guidelines" file, distinct from the auto-generated
`.claude/CLAUDE.md` "Agent System" file) points its Documentation Policy, Box Drawing, Character
Encoding/Emoji Policy, and Lua Testing Assertion Patterns sections at a nonexistent directory
tree. `specs/state.json`'s task 294 entry declares `file_scope: ["CLAUDE.md"]`, confirming the
task is scoped to exactly this one file.

Because the edit target (`CLAUDE.md` at repo root) is outside `.claude/**`, the
source-store-deploy-boundary rule (`.claude/rules/source-store-deploy-boundary.md`) does not
apply — this is a direct, hand-authored file, not a deploy artifact regenerated from a source
store. This was independently re-verified during research, not merely taken from the dispatch
description.

## Findings

### Codebase Patterns

Verified directly:

```
$ grep -n "standards/" CLAUDE.md
34:See `.claude/extensions/nvim/context/project/neovim/standards/documentation-policy.md` ...
37:See `.claude/extensions/nvim/context/project/neovim/standards/box-drawing-guide.md` ...
40:See `.claude/extensions/nvim/context/project/neovim/standards/emoji-policy.md` ...
63:See `.claude/extensions/nvim/context/project/neovim/standards/lua-assertion-patterns.md` ...
```

Path existence check (all four wrong paths MISSING, all four correct paths EXISTS):

| File | Wrong path (`.claude/extensions/nvim/...`) | Correct path (`.claude/context/project/neovim/standards/...`) |
|---|---|---|
| documentation-policy.md | MISSING | EXISTS |
| box-drawing-guide.md | MISSING | EXISTS |
| emoji-policy.md | MISSING | EXISTS |
| lua-assertion-patterns.md | MISSING | EXISTS |

`.claude/extensions/nvim/` directory listing contains exactly one entry: `manifest.json`. There
is no `context/` subdirectory under it at all — confirming it is purely the extension
manifest/source directory, never a path any deployed content resolves through.

The four lines in `CLAUDE.md` (with exact current line numbers, 1-indexed):
- Line 34 — `## Documentation Policy` section
- Line 37 — `## Box Drawing` section
- Line 40 — `## Character Encoding and Emoji Policy` section
- Line 63 — `### Lua Testing Assertion Patterns` subsection (under `## Testing Protocols`)

All four currently read `See \`.claude/extensions/nvim/context/project/neovim/standards/{name}.md\` for ...` and need only the directory-prefix segment corrected; the trailing filename and surrounding sentence are correct and unchanged.

### Historical Context (Important — Do Not Let This Reopen the Question)

A repo-wide grep for the wrong-prefix string surfaced an **archived, differently-scoped task
that previously reused this same task number** (`specs/vault/01-vault/archive/294_fix_extension_dependent_refs/`)
whose plan *deliberately changed these same four paths in the opposite direction* — from
`.claude/context/project/neovim/standards/...` to
`.claude/extensions/nvim/context/project/neovim/standards/...` — on the premise that the
extension-namespaced path was canonical at that time. A later archived report (`433_move_nvim_specific_content_to_neovim_extension/reports/01_extension-restructuring.md`)
likewise asserted root `CLAUDE.md` "already cross-references extension paths correctly" using
the `.claude/extensions/nvim/...` form, and other archived reports (`304_fix_rule_source_refs`,
`349_review_update_claude_agent_system_docs`, `441_update_readme_documentation`) also treated
`.claude/extensions/nvim/context/project/neovim/standards/*.md` as existing and correct at the
time they were written.

This is not evidence that the current fix is wrong — it is evidence the deploy architecture
changed since those tasks ran, and today's manifest confirms the *current* truth decisively:
`.claude-extensions.json`'s `nvim` entry `installed_files` list enumerates exactly
`.claude/context/project/neovim/standards/{box-drawing-guide,documentation-policy,emoji-policy,lua-assertion-patterns,lua-style-guide,testing-patterns}.md`
(flat, directly under `.claude/context/...`) plus a single `.claude/extensions/nvim/manifest.json`
— there is no `installed_files` entry anywhere under `.claude/extensions/nvim/context/...`. Per
`.claude/context/project/neovim/domain/extension-deploy-modes.md`, `.claude/extensions/{ext}/`
is populated by the symlink installer only for skills/agents/commands categories; context/
standards files are deployed flat into `.claude/context/...` by the copy engine, never nested
under `.claude/extensions/{ext}/context/...`. The source store
(`agent-system/extensions/nvim/context/project/neovim/standards/`) also has these six files, all
copied to the flat `.claude/context/...` destination per `installed_files`, confirming the
current, authoritative mapping matches the "correct path" column in the table below, not the
old archived tasks' assumption.

**Conclusion for implementation/plan stages**: trust the live `installed_files` manifest and the
live filesystem check in this report over any archived task's prior assumption. Do not consult
the three archived reports/plans above as a reason to revert this fix — they reflect a now-
superseded deploy-path convention.

### External Resources

Not applicable — this is a pure internal path-correction fix with no external dependency or
documentation lookup required.

## Recommendations

1. In root `CLAUDE.md`, replace the prefix `.claude/extensions/nvim/context/project/neovim/standards/`
   with `.claude/context/project/neovim/standards/` on all four lines (current lines 34, 37, 40,
   63). This is a literal substring substitution — the filename segment
   (`documentation-policy.md`, `box-drawing-guide.md`, `emoji-policy.md`,
   `lua-assertion-patterns.md`) and the rest of each sentence remain untouched.
2. No other files require changes: `file_scope` for task 294 is `["CLAUDE.md"]` only, and no
   other pointer in the repository was found referencing the wrong `.claude/extensions/nvim/`
   prefix for these four standards files (this report's codebase check was limited to the task's
   declared scope and the specific four paths named in the review finding; a plan/implementation
   pass should do a final `grep -rn "extensions/nvim/context/project/neovim/standards"` across the
   repo as a cheap confirming check before closing, but no evidence from this research suggests
   other occurrences exist).
3. No test suite exercises these path strings (they are documentation pointers, not
   code-resolved paths), so verification is simply: re-run the four-path existence check after
   the edit and confirm all four now resolve to `EXISTS` under the corrected prefix, and that the
   old wrong-prefix string no longer appears in `CLAUDE.md`.

## Decisions

- Confirmed no source-store-deploy-boundary concern applies: target file is `CLAUDE.md` at repo
  root, outside `.claude/**`.
- Confirmed the fix is a straightforward string substitution with no structural, semantic, or
  cross-file ripple — appropriate for a direct single-phase implementation plan (or even a
  skip-to-implement if the orchestration flow permits), not a multi-phase plan.

## Risks & Mitigations

- **Risk**: Accidentally touching unrelated lines or sections while editing. **Mitigation**: use
  a scoped find/replace targeting the exact wrong-prefix substring only, and diff-review before
  commit.
- **Risk**: Missing a fifth occurrence elsewhere in the repo. **Mitigation**: recommended
  confirming repo-wide grep in the Recommendations section above, prior to closing the task.
- **Risk**: A future planning/implementation pass finds the archived `294_fix_extension_dependent_refs`
  (or `433`/`304`/`349`/`441`) precedent via grep or memory search and mistakenly treats it as
  authoritative, reverting the fix back to the `.claude/extensions/nvim/...` form. **Mitigation**:
  see "Historical Context" above — the live `.claude-extensions.json` `installed_files` manifest
  and the live filesystem are the ground truth, and both confirm the flat `.claude/context/...`
  path is correct today regardless of what was true when those older tasks ran.

## Context Extension Recommendations

None — this is a meta/documentation path-correction task with no gap in existing
`.claude/context/` coverage. The standards files themselves are current and already documented;
only the pointer paths in `CLAUDE.md` were stale.

## Appendix

Search queries / commands used:
- `grep -n "standards/" CLAUDE.md`
- Existence checks (`[ -f ... ]`) for each of the 4 wrong-path and 4 correct-path candidates
- `find .claude/extensions/nvim -maxdepth 3 -type d` and `ls .claude/extensions/nvim/`
- `jq`/`sed -n` lookups against `specs/state.json` for the task 294 entry (`file_scope`,
  `description`, `status`)
- `sed -n '1,65p' CLAUDE.md` to confirm exact line numbers and surrounding section context
