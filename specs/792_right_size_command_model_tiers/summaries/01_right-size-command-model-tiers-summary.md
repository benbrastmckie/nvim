# Implementation Summary: Task #792

**Completed**: 2026-06-30
**Duration**: ~30 minutes

## Overview

Right-sized `model:` frontmatter across 12 slash-command canonical extension sources, reserving `opus` for the 6 context-accumulating orchestrator/deep-reasoning commands. Fixed the root-cause `meta.md` embedded command-scaffolding template that was hardcoding `opus` for every newly scaffolded command, and reconciled the two docs (`creating-commands.md`, `command-template.md`) that described command model tiers so they now agree with the refreshed policy from task 790.

## What Changed

**Phase 1 — OMIT-FIELD (removed `model: opus` line entirely, so command inherits its skill/agent's declared tier):**
- `.claude/extensions/core/commands/fix-it.md`
- `.claude/extensions/core/commands/spawn.md`
- `.claude/extensions/core/commands/project-overview.md`
- `.claude/extensions/core/commands/refresh.md`
- `.claude/extensions/core/commands/tag.md`
- `.claude/extensions/cslib/commands/vet.md`

**Phase 2 — DOWNGRADE-TO-SONNET (`model: opus` → `model: sonnet`):**
- `.claude/extensions/core/commands/merge.md`
- `.claude/extensions/core/commands/errors.md`
- `.claude/extensions/core/commands/task.md`
- `.claude/extensions/core/commands/todo.md`
- `.claude/extensions/core/commands/review.md`
- `.claude/extensions/cslib/commands/pr.md`

**Phase 3 — root-cause + doc reconciliation:**
- `.claude/extensions/core/commands/meta.md` — embedded "Command Template Reference" code block (previously line 184) changed `model: opus` → `model: sonnet`, with a new guidance note above the block explaining the tiering policy. Frontmatter `model: opus` on line 5 (the command's own tier — `/meta` is a keep-opus command) was left untouched and verified intact.
- `.claude/docs/guides/creating-commands.md` — frontmatter example changed from `model: opus` to `model: sonnet`; the "Model Selection" table was rewritten (it was previously inverted vs. policy) to state: context-accumulating orchestrators (`/research`, `/plan`, `/implement`, `/orchestrate`) and deep-reasoning commands (`/meta`, `/revise`) = `opus`; pure-delegation commands = omit; inline/single-shot utility commands (`/todo`, `/review`, `/task`, `/merge`, `/errors`) = `sonnet`.
- `.claude/docs/templates/command-template.md` — verify-only; line 5 already read `model: sonnet`, no change needed.

No edits were made to any file under `.claude/commands/` or the dotfiles tree (these are generated copies/symlinks per the plan's non-goals).

## Decisions

- Followed the plan's phase structure exactly (4 phases, disjoint file sets in phases 1-3, verification-only phase 4).
- In `meta.md`, targeted only the embedded template's code block, verified line 5 (`/meta`'s own frontmatter) remained `model: opus` after the edit.
- Added a short tiering-guidance note directly above the embedded template in `meta.md` so future manual edits to the scaffold template have the rationale in context.

## Plan Deviations

- None (implementation followed plan).

## Verification

All Phase 4 greps specified in the plan were run and passed:

1. **KEEP-OPUS** (expect `model: opus` on all six): `research.md`, `plan.md`, `implement.md`, `orchestrate.md`, `revise.md` all print `model: opus`; `meta.md` frontmatter (lines 1-6) prints `model: opus`. **PASS**
2. **OMIT-FIELD** (expect no frontmatter `model:` line): `fix-it.md`, `spawn.md`, `project-overview.md`, `refresh.md`, `tag.md`, `vet.md` all report `OK (omitted)`. **PASS**
3. **DOWNGRADE** (expect `model: sonnet`): `merge.md`, `errors.md`, `task.md`, `todo.md`, `review.md`, `pr.md` all print `model: sonnet`. **PASS**
4. **meta.md embedded template**: `grep -nE 'model: opus' .claude/extensions/core/commands/meta.md` returns only `5:model: opus` — the embedded template no longer hardcodes opus. **PASS**
5. **Docs consistency**: `creating-commands.md` frontmatter example now shows `model: sonnet`, and the rewritten Model Selection table lists orchestrators/deep-reasoning as opus and pure-delegation/utility as omit/sonnet; `command-template.md` line 5 reads `model: sonnet`. **PASS**

Frontmatter validity: each of the 12 edited files retains intact YAML delimiters and all other frontmatter keys (`description`, `allowed-tools`, `argument-hint` where present).

- Build: N/A (meta task, no build system)
- Tests: N/A (documentation/frontmatter edits only)
- Files verified: Yes

## Notes

**REQUIRED MANUAL STEP — the user must run the Neovim extension-picker resync TWICE:**

1. Once for the **nvim project** (`/home/benjamin/.config/nvim`)
2. Once for the **dotfiles project** (`/home/benjamin/.dotfiles`)

This implementation edited only the canonical extension sources under `.claude/extensions/core/commands/` and `.claude/extensions/cslib/commands/`. The generated `.claude/commands/` files in both the nvim project and the dotfiles project are copies/symlinks produced by the extension-picker "Load Core"/resync operation, and were intentionally left untouched (per the plan's non-goals — hand-editing generated files would be silently reverted on the next resync anyway). Until the user runs the resync in both projects, the generated command files will still show the old `model:` values.
